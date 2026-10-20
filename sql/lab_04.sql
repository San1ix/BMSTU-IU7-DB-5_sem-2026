CREATE EXTENSION IF NOT EXISTS plpython3u;

-- 1. считаем содержание кофеина в позиции меню

CREATE OR REPLACE FUNCTION get_menu_item_coffeine(target_menu_item_id INT)
RETURNS NUMERIC(6, 1)
LANGUAGE plpython3u
AS $$
	query = f"""
		SELECT r.amount_needed
		FROM recipes r
		JOIN ingredients i ON i.ingredient_id = r.ingredient_id
		WHERE r.menu_item_id = {target_menu_item_id}
			AND i.category = 'Зерновой кофе'
	"""

	res = plpy.execute(query)
	
	if (len(res) == 0):
		return 0.0

	amount_kg = float(res[0]['amount_needed'])
	grams = amount_kg * 1000.0
	caffeine_mg = grams * 10.0

	return round(caffeine_mg, 1)
$$;

SELECT name 
	, get_menu_item_coffeine(menu_item_id) AS Coffeine_mg
FROM menu_items;

DROP FUNCTION IF EXISTS get_menu_item_coffeine(INT);

-- 2. средняя стоимость поставок с инфляцией

CREATE OR REPLACE FUNCTION plpy_mul_state(state NUMERIC, next_val NUMERIC)
RETURNS NUMERIC 
LANGUAGE plpython3u
AS $$
	if state is None:
		return next_val
	if next_val is None:
		return state

	res = 0.3 * float(next_val) + 0.7 * float(state)

	return round(res, 2)	
$$;

CREATE AGGREGATE dynamic_cost(NUMERIC) (
	SFUNC = plpy_mul_state,
    STYPE = NUMERIC
);

SELECT i.ingredient_id
	, i.name
	, i.unit
	, ROUND(AVG(d.total_cost / d.quantity)) AS avg_cost
	, dynamic_cost(ROUND(d.total_cost / d.quantity, 2)) AS actual_cost 
FROM ingredients i 
JOIN deliveries d ON i.ingredient_id = d.ingredient_id 
GROUP BY i.ingredient_id, i.name, i.unit
ORDER BY i.ingredient_id;

DROP AGGREGATE IF EXISTS dynamic_cost(NUMERIC);
DROP FUNCTION IF EXISTS plpy_mul_state(NUMERIC, NUMERIC);

-- 3. График смен
DROP FUNCTION IF EXISTS generate_barista_shedule(INT, INT, INT);

CREATE OR REPLACE FUNCTION generate_barista_shedule(target_shop_id INT, target_year INT, target_month INT)
RETURNS TABLE (
    shift_date DATE,
    employee_id INT,
    employee_name VARCHAR,
    shift_type VARCHAR
)
LANGUAGE plpython3u
AS $$
	import datetime
	
	query = f"""
	    SELECT employee_id, full_name
	    FROM employees
	    WHERE shop_id = {target_shop_id}
	      AND position ILIKE '%бариста%'
	    ORDER BY employee_id;
	"""
	staff = plpy.execute(query)
	
	if len(staff) == 0:
	    return []
	
	if target_month == 12:
	    next_month = datetime.date(target_year + 1, 1, 1)
	else:
	    next_month = datetime.date(target_year, target_month + 1, 1)
	
	days_in_month = (next_month - datetime.timedelta(days=1)).day
	
	schedule = []
	for day in range(1, days_in_month + 1):
	    shift_date = datetime.date(target_year, target_month, day)
	    
	    m_emp = staff[(day * 2) % len(staff)]
	    schedule.append({
	        'shift_date': shift_date,
	        'employee_id': m_emp['employee_id'],
	        'employee_name': m_emp['full_name'],
	        'shift_type': 'Утренняя смена'
	    })
	
	    e_emp = staff[(day * 2 + 1) % len(staff)]
	    schedule.append({
	        'shift_date': shift_date,
	        'employee_id': e_emp['employee_id'],
	        'employee_name': e_emp['full_name'],
	        'shift_type': 'Вечерняя смена'
	    })
	    
	return schedule
$$;

SELECT * FROM generate_barista_shedule(4, 2026, 10);

-- 4. автозаказ ингредиента в дефиците

CREATE OR REPLACE PROCEDURE auto_reorder_supplies(target_shop_id INT)
LANGUAGE plpython3u
AS $$
	deficit_query = f"""
	    SELECT 
	        i.ingredient_id, 
	        i.name, 
	        i.min_stock_level,
	        i.cost_per_unit,
	        COALESCE(SUM(d.quantity), 0) AS current_stock
	    FROM ingredients i
	    LEFT JOIN deliveries d ON i.ingredient_id = d.ingredient_id AND d.shop_id = {target_shop_id}
	    GROUP BY i.ingredient_id, i.name, i.min_stock_level, i.cost_per_unit
	    HAVING COALESCE(SUM(d.quantity), 0) < i.min_stock_level
	    LIMIT 3;
	"""
	deficit_items = plpy.execute(deficit_query)
	
	if len(deficit_items) == 0:
	    plpy.notice(f"В кофейни {target_shop_id} кол-во ингредиентов в норме")
	    return

	supplier_query = f"""
	    SELECT supplier_id, company_name 
	    FROM suppliers 
	    WHERE rating IS NOT NULL 
	    ORDER BY rating DESC, min_order_price ASC 
	    LIMIT 1;
	"""
	best_supplier = plpy.execute(supplier_query)[0]
	sup_id = best_supplier['supplier_id']
	sup_name = best_supplier['company_name']

	plpy.notice(f"ЗАКАЗ СЫРЬЯ ДЛЯ КОФЕЙНИ {target_shop_id} (Поставщик: {sup_name})")

	for item in deficit_items:
	    ing_id = item['ingredient_id']
	    ing_name = item['name']
	    
	    order_qty = float(item['min_stock_level']) * 2.0
	    if order_qty <= 0:
	        order_qty = 10.0
	        
	    unit_cost = float(item['cost_per_unit'])
	    total_cost = round(order_qty * unit_cost, 2)
	
	    insert_query = f"""
	        INSERT INTO deliveries (shop_id, supplier_id, ingredient_id, delivery_day, quantity, total_cost)
	        VALUES ({target_shop_id}, {sup_id}, {ing_id}, CURRENT_DATE, {order_qty}, {total_cost});
	    """
	    plpy.execute(insert_query)
$$;

CALL auto_reorder_supplies(4);

DROP PROCEDURE IF EXISTS auto_reorder_supplies(INT);

-- 5. аллергены
CREATE OR REPLACE FUNCTION detect_allergens_in_recipe()
RETURNS TRIGGER
LANGUAGE plpython3u
AS $$
    menu_id = TD["new"]["menu_item_id"]
    ing_id = TD["new"]["ingredient_id"]

    res_drink = plpy.execute(f"SELECT name FROM menu_items WHERE menu_item_id = {menu_id}")
    drink_name = res_drink[0]["name"] if res_drink else "Неизвестный напиток"

    res_ing = plpy.execute(f"SELECT name FROM ingredients WHERE ingredient_id = {ing_id}")
    if not res_ing:
        return None
    
    ing_name = res_ing[0]["name"]
    name_lower = ing_name.lower()

    allergens = []
    if "молоко" in name_lower and not any(x in name_lower for x in ["овсян", "миндал", "кокос", "соев"]):
        allergens.append("Лактоза")
    if any(x in name_lower for x in ["орех", "миндал", "фундук", "фисташк"]):
        allergens.append("Орехи")
    if any(x in name_lower for x in ["выпечка", "круассан", "овсян"]):
        allergens.append("Глютен")

    if allergens:
        allergens_str = ", ".join(allergens)
        plpy.notice(f"Напиток '{drink_name}' содержит [{allergens_str}] из-за '{ing_name}'!")

    return None
$$;

CREATE TRIGGER trg_detect_allergens
AFTER INSERT OR UPDATE ON recipes
FOR EACH ROW
EXECUTE FUNCTION detect_allergens_in_recipe();

INSERT INTO recipes (menu_item_id, ingredient_id, amount_needed)
VALUES (1, (SELECT ingredient_id FROM ingredients WHERE name ILIKE '%орех%' LIMIT 1), 0.030)
ON CONFLICT (menu_item_id, ingredient_id) DO NOTHING;

DROP TRIGGER IF EXISTS trg_detect_allergens ON recipes;
DROP FUNCTION IF EXISTS detect_allergens_in_recipe();

-- 6. инфа по продукту

CREATE TYPE portion_info AS (
    size_val INT,
    unit_name VARCHAR(10),
    calories NUMERIC(6, 1),
    is_vegan BOOLEAN
);

CREATE OR REPLACE FUNCTION get_drink_nutrition(target_menu_item_id INT)
RETURNS portion_info
LANGUAGE plpython3u
AS $$
    res_item = plpy.execute(f"SELECT portion_size, unit, category FROM menu_items WHERE menu_item_id = {target_menu_item_id}")
    if not res_item:
        return None

    portion = res_item[0]['portion_size']
    unit = res_item[0]['unit']
    cat = res_item[0]['category']

    res_ing = plpy.execute(f"""
        SELECT i.name, i.category 
        FROM recipes r
        JOIN ingredients i ON r.ingredient_id = i.ingredient_id
        WHERE r.menu_item_id = {target_menu_item_id}
    """)

    is_vegan = True
    for ing in res_ing:
        ing_name = ing['name'].lower()
        if ing['category'] == 'Молочные продукты' or 'сливки' in ing_name or 'сыр' in ing_name:
            is_vegan = False
            break

    if not is_vegan:
        calories = round(portion * 0.65, 1)
    elif 'выпечка' in cat.lower():
        calories = round(portion * 3.4, 1)
    else:
        calories = round(portion * 0.05, 1)

    return {
        'size_val': portion,
        'unit_name': unit,
        'calories': calories,
        'is_vegan': is_vegan
    }
$$;

SELECT name AS "Позиция меню"
    , get_drink_nutrition(menu_item_id) AS "Энергетическая ценность"
FROM menu_items;

DROP FUNCTION IF EXISTS get_drink_nutrition(INT);
DROP TYPE IF EXISTS portion_info CASCADE;


CREATE OR REPLACE PROCEDURE reorder_for_menu(target_shop_id INT, target_menu_item_id INT)
LANGUAGE plpython3u
AS $$
    recipe = plpy.execute(f"""
        SELECT r.ingredient_id, r.amount_needed, i.cost_per_unit
        FROM recipes r
        JOIN ingredients i ON i.ingredient_id = r.ingredient_id
        WHERE r.menu_item_id = {target_menu_item_id}
    """)

    if len(recipe) == 0:
        return

    sup_id = plpy.execute("""
        SELECT supplier_id FROM suppliers
        WHERE rating IS NOT NULL
        ORDER BY rating DESC, min_order_price ASC
        LIMIT 1
    """)[0]['supplier_id']

    for ing in recipe:
        qty = float(ing['amount_needed'])
        cost = round(qty * float(ing['cost_per_unit']), 2)
        plpy.execute(f"""
            INSERT INTO deliveries (shop_id, supplier_id, ingredient_id, delivery_day, quantity, total_cost)
            VALUES ({target_shop_id}, {sup_id}, {ing['ingredient_id']}, CURRENT_DATE, {qty}, {cost})
        """)
$$;

-- ЗАЩИТА
-- функция для кофейен заданного города определять позиции не содерж кофеин и не содерж аллергены и для каждой такой кофейни в заданном городе найти топ 3 не дорогих позиции
-- 1. выбрать кофейни по городу, город извлекать из адреса
-- 2. у выбранных кофеен найти товары, в окторых нет кофеина и нет аллергенов (то есть по поставкам надо посчитать, что кофейня может продавать еще)
-- 		а) выбрать какие товары не содерж кофеина и аллергенов
-- 		б) посчитать, можем ли мы их продавать по поставкам ингредиентов в кофейню
-- 3. отсортировать найденные товары по цене и вывести топ 3


CREATE OR REPLACE FUNCTION get_top_3_decaf_menu_items_without_allergens_at_city(target_city VARCHAR)
RETURNS TABLE (
	res_shop_id INT
	, res_shop_address VARCHAR
	, res_menu_item_id INT
	, res_menu_item_name VARCHAR
	, res_menu_item_price NUMERIC(10, 2)
)
LANGUAGE plpython3u
AS $$
	#1 выбор кофеен по городу
	shops = plpy.execute(f"""
		SELECT shop_id
			, address	
		FROM coffee_shops
		WHERE address ILIKE '%{target_city},%'
			AND is_active = True
		ORDER BY shop_id
	""")

	if len(shops) == 0:
		plpy.notice(f"В городе {target_city} нет активных кофеен")
		return []

	# 2 а) собрать товары без кофеина и аллергенов, допустим, что у нас в чае нет кофеина
	# по кофеину не берем: Классический кофе, Авторский кофе, Холодный кофе
	# но проверка на 'Без кофеина'
	# на аллергены (допущение, чтобы не сойти с ума, что проверка только на орехи) не берем: кокос, миндал, фунду, пекан, фисташк

	items = plpy.execute(f"""
		SELECT menu_item_id
			, name
			, price
		FROM menu_items m
		WHERE is_available = True
			AND (name LIKE '%Без кофеина%'
				OR category NOT IN (
					'Классический кофе'
	        		, 'Авторский кофе'
	        		, 'Холодный кофе'
				))
			AND name NOT ILIKE '%кокос%'
			AND name NOT ILIKE '%миндал%'
			AND name NOT ILIKE '%фунду%'
			AND name NOT ILIKE '%пекан%'
			AND name NOT ILIKE '%фисташк%'
		ORDER BY price ASC
	""")

	if len(items) == 0:
		plpy.notice(f"Продуктов без кофеина и аллергена [орех] пока нет в продаже")
		return []

	# 2 б) проверка на возможность продажи в конкретной кофейне
	# берем первые 3, для каждой позиции лутаем рецепт и проверяем по доставкам достаточное ли кол-во ингредиентов в кофейне


	result = []
	for shop in shops:
		s_id = shop['shop_id']
		s_addr = shop['address']

		plpy.notice(f"Кофейня {s_id} по адресу: {s_addr}")
		
		taken = 0

		for item in items:
			i_id = item['menu_item_id']
			
			recipe = plpy.execute(f"""
				SELECT ingredient_id
					, amount_needed
				FROM recipes
				WHERE menu_item_id = {i_id}
			""")

			if len(recipe) == 0:
				continue

			can_cook = True

			for ing in recipe:
				ing_id = ing['ingredient_id']
				need = ing['amount_needed']
				
				shop_stock = plpy.execute(f"""
					SELECT COALESCE(SUM(quantity), 0) AS stock
					FROM deliveries
					WHERE shop_id = {s_id}
						AND ingredient_id = {ing_id}
				""")
				stock = float(shop_stock[0]['stock'])

				if stock < need:
					plpy.notice(f"Не оказалось достаточно ингредиента с айди {ing_id} для {i_id}")
					can_cook = False
					break
				
			if can_cook:
				plpy.notice(f"Может продать {i_id} по цене {item['price']}")
				if taken < 3:
					result.append({
						'res_shop_id': s_id
						, 'res_shop_address': s_addr
						, 'res_menu_item_id': i_id
						, 'res_menu_item_name': item['name']
						, 'res_menu_item_price': item['price']
					})
					taken += 1

	return result
$$;

SELECT * FROM get_top_3_decaf_menu_items_without_allergens_at_city('Москва');

CALL reorder_for_menu(770, 289);


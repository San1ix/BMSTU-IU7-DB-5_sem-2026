-- 1.1 подсчет маржи товара по айдишнику (розничная цена - себестоимость)

CREATE OR REPLACE FUNCTION get_item_margin(target_item_id INT)
RETURNS NUMERIC(10, 2) -- что возвращаем
LANGUAGE plpgsql
AS $$
DECLARE -- тут перечисляем переменные
	item_price NUMERIC(10, 2); -- цена товара
	item_cost NUMERIC(10, 2); -- себестоимость продукта
	margin NUMERIC(10, 2); -- результат
BEGIN
	SELECT price INTO item_price 
	FROM menu_items
	WHERE menu_item_id = target_item_id;

	SELECT ROUND(SUM(r.amount_needed * i.cost_per_unit), 2) INTO item_cost
	FROM recipes r
	JOIN ingredients i ON r.ingredient_id = i.ingredient_id
	WHERE r.menu_item_id = target_item_id;
	
	margin := item_price - COALESCE(item_cost, 0);

	RETURN margin;
END;
$$;

SELECT 
	menu_item_id
	, name AS "Позиция меню"
	, price AS "Розничная цена"
	, get_item_margin(menu_item_id) AS "Маржа"
FROM menu_items
LIMIT 10;

-- 1.2 таблица поставок конкретного филиала

CREATE OR REPLACE FUNCTION get_shop_deliveries(target_shop_id INT, start_date DATE, end_date DATE)
RETURNS TABLE (
	out_delivery_id INT
	, out_ingredient_name VARCHAR
	, out_delivery_day DATE
	, out_quantity NUMERIC(10, 2)
	, out_total_cost NUMERIC(10, 2)
)
LANGUAGE sql
AS $$
	SELECT d.delivery_id
		, i.name
		, d.delivery_day
		, d.quantity
		, d.total_cost
	FROM deliveries d
	JOIN ingredients i on d.ingredient_id = i.ingredient_id
	WHERE d.shop_id = target_shop_id AND d.delivery_day BETWEEN start_date AND end_date;
$$;

SELECT *
FROM get_shop_deliveries(285, '2020-01-01', '2026-01-01')
ORDER BY out_delivery_day DESC;

-- 1.3 в какую копеечку нам обходятся точки
CREATE OR REPLACE FUNCTION get_shops_financial_summary()
RETURNS TABLE (
    out_shop_id INT,
    out_address VARCHAR,
    out_payroll NUMERIC(10, 2),
    out_delivery_cost NUMERIC(12, 2),
    out_status VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE 
	r_shop RECORD;
BEGIN
	FOR r_shop IN SELECT shop_id, address, is_active FROM coffee_shops ORDER BY shop_id LOOP
		SELECT COALESCE(SUM(salary), 0) INTO out_payroll
		FROM employees
		WHERE shop_id = r_shop.shop_id;

		SELECT COALESCE(SUM(total_cost), 0) INTO out_delivery_cost 
		FROM deliveries 
		WHERE shop_id = r_shop.shop_id;


		out_shop_id := r_shop.shop_id;
        out_address := r_shop.address;

		IF NOT r_shop.is_active THEN
		    out_status := 'Закрыта / На ремонте';
		ELSE
		    IF (out_payroll + out_delivery_cost) = 0 THEN
		        out_status := 'Открыта, но нет активности';
		    ELSIF (out_payroll + out_delivery_cost) > 100000.00 THEN
		        out_status := 'Большие расходы';
		    ELSE
		        out_status := 'В пределах нормы';
		    END IF;
		END IF;

		RETURN NEXT;
	END LOOP;
END;
$$;

SELECT * 
FROM get_shops_financial_summary();

-- 1.4 персонал 
CREATE OR REPLACE FUNCTION get_career_hierarchy()
RETURNS TABLE (
	out_level INT
	, out_position VARCHAR
	, out_staff_count BIGINT
	, out_avg_salary NUMERIC(10, 2)
)
LANGUAGE plpgsql
AS $$
BEGIN
	RETURN QUERY
	WITH RECURSIVE career_ladder (level, position, next_position) AS (
		SELECT 1 AS level
			, 'Управляющий филиала'::VARCHAR AS position
            , 'Заместитель управляющего'::VARCHAR AS next_position
		UNION ALL
		SELECT cl.level + 1
			, cl.next_position
			, CASE cl.next_position 
				WHEN 'Заместитель управляющего' THEN 'Шеф-бариста'::VARCHAR
                WHEN 'Шеф-бариста' THEN 'Старший бариста'::VARCHAR
                WHEN 'Старший бариста' THEN 'Бариста'::VARCHAR
                WHEN 'Бариста' THEN 'Младший бариста'::VARCHAR
                WHEN 'Младший бариста' THEN 'Стажер'::VARCHAR
                ELSE NULL 
			END
		FROM career_ladder cl
		WHERE cl.next_position IS NOT NULL
	)

	SELECT cl.level
		, cl.position 
		, COUNT(e.employee_id) AS staff_count
		, ROUND(AVG(e.salary), 2) AS avg_salary
	FROM career_ladder cl
	LEFT JOIN employees e ON cl.position = e.position
	GROUP BY cl.level, cl.position
	ORDER BY cl.level;
END;
$$;

SELECT * 
FROM get_career_hierarchy();

-- 2.1 Меняем меню под сезон
CREATE OR REPLACE PROCEDURE switch_seasonal_menu(new_season VARCHAR)
LANGUAGE plpgsql
AS $$
BEGIN
	UPDATE menu_items
	SET is_available = false
	WHERE category = 'Сезонные новинки';

	UPDATE menu_items
	SET is_available = true
	WHERE category = 'Сезонные новинки' 
		AND name LIKE '%[' || new_season || ']%';

	RAISE NOTICE 'Сезонное меню успешно обновлено на сезон: %', new_season;
END;
$$;

CALL switch_seasonal_menu('Зима');
CALL switch_seasonal_menu('Весна');
CALL switch_seasonal_menu('Лето');
CALL switch_seasonal_menu('Осень');

-- 2.2 всем премии
CREATE OR REPLACE PROCEDURE award_cascade_bonus(level INT, bonus NUMERIC(10, 2))
LANGUAGE plpgsql
AS $$
DECLARE 
	l_position VARCHAR;
BEGIN
	l_position := CASE level
		WHEN 1 THEN 'Управляющий филиала'
        WHEN 2 THEN 'Старший бариста'
        WHEN 3 THEN 'Бариста'
        WHEN 4 THEN 'Стажер'
        ELSE NULL
	END;

	IF l_position IS NOT NULL THEN
		UPDATE employees
		SET salary = salary + bonus 
		WHERE position = l_position;
		RAISE NOTICE 'Уровень % (%): начислена премия % руб.', level, l_position, bonus;
	END IF;

	IF level < 4 THEN
		CALL award_cascade_bonus(level + 1, ROUND(bonus * 0.70, 2));
	END IF;
END;
$$;

CALL award_cascade_bonus(1, 10000.00);

-- 2.3 - плановые повышения барист по стажу больше 2 лет, надбавка к зараплате
CREATE OR REPLACE PROCEDURE promote_experienced_baristas(target_shop_id INT)
LANGUAGE plpgsql
AS $$
DECLARE 
	cur_baristas CURSOR FOR
		SELECT	employee_id
			, full_name
			, salary
		FROM employees
		WHERE shop_id = target_shop_id
			AND position = 'Бариста'
			AND hire_date <= CURRENT_DATE - INTERVAL '2 years';

	e_id INT;
	e_name VARCHAR;
	e_salary NUMERIC(10, 2);
	e_count INT := 0;
BEGIN
	OPEN cur_baristas;

	LOOP
		FETCH cur_baristas INTO e_id, e_name, e_salary;
		EXIT WHEN NOT FOUND;

		UPDATE employees
		SET position = 'Старший бариста'
		WHERE employee_id = e_id;
		
		e_count := e_count + 1;
		RAISE NOTICE 'Повышен: % (Новый оклад: % руб.)', e_name, e_salary + 5000.00;
	END LOOP;

	CLOSE cur_baristas;
	RAISE NOTICE 'Итого повышено сотрудников: %', e_count;
END;
$$;

CALL promote_experienced_baristas(764);

-- 2.4 - список таблиц в схеме
CREATE OR REPLACE PROCEDURE show_db_metadata(target_schema VARCHAR)
LANGUAGE plpgsql
AS $$
DECLARE
	r RECORD;
BEGIN
	FOR r IN
		SELECT table_name 
		FROM information_schema.tables
		WHERE table_schema = target_schema
			AND table_type = 'BASE TABLE'
		ORDER BY table_name
	LOOP
		RAISE NOTICE 'Таблица: %', r.table_name;
	END LOOP;
END;
$$;

CALL  show_db_metadata('public');

-- 3.1
CREATE TABLE IF NOT EXISTS employees_archive (
	archive_id SERIAL PRIMARY KEY
	, operation VARCHAR(10)
	, employee_id INT
	, old_salary NUMERIC(10, 2)
	, changed_at TIMESTAMP DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION trg_audit_employees()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
	INSERT INTO employees_archive(operation, employee_id, old_salary)
	VALUES (TG_OP, OLD.employee_id, OLD.salary);
	RETURN OLD;
END;
$$;

CREATE TRIGGER after_employees_audit
AFTER UPDATE OR DELETE ON employees
FOR EACH ROW
EXECUTE FUNCTION trg_audit_employees();

UPDATE employees 
SET salary = salary + 1000 
WHERE employee_id = 3;

DELETE FROM employees 
WHERE employee_id = 2;

SELECT * 
FROM employees_archive;

-- 3.2
CREATE OR REPLACE VIEW v_menu_items AS
SELECT menu_item_id
	, name
	, price
	, is_available
FROM menu_items;

CREATE OR REPLACE FUNCTION trg_soft_delete_menu_item()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
BEGIN
	UPDATE menu_items
	SET is_available = false
	WHERE menu_item_id = OLD.menu_item_id;

	RETURN OLD;
END;
$$;

CREATE TRIGGER instead_of_delete_menu_item
INSTEAD OF DELETE ON v_menu_items
FOR EACH ROW
EXECUTE FUNCTION trg_soft_delete_menu_item();

SELECT * FROM v_menu_items 
WHERE menu_item_id = 1;

DELETE FROM v_menu_items 
WHERE menu_item_id = 1;

SELECT menu_item_id
	, name
	, is_available
FROM menu_items 
WHERE menu_item_id = 1;

UPDATE menu_items
SET is_available = TRUE
WHERE menu_item_id = 1;

-- дропы
DROP FUNCTION IF EXISTS get_item_margin(INT);
DROP FUNCTION IF EXISTS get_shop_deliveries(INT, DATE, DATE);
DROP FUNCTION IF EXISTS get_shops_financial_summary();
DROP FUNCTION IF EXISTS get_career_hierarchy();

DROP PROCEDURE IF EXISTS switch_seasonal_menu(VARCHAR);
DROP PROCEDURE IF EXISTS award_cascade_bonus(INT, NUMERIC);
DROP PROCEDURE IF EXISTS promote_experienced_baristas(INT);
DROP PROCEDURE IF EXISTS show_db_metadata(VARCHAR);

DROP TRIGGER IF EXISTS after_employees_audit ON employees;
DROP FUNCTION IF EXISTS trg_audit_employees();
DROP TABLE IF EXISTS employees_archive;

DROP TRIGGER IF EXISTS instead_of_delete_menu_item ON v_menu_items;
DROP FUNCTION IF EXISTS trg_soft_delete_menu_item();
DROP VIEW IF EXISTS v_menu_items;

-- ЗАЩИТА
-- ф-я кот принимает время в часах, от заданного времени до окончания работы кофеен проверять какие точки работают и при этом в точках есть в наличие ингрeдиент

CREATE OR REPLACE FUNCTION get_opened_shops_with_ingredient(target_hour INT, target_ingredient_id INT)
RETURNS TABLE (
	r_shop_id INT
	, r_closing_time TIME
	, r_address VARCHAR
	, r_quantity NUMERIC(10, 2)
)
LANGUAGE plpgsql
AS $$
BEGIN
	RETURN QUERY
	SELECT s.shop_id
		, s.closing_time
		, s.address
		, SUM(d.quantity) AS total_quantity
	FROM coffee_shops s
	JOIN deliveries d ON s.shop_id = d.shop_id
	WHERE d.ingredient_id = target_ingredient_id
		AND s.is_active = true
		AND target_hour BETWEEN EXTRACT(HOUR FROM s.opening_time) 
							AND EXTRACT(HOUR FROM s.closing_time)
	GROUP BY s.shop_id, s.address, s.closing_time
	HAVING SUM(d.quantity) > 0
	ORDER BY s.closing_time;
END;
$$;

SELECT * FROM get_opened_shops_with_ingredient(22, 23);

DROP FUNCTION IF EXISTS get_opened_shops_with_ingredient(INT, INT);

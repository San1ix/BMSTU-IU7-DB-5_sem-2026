-- миу миу миу миу ня ня ня ня ня тын тырын тын тын тын 
-- 9151901517

-- 1. найти сотрудников-сменщиков бариста из одного магазина

SELECT DISTINCT 
    e1.shop_id AS "ID кофейни",
    e1.full_name AS "Сотрудник 1",
    e2.full_name AS "Сотрудник 2",
    e1.position AS "Должность"
FROM employees e1
JOIN employees e2 ON e1.shop_id = e2.shop_id
WHERE e1.employee_id <> e2.employee_id 
    AND e1.position = e2.position
    AND e1.position = 'Бариста'
ORDER BY e1.shop_id;

-- 2. получить список поставок за лето 24 года
SELECT * FROM deliveries
WHERE delivery_day BETWEEN '2024-06-01' AND '2024-08-31'
ORDER BY delivery_day ASC;

-- 3. ищем капучино
SELECT * FROM menu_items
WHERE name LIKE '%Капучино%'
ORDER BY name ASC;

-- 4. собрать продукты для свежей выпечки
SELECT * FROM recipes
WHERE menu_item_id IN (
    SELECT menu_item_id FROM menu_items
    WHERE category = 'Свежая выпечка'
)
ORDER BY menu_item_id ASC;

-- 5. список поставок, которые делали доставщики без рейтинга
SELECT * FROM deliveries d
WHERE EXISTS (
    SELECT 1 FROM suppliers s
    WHERE d.supplier_id = s.supplier_id 
      AND s.rating IS NULL
)
ORDER BY delivery_day DESC;

-- 6. найти сезонные новинки, которые дороже чем товары из категории классического кофе
SELECT * FROM menu_items
WHERE category = 'Сезонные новинки'
AND price > ALL (
    SELECT price FROM menu_items
    WHERE category = 'Классический кофе'
)
ORDER BY price DESC;

-- 7. средние траты кофейни на поставки
SELECT
    ROUND(AVG(shop_total_cost), 2) AS "Средний расход точки"
FROM (
    SELECT 
        shop_id,
        SUM(total_cost) AS shop_total_cost
    FROM deliveries
    GROUP BY shop_id
) AS shop_expenses;

-- 8. ср и макс чек поставок в лаундж кофейни
SELECT 
    shop_id,
    address,
    format,
    (
        SELECT ROUND(AVG(total_cost), 2) 
        FROM deliveries d 
        WHERE d.shop_id = cs.shop_id
    ) AS avg_check,
    (
		SELECT MAX(total_cost) 
        FROM deliveries d 
        WHERE d.shop_id = cs.shop_id
    ) AS max_check
FROM coffee_shops cs
WHERE format = 'Lounge'
ORDER BY shop_id;

-- 9. на человеческий
SELECT 
    shop_id,
    address,
    format,
    CASE format 
        WHEN 'To-Go' THEN 'Кофе с собой, без посадки'
        WHEN 'Island' THEN 'Островок в ТЦ'
        WHEN 'Base' THEN 'Стандартная кофейня'
        ELSE 'С зоной на улице'
    END AS "Описание формата"
FROM coffee_shops;
    

-- 10. рейтинговая табличка поставщиков от Олега Тинькова
SELECT
    supplier_id,
    company_name,
    rating,
    CASE 
        WHEN rating > 4.50 THEN 'Так это ж круто'
        WHEN rating > 3.00 THEN 'Сомнительно... но ОКЭЙ'
        WHEN rating IS NULL THEN 'Я это не понимаю, мне это не интересно'
        ELSE 'Не могу осуждать... хотя осуждаю'
    ENd AS "Рекомендация"
FROM suppliers;

-- 11. считаем сумму поставок конкретного ингредиента
SELECT 
    ingredient_id,
    SUM(quantity) AS total_quantity,
    ROUND(SUM(total_cost), 2) AS total_spent
INTO TEMP TABLE temp_ingredient_totals
FROM deliveries
WHERE ingredient_id IS NOT NULL
GROUP BY ingredient_id;

SELECT * 
FROM temp_ingredient_totals
LIMIT 10;

DROP TABLE IF EXISTS temp_ingredient_totals;

-- 12. лучший по деньгам и по доставкам
SELECT 
    'По объему поставок' AS "Номинация", 
    s.company_name AS "Поставщик", 
    top_qty.val AS "Показатель"
FROM suppliers s
JOIN (
    SELECT 
        supplier_id, 
        SUM(quantity) AS val
    FROM deliveries
    GROUP BY supplier_id
    ORDER BY val DESC
    LIMIT 1
) AS top_qty ON s.supplier_id = top_qty.supplier_id
UNION
SELECT 
    'По сумме выплат' AS "Номинация", 
    s.company_name AS "Поставщик", 
    top_cost.val AS "Показатель"
FROM suppliers s
JOIN (
    SELECT supplier_id, SUM(total_cost) AS val
    FROM deliveries
    GROUP BY supplier_id
    ORDER BY val DESC
    LIMIT 1
) AS top_cost ON s.supplier_id = top_cost.supplier_id;

-- 13. кофейня, принявшая рекордный объем поставок
SELECT 
    shop_id, 
    address, 
    format
FROM coffee_shops
WHERE shop_id = (
    SELECT shop_id
    FROM deliveries
    GROUP BY shop_id
    HAVING SUM(quantity) = (
        SELECT MAX(total_qty)
        FROM (
            SELECT SUM(quantity) AS total_qty
            FROM deliveries
            GROUP BY shop_id
        ) AS sub_totals
    )
    LIMIT 1
);

-- 14. итоговая сводка поставок сорта зернового кофе
SELECT 
    i.ingredient_id,
    i.name,
    i.cost_per_unit,
    ROUND(AVG(d.total_cost), 2) AS avg_check,
    SUM(d.quantity) AS total
FROM ingredients i
JOIN deliveries d ON i.ingredient_id = d.ingredient_id
WHERE i.category = 'Зерновой кофе'
GROUP BY i.ingredient_id, i.name, i.cost_per_unit
ORDER BY total DESC;

-- 15. средняя цена выше категории выше средней цены всего
SELECT 
    category,
    ROUND(AVG(cost_per_unit), 2) AS avg_price
FROM ingredients
GROUP BY category
HAVING AVG(cost_per_unit) > (
    SELECT AVG(cost_per_unit) 
    FROM ingredients
)
ORDER BY avg_price DESC;

-- 16. Шеф-бариста придумал новый сезонный рецепт
INSERT INTO menu_items(category, name, unit, portion_size, price, is_available)
VALUES ('Авторский кофе', 'Капучино Медовик с сырной пенкой на Фундучном', 'мл', 400, 320.00, true);

-- 17. добавление упаковки в рецепты холодных напитков
INSERT INTO recipes (menu_item_id, ingredient_id, amount_needed)
SELECT 
    m.menu_item_id,
    (SELECT MIN(ingredient_id) FROM ingredients WHERE category = 'Пищевая упаковка'),
    1.000
FROM menu_items m
WHERE m.category = 'Холодный кофе'
ON CONFLICT (menu_item_id, ingredient_id) DO NOTHING;

-- 18. инфляция на ледик
UPDATE menu_items
SET price = ROUND(price * 1.5, 2)
WHERE name LIKE 'Айс%';

-- 19.обновляем стоимость ингридиента по средней цене из поставок
UPDATE ingredients
SET cost_per_unit = (
    SELECT ROUND(AVG(total_cost / quantity), 2)
    FROM deliveries
    WHERE ingredient_id = 1
)
WHERE ingredient_id = 1;

-- 20. удаляем недоступные позиции
DELETE FROM menu_items
WHERE is_available = false;

-- 21. удаление неиспользуемых расходников
DELETE FROM ingredients
WHERE ingredient_id IN (
    SELECT i.ingredient_id
    FROM ingredients i
    LEFT JOIN deliveries d ON i.ingredient_id = d.ingredient_id
    WHERE d.ingredient_id IS NULL
    AND i.category = 'Хозяйственные расходники'
);

-- 22.
WITH supplier_shipments (supplier_id, total_orders) AS (
    SELECT 
        supplier_id, 
        COUNT(*) AS total_orders
    FROM deliveries
    WHERE supplier_id IS NOT NULL
    GROUP BY supplier_id
)
SELECT 
    ROUND(AVG(total_orders), 2) AS avg_orders
FROM supplier_shipments;

-- 23. дерево подчинения сотрудников
WITH RECURSIVE career_ladder (level, position, next_position) AS (
    SELECT
        1 AS level,
        'Управляющий филиала'::VARCHAR AS position,
        'Заместитель управляющего'::VARCHAR AS next_position
    UNION ALL
    SELECT 
        cl.level + 1,
        cl.next_position,
        CASE cl.next_position
            WHEN 'Заместитель управляющего' THEN 'Шеф-бариста'::VARCHAR
            WHEN 'Шеф-бариста'            THEN 'Старший бариста'::VARCHAR
            WHEN 'Старший бариста'         THEN 'Бариста'::VARCHAR
            WHEN 'Бариста'                 THEN 'Младший бариста'::VARCHAR
            WHEN 'Младший бариста'         THEN 'Стажер'::VARCHAR
            ELSE NULL
        END
    FROM career_ladder cl
    WHERE cl.next_position IS NOT NULL
)
SELECT 
    cl.level,
    cl.position,
    COUNT(e.employee_id) AS total_employees,
    ROUND(AVG(e.salary), 2) AS avg_salary
FROM career_ladder cl
LEFT JOIN employees e ON cl.position = e.position
GROUP BY cl.level, cl.position
ORDER BY cl.level;

-- 24. ср, мин, макс цена по категориям
SELECT
    name, 
    category,
    price,
    ROUND(AVG(price) OVER(PARTITION BY category), 2) AS avg_price,
    MIN(price) OVER(PARTITION BY category) AS min_price,
    MAX(price) OVER(PARTITION BY category) AS max_price
FROM menu_items
ORDER BY category, price;

-- 25. убрать дубли (формат, активность)
WITH ranked_formats AS (
    SELECT
        format, 
        is_active,
        ROW_NUMBER() OVER(PARTITION BY format, is_active ORDER BY format) AS rn
    FROM coffee_shops
)
SELECT format, is_active
FROM ranked_formats
WHERE rn = 1;


-- ЗАЩИТА
-- вывести лучшего управляющего по тому, насколько много деняжек он потратил на доставки за все время
select
	e.full_name as "управляющий",
	cs.address as "адрес точки",
	round(sum(d.total_cost), 2) as "всего уплочено"
from employees e 
join coffee_shops cs on e.shop_id = cs.shop_id 
join deliveries d ON d.shop_id = cs.shop_id
where e.position = 'Управляющий филиала'
group by e.employee_id, e.full_name, cs.address
order by "всего уплочено" desc;
-- limit 1;

	
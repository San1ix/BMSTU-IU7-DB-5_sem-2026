COPY coffee_shops (format, address, opening_time, closing_time, is_active)
FROM '/home/sanlix/BD/lab_01/data/coffee_shops.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

COPY employees (shop_id, full_name, contact_phone, position, salary, hire_date)
FROM '/home/sanlix/BD/lab_01/data/employees.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

COPY suppliers (company_name, contact_phone, delivery_days, min_order_price, rating)
FROM '/home/sanlix/BD/lab_01/data/suppliers.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

COPY ingredients (category, name, unit, shelf_life_days, storage_condition, min_stock_level,cost_per_unit )
FROM '/home/sanlix/BD/lab_01/data/ingredients.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

COPY menu_items (category, name, unit, portion_size, price, is_available)
FROM '/home/sanlix/BD/lab_01/data/menu_items.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

COPY deliveries (shop_id, supplier_id, ingredient_id, delivery_day, quantity, total_cost)
FROM '/home/sanlix/BD/lab_01/data/deliveries.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

COPY recipes (menu_item_id, ingredient_id, amount_needed)
FROM '/home/sanlix/BD/lab_01/data/recipes.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');
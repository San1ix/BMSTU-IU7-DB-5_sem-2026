--CREATE DATABASE coffee_shop_db;

CREATE TABLE "public"."coffee_shops" (
    shop_id SERIAL,
    format VARCHAR(150),
    address VARCHAR(200),
    opening_time TIME,
    closing_time TIME,
    is_active BOOLEAN
);

CREATE TABLE "public"."employees" (
    employee_id SERIAL,
    shop_id INT,
    full_name VARCHAR(150),
    contact_phone VARCHAR(20),
    position VARCHAR(50),
    salary NUMERIC(10, 2),
    hire_date DATE
);

CREATE TABLE "public"."suppliers" (
    supplier_id SERIAL,
    company_name VARCHAR(100),
    contact_phone VARCHAR(20),
    delivery_days INT,
    min_order_price NUMERIC(10, 2),
    rating NUMERIC(3, 2)
);

CREATE TABLE "public"."ingredients" (
    ingredient_id SERIAL,
    category VARCHAR(50),
    name VARCHAR(100),
    unit VARCHAR(20),
    shelf_life_days INT,
    storage_condition VARCHAR(100),
    min_stock_level NUMERIC(10, 2),
    cost_per_unit NUMERIC(10, 2)
);

CREATE TABLE "public"."menu_items" (
    menu_item_id SERIAL,
    category VARCHAR(50),
    name VARCHAR(100),
    unit VARCHAR(20),
    portion_size INT,
    price NUMERIC(10, 2),
    is_available BOOLEAN
);

CREATE TABLE "public"."deliveries" (
    delivery_id SERIAL,
    shop_id INT,
    supplier_id INT,
    ingredient_id INT,
    delivery_day DATE,
    quantity NUMERIC(10, 2),
    total_cost NUMERIC(10, 2)
);

CREATE TABLE "public"."recipes" (
    menu_item_id INT,
    ingredient_id INT,
    amount_needed NUMERIC(10, 3)
);
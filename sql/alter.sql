ALTER TABLE "public"."coffee_shops"
    ADD CONSTRAINT pk_coffee_shops 
    PRIMARY KEY (shop_id);

ALTER TABLE "public"."coffee_shops"
    ADD CONSTRAINT chk_coffee_shops_format 
    CHECK (format in (
        'To-Go',
        'Island',
        'Base',
        'Lounge'
    ));

ALTER TABLE "public"."coffee_shops"
    ADD CONSTRAINT uq_coffee_shops_address 
    UNIQUE (address);

ALTER TABLE "public"."coffee_shops"
    ADD CONSTRAINT chk_coffee_shops_working_hours 
    CHECK (closing_time > opening_time);

ALTER TABLE "public"."coffee_shops"
    ADD CONSTRAINT nn_coffee_shops_is_active
    NOT NULL is_active;

--

ALTER TABLE "public"."employees"
    ADD CONSTRAINT pk_employees 
    PRIMARY KEY (employee_id);

ALTER TABLE "public"."employees"
    ADD CONSTRAINT fk_employees_shop_id
    FOREIGN KEY (shop_id) 
    REFERENCES "public"."coffee_shops"(shop_id)
    ON UPDATE CASCADE; 

ALTER TABLE "public"."employees"
    ADD CONSTRAINT uq_employees_contact_phone 
    UNIQUE (contact_phone);

ALTER TABLE "public"."employees"
    ADD CONSTRAINT chk_employees_position 
    CHECK (position IN (
        'Стажер',
        'Младший бариста',
        'Бариста',
        'Старший бариста',
        'Шеф-бариста',
        'Бариста-кассир',
        'Заместитель управляющего',
        'Управляющий филиала',
        'Сервисный техник',
        'Кладовщик'
    ));

ALTER TABLE "public"."employees"
    ADD CONSTRAINT chk_employees_salary 
    CHECK (salary >= 15000.00);

ALTER TABLE "public"."employees"
    ADD CONSTRAINT chk_employees_hire_date 
    CHECK (hire_date >= '2000-01-01');

--

ALTER TABLE "public"."suppliers"
    ADD CONSTRAINT pk_suppliers 
    PRIMARY KEY (supplier_id);

ALTER TABLE "public"."suppliers"
    ADD CONSTRAINT uk_suppliers_contact_phone
    UNIQUE (contact_phone);

ALTER TABLE "public"."suppliers"
    ADD CONSTRAINT chk_suppliers_delivery_days
    CHECK (delivery_days >= 0);

ALTER TABLE "public"."suppliers"
    ADD CONSTRAINT chk_suppliers_min_order_price
    CHECK (min_order_price > 0);

ALTER TABLE "public"."suppliers"
    ADD CONSTRAINT chk_suppliers_rating
    CHECK (rating BETWEEN 1.00 AND 5.00);

--

ALTER TABLE "public"."ingredients"
    ADD CONSTRAINT pk_ingredients 
    PRIMARY KEY (ingredient_id);

ALTER TABLE "public"."ingredients"
    ADD CONSTRAINT chk_ingredients_category
    CHECK (category in (
        'Зерновой кофе',
        'Молочные продукты',
        'Растительное молоко',
        'Чай',
        'Сиропы и топпинги',
        'Какао и шоколад',
        'Выпечка и заморозка',
        'Пищевая упаковка',
        'Хозяйственные расходники'
    ));

ALTER TABLE "public"."ingredients"
    ADD CONSTRAINT chk_ingredients_unit
    CHECK (unit in (
        'кг',
        'л',
        'шт',
        'г',
        'мл'
    ));

ALTER TABLE "public"."ingredients"
    ADD CONSTRAINT chk_ingredients_shelf_life_days
    CHECK (shelf_life_days > 0);

ALTER TABLE "public"."ingredients"
    ADD CONSTRAINT chk_ingredients_min_stock_level
    CHECK (min_stock_level >= 0);

ALTER TABLE "public"."ingredients"
    ADD CONSTRAINT chk_ingredients_cost_per_unit
    CHECK (cost_per_unit > 0);

--

ALTER TABLE "public"."menu_items"
    ADD CONSTRAINT pk_menu_items 
    PRIMARY KEY (menu_item_id);

ALTER TABLE "public"."menu_items"
    ADD CONSTRAINT chk_menu_items_category
    CHECK (category in (
        'Классический кофе',
        'Авторский кофе',
        'Холодный кофе',
        'Сезонные новинки',
        'Чай и матча',
        'Лимонады и фреши',
        'Свежая выпечка'
    ));

ALTER TABLE "public"."menu_items"
    ADD CONSTRAINT uq_menu_items_name_portion
    UNIQUE (name, unit, portion_size);

ALTER TABLE "public"."menu_items"
    ADD CONSTRAINT chk_menu_items_portion_size
    CHECK (portion_size > 0);

ALTER TABLE "public"."menu_items"
    ADD CONSTRAINT chk_menu_items_price
    CHECK (price > 0);

ALTER TABLE "public"."menu_items"
    ADD CONSTRAINT nn_menu_items_is_available
    NOT NULL is_available;

--

ALTER TABLE "public"."deliveries"
    ADD CONSTRAINT pk_deliveries 
    PRIMARY KEY (delivery_id);

ALTER TABLE "public"."deliveries"
    ADD CONSTRAINT fk_deliveries_shop_id
    FOREIGN KEY (shop_id)
    REFERENCES "public"."coffee_shops"(shop_id)
    ON UPDATE CASCADE;

ALTER TABLE "public"."deliveries"
    ADD CONSTRAINT fk_deliveries_supplier_id
    FOREIGN KEY (supplier_id)
    REFERENCES "public"."suppliers"(supplier_id)
    ON UPDATE CASCADE;

ALTER TABLE "public"."deliveries"
    ADD CONSTRAINT fk_deliveries_ingredient_id
    FOREIGN KEY (ingredient_id)
    REFERENCES "public"."ingredients"(ingredient_id)
    ON UPDATE CASCADE;

ALTER TABLE "public"."deliveries"
    ADD CONSTRAINT chk_deliveries_delivery_day
    CHECK (delivery_day >= '2000-01-01');

ALTER TABLE "public"."deliveries"
    ADD CONSTRAINT chk_deliveries_quantity
    CHECK (quantity > 0);

ALTER TABLE "public"."deliveries"
    ADD CONSTRAINT chk_deliveries_total_cost
    CHECK (total_cost > 0);

--

ALTER TABLE "public"."recipes"
    ADD CONSTRAINT pk_recipes 
    PRIMARY KEY (menu_item_id, ingredient_id);

ALTER TABLE "public"."recipes"
    ADD CONSTRAINT fk_recipes_menu_item_id
    FOREIGN KEY (menu_item_id)
    REFERENCES "public"."menu_items"(menu_item_id)
    ON UPDATE CASCADE;

ALTER TABLE "public"."recipes"
    ADD CONSTRAINT fk_recipes_ingredient_id
    FOREIGN KEY (ingredient_id)
    REFERENCES "public"."ingredients"(ingredient_id)
    ON UPDATE cascade on delete set null;

ALTER TABLE "public"."recipes"
    ADD CONSTRAINT chk_recipes_amount_needed
    CHECK (amount_needed > 0);
import json
import csv
import random
from datetime import date
from faker import Faker

fake = Faker('ru_RU');

with open('scripts/config.json', 'r', encoding = 'utf-8') as file:
    CONFIG = json.load(file)

VOLUMES = CONFIG['volumes']
NUM_SHOPS = VOLUMES['num_shops']
NUM_EMPLOYEES = VOLUMES['num_employees']
NUM_SUPPLIERS = VOLUMES['num_suppliers']
NUM_INGREDIENTS = VOLUMES['num_ingredients']
NUM_MENU_ITEMS = VOLUMES['num_menu_items']
NUM_DELIVERIES = VOLUMES['num_deliveries']
NUM_RECIPES = VOLUMES['num_recipes']

def generate_coffee_shops():
    formats = CONFIG['shops']['formats']
    used_addresses = set()
    
    with open('data/coffee_shops.csv', 'w', newline = '', encoding = 'utf-8') as file:
        writer = csv.writer(file)

        writer.writerow(['format', 'address', 'opening_time', 'closing_time', 'is_active'])

        while len(used_addresses) < NUM_SHOPS:
            addr = fake.address().replace('\n', ', ')
            
            if addr in used_addresses:
                continue

            used_addresses.add(addr)

            shop_format = random.choice(formats)

            open_hour = random.randint(6, 10)
            opening_time = f"{open_hour:02d}:00:00"

            close_hour = random.randint(19, 23)
            closing_time = f"{close_hour:02d}:00:00"

            is_active = 'true' if random.random() < 0.9 else 'false'

            writer.writerow([shop_format, addr, opening_time, closing_time, is_active])

    print(f"Генерация кофеен закончена, создано {NUM_SHOPS} записей.")


def generate_employees():
    positions = CONFIG['employees']['positions']
    used_phones = set()

    with open('data/employees.csv','w', newline = '', encoding = 'utf-8') as file:
        writer = csv.writer(file)

        writer.writerow(['shop_id', 'full_name', 'contact_phone', 'position', 'salary', 'hire_date'])

        while len(used_phones) < NUM_EMPLOYEES:

            phone = f"+79{random.randint(100000000, 999999999)}"

            if phone in used_phones:
                continue

            used_phones.add(phone)

            shop_id = random.randint(1, NUM_SHOPS)

            if random.random() < 0.5:
                full_name = f"{fake.last_name_male()} {fake.first_name_male()} {fake.middle_name_male()}"
            else:
                full_name = f"{fake.last_name_female()} {fake.first_name_female()} {fake.middle_name_female()}"

            position = random.choice(positions)

            if position == 'Стажер':
                salary = round(random.uniform(15000.00, 30000.00), 2)
            elif position == 'Управляющий филиала':
                salary = round(random.uniform(60000.00, 95000.00), 2)
            else:
                salary = round(random.uniform(35000.00, 60000.00), 2)

            hire_date = fake.date_between(start_date = date(2000, 1, 1), end_date = date.today())

            writer.writerow([shop_id, full_name, phone, position, salary, hire_date])

    print(f"Генерация сотрудников закончена, создано {NUM_EMPLOYEES} записей.")


def generate_suppliers():
    cfg = CONFIG['suppliers']
    used_phones = set()
    supplier_weights = {}

    with open('data/suppliers.csv', 'w', newline = '', encoding = 'utf-8') as file:
        writer = csv.writer(file)

        writer.writerow(['company_name', 'contact_phone', 'delivery_days', 'min_order_price', 'rating'])

        while len(used_phones) < NUM_SUPPLIERS:
            phone = f"+71{random.randint(100000000, 999999999)}"

            if phone in used_phones:
                continue

            used_phones.add(phone)

            supplier_id = len(used_phones)

            company_name = f"{fake.company()}"

            delivery_days = random.randint(cfg['min_delivery_days'], cfg['max_delivery_days'])

            min_order_price = round(random.uniform(1000.00, 50000.00), 2)

            if random.random() > 0.10:
                rating_val = round(random.uniform(cfg['min_rating'], cfg['max_rating']), 2)
                rating = str(rating_val)
                weight = rating_val ** 2
            else:
                rating = ''
                weight = 2.5 * 2

            supplier_weights[supplier_id] = weight
            writer.writerow([company_name, phone, delivery_days, min_order_price, rating])

    print(f"Генерация поставщиков закончена, создано {NUM_SUPPLIERS} записей.")
    return supplier_weights


def generate_ingredients():
    cfg = CONFIG['ingredients']
    categories = cfg['categories']
    rules = cfg['rules']
    sample_names = cfg['sample_names']

    ingredients_by_category = {category: [] for category in categories}

    with open('data/ingredients.csv', 'w', newline = '', encoding = 'utf-8') as file:
        writer = csv.writer(file)

        writer.writerow(['category', 'name', 'unit', 'shelf_life_days', 'storage_condition', 'min_stock_level', 'cost_per_unit'])

        for i in range (1, NUM_INGREDIENTS + 1):
            category = random.choice(categories)
            ingredients_by_category[category].append(i)

            base_name = random.choice(sample_names[category])
            brand = fake.company()
            item_name = f"{base_name} ({brand})"

            unit = rules[category]['unit']

            shelf = random.randint(rules[category]['shelf_range'][0], rules[category]['shelf_range'][1])

            storage = rules[category]['storage']

            min_stock = round(random.uniform(0.00, 35.00), 2)

            cost = round(random.uniform(rules[category]['cost_range'][0], rules[category]['cost_range'][1]), 2)

            writer.writerow([category, item_name, unit, shelf, storage, min_stock, cost])

    print(f"Генерация ингредиентнов закончена, создано {NUM_INGREDIENTS} записей.")
    return ingredients_by_category


def generate_menu_items():
    cfg = CONFIG['menu_items']
    categories = cfg['categories']
    modifiers = cfg['modifiers']
    samples = cfg['samples']

    used_combos = set()
    menu_items_info = {}

    with open('data/menu_items.csv', 'w', newline = '', encoding = 'utf-8') as file:
        writer = csv.writer(file)

        writer.writerow(['category', 'name', 'unit', 'portion_size', 'price', 'is_available'])

        while len(used_combos) < NUM_MENU_ITEMS:
            category = random.choice(categories)

            if category == 'Сезонные новинки':
                season = random.choice(list(samples['Сезонные новинки'].keys()))
                item_template = random.choice(samples['Сезонные новинки'][season])
                prefix_name = f"{item_template['name']} [{season}]"
            else:
                item_template = random.choice(samples[category])
                prefix_name = item_template['name']

            unit, portion_size = random.choice(item_template['units'])

            mod = random.choice(modifiers)
            
            if category == 'Свежая выпечка':
                full_name = item_template['name']
            elif 'Классический' in category:
                origin = random.choice(['Бразилия', 'Эфиопия', 'Колумбия', 'Кения', 'Гватемала', 'Бленд'])
                full_name = f"{prefix_name} ({origin})"
            else:
                full_name = f"{prefix_name} {mod}"

            combo = (full_name, unit, portion_size)
            
            if combo in used_combos:
                continue

            used_combos.add(combo)

            item_id = len(used_combos)
            menu_items_info[item_id] = {'category': category, 'name': full_name}

            price = round(random.uniform(item_template['price'][0], item_template['price'][1]), 2)

            if category == 'Сезонные новинки':
                is_available = 'true' if random.random() < 0.70 else 'false'
            else:
                is_available = 'true' if random.random() < 0.95 else 'false'

            writer.writerow([category, full_name, unit, portion_size, price, is_available])

    print(f"Генерация товаров в меню закончена, создано {NUM_MENU_ITEMS} записей.")
    return menu_items_info


def generate_deliveries(supplier_weights):
    supplier_ids = list(supplier_weights.keys())
    weights = list(supplier_weights.values())

    with open('data/deliveries.csv', 'w', newline = '', encoding = 'utf-8') as file:
        writer = csv.writer(file)

        writer.writerow(['shop_id', 'supplier_id', 'ingredient_id', 'delivery_day', 'quantity', 'total_cost'])

        for _ in range(NUM_DELIVERIES):
            shop_id = random.randint(1, NUM_SHOPS)

            supplier_id = random.choices(supplier_ids, weights=weights, k=1)[0]

            ingredient_id = random.randint(1, NUM_INGREDIENTS)

            deliv_day = fake.date_between(start_date=date(2005, 1, 1), end_date=date.today())

            qty = round(random.uniform(5.00, 80.00), 2)

            cost_per_one = round(random.uniform(80.00, 1800.00), 2)

            total_cost = round(qty * cost_per_one, 2)

            writer.writerow([shop_id, supplier_id, ingredient_id, deliv_day, qty, total_cost])

    print(f"Генерация доставок закончена, создано {NUM_DELIVERIES} записей.")


def generate_recipes(ingredients_by_category, menu_items_info):
    used_pairs = set()

    with open('data/recipes.csv', 'w', newline = '', encoding = 'utf-8') as file:
        writer = csv.writer(file)

        writer.writerow(['menu_item_id', 'ingredient_id', 'amount_needed'])

        for menu_id, info in menu_items_info.items():
            category = info['category']
            name_lower = info['name'].lower()

            if category in ['Классический кофе', 'Авторский кофе', 'Холодный кофе', 'Сезонные новинки']:
                req_categories = ['Зерновой кофе', 'Пищевая упаковка']
                if any(x in name_lower for x in ['латте', 'капучино', 'раф', 'флэт']):
                    req_categories.append(random.choice(['Молочные продукты', 'Растительное молоко']))
                if category in ['Авторский кофе', 'Сезонные новинки']:
                    req_categories.append('Сиропы и топпинги')
            elif category == 'Чай и матча':
                req_categories = ['Чай', 'Пищевая упаковка']
                if 'матча' in name_lower:
                    req_categories.append('Молочные продукты')
            elif category == 'Свежая выпечка':
                req_categories = ['Выпечка и заморозка', 'Пищевая упаковка']
            else:
                req_categories = ['Сиропы и топпинги', 'Пищевая упаковка']


            for req_category in req_categories:
                pool = ingredients_by_category.get(req_category, [])
                if not pool:
                    continue

                ing_id = random.choice(pool)

                if (menu_id, ing_id) in used_pairs:
                    continue

                used_pairs.add((menu_id, ing_id))

                if req_category == 'Зерновой кофе':
                    amount = round(random.uniform(0.018, 0.036), 3)
                elif req_category in ['Молочные продукты', 'Растительное молоко']:
                    amount = round(random.uniform(0.150, 0.350), 3)
                elif req_category == 'Сиропы и топпинги':
                    amount = round(random.uniform(0.020, 0.040), 3)
                elif req_category == 'Чай':
                    amount = round(random.uniform(0.005, 0.012), 3)
                else:
                    amount = 1.000

                writer.writerow([menu_id, ing_id, amount])

        while len(used_pairs) < NUM_RECIPES:
            menu_id = random.randint(1, NUM_MENU_ITEMS)
            category = menu_items_info[menu_id]['category']

            if 'кофе' in category.lower() or category == 'Сезонные новинки':
                pick_category = random.choice(['Сиропы и топпинги', 'Растительное молоко', 'Какао и шоколад'])
            else:
                pick_category = random.choice(['Сиропы и топпинги', 'Пищевая упаковка'])

            pool = ingredients_by_category.get(pick_category, [])

            if not pool:
                continue

            ing_id = random.choice(pool)

            if (menu_id, ing_id) not in used_pairs:
                used_pairs.add((menu_id, ing_id))
                writer.writerow([menu_id, ing_id, round(random.uniform(0.015, 0.045), 3)])

    print(f"Генерация соотношений продукт-ингредиент закончена, создано {NUM_RECIPES} записей.")


if __name__ == '__main__':
    generate_coffee_shops()
    generate_employees()
    supplier_weights = generate_suppliers()
    ingredients_by_category = generate_ingredients()
    menu_items_info = generate_menu_items()
    generate_deliveries(supplier_weights)
    generate_recipes(ingredients_by_category, menu_items_info)
                
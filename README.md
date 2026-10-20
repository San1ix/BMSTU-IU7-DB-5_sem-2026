# Реляционная база данных "Сеть кофейен" (Coffee Shop Database)
- PostgreSQL
- Python | Faker
- DBeaver
---

**ER-диаграмма:** `docs/coffee_shop_diagram.png`

**Инструкция по взаимодействию**
1. Генерируем таблички с данными
```
python scripts/generate_data.python
```
2. Запускаем sql-скрипты в следующем порядке: 
```
psql -U postgres -d coffee_shop_db -f sql/create_tables.sql
psql -U postgres -d coffee_shop_db -f sql/alter.sql
psql -U postgres -d coffee_shop_db -f sql/copy.sql
```
3. Удачи вам на жизненном пути!
# 🏭 Manufacturing Quality & Operations Star Schema Architecture

## Data Model Design
```
       +--------------------+          +--------------------+
       |    dim_machines    |          |    dim_products    |
       |--------------------|          |--------------------|
       | machine_id (PK)    |<---+     | product_id (PK)    |<----+
       | machine_name       |    |     | product_name       |     |
       | production_line    |    |     | target_shift_output|     |
       | base_temp / press  |    |     | unit_weight_kg     |     |
       +--------------------+    |     +--------------------+     |
                                 |                                |
                                 | 1:N                            | 1:N
                                 |                                |
       +--------------------+    |     +--------------------+     |
       |      dim_date      |    |     | fact_prod_shifts   |     |
       |--------------------|    |     |--------------------|     |
       | Date (PK)          |<---|--+  | record_id (PK)     |     |
       | Year / Month / Day |    |  |  | machine_id (FK)    |-----+
       | DayOfWeekName      |    |  |  | product_id (FK)    |-----+
       +--------------------+    |  |  | production_date(FK)|
                 |               |  |  | units_produced     |
                 | 1:N           |  |  | units_defective    |
                 v               |  |  | downtime_minutes   |
       +--------------------+    |  |  | sensor readings    |
       |  fact_maintenance  |    |  |  | energy_kwh         |
       |--------------------|    |  |  +--------------------+
       | maintenance_id (PK)|    |  |
       | machine_id (FK)    |----+  |
       | maintenance_date   |-------+
       | maintenance_type   |
       | duration_hours     |
       | maintenance_cost   |
       +--------------------+
```

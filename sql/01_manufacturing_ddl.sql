-- ============================================================================
-- PROJECT 2: MANUFACTURING QUALITY, DOWNTIME & OPERATIONS ANALYTICS
-- Database: PostgreSQL 14+ / Standard SQL Relational DDL
-- ============================================================================

DROP TABLE IF EXISTS fact_production_shifts CASCADE;
DROP TABLE IF EXISTS fact_maintenance CASCADE;
DROP TABLE IF EXISTS dim_machines CASCADE;
DROP TABLE IF EXISTS dim_products CASCADE;

-- 1. DIMENSION: MACHINES & PRODUCTION LINES
CREATE TABLE dim_machines (
    machine_id VARCHAR(20) PRIMARY KEY,
    machine_name VARCHAR(100) NOT NULL,
    production_line VARCHAR(100) NOT NULL,
    base_temp NUMERIC(6, 2) NOT NULL,
    base_press NUMERIC(6, 2) NOT NULL,
    base_vib NUMERIC(6, 2) NOT NULL,
    base_energy_kwh NUMERIC(8, 2) NOT NULL,
    health_status VARCHAR(50) NOT NULL
);

-- 2. DIMENSION: PRODUCTS & TARGETS
CREATE TABLE dim_products (
    product_id VARCHAR(20) PRIMARY KEY,
    product_name VARCHAR(150) NOT NULL,
    target_output_per_shift INT NOT NULL,
    unit_weight_kg NUMERIC(6, 2) NOT NULL
);

-- 3. FACT: PRODUCTION SHIFTS & SENSOR LOGS (8,784 RECORDS)
CREATE TABLE fact_production_shifts (
    record_id VARCHAR(20) PRIMARY KEY,
    production_date DATE NOT NULL,
    shift VARCHAR(50) NOT NULL,
    machine_id VARCHAR(20) NOT NULL REFERENCES dim_machines(machine_id),
    machine_name VARCHAR(100) NOT NULL,
    production_line VARCHAR(100) NOT NULL,
    product_id VARCHAR(20) NOT NULL REFERENCES dim_products(product_id),
    product_name VARCHAR(150) NOT NULL,
    operator_id VARCHAR(20) NOT NULL,
    production_target INT NOT NULL,
    units_produced INT NOT NULL,
    units_defective INT NOT NULL,
    units_good INT NOT NULL,
    defect_rate_pct NUMERIC(6, 2) NOT NULL,
    primary_defect_type VARCHAR(100),
    downtime_minutes INT NOT NULL,
    downtime_rate_pct NUMERIC(6, 2) NOT NULL,
    downtime_reason VARCHAR(100),
    operating_minutes INT NOT NULL,
    sensor_temperature_c NUMERIC(6, 2) NOT NULL,
    sensor_pressure_bar NUMERIC(6, 2) NOT NULL,
    sensor_vibration_mms NUMERIC(6, 2) NOT NULL,
    energy_consumption_kwh NUMERIC(10, 2) NOT NULL,
    energy_per_unit_kwh NUMERIC(8, 3) NOT NULL,
    efficiency_pct NUMERIC(6, 2) NOT NULL,
    target_met VARCHAR(10) CHECK (target_met IN ('Yes', 'No'))
);

-- 4. FACT: MACHINE MAINTENANCE LOGS
CREATE TABLE fact_maintenance (
    maintenance_id VARCHAR(20) PRIMARY KEY,
    machine_id VARCHAR(20) NOT NULL REFERENCES dim_machines(machine_id),
    maintenance_date DATE NOT NULL,
    maintenance_type VARCHAR(100) NOT NULL,
    duration_hours NUMERIC(5, 2) NOT NULL,
    maintenance_cost_usd NUMERIC(10, 2) NOT NULL,
    technician_id VARCHAR(20) NOT NULL,
    parts_replaced VARCHAR(10) CHECK (parts_replaced IN ('Yes', 'No'))
);

-- 5. INDEXES FOR FAST ANALYTICAL GROUPINGS
CREATE INDEX idx_mfg_date_shift ON fact_production_shifts(production_date, shift);
CREATE INDEX idx_mfg_machine ON fact_production_shifts(machine_id);
CREATE INDEX idx_mfg_downtime ON fact_production_shifts(downtime_reason);
CREATE INDEX idx_mfg_defects ON fact_production_shifts(primary_defect_type);

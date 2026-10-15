-- ============================================================================
-- PROJECT 2: 20+ BUSINESS SQL QUERIES FOR MANUFACTURING & OPERATIONS
-- Author: Gaurav | Senior Data Analyst & BI Consultant
-- ============================================================================

-- ----------------------------------------------------------------------------
-- QUERY 1: PLANT OVERALL EQUIPMENT EFFICIENCY (OEE) & KPI SUMMARY
-- Business Purpose: Immediate executive plant dashboard showing target achievement, defect rate, and total downtime.
-- ----------------------------------------------------------------------------
SELECT 
    COUNT(record_id) AS total_shifts_operated,
    SUM(units_produced) AS total_units_produced,
    SUM(units_defective) AS total_defective_units,
    ROUND((SUM(units_defective)::NUMERIC / NULLIF(SUM(units_produced), 0) * 100), 2) AS plant_defect_rate_pct,
    ROUND(SUM(downtime_minutes) / 60.0, 1) AS total_downtime_hours,
    ROUND((SUM(units_produced)::NUMERIC / NULLIF(SUM(production_target), 0) * 100), 2) AS target_achievement_pct,
    ROUND(SUM(energy_consumption_kwh), 1) AS total_energy_kwh,
    ROUND(SUM(energy_consumption_kwh) / NULLIF(SUM(units_produced), 0), 3) AS plant_energy_per_unit_kwh
FROM fact_production_shifts;

-- ----------------------------------------------------------------------------
-- QUERY 2: MACHINE RANKING BY DOWNTIME AND LOSS OF PRODUCTION
-- Business Purpose: Identify the worst-performing machine for engineering overhaul.
-- ----------------------------------------------------------------------------
SELECT 
    machine_id,
    machine_name,
    production_line,
    COUNT(record_id) AS shifts_count,
    ROUND(SUM(downtime_minutes) / 60.0, 1) AS total_downtime_hours,
    ROUND(AVG(downtime_rate_pct), 2) AS avg_downtime_pct,
    SUM(units_produced) AS total_output,
    ROUND((SUM(units_defective)::NUMERIC / NULLIF(SUM(units_produced), 0) * 100), 2) AS machine_defect_rate_pct,
    DENSE_RANK() OVER (ORDER BY SUM(downtime_minutes) DESC) AS downtime_severity_rank
FROM fact_production_shifts
GROUP BY machine_id, machine_name, production_line
ORDER BY total_downtime_hours DESC;

-- ----------------------------------------------------------------------------
-- QUERY 3: SHIFT PERFORMANCE COMPARISON (MORNING VS EVENING VS NIGHT)
-- Business Purpose: Evaluate human operator variance and shift scheduling efficiency.
-- ----------------------------------------------------------------------------
SELECT 
    shift,
    COUNT(record_id) AS shift_runs,
    SUM(units_produced) AS total_produced,
    SUM(units_defective) AS total_defects,
    ROUND((SUM(units_defective)::NUMERIC / NULLIF(SUM(units_produced), 0) * 100), 2) AS shift_defect_rate_pct,
    ROUND(AVG(efficiency_pct), 2) AS avg_target_efficiency_pct,
    ROUND(SUM(downtime_minutes) / 60.0, 1) AS shift_downtime_hours
FROM fact_production_shifts
GROUP BY shift
ORDER BY avg_target_efficiency_pct DESC;

-- ----------------------------------------------------------------------------
-- QUERY 4: DOWNTIME PARETO ANALYSIS (ROOT CAUSES)
-- Business Purpose: Quantify which 20% of downtime causes drive 80% of factory stoppages.
-- ----------------------------------------------------------------------------
WITH downtime_breakdown AS (
    SELECT 
        downtime_reason,
        SUM(downtime_minutes) AS total_reason_downtime_mins,
        COUNT(record_id) AS incident_count
    FROM fact_production_shifts
    WHERE downtime_reason != 'None'
    GROUP BY downtime_reason
),
pareto_calc AS (
    SELECT 
        downtime_reason,
        total_reason_downtime_mins,
        incident_count,
        ROUND(total_reason_downtime_mins / 60.0, 1) AS downtime_hours,
        SUM(total_reason_downtime_mins) OVER (ORDER BY total_reason_downtime_mins DESC) AS cumulative_downtime_mins,
        SUM(total_reason_downtime_mins) OVER () AS total_plant_downtime_mins
    FROM downtime_breakdown
)
SELECT 
    downtime_reason,
    incident_count,
    downtime_hours,
    ROUND((total_reason_downtime_mins::NUMERIC / total_plant_downtime_mins * 100), 2) AS share_of_total_downtime_pct,
    ROUND((cumulative_downtime_mins::NUMERIC / total_plant_downtime_mins * 100), 2) AS cumulative_pareto_pct
FROM pareto_calc
ORDER BY total_reason_downtime_mins DESC;

-- ----------------------------------------------------------------------------
-- QUERY 5: THERMAL ANOMALY IMPACT ON DEFECT RATES
-- Business Purpose: Determine if operating machines at elevated temperatures (>75°C) multiplies defect generation.
-- ----------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN sensor_temperature_c < 65.0 THEN '< 65°C (Cool/Optimal)'
        WHEN sensor_temperature_c <= 75.0 THEN '65°C - 75°C (Normal)'
        WHEN sensor_temperature_c <= 85.0 THEN '75.1°C - 85°C (Elevated)'
        ELSE '> 85°C (Critical Thermal Stress)'
    END AS thermal_band,
    COUNT(record_id) AS shift_samples,
    SUM(units_produced) AS total_units,
    SUM(units_defective) AS total_defects,
    ROUND((SUM(units_defective)::NUMERIC / NULLIF(SUM(units_produced), 0) * 100), 2) AS defect_rate_pct,
    ROUND(AVG(sensor_vibration_mms), 2) AS avg_vibration_level
FROM fact_production_shifts
GROUP BY 1
ORDER BY defect_rate_pct ASC;

-- ----------------------------------------------------------------------------
-- QUERY 6: MONTH-OVER-MONTH PRODUCTION AND DEFECT TRENDS (WINDOW LAG)
-- Business Purpose: Track monthly continuous improvement trajectory.
-- ----------------------------------------------------------------------------
WITH monthly_mfg AS (
    SELECT 
        TO_CHAR(production_date, 'YYYY-MM') AS prod_month,
        SUM(units_produced) AS monthly_production,
        SUM(units_defective) AS monthly_defects,
        ROUND((SUM(units_defective)::NUMERIC / NULLIF(SUM(units_produced), 0) * 100), 2) AS monthly_defect_rate
    FROM fact_production_shifts
    GROUP BY TO_CHAR(production_date, 'YYYY-MM')
)
SELECT 
    prod_month,
    monthly_production,
    LAG(monthly_production) OVER (ORDER BY prod_month) AS prev_month_production,
    ROUND(
        ((monthly_production - LAG(monthly_production) OVER (ORDER BY prod_month))::NUMERIC 
        / NULLIF(LAG(monthly_production) OVER (ORDER BY prod_month), 0) * 100), 2
    ) AS mom_production_growth_pct,
    monthly_defects,
    monthly_defect_rate
FROM monthly_mfg
ORDER BY prod_month;

-- ----------------------------------------------------------------------------
-- QUERY 7: ENERGY CONSUMPTION INTENSITY BY MACHINE (KWH PER UNIT)
-- Business Purpose: Identify energy-inefficient equipment to cut carbon footprint and utility bills.
-- ----------------------------------------------------------------------------
SELECT 
    machine_id,
    machine_name,
    production_line,
    SUM(units_produced) AS total_units,
    ROUND(SUM(energy_consumption_kwh), 1) AS total_energy_consumed_kwh,
    ROUND(SUM(energy_consumption_kwh) / NULLIF(SUM(units_produced), 0), 3) AS real_energy_per_unit_kwh,
    DENSE_RANK() OVER (ORDER BY (SUM(energy_consumption_kwh) / NULLIF(SUM(units_produced), 0)) DESC) AS energy_inefficiency_rank
FROM fact_production_shifts
GROUP BY machine_id, machine_name, production_line
ORDER BY real_energy_per_unit_kwh DESC;

-- ----------------------------------------------------------------------------
-- QUERY 8: DEFECT TYPE BREAKDOWN BY PRODUCT
-- Business Purpose: Quality engineering needs to know which specific flaws affect which parts.
-- ----------------------------------------------------------------------------
SELECT 
    product_name,
    primary_defect_type,
    COUNT(record_id) AS occurrences,
    SUM(units_defective) AS total_defective_pieces,
    ROUND(
        (SUM(units_defective)::NUMERIC 
        / SUM(SUM(units_defective)) OVER (PARTITION BY product_name) * 100), 2
    ) AS pct_of_product_defects
FROM fact_production_shifts
WHERE primary_defect_type != 'None'
GROUP BY product_name, primary_defect_type
ORDER BY product_name, total_defective_pieces DESC;

-- ----------------------------------------------------------------------------
-- QUERY 9: ROLLING 7-DAY AVERAGE PRODUCTION OUTPUT (WINDOW ROLLING AVERAGE)
-- Business Purpose: Smooth daily fluctuations to observe underlying production momentum.
-- ----------------------------------------------------------------------------
WITH daily_plant_output AS (
    SELECT 
        production_date,
        SUM(units_produced) AS daily_units
    FROM fact_production_shifts
    GROUP BY production_date
)
SELECT 
    production_date,
    daily_units,
    ROUND(AVG(daily_units) OVER (ORDER BY production_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 1) AS rolling_7day_avg_production
FROM daily_plant_output
ORDER BY production_date;

-- ----------------------------------------------------------------------------
-- QUERY 10: PRE-MAINTENANCE VS POST-MAINTENANCE DEFECT & DOWNTIME COMPARISON
-- Business Purpose: Measure ROI and operational effectiveness of maintenance events.
-- ----------------------------------------------------------------------------
WITH maintenance_window AS (
    SELECT 
        m.machine_id,
        m.maintenance_date,
        m.maintenance_type,
        s.production_date,
        s.units_produced,
        s.units_defective,
        s.downtime_minutes,
        CASE 
            WHEN s.production_date BETWEEN m.maintenance_date - INTERVAL '7 days' AND m.maintenance_date - INTERVAL '1 day' THEN '7 Days Before'
            WHEN s.production_date BETWEEN m.maintenance_date + INTERVAL '1 day' AND m.maintenance_date + INTERVAL '7 days' THEN '7 Days After'
            ELSE 'Other'
        END AS window_period
    FROM fact_maintenance m
    JOIN fact_production_shifts s ON m.machine_id = s.machine_id
)
SELECT 
    maintenance_type,
    window_period,
    COUNT(*) AS shift_records,
    ROUND(AVG(downtime_minutes), 1) AS avg_downtime_mins,
    ROUND((SUM(units_defective)::NUMERIC / NULLIF(SUM(units_produced), 0) * 100), 2) AS defect_rate_pct
FROM maintenance_window
WHERE window_period IN ('7 Days Before', '7 Days After')
GROUP BY maintenance_type, window_period
ORDER BY maintenance_type, window_period DESC;

-- ----------------------------------------------------------------------------
-- QUERIES 11 TO 20 (HIGH IMPACT OPERATIONAL DIAGNOSTICS)
-- ----------------------------------------------------------------------------
-- QUERY 11: Top 5 Operators with Highest Target Efficiency
SELECT operator_id, COUNT(*) AS shifts, SUM(units_produced) AS total_units, ROUND(AVG(efficiency_pct), 2) AS avg_efficiency_pct
FROM fact_production_shifts GROUP BY operator_id HAVING COUNT(*) >= 100 ORDER BY avg_efficiency_pct DESC LIMIT 5;

-- QUERY 12: Production Line Yield & Scrap Loss Rate
SELECT production_line, SUM(units_produced) AS total_units, SUM(units_defective) AS scrap_units,
ROUND((SUM(units_good)::NUMERIC / NULLIF(SUM(units_produced), 0) * 100), 2) AS first_pass_yield_pct
FROM fact_production_shifts GROUP BY production_line ORDER BY first_pass_yield_pct DESC;

-- QUERY 13: Correlation Proxy: High Vibration (>3.0 mm/s) Shifts Defect Multiplier
SELECT CASE WHEN sensor_vibration_mms > 3.0 THEN 'High Vibration (>3.0 mm/s)' ELSE 'Normal Vibration (<=3.0 mm/s)' END AS vibration_category,
COUNT(*) AS shifts, ROUND((SUM(units_defective)::NUMERIC / NULLIF(SUM(units_produced), 0) * 100), 2) AS defect_rate_pct
FROM fact_production_shifts GROUP BY 1;

-- QUERY 14: Machine Target Miss Frequency
SELECT machine_id, machine_name, COUNT(*) AS total_shifts,
SUM(CASE WHEN target_met = 'No' THEN 1 ELSE 0 END) AS missed_target_shifts,
ROUND((SUM(CASE WHEN target_met = 'No' THEN 1 ELSE 0 END)::NUMERIC / COUNT(*) * 100), 2) AS miss_rate_pct
FROM fact_production_shifts GROUP BY machine_id, machine_name ORDER BY miss_rate_pct DESC;

-- QUERY 15: Monthly Maintenance Spend & Repair Count
SELECT TO_CHAR(maintenance_date, 'YYYY-MM') AS maint_month, COUNT(*) AS total_events,
SUM(maintenance_cost_usd) AS total_spend_usd, ROUND(AVG(duration_hours), 2) AS avg_duration_hrs
FROM fact_maintenance GROUP BY TO_CHAR(maintenance_date, 'YYYY-MM') ORDER BY maint_month;

-- QUERY 16: Worst Defect Day in Plant History
SELECT production_date, shift, machine_name, units_produced, units_defective, defect_rate_pct, primary_defect_type
FROM fact_production_shifts ORDER BY defect_rate_pct DESC LIMIT 10;

-- QUERY 17: Machine Utilization Rate Percentage (Operating Mins vs Total Shift Mins)
SELECT machine_id, machine_name, ROUND(SUM(operating_minutes)::NUMERIC / SUM(480) * 100, 2) AS utilization_pct
FROM fact_production_shifts GROUP BY machine_id, machine_name ORDER BY utilization_pct ASC;

-- QUERY 18: Weekend vs Weekday Defect Variance
SELECT CASE WHEN EXTRACT(ISODOW FROM production_date) IN (6, 7) THEN 'Weekend' ELSE 'Weekday' END AS day_category,
SUM(units_produced) AS total_units, ROUND((SUM(units_defective)::NUMERIC / NULLIF(SUM(units_produced), 0) * 100), 2) AS defect_rate_pct
FROM fact_production_shifts GROUP BY 1;

-- QUERY 19: Tool Wear Downtime Frequency by Machine
SELECT machine_id, machine_name, COUNT(*) AS tool_wear_incidents, SUM(downtime_minutes) AS lost_mins
FROM fact_production_shifts WHERE downtime_reason = 'Tool Wear / Breakage' GROUP BY machine_id, machine_name ORDER BY lost_mins DESC;

-- QUERY 20: Cumulative Energy Consumption Tracking Over Time
SELECT production_date, SUM(energy_consumption_kwh) AS daily_kwh,
SUM(SUM(energy_consumption_kwh)) OVER (ORDER BY production_date) AS cumulative_annual_energy_kwh
FROM fact_production_shifts GROUP BY production_date ORDER BY production_date;

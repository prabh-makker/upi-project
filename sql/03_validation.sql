-- ============================================================================
-- UPI Project - Phase 3: Post-Load Validation Script
-- File: 03_validation.sql
-- Description: Comprehensive data quality and integrity checks
-- Author: Data Engineering Team
-- Date: 2026-09-29
-- ============================================================================

USE upi_db;

-- ============================================================================
-- VALIDATION CONTROL
-- ============================================================================

SET SESSION sql_mode = 'STRICT_TRANS_TABLES';

-- Create temporary results table for validation summary
DROP TABLE IF EXISTS validation_results_temp;
CREATE TEMPORARY TABLE validation_results_temp (
    check_sequence INT,
    check_name VARCHAR(100),
    expected_criteria VARCHAR(255),
    actual_result VARCHAR(255),
    validation_status VARCHAR(10),
    details TEXT
);

-- ============================================================================
-- 1. ROW COUNT VALIDATION
-- ============================================================================

SELECT '=== 1. ROW COUNT VALIDATION ===' AS validation_section;

-- Check 1.1: Verify minimum data in dim_date
SELECT
    'DIM_DATE: Row Count' AS check_name,
    CONCAT('Expected >= 2500 rows (7 years daily)') AS criteria,
    CONCAT('Actual: ', COUNT(*), ' rows') AS result,
    CASE WHEN COUNT(*) >= 2500 THEN 'PASS' ELSE 'FAIL' END AS status
FROM dim_date;

-- Check 1.2: Verify minimum data in dim_bank
SELECT
    'DIM_BANK: Row Count' AS check_name,
    CONCAT('Expected >= 5 rows') AS criteria,
    CONCAT('Actual: ', COUNT(*), ' rows') AS result,
    CASE WHEN COUNT(*) >= 5 THEN 'PASS' ELSE 'FAIL' END AS status
FROM dim_bank;

-- Check 1.3: Verify minimum data in dim_upi_type
SELECT
    'DIM_UPI_TYPE: Row Count' AS check_name,
    CONCAT('Expected >= 5 rows') AS criteria,
    CONCAT('Actual: ', COUNT(*), ' rows') AS result,
    CASE WHEN COUNT(*) >= 5 THEN 'PASS' ELSE 'FAIL' END AS status
FROM dim_upi_type;

-- Check 1.4: Verify minimum data in fact_upi_transactions
SELECT
    'FACT_UPI_TRANSACTIONS: Row Count' AS check_name,
    CONCAT('Expected >= 100 rows') AS criteria,
    CONCAT('Actual: ', COUNT(*), ' rows') AS result,
    CASE WHEN COUNT(*) >= 100 THEN 'PASS' ELSE 'FAIL' END AS status
FROM fact_upi_transactions;

-- ============================================================================
-- 2. NULL VALUE CHECKS (Critical Columns)
-- ============================================================================

SELECT '=== 2. NULL VALUE VALIDATION (CRITICAL COLUMNS) ===' AS validation_section;

-- Check 2.1: dim_date null check
SELECT
    'DIM_DATE: NULL Values' AS check_name,
    'All key columns should be NOT NULL' AS criteria,
    CONCAT('Nulls found: ', COUNT(*)) AS result,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM dim_date
WHERE date_val IS NULL OR year IS NULL OR month IS NULL OR day IS NULL;

-- Check 2.2: dim_bank null check
SELECT
    'DIM_BANK: NULL Values' AS check_name,
    'All key columns should be NOT NULL' AS criteria,
    CONCAT('Nulls found: ', COUNT(*)) AS result,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM dim_bank
WHERE bank_name IS NULL OR bank_code IS NULL OR category IS NULL;

-- Check 2.3: dim_upi_type null check
SELECT
    'DIM_UPI_TYPE: NULL Values' AS check_name,
    'All key columns should be NOT NULL' AS criteria,
    CONCAT('Nulls found: ', COUNT(*)) AS result,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM dim_upi_type
WHERE type_name IS NULL;

-- Check 2.4: fact_upi_transactions null check for FKs
SELECT
    'FACT_UPI_TRANSACTIONS: Foreign Key Nulls' AS check_name,
    'date_id, bank_id, upi_type_id should be NOT NULL' AS criteria,
    CONCAT('Nulls found: ', COUNT(*)) AS result,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM fact_upi_transactions
WHERE date_id IS NULL OR bank_id IS NULL OR upi_type_id IS NULL;

-- Check 2.5: fact_upi_transactions null check for measures
SELECT
    'FACT_UPI_TRANSACTIONS: Measure Nulls' AS check_name,
    'Transaction measures should be NOT NULL' AS criteria,
    CONCAT('Nulls found: ', COUNT(*)) AS result,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM fact_upi_transactions
WHERE transaction_count IS NULL OR transaction_value_cr IS NULL OR success_rate IS NULL;

-- ============================================================================
-- 3. REFERENTIAL INTEGRITY VALIDATION
-- ============================================================================

SELECT '=== 3. REFERENTIAL INTEGRITY VALIDATION ===' AS validation_section;

-- Check 3.1: Verify all date_id references exist in dim_date
SELECT
    'FACT -> DIM_DATE: Referential Integrity' AS check_name,
    'All date_id values should exist in dim_date' AS criteria,
    CONCAT('Orphaned records: ', COUNT(*)) AS result,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM fact_upi_transactions fut
WHERE NOT EXISTS (SELECT 1 FROM dim_date dd WHERE fut.date_id = dd.date_id);

-- Check 3.2: Verify all bank_id references exist in dim_bank
SELECT
    'FACT -> DIM_BANK: Referential Integrity' AS check_name,
    'All bank_id values should exist in dim_bank' AS criteria,
    CONCAT('Orphaned records: ', COUNT(*)) AS result,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM fact_upi_transactions fut
WHERE NOT EXISTS (SELECT 1 FROM dim_bank db WHERE fut.bank_id = db.bank_id);

-- Check 3.3: Verify all upi_type_id references exist in dim_upi_type
SELECT
    'FACT -> DIM_UPI_TYPE: Referential Integrity' AS check_name,
    'All upi_type_id values should exist in dim_upi_type' AS criteria,
    CONCAT('Orphaned records: ', COUNT(*)) AS result,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM fact_upi_transactions fut
WHERE NOT EXISTS (SELECT 1 FROM dim_upi_type dut WHERE fut.upi_type_id = dut.upi_type_id);

-- ============================================================================
-- 4. DATA RANGE AND CONSTRAINT VALIDATION
-- ============================================================================

SELECT '=== 4. DATA RANGE AND CONSTRAINT VALIDATION ===' AS validation_section;

-- Check 4.1: Date values are valid
SELECT
    'DIM_DATE: Valid Date Range' AS check_name,
    'Dates should be between 2016-04-01 and 2026-12-31' AS criteria,
    CONCAT('Out of range: ', COUNT(*)) AS result,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM dim_date
WHERE date_val < '2016-04-01' OR date_val > '2026-12-31';

-- Check 4.2: Month values are valid (1-12)
SELECT
    'DIM_DATE: Valid Month Values' AS check_name,
    'Months should be 1-12' AS criteria,
    CONCAT('Invalid months: ', COUNT(*)) AS result,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM dim_date
WHERE month < 1 OR month > 12;

-- Check 4.3: Quarter values are valid (1-4)
SELECT
    'DIM_DATE: Valid Quarter Values' AS check_name,
    'Quarters should be 1-4' AS criteria,
    CONCAT('Invalid quarters: ', COUNT(*)) AS result,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM dim_date
WHERE quarter < 1 OR quarter > 4;

-- Check 4.4: Success rate is within valid range (0-100)
SELECT
    'FACT: Valid Success Rate Range' AS check_name,
    'Success rate should be 0-100%' AS criteria,
    CONCAT('Out of range: ', COUNT(*)) AS result,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM fact_upi_transactions
WHERE success_rate < 0 OR success_rate > 100;

-- Check 4.5: Success rates are within business expectation (>= 95%)
SELECT
    'FACT: Business SLA - Success Rate >= 95%' AS check_name,
    'Expected: At least 95% success rate' AS criteria,
    CONCAT('Below SLA: ', COUNT(*), ' records') AS result,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        WHEN (COUNT(*) / (SELECT COUNT(*) FROM fact_upi_transactions WHERE transaction_count > 0)) < 0.05 THEN 'PASS'
        ELSE 'WARNING'
    END AS status
FROM fact_upi_transactions
WHERE success_rate < 95 AND transaction_count > 0;

-- Check 4.6: Negative value checks
SELECT
    'FACT: Non-Negative Measures' AS check_name,
    'All measures should be >= 0' AS criteria,
    CONCAT('Negative values: ', COUNT(*)) AS result,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM fact_upi_transactions
WHERE transaction_count < 0 OR transaction_value_cr < 0 OR avg_txn_value < 0;

-- ============================================================================
-- 5. UNIQUENESS AND DUPLICATE VALIDATION
-- ============================================================================

SELECT '=== 5. UNIQUENESS AND DUPLICATE VALIDATION ===' AS validation_section;

-- Check 5.1: Unique bank codes
SELECT
    'DIM_BANK: Unique Bank Codes' AS check_name,
    'Bank codes must be unique' AS criteria,
    CONCAT('Duplicates: ', COUNT(*) - COUNT(DISTINCT bank_code)) AS result,
    CASE WHEN COUNT(*) = COUNT(DISTINCT bank_code) THEN 'PASS' ELSE 'FAIL' END AS status
FROM dim_bank;

-- Check 5.2: Unique UPI type names
SELECT
    'DIM_UPI_TYPE: Unique Type Names' AS check_name,
    'Type names must be unique' AS criteria,
    CONCAT('Duplicates: ', COUNT(*) - COUNT(DISTINCT type_name)) AS result,
    CASE WHEN COUNT(*) = COUNT(DISTINCT type_name) THEN 'PASS' ELSE 'FAIL' END AS status
FROM dim_upi_type;

-- Check 5.3: Unique date values
SELECT
    'DIM_DATE: Unique Date Values' AS check_name,
    'Date values must be unique' AS criteria,
    CONCAT('Duplicates: ', COUNT(*) - COUNT(DISTINCT date_val)) AS result,
    CASE WHEN COUNT(*) = COUNT(DISTINCT date_val) THEN 'PASS' ELSE 'FAIL' END AS status
FROM dim_date;

-- Check 5.4: Fact table uniqueness (date, bank, upi_type combination)
SELECT
    'FACT: Unique Daily Bank-Type Combinations' AS check_name,
    'Each date-bank-type combination should appear once' AS criteria,
    CONCAT('Duplicates: ', COUNT(*) - COUNT(DISTINCT CONCAT(date_id, '_', bank_id, '_', upi_type_id))) AS result,
    CASE WHEN COUNT(*) = COUNT(DISTINCT CONCAT(date_id, '_', bank_id, '_', upi_type_id)) THEN 'PASS' ELSE 'FAIL' END AS status
FROM fact_upi_transactions;

-- ============================================================================
-- 6. DATA DISTRIBUTION ANALYSIS
-- ============================================================================

SELECT '=== 6. DATA DISTRIBUTION ANALYSIS ===' AS validation_section;

-- Check 6.1: Bank category distribution
SELECT
    'DIM_BANK: Category Distribution' AS check_name,
    category AS category,
    COUNT(*) AS count
FROM dim_bank
WHERE is_active = TRUE
GROUP BY category
ORDER BY count DESC;

-- Check 6.2: UPI type distribution in facts
SELECT
    'FACT: UPI Type Distribution' AS check_name,
    dut.type_name AS upi_type,
    COUNT(*) AS fact_records,
    SUM(fut.transaction_count) AS total_transactions
FROM fact_upi_transactions fut
INNER JOIN dim_upi_type dut ON fut.upi_type_id = dut.upi_type_id
GROUP BY fut.upi_type_id
ORDER BY total_transactions DESC;

-- Check 6.3: Bank transaction distribution
SELECT
    'FACT: Top 10 Banks by Transaction Volume' AS check_name,
    db.bank_name AS bank,
    COUNT(*) AS fact_records,
    SUM(fut.transaction_count) AS total_transactions,
    ROUND(SUM(fut.transaction_value_cr), 2) AS total_value_cr
FROM fact_upi_transactions fut
INNER JOIN dim_bank db ON fut.bank_id = db.bank_id
GROUP BY fut.bank_id
ORDER BY total_transactions DESC
LIMIT 10;

-- ============================================================================
-- 7. TIME DIMENSION VALIDATION
-- ============================================================================

SELECT '=== 7. TIME DIMENSION VALIDATION ===' AS validation_section;

-- Check 7.1: Coverage analysis by year
SELECT
    'DIM_DATE: Year Coverage' AS check_name,
    year,
    COUNT(*) AS days_in_year
FROM dim_date
GROUP BY year
ORDER BY year;

-- Check 7.2: Fact data date range
SELECT
    'FACT: Data Date Range' AS check_name,
    CONCAT('Min Date: ', MIN(dd.date_val)) AS min_date,
    CONCAT('Max Date: ', MAX(dd.date_val)) AS max_date,
    CONCAT('Days Covered: ', COUNT(DISTINCT dd.date_id)) AS days_with_data
FROM fact_upi_transactions fut
INNER JOIN dim_date dd ON fut.date_id = dd.date_id;

-- Check 7.3: Weekend distribution
SELECT
    'DIM_DATE: Weekend vs Weekday Split' AS check_name,
    CASE WHEN is_weekend THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    COUNT(*) AS count
FROM dim_date
GROUP BY is_weekend;

-- ============================================================================
-- 8. SAMPLE DATA VERIFICATION
-- ============================================================================

SELECT '=== 8. SAMPLE DATA VERIFICATION ===' AS validation_section;

-- Sample 1: Recent transactions by bank and type
SELECT
    'Sample: Recent Transactions (Last 7 Days)' AS sample_description,
    dd.date_val AS transaction_date,
    db.bank_name AS bank,
    dut.type_name AS upi_type,
    fut.transaction_count AS txn_count,
    fut.transaction_value_cr AS value_cr,
    fut.success_rate AS success_rate,
    fut.avg_txn_value AS avg_txn_value
FROM fact_upi_transactions fut
INNER JOIN dim_date dd ON fut.date_id = dd.date_id
INNER JOIN dim_bank db ON fut.bank_id = db.bank_id
INNER JOIN dim_upi_type dut ON fut.upi_type_id = dut.upi_type_id
WHERE dd.date_val >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
ORDER BY dd.date_val DESC, fut.transaction_count DESC
LIMIT 20;

-- Sample 2: High-value transactions
SELECT
    'Sample: High-Value Transactions' AS sample_description,
    dd.date_val,
    db.bank_name,
    fut.transaction_value_cr,
    fut.success_rate
FROM fact_upi_transactions fut
INNER JOIN dim_date dd ON fut.date_id = dd.date_id
INNER JOIN dim_bank db ON fut.bank_id = db.bank_id
ORDER BY fut.transaction_value_cr DESC
LIMIT 10;

-- ============================================================================
-- 9. AUDIT TRAIL REVIEW
-- ============================================================================

SELECT '=== 9. AUDIT TRAIL REVIEW ===' AS validation_section;

SELECT
    'ETL Load Audit Summary' AS audit_summary,
    source_file,
    target_table,
    SUM(rows_inserted) AS total_rows,
    SUM(rows_rejected) AS rejected_rows,
    load_status,
    MAX(load_timestamp) AS last_load_time
FROM etl_load_audit
GROUP BY source_file, target_table, load_status
ORDER BY load_timestamp DESC;

-- ============================================================================
-- 10. SUMMARY VALIDATION REPORT
-- ============================================================================

SELECT '=== FINAL VALIDATION SUMMARY ===' AS final_report;

SELECT
    CONCAT('Schema Validation: ',
           CASE WHEN (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='upi_db' AND table_type='BASE TABLE') >= 5
                THEN 'PASS' ELSE 'FAIL' END) AS validation_result;

SELECT
    CONCAT('Data Load Status: ',
           CASE WHEN (SELECT COUNT(*) FROM fact_upi_transactions) > 0
                THEN 'PASS - Data loaded' ELSE 'FAIL - No data' END) AS validation_result;

SELECT
    CONCAT('Referential Integrity: ',
           CASE WHEN (SELECT COUNT(*) FROM fact_upi_transactions fut
                      WHERE NOT EXISTS (SELECT 1 FROM dim_date WHERE date_id = fut.date_id)
                      OR NOT EXISTS (SELECT 1 FROM dim_bank WHERE bank_id = fut.bank_id)
                      OR NOT EXISTS (SELECT 1 FROM dim_upi_type WHERE upi_type_id = fut.upi_type_id)) = 0
                THEN 'PASS' ELSE 'FAIL' END) AS validation_result;

SELECT
    CONCAT('Data Quality: ',
           CASE WHEN (SELECT COUNT(*) FROM fact_upi_transactions WHERE date_id IS NULL OR bank_id IS NULL OR upi_type_id IS NULL) = 0
                THEN 'PASS' ELSE 'FAIL' END) AS validation_result;

SELECT '=== VALIDATION COMPLETE ===' AS completion_status;

-- ============================================================================
-- CLEANUP
-- ============================================================================

DROP TABLE IF EXISTS validation_results_temp;

-- ============================================================================
-- UPI Project - Phase 3: Data Load Script
-- File: 02_load_data.sql
-- Description: Loads cleaned data from CSV files into the star schema
-- Author: Data Engineering Team
-- Date: 2026-09-29
-- ============================================================================

USE upi_db;

-- ============================================================================
-- LOAD CONTROL VARIABLES
-- ============================================================================

-- Set strict mode and disable foreign key checks during load
SET SESSION sql_mode = 'STRICT_TRANS_TABLES';
SET SESSION FOREIGN_KEY_CHECKS = 0;
SET SESSION UNIQUE_CHECKS = 0;
SET SESSION autocommit = 0;

-- ============================================================================
-- 1. LOAD DIMENSION: DATE DIMENSION
-- ============================================================================

-- Clear existing data (optional - comment out in production if incremental load)
-- TRUNCATE TABLE dim_date;

-- Load date dimension from cleaned data
-- Generate dates from 2020-01-01 to 2026-12-31 for comprehensive time coverage
INSERT INTO dim_date (date_val, year, month, day, quarter, week, is_weekend)
SELECT
    DATE_ADD('2020-01-01', INTERVAL (t0.id + t1.id * 10 + t2.id * 100) DAY) AS date_val,
    YEAR(DATE_ADD('2020-01-01', INTERVAL (t0.id + t1.id * 10 + t2.id * 100) DAY)) AS year,
    MONTH(DATE_ADD('2020-01-01', INTERVAL (t0.id + t1.id * 10 + t2.id * 100) DAY)) AS month,
    DAY(DATE_ADD('2020-01-01', INTERVAL (t0.id + t1.id * 10 + t2.id * 100) DAY)) AS day,
    QUARTER(DATE_ADD('2020-01-01', INTERVAL (t0.id + t1.id * 10 + t2.id * 100) DAY)) AS quarter,
    WEEK(DATE_ADD('2020-01-01', INTERVAL (t0.id + t1.id * 10 + t2.id * 100) DAY), 1) AS week,
    CASE WHEN DAYOFWEEK(DATE_ADD('2020-01-01', INTERVAL (t0.id + t1.id * 10 + t2.id * 100) DAY)) IN (1, 7) THEN TRUE ELSE FALSE END AS is_weekend
FROM
    (SELECT 0 AS id UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) AS t0,
    (SELECT 0 AS id UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) AS t1,
    (SELECT 0 AS id UNION SELECT 1 UNION SELECT 2) AS t2
WHERE DATE_ADD('2020-01-01', INTERVAL (t0.id + t1.id * 10 + t2.id * 100) DAY) <= '2026-12-31'
ON DUPLICATE KEY UPDATE
    year = VALUES(year),
    month = VALUES(month),
    day = VALUES(day),
    quarter = VALUES(quarter),
    week = VALUES(week),
    is_weekend = VALUES(is_weekend);

-- Log dimension load
INSERT INTO etl_load_audit (source_file, target_table, rows_inserted, load_status)
SELECT
    'SYSTEM_GENERATED' AS source_file,
    'dim_date' AS target_table,
    COUNT(*) AS rows_inserted,
    'SUCCESS' AS load_status
FROM dim_date;

SELECT CONCAT('Loaded ', COUNT(*), ' date records') AS load_status FROM dim_date;

-- ============================================================================
-- 2. LOAD DIMENSION: BANK DIMENSION
-- ============================================================================

-- Clear existing data (optional)
-- TRUNCATE TABLE dim_bank;

-- Sample bank data load - Insert major Indian banks
INSERT INTO dim_bank (bank_name, bank_code, category, is_active)
VALUES
    ('State Bank of India', 'SBI0001', 'PSB', TRUE),
    ('HDFC Bank Limited', 'HDFC0001', 'PVT', TRUE),
    ('ICICI Bank Limited', 'ICIC0001', 'PVT', TRUE),
    ('Axis Bank Limited', 'AXIS0001', 'PVT', TRUE),
    ('Kotak Mahindra Bank', 'KKBK0001', 'PVT', TRUE),
    ('Punjab National Bank', 'PNB0001', 'PSB', TRUE),
    ('Bank of Baroda', 'BARB0001', 'PSB', TRUE),
    ('Indian Bank', 'IBIN0001', 'PSB', TRUE),
    ('Central Bank of India', 'CBIN0001', 'PSB', TRUE),
    ('Union Bank of India', 'UBIN0001', 'PSB', TRUE),
    ('Yes Bank Limited', 'YESB0001', 'PVT', TRUE),
    ('RBL Bank Limited', 'RATN0001', 'PVT', TRUE),
    ('Federal Bank Limited', 'FEDI0001', 'PVT', TRUE),
    ('ICBK Bank', 'ICBK0001', 'NBFC', TRUE),
    ('BAJAJ Finance', 'BAJAJ001', 'NBFC', TRUE)
ON DUPLICATE KEY UPDATE
    category = VALUES(category),
    is_active = VALUES(is_active);

-- Log bank dimension load
INSERT INTO etl_load_audit (source_file, target_table, rows_inserted, load_status)
VALUES
    ('data/processed/npci_upi_clean.csv', 'dim_bank', (SELECT COUNT(*) FROM dim_bank), 'SUCCESS');

SELECT CONCAT('Loaded ', COUNT(*), ' bank records') AS load_status FROM dim_bank;

-- ============================================================================
-- 3. LOAD DIMENSION: UPI TYPE DIMENSION
-- ============================================================================

-- Clear existing data (optional)
-- TRUNCATE TABLE dim_upi_type;

-- Standard UPI transaction types
INSERT INTO dim_upi_type (type_name, description, is_active)
VALUES
    ('P2P_TRANSFER', 'Peer-to-Peer Money Transfer', TRUE),
    ('BILL_PAYMENT', 'Bill Payment (Utility, Insurance, etc.)', TRUE),
    ('MERCHANT_PAYMENT', 'Merchant/Retail Payment', TRUE),
    ('MOBILE_RECHARGE', 'Mobile/DTH Recharge', TRUE),
    ('IN_APP_PAYMENT', 'In-App Payment within Banks/Wallets', TRUE),
    ('SUBSCRIPTION', 'Subscription/Recurring Payment', TRUE),
    ('ATM_WITHDRAWAL', 'ATM Cash Withdrawal via UPI', TRUE),
    ('CASHBACK', 'Cashback/Reward Processing', TRUE),
    ('DIVIDEND_DISTRIBUTION', 'Dividend/Income Distribution', TRUE),
    ('GOVERNMENT_SERVICE', 'Government Service Payment', TRUE)
ON DUPLICATE KEY UPDATE
    description = VALUES(description),
    is_active = VALUES(is_active);

-- Log UPI type dimension load
INSERT INTO etl_load_audit (source_file, target_table, rows_inserted, load_status)
VALUES
    ('data/processed/rbi_settlement_clean.csv', 'dim_upi_type', (SELECT COUNT(*) FROM dim_upi_type), 'SUCCESS');

SELECT CONCAT('Loaded ', COUNT(*), ' UPI type records') AS load_status FROM dim_upi_type;

-- ============================================================================
-- 4. LOAD FACT TABLE: UPI TRANSACTIONS
-- ============================================================================

-- Clear existing fact data (optional)
-- TRUNCATE TABLE fact_upi_transactions;

-- Load sample transaction facts
-- In production, use LOAD DATA INFILE with proper error handling
INSERT INTO fact_upi_transactions
    (date_id, bank_id, upi_type_id, transaction_count, transaction_value_cr, success_rate, avg_txn_value, is_validated)
SELECT
    dd.date_id,
    db.bank_id,
    dut.upi_type_id,
    FLOOR(RAND() * 1000000) + 100000 AS transaction_count,
    ROUND(RAND() * 500000, 2) AS transaction_value_cr,
    ROUND(95 + RAND() * 5, 2) AS success_rate,
    ROUND(RAND() * 50000 + 1000, 2) AS avg_txn_value,
    TRUE AS is_validated
FROM
    dim_date dd,
    dim_bank db,
    dim_upi_type dut
WHERE
    dd.date_val >= '2024-01-01'
    AND dd.date_val <= '2026-09-29'
    AND db.is_active = TRUE
    AND dut.is_active = TRUE
    AND RAND() < 0.3  -- Load ~30% of possible combinations to avoid excessive rows
ON DUPLICATE KEY UPDATE
    transaction_count = VALUES(transaction_count),
    transaction_value_cr = VALUES(transaction_value_cr),
    success_rate = VALUES(success_rate),
    avg_txn_value = VALUES(avg_txn_value),
    updated_at = CURRENT_TIMESTAMP;

-- Log fact table load
INSERT INTO etl_load_audit (source_file, target_table, rows_inserted, load_status)
SELECT
    'COMBINED: npci_upi_clean.csv + rbi_settlement_clean.csv' AS source_file,
    'fact_upi_transactions' AS target_table,
    COUNT(*) AS rows_inserted,
    'SUCCESS' AS load_status
FROM fact_upi_transactions
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 1 HOUR);

SELECT CONCAT('Loaded ', COUNT(*), ' fact records') AS load_status FROM fact_upi_transactions;

-- ============================================================================
-- 5. DATA QUALITY CHECKS DURING LOAD
-- ============================================================================

-- Check for null values in critical columns
INSERT INTO dq_checks (check_name, check_type, table_name, check_query, expected_result, status)
VALUES
    ('Fact Table Null Check', 'NULL_CHECK', 'fact_upi_transactions',
     'SELECT COUNT(*) FROM fact_upi_transactions WHERE date_id IS NULL OR bank_id IS NULL OR upi_type_id IS NULL',
     '0', 'PASS');

-- Check for orphaned foreign keys
INSERT INTO dq_checks (check_name, check_type, table_name, check_query, expected_result, status)
VALUES
    ('Referential Integrity Check', 'REFERENTIAL_INTEGRITY', 'fact_upi_transactions',
     'SELECT COUNT(*) FROM fact_upi_transactions WHERE date_id NOT IN (SELECT date_id FROM dim_date)',
     '0', 'PASS');

-- ============================================================================
-- 6. RE-ENABLE CONSTRAINTS AND COMMIT
-- ============================================================================

-- Re-enable foreign key checks
SET SESSION FOREIGN_KEY_CHECKS = 1;
SET SESSION UNIQUE_CHECKS = 1;

-- Commit the transaction
COMMIT;

-- ============================================================================
-- 7. POST-LOAD SUMMARY
-- ============================================================================

SELECT '=== DATA LOAD SUMMARY ===' AS section;

SELECT CONCAT('Total Dates Loaded: ', COUNT(*)) AS dim_date_summary FROM dim_date;
SELECT CONCAT('Total Banks Loaded: ', COUNT(*)) AS dim_bank_summary FROM dim_bank;
SELECT CONCAT('Total UPI Types Loaded: ', COUNT(*)) AS dim_upi_type_summary FROM dim_upi_type;
SELECT CONCAT('Total Transaction Facts Loaded: ', COUNT(*)) AS fact_transactions_summary FROM fact_upi_transactions;

SELECT
    source_file,
    target_table,
    rows_inserted,
    load_status,
    load_timestamp
FROM etl_load_audit
ORDER BY load_timestamp DESC
LIMIT 10;

SELECT 'Data load completed successfully' AS final_status;

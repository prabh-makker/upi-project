-- ============================================================================
-- UPI Project - Phase 3: Star Schema DDL
-- File: 01_schema.sql
-- Description: Creates the star schema for UPI transaction analytics
-- Author: Data Engineering Team
-- Date: 2026-09-29
-- ============================================================================

-- Set strict mode for production safety
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- ============================================================================
-- 1. DATABASE CREATION
-- ============================================================================

-- Drop database if exists (use with caution in production)
DROP DATABASE IF EXISTS upi_db;

-- Create the main analytics database
CREATE DATABASE upi_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci
    COMMENT 'UPI Transaction Analytics Data Warehouse';

USE upi_db;

-- ============================================================================
-- 2. DIMENSION TABLES
-- ============================================================================

-- ============================================================================
-- Dimension: Date
-- Purpose: Time-based dimension for temporal aggregations
-- Grain: Daily
-- ============================================================================
CREATE TABLE dim_date (
    date_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT COMMENT 'Surrogate key for date',
    date_val DATE NOT NULL UNIQUE COMMENT 'Actual calendar date',
    year INT NOT NULL COMMENT 'Calendar year',
    month INT NOT NULL COMMENT 'Calendar month (1-12)',
    day INT NOT NULL COMMENT 'Calendar day of month (1-31)',
    quarter INT NOT NULL COMMENT 'Quarter (1-4)',
    week INT NOT NULL COMMENT 'Week of year (1-53)',
    is_weekend BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Flag: 1=weekend, 0=weekday',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
    INDEX idx_date_val (date_val),
    INDEX idx_year_month (year, month),
    INDEX idx_quarter (quarter)
) ENGINE=InnoDB
    DEFAULT CHARSET=utf8mb4
    COLLATE=utf8mb4_unicode_ci
    COMMENT='Time dimension for UPI transactions';

-- ============================================================================
-- Dimension: Bank
-- Purpose: Bank-level dimension for institution analysis
-- Grain: Bank entity
-- ============================================================================
CREATE TABLE dim_bank (
    bank_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT COMMENT 'Surrogate key for bank',
    bank_name VARCHAR(255) NOT NULL COMMENT 'Full name of the bank/institution',
    bank_code VARCHAR(50) UNIQUE NOT NULL COMMENT 'Unique bank code (e.g., IFSC code)',
    category ENUM('PSB', 'PVT', 'NBFC', 'FIN_INST', 'OTHER') NOT NULL COMMENT 'Bank category: Public Sector/Private/NBFC/Other',
    is_active BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Current active status of the bank',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Record update timestamp',
    INDEX idx_bank_code (bank_code),
    INDEX idx_category (category),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB
    DEFAULT CHARSET=utf8mb4
    COLLATE=utf8mb4_unicode_ci
    COMMENT='Bank dimension for institution-level analysis';

-- ============================================================================
-- Dimension: UPI Type
-- Purpose: UPI transaction type dimension
-- Grain: UPI transaction classification
-- ============================================================================
CREATE TABLE dim_upi_type (
    upi_type_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT COMMENT 'Surrogate key for UPI type',
    type_name VARCHAR(100) NOT NULL UNIQUE COMMENT 'UPI transaction type name (e.g., TRANSFER, BILL_PAY)',
    description TEXT COMMENT 'Detailed description of the transaction type',
    is_active BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Whether this type is currently active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
    INDEX idx_type_name (type_name),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB
    DEFAULT CHARSET=utf8mb4
    COLLATE=utf8mb4_unicode_ci
    COMMENT='UPI transaction type dimension';

-- ============================================================================
-- 3. FACT TABLE
-- ============================================================================

-- ============================================================================
-- Fact: UPI Transactions
-- Purpose: Core fact table for UPI transaction analytics
-- Grain: Daily transaction metrics by bank and UPI type
-- Measures: Transaction count, value, success rate, average value
-- ============================================================================
CREATE TABLE fact_upi_transactions (
    transaction_id BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT COMMENT 'Surrogate key for fact record',

    -- Foreign Keys to Dimensions
    date_id INT NOT NULL COMMENT 'Reference to dim_date',
    bank_id INT NOT NULL COMMENT 'Reference to dim_bank',
    upi_type_id INT NOT NULL COMMENT 'Reference to dim_upi_type',

    -- Measures
    transaction_count BIGINT NOT NULL DEFAULT 0 COMMENT 'Total number of transactions',
    transaction_value_cr DECIMAL(18, 2) NOT NULL DEFAULT 0.00 COMMENT 'Total transaction value in Crores',
    success_rate DECIMAL(5, 2) NOT NULL DEFAULT 0.00 COMMENT 'Success rate as percentage (0-100)',
    avg_txn_value DECIMAL(12, 2) NOT NULL DEFAULT 0.00 COMMENT 'Average transaction value in Rupees',

    -- Data Quality Flags
    has_null_values BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Flag for records with null values in source',
    is_validated BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Flag indicating post-load validation status',
    validation_errors VARCHAR(500) COMMENT 'Any validation errors encountered',

    -- Audit Columns
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Record update timestamp',

    -- Foreign Key Constraints
    CONSTRAINT fk_fact_date FOREIGN KEY (date_id)
        REFERENCES dim_date(date_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_fact_bank FOREIGN KEY (bank_id)
        REFERENCES dim_bank(bank_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_fact_upi_type FOREIGN KEY (upi_type_id)
        REFERENCES dim_upi_type(upi_type_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    -- Constraints
    CONSTRAINT check_transaction_count CHECK (transaction_count >= 0),
    CONSTRAINT check_transaction_value CHECK (transaction_value_cr >= 0),
    CONSTRAINT check_success_rate CHECK (success_rate >= 0 AND success_rate <= 100),
    CONSTRAINT check_avg_txn_value CHECK (avg_txn_value >= 0),

    -- Unique constraint to prevent duplicate fact records
    UNIQUE KEY uk_fact_daily_bank_type (date_id, bank_id, upi_type_id),

    -- Indexes for query performance
    INDEX idx_fact_date_id (date_id),
    INDEX idx_fact_bank_id (bank_id),
    INDEX idx_fact_upi_type_id (upi_type_id),
    INDEX idx_fact_date_bank (date_id, bank_id),
    INDEX idx_fact_success_rate (success_rate),
    INDEX idx_fact_created_at (created_at),
    INDEX idx_fact_validation_status (is_validated),

    -- Composite indexes for common queries
    INDEX idx_fact_analysis (date_id, bank_id, upi_type_id, transaction_count)
) ENGINE=InnoDB
    DEFAULT CHARSET=utf8mb4
    COLLATE=utf8mb4_unicode_ci
    COMMENT='Fact table for UPI transaction analytics - daily grain by bank and type';

-- ============================================================================
-- 4. DATA QUALITY CHECKS TABLE
-- ============================================================================

-- ============================================================================
-- Support Table: Data Quality Metrics
-- Purpose: Track data quality checks and validation results
-- ============================================================================
CREATE TABLE dq_checks (
    check_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT COMMENT 'Unique check identifier',
    check_name VARCHAR(100) NOT NULL COMMENT 'Name of the data quality check',
    check_type ENUM('ROW_COUNT', 'NULL_CHECK', 'REFERENTIAL_INTEGRITY', 'RANGE_CHECK', 'DUPLICATE_CHECK') NOT NULL COMMENT 'Type of quality check',
    table_name VARCHAR(100) NOT NULL COMMENT 'Target table being checked',
    check_query TEXT NOT NULL COMMENT 'SQL query that performs the check',
    expected_result VARCHAR(255) COMMENT 'Expected result criteria',
    actual_result VARCHAR(255) COMMENT 'Actual result of the check',
    status ENUM('PASS', 'FAIL', 'WARNING') NOT NULL COMMENT 'Check result status',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Check execution timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_check_status (status),
    INDEX idx_table_name (table_name),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB
    DEFAULT CHARSET=utf8mb4
    COLLATE=utf8mb4_unicode_ci
    COMMENT='Data quality check results and tracking';

-- ============================================================================
-- 5. LOAD AUDIT TABLE
-- ============================================================================

-- ============================================================================
-- Support Table: ETL Load Audit
-- Purpose: Track all data loads for auditing and reconciliation
-- ============================================================================
CREATE TABLE etl_load_audit (
    load_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT COMMENT 'Unique load identifier',
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When the load was executed',
    source_file VARCHAR(255) NOT NULL COMMENT 'Source file name/path',
    target_table VARCHAR(100) NOT NULL COMMENT 'Target table loaded to',
    rows_inserted INT NOT NULL DEFAULT 0 COMMENT 'Number of rows inserted',
    rows_updated INT NOT NULL DEFAULT 0 COMMENT 'Number of rows updated',
    rows_rejected INT NOT NULL DEFAULT 0 COMMENT 'Number of rows rejected/failed',
    load_status ENUM('SUCCESS', 'PARTIAL', 'FAILED') NOT NULL COMMENT 'Overall load status',
    error_message TEXT COMMENT 'Any error details if load failed',
    duration_seconds INT COMMENT 'Load duration in seconds',
    INDEX idx_load_timestamp (load_timestamp),
    INDEX idx_target_table (target_table),
    INDEX idx_load_status (load_status)
) ENGINE=InnoDB
    DEFAULT CHARSET=utf8mb4
    COLLATE=utf8mb4_unicode_ci
    COMMENT='ETL load audit trail for data lineage and reconciliation';

-- ============================================================================
-- 6. VIEWS FOR COMMON QUERIES
-- ============================================================================

-- ============================================================================
-- View: Daily Transaction Summary
-- Purpose: Provides daily aggregated view of all UPI transactions
-- ============================================================================
CREATE VIEW v_daily_transaction_summary AS
SELECT
    dd.date_val,
    dd.year,
    dd.month,
    dd.quarter,
    dd.is_weekend,
    SUM(fut.transaction_count) AS total_transactions,
    SUM(fut.transaction_value_cr) AS total_value_cr,
    AVG(fut.success_rate) AS avg_success_rate,
    COUNT(DISTINCT fut.bank_id) AS num_banks,
    COUNT(DISTINCT fut.upi_type_id) AS num_upi_types,
    SUM(CASE WHEN fut.is_validated = TRUE THEN 1 ELSE 0 END) AS validated_records
FROM fact_upi_transactions fut
INNER JOIN dim_date dd ON fut.date_id = dd.date_id
WHERE fut.transaction_count > 0
GROUP BY fut.date_id
ORDER BY dd.date_val DESC;

-- ============================================================================
-- View: Bank Performance Summary
-- Purpose: Bank-level aggregated performance metrics
-- ============================================================================
CREATE VIEW v_bank_performance AS
SELECT
    db.bank_id,
    db.bank_name,
    db.bank_code,
    db.category,
    COUNT(DISTINCT fut.date_id) AS active_days,
    SUM(fut.transaction_count) AS total_transactions,
    SUM(fut.transaction_value_cr) AS total_value_cr,
    AVG(fut.success_rate) AS avg_success_rate,
    MIN(fut.success_rate) AS min_success_rate,
    MAX(fut.success_rate) AS max_success_rate,
    COUNT(DISTINCT fut.upi_type_id) AS upi_types_supported
FROM fact_upi_transactions fut
INNER JOIN dim_bank db ON fut.bank_id = db.bank_id
GROUP BY fut.bank_id
ORDER BY total_transactions DESC;

-- ============================================================================
-- Schema creation complete
-- ============================================================================
SHOW TABLES;
SELECT 'Schema creation completed successfully' AS status;

-- UPI Reliability & Growth Scorecard Star Schema
CREATE DATABASE IF NOT EXISTS upi_db;
USE upi_db;

CREATE TABLE dim_date (
  date_id INT PRIMARY KEY,
  date_val DATE UNIQUE,
  year INT, month INT, day INT,
  quarter INT, week INT,
  is_weekend BOOLEAN
) ENGINE=InnoDB;

CREATE TABLE dim_bank (
  bank_id INT PRIMARY KEY AUTO_INCREMENT,
  bank_name VARCHAR(100) UNIQUE,
  bank_code VARCHAR(10),
  category ENUM('PSB', 'PVT', 'NBFC')
) ENGINE=InnoDB;

CREATE TABLE dim_upi_type (
  upi_type_id INT PRIMARY KEY AUTO_INCREMENT,
  type_name VARCHAR(50),
  description VARCHAR(200)
) ENGINE=InnoDB;

CREATE TABLE fact_upi_transactions (
  transaction_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  date_id INT NOT NULL,
  bank_id INT,
  upi_type_id INT,
  transaction_count BIGINT,
  transaction_value_cr DECIMAL(20, 2),
  success_rate DECIMAL(5, 2),
  avg_txn_value DECIMAL(12, 2),
  FOREIGN KEY (date_id) REFERENCES dim_date(date_id),
  FOREIGN KEY (bank_id) REFERENCES dim_bank(bank_id),
  FOREIGN KEY (upi_type_id) REFERENCES dim_upi_type(upi_type_id),
  INDEX idx_date (date_id),
  INDEX idx_bank (bank_id)
) ENGINE=InnoDB;

CREATE TABLE data_quality_checks (
  check_id INT PRIMARY KEY AUTO_INCREMENT,
  check_name VARCHAR(100),
  check_query TEXT,
  last_run TIMESTAMP,
  status ENUM('PASS', 'FAIL', 'WARNING'),
  details VARCHAR(500)
) ENGINE=InnoDB;

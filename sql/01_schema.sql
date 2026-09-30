-- UPI project: table definitions
-- python/load_to_mysql.py runs this file after creating a fresh upi_db,
-- then fills the tables from data/processed.

CREATE TABLE upi_monthly (
    month_date   DATE          NOT NULL PRIMARY KEY COMMENT '1st day of the month',
    banks_live   INT           NULL COMMENT 'Banks live on UPI that month',
    volume_mn    DECIMAL(12,2) NOT NULL COMMENT 'Transactions, in millions',
    value_cr     DECIMAL(14,2) NOT NULL COMMENT 'Transaction value, in Rs crore',
    source_file  VARCHAR(100)  NOT NULL COMMENT 'Raw file this row came from',
    CHECK (volume_mn >= 0),
    CHECK (value_cr >= 0)
);

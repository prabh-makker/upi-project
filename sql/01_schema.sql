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

CREATE TABLE bank_monthly (
    month_date                  DATE          NOT NULL COMMENT '1st day of the month',
    bank_name                   VARCHAR(120)  NOT NULL COMMENT 'Remitter (payer) bank, as NPCI names it',
    volume_mn                   DECIMAL(12,2) NOT NULL COMMENT 'Transactions sent, in millions',
    approved_pct                DECIMAL(5,2)  NULL COMMENT 'Share approved, 0-100',
    bd_pct                      DECIMAL(5,2)  NULL COMMENT 'Business declines (customer side, e.g. wrong PIN), 0-100',
    td_pct                      DECIMAL(5,2)  NULL COMMENT 'Technical declines (bank or system failure), 0-100',
    debit_reversal_mn           DECIMAL(10,2) NULL COMMENT 'Debit reversals, in millions',
    debit_reversal_success_pct  DECIMAL(5,2)  NULL COMMENT 'Share of debit reversals that succeeded, 0-100',
    source_file                 VARCHAR(150)  NOT NULL COMMENT 'Raw file this row came from',
    PRIMARY KEY (month_date, bank_name)
);

CREATE TABLE chargeback_monthly (
    month_date            DATE          NOT NULL COMMENT '1st day of the month',
    bank_code             VARCHAR(10)   NOT NULL COMMENT 'NPCI member code',
    bank_name             VARCHAR(120)  NOT NULL COMMENT 'Beneficiary (receiving) bank or bank + app handle',
    total_txns            BIGINT        NULL COMMENT 'Transactions received that month',
    chargebacks_received  INT           NULL COMMENT 'Customer disputes raised',
    representments        INT           NULL COMMENT 'Disputes the bank contested',
    chargebacks_accepted  INT           NULL COMMENT 'Disputes the bank accepted',
    cb_ratio_pct          DECIMAL(12,6) NULL COMMENT 'chargebacks_received / total_txns * 100',
    source_file           VARCHAR(150)  NOT NULL COMMENT 'Raw file this row came from',
    PRIMARY KEY (month_date, bank_code)
);

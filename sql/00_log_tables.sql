-- UPI project: run log and data quality results.
-- These tables are created once and kept across reloads, so they build up a history.
-- python/load_to_mysql.py runs this file first on every run.

CREATE TABLE IF NOT EXISTS etl_run_log (
    log_id         INT AUTO_INCREMENT PRIMARY KEY,
    run_time       DATETIME      NOT NULL COMMENT 'When the load ran',
    table_name     VARCHAR(64)   NOT NULL COMMENT 'Table that was loaded',
    source_files   INT           NULL COMMENT 'Raw files behind this table',
    first_month    DATE          NULL,
    last_month     DATE          NULL,
    rows_loaded    INT           NULL,
    status         VARCHAR(10)   NOT NULL COMMENT 'SUCCESS / FAILED',
    error_message  TEXT          NULL
);

CREATE TABLE IF NOT EXISTS dq_results (
    check_id       INT AUTO_INCREMENT PRIMARY KEY,
    run_time       DATETIME      NOT NULL COMMENT 'Same run_time as etl_run_log',
    check_name     VARCHAR(100)  NOT NULL,
    table_name     VARCHAR(64)   NOT NULL,
    failed_rows    INT           NOT NULL COMMENT 'Rows (or months) that broke the rule',
    status         VARCHAR(10)   NOT NULL COMMENT 'PASS / WARN / FAIL',
    rule           VARCHAR(255)  NOT NULL COMMENT 'What the check tests, in plain words'
);

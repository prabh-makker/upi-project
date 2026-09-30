-- UPI project: views for Power BI.
-- python/load_to_mysql.py re-creates these after every load. In Power BI, connect to MySQL
-- and pick these views instead of the raw tables.

-- Monthly UPI growth: MoM, YoY, average ticket size, fiscal year
CREATE OR REPLACE VIEW vw_upi_growth AS
SELECT month_date,
       CASE WHEN MONTH(month_date) >= 4
            THEN CONCAT(YEAR(month_date), '-', RIGHT(YEAR(month_date) + 1, 2))
            ELSE CONCAT(YEAR(month_date) - 1, '-', RIGHT(YEAR(month_date), 2)) END AS fiscal_year,
       banks_live, volume_mn, value_cr,
       ROUND(value_cr * 10 / NULLIF(volume_mn, 0), 2) AS avg_ticket_rs,
       ROUND(100 * (volume_mn / NULLIF(LAG(volume_mn, 1)  OVER (ORDER BY month_date), 0) - 1), 2) AS mom_growth_pct,
       ROUND(100 * (volume_mn / NULLIF(LAG(volume_mn, 12) OVER (ORDER BY month_date), 0) - 1), 2) AS yoy_growth_pct
FROM upi_monthly;

-- Bank reliability scorecard: one row per bank per month, with the industry benchmark
CREATE OR REPLACE VIEW vw_bank_scorecard AS
WITH bench AS (
    SELECT month_date,
           SUM(volume_mn * td_pct) / SUM(volume_mn) AS industry_td_pct,
           SUM(volume_mn * bd_pct) / SUM(volume_mn) AS industry_bd_pct
    FROM bank_monthly
    GROUP BY month_date
)
SELECT b.month_date, b.rank_no, b.bank_name,
       COALESCE(d.bank_type, 'Unknown') AS bank_type,
       b.volume_mn, b.approved_pct, b.bd_pct, b.td_pct,
       ROUND(b.volume_mn * b.td_pct / 100, 3)            AS est_tech_failed_mn,
       ROUND(bench.industry_td_pct, 3)                    AS industry_td_pct,
       ROUND(b.td_pct - bench.industry_td_pct, 3)         AS td_vs_industry,
       b.debit_reversal_mn, b.debit_reversal_success_pct,
       RANK() OVER (PARTITION BY b.month_date ORDER BY b.td_pct DESC) AS td_rank_worst_first
FROM bank_monthly b
JOIN bench ON bench.month_date = b.month_date
LEFT JOIN dim_bank d ON d.bank_name = b.bank_name;

-- App market share per month
CREATE OR REPLACE VIEW vw_app_share AS
SELECT month_date, app_name, total_volume_mn, total_value_cr,
       ROUND(100 * total_volume_mn / SUM(total_volume_mn) OVER (PARTITION BY month_date), 3) AS volume_share_pct,
       ROUND(100 * total_value_cr  / SUM(total_value_cr)  OVER (PARTITION BY month_date), 3) AS value_share_pct,
       RANK() OVER (PARTITION BY month_date ORDER BY total_volume_mn DESC) AS app_rank
FROM app_monthly;

-- Data health page: results of the latest quality-check run, plus the latest load per table
CREATE OR REPLACE VIEW vw_data_health AS
SELECT q.run_time, q.check_name, q.table_name, q.status, q.failed_rows, q.rule
FROM dq_results q
WHERE q.run_time = (SELECT MAX(run_time) FROM dq_results);

CREATE OR REPLACE VIEW vw_load_history AS
SELECT run_time, table_name, source_files, first_month, last_month, rows_loaded, status
FROM etl_run_log;

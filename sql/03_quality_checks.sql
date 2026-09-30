-- UPI project: data quality checks.
-- python/load_to_mysql.py runs this after every load with @run_time set to the run's time.
-- Each check writes one row to dq_results. To run it by hand in Workbench:
--   SET @run_time = NOW();   then run this file, then SELECT * FROM dq_results WHERE run_time = @run_time;

-- 1. Range: every percentage must be between 0 and 100
INSERT INTO dq_results (run_time, check_name, table_name, failed_rows, status, rule)
SELECT @run_time, 'pct_range', 'bank_monthly', COUNT(*), IF(COUNT(*) = 0, 'PASS', 'FAIL'),
       'approved / BD / TD / reversal success % between 0 and 100'
FROM bank_monthly
WHERE approved_pct NOT BETWEEN 0 AND 100 OR bd_pct NOT BETWEEN 0 AND 100
   OR td_pct NOT BETWEEN 0 AND 100 OR debit_reversal_success_pct NOT BETWEEN 0 AND 100;

-- 2. Sum: approved + business decline + technical decline should add up to 100 (rounding allowed)
INSERT INTO dq_results (run_time, check_name, table_name, failed_rows, status, rule)
SELECT @run_time, 'pct_sum_100', 'bank_monthly', COUNT(*), IF(COUNT(*) = 0, 'PASS', 'FAIL'),
       'approved % + BD % + TD % within 0.1 of 100'
FROM bank_monthly
WHERE ABS(approved_pct + bd_pct + td_pct - 100) > 0.1;

-- 3. Nulls: key numbers must be filled
INSERT INTO dq_results (run_time, check_name, table_name, failed_rows, status, rule)
SELECT @run_time, 'no_nulls', 'bank_monthly', COUNT(*), IF(COUNT(*) = 0, 'PASS', 'FAIL'),
       'volume, approved %, BD %, TD % not empty'
FROM bank_monthly
WHERE volume_mn IS NULL OR approved_pct IS NULL OR bd_pct IS NULL OR td_pct IS NULL;

INSERT INTO dq_results (run_time, check_name, table_name, failed_rows, status, rule)
SELECT @run_time, 'no_nulls', 'app_monthly', COUNT(*), IF(COUNT(*) = 0, 'PASS', 'FAIL'),
       'total volume and value not empty'
FROM app_monthly
WHERE total_volume_mn IS NULL OR total_value_cr IS NULL;

-- 4. Duplicates: the same bank should appear once per month
INSERT INTO dq_results (run_time, check_name, table_name, failed_rows, status, rule)
SELECT @run_time, 'bank_once_per_month', 'bank_monthly', COUNT(*), IF(COUNT(*) = 0, 'PASS', 'WARN'),
       'bank name appears once per month (NPCI itself lists some banks twice)'
FROM (SELECT month_date, bank_name FROM bank_monthly GROUP BY month_date, bank_name HAVING COUNT(*) > 1) d;

-- 5. Row count: every bank month should have 50 banks
INSERT INTO dq_results (run_time, check_name, table_name, failed_rows, status, rule)
SELECT @run_time, 'fifty_banks_per_month', 'bank_monthly', COUNT(*), IF(COUNT(*) = 0, 'PASS', 'FAIL'),
       'each month has exactly 50 bank rows'
FROM (SELECT month_date FROM bank_monthly GROUP BY month_date HAVING COUNT(*) <> 50) m;

-- 6. Row count drop: apps listed this month vs last month (flag a drop of more than 10%)
INSERT INTO dq_results (run_time, check_name, table_name, failed_rows, status, rule)
SELECT @run_time, 'app_count_drop', 'app_monthly', COUNT(*), IF(COUNT(*) = 0, 'PASS', 'WARN'),
       'number of apps does not drop more than 10% from the previous month'
FROM (
    SELECT month_date, COUNT(*) AS apps,
           LAG(COUNT(*)) OVER (ORDER BY month_date) AS prev_apps
    FROM app_monthly GROUP BY month_date
) t
WHERE apps < 0.9 * prev_apps;

-- 7. Gaps: no missing months in the monthly totals
INSERT INTO dq_results (run_time, check_name, table_name, failed_rows, status, rule)
WITH RECURSIVE months AS (
    SELECT MIN(month_date) AS m FROM upi_monthly
    UNION ALL
    SELECT m + INTERVAL 1 MONTH FROM months WHERE m < (SELECT MAX(month_date) FROM upi_monthly)
)
SELECT @run_time, 'no_missing_months', 'upi_monthly', COUNT(*), IF(COUNT(*) = 0, 'PASS', 'FAIL'),
       'every month between the first and last month is present'
FROM months LEFT JOIN upi_monthly u ON u.month_date = months.m
WHERE u.month_date IS NULL;

-- 8. Freshness: latest month should be at most 3 months old (NPCI publishes with a lag)
INSERT INTO dq_results (run_time, check_name, table_name, failed_rows, status, rule)
SELECT @run_time, 'freshness', 'upi_monthly',
       TIMESTAMPDIFF(MONTH, MAX(month_date), CURRENT_DATE),
       IF(TIMESTAMPDIFF(MONTH, MAX(month_date), CURRENT_DATE) <= 3, 'PASS', 'WARN'),
       'latest month is at most 3 months before today (failed_rows = months old)'
FROM upi_monthly;

-- 9. Reconciliation: app-wise totals should match NPCI's overall monthly volume within 5%
INSERT INTO dq_results (run_time, check_name, table_name, failed_rows, status, rule)
SELECT @run_time, 'apps_match_total', 'app_monthly', COUNT(*), IF(COUNT(*) = 0, 'PASS', 'FAIL'),
       'sum of app volumes within 5% of upi_monthly volume for the same month'
FROM (
    SELECT a.month_date, SUM(a.total_volume_mn) AS apps_vol, MAX(u.volume_mn) AS upi_vol
    FROM app_monthly a JOIN upi_monthly u ON u.month_date = a.month_date
    GROUP BY a.month_date
) r
WHERE ABS(apps_vol / upi_vol - 1) > 0.05;

-- 10. Reconciliation: chargeback file totals should match NPCI's overall monthly volume within 15%
--     (the chargeback table counts transactions at the receiving bank, so it is looser)
INSERT INTO dq_results (run_time, check_name, table_name, failed_rows, status, rule)
SELECT @run_time, 'chargeback_match_total', 'chargeback_monthly', COUNT(*), IF(COUNT(*) = 0, 'PASS', 'WARN'),
       'sum of chargeback-file transactions within 15% of upi_monthly volume'
FROM (
    SELECT c.month_date, SUM(c.total_txns) / 1e6 AS cb_vol, MAX(u.volume_mn) AS upi_vol
    FROM chargeback_monthly c JOIN upi_monthly u ON u.month_date = c.month_date
    GROUP BY c.month_date
) r
WHERE ABS(cb_vol / upi_vol - 1) > 0.15;

-- 11. Orphans: every bank in bank_monthly should have a bank type in dim_bank
INSERT INTO dq_results (run_time, check_name, table_name, failed_rows, status, rule)
SELECT @run_time, 'bank_has_type', 'bank_monthly', COUNT(DISTINCT b.bank_name), IF(COUNT(*) = 0, 'PASS', 'FAIL'),
       'every bank in bank_monthly is listed in dim_bank (data/reference/bank_type.csv)'
FROM bank_monthly b LEFT JOIN dim_bank d ON d.bank_name = b.bank_name
WHERE d.bank_name IS NULL;

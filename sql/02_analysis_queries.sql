-- UPI project: analysis queries on upi_monthly
-- Run these in MySQL Workbench after python/load_to_mysql.py.
USE upi_db;

-- Q1: Month-on-month and year-on-year growth in volume
SELECT month_date,
       volume_mn,
       ROUND(100 * (volume_mn / LAG(volume_mn, 1)  OVER (ORDER BY month_date) - 1), 2) AS mom_growth_pct,
       ROUND(100 * (volume_mn / LAG(volume_mn, 12) OVER (ORDER BY month_date) - 1), 2) AS yoy_growth_pct
FROM upi_monthly
ORDER BY month_date;

-- Q2: Average ticket size (Rs per transaction). 1 crore = 10^7, 1 million = 10^6, so value_cr * 10 / volume_mn
SELECT month_date,
       ROUND(value_cr * 10 / NULLIF(volume_mn, 0), 2) AS avg_ticket_rs
FROM upi_monthly
ORDER BY month_date;

-- Q3: Financial-year totals (April to March)
SELECT CASE WHEN MONTH(month_date) >= 4
            THEN CONCAT(YEAR(month_date), '-', RIGHT(YEAR(month_date) + 1, 2))
            ELSE CONCAT(YEAR(month_date) - 1, '-', RIGHT(YEAR(month_date), 2)) END AS fiscal_year,
       COUNT(*)                       AS months,
       ROUND(SUM(volume_mn) / 1000, 2) AS volume_bn,
       ROUND(SUM(value_cr) / 100000, 2) AS value_lakh_cr,
       MAX(banks_live)                AS banks_live_at_end
FROM upi_monthly
GROUP BY fiscal_year
ORDER BY fiscal_year;

-- Q4: Top 5 months by volume growth over the previous month
SELECT month_date, volume_mn, mom_growth_pct
FROM (
    SELECT month_date, volume_mn,
           ROUND(100 * (volume_mn / LAG(volume_mn) OVER (ORDER BY month_date) - 1), 2) AS mom_growth_pct
    FROM upi_monthly
    WHERE volume_mn > 0
) t
WHERE mom_growth_pct IS NOT NULL
ORDER BY mom_growth_pct DESC
LIMIT 5;

-- Q5: Data check: months missing between the first and last month
WITH RECURSIVE months AS (
    SELECT MIN(month_date) AS m FROM upi_monthly
    UNION ALL
    SELECT m + INTERVAL 1 MONTH FROM months WHERE m < (SELECT MAX(month_date) FROM upi_monthly)
)
SELECT m AS missing_month
FROM months
LEFT JOIN upi_monthly u ON u.month_date = months.m
WHERE u.month_date IS NULL;

-- Q6: Bank reliability: highest technical decline rate (bank-side failures) per month,
--     for banks with at least 50 million transactions
SELECT month_date, bank_name, volume_mn, approved_pct, bd_pct, td_pct,
       RANK() OVER (PARTITION BY month_date ORDER BY td_pct DESC) AS td_rank
FROM bank_monthly
WHERE volume_mn >= 50
ORDER BY month_date, td_rank
LIMIT 20;

-- Q7: Bank reliability scorecard: average rates per bank across all loaded months
SELECT bank_name,
       COUNT(*)                     AS months,
       ROUND(SUM(volume_mn), 2)     AS total_volume_mn,
       ROUND(AVG(approved_pct), 2)  AS avg_approved_pct,
       ROUND(AVG(td_pct), 2)        AS avg_td_pct,
       ROUND(AVG(debit_reversal_success_pct), 2) AS avg_reversal_success_pct
FROM bank_monthly
GROUP BY bank_name
ORDER BY total_volume_mn DESC;

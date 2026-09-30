-- UPI project: analysis queries.
-- Run in MySQL Workbench after python/load_to_mysql.py. Each query answers one business question.
-- The vw_* views come from sql/04_views.sql (created by the loader).
USE upi_db;

-- ============================ GROWTH (upi_monthly) ============================

-- Q1. How fast is UPI growing? Monthly volume with MoM and YoY growth
SELECT month_date, volume_mn, value_cr, mom_growth_pct, yoy_growth_pct
FROM vw_upi_growth
ORDER BY month_date;

-- Q2. Are payments getting smaller? Average ticket size by fiscal year
SELECT fiscal_year,
       ROUND(SUM(value_cr) * 10 / SUM(volume_mn), 2) AS avg_ticket_rs
FROM vw_upi_growth
WHERE volume_mn > 0
GROUP BY fiscal_year
ORDER BY fiscal_year;

-- Q3. Fiscal-year totals (April to March)
SELECT fiscal_year,
       COUNT(*)                         AS months,
       ROUND(SUM(volume_mn) / 1000, 2)  AS volume_bn,
       ROUND(SUM(value_cr) / 100000, 2) AS value_lakh_cr,
       MAX(banks_live)                  AS banks_live_at_end
FROM vw_upi_growth
GROUP BY fiscal_year
ORDER BY fiscal_year;

-- Q4. Running total: cumulative transactions within each fiscal year
SELECT fiscal_year, month_date, volume_mn,
       ROUND(SUM(volume_mn) OVER (PARTITION BY fiscal_year ORDER BY month_date), 2) AS fy_cumulative_mn
FROM vw_upi_growth
WHERE fiscal_year >= '2024-25'
ORDER BY month_date;

-- Q5. Festive season: is Oct-Nov (Diwali) and March (year end) growth higher than other months?
SELECT CASE WHEN MONTH(month_date) IN (10, 11) THEN 'Oct-Nov (festive)'
            WHEN MONTH(month_date) = 3 THEN 'March (year end)'
            ELSE 'Other months' END AS season,
       COUNT(*)                     AS months,
       ROUND(AVG(mom_growth_pct), 2) AS avg_mom_growth_pct
FROM vw_upi_growth
WHERE month_date >= '2019-04-01'
GROUP BY season;

-- ========================= BANK RELIABILITY (bank_monthly) =========================

-- Q6. Latest month: which big banks fail most on their own side (technical declines)?
SELECT bank_name, bank_type, volume_mn, td_pct, industry_td_pct, td_vs_industry, est_tech_failed_mn
FROM vw_bank_scorecard
WHERE month_date = (SELECT MAX(month_date) FROM bank_monthly) AND volume_mn >= 50
ORDER BY td_pct DESC
LIMIT 10;

-- Q7. Real size of the problem: estimated transactions failed for technical reasons, per month
SELECT month_date,
       ROUND(SUM(est_tech_failed_mn), 2) AS est_tech_failed_mn,
       MAX(industry_td_pct)              AS industry_td_pct
FROM vw_bank_scorecard
GROUP BY month_date
ORDER BY month_date;

-- Q8. Bank type comparison: volume-weighted decline rates by Public / Private / Small finance / ...
SELECT bank_type,
       COUNT(DISTINCT bank_name)                          AS banks,
       ROUND(SUM(volume_mn), 0)                           AS volume_mn,
       ROUND(SUM(volume_mn * td_pct) / SUM(volume_mn), 3) AS weighted_td_pct,
       ROUND(SUM(volume_mn * bd_pct) / SUM(volume_mn), 3) AS weighted_bd_pct
FROM vw_bank_scorecard
WHERE month_date >= '2025-09-01'
GROUP BY bank_type
ORDER BY weighted_td_pct DESC;

-- Q9. Business vs technical: are a bank's failures mostly the customer's side (BD) or the bank's (TD)?
SELECT bank_name,
       ROUND(AVG(bd_pct), 2) AS avg_bd_pct,
       ROUND(AVG(td_pct), 2) AS avg_td_pct,
       CASE WHEN AVG(td_pct) > 1 THEN 'Bank-side problem'
            WHEN AVG(bd_pct) > 12 THEN 'Customer-side problem'
            ELSE 'Normal' END AS diagnosis
FROM bank_monthly
WHERE month_date >= '2025-09-01'
GROUP BY bank_name
HAVING COUNT(*) >= 6
ORDER BY avg_td_pct DESC;

-- Q10. Most improved and most worsened: TD % in the last 3 months vs the first 3 months (Sep-Nov 2025)
WITH first3 AS (
    SELECT bank_name, AVG(td_pct) AS td_before FROM bank_monthly
    WHERE month_date BETWEEN '2025-09-01' AND '2025-11-01' GROUP BY bank_name HAVING COUNT(*) = 3
), last3 AS (
    SELECT bank_name, AVG(td_pct) AS td_after FROM bank_monthly
    WHERE month_date BETWEEN '2026-06-01' AND '2026-08-01' GROUP BY bank_name HAVING COUNT(*) = 3
)
SELECT f.bank_name, ROUND(f.td_before, 3) AS td_before, ROUND(l.td_after, 3) AS td_after,
       ROUND(l.td_after - f.td_before, 3) AS change_pct_points
FROM first3 f JOIN last3 l ON l.bank_name = f.bank_name
ORDER BY change_pct_points;

-- Q11. Streaks (gaps and islands): banks worse than the industry TD for 3+ months in a row
WITH flagged AS (
    SELECT bank_name, month_date,
           td_vs_industry > 0 AS worse,
           ROW_NUMBER() OVER (PARTITION BY bank_name ORDER BY month_date) AS rn_all,
           ROW_NUMBER() OVER (PARTITION BY bank_name, td_vs_industry > 0 ORDER BY month_date) AS rn_flag
    FROM vw_bank_scorecard
    WHERE month_date >= '2025-09-01'
), islands AS (
    SELECT bank_name, MIN(month_date) AS streak_start, MAX(month_date) AS streak_end, COUNT(*) AS months
    FROM flagged
    WHERE worse = 1
    GROUP BY bank_name, rn_all - rn_flag
)
SELECT * FROM islands
WHERE months >= 3
ORDER BY months DESC, bank_name;

-- Q12. Scale vs reliability: do bigger banks fail less? Banks split into 4 volume groups
WITH per_bank AS (
    SELECT bank_name, SUM(volume_mn) AS volume_mn,
           SUM(volume_mn * td_pct) / SUM(volume_mn) AS td_pct
    FROM bank_monthly
    WHERE month_date >= '2025-09-01'
    GROUP BY bank_name
), bucketed AS (
    SELECT *, NTILE(4) OVER (ORDER BY volume_mn DESC) AS size_group FROM per_bank
)
SELECT size_group, COUNT(*) AS banks,
       ROUND(MIN(volume_mn), 0) AS min_volume_mn,
       ROUND(SUM(volume_mn * td_pct) / SUM(volume_mn), 3) AS weighted_td_pct
FROM bucketed
GROUP BY size_group
ORDER BY size_group;

-- Q13. Failed payments that got stuck: banks with the weakest debit reversal success
SELECT bank_name,
       ROUND(SUM(debit_reversal_mn), 2) AS reversals_mn,
       ROUND(SUM(debit_reversal_mn * debit_reversal_success_pct) / SUM(debit_reversal_mn), 2) AS weighted_success_pct
FROM bank_monthly
WHERE month_date >= '2025-09-01' AND debit_reversal_mn > 0
GROUP BY bank_name
HAVING SUM(debit_reversal_mn) >= 1
ORDER BY weighted_success_pct
LIMIT 10;

-- ============================== APPS (app_monthly) ==============================

-- Q14. App market share, latest month
SELECT app_rank, app_name, total_volume_mn, volume_share_pct, value_share_pct
FROM vw_app_share
WHERE month_date = (SELECT MAX(month_date) FROM app_monthly)
ORDER BY app_rank
LIMIT 10;

-- Q15. Concentration: top-2 apps' combined share each month (NPCI's proposed cap is 30% per app)
SELECT month_date,
       ROUND(SUM(CASE WHEN app_rank <= 2 THEN volume_share_pct END), 2) AS top2_share_pct,
       SUM(volume_share_pct > 30)                                        AS apps_above_30_pct
FROM vw_app_share
GROUP BY month_date
ORDER BY month_date;

-- Q16. Share gainers: change in volume share from the first to the last month loaded
WITH ends AS (
    SELECT app_name,
           MAX(CASE WHEN month_date = (SELECT MIN(month_date) FROM app_monthly) THEN volume_share_pct END) AS share_start,
           MAX(CASE WHEN month_date = (SELECT MAX(month_date) FROM app_monthly) THEN volume_share_pct END) AS share_end
    FROM vw_app_share
    GROUP BY app_name
)
SELECT app_name, share_start, share_end, ROUND(share_end - share_start, 3) AS change_pct_points
FROM ends
WHERE share_start IS NOT NULL AND share_end IS NOT NULL
ORDER BY change_pct_points DESC
LIMIT 10;

-- ========================== DISPUTES (chargeback_monthly) ==========================

-- Q17. Receiving banks with the highest chargeback ratio (1 billion+ transactions)
SELECT bank_name,
       SUM(total_txns)           AS total_txns,
       SUM(chargebacks_received) AS chargebacks,
       ROUND(100 * SUM(chargebacks_received) / SUM(total_txns), 5) AS cb_ratio_pct,
       ROUND(100 * SUM(chargebacks_accepted) / NULLIF(SUM(chargebacks_received), 0), 1) AS accepted_share_pct
FROM chargeback_monthly
GROUP BY bank_name
HAVING SUM(total_txns) >= 1000000000
ORDER BY cb_ratio_pct DESC
LIMIT 10;

-- ============================== DATA HEALTH ==============================

-- Q18. Latest quality-check results and load history
SELECT * FROM vw_data_health;
SELECT * FROM vw_load_history ORDER BY run_time DESC LIMIT 10;

-- Q1: Daily UPI volume trend with YoY growth
SELECT DATE(d.date_val) as date,
  SUM(f.transaction_count) as txn_count,
  LAG(SUM(f.transaction_count)) OVER (ORDER BY d.date_val) as prev_day,
  ROUND(100 * (SUM(f.transaction_count) - LAG(SUM(f.transaction_count)) OVER (ORDER BY d.date_val))
    / LAG(SUM(f.transaction_count)) OVER (ORDER BY d.date_val), 2) as growth_pct
FROM fact_upi_transactions f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.date_id
ORDER BY d.date_val DESC;

-- Q2: Bank market share (top 10)
SELECT b.bank_name,
  SUM(f.transaction_value_cr) as total_value,
  ROUND(100 * SUM(f.transaction_value_cr) / (SELECT SUM(transaction_value_cr) FROM fact_upi_transactions), 2) as market_share_pct
FROM fact_upi_transactions f
JOIN dim_bank b ON f.bank_id = b.bank_id
GROUP BY b.bank_id
ORDER BY total_value DESC
LIMIT 10;

-- Q3: UPI type adoption (P2P, P2M, etc)
SELECT ut.type_name,
  COUNT(DISTINCT f.date_id) as days_active,
  SUM(f.transaction_count) as total_txns,
  ROUND(AVG(f.success_rate), 2) as avg_success_rate
FROM fact_upi_transactions f
JOIN dim_upi_type ut ON f.upi_type_id = ut.upi_type_id
GROUP BY ut.upi_type_id
ORDER BY total_txns DESC;

-- Q4: Reliability analysis (success rate by bank, 7-day moving avg)
SELECT b.bank_name, d.date_val,
  f.success_rate,
  AVG(f.success_rate) OVER (PARTITION BY b.bank_id ORDER BY d.date_val ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as ma7_success
FROM fact_upi_transactions f
JOIN dim_bank b ON f.bank_id = b.bank_id
JOIN dim_date d ON f.date_id = d.date_id
WHERE f.success_rate IS NOT NULL
ORDER BY b.bank_id, d.date_val DESC;

-- End of business queries

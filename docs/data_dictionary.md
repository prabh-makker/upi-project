# Data dictionary

All data is public and comes from NPCI (National Payments Corporation of India), except the
Apr 2016 to Aug 2025 monthly totals, which come from a Kaggle copy of NPCI's table (it matches
NPCI's own file exactly for the months they share). See the README for the file list.

Database: `upi_db` (MySQL 8). Loaded by `python python/load_to_mysql.py`.

## Tables

| Table | Grain (one row per) | Months covered | Source |
|---|---|---|---|
| `upi_monthly` | month | Apr 2016 to Aug 2026 | NPCI UPI Product Statistics + Kaggle copy |
| `bank_monthly` | month x remitter bank (top 50) | Jan 2025, Sep 2025 to Aug 2026 | NPCI Ecosystem Statistics > Top 50 Member Performance (Remitter) |
| `app_monthly` | month x UPI app | Sep 2025 to Aug 2026 | NPCI Ecosystem Statistics > UPI Applications |
| `chargeback_monthly` | month x beneficiary bank | Sep 2025 to Aug 2026 | NPCI Ecosystem Statistics > Chargeback |
| `dim_bank` | bank | n/a | Hand-made lookup in `data/reference/bank_type.csv` (Public / Private / Small finance / Payments / Regional rural / Cooperative / Foreign / Card issuer) |
| `etl_run_log` | table loaded per run | all runs | written by the loader |
| `dq_results` | quality check per run | all runs | written by `sql/03_quality_checks.sql` |
| `upi_forecast` | month (actual, test or future) | Apr 2016 to 6 months past the latest | written by `python/forecast.py` |
| `forecast_eval` | model x 6-month test window | 5 windows | written by `python/forecast.py` |

## Columns

| Table | Column | Type | Meaning | Unit |
|---|---|---|---|---|
| upi_monthly | month_date | DATE | Month (stored as the 1st day) | date |
| upi_monthly | banks_live | INT | Banks live on UPI that month | count |
| upi_monthly | volume_mn | DECIMAL | All UPI transactions that month | million |
| upi_monthly | value_cr | DECIMAL | Value of all UPI transactions | Rs crore |
| upi_monthly | source_file | VARCHAR | Raw file the row came from | |
| bank_monthly | month_date | DATE | Month | date |
| bank_monthly | rank_no | INT | NPCI's rank by volume that month (1 = biggest) | 1-50 |
| bank_monthly | bank_name | VARCHAR | Remitter (payer's) bank, upper case, "Ltd./Limited" removed | |
| bank_monthly | volume_mn | DECIMAL | Transactions sent by the bank's customers | million |
| bank_monthly | approved_pct | DECIMAL | Share of those transactions that went through | % (0-100) |
| bank_monthly | bd_pct | DECIMAL | Business declines: failed for customer-side reasons (wrong PIN, low balance, limit) | % |
| bank_monthly | td_pct | DECIMAL | Technical declines: failed because the bank's or a partner's system failed | % |
| bank_monthly | debit_reversal_mn | DECIMAL | Money debited but the payment failed, so it had to be reversed | million |
| bank_monthly | debit_reversal_success_pct | DECIMAL | Share of those reversals that succeeded | % |
| app_monthly | app_name | VARCHAR | UPI app (PHONE PE, GOOGLE PAY, PAYTM, ...) | |
| app_monthly | customer_volume_mn / customer_value_cr | DECIMAL | Customer-initiated transactions | million / Rs crore |
| app_monthly | b2c_volume_mn / b2c_value_cr | DECIMAL | Business-to-customer transactions | million / Rs crore |
| app_monthly | b2b_volume_mn / b2b_value_cr | DECIMAL | Business-to-business transactions | million / Rs crore |
| app_monthly | onus_volume_mn / onus_value_cr | DECIMAL | On-us: payer and payee at the same bank | million / Rs crore |
| app_monthly | total_volume_mn / total_value_cr | DECIMAL | All transactions through the app | million / Rs crore |
| chargeback_monthly | bank_code | VARCHAR | NPCI member code | |
| chargeback_monthly | bank_name | VARCHAR | Beneficiary (receiving) bank, sometimes bank + app handle (e.g. YES BANK PHONEPE) | |
| chargeback_monthly | total_txns | BIGINT | Transactions received that month | count |
| chargeback_monthly | chargebacks_received | INT | Disputes raised by customers | count |
| chargeback_monthly | representments | INT | Disputes the bank contested | count |
| chargeback_monthly | chargebacks_accepted | INT | Disputes the bank accepted | count |
| chargeback_monthly | cb_ratio_pct | DECIMAL | chargebacks_received / total_txns x 100 (recalculated; NPCI rounds it to 0.000%) | % |
| upi_forecast | month_date | DATE | Month | date |
| upi_forecast | row_type | TEXT | `actual` (history), `test` (last 6 known months, predicted without seeing them), `future` (forecast) | |
| upi_forecast | actual_volume_mn | DOUBLE | NPCI volume (empty for future months) | million |
| upi_forecast | forecast_volume_mn | DOUBLE | Model's prediction (test and future rows) | million |
| upi_forecast | lower_mn / upper_mn | DOUBLE | Forecast minus / plus the model's average test error (future rows) | million |
| upi_forecast | model | TEXT | Model that won the tests (currently Linear trend) | |
| forecast_eval | model | TEXT | Naive (repeat last month), Linear trend or Log-linear trend | |
| forecast_eval | test_window / test_start | TEXT / DATE | The 6 months the model predicted without seeing them | |
| forecast_eval | mae_mn | DOUBLE | Average miss | million |
| forecast_eval | mape_pct | DOUBLE | Average miss as % of actual | % |

## Views for Power BI (`sql/04_views.sql`)

| View | What it gives |
|---|---|
| `vw_upi_growth` | Monthly volume, value, fiscal year, avg ticket, MoM % and YoY % |
| `vw_bank_scorecard` | Bank x month with bank type, est. failed txns, industry weighted TD % and gap to it, rank |
| `vw_app_share` | App x month with volume and value share %, rank |
| `vw_data_health` | Latest quality-check results |
| `vw_load_history` | Every load from `etl_run_log` |

## KPIs

| KPI | Formula | Why it matters |
|---|---|---|
| MoM growth % | volume / previous month volume - 1 | Short-term momentum |
| YoY growth % | volume / same month last year - 1 | Growth without seasonality |
| Avg ticket size (Rs) | value_cr x 10 / volume_mn | Falling ticket size means more small everyday payments |
| Weighted tech decline % | SUM(volume_mn x td_pct) / SUM(volume_mn) | Fair industry average; big banks count more |
| Estimated failed txns (mn) | volume_mn x td_pct / 100 | Real size of the bank-side failure problem |
| App share % | app total_volume_mn / SUM over all apps that month x 100 | Market concentration |
| Top-2 app share % | share of the two biggest apps | NPCI's proposed 30% market cap is about this |
| Chargeback ratio % | chargebacks_received / total_txns x 100 | Dispute rate at the receiving bank |
| Forecast error (MAPE) % | average of abs(actual - forecast) / actual x 100 over a test window | How far off the volume forecast is, on months it never saw |

## Quality checks (`sql/03_quality_checks.sql`)

Run after every load; results go to `dq_results`. PASS / WARN / FAIL per check:
percentages between 0 and 100, approved + BD + TD = 100, no empty key values, one row per bank
per month, 50 banks per month, app count doesn't drop more than 10%, no missing months, latest
month at most 3 months old, app totals within 5% of the overall monthly volume, and chargeback
totals within 15% of it.

## Known limitations

- Monthly aggregates only, not individual transactions.
- `bank_monthly` covers only the top 50 remitter banks each month, which is most of the volume but not all of it.
- Bank-wise and app-wise data is available here for 13 and 12 months, so trends there are short.
- NPCI lists Slice Small Finance Bank twice in Mar and Jun 2026, so rows are keyed on rank, not name.
- NPCI's Aug 2026 Remitter file is titled "Jul'26" but holds August data. The month is taken from the file name.
- App data for Mar, May and Jun 2026 was saved from NPCI's page as JSON because the download link returned 404. The numbers are the same table.
- Bank names change over time (for example regional rural banks that merged), so some banks appear under a new name mid-series.
- Definitions (BD, TD, chargeback) are NPCI's.

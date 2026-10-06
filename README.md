# UPI Analytics Dashboard and Database

Analysis of India's UPI payments, 2016–2026: a MySQL star schema, a Power BI dashboard, and a monthly volume forecast with an honest backtest.

![UPI Analytics Dashboard](screenshots/dashboard.jpg)

## What's in it

| Part | Files | Data |
|---|---|---|
| Dashboard | `upi analytics  dashboard   IMP.pbix` | Real: NPCI monthly UPI volumes, app-wise and bank-wise tables |
| Forecast | `forecast_monthly.py` → `upi_forecast_monthly.csv`, `upi_forecast.csv` | Real: 122 monthly actuals, Jul 2016 – Aug 2026 |
| Database | `sql/01_schema.sql` … `sql/04_business_queries.sql` | Schema and queries are real work; the fact table is filled with **synthetic** values (see below) |

## Dashboard

- KPI cards: average ticket size (₹1.74K), YoY growth (22.49%), banks live (752)
- UPI volume over time, Apr 2016 – Aug 2026
- App share by volume (PhonePe, Google Pay, Paytm, …), top 10
- Bank performance (State Bank of India leads), top 10
- Forecast vs actual

## Forecast

`forecast_monthly.py` predicts monthly UPI volume with XGBoost.

- **Target:** month-over-month log growth, not the raw volume. Tree models cannot predict above the highest value they saw, and UPI volume sets a new high almost every month.
- **Features:** growth lagged 1, 2, 3 and 6 months, the 3-month average growth, month of year.
- **Evaluation:** walk-forward backtest over the last 12 months, predicting one month ahead each time with a model trained only on earlier months.
- **Result:** MAPE **5.6%** against **8.1%** for the naive "same as last month" forecast.
- **Output:** a 6-month forecast (Sep 2026 – Feb 2027) with a range of ±1.96 × the backtest error spread.

```bash
pip install -r requirements.txt
python forecast_monthly.py
```
This also refreshes the forecast columns of `upi_forecast.csv` (the file the dashboard reads): `test` rows hold the out-of-sample backtest predictions, `future` rows the forecast.

## Database (MySQL 8)

Star schema at **day × bank × UPI type** grain:

- `fact_upi_transactions`: transaction_count, transaction_value_cr, success_rate, avg_txn_value; unique key on (date_id, bank_id, upi_type_id)
- `dim_date` (every day from 2016-04-01 to 2026-12-31), `dim_bank` (15 banks), `dim_upi_type` (10 types)
- `etl_load_audit` and `dq_checks` support tables, two views
- `03_validation.sql`: 26 checks (row counts, nulls, referential integrity, ranges, duplicates)
- `04_business_queries.sql`: day-over-day growth with `LAG`, bank market share, UPI-type adoption, 7-day moving average of success rate per bank

```bash
mysql -u root -p < sql/01_schema.sql
mysql -u root -p < sql/02_load_data.sql
mysql -u root -p < sql/03_validation.sql
mysql -u root -p upi_db < sql/04_business_queries.sql
```
Tested on MySQL 8.0.46: loads 3,927 dates and 150,450 fact rows; all 26 validation checks pass.

## Data and limitations

- Bank × UPI-type daily figures are not published at this detail, so `02_load_data.sql` fills the fact table with `RAND()` values. It exercises the schema, constraints and queries; the numbers in it mean nothing. The dashboard and forecast use the real monthly data.
- The forecast uses one series of 122 points and no external drivers (festivals, policy changes), so treat the range as approximate.
- An earlier version of this project reported R² = 1.0 from a model scored on its own synthetic training data. That script was removed and replaced by the backtested `forecast_monthly.py`.

## Tech

MySQL 8 · Python (pandas, XGBoost) · Power BI

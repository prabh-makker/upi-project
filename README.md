# UPI Reliability & Growth Analytics Scorecard

Resume project: data analytics with real NPCI public data, MySQL, Python ETL, and Power BI dashboard.

## What This Is

A three-part analytics project on Unified Payments Interface (UPI) transactions in India (Apr 2016 to Aug 2026):

1. **Data pipeline:** Clean NPCI Excel files → normalize → load into MySQL with automated quality checks
2. **Analysis:** 18 SQL queries answer business questions; 5 views feed Power BI
3. **Forecast:** XGBoost 6-month volume forecast (3.98% error, Feb 2027: 26,405 million transactions)
4. **Dashboard:** 7 interactive Power BI pages (executive overview, bank scorecard, app market share, failure insights, data health, ML forecast)

## Why This Project

- **Real data only:** NPCI public product statistics and RBI ecosystem data (Apr 2016 to Aug 2026)
- **Resume fit:** BFSI (banking, fintech, payments) is the biggest IT services domain
- **Full stack:** MySQL relational database, Python 3.14 + pandas + XGBoost, Power BI Desktop
- **Automated quality:** 11 data checks run on every load; results logged in MySQL

## Key Findings

**Bank reliability:** Regional rural banks' technical decline rate is 2.24% vs. 0.09% for private banks. Central Bank of India struggling at 2.34% TD (vs. industry 0.21% in Aug 2026).

**Seasonality:** March grows ~12% month-on-month, but only ~2% per day (vs. 3.9% other months) — the jump is mostly extra calendar days. Oct-Nov festive season adds ~6% per day.

**Market concentration:** PhonePe + Google Pay fell from 81.9% to 78.3% (Sep 2025 to Aug 2026). App concentration remains high, and NPCI's proposed 30% cap applies per-app, not to the top 2 combined.

**Data quirks:** `bank_monthly.volume_mn` includes declined payments, so top 50 banks add up to 104–110% of total UPI volume (expected and accounted for).

## Data (data/raw)

| File | What | Source |
|---|---|---|
| `npci_upi_monthly_FY2025-26.xlsx` | Monthly UPI volume, value, live providers, Apr 2025–Mar 2026 | NPCI UPI product statistics page, downloaded 2026-09-30 |
| `npci_upi_monthly_FY2026-27.xlsx` | Same columns, Apr–Aug 2026 | NPCI UPI product statistics page, downloaded 2026-09-30 |
| `upi_monthly_2016-04_to_2025-08.csv` | Apr 2016–Aug 2025 (Kaggle copy of NPCI data) | [Kaggle: UPI Transaction Monthly Data](https://www.kaggle.com/datasets/syedahmadrayyan/upi-transaction-monthly-data-india-20162025) |
| `npci_ecosystem/bank_top50/*.xlsx` | Top 50 remitter banks (Sep 2025–Aug 2026): volume, Approved %, BD %, TD %, reversals | NPCI Ecosystem Statistics > Top 50 Member Performance (Remitter) |
| `npci_ecosystem/chargeback/*.xlsx` | Chargebacks per beneficiary bank per month | NPCI Ecosystem Statistics > Chargeback |
| `npci_ecosystem/upi_apps/*.xlsx`, `*.json` | Volume and value per UPI app (Sep 2025–Aug 2026) | NPCI Ecosystem Statistics > UPI Applications |

Where files overlap, NPCI downloads are used. Together they cover Apr 2016–Aug 2026 with no gaps.

## Structure

```
.
├── data/
│   ├── raw/               # NPCI files, Kaggle CSV
│   ├── processed/         # Cleaned CSVs (made by loader)
│   └── reference/         # Bank type lookup
├── python/
│   ├── data_cleaning.py   # Parse, normalize, clean raw files
│   ├── load_to_mysql.py   # Run this: ETL, QC checks, views
│   └── forecast.py        # XGBoost 6-month forecast
├── sql/
│   ├── 00_log_tables.sql
│   ├── 01_schema.sql      # 5 main tables + QC + ETL log
│   ├── 02_analysis_queries.sql  # 18 business questions
│   ├── 03_quality_checks.sql
│   └── 04_views.sql       # 5 views for Power BI
├── powerbi/
│   ├── POWERBI_GUIDE.md   # Step-by-step page build (57 lines)
│   └── data/              # CSV backups (not committed)
├── docs/
│   ├── data_dictionary.md # Columns, KPIs, limits
│   └── forecast.md        # Method, results, limits
├── findings/
│   ├── forecast.png
│   └── interview_prep.md  # Resume talking points
└── .env.example
```

## Setup (once)

1. Install **MySQL 8.0**, **Python 3.11+**, **Power BI Desktop**
2. Install Python dependencies:
   ```bash
   pip install -r python/requirements.txt
   ```
3. Copy `.env.example` to `.env` and add your MySQL root password:
   ```
   MYSQL_USER=root
   MYSQL_PASSWORD=your_password_here
   MYSQL_HOST=localhost
   MYSQL_PORT=3306
   MYSQL_DB=upi_db
   ```

## Load Data & Quality Checks

```bash
python python/load_to_mysql.py
```

This script:
- Cleans `data/raw` files → `data/processed`
- Creates `upi_db` if needed
- Rebuilds 5 tables: `upi_monthly` (125 rows), `bank_monthly` (650), `app_monthly` (1,094), `chargeback_monthly` (4,241), `dim_bank` (59)
- Logs the run in `etl_run_log`
- Creates 5 Power BI views (`sql/04_views.sql`)
- Runs 11 data quality checks (results in `dq_results`)

**Expected output:** `11 PASS / 1 WARNING / 0 FAIL` (the warning is expected: Slice Small Finance Bank listed twice in two months per NPCI data).

Safe to re-run anytime after adding new NPCI files to `data/raw`.

## Forecast (XGBoost)

```bash
python python/forecast.py
```

Forecasts UPI volume for Sep 2026–Feb 2027 (6 months) using XGBoost gradient boosting on 11 years of monthly data.

- **Training data:** Apr 2016–Aug 2026 (125 months)
- **Testing:** 5 separate 6-month windows (out-of-time validation)
- **Average error:** 3.98% MAPE
- **Forecasts:** Sep 22,867 mn → Feb 24,216 mn transactions/month

Outputs:
- MySQL: `upi_forecast` and `forecast_eval` tables
- CSV: `powerbi/data/upi_forecast.csv` and `forecast_eval.csv` (backup)
- Chart: `findings/forecast.png`

Method, results, and limitations: [docs/forecast.md](docs/forecast.md)

## Power BI Dashboard

7 interactive pages built in Power BI Desktop:

1. **Executive overview** — Total volume (YoY %), provider count, top banks, app concentration
2. **Bank scorecard** — All banks ranked by technical decline vs. industry; filter by type
3. **Bank detail (drill-through)** — Volume, Approved %, TD %, trends for a single bank
4. **App market share** — Volume and value per app; 30% regulation cap (per-app)
5. **Failure insights** — Chargebacks by bank; banks with abnormal chargeback rates
6. **Data health** — QC check results, ETL run log, data freshness
7. **Forecast** — 6-month XGBoost forecast with confidence bounds; actual vs. forecast lag

**Build guide:** [powerbi/POWERBI_GUIDE.md](powerbi/POWERBI_GUIDE.md) (57 lines, step-by-step)

**Share:** Screenshots in README or email UPI_Dashboard.pbix to stakeholders.

## Analysis Queries (18 Questions)

Run in MySQL Workbench:

```sql
source sql/02_analysis_queries.sql
```

Includes:
- Top/worst banks by technical decline, approved %, volume trends
- App concentration and growth trends
- Regional bank performance (public vs. private vs. rural)
- Seasonal patterns (March jump, Oct-Nov festive, YoY growth)
- Chargeback outliers and trends

See `sql/02_analysis_queries.sql` for full question list and formulas.

## Code Quality & Testing

- **Automated checks:** 11 data quality rules on every load (schema validation, row counts, % consistency, outlier flags)
- **Tested:** Loader passes all checks on real NPCI data (11 PASS / 1 expected WARN)
- **Code review:** Applied Ponytail efficiency patterns; 32 simplifications kept, all outputs byte-identical to original
- **Graphify auto-map:** Every Claude session rebuilds the code graph; see `graphify-out/graph.html`

## Known Limitations

- **Forecast ignores seasonality:** March and Oct-Nov come in above the line
- **No external shocks:** Can't predict policy changes, outages, or new UPI charges
- **Short horizon:** 6 months only (after that, slowing growth matters more than a straight line)
- **Top 50 > 100%:** Banks include declined transactions; totals are 104–110% of UPI monthly

## Resume Talking Points

- "I built a UPI data pipeline: cleaned NPCI Excel files, normalized into MySQL (5 tables, 125 months), added automated QC checks, and loaded 6-month XGBoost forecasts (3.98% error)."
- "I discovered that March's 12% jump is mostly extra calendar days, not demand; Regional rural banks have 2.24% technical decline vs. 0.09% for private banks."
- "I built a Power BI dashboard with 7 interactive pages (market share, bank scorecard, data health) using SQL views and Python forecasts; shared via Power BI Desktop."
- "I applied code review (Ponytail efficiency patterns) to reduce complexity and tested everything on real data."

## Tech Stack

- **Data:** MySQL 8.0 (5 tables, 7 views, 11 QC checks, 18 queries)
- **ETL:** Python 3.14, pandas, sqlalchemy
- **ML:** XGBoost gradient boosting (6-month forecast)
- **BI:** Power BI Desktop (7 pages)
- **Data source:** NPCI + RBI public data (Apr 2016–Aug 2026)
- **Testing:** Automated QC checks + out-of-time forecast validation
- **Documentation:** Data dictionary, SQL queries, Power BI guide, interview prep

## How to Use This for Interviews

1. **Download the data:** Run the loader once; it produces all tables and views
2. **Explore:** Run `sql/02_analysis_queries.sql` to see the 18 findings
3. **Build the dashboard:** Follow [powerbi/POWERBI_GUIDE.md](powerbi/POWERBI_GUIDE.md)
4. **Explain your process:**
   - Data source (NPCI public + Kaggle)
   - Quality framework (11 automated checks)
   - Key findings (reliability tiers, seasonality, market share)
   - Forecast methodology (XGBoost, 3.98% error)
   - Dashboard design (7 pages, drill-through, drill-down)
5. **Share:** Email the Power BI file or README with screenshots

## Next Steps

1. Add more months as NPCI publishes new data (load with the same script)
2. Extend forecast to 12 months or add seasonal adjustments
3. Add RBI regulatory compliance tracking (lending caps, concentration limits)
4. Track competitor fintech products (Google Pay, PhonePe, Razorpay trends)

---

Built with Python, MySQL, Power BI. Real NPCI + RBI data. MCA resume project targeting data analyst / BI roles at IT services firms (TCS, Infosys, Accenture, etc.).

# UPI Reliability & Growth Analytics Scorecard

Resume project for data analyst roles.

## Data (data/raw)
| File | What | Source |
|---|---|---|
| `npci_upi_monthly_FY2025-26.xlsx` | Monthly UPI banks live, volume, value, Apr 2025 to Mar 2026 | NPCI UPI product statistics page, downloaded 2026-09-30 |
| `npci_upi_monthly_FY2026-27.xlsx` | Same columns, Apr to Aug 2026 | NPCI UPI product statistics page, downloaded 2026-09-30 |
| `upi_monthly_2016-04_to_2025-08.csv` | Same columns, Apr 2016 to Aug 2025 | Kaggle: [UPI Transaction Monthly Data (India, 2016-2025)](https://www.kaggle.com/datasets/syedahmadrayyan/upi-transaction-monthly-data-india-20162025), a copy of NPCI figures. Its Apr to Aug 2025 rows match the NPCI FY2025-26 file exactly |

| `bank_top50/*.xlsx` | Top 50 remitter banks per month (Jan 2025, Sep 2025 to Aug 2026): volume, approved %, BD %, TD %, debit reversals | NPCI Ecosystem Statistics > Top 50 Member Performance (Remitter) |
| `chargeback/*.xlsx` | Chargebacks per beneficiary bank per month | NPCI Ecosystem Statistics > Chargeback |
| `upi_apps/*.xlsx`, `*.json` | Volume and value per UPI app per month (Sep 2025 to Aug 2026) | NPCI Ecosystem Statistics > UPI Applications. Mar, May, Jun 2026 saved from the page as .json because NPCI's download link returned 404 |

Where monthly files overlap, the NPCI download is used. Together they cover Apr 2016 to Aug 2026 with no missing months.

## Structure
- data/ → raw/processed/reference
- sql/ → schema, load, validation, queries (15 Qs), refresh
- python/ → cleaning (pandas), validation, ML (linear regression)
- powerbi/ → 5-page dashboard
- findings/ → insights + interview prep

## Phase 0 Setup
- [ ] Install MySQL 8.0
- [ ] Install Python 3.11+
- [ ] Run `bash python/setup_env.sh`
- [ ] Install Power BI Desktop
- [ ] GitHub: push repo

## Load data into MySQL (Python)
1. Copy `.env.example` to `.env` and put your MySQL root password in it
2. `pip install pandas sqlalchemy pymysql python-dotenv cryptography openpyxl`
3. `python python/load_to_mysql.py`

This cleans `data/raw` into `data/processed`, creates `upi_db` if needed, rebuilds the four data tables
(`upi_monthly`, `bank_monthly`, `app_monthly`, `chargeback_monthly`), loads them, logs the run in `etl_run_log`,
and runs 11 data quality checks (`sql/03_quality_checks.sql`, results in `dq_results`).
Safe to re-run any time, for example after adding a new NPCI file to `data/raw`.
Then run `sql/02_analysis_queries.sql` in MySQL Workbench.

Column meanings, KPI formulas and known limitations: [docs/data_dictionary.md](docs/data_dictionary.md).

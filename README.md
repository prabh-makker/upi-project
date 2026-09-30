# UPI Reliability & Growth Analytics Scorecard

Resume project for data analyst roles.

## Data (data/raw)
| File | What | Source |
|---|---|---|
| `npci_upi_monthly_FY2026-27.xlsx` | Monthly UPI banks live, volume, value, Apr to Aug 2026 | NPCI UPI product statistics page, downloaded 2026-09-30 |
| `upi_monthly_2016-04_to_2025-08.csv` | Same columns, Apr 2016 to Aug 2025 | Source link to be added |

Missing right now: Sep 2025 to Mar 2026 (the NPCI FY 2025-26 download fills it).

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

This cleans `data/raw` into `data/processed/upi_monthly.csv`, re-creates the `upi_db` database,
creates the tables from `sql/01_schema.sql`, loads the data and prints row counts to confirm.
Safe to re-run any time, for example after adding a new NPCI file to `data/raw`.
Then run `sql/02_analysis_queries.sql` in MySQL Workbench.

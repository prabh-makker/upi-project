# UPI Reliability & Growth Analytics Scorecard

Resume project for data analyst roles. Real NPCI+RBI data.

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
2. `pip install pandas sqlalchemy pymysql python-dotenv cryptography`
3. `python python/load_to_mysql.py`

This re-creates the `upi_db` database, cleans `data/raw` into `data/processed` if needed,
loads every CSV in `data/processed` as its own table, and prints row counts to confirm.
Safe to re-run any time (for example after replacing the data files).

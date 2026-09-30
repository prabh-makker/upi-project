"""
Load to MySQL - Phase 3
Cleans the raw files and loads them into a fresh MySQL database, using Python only
(no mysql command line, no LOAD DATA INFILE).

What it does:
1. Reads MySQL login details from the .env file in the project root
2. Runs data_cleaning.py (data/raw -> data/processed)
3. Creates the database (default: upi_db) if it doesn't exist
4. Runs sql/00_log_tables.sql (run log + quality results, kept across runs)
5. Runs sql/01_schema.sql, which drops and rebuilds the data tables, so re-running is always safe
6. Loads every CSV in data/processed into the table with the same name, logging each load,
   then checks that MySQL's row counts match the CSVs
7. Runs sql/04_views.sql (views for Power BI), then sql/03_quality_checks.sql and prints the results
8. Saves CSV copies of the 5 views to powerbi/data/ (backup for Power BI) and prints a sample query,
   which proves Python is talking to MySQL

Run from the project root:
    python python/load_to_mysql.py
"""

import glob
import os
import sys
from datetime import datetime

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import URL, create_engine, text

import data_cleaning  # our own cleaning script, in the same folder

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROCESSED_DIR = os.path.join(ROOT, 'data', 'processed')
POWERBI_DIR = os.path.join(ROOT, 'powerbi', 'data')
POWERBI_VIEWS = ['vw_upi_growth', 'vw_bank_scorecard', 'vw_app_share', 'vw_data_health', 'vw_load_history']
SQL_DIR = os.path.join(ROOT, 'sql')


def get_settings():
    """Read MySQL settings from .env"""
    env_path = os.path.join(ROOT, '.env')
    if not os.path.exists(env_path):
        sys.exit(f"No .env file found at {env_path}\n"
                 "Copy .env.example to .env and put your MySQL password in it.")
    load_dotenv(env_path)
    return {
        'host': os.getenv('MYSQL_HOST', 'localhost'),
        'port': int(os.getenv('MYSQL_PORT', '3306')),
        'user': os.getenv('MYSQL_USER', 'root'),
        'password': os.getenv('MYSQL_PASSWORD', ''),
        'db': os.getenv('MYSQL_DB', 'upi_db'),
    }


def make_engine(s, database=None):
    url = URL.create('mysql+pymysql', username=s['user'], password=s['password'],
                     host=s['host'], port=s['port'], database=database)
    return create_engine(url)


def ensure_database(s):
    """Create the database if it doesn't exist yet"""
    server = make_engine(s)
    try:
        with server.begin() as conn:
            conn.execute(text(f"CREATE DATABASE IF NOT EXISTS `{s['db']}` "
                              "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"))
    except Exception as e:
        sys.exit(f"Could not connect to MySQL as {s['user']}@{s['host']}:{s['port']}.\n"
                 "Check that MySQL is running and the password in .env is right.\n"
                 f"Details: {e}")
    server.dispose()
    print(f"Using database: {s['db']}")


def run_sql_file(conn, name):
    """Run each statement in sql/<name> on one connection (so @variables carry over)"""
    with open(os.path.join(SQL_DIR, name), encoding='utf-8') as f:
        lines = [line for line in f if not line.strip().startswith('--')]
    statements = [stmt.strip() for stmt in ''.join(lines).split(';') if stmt.strip()]
    for stmt in statements:
        conn.execute(text(stmt))
    print(f"Ran sql/{name} ({len(statements)} statements)")


def log_load(engine, run_time, table, df, status, error=None):
    months = pd.to_datetime(df['month_date']) if df is not None and 'month_date' in df else None
    with engine.begin() as conn:
        conn.execute(text("""
            INSERT INTO etl_run_log (run_time, table_name, source_files, first_month, last_month,
                                     rows_loaded, status, error_message)
            VALUES (:run_time, :table, :files, :first, :last, :rows, :status, :error)
        """), {'run_time': run_time, 'table': table,
               'files': df['source_file'].nunique() if df is not None and 'source_file' in df else None,
               'first': months.min().date() if months is not None else None,
               'last': months.max().date() if months is not None else None,
               'rows': len(df) if df is not None else None, 'status': status,
               'error': str(error)[:2000] if error else None})


def main():
    s = get_settings()

    print("Cleaning raw files...")
    data_cleaning.main()
    csvs = sorted(glob.glob(os.path.join(PROCESSED_DIR, '*.csv')))

    ensure_database(s)
    engine = make_engine(s, s['db'])
    run_time = datetime.now().replace(microsecond=0)
    with engine.begin() as conn:
        run_sql_file(conn, '00_log_tables.sql')
        run_sql_file(conn, '01_schema.sql')

    loaded = {}
    for path in csvs:
        table = os.path.splitext(os.path.basename(path))[0].lower()
        try:
            # Every CSV has its table in 01_schema.sql, so append keeps the types and keys.
            # MySQL turns the 'YYYY-MM-DD' text in month_date into a DATE by itself.
            df = pd.read_csv(path)
            df.to_sql(table, engine, if_exists='append', index=False, chunksize=1000)
        except Exception as e:
            log_load(engine, run_time, table, None, 'FAILED', e)
            raise
        log_load(engine, run_time, table, df, 'SUCCESS')
        loaded[table] = len(df)
        print(f"Loaded {len(df):>6} rows from {os.path.basename(path)} into table {table}")

    # Verify from the database side: row counts must match the CSVs
    print("\nChecking row counts in MySQL:")
    all_ok = True
    with engine.connect() as conn:
        for table, rows in loaded.items():
            db_rows = conn.execute(text(f"SELECT COUNT(*) FROM `{table}`")).scalar()
            status = 'OK' if db_rows == rows else 'MISMATCH'
            all_ok = all_ok and db_rows == rows
            print(f"  {table:<20} csv={rows:<6} mysql={db_rows:<6} {status}")

    with engine.begin() as conn:
        run_sql_file(conn, '04_views.sql')

    print("\nData quality checks:")
    with engine.begin() as conn:
        conn.execute(text("SET @run_time = :t"), {'t': run_time})
        run_sql_file(conn, '03_quality_checks.sql')
    dq = pd.read_sql(text("""
        SELECT status, check_name, table_name, failed_rows, rule
        FROM dq_results WHERE run_time = :t ORDER BY check_id
    """), engine, params={'t': run_time})
    print(dq.to_string(index=False))
    failed = (dq['status'] == 'FAIL').sum()
    print(f"{(dq['status'] == 'PASS').sum()} passed, {(dq['status'] == 'WARN').sum()} warnings, {failed} failed")

    # CSV copies of the Power BI views, for Get Data > Text/CSV if the MySQL connector gives trouble
    os.makedirs(POWERBI_DIR, exist_ok=True)
    for view in POWERBI_VIEWS:
        pd.read_sql(text(f"SELECT * FROM {view}"), engine).to_csv(os.path.join(POWERBI_DIR, f"{view}.csv"), index=False)
    print(f"\nSaved {len(POWERBI_VIEWS)} view exports to powerbi/data/ (backup for Power BI)")

    print("\nSample query (last 6 months in vw_upi_growth):")
    sample = pd.read_sql(text("SELECT month_date, banks_live, volume_mn, value_cr, avg_ticket_rs "
                              "FROM vw_upi_growth ORDER BY month_date DESC LIMIT 6"), engine)
    print(sample.to_string(index=False))

    engine.dispose()
    if not all_ok:
        sys.exit("\nSome row counts did not match. See above.")
    if failed:
        print("\nSome data quality checks FAILED. See the table above (also saved in dq_results).")
    print(f"\nDone. Python is connected to MySQL and all tables are in {s['db']}.")
    print("Next: open sql/02_analysis_queries.sql in MySQL Workbench and run it.")


if __name__ == '__main__':
    main()

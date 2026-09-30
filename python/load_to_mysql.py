"""
Load to MySQL - Phase 3
Loads every CSV in data/processed into a fresh MySQL database, using Python only
(no mysql command line, no LOAD DATA INFILE).

What it does:
1. Reads MySQL login details from the .env file in the project root
2. If data/processed has no CSVs yet, runs data_cleaning.py first
3. Drops and re-creates the database (default: upi_db), so re-running is always safe
4. Creates one table per CSV (npci_upi_clean.csv -> table npci_upi_clean) and loads it
5. Prints row counts and a sample query, which proves Python is talking to MySQL

Run from the project root:
    python python/load_to_mysql.py
"""

import glob
import os
import sys

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.engine import URL

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROCESSED_DIR = os.path.join(ROOT, 'data', 'processed')


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


def ensure_processed_csvs():
    """Return the processed CSVs, running the cleaning step first if there are none"""
    csvs = sorted(glob.glob(os.path.join(PROCESSED_DIR, '*.csv')))
    if not csvs:
        print("No CSVs in data/processed yet, running data_cleaning.py first...")
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import data_cleaning
        data_cleaning.main()
        csvs = sorted(glob.glob(os.path.join(PROCESSED_DIR, '*.csv')))
    if not csvs:
        sys.exit("Still no CSVs in data/processed. Check data/raw.")
    return csvs


def recreate_database(s):
    """Drop and create the database fresh"""
    server = make_engine(s)
    try:
        with server.begin() as conn:
            conn.execute(text(f"DROP DATABASE IF EXISTS `{s['db']}`"))
            conn.execute(text(f"CREATE DATABASE `{s['db']}` "
                              "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"))
    except Exception as e:
        sys.exit(f"Could not connect to MySQL as {s['user']}@{s['host']}:{s['port']}.\n"
                 "Check that MySQL is running and the password in .env is right.\n"
                 f"Details: {e}")
    server.dispose()
    print(f"Created fresh database: {s['db']}")


def load_csv(engine, path):
    """Load one CSV into a table named after the file"""
    table = os.path.splitext(os.path.basename(path))[0].lower()
    df = pd.read_csv(path)
    # Columns with 'date' in the name become real DATE columns in MySQL
    for col in df.columns:
        if 'date' in col.lower():
            df[col] = pd.to_datetime(df[col]).dt.date
    df.to_sql(table, engine, if_exists='replace', index=False, chunksize=1000)
    return table, len(df)


def main():
    s = get_settings()
    csvs = ensure_processed_csvs()
    recreate_database(s)

    engine = make_engine(s, s['db'])
    loaded = {}
    for path in csvs:
        table, rows = load_csv(engine, path)
        loaded[table] = rows
        print(f"Loaded {rows:>6} rows from {os.path.basename(path)} into table {table}")

    # Verify from the database side: row counts must match the CSVs
    print("\nChecking row counts in MySQL:")
    all_ok = True
    with engine.connect() as conn:
        for table, rows in loaded.items():
            db_rows = conn.execute(text(f"SELECT COUNT(*) FROM `{table}`")).scalar()
            status = 'OK' if db_rows == rows else 'MISMATCH'
            all_ok = all_ok and db_rows == rows
            print(f"  {table:<28} csv={rows:<6} mysql={db_rows:<6} {status}")

    print("\nColumns per table:")
    insp = inspect(engine)
    for table in loaded:
        cols = [f"{c['name']} ({c['type']})" for c in insp.get_columns(table)]
        print(f"  {table}: {', '.join(cols)}")

    if 'npci_upi_clean' in loaded:
        print("\nSample query (monthly totals from npci_upi_clean):")
        sample = pd.read_sql(text("""
            SELECT `year`, `month`,
                   SUM(transaction_count) AS total_txn,
                   ROUND(SUM(transaction_value_crores), 2) AS total_value_cr,
                   ROUND(AVG(success_rate_percent), 2) AS avg_success_rate
            FROM npci_upi_clean
            GROUP BY `year`, `month`
            ORDER BY `year`, `month`
        """), engine)
        print(sample.to_string(index=False))

    engine.dispose()
    if not all_ok:
        sys.exit("\nSome row counts did not match. See above.")
    print(f"\nDone. Python is connected to MySQL and all tables are in {s['db']}.")


if __name__ == '__main__':
    main()

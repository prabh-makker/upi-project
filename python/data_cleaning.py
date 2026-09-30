"""
Data Cleaning - Phase 2
Combines the monthly UPI files in data/raw into one clean table.

Input (data/raw):
- npci_upi_monthly_FY*.xlsx   Downloaded from the NPCI UPI product statistics page, one file per
                              financial year. Months look like "August-2026".
- upi_monthly_*.csv           Monthly UPI table covering Apr-2016 to Aug-2025. Months look like
                              "Aug-25". Its computed columns (average ticket, MoM growth) are
                              dropped here and recalculated in SQL.

Cleaning rules:
- Month text -> real date (1st of the month)
- Numbers like "29,82,355.95" (Indian commas) -> 2982355.95
- Same month in two files -> keep the NPCI download
- Report any missing months between the first and last month

Output:
- data/processed/upi_monthly.csv  (month_date, banks_live, volume_mn, value_cr, source_file)
"""

import glob
import os

import pandas as pd

# Paths are relative to the repo, so this runs the same on Windows and Linux
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR = os.path.join(ROOT, 'data', 'raw')
PROCESSED_DIR = os.path.join(ROOT, 'data', 'processed')

# Raw column name -> clean column name
COLUMN_MAP = {
    'month': 'month',
    'no. of banks live on upi': 'banks_live',
    'volume (in mn.)': 'volume_mn',
    'volume (in mn)': 'volume_mn',
    'value (in cr.)': 'value_cr',
}


def to_number(series):
    """'29,82,355.95' -> 2982355.95"""
    return pd.to_numeric(series.astype(str).str.replace(',', '').str.strip(), errors='coerce')


def parse_month(series):
    """'August-2026' or 'Aug-25' -> 2026-08-01 / 2025-08-01"""
    text = series.astype(str).str.strip()
    parsed = pd.to_datetime(text, format='%B-%Y', errors='coerce')
    parsed = parsed.fillna(pd.to_datetime(text, format='%b-%y', errors='coerce'))
    return parsed


def read_raw_file(path):
    if path.lower().endswith('.xlsx'):
        df = pd.read_excel(path, dtype=str)
    else:
        df = pd.read_csv(path, dtype=str)
    df.columns = [c.strip().lower() for c in df.columns]
    df = df.rename(columns=COLUMN_MAP)[['month', 'banks_live', 'volume_mn', 'value_cr']]
    df = df.dropna(how='all')

    df['month_date'] = parse_month(df['month'])
    bad = df['month_date'].isna()
    if bad.any():
        print(f"  {os.path.basename(path)}: skipped {bad.sum()} rows with an unreadable month: "
              f"{df.loc[bad, 'month'].tolist()}")
    df = df[~bad]

    df['banks_live'] = to_number(df['banks_live']).astype('Int64')
    df['volume_mn'] = to_number(df['volume_mn']).round(2)
    df['value_cr'] = to_number(df['value_cr']).round(2)
    df['source_file'] = os.path.basename(path)
    # NPCI downloads win when two files have the same month
    df['priority'] = 0 if os.path.basename(path).startswith('npci_') else 1
    return df[['month_date', 'banks_live', 'volume_mn', 'value_cr', 'source_file', 'priority']]


def main():
    files = sorted(glob.glob(os.path.join(RAW_DIR, '*.xlsx')) + glob.glob(os.path.join(RAW_DIR, '*.csv')))
    if not files:
        raise SystemExit(f"No .xlsx or .csv files in {RAW_DIR}")

    frames = []
    for path in files:
        df = read_raw_file(path)
        print(f"  {os.path.basename(path)}: {len(df)} months "
              f"({df['month_date'].min():%b-%Y} to {df['month_date'].max():%b-%Y})")
        frames.append(df)

    df = pd.concat(frames, ignore_index=True)
    rows_before = len(df)
    df = (df.sort_values(['month_date', 'priority'])
            .drop_duplicates(subset='month_date', keep='first')
            .drop(columns='priority')
            .sort_values('month_date')
            .reset_index(drop=True))
    print(f"Combined: {rows_before} rows -> {len(df)} unique months "
          f"({rows_before - len(df)} duplicate months dropped)")

    all_months = pd.date_range(df['month_date'].min(), df['month_date'].max(), freq='MS')
    missing = all_months.difference(df['month_date'])
    if len(missing):
        print(f"Missing months ({len(missing)}): {', '.join(m.strftime('%b-%Y') for m in missing)}")

    os.makedirs(PROCESSED_DIR, exist_ok=True)
    # Clear old outputs so the loader never picks up stale files
    for old in glob.glob(os.path.join(PROCESSED_DIR, '*.csv')):
        os.remove(old)
    df['month_date'] = df['month_date'].dt.date
    out = os.path.join(PROCESSED_DIR, 'upi_monthly.csv')
    df.to_csv(out, index=False)
    print(f"Saved {out}")


if __name__ == '__main__':
    main()

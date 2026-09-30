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

Also (data/raw/bank_top50):
- Ecosystem-Statistics-UPI-Top-50-member-performance-<YYYY>-<Mon>-Remitter.xlsx
                              NPCI Ecosystem Statistics > Top 50 Member Performance (Remitter),
                              one file per month. Percent columns can come as 0.9122 or 91.22;
                              both are stored as 91.22.

Also (data/raw/chargeback):
- Ecosystem-Statistics-UPI-Chargeback-<YYYY>-<Mon>.xlsx
                              NPCI Ecosystem Statistics > Chargeback, one file per month, by
                              beneficiary bank. The CB ratio is recalculated from the counts
                              because NPCI rounds it to 0.000% for big banks.

Also (data/raw/upi_apps):
- Ecosystem-Statistics-UPI-Upi-apps-<YYYY>-<Mon>.xlsx (or .json)
                              NPCI Ecosystem Statistics > UPI Applications, one file per month.
                              For Mar, May and Jun 2026 NPCI's download link returned 404, so the
                              table data was saved from the page as .json instead.

Month for every monthly file comes from the file name (NPCI's Aug-2026 Remitter file is titled Jul'26).

Output:
- data/processed/upi_monthly.csv  (month_date, banks_live, volume_mn, value_cr, source_file)
- data/processed/bank_monthly.csv (month_date, rank_no, bank_name, volume_mn, approved_pct, bd_pct, td_pct,
                                   debit_reversal_mn, debit_reversal_success_pct, source_file)
- data/processed/chargeback_monthly.csv (month_date, bank_code, bank_name, total_txns,
                                   chargebacks_received, representments, chargebacks_accepted,
                                   cb_ratio_pct, source_file)
- data/processed/app_monthly.csv  (month_date, app_name, <customer|b2c|b2b|onus|total>_volume_mn and
                                   _value_cr, source_file)
"""

import glob
import json
import os
import re

import pandas as pd

# Paths are relative to the repo, so this runs the same on Windows and Linux
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR = os.path.join(ROOT, 'data', 'raw')
PROCESSED_DIR = os.path.join(ROOT, 'data', 'processed')
BANK_DIR = os.path.join(RAW_DIR, 'bank_top50')
CHARGEBACK_DIR = os.path.join(RAW_DIR, 'chargeback')
APPS_DIR = os.path.join(RAW_DIR, 'upi_apps')
REFERENCE_DIR = os.path.join(ROOT, 'data', 'reference')

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
    return pd.to_numeric(series.astype(str).str.replace(',', '').str.replace('%', '').str.strip(), errors='coerce')


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


# Bank file header with everything except letters removed -> clean column name (matched on the start).
# NPCI changes header style between months ("UPI Remitter Banks" vs "upi_remitter_banks").
BANK_COLUMNS = [
    ('sr', 'rank_no'),
    ('upiremitterbanks', 'bank_name'),
    ('totalvolume', 'volume_mn'),
    ('approved', 'approved_pct'),
    ('bd', 'bd_pct'),
    ('td', 'td_pct'),
    ('totaldebitreversalcount', 'debit_reversal_mn'),
    ('debitreversalsuccess', 'debit_reversal_success_pct'),
]
PCT_COLUMNS = ['approved_pct', 'bd_pct', 'td_pct', 'debit_reversal_success_pct']


def file_month(path, title=None):
    """Month from the file name "2025-Jan", else from a title row like "(Jan'25)".
    The file name wins: NPCI's Aug-2026 Remitter file has the title "(Jul'26)" but Aug data."""
    m = re.search(r'(\d{4})-([A-Za-z]{3})', os.path.basename(path))
    if m:
        return pd.to_datetime(f"{m.group(2)}-{m.group(1)}", format='%b-%Y')
    m = re.search(r"\(([A-Za-z]{3})[a-z]*'(\d{2})\)", str(title))
    if m:
        return pd.to_datetime(f"{m.group(1)}-{m.group(2)}", format='%b-%y')
    raise SystemExit(f"Can't tell which month {os.path.basename(path)} is for")


def clean_name(series):
    """'State Bank Of India' / 'Google Pay  #' / 'Karnataka Bank Ltd.' ->
    'STATE BANK OF INDIA' / 'GOOGLE PAY' / 'KARNATAKA BANK' (NPCI switches between Ltd. and Limited)"""
    return (series.astype(str).str.replace(r'[#*]', '', regex=True)
            .str.replace(r'\s+', ' ', regex=True).str.strip().str.upper()
            .str.replace(r'\s+(LTD\.?|LIMITED)$', '', regex=True))


def read_bank_file(path):
    raw = pd.read_excel(path, header=None, dtype=object)
    header_row = raw.index[raw.iloc[:, 0].astype(str).str.strip().str.lower().str.startswith('sr')][0]
    month_date = file_month(path, raw.iloc[0, 0])

    df = raw.iloc[header_row + 1:].copy()
    df.columns = [re.sub('[^a-z]', '', str(c).lower()) for c in raw.iloc[header_row]]
    rename = {}
    for col in df.columns:
        for prefix, clean in BANK_COLUMNS:
            if col.startswith(prefix) and clean not in rename.values():
                rename[col] = clean
                break
    df = df.rename(columns=rename)[[clean for _, clean in BANK_COLUMNS]]
    df = df.dropna(subset=['bank_name'])

    df['bank_name'] = clean_name(df['bank_name'])
    for col in df.columns.drop('bank_name'):
        df[col] = to_number(df[col].replace('-', None))
    df['rank_no'] = df['rank_no'].astype('Int64')
    for col in PCT_COLUMNS:
        if df[col].max() <= 1:          # 0.9122 -> 91.22
            df[col] = df[col] * 100
        df[col] = df[col].round(2)
    df.insert(0, 'month_date', month_date)
    df['source_file'] = os.path.basename(path)
    return df


def clean_bank_files():
    files = sorted(glob.glob(os.path.join(BANK_DIR, '*.xlsx')))
    if not files:
        return None
    df = pd.concat([read_bank_file(p) for p in files], ignore_index=True)
    rows_before = len(df)
    # A bank can appear twice in one month (NPCI lists Slice Small Finance Bank twice in Mar and
    # Jun 2026), so rows are keyed on NPCI's rank, not the name
    df = df.drop_duplicates(subset=['month_date', 'rank_no']).sort_values(['month_date', 'rank_no'])
    months = df['month_date'].dt.strftime('%b-%Y').unique()
    print(f"  bank_top50: {len(files)} files, {len(df)} bank-month rows "
          f"({rows_before - len(df)} duplicates dropped), months: {', '.join(months)}")
    df['month_date'] = df['month_date'].dt.date
    return df


# Header with everything except letters removed -> clean column name.
# NPCI changes header style between months ("Re-presentment Raised ..." vs "representment_raised_...").
CHARGEBACK_COLUMNS = {
    'code': 'bank_code',
    'beneficiarybank': 'bank_name',
    'totaltxnsduringthemonth': 'total_txns',
    'chargebacksreceivedduringthemonth': 'chargebacks_received',
    'representmentraisedduringthemonth': 'representments',
    'chargebacksacceptedduringthemonth': 'chargebacks_accepted',
}


def read_chargeback_file(path):
    month_date = file_month(path)

    df = pd.read_excel(path, dtype=str)
    df.columns = [re.sub('[^a-z]', '', str(c).lower()) for c in df.columns]
    df = df.rename(columns=CHARGEBACK_COLUMNS)[list(CHARGEBACK_COLUMNS.values())]
    df = df.dropna(subset=['bank_name'])
    df['bank_code'] = df['bank_code'].str.strip().str.upper()
    df['bank_name'] = clean_name(df['bank_name'])
    for col in ['total_txns', 'chargebacks_received', 'representments', 'chargebacks_accepted']:
        df[col] = to_number(df[col]).astype('Int64')
    df['cb_ratio_pct'] = (100 * df['chargebacks_received'] / df['total_txns'].replace(0, pd.NA)).astype(float).round(6)
    df.insert(0, 'month_date', month_date)
    df['source_file'] = os.path.basename(path)
    return df


def clean_chargeback_files():
    files = sorted(glob.glob(os.path.join(CHARGEBACK_DIR, '*.xlsx')))
    if not files:
        return None
    df = pd.concat([read_chargeback_file(p) for p in files], ignore_index=True)
    rows_before = len(df)
    df = df.drop_duplicates(subset=['month_date', 'bank_code']).sort_values(['month_date', 'total_txns'],
                                                                           ascending=[True, False])
    months = df['month_date'].sort_values().dt.strftime('%b-%Y').unique()
    print(f"  chargeback: {len(files)} files, {len(df)} bank-month rows "
          f"({rows_before - len(df)} duplicates dropped), months: {', '.join(months)}")
    df['month_date'] = df['month_date'].dt.date
    return df


# UPI Apps: (volume, value) pairs in the order NPCI prints them
APP_PAIRS = ['customer', 'b2c', 'b2b', 'onus', 'total']
APP_JSON_KEYS = {
    'customer': 'customer_initiated_transactions', 'b2c': 'b_2_c_transactions',
    'b2b': 'b_2_b_transactions', 'onus': 'onus_transactions', 'total': 'total',
}


def read_app_file(path):
    """UPI Apps table: .xlsx download, or .json saved from the page when NPCI's download link was broken"""
    month_date = file_month(path)
    if path.endswith('.json'):
        with open(path, encoding='utf-8') as f:
            rows = json.load(f)['data']['results']
        df = pd.DataFrame({'srno': [r.get('srno') for r in rows],
                           'app_name': [r.get('application_name') for r in rows]})
        for pair in APP_PAIRS:
            key = APP_JSON_KEYS[pair]
            df[f'{pair}_volume_mn'] = [r.get(f'{key}_volume_mn') for r in rows]
            df[f'{pair}_value_cr'] = [r.get(f'{key}_value_cr') for r in rows]
    else:
        raw = pd.read_excel(path, header=None, dtype=str)
        month_date = file_month(path, raw.iloc[0, 0])
        df = raw.iloc[:, :12].copy()
        df.columns = ['srno', 'app_name'] + [f'{pair}_{kind}' for pair in APP_PAIRS
                                             for kind in ('volume_mn', 'value_cr')]
    # Keep only numbered rows (drops title and header rows)
    df = df[pd.to_numeric(df['srno'], errors='coerce').notna()].drop(columns='srno')
    df['app_name'] = clean_name(df['app_name'])
    for col in df.columns.drop('app_name'):
        df[col] = to_number(df[col]).round(2)
    df.insert(0, 'month_date', month_date)
    df['source_file'] = os.path.basename(path)
    return df


def clean_app_files():
    files = sorted(glob.glob(os.path.join(APPS_DIR, '*.xlsx')) + glob.glob(os.path.join(APPS_DIR, '*.json')))
    if not files:
        return None
    df = pd.concat([read_app_file(p) for p in files], ignore_index=True)
    rows_before = len(df)
    df = df.drop_duplicates(subset=['month_date', 'app_name']).sort_values(['month_date', 'total_volume_mn'],
                                                                          ascending=[True, False])
    months = df['month_date'].sort_values().dt.strftime('%b-%Y').unique()
    print(f"  upi_apps: {len(files)} files, {len(df)} app-month rows "
          f"({rows_before - len(df)} duplicates dropped), months: {', '.join(months)}")
    df['month_date'] = df['month_date'].dt.date
    return df


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

    banks = clean_bank_files()
    if banks is not None:
        out = os.path.join(PROCESSED_DIR, 'bank_monthly.csv')
        banks.to_csv(out, index=False)
        print(f"Saved {out}")

        # Bank type lookup (Public / Private / Small finance / ...), kept by hand in data/reference
        dim = pd.read_csv(os.path.join(REFERENCE_DIR, 'bank_type.csv'))
        missing = sorted(set(banks['bank_name']) - set(dim['bank_name']))
        if missing:
            print(f"  Add these banks to data/reference/bank_type.csv: {', '.join(missing)}")
        out = os.path.join(PROCESSED_DIR, 'dim_bank.csv')
        dim.to_csv(out, index=False)
        print(f"Saved {out}")

    chargebacks = clean_chargeback_files()
    if chargebacks is not None:
        out = os.path.join(PROCESSED_DIR, 'chargeback_monthly.csv')
        chargebacks.to_csv(out, index=False)
        print(f"Saved {out}")

    apps = clean_app_files()
    if apps is not None:
        out = os.path.join(PROCESSED_DIR, 'app_monthly.csv')
        apps.to_csv(out, index=False)
        print(f"Saved {out}")


if __name__ == '__main__':
    main()

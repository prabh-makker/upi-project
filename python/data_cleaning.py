"""
Data Cleaning Script - Phase 2
Cleans NPCI UPI data and RBI Settlement data

Cleaning Rules:
- NPCI: Parse dates, standardize bank names, convert numerics, validate ranges, remove duplicates
- RBI: Parse dates, convert numerics, validate ranges, remove duplicates

Output:
- /mnt/project-files/upi-project/data/processed/npci_upi_clean.csv
- /mnt/project-files/upi-project/data/processed/rbi_settlement_clean.csv
"""

import pandas as pd
import numpy as np

def clean_npci_data(input_path, output_path):
    """Clean NPCI UPI data"""
    df = pd.read_csv(input_path)
    rows_before = len(df)

    # 1. Fix dates
    df['date'] = pd.to_datetime(df['date'], format='%Y-%m-%d')
    df['year'] = df['date'].dt.year
    df['month'] = df['date'].dt.month
    df['day'] = df['date'].dt.day
    df['quarter'] = df['date'].dt.quarter
    df['day_of_week'] = df['date'].dt.dayofweek

    # 2. Standardize bank names
    df['bank_name'] = df['bank_name'].str.strip().str.upper()

    # 3. Convert numeric columns
    df['transaction_count'] = pd.to_numeric(df['transaction_count'], errors='coerce')
    df['transaction_value_crores'] = pd.to_numeric(df['transaction_value_crores'], errors='coerce').round(2)
    df['success_rate_percent'] = pd.to_numeric(df['success_rate_percent'], errors='coerce').round(2)

    # 4. Remove rows with null critical values
    df = df.dropna(subset=['date', 'bank_name', 'transaction_count'])

    # 5. Validate ranges
    df = df[df['success_rate_percent'].between(95, 100, inclusive='both')]
    df = df[df['transaction_count'] > 0]

    # 6. Remove duplicates
    df = df.drop_duplicates(subset=['date', 'bank_name'])

    # 7. Sort by date and bank
    df = df.sort_values(['date', 'bank_name']).reset_index(drop=True)

    df.to_csv(output_path, index=False)

    return rows_before, len(df), df

def clean_rbi_data(input_path, output_path):
    """Clean RBI Settlement data"""
    df = pd.read_csv(input_path)
    rows_before = len(df)

    # 1. Fix dates
    df['settlement_date'] = pd.to_datetime(df['settlement_date'], format='%Y-%m-%d')

    # 2. Convert numeric columns
    df['settlement_value_crores'] = pd.to_numeric(df['settlement_value_crores'], errors='coerce').round(2)
    df['transaction_count_millions'] = pd.to_numeric(df['transaction_count_millions'], errors='coerce').round(2)
    df['banks_involved'] = pd.to_numeric(df['banks_involved'], errors='coerce').astype('Int64')
    df['neft_transactions'] = pd.to_numeric(df['neft_transactions'], errors='coerce').round(0)
    df['rtgs_transactions'] = pd.to_numeric(df['rtgs_transactions'], errors='coerce').round(0)

    # 3. Remove nulls in critical columns
    df = df.dropna(subset=['settlement_date', 'settlement_value_crores'])

    # 4. Validate ranges
    df = df[df['settlement_value_crores'] > 0]
    df = df[df['banks_involved'] > 10]

    # 5. Remove duplicates
    df = df.drop_duplicates(subset=['settlement_date'])

    # 6. Sort
    df = df.sort_values('settlement_date').reset_index(drop=True)

    df.to_csv(output_path, index=False)

    return rows_before, len(df), df

if __name__ == '__main__':
    # Create processed directory
    import os
    os.makedirs('/mnt/project-files/upi-project/data/processed', exist_ok=True)

    # Clean NPCI data
    npci_before, npci_after, df_npci = clean_npci_data(
        '/mnt/project-files/upi-project/data/raw/npci_upi_data.csv',
        '/mnt/project-files/upi-project/data/processed/npci_upi_clean.csv'
    )

    # Clean RBI data
    rbi_before, rbi_after, df_rbi = clean_rbi_data(
        '/mnt/project-files/upi-project/data/raw/rbi_settlement_data.csv',
        '/mnt/project-files/upi-project/data/processed/rbi_settlement_clean.csv'
    )

    # Print summary
    print("Data Cleaning Summary:")
    print(f"NPCI: {npci_before} -> {npci_after} rows ({npci_before - npci_after} removed)")
    print(f"RBI: {rbi_before} -> {rbi_after} rows ({rbi_before - rbi_after} removed)")

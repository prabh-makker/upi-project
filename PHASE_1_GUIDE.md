# PHASE 1: Download Real UPI Data Guide

## Overview

This guide walks you through downloading real, official UPI transaction data from two authoritative sources in India:

- **NPCI (National Payments Corporation of India)** - Publishes monthly UPI transaction statistics
- **RBI (Reserve Bank of India)** - Maintains settlement and payment system data

This data forms the foundation for Phase 2 (cleaning/processing) and Phase 3 (MySQL database load). By downloading official data, we ensure accuracy and credibility for any analysis or visualizations built on top.

**Why this matters:**
- NPCI data shows transaction volume and value by bank/provider
- RBI data shows settlement metrics and system health
- Combined, they give us a complete picture of India's digital payments landscape

---

## Part 1: NPCI Data (Estimated: 30 minutes)

NPCI publishes monthly UPI statistics that are freely available to the public.

### Step-by-Step Download

1. **Open NPCI Statistics Page**
   - Navigate to: https://www.npci.org.in/what-we-do/upi/upi-transaction-statistics
   - You should see a page with monthly UPI data

2. **Locate Latest CSV Download**
   - Look for a table or download section with monthly data
   - File naming pattern: `UPI_Transaction_Statistics_[Month_Year].csv`
   - Example: `UPI_Transaction_Statistics_September_2024.csv`
   - Download the **most recent available month**

3. **Save to Project Directory**
   - Save the file as: `data/raw/npci_upi_data.csv`
   - Create the directory if it doesn't exist:
     ```bash
     mkdir -p data/raw
     ```

4. **Expected Data Structure**
   - The CSV should contain these columns (or similar):
     - `date` or `month` - Transaction date/month
     - `bank_name` - Name of the bank/NPCI participant
     - `transaction_count` - Number of UPI transactions
     - `transaction_value` - Total transaction value (in crores/lakhs)
     - Additional columns may include merchant/customer breakdown
   
   - **File size:** Should be ~100KB to 500KB
   - **Row count:** Typically 50-500 rows depending on time range

### Verification Checklist
- [ ] File downloaded and saved to `data/raw/npci_upi_data.csv`
- [ ] File size is > 100KB
- [ ] Open in Excel/VS Code and verify columns exist
- [ ] File is valid CSV (not corrupted)

---

## Part 2: RBI Data (Estimated: 20 minutes)

The Reserve Bank of India maintains comprehensive payment system statistics through their StatoBot database.

### Step-by-Step Download

1. **Access RBI Statistics Portal**
   - Navigate to: https://www.rbi.org.in/Scripts/statistics.aspx (StatoBot)
   - This is the RBI's official statistics portal

2. **Search for UPI/NEFT Settlement Data**
   - In the search box, search for: **"UPI"** or **"Unified Payments Interface"**
   - Alternative search: **"NEFT"** (National Electronic Funds Transfer) for settlement data
   - You may also search for: **"Payment Systems"** or **"Real Time Gross Settlement"**

3. **Select and Download Data**
   - Choose the dataset with the most recent data
   - Download options typically include: CSV or Excel format
   - Common datasets:
     - "UPI Transactions - Volume and Value"
     - "Payment System Transactions - Settlement"
     - "Bank-wise UPI Performance"
   - Download the **CSV format** (if available)

4. **Save to Project Directory**
   - Save the file as: `data/raw/rbi_settlement_data.csv`
   - If downloaded as Excel (.xlsx), convert to CSV:
     ```bash
     # Using Python (if needed)
     python -c "import pandas as pd; df = pd.read_excel('rbi_file.xlsx'); df.to_csv('data/raw/rbi_settlement_data.csv', index=False)"
     ```

5. **Expected Data Structure**
   - The CSV should contain columns like:
     - `date` - Settlement date
     - `settlement_value` - Value of settlements (in crores)
     - `transaction_count` - Number of transactions settled
     - `success_rate` - Settlement success rate (%)
     - `bank_name` or `participant` - Participant identifier
   
   - **File size:** Should be ~50KB to 300KB
   - **Frequency note:** RBI data may be **quarterly or monthly**, not necessarily daily

### Important Notes about RBI Data
- RBI data updates may be less frequent than NPCI (quarterly vs. monthly)
- Some data may be password-protected or require registration (free)
- If StatoBot link is down, try: https://data.gov.in/ - search for "RBI UPI"
- For archived data, check: https://www.rbi.org.in/scripts/PublicationReports.aspx

### Verification Checklist
- [ ] File downloaded and saved to `data/raw/rbi_settlement_data.csv`
- [ ] File size is > 50KB
- [ ] Open in Excel/VS Code and verify columns exist
- [ ] Note the date range covered (monthly/quarterly?)
- [ ] File is valid CSV (not corrupted)

---

## Part 3: Verify Your Downloads

After downloading both files, run these verification checks:

### 1. File Size Check
```bash
ls -lh data/raw/
# Expected output:
# -rw-r--r--  1 user  group  150K Sep 29 12:00 npci_upi_data.csv
# -rw-r--r--  1 user  group  100K Sep 29 12:05 rbi_settlement_data.csv
```

### 2. CSV Validity Check
```bash
# Check first few rows of each file
head -5 data/raw/npci_upi_data.csv
head -5 data/raw/rbi_settlement_data.csv

# Count rows (subtract 1 for header)
wc -l data/raw/npci_upi_data.csv
wc -l data/raw/rbi_settlement_data.csv
```

### 3. Column Verification
- Open both files in Excel or VS Code
- Confirm expected columns are present
- Note any missing data (NULL, blank cells) - this is normal

### 4. Data Sanity Checks
- NPCI: Transaction counts should be > 0
- NPCI: Transaction values should be > 0 (in crores)
- RBI: Settlement values should match overall UPI volume trends
- RBI: Success rates should be 95%+ (normal for modern systems)

---

## Part 4: Next Steps

Once both files are downloaded and verified:

### Run Data Cleaning

1. **Navigate to Python Scripts**
   ```bash
   cd python/
   ```

2. **Open Data Cleaning Notebook**
   - Open in Jupyter: `jupyter notebook 01_data_cleaning.ipynb`
   - OR in VS Code: Open file and use Python extension
   - This notebook will:
     - Load both raw CSV files
     - Clean column names and data types
     - Handle missing values
     - Merge NPCI and RBI data
     - Output cleaned data to `data/processed/`

3. **Expected Output**
   - `data/processed/npci_cleaned.csv` - Cleaned NPCI data
   - `data/processed/rbi_cleaned.csv` - Cleaned RBI data
   - `data/processed/upi_combined.csv` - Merged dataset (if applicable)
   - Processing log with data quality metrics

4. **Phase 2 Complete**
   - Once cleaning is done, you can proceed to Phase 3
   - Phase 3: Load cleaned data into MySQL database
   - Phase 4: Create visualizations and dashboards

---

## Tips & Troubleshooting

### If Downloads Are Behind a Paywall
- Look for "Public Data" or "Open Data" versions on NPCI/RBI websites
- Check data.gov.in (Indian government's open data portal)
- Try the "Archives" section of NPCI/RBI sites (often free)

### If Original Links Are Dead or Changed
- **NPCI Alternative:** Search "NPCI UPI statistics" on npci.org.in
- **RBI Alternative:** Use data.gov.in and search "RBI UPI"
- **Archive:** Try Wayback Machine (archive.org) for historical data

### Data Format Variations
- Files may come as CSV, XLS, or XLSX
- Always save/convert to CSV before cleaning:
  ```bash
  # If you have an .xlsx file
  python -c "import pandas as pd; pd.read_excel('file.xlsx').to_csv('file.csv', index=False)"
  ```

### Handling Missing Data
- Phase 2 cleaning script automatically handles:
  - Missing values (forward fill or removal)
  - Inconsistent date formats
  - Duplicate rows
  - Data type conversions
- If data is significantly incomplete (>50% missing), note this for Phase 4 (insights)

### File Size Seems Wrong?
- NPCI data: Single month = ~150KB, Year = ~1-2MB
- RBI data: Single quarter = ~50KB, Full year = ~200KB
- If much larger: File may contain multiple years or unnecessary columns
- If much smaller: May be summary only (try finding detailed breakdown)

---

## Timeline Summary

| Task | Duration | Status |
|------|----------|--------|
| Download NPCI data | 15-20 min | Starting |
| Verify NPCI file | 5 min | After download |
| Download RBI data | 15-20 min | After NPCI |
| Verify RBI file | 5 min | After download |
| **Total Phase 1** | **50 min** | Estimated |
| Data Cleaning (Phase 2) | 30-45 min | After Phase 1 |
| Database Load (Phase 3) | 20-30 min | After Phase 2 |

---

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| NPCI/RBI links not working | Try data.gov.in or search within the official websites |
| Downloaded file is .xlsx not .csv | Convert using pandas (see Tips section) or open in Excel and save as CSV |
| File looks empty or has no headers | Data may be in a different sheet (xlsx) or require different parsing |
| Columns don't match expected list | Different report versions have different columns - document what you have in Phase 2 |
| Very small file size | May be summary data - look for "detailed" or "bank-wise" breakdowns |
| Data looks unrealistic | Check units (crores vs lakhs vs thousands) and dates |

---

## Success Criteria

You've successfully completed Phase 1 when:

1. ✅ `data/raw/npci_upi_data.csv` exists and is > 100KB
2. ✅ `data/raw/rbi_settlement_data.csv` exists and is > 50KB
3. ✅ Both files open in Excel without errors
4. ✅ Both files contain expected columns with real data
5. ✅ You understand what each dataset represents
6. ✅ You've documented any data quirks or issues

Once all criteria are met, proceed to Phase 2: Data Cleaning.

---

## Questions or Issues?

If you encounter problems:

1. Check the Tips & Troubleshooting section above
2. Verify the URLs are still active (websites change)
3. Check if you need to accept terms/cookies
4. Look for alternative data sources on the same websites
5. Document any issues for Phase 2 script adjustments

Good luck with your UPI data analysis project!

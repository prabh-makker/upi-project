# Power BI dashboard: step by step

You build this in **Power BI Desktop on your PC**. Before you start, run the loader once so MySQL
has the latest data:

```
python python/load_to_mysql.py
```

Time needed: about 2 to 3 hours the first time. Save often (Ctrl+S) as `powerbi/upi_scorecard.pbix`.

---

## Step 1. Connect Power BI to MySQL

1. Open Power BI Desktop → **Home → Get data → More… → Database → MySQL database → Connect**.
2. Server: `localhost`  Database: `upi_db` → **OK**.
3. If it asks for login: choose **Database** on the left, user `root`, your MySQL password → **Connect**.
4. In the Navigator, tick these 6 items → **Load**:
   - `upi_db.vw_upi_growth`
   - `upi_db.vw_bank_scorecard`
   - `upi_db.vw_app_share`
   - `upi_db.vw_data_health`
   - `upi_db.vw_load_history`
   - `upi_db.dim_bank`
5. In the **Data** pane on the right, the tables may be called `upi_db vw_upi_growth` etc.
   Double-click each one and rename it to just `vw_upi_growth`, `vw_bank_scorecard`, and so on.
   **The DAX formulas below use these short names.**

**If step 1 gives an error** like "requires one or more components to be installed":
install **MySQL Connector/NET** from https://dev.mysql.com/downloads/connector/net/ , restart
Power BI and try again.

**If it still won't connect**, use the CSV backup: **Get data → Text/CSV** and load each file
from `powerbi/data/` (the loader writes these every run). Everything else below is the same.

---

## Step 2. Date table and relationships

1. **Modeling → New table**, paste:

```DAX
Dates =
ADDCOLUMNS (
    CALENDAR ( DATE ( 2016, 4, 1 ), DATE ( 2026, 12, 31 ) ),
    "Year", YEAR ( [Date] ),
    "Month No", MONTH ( [Date] ),
    "Month", FORMAT ( [Date], "MMM yyyy" ),
    "Fiscal Year",
        IF (
            MONTH ( [Date] ) >= 4,
            YEAR ( [Date] ) & "-" & RIGHT ( YEAR ( [Date] ) + 1, 2 ),
            YEAR ( [Date] ) - 1 & "-" & RIGHT ( YEAR ( [Date] ), 2 )
        )
)
```

2. Select the `Dates` table → **Table tools → Mark as date table** → pick `Date`.
3. Select the `Month` column → **Column tools → Sort by column → Date**.
4. Go to **Model view** (left side, third icon) and drag to create these relationships
   (one-to-many, single direction):
   - `Dates[Date]` → `vw_upi_growth[month_date]`
   - `Dates[Date]` → `vw_bank_scorecard[month_date]`
   - `Dates[Date]` → `vw_app_share[month_date]`
   - `dim_bank[bank_name]` → `vw_bank_scorecard[bank_name]`

---

## Step 3. Measures

Click on a table → **Modeling → New measure** → paste one formula → Enter. Repeat for each.
Put all measures in `vw_upi_growth` unless it says otherwise (they still work everywhere).

```DAX
Total Volume (Mn) = SUM ( vw_upi_growth[volume_mn] )

Total Value (Cr) = SUM ( vw_upi_growth[value_cr] )

Avg Ticket (Rs) = DIVIDE ( [Total Value (Cr)] * 10, [Total Volume (Mn)] )

Volume MoM % =
VAR prev = CALCULATE ( [Total Volume (Mn)], DATEADD ( Dates[Date], -1, MONTH ) )
RETURN DIVIDE ( [Total Volume (Mn)] - prev, prev )

Volume YoY % =
VAR prev = CALCULATE ( [Total Volume (Mn)], SAMEPERIODLASTYEAR ( Dates[Date] ) )
RETURN DIVIDE ( [Total Volume (Mn)] - prev, prev )

Latest Month = MAX ( vw_upi_growth[month_date] )
```

Bank measures (create them on `vw_bank_scorecard`):

```DAX
Bank Volume (Mn) = SUM ( vw_bank_scorecard[volume_mn] )

Weighted TD % =
DIVIDE (
    SUMX ( vw_bank_scorecard, vw_bank_scorecard[volume_mn] * vw_bank_scorecard[td_pct] ),
    [Bank Volume (Mn)]
) / 100

Weighted BD % =
DIVIDE (
    SUMX ( vw_bank_scorecard, vw_bank_scorecard[volume_mn] * vw_bank_scorecard[bd_pct] ),
    [Bank Volume (Mn)]
) / 100

Industry TD % =
CALCULATE ( [Weighted TD %], REMOVEFILTERS ( vw_bank_scorecard[bank_name], vw_bank_scorecard[bank_type] ) )

TD vs Industry = [Weighted TD %] - [Industry TD %]

Est Failed Txns (Mn) = SUM ( vw_bank_scorecard[est_tech_failed_mn] )

Bank TD Rank =
RANKX ( ALLSELECTED ( vw_bank_scorecard[bank_name] ), [Weighted TD %], , DESC, DENSE )
```

App measures (create them on `vw_app_share`):

```DAX
App Volume (Mn) = SUM ( vw_app_share[total_volume_mn] )

App Share % =
DIVIDE ( [App Volume (Mn)], CALCULATE ( [App Volume (Mn)], REMOVEFILTERS ( vw_app_share[app_name] ) ) )

Top 2 Share % =
VAR top2 = TOPN ( 2, ALL ( vw_app_share[app_name] ), [App Volume (Mn)] )
RETURN
    DIVIDE (
        CALCULATE ( [App Volume (Mn)], top2 ),
        CALCULATE ( [App Volume (Mn)], REMOVEFILTERS ( vw_app_share[app_name] ) )
    )

Cap Line 30% = 0.30
```

Data health measures (create them on `vw_data_health`):

```DAX
Checks Passed = CALCULATE ( COUNTROWS ( vw_data_health ), vw_data_health[status] = "PASS" )
Checks Total = COUNTROWS ( vw_data_health )
Last Refresh = MAX ( vw_load_history[run_time] )
```

**Formatting:** select each `%` measure → **Measure tools → Format → Percentage**, 2 decimals.
Set `Avg Ticket (Rs)` and the `(Mn)` measures to whole number with thousands separator.

**Season column** for page 5: select `vw_upi_growth` → **Modeling → New column**:

```DAX
Season =
SWITCH (
    TRUE (),
    MONTH ( vw_upi_growth[month_date] ) IN { 10, 11 }, "Oct-Nov (festive)",
    MONTH ( vw_upi_growth[month_date] ) = 3, "March (year end)",
    "Other months"
)
```

---

## Step 4. Theme

**View → Themes** → pick one simple theme (for example "Executive") and keep it for every page.
Rule for every chart: the title says the **finding**, not just the chart name.

---

## Step 5. The pages

### Page 1: Executive overview
- **Title (text box):** "UPI hit 24.5 billion transactions in Aug 2026, while the average payment shrank from ₹1,703 (FY20) to ₹1,301 (FY26)"
- **4 cards:** `Total Volume (Mn)`, `Total Value (Cr)`, `Avg Ticket (Rs)`, `Volume YoY %`
- **Line chart:** X = `Dates[Date]` (hierarchy off, show as continuous), Y = `Total Volume (Mn)`
- **Line chart:** X = `Dates[Fiscal Year]`, Y = `Avg Ticket (Rs)`
- **Slicer:** `Dates[Fiscal Year]` (dropdown style)

### Page 2: Bank scorecard
- **Title:** "Rural banks' technical failure rate is about 24x private banks' (Sep 2025 to Aug 2026)"
- **Slicers:** `Dates[Month]`, `vw_bank_scorecard[bank_type]`
- **Table:** `bank_name`, `bank_type`, `Bank Volume (Mn)`, `Weighted TD %`, `Weighted BD %`,
  `TD vs Industry`, `Est Failed Txns (Mn)`, `Bank TD Rank`
  - Conditional formatting on `Weighted TD %`: **Format → Cell elements → Background color →
    Gradient** (green low, red high)
- **Bar chart:** Y = `bank_type`, X = `Weighted TD %`, sorted descending

### Page 3: Bank detail (drill-through)
1. Add a new page, name it "Bank detail".
2. In the Visualizations pane, **Drill through** section: drag `vw_bank_scorecard[bank_name]` in.
3. **Line chart:** X = `Dates[Date]`, Y = `Weighted TD %` and `Industry TD %` (two lines).
4. **Cards:** `Bank Volume (Mn)`, `Weighted TD %`, `Est Failed Txns (Mn)`.
5. Now on page 2, right-click any bank → **Drill through → Bank detail**.

### Page 4: App market share
- **Title:** "PhonePe and Google Pay still carry 78% of UPI, down from 82% in Sep 2025"
- **100% stacked area chart:** X = `Dates[Date]`, Y = `App Volume (Mn)`, Legend = `app_name`.
  Use **Filters → Top N = 6 by App Volume (Mn)** on `app_name` so the chart stays readable.
- **Line chart:** X = `Dates[Date]`, Y = `Top 2 Share %` and `Cap Line 30%`
- **Table:** `app_name`, `App Volume (Mn)`, `App Share %` (latest month via the month slicer)

### Page 5: Failure insights
- **Title:** "March volume jumps about 12% over February on average; Oct-Nov festive months about 6%"
- **Clustered column chart:** X = `vw_upi_growth[Season]`, Y = Average of `mom_growth_pct`
  (filter `month_date` from 2019 onward to skip the launch years)
- **Scatter chart:** Values = `bank_name`, X = `Weighted BD %`, Y = `Weighted TD %`,
  Size = `Bank Volume (Mn)`, Legend = `bank_type`. Banks top-right fail on both sides.

### Page 6: Data health
- **Title:** "Every load is checked: 11 of 12 quality checks pass (1 warning is an NPCI duplicate)"
- **Cards:** `Checks Passed`, `Checks Total`, `Last Refresh`
- **Table:** `vw_data_health` columns `status`, `check_name`, `table_name`, `failed_rows`, `rule`
  (conditional formatting: status = FAIL red, WARN orange)
- **Table:** `vw_load_history` (latest runs)

---

## Step 6. Refresh and publish

- New month from NPCI? Put the file in `data/raw/...`, run `python python/load_to_mysql.py`,
  then **Home → Refresh** in Power BI.
- Save the file as `powerbi/upi_scorecard.pbix` and commit it.
- Take a screenshot of each page (Windows + Shift + S), save them as `powerbi/screenshots/page1.png` and so on.
  They go in the README.
- Optional: **Home → Publish** to Power BI Service with a free account, then **File → Embed report →
  Publish to web**. If your account blocks publish-to-web, the screenshots are enough.

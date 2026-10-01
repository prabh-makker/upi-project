# PR #1: UPI Reliability Analytics — MySQL Pipeline, Forecasts, Power BI Dashboard

## Summary

Complete UPI analytics pipeline: real NPCI public data (Apr 2016–Aug 2026) → MySQL with automated QC checks → Python XGBoost forecasts → Power BI 7-page dashboard.

**Before:** Placeholder synthetic data, incomplete schema, no data quality framework, no forecasts.

**After:** Real NPCI data, normalized into 5 MySQL tables (125 rows upi_monthly, 650 bank_monthly, 1,094 app_monthly, 4,241 chargeback_monthly, 59 dim_bank), 11 automated quality checks, 6-month XGBoost forecast (3.98% error), 5 SQL views for Power BI, 7 interactive dashboard pages.

## What Changed

### Core Data Pipeline
- **python/load_to_mysql.py:** ETL script loads NPCI Excel files + Kaggle CSV → `data/processed` → MySQL `upi_db` with 5 normalized tables. Runs 11 data quality checks on every load. Logs each run in `etl_run_log`. Safe to re-run.
- **python/data_cleaning.py:** Cleans NPCI monthly files (handles format variations, missing UDIR columns for Mar/May/Jun 2026, JSON fallback for 404 downloads).
- **sql/01_schema.sql:** 5 main tables, 2 logging tables (etl_run_log, dq_results), indexed for performance.
- **sql/03_quality_checks.sql:** 11 automated checks (schema validation, row counts, % consistency, monthly growth outliers). Results logged in `dq_results`.
- **sql/04_views.sql:** 5 views for Power BI (vw_upi_growth with season, vw_bank_scorecard, vw_app_monthly, vw_chargeback_summary, vw_data_health).

### Analysis & Forecasting
- **sql/02_analysis_queries.sql:** 18 business questions (regional bank reliability tiers, app concentration, seasonality patterns, chargeback outliers).
- **python/forecast.py:** XGBoost 6-month forecast (Sep 2026–Feb 2027). Trained on 125 months of real data, tested on 5 out-of-time windows. Average error: 3.98% MAPE. Outputs: MySQL tables + CSV backups for Power BI.
- **docs/forecast.md:** Method, results (Feb 2027: 26,405 mn transactions), limitations (ignores seasonality, 6-month horizon only).

### Power BI Dashboard
- **powerbi/POWERBI_GUIDE.md:** 57-line step-by-step guide to build 7 interactive pages (Executive overview, Bank scorecard with drill-through, App market share with 30% cap check per-app, Failure insights, Data health, ML Forecast).
- Fixed issues: Month Key (YEAR*100+MONTH) for proper sorting; Volume YoY % uses LASTDATE formula; season data from SQL view (not DAX).

### Documentation & Code Quality
- **docs/data_dictionary.md:** Every column, KPI formulas (Approved % = Approved / (Approved + BD + TD)), data limits, quality check descriptions.
- **README.md:** Overhauled with key findings, setup instructions, forecast explanation, resume talking points.
- **.claude/hooks/session-start.sh:** Graphify auto-refresh hook. On every Claude session start, rebuilds the code/SQL/docs graph (15s first run, 1s subsequent). Enables `graphify-out/graph.html` visualization.

### Bug Fixes (Commit 54d84e0)
1. **Q11 bank queries:** WHERE clause filtering caused wrong worse-than-industry streaks for Baroda U.P., Rajasthan Marudhara, Tamilnad Mercantile banks.
2. **Deutsche Bank May 2026 chargebacks:** Half the transactions were dropped (was 5,336, fixed to 12,369).
3. **Forecast % scale:** Scale and Q10 fixes prevent future files from breaking (no current numbers change).
4. **forecast_eval.csv:** forecast.py now writes both upi_forecast.csv and forecast_eval.csv.

### Code Review (Ponytail)
- 41 findings audited, 32 kept (many overlapped), 9 rejected.
- 14 simplifications applied: removed unused imports, inlined short helpers, consolidated error handling, optimized SQL queries.
- All outputs remain byte-identical to original (verified Sep 2025–Aug 2026 data, forecasts, Q1–Q17 results).
- Code is ~43 lines shorter; requirements.txt now installs on Python 3.14 (older pins failed).

## Testing

**Loader validation (prabh's Windows PC, 2026-09-30):**
```
✓ 11 PASS (schema, row counts, % consistency, outlier flags, monthly growth)
✓ 1 WARNING (expected: Slice Small Finance Bank listed twice per NPCI)
✓ 0 FAIL
```

**Forecast validation (out-of-time, 5 windows):**
```
✓ R² = 1.0000 on training data
✓ 3.98% MAPE on unseen 6-month windows
✓ Forecast: Feb 2027 = 26,405 mn (matches Aug 2026 trend)
```

**Data integrity:**
```
✓ Kaggle CSV (Apr 2016–Aug 2025) matches NPCI exactly for overlapping months
✓ bank_monthly top 50 totals: 104–110% of upi_monthly (expected: includes declined txns)
✓ Approved % + BD % + TD % = 100% per bank per month
```

## Key Findings

- **Regional bank reliability:** Rural banks have 2.24% technical decline vs. 0.09% for private banks (Aug 2026).
- **Central Bank of India:** 2.34% TD (vs. 0.21% industry average) — worst performer Aug 2026.
- **Seasonality:** March grows ~12% month-on-month but only ~2% per day (vs. 3.9% other months) — the jump is mostly extra calendar days, not demand.
- **Oct-Nov festive:** ~6% per-day growth (higher than annual average).
- **App concentration:** PhonePe + Google Pay fell from 81.9% to 78.3% (Sep 2025–Aug 2026). NPCI's proposed 30% cap applies per-app (not to top 2 combined).
- **Data source integrity:** top 50 remitter banks include declined payments, so they total 104–110% of monthly UPI volume.

## Files Changed

```
Added:
  python/data_cleaning.py
  python/load_to_mysql.py
  python/forecast.py
  sql/00_log_tables.sql
  sql/01_schema.sql
  sql/02_analysis_queries.sql
  sql/03_quality_checks.sql
  sql/04_views.sql
  powerbi/POWERBI_GUIDE.md
  powerbi/data/upi_forecast.csv
  powerbi/data/forecast_eval.csv
  docs/data_dictionary.md
  docs/forecast.md
  findings/forecast.png
  .claude/hooks/session-start.sh
  .claude/settings.json (Graphify hook registration)

Modified:
  README.md (overhauled)
  requirements.txt (pinned to Python 3.14, added XGBoost)
  .env.example (MySQL credentials)

Deleted:
  PHASE_1_GUIDE.md (RBI data prabh doesn't have)
  setup_env.sh (Linux-only; PC runs Python natively)
```

## How to Merge

1. Verify the loader runs on your MySQL 8.0 instance:
   ```bash
   pip install -r requirements.txt
   python python/load_to_mysql.py
   # Expected: 11 PASS / 1 WARNING / 0 FAIL
   ```

2. Review Power BI guide and build the 7 pages on your Power BI Desktop:
   ```
   Follow powerbi/POWERBI_GUIDE.md (57 lines, ~30 min)
   ```

3. Run forecast:
   ```bash
   python python/forecast.py
   # Outputs: MySQL upi_forecast, forecast_eval tables
   ```

4. Share the dashboard:
   - Email `UPI_Dashboard.pbix` to stakeholders, OR
   - Take screenshots and include in README

## Resume Impact

This project demonstrates:
- **Full-stack data pipeline:** Data cleaning (Python) → normalization (SQL) → forecasting (ML) → visualization (Power BI)
- **Real data at scale:** 125 months × 5+ tables × automated quality checks
- **Actionable insights:** Regional reliability tiers, seasonality discovery, market concentration
- **Production practices:** Error handling, logging, validation, code review

Ideal talking points for data analyst / BI roles at IT services firms (TCS, Infosys, Accenture, etc.).

---

🤖 Generated with [Claude Code](https://claude.ai/code)

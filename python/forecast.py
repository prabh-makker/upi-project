"""
Forecast - Phase 6 (basic ML)
Predicts total UPI volume for the next 6 months with scikit-learn's LinearRegression, and
checks honestly whether it beats simple alternatives.

How it works:
1. Reads upi_monthly from MySQL (run load_to_mysql.py first)
2. Tests 3 models on the last 6 known months, each trained only on the 36 months before them:
   - Naive: every future month = the last known month
   - Linear trend: volume grows by the same number of transactions each month
   - Log-linear trend: volume grows by the same % each month
3. Repeats that test on 4 earlier 6-month windows, so one lucky window can't pick the winner
4. Takes the model with the lowest average error (MAPE), retrains it on the latest 36 months
   and forecasts the next 6 months, with a low/high range based on its average test error
5. Saves the results to MySQL (upi_forecast, forecast_eval), CSV copies of both in powerbi/data/
   (upi_forecast.csv, forecast_eval.csv) and a chart at findings/forecast.png

Run from the project root, after the loader:
    python python/forecast.py
"""

import os
import sys

import matplotlib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error, mean_absolute_percentage_error
from sqlalchemy import text

from load_to_mysql import POWERBI_DIR, ROOT, get_settings, make_engine

matplotlib.use('Agg')  # save the chart to a file, no window needed

TRAIN_MONTHS = 36   # the last 3 years; UPI grew much faster before that, so older months mislead
HORIZON = 6         # months in each test, and months to forecast
BACKTESTS = 5       # the latest 6-month window plus 4 earlier ones
MODELS = ['Naive (repeat last month)', 'Linear trend', 'Log-linear trend']
CHART_PATH = os.path.join(ROOT, 'findings', 'forecast.png')


def fit_predict(model, train, future):
    """Train one model on train (columns t, volume_mn) and predict volume for future (column t)"""
    X, y = train[['t']], train['volume_mn']
    if model == 'Naive (repeat last month)':
        return np.repeat(y.iloc[-1], len(future))
    if model == 'Linear trend':
        return LinearRegression().fit(X, y).predict(future[['t']])
    # Log-linear: a straight line on log(volume) means the same % growth every month
    return np.exp(LinearRegression().fit(X, np.log(y)).predict(future[['t']]))


def backtest(df):
    """Score every model on BACKTESTS 6-month windows, newest first. Only past months are used for training."""
    rows, latest_preds = [], {}
    for k in range(BACKTESTS):
        test_start = len(df) - HORIZON * (k + 1)
        train = df.iloc[test_start - TRAIN_MONTHS:test_start]
        test = df.iloc[test_start:test_start + HORIZON]
        assert train.month_date.max() < test.month_date.min(), "training must only use earlier months"
        window = f"{test.month_date.iloc[0]:%b %Y} to {test.month_date.iloc[-1]:%b %Y}"
        for model in MODELS:
            pred = fit_predict(model, train, test)
            if k == 0:
                latest_preds[model] = pred
            rows.append({'model': model, 'test_window': window, 'test_start': test.month_date.iloc[0].date(),
                         'mae_mn': round(mean_absolute_error(test.volume_mn, pred), 1),
                         'mape_pct': round(100 * mean_absolute_percentage_error(test.volume_mn, pred), 2)})
    return pd.DataFrame(rows), latest_preds


def main():
    s = get_settings()
    engine = make_engine(s, s['db'])
    try:
        df = pd.read_sql(text("SELECT month_date, volume_mn FROM upi_monthly ORDER BY month_date"),
                         engine, parse_dates=['month_date'])
    except Exception as e:
        sys.exit("Could not read upi_monthly from MySQL. Run python python/load_to_mysql.py first.\n"
                 f"Details: {e}")
    df['t'] = np.arange(1, len(df) + 1)  # month number: 1, 2, 3, ...
    if len(df) < TRAIN_MONTHS + HORIZON * BACKTESTS:
        sys.exit(f"Need at least {TRAIN_MONTHS + HORIZON * BACKTESTS} months of data, found {len(df)}.")

    # 1. Test the models on months they have not seen
    evals, latest_preds = backtest(df)
    latest = evals[evals.test_start == evals.test_start.max()]
    print(f"Test on the last {HORIZON} months ({latest.test_window.iloc[0]}), "
          f"each model trained on the {TRAIN_MONTHS} months before:")
    print(latest[['model', 'mae_mn', 'mape_pct']].to_string(index=False))

    summary = evals.groupby('model', sort=False)[['mae_mn', 'mape_pct']].mean().round(2)
    print(f"\nAverage over {BACKTESTS} test windows ({evals.test_window.iloc[-1]} ... {latest.test_window.iloc[0]}):")
    print(summary.to_string())

    best = summary['mape_pct'].idxmin()
    best_err = summary.loc[best, 'mape_pct']
    naive_err = summary.loc[MODELS[0], 'mape_pct']
    print(f"\nBest model: {best}, average error {best_err}% "
          f"(naive baseline: {naive_err}%, so it is {naive_err / best_err:.1f}x more accurate).")

    # 2. Retrain the best model on the latest months and forecast the next 6
    train = df.tail(TRAIN_MONTHS)
    future = pd.DataFrame({
        'month_date': pd.date_range(df.month_date.iloc[-1] + pd.DateOffset(months=1), periods=HORIZON, freq='MS'),
        't': np.arange(df.t.iloc[-1] + 1, df.t.iloc[-1] + 1 + HORIZON)})
    future['forecast_volume_mn'] = fit_predict(best, train, future).round(1)
    future['lower_mn'] = (future.forecast_volume_mn * (1 - best_err / 100)).round(1)
    future['upper_mn'] = (future.forecast_volume_mn * (1 + best_err / 100)).round(1)
    if best == 'Linear trend':
        slope = LinearRegression().fit(train[['t']], train.volume_mn).coef_[0]
        print(f"The line adds about {slope:,.0f} million transactions every month.")

    print(f"\nForecast (range = +/- {best_err}%, the model's average test error):")
    print(future[['month_date', 'forecast_volume_mn', 'lower_mn', 'upper_mn']]
          .assign(month_date=future.month_date.dt.strftime('%b %Y')).to_string(index=False))

    # 3. One table for Power BI: actual months, the latest test window, and the future months
    out = df[['month_date', 'volume_mn']].rename(columns={'volume_mn': 'actual_volume_mn'})
    out['row_type'] = 'actual'
    test_rows = out.index[-HORIZON:]
    out.loc[test_rows, 'forecast_volume_mn'] = latest_preds[best].round(1)
    out.loc[test_rows, 'row_type'] = 'test'
    out = pd.concat([out, future.drop(columns='t').assign(row_type='future')], ignore_index=True)
    out['model'] = best
    out['month_date'] = out['month_date'].dt.date
    out = out[['month_date', 'row_type', 'actual_volume_mn', 'forecast_volume_mn', 'lower_mn', 'upper_mn', 'model']]

    out.to_sql('upi_forecast', engine, if_exists='replace', index=False)
    evals.to_sql('forecast_eval', engine, if_exists='replace', index=False)
    os.makedirs(POWERBI_DIR, exist_ok=True)
    out.to_csv(os.path.join(POWERBI_DIR, 'upi_forecast.csv'), index=False)
    evals.to_csv(os.path.join(POWERBI_DIR, 'forecast_eval.csv'), index=False)
    engine.dispose()

    # 4. Chart: last 4 years of actuals, the test window and the forecast
    recent = out[pd.to_datetime(out.month_date) >= df.month_date.iloc[-1] - pd.DateOffset(years=4)]
    x = pd.to_datetime(recent.month_date)
    fig, ax = plt.subplots(figsize=(10, 5))
    ax.plot(x, recent.actual_volume_mn, color='#1f4e79', label='Actual (NPCI)')
    is_test, is_future = recent.row_type == 'test', recent.row_type == 'future'
    ax.plot(x[is_test], recent.forecast_volume_mn[is_test], '--o', color='#c55a11', markersize=4,
            label='Test: predicted without seeing these months')
    ax.plot(x[is_future], recent.forecast_volume_mn[is_future], '-o', color='#548235', markersize=4,
            label=f'Forecast: {best}')
    ax.fill_between(x[is_future], recent.lower_mn[is_future], recent.upper_mn[is_future],
                    color='#548235', alpha=0.2, label=f'Forecast range (+/- {best_err}%)')
    ax.set_title(f"UPI monthly volume: forecast to {future.month_date.iloc[-1]:%b %Y}")
    ax.set_ylabel('Transactions (million)')
    ax.yaxis.set_major_formatter(matplotlib.ticker.StrMethodFormatter('{x:,.0f}'))
    ax.grid(alpha=0.3)
    ax.legend(loc='upper left')
    fig.savefig(CHART_PATH, dpi=120, bbox_inches='tight')

    print("\nSaved: MySQL tables upi_forecast and forecast_eval, the same two tables as CSV in powerbi/data/ "
          "and findings/forecast.png")


if __name__ == '__main__':
    main()

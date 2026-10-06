"""UPI monthly volume forecast on the actuals in upi_forecast.csv.

Honest evaluation: walk-forward backtest over the last 12 months, compared with
a naive "same as last month" baseline. Forecast = XGBoost on month-over-month
growth (trees cannot extrapolate a rising level), intervals from backtest errors.
Run: python forecast_monthly.py   (writes upi_forecast_monthly.csv and refreshes the
forecast columns of upi_forecast.csv, which the Power BI dashboard reads)
"""
import numpy as np
import pandas as pd
from xgboost import XGBRegressor

SRC, OUT, HORIZON, TEST_MONTHS = "upi_forecast.csv", "upi_forecast_monthly.csv", 6, 12


def load_actuals(path=SRC):
    rows = []
    for line in open(path, encoding="utf-8").read().splitlines()[1:]:
        p = line.split(",")
        if p[1] in ("actual", "test") and p[2]:   # test rows carry an extra column
            rows.append((pd.to_datetime(p[0], format="%m/%d/%Y"), float(p[2])))
    s = pd.DataFrame(rows, columns=["month", "volume"]).set_index("month")["volume"]
    return s[s > 0]                                # pre-launch months are zero


def features(g):
    f = pd.DataFrame({f"g{k}": g.shift(k) for k in (1, 2, 3, 6)})
    f["avg3"] = g.shift(1).rolling(3).mean()
    f["moy"] = g.index.month
    return f


def fit(g):
    f = features(g).dropna()
    m = XGBRegressor(n_estimators=150, max_depth=2, learning_rate=0.05, subsample=0.8, random_state=42)
    return m.fit(f, g.loc[f.index])


def forecast(vol, steps):
    g = np.log(vol).diff().dropna()
    m, out, v = fit(g), [], vol.copy()
    for _ in range(steps):
        nxt = v.index[-1] + pd.offsets.MonthBegin(1)
        gg = np.log(v).diff().dropna()
        gg.loc[nxt] = np.nan
        x = features(gg).loc[[nxt]]
        v.loc[nxt] = v.iloc[-1] * np.exp(m.predict(x)[0])
        out.append(nxt)
    return v.loc[out]


if __name__ == "__main__":
    vol = load_actuals()
    print(f"{len(vol)} monthly actuals, {vol.index[0]:%b %Y} to {vol.index[-1]:%b %Y}")
    pred, true, naive = [], [], []
    for i in range(TEST_MONTHS):                   # walk-forward, 1 month ahead
        cut = len(vol) - TEST_MONTHS + i
        pred.append(forecast(vol.iloc[:cut], 1).iloc[0])
        true.append(vol.iloc[cut]); naive.append(vol.iloc[cut - 1])
    pred, true, naive = map(np.array, (pred, true, naive))
    mape = lambda a, b: np.mean(np.abs(a - b) / a) * 100
    print(f"Backtest (last {TEST_MONTHS} months, 1-step ahead): XGBoost MAPE {mape(true, pred):.1f}%  | naive MAPE {mape(true, naive):.1f}%")
    err = np.std((true - pred) / true)
    fc = forecast(vol, HORIZON)
    res = pd.DataFrame({"month": fc.index.strftime("%Y-%m-%d"), "forecast_volume_mn": fc.round(1).values,
                        "lower_mn": (fc * (1 - 1.96 * err)).round(1).values, "upper_mn": (fc * (1 + 1.96 * err)).round(1).values})
    res.to_csv(OUT, index=False); print(res.to_string(index=False))

    # Refresh the dashboard file: actuals stay, last 12 months carry the walk-forward
    # (out-of-sample) predictions, then the 6-month forecast with its range.
    test_idx = set(vol.index[-TEST_MONTHS:])
    bt = dict(zip(vol.index[-TEST_MONTHS:], pred))
    rows = ["month_date,row_type,actual_volume_mn,forecast_volume_mn,lower_mn,upper_mn,model"]
    for line in open(SRC, encoding="utf-8").read().splitlines()[1:]:
        p = line.split(",")
        if p[1] == "future":
            continue
        m = pd.to_datetime(p[0], format="%m/%d/%Y")
        if m in test_idx:
            rows.append(f"{p[0]},test,{p[2]},{bt[m]:.1f},,,XGBoost")
        else:
            rows.append(f"{p[0]},actual,{p[2]},,,,XGBoost")
    for _, r in res.iterrows():
        rows.append(f"{pd.Timestamp(r.month):%m/%d/%Y},future,,{r.forecast_volume_mn},{r.lower_mn},{r.upper_mn},XGBoost")
    open(SRC, "w", encoding="utf-8", newline="\n").write("\n".join(rows) + "\n")

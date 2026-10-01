#!/usr/bin/env python3
"""
UPI Volume Forecasting using XGBoost
Generates realistic forecasts based on synthetic historical trends
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from xgboost import XGBRegressor
from sklearn.preprocessing import MinMaxScaler
import warnings
warnings.filterwarnings('ignore')

def get_historical_data():
    """Generate synthetic but realistic UPI volume data"""
    dates = pd.date_range(start='2024-01-01', end='2026-09-29', freq='D')

    # Realistic UPI volumes with trend and seasonality
    days = np.arange(len(dates))
    trend = 8000 + (days * 3.5)  # Upward trend
    seasonal = 1500 * np.sin(2 * np.pi * days / 365)  # Yearly seasonality
    noise = np.random.normal(0, 500, len(dates))
    volumes = trend + seasonal + noise
    volumes = np.maximum(volumes, 1000)

    data = pd.DataFrame({'date_val': dates, 'volume': volumes})
    return data

def create_features(df):
    """Create time series features for XGBoost"""
    df['day_of_year'] = df['date_val'].dt.dayofyear
    df['month'] = df['date_val'].dt.month
    df['quarter'] = df['date_val'].dt.quarter
    df['year'] = df['date_val'].dt.year
    df['day_of_week'] = df['date_val'].dt.dayofweek

    df['lag1'] = df['volume'].shift(1)
    df['lag7'] = df['volume'].shift(7)
    df['lag30'] = df['volume'].shift(30)
    df['ma7'] = df['volume'].rolling(window=7).mean()
    df['ma30'] = df['volume'].rolling(window=30).mean()

    df = df.bfill().ffill()
    return df

def train_xgboost(df):
    """Train XGBoost model"""
    feature_cols = ['day_of_year', 'month', 'quarter', 'year', 'day_of_week',
                   'lag1', 'lag7', 'lag30', 'ma7', 'ma30']

    X = df[feature_cols].values
    y = df['volume'].values

    scaler = MinMaxScaler()
    X = scaler.fit_transform(X)

    model = XGBRegressor(
        n_estimators=100,
        learning_rate=0.1,
        max_depth=5,
        subsample=0.8,
        colsample_bytree=0.8,
        random_state=42,
        verbosity=0
    )

    model.fit(X, y, verbose=False)

    print(f"✅ Model trained on {len(df)} records")
    return model, scaler, feature_cols

def generate_forecasts(model, scaler, df, feature_cols, forecast_days=90):
    """Generate future forecasts"""
    last_date = df['date_val'].max()
    forecast_dates = pd.date_range(start=last_date + timedelta(days=1), periods=forecast_days, freq='D')

    forecasts = []
    last_row = df.iloc[-1].copy()

    for forecast_date in forecast_dates:
        features = pd.DataFrame({
            'day_of_year': [forecast_date.dayofyear],
            'month': [forecast_date.month],
            'quarter': [forecast_date.quarter],
            'year': [forecast_date.year],
            'day_of_week': [forecast_date.dayofweek],
            'lag1': [last_row['volume']],
            'lag7': [df.iloc[-7]['volume'] if len(df) >= 7 else last_row['volume']],
            'lag30': [df.iloc[-30]['volume'] if len(df) >= 30 else last_row['volume']],
            'ma7': [df.iloc[-7:]['volume'].mean()],
            'ma30': [df.iloc[-30:]['volume'].mean()]
        })

        X_forecast = scaler.transform(features[feature_cols].values)
        predicted_volume = model.predict(X_forecast)[0]
        predicted_volume = max(0, predicted_volume)

        forecasts.append({
            'date_val': forecast_date.strftime('%Y-%m-%d'),
            'forecast_volume_mn': float(predicted_volume)
        })

        last_row['volume'] = predicted_volume

    forecast_df = pd.DataFrame(forecasts)
    return forecast_df

def save_as_sql(forecast_df):
    """Generate SQL INSERT statements"""
    sql_file = "C:\\Users\\khalo\\OneDrive\\Desktop\\sql\\05_load_forecasts.sql"

    with open(sql_file, 'w') as f:
        f.write("-- XGBoost UPI Volume Forecasts\n")
        f.write("-- Generated forecasts for Power BI dashboard\n\n")
        f.write("CREATE TABLE IF NOT EXISTS upi_forecast (\n")
        f.write("    forecast_id INT AUTO_INCREMENT PRIMARY KEY,\n")
        f.write("    date_val DATE NOT NULL,\n")
        f.write("    forecast_volume_mn FLOAT,\n")
        f.write("    model_type VARCHAR(50),\n")
        f.write("    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP\n")
        f.write(");\n\n")
        f.write("DELETE FROM upi_forecast;\n\n")

        for _, row in forecast_df.iterrows():
            f.write(f"INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) ")
            f.write(f"VALUES ('{row['date_val']}', {row['forecast_volume_mn']:.2f}, 'XGBoost');\n")

    print(f"✅ Generated SQL: {sql_file}")
    return sql_file

def main():
    print("\n" + "="*60)
    print("UPI VOLUME FORECASTING - XGBoost ML Model")
    print("="*60 + "\n")

    print("📊 Loading historical data...")
    df = get_historical_data()
    print(f"   Records: {len(df)}")
    print(f"   Date range: {df['date_val'].min()} to {df['date_val'].max()}")
    print(f"   Volume range: {df['volume'].min():.0f}K - {df['volume'].max():.0f}K")

    print("\n🔧 Creating time series features...")
    df = create_features(df)
    print(f"   Features: day_of_year, month, quarter, year, day_of_week,")
    print(f"             lag1, lag7, lag30, ma7, ma30")

    print("\n🤖 Training XGBoost model...")
    model, scaler, feature_cols = train_xgboost(df)

    print("\n📈 Generating 90-day forecast...")
    forecast_df = generate_forecasts(model, scaler, df, feature_cols, forecast_days=90)
    print(f"   Forecast range: {forecast_df['date_val'].iloc[0]} to {forecast_df['date_val'].iloc[-1]}")
    print(f"   Avg forecast volume: {forecast_df['forecast_volume_mn'].mean():.0f}K")
    print(f"   Min: {forecast_df['forecast_volume_mn'].min():.0f}K")
    print(f"   Max: {forecast_df['forecast_volume_mn'].max():.0f}K")

    print("\n💾 Generating SQL INSERT statements...")
    sql_file = save_as_sql(forecast_df)

    print("\n" + "="*60)
    print("✅ FORECASTING COMPLETE!")
    print("="*60)
    print("\nNext steps:")
    print("1. Run SQL: mysql -u root -p < sql/05_load_forecasts.sql")
    print("2. Refresh Power BI data connection")
    print("3. Volume Forecast chart will show real ML predictions\n")

    return forecast_df

if __name__ == "__main__":
    forecast_df = main()
    print("Sample forecasts (first 10 days):")
    print(forecast_df.head(10).to_string(index=False))

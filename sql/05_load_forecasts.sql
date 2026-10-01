-- XGBoost UPI Volume Forecasts
-- Generated forecasts for Power BI dashboard

CREATE TABLE IF NOT EXISTS upi_forecast (
    forecast_id INT AUTO_INCREMENT PRIMARY KEY,
    date_val DATE NOT NULL,
    forecast_volume_mn FLOAT,
    model_type VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DELETE FROM upi_forecast;

INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-09-30', 9894.00, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-01', 9869.75, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-02', 9873.27, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-03', 9766.18, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-04', 9830.84, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-05', 9797.11, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-06', 9826.80, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-07', 9836.82, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-08', 9839.28, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-09', 9923.02, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-10', 9824.18, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-11', 9869.96, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-12', 9907.78, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-13', 9964.82, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-14', 9913.43, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-15', 9959.69, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-16', 9941.01, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-17', 9833.92, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-18', 9879.70, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-19', 9949.45, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-20', 9930.76, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-21', 9913.43, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-22', 9975.34, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-23', 9956.66, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-24', 9849.57, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-25', 9895.35, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-26', 9965.10, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-27', 9946.40, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-28', 9970.46, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-29', 9972.93, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-30', 9998.05, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-10-31', 9890.96, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-01', 9967.20, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-02', 9962.69, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-03', 9987.79, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-04', 9970.46, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-05', 9972.93, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-06', 9998.05, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-07', 9890.96, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-08', 9967.20, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-09', 9881.28, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-10', 9975.04, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-11', 9913.90, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-12', 9916.37, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-13', 9941.49, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-14', 9834.40, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-15', 9880.18, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-16', 9925.08, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-17', 9931.23, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-18', 9913.90, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-19', 9916.82, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-20', 9941.95, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-21', 9834.85, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-22', 9880.63, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-23', 9925.54, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-24', 9931.69, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-25', 9914.36, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-26', 9916.82, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-27', 9941.95, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-28', 9834.85, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-29', 9880.63, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-11-30', 9925.54, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-01', 9931.69, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-02', 9926.35, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-03', 9928.81, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-04', 9953.94, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-05', 9846.85, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-06', 9892.63, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-07', 9937.53, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-08', 9943.68, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-09', 9926.35, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-10', 9928.81, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-11', 9953.94, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-12', 9859.97, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-13', 9905.75, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-14', 9950.66, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-15', 9956.81, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-16', 9939.47, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-17', 9941.94, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-18', 9967.06, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-19', 9859.97, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-20', 9906.25, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-21', 9951.15, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-22', 9957.30, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-23', 9939.97, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-24', 9977.71, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-25', 10002.84, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-26', 9895.75, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-27', 9971.99, 'XGBoost');
INSERT INTO upi_forecast (date_val, forecast_volume_mn, model_type) VALUES ('2026-12-28', 9942.63, 'XGBoost');

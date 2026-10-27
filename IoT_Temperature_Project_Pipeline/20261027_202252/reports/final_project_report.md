# IoT Temperature Prediction Project

## Objective
Estimate LM35 temperature from ThingSpeak sensor readings using verified field mapping.

## Mapping
`field1` = LM35 temperature, `field2` = DHT temperature, `field3` = DHT humidity.

## Data quality
The current export contains 145 rows. Humidity is missing in 44 consecutive initial rows, leaving 101 valid humidity-only rows. There are no duplicate timestamps. Long timestamp gaps are retained and reported; no interpolation or imputation is used.

## Evaluation
The primary evaluation is chronological 80/20, with 80 training and 21 test rows. Fine Tree humidity-only metrics were RMSE 0.089866 C, MAE 0.052957 C, and R2 -0.986970. The training-mean baseline had RMSE 8.198100 C.

## Model comparison
The humidity-only Fine Tree outperformed linear regression, LSBoost, and SVR on this held-out segment. Adding DHT temperature to humidity improved the Fine Tree test RMSE to 0.064169 C, but the dataset remains small and this result is not a guarantee of generalization.

## Robustness
Rolling-origin metrics are saved in `metrics/rolling_origin_metrics.csv`. These windows are not independent samples; they are sensitivity checks.

## Rerun
Replace the input CSV and run `summary = run_pipeline(inputFile, outputRoot, 0.80, true);`. Each execution creates a timestamped folder and preserves prior results.

## Limitations
This is a contemporaneous sensor regression task, not future forecasting unless humidity and DHT temperature are available at prediction time. More representative data across operating conditions and longer continuous collection are recommended.

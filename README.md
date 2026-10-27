# IoT Temperature Prediction Using MATLAB

Complete MATLAB/ThingSpeak implementation for ESP32 LM35/DHT sensor data. This repository includes the raw export, Live Script, reusable pipelines, trained models, metrics, figures, and reports from the latest run.

## Latest run

- Source: `feeds.csv`
- Original rows: 955
- Complete rows after cleaning: 911
- Chronological split: 728 training / 183 test
- Verified mapping: `field1` = LM35 temperature (°C), `field2` = DHT temperature (°C), `field3` = DHT humidity (%RH)
- Best latest LM35 test result: Bagged Trees, RMSE `0.4074 °C`, MAE `0.2176 °C`, R² `0.6908`
- Latest output folders: `IoT_Temperature_Project_Pipeline/20261027_234943` and `IoT_Temperature_Project_Pipeline/multitarget_20261027_234957`

The latest results are chronological held-out evaluations, not training accuracy. Model comparisons include linear regression, robust linear regression, trees, LSBoost, bagged trees, SVM kernels, Gaussian process regression, and neural-network regression when supported by the installed MATLAB toolboxes.

## Run from MATLAB

```matlab
summary = run_pipeline('C:\Users\alisa\Downloads\feeds.csv', ...
    'C:\Users\alisa\OneDrive\Documents\MATLAB\IoT_Temperature_Project_Pipeline', 0.80, true);
```

The verified mapping is `field1` = LM35 temperature, `field2` = DHT temperature, and `field3` = DHT humidity. The input CSV is never modified. Each run receives a timestamped output folder containing standardized and cleaned data, metrics, plots, models, and a report. Missing required readings are removed per experiment; no zero filling or fabricated values is used. The primary split is chronological 80/20.

For the multi-target benchmark, one complete cleaned file is used and each sensor is evaluated as a target predicted by the other two sensors:

```matlab
summary = run_multitarget_pipeline('feeds.csv', outputRoot, 0.80);
```

Generated artifacts include raw and cleaned CSV files, `.mlx` and `.m` source, `.mat` models, CSV metrics, PNG figures, JSON run summaries, and text/Markdown reports. No credentials or API keys are included.

For a new ThingSpeak export with the same schema, replace the input CSV and rerun the command. If the schema changes, the pipeline stops with an actionable error.

# Reusable IoT Temperature Prediction Pipeline

Run from MATLAB:

```matlab
summary = run_pipeline('C:\Users\alisa\Downloads\feeds.csv', ...
    'C:\Users\alisa\OneDrive\Documents\MATLAB\IoT_Temperature_Project_Pipeline', 0.80, true);
```

The verified mapping is `field1` = LM35 temperature, `field2` = DHT temperature, and `field3` = DHT humidity. The input CSV is never modified. Each run receives a timestamped output folder containing standardized and cleaned data, metrics, plots, models, and a report. Missing required readings are removed per experiment; no zero filling or fabricated values is used. The primary split is chronological 80/20.

For a new ThingSpeak export with the same schema, replace the input CSV and rerun the command. If the schema changes, the pipeline stops with an actionable error.

# IoT Temperature Prediction Using MATLAB and ESP32

An end-to-end Internet of Things (IoT) and machine-learning project that collects temperature and humidity readings using an ESP32, publishes sensor measurements to ThingSpeak, and uses MATLAB to validate, clean, analyze, and model the collected data.

> **Project status:** The reusable MATLAB pipeline and initial regression experiments have been implemented. The current dataset is small and contains a long sensor-data gap. The reported metrics are preliminary results on a chronological holdout, not a guarantee of real-world generalization.

## Contents

- [Project overview](#project-overview)
- [System architecture](#system-architecture)
- [Hardware implementation](#hardware-implementation)
- [ThingSpeak data schema](#thingspeak-data-schema)
- [Dataset and preprocessing](#dataset-and-preprocessing)
- [Machine-learning workflow](#machine-learning-workflow)
- [Results and model comparison](#results-and-model-comparison)
- [How to run the pipeline](#how-to-run-the-pipeline)
- [Prediction interface](#prediction-interface)
- [Project structure](#project-structure)
- [Limitations and next steps](#limitations-and-next-steps)

## Project overview

The project connects physical sensing with an automated MATLAB machine-learning workflow:

1. An **ESP32 development board** reads an LM35 analog temperature sensor and a DHT digital temperature/humidity sensor.
2. The microcontroller sends readings to **ThingSpeak** over Wi-Fi.
3. The channel data is exported as a CSV file.
4. MATLAB reads the CSV directly, validates its schema and timestamps, and creates experiment-specific cleaned datasets.
5. A chronological train/test split is used to evaluate regression models.
6. The pipeline saves metrics, plots, trained models, data-quality summaries, and a run report in a new timestamped directory.

The main regression task is to estimate the LM35 temperature from the DHT sensor measurements. The humidity-only model is the baseline; a separate experiment uses both DHT humidity and DHT temperature.

## System architecture

```text
LM35 analog temperature sensor ──> ESP32 ADC input (GPIO34)
                                          │
DHT digital temperature/humidity sensor ─> ESP32 digital input (GPIO4)
                                          │
                                          ▼
                                    ESP32 firmware
                                          │ Wi-Fi
                                          ▼
                                      ThingSpeak
                                          │ CSV export
                                          ▼
                               MATLAB data-validation pipeline
                                          │
                              Cleaning and chronological split
                                          │
                                          ▼
                           Regression training and evaluation
                                          │
                    Metrics, plots, saved model, and run report
```

### Technologies

| Layer | Technology | Purpose |
|---|---|---|
| Microcontroller | ESP32 NodeMCU-32S / ESP32 DevKit-family board | Reads sensors and uploads measurements |
| Temperature sensing | LM35 analog sensor | Primary target/reference signal for regression |
| Digital sensing | DHT module (exact variant not recorded in repository) | Measures DHT temperature and relative humidity |
| Wireless data transport | Wi-Fi | Sends sensor measurements to ThingSpeak |
| IoT data platform | ThingSpeak | Stores time-stamped sensor fields and provides CSV export |
| Analysis and automation | MATLAB | Loads, validates, cleans, splits, models, evaluates, and reports results |
| Regression models | Fine Tree, Linear Regression, LSBoost Ensemble, Support Vector Regression (SVR); a Gaussian Process result is also saved | Compares regression approaches |
| Version control | Git and GitHub | Stores source code, run artifacts, and documentation |

## Hardware implementation

The physical prototype uses an ESP32 board with two sensors. Project code and prior implementation notes identify these signal connections:

| Component | ESP32 connection | Signal type | Role |
|---|---|---|---|
| LM35 temperature sensor | GPIO34 | Analog input (ADC) | LM35 temperature reading |
| DHT sensor data pin | GPIO4 | Digital I/O | DHT temperature and humidity readings |
| Sensor grounds | ESP32 GND | Common ground | Shared electrical reference |
| Sensor power | Appropriate sensor supply pin | Power | Must match the exact sensor module requirements |

**Wiring and electrical safety notes**

- GPIO34 is an input-only ESP32 pin and is suitable for reading an analog input.
- Connect the LM35 output to GPIO34 only after verifying its supply voltage and output range. The ESP32 ADC/GPIO must not be exposed to a voltage above its permitted input range.
- GPIO4 is used for the DHT data signal in the project notes. A bare DHT sensor generally needs an appropriate data pull-up; some breakout modules already include one.
- The ESP32 uses 3.3 V logic. Do not feed a 5 V signal directly into an ESP32 GPIO.
- Confirm the pin labels and board variant before wiring; ESP32 DevKit versions and clones can differ.
- The exact DHT model, power arrangement, pull-up circuit, and any added components were not present in the reviewed repository files. Do not assume those details without checking the real build.

### Hardware visuals

**1. ESP32 DevKit-family board reference**

![ESP32 DevKit V1 development-board reference](https://static.ticimax.cloud/cdn-cgi/image/width%3D0%2Cquality%3D85/75519/uploads/urunresimleri/buyuk/esp32-wifi-bluetooth-gelistirme-karti---4396-.jpg)

This is a general board reference, not a verified photograph of the specific board used in this project. Board layout and USB connector can vary by version.

**2. Conceptual sensor-wiring illustration**

This is a conceptual wiring reference for an ESP32 with an LM35-style analog sensor and DHT22-style digital sensor. It is not a photograph or a confirmed exact replica of the assembled circuit. Use the GPIO34 and GPIO4 assignments documented above, and confirm the actual sensor pinout before replicating a circuit.

![Conceptual ESP32, LM35 and DHT22 sensor wiring reference](https://thumbs.wokwi.com/projects/399467738985928705/social/1717221539434.png)

The linked illustration may show an additional sensor or different labels; use it only as a visual reference. The project-specific connections are those recorded in the table above.

## ThingSpeak data schema

The ThingSpeak channel mapping has been verified:

| CSV column | Channel meaning | Units | ML usage |
|---|---|---|---|
| `created_at` | Record timestamp | Time | Chronological ordering and gap analysis |
| `field1` | LM35 Temperature | °C | Prediction target |
| `field2` | DHT Temperature | °C | Optional second predictor |
| `field3` | DHT Humidity | % relative humidity | Primary baseline predictor |

Other columns such as `entry_id`, location, elevation, or status may be present in a ThingSpeak export; the current pipeline expects `created_at`, `field1`, `field2`, and `field3`.

**Important:** The code uses the verified field mapping above. The data itself includes abrupt changes and long gaps, so field names alone are not evidence that every sensor value is physically correct.

## Dataset and preprocessing

The latest documented run used a ThingSpeak CSV containing **145 records**.

| Data-quality check | Finding |
|---|---:|
| Original records | 145 |
| Rows with missing humidity | 44 |
| Missing-humidity pattern | Consecutive initial block (rows 1–44 in the inspected export) |
| Valid humidity + LM35 rows | 101 |
| Valid rows for the two-predictor configuration | 101 |
| Duplicate timestamps | 0 |
| Timestamp gaps greater than 30 seconds | 15 |
| Largest gap between timestamps | 319,714 seconds (about 3.7 days) |

### Preprocessing steps

1. **Read the CSV directly** with MATLAB rather than relying on a manually imported workspace variable.
2. **Validate the required schema** and parse `created_at` as timestamps.
3. **Order records chronologically** to preserve the time order.
4. **Standardize column names** to `Timestamp`, `LM35Temperature`, `DHTTemperature`, and `DHTHumidity`.
5. **Create separate experiment datasets.** The humidity-only experiment requires valid LM35 temperature and humidity. The two-predictor experiment additionally requires DHT temperature.
6. **Exclude rows with missing or non-finite required values.** The pipeline does not impute missing readings, replace them with zeros, or fabricate sensor values.
7. **Inspect time gaps and duplicates.** Long gaps are retained in the time-series audit rather than being interpolated away.
8. **Save a separate output directory for each run** so prior results are retained.

The original input file is not modified.

## Machine-learning workflow

### Target and predictor configurations

**Experiment A — humidity-only baseline**

- Predictor (X): DHT Humidity (`field3`)
- Target (Y): LM35 Temperature (`field1`)
- Primary model: Fine Tree regression
- Comparator: training-mean baseline
- Split: chronological 80% training / 20% testing

**Experiment B — two-predictor model**

- Predictors: DHT Humidity (`field3`) and DHT Temperature (`field2`)
- Target: LM35 Temperature (`field1`)
- Model: Fine Tree regression

### Models compared

- **Fine Tree Regression:** a decision-tree regression model that can represent nonlinear relationships.
- **Linear Regression:** a simple linear benchmark.
- **LSBoost Ensemble:** a boosted ensemble of regression learners.
- **Support Vector Regression (SVR):** a kernel-based regression approach.
- **Gaussian Process Regression:** a saved additional experiment result.
- **Training-mean baseline:** predicts the mean LM35 temperature calculated from training rows only.

### Evaluation metrics

- **RMSE (°C):** square root of mean squared error; gives greater weight to larger errors.
- **MAE (°C):** mean absolute prediction error.
- **R²:** compares squared prediction error with variation around the test-set target mean. A negative R² means the predictions are worse, by this measure, than predicting the mean of the actual test targets.
- **Bias (°C):** average prediction minus actual target; positive values indicate average overprediction.
- **Max absolute error (°C):** the largest absolute error in the test segment.

## Results and model comparison

The following figures are the metrics saved by the documented run `20261027_202252`. They are reported to make the experiment reproducible, but they must be interpreted with the small test set and near-constant test-target segment in mind.

### Held-out chronological test results

| Model | Predictors | Test samples | RMSE (°C) | MAE (°C) | R² |
|---|---|---:|---:|---:|---:|
| Fine Tree | Humidity | 21 | 0.089866 | 0.052957 | -0.986971 |
| Linear Regression | Humidity | 21 | 0.426359 | 0.401020 | -43.725052 |
| LSBoost Ensemble | Humidity | 21 | 0.096923 | 0.068482 | -1.311296 |
| SVR | Humidity | 21 | 0.568795 | 0.556694 | -78.599532 |
| Gaussian Process Regression* | Humidity | 21 | 0.293191 | 0.277491 | -20.149507 |
| Fine Tree | Humidity + DHT Temperature | 21 | **0.064169** | **0.040678** | **-0.013083** |

*The Gaussian Process result was saved in a separate metrics file. Confirm that its test rows and split are identical before treating it as a strictly paired comparison with all other entries.

### Interpretation

- The **two-predictor Fine Tree** has the lowest reported RMSE and MAE among the listed candidate models.
- For the humidity-only configuration, the Fine Tree has the lowest reported RMSE and MAE among Linear Regression, Fine Tree, LSBoost, SVR, and the separately saved Gaussian Process result.
- **All displayed R² values are negative.** This is a warning not to call the models generally accurate based on RMSE/MAE alone.
- The 21 humidity-only test targets have a very small reported spread (approximately 16.673–16.975 °C in the saved cleaned test segment). When test targets are nearly constant, the denominator in R² is small; even modest errors can therefore produce a negative R².
- The training-mean baseline had RMSE **8.198129 °C**, MAE **8.197881 °C**, and R² **-16534.942131** in the saved baseline report. This is consistent with a training mean far from the nearly constant test target segment; it is not evidence that the Fine Tree generalizes across environmental conditions.
- The current evaluation is a small chronological holdout with long time gaps. More continuous measurements over a wider range of conditions are needed before making strong claims about model quality.
- The two-predictor model and humidity-only model should be compared on the **same test timestamps** for a fair estimate of the benefit of adding DHT temperature. Verify paired indices before interpreting the difference as a model improvement.

These are contemporaneous sensor regression experiments: the model estimates LM35 temperature using humidity and optionally DHT temperature from the same observation. This is not a future forecast unless those predictor readings are actually available at the forecast time.

## How to run the pipeline

The reusable pipeline entry point is `run_pipeline.m`.

```matlab
summary = run_pipeline( ...
    'C:\Users\alisa\Downloads\feeds.csv', ...
    'C:\Users\alisa\OneDrive\Documents\MATLAB\IoT_Temperature_Project_Pipeline', ...
    0.80, true);
```

Arguments:

1. **Input CSV path** — the ThingSpeak export to read.
2. **Output root** — parent directory for run-specific output.
3. **Training fraction** — `0.80` for an 80/20 chronological split.
4. **Advanced experiments flag** — `true` to run the implemented model comparisons.

For another dataset with the same schema, export a fresh CSV from ThingSpeak and pass its path to the function. Each run creates a timestamped folder with data, metrics, model files, figures, a report, and a run summary. The raw input remains unchanged.

> The sample paths above are specific to the original Windows workstation. Replace them with paths that exist on your machine.

## Prediction interface

The repository includes `predict_lm35_temperature.m` for inference with a saved humidity-only Fine Tree model.

Conceptually, the function needs a table containing `DHTHumidity` and a path to the saved model file:

```matlab
newReading = table(53.2, 'VariableNames', {'DHTHumidity'});

[estimatedLM35C, info] = predict_lm35_temperature( ...
    newReading, ...
    'path/to/humidity_fine_tree.mat');
```

Use a saved model from a specific pipeline run. The prediction function does not retrain the model. For the two-predictor model, use the corresponding model and interface that require both DHT humidity and DHT temperature.

## Project structure

```text
.
├── README.md
├── RoboticsAIOTTask.mlx
├── RoboticsAIOTTask_exported.m
├── run_pipeline.m
├── run_multitarget_pipeline.m
├── baseline_humidity_only.m
├── predict_lm35_temperature.m
├── predict_lm35_temperature_extended.m
├── test_pipeline_assertions.m
├── feeds.csv
├── clean_temperature_data.csv
├── IoT_Temperature_Project_Output/
└── IoT_Temperature_Project_Pipeline/
    ├── run_pipeline.m
    ├── predict_lm35_temperature.m
    └── timestamped run folders containing:
        ├── data/
        ├── figures/
        ├── metrics/
        ├── models/
        ├── reports/
        └── run_summary.json
```

The repository contains both root-level and pipeline-folder copies of some scripts. Check which entry point is being used before making changes.

## Limitations and next steps

1. **Increase data coverage:** collect more continuous readings and repeat the experiment under multiple ambient conditions.
2. **Investigate missing humidity:** the initial block of 44 missing humidity readings should be traced to startup, sensor initialization, or data publishing if possible.
3. **Check sensor calibration and placement:** the saved sensor-agreement result shows a large mean difference, which may reflect field interpretation, sensor configuration, scaling, wiring, or sensor calibration issues. Verify raw serial output against ThingSpeak before treating either temperature sensor as ground truth.
4. **Keep chronological evaluation:** future observations must remain held out from training and tuning. With more data, use rolling-origin evaluation over multiple time periods.
5. **Compare models fairly:** use identical test timestamps for direct model comparisons, including humidity-only versus the two-predictor model.
6. **Avoid overclaiming:** negative R² and a small test segment mean that better validation is needed before deployment.
7. **Document the exact hardware build:** add a photo of the real assembled circuit, confirm the exact DHT module type, and verify sensor power and signal wiring.

## Reproducibility and artifacts

The pipeline writes per-run artifacts such as:

- Standardized and cleaned CSV datasets
- Data-quality summary
- Baseline and model-comparison metrics
- Trained regression models
- Actual-versus-predicted and residual plots
- Sensor timeline, correlation, and diagnostic outputs
- Text/Markdown reports and a machine-readable run summary

See the [pipeline folder](IoT_Temperature_Project_Pipeline/) and the documented run folder [20261027_202252](IoT_Temperature_Project_Pipeline/20261027_202252/).

## License

See [LICENSE](LICENSE).

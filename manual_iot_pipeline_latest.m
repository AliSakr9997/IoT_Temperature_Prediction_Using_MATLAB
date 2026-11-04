%% Step 1 - Reset MATLAB
clearvars
close all
clc

version
pwd

%% Step 2 - Import ThingSpeak data
filePath = 'C:\Users\alisa\Downloads\feeds.csv';

data = readtable(filePath);

fprintf('Rows: %d\n', height(data));
fprintf('Columns: %d\n', width(data));

disp(data.Properties.VariableNames)
head(data)

%% Step 3 - Inspect variables
summary(data)

disp('Missing values per column:')
disp(sum(ismissing(data)))

disp('First rows:')
disp(data(1:min(10,height(data)),:))

%% Step 4 - Create standardized variables
Timestamp = datetime( ...
    string(data.created_at), ...
    'InputFormat','yyyy-MM-dd''T''HH:mm:ssXXX', ...
    'TimeZone','UTC');

LM35Temperature = data.field1;
DHTTemperature  = data.field2;
DHTHumidity     = data.field3;

fprintf('LM35 range: %.3f to %.3f °C\n', ...
    min(LM35Temperature,[],'omitnan'), ...
    max(LM35Temperature,[],'omitnan'));

fprintf('DHT temperature range: %.3f to %.3f °C\n', ...
    min(DHTTemperature,[],'omitnan'), ...
    max(DHTTemperature,[],'omitnan'));

fprintf('DHT humidity range: %.3f to %.3f %%RH\n', ...
    min(DHTHumidity,[],'omitnan'), ...
    max(DHTHumidity,[],'omitnan'));

%% Step 5 - Missing-value analysis
fprintf('Missing LM35 values: %d\n', sum(~isfinite(LM35Temperature)));
fprintf('Missing DHT temperature values: %d\n', sum(~isfinite(DHTTemperature)));
fprintf('Missing DHT humidity values: %d\n', sum(~isfinite(DHTHumidity)));

missingHumidityRows = find(~isfinite(DHTHumidity));

disp('Rows with missing humidity:')
disp(missingHumidityRows')

%% Step 6 - Timestamp quality
[Timestamp, sortIndex] = sort(Timestamp);

LM35Temperature = LM35Temperature(sortIndex);
DHTTemperature  = DHTTemperature(sortIndex);
DHTHumidity     = DHTHumidity(sortIndex);

timestampGaps = seconds(diff(Timestamp));

fprintf('Duplicate timestamps: %d\n', ...
    height(data) - numel(unique(Timestamp)));

fprintf('Gaps greater than 30 seconds: %d\n', ...
    sum(timestampGaps > 30));

fprintf('Largest gap: %.0f seconds\n', max(timestampGaps));

fprintf('First timestamp: %s\n', string(Timestamp(1)));
fprintf('Last timestamp: %s\n', string(Timestamp(end)));

%% Step 7 - Raw sensor signals
figure

tiledlayout(3,1)

nexttile
plot(Timestamp, LM35Temperature, 'r.-')
grid on
ylabel('Temperature (°C)')
title('LM35 Temperature')

nexttile
plot(Timestamp, DHTTemperature, 'b.-')
grid on
ylabel('Temperature (°C)')
title('DHT Temperature')

nexttile
plot(Timestamp, DHTHumidity, 'g.-')
grid on
ylabel('Humidity (%RH)')
xlabel('Time')
title('DHT Humidity')

%% Step 8 - Filter date and remove missing humidity
startDate = datetime('27-Oct-2026 15:29:30', ...
    'InputFormat', 'dd-MMM-uuuu HH:mm:ss');

% If your Timestamp has a time zone, match it automatically:
if ~isempty(Timestamp.TimeZone)
    startDate.TimeZone = Timestamp.TimeZone;
end

dateRows = Timestamp >= startDate;
humidityRows = isfinite(DHTHumidity);

fprintf('Rows before 27-Oct-2026 15:29:30: %d\n', sum(~dateRows));
fprintf('Missing humidity rows: %d\n', sum(~humidityRows));

% Keep only records from 27 October 15:29:30 onward
% and remove rows with missing humidity
keepRows = dateRows & humidityRows;

TimestampFiltered = Timestamp(keepRows);
LM35Filtered      = LM35Temperature(keepRows);
DHTTempFiltered   = DHTTemperature(keepRows);
HumidityFiltered  = DHTHumidity(keepRows);

fprintf('Rows after date and humidity filtering: %d\n', ...
    numel(TimestampFiltered));

%% Step 9 - Cleaned sensor signals
figure

tiledlayout(3,1)

nexttile
plot(TimestampFiltered, LM35Filtered, 'r.-')
grid on
ylabel('Temperature (°C)')
title('LM35 Temperature (Cleaned)')

nexttile
plot(TimestampFiltered, DHTTempFiltered, 'b.-')
grid on
ylabel('Temperature (°C)')
title('DHT Temperature (Cleaned)')

nexttile
plot(TimestampFiltered, HumidityFiltered, 'g.-')
grid on
ylabel('Humidity (%RH)')
xlabel('Time')
title('DHT Humidity (Cleaned)')

%% Step 10 - Create final cleaned dataset

completeRows = ...
    isfinite(LM35Filtered) & ...
    isfinite(DHTTempFiltered) & ...
    isfinite(HumidityFiltered);

cleanData = table( ...
    TimestampFiltered(completeRows), ...
    LM35Filtered(completeRows), ...
    DHTTempFiltered(completeRows), ...
    HumidityFiltered(completeRows), ...
    'VariableNames', { ...
    'Timestamp', ...
    'LM35Temperature', ...
    'DHTTemperature', ...
    'DHTHumidity'});

fprintf('Rows after final cleaning: %d\n', height(cleanData));
disp(cleanData(1:min(10,height(cleanData)),:))

%% Step 11 - Verify cleaned data

disp('Missing values in cleanData:')
disp(sum(ismissing(cleanData)))

fprintf('Duplicate timestamps: %d\n', ...
    height(cleanData) - numel(unique(cleanData.Timestamp)));

fprintf('Final time range:\n')
fprintf('%s to %s\n', ...
    string(cleanData.Timestamp(1)), ...
    string(cleanData.Timestamp(end)));

%% Step 12 - Save cleaned data

outputFolder = 'C:\Users\alisa\Documents\Codex\matlab_manual_results';

if ~exist(outputFolder,'dir')
    mkdir(outputFolder)
end

cleanedFile = fullfile(outputFolder,'cleaned_data.csv');

writetable(cleanData,cleanedFile);

fprintf('Cleaned data saved to:\n%s\n',cleanedFile);

%% Step 13 - Chronological train/test split

n = height(cleanData);
splitIndex = floor(0.80*n);

trainData = cleanData(1:splitIndex,:);
testData  = cleanData(splitIndex+1:end,:);

fprintf('Training rows: %d\n',height(trainData));
fprintf('Testing rows: %d\n',height(testData));

fprintf('Training period:\n%s to %s\n', ...
    string(trainData.Timestamp(1)), ...
    string(trainData.Timestamp(end)));

fprintf('Testing period:\n%s to %s\n', ...
    string(testData.Timestamp(1)), ...
    string(testData.Timestamp(end)));

%% Step 14 - Fine Tree humidity-only model

fineTreeModel = fitrtree( ...
    trainData.DHTHumidity, ...
    trainData.LM35Temperature, ...
    'MaxNumSplits',100, ...
    'MinLeafSize',1);

predFineTree = predict( ...
    fineTreeModel, ...
    testData.DHTHumidity);

view(fineTreeModel,'Mode','graph')

%% Step 15 - Training mean baseline

trainingMean = mean(trainData.LM35Temperature);

predMean = repmat( ...
    trainingMean, ...
    height(testData),1);

fprintf('Training mean: %.4f °C\n',trainingMean);

%% Step 16 - Calculate metrics

actual = testData.LM35Temperature;

errorFineTree = predFineTree - actual;
errorMean = predMean - actual;

rmse = @(e) sqrt(mean(e.^2));
mae  = @(e) mean(abs(e));
bias = @(e) mean(e);

r2 = @(e,y) 1 - ...
    sum(e.^2) / sum((y - mean(y)).^2);

fineTreeRMSE = rmse(errorFineTree);
fineTreeMAE  = mae(errorFineTree);
fineTreeR2   = r2(errorFineTree,actual);
fineTreeBias = bias(errorFineTree);

meanRMSE = rmse(errorMean);
meanMAE  = mae(errorMean);
meanR2   = r2(errorMean,actual);
meanBias = bias(errorMean);

metrics = table( ...
    {'Fine Tree';'Training Mean'}, ...
    [fineTreeRMSE;meanRMSE], ...
    [fineTreeMAE;meanMAE], ...
    [fineTreeR2;meanR2], ...
    [fineTreeBias;meanBias], ...
    'VariableNames', ...
    {'Model','RMSE','MAE','R2','Bias'});

disp(metrics)

%% Step 17 - Actual versus predicted

figure

plot(testData.Timestamp,actual, ...
    'k.-','LineWidth',1.5)

hold on

plot(testData.Timestamp,predFineTree, ...
    'b.-','LineWidth',1.5)

grid on
legend('Actual LM35','Fine Tree prediction', ...
    'Location','best')

xlabel('Time')
ylabel('Temperature (°C)')
title('Actual versus Predicted LM35 Temperature')

%% Step 18 - Residuals over time

figure

plot(testData.Timestamp,errorFineTree, ...
    'r.-','LineWidth',1.5)

hold on
yline(0,'k--')

grid on
xlabel('Time')
ylabel('Residual (°C)')
title('Fine Tree Residuals Over Time')

%% Step 19 - Actual versus predicted scatter

figure

scatter(actual,predFineTree,60,'filled')

hold on

minimumValue = min([actual;predFineTree]);
maximumValue = max([actual;predFineTree]);

plot([minimumValue maximumValue], ...
    [minimumValue maximumValue], ...
    'k--','LineWidth',1.5)

grid on
xlabel('Actual LM35 Temperature (°C)')
ylabel('Predicted LM35 Temperature (°C)')
title('Actual versus Predicted Scatter')

legend('Predictions','Perfect prediction', ...
    'Location','best')

%% Step 20 - Linear Regression

linearModel = fitlm( ...
    trainData.DHTHumidity, ...
    trainData.LM35Temperature);

predLinear = predict( ...
    linearModel, ...
    testData.DHTHumidity);

errorLinear = predLinear - actual;

linearRMSE = rmse(errorLinear);
linearMAE  = mae(errorLinear);
linearR2   = r2(errorLinear,actual);
linearBias = bias(errorLinear);

disp(linearModel)

%% Step 21 - LSBoost Ensemble

boostModel = fitrensemble( ...
    trainData.DHTHumidity, ...
    trainData.LM35Temperature, ...
    'Method','LSBoost', ...
    'NumLearningCycles',100);

predBoost = predict( ...
    boostModel, ...
    testData.DHTHumidity);

errorBoost = predBoost - actual;

boostRMSE = rmse(errorBoost);
boostMAE  = mae(errorBoost);
boostR2   = r2(errorBoost,actual);
boostBias = bias(errorBoost);

%% Step 22 - Gaussian SVR

svmModel = fitrsvm( ...
    trainData.DHTHumidity, ...
    trainData.LM35Temperature, ...
    'KernelFunction','gaussian', ...
    'Standardize',true);

predSVM = predict( ...
    svmModel, ...
    testData.DHTHumidity);

errorSVM = predSVM - actual;

svmRMSE = rmse(errorSVM);
svmMAE  = mae(errorSVM);
svmR2   = r2(errorSVM,actual);
svmBias = bias(errorSVM);

%% Step 23 - Compare models

comparison = table( ...
    {'Fine Tree'; ...
    'Linear Regression'; ...
    'LSBoost Ensemble'; ...
    'Gaussian SVR'; ...
    'Training Mean'}, ...
    [fineTreeRMSE;linearRMSE;boostRMSE;svmRMSE;meanRMSE], ...
    [fineTreeMAE;linearMAE;boostMAE;svmMAE;meanMAE], ...
    [fineTreeR2;linearR2;boostR2;svmR2;meanR2], ...
    [fineTreeBias;linearBias;boostBias;svmBias;meanBias], ...
    'VariableNames', ...
    {'Model','RMSE','MAE','R2','Bias'});

disp(comparison)

%% Step 24 - RMSE comparison

figure

bar(categorical(comparison.Model),comparison.RMSE)

grid on
ylabel('RMSE (°C)')
title('Model Comparison - RMSE')
xtickangle(30)

%% Step 25 - MAE and R² comparison

figure

tiledlayout(2,1)

nexttile
bar(categorical(comparison.Model),comparison.MAE)
grid on
ylabel('MAE (°C)')
title('Model Comparison - MAE')
xtickangle(30)

nexttile
bar(categorical(comparison.Model),comparison.R2)
grid on
ylabel('R²')
title('Model Comparison - R²')
xtickangle(30)

%% Step 26 - Fine Tree with humidity and DHT temperature

XTrain2 = trainData{:, ...
    {'DHTHumidity','DHTTemperature'}};

XTest2 = testData{:, ...
    {'DHTHumidity','DHTTemperature'}};

fineTreeTwoPredictor = fitrtree( ...
    XTrain2, ...
    trainData.LM35Temperature, ...
    'MaxNumSplits',100, ...
    'MinLeafSize',1);

predTwoPredictor = predict( ...
    fineTreeTwoPredictor, ...
    XTest2);

errorTwoPredictor = predTwoPredictor - actual;

twoRMSE = rmse(errorTwoPredictor);
twoMAE  = mae(errorTwoPredictor);
twoR2   = r2(errorTwoPredictor,actual);
twoBias = bias(errorTwoPredictor);

fprintf('Two-predictor Fine Tree:\n')
fprintf('RMSE: %.6f °C\n',twoRMSE)
fprintf('MAE: %.6f °C\n',twoMAE)
fprintf('R²: %.6f\n',twoR2)
fprintf('Bias: %.6f °C\n',twoBias)

%% Step 27 - Two-predictor predictions

figure

plot(testData.Timestamp,actual, ...
    'k.-','LineWidth',1.5)

hold on

plot(testData.Timestamp,predTwoPredictor, ...
    'm.-','LineWidth',1.5)

grid on
legend('Actual LM35', ...
    'Humidity + DHT temperature', ...
    'Location','best')

xlabel('Time')
ylabel('Temperature (°C)')
title('Two-Predictor Fine Tree')

%% Step 28 - Sensor correlation

sensorValues = cleanData{:, ...
    {'LM35Temperature', ...
    'DHTTemperature', ...
    'DHTHumidity'}};

correlationMatrix = corr( ...
    sensorValues, ...
    'Rows','pairwise');

disp(correlationMatrix)

figure

imagesc(correlationMatrix)
colorbar

xticks(1:3)
yticks(1:3)

xticklabels({'LM35','DHT Temperature','Humidity'})
yticklabels({'LM35','DHT Temperature','Humidity'})

title('Sensor Correlation Matrix')

%% Step 29 - Save data, metrics, and models

writetable(cleanData, ...
    fullfile(outputFolder,'cleaned_data_manual.csv'));

writetable(comparison, ...
    fullfile(outputFolder,'model_comparison_manual.csv'));

save(fullfile(outputFolder,'trained_models_manual.mat'), ...
    'fineTreeModel', ...
    'linearModel', ...
    'boostModel', ...
    'svmModel', ...
    'fineTreeTwoPredictor', ...
    'metrics', ...
    'comparison');

fprintf('All results saved to:\n%s\n',outputFolder);

%% Step 30 - Final summary

fprintf('\n===== FINAL SUMMARY =====\n')
fprintf('Original rows: %d\n',height(data))
fprintf('Rows after date filtering: %d\n',sum(dateRows))
fprintf('Rows after humidity filtering: %d\n',sum(keepRows))
fprintf('Final cleaned rows: %d\n',height(cleanData))
fprintf('Training rows: %d\n',height(trainData))
fprintf('Testing rows: %d\n',height(testData))

disp(comparison)

fprintf('Results folder:\n%s\n',outputFolder)

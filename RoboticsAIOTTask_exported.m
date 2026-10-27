data = readtable("C:\Users\alisa\Downloads\feeds.csv");

% Inspect the column names and first rows
disp(data.Properties.VariableNames)
head(data)
summary(data)
%%

% Inspect the imported ThingSpeak dataset
disp("Column names:");
disp(data.Properties.VariableNames');

disp("First 10 rows:");
head(data, 10)

disp("Dataset size:");
disp(size(data));

disp("Missing values per column:");
disp(sum(ismissing(data)));
%%

% Select the required input and target
Humidity = data.field3;
LM35Temperature = data.field1;

% Keep only rows with valid numeric readings
validRows = isfinite(Humidity) & isfinite(LM35Temperature) ...
    & Humidity >= 0 & Humidity <= 100 ...
    & LM35Temperature >= 0 & LM35Temperature <= 150;

cleanData = table( ...
    Humidity(validRows), ...
    LM35Temperature(validRows), ...
    'VariableNames', {'Humidity', 'LM35Temperature'});

% Display the cleaned dataset
disp("Cleaned dataset size:");
disp(size(cleanData));

head(cleanData, 10)
%%

n = height(cleanData);

if n < 30
    error("Collect more valid readings before training.");
end

splitIndex = floor(0.8 * n);

trainData = cleanData(1:splitIndex, :);
testData  = cleanData(splitIndex+1:end, :);

fprintf("Training rows: %d\n", height(trainData));
fprintf("Testing rows: %d\n", height(testData));
%%
rehash toolboxcache
which shareMATLABSession -all
%%
shareMATLABSession()
%%

% Inspect the most recent 15 ThingSpeak records
disp(tail(data, 15));

% Count valid values in each sensor field
fprintf("Valid field1 values: %d\n", sum(~isnan(data.field1)));
fprintf("Valid field2 values: %d\n", sum(~isnan(data.field2)));
fprintf("Valid field3 values: %d\n", sum(~isnan(data.field3)));
%%
savepath
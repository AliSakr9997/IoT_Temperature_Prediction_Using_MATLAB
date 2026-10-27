function [temperatureC, info] = predict_lm35_temperature(sensorData, modelFile)
% Predict LM35 temperature from DHT humidity using a saved pipeline model.
if nargin<2, error('Provide sensorData and a saved humidity_fine_tree.mat path.'); end
S=load(modelFile,'mdl');
if ~istable(sensorData) || ~ismember('DHTHumidity',sensorData.Properties.VariableNames), error('sensorData must contain DHTHumidity.'); end
if any(~isfinite(sensorData.DHTHumidity)), error('DHTHumidity contains missing or non-finite values.'); end
temperatureC=predict(S.mdl,sensorData.DHTHumidity);
info=struct('Model','Fine Tree','Predictor','DHTHumidity','Units','degC');
end

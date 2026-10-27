function [temperatureC, info] = predict_lm35_temperature_extended(sensorData, modelFile)
% Predict LM35 using humidity and DHT temperature from a saved model.
S=load(modelFile,'m2');
if ~istable(sensorData) || ~all(ismember({'DHTHumidity','DHTTemperature'},sensorData.Properties.VariableNames)), error('sensorData must contain DHTHumidity and DHTTemperature.'); end
X=sensorData{:,{'DHTHumidity','DHTTemperature'}};
if any(~isfinite(X),'all'), error('Predictors contain missing or non-finite values.'); end
temperatureC=predict(S.m2,X); info=struct('Model','Fine Tree','Predictors',{{'DHTHumidity','DHTTemperature'}},'Units','degC');
end

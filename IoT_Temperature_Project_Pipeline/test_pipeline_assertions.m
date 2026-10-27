function tests = test_pipeline_assertions
tests = functiontests(localfunctions);
end
function testSchema(testCase)
T=readtable('C:\Users\alisa\Downloads\feeds.csv'); verifyTrue(testCase,all(ismember({'created_at','field1','field2','field3'},T.Properties.VariableNames))); end
function testMissingHumidity(testCase)
T=readtable('C:\Users\alisa\Downloads\feeds.csv'); verifyEqual(testCase,sum(isnan(T.field3)),44); end
function testChronologicalSplit(testCase)
H=readtable('C:\Users\alisa\OneDrive\Documents\MATLAB\IoT_Temperature_Project_Pipeline\20261027_202252\data\cleaned_humidity_only.csv'); verifyEqual(testCase,floor(.8*height(H)),80); verifyTrue(testCase,all(diff(H.Timestamp)>=seconds(0))); end
function testMetrics(testCase)
M=readtable('C:\Users\alisa\OneDrive\Documents\MATLAB\IoT_Temperature_Project_Pipeline\20261027_202252\metrics\baseline_audit_metrics.csv'); verifyLessThan(testCase,abs(M.RMSE(1)-0.089866),1e-4); verifyLessThan(testCase,abs(M.MAE(1)-0.052957),1e-4); end
function testPredictionInterface(testCase)
S=table(40,'VariableNames',{'DHTHumidity'}); [y,~]=predict_lm35_temperature(S,'C:\Users\alisa\OneDrive\Documents\MATLAB\IoT_Temperature_Project_Pipeline\20261027_202252\models\humidity_fine_tree.mat'); verifyTrue(testCase,isfinite(y)); end

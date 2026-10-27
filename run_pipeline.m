function summary = run_pipeline(inputFile, outputRoot, trainFraction, runAdvanced)
% Reusable ThingSpeak IoT temperature regression pipeline.
if nargin<1 || isempty(inputFile), inputFile='C:\Users\alisa\Downloads\feeds.csv'; end
if nargin<2 || isempty(outputRoot), outputRoot='C:\Users\alisa\OneDrive\Documents\MATLAB\IoT_Temperature_Project_Pipeline'; end
if nargin<3 || isempty(trainFraction), trainFraction=0.80; end
if nargin<4, runAdvanced=true; end
rng(42,'twister');
runId=char(datetime('now','Format','yyyyMMdd_HHmmss')); out=fullfile(outputRoot,runId); mkdir(out); mkdir(fullfile(out,'figures')); mkdir(fullfile(out,'models')); mkdir(fullfile(out,'metrics')); mkdir(fullfile(out,'data')); mkdir(fullfile(out,'reports'));
T=readtable(inputFile); required={'created_at','field1','field2','field3'}; if ~all(ismember(required,T.Properties.VariableNames)), error('Schema error: required columns are created_at, field1, field2, field3.'); end
ts=datetime(string(T.created_at),'InputFormat','yyyy-MM-dd''T''HH:mm:ssXXX','TimeZone','UTC');
if any(isnat(ts)), error('Timestamp parsing failed for one or more rows.'); end
[ts,ord]=sort(ts); T=T(ord,:); n0=height(T); dup=n0-numel(unique(ts));
stdT=table(ts,T.field1(ord),T.field2(ord),T.field3(ord),'VariableNames',{'Timestamp','LM35Temperature','DHTTemperature','DHTHumidity'});
writetable(stdT,fullfile(out,'data','standardized_data.csv'));
validH=isfinite(stdT.LM35Temperature)&isfinite(stdT.DHTHumidity); valid2=validH&isfinite(stdT.DHTTemperature);
H=stdT(validH,:); H2=stdT(valid2,:); writetable(H,fullfile(out,'data','cleaned_humidity_only.csv')); writetable(H2,fullfile(out,'data','cleaned_two_predictor.csv'));
split=floor(trainFraction*height(H)); X=H.DHTHumidity; y=H.LM35Temperature; mdl=fitrtree(X(1:split),y(1:split),'MaxNumSplits',100,'MinLeafSize',1); pred=predict(mdl,X(split+1:end)); actual=y(split+1:end); meanPred=repmat(mean(y(1:split)),size(actual));
M=metricRows({'Fine Tree';'Training mean baseline'},{'Humidity';'Humidity'},actual,[pred,meanPred],split); writetable(M,fullfile(out,'metrics','humidity_baseline_metrics.csv')); save(fullfile(out,'models','humidity_fine_tree.mat'),'mdl','split','trainFraction','M');
fig=figure('Visible','off'); plot(H.Timestamp(split+1:end),actual,'k.-',H.Timestamp(split+1:end),pred,'b.-'); grid on; legend('Actual LM35','Fine Tree'); xlabel('Time'); ylabel('Temperature (°C)'); saveas(fig,fullfile(out,'figures','baseline_predictions.png')); close(fig);
fig=figure('Visible','off'); plot(H.Timestamp(split+1:end),actual-pred,'r.-'); yline(0,'k--'); grid on; xlabel('Time'); ylabel('Residual (°C)'); saveas(fig,fullfile(out,'figures','baseline_residuals.png')); close(fig);
if runAdvanced
  models={}; names={}; Xh=X(1:split); yh=y(1:split); Xt=X(split+1:end);
  models{end+1}=fitlm(Xh,yh); names{end+1}='Linear regression';
  models{end+1}=mdl; names{end+1}='Fine Tree';
  try, models{end+1}=fitrensemble(Xh,yh,'Method','LSBoost','NumLearningCycles',50); names{end+1}='LSBoost ensemble'; catch, end
  try, models{end+1}=fitrsvm(Xh,yh,'KernelFunction','gaussian','Standardize',true); names{end+1}='SVR'; catch, end
  A=[]; for k=1:numel(models), pp=predict(models{k},Xt); A=[A; metricRow(names{k},'Humidity',actual,pp,split)]; end
  X2=H2{:,{'DHTHumidity','DHTTemperature'}}; s2=floor(trainFraction*height(H2)); m2=fitrtree(X2(1:s2,:),H2.LM35Temperature(1:s2),'MaxNumSplits',100,'MinLeafSize',1); p2=predict(m2,X2(s2+1:end,:)); A=[A; metricRow('Fine Tree','Humidity + DHT temperature',H2.LM35Temperature(s2+1:end),p2,s2)]; writetable(A,fullfile(out,'metrics','model_comparison_metrics.csv')); save(fullfile(out,'models','models.mat'),'models','names','m2');
end
gaps=seconds(diff(ts)); audit=table(n0,height(H),height(H2),sum(~isfinite(stdT.DHTHumidity)),dup,sum(gaps>30),max(gaps),'VariableNames',{'OriginalRows','HumidityValidRows','TwoPredictorRows','MissingHumidity','DuplicateTimestamps','GapsOver30s','LargestGapSeconds'}); writetable(audit,fullfile(out,'metrics','data_quality_summary.csv'));
fid=fopen(fullfile(out,'reports','run_report.txt'),'w'); fprintf(fid,'IoT Temperature Prediction Pipeline\nRun: %s\nInput: %s\nMapping: field1=LM35, field2=DHT temperature, field3=DHT humidity\nRows: original %d, humidity-valid %d, two-predictor-valid %d\nTrain/test humidity: %d/%d\nMissing humidity: %d; duplicate timestamps: %d; gaps >30s: %d; largest gap seconds: %.0f\n\n',runId,inputFile,n0,height(H),height(H2),split,height(H)-split,audit.MissingHumidity,audit.DuplicateTimestamps,audit.GapsOver30s,audit.LargestGapSeconds); for i=1:height(M), fprintf(fid,'%s: RMSE %.6f, MAE %.6f, R2 %.6f, bias %.6f\n',M.Model{i},M.RMSE(i),M.MAE(i),M.R2(i),M.Bias(i)); end; fclose(fid);
summary=struct('runId',runId,'outputDirectory',out,'originalRows',n0,'humidityRows',height(H),'twoPredictorRows',height(H2),'metrics',M); save(fullfile(out,'run_summary.mat'),'summary');
end
function M=metricRows(names,preds,actual,P,split), M=[]; for i=1:numel(names), M=[M;metricRow(names{i},preds{i},actual,P(:,i),split)]; end; end
function r=metricRow(model,predictors,actual,pred,trainN), e=pred-actual; den=sum((actual-mean(actual)).^2); r=table({model},{predictors},numel(actual),sqrt(mean(e.^2)),mean(abs(e)),1-sum(e.^2)/den,mean(e),max(abs(e)),'VariableNames',{'Model','Predictors','TestN','RMSE','MAE','R2','Bias','MaxAbsError'}); end

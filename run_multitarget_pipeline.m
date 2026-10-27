function summary=run_multitarget_pipeline(inputFile,outputRoot,trainFraction)
% Multi-target benchmark: one complete cleaned dataset, every sensor can be a target.
if nargin<1||isempty(inputFile), inputFile='C:\Users\alisa\Downloads\feeds.csv'; end
if nargin<2||isempty(outputRoot), outputRoot='C:\Users\alisa\OneDrive\Documents\MATLAB\IoT_Temperature_Project_Pipeline'; end
if nargin<3||isempty(trainFraction), trainFraction=.8; end
rng(42); runId=char(datetime('now','Format','yyyyMMdd_HHmmss')); out=fullfile(outputRoot,['multitarget_' runId]); mkdir(out); mkdir(fullfile(out,'data')); mkdir(fullfile(out,'metrics')); mkdir(fullfile(out,'figures')); mkdir(fullfile(out,'models')); mkdir(fullfile(out,'reports'));
T=readtable(inputFile); req={'created_at','field1','field2','field3'}; if ~all(ismember(req,T.Properties.VariableNames)), error('Required columns: created_at, field1, field2, field3'); end
ts=datetime(string(T.created_at),'InputFormat','yyyy-MM-dd''T''HH:mm:ssXXX','TimeZone','UTC'); [ts,ix]=sort(ts); T=T(ix,:); D=table(ts,T.field1,T.field2,T.field3,'VariableNames',{'Timestamp','LM35Temperature','DHTTemperature','DHTHumidity'}); writetable(D,fullfile(out,'data','standardized_data.csv'));
valid=isfinite(D.LM35Temperature)&isfinite(D.DHTTemperature)&isfinite(D.DHTHumidity); C=D(valid,:); writetable(C,fullfile(out,'data','cleaned_data.csv')); fprintf('Original rows: %d, complete cleaned rows: %d\n',height(D),height(C));
names={'LM35Temperature','DHTTemperature','DHTHumidity'}; rows=[]; allModels=struct();
for ti=1:3
 target=names{ti}; predictors=names(setdiff(1:3,ti)); s=floor(trainFraction*height(C)); X=C{:,predictors}; y=C.(target); Xtr=X(1:s,:); ytr=y(1:s); Xte=X(s+1:end,:); yte=y(s+1:end); models={}; labels={};
  models{end+1}=fitlm(Xtr,ytr); labels{end+1}='Linear';
  models{end+1}=fitlm(Xtr,ytr,'RobustOpts','on'); labels{end+1}='Robust Linear';
  for leaf=[1 5 10], models{end+1}=fitrtree(Xtr,ytr,'MinLeafSize',leaf,'MaxNumSplits',100); labels{end+1}=sprintf('Tree leaf %d',leaf); end
  try, models{end+1}=fitrensemble(Xtr,ytr,'Method','LSBoost','NumLearningCycles',100); labels{end+1}='LSBoost'; catch, end
  try, models{end+1}=fitrensemble(Xtr,ytr,'Method','Bag','NumLearningCycles',100); labels{end+1}='Bagged Trees'; catch, end
  for ker={'linear','gaussian','polynomial'}, try, models{end+1}=fitrsvm(Xtr,ytr,'KernelFunction',ker{1},'Standardize',true); labels{end+1}=['SVM ' ker{1}]; catch, end; end
  if exist('fitrgp','file')==2, try, models{end+1}=fitrgp(Xtr,ytr,'Standardize',true); labels{end+1}='Gaussian Process'; catch, end; end
  if exist('fitrnet','file')==2, try, models{end+1}=fitrnet(Xtr,ytr,'Standardize',true); labels{end+1}='Neural Network'; catch, end; end
  for mi=1:numel(models), p=predict(models{mi},Xte); e=p-yte; r=metricRow(target,labels{mi},strjoin(predictors,' + '),s,numel(yte),yte,p); rows=[rows;r]; end
  allModels.(target)=models; allModels.([target '_names'])=labels;
end
writetable(rows,fullfile(out,'metrics','all_target_model_metrics.csv')); save(fullfile(out,'models','all_target_models.mat'),'allModels','names','trainFraction');
fig=figure('Visible','off'); categoricalNames=categorical(strcat(rows.Target,': ',rows.Model)); bar(categoricalNames,rows.RMSE); ylabel('Chronological test RMSE (°C or native units)'); xtickangle(45); grid on; saveas(fig,fullfile(out,'figures','all_models_rmse.png')); close(fig);
fig=figure('Visible','off'); categoricalNames=categorical(strcat(rows.Target,': ',rows.Model)); bar(categoricalNames,rows.R2); ylabel('Chronological test R²'); xtickangle(45); grid on; saveas(fig,fullfile(out,'figures','all_models_r2.png')); close(fig);
summary=struct('outputDirectory',out,'originalRows',height(D),'cleanedRows',height(C),'targets',{names},'modelCount',height(rows)); fid=fopen(fullfile(out,'run_summary.json'),'w'); fwrite(fid,jsonencode(summary),'char'); fclose(fid); fid=fopen(fullfile(out,'reports','README_multitarget.txt'),'w'); fprintf(fid,'One cleaned dataset is used: rows require finite LM35Temperature, DHTTemperature, and DHTHumidity. Each target is predicted from the other two sensors. Results are chronological %.0f/%.0f train/test and include all supported model families.\n',100*trainFraction,100*(1-trainFraction)); fclose(fid); disp(rows); end
function r=metricRow(target,model,predictors,trainN,testN,y,p), e=p-y; r=table({target},{model},{predictors},trainN,testN,sqrt(mean(e.^2)),mean(abs(e)),1-sum(e.^2)/sum((y-mean(y)).^2),mean(e),'VariableNames',{'Target','Model','Predictors','TrainN','TestN','RMSE','MAE','R2','Bias'}); end

% Reproducible humidity-only LM35 temperature baseline.
% Original input is read-only; outputs are written to a dedicated folder.
sourceFile = 'C:\Users\alisa\Downloads\feeds.csv';
out = 'C:\Users\alisa\OneDrive\Documents\MATLAB\IoT_Temperature_Project_Output';
if ~exist(out,'dir'), mkdir(out); end
T = readtable(sourceFile);
ts = datetime(string(T.created_at),'InputFormat','yyyy-MM-dd''T''HH:mm:ssXXX','TimeZone','UTC');
valid = isfinite(T.field1) & isfinite(T.field3) & T.field1>=0 & T.field1<=150 & T.field3>=0 & T.field3<=100;
clean = T(valid,{'created_at','entry_id','field1','field2','field3'});
clean.Timestamp = ts(valid); clean = movevars(clean,'Timestamp','Before',1);
writetable(clean,fullfile(out,'cleaned_humidity_baseline.csv'));
X=clean.field3; Y=clean.field1; n=height(clean); split=floor(0.8*n);
mdl=fitrtree(X(1:split),Y(1:split),'MaxNumSplits',100,'MinLeafSize',1);
pred=predict(mdl,X(split+1:end)); actual=Y(split+1:end); mu=mean(Y(1:split)); base=repmat(mu,size(actual));
rmse=@(a,b)sqrt(mean((a-b).^2)); mae=@(a,b)mean(abs(a-b)); r2=@(a,b)1-sum((a-b).^2)/sum((b-mean(b)).^2);
metrics=table({'Fine Tree';'Training mean baseline'},{'Humidity only';'Humidity only'},[rmse(pred,actual);rmse(base,actual)],[mae(pred,actual);mae(base,actual)],[r2(pred,actual);r2(base,actual)],'VariableNames',{'Model','Predictors','RMSE','MAE','R2'});
writetable(metrics,fullfile(out,'baseline_metrics.csv')); save(fullfile(out,'baseline_model.mat'),'mdl','split','mu','metrics');
figure('Visible','off'); plot(clean.Timestamp(split+1:end),actual,'k.-',clean.Timestamp(split+1:end),pred,'b.-'); grid on; legend('Actual LM35','Fine Tree'); xlabel('Time'); ylabel('Temperature'); title('Humidity-only Fine Tree: Test Predictions'); saveas(gcf,fullfile(out,'actual_vs_predicted.png')); close;
figure('Visible','off'); plot(clean.Timestamp(split+1:end),actual-pred,'r.-'); yline(0,'k--'); grid on; xlabel('Time'); ylabel('Residual'); title('Humidity-only Fine Tree Residuals'); saveas(gcf,fullfile(out,'residuals_over_time.png')); close;
disp(metrics)

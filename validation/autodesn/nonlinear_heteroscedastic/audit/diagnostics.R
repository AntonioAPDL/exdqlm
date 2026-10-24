# Diagnostic regressions do not replace the original Bayesian architecture average.
source('validation/autodesn/nonlinear_heteroscedastic/helpers.R')
root<-file.path(nh_root,'audit');out<-file.path(root,'artifacts');dir.create(out,showWarnings=FALSE)
cfg<-jsonlite::fromJSON(file.path(root,'protocol.json'));penalties<-cfg$ridge_penalties
bank<-readRDS(file.path(nh_root,'artifacts/standardized_bank/bank.rds'))
truth<-read.csv(file.path(nh_root,'input/dgp_truth.csv'));y<-truth$y;mu<-truth$conditional_mean
train<-501:2500;test<-2501:3000;pre<-1:1500;valid<-1501:2000
cps<-lapply(c('requested','scaling_only','ridge_standardized'),function(s) readRDS(file.path(nh_root,'evidence',paste0(s,'_forecast_checkpoint.rds'))))
names(cps)<-c('requested','scaling_only','ridge_standardized')
stopifnot(identical(bank$keep_idx,train),max(abs(bank$history-y[1:2500]))<1e-12)
# A ridge family in standardized coordinates, fit and selected before test data.
path_fit<-function(F,target,lambda) {
 center<-colMeans(F);sd<-apply(F,2,stats::sd);keep<-which(sd>1e-10);G<-sweep(sweep(F[,keep,drop=FALSE],2,center[keep],'-'),2,sd[keep],'/')
 E<-eigen(crossprod(G)/nrow(G),symmetric=TRUE);values<-pmax(E$values,0);u<-crossprod(E$vectors,crossprod(G,target-mean(target))/nrow(G));B<-sapply(lambda,function(l) {v<-values+l;if(l==0)v[values<max(values)*1e-12]<-Inf;as.vector(E$vectors%*%(u/v))})
 list(center=center,sd=sd,keep=keep,B=matrix(B,length(keep)),mean=mean(target),lambda=lambda,eigen=values)
}
predict_path<-function(f,F) sweep(sweep(sweep(F[,f$keep,drop=FALSE],2,f$center[f$keep],'-'),2,f$sd[f$keep],'/')%*%f$B,2,rep(f$mean,ncol(f$B)),'+')
choose_fit<-function(F,te,target,truth_test) {
 f<-path_fit(F[pre,,drop=FALSE],target[pre],penalties);v<-predict_path(f,F[valid,,drop=FALSE]);errors<-colMeans((v-target[valid])^2);best<-which.min(errors)
 final<-path_fit(F,target,penalties[best]);a<-as.vector(predict_path(final,F));b<-as.vector(predict_path(final,te))
 list(lambda=penalties[best],validation_RMSE=sqrt(errors[best]),train_RMSE=sqrt(mean((a-target)^2)),test_RMSE=sqrt(mean((b-truth_test)^2)),test_mean=b,train_mean=a,coefficient_norm=sqrt(sum(final$B^2)),rank=sum(final$eigen>max(final$eigen)*1e-12),effective_rank=sum(final$eigen)^2/sum(final$eigen^2),condition=sqrt(max(final$eigen)/max(min(final$eigen),1e-20)))
}
postpred<-lapply(cps,function(cp) list(train192=rep(0,2000),test192=rep(0,500),train384=rep(0,2000),test384=rep(0,500)))
features_test<-vector('list',length(bank$models));cap<-list();model_preds<-list();parity<-numeric();began<-proc.time()[3]
z<-(y-bank$preprocessing$center)/bank$preprocessing$scale
for(j in seq_along(bank$models)) {
 m<-bank$models[[j]];template<-bank$templates[[j]];template$fit<-list(target_label='capacity_diagnostic');class(template)<-c('qdesn_normal_fit','list')
 if(is.null(template$states$H_last))template$states$H_last<-lapply(template$states$H_all,function(h) as.numeric(h[nrow(h),]))
 fc<-forecast_paths.qdesn_normal_fit(template,H=500L,y_hist=bank$history_scaled,origin_state=template$states$H_last,
  draws=list(beta=matrix(0,1L,m$raw_d+1L),omega2=1),innovations=matrix(0,500L,1L),y_future_obs=z[test],return_design=TRUE,backend='batched')
 raw<-matrix(fc$design[,1,-1],500L,m$raw_d);Ftest<-.autodesn_feature_apply(m,raw);features_test[[j]]<-Ftest
 F<-m$X[,-1L,drop=FALSE]
 a<-choose_fit(F,Ftest,mu[train],mu[test]);b<-choose_fit(F,Ftest,y[train],y[test])
 cap[[j]]<-cbind(bank$model_info[j,,drop=FALSE],data.frame(model=j,slopes=m$d,
  oracle_lambda=a$lambda,oracle_validation_RMSE=a$validation_RMSE,oracle_train_RMSE=a$train_RMSE,oracle_test_RMSE=a$test_RMSE,oracle_coefficient_norm=a$coefficient_norm,
  noisy_lambda=b$lambda,noisy_validation_RMSE=b$validation_RMSE,noisy_train_RMSE=b$train_RMSE,noisy_test_RMSE=b$test_RMSE,noisy_test_mu_RMSE=sqrt(mean((b$test_mean-mu[test])^2)),
  rank=a$rank,effective_rank=a$effective_rank,condition=a$condition))
 model_preds[[j]]<-list(oracle=a$test_mean,noisy=b$test_mean)
 for(sc in names(cps)) {
  cp<-cps[[sc]]
  for(N in c(192L,384L)) {
   ids<-which(cp$draws$model[1:N]==j);if(!length(ids))next
   beta<-do.call(rbind,cp$readout_beta[ids]);stopifnot(ncol(beta)==m$d+1L)
   coefficient<-colSums(beta)/N
   postpred[[sc]][[paste0('train',N)]]<-postpred[[sc]][[paste0('train',N)]]+as.vector(m$X%*%coefficient)
   postpred[[sc]][[paste0('test',N)]]<-postpred[[sc]][[paste0('test',N)]]+as.vector(cbind(1,Ftest)%*%coefficient)
  }
 }
 if(j%%25==0){cat('Capacity',j,'/',length(bank$models),'elapsed',unname(proc.time()[3]-began),'\n');flush.console()}
}
capacity<-do.call(rbind,cap);write.csv(capacity,file.path(out,'reservoir_capacity.csv'),row.names=FALSE)
# Verify public observed-feedback design at 1-step equals the original frozen forecasts.
fit_summaries<-list();preds<-list();coef_summary<-list();by_model<-list()
for(sc in names(cps)) {
 cp<-cps[[sc]];method<-if(sc=='ridge_standardized')'ridge' else 'rhs';old<-read.csv(file.path(nh_root,'artifacts',sc,method,'scores.csv'));old<-old[old$horizon==1,]
 for(N in c(192L,384L)) {
  a<-bank$preprocessing$center+bank$preprocessing$scale*postpred[[sc]][[paste0('train',N)]];b<-bank$preprocessing$center+bank$preprocessing$scale*postpred[[sc]][[paste0('test',N)]]
  fit_summaries[[length(fit_summaries)+1L]]<-data.frame(scenario=sc,draws=N,train_y_RMSE=sqrt(mean((a-y[train])^2)),train_mu_RMSE=sqrt(mean((a-mu[train])^2)),test_y_RMSE=sqrt(mean((b-y[test])^2)),test_mu_RMSE=sqrt(mean((b-mu[test])^2)),fitted_signal_SD=sd(a),true_signal_SD=sd(mu[train]),mean_noise_variance=mean(cp$draws$variance)*bank$preprocessing$scale^2)
  preds[[length(preds)+1L]]<-rbind(data.frame(scenario=sc,draws=N,time=train,split='training',mean=a,actual=y[train],true_mean=mu[train]),data.frame(scenario=sc,draws=N,time=test,split='test',mean=b,actual=y[test],true_mean=mu[test]))
  if(N==192){err<-max(abs(b[1:471]-old$mean));stopifnot(err<1e-10);parity<-c(parity,err)}
 }
 B<-lapply(cp$readout_beta,function(v)v[-1]);coef_summary[[sc]]<-do.call(rbind,lapply(seq_along(B),function(k){v<-B[[k]];data.frame(scenario=sc,draw=k,model=cp$draws$model[k],slopes=length(v),exact_zero=sum(v==0),below_001=mean(abs(v)<.001),below_01=mean(abs(v)<.01),below_05=mean(abs(v)<.05),above_10=sum(abs(v)>.1),slope_norm=sqrt(sum(v^2)),max_abs=max(abs(v)))}))
 for(j in unique(cp$draws$model)) {
  ids<-which(cp$draws$model==j);Bmat<-do.call(rbind,lapply(cp$readout_beta[ids],function(v)v[-1]));lo<-apply(Bmat,2,quantile,.025);hi<-apply(Bmat,2,quantile,.975)
  by_model[[length(by_model)+1L]]<-data.frame(scenario=sc,model=j,draws=length(ids),slopes=ncol(Bmat),conditional_CI_excludes_zero=if(length(ids)>=30L) sum(lo>0|hi<0) else NA_integer_,median_abs_coefficient=median(abs(Bmat)),median_slope_norm=median(sqrt(rowSums(Bmat^2))))
 }
}
write.csv(do.call(rbind,fit_summaries),file.path(out,'fitted_function_summary.csv'),row.names=FALSE);write.csv(do.call(rbind,preds),file.path(out,'fitted_functions.csv'),row.names=FALSE)
write.csv(do.call(rbind,coef_summary),file.path(out,'coefficient_draw_diagnostics.csv'),row.names=FALSE);write.csv(do.call(rbind,by_model),file.path(out,'coefficient_model_diagnostics.csv'),row.names=FALSE)
# Add explicit phase information to test input-information vs reservoir-width limits.
phase<-model.matrix(~factor((1:3000-1)%%60))[,-1,drop=FALSE];lagmat<-sapply(c(1,2,12,60),function(k)y[pmax(1,1:3000-k)])
best_noisy<-which.min(capacity$noisy_validation_RMSE);best_oracle<-which.min(capacity$oracle_validation_RMSE)
ids<-unique(c(118L,167L,best_noisy,best_oracle));aug<-list();augpred<-list()
experiments<-c(list(phase_only=list(train=phase[train,],test=phase[test,]),phase_and_raw_lags=list(train=cbind(phase[train,],lagmat[train,]),test=cbind(phase[test,],lagmat[test,]))),setNames(lapply(ids,function(j) list(train=cbind(bank$models[[j]]$X[,-1,drop=FALSE],phase[train,]),test=cbind(features_test[[j]],phase[test,]))),paste0('model_',ids,'_plus_phase')))
for(name in names(experiments))for(target in c('noisy','oracle')) {
 e<-experiments[[name]];a<-choose_fit(e$train,e$test,if(target=='noisy')y[train] else mu[train],if(target=='noisy')y[test] else mu[test])
 aug[[length(aug)+1L]]<-data.frame(model=name,target=target,lambda=a$lambda,validation_RMSE=a$validation_RMSE,train_RMSE=a$train_RMSE,test_y_RMSE=sqrt(mean((a$test_mean-y[test])^2)),test_mu_RMSE=sqrt(mean((a$test_mean-mu[test])^2)))
 augpred[[length(augpred)+1L]]<-data.frame(model=name,target=target,time=test,mean=a$test_mean)
}
write.csv(do.call(rbind,aug),file.path(out,'phase_augmentation.csv'),row.names=FALSE);write.csv(do.call(rbind,augpred),file.path(out,'phase_augmentation_predictions.csv'),row.names=FALSE)
sel<-list(noisy=best_noisy,oracle=best_oracle);selected<-do.call(rbind,lapply(names(sel),function(target){j<-sel[[target]];data.frame(target=target,model=j,time=test,mean=model_preds[[j]][[target]])}));write.csv(selected,file.path(out,'validation_selected_capacity_predictions.csv'),row.names=FALSE)
rhs_json(list(complete=TRUE,candidates=length(bank$models),best_noisy_by_validation=best_noisy,best_oracle_by_validation=best_oracle,forecast_reconstruction_max_error=max(parity),elapsed_seconds=unname(proc.time()[3]-began),selection_used_test=FALSE,oracle_targets_are_privileged=TRUE),file.path(out,'capacity_status.json'))
cat('Capacity, coefficient and forecast-reconstruction audit complete\n')

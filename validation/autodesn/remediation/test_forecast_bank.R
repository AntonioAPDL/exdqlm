# Full-bank controlled numerical recursion, not a posterior benchmark forecast.
source('validation/autodesn/load_checkout.R');source('validation/autodesn/remediation/load_forecast_bank.R')
root<-'validation/autodesn/remediation';b<-remediation_forecast_bank('F1')
stopifnot(length(b$models)==426L,identical(b$keep_idx,501:2500),all(lengths(b$extension$initial_states)>0L))
B<-numeric(ncol(.ext_design(b,1,1)$X));B[1:3]<-c(.1,.5,-.2)
f<-structure(list(bank=b,beta=list(B),draws=data.frame(model=1,period_index=1,variance=.1),controls=list(target=list(bank_id=b$extension$id),variance_control=list(type='constant'),target_id='controlled_numeric_fixture'),meta=list(beta_prior_type='controlled_numeric_fixture',qualified=FALSE)),class=c('autodesn_extended_fit','autodesn_fit'))
z<-matrix(c(.2,-.3,.1),3,1);a<-forecast_paths(f,3,draw_index=1,inner_paths=1,innovations=z,seed=117)
history<-b$history_scaled;expected<-numeric(3)
for(h in 1:3){lag<-history[length(history)+1L-1:2];mu<-.1+sum((lag-b$extension$lag$center[1:2])/b$extension$lag$scale[1:2]*c(.5,-.2));y<-mu+sqrt(.1)*z[h];expected[h]<-b$preprocessing$center+b$preprocessing$scale*y;history<-c(history,y)}
error<-max(abs(expected-a$yrep));stopifnot(error<1e-11)
u<-autodesn_update_history(f,c(.1,.3));v<-autodesn_update_history(f,c(.1,300))
for(m in 1:426)stopifnot(identical(u$bank$extension$last_observation_features[[m]][1,],v$bank$extension$last_observation_features[[m]][1,]))
jsonlite::write_json(list(complete=TRUE,reservoirs=426L,source_bank_id=b$extension$id,forecast_map_id=b$extension$forecast_map_id,maximum_manual_recursive_path_error=error,all_426_first_observed_updates_independent_of_second_value=TRUE,benchmark_forecasts_issued=FALSE,scope='Controlled arbitrary coefficient/innovation unit fixture on the full original bank; no unqualified posterior scores and no held-out response read'),file.path(root,'evidence/full_bank_forecast_integration.json'),pretty=TRUE,auto_unbox=TRUE)

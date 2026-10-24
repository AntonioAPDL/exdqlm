# Paired synthetic forecast benchmark. No NHS1 future response or qualified fit.
source('validation/autodesn/load_checkout.R')
reference<-new.env(parent=.GlobalEnv);sys.source('validation/autodesn/remediation/references/forecast_unbatched.R',reference)
set.seed(6266100);y<-sin((1:500)/8)+rnorm(500,sd=.2)
specs<-lapply(1:2,function(k)list(D=1,n=64,n_tilde=integer(0),m=3,alpha=.5,rho=.6,seed=720+k,washout=20,pi_in=1,pi_w=1))
b<-autodesn_build_bank(y,specs,conditioning=5,washout=20,standardize_features=TRUE,normalize_features=FALSE)
e<-autodesn_extend_bank(b,list(lags=1:12),list(periods=20:22,harmonics=4))
f<-autodesn_fit_bank(e,n_burn=20,n_mcmc=50,beta_prior='ridge',seed=36,backend='R')
ids<-sample.int(nrow(f$draws),192,replace=TRUE);Z<-matrix(rnorm(30*192*8),30)
a<-forecast_paths(f,30,draw_index=ids,inner_paths=8,innovations=Z,seed=37)
r<-reference$forecast_paths.autodesn_extended_fit(f,30,draw_index=ids,inner_paths=8,innovations=Z,seed=37)
error<-max(abs(a$yrep-r$yrep),abs(a$mu_draws-r$mu_draws),abs(a$sd_draws-r$sd_draws));stopifnot(error<1e-10)
rows<-list();j<-0L
for(replicate in 1:7)for(backend in sample(c('reference','batched'))) {
 t<-proc.time();fun<-if(backend=='reference')reference$forecast_paths.autodesn_extended_fit else forecast_paths.autodesn_extended_fit
 invisible(fun(f,30,draw_index=ids,inner_paths=8,innovations=Z,seed=37));delta<-proc.time()-t
 j<-j+1;rows[[j]]<-data.frame(replicate=replicate,backend=backend,elapsed_seconds=unname(delta[3]),cpu_seconds=unname(sum(delta[1:2])))
}
rows<-do.call(rbind,rows);write.csv(rows,'validation/autodesn/remediation/evidence/forecast_batch_timings.csv',row.names=FALSE)
summary<-aggregate(cbind(elapsed_seconds,cpu_seconds)~backend,rows,median)
jsonlite::write_json(list(complete=TRUE,scope='Synthetic reservoir-64 fixture with unqualified short fit, paired H30/192 outer/8 inner simulation; other training job active, not whole-study speedup',max_absolute_path_error=error,summary=summary,forecast_outer=192,forecast_inner=8,forecast_horizon=30,posterior_qualified=FALSE,source_reference_sha256=digest::digest(file='validation/autodesn/remediation/references/forecast_unbatched.R',algo='sha256')), 'validation/autodesn/remediation/evidence/forecast_batch_benchmark.json',pretty=TRUE,auto_unbox=TRUE)
print(summary);print(error)

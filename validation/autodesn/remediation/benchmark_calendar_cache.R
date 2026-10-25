# Full original bank: computational comparison only, no new forecast or tuning.
snapshot<-Sys.getenv('AUTODESN_SOURCE_SNAPSHOT');stopifnot(nzchar(snapshot))
for(p in list.files(file.path(snapshot,'R'),pattern='[.]R$',full.names=TRUE))source(p,local=.GlobalEnv)
Rcpp::sourceCpp(file.path(snapshot,'src/autodesn_rhs.cpp'),cacheDir='validation/autodesn/remediation/artifacts/cpp',showOutput=FALSE)
r<-'validation/autodesn/remediation';manifest<-jsonlite::fromJSON(file.path(r,'artifacts/inference_cache_manifest.json'))
stopifnot(identical(digest::digest(file=manifest$path,algo='sha256'),manifest$sha256))
b<-readRDS(manifest$path);p<-manifest$extensions$F2$path
stopifnot(identical(digest::digest(file=p,algo='sha256'),manifest$extensions$F2$sha256))
b$extension<-readRDS(p);class(b)<-c('autodesn_extended_bank',class(b))
stopifnot(length(b$models)==426L,length(b$extension$periods)==101L,b$n==2000L)
out<-file.path(r,'artifacts/calendar_cache_benchmark');stopifnot(!dir.exists(out));dir.create(out,recursive=TRUE)
gc(FALSE);started<-proc.time()[3];s<-autodesn_cache_calendar_blocks(b,max_bytes=128*1024^2);construction<-unname(proc.time()[3]-started)
write.csv(data.frame(model=seq_along(b$models),slopes=vapply(b$models,`[[`,0L,'d')),file.path(out,'dimensions.csv'),row.names=FALSE)
# All architectures at three periods, plus all periods at three distinct sizes.
extremes<-unique(c(which.min(vapply(b$models,`[[`,0L,'d')),213L,which.max(vapply(b$models,`[[`,0L,'d'))))
pairs<-unique(rbind(expand.grid(model=1:426,period=c(1L,51L,101L)),expand.grid(model=extremes,period=1:101)))
maximum_gram_error<-maximum_xty_error<-0
for(i in seq_len(nrow(pairs))){
 m<-pairs$model[i];p<-pairs$period[i];a<-.ext_design(b,m,p);z<-.ext_design(s,m,p)
 stopifnot(identical(a$X,z$X),identical(a$slots,z$slots),identical(a$groups,z$groups))
 maximum_gram_error<-max(maximum_gram_error,max(abs(a$XtX-z$XtX)))
 maximum_xty_error<-max(maximum_xty_error,max(abs(a$Xty-z$Xty)))
 stopifnot(isTRUE(all.equal(a$XtX,z$XtX,tolerance=1e-12)),isTRUE(all.equal(a$Xty,z$Xty,tolerance=1e-12)))
}
saveRDS(s$extension$statistics_cache,file.path(out,'blocks.rds'))
all_model_support<-identical(b$prior,s$prior)&&identical(b$extension$period_prior,s$extension$period_prior)&&identical(b$extension$id,s$extension$id)
# Dispersed dimensions/periods, including interactions intentionally not cached.
panel<-unique(rbind(expand.grid(model=unique(as.integer(round(seq(1,426,length.out=12)))),period=c(1L,26L,51L,76L,101L)),expand.grid(model=extremes,period=c(3L,49L,99L))))
timings<-list();results<-list()
for(repetition in 1:3){
 order<-if(repetition%%2)c('direct','blocks') else c('blocks','direct')
 for(kind in order){
  bank<-if(kind=='direct')b else s;gc(FALSE);t<-proc.time()[3]
  checksum<-sum(vapply(seq_len(nrow(panel)),function(i){d<-.ext_design(bank,panel$model[i],panel$period[i]);sum(diag(d$XtX))+sum(d$Xty)},0))
  timings[[length(timings)+1L]]<-data.frame(repetition=repetition,kind=kind,seconds=unname(proc.time()[3]-t),checksum=checksum,pairs=nrow(panel))
 }
}
timings<-do.call(rbind,timings);write.csv(timings,file.path(r,'evidence/calendar_cache_design_benchmark.csv'),row.names=FALSE)
# Same fresh seeds and complete support. This is not posterior qualification.
for(repetition in 1:3){
 order<-if(repetition%%2)c('direct','blocks') else c('blocks','direct');fits<-list()
 for(kind in order){
  bank<-if(kind=='direct')b else s;gc(FALSE);started<-proc.time()[3]
  f<-autodesn_fit_bank(bank,n_burn=100L,n_mcmc=500L,beta_prior='rhs',rhs_control=list(tau0=.001,slab_scale=1,slab_df=4,interweave_global=TRUE),model_control=list(moves=4L,joint_moves=2L,save_draws=32L),seed=9466300L+repetition,backend='cpp')
  elapsed<-unname(proc.time()[3]-started);f$bank<-NULL;fits[[kind]]<-f
  saveRDS(f,file.path(out,paste0('fit_',repetition,'_',kind,'.rds')))
  results[[length(results)+1L]]<-data.frame(repetition=repetition,kind=kind,seconds=elapsed)
 }
 for(field in c('trace','draws','beta','local','volatility','probes','model_summary'))stopifnot(isTRUE(all.equal(fits$direct[[field]],fits$blocks[[field]],tolerance=1e-9)))
 stopifnot(identical(fits$direct$draws$model,fits$blocks$draws$model),identical(fits$direct$draws$period_index,fits$blocks$draws$period_index),identical(fits$direct$controls$target_id,fits$blocks$controls$target_id))
}
results<-do.call(rbind,results);write.csv(results,file.path(r,'evidence/calendar_cache_sampler_benchmark.csv'),row.names=FALSE)
record<-list(complete=TRUE,all_model_support=all_model_support,architectures=426L,periods=101L,checked_design_pairs=nrow(pairs),maximum_gram_absolute_error=maximum_gram_error,maximum_xty_absolute_error=maximum_xty_error,construction_seconds=construction,numeric_payload_bytes=s$extension$statistics_cache$payload_bytes,max_bytes=s$extension$statistics_cache$max_bytes,cached_reservoir_calendar_interactions=length(s$extension$statistics_cache$interactions),sampler_pairs=3L,warmup=100L,retained=500L,matching_sampler_states_within_tolerance=TRUE,model_period_sequences_identical=TRUE,direct_design_median_seconds=median(timings$seconds[timings$kind=='direct']),block_design_median_seconds=median(timings$seconds[timings$kind=='blocks']),direct_sampler_median_seconds=median(results$seconds[results$kind=='direct']),block_sampler_median_seconds=median(results$seconds[results$kind=='blocks']),source_snapshot=basename(snapshot),heldout_used=FALSE,posterior_qualified=FALSE,scope='Three paired alternating-order short full426-model/101-period RHS computations under concurrent production load; no independent DGP replications or whole-study speed claim')
jsonlite::write_json(record,file.path(r,'evidence/calendar_cache_benchmark.json'),pretty=TRUE,auto_unbox=TRUE,digits=16)
print(record)

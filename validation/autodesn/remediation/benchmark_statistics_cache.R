# Three paired training-only timings and exact whole-chain output comparison.
source('validation/autodesn/load_checkout.R');root<-'validation/autodesn/remediation'
Rcpp::sourceCpp('src/autodesn_rhs.cpp',cacheDir=file.path(root,'artifacts/cpp'),showOutput=FALSE)
manifest<-jsonlite::fromJSON(file.path(root,'artifacts/inference_cache_manifest.json'))
stopifnot(identical(digest::digest(file=manifest$path,algo='sha256'),manifest$sha256))
b<-readRDS(manifest$path);b$extension<-readRDS(manifest$extensions$F1$path);class(b)<-c('autodesn_extended_bank',class(b))
began<-proc.time()[3];cached<-autodesn_cache_statistics(b);construction<-unname(proc.time()[3]-began)
cache<-cached$extension$statistics_cache
stopifnot(identical(cached$extension$id,b$extension$id),length(cache$entries)==426L)
path<-file.path(root,'artifacts/statistics_F1.rds');temporary<-paste0(path,'.writing');saveRDS(cache,temporary);stopifnot(file.rename(temporary,path))
q<-readRDS(file.path(root,'artifacts/F1/frozen_proposal_128.rds'));lp<-readRDS(file.path(root,'artifacts/F1/frozen_local_proposal_128.rds'))
stopifnot(identical(q$bank_id,b$extension$id),identical(lp$proposal$bank_id,b$extension$id))
fit<-function(bank,seed){autodesn_fit_bank(bank,n_burn=500L,n_mcmc=2000L,beta_prior='rhs',rhs_control=list(tau0=.001,slab_scale=1,slab_df=4,interweave_global=TRUE),model_control=list(moves=4L,joint_moves=2L,save_draws=128L,proposal=q$model,period_proposal=q$period,joint_proposal=q$joint,local_proposal=lp$proposal,local_moves=1L,local_scale_proposal=TRUE),initial_variance=1,seed=seed,backend='cpp')}
rows<-list()
for(k in 1:3){
 seed<-9366020L+k
 # Alternate order to expose gross timing/order effects under concurrent load.
 if(k%%2L){x<-fit(b,seed);z<-fit(cached,seed)} else {z<-fit(cached,seed);x<-fit(b,seed)}
 fields<-c('trace','draws','beta','local','volatility','probes','model_summary','period_summary')
 stopifnot(all(vapply(fields,function(nm)identical(x[[nm]],z[[nm]]),TRUE)),identical(x$controls$target_id,z$controls$target_id))
 rows[[k]]<-data.frame(pair=k,seed=seed,uncached_seconds=x$computation$elapsed_seconds,cached_seconds=z$computation$elapsed_seconds,all_recorded_states_bit_identical=TRUE)
 rm(x,z);gc(FALSE)
}
table<-do.call(rbind,rows);write.csv(table,file.path(root,'evidence/statistics_cache_benchmark.csv'),row.names=FALSE)
record<-list(complete=TRUE,pairs=3L,warmup=500L,retained=2000L,cache_construction_seconds=construction,cached_pairs=length(cache$entries),cache_payload_bytes=cache$payload_bytes,maximum_payload_bytes=cache$max_bytes,cache_path=path,cache_sha256=digest::digest(file=path,algo='sha256'),bank_id=b$extension$id,median_uncached_seconds=median(table$uncached_seconds),median_cached_seconds=median(table$cached_seconds),all_recorded_states_bit_identical=TRUE,test_outcomes_used=FALSE,scope='Three alternating-order same-seed full-bank short training runs under concurrent calibration load. Includes all traces, matching coefficients/locals/states, probes and architecture masses. Computational timing, not independent DGP replications or production qualification.')
jsonlite::write_json(record,file.path(root,'evidence/statistics_cache_benchmark.json'),pretty=TRUE,auto_unbox=TRUE);print(record)

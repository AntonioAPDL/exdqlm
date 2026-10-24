# Same full-bank seed/target with and without retained construction environments.
root<-'validation/autodesn/remediation';rows<-list()
for(k in c(2L,4L)){
 a<-readRDS(file.path(root,'artifacts/F1/production_32000',paste0('chain_',k,'.rds')))$fit
 b<-readRDS(file.path(root,'artifacts/F1/production_32000_cache1',paste0('chain_',k,'.rds')))$fit
 common<-intersect(names(a$trace),names(b$trace))
 stopifnot(identical(a$controls$target_id,b$controls$target_id),identical(a$trace[common],b$trace[common]),identical(a$beta,b$beta),identical(a$local,b$local),identical(a$volatility,b$volatility),identical(a$probes,b$probes))
 rows[[length(rows)+1L]]<-list(chain=k,common_trace_fields=length(common),saved_joint_states=length(a$beta),trace_and_joint_states_bit_identical=TRUE)
 rm(a,b);gc(FALSE)
}
jsonlite::write_json(list(complete=TRUE,passed=TRUE,chains=rows,scope='Original full-bank production and exact matrix/augmentation cache, same initial values, seeds and target; no statistical approximation'),file.path(root,'evidence/cache_posterior_parity.json'),pretty=TRUE,auto_unbox=TRUE)

# Measure, rather than assume, which optional construction objects dominate RSS.
root<-'validation/autodesn/remediation';source('validation/autodesn/load_checkout.R')
rss<-function(){s<-readLines('/proc/self/status');as.numeric(sub('.*:[[:space:]]*([0-9]+).*','\\1',s[grepl('^VmRSS:',s)]))}
record<-list();b<-readRDS('validation/autodesn/nonlinear_heteroscedastic/artifacts/standardized_bank/bank.rds')
record$loaded_rss_kib<-rss();record$components<-data.frame(component=names(b),bytes=vapply(b,function(x)as.numeric(object.size(x)),0))
e<-autodesn_extend_bank(b,list(lags=1:90),list(periods=20:120,harmonics=16));identity<-e$extension$id
# Every admitted design, prior mass and statistical target field remains present.
e$templates<-NULL;b<-NULL;gc(TRUE)
record$stripped_rss_kib<-rss();record$gc<-as.data.frame(gc());record$target_bank_id<-identity;record$admitted<-length(e$models);record$all_model_masses_retained<-length(e$prior)==426L&&all(e$prior>0)
# Save the already verified inference-only matrix view for a long memory test.
saveRDS(e,file.path(root,'artifacts/inference_bank_F2flat.rds'),compress=FALSE)
jsonlite::write_json(record,file.path(root,'evidence/inference_bank_memory.json'),pretty=TRUE,auto_unbox=TRUE)
print(record[c('loaded_rss_kib','stripped_rss_kib','admitted')]);print(record$components)

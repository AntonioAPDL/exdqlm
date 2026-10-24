# Recreate an interrupted CSV export from matching immutable joint states.
root<-'validation/autodesn/remediation'
d<-file.path(root,'artifacts/F1/production_128000_joint128')
contract<-readRDS(file.path(d,'contract.rds'));records<-list()
for(k in 1:4) {
 p<-file.path(d,paste0('chain_',k,'.rds'))
 st<-jsonlite::fromJSON(file.path(d,paste0('chain_',k,'_status.json')))
 stopifnot(identical(digest::digest(file=p,algo='sha256'),st$checkpoint_sha256))
 x<-readRDS(p);f<-x$fit
 stopifnot(identical(x$contract_id,contract$id),identical(st$contract_id,contract$id),nrow(f$trace)==128000L)
 tr<-f$trace;tr$chain<-k
 for(j in seq_len(ncol(f$probes)))tr[[paste0('fitted_probe_',j)]]<-f$probes[,j]
 target<-file.path(d,paste0('trace_',k,'.csv'));tmp<-paste0(target,'.recovered')
 write.csv(tr,tmp,row.names=FALSE)
 regenerated_sha<-digest::digest(file=tmp,algo='sha256')
 had_original<-file.exists(target)
 if(had_original) {
  stopifnot(identical(regenerated_sha,digest::digest(file=target,algo='sha256')))
  unlink(tmp)
 } else stopifnot(file.rename(tmp,target))
 records[[k]]<-list(chain=k,checkpoint_sha256=st$checkpoint_sha256,csv_sha256=regenerated_sha,original_csv_recovered=had_original,existing_csv_bit_identical=if(had_original)TRUE else NULL)
 rm(x,f,tr);gc(FALSE)
}
record<-list(complete=TRUE,chains=4L,contract_id=contract$id,records=records,
 scope='All four original RDS hashes and contracts verify; existing CSVs 1-3 reproduce byte for byte; missing CSV4 regenerated from its matching saved trace/probes. This does not alter inference or establish convergence.')
jsonlite::write_json(record,file.path(root,'evidence/joint128_trace_recovery.json'),pretty=TRUE,auto_unbox=TRUE)
print(record)

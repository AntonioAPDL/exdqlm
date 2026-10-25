# Freeze consistent copies of atomic checkpoints while their live paths advance.
args<-commandArgs(TRUE);stopifnot(length(args)==3L,args[1]%in%c('F1','F2','SV','F2flat','SVseasonal','F1ridge','F2ridge'),grepl('^[A-Za-z0-9_]+$',args[2]),grepl('^[A-Za-z0-9_]+$',args[3]))
r<-'validation/autodesn/remediation';directory<-file.path(r,'artifacts',args[1],args[2])
out<-file.path(r,'artifacts/live_chain_snapshots',args[3]);stopifnot(!dir.exists(out));dir.create(out,recursive=TRUE)
contract<-readRDS(file.path(directory,'contract.rds'));configuration<-contract$configuration
stopifnot(identical(contract$id,digest::digest(configuration,algo='sha256')))
records<-lapply(1:4,function(k){
  source<-file.path(directory,paste0('chain_',k,'_progress.rds'))
  status<-jsonlite::fromJSON(file.path(directory,paste0('chain_',k,'_progress_status.json')))
  stopifnot(identical(status$contract_id,contract$id))
  temporary<-file.path(out,paste0('copy_',k,'.writing'))
  # The writer replaces this inode atomically and never modifies it in place.
  stopifnot(file.copy(source,temporary,overwrite=FALSE))
  x<-readRDS(temporary)
  stopifnot(identical(x$version,1L),identical(x$id,status$checkpoint_id),
    identical(x$sha256,digest::digest(x$payload,algo='sha256')),
    x$payload$iteration>=1L,x$payload$iteration<=configuration$burn+configuration$retained,
    x$payload$retained==max(0L,x$payload$iteration-configuration$burn),
    nrow(x$payload$draws)==x$payload$retained,nrow(x$payload$probes)==x$payload$retained)
  sha<-digest::digest(file=temporary,algo='sha256')
  path<-file.path(out,paste0('chain_',k,'_sweep_',x$payload$iteration,'.rds'))
  stopifnot(!file.exists(path),file.rename(temporary,path))
  list(chain=k,path=path,sha256=sha,checkpoint_id=x$id,iteration=x$payload$iteration,
    retained=x$payload$retained,complete_fit=FALSE,qualified=FALSE)
})
for(name in c('contract.rds','configuration.json'))stopifnot(file.copy(file.path(directory,name),file.path(out,name),overwrite=FALSE))
result<-list(complete=TRUE,observation_utc=format(Sys.time(),tz='UTC',usetz=TRUE),family=args[1],phase=args[2],
  contract_id=contract$id,configuration_sha256=digest::digest(file=file.path(out,'configuration.json'),algo='sha256'),
  contract_file_sha256=digest::digest(file=file.path(out,'contract.rds'),algo='sha256'),records=records,
  live_paths_may_advance=TRUE,original_process_exit_inferred=FALSE,posterior_qualified=FALSE,
  source_snapshot=configuration$source_sha256,forecast_allowed=FALSE,
  scope='Immutable observation of completed sweep-boundary files from an advancing invocation. File/internal payload/source-contract checks pass. These are the same four incomplete chains, not new chains or completed posteriors. Restore only while no writer holds the large-job reservation, using the matching full budget and immutable source snapshot.')
jsonlite::write_json(result,file.path(out,'manifest.json'),pretty=TRUE,auto_unbox=TRUE)
jsonlite::write_json(result,file.path(r,'evidence',paste0('live_chain_snapshot_',args[3],'.json')),pretty=TRUE,auto_unbox=TRUE)
cat('VERIFIED_LIVE_SNAPSHOT',paste(vapply(records,`[[`,0L,'iteration'),collapse=','),'\n')

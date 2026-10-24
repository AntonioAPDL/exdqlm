# Atomic import of same-case calculations from an isolated scheduling shard.
# Source/RNG/truth/retained-budget contracts must match; these are not new cases.
remediation_import_sbc_shard<-function(source,destination,cases,record,audit_only=FALSE){
 stopifnot(!file.exists(record),length(cases)>0L,!anyDuplicated(cases))
 a<-readRDS(file.path(source,'contract.rds'));b<-readRDS(file.path(destination,'contract.rds'))
 stopifnot(identical(a,b),all(cases%in%seq_len(a$contract$replications)))
 core<-function(x){x$computation$elapsed_seconds<-NULL;x}
 validate<-function(x,r){
  stopifnot(identical(x$contract_id,a$id),identical(as.integer(x$case),as.integer(r)),
   isTRUE(x$frozen_geometry_verified),isTRUE(x$causal_design_reconstruction_verified),
   all(is.finite(x$u)),all(x$u>=0&x$u<=1),all(is.finite(x$ess)),all(x$ess>0),
   is.character(x$target_id),length(x$target_id)==1L,grepl('^[0-9a-f]{64}$',x$target_id))
 }
 rows<-list();missing<-integer();busy<-integer()
 for(r in cases){
  src<-file.path(source,paste0('case_',r,'.rds'));dst<-file.path(destination,paste0('case_',r,'.rds'))
  if(!file.exists(src)){missing<-c(missing,r);next}
  x<-readRDS(src);validate(x,r);sha<-digest::digest(file=src,algo='sha256')
  if(file.exists(paste0(dst,'.writing'))){busy<-c(busy,r);next}
  imported<-FALSE
  if(!file.exists(dst)&&!audit_only){
   temporary<-tempfile('verified-shard-',tmpdir=destination)
   stopifnot(file.copy(src,temporary,overwrite=FALSE),identical(digest::digest(file=temporary,algo='sha256'),sha))
   # link is an exclusive, atomic publication on the destination filesystem.
   imported<-suppressWarnings(file.link(temporary,dst));unlink(temporary)
   if(!imported&&!file.exists(dst))stop('Atomic shard publication failed')
  }
  stopifnot(file.exists(dst));y<-readRDS(dst);validate(y,r)
  stopifnot(identical(core(x),core(y)))
  rows[[length(rows)+1L]]<-list(case=r,action=if(imported)'imported' else 'existing_equal',target_id=x$target_id,source_sha256=sha,destination_sha256_at_observation=digest::digest(file=dst,algo='sha256'),semantic_contents_identical=TRUE)
 }
 result<-list(complete=TRUE,audit_only=audit_only,contract_id=a$id,source=source,destination=destination,selected_cases=cases,missing_source_cases=missing,destination_writers_observed=busy,all_selected_cases_verified=length(rows)==length(cases),records=rows,independent_replications_added=0L,scope='Same-case same-source/prior/map/seed/budget import. Only elapsed computation time may differ for duplicate calculations. Atomic exclusive publication; record hashes describe the observation time, with final audit required after original writers finish.')
 jsonlite::write_json(result,record,pretty=TRUE,auto_unbox=TRUE);result
}

if(sys.nframe()==0L){
 args<-commandArgs(TRUE);stopifnot(length(args)%in%c(4L,5L))
 cases<-as.integer(strsplit(args[3],',',fixed=TRUE)[[1]])
 x<-remediation_import_sbc_shard(args[1],args[2],cases,args[4],length(args)==5L&&args[5]=='--audit-only')
 cat('Verified',length(x$records),'same-case records; missing',length(x$missing_source_cases),'busy',length(x$destination_writers_observed),'\n')
}

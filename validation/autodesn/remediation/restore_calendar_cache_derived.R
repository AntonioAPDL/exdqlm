# Recreate a bank-free archive's omitted, rapidly reconstructible numeric cache.
args<-commandArgs(TRUE);index<-if(length(args))as.integer(args[1]) else 1L
r<-'validation/autodesn/remediation';inventory<-jsonlite::read_json(file.path(r,'evidence/calendar_cache_derived_inventory.json'),simplifyVector=FALSE)
stopifnot(index%in%seq_along(inventory$files));entry<-inventory$files[[index]]
if(file.exists(entry$path)){
 stopifnot(identical(digest::digest(file=entry$path,algo='sha256'),entry$sha256));cat('DERIVED_CACHE_ALREADY_VERIFIED\n')
}else{
 snapshot<-file.path(r,'artifacts/calendar_cache_sources',entry$source_snapshot)
 for(p in list.files(file.path(snapshot,'R'),pattern='[.]R$',full.names=TRUE))source(p,local=.GlobalEnv)
 m<-jsonlite::fromJSON(file.path(r,'artifacts/inference_cache_manifest.json'))
 stopifnot(identical(digest::digest(file=m$path,algo='sha256'),m$sha256))
 b<-readRDS(m$path);b$extension<-readRDS(m$extensions$F2$path);class(b)<-c('autodesn_extended_bank',class(b))
 b<-autodesn_cache_calendar_blocks(b,max_bytes=entry$max_bytes)
 dir.create(dirname(entry$path),recursive=TRUE,showWarnings=FALSE);temporary<-paste0(entry$path,'.writing');stopifnot(!file.exists(temporary))
 saveRDS(b$extension$statistics_cache,temporary)
 stopifnot(identical(digest::digest(file=temporary,algo='sha256'),entry$sha256),file.rename(temporary,entry$path))
 cat('DERIVED_CACHE_RECONSTRUCTED_AND_SHA_VERIFIED\n')
}

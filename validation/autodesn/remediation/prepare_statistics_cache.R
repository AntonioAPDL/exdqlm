# Reconstruct a computational cache without rerunning timing pairs.
source('validation/autodesn/load_checkout.R')
args<-commandArgs(TRUE);stopifnot(length(args)%in%c(1L,2L),args[1]%in%c('F1','F2','F2flat'))
family<-args[1];root<-'validation/autodesn/remediation'
manifest<-jsonlite::fromJSON(file.path(root,'artifacts/inference_cache_manifest.json'))
stopifnot(identical(digest::digest(file=manifest$path,algo='sha256'),manifest$sha256))
entry<-manifest$extensions[[family]]
stopifnot(identical(digest::digest(file=entry$path,algo='sha256'),entry$sha256))
b<-readRDS(manifest$path);b$extension<-readRDS(entry$path);class(b)<-c('autodesn_extended_bank',class(b))
began<-proc.time()[3];b<-autodesn_cache_statistics(b);seconds<-unname(proc.time()[3]-began)
path<-if(length(args)==2L)args[2] else file.path(root,'artifacts',paste0('statistics_',family,'.rds'))
stopifnot(!file.exists(path));temporary<-paste0(path,'.writing');saveRDS(b$extension$statistics_cache,temporary)
stopifnot(identical(readRDS(temporary)$bank_id,entry$bank_id),file.rename(temporary,path))
record<-list(complete=TRUE,bank_id=entry$bank_id,cache_path=path,cache_sha256=digest::digest(file=path,algo='sha256'),cached_pairs=length(b$extension$statistics_cache$entries),total_pairs=b$extension$statistics_cache$total_pairs,payload_bytes=b$extension$statistics_cache$payload_bytes,construction_seconds=seconds,scope='Fixed unweighted design cache; uncomputed pairs retain on-demand evaluation and all prior support. No forecast issued.')
jsonlite::write_json(record,paste0(path,'.json'),pretty=TRUE,auto_unbox=TRUE);print(record)

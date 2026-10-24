# Precompute the small, already verified augmentation objects once. Fitting
# reloads them without allocating another serialization of every design matrix.
source('validation/autodesn/load_checkout.R');root<-'validation/autodesn/remediation';m<-jsonlite::fromJSON(file.path(root,'artifacts/inference_cache_manifest.json'));stopifnot(identical(digest::digest(file=m$path,algo='sha256'),m$sha256));raw<-readRDS(m$path)
entries<-list()
for(family in c('F1','F2','F2flat')) {
 e<-autodesn_extend_bank(raw,list(lags=1:90,prior=if(family=='F2')'grouped' else 'flat',cache_size=32),if(family=='F1')NULL else list(periods=20:120,harmonics=16));stopifnot(identical(e$extension$id,m$bank_ids[[family]]))
 path<-file.path(root,'artifacts',paste0('extension_',family,'.rds'));temporary<-paste0(path,'.writing');saveRDS(e$extension,temporary);stopifnot(identical(readRDS(temporary)$id,e$extension$id),file.rename(temporary,path))
 entries[[family]]<-list(path=path,sha256=digest::digest(file=path,algo='sha256'),bank_id=e$extension$id)
}
m$extensions<-entries;jsonlite::write_json(m,file.path(root,'artifacts/inference_cache_manifest.json'),pretty=TRUE,auto_unbox=TRUE);jsonlite::write_json(m,file.path(root,'evidence/inference_cache_validation.json'),pretty=TRUE,auto_unbox=TRUE)

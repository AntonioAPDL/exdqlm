# Add the architecture-metadata identity to an already complete RDS/CSV audit.
# The base record is retained, reverified, and referenced rather than overwritten.
args<-commandArgs(TRUE);stopifnot(length(args)==3L,!file.exists(args[3]))
base<-jsonlite::fromJSON(args[1],simplifyVector=FALSE);d<-args[2]
stopifnot(isTRUE(base$complete),base$chain_artifacts_verified==4L,length(base$input_files_sha256)>=14L)
for(name in names(base$input_files_sha256))stopifnot(identical(basename(name),name),identical(digest::digest(file=file.path(d,name),algo='sha256'),base$input_files_sha256[[name]]))
p<-file.path(d,'model_metadata.csv');metadata<-read.csv(p)
for(k in 1:4){f<-readRDS(file.path(d,paste0('chain_',k,'.rds')))$fit;stopifnot(identical(f$controls$target_id,base$target_id),isTRUE(all.equal(metadata,f$model_summary[,names(metadata),drop=FALSE],tolerance=1e-12,check.attributes=FALSE)));rm(f);gc(FALSE)}
base$input_files_sha256[['model_metadata.csv']]<-digest::digest(file=p,algo='sha256')
base$base_validation<-list(path=args[1],sha256=digest::digest(file=args[1],algo='sha256'))
base$metadata_supplement<-list(path='validation/autodesn/remediation/supplement_metadata_binding.R',sha256=digest::digest(file='validation/autodesn/remediation/supplement_metadata_binding.R',algo='sha256'))
jsonlite::write_json(base,args[3],auto_unbox=TRUE,pretty=TRUE)
cat('METADATA_BINDING_SUPPLEMENT_COMPLETE\n')

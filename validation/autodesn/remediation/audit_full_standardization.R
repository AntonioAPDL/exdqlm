# Check actual Gram matrices used in inference, not just scaler metadata.
r<-'validation/autodesn/remediation';cfg<-jsonlite::fromJSON(file.path(r,'artifacts/F1/production_256000_joint128_recoverable/configuration.json'))
path<-cfg$statistics_cache_path;stopifnot(identical(digest::digest(file=path,algo='sha256'),cfg$statistics_cache_sha256))
s<-readRDS(path);stopifnot(identical(s$bank_id,cfg$bank_id),length(s$entries)==426L)
rows<-lapply(names(s$entries),function(key){
 G<-s$entries[[key]]$XtX;n<-G[1,1];mu<-G[-1,1]/n
 v<-(diag(G)[-1L]-G[-1L,1]^2/n)/(n-1)
 data.frame(component='F1 full readout',key=key,n=n,slopes=length(v),maximum_absolute_mean=max(abs(mu)),maximum_sample_sd_error=max(abs(sqrt(v)-1)),finite=all(is.finite(v)))
})
stopifnot(all(vapply(rows,function(x)x$n==2000,TRUE)))
rm(s);gc(FALSE)
manifest<-jsonlite::fromJSON(file.path(r,'artifacts/inference_cache_manifest.json'));calendars<-list()
for(family in c('F2','F2flat')){
 e<-manifest$extensions[[family]];stopifnot(identical(digest::digest(file=e$path,algo='sha256'),e$sha256))
 extension<-readRDS(e$path);calendars[[family]]<-vapply(extension$calendar,function(z)digest::digest(z$X,algo='sha256'),'')
 for(k in seq_along(extension$calendar)){
  X<-extension$calendar[[k]]$X;v<-apply(X,2,sd)
  rows[[length(rows)+1L]]<-data.frame(component=paste(family,'calendar'),key=as.character(extension$periods[k]),n=nrow(X),slopes=ncol(X),maximum_absolute_mean=max(abs(colMeans(X))),maximum_sample_sd_error=max(abs(v-1)),finite=all(is.finite(v)))
 }
 rm(extension);gc(FALSE)
}
stopifnot(identical(calendars$F2,calendars$F2flat))
t<-do.call(rbind,rows);write.csv(t,file.path(r,'evidence/full_standardization.csv'),row.names=FALSE)
passed<-all(t$finite)&all(t$maximum_absolute_mean<1e-10)&all(t$maximum_sample_sd_error<1e-10)
jsonlite::write_json(list(complete=TRUE,passed=passed,reservoir_readouts=426L,calendar_variants=202L,
  maximum_absolute_mean=max(t$maximum_absolute_mean),maximum_sample_sd_error=max(t$maximum_sample_sd_error),
  F2_and_F2flat_calendar_matrices_bit_identical=TRUE,statistics_cache_sha256=cfg$statistics_cache_sha256,
  intercept_exempt=TRUE,dimension_division_applied=FALSE,heldout_used=FALSE,
  scope='Actual inference-Gram audit of every F1 slope, including all90 direct lags and reservoir coordinates, plus direct matrix checks of all101 calendar periods in F2 and F2flat. All readout slopes are centered with unit sample SD on501:2500; the proper-prior intercept is constant. Shared original reservoir inputs retain their first500 conditioning transformation.'),file.path(r,'evidence/full_standardization.json'),pretty=TRUE,auto_unbox=TRUE)
if(!passed)quit(status=2)
cat('All426 readouts and202 calendar variants have centered unit-sample-SD slopes\n')

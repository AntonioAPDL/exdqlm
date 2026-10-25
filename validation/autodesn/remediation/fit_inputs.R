# Study adapters only. Every inferential parameter is still fitted by the
# public AutoDESN API; no validation responses are read here.
remediation_mean_selection <- function(path) {
 if(!nzchar(path)||!file.exists(path))stop('SV requires a frozen qualified mean-selection certificate.')
 x<-jsonlite::fromJSON(path,simplifyVector=FALSE)
 if(!isTRUE(x$complete)||!isTRUE(x$selection_frozen)||!isTRUE(x$posterior_qualified)||
    !identical(x$heldout_test_used,FALSE)||!x$chosen_mean_family%in%c('F1','F2','F2flat')||
    !length(x$inputs)||is.null(names(x$inputs))||any(!nzchar(names(x$inputs)))||anyDuplicated(names(x$inputs))||
    !setequal(as.integer(unlist(x$development_cutoffs)),c(1500L,2000L)))
   stop('Invalid mean-selection certificate; both qualified development folds are required.')
 for(p in names(x$inputs))if(!file.exists(p)||!identical(digest::digest(file=p,algo='sha256'),x$inputs[[p]]))stop('Mean-selection input identity mismatch: ',p)
 list(family=x$chosen_mean_family,path=path,sha256=digest::digest(file=path,algo='sha256'))
}

remediation_family_controls <- function(family,selection=NULL) {
 sv<-family%in%c('SV','SVseasonal')
 if(sv&&is.null(selection))stop('SV requires a frozen qualified mean selection.')
 mean_family<-if(sv)selection$family else sub('ridge$','',family)
 if(!mean_family%in%c('F1','F2','F2flat'))stop('Unknown selected mean family.')
 list(mean_family=mean_family,
  readout=list(lags=1:90,prior=if(mean_family=='F2')'grouped' else 'flat',cache_size=32L),
  seasonal=if(mean_family!='F1')list(periods=20:120,harmonics=16L) else if(family=='SVseasonal')list(periods=20:120,harmonics=0L) else NULL,
  variance=if(sv)list(type='sv',seasonal=family=='SVseasonal',save_state_paths=TRUE) else NULL,
  beta_prior=if(grepl('ridge$',family))'ridge' else 'rhs')
}

remediation_study_input <- function(root,family,prefix_path='',use_cache=FALSE,selection=NULL) {
 controls<-remediation_family_controls(family,selection)
 prefix<-NULL;cutoff<-2500L
 basepath<-'validation/autodesn/nonlinear_heteroscedastic/artifacts/standardized_bank/bank.rds'
 cache_manifest<-NULL
 if(nzchar(prefix_path)){
  prefix<-jsonlite::fromJSON(prefix_path,simplifyVector=FALSE)
  stopifnot(isTRUE(prefix$complete),identical(prefix$heldout_read,FALSE),identical(prefix$validation_outcomes_read,FALSE),
    prefix$cutoff%in%c(1500L,2000L),prefix$washout==500L,prefix$admitted==426L)
  cutoff<-as.integer(prefix$cutoff)
  for(f in c(prefix$files,prefix$extensions))stopifnot(file.exists(f$path),identical(digest::digest(file=f$path,algo='sha256'),f$sha256))
  basepath<-prefix$files[[which(vapply(prefix$files,function(f)basename(f$path)=='inference_bank.rds',TRUE))]]$path
  base_sha<-digest::digest(file=basepath,algo='sha256')
  cache_manifest<-list(path=basepath,sha256=base_sha,source_bank_sha256=base_sha,extensions=prefix$extensions)
  use_cache<-TRUE
 }else if(use_cache){
  cache_manifest<-jsonlite::fromJSON(file.path(root,'artifacts/inference_cache_manifest.json'))
  stopifnot(identical(digest::digest(file=cache_manifest$path,algo='sha256'),cache_manifest$sha256),
    identical(digest::digest(file=basepath,algo='sha256'),cache_manifest$source_bank_sha256))
 }
 b<-readRDS(if(use_cache)cache_manifest$path else basepath)
 stopifnot(b$n==cutoff-500L,identical(b$keep_idx,seq.int(501L,cutoff)),length(b$history)==cutoff,length(b$models)==426L)
 # The F1 seasonal-variance model has an auxiliary period but zero calendar
 # mean columns. Its extension is therefore intentionally a different object.
 entry<-NULL
 if(use_cache&&!(controls$mean_family=='F1'&&family=='SVseasonal')){
  entry<-cache_manifest$extensions[[controls$mean_family]]
  stopifnot(identical(digest::digest(file=entry$path,algo='sha256'),entry$sha256))
  bank<-b;bank$extension<-readRDS(entry$path);class(bank)<-c('autodesn_extended_bank',class(bank))
  stopifnot(identical(bank$extension$id,entry$bank_id))
 }else bank<-autodesn_extend_bank(b,controls$readout,controls$seasonal)
 list(bank=bank,basepath=basepath,use_cache=use_cache,cache_manifest=cache_manifest,
  entry=entry,cutoff=cutoff,controls=controls,prefix_path=prefix_path,
  prefix_sha256=if(nzchar(prefix_path))digest::digest(file=prefix_path,algo='sha256') else NULL,
  selection=selection)
}

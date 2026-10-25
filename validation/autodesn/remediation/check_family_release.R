args<-commandArgs(TRUE);stopifnot(length(args)==1L,args%in%c('source','installed'))
root<-normalizePath('validation/autodesn/remediation');mode<-args[1]
if(mode=='source'){
 source('validation/autodesn/load_checkout.R')
 Rcpp::sourceCpp('src/autodesn_rhs.cpp',cacheDir=file.path(root,'artifacts/cpp'),showOutput=FALSE)
}else{
 library(exdqlm,lib.loc=file.path(root,'artifacts/family_library'))
 stopifnot(length(tools::checkS3methods('exdqlm',lib.loc=file.path(root,'artifacts/family_library')))==0L)
}
files<-c('test-autodesn-extended.R','test-autodesn-statistics-cache.R','test-autodesn-checkpoint.R','test-autodesn-calendar-cache.R','test-autodesn-variance-only-seasonality.R')
old<-getwd();directory<-NULL
if(mode=='installed'){
 directory<-tempfile('calendar-installed-',tmpdir='/tmp');dir.create(directory)
 stopifnot(all(file.copy(file.path('tests/testthat',files),directory)),file.copy('tests/testthat/fixtures',directory,recursive=TRUE))
 if(nzchar(Sys.which('git'))){g<-suppressWarnings(system2('git',c('-C',shQuote(directory),'rev-parse','--show-toplevel'),stdout=TRUE,stderr=FALSE));stopifnot(!is.null(attr(g,'status')),attr(g,'status')!=0L)}
 setwd(directory)
}
results<-lapply(files,function(n)testthat::test_file(if(mode=='source')file.path('tests/testthat',n) else n,reporter='summary',stop_on_failure=FALSE))
setwd(old);s<-do.call(rbind,lapply(results,as.data.frame))
saveRDS(results,file.path(root,'artifacts',paste0('family_release_',mode,'_results.rds')))
record<-list(complete=TRUE,mode=mode,tests=nrow(s),assertions=sum(s$nb),passed=sum(s$passed),failures=sum(s$failed),errors=sum(s$error),warnings=sum(s$warning),outside_git=mode=='installed',test_source_sha256=as.list(setNames(vapply(file.path('tests/testthat',files),function(p)digest::digest(file=p,algo='sha256'),''),files)),scope='Complete scoped AutoDESN extension, pair/block statistics and recovery regression; not a complete repository check or posterior qualification')
if(mode=='source')record$source_sha256<-as.list(setNames(vapply(.autodesn_source_paths,function(p)digest::digest(file=p,algo='sha256'),''),.autodesn_source_paths)) else record$installed_database_sha256<-digest::digest(file=system.file('R/exdqlm.rdb',package='exdqlm'),algo='sha256')
jsonlite::write_json(record,file.path(root,'evidence',paste0('family_release_',mode,'_tests.json')),pretty=TRUE,auto_unbox=TRUE)
if(!is.null(directory))unlink(directory,recursive=TRUE)
stopifnot(record$failures==0L,record$errors==0L,record$warnings==0L)
cat('FAMILY_RELEASE_TESTS_COMPLETE',mode,'\n')

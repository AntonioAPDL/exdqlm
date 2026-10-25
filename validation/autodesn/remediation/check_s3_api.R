# API compatibility plus the existing numerical/recovery extension suite.
source('validation/autodesn/load_checkout.R')
Rcpp::sourceCpp('src/autodesn_rhs.cpp',cacheDir='validation/autodesn/remediation/artifacts/cpp',showOutput=FALSE)
methods<-c('predict_mu.autodesn_fit','posterior_predict.autodesn_fit','predict_mu.qdesn_normal_fit','posterior_predict.qdesn_normal_fit','predict_mu.qdesn_fit','posterior_predict.qdesn_fit','forecast_paths.qdesn_fit')
for(n in methods){
 stopifnot('...'%in%names(formals(get(n))))
 call<-as.call(c(list(as.name(n),NULL),alist(misspelled=stop('PROMISE_FORCED'))))
 msg<-tryCatch({eval(call);'NO_ERROR'},error=conditionMessage)
 stopifnot(identical(msg,'unused arguments in ...'))
}
files<-c('test-autodesn-extended.R','test-autodesn-statistics-cache.R','test-autodesn-checkpoint.R')
results<-lapply(files,function(n)testthat::test_file(file.path('tests/testthat',n),reporter='summary',stop_on_failure=FALSE))
r<-'validation/autodesn/remediation';saveRDS(results,file.path(r,'artifacts/s3_api_test_results.rds'))
s<-do.call(rbind,lapply(results,as.data.frame))
record<-list(complete=TRUE,methods_checked=methods,unknown_dots_rejected_without_evaluation=TRUE,tests=nrow(s),assertions=sum(s$nb),passed=sum(s$passed),failures=sum(s$failed),errors=sum(s$error),warnings=sum(s$warning),source_sha256=as.list(setNames(vapply(.autodesn_source_paths,function(p)digest::digest(file=p,algo='sha256'),''),.autodesn_source_paths)),scope='Source extension regression and S3 generic compatibility; no package-wide CI or posterior convergence claim')
jsonlite::write_json(record,file.path(r,'evidence/s3_api_tests.json'),pretty=TRUE,auto_unbox=TRUE)
stopifnot(record$failures==0L,record$errors==0L,record$warnings==0L)
cat('S3_API_AND_EXTENDED_TESTS_COMPLETE\n')

source('validation/autodesn/load_checkout.R')
Rcpp::sourceCpp('src/autodesn_rhs.cpp',cacheDir='validation/autodesn/remediation/artifacts/cpp',showOutput=FALSE)
root<-'validation/autodesn/remediation'
result<-testthat::test_file('tests/testthat/test-autodesn-variance-only-seasonality.R',reporter='summary',stop_on_failure=FALSE)
saveRDS(result,file.path(root,'artifacts/variance_only_seasonality_results.rds'))
s<-as.data.frame(result)
record<-list(complete=TRUE,assertions=sum(s$nb),passed=sum(s$passed),failures=sum(s$failed),errors=sum(s$error),warnings=sum(s$warning),source_sha256=digest::digest(file='R/autodesn_extended.R',algo='sha256'),test_sha256=digest::digest(file='tests/testthat/test-autodesn-variance-only-seasonality.R',algo='sha256'),scope='Variance-only seasonal period integration and selected nonseasonal mean, R/C++ agreement; not production convergence or forecast qualification')
jsonlite::write_json(record,file.path(root,'evidence/variance_only_seasonality_tests.json'),pretty=TRUE,auto_unbox=TRUE)
stopifnot(record$failures==0L,record$errors==0L,record$warnings==0L)

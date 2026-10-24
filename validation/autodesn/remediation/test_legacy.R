source('validation/autodesn/load_checkout.R')
Rcpp::sourceCpp('src/autodesn_rhs.cpp',cacheDir='validation/autodesn/remediation/artifacts/cpp',showOutput=FALSE)
r<-testthat::test_dir('tests/testthat',filter='autodesn|qdesn-normal',reporter='summary',stop_on_failure=FALSE,stop_on_warning=FALSE)
saveRDS(r,'validation/autodesn/remediation/artifacts/legacy_test_results.rds')
s<-as.data.frame(r)
jsonlite::write_json(list(complete=TRUE,tests=nrow(s),assertions=sum(s$nb),failed=sum(s$failed),errors=sum(s$error),warnings=sum(s$warning),skips=sum(s$skipped),passed=sum(s$passed)), 'validation/autodesn/remediation/evidence/legacy_tests.json',pretty=TRUE,auto_unbox=TRUE)

stopifnot(sum(s$failed)==0,!any(s$error))

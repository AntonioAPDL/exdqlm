source('validation/autodesn/load_checkout.R')
Rcpp::sourceCpp('src/autodesn_rhs.cpp',cacheDir='validation/autodesn/remediation/artifacts/cpp',showOutput=FALSE)
results<-testthat::test_file('tests/testthat/test-autodesn-calendar-cache.R',reporter='summary',stop_on_failure=FALSE)
s<-as.data.frame(results);r<-'validation/autodesn/remediation'
saveRDS(results,file.path(r,'artifacts/calendar_cache_test_results.rds'))
record<-list(complete=TRUE,tests=nrow(s),assertions=sum(s$nb),passed=sum(s$passed),failures=sum(s$failed),errors=sum(s$error),warnings=sum(s$warning),source_sha256=as.list(setNames(vapply(.autodesn_source_paths,function(p)digest::digest(file=p,algo='sha256'),''),.autodesn_source_paths)),scope='Block algebra against direct Grams/dense Gaussian evidence and fixed-seed ridge/RHS/SV R/C++ paths; not a posterior-convergence claim')
jsonlite::write_json(record,file.path(r,'evidence/calendar_cache_tests.json'),pretty=TRUE,auto_unbox=TRUE)
stopifnot(record$failures==0L,record$errors==0L,record$warnings==0L)
cat('CALENDAR_CACHE_TESTS_COMPLETE\n')

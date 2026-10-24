# Run the installed extension suite with only bundled fixtures, outside Git.
root<-normalizePath('validation/autodesn/remediation');test<-normalizePath('tests/testthat/test-autodesn-extended.R');fixtures<-normalizePath('tests/testthat/fixtures')
library(exdqlm,lib.loc=file.path(root,'artifacts/library'))
stopifnot('kernel_coordinates'%in%names(formals(autodesn_extended_local_proposal)))
directory<-tempfile('autodesn-installed-',tmpdir='/tmp');dir.create(directory)
stopifnot(file.copy(test,file.path(directory,basename(test))),file.copy(fixtures,directory,recursive=TRUE))
outside<-TRUE
if(nzchar(Sys.which('git'))){g<-suppressWarnings(system2('git',c('-C',shQuote(directory),'rev-parse','--show-toplevel'),stdout=TRUE,stderr=FALSE));outside<-!is.null(attr(g,'status'))&&attr(g,'status')!=0L}
stopifnot(outside)
old<-getwd();setwd(directory)
r<-testthat::test_file(basename(test),reporter='summary',stop_on_failure=FALSE)
setwd(old);s<-as.data.frame(r)
saveRDS(r,file.path(root,'artifacts/portable_installed_tests.rds'))
record<-list(complete=TRUE,tests=nrow(s),assertions=sum(s$nb),failed=sum(s$failed),errors=sum(s$error),warnings=sum(s$warning),passed=sum(s$passed),outside_git_working_tree=outside,fixture_sources_manifest_sha256=digest::digest(file=file.path(fixtures,'autodesn_reference_sources.json'),algo='sha256'),test_source_sha256=digest::digest(file=test,algo='sha256'),installed_database_sha256=digest::digest(file=system.file('R/exdqlm.rdb',package='exdqlm'),algo='sha256'),scope='Installed extension tests with bundled frozen references outside Git history; not a package-wide CRAN check')
jsonlite::write_json(record,file.path(root,'evidence/portable_installed_tests.json'),pretty=TRUE,auto_unbox=TRUE);unlink(directory,recursive=TRUE)
stopifnot(record$failed==0L,record$errors==0L,record$warnings==0L);print(record)

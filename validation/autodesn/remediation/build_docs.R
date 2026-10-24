# Generate only extension help files; preserve unrelated repository documentation.
tmp<-tempfile('autodesn-docs-');dir.create(tmp);dir.create(file.path(tmp,'R'))
writeLines(c('Package: exdqlm','Title: AutoDESN Extension Documentation','Version: 1.1.1','Authors@R: person("Antonio", "de Leon", email="none@example.org", role=c("aut","cre"))','Description: Documentation-only build.','License: MIT','Encoding: UTF-8'),file.path(tmp,'DESCRIPTION'))
files<-c('autodesn_extended.R','autodesn_extended_forecast.R','autodesn_extended_proposal.R','autodesn_extended_local.R','autodesn_extended_coefficients.R','autodesn_generics.R')
file.copy(file.path('R',files),file.path(tmp,'R'))
roxygen2::roxygenize(tmp,roclets='rd',load_code=roxygen2::load_source)
docs<-list.files(file.path(tmp,'man'),full.names=TRUE);stopifnot(length(docs)>=10);file.copy(docs,'man',overwrite=TRUE)
cat('Extension Rd files:',length(docs),'\n')

# Regenerate only the affected method pages with the package's Markdown options.
root<-'validation/autodesn/remediation';tmp<-tempfile('s3-documentation-');dir.create(tmp);dir.create(file.path(tmp,'R'))
sources<-c('R/autodesn.R','R/qdesn_normal.R','R/qdesn_vb.R')
stopifnot(file.copy('DESCRIPTION',tmp),all(file.copy(sources,file.path(tmp,'R'))))
roxygen2::roxygenise(tmp,roclets='rd',load_code=roxygen2::load_source)
names<-c('predict_mu.autodesn_fit','posterior_predict.autodesn_fit','predict_mu.qdesn_normal_fit','posterior_predict.qdesn_normal_fit','predict_mu.qdesn_fit','posterior_predict.qdesn_fit','forecast_paths.qdesn_fit')
for(n in names){
 p<-file.path(tmp,'man',paste0(n,'.Rd'));stopifnot(file.exists(p));stopifnot(file.copy(p,file.path('man',basename(p)),overwrite=TRUE))
}
jsonlite::write_json(list(complete=TRUE,roxygen_version=as.character(packageVersion('roxygen2')),pages=names,source_sha256=as.list(setNames(vapply(c('R/autodesn.R','R/qdesn_normal.R','R/qdesn_vb.R'),function(p)digest::digest(file=p,algo='sha256'),''),c('R/autodesn.R','R/qdesn_normal.R','R/qdesn_vb.R')))),file.path(root,'evidence/s3_method_documentation.json'),pretty=TRUE,auto_unbox=TRUE)
unlink(tmp,recursive=TRUE)

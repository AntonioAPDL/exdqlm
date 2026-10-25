# Export only already-saved matching local states; do not reconstruct marginals.
root<-'validation/autodesn/remediation';label<-'production_scale';d<-file.path(root,'artifacts',paste0(label,'_reference'))
stopifnot(isTRUE(jsonlite::fromJSON(file.path(d,'status.json'))$complete))
fixture<-jsonlite::fromJSON(file.path(root,'artifacts',paste0(label,'_reference_fixture.json')),simplifyVector=FALSE)
for(design in fixture$designs)stopifnot(identical(unlist(design$groups)[2:3],c('lag','reservoir')))
for(k in 1:4){
 f<-readRDS(file.path(d,paste0('chain_',k,'.rds')))
 stopifnot(length(f$local)==nrow(f$draws),all(lengths(f$local)>=2L))
 z<-data.frame(iteration=f$draws$iteration,log_local_lag=vapply(f$local,`[`,0,1L),log_local_reservoir_1=vapply(f$local,`[`,0,2L))
 write.csv(z,file.path(d,paste0('locals_',k,'.csv')),row.names=FALSE)
}

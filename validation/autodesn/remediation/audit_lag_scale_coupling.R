# Descriptive proposal-geometry audit of an explicitly unqualified old run.
root<-'validation/autodesn/remediation';d<-file.path(root,'artifacts/F1/production_128000_joint128')
manifest<-jsonlite::fromJSON(file.path(root,'artifacts/inference_cache_manifest.json'))
entry<-manifest$extensions$F1;stopifnot(identical(digest::digest(file=entry$path,algo='sha256'),entry$sha256))
ext<-readRDS(entry$path);stopifnot(identical(ext$lag$active,1:90))
global<-models<-numeric();locals<-slopes<-matrix(numeric(),0L,90L);sources<-list()
qualification<-jsonlite::fromJSON(file.path(d,'qualification.json'));stopifnot(!qualification$screen_passed)
for(k in 1:4){
 p<-file.path(d,paste0('chain_',k,'.rds'));z<-readRDS(p);f<-z$fit
 stopifnot(identical(f$controls$target$bank_id,entry$bank_id),f$controls$rhs_control$tau0==.001,length(f$local)==nrow(f$draws))
 global<-c(global,f$draws$log_global_1);models<-c(models,f$draws$model)
 locals<-rbind(locals,t(vapply(f$local,function(x)x[1:90],numeric(90))))
 slopes<-rbind(slopes,t(vapply(f$beta,function(x)x[2:91],numeric(90))))
 sources[[k]]<-list(path=p,sha256=digest::digest(file=p,algo='sha256'))
 rm(z,f);gc(FALSE)
}
stopifnot(all(is.finite(global)),all(is.finite(locals)),all(is.finite(slopes)))
products<-locals+global+log(.001)
freq<-table(models)/length(models);major<-as.numeric(names(freq)[freq>=.01]);selected<-models%in%major
fraction<-function(x){x<-x[selected];groups<-models[selected];center<-mean(x);means<-tapply(x,groups,mean);weights<-table(groups)/length(groups);sum(weights*(means-center)^2)/mean((x-center)^2)}
rows<-do.call(rbind,lapply(1:90,function(j)data.frame(lag=j,cor_log_local_global=cor(locals[,j],global),
 cor_log_product_global=cor(products[,j],global),sd_global=sd(global),sd_log_local=sd(locals[,j]),sd_log_product=sd(products[,j]),
 median_abs_slope=median(abs(slopes[,j])),between_major_model_fraction_log_product=fraction(products[,j]))))
write.csv(rows,file.path(root,'evidence/lag_scale_coupling.csv'),row.names=FALSE)
jsonlite::write_json(list(complete=TRUE,matching_states=length(global),source_phase='production_128000_joint128',source_target_id=qualification$target_id,
 source_run_qualified=FALSE,source_checkpoints=sources,scope='Descriptive geometry of matching states from an unqualified training-only run. Associations diagnose proposal coupling; they are not certified posterior summaries and do not select or remove architectures.'),file.path(root,'evidence/lag_scale_coupling.json'),pretty=TRUE,auto_unbox=TRUE)
print(rows[order(rows$cor_log_local_global),][1:10,])

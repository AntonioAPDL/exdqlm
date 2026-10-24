# Refresh computational proposal densities from a recorded training-only run.
# Every model/period retains a positive prior proposal component.
source('validation/autodesn/load_checkout.R');args<-commandArgs(TRUE);stopifnot(length(args)==3L,args[1]%in%c('F1','F2','F2flat'),grepl('^[A-Za-z0-9_]+$',args[3]))
root<-'validation/autodesn/remediation';family<-args[1];d<-file.path(root,'artifacts',family,args[2]);config<-jsonlite::fromJSON(file.path(d,'configuration.json'));stopifnot(config$beta_prior=='rhs',!config$test_data_read)
paths<-file.path(d,paste0('chain_',1:4,'.rds'));fits<-lapply(paths,function(path){z<-readRDS(path);st<-jsonlite::fromJSON(sub('[.]rds$','_status.json',path));stopifnot(identical(digest::digest(file=path,algo='sha256'),st$checkpoint_sha256));z$fit})
targets<-vapply(fits,function(f)f$controls$target_id,'');stopifnot(length(unique(targets))==1L)
training<-do.call(rbind,lapply(fits,`[[`,'trace'));M<-nrow(fits[[1]]$model_summary);NP<-nrow(fits[[1]]$period_summary);prior<-fits[[1]]$model_summary$prior_probability;priorP<-fits[[1]]$period_summary$prior
cols<-grep('^log_global_',names(training),value=TRUE);Z<-as.matrix(cbind(log(training$variance),training[cols],training$log_slab));D<-ncol(Z)
C<-cov(Z);C<-.9*C+.1*diag(diag(C))+diag(c(.05,rep(.2,D-1))^2);center<-matrix(rep(colMeans(Z),each=M),M,D)
for(m in seq_len(M)){ids<-which(training$model==m);if(length(ids)>=30L)center[m,]<-colMeans(Z[ids,,drop=FALSE])}
joint<-autodesn_extended_proposal(center,C*3/5*1.2^2,wide_center=colMeans(Z),wide_scale=9*C)
q<-.2*prior+.8*tabulate(training$model,M)/nrow(training);qp<-.2*priorP+.8*tabulate(training$period_index,NP)/nrow(training)
record<-list(bank_id=config$bank_id,joint=joint,model=q,period=qp,frozen_before_production=TRUE,training_only=TRUE,posterior_qualification_claimed=FALSE,source_phase=args[2],source_target_id=targets[1],sources=lapply(paths,function(path)list(path=path,sha256=digest::digest(file=path,algo='sha256'))),prior_fraction=.2)
out<-file.path(root,'artifacts',family,paste0(args[3],'.rds'));stopifnot(!file.exists(out));saveRDS(record,out)
jsonlite::write_json(list(complete=TRUE,path=out,sha256=digest::digest(file=out,algo='sha256'),bank_id=config$bank_id,source_phase=args[2],frozen_before_production=TRUE,training_only=TRUE,prior_fraction=.2,all_model_period_proposals_positive=all(q>0)&&all(qp>0),sources=record$sources,scope='Computational independence proposal, not a replacement posterior or a changed prior'),file.path(root,'evidence',paste0(family,'_',args[3],'.json')),pretty=TRUE,auto_unbox=TRUE)
cat('Frozen scale/model/period proposal:',M,'reservoirs;',NP,'period states\n')

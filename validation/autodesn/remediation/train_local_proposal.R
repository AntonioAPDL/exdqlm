# Computational proposal fitting only; no held-out responses or model screening.
snapshot<-Sys.getenv('AUTODESN_PROPOSAL_SOURCE_SNAPSHOT',unset='.')
if(snapshot=='.')source('validation/autodesn/load_checkout.R') else for(p in list.files(file.path(snapshot,'R'),pattern='[.]R$',full.names=TRUE))source(p,local=.GlobalEnv)
source_paths<-c(list.files(file.path(snapshot,'R'),pattern='[.]R$',full.names=TRUE),file.path(snapshot,'validation/autodesn/remediation/train_local_proposal.R'))
source_sha<-setNames(vapply(source_paths,function(p)digest::digest(file=p,algo='sha256'),''),substring(source_paths,nchar(snapshot)+2L))
args<-commandArgs(TRUE);stopifnot(length(args)%in%c(2L,3L,4L),args[1]%in%c('F1','F2','F2flat'))
family<-args[1];phase<-args[2];root<-'validation/autodesn/remediation';directory<-file.path(root,'artifacts',family,phase)
output_label<-if(length(args)>=3L)args[3] else 'frozen_local_proposal';stopifnot(grepl('^[A-Za-z0-9_]+$',output_label))
limit<-if(length(args)==4L)as.integer(args[4]) else NULL;if(!is.null(limit))stopifnot(is.finite(limit),limit>=1L)
config<-jsonlite::fromJSON(file.path(directory,'configuration.json'));stopifnot(config$beta_prior=='rhs',!config$test_data_read)
paths<-file.path(directory,paste0('chain_',1:4,'.rds'));fits<-lapply(paths,function(path){z<-readRDS(path);st<-jsonlite::fromJSON(sub('[.]rds$','_status.json',path));stopifnot(identical(digest::digest(file=path,algo='sha256'),st$checkpoint_sha256));z$fit})
stopifnot(length(unique(vapply(fits,function(f)f$controls$target_id,'')))==1L)
audit<-read.csv('validation/autodesn/nonlinear_heteroscedastic/artifacts/standardized_bank/feature_audit.csv');M<-nrow(audit);stopifnot(M==426L,identical(audit$model,1:426))
nl<-length(fits[[1]]$reconstruction_bank$readout$lags);if(!nl)nl<-length(fits[[1]]$bank_reference$readout$lags)
stopifnot(nl==90L)
dimensions<-audit$fitted_slopes;centers<-bandwidth<-slopes<-vector('list',M);reference<-numeric(M);weights<-numeric(M);counts<-integer(M)
coordinates<-if(!is.null(limit))rep(list(integer(0)),M) else NULL
global<-if(family=='F1'||family=='F2flat')'log_global_1' else 'log_global_2'
for(m in seq_len(M)){
 values<-list();u<-numeric()
 for(f in fits){ix<-which(f$draws$model==m);if(!length(ix))next;values<-c(values,lapply(f$local[ix],function(x)x[nl+seq_len(dimensions[m])])) ;u<-c(u,f$draws[[global]][ix])}
 counts[m]<-length(u);d<-dimensions[m];centers[[m]]<-matrix(0,0,d);bandwidth[[m]]<-rep(1,d);slopes[[m]]<-numeric(d)
 if(length(u)<24L)next
 L<-do.call(rbind,values);stopifnot(nrow(L)==length(u),ncol(L)==d,all(is.finite(L)))
 reference[m]<-mean(u);vu<-var(u);slope<-if(vu>1e-4)as.vector(crossprod(u-mean(u),sweep(L,2,colMeans(L),'-'))/(length(u)-1)/vu) else numeric(d)
 slope<-pmax(-1,pmin(0,slope));residual<-L-outer(u-reference[m],slope)
 spread<-apply(residual,2,mad);fallback<-apply(residual,2,sd);spread[!is.finite(spread)|spread<.05]<-fallback[!is.finite(spread)|spread<.05]
 bandwidth[[m]]<-pmax(.15,1.2*1.06*spread*length(u)^(-1/5));slopes[[m]]<-slope
 ids<-unique(as.integer(round(seq(1,length(u),length.out=min(64L,length(u))))));centers[[m]]<-residual[ids,,drop=FALSE];weights[m]<-.8
 if(!is.null(limit))coordinates[[m]]<-sort(head(order(abs(apply(residual,2,median)),decreasing=TRUE),min(limit,d)))
}
proposal<-autodesn_extended_local_proposal(centers,bandwidth,slopes,reference,weights,bank_id=config$bank_id,kernel_coordinates=coordinates)
record<-list(proposal=proposal,frozen_before_production=TRUE,training_only=TRUE,posterior_qualification_claimed=FALSE,source_phase=phase,training_counts=counts,sources=lapply(paths,function(path)list(path=path,sha256=digest::digest(file=path,algo='sha256'))),specification=list(kernel='whole-vector prior / product marginal Gaussian KDE mixture',prior_weight=.2,maximum_centers=64L,minimum_training_states=24L,slope_range=c(-1,0),bandwidth_floor=.15))
record$training_source_sha256<-as.list(source_sha);record$R_version<-R.version.string
if(snapshot!='.')record$training_source_snapshot_key<-basename(snapshot)
if(!is.null(limit)){record$specification$maximum_kernel_coordinates<-limit;record$specification$coordinate_rule<-'Largest absolute conditional-reference-global median log-local scale';record$specification$remaining_coordinates<-'Independent proper unit log-half-Cauchy proposal; no likelihood feature removed'}
out<-file.path(root,'artifacts',family,paste0(output_label,'.rds'));stopifnot(!file.exists(out));temporary<-paste0(out,'.writing');saveRDS(record,temporary);stopifnot(identical(readRDS(temporary)$proposal,proposal),file.rename(temporary,out))
jsonlite::write_json(c(record[setdiff(names(record),'proposal')],list(path=out,sha256=digest::digest(file=out,algo='sha256'),bank_id=config$bank_id,models_with_kernel=sum(weights>0),models_using_prior_only=sum(weights==0))),file.path(root,'evidence',paste0(family,'_',output_label,'.json')),pretty=TRUE,auto_unbox=TRUE)
cat('Frozen local proposal:',sum(weights>0),'kernel models;',sum(weights==0),'prior-only models; all',M,'retained\n')

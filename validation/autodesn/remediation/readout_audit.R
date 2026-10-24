# Conditional readout geometry at matching joint posterior checkpoints.
# This is a diagnostic, not variable selection or posterior qualification.
remediation_readout_audit <- function(fit, draw_index = seq_len(nrow(fit$draws)), near_zero_effect = .01) {
 stopifnot(inherits(fit,'autodesn_extended_fit'),length(draw_index)>0,all(draw_index%in%seq_len(nrow(fit$draws))),is.finite(near_zero_effect),near_zero_effect>0)
 b<-fit$bank;rc<-fit$controls$rhs_control;target<-fit$controls$target;family<-target$beta_prior
 G<-if(b$extension$readout$prior=='flat')1L else 2L;tau0<-rep_len(rc$tau0,G)
 response_sd<-sd(b$y);if(!is.finite(response_sd)||response_sd<=0)response_sd<-1
 scalar<-groups<-list();singular<-list()
 for(j in seq_along(draw_index)) {
  k<-draw_index[j];row<-fit$draws[k,];d<-.ext_design(b,row$model,row$period_index);B<-fit$beta[[k]];ell<-numeric(b$extension$dimension);ell[d$slots]<-fit$local[[k]]
  lu<-as.numeric(row[paste0('log_global_',seq_len(G))]);lv<-.ext_logv(d,ell,lu,row$log_slab,tau0,family,row$ridge_precision,target$intercept_variance)
  logd<-rep(log(row$variance),b$n)
  if(fit$controls$variance_control$type=='sv') {
   state<-fit$volatility[[k]];if(length(state$path)!=b$n)stop('Matching saved SV smoothing paths are required for conditional geometry.')
   off<-if(length(state$gamma))as.vector(.ext_sv_w(b,row$period_index)%*%state$gamma) else 0
   logd<-logd+off+row$omega*state$path
  }
  T<-sweep(d$X*exp(-logd/2),2,exp(lv/2),'*');K<-diag(ncol(T))+crossprod(T);U<-chol(K);inverse_chol<-backsolve(U,diag(ncol(T)));contribution<-1-rowSums(inverse_chol^2)
  stopifnot(min(contribution)>-1e-8,max(contribution)<1+1e-8)
  # Independent singular-value identity, also stable when columns are dependent.
  s<-svd(T,nu=0,nv=0)$d;filter<-s^2/(1+s^2);stopifnot(abs(sum(contribution)-sum(filter))<1e-7*max(1,sum(filter)))
  raw_s<-svd(d$X,nu=0,nv=0)$d;rank<-sum(raw_s>max(raw_s)*sqrt(.Machine$double.eps));labels<-c('intercept',d$groups)
  scalar[[j]]<-data.frame(draw=k,model=row$model,period=b$extension$periods[row$period_index],coefficients=length(B),conditional_edf=sum(contribution),design_rank=rank,design_condition=if(rank<ncol(d$X))Inf else max(raw_s)/min(raw_s),response_sd_scaled=response_sd)
  groups[[j]]<-do.call(rbind,lapply(unique(labels),function(group){ids<-which(labels==group);effect<-as.vector(d$X[,ids,drop=FALSE]%*%B[ids]);data.frame(draw=k,group=group,coefficients=length(ids),conditional_edf=sum(contribution[ids]),coefficient_l2=sqrt(sum(B[ids]^2)),fitted_block_rms_scaled=sqrt(mean(effect^2)),fraction_below_declared_effect_threshold=if(group=='intercept')NA_real_ else mean(abs(B[ids])/response_sd<near_zero_effect))}))
  singular[[j]]<-data.frame(draw=k,direction=seq_along(s),prior_whitened_singular_value=s,conditional_smoother_factor=filter)
 }
 list(draws=do.call(rbind,scalar),groups=do.call(rbind,groups),directions=do.call(rbind,singular),near_zero_effect_threshold=near_zero_effect,threshold_units='coefficient effect per one training feature SD divided by training response SD',scope='Conditional linear smoother and group summaries at matching final joint states; continuous RHS has no inclusion atom, and this is not total adaptive-model degrees of freedom',posterior_qualified=FALSE,target_id=fit$controls$target_id)
}

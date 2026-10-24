# Optional exact independence proposal on (architecture, log sigma^2,
# log u, log c^2). Coefficients are integrated out, then immediately redrawn.

#' Frozen joint architecture and scale proposal for AutoDESN-RHS
#'
#' This controls a Metropolis--Hastings proposal, not a prior. Estimate it using
#' training chains only and freeze it before a fresh production chain.
#' @param center Numeric M by 3 matrix, columns log(variance), log(u), log(c^2).
#' @param scale Positive-definite 3 by 3 Student-t scale matrix, or 3 by 3 by M array.
#' @param df Positive Student-t degrees of freedom.
#' @param moves Positive number of additional joint proposals per sweep.
#' @param wide_weight Mixture weight in [0,1] for a common broad Student-t.
#' @param wide_center Length-three center of the broad component.
#' @param wide_scale Positive-definite 3 by 3 scale matrix of the broad component.
#' @return A validated proposal for `model_control$joint_proposal`. Model
#'   probabilities are supplied by `model_control$proposal`; all must be positive.
#' @export
autodesn_rhs_joint_proposal <- function(center,scale,df=5,moves=1L,
    wide_weight=.1,wide_center=c(0,0,0),wide_scale=diag(c(1.5,2,1.5)^2)) {
 if(!is.matrix(center)||!is.numeric(center)||ncol(center)!=3L||nrow(center)<1L||any(!is.finite(center)))
  stop("center must be a finite M by 3 numeric matrix.",call.=FALSE)
 .autodesn_positive(df,"joint proposal df");.autodesn_integer(moves,"joint proposal moves")
 if(length(wide_weight)!=1L||!is.finite(wide_weight)||wide_weight<0||wide_weight>1)
  stop("wide_weight must be in [0,1].",call.=FALSE)
 if(!is.numeric(wide_center)||length(wide_center)!=3L||any(!is.finite(wide_center)))
  stop("wide_center must have three finite values.",call.=FALSE)
 M<-nrow(center)
 if(is.matrix(scale)&&identical(dim(scale),c(3L,3L))) scale<-array(rep(scale,M),c(3L,3L,M))
 if(!is.numeric(scale)||!identical(dim(scale),c(3L,3L,M))||any(!is.finite(scale)))
  stop("scale must be a finite 3 by 3 matrix or 3 by 3 by M array.",call.=FALSE)
 checked_chol<-function(S) {
  if(!is.matrix(S)||!is.numeric(S)||!identical(dim(S),c(3L,3L))||any(!is.finite(S))||max(abs(S-t(S)))>1e-12)
   stop("Joint proposal scale matrices must be finite symmetric 3 by 3 matrices.",call.=FALSE)
  tryCatch(chol(S),error=function(e) stop("Joint proposal scale matrices must be positive definite.",call.=FALSE))
 }
 ch<-array(0,c(3L,3L,M));for(j in seq_len(M)) ch[,,j]<-checked_chol(scale[,,j])
 wc<-checked_chol(wide_scale)
 structure(list(center=unname(center),scale=scale,df=df,moves=as.integer(moves),
  wide_weight=wide_weight,wide_center=as.numeric(wide_center),wide_scale=wide_scale),
  chol=ch,wide_chol=wc,class=c("autodesn_rhs_joint_proposal","list"))
}

.autodesn_rhs_log_mvt <- function(x,center,R,df) {
 z<-forwardsolve(t(R),x-center)
 lgamma((df+3)/2)-lgamma(df/2)-1.5*log(df*pi)-sum(log(diag(R)))-
  .5*(df+3)*log1p(sum(z*z)/df)
}
.autodesn_rhs_joint_logq <- function(x,model,proposal) {
 a<-.autodesn_rhs_log_mvt(x,proposal$center[model,],attr(proposal,"chol")[,,model],proposal$df)
 b<-.autodesn_rhs_log_mvt(x,proposal$wide_center,attr(proposal,"wide_chol"),proposal$df)
 .autodesn_rhs_logadd(log1p(-proposal$wide_weight)+a,log(proposal$wide_weight)+b)
}
.autodesn_rhs_joint_draw <- function(model,proposal) {
 wide<-stats::runif(1)<proposal$wide_weight
 center<-if(wide) proposal$wide_center else proposal$center[model,]
 R<-if(wide) attr(proposal,"wide_chol") else attr(proposal,"chol")[,,model]
 as.numeric(center+t(R)%*%stats::rnorm(3)/sqrt(stats::rchisq(1,proposal$df)/proposal$df))
}
.autodesn_rhs_joint_log_target <- function(log_model_prior,log_evidence,z,a_sigma,b_sigma,slab_df,slab_scale) {
 iglog<-function(s,a,b) a*log(b)-lgamma(a)-a*s-b*exp(-s)
 log_model_prior+log_evidence+iglog(z[1],a_sigma,b_sigma)+
  .autodesn_rhs_log_hc_log(z[2])+iglog(z[3],slab_df/2,slab_df*slab_scale^2/2)
}
.autodesn_rhs_joint_log_ratio <- function(old,proposed,z_old,z_new,loge_old,loge_new,
    prior,model_proposal,proposal,a_sigma,b_sigma,slab_df,slab_scale) {
 .autodesn_rhs_joint_log_target(log(prior[proposed]),loge_new,z_new,a_sigma,b_sigma,slab_df,slab_scale)-
  .autodesn_rhs_joint_log_target(log(prior[old]),loge_old,z_old,a_sigma,b_sigma,slab_df,slab_scale)+
  log(model_proposal[old])+.autodesn_rhs_joint_logq(z_old,old,proposal)-
  log(model_proposal[proposed])-.autodesn_rhs_joint_logq(z_new,proposed,proposal)
}

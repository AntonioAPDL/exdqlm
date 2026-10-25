#' Cache shared Gaussian statistics for period-averaged AutoDESN
#'
#' Store shared lag, reservoir and calendar cross-products in blocks instead of
#' duplicating a complete Gram matrix for every architecture-period pair.
#' Missing blocks are computed on demand, retaining every model and period.
#' This is an optional computational cache for constant-variance Gaussian fits;
#' stochastic-volatility updates still recompute their weighted statistics.
#'
#' @param bank An augmented AutoDESN bank with frozen training geometry.
#' @param max_bytes Maximum numeric matrix/vector payload. List/index overhead
#'   is additional. Oversized blocks are omitted without removing model support.
#' @return The bank with a version-two block statistics cache. The conditional
#'   bank identity and model priors are unchanged. Cache construction uses no
#'   random draws. Reordered floating-point sums may change sampled trajectories;
#'   this cache does not promise bit-identical paths.
#' @seealso [autodesn_cache_statistics()]
#' @export
autodesn_cache_calendar_blocks <- function(bank, max_bytes = 512 * 1024^2) {
  if (!inherits(bank,"autodesn_extended_bank")) stop("Supply an augmented AutoDESN bank.",call.=FALSE)
  .autodesn_positive(max_bytes,"max_bytes")
  bank$extension$statistics_cache <- NULL
  e<-bank$extension;A<-cbind(1,e$lag$X);used<-0
  keep<-function(value){
    bytes<-8*sum(vapply(value,length,0L))
    if(bytes>max_bytes-used)return(NULL)
    used<<-used+bytes;value
  }
  common<-keep(list(XtX=crossprod(A),Xty=as.vector(crossprod(A,bank$y))))
  models<-vector('list',length(bank$models));periods<-vector('list',length(e$calendar))
  for(m in seq_along(models)){
    B<-bank$models[[m]]$X[,-1L,drop=FALSE]
    models[m]<-list(keep(list(XtX=crossprod(B),Xty=as.vector(crossprod(B,bank$y)),AtX=crossprod(A,B))))
  }
  for(p in seq_along(periods)){
    C<-e$calendar[[p]]$X
    periods[p]<-list(keep(list(XtX=crossprod(C),Xty=as.vector(crossprod(C,bank$y)),AtX=crossprod(A,C))))
  }
  interactions<-list()
  for(p in seq_along(periods))for(m in seq_along(models)){
    bytes<-8*bank$models[[m]]$d*ncol(e$calendar[[p]]$X)
    if(bytes>max_bytes-used)next
    value<-keep(list(BtC=crossprod(bank$models[[m]]$X[,-1L,drop=FALSE],e$calendar[[p]]$X)))
    interactions[[paste(m,p,sep=':')]]<-value
  }
  bank$extension$statistics_cache<-list(version=2L,bank_id=e$id,common=common,models=models,periods=periods,interactions=interactions,payload_bytes=used,max_bytes=max_bytes,total_pairs=length(models)*length(periods))
  bank
}

.autodesn_calendar_cached_statistics <- function(cache,A,B,C,y,m,p,column_names) {
  common<-cache$common
  if(is.null(common))common<-list(XtX=crossprod(A),Xty=as.vector(crossprod(A,y)))
  model<-cache$models[[m]]
  if(is.null(model))model<-list(XtX=crossprod(B),Xty=as.vector(crossprod(B,y)),AtX=crossprod(A,B))
  period<-cache$periods[[p]]
  if(is.null(period))period<-list(XtX=crossprod(C),Xty=as.vector(crossprod(C,y)),AtX=crossprod(A,C))
  interaction<-cache$interactions[[paste(m,p,sep=':')]]
  BtC<-if(is.null(interaction))crossprod(B,C) else interaction$BtC
  na<-ncol(A);nb<-ncol(B);nc<-ncol(C);a<-seq_len(na);b<-na+seq_len(nb);c<-na+nb+seq_len(nc)
  G<-matrix(0,na+nb+nc,na+nb+nc,dimnames=if(is.null(column_names))NULL else list(column_names,column_names))
  G[a,a]<-common$XtX;G[b,b]<-model$XtX;G[c,c]<-period$XtX
  G[a,b]<-model$AtX;G[b,a]<-t(model$AtX)
  G[a,c]<-period$AtX;G[c,a]<-t(period$AtX)
  G[b,c]<-BtC;G[c,b]<-t(BtC)
  list(XtX=G,Xty=c(common$Xty,model$Xty,period$Xty))
}

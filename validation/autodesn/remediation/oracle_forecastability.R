# Privileged known-DGP diagnostic. It never fits or changes a candidate model.
nh_oracle_paths<-function(state,origin,innovations,keep_paths=FALSE){
 H<-nrow(innovations);N<-ncol(innovations)
 stopifnot(length(state$lags)==60L,H>=1L,N>=2L,origin>=60L,
  all(is.finite(c(state$lags,state$variance,state$error,innovations))),state$variance>0)
 lag<-matrix(state$lags,60L,N);v<-rep(state$variance,N);error<-rep(state$error,N)
 kept<-if(keep_paths)list(y=matrix(0,H,N),mean=matrix(0,H,N),variance=matrix(0,H,N)) else NULL
 rows<-vector('list',H)
 for(h in seq_len(H)){
  t<-origin+h;v<-nh_variance(t,lag[1,],error,v);mu<-nh_location(lag)
  location<-mu+nh_season(t);center<-mean(location)
  mean_variance<-var(location)
  influence<-v+(location-center)^2*N/(N-1)
  rows[[h]]<-data.frame(origin=origin,horizon=h,paths=N,oracle_mean=center,
   mean_mcse=sd(location)/sqrt(N),predictive_variance=mean(v)+mean_variance,
   variance_mcse=sd(influence)/sqrt(N),expected_innovation_variance=mean(v),
   dynamic_mean_variance=mean_variance)
  error<-sqrt(v)*innovations[h,];x<-mu+error
  if(keep_paths){kept$y[h,]<-x+nh_season(t);kept$mean[h,]<-location;kept$variance[h,]<-v}
  lag<-rbind(x,lag[1:59,,drop=FALSE])
 }
 result<-do.call(rbind,rows);stopifnot(all(is.finite(as.matrix(result))),all(result$predictive_variance>0))
 list(summary=result,paths=kept)
}

nh_oracle_state<-function(prefix){
 stopifnot(nrow(prefix)>=60L,identical(prefix$time,seq_len(nrow(prefix))))
 t<-nrow(prefix);residual<-prefix$y-nh_season(prefix$time)
 list(lags=rev(tail(residual,60)),variance=tail(prefix$conditional_sd,1)^2,
  error=tail(prefix$y-prefix$conditional_mean,1))
}

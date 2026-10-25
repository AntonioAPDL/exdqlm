# Proper marginal scoring after a causal forecast has already been issued.
# Equal outer weights and equal inner counts; no data enters the forecaster here.
remediation_score_forecast<-function(fc,actual){
 Y<-fc$yrep;MU<-fc$mu_draws;SD<-fc$sd_draws
 stopifnot(is.matrix(Y),is.matrix(MU),is.matrix(SD),identical(dim(Y),dim(MU)),identical(dim(Y),dim(SD)),all(is.finite(c(Y,MU,SD,actual))),all(SD>0),length(actual)==nrow(Y),length(fc$outer_draw_index)==ncol(Y))
 outer<-fc$outer_draw_index;groups<-split(seq_len(ncol(Y)),outer);M<-length(groups);K<-lengths(groups)
 stopifnot(M>=2L,length(unique(K))==1L,ncol(Y)==M*K[1L]);K<-K[1L]
 pair_sum<-function(z){z<-sort(z);z<-z-z[1L];sum((2*seq_along(z)-length(z)-1)*z)}
 result<-lapply(seq_len(nrow(Y)),function(h){
  mu<-MU[h,];sd<-SD[h,];x<-Y[h,];y<-actual[h]
  location<-mean(mu);variance<-mean(sd^2+(mu-location)^2)
  lp<-dnorm(y,mu,sd,log=TRUE);top<-max(lp);stopifnot(is.finite(top))
  nll<--(top+log(mean(exp(lp-top))))
  # The whole-vector V statistic contains dependent within-outer pairs.
  # Remove those pairs exactly, using sorted sums in O(N log N), then divide
  # by the number of ordered distinct-outer pairs (including equal K^2 paths).
  second<-(pair_sum(x)-sum(vapply(groups,function(ix)pair_sum(x[ix]),0)))/(M*(M-1)*K^2)
  crps<-mean(abs(x-y))-second
  quantiles<-vapply(c(.05,.25,.5,.75,.95),function(p)uniroot(function(q)mean(pnorm(q,mu,sd))-p,c(min(mu-12*sd),max(mu+12*sd)),tol=1e-10)$root,0)
  data.frame(origin=fc$origin,horizon=h,target=fc$origin+h,actual=y,mean=location,predictive_sd=sqrt(variance),predictive_sample_mean=mean(x),lower90=quantiles[1],lower50=quantiles[2],median=quantiles[3],upper50=quantiles[4],upper90=quantiles[5],squared_error=(location-y)^2,absolute_error=abs(location-y),crps=crps,negative_log_score=nll,covered50=y>=quantiles[2]&&y<=quantiles[4],covered90=y>=quantiles[1]&&y<=quantiles[5],width50=quantiles[4]-quantiles[2],width90=quantiles[5]-quantiles[1],outer_draws=M,inner_paths=K)
 })
 out<-do.call(rbind,result)
 attr(out,'score_policy')<-list(mean='Rao-Blackwellized conditional means',density='conditional Normal mixture; finite-log-Monte-Carlo bias remains',quantiles='conditional Normal mixture CDF',crps='distinct-outer U statistic conditional on independently sampled outer draws from the empirical posterior; within-outer dependence removed; residual MCMC/state-filter error remains',independent_data_replications=FALSE)
 out
}

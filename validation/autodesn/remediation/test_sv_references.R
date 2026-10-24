# Independent small-state references for production SV conditional targets.
source('validation/autodesn/load_checkout.R')
set.seed(5616100);u<-c(.3,-.2,.7,.1,-.4);shape<-c(10,1.5);n<-length(u)
# Dense stationary covariance is independent of the production Markov factorization.
dense<-function(phi) {
 C<-outer(seq_len(n),seq_len(n),function(a,b)phi^abs(a-b));U<-chol(C)
 -.5*(n*log(2*pi)+2*sum(log(diag(U)))+sum(forwardsolve(t(U),u)^2))
}
checks<-list();k<-0L
for(phi in c(-.95,-.5,0,.7,.95)) {
 z<-qlogis((phi+1)/2);expected<-dense(phi)+dbeta((phi+1)/2,shape[1],shape[2],log=TRUE)+log((1-phi^2)/4)
 k<-k+1;checks[[k]]<-data.frame(quantity=paste0('phi_logit_density_',phi),error=abs(.ext_sv_phi_logit_target(z,u,shape)-expected),tolerance=1e-10)
}
raw_phi<-function(phi)exp(dense(phi)+dbeta((phi+1)/2,shape[1],shape[2],log=TRUE))/2
normalizer<-integrate(Vectorize(raw_phi),-1,1,rel.tol=1e-10)$value
transformed<-integrate(Vectorize(function(z)exp(.ext_sv_phi_logit_target(z,u,shape))),-30,30,rel.tol=1e-10)$value
k<-k+1;checks[[k]]<-data.frame(quantity='phi_transformed_integral',error=abs(normalizer-transformed),tolerance=1e-10)
residual<-c(0,.3,-1.2,.1,.5);offset<-c(.1,.2,-.1,0,.1);s2<-.4;sd_prior<-.5
raw_omega<-function(w)exp(sum(dnorm(residual,0,sqrt(s2*exp(offset+w*u)),log=TRUE))+dnorm(w,0,sd_prior,log=TRUE)+log(2))
# Production loglik omits only the constant n*log(2*pi*s2)/2.
constant<--n/2*log(2*pi*s2)
for(w in c(.01,.1,.5,2)) {
 expected<-log(raw_omega(w))-constant+log(w)
 k<-k+1;checks[[k]]<-data.frame(quantity=paste0('omega_log_density_',w),error=abs(.ext_sv_omega_log_target(log(w),u,residual,s2,offset,sd_prior)-expected),tolerance=1e-10)
}
norm_omega<-integrate(Vectorize(raw_omega),0,Inf,rel.tol=1e-10)$value
trans_omega<-integrate(Vectorize(function(z)exp(.ext_sv_omega_log_target(z,u,residual,s2,offset,sd_prior)+constant)),-30,5,rel.tol=1e-10)$value
k<-k+1;checks[[k]]<-data.frame(quantity='omega_transformed_integral',error=abs(norm_omega-trans_omega),tolerance=1e-10)
# Exact zero residual contributes zero quadratic even when exp(-logvariance) overflows.
stopifnot(identical(.ext_sv_loglik(rep(-1000,n),rep(0,n),s2),2500),identical(.ext_sv_omega_log_target(1000,u,residual,s2,offset,sd_prior),-Inf))
for(which in c('phi','omega')) {
 target<-if(which=='phi')function(z).ext_sv_phi_logit_target(z,u,shape) else function(z).ext_sv_omega_log_target(z,u,residual,s2,offset,sd_prior)
 raw<-if(which=='phi')raw_phi else raw_omega;interval<-if(which=='phi')c(-1,1) else c(0,Inf);norm<-if(which=='phi')normalizer else norm_omega
 expected<-sapply(1:2,function(power)integrate(Vectorize(function(x)x^power*raw(x)),interval[1],interval[2],rel.tol=1e-10)$value/norm)
 z<-0;values<-numeric(12000)
 for(i in 1:13000){z<-.autodesn_rhs_slice(z,target,1,30,10000)$value;if(i>1000)values[i-1000]<-if(which=='phi')2*plogis(z)-1 else exp(z)}
 for(power in 1:2) {
  sample<-values^power;mcse<-.autodesn_batch_mcse(list(sample));error<-abs(mean(sample)-expected[power]);k<-k+1
  checks[[k]]<-data.frame(quantity=paste0(which,'_conditional_moment_',power),error=error,tolerance=7*mcse)
 }
}
checks<-do.call(rbind,checks);stopifnot(all(checks$error<checks$tolerance))
write.csv(checks,'validation/autodesn/remediation/evidence/sv_conditional_reference_checks.csv',row.names=FALSE)
jsonlite::write_json(list(complete=TRUE,checks=nrow(checks)+2L,passed=TRUE,scope='Dense stationary covariance, transformed phi/omega normalizers and invariant slice moments conditional on fixed latent states; not full SV posterior qualification'), 'validation/autodesn/remediation/evidence/sv_conditional_references.json',pretty=TRUE,auto_unbox=TRUE)
print(checks)

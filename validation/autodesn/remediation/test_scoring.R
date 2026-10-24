# Independent direct pair enumeration and analytic one-Normal references.
source('validation/autodesn/remediation/score_forecast.R')
x<-c(0,3,1,2,-1,4);actual<-1;outer<-rep(1:3,each=2)
fc<-list(yrep=matrix(x,1),mu_draws=matrix(.3,1,6),sd_draws=matrix(.7,1,6),outer_draw_index=outer,origin=100)
s<-remediation_score_forecast(fc,actual)
cross<-0
for(i in seq_along(x))for(j in seq_along(x))if(outer[i]!=outer[j])cross<-cross+abs(x[i]-x[j])
reference<-mean(abs(x-actual))-.5*cross/(3*2*2^2)
stopifnot(abs(s$crps-reference)<1e-12,abs(s$crps-5/12)<1e-12,abs(s$mean-.3)<1e-12,abs(s$predictive_sd-.7)<1e-12,abs(s$negative_log_score+dnorm(actual,.3,.7,log=TRUE))<1e-12,max(abs(unlist(s[c('lower90','lower50','median','upper50','upper90')])-(.3+.7*qnorm(c(.05,.25,.5,.75,.95)))))<1e-8,s$target==101L)
# Mixture means must be based on conditional means, not an arbitrary innovation.
fc$yrep<-fc$yrep+100
s2<-remediation_score_forecast(fc,actual)
stopifnot(identical(s2$mean,s$mean),identical(s2$negative_log_score,s$negative_log_score),identical(s2$lower90,s$lower90),s2$predictive_sample_mean!=s$predictive_sample_mean)
bad<-fc;bad$outer_draw_index<-rep(1L,6)
stopifnot(inherits(try(remediation_score_forecast(bad,actual),silent=TRUE),'try-error'))
record<-list(complete=TRUE,passed=TRUE,checks=c('distinct_outer_direct_pair_definition','analytic_normal_mean_variance_density_quantiles','target_timestamp','current_innovation_integration','single_cluster_rejected'),scope='Synthetic marginal score identities; no posterior or benchmark forecast issued')
jsonlite::write_json(record,'validation/autodesn/remediation/evidence/scoring_checks.json',pretty=TRUE,auto_unbox=TRUE);print(record)

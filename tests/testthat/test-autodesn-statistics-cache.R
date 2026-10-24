cache_bank <- function() {
 y<-sin(seq_len(12)/2)
 b<-autodesn_prepare_bank(y,list(cbind(y,cos(y)),matrix(y^2,ncol=1)),standardize_features=TRUE,normalize_features=FALSE)
 autodesn_extend_bank(b,seasonal_control=list(periods=c(7,11),harmonics=1))
}
cache_internal <- function(name) get(name,envir=environment(autodesn_fit_bank),inherits=TRUE)

test_that('bounded statistics retain every design and the complete bank identity', {
 b<-cache_bank();s<-autodesn_cache_statistics(b)
 expect_identical(b$extension$id,s$extension$id)
 expect_identical(b$prior,s$prior)
 expect_identical(b$extension$period_prior,s$extension$period_prior)
 expect_equal(length(s$extension$statistics_cache$entries),4L)
 expect_lte(s$extension$statistics_cache$payload_bytes,s$extension$statistics_cache$max_bytes)
 for(m in 1:2)for(p in 1:2) expect_identical(cache_internal('.ext_design')(b,m,p),cache_internal('.ext_design')(s,m,p))
 partial<-autodesn_cache_statistics(b,8*(5^2+5))
 expect_lt(length(partial$extension$statistics_cache$entries),4L)
 for(m in 1:2)for(p in 1:2) expect_identical(cache_internal('.ext_design')(b,m,p),cache_internal('.ext_design')(partial,m,p))
 bad<-s;bad$extension$statistics_cache$bank_id<-'different'
 expect_error(cache_internal('.ext_design')(bad,1,1),'different conditional bank')
 expect_error(autodesn_cache_statistics(b,0),'max_bytes')
})

test_that('cached and uncached Gibbs paths are bit-identical for ridge, RHS and SV', {
 b<-cache_bank();s<-autodesn_cache_statistics(b)
 for(prior in c('ridge','rhs'))for(sv in c(FALSE,TRUE)) {
  args<-list(n_burn=8L,n_mcmc=30L,beta_prior=prior,model_control=list(moves=2L,joint_moves=1L,save_draws=12L),seed=4411,backend='R',variance_control=if(sv)list(type='sv',save_state_paths=TRUE) else NULL)
  x<-do.call(autodesn_fit_bank,c(list(bank=b),args));z<-do.call(autodesn_fit_bank,c(list(bank=s),args))
  expect_identical(x$trace,z$trace);expect_identical(x$draws,z$draws)
  expect_identical(x$beta,z$beta);expect_identical(x$local,z$local)
  expect_identical(x$volatility,z$volatility);expect_identical(x$probes,z$probes)
  expect_identical(x$controls$target_id,z$controls$target_id)
 }
})

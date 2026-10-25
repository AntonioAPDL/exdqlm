# Measure small-target sampler overhead before choosing an optimization.
source('validation/autodesn/load_checkout.R');root<-'validation/autodesn/remediation'
Rcpp::sourceCpp('src/autodesn_rhs.cpp',cacheDir=file.path(root,'artifacts/cpp'),showOutput=FALSE)
x<-seq(-1,1,length.out=8);e<-autodesn_extend_bank(autodesn_prepare_bank(sin(x),list(matrix(x),cbind(x,x*x)),normalize_features=FALSE,standardize_features=TRUE),seasonal_control=list(periods=c(4,11),harmonics=2))
path<-file.path(root,'artifacts/small_trace_profile.out');Rprof(path,interval=.002)
f<-autodesn_fit_bank(e,n_burn=1000,n_mcmc=6000,beta_prior='rhs',rhs_control=list(tau0=.2,interweave_global=TRUE),model_control=list(method='categorical',joint_moves=1,save_draws=128),backend='cpp',seed=2216100)
Rprof(NULL);s<-summaryRprof(path)$by.self;write.csv(s,file.path(root,'evidence/small_trace_profile.csv'));print(head(s,18));cat('Inference elapsed',f$computation$elapsed_seconds,'seconds\n')

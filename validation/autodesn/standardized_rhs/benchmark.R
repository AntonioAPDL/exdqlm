# Computational kernel comparison only: these short chains are not forecasts
# or convergence evidence. Compilation, dependency installation and data setup
# are excluded. Identical seeds couple R and C++ conditional simulations.
library(exdqlm)
out<-"validation/autodesn/standardized_rhs/artifacts/validation"
dir.create(out,recursive=TRUE,showWarnings=FALSE)
set.seed(7301);n<-200L;p<-64L
H<-matrix(rnorm(n*p),n,p);H[,2]<-H[,1]+1e-5*H[,2]
y<-.6*H[,1]+.15*H[,3]+rnorm(n,sd=.4)
bank<-autodesn_prepare_bank(y,lapply(c(4L,12L,32L,64L),function(k) H[,seq_len(k),drop=FALSE]),
 standardize_features=TRUE,normalize_features=FALSE)
fit<-function(backend,seed,draws) autodesn_fit_bank(bank,beta_prior="rhs",backend=backend,
 rhs_control=list(tau0=.001,slab_scale=1,slab_df=4,interweave_global=TRUE),
 model_control=list(method="mh",moves=4L),n_burn=100L,n_mcmc=draws,seed=seed)
invisible(fit("R",7302L,2L));invisible(fit("cpp",7302L,2L))
rows<-list();parity<-list()
for(k in 1:3) {
 pair<-list()
 for(backend in c("R","cpp")) {
  gc(FALSE);t<-proc.time()[3];f<-fit(backend,7310L+k,800L);seconds<-unname(proc.time()[3]-t)
  pair[[backend]]<-f
  rows[[length(rows)+1L]]<-data.frame(replication=k,backend=backend,n=n,max_slopes=p,
   architectures=4L,burn=100L,retained=800L,elapsed_seconds=seconds)
 }
 error<-max(abs(as.matrix(pair$R$draws)-as.matrix(pair$cpp$draws)),
  abs(unlist(pair$R$beta)-unlist(pair$cpp$beta)))
 parity[[k]]<-data.frame(replication=k,max_paired_draw_error=error,
  identical_model_path=identical(pair$R$draws$model,pair$cpp$draws$model))
 stopifnot(error<1e-7,parity[[k]]$identical_model_path)
}
write.csv(do.call(rbind,rows),file.path(out,"standardized_backend_benchmark.csv"),row.names=FALSE)
write.csv(do.call(rbind,parity),file.path(out,"standardized_backend_parity.csv"),row.names=FALSE)
writeLines(c("Short computational benchmark, not posterior-convergence evidence.",
 "Column-standardized synthetic designs; setup and compile costs excluded.",capture.output(sessionInfo())),file.path(out,"standardized_backend_session.txt"))
print(do.call(rbind,rows));print(do.call(rbind,parity))

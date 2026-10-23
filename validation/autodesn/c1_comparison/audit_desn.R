# Independent export for cross-language auditing; no fitting or forecast changes.
source("validation/autodesn/c1_comparison/helpers.R")
out <- file.path(c1_root,"artifacts/desn")
cp <- readRDS(file.path(out,"posterior_checkpoint.rds"))
for(origin in c(2500L,2735L,2970L)) {
  fc <- readRDS(file.path(out,paste0("forecast_",origin,".rds")))
  H <- nrow(fc$yrep);N <- ncol(fc$yrep)
  con <- gzfile(file.path(out,paste0("forecast_samples_",origin,".csv.gz")),"wt")
  write.csv(data.frame(horizon=rep(seq_len(H),N),path=rep(seq_len(N),each=H),
    mu=as.vector(fc$mu_draws),sd=as.vector(fc$sd_draws),yrep=as.vector(fc$yrep)),con,row.names=FALSE)
  close(con)
}
spectral <- do.call(rbind,lapply(seq_along(cp$bank$templates),function(j) {
  t <- cp$bank$templates[[j]]
  x <- t$reservoir$spectral_diagnostics;x$model <- j;x$candidate <- cp$model_summary$candidate[j]
  x
}))
write.csv(spectral,file.path(out,"spectral_audit.csv"),row.names=FALSE)
prior <- aggregate(prior_probability~D,cp$model_summary,sum)
stopifnot(max(abs(prior$prior_probability-1/nrow(prior)))<1e-12,
  hh_qualify(cp$diagnostics),identical(cp$bank$keep_idx,501:2500))
c1_json(list(complete=TRUE,depth_prior_balanced=TRUE,convergence_screens_passed=TRUE,
  snapshot_origins=c(2500,2735,2970)),file.path(out,"independent_export.json"))

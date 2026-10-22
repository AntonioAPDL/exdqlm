source("validation/autodesn/load_checkout.R")
root <- "validation/autodesn/heteroscedastic/rolling"
out <- Sys.getenv("AUTODESN_ROLLING_OUT",file.path(root,"artifacts"))
dir.create(out,recursive=TRUE,showWarnings=FALSE)
if(file.exists(file.path(out,"configuration.R"))) stop("Frozen rolling output already exists")
cfg <- list(schema="autodesn_rolling_no_refit_500_2000_h30_v1",washout=500L,
  n_train=2000L,initial_origin=2500L,origins=2500:2570,H=30L,
  outer_draws=192L,inner_paths=16L,sensitivity_inner=c(8L,16L,32L),
  origin_workers=2L,case_workers=2L,refit_per_origin=FALSE,
  preprocessing_updates=FALSE,posterior_model_weight_updates=FALSE,
  teacher_forced_between_origins=TRUE,recursive_within_origin=TRUE,
  future_observations_within_origin=FALSE,
  inference="Exact replay of the final diagnostic-selected sampler duration/seeds from the recorded fixed-origin study; no new model selection/tuning on the test period.",
  design_history="Rolling H=30 requested after the original fixed-origin run. DGPs, candidate bank, priors and fit window unchanged.",
  protocol="docs/implementation_notes/independent_qdesn_corrected_forecast_v3_20260930.md",
  source_revision_at_launch=system2("/usr/bin/git",c("rev-parse","HEAD"),stdout=TRUE))
dput(cfg,file.path(out,"configuration.R"))
cases <- read.csv("validation/autodesn/heteroscedastic/artifacts/audit.csv")[,c("dgp","repetition","dgp_seed")]
write.csv(cases,file.path(out,"cases.csv"),row.names=FALSE)
files <- c(list.files("R",pattern="\\.R$",full.names=TRUE),
  "validation/autodesn/load_checkout.R","validation/autodesn/long_horizon/helpers.R",
  "validation/autodesn/heteroscedastic/dgp.R","validation/autodesn/heteroscedastic/forecasting.R",
  list.files(root,pattern="\\.R$",full.names=TRUE))
write.csv(data.frame(path=files,md5=unname(tools::md5sum(files))),file.path(out,"launch_source_manifest.csv"),row.names=FALSE)
cat("Frozen rolling protocol: 71 origins, 30 leads, 3072 DESN paths per origin; no refitting.\n")

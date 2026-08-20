qdesn_cgcv2_repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)

source(file.path(
  qdesn_cgcv2_repo_root, "validation", "fitforecast_v2", "R",
  "qdesn_forecast_gap_adaptive_mcmc_v1.R"
))

qdesn_cgcv2_stage <-
  "qdesn_dynamic_fitforecast_v2_500obs_canonical_gap_mcmc_v2"
qdesn_cgcv2_schema <- "qdesn_canonical_gap_mcmc_v2_job_v1"
qdesn_cgcv2_method_id <- qdesn_ssv2_method_id
qdesn_cgcv2_branch <- "validation/qdesn-canonical-gap-mcmc-v2-1.0.0"
qdesn_cgcv2_target_metrics <- c(
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
  "forecast_check_loss_H1000"
)

# The inherited helpers resolve result paths through this global stage name.
qdesn_fgav1_stage <- qdesn_cgcv2_stage

qdesn_cgcv2_budget <- function(stage) {
  switch(stage,
    smoke = list(n_burn = 4L, n_mcmc = 4L, draws = 4L),
    calibration = list(n_burn = 300L, n_mcmc = 700L, draws = 40L),
    screen = list(n_burn = 1000L, n_mcmc = 4000L, draws = 120L),
    refine = list(n_burn = 2500L, n_mcmc = 7500L, draws = 160L),
    confirmation = list(n_burn = 5000L, n_mcmc = 20000L, draws = 200L),
    stop(sprintf("Unknown canonical-gap stage: %s", stage), call. = FALSE)
  )
}

qdesn_cgcv2_timeout_seconds <- function(stage) {
  switch(stage,
    smoke = 1800L,
    calibration = 21600L,
    screen = 172800L,
    refine = 259200L,
    confirmation = 604800L,
    stop(sprintf("Unknown canonical-gap stage: %s", stage), call. = FALSE)
  )
}

qdesn_cgcv2_effective_dimension <- function(profile) {
  qdesn_ssv2_effective_readout_dimension(
    profile$n[[1L]], profile$n_tilde[[1L]],
    profile$reservoir_lags[[1L]], profile$readout_y_lags[[1L]]
  )
}

qdesn_cgcv2_make_job <- function(repo_root, profile, target, source, stage,
                                  source_registry_path, chain_id,
                                  reservoir_seed_id) {
  old_budget <- qdesn_fgav1_budget
  old_timeout <- qdesn_fgav1_timeout_seconds
  on.exit({
    assign("qdesn_fgav1_budget", old_budget, envir = .GlobalEnv)
    assign("qdesn_fgav1_timeout_seconds", old_timeout, envir = .GlobalEnv)
  }, add = TRUE)
  assign("qdesn_fgav1_budget", qdesn_cgcv2_budget, envir = .GlobalEnv)
  assign("qdesn_fgav1_timeout_seconds", qdesn_cgcv2_timeout_seconds,
         envir = .GlobalEnv)
  job <- qdesn_fgav1_make_job(
    repo_root, profile, target, source, stage, source_registry_path,
    chain_id = chain_id, reservoir_seed_id = reservoir_seed_id
  )
  job$schema_version <- qdesn_cgcv2_schema
  job$spec_id <- paste0("canonical_gap_mcmc_v2__", job$job_id)
  job$config$validation_spec_id <- job$spec_id
  job$config$outputs$retention_profile <-
    "storage_light_canonical_gap_mcmc_v2"
  job$root_spec$screening_stage <- qdesn_cgcv2_stage
  job$study_contract$validation_stage <- qdesn_cgcv2_stage
  job$study_contract$authority_interface <-
    "qdesn_dqlm_500obs_trainonly_article_v8_forecast_gap_adaptive_20260819"
  job$study_contract$canonical_data_screening <- TRUE
  job$study_contract$diagnostics_are_promotion_veto <- FALSE
  job$study_contract$promotion_requires_strict_metric_gain <- TRUE
  job$study_contract$global_specification_required <- FALSE
  job
}

qdesn_cgcv2_job_root <- function(repo_root, run_tag, job_id) {
  qdesn_ssv2_path(
    repo_root, "results", "qdesn_mcmc_validation", qdesn_cgcv2_stage,
    run_tag, "jobs", job_id
  )
}

qdesn_cgcv2_seed <- function(...) {
  key <- paste(..., sep = "|")
  hex <- substr(digest::digest(key, algo = "sha256", serialize = FALSE), 1L, 7L)
  as.integer(strtoi(hex, base = 16L)) %% 900000000L + 10000000L
}

qdesn_cgcv2_apply_seeds <- function(job) {
  key <- paste(job$stage, job$candidate_id, job$chain_id,
               job$reservoir_seed_id, sep = "|")
  job$config$desn$seed <- qdesn_cgcv2_seed(key, "desn")
  job$config$inference$mcmc$control$seed <- qdesn_cgcv2_seed(key, "mcmc")
  job$config$inference$mcmc$control$rng_seed <- qdesn_cgcv2_seed(key, "rng")
  job$config$inference$mcmc$vb_warm_start_seed <-
    qdesn_cgcv2_seed(key, "vb")
  job$root_spec$desn_seed <- job$config$desn$seed
  job$root_spec$mcmc_seed <- job$config$inference$mcmc$control$seed
  job$root_spec$mcmc_rng_seed <- job$config$inference$mcmc$control$rng_seed
  job$root_spec$vb_warm_start_seed <-
    job$config$inference$mcmc$vb_warm_start_seed
  job
}

qdesn_cgcv2_metric_values <- qdesn_fgav1_metric_values

qdesn_cgcv2_signature <- function(x) {
  fields <- c("D", "n", "n_tilde", "m", "alpha", "rho", "pi_w", "pi_in",
              "rhs_tau0", "readout_y_lags", "reservoir_lags", "washout")
  paste(vapply(fields, function(field) as.character(x[[field]][[1L]]),
               character(1L)), collapse = "|")
}

qdesn_cgcv2_stage_canonical_window <- function(root, m, washout, output_root) {
  series <- qdesn_ssv2_read_csv(root$series_wide_path[[1L]])
  all_idx <- 8111:10000
  if (nrow(series) != length(all_idx)) stop("Canonical series must cover 8111:10000.")
  raw_start <- 8501L - as.integer(m) - as.integer(washout)
  keep <- all_idx >= raw_start; x <- series[keep,,drop=FALSE]; idx <- all_idx[keep]
  x$source_index <- idx; x$t <- seq_len(nrow(x))
  dir <- file.path(output_root, root$family[[1L]], sprintf("tau_%s",sub("[.]","p",sprintf("%.2f",root$tau[[1L]]))),sprintf("m%d_w%d",m,washout))
  dir.create(dir,recursive=TRUE,showWarnings=FALSE)
  series_path<-qdesn_ssv2_write_csv(x,file.path(dir,"series_wide.csv"))
  selection_path<-qdesn_ssv2_write_csv(data.frame(t=seq_len(nrow(x)),source_index=idx),file.path(dir,"selection_indices.csv"))
  phase1<-2*pi*idx/90;phase2<-4*pi*idx/90;trend<-(idx-mean(idx))/stats::sd(idx)
  observed_path<-qdesn_ssv2_write_csv(data.frame(y=x$y,period90_sin_h1=sin(phase1),period90_cos_h1=cos(phase1),period90_sin_h2=sin(phase2),period90_cos_h2=cos(phase2),period90_trend_z=trend),file.path(dir,"observed.csv"))
  qtrue_path<-qdesn_ssv2_write_csv(data.frame(t=seq_len(nrow(x)),source_index=idx,q_true=x$q_target,y=x$y,mu=x$mu),file.path(dir,"q_true.csv"))
  data.frame(source_id="canonical_article",source_role="canonical_confirmation",scenario=root$scenario,family=root$family,tau=root$tau,m=as.integer(m),washout=as.integer(washout),raw_start_source_index=raw_start,raw_end_source_index=10000L,train_start_source_index=8501L,train_end_source_index=9000L,forecast_start_source_index=9001L,forecast_end_source_index=10000L,source_total_size=nrow(x),source_series_wide_path=series_path,source_series_wide_sha256=qdesn_ssv2_sha256(series_path),source_selection_indices_path=selection_path,source_selection_indices_sha256=qdesn_ssv2_sha256(selection_path),source_sim_path=root$sim_output_path,source_sim_sha256=root$sim_output_sha256,source_latent_seed=NA_integer_,source_noise_seed=NA_integer_,observed_path=observed_path,observed_sha256=qdesn_ssv2_sha256(observed_path),qtrue_path=qtrue_path,qtrue_sha256=qdesn_ssv2_sha256(qtrue_path),stringsAsFactors=FALSE)
}

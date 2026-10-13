#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
repo <- normalizePath(args[1]); root <- args[2]
setwd(repo)
Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1")
suppressPackageStartupMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
source("validation/fitforecast_v2/R/independent_qdesn_coupled_design_v7.R")
iqdr_v7_source(repo)
dir.create(root, recursive = TRUE, showWarnings = FALSE)
t <- 8111:10000
mu <- .5 * sin(t / 10) + .2 * cos(t / 31)
source_rows <- data.frame(t = t, y = mu + .2 * sin(t * 13), mu = mu, q_target = mu, eps = .2 * sin(t * 13))
source_path <- iqfr_v2_write_csv(source_rows, file.path(root, "synthetic_source.csv"))
records <- list()
for (family in c("al", "exal")) {
  cfg <- list(schema_version = iqdr_v7_schema, stage = "synthetic_smoke", repo_root = repo,
    source = list(frozen_path = source_path, frozen_sha256 = iqfr_v2_sha256(source_path)),
    probability = .25, likelihood_family = family, rhs_s2 = 1,
    fit_end = 8520L, rollout_end = 8533L, origins = list(start = 8520L, end = 8530L, stride = 10L),
    horizon = 3L, outer_draws = 4L, inner_path_grid = 4L, include_mean_readout_state = FALSE,
    seed = 9912L, budget = list(max_iter = 3L, tol = 0, n_samp_xi = 16L),
    candidate = list(family = "normal", candidate_id = paste0("synthetic_", family),
      structure_id = "synthetic", representation_role = "synthetic", D = 1L, n = "4", n_tilde = "",
      m = 2L, alpha = .5, rho = .6, center_scale = "mean_sd", input_bound = "none",
      input_gain = .1, recurrent_indegree = 2L, input_fanin = 2L, interlayer_fanin = 2L,
      matrix_seed = 920001L, rhs_tau0 = .01, rhs_tau0_source_scale = .01,
      tau0_reference = .01, tau0_reference_source_scale = .01,
      tau0_multiplier = 1, tau_arm = "synthetic"))
  original_path <- file.path(root, paste0("reference_", family, ".json"))
  cfg$config_path <- original_path
  iqfr_v2_write_json(cfg, original_path)
  initializer <- file.path(root, paste0("initializer_", family, ".json"))
  iqct_v6_prepare_initializer(cfg, initializer)
  for (multiplier in c(1, 3.5)) {
    job <- cfg
    job$job_id <- paste("smoke", family, multiplier, sep = "__")
    job$run_root <- root
    job$baseline_config_sha256 <- iqfr_v2_sha256(original_path)
    job$frozen_initializer_path <- initializer
    job$frozen_initializer_sha256 <- iqfr_v2_sha256(initializer)
    job$beta_covariance_approximation <- "full"
    job$collect_solver_diagnostics <- TRUE
    job$candidate$rhs_tau0 <- cfg$candidate$rhs_tau0 * multiplier
    job$candidate$rhs_tau0_source_scale <- cfg$candidate$rhs_tau0_source_scale * multiplier
    job$config_path <- file.path(root, "configs", paste0(job$job_id, ".json"))
    job$status_path <- file.path(root, "status", paste0(job$job_id, ".json"))
    suffixes <- c(result_path = ".csv", metric_draw_path = "__metric_draws.csv.gz",
      origin_lead_path = "__origin_lead.csv.gz", lead_profile_path = "__lead_profile.csv",
      origin_profile_path = "__origin_profile.csv", origin_block_path = "__origin_blocks.csv")
    for (k in names(suffixes)) job[[k]] <- file.path(root, "results", paste0(job$job_id, suffixes[[k]]))
    iqfr_v2_write_json(job, job$config_path)
    iqdr_v7_run_measured(job)
    valid <- iqcb_v4_status_valid(job$config_path, job$status_path)
    initial <- iqfr_v2_read_json(file.path(root, "fit_diagnostics", job$job_id, "initialization.json"))
    timing <- iqfr_v2_read_json(file.path(root, "timing", job$job_id, "worker_timing.json"))
    records[[length(records) + 1L]] <- data.frame(likelihood = family, multiplier = multiplier,
      pass = valid && isTRUE(initial$fresh_RHS_state) && !initial$beta_state_transferred &&
        timing$quantile_seconds > 0 && timing$forecast_and_artifact_seconds > 0,
      initializer_digest = initial$initialization_digest)
  }
}
x <- do.call(rbind, records)
stopifnot(all(x$pass), all(vapply(split(x$initializer_digest, x$likelihood), function(z) length(unique(z)) == 1L, TRUE)))
iqfr_v2_write_csv(x, file.path(root, "smoke_summary.csv"))
print(x)

#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
repo <- normalizePath(args[1]); root <- args[2]
setwd(repo)
Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1")
suppressPackageStartupMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
source("validation/fitforecast_v2/R/independent_qdesn_mcmc_bridge_v9.R")
iqmb_v9_source(repo)
dir.create(root, recursive = TRUE, showWarnings = FALSE)
t <- 8111:10000; mu <- .5 * sin(t/10) + .2 * cos(t/31)
path <- iqfr_v2_write_csv(data.frame(t = t, y = mu + .2*sin(13*t), mu = mu,
  q_target = mu, eps = .2*sin(13*t)), file.path(root, "source.csv"))
records <- list()
for (family in c("al", "exal")) {
  ref <- list(schema_version = iqmb_v9_schema, stage = "synthetic_smoke", repo_root = repo,
    source = list(frozen_path = path, frozen_sha256 = iqfr_v2_sha256(path)),
    probability = .25, likelihood_family = family, rhs_s2 = 1,
    fit_end = 8520L, rollout_end = 8533L, origins = list(start = 8520L, end = 8530L, stride = 10L),
    horizon = 3L, outer_draws = 4L, inner_path_grid = 4L, include_mean_readout_state = FALSE,
    seed = 19912L, chain_seed = 111111L, mcmc_burn = 5L, mcmc_retained = 12L,
    budget = list(max_iter = 3L, tol = 0, n_samp_xi = 16L),
    candidate = list(family = "normal", candidate_id = paste0("smoke_", family),
      structure_id = "smoke", representation_role = "smoke", D = 1L, n = "4", n_tilde = "",
      m = 2L, alpha = .5, rho = .6, center_scale = "mean_sd", input_bound = "none",
      input_gain = .1, recurrent_indegree = 2L, input_fanin = 2L, interlayer_fanin = 2L,
      matrix_seed = 920001L, rhs_tau0 = .01, rhs_tau0_source_scale = .01,
      tau0_reference = .01, tau0_reference_source_scale = .01, tau0_multiplier = 1, tau_arm = "smoke"))
  ref$config_path <- file.path(root, paste0("reference_", family, ".json"))
  iqfr_v2_write_json(ref, ref$config_path)
  initializer <- file.path(root, paste0("initializer_", family, ".json"))
  iqct_v6_prepare_initializer(ref, initializer)
  prior <- NULL
  for (index in 1:3) {
    cfg <- ref; cfg$run_root <- root; cfg$reference_config_path <- ref$config_path
    cfg$job_id <- paste("smoke", family, index, sep = "__"); cfg$pair_role <- "smoke"; cfg$chain_index <- 1L
    cfg$case_id <- paste0("synthetic_", family)
    if (index == 3L) cfg$chain_seed <- cfg$chain_seed + 1L
    cfg$baseline_config_sha256 <- iqfr_v2_sha256(ref$config_path)
    cfg$frozen_initializer_path <- initializer; cfg$frozen_initializer_sha256 <- iqfr_v2_sha256(initializer)
    cfg$beta_covariance_approximation <- "full"; cfg$collect_solver_diagnostics <- TRUE
    cfg$config_path <- file.path(root, "configs", paste0(cfg$job_id, ".json"))
    cfg$status_path <- file.path(root, "status", paste0(cfg$job_id, ".json"))
    for (k in c("result_path", "metric_draw_path", "origin_lead_path", "lead_profile_path", "origin_profile_path"))
      cfg[[k]] <- file.path(root, "results", paste0(cfg$job_id, "__", k, ".csv"))
    iqfr_v2_write_json(cfg, cfg$config_path)
    iqmb_v9_compute(cfg, verify_warm = FALSE)
    current <- iqfr_v2_read_json(cfg$status_path)
    params <- read.csv(current$artifact_paths$parameter_draws)
    scores <- read.csv(cfg$result_path)
    same <- is.null(prior) || if (index == 2L) {
      identical(params, prior$params) && identical(scores, prior$scores)
    } else !identical(params, prior$params)
    diag <- iqfr_v2_read_json(current$artifact_paths$mcmc_diagnostics)
    stopifnot(same, diag$control$rng_seed == cfg$chain_seed)
    records[[length(records) + 1L]] <- data.frame(likelihood = family, repeat_index = index,
      pass = iqmb_v9_status_valid(cfg$config_path) && same)
    if (index == 1L) prior <- list(params = params, scores = scores)
  }
}
x <- do.call(rbind, records)
stopifnot(nrow(x) == 6L, all(x$pass))
iqfr_v2_write_csv(x, file.path(root, "smoke_summary.csv"))
print(x)

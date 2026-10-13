#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
index <- match("--run-root", args)
if (is.na(index) || index == length(args)) {
  stop("Usage: --run-root RUN_ROOT", call. = FALSE)
}
run_root <- normalizePath(args[[index + 1L]], winslash = "/", mustWork = TRUE)
repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
Sys.setenv(
  OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1", NUMEXPR_NUM_THREADS = "1",
  RCPP_PARALLEL_NUM_THREADS = "1"
)
suppressPackageStartupMessages(pkgload::load_all(repo_root, quiet = TRUE))
for (path in c(
  "independent_qdesn_full_redesign_v2.R",
  "independent_qdesn_full_redesign_v2_runtime.R",
  "independent_qdesn_representation_screen_v1.R",
  "independent_qdesn_representation_screen_v1_runtime.R",
  "independent_qdesn_cellwise_refinement_v2.R"
)) source(file.path(repo_root, "validation", "fitforecast_v2", "R", path))

protocol <- iqcr_v2_read_protocol(repo_root)
checks <- iqcr_v2_assert_protocol(protocol)
authorities <- iqcr_v2_assert_authorities(repo_root, protocol)
if (!identical(as.character(utils::packageVersion("exdqlm")), "1.1.1")) {
  stop("Preflight requires exdqlm 1.1.1.", call. = FALSE)
}
sigmagam <- exal_make_vb_sigmagam_control()
if (!identical(sigmagam$factorization, "structured") ||
    !identical(as.integer(sigmagam$structured_grid_size), 151L)) {
  stop("Structured exAL LDVB default is unavailable.", call. = FALSE)
}
if (!grepl("m0_v_collapsed_support_logit",
           paste(deparse(body(exal_mcmc_fit)), collapse = "\n"),
           fixed = TRUE)) {
  stop("Exact exAL M0 transition is unavailable.", call. = FALSE)
}

sources <- utils::read.csv(
  file.path(run_root, "source_manifest.csv"), check.names = FALSE,
  stringsAsFactors = FALSE
)
if (nrow(sources) != 9L || any(vapply(
  sources$frozen_path, iqfr_v2_sha256, character(1L)
) != sources$frozen_sha256)) {
  stop("Frozen source preflight failed.", call. = FALSE)
}
structures <- utils::read.csv(
  file.path(run_root, "manifests", "structure_catalog.csv"),
  check.names = FALSE, stringsAsFactors = FALSE
)
counts <- table(structures$family)
if (nrow(structures) != 220L ||
    !identical(as.integer(counts[iqcr_v2_families]), c(80L, 60L, 80L)) ||
    sum(structures$generation == "family_targeted_v2_new") != 80L ||
    max(structures$m) != 360L || max(structures$D) != 5L ||
    max(structures$total_states) > 2400L ||
    any(structures$matrix_seed != 920001L)) {
  stop("Targeted candidate-bank preflight failed.", call. = FALSE)
}

source <- sources[sources$family == "normal" &
                    abs(sources$tau - 0.50) < 1e-12, , drop = FALSE]
x <- iqfr_v2_source_rows(source$frozen_path[[1L]])
if (min(x$t) != 8111L || 8501L - min(x$t) != 390L) {
  stop("The frozen source-prefix contract has drifted.", call. = FALSE)
}
candidate <- structures[
  structures$generation == "family_targeted_v2_new" & structures$D == 5L,
  , drop = FALSE
][1L, , drop = FALSE]
candidate$n <- "20;20;20;20;20"
candidate$n_tilde <- "20;20;20;20"
candidate$total_states <- 100L
candidate$readout_dimension <- 101L
candidate$m <- 360L
candidate$input_fanin_fraction <- 0.05
candidate$input_fanin <- 18L
candidate$recurrent_indegree <- 5L
candidate$interlayer_fanin <- 5L
candidate$rhs_tau0 <- 0.1
candidate$tau0_base <- 0.1
candidate$tau0_mode <- "preflight"
candidate$tau_arm <- iqfr_v2_tau_arm_label(0.1)
candidate$candidate_signature <- paste(iqcr_v2_schema, "preflight", sep = "|")
candidate$candidate_id <- "iqcr2_preflight"
fit_rows <- x$t >= 8501L & x$t <= 8750L
preprocess <- iqfr_v2_training_preprocess(
  x$y[fit_rows], candidate$center_scale
)
design <- do.call(qdesn_fit_normal, iqfr_v2_design_args(
  y = x$y[x$t <= 8780L], candidate = candidate, preprocess = preprocess,
  p0 = 0.5, fit_readout = FALSE
))
iqfr_v2_assert_design(design, candidate, 280L)
if (!all(design$reservoir$Q_is_identity) ||
    !identical(iqfr_v2_unpack_integer(candidate$n_tilde),
               rep(20L, 4L))) {
  stop("D5/m360 exact identity-Q preflight failed.", call. = FALSE)
}
X_fit <- design$X[seq_len(250L), , drop = FALSE]
y_fit <- design$y_fit[seq_len(250L)]
ridge <- normal_desn_fit(
  X_fit, y_fit, beta_prior_type = "scaled_ridge",
  prior = list(beta_ridge_tau2 = 0.1, intercept_var = 1e6)
)
rhs <- normal_desn_fit(
  X_fit, y_fit, beta_prior_type = "rhs_ns",
  rhs = list(tau0 = 0.1, s2 = 1, shrink_intercept = FALSE, n_inner = 2L),
  control = list(max_iter = 5L, min_iter = 2L, tol = 1e-3,
                 covariance = "woodbury_diagonal")
)
if (any(!is.finite(ridge$beta$mean)) || any(!is.finite(rhs$beta$mean))) {
  stop("Normal ridge/RHS canary failed.", call. = FALSE)
}

tmp <- file.path(run_root, "preflight_tmp")
unlink(tmp, recursive = TRUE, force = TRUE)
dir.create(tmp, recursive = TRUE)
on.exit(unlink(tmp, recursive = TRUE, force = TRUE), add = TRUE)
for (part in c("configs", "results/mcmc", "status/mcmc")) {
  dir.create(file.path(tmp, part), recursive = TRUE, showWarnings = FALSE)
}
mcmc_modes <- c(al = "sigma_then_gamma",
                exal = "m0_v_collapsed_support_logit")
mcmc_rows <- lapply(names(mcmc_modes), function(likelihood) {
  job_id <- paste0("preflight_", likelihood)
  smoke_candidate <- candidate
  smoke_candidate$m <- 15L
  smoke_candidate$input_fanin <- 5L
  config <- list(
    schema_version = iqcr_v2_schema, protocol_id = protocol$protocol$id,
    stage = "mcmc_pilot", job_id = job_id, repo_root = repo_root,
    run_root = tmp, source = as.list(source),
    candidate = as.list(smoke_candidate), likelihood_family = likelihood,
    tau = 0.50, chain_id = 1L,
    seed = iqfr_v2_seed(iqcr_v2_schema, job_id),
    budget = list(burn = 3L, sample = 8L, draws = 4L),
    forecast_contract = list(
      source_offset = 8110L, train_end = 8750L, rollout_end = 8780L,
      origin_start = 8750L, origin_end = 8750L, origin_stride = 1L,
      horizon = 30L, estimators = "posterior_predictive_mean_readout_state",
      export_origin_lead = FALSE
    ),
    result_path = file.path(tmp, "results", "mcmc", paste0(job_id, ".csv")),
    status_path = file.path(tmp, "status", "mcmc", paste0(job_id, ".json"))
  )
  path <- file.path(tmp, "configs", paste0(job_id, ".json"))
  iqfr_v2_write_json(config, path)
  result <- iqfr_v2_mcmc_job(path)
  metric_draws <- utils::read.csv(
    gzfile(result$metric_draw_path[[1L]]), check.names = FALSE,
    stringsAsFactors = FALSE
  )
  gamma_contract <- if (likelihood == "al") {
    all(is.finite(metric_draws$gamma)) &&
      all(abs(metric_draws$gamma) <= 1e-12)
  } else {
    all(is.finite(metric_draws$gamma)) &&
      all(metric_draws$gamma > -1 & metric_draws$gamma < 1)
  }
  if (nrow(result) != 1L ||
      !identical(result$core_update_mode[[1L]], mcmc_modes[[likelihood]]) ||
      !file.exists(result$metric_draw_path[[1L]]) || !gamma_contract) {
    stop("MCMC preflight failed for ", likelihood, call. = FALSE)
  }
  data.frame(
    likelihood_family = likelihood,
    core_update_mode = result$core_update_mode[[1L]],
    gamma_contract_pass = gamma_contract,
    stringsAsFactors = FALSE
  )
})

report <- list(
  schema_version = iqcr_v2_schema, status = "PREFLIGHT_PASS",
  completed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  git_branch = system2("git", c("-C", repo_root, "branch", "--show-current"),
                       stdout = TRUE),
  git_head = system2("git", c("-C", repo_root, "rev-parse", "HEAD"),
                     stdout = TRUE),
  package_version = as.character(utils::packageVersion("exdqlm")),
  source_package_version = as.character(read.dcf(
    file.path(repo_root, "DESCRIPTION"), fields = "Version"
  )[[1L]]),
  protocol_checks = checks, authority_hashes_pass = all(authorities$hash_pass),
  source_hashes_pass = TRUE, candidate_count = nrow(structures),
  novel_candidate_count = sum(
    structures$generation == "family_targeted_v2_new"
  ),
  maximum_total_states = max(structures$total_states),
  maximum_lag = max(structures$m), maximum_depth = max(structures$D),
  source_prefix_length = 390L, exact_identity_projection = TRUE,
  ridge_canary = all(is.finite(ridge$beta$mean)),
  rhs_canary = all(is.finite(rhs$beta$mean)),
  mcmc_canaries = do.call(rbind, mcmc_rows), fitted_model_binaries = 0L
)
report_path <- file.path(run_root, "manifests", "preflight_report.json")
iqfr_v2_write_json(report, report_path)
cat(sprintf("PREFLIGHT_PASS report=%s\n", report_path))

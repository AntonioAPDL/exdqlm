#!/usr/bin/env Rscript

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

parse_cli <- function(args) {
  out <- list()
  ii <- 1L
  while (ii <= length(args)) {
    key <- args[[ii]]
    if (!startsWith(key, "--")) {
      stop(sprintf("Unexpected positional argument: %s", key), call. = FALSE)
    }
    key <- sub("^--", "", key)
    value <- "true"
    if (ii < length(args) && !startsWith(args[[ii + 1L]], "--")) {
      value <- args[[ii + 1L]]
      ii <- ii + 1L
    }
    out[[key]] <- value
    ii <- ii + 1L
  }
  out
}

as_flag <- function(x, default = FALSE) {
  if (is.null(x)) return(default)
  x <- tolower(trimws(as.character(x)[1L]))
  if (x %in% c("true", "t", "1", "yes", "y")) return(TRUE)
  if (x %in% c("false", "f", "0", "no", "n")) return(FALSE)
  stop(sprintf("Cannot parse logical flag: %s", x), call. = FALSE)
}

git_value <- function(repo_root, ...) {
  value <- tryCatch(
    system2("git", c("-C", repo_root, ...), stdout = TRUE, stderr = TRUE),
    error = function(e) character(0)
  )
  paste(value, collapse = "\n")
}

write_csv <- function(x, path) {
  utils::write.csv(x, file = path, row.names = FALSE, na = "")
}

interval_metrics <- function(scenario_id, backend, y, pred, coverage_level,
                             learning_rate, elapsed_sec) {
  lower <- as.numeric(pred$lower_mean)
  upper <- as.numeric(pred$upper_mean)
  midpoint <- as.numeric(pred$midpoint_mean)
  width <- upper - lower
  miss_alpha <- 1 - coverage_level
  score <- width +
    (2 / miss_alpha) * pmax(lower - y, 0) +
    (2 / miss_alpha) * pmax(y - upper, 0)
  data.frame(
    scenario_id = scenario_id,
    backend = backend,
    coverage_level = coverage_level,
    learning_rate = learning_rate,
    n_eval = length(y),
    empirical_coverage = mean(y >= lower & y <= upper),
    mean_width = mean(width),
    interval_score_mean = mean(score),
    midpoint_mae = mean(abs(midpoint - y)),
    finite_lower = all(is.finite(lower)),
    finite_upper = all(is.finite(upper)),
    ordered_intervals = all(upper >= lower),
    runtime_sec = as.numeric(elapsed_sec),
    stringsAsFactors = FALSE
  )
}

mcmc_diagnostics <- function(scenario_id, backend, fit) {
  core <- if (inherits(fit, "rqr_desn_fit")) fit$fit else fit
  if (!inherits(core, "rqr_mcmc")) return(NULL)
  loss <- as.numeric(core$diagnostics$loss_trace %||% numeric(0))
  finite_loss <- loss[is.finite(loss)]
  data.frame(
    scenario_id = scenario_id,
    backend = backend,
    n_draws = nrow(core$samp.beta_root1),
    n_design_cols = ncol(core$X),
    beta_prior = as.character(core$beta_prior$type %||% NA_character_),
    loss_first = finite_loss[1L] %||% NA_real_,
    loss_last = finite_loss[length(finite_loss)] %||% NA_real_,
    root1_precision_strategies = paste(sort(unique(core$diagnostics$precision_strategy_root1)), collapse = ";"),
    root2_precision_strategies = paste(sort(unique(core$diagnostics$precision_strategy_root2)), collapse = ";"),
    response_likelihood = isTRUE(core$model_spec$response_likelihood),
    generalized_bayes = isTRUE(core$model_spec$generalized_bayes),
    stringsAsFactors = FALSE
  )
}

vb_diagnostics <- function(scenario_id, backend, fit) {
  core <- if (inherits(fit, "rqr_desn_fit")) fit$fit else fit
  if (!inherits(core, "rqr_vb")) return(NULL)
  objective <- as.numeric(core$diagnostics$objective_trace %||% numeric(0))
  delta <- as.numeric(core$diagnostics$delta_trace %||% numeric(0))
  data.frame(
    scenario_id = scenario_id,
    backend = backend,
    n_draws = nrow(core$draws$beta_root1),
    n_design_cols = ncol(core$X),
    converged = isTRUE(core$diagnostics$converged),
    objective_last = objective[length(objective)] %||% NA_real_,
    delta_last = delta[length(delta)] %||% NA_real_,
    calibrated_uncertainty = isTRUE(core$model_spec$calibrated_uncertainty),
    response_likelihood = isTRUE(core$model_spec$response_likelihood),
    generalized_bayes = isTRUE(core$model_spec$generalized_bayes),
    stringsAsFactors = FALSE
  )
}

run_timed <- function(expr) {
  start <- proc.time()[["elapsed"]]
  value <- force(expr)
  elapsed <- proc.time()[["elapsed"]] - start
  list(value = value, elapsed = elapsed)
}

scenario_record <- function(scenario_id, backend, inference, design_type,
                            coverage_level, learning_rate, n_train, n_eval,
                            prior, purpose) {
  data.frame(
    scenario_id = scenario_id,
    backend = backend,
    inference = inference,
    design_type = design_type,
    coverage_level = coverage_level,
    learning_rate = learning_rate,
    n_train = n_train,
    n_eval = n_eval,
    prior = prior,
    purpose = purpose,
    stringsAsFactors = FALSE
  )
}

args <- parse_cli(commandArgs(trailingOnly = TRUE))
repo_root <- args[["repo-root"]] %||% git_value(getwd(), "rev-parse", "--show-toplevel")
if (!nzchar(repo_root)) repo_root <- getwd()
repo_root <- normalizePath(repo_root, mustWork = TRUE)

short_sha <- substr(git_value(repo_root, "rev-parse", "HEAD"), 1L, 12L)
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
default_output_dir <- file.path(
  repo_root,
  "reports",
  "rqr_desn_pre_simulation_readiness",
  sprintf("rqr_desn_readiness_%s_git_%s", stamp, short_sha)
)
output_dir <- args[["output-dir"]] %||% default_output_dir
output_dir <- normalizePath(output_dir, mustWork = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

install_package <- as_flag(args[["install-package"]], default = FALSE)
lib_path <- args[["lib-path"]] %||% NULL
if (isTRUE(install_package)) {
  lib_path <- lib_path %||% file.path(tempdir(), sprintf("exdqlm-rqr-readiness-lib-%s", stamp))
  dir.create(lib_path, recursive = TRUE, showWarnings = FALSE)
  status <- system2(
    file.path(R.home("bin"), "R"),
    c("CMD", "INSTALL", sprintf("--library=%s", lib_path), "--no-multiarch", "--with-keep.source", repo_root)
  )
  if (!identical(status, 0L)) {
    stop("Package installation failed; aborting readiness harness.", call. = FALSE)
  }
}
if (!is.null(lib_path)) {
  .libPaths(c(normalizePath(lib_path, mustWork = TRUE), .libPaths()))
}
suppressPackageStartupMessages(library(exdqlm))

set.seed(8816001)
scenario_manifest <- list()
fit_summary <- list()
metrics <- list()
mcmc_diag <- list()
vb_diag <- list()

add_result <- function(index, scenario_id, backend, fit, X_eval, y_eval,
                       coverage_level, learning_rate, elapsed_sec,
                       inference, design_type, n_train, prior, purpose,
                       nd = NULL, seed = NULL) {
  pred <- exdqlm::predict_interval(fit, X_new = X_eval, nd = nd, seed = seed)
  scenario_manifest[[index]] <<- scenario_record(
    scenario_id = scenario_id,
    backend = backend,
    inference = inference,
    design_type = design_type,
    coverage_level = coverage_level,
    learning_rate = learning_rate,
    n_train = n_train,
    n_eval = length(y_eval),
    prior = prior,
    purpose = purpose
  )
  metrics[[index]] <<- interval_metrics(
    scenario_id = scenario_id,
    backend = backend,
    y = y_eval,
    pred = pred,
    coverage_level = coverage_level,
    learning_rate = learning_rate,
    elapsed_sec = elapsed_sec
  )
  core <- if (inherits(fit, "rqr_desn_fit")) fit$fit else fit
  fit_summary[[index]] <<- data.frame(
    scenario_id = scenario_id,
    backend = backend,
    method = as.character(core$method %||% NA_character_),
    family = as.character(core$family %||% NA_character_),
    n_design_rows = nrow(core$X),
    n_design_cols = ncol(core$X),
    lower_mean_avg = mean(core$summary$lower_mean),
    upper_mean_avg = mean(core$summary$upper_mean),
    width_mean_avg = mean(core$summary$width_mean),
    response_likelihood = isTRUE(core$model_spec$response_likelihood),
    generalized_bayes = isTRUE(core$model_spec$generalized_bayes),
    stringsAsFactors = FALSE
  )
  mcmc_diag[[index]] <<- mcmc_diagnostics(scenario_id, backend, fit)
  vb_diag[[index]] <<- vb_diagnostics(scenario_id, backend, fit)
  invisible(pred)
}

y1 <- sort(rnorm(20, mean = 0.1, sd = 0.5))
X1 <- matrix(1, nrow = length(y1), ncol = 1, dimnames = list(NULL, "(Intercept)"))
timed <- run_timed(exdqlm::rqr_mcmc_fit(
  y = y1,
  X = X1,
  coverage_level = 0.8,
  learning_rate = 1,
  beta_prior_obj = exdqlm::beta_prior("ridge", ridge = list(tau2 = 10)),
  mcmc_control = list(n_burn = 40, n_mcmc = 60, thin = 1, seed = 8816002)
))
add_result(1L, "intercept_normal_mcmc", "rqr_fixed_design_mcmc", timed$value, X1, y1,
           0.8, 1, timed$elapsed, "mcmc", "intercept_only", length(y1),
           "ridge_tau2_10", "intercept smoke with symmetric data")

y2 <- as.numeric(rexp(22, rate = 1.4) - 0.6)
X2 <- matrix(1, nrow = length(y2), ncol = 1, dimnames = list(NULL, "(Intercept)"))
timed <- run_timed(exdqlm::rqr_mcmc_fit(
  y = y2,
  X = X2,
  coverage_level = 0.8,
  learning_rate = 1.2,
  beta_prior_obj = exdqlm::beta_prior("ridge", ridge = list(tau2 = 12)),
  mcmc_control = list(n_burn = 40, n_mcmc = 60, thin = 1, seed = 8816003)
))
add_result(2L, "intercept_asymmetric_mcmc", "rqr_fixed_design_mcmc", timed$value, X2, y2,
           0.8, 1.2, timed$elapsed, "mcmc", "intercept_only", length(y2),
           "ridge_tau2_12", "intercept smoke with asymmetric data")

x3 <- seq(-1, 1, length.out = 24)
X3 <- cbind("(Intercept)" = 1, x = x3)
y3 <- as.numeric(0.15 + 0.45 * x3 + 0.18 * rnorm(length(x3)))
timed <- run_timed(exdqlm::rqr_mcmc_fit(
  y = y3,
  X = X3,
  coverage_level = 0.75,
  learning_rate = 0.8,
  beta_prior_obj = exdqlm::beta_prior("ridge", ridge = list(tau2 = 8)),
  mcmc_control = list(n_burn = 45, n_mcmc = 65, thin = 1, seed = 8816004)
))
add_result(3L, "linear_fixed_design_mcmc", "rqr_fixed_design_mcmc", timed$value, X3, y3,
           0.75, 0.8, timed$elapsed, "mcmc", "linear_fixed_design", length(y3),
           "ridge_tau2_8", "linear fixed-design readout smoke")

timed <- run_timed(exdqlm::rqr_vb_fit(
  y = y3,
  X = X3,
  coverage_level = 0.75,
  learning_rate = 0.8,
  beta_prior_obj = exdqlm::beta_prior("ridge", ridge = list(tau2 = 8)),
  vb_control = list(max_iter = 40, tol = 1e-5, n_draws = 80, seed = 8816005)
))
add_result(4L, "linear_fixed_design_vb_sidecar", "rqr_fixed_design_vb", timed$value, X3, y3,
           0.75, 0.8, timed$elapsed, "vb", "linear_fixed_design", length(y3),
           "ridge_tau2_8", "VB sidecar smoke; not calibrated uncertainty")

x4 <- seq(-1, 1, length.out = 18)
X4 <- cbind("(Intercept)" = 1, x = x4)
y4 <- as.numeric(-0.05 + 0.25 * x4 + 0.12 * rnorm(length(x4)))
rhs_prior <- exdqlm::beta_prior("rhs_ns", rhs = list(
  tau0 = 0.5,
  a_zeta = 2,
  b_zeta = 1,
  s2 = 1,
  n_inner = 1L
))
timed <- run_timed(exdqlm::rqr_mcmc_fit(
  y = y4,
  X = X4,
  coverage_level = 0.8,
  learning_rate = 1,
  beta_prior_obj = rhs_prior,
  mcmc_control = list(n_burn = 30, n_mcmc = 40, thin = 1, seed = 8816006)
))
add_result(5L, "rhs_ns_fixed_design_mcmc", "rqr_fixed_design_mcmc", timed$value, X4, y4,
           0.8, 1, timed$elapsed, "mcmc", "linear_fixed_design", length(y4),
           "rhs_ns_tiny", "RHS_NS prior smoke for sparse readouts")

y5 <- as.numeric(sin(seq_len(38) / 5) + 0.08 * rnorm(38))
timed <- run_timed(exdqlm::rqr_desn_fit(
  y = y5,
  coverage_level = 0.8,
  D = 1L,
  n = 6L,
  m = 3L,
  alpha = 0.25,
  rho = 0.8,
  act_f = "tanh",
  act_k = "identity",
  pi_w = 0.3,
  pi_in = 1.0,
  washout = 4L,
  add_bias = TRUE,
  seed = 8816007,
  inference = "mcmc",
  learning_rate = 1,
  mcmc_args = list(n_burn = 25, n_mcmc = 35, thin = 1, seed = 8816008)
))
add_result(6L, "tiny_desn_shell_mcmc", "rqr_desn_mcmc", timed$value, timed$value$X,
           timed$value$y_fit, 0.8, 1, timed$elapsed, "mcmc", "tiny_desn_shell",
           length(timed$value$y_fit), "ridge_default", "DESN shell/readout integration smoke",
           nd = 30, seed = 8816009)

scenario_manifest_df <- do.call(rbind, scenario_manifest)
fit_summary_df <- do.call(rbind, fit_summary)
metrics_df <- do.call(rbind, metrics)
mcmc_diag_df <- do.call(rbind, Filter(Negate(is.null), mcmc_diag))
vb_diag_df <- do.call(rbind, Filter(Negate(is.null), vb_diag))

manifest_df <- data.frame(
  key = c(
    "artifact_kind",
    "interpretation",
    "repo_root",
    "git_commit",
    "git_branch",
    "output_dir",
    "scenario_count",
    "created_at",
    "r_version",
    "install_package"
  ),
  value = c(
    "rqr_desn_pre_simulation_readiness",
    "tiny deterministic readiness smoke; not a broad simulation or performance claim",
    repo_root,
    git_value(repo_root, "rev-parse", "HEAD"),
    git_value(repo_root, "branch", "--show-current"),
    output_dir,
    as.character(nrow(scenario_manifest_df)),
    format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    paste(R.version$major, R.version$minor, sep = "."),
    as.character(install_package)
  ),
  stringsAsFactors = FALSE
)

write_csv(manifest_df, file.path(output_dir, "manifest.csv"))
write_csv(scenario_manifest_df, file.path(output_dir, "scenario_manifest.csv"))
write_csv(fit_summary_df, file.path(output_dir, "fit_summary.csv"))
write_csv(metrics_df, file.path(output_dir, "interval_metrics.csv"))
write_csv(mcmc_diag_df, file.path(output_dir, "mcmc_diagnostics.csv"))
write_csv(vb_diag_df, file.path(output_dir, "vb_diagnostics.csv"))

readme_lines <- c(
  "# RQR-DESN Pre-Simulation Readiness",
  "",
  "This directory is produced by `scripts/rqr_desn_pre_simulation_readiness.R`.",
  "It is a deterministic plumbing and contract smoke run, not a broad simulation study.",
  "",
  "The fitted objects are generalized-Bayes interval readouts. The outputs report interval",
  "summaries and diagnostics; they do not create response predictive samples and do not",
  "claim calibrated VB uncertainty.",
  "",
  "Primary files:",
  "- `manifest.csv`: provenance and interpretation contract.",
  "- `scenario_manifest.csv`: tiny scenario design.",
  "- `interval_metrics.csv`: empirical interval summaries on tiny in-sample/evaluation sets.",
  "- `mcmc_diagnostics.csv`: sampler-side diagnostics for MCMC scenarios.",
  "- `vb_diagnostics.csv`: approximation diagnostics for the VB sidecar.",
  "- `output_hashes.csv`: md5 hashes for reproducibility bookkeeping."
)
writeLines(readme_lines, file.path(output_dir, "README.md"))
writeLines(capture.output(sessionInfo()), file.path(output_dir, "session_info.txt"))
writeLines(
  c(
    "$ git status --short --branch",
    git_value(repo_root, "status", "--short", "--branch"),
    "",
    "$ git log --oneline -5",
    git_value(repo_root, "log", "--oneline", "-5")
  ),
  file.path(output_dir, "git_state.txt")
)

artifact_files <- list.files(output_dir, full.names = TRUE)
artifact_files <- artifact_files[basename(artifact_files) != "output_hashes.csv"]
hash_df <- data.frame(
  file = basename(artifact_files),
  md5 = unname(tools::md5sum(artifact_files)),
  stringsAsFactors = FALSE
)
write_csv(hash_df, file.path(output_dir, "output_hashes.csv"))

stopifnot(all(metrics_df$finite_lower), all(metrics_df$finite_upper), all(metrics_df$ordered_intervals))
message(sprintf("RQR-DESN readiness harness wrote %d scenarios to %s", nrow(scenario_manifest_df), output_dir))

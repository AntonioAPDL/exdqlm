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

as_int <- function(x, default) {
  if (is.null(x)) return(default)
  out <- as.integer(x[1L])
  if (!is.finite(out)) stop(sprintf("Expected integer, got: %s", x[1L]), call. = FALSE)
  out
}

as_num_vec <- function(x, default) {
  if (is.null(x)) return(default)
  out <- as.numeric(strsplit(as.character(x)[1L], ",", fixed = TRUE)[[1L]])
  if (any(!is.finite(out))) stop(sprintf("Expected numeric comma list, got: %s", x[1L]), call. = FALSE)
  out
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

interval_score <- function(y, lower, upper, coverage_level) {
  miss_alpha <- 1 - coverage_level
  (upper - lower) +
    (2 / miss_alpha) * pmax(lower - y, 0) +
    (2 / miss_alpha) * pmax(y - upper, 0)
}

metric_row <- function(scenario_id, scenario_family, replicate_id, backend,
                       inference, prior_type, coverage_level, learning_rate,
                       y, lower, upper, midpoint = NULL,
                       oracle_lower = NULL, oracle_upper = NULL,
                       runtime_sec = NA_real_) {
  y <- as.numeric(y)
  lower <- as.numeric(lower)
  upper <- as.numeric(upper)
  midpoint <- midpoint %||% (0.5 * (lower + upper))
  finite_lower <- all(is.finite(lower))
  finite_upper <- all(is.finite(upper))
  ordered <- all(upper >= lower)
  width <- upper - lower
  score <- interval_score(y, lower, upper, coverage_level)
  endpoint_mae <- NA_real_
  if (!is.null(oracle_lower) && !is.null(oracle_upper)) {
    endpoint_mae <- mean(abs(lower - oracle_lower) + abs(upper - oracle_upper)) / 2
  }
  data.frame(
    scenario_id = scenario_id,
    scenario_family = scenario_family,
    replicate_id = replicate_id,
    backend = backend,
    inference = inference,
    prior_type = prior_type,
    coverage_level = coverage_level,
    learning_rate = learning_rate,
    n_eval = length(y),
    empirical_coverage = mean(y >= lower & y <= upper),
    mean_width = mean(width),
    interval_score_mean = mean(score),
    midpoint_mae = mean(abs(as.numeric(midpoint) - y)),
    endpoint_mae = endpoint_mae,
    finite_lower = finite_lower,
    finite_upper = finite_upper,
    ordered_intervals = ordered,
    positive_mean_width = is.finite(mean(width)) && mean(width) > 0,
    runtime_sec = as.numeric(runtime_sec),
    stringsAsFactors = FALSE
  )
}

scenario_row <- function(scenario_id, scenario_family, replicate_id,
                         design_type, backend, inference, prior_type,
                         coverage_level, learning_rate, n_train, n_test,
                         seed, note) {
  data.frame(
    scenario_id = scenario_id,
    scenario_family = scenario_family,
    replicate_id = replicate_id,
    design_type = design_type,
    backend = backend,
    inference = inference,
    prior_type = prior_type,
    coverage_level = coverage_level,
    learning_rate = learning_rate,
    n_train = n_train,
    n_test = n_test,
    seed = seed,
    note = note,
    stringsAsFactors = FALSE
  )
}

fit_summary_row <- function(scenario_id, scenario_family, replicate_id, backend,
                            inference, prior_type, fit, runtime_sec) {
  core <- if (inherits(fit, "rqr_desn_fit")) fit$fit else fit
  data.frame(
    scenario_id = scenario_id,
    scenario_family = scenario_family,
    replicate_id = replicate_id,
    backend = backend,
    inference = inference,
    prior_type = prior_type,
    method = as.character(core$method %||% NA_character_),
    family = as.character(core$family %||% NA_character_),
    n_design_rows = nrow(core$X),
    n_design_cols = ncol(core$X),
    beta_prior = as.character(core$beta_prior$type %||% NA_character_),
    response_likelihood = isTRUE(core$model_spec$response_likelihood),
    generalized_bayes = isTRUE(core$model_spec$generalized_bayes),
    runtime_sec = as.numeric(runtime_sec),
    stringsAsFactors = FALSE
  )
}

failure_row <- function(scenario_id, scenario_family, replicate_id, backend,
                        inference, prior_type, coverage_level, learning_rate,
                        message) {
  data.frame(
    scenario_id = scenario_id,
    scenario_family = scenario_family,
    replicate_id = replicate_id,
    backend = backend,
    inference = inference,
    prior_type = prior_type,
    coverage_level = coverage_level,
    learning_rate = learning_rate,
    message = as.character(message),
    stringsAsFactors = FALSE
  )
}

run_timed <- function(expr) {
  start <- proc.time()[["elapsed"]]
  value <- force(expr)
  elapsed <- proc.time()[["elapsed"]] - start
  list(value = value, elapsed = elapsed)
}

make_fixed_design <- function(family, seed, n_train = 48L, n_test = 24L) {
  set.seed(seed)
  n <- n_train + n_test
  x <- seq(-1, 1, length.out = n)
  if (identical(family, "symmetric_linear")) {
    sigma <- 0.35
    mu <- 0.15 + 0.5 * x
    y <- mu + sigma * rnorm(n)
    oracle <- function(coverage_level) {
      q <- stats::qnorm((1 + coverage_level) / 2)
      list(lower = mu[(n_train + 1L):n] - q * sigma,
           upper = mu[(n_train + 1L):n] + q * sigma)
    }
  } else if (identical(family, "skewed_linear")) {
    scale <- 0.30
    mu <- -0.05 + 0.35 * x
    noise <- scale * (stats::rexp(n, rate = 1) - 1)
    y <- mu + noise
    oracle <- function(coverage_level) {
      lo_p <- (1 - coverage_level) / 2
      hi_p <- 1 - lo_p
      list(lower = mu[(n_train + 1L):n] + scale * (stats::qexp(lo_p, rate = 1) - 1),
           upper = mu[(n_train + 1L):n] + scale * (stats::qexp(hi_p, rate = 1) - 1))
    }
  } else {
    stop(sprintf("Unknown fixed-design family: %s", family), call. = FALSE)
  }
  X <- cbind("(Intercept)" = 1, x = x)
  list(
    X_train = X[seq_len(n_train), , drop = FALSE],
    y_train = y[seq_len(n_train)],
    X_test = X[(n_train + 1L):n, , drop = FALSE],
    y_test = y[(n_train + 1L):n],
    oracle = oracle
  )
}

make_desn_design <- function(seed, n_total = 86L, n_train = 50L, n_test = 24L) {
  set.seed(seed)
  y <- numeric(n_total)
  y[1L] <- rnorm(1, sd = 0.2)
  for (tt in 2:n_total) {
    y[tt] <- 0.55 * y[tt - 1L] + 0.45 * sin(tt / 5) + 0.12 * rnorm(1)
  }
  shell <- exdqlm::qdesn_fit_vb(
    y = y,
    p0 = 0.5,
    fit_readout = FALSE,
    vb_args = list(),
    D = 1L,
    n = 8L,
    m = 3L,
    alpha = 0.25,
    rho = 0.8,
    act_f = "tanh",
    act_k = "identity",
    pi_w = 0.3,
    pi_in = 1.0,
    washout = n_total - (n_train + n_test),
    add_bias = TRUE,
    seed = seed + 17L
  )
  if (nrow(shell$X) < n_train + n_test) {
    stop("DESN shell produced fewer rows than requested.", call. = FALSE)
  }
  if (all(abs(shell$X) <= sqrt(.Machine$double.eps))) {
    stop("DESN shell is all-zero; pilot requires a nondegenerate design.", call. = FALSE)
  }
  list(
    X_train = shell$X[seq_len(n_train), , drop = FALSE],
    y_train = shell$y_fit[seq_len(n_train)],
    X_test = shell$X[(n_train + 1L):(n_train + n_test), , drop = FALSE],
    y_test = shell$y_fit[(n_train + 1L):(n_train + n_test)],
    oracle = function(coverage_level) list(lower = NULL, upper = NULL)
  )
}

central_empirical_baseline <- function(y_train, n_test, coverage_level) {
  probs <- c((1 - coverage_level) / 2, 1 - (1 - coverage_level) / 2)
  qs <- as.numeric(stats::quantile(y_train, probs = probs, names = FALSE, type = 8))
  list(lower = rep(qs[1L], n_test), upper = rep(qs[2L], n_test))
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
  "rqr_desn_pilot",
  sprintf("rqr_desn_pilot_%s_git_%s", stamp, short_sha)
)
output_dir <- normalizePath(args[["output-dir"]] %||% default_output_dir, mustWork = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

install_package <- as_flag(args[["install-package"]], default = FALSE)
lib_path <- args[["lib-path"]] %||% NULL
if (isTRUE(install_package)) {
  lib_path <- lib_path %||% file.path(tempdir(), sprintf("exdqlm-rqr-pilot-lib-%s", stamp))
  dir.create(lib_path, recursive = TRUE, showWarnings = FALSE)
  status <- system2(
    file.path(R.home("bin"), "R"),
    c("CMD", "INSTALL", sprintf("--library=%s", lib_path), "--no-multiarch", "--with-keep.source", repo_root)
  )
  if (!identical(status, 0L)) stop("Package installation failed; aborting pilot.", call. = FALSE)
}
if (!is.null(lib_path)) {
  .libPaths(c(normalizePath(lib_path, mustWork = TRUE), .libPaths()))
}
suppressPackageStartupMessages(library(exdqlm))

replicates <- max(1L, as_int(args[["replicates"]], 2L))
n_burn <- max(5L, as_int(args[["mcmc-burn"]], 50L))
n_mcmc <- max(5L, as_int(args[["mcmc-keep"]], 70L))
vb_draws <- max(30L, as_int(args[["vb-draws"]], 80L))
coverage_levels <- as_num_vec(args[["coverage-levels"]], c(0.8, 0.9))
learning_rates <- as_num_vec(args[["learning-rates"]], c(0.5, 1.0))

scenario_manifest <- list()
metrics <- list()
fit_summary <- list()
failures <- list()
row_id <- 0L
fit_id <- 0L
failure_id <- 0L

record_failure <- function(...) {
  failure_id <<- failure_id + 1L
  failures[[failure_id]] <<- failure_row(...)
}

run_model <- function(data, scenario_id, scenario_family, replicate_id,
                      backend, inference, prior_type, coverage_level,
                      learning_rate, seed, design_type, note) {
  row_id <<- row_id + 1L
  scenario_manifest[[row_id]] <<- scenario_row(
    scenario_id = scenario_id,
    scenario_family = scenario_family,
    replicate_id = replicate_id,
    design_type = design_type,
    backend = backend,
    inference = inference,
    prior_type = prior_type,
    coverage_level = coverage_level,
    learning_rate = learning_rate,
    n_train = length(data$y_train),
    n_test = length(data$y_test),
    seed = seed,
    note = note
  )

  if (identical(backend, "empirical_train_interval")) {
    base <- central_empirical_baseline(data$y_train, length(data$y_test), coverage_level)
    oracle <- data$oracle(coverage_level)
    fit_id <<- fit_id + 1L
    metrics[[fit_id]] <<- metric_row(
      scenario_id, scenario_family, replicate_id, backend, inference, prior_type,
      coverage_level, learning_rate, data$y_test, base$lower, base$upper,
      oracle_lower = oracle$lower, oracle_upper = oracle$upper, runtime_sec = 0
    )
    return(invisible(TRUE))
  }

  fit_result <- tryCatch({
    run_timed({
      if (identical(inference, "mcmc")) {
        prior <- if (identical(prior_type, "rhs_ns")) {
          exdqlm::beta_prior("rhs_ns", rhs = list(
            tau0 = 0.5,
            a_zeta = 2,
            b_zeta = 1,
            s2 = 1,
            n_inner = 1L
          ))
        } else {
          exdqlm::beta_prior("ridge", ridge = list(tau2 = 8))
        }
        exdqlm::rqr_mcmc_fit(
          y = data$y_train,
          X = data$X_train,
          coverage_level = coverage_level,
          learning_rate = learning_rate,
          beta_prior_obj = prior,
          mcmc_control = list(n_burn = n_burn, n_mcmc = n_mcmc, thin = 1, seed = seed)
        )
      } else if (identical(inference, "vb")) {
        exdqlm::rqr_vb_fit(
          y = data$y_train,
          X = data$X_train,
          coverage_level = coverage_level,
          learning_rate = learning_rate,
          beta_prior_obj = exdqlm::beta_prior("ridge", ridge = list(tau2 = 8)),
          vb_control = list(max_iter = 60, tol = 1e-5, n_draws = vb_draws, seed = seed)
        )
      } else {
        stop(sprintf("Unknown inference method: %s", inference), call. = FALSE)
      }
    })
  }, error = function(e) e)

  if (inherits(fit_result, "error")) {
    record_failure(
      scenario_id, scenario_family, replicate_id, backend, inference, prior_type,
      coverage_level, learning_rate, conditionMessage(fit_result)
    )
    return(invisible(FALSE))
  }

  pred_result <- tryCatch({
    exdqlm::predict_interval(fit_result$value, X_new = data$X_test, seed = seed + 10000L)
  }, error = function(e) e)
  if (inherits(pred_result, "error")) {
    record_failure(
      scenario_id, scenario_family, replicate_id, backend, inference, prior_type,
      coverage_level, learning_rate, conditionMessage(pred_result)
    )
    return(invisible(FALSE))
  }

  oracle <- data$oracle(coverage_level)
  fit_id <<- fit_id + 1L
  metrics[[fit_id]] <<- metric_row(
    scenario_id, scenario_family, replicate_id, backend, inference, prior_type,
    coverage_level, learning_rate, data$y_test, pred_result$lower_mean,
    pred_result$upper_mean, pred_result$midpoint_mean,
    oracle_lower = oracle$lower, oracle_upper = oracle$upper,
    runtime_sec = fit_result$elapsed
  )
  fit_summary[[fit_id]] <<- fit_summary_row(
    scenario_id, scenario_family, replicate_id, backend, inference, prior_type,
    fit_result$value, fit_result$elapsed
  )
  invisible(TRUE)
}

for (rr in seq_len(replicates)) {
  seed_base <- 9026000L + rr * 1000L
  for (family in c("symmetric_linear", "skewed_linear")) {
    data <- make_fixed_design(family, seed = seed_base + match(family, c("symmetric_linear", "skewed_linear")))
    for (coverage_level in coverage_levels) {
      run_model(
        data, sprintf("%s_rep%02d_cov%s_baseline", family, rr, gsub("\\.", "p", coverage_level)),
        family, rr, "empirical_train_interval", "baseline", "none",
        coverage_level, NA_real_, seed_base, "fixed_linear", "constant train empirical central interval"
      )
      for (learning_rate in learning_rates) {
        run_model(
          data, sprintf("%s_rep%02d_cov%s_lr%s_mcmc_ridge", family, rr, gsub("\\.", "p", coverage_level), gsub("\\.", "p", learning_rate)),
          family, rr, "rqr_fixed_design_mcmc", "mcmc", "ridge",
          coverage_level, learning_rate, seed_base + 10L, "fixed_linear", "primary fixed-design MCMC"
        )
      }
      if (identical(coverage_level, coverage_levels[1L])) {
        run_model(
          data, sprintf("%s_rep%02d_cov%s_vb_sidecar", family, rr, gsub("\\.", "p", coverage_level)),
          family, rr, "rqr_fixed_design_vb", "vb", "ridge",
          coverage_level, learning_rates[1L], seed_base + 20L, "fixed_linear", "VB sidecar; uncertainty not calibrated"
        )
        run_model(
          data, sprintf("%s_rep%02d_cov%s_mcmc_rhsns", family, rr, gsub("\\.", "p", coverage_level)),
          family, rr, "rqr_fixed_design_mcmc", "mcmc", "rhs_ns",
          coverage_level, learning_rates[1L], seed_base + 30L, "fixed_linear", "RHS_NS sparse-prior smoke"
        )
      }
    }
  }

  data <- make_desn_design(seed = seed_base + 77L)
  for (coverage_level in coverage_levels) {
    run_model(
      data, sprintf("teacher_forced_desn_rep%02d_cov%s_baseline", rr, gsub("\\.", "p", coverage_level)),
      "teacher_forced_desn", rr, "empirical_train_interval", "baseline", "none",
      coverage_level, NA_real_, seed_base + 77L, "teacher_forced_desn", "constant train empirical central interval"
    )
    for (learning_rate in learning_rates) {
      run_model(
        data, sprintf("teacher_forced_desn_rep%02d_cov%s_lr%s_mcmc_ridge", rr, gsub("\\.", "p", coverage_level), gsub("\\.", "p", learning_rate)),
        "teacher_forced_desn", rr, "rqr_desn_teacher_forced_mcmc", "mcmc", "ridge",
        coverage_level, learning_rate, seed_base + 80L, "teacher_forced_desn",
        "RQR readout on explicit teacher-forced DESN future design; not recursive response sampling"
      )
    }
  }
}

scenario_manifest_df <- if (length(scenario_manifest)) do.call(rbind, scenario_manifest) else data.frame()
metrics_df <- if (length(metrics)) do.call(rbind, metrics) else data.frame()
fit_summary_df <- if (length(fit_summary)) do.call(rbind, fit_summary) else data.frame()
failure_df <- if (length(failures)) do.call(rbind, failures) else data.frame(
  scenario_id = character(0),
  scenario_family = character(0),
  replicate_id = integer(0),
  backend = character(0),
  inference = character(0),
  prior_type = character(0),
  coverage_level = numeric(0),
  learning_rate = numeric(0),
  message = character(0),
  stringsAsFactors = FALSE
)

model_rows <- metrics_df[metrics_df$backend != "empirical_train_interval", , drop = FALSE]
pass_finite <- nrow(model_rows) > 0 && all(model_rows$finite_lower) && all(model_rows$finite_upper)
pass_ordered <- nrow(model_rows) > 0 && all(model_rows$ordered_intervals)
pass_width <- nrow(model_rows) > 0 && all(model_rows$positive_mean_width)
pass_failures <- nrow(failure_df) == 0L
go_for_broad_spec <- pass_finite && pass_ordered && pass_width && pass_failures

manifest_df <- data.frame(
  key = c(
    "artifact_kind",
    "interpretation",
    "repo_root",
    "git_commit",
    "git_branch",
    "output_dir",
    "replicates",
    "coverage_levels",
    "learning_rates",
    "mcmc_burn",
    "mcmc_keep",
    "vb_draws",
    "scenario_rows",
    "metric_rows",
    "failure_rows",
    "go_for_broad_spec",
    "created_at",
    "r_version",
    "install_package"
  ),
  value = c(
    "rqr_desn_pilot",
    "small deterministic pilot; not broad simulation or article evidence",
    repo_root,
    git_value(repo_root, "rev-parse", "HEAD"),
    git_value(repo_root, "branch", "--show-current"),
    output_dir,
    as.character(replicates),
    paste(coverage_levels, collapse = ","),
    paste(learning_rates, collapse = ","),
    as.character(n_burn),
    as.character(n_mcmc),
    as.character(vb_draws),
    as.character(nrow(scenario_manifest_df)),
    as.character(nrow(metrics_df)),
    as.character(nrow(failure_df)),
    if (go_for_broad_spec) "yes" else "no",
    format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    paste(R.version$major, R.version$minor, sep = "."),
    as.character(install_package)
  ),
  stringsAsFactors = FALSE
)

write_csv(manifest_df, file.path(output_dir, "manifest.csv"))
write_csv(scenario_manifest_df, file.path(output_dir, "scenario_manifest.csv"))
write_csv(metrics_df, file.path(output_dir, "interval_metrics.csv"))
write_csv(fit_summary_df, file.path(output_dir, "fit_summary.csv"))
write_csv(failure_df, file.path(output_dir, "failure_log.csv"))

aggregate_cols <- c("empirical_coverage", "mean_width", "interval_score_mean", "midpoint_mae", "endpoint_mae")
group_cols <- c("scenario_family", "backend", "inference", "prior_type", "coverage_level")
summary_df <- stats::aggregate(
  metrics_df[aggregate_cols],
  by = metrics_df[group_cols],
  FUN = function(x) {
    if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
  }
)
write_csv(summary_df, file.path(output_dir, "pilot_metric_summary.csv"))

closeout_lines <- c(
  "# RQR-DESN Pilot Closeout",
  "",
  sprintf("Created: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  sprintf("Git commit: `%s`", git_value(repo_root, "rev-parse", "HEAD")),
  sprintf("Branch: `%s`", git_value(repo_root, "branch", "--show-current")),
  "",
  "## Decision",
  "",
  sprintf("`go_for_broad_spec`: **%s**", if (go_for_broad_spec) "yes" else "no"),
  "",
  "## Gate Summary",
  "",
  sprintf("- failure rows: %d", nrow(failure_df)),
  sprintf("- model rows finite: %s", pass_finite),
  sprintf("- model rows ordered: %s", pass_ordered),
  sprintf("- model rows positive mean width: %s", pass_width),
  "",
  "## Interpretation",
  "",
  "This is a pilot and plumbing check. It is not a broad simulation study and",
  "should not be promoted to the article. The DESN scenario uses an explicit",
  "teacher-forced future design matrix to test readout wiring; it does not",
  "perform recursive response sampling from the RQR pseudo-likelihood.",
  "",
  "## Metric Summary",
  "",
  paste(capture.output(print(summary_df, row.names = FALSE)), collapse = "\n")
)
writeLines(closeout_lines, file.path(output_dir, "pilot_closeout.md"))

readme_lines <- c(
  "# RQR-DESN Pilot",
  "",
  "Generated by `scripts/rqr_desn_pilot_simulation.R`.",
  "",
  "This directory is a small deterministic pilot used to test output contracts",
  "before a broad simulation. It is not article evidence.",
  "",
  "Files:",
  "- `manifest.csv`: run configuration and go/no-go flag.",
  "- `scenario_manifest.csv`: scenario, backend, and seed inventory.",
  "- `interval_metrics.csv`: row-level interval metrics.",
  "- `pilot_metric_summary.csv`: aggregate metric summary.",
  "- `fit_summary.csv`: model fit metadata.",
  "- `failure_log.csv`: explicit fit/prediction failures.",
  "- `pilot_closeout.md`: human-readable closeout.",
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

if (!pass_finite || !pass_ordered || !pass_width) {
  stop("Pilot completed but failed finite/order/width gates; inspect pilot_closeout.md.", call. = FALSE)
}
if (!pass_failures) {
  stop("Pilot completed with failure rows; inspect failure_log.csv.", call. = FALSE)
}

message(sprintf(
  "RQR-DESN pilot wrote %d metric rows to %s; go_for_broad_spec=%s",
  nrow(metrics_df),
  output_dir,
  if (go_for_broad_spec) "yes" else "no"
))

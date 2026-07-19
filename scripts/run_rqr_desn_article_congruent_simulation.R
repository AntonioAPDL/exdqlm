#!/usr/bin/env Rscript

if (requireNamespace("compiler", quietly = TRUE)) invisible(compiler::enableJIT(0))

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

parse_cli <- function(args) {
  out <- list()
  ii <- 1L
  while (ii <= length(args)) {
    key <- args[[ii]]
    if (!startsWith(key, "--")) stop(sprintf("Unexpected positional argument: %s", key), call. = FALSE)
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
  out <- suppressWarnings(as.integer(x[1L]))
  if (!is.finite(out)) stop(sprintf("Expected integer, got: %s", x[1L]), call. = FALSE)
  out
}

split_cli_vec <- function(x) {
  if (is.null(x) || !nzchar(as.character(x)[1L])) return(NULL)
  trimws(strsplit(as.character(x)[1L], ",", fixed = TRUE)[[1L]])
}

scenario_file_ids <- function(path) {
  if (is.null(path) || !nzchar(as.character(path)[1L])) return(NULL)
  path <- normalizePath(as.character(path)[1L], mustWork = TRUE)
  if (grepl("\\.csv$", path, ignore.case = TRUE)) {
    x <- read_csv(path)
    if ("scenario_id" %in% names(x)) return(unique(as.character(x$scenario_id)))
  }
  unique(trimws(readLines(path, warn = FALSE)))
}

git_value <- function(repo_root, ...) {
  paste(tryCatch(system2("git", c("-C", repo_root, ...), stdout = TRUE, stderr = TRUE), error = function(e) character(0)), collapse = "\n")
}

write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
}

read_csv <- function(path) utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)

source_config <- function(config_path) {
  env <- new.env(parent = baseenv())
  sys.source(config_path, envir = env)
  get("rqr_desn_article_congruent_simulation_config", envir = env)
}

load_package <- function(repo_root) {
  if (requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(repo_root, quiet = TRUE)
  } else {
    suppressPackageStartupMessages(library(exdqlm))
  }
}

materialize_manifest <- function(repo_root, config_path, output_dir) {
  manifest_path <- file.path(output_dir, "scenario_manifest.csv")
  if (file.exists(manifest_path)) return(invisible(TRUE))
  script <- file.path(repo_root, "scripts", "materialize_rqr_desn_article_congruent_manifest.R")
  out <- system2(file.path(R.home("bin"), "Rscript"), c(script, "--config", config_path, "--output-dir", output_dir, "--repo-root", repo_root), stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status", exact = TRUE) %||% 0L
  if (!identical(as.integer(status), 0L)) stop(sprintf("Manifest materialization failed:\n%s", paste(out, collapse = "\n")), call. = FALSE)
}

filter_manifest <- function(df, cli) {
  filters <- list(
    stage_id = split_cli_vec(cli[["stage-id"]]),
    family_id = split_cli_vec(cli[["family-id"]]),
    method_id = split_cli_vec(cli[["method-id"]]),
    implemented_adapter = split_cli_vec(cli[["implemented-adapter"]])
  )
  for (nm in names(filters)) {
    if (!is.null(filters[[nm]])) df <- df[df[[nm]] %in% filters[[nm]], , drop = FALSE]
  }
  file_ids <- scenario_file_ids(cli[["scenario-file"]])
  if (!is.null(file_ids)) df <- df[df$scenario_id %in% file_ids, , drop = FALSE]
  if (!is.null(cli[["scenario-id"]])) df <- df[df$scenario_id %in% split_cli_vec(cli[["scenario-id"]]), , drop = FALSE]
  max_scenarios <- as_int(cli[["max-scenarios"]], NA_integer_)
  if (is.finite(max_scenarios) && max_scenarios > 0L && nrow(df) > max_scenarios) df <- df[seq_len(max_scenarios), , drop = FALSE]
  rownames(df) <- NULL
  df
}

interval_score <- function(y, lower, upper, coverage_level) {
  alpha <- 1 - as.numeric(coverage_level)[1L]
  (upper - lower) + (2 / alpha) * pmax(lower - y, 0) + (2 / alpha) * pmax(y - upper, 0)
}

empirical_interval <- function(y_fit, n, coverage_level) {
  p <- c((1 - coverage_level) / 2, 1 - (1 - coverage_level) / 2)
  q <- as.numeric(stats::quantile(y_fit, probs = p, type = 8, names = FALSE))
  list(lower = rep(q[1L], n), upper = rep(q[2L], n), midpoint = rep(mean(q), n))
}

innovation_draw <- function(n, family, seed, params = list()) {
  set.seed(as.integer(seed)[1L])
  family <- as.character(family)[1L]
  if (family == "gaussian") return(stats::rnorm(n))
  if (family == "laplace") {
    u <- stats::runif(n) - 0.5
    return(-sign(u) * log1p(-2 * abs(u)))
  }
  if (family == "student_t") return(stats::rt(n, df = as.numeric(params$df %||% 5)))
  if (family == "centered_gamma") {
    shape <- as.numeric(params$shape %||% 2)
    scale <- as.numeric(params$scale %||% 1)
    return(stats::rgamma(n, shape = shape, scale = scale) - shape * scale)
  }
  if (family == "asymmetric_laplace") {
    tau <- as.numeric(params$tau %||% 0.25)
    u <- stats::runif(n)
    raw <- ifelse(u < tau, log(u / tau) / (1 - tau), -log((1 - u) / (1 - tau)) / tau)
    return(raw - (1 - 2 * tau) / (tau * (1 - tau)))
  }
  if (family == "gaussian_mixture") {
    w <- as.numeric(params$weights %||% c(0.1, 0.9))
    m <- as.numeric(params$means %||% c(0, 1))
    s <- as.numeric(params$sds %||% c(0.5, 1.5))
    z <- sample.int(length(w), size = n, replace = TRUE, prob = w)
    raw <- stats::rnorm(n, mean = m[z], sd = s[z])
    if (isTRUE(params$center %||% TRUE)) raw <- raw - sum(w / sum(w) * m)
    return(raw)
  }
  stop(sprintf("Unsupported innovation family: %s", family), call. = FALSE)
}

family_params <- function(row) {
  # The runner keeps the full config authoritative; these defaults mirror it for
  # row-level smoke execution.
  switch(as.character(row$innovation_family),
    student_t = list(df = if (grepl("persistent", row$family_id)) 3 else 5, scale = 1),
    centered_gamma = list(shape = 2, scale = 1),
    asymmetric_laplace = list(tau = 0.25, scale = 1),
    gaussian_mixture = list(weights = c(0.1, 0.9), means = c(0, 1), sds = c(0.5, 1.5), center = TRUE),
    laplace = list(location = 0, scale = 1),
    gaussian = list(mean = 0, sd = 1),
    list()
  )
}

fixed_data <- function(row, seed) {
  n_cal <- as.integer(row$calibration_n)
  n_fit <- as.integer(row$final_fit_n)
  n_test <- as.integer(row$test_n)
  n <- n_cal + n_fit + n_test
  set.seed(as.integer(seed)[1L])
  p <- 20L
  rho <- 0.5
  Sigma <- outer(seq_len(p), seq_len(p), function(i, j) rho^abs(i - j))
  X0 <- matrix(stats::rnorm(n * p), n, p) %*% chol(Sigma)
  beta <- c(0.70, -0.55, 0.40, 0.25, -0.20, rep(0, p - 5L))
  mu <- 0.25 + as.numeric(X0 %*% beta)
  sigma <- if (grepl("heteroskedastic", row$family_id)) 0.55 + 0.25 * abs(X0[, 1L]) else rep(0.75, n)
  eps <- innovation_draw(n, row$innovation_family, seed + 17L, family_params(row))
  y <- mu + sigma * eps
  X <- cbind("(Intercept)" = 1, X0)
  idx_cal <- seq_len(n_cal)
  idx_fit <- n_cal + seq_len(n_fit)
  idx_test <- n_cal + n_fit + seq_len(n_test)
  list(
    X_calibration = X[idx_cal, , drop = FALSE],
    y_calibration = y[idx_cal],
    X_fit = X[idx_fit, , drop = FALSE],
    y_fit = y[idx_fit],
    X_test = X[idx_test, , drop = FALSE],
    y_test = y[idx_test],
    oracle = function(coverage_level) exdqlm::rqr_oracle_endpoints(mu[idx_test], sigma[idx_test], row$innovation_family, coverage_level, params = family_params(row))
  )
}

dynamic_signal <- function(n, family_id, seed) {
  set.seed(as.integer(seed)[1L])
  mu <- numeric(n)
  sigma <- rep(0.65, n)
  for (tt in 2:n) {
    base <- 0.55 * mu[tt - 1L] + 0.25 * sin(tt / 35) + 0.15 * cos(tt / 90)
    if (grepl("regime_shift", family_id) && tt > 0.62 * n) base <- base + 0.8 - 0.65 * mu[tt - 1L]
    if (grepl("nonlinear", family_id)) base <- base + 0.30 * sin(mu[tt - 1L])
    mu[tt] <- base + stats::rnorm(1, sd = 0.025)
    if (grepl("persistent_heavy_tail", family_id)) sigma[tt] <- 0.35 + 0.55 * abs(sin(tt / 60))
    if (grepl("heteroskedastic", family_id)) sigma[tt] <- 0.40 + 0.35 * abs(mu[tt - 1L])
  }
  list(mu = mu, sigma = pmax(sigma, 0.05))
}

dynamic_data <- function(row, seed, config) {
  split <- config$split_contract
  n_eff <- as.integer(split$effective_length)
  sig <- dynamic_signal(n_eff, row$family_id, seed)
  eps <- innovation_draw(n_eff, row$innovation_family, seed + 31L, family_params(row))
  y <- sig$mu + sig$sigma * eps
  design <- config$stages[[2L]]$design
  shell <- exdqlm::qdesn_fit_vb(
    y = y,
    p0 = 0.5,
    fit_readout = FALSE,
    vb_args = list(),
    D = as.integer(design$DESN_D),
    n = rep(as.integer(design$DESN_n), as.integer(design$DESN_D)),
    n_tilde = integer(0),
    m = as.integer(design$DESN_m),
    alpha = rep(as.numeric(design$alpha), as.integer(design$DESN_D)),
    rho = rep(as.numeric(design$rho), as.integer(design$DESN_D)),
    act_f = as.character(design$act_f),
    act_k = as.character(design$act_k),
    pi_w = as.numeric(design$pi_w),
    pi_in = as.numeric(design$pi_in),
    washout = as.integer(design$washout),
    add_bias = isTRUE(design$add_bias),
    seed = as.integer(seed + 91L)
  )
  offset <- as.integer(design$washout)
  idx_cal <- as.integer(split$calibration_start):as.integer(split$calibration_end) - offset
  idx_fit <- as.integer(split$final_fit_start):as.integer(split$final_fit_end) - offset
  idx_test <- as.integer(split$test_start):as.integer(split$test_end) - offset
  eff_test <- as.integer(split$test_start):as.integer(split$test_end)
  list(
    X_calibration = shell$X[idx_cal, , drop = FALSE],
    y_calibration = shell$y_fit[idx_cal],
    X_fit = shell$X[idx_fit, , drop = FALSE],
    y_fit = shell$y_fit[idx_fit],
    X_test = shell$X[idx_test, , drop = FALSE],
    y_test = shell$y_fit[idx_test],
    oracle = function(coverage_level) exdqlm::rqr_oracle_endpoints(sig$mu[eff_test], sig$sigma[eff_test], row$innovation_family, coverage_level, params = family_params(row))
  )
}

make_data <- function(row, config) {
  seed <- as.integer(row$seed) + as.integer(row$replicate_id) * 10000L
  if (row$stage_family == "fixed_design") return(fixed_data(row, seed))
  if (row$stage_family == "dynamic_desn") return(dynamic_data(row, seed, config))
  stop(sprintf("Runner does not implement stage_family=%s yet.", row$stage_family), call. = FALSE)
}

build_prior <- function(row, config) {
  prior_cfg <- config_prior(row, config)
  if (row$prior_type %in% c("rqr_rhs_ns", "qdesn_rhs_ns")) {
    return(exdqlm::beta_prior("rhs_ns", rhs = list(
      tau0 = as.numeric(prior_cfg$tau0 %||% 0.5),
      a_zeta = as.numeric(prior_cfg$a_zeta %||% 2),
      b_zeta = as.numeric(prior_cfg$b_zeta %||% 1),
      s2 = as.numeric(prior_cfg$s2 %||% 1),
      n_inner = as.integer(prior_cfg$n_inner %||% 1L),
      shrink_intercept = isTRUE(prior_cfg$shrink_intercept %||% FALSE)
    )))
  }
  exdqlm::beta_prior("ridge", ridge = list(tau2 = 8))
}

config_prior <- function(row, config) {
  priors <- config$priors %||% list()
  priors[[as.character(row$prior_type)[1L]]] %||% list()
}

learning_rate_mode_from_row <- function(row) {
  mode <- tolower(as.character(row$learning_rate_mode %||% "fixed")[1L])
  mode <- switch(mode,
    learned = "learned_scale",
    scale = "learned_scale",
    learned_loss_scale = "learned_scale",
    pure = "learned_pure",
    mode
  )
  if (!mode %in% c("fixed", "learned_scale", "learned_pure")) {
    stop(sprintf("Unsupported learning_rate_mode: %s", mode), call. = FALSE)
  }
  mode
}

learning_rate_initial_from_row <- function(row) {
  lr <- suppressWarnings(as.numeric(row$learning_rate)[1L])
  if (!is.finite(lr) || lr <= 0) lr <- 1
  lr
}

lambda_prior_from_row <- function(row) {
  list(
    shape = suppressWarnings(as.numeric(row$lambda_prior_shape)[1L]),
    rate = suppressWarnings(as.numeric(row$lambda_prior_rate)[1L]),
    power = suppressWarnings(as.numeric(row$lambda_prior_power)[1L])
  )
}

rqr_loss_reference_scale <- function(data, config) {
  cfg <- config$analysis_scale %||% list()
  mode <- tolower(as.character(cfg$rqr_loss_reference_scale %||% cfg$loss_reference_scale %||% "raw")[1L])
  floor_value <- as.numeric(cfg$loss_reference_floor %||% 1e-8)[1L]
  if (!is.finite(floor_value) || floor_value <= 0) floor_value <- 1e-8
  if (mode %in% c("raw", "none", "fixed_one")) return(1)
  if (mode %in% c("train_response_variance", "training_response_variance", "fit_response_variance")) {
    value <- stats::var(as.numeric(data$y_fit))
    return(max(as.numeric(value), floor_value))
  }
  value <- suppressWarnings(as.numeric(mode)[1L])
  if (is.finite(value) && value > 0) return(value)
  stop(sprintf("Unsupported rqr_loss_reference_scale mode: %s", mode), call. = FALSE)
}

mcmc_control <- function(row, config, cli, chain_id) {
  ctl <- config$mcmc_control
  n_burn <- as_int(cli[["mcmc-burn"]], as.integer(ctl$n_burn))
  n_mcmc <- as_int(cli[["mcmc-keep"]], as.integer(ctl$n_mcmc))
  list(
    n_burn = n_burn,
    n_mcmc = n_mcmc,
    thin = as.integer(ctl$thin),
    store_latent_draws = FALSE,
    precision_beta = ctl$precision_beta,
    seed = as.integer(row$seed) + 1000L * as.integer(chain_id),
    verbose = FALSE
  )
}

fit_rqr_interval <- function(row, data, config, cli) {
  chains <- max(1L, as_int(cli[["chains"]], as.integer(row$chain_count)))
  loss_reference_scale <- rqr_loss_reference_scale(data, config)
  lower_draws <- upper_draws <- NULL
  diag <- list()
  for (chain_id in seq_len(chains)) {
    fit <- exdqlm::rqr_mcmc_fit(
      y = data$y_fit,
      X = data$X_fit,
      coverage_level = as.numeric(row$coverage_level),
      learning_rate = learning_rate_initial_from_row(row),
      loss_reference_scale = loss_reference_scale,
      learning_rate_mode = learning_rate_mode_from_row(row),
      lambda_prior = lambda_prior_from_row(row),
      beta_prior_obj = build_prior(row, config),
      mcmc_control = mcmc_control(row, config, cli, chain_id)
    )
    pred <- exdqlm::predict_interval(fit, X_new = data$X_test)
    lower_draws <- cbind(lower_draws, pred$lower_draws)
    upper_draws <- cbind(upper_draws, pred$upper_draws)
    diag[[chain_id]] <- data.frame(
      scenario_id = row$scenario_id,
      chain_id = chain_id,
      n_draws = nrow(fit$samp.beta_root1),
      diagnostic_status = if (all(is.finite(fit$diagnostics$loss_trace))) "pass" else "review",
      learning_rate_mode = fit$model_spec$learning_rate_mode %||% "fixed",
      loss_reference_scale = fit$model_spec$loss_reference_scale %||% loss_reference_scale,
      effective_learning_rate_mean = fit$model_spec$effective_learning_rate %||% NA_real_,
      lambda_mean = fit$model_spec$lambda_summary$mean %||% NA_real_,
      lambda_sd = fit$model_spec$lambda_summary$sd %||% NA_real_,
      lambda_q05 = fit$model_spec$lambda_summary$q05 %||% NA_real_,
      lambda_q95 = fit$model_spec$lambda_summary$q95 %||% NA_real_,
      response_likelihood = FALSE,
      generalized_bayes = TRUE
    )
  }
  list(
    lower = rowMeans(lower_draws),
    upper = rowMeans(upper_draws),
    diagnostics = do.call(rbind, diag),
    loss_reference_scale = loss_reference_scale
  )
}

fit_independent_al_pair <- function(row, data, config, cli) {
  chains <- max(1L, as_int(cli[["chains"]], as.integer(row$chain_count)))
  q_lower <- as.numeric(row$quantile_lower)
  q_upper <- as.numeric(row$quantile_upper)
  fit_quantile <- function(p0, seed_shift) {
    draws <- NULL
    for (chain_id in seq_len(chains)) {
      ctl <- mcmc_control(row, config, cli, chain_id + seed_shift)
      set.seed(as.integer(ctl$seed))
      ctl$seed <- NULL
      mctl <- do.call(exdqlm::exal_make_mcmc_control, c(ctl, list(init_from_vb = FALSE)))
      fit <- exdqlm::exal_mcmc_fit(
        y = data$y_fit,
        X = data$X_fit,
        p0 = p0,
        gamma_bounds = c(exdqlm:::L.fn(p0), exdqlm:::U.fn(p0)),
        likelihood_family = "al",
        al_fixed_gamma = 0,
        mcmc_control = mctl,
        beta_prior_obj = build_prior(row, config)
      )
      draws <- cbind(draws, data$X_test %*% t(fit$samp.beta))
    }
    rowMeans(draws)
  }
  qlo <- fit_quantile(q_lower, 100L)
  qhi <- fit_quantile(q_upper, 200L)
  list(
    lower = pmin(qlo, qhi),
    upper = pmax(qlo, qhi),
    diagnostics = data.frame(
      scenario_id = row$scenario_id,
      chain_id = seq_len(chains),
      n_draws = as_int(cli[["mcmc-keep"]], as.integer(config$mcmc_control$n_mcmc)),
      diagnostic_status = "pass",
      response_likelihood = TRUE,
      generalized_bayes = FALSE
    )
  )
}

metric_row <- function(row, data, interval, runtime_sec) {
  oracle <- data$oracle(as.numeric(row$coverage_level))
  lower <- as.numeric(interval$lower)
  upper <- as.numeric(interval$upper)
  y <- as.numeric(data$y_test)
  score <- interval_score(y, lower, upper, as.numeric(row$coverage_level))
  endpoint_mae <- mean(abs(lower - oracle$lower) + abs(upper - oracle$upper)) / 2
  data.frame(
    scenario_id = row$scenario_id,
    stage_id = row$stage_id,
    family_id = row$family_id,
    replicate_id = as.integer(row$replicate_id),
    method_id = row$method_id,
    method_family = row$method_family,
    inference = row$inference,
    implemented_adapter = row$implemented_adapter,
    prior_type = row$prior_type,
    coverage_level = as.numeric(row$coverage_level),
    learning_rate = as.numeric(row$learning_rate),
    learning_rate_mode = row$learning_rate_mode %||% "fixed",
    loss_reference_scale = interval$loss_reference_scale %||% NA_real_,
    lambda_prior_shape = suppressWarnings(as.numeric(row$lambda_prior_shape)[1L]),
    lambda_prior_rate = suppressWarnings(as.numeric(row$lambda_prior_rate)[1L]),
    lambda_prior_power = suppressWarnings(as.numeric(row$lambda_prior_power)[1L]),
    quantile_lower = as.numeric(row$quantile_lower),
    quantile_upper = as.numeric(row$quantile_upper),
    empirical_coverage = mean(y >= lower & y <= upper),
    coverage_error = mean(y >= lower & y <= upper) - as.numeric(row$coverage_level),
    mean_width = mean(upper - lower),
    interval_score_mean = mean(score),
    endpoint_mae = endpoint_mae,
    midpoint_mae = mean(abs(0.5 * (lower + upper) - oracle$midpoint)),
    finite_lower = all(is.finite(lower)),
    finite_upper = all(is.finite(upper)),
    ordered_intervals = all(upper >= lower),
    positive_mean_width = is.finite(mean(upper - lower)) && mean(upper - lower) > 0,
    runtime_sec = runtime_sec,
    rqr_response_likelihood = FALSE,
    rqr_response_predictive_draws = FALSE,
    rqr_recursive_response_sampling = FALSE,
    qdesn_pair_scalar_density = FALSE,
    stringsAsFactors = FALSE
  )
}

failure_row <- function(row, stage, class, message) {
  data.frame(
    scenario_id = row$scenario_id,
    stage_id = row$stage_id,
    family_id = row$family_id,
    method_id = row$method_id,
    failure_stage = stage,
    failure_class = class,
    failure_message = message,
    stringsAsFactors = FALSE
  )
}

status_row <- function(row, status, runtime_sec, message = "") {
  data.frame(
    scenario_id = row$scenario_id,
    status = status,
    runtime_sec = runtime_sec,
    message = message,
    stringsAsFactors = FALSE
  )
}

run_one <- function(row, data, config, cli) {
  dir.create(row$scenario_output_dir, recursive = TRUE, showWarnings = FALSE)
  t0 <- proc.time()[["elapsed"]]
  out <- tryCatch({
    if (!as_flag(row$adapter_ready, FALSE)) {
      stop("External article joint-QVP adapter is declared but not wired in the package-side runner.", call. = FALSE)
    }
    if (row$implemented_adapter == "empirical_interval") {
      interval <- empirical_interval(data$y_fit, length(data$y_test), as.numeric(row$coverage_level))
      interval$diagnostics <- data.frame()
    } else if (row$implemented_adapter == "rqr_mcmc") {
      interval <- fit_rqr_interval(row, data, config, cli)
    } else if (row$implemented_adapter == "independent_al_pair") {
      interval <- fit_independent_al_pair(row, data, config, cli)
    } else {
      stop(sprintf("Unknown implemented adapter: %s", row$implemented_adapter), call. = FALSE)
    }
    runtime <- proc.time()[["elapsed"]] - t0
    metric <- metric_row(row, data, interval, runtime)
    write_csv(metric, file.path(row$scenario_output_dir, "interval_metrics.csv"))
    write_csv(interval$diagnostics, file.path(row$scenario_output_dir, "mcmc_diagnostics.csv"))
    write_csv(data.frame(), file.path(row$scenario_output_dir, "failure_log.csv"))
    write_csv(status_row(row, "completed", runtime, "completed"), file.path(row$scenario_output_dir, "scenario_status.csv"))
    "completed"
  }, error = function(e) {
    runtime <- proc.time()[["elapsed"]] - t0
    write_csv(data.frame(), file.path(row$scenario_output_dir, "interval_metrics.csv"))
    write_csv(data.frame(), file.path(row$scenario_output_dir, "mcmc_diagnostics.csv"))
    write_csv(failure_row(row, "fit_or_score", class(e)[1L], conditionMessage(e)), file.path(row$scenario_output_dir, "failure_log.csv"))
    write_csv(status_row(row, "failed", runtime, conditionMessage(e)), file.path(row$scenario_output_dir, "scenario_status.csv"))
    "failed"
  })
  out
}

combine_csvs <- function(paths) {
  paths <- paths[file.exists(paths)]
  if (!length(paths)) return(data.frame())
  parts <- lapply(paths, function(path) {
    x <- tryCatch(read_csv(path), error = function(e) data.frame())
    if (nrow(x)) x else NULL
  })
  parts <- Filter(Negate(is.null), parts)
  if (!length(parts)) return(data.frame())
  all_names <- unique(unlist(lapply(parts, names), use.names = FALSE))
  parts <- lapply(parts, function(x) {
    missing <- setdiff(all_names, names(x))
    for (nm in missing) x[[nm]] <- NA
    x[all_names]
  })
  do.call(rbind, parts)
}

aggregate_outputs <- function(output_dir, selected) {
  dirs <- selected$scenario_output_dir
  metrics <- combine_csvs(file.path(dirs, "interval_metrics.csv"))
  mcmc <- combine_csvs(file.path(dirs, "mcmc_diagnostics.csv"))
  failures <- combine_csvs(file.path(dirs, "failure_log.csv"))
  statuses <- combine_csvs(file.path(dirs, "scenario_status.csv"))
  write_csv(metrics, file.path(output_dir, "interval_metrics.csv"))
  write_csv(mcmc, file.path(output_dir, "mcmc_diagnostics.csv"))
  write_csv(failures, file.path(output_dir, "failure_log.csv"))
  write_csv(statuses, file.path(output_dir, "run_status.csv"))
  if (nrow(metrics)) {
    baseline <- metrics[metrics$method_id == "empirical_train_interval", c("stage_id", "family_id", "replicate_id", "coverage_level", "scenario_id", "interval_score_mean", "mean_width"), drop = FALSE]
    names(baseline)[names(baseline) == "scenario_id"] <- "baseline_scenario_id"
    names(baseline)[names(baseline) == "interval_score_mean"] <- "baseline_interval_score_mean"
    names(baseline)[names(baseline) == "mean_width"] <- "baseline_mean_width"
    model <- metrics[metrics$method_id != "empirical_train_interval", , drop = FALSE]
    deltas <- merge(model, baseline, by = c("stage_id", "family_id", "replicate_id", "coverage_level"), all.x = TRUE, sort = FALSE)
    deltas$interval_score_delta <- deltas$interval_score_mean - deltas$baseline_interval_score_mean
    deltas$width_ratio <- deltas$mean_width / deltas$baseline_mean_width
  } else {
    deltas <- data.frame()
  }
  write_csv(deltas, file.path(output_dir, "replicate_pairwise_deltas.csv"))
  gates <- data.frame(
    gate = c(
      "selected_rows_terminal",
      "no_rqr_predictive_response_draws",
      "no_qdesn_pair_scalar_density_claim",
      "external_adapter_failures_explicit"
    ),
    status = c(
      if (nrow(statuses) == nrow(selected)) "pass" else "fail",
      if (!nrow(metrics) || !any(as.logical(metrics$rqr_response_predictive_draws))) "pass" else "fail",
      if (!nrow(metrics) || !any(as.logical(metrics$qdesn_pair_scalar_density))) "pass" else "fail",
      if (any(selected$implemented_adapter == "external_article_joint_qvp_required")) "review" else "pass"
    ),
    observed = c(nrow(statuses), NA, NA, sum(selected$implemented_adapter == "external_article_joint_qvp_required")),
    expected = c(nrow(selected), 0, 0, NA)
  )
  write_csv(gates, file.path(output_dir, "readiness_gates.csv"))
  writeLines(c(
    "# RQR-DESN Article-Congruent Run Closeout",
    "",
    sprintf("- selected rows: `%d`", nrow(selected)),
    sprintf("- completed rows: `%d`", sum(statuses$status == "completed")),
    sprintf("- failed rows: `%d`", sum(statuses$status == "failed")),
    sprintf("- metric rows: `%d`", nrow(metrics)),
    "",
    "This run is package-side evidence. Full article promotion requires the separate results audit and manuscript asset build."
  ), file.path(output_dir, "closeout.md"))
}

write_hashes <- function(output_dir) {
  files <- list.files(output_dir, full.names = TRUE, recursive = FALSE)
  files <- files[file.info(files)$isdir %in% FALSE]
  files <- files[basename(files) != "output_hashes.csv"]
  write_csv(data.frame(file = basename(files), md5 = unname(tools::md5sum(files))), file.path(output_dir, "output_hashes.csv"))
}

main <- function(args = commandArgs(trailingOnly = TRUE)) {
  cli <- parse_cli(args)
  repo_root <- cli[["repo-root"]] %||% git_value(getwd(), "rev-parse", "--show-toplevel")
  repo_root <- normalizePath(if (nzchar(repo_root)) repo_root else getwd(), mustWork = TRUE)
  config_path <- normalizePath(cli[["config"]] %||% file.path(repo_root, "config", "rqr_desn", "rqr_desn_article_congruent_simulation_20260718.R"), mustWork = TRUE)
  config <- source_config(config_path)
  smoke <- as_flag(cli[["smoke"]], FALSE)
  if (!smoke && !as_flag(cli[["confirm-full-launch"]], FALSE)) {
    stop("Full article-congruent RQR-DESN simulation requires --confirm-full-launch true. Use --smoke true for validation slices.", call. = FALSE)
  }
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  short_sha <- substr(git_value(repo_root, "rev-parse", "HEAD"), 1L, 12L)
  output_dir <- normalizePath(cli[["output-dir"]] %||% file.path(repo_root, config$output_contract$output_root, sprintf("run_%s_git_%s", stamp, short_sha)), mustWork = FALSE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  materialize_manifest(repo_root, config_path, output_dir)
  scenarios <- read_csv(file.path(output_dir, "scenario_manifest.csv"))
  selected <- filter_manifest(scenarios, cli)
  if (smoke && nrow(selected) > as.integer(config$smoke_control$max_scenarios)) {
    selected <- selected[seq_len(as.integer(config$smoke_control$max_scenarios)), , drop = FALSE]
  }
  if (!nrow(selected)) stop("No scenarios selected.", call. = FALSE)
  write_csv(selected, file.path(output_dir, "launch_manifest.csv"))
  writeLines(capture.output(sessionInfo()), file.path(output_dir, "session_info.txt"))
  writeLines(c("$ git status --short --branch", git_value(repo_root, "status", "--short", "--branch"), "", "$ git log --oneline -5", git_value(repo_root, "log", "--oneline", "-5")), file.path(output_dir, "git_state.txt"))
  load_package(repo_root)
  group_key <- paste(selected$stage_id, selected$family_id, selected$replicate_id, sep = "__")
  groups <- split(seq_len(nrow(selected)), group_key)
  for (idx in groups) {
    data <- make_data(selected[idx[1L], , drop = FALSE], config)
    for (ii in idx) run_one(selected[ii, , drop = FALSE], data, config, cli)
  }
  aggregate_outputs(output_dir, selected)
  write_hashes(output_dir)
  message(sprintf("RQR-DESN article-congruent run completed selected rows in %s", output_dir))
  invisible(output_dir)
}

if (sys.nframe() == 0L) main()

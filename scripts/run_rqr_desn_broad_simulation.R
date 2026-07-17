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

as_int <- function(x, default = NA_integer_) {
  if (is.null(x)) return(default)
  out <- suppressWarnings(as.integer(x[1L]))
  if (!is.finite(out)) stop(sprintf("Expected integer, got: %s", x[1L]), call. = FALSE)
  out
}

as_num <- function(x, default = NA_real_) {
  if (is.null(x)) return(default)
  out <- suppressWarnings(as.numeric(x[1L]))
  if (!is.finite(out) && !is.na(out)) stop(sprintf("Expected numeric, got: %s", x[1L]), call. = FALSE)
  out
}

as_bool_value <- function(x, default = FALSE) {
  if (is.null(x) || length(x) == 0L || is.na(x[1L])) return(default)
  if (is.logical(x)) return(isTRUE(x[1L]))
  value <- tolower(trimws(as.character(x[1L])))
  if (value %in% c("true", "t", "1", "yes", "y")) return(TRUE)
  if (value %in% c("false", "f", "0", "no", "n")) return(FALSE)
  default
}

split_cli_vec <- function(x) {
  if (is.null(x) || !nzchar(as.character(x)[1L])) return(NULL)
  trimws(strsplit(as.character(x)[1L], ",", fixed = TRUE)[[1L]])
}

is_naish <- function(x) {
  length(x) == 0L || is.na(x) || !nzchar(as.character(x)[1L])
}

git_value <- function(repo_root, ...) {
  value <- tryCatch(
    system2("git", c("-C", repo_root, ...), stdout = TRUE, stderr = TRUE),
    error = function(e) character(0)
  )
  paste(value, collapse = "\n")
}

write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, file = path, row.names = FALSE, na = "")
}

read_csv_safe <- function(path) {
  if (!file.exists(path)) return(NULL)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

source_config <- function(config_path) {
  env <- new.env(parent = baseenv())
  sys.source(config_path, envir = env)
  get("rqr_desn_broad_simulation_config", envir = env)
}

stable_list_string <- function(x) {
  if (is.null(x)) return("NULL")
  if (!is.list(x)) return(paste(as.character(x), collapse = ","))
  nms <- names(x) %||% rep("", length(x))
  if (length(nms) && all(nzchar(nms))) {
    ord <- order(nms)
    nms <- nms[ord]
    x <- x[ord]
  }
  paste(vapply(seq_along(x), function(ii) {
    nm <- nms[[ii]]
    value <- stable_list_string(x[[ii]])
    if (nzchar(nm)) paste0(nm, "=", value) else value
  }, character(1)), collapse = ";")
}

sanitize_id <- function(x) {
  x <- tolower(as.character(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  ifelse(nzchar(x), x, "na")
}

interval_score <- function(y, lower, upper, coverage_level) {
  alpha <- 1 - coverage_level
  (upper - lower) +
    (2 / alpha) * pmax(lower - y, 0) +
    (2 / alpha) * pmax(y - upper, 0)
}

central_empirical_baseline <- function(y_train, n_test, coverage_level) {
  probs <- c((1 - coverage_level) / 2, 1 - (1 - coverage_level) / 2)
  qs <- as.numeric(stats::quantile(y_train, probs = probs, names = FALSE, type = 8))
  list(lower = rep(qs[1L], n_test), upper = rep(qs[2L], n_test))
}

make_fixed_design_data <- function(family_id, seed, n_train, n_test) {
  set.seed(as.integer(seed)[1L])
  n <- n_train + n_test
  x <- seq(-1, 1, length.out = n)
  mu <- 0.15 + 0.5 * x

  if (identical(family_id, "symmetric_linear")) {
    sigma <- rep(0.35, n)
    y <- mu + sigma * stats::rnorm(n)
    endpoint <- function(coverage_level) {
      q <- stats::qnorm((1 + coverage_level) / 2)
      idx <- (n_train + 1L):n
      list(
        lower = mu[idx] - q * sigma[idx],
        upper = mu[idx] + q * sigma[idx],
        midpoint = mu[idx]
      )
    }
  } else if (identical(family_id, "skewed_linear")) {
    scale <- 0.30
    y <- mu + scale * (stats::rexp(n, rate = 1) - 1)
    endpoint <- function(coverage_level) {
      lo_p <- (1 - coverage_level) / 2
      hi_p <- 1 - lo_p
      idx <- (n_train + 1L):n
      list(
        lower = mu[idx] + scale * (stats::qexp(lo_p, rate = 1) - 1),
        upper = mu[idx] + scale * (stats::qexp(hi_p, rate = 1) - 1),
        midpoint = mu[idx] + scale * ((stats::qexp(lo_p, rate = 1) + stats::qexp(hi_p, rate = 1)) / 2 - 1)
      )
    }
  } else if (identical(family_id, "heavy_tail_linear")) {
    df <- 3
    scale <- 0.24
    y <- mu + scale * stats::rt(n, df = df)
    endpoint <- function(coverage_level) {
      lo_p <- (1 - coverage_level) / 2
      hi_p <- 1 - lo_p
      idx <- (n_train + 1L):n
      list(
        lower = mu[idx] + scale * stats::qt(lo_p, df = df),
        upper = mu[idx] + scale * stats::qt(hi_p, df = df),
        midpoint = mu[idx]
      )
    }
  } else if (identical(family_id, "heteroskedastic_linear")) {
    sigma <- 0.16 + 0.32 * abs(x)
    y <- mu + sigma * stats::rnorm(n)
    endpoint <- function(coverage_level) {
      q <- stats::qnorm((1 + coverage_level) / 2)
      idx <- (n_train + 1L):n
      list(
        lower = mu[idx] - q * sigma[idx],
        upper = mu[idx] + q * sigma[idx],
        midpoint = mu[idx]
      )
    }
  } else {
    stop(sprintf("Unknown fixed-design family: %s", family_id), call. = FALSE)
  }

  X <- cbind("(Intercept)" = 1, x = x)
  list(
    X_train = X[seq_len(n_train), , drop = FALSE],
    y_train = y[seq_len(n_train)],
    X_test = X[(n_train + 1L):n, , drop = FALSE],
    y_test = y[(n_train + 1L):n],
    oracle = endpoint,
    dgp_midpoint_available = TRUE
  )
}

make_dynamic_series <- function(family_id, seed, n_total) {
  set.seed(as.integer(seed)[1L])
  y <- numeric(n_total)
  y[1L] <- stats::rnorm(1, sd = 0.2)
  if (identical(family_id, "nonlinear_dynamic")) {
    for (tt in 2:n_total) {
      signal <- 0.50 * y[tt - 1L] + 0.25 * sin(1.5 * y[tt - 1L]) + 0.30 * sin(tt / 8)
      y[tt] <- signal + 0.18 * stats::rnorm(1)
    }
  } else if (identical(family_id, "regime_shift_dynamic")) {
    cut <- floor(0.55 * n_total)
    for (tt in 2:n_total) {
      phi <- if (tt <= cut) 0.55 else -0.20
      shift <- if (tt <= cut) 0 else 0.55
      y[tt] <- shift + phi * y[tt - 1L] + 0.22 * sin(tt / 9) + 0.20 * stats::rnorm(1)
    }
  } else {
    stop(sprintf("Unknown dynamic family: %s", family_id), call. = FALSE)
  }
  y
}

normalize_qdesn_design_args <- function(design) {
  D <- as.integer(design$DESN_D)[1L]
  if (!is.finite(D) || D < 1L) stop("DESN_D must be a positive integer.", call. = FALSE)
  n_vec <- as.integer(design$DESN_n)[1L]
  if (!is.finite(n_vec) || n_vec < 1L) stop("DESN_n must be a positive integer.", call. = FALSE)
  n_vec <- rep(n_vec, D)
  n_tilde <- if (D == 1L) integer(0) else pmax(1L, as.integer(head(n_vec, -1L) / 2L))
  alpha_vec <- rep(as.numeric(design$alpha)[1L], D)
  rho_vec <- rep(as.numeric(design$rho)[1L], D)
  if (any(!is.finite(alpha_vec)) || any(alpha_vec <= 0 | alpha_vec >= 1)) {
    stop("DESN alpha must be finite and in (0, 1).", call. = FALSE)
  }
  if (any(!is.finite(rho_vec)) || any(rho_vec <= 0 | rho_vec >= 1)) {
    stop("DESN rho must be finite and in (0, 1).", call. = FALSE)
  }
  list(D = D, n = n_vec, n_tilde = n_tilde, alpha = alpha_vec, rho = rho_vec)
}

make_dynamic_data <- function(family_id, design, dgp_seed, design_seed, n_train, n_test) {
  washout <- as.integer(design$washout %||% 0L)[1L]
  if (!is.finite(washout) || washout < 0L) washout <- 0L
  n_total <- washout + n_train + n_test
  y <- make_dynamic_series(family_id, dgp_seed, n_total)

  if (identical(as.character(design$design_id %||% "none"), "none")) {
    y_fit <- y[(washout + 1L):n_total]
    return(list(
      X_train = NULL,
      y_train = y_fit[seq_len(n_train)],
      X_test = NULL,
      y_test = y_fit[(n_train + 1L):(n_train + n_test)],
      oracle = function(coverage_level) list(lower = NULL, upper = NULL, midpoint = NULL),
      dgp_midpoint_available = FALSE
    ))
  }

  qdesn_args <- normalize_qdesn_design_args(design)
  shell <- exdqlm::qdesn_fit_vb(
    y = y,
    p0 = 0.5,
    fit_readout = FALSE,
    vb_args = list(),
    D = qdesn_args$D,
    n = qdesn_args$n,
    n_tilde = qdesn_args$n_tilde,
    m = as.integer(design$DESN_m)[1L],
    alpha = qdesn_args$alpha,
    rho = qdesn_args$rho,
    act_f = as.character(design$act_f)[1L],
    act_k = as.character(design$act_k)[1L],
    pi_w = as.numeric(design$pi_w)[1L],
    pi_in = as.numeric(design$pi_in)[1L],
    washout = washout,
    add_bias = as_bool_value(design$add_bias, default = FALSE),
    seed = as.integer(design_seed)[1L]
  )
  if (nrow(shell$X) < n_train + n_test) {
    stop("DESN shell produced fewer design rows than required.", call. = FALSE)
  }
  if (all(abs(shell$X) <= sqrt(.Machine$double.eps))) {
    stop("DESN shell is all-zero; broad runner requires a nondegenerate design.", call. = FALSE)
  }

  list(
    X_train = shell$X[seq_len(n_train), , drop = FALSE],
    y_train = shell$y_fit[seq_len(n_train)],
    X_test = shell$X[(n_train + 1L):(n_train + n_test), , drop = FALSE],
    y_test = shell$y_fit[(n_train + 1L):(n_train + n_test)],
    oracle = function(coverage_level) list(lower = NULL, upper = NULL, midpoint = NULL),
    dgp_midpoint_available = FALSE
  )
}

derive_dgp_seed <- function(row, config) {
  as.integer(config$randomization$seed_base) +
    1000000L +
    as.integer(row$stage_index) * 100000L +
    as.integer(row$family_index) * 10000L +
    as.integer(row$replicate_id)
}

derive_design_seed <- function(row, config) {
  derive_dgp_seed(row, config) + 1000L + as.integer(row$design_index %||% 0L)
}

row_scalar <- function(row, name, default = NA) {
  if (!name %in% names(row)) return(default)
  row[[name]][1L]
}

metric_row <- function(row, data, lower, upper, midpoint, oracle, runtime_sec,
                       dgp_seed, design_seed) {
  y <- as.numeric(data$y_test)
  lower <- as.numeric(lower)
  upper <- as.numeric(upper)
  midpoint <- midpoint %||% (0.5 * (lower + upper))
  finite_lower <- all(is.finite(lower))
  finite_upper <- all(is.finite(upper))
  ordered <- all(upper >= lower)
  width <- upper - lower
  coverage_level <- as.numeric(row$coverage_level)
  score <- interval_score(y, lower, upper, coverage_level)

  endpoint_mae <- NA_real_
  if (!is.null(oracle$lower) && !is.null(oracle$upper)) {
    endpoint_mae <- mean(abs(lower - oracle$lower) + abs(upper - oracle$upper)) / 2
  }
  midpoint_target <- if (!is.null(oracle$midpoint)) oracle$midpoint else y

  data.frame(
    scenario_id = row$scenario_id,
    stage_id = row$stage_id,
    family_id = row$family_id,
    design_id = row$design_id,
    backend_id = row$backend_id,
    inference = row$inference,
    prior_type = row$prior_type,
    replicate_id = as.integer(row$replicate_id),
    seed = as.integer(row$seed),
    dgp_seed = as.integer(dgp_seed),
    design_seed = as.integer(design_seed),
    coverage_level = coverage_level,
    learning_rate = as.numeric(row$learning_rate),
    n_train = length(data$y_train),
    n_test = length(data$y_test),
    endpoint_summary = if (!is.null(oracle$lower) && !is.null(oracle$upper)) "oracle" else "heldout_only",
    empirical_coverage = mean(y >= lower & y <= upper),
    mean_width = mean(width),
    interval_score_mean = mean(score),
    midpoint_mae = mean(abs(as.numeric(midpoint) - midpoint_target)),
    endpoint_mae = endpoint_mae,
    finite_lower = finite_lower,
    finite_upper = finite_upper,
    ordered_intervals = ordered,
    positive_mean_width = is.finite(mean(width)) && mean(width) > 0,
    runtime_sec = as.numeric(runtime_sec),
    response_likelihood = FALSE,
    response_predictive_draws = FALSE,
    recursive_response_sampling = FALSE,
    stringsAsFactors = FALSE
  )
}

fit_summary_row <- function(row, fit, data, runtime_sec) {
  core <- if (inherits(fit, "rqr_desn_fit")) fit$fit else fit
  data.frame(
    scenario_id = row$scenario_id,
    stage_id = row$stage_id,
    backend_id = row$backend_id,
    inference = row$inference,
    prior_type = row$prior_type,
    method = as.character(core$method %||% NA_character_),
    family = as.character(core$family %||% NA_character_),
    n_design_rows = if (is.null(data$X_train)) NA_integer_ else nrow(data$X_train),
    n_design_cols = if (is.null(data$X_train)) NA_integer_ else ncol(data$X_train),
    beta_prior = as.character(core$beta_prior$type %||% NA_character_),
    response_likelihood = isTRUE(core$model_spec$response_likelihood),
    generalized_bayes = isTRUE(core$model_spec$generalized_bayes),
    runtime_sec = as.numeric(runtime_sec),
    stringsAsFactors = FALSE
  )
}

mcmc_diagnostics_row <- function(row, fit) {
  loss <- as.numeric(fit$diagnostics$loss_trace %||% NA_real_)
  loss <- loss[is.finite(loss)]
  tail_n <- min(100L, length(loss))
  ps1 <- as.character(fit$diagnostics$precision_strategy_root1 %||% NA_character_)
  ps2 <- as.character(fit$diagnostics$precision_strategy_root2 %||% NA_character_)
  data.frame(
    scenario_id = row$scenario_id,
    n_draws = nrow(fit$samp.beta_root1),
    n_design_cols = ncol(fit$X),
    beta_prior = as.character(fit$beta_prior$type %||% row$prior_type),
    loss_first = if (length(loss)) loss[1L] else NA_real_,
    loss_last = if (length(loss)) loss[length(loss)] else NA_real_,
    loss_tail_mean = if (tail_n) mean(utils::tail(loss, tail_n)) else NA_real_,
    loss_tail_sd = if (tail_n > 1L) stats::sd(utils::tail(loss, tail_n)) else NA_real_,
    precision_strategy_root1 = paste(sort(unique(ps1)), collapse = ";"),
    precision_strategy_root2 = paste(sort(unique(ps2)), collapse = ";"),
    rhs_stats_available = identical(as.character(fit$beta_prior$type %||% ""), "rhs_ns"),
    response_likelihood = isTRUE(fit$model_spec$response_likelihood),
    generalized_bayes = isTRUE(fit$model_spec$generalized_bayes),
    sentinel_chain = FALSE,
    stringsAsFactors = FALSE
  )
}

vb_diagnostics_row <- function(row, fit) {
  delta <- as.numeric(fit$diagnostics$delta_trace %||% NA_real_)
  obj <- as.numeric(fit$diagnostics$objective_trace %||% NA_real_)
  data.frame(
    scenario_id = row$scenario_id,
    n_draws = nrow(fit$draws$beta_root1),
    n_design_cols = ncol(fit$X),
    converged = isTRUE(fit$diagnostics$converged),
    objective_last = if (length(obj)) obj[length(obj)] else NA_real_,
    delta_last = if (length(delta)) delta[length(delta)] else NA_real_,
    calibrated_uncertainty = isTRUE(fit$model_spec$calibrated_uncertainty),
    response_likelihood = isTRUE(fit$model_spec$response_likelihood),
    generalized_bayes = isTRUE(fit$model_spec$generalized_bayes),
    stringsAsFactors = FALSE
  )
}

failure_row <- function(row, stage, class, message, trace_hint = NA_character_) {
  data.frame(
    scenario_id = row$scenario_id,
    stage_id = row$stage_id,
    family_id = row$family_id,
    design_id = row$design_id,
    backend_id = row$backend_id,
    inference = row$inference,
    prior_type = row$prior_type,
    coverage_level = as.numeric(row$coverage_level),
    learning_rate = as.numeric(row$learning_rate),
    failure_stage = stage,
    failure_class = class,
    failure_message = message,
    trace_hint = trace_hint,
    created_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    stringsAsFactors = FALSE
  )
}

status_row <- function(row, status, started_at, finished_at, runtime_sec, message = NA_character_) {
  data.frame(
    scenario_id = row$scenario_id,
    stage_id = row$stage_id,
    family_id = row$family_id,
    design_id = row$design_id,
    backend_id = row$backend_id,
    inference = row$inference,
    prior_type = row$prior_type,
    replicate_id = as.integer(row$replicate_id),
    scenario_index = as.integer(row$scenario_index),
    status = status,
    started_at = started_at,
    finished_at = finished_at,
    runtime_sec = as.numeric(runtime_sec),
    message = message,
    stringsAsFactors = FALSE
  )
}

run_timed <- function(expr) {
  start <- proc.time()[["elapsed"]]
  value <- force(expr)
  elapsed <- proc.time()[["elapsed"]] - start
  list(value = value, elapsed = elapsed)
}

scenario_done <- function(row, rerun_failures = FALSE) {
  status_path <- file.path(row$scenario_output_dir, "scenario_status.csv")
  status <- read_csv_safe(status_path)
  if (is.null(status) || !nrow(status)) return(FALSE)
  terminal <- as.character(status$status[1L])
  if (identical(terminal, "completed")) return(TRUE)
  if (identical(terminal, "failed") && !isTRUE(rerun_failures)) return(TRUE)
  FALSE
}

build_prior <- function(prior_type, config) {
  prior_type <- as.character(prior_type)[1L]
  if (identical(prior_type, "ridge")) {
    hyp <- config$priors$ridge
    return(exdqlm::beta_prior("ridge", ridge = list(tau2 = as.numeric(hyp$tau2 %||% 8))))
  }
  if (identical(prior_type, "rhs_ns")) {
    hyp <- config$priors$rhs_ns
    rhs <- hyp[setdiff(names(hyp), "type")]
    return(exdqlm::beta_prior("rhs_ns", rhs = rhs))
  }
  stop(sprintf("Cannot build beta prior for prior_type=%s", prior_type), call. = FALSE)
}

effective_mcmc_control <- function(row, config, cli) {
  cfg <- config$mcmc_control
  list(
    n_burn = max(0L, as_int(cli[["mcmc-burn"]], as.integer(cfg$n_burn %||% 600L))),
    n_mcmc = max(1L, as_int(cli[["mcmc-keep"]], as.integer(cfg$n_mcmc %||% 900L))),
    thin = max(1L, as_int(cli[["mcmc-thin"]], as.integer(cfg$thin %||% 1L))),
    store_latent_draws = isTRUE(cfg$store_latent_draws),
    precision_beta = cfg$precision_beta %||% list(strategy = "off"),
    seed = as.integer(row$seed),
    verbose = FALSE
  )
}

effective_vb_control <- function(row, config, cli) {
  cfg <- config$vb_control
  list(
    max_iter = max(1L, as_int(cli[["vb-max-iter"]], as.integer(cfg$max_iter %||% 500L))),
    tol = as_num(cli[["vb-tol"]], as.numeric(cfg$tol %||% 1e-5)),
    n_draws = max(20L, as_int(cli[["vb-draws"]], as.integer(cfg$n_draws %||% 1000L))),
    seed = as.integer(row$seed),
    verbose = FALSE
  )
}

predict_from_fit <- function(fit, X_test, seed) {
  exdqlm::predict_interval(fit, X_new = X_test, seed = as.integer(seed) + 10000L)
}

run_one_scenario <- function(row, data, config, cli) {
  row <- as.data.frame(row, stringsAsFactors = FALSE)
  scenario_dir <- as.character(row$scenario_output_dir[1L])
  dir.create(scenario_dir, recursive = TRUE, showWarnings = FALSE)
  started_at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
  status_path <- file.path(scenario_dir, "scenario_status.csv")
  write_csv(status_row(row, "running", started_at, NA_character_, NA_real_), status_path)

  dgp_seed <- derive_dgp_seed(row, config)
  design_seed <- derive_design_seed(row, config)
  start <- proc.time()[["elapsed"]]
  result <- tryCatch({
    coverage_level <- as.numeric(row$coverage_level)

    if (identical(as.character(row$inference), "baseline")) {
      base <- central_empirical_baseline(data$y_train, length(data$y_test), coverage_level)
      oracle <- data$oracle(coverage_level)
      metric <- metric_row(row, data, base$lower, base$upper, 0.5 * (base$lower + base$upper),
                           oracle, runtime_sec = 0, dgp_seed = dgp_seed, design_seed = design_seed)
      write_csv(metric, file.path(scenario_dir, "interval_metrics.csv"))
      write_csv(data.frame(), file.path(scenario_dir, "fit_summary.csv"))
      write_csv(data.frame(), file.path(scenario_dir, "mcmc_diagnostics.csv"))
      write_csv(data.frame(), file.path(scenario_dir, "vb_diagnostics.csv"))
      write_csv(data.frame(), file.path(scenario_dir, "failure_log.csv"))
      list(status = "completed", message = "baseline completed")
    } else {
      if (is.null(data$X_train) || is.null(data$X_test)) {
        stop("Model scenario requires X_train/X_test but the design is missing.", call. = FALSE)
      }

      fit_timed <- run_timed({
        if (identical(as.character(row$inference), "mcmc")) {
          exdqlm::rqr_mcmc_fit(
            y = data$y_train,
            X = data$X_train,
            coverage_level = coverage_level,
            learning_rate = as.numeric(row$learning_rate),
            beta_prior_obj = build_prior(row$prior_type, config),
            mcmc_control = effective_mcmc_control(row, config, cli)
          )
        } else if (identical(as.character(row$inference), "vb")) {
          exdqlm::rqr_vb_fit(
            y = data$y_train,
            X = data$X_train,
            coverage_level = coverage_level,
            learning_rate = as.numeric(row$learning_rate),
            beta_prior_obj = build_prior("ridge", config),
            vb_control = effective_vb_control(row, config, cli)
          )
        } else {
          stop(sprintf("Unknown inference method: %s", row$inference), call. = FALSE)
        }
      })

      pred <- predict_from_fit(fit_timed$value, data$X_test, as.integer(row$seed))
      oracle <- data$oracle(coverage_level)
      metric <- metric_row(row, data, pred$lower_mean, pred$upper_mean, pred$midpoint_mean,
                           oracle, runtime_sec = fit_timed$elapsed, dgp_seed = dgp_seed, design_seed = design_seed)
      fit_summary <- fit_summary_row(row, fit_timed$value, data, runtime_sec = fit_timed$elapsed)
      write_csv(metric, file.path(scenario_dir, "interval_metrics.csv"))
      write_csv(fit_summary, file.path(scenario_dir, "fit_summary.csv"))
      if (identical(as.character(row$inference), "mcmc")) {
        write_csv(mcmc_diagnostics_row(row, fit_timed$value), file.path(scenario_dir, "mcmc_diagnostics.csv"))
        write_csv(data.frame(), file.path(scenario_dir, "vb_diagnostics.csv"))
      } else {
        write_csv(data.frame(), file.path(scenario_dir, "mcmc_diagnostics.csv"))
        write_csv(vb_diagnostics_row(row, fit_timed$value), file.path(scenario_dir, "vb_diagnostics.csv"))
      }
      write_csv(data.frame(), file.path(scenario_dir, "failure_log.csv"))
      list(status = "completed", message = "model completed")
    }
  }, error = function(e) {
    fail <- failure_row(row, "fit_or_score", class(e)[1L], conditionMessage(e))
    write_csv(fail, file.path(scenario_dir, "failure_log.csv"))
    write_csv(data.frame(), file.path(scenario_dir, "interval_metrics.csv"))
    write_csv(data.frame(), file.path(scenario_dir, "fit_summary.csv"))
    write_csv(data.frame(), file.path(scenario_dir, "mcmc_diagnostics.csv"))
    write_csv(data.frame(), file.path(scenario_dir, "vb_diagnostics.csv"))
    list(status = "failed", message = conditionMessage(e))
  })
  elapsed <- proc.time()[["elapsed"]] - start
  finished_at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
  write_csv(status_row(row, result$status, started_at, finished_at, elapsed, result$message), status_path)
  result$status
}

write_setup_failure_scenario <- function(row, message) {
  row <- as.data.frame(row, stringsAsFactors = FALSE)
  scenario_dir <- as.character(row$scenario_output_dir[1L])
  dir.create(scenario_dir, recursive = TRUE, showWarnings = FALSE)
  started_at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
  fail <- failure_row(row, "data_or_design_setup", "setup_error", message)
  write_csv(fail, file.path(scenario_dir, "failure_log.csv"))
  write_csv(data.frame(), file.path(scenario_dir, "interval_metrics.csv"))
  write_csv(data.frame(), file.path(scenario_dir, "fit_summary.csv"))
  write_csv(data.frame(), file.path(scenario_dir, "mcmc_diagnostics.csv"))
  write_csv(data.frame(), file.path(scenario_dir, "vb_diagnostics.csv"))
  write_csv(
    status_row(row, "failed", started_at, format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), 0, message),
    file.path(scenario_dir, "scenario_status.csv")
  )
  "failed"
}

load_design_row <- function(design_manifest, row) {
  if (identical(as.character(row$design_id), "none")) {
    return(list(design_id = "none", design_type = "none", washout = NA_integer_))
  }
  idx <- which(
    as.character(design_manifest$stage_id) == as.character(row$stage_id) &
      as.character(design_manifest$design_id) == as.character(row$design_id)
  )
  if (!length(idx)) {
    stop(sprintf("Missing design_manifest row for stage=%s design=%s", row$stage_id, row$design_id), call. = FALSE)
  }
  as.list(design_manifest[idx[1L], , drop = FALSE])
}

load_dgp_row <- function(dgp_manifest, row) {
  idx <- which(
    as.character(dgp_manifest$stage_id) == as.character(row$stage_id) &
      as.character(dgp_manifest$family_id) == as.character(row$family_id)
  )
  if (!length(idx)) {
    stop(sprintf("Missing dgp_manifest row for stage=%s family=%s", row$stage_id, row$family_id), call. = FALSE)
  }
  as.list(dgp_manifest[idx[1L], , drop = FALSE])
}

make_data_for_group <- function(row, dgp_manifest, design_manifest, config) {
  row <- as.data.frame(row, stringsAsFactors = FALSE)
  dgp <- load_dgp_row(dgp_manifest, row)
  design <- load_design_row(design_manifest, row)
  n_train <- as.integer(dgp$n_train)[1L]
  n_test <- as.integer(dgp$n_test)[1L]
  dgp_seed <- derive_dgp_seed(row, config)
  design_seed <- derive_design_seed(row, config)

  if (identical(as.character(row$stage_id), "fixed_design_calibration")) {
    return(make_fixed_design_data(row$family_id, dgp_seed, n_train, n_test))
  }
  if (identical(as.character(row$stage_id), "teacher_forced_desn_dynamic")) {
    return(make_dynamic_data(row$family_id, design, dgp_seed, design_seed, n_train, n_test))
  }
  stop(sprintf("Unknown stage_id: %s", row$stage_id), call. = FALSE)
}

group_key <- function(df) {
  paste(
    as.character(df$stage_id),
    as.character(df$family_id),
    as.character(df$replicate_id),
    as.character(df$design_id),
    sep = "__"
  )
}

filter_scenarios <- function(df, cli) {
  filters <- list(
    stage_id = split_cli_vec(cli[["stage-id"]]),
    family_id = split_cli_vec(cli[["family-id"]]),
    inference = split_cli_vec(cli[["inference"]]),
    backend_id = split_cli_vec(cli[["backend-id"]]),
    scenario_id = split_cli_vec(cli[["scenario-id"]])
  )
  for (nm in names(filters)) {
    allowed <- filters[[nm]]
    if (!is.null(allowed)) df <- df[df[[nm]] %in% allowed, , drop = FALSE]
  }
  idx_min <- as_int(cli[["scenario-index-min"]], NA_integer_)
  idx_max <- as_int(cli[["scenario-index-max"]], NA_integer_)
  if (is.finite(idx_min)) df <- df[as.integer(df$scenario_index) >= idx_min, , drop = FALSE]
  if (is.finite(idx_max)) df <- df[as.integer(df$scenario_index) <= idx_max, , drop = FALSE]
  max_scenarios <- as_int(cli[["max-scenarios"]], NA_integer_)
  if (is.finite(max_scenarios) && max_scenarios > 0L && nrow(df) > max_scenarios) {
    df <- df[seq_len(max_scenarios), , drop = FALSE]
  }
  rownames(df) <- NULL
  df
}

materialize_preflight_if_needed <- function(repo_root, config_path, output_dir) {
  manifest_path <- file.path(output_dir, "scenario_manifest.csv")
  if (file.exists(manifest_path)) return(invisible(TRUE))
  script <- file.path(repo_root, "scripts", "materialize_rqr_desn_broad_scenario_manifest.R")
  args <- c(script, "--config", config_path, "--output-dir", output_dir, "--repo-root", repo_root)
  output <- system2(file.path(R.home("bin"), "Rscript"), args, stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status", exact = TRUE) %||% 0L
  if (!identical(as.integer(status), 0L)) {
    stop(sprintf("Manifest materialization failed:\n%s", paste(output, collapse = "\n")), call. = FALSE)
  }
  invisible(TRUE)
}

install_package_if_requested <- function(repo_root, output_dir, cli) {
  install_package <- as_flag(cli[["install-package"]], default = FALSE)
  lib_path <- cli[["lib-path"]] %||% NULL
  if (isTRUE(install_package)) {
    lib_path <- lib_path %||% file.path(output_dir, "package_lib")
    dir.create(lib_path, recursive = TRUE, showWarnings = FALSE)
    log_path <- file.path(output_dir, "package_install.log")
    output <- system2(
      file.path(R.home("bin"), "R"),
      c("CMD", "INSTALL", sprintf("--library=%s", lib_path), "--no-multiarch", "--with-keep.source", repo_root),
      stdout = TRUE,
      stderr = TRUE
    )
    writeLines(output, log_path)
    status <- attr(output, "status", exact = TRUE) %||% 0L
    if (!identical(as.integer(status), 0L)) {
      stop(sprintf("Package installation failed; see %s", log_path), call. = FALSE)
    }
  }
  if (!is.null(lib_path)) {
    .libPaths(c(normalizePath(lib_path, mustWork = TRUE), .libPaths()))
  }
  invisible(lib_path)
}

needs_exdqlm <- function(df) {
  any(as.character(df$inference) != "baseline")
}

combine_csvs <- function(paths) {
  paths <- paths[file.exists(paths)]
  if (!length(paths)) return(data.frame())
  parts <- lapply(paths, function(path) {
    x <- tryCatch(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) data.frame())
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

ensure_schema <- function(x, schema_path) {
  if (nrow(x) || !file.exists(schema_path)) return(x)
  schema <- tryCatch(utils::read.csv(schema_path, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) data.frame())
  if (!ncol(schema)) return(x)
  schema[0, , drop = FALSE]
}

write_hashes <- function(output_dir) {
  files <- list.files(output_dir, full.names = TRUE, recursive = FALSE)
  files <- files[file.info(files)$isdir %in% FALSE]
  files <- files[basename(files) != "output_hashes.csv"]
  hash_df <- data.frame(
    file = basename(files),
    md5 = unname(tools::md5sum(files)),
    stringsAsFactors = FALSE
  )
  write_csv(hash_df, file.path(output_dir, "output_hashes.csv"))
  invisible(hash_df)
}

aggregate_outputs <- function(output_dir, selected_manifest) {
  scenario_dirs <- as.character(selected_manifest$scenario_output_dir)
  metrics <- combine_csvs(file.path(scenario_dirs, "interval_metrics.csv"))
  fits <- combine_csvs(file.path(scenario_dirs, "fit_summary.csv"))
  mcmc_diag <- combine_csvs(file.path(scenario_dirs, "mcmc_diagnostics.csv"))
  vb_diag <- combine_csvs(file.path(scenario_dirs, "vb_diagnostics.csv"))
  failures <- combine_csvs(file.path(scenario_dirs, "failure_log.csv"))
  statuses <- combine_csvs(file.path(scenario_dirs, "scenario_status.csv"))

  metrics <- ensure_schema(metrics, file.path(output_dir, "interval_metrics.csv"))
  fits <- ensure_schema(fits, file.path(output_dir, "fit_summary.csv"))
  mcmc_diag <- ensure_schema(mcmc_diag, file.path(output_dir, "mcmc_diagnostics.csv"))
  vb_diag <- ensure_schema(vb_diag, file.path(output_dir, "vb_diagnostics.csv"))
  failures <- ensure_schema(failures, file.path(output_dir, "failure_log.csv"))

  write_csv(metrics, file.path(output_dir, "interval_metrics.csv"))
  write_csv(fits, file.path(output_dir, "fit_summary.csv"))
  write_csv(mcmc_diag, file.path(output_dir, "mcmc_diagnostics.csv"))
  write_csv(vb_diag, file.path(output_dir, "vb_diagnostics.csv"))
  write_csv(failures, file.path(output_dir, "failure_log.csv"))
  write_csv(statuses, file.path(output_dir, "run_status.csv"))

  if (nrow(metrics)) {
    group_cols <- c("stage_id", "family_id", "backend_id", "inference", "prior_type", "coverage_level", "learning_rate")
    value_cols <- c("empirical_coverage", "mean_width", "interval_score_mean", "midpoint_mae", "endpoint_mae", "runtime_sec")
    summary_groups <- metrics[group_cols]
    for (nm in group_cols) {
      summary_groups[[nm]] <- as.character(summary_groups[[nm]])
      missing <- is.na(summary_groups[[nm]]) | !nzchar(summary_groups[[nm]])
      summary_groups[[nm]][missing] <- "not_applicable"
    }
    summary <- stats::aggregate(metrics[value_cols], by = summary_groups, FUN = function(x) {
      if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
    })
    summary$n_rows <- as.integer(stats::aggregate(metrics$scenario_id, by = summary_groups, FUN = length)$x)
  } else {
    summary <- data.frame()
  }
  write_csv(summary, file.path(output_dir, "metric_summary.csv"))

  terminal <- statuses$status %in% c("completed", "failed")
  completed <- sum(statuses$status == "completed", na.rm = TRUE)
  failed <- sum(statuses$status == "failed", na.rm = TRUE)
  selected_n <- nrow(selected_manifest)
  completed_all <- completed + failed >= selected_n
  metric_rows <- nrow(metrics)
  failure_rows <- nrow(failures)
  model_metrics <- metrics[as.character(metrics$inference) != "baseline", , drop = FALSE]
  finite_ordered <- if (nrow(model_metrics)) {
    all(as.logical(model_metrics$finite_lower)) &&
      all(as.logical(model_metrics$finite_upper)) &&
      all(as.logical(model_metrics$ordered_intervals)) &&
      all(as.logical(model_metrics$positive_mean_width))
  } else {
    NA
  }

  closeout <- c(
    "# RQR-DESN Broad Simulation Closeout",
    "",
    sprintf("Created: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    sprintf("Output directory: `%s`", output_dir),
    "",
    "## Status",
    "",
    sprintf("- selected scenario rows: `%d`", selected_n),
    sprintf("- completed rows: `%d`", completed),
    sprintf("- failed rows: `%d`", failed),
    sprintf("- terminal rows: `%d`", sum(terminal, na.rm = TRUE)),
    sprintf("- metric rows: `%d`", metric_rows),
    sprintf("- failure-log rows: `%d`", failure_rows),
    sprintf("- completed_all_selected: `%s`", completed_all),
    sprintf("- finite_ordered_positive_model_intervals: `%s`", finite_ordered),
    "",
    "## Interpretation Guard",
    "",
    "This artifact is package-side RQR-DESN interval evidence. It is not a response",
    "predictive likelihood study and it does not authorize article updates by itself.",
    "VB rows remain sidecar diagnostics unless a separate calibration study is run.",
    "",
    "## Metric Summary",
    "",
    if (nrow(summary)) paste(capture.output(print(summary, row.names = FALSE)), collapse = "\n") else "No metric rows have been written yet."
  )
  writeLines(closeout, file.path(output_dir, "closeout.md"))
  write_hashes(output_dir)
  invisible(list(
    metrics = metrics,
    failures = failures,
    statuses = statuses,
    summary = summary,
    completed_all = completed_all
  ))
}

write_run_readme <- function(output_dir) {
  lines <- c(
    "# RQR-DESN Broad Simulation Run",
    "",
    "Generated by `scripts/run_rqr_desn_broad_simulation.R`.",
    "",
    "This is package-side interval-model evidence. It is not article evidence until a",
    "separate closeout decision promotes a documented subset.",
    "",
    "Key files:",
    "",
    "- `manifest.csv`: no-fit denominator/provenance from manifest preflight.",
    "- `launch_manifest.csv`: scenario rows selected for this run invocation.",
    "- `run_status.csv`: terminal status rows collected from scenario directories.",
    "- `interval_metrics.csv`: aggregated interval metrics.",
    "- `fit_summary.csv`: aggregated fit metadata.",
    "- `mcmc_diagnostics.csv`: aggregated MCMC diagnostics.",
    "- `vb_diagnostics.csv`: aggregated VB diagnostics.",
    "- `failure_log.csv`: explicit failures.",
    "- `metric_summary.csv`: aggregate performance summary.",
    "- `closeout.md`: human-readable closeout."
  )
  writeLines(lines, file.path(output_dir, "README.md"))
}

rqr_desn_broad_run_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  cli <- parse_cli(args)
  repo_root <- cli[["repo-root"]] %||% git_value(getwd(), "rev-parse", "--show-toplevel")
  if (!nzchar(repo_root)) repo_root <- getwd()
  repo_root <- normalizePath(repo_root, mustWork = TRUE)
  config_path <- cli[["config"]] %||% file.path(repo_root, "config", "rqr_desn", "rqr_desn_broad_simulation_frozen_20260716_v2.R")
  config_path <- normalizePath(config_path, mustWork = TRUE)
  config <- source_config(config_path)
  short_sha <- substr(git_value(repo_root, "rev-parse", "HEAD"), 1L, 12L)
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  output_root <- if (as_flag(cli[["smoke"]], default = FALSE)) {
    "reports/rqr_desn_broad_simulation_smoke"
  } else {
    config$output_contract$output_root %||% "reports/rqr_desn_broad_simulation"
  }
  default_output_dir <- file.path(repo_root, output_root, sprintf("rqr_desn_broad_run_%s_git_%s", stamp, short_sha))
  output_dir <- normalizePath(cli[["output-dir"]] %||% default_output_dir, mustWork = FALSE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  materialize_preflight_if_needed(repo_root, config_path, output_dir)
  scenario_manifest <- read_csv_safe(file.path(output_dir, "scenario_manifest.csv"))
  dgp_manifest <- read_csv_safe(file.path(output_dir, "dgp_manifest.csv"))
  design_manifest <- read_csv_safe(file.path(output_dir, "design_manifest.csv"))
  if (is.null(scenario_manifest) || is.null(dgp_manifest) || is.null(design_manifest)) {
    stop("Required manifest files are missing after preflight materialization.", call. = FALSE)
  }

  selected <- filter_scenarios(scenario_manifest, cli)
  if (!nrow(selected)) stop("No scenario rows selected for run.", call. = FALSE)
  write_csv(selected, file.path(output_dir, "launch_manifest.csv"))
  write_run_readme(output_dir)
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

  install_package_if_requested(repo_root, output_dir, cli)
  if (needs_exdqlm(selected)) {
    suppressPackageStartupMessages(library(exdqlm))
  }

  force <- as_flag(cli[["force"]], default = FALSE)
  rerun_failures <- as_flag(cli[["rerun-failures"]], default = FALSE)
  if (!isTRUE(force)) {
    keep <- !vapply(seq_len(nrow(selected)), function(ii) {
      scenario_done(selected[ii, , drop = FALSE], rerun_failures = rerun_failures)
    }, logical(1))
    todo <- selected[keep, , drop = FALSE]
  } else {
    todo <- selected
  }

  if (!nrow(todo)) {
    aggregate_outputs(output_dir, selected)
    message(sprintf("RQR-DESN broad run has no pending scenarios in %s", output_dir))
    return(invisible(output_dir))
  }

  workers <- max(1L, as_int(cli[["workers"]], 1L))
  keys <- group_key(todo)
  group_ids <- split(seq_len(nrow(todo)), keys)
  run_group <- function(idx) {
    group_rows <- todo[idx, , drop = FALSE]
    first <- group_rows[1L, , drop = FALSE]
    data <- tryCatch(
      make_data_for_group(first, dgp_manifest, design_manifest, config),
      error = function(e) e
    )
    if (inherits(data, "error")) {
      msg <- conditionMessage(data)
      return(vapply(seq_len(nrow(group_rows)), function(ii) {
        write_setup_failure_scenario(group_rows[ii, , drop = FALSE], msg)
      }, character(1)))
    }
    vapply(seq_len(nrow(group_rows)), function(ii) {
      run_one_scenario(group_rows[ii, , drop = FALSE], data, config, cli)
    }, character(1))
  }

  message(sprintf(
    "RQR-DESN broad run starting %d pending scenarios in %d data groups with %d worker(s): %s",
    nrow(todo), length(group_ids), workers, output_dir
  ))
  if (workers > 1L && .Platform$OS.type != "windows") {
    parallel::mclapply(group_ids, run_group, mc.cores = workers, mc.preschedule = FALSE)
  } else {
    lapply(group_ids, run_group)
  }
  close <- aggregate_outputs(output_dir, selected)
  message(sprintf(
    "RQR-DESN broad run aggregated %d metric rows and %d failure rows in %s",
    nrow(close$metrics), nrow(close$failures), output_dir
  ))
  invisible(output_dir)
}

if (sys.nframe() == 0L) {
  rqr_desn_broad_run_main()
}

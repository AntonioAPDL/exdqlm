`%||%` <- function(a, b) if (is.null(a)) b else a

.qdesn_validation_or <- function(a, b) if (is.null(a)) b else a

.qdesn_validation_require_namespace <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("Package '%s' is required for the Q-DESN validation framework.", pkg), call. = FALSE)
  }
}

.qdesn_validation_repo_root <- function(repo_root = NULL) {
  if (!is.null(repo_root)) {
    return(normalizePath(repo_root, winslash = "/", mustWork = TRUE))
  }
  tryCatch(
    normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
    error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
  )
}

.qdesn_validation_resolve_path <- function(path, repo_root = NULL, must_work = TRUE) {
  if (is.null(path) || !length(path)) return(NULL)
  path <- as.character(path)[1L]
  if (is.na(path)) return(NULL)
  path <- trimws(path)
  if (!nzchar(path)) return(NULL)
  if (grepl("^/", path)) {
    return(normalizePath(path, winslash = "/", mustWork = must_work))
  }
  normalizePath(file.path(.qdesn_validation_repo_root(repo_root), path), winslash = "/", mustWork = must_work)
}

.qdesn_validation_dir_create <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}

.qdesn_validation_write_json <- function(path, x) {
  .qdesn_validation_require_namespace("jsonlite")
  .qdesn_validation_dir_create(dirname(path))
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  invisible(path)
}

.qdesn_validation_read_json_if_exists <- function(path) {
  .qdesn_validation_require_namespace("jsonlite")
  if (!file.exists(path)) return(NULL)
  jsonlite::fromJSON(path, simplifyVector = TRUE)
}

.qdesn_validation_write_lines <- function(path, lines) {
  .qdesn_validation_dir_create(dirname(path))
  writeLines(as.character(lines), con = path, useBytes = TRUE)
  invisible(path)
}

.qdesn_validation_tau_label <- function(x, digits = 2L) {
  sprintf(paste0("%.", as.integer(digits), "f"), as.numeric(x))
}

.qdesn_validation_case_label <- function(scenario, tau, seed = NULL, reservoir_profile = NULL) {
  base <- paste0(as.character(scenario), "\n", "tau=", .qdesn_validation_tau_label(tau))
  if (!is.null(seed) && length(unique(as.integer(seed))) > 1L) {
    base <- paste0(base, "\nseed=", as.integer(seed))
  }
  if (!is.null(reservoir_profile) && length(unique(as.character(reservoir_profile))) > 1L) {
    base <- paste0(base, "\nres=", as.character(reservoir_profile))
  }
  base
}

.qdesn_validation_prob_label <- function(x, digits = 2L) {
  gsub("\\.", "p", format(as.numeric(x)[1L], nsmall = digits, digits = digits + 2L, trim = TRUE))
}

.qdesn_validation_prob_token <- function(x) {
  sprintf("%03d", as.integer(round(as.numeric(x)[1L] * 100)))
}

.qdesn_validation_as_flag <- function(x, default = TRUE) {
  if (is.null(x) || length(x) == 0L || is.na(x[[1L]])) return(default)
  isTRUE(x)
}

.qdesn_validation_resolve_validation_p_vec <- function(root_spec, defaults) {
  pipeline_cfg <- defaults$pipeline %||% list()
  p_raw <- pipeline_cfg$validation_p_vec %||% NULL
  if (is.null(p_raw) || !length(p_raw)) {
    return(as.numeric(root_spec$tau)[1L])
  }
  p_vec <- sort(unique(as.numeric(unlist(p_raw, use.names = FALSE))))
  p_vec <- p_vec[is.finite(p_vec) & p_vec > 0 & p_vec < 1]
  if (!length(p_vec)) {
    return(as.numeric(root_spec$tau)[1L])
  }
  tau <- as.numeric(root_spec$tau)[1L]
  if (is.finite(tau) && tau > 0 && tau < 1 && !any(abs(p_vec - tau) < 1e-12)) {
    p_vec <- sort(unique(c(p_vec, tau)))
  }
  p_vec
}

.qdesn_validation_tau_key <- function(x, digits = 3L) {
  sprintf(paste0("%.", as.integer(digits), "f"), as.numeric(x))
}

.qdesn_validation_git_sha <- function(repo_root = NULL) {
  root <- .qdesn_validation_repo_root(repo_root)
  sha <- tryCatch(
    system2("git", c("-C", root, "rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE),
    error = function(...) character(0)
  )
  if (!length(sha)) return(NA_character_)
  trimws(as.character(sha[[1L]]))
}

qdesn_validation_load_defaults <- function(path = file.path("config", "validation", "qdesn_mcmc_pilot_defaults.yaml"),
                                           repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- yaml::read_yaml(yaml_path)
  if (!is.list(out)) {
    stop("Validation defaults YAML must parse to a list.", call. = FALSE)
  }
  out
}

qdesn_validation_load_grid <- function(path = file.path("config", "validation", "qdesn_mcmc_pilot_grid.csv"),
                                       repo_root = NULL) {
  grid_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- utils::read.csv(grid_path, stringsAsFactors = FALSE)
  if (!nrow(out)) {
    stop("Validation grid CSV is empty.", call. = FALSE)
  }
  out
}

qdesn_validation_build_root_id <- function(root_spec) {
  sprintf(
    "scenario-%s__tau-%s__lik-%s__prior-%s__seed-%s__res-%s",
    as.character(root_spec$scenario)[1L],
    .qdesn_validation_prob_label(root_spec$tau),
    as.character(root_spec$likelihood_family)[1L],
    as.character(root_spec$beta_prior_type)[1L],
    as.integer(root_spec$seed)[1L],
    as.character(root_spec$reservoir_profile)[1L]
  )
}

qdesn_validation_enrich_root_spec <- function(root_spec, defaults) {
  pilot_cfg <- defaults$pilot %||% list()
  scenario <- as.character(root_spec$scenario %||% pilot_cfg$scenario %||% "toy_sine_small")[1L]
  tau <- as.numeric(root_spec$tau %||% pilot_cfg$tau %||% 0.25)[1L]
  likelihood_family <- tolower(as.character(
    root_spec$likelihood_family %||%
      pilot_cfg$likelihood_family %||%
      "exal"
  )[1L])
  beta_prior_type <- tolower(as.character(root_spec$beta_prior_type %||% pilot_cfg$beta_prior_type %||% "rhs_ns")[1L])
  seed <- as.integer(root_spec$seed %||% pilot_cfg$seed %||% 123L)[1L]
  reservoir_profile <- as.character(root_spec$reservoir_profile %||% pilot_cfg$reservoir_profile %||% "tiny_d1_n8")[1L]
  enabled <- .qdesn_validation_as_flag(root_spec$enabled %||% pilot_cfg$enabled, default = TRUE)

  if (!likelihood_family %in% c("exal", "al")) {
    stop(sprintf("Unsupported likelihood_family '%s'.", likelihood_family), call. = FALSE)
  }
  if (!beta_prior_type %in% c("ridge", "rhs", "rhs_ns")) {
    stop(sprintf("Unsupported beta_prior_type '%s'.", beta_prior_type), call. = FALSE)
  }
  if (!is.finite(tau) || tau <= 0 || tau >= 1) {
    stop("Validation tau must lie in (0, 1).", call. = FALSE)
  }
  if (!is.finite(seed)) {
    stop("Validation seed must be finite.", call. = FALSE)
  }

  out <- list(
    scenario = scenario,
    tau = tau,
    likelihood_family = likelihood_family,
    beta_prior_type = beta_prior_type,
    seed = as.integer(seed),
    reservoir_profile = reservoir_profile,
    enabled = enabled
  )
  out$root_id <- as.character(root_spec$root_id %||% qdesn_validation_build_root_id(out))[1L]
  out
}

qdesn_validation_generate_toy_series <- function(scenario = "toy_sine_small",
                                                 seed = 123L,
                                                 p_grid = seq(0.01, 0.99, by = 0.01),
                                                 scenario_cfg = list()) {
  scenario <- as.character(scenario)[1L]
  seed <- as.integer(seed)[1L]
  p_grid <- sort(unique(as.numeric(p_grid)))
  p_grid <- p_grid[is.finite(p_grid) & p_grid > 0 & p_grid < 1]
  if (!length(p_grid)) {
    stop("p_grid must contain at least one probability in (0, 1).", call. = FALSE)
  }

  T_use <- as.integer(scenario_cfg$T_use %||% 96L)[1L]
  n_train <- as.integer(scenario_cfg$n_train %||% max(2L, T_use - 18L))[1L]
  if (!is.finite(T_use) || T_use < 8L) {
    stop("T_use must be at least 8 for validation scenarios.", call. = FALSE)
  }
  if (!is.finite(n_train) || n_train < 2L || n_train >= T_use) {
    n_train <- max(2L, T_use - 18L)
  }
  t <- seq_len(T_use)
  set.seed(seed)

  dynamic_scenarios <- c("dlm_constV_smallW", "dlm_constV_bigW", "dlm_ar1V")
  if (scenario %in% dynamic_scenarios) {
    burnin <- as.integer(scenario_cfg$burnin %||% 500L)[1L]
    if (!is.finite(burnin) || burnin < 0L) burnin <- 500L
    R_mc <- as.integer(scenario_cfg$R_mc %||% 2000L)[1L]
    if (!is.finite(R_mc) || R_mc < 100L) R_mc <- 2000L
    sim_params <- scenario_cfg$params %||% scenario_cfg$sim_params %||% list()

    sim_obj <- simulate_ts_mc_quantiles(
      T = T_use,
      p_grid = p_grid,
      R_mc = R_mc,
      scenario = scenario,
      params = sim_params,
      burnin = burnin,
      seed = seed,
      keep_latents = TRUE,
      keep_draws = FALSE
    )

    y <- as.numeric(sim_obj$y %||% numeric(0))
    q_mat <- as.matrix(sim_obj$q %||% matrix(numeric(0), 0L, 0L))
    if (length(y) != T_use || nrow(q_mat) != T_use || ncol(q_mat) != length(p_grid)) {
      stop(
        sprintf(
          "Dynamic scenario '%s' returned incompatible shapes: length(y)=%d, q=[%d x %d], expected T=%d, K=%d.",
          scenario, length(y), nrow(q_mat), ncol(q_mat), T_use, length(p_grid)
        ),
        call. = FALSE
      )
    }
    mu <- as.numeric((sim_obj$extras %||% list())$mu %||% rep(NA_real_, T_use))
    if (length(mu) != T_use) mu <- rep(NA_real_, T_use)
    scenario_meta <- list(
      name = scenario,
      source = "simulate_ts_mc_quantiles",
      burnin = burnin,
      R_mc = R_mc,
      params = sim_obj$info$params %||% sim_params
    )
  } else if (identical(scenario, "toy_sine_small")) {
    amplitude <- as.numeric(scenario_cfg$amplitude %||% 0.7)[1L]
    period <- as.numeric(scenario_cfg$period %||% 12)[1L]
    noise_sd <- as.numeric(scenario_cfg$noise_sd %||% 0.12)[1L]
    phase <- as.numeric(scenario_cfg$phase %||% 0)[1L]
    mu <- amplitude * sin((2 * pi * (t + phase)) / period)
    y <- as.numeric(mu + stats::rnorm(T_use, sd = noise_sd))
    q_mat <- outer(mu, stats::qnorm(p_grid) * noise_sd, "+")
    scenario_meta <- list(
      name = scenario,
      amplitude = amplitude,
      period = period,
      noise_sd = noise_sd,
      phase = phase
    )
  } else if (identical(scenario, "const_small")) {
    level <- as.numeric(scenario_cfg$level %||% 0.4)[1L]
    noise_sd <- as.numeric(scenario_cfg$noise_sd %||% 0.08)[1L]
    mu <- rep(level, T_use)
    y <- as.numeric(mu + stats::rnorm(T_use, sd = noise_sd))
    q_mat <- outer(mu, stats::qnorm(p_grid) * noise_sd, "+")
    scenario_meta <- list(
      name = scenario,
      level = level,
      noise_sd = noise_sd
    )
  } else if (identical(scenario, "sin_asym_small")) {
    amplitude <- as.numeric(scenario_cfg$amplitude %||% 0.6)[1L]
    period <- as.numeric(scenario_cfg$period %||% 12)[1L]
    phase <- as.numeric(scenario_cfg$phase %||% 0)[1L]
    meanlog <- as.numeric(scenario_cfg$meanlog %||% -0.35)[1L]
    sdlog <- as.numeric(scenario_cfg$sdlog %||% 0.45)[1L]
    noise_scale <- as.numeric(scenario_cfg$noise_scale %||% 0.35)[1L]
    mu <- amplitude * sin((2 * pi * (t + phase)) / period)
    centered_lognorm_mean <- exp(meanlog + 0.5 * sdlog^2)
    eps <- noise_scale * (stats::rlnorm(T_use, meanlog = meanlog, sdlog = sdlog) - centered_lognorm_mean)
    y <- as.numeric(mu + eps)
    q_noise <- noise_scale * (stats::qlnorm(p_grid, meanlog = meanlog, sdlog = sdlog) - centered_lognorm_mean)
    q_mat <- outer(mu, q_noise, "+")
    scenario_meta <- list(
      name = scenario,
      amplitude = amplitude,
      period = period,
      phase = phase,
      meanlog = meanlog,
      sdlog = sdlog,
      noise_scale = noise_scale
    )
  } else if (identical(scenario, "level_shift_small")) {
    break_1 <- as.integer(scenario_cfg$break_1 %||% floor(T_use / 3))[1L]
    break_2 <- as.integer(scenario_cfg$break_2 %||% floor(2 * T_use / 3))[1L]
    level_1 <- as.numeric(scenario_cfg$level_1 %||% 0.15)[1L]
    level_2 <- as.numeric(scenario_cfg$level_2 %||% 0.75)[1L]
    level_3 <- as.numeric(scenario_cfg$level_3 %||% -0.05)[1L]
    noise_sd <- as.numeric(scenario_cfg$noise_sd %||% 0.10)[1L]
    mu <- c(
      rep(level_1, max(1L, break_1)),
      rep(level_2, max(1L, break_2 - break_1)),
      rep(level_3, max(1L, T_use - break_2))
    )
    mu <- as.numeric(mu[seq_len(T_use)])
    y <- as.numeric(mu + stats::rnorm(T_use, sd = noise_sd))
    q_mat <- outer(mu, stats::qnorm(p_grid) * noise_sd, "+")
    scenario_meta <- list(
      name = scenario,
      break_1 = break_1,
      break_2 = break_2,
      level_1 = level_1,
      level_2 = level_2,
      level_3 = level_3,
      noise_sd = noise_sd
    )
  } else {
    stop(sprintf("Unsupported toy validation scenario '%s'.", scenario), call. = FALSE)
  }

  long <- data.frame(
    t = rep(t, each = length(p_grid)),
    p = rep(p_grid, times = T_use),
    q = as.numeric(t(q_mat)),
    y = rep(y, each = length(p_grid)),
    mu = rep(mu, each = length(p_grid)),
    stringsAsFactors = FALSE
  )

  wide <- data.frame(
    t = t,
    y = y,
    mu = mu,
    stringsAsFactors = FALSE
  )
  for (j in seq_along(p_grid)) {
    nm <- paste0("q_", .qdesn_validation_prob_token(p_grid[[j]]))
    wide[[nm]] <- q_mat[, j]
  }

  split_summary <- data.frame(
    T_use = T_use,
    n_train = n_train,
    H_forecast = as.integer(T_use - n_train),
    stringsAsFactors = FALSE
  )

  list(
    long = long,
    wide = wide,
    split = split_summary,
    meta = c(
      list(
        scenario = scenario,
        seed = seed,
        p_grid = p_grid
      ),
      scenario_meta
    )
  )
}

.qdesn_validation_reservoir_cfg <- function(defaults, profile) {
  cfg <- (defaults$reservoir_profiles %||% list())[[profile]]
  if (is.null(cfg)) {
    stop(sprintf("Reservoir profile '%s' not found in validation defaults.", profile), call. = FALSE)
  }
  n_exact <- cfg[["n", exact = TRUE]]
  if (is.null(n_exact) && !is.null(cfg[["FALSE", exact = TRUE]])) {
    cfg[["n"]] <- cfg[["FALSE", exact = TRUE]]
    cfg[["FALSE"]] <- NULL
  }
  cfg$D <- as.integer(cfg[["D", exact = TRUE]] %||% 1L)[1L]
  cfg[["n"]] <- as.integer(unlist(cfg[["n", exact = TRUE]] %||% integer(0), use.names = FALSE))
  cfg$n_tilde <- as.integer(unlist(cfg[["n_tilde", exact = TRUE]] %||% integer(0), use.names = FALSE))
  cfg$m <- as.integer(cfg[["m", exact = TRUE]] %||% 4L)[1L]
  cfg$washout <- as.integer(cfg[["washout", exact = TRUE]] %||% 4L)[1L]
  cfg
}

.qdesn_validation_scenario_cfg <- function(defaults, scenario) {
  cfg <- ((defaults$toy %||% list())$scenarios %||% list())[[scenario]]
  if (is.null(cfg)) {
    stop(sprintf("Toy scenario '%s' not found in validation defaults.", scenario), call. = FALSE)
  }
  cfg
}

.qdesn_validation_apply_prior_override <- function(method_cfg, beta_prior_type) {
  method_cfg <- method_cfg %||% list()
  prior_overrides <- method_cfg$prior_overrides %||% list()
  override <- prior_overrides[[beta_prior_type]] %||% NULL
  if (is.null(override) && identical(as.character(beta_prior_type), "rhs_ns")) {
    override <- prior_overrides[["rhs"]] %||% NULL
  }
  if (is.list(override)) {
    method_cfg <- modifyList(method_cfg, override)
  }
  method_cfg$prior_overrides <- NULL
  method_cfg
}

.qdesn_validation_assert_non_dlm_input <- function(pipeline_cfg) {
  readout_cfg <- pipeline_cfg$readout %||% list()
  decomposition_cfg <- pipeline_cfg$decomposition %||% list()

  input_mode <- tolower(as.character(readout_cfg$input_mode %||% "raw_y_lags")[1L])
  decomposition_enabled <- isTRUE(decomposition_cfg$enabled %||% FALSE)

  if (!identical(input_mode, "raw_y_lags")) {
    stop(
      sprintf(
        "Validation campaigns enforce readout.input_mode='raw_y_lags'. Received '%s'.",
        input_mode
      ),
      call. = FALSE
    )
  }
  if (decomposition_enabled) {
    stop(
      "Validation campaigns enforce decomposition.enabled=FALSE; DLM-informed input is disabled for this framework.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

qdesn_validation_build_pipeline_cfg <- function(root_spec, defaults, method = c("vb", "mcmc")) {
  method <- match.arg(method)
  pipeline_cfg <- defaults$pipeline %||% list()
  .qdesn_validation_assert_non_dlm_input(pipeline_cfg)
  infer_cfg <- pipeline_cfg$inference %||% list()
  scenario_cfg <- .qdesn_validation_scenario_cfg(defaults, root_spec$scenario)
  reservoir_cfg <- .qdesn_validation_reservoir_cfg(defaults, root_spec$reservoir_profile)

  forecast_cfg <- modifyList(list(
    mode = "origin",
    horizon = as.integer(scenario_cfg$T_use - scenario_cfg$n_train),
    train_last_window = min(18L, as.integer(scenario_cfg$n_train)),
    fore_last_window = min(18L, as.integer(scenario_cfg$T_use - scenario_cfg$n_train))
  ), pipeline_cfg$forecast %||% list())
  if (is.null(forecast_cfg$horizon) || !is.finite(as.numeric(forecast_cfg$horizon))) {
    forecast_cfg$horizon <- as.integer(scenario_cfg$T_use - scenario_cfg$n_train)
  }

  cfg <- list(
    pipeline = list(mode = "sim", verbose = isTRUE(pipeline_cfg$verbose %||% TRUE)),
    split = list(
      use_last = TRUE,
      T_use = as.integer(scenario_cfg$T_use),
      train_n = as.integer(scenario_cfg$n_train)
    ),
    p_vec = .qdesn_validation_resolve_validation_p_vec(root_spec, defaults),
    desn = reservoir_cfg,
    readout = modifyList(list(
      include_input = TRUE,
      reservoir_lags = 1L,
      input_position = "after_reservoir",
      input_mode = "raw_y_lags"
    ), pipeline_cfg$readout %||% list()),
    decomposition = modifyList(list(
      enabled = FALSE
    ), pipeline_cfg$decomposition %||% list()),
    sampling = modifyList(list(nd_draws = 96L, chunk = 48L), pipeline_cfg$sampling %||% list()),
    forecast = forecast_cfg,
    synthesis = modifyList(list(
      isotonic = TRUE,
      rearrange = TRUE,
      grid_M = 151L,
      n_samp = 96L,
      seed = as.integer(root_spec$seed) + 1000L
    ), pipeline_cfg$synthesis %||% list()),
    diagnostics = modifyList(list(
      calibration = FALSE,
      pit = FALSE,
      scores = TRUE,
      lead_eval = FALSE,
      fan_charts = FALSE,
      plots = FALSE
    ), pipeline_cfg$diagnostics %||% list()),
    cpp = modifyList(list(
      use_postpred = FALSE,
      postpred_omp = FALSE,
      postpred_precompute = FALSE,
      postpred_threads = 1L
    ), pipeline_cfg$cpp %||% list()),
    outputs = modifyList(list(
      save = TRUE,
      keep_draws = FALSE,
      thesis_subset = FALSE
    ), pipeline_cfg$outputs %||% list()),
    inference = list(
      method = method,
      likelihood_family = as.character(root_spec$likelihood_family %||% "exal")[1L],
      readout_scale = isTRUE(infer_cfg$readout_scale %||% TRUE)
    )
  )

  if (identical(method, "vb")) {
    cfg$inference$vb <- modifyList(list(), infer_cfg$vb %||% list())
    cfg$inference$vb <- .qdesn_validation_apply_prior_override(cfg$inference$vb, root_spec$beta_prior_type)
    cfg$inference$vb$priors <- modifyList(list(), cfg$inference$vb$priors %||% list())
    cfg$inference$vb$priors$beta <- modifyList(list(type = root_spec$beta_prior_type), cfg$inference$vb$priors$beta %||% list())
    cfg$inference$vb$priors$beta$type <- root_spec$beta_prior_type
  } else {
    cfg$inference$mcmc <- modifyList(list(), infer_cfg$mcmc %||% list())
    cfg$inference$mcmc <- .qdesn_validation_apply_prior_override(cfg$inference$mcmc, root_spec$beta_prior_type)
    cfg$inference$mcmc$priors <- modifyList(list(), cfg$inference$mcmc$priors %||% list())
    cfg$inference$mcmc$priors$beta <- modifyList(list(type = root_spec$beta_prior_type), cfg$inference$mcmc$priors$beta %||% list())
    cfg$inference$mcmc$priors$beta$type <- root_spec$beta_prior_type
  }

  cfg
}

.qdesn_validation_apply_thread_caps <- function(threads = 1L) {
  n_threads <- max(1L, as.integer(threads)[1L])
  Sys.setenv(
    OMP_NUM_THREADS = as.character(n_threads),
    OPENBLAS_NUM_THREADS = as.character(n_threads),
    MKL_NUM_THREADS = as.character(n_threads),
    VECLIB_MAXIMUM_THREADS = as.character(n_threads),
    NUMEXPR_NUM_THREADS = as.character(n_threads)
  )
  invisible(n_threads)
}

.qdesn_validation_extract_fit <- function(summary_obj) {
  if (is.null(summary_obj$forecast_objects)) return(NULL)
  fits_fc <- summary_obj$forecast_objects$fits_fc %||% list()
  if (!length(fits_fc)) return(NULL)
  fit_entry <- fits_fc[[1L]]
  if (is.null(fit_entry$fit_train$fit)) return(NULL)
  fit_entry$fit_train$fit
}

.qdesn_validation_is_vb_fit <- function(fit) {
  inherits(fit, "exal_vb") ||
    (is.list(fit) &&
       is.list(fit$qbeta %||% NULL) &&
       is.list(fit$qsiggam %||% NULL) &&
       is.list(fit$misc %||% NULL) &&
       !is.null(fit$qbeta$m))
}

.qdesn_validation_is_mcmc_fit <- function(fit) {
  inherits(fit, "exal_mcmc") ||
    (is.list(fit) &&
       !is.null(fit$samp.beta) &&
       !is.null(fit$samp.sigma) &&
       !is.null(fit$samp.gamma) &&
       !is.null(fit$bounds))
}

.qdesn_validation_extract_forecast_df <- function(summary_obj) {
  if (is.null(summary_obj$forecast_objects)) return(NULL)
  fits_fc <- summary_obj$forecast_objects$fits_fc %||% list()
  if (!length(fits_fc)) return(NULL)
  out <- fits_fc[[1L]]$df_pred_fc %||% NULL
  if (is.null(out)) return(NULL)
  as.data.frame(out, stringsAsFactors = FALSE)
}

.qdesn_validation_compact_fit_path_file <- function(method_dir, split = c("train", "holdout")) {
  split <- match.arg(split)
  file.path(method_dir, "tables", sprintf("fit_quantile_path_%s.csv", split))
}

.qdesn_validation_adjust_vector <- function(x, n, default = NA) {
  n <- as.integer(n)[1L]
  if (!is.finite(n) || n <= 0L) return(x[0L])
  if (is.null(x) || !length(x)) {
    if (length(default) == n) return(default)
    return(rep(default[1L], n))
  }
  out <- x
  if (length(out) >= n) {
    return(out[seq_len(n)])
  }
  c(out, rep(default[1L], n - length(out)))
}

.qdesn_validation_df_col <- function(df, candidates, n, default = NA, numeric = FALSE) {
  if (is.null(df)) df <- data.frame(stringsAsFactors = FALSE)
  for (nm in as.character(candidates)) {
    if (nm %in% names(df)) {
      out <- .qdesn_validation_adjust_vector(df[[nm]], n, default = default)
      if (isTRUE(numeric)) out <- as.numeric(out)
      return(out)
    }
  }
  out <- if (length(default) == as.integer(n)[1L]) default else rep(default[1L], as.integer(n)[1L])
  if (isTRUE(numeric)) out <- as.numeric(out)
  out
}

.qdesn_validation_source_path_from_root_spec <- function(root_spec) {
  path <- root_spec$source_series_wide_path %||% root_spec$series_wide_path %||% NULL
  if (is.null(path) || !length(path)) return(NULL)
  path <- as.character(path)[1L]
  if (is.na(path) || !nzchar(trimws(path))) return(NULL)
  tryCatch(.qdesn_validation_resolve_path(path, must_work = FALSE), error = function(...) path)
}

.qdesn_validation_read_source_series <- function(root_spec) {
  path <- .qdesn_validation_source_path_from_root_spec(root_spec)
  if (is.null(path) || !file.exists(path)) return(NULL)
  tryCatch(utils::read.csv(path, stringsAsFactors = FALSE), error = function(...) NULL)
}

.qdesn_validation_source_values <- function(source_df, idx, candidates, default = NA_real_) {
  idx <- as.integer(idx)
  n <- length(idx)
  if (is.null(source_df) || !nrow(source_df) || !length(candidates)) {
    return(rep(default, n))
  }
  for (nm in as.character(candidates)) {
    if (nm %in% names(source_df)) {
      out <- rep(default, n)
      ok <- is.finite(idx) & idx >= 1L & idx <= nrow(source_df)
      out[ok] <- source_df[[nm]][idx[ok]]
      return(out)
    }
  }
  rep(default, n)
}

.qdesn_validation_compact_fit_path_df <- function(summary_obj,
                                                  root_spec,
                                                  split = c("train", "holdout")) {
  split <- match.arg(split)
  fits_fc <- (summary_obj$forecast_objects %||% list())$fits_fc %||% list()
  if (!length(fits_fc)) return(data.frame(stringsAsFactors = FALSE))
  fit_entry <- fits_fc[[1L]]
  df_mu <- as.data.frame(
    if (identical(split, "train")) fit_entry$df_mu_tr %||% data.frame(stringsAsFactors = FALSE) else fit_entry$df_mu_fc %||% data.frame(stringsAsFactors = FALSE),
    stringsAsFactors = FALSE
  )
  df_pred <- as.data.frame(
    if (identical(split, "train")) fit_entry$df_pred_tr %||% data.frame(stringsAsFactors = FALSE) else fit_entry$df_pred_fc %||% data.frame(stringsAsFactors = FALSE),
    stringsAsFactors = FALSE
  )
  n <- max(nrow(df_mu), nrow(df_pred))
  if (!is.finite(n) || n <= 0L) return(data.frame(stringsAsFactors = FALSE))

  source_df <- .qdesn_validation_read_source_series(root_spec)
  if (identical(split, "train")) {
    keep_idx <- as.integer(((fit_entry$fit_train %||% list())$meta %||% list())$keep_idx %||% seq_len(n))
    keep_idx <- .qdesn_validation_adjust_vector(keep_idx, n, default = NA_integer_)
  } else {
    split_n <- as.integer((summary_obj$summary$n_train %||% NA_integer_)[1L])
    keep_idx <- if (is.finite(split_n)) seq.int(split_n + 1L, length.out = n) else seq_len(n)
  }

  source_t <- .qdesn_validation_source_values(source_df, keep_idx, c("t", "time", "source_t"), default = NA_real_)
  source_index <- .qdesn_validation_source_values(source_df, keep_idx, c("source_index", "t"), default = NA_real_)
  q_true <- .qdesn_validation_df_col(df_mu, c("q_true", "q_target"), n, default = NA_real_, numeric = TRUE)
  if (!any(is.finite(q_true))) {
    q_true <- .qdesn_validation_df_col(df_pred, c("q_true", "q_target"), n, default = NA_real_, numeric = TRUE)
  }
  source_q_true <- .qdesn_validation_source_values(source_df, keep_idx, c("q_target", "q_true", "mu"), default = NA_real_)
  replace_q <- !is.finite(q_true) & is.finite(as.numeric(source_q_true))
  q_true[replace_q] <- as.numeric(source_q_true)[replace_q]

  y <- .qdesn_validation_df_col(df_mu, c("y"), n, default = NA_real_, numeric = TRUE)
  if (!any(is.finite(y))) {
    y <- .qdesn_validation_df_col(df_pred, c("y"), n, default = NA_real_, numeric = TRUE)
  }
  source_y <- .qdesn_validation_source_values(source_df, keep_idx, c("y"), default = NA_real_)
  replace_y <- !is.finite(y) & is.finite(as.numeric(source_y))
  y[replace_y] <- as.numeric(source_y)[replace_y]

  method <- as.character(
    (summary_obj$summary$inference_method %||% root_spec$method %||% root_spec$inference %||% NA_character_)[1L]
  )
  likelihood_family <- as.character(
    (root_spec$likelihood_family %||% summary_obj$summary$likelihood_family %||% root_spec$model %||% NA_character_)[1L]
  )
  out <- data.frame(
    root_id = as.character(root_spec$root_id %||% NA_character_)[1L],
    dataset_cell_id = as.character(root_spec$dataset_cell_id %||% NA_character_)[1L],
    scenario = as.character(root_spec$scenario %||% root_spec$source_scenario %||% NA_character_)[1L],
    family = as.character(root_spec$source_family %||% root_spec$family %||% NA_character_)[1L],
    tau = as.numeric(root_spec$tau %||% NA_real_)[1L],
    fit_size = as.integer(root_spec$effective_fit_size %||% root_spec$fit_size %||% NA_integer_)[1L],
    source_total_size = as.integer(root_spec$source_total_size %||% NA_integer_)[1L],
    prior = as.character(root_spec$beta_prior_type %||% root_spec$prior %||% NA_character_)[1L],
    inference = method,
    method = method,
    likelihood_family = likelihood_family,
    model = likelihood_family,
    split = split,
    h = as.integer(.qdesn_validation_df_col(df_mu, c("h", "step", "t"), n, default = seq_len(n), numeric = TRUE)),
    source_t = as.numeric(source_t),
    source_index = as.integer(source_index),
    p0 = as.numeric(.qdesn_validation_df_col(df_mu, c("p0", "p", "tau"), n, default = as.numeric(root_spec$tau %||% NA_real_), numeric = TRUE)),
    y = as.numeric(y),
    q_true = as.numeric(q_true),
    q_pred = as.numeric(.qdesn_validation_df_col(df_pred, c("q_pred", "qhat", "mu"), n, default = NA_real_, numeric = TRUE)),
    mu = as.numeric(.qdesn_validation_df_col(df_mu, c("mu", "q_pred", "qhat"), n, default = NA_real_, numeric = TRUE)),
    lo = as.numeric(.qdesn_validation_df_col(df_mu, c("lo", "lower", "lwr", "q05", "q025"), n, default = NA_real_, numeric = TRUE)),
    hi = as.numeric(.qdesn_validation_df_col(df_mu, c("hi", "upper", "upr", "q95", "q975"), n, default = NA_real_, numeric = TRUE)),
    band_type = as.character(.qdesn_validation_df_col(df_mu, c("band_type", "interval_type"), n, default = "posterior_quantile_band")),
    stringsAsFactors = FALSE
  )
  out
}

.qdesn_validation_first_finite_int <- function(x) {
  x <- suppressWarnings(as.integer(x %||% NA_integer_))
  x <- x[is.finite(x)]
  if (length(x)) x[[1L]] else NA_integer_
}

.qdesn_validation_split_alignment_row <- function(df, root_spec, split = c("train", "holdout")) {
  split <- match.arg(split)
  df <- as.data.frame(df %||% data.frame(stringsAsFactors = FALSE), stringsAsFactors = FALSE)
  source_index <- if ("source_index" %in% names(df)) suppressWarnings(as.integer(df$source_index)) else integer(0)
  source_index <- source_index[is.finite(source_index)]

  expected_first <- if (identical(split, "train")) {
    .qdesn_validation_first_finite_int(root_spec$train_start_source_index)
  } else {
    .qdesn_validation_first_finite_int(root_spec$forecast_start_source_index)
  }
  expected_last <- if (identical(split, "train")) {
    .qdesn_validation_first_finite_int(root_spec$train_end_source_index)
  } else {
    .qdesn_validation_first_finite_int(root_spec$forecast_end_source_index)
  }
  expected_n <- if (is.finite(expected_first) && is.finite(expected_last) && expected_last >= expected_first) {
    as.integer(expected_last - expected_first + 1L)
  } else if (identical(split, "train")) {
    .qdesn_validation_first_finite_int(root_spec$effective_fit_size %||% root_spec$fit_size)
  } else {
    NA_integer_
  }

  realized_n <- as.integer(nrow(df))
  realized_first <- if (length(source_index)) min(source_index, na.rm = TRUE) else NA_integer_
  realized_last <- if (length(source_index)) max(source_index, na.rm = TRUE) else NA_integer_
  contiguous <- if (length(source_index) > 1L) {
    identical(source_index, seq.int(source_index[[1L]], source_index[[1L]] + length(source_index) - 1L))
  } else {
    length(source_index) == 1L
  }

  problems <- character(0)
  if (is.finite(expected_n) && !identical(realized_n, as.integer(expected_n))) {
    problems <- c(problems, sprintf("n_%d_expected_%d", realized_n, expected_n))
  }
  if (is.finite(expected_first) && !identical(as.integer(realized_first), as.integer(expected_first))) {
    problems <- c(problems, sprintf("first_%s_expected_%s", as.character(realized_first), as.character(expected_first)))
  }
  if (is.finite(expected_last) && !identical(as.integer(realized_last), as.integer(expected_last))) {
    problems <- c(problems, sprintf("last_%s_expected_%s", as.character(realized_last), as.character(expected_last)))
  }
  if (length(source_index) && !isTRUE(contiguous)) {
    problems <- c(problems, "source_index_not_contiguous")
  }
  if (!length(source_index) && nrow(df)) {
    problems <- c(problems, "missing_source_index")
  }
  data.frame(
    root_id = as.character(root_spec$root_id %||% NA_character_)[1L],
    dataset_cell_id = as.character(root_spec$dataset_cell_id %||% NA_character_)[1L],
    split = if (identical(split, "holdout")) "forecast" else "train",
    realized_n = realized_n,
    expected_n = as.integer(expected_n),
    realized_source_index_first = as.integer(realized_first),
    realized_source_index_last = as.integer(realized_last),
    expected_source_index_first = as.integer(expected_first),
    expected_source_index_last = as.integer(expected_last),
    contiguous_source_index = isTRUE(contiguous),
    status = if (length(problems)) "FAIL" else "PASS",
    reason = if (length(problems)) paste(unique(problems), collapse = ";") else "ok",
    stringsAsFactors = FALSE
  )
}

.qdesn_validation_pinball <- function(y, q, tau) {
  y <- as.numeric(y)
  q <- as.numeric(q)
  tau <- as.numeric(tau)[1L]
  ok <- is.finite(y) & is.finite(q) & is.finite(tau)
  if (!any(ok)) return(NA_real_)
  e <- y[ok] - q[ok]
  mean((tau - as.numeric(e < 0)) * e)
}

.qdesn_validation_horizon_summary_df <- function(holdout_df,
                                                 root_spec,
                                                 horizons = c(100L, 1000L)) {
  holdout_df <- as.data.frame(holdout_df %||% data.frame(stringsAsFactors = FALSE), stringsAsFactors = FALSE)
  if (!nrow(holdout_df)) return(data.frame(stringsAsFactors = FALSE))
  horizons <- unique(as.integer(horizons))
  horizons <- horizons[is.finite(horizons) & horizons > 0L]
  horizons <- horizons[horizons <= nrow(holdout_df)]
  if (!length(horizons)) return(data.frame(stringsAsFactors = FALSE))

  rows <- lapply(horizons, function(horizon) {
    sub <- holdout_df[seq_len(horizon), , drop = FALSE]
    q_pred <- as.numeric(sub$q_pred %||% sub$mu %||% NA_real_)
    q_true <- as.numeric(sub$q_true %||% NA_real_)
    y <- as.numeric(sub$y %||% NA_real_)
    tau <- as.numeric(root_spec$tau %||% sub$p0[1L] %||% NA_real_)[1L]
    err <- q_pred - q_true
    ok <- is.finite(err)
    corr <- if (sum(ok) >= 2L) suppressWarnings(stats::cor(q_pred[ok], q_true[ok])) else NA_real_
    data.frame(
      root_id = as.character(root_spec$root_id %||% NA_character_)[1L],
      dataset_cell_id = as.character(root_spec$dataset_cell_id %||% NA_character_)[1L],
      scenario = as.character(root_spec$scenario %||% root_spec$source_scenario %||% NA_character_)[1L],
      family = as.character(root_spec$source_family %||% root_spec$family %||% NA_character_)[1L],
      tau = tau,
      fit_size = as.integer(root_spec$effective_fit_size %||% root_spec$fit_size %||% NA_integer_)[1L],
      prior = as.character(root_spec$beta_prior_type %||% root_spec$prior %||% NA_character_)[1L],
      inference = as.character(sub$inference[1L] %||% sub$method[1L] %||% NA_character_),
      model = as.character(sub$model[1L] %||% sub$likelihood_family[1L] %||% NA_character_),
      window = sprintf("forecast_H%d", horizon),
      horizon = as.integer(horizon),
      n_eval = as.integer(sum(ok)),
      source_index_first = if ("source_index" %in% names(sub)) as.integer(sub$source_index[1L]) else NA_integer_,
      source_index_last = if ("source_index" %in% names(sub)) as.integer(sub$source_index[nrow(sub)]) else NA_integer_,
      qtrue_mae = if (any(ok)) mean(abs(err[ok])) else NA_real_,
      qtrue_rmse = if (any(ok)) sqrt(mean(err[ok]^2)) else NA_real_,
      qtrue_bias = if (any(ok)) mean(err[ok]) else NA_real_,
      qtrue_corr = as.numeric(corr),
      pinball_tau = .qdesn_validation_pinball(y, q_pred, tau),
      coverage = if (any(is.finite(y) & is.finite(q_pred))) mean(y <= q_pred, na.rm = TRUE) else NA_real_,
      coverage_minus_tau = if (any(is.finite(y) & is.finite(q_pred)) && is.finite(tau)) mean(y <= q_pred, na.rm = TRUE) - tau else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  .qdesn_validation_bind_rows(rows)
}

.qdesn_validation_qdesn_state_update_method <- function() {
  "forecast_lattice_observed_lag_state_update_no_refit"
}

.qdesn_validation_rolling_origin_cfg <- function(defaults = NULL) {
  metrics <- (defaults %||% list())$metrics %||% list()
  rolling <- metrics$rolling_origin %||% list()
  if (!length(rolling)) {
    source <- (defaults %||% list())$source %||% list()
    rolling <- list(
      enabled = FALSE,
      forecast_protocol = source$forecast_protocol %||% metrics$forecast_protocol %||% "rolling_origin_no_refit_state_update",
      max_lead_configured = source$rolling_hmax %||% metrics$rolling_hmax %||% 30L,
      origin_stride = source$origin_stride %||% metrics$origin_stride %||% source$rolling_hmax %||% 30L,
      require_lead_export = FALSE
    )
  }
  hmax <- as.integer(
    rolling$max_lead_configured %||% rolling$hmax %||% rolling$rolling_hmax %||% 30L
  )[1L]
  stride <- as.integer(
    rolling$origin_stride %||% rolling$stride %||% hmax
  )[1L]
  if (!is.finite(hmax) || hmax < 1L) hmax <- 30L
  if (!is.finite(stride) || stride < 1L) stride <- hmax
  list(
    enabled = isTRUE(rolling$enabled %||% FALSE),
    require_lead_export = isTRUE(rolling$require_lead_export %||% rolling$required %||% FALSE),
    forecast_protocol = as.character(rolling$forecast_protocol %||% "rolling_origin_no_refit_state_update")[1L],
    state_update_method = as.character(rolling$state_update_method %||% .qdesn_validation_qdesn_state_update_method())[1L],
    refit_per_origin = isTRUE(rolling$refit_per_origin %||% FALSE),
    max_lead_configured = hmax,
    origin_stride = stride
  )
}

.qdesn_validation_rolling_grid <- function(train_end_source_index,
                                           forecast_start_source_index,
                                           forecast_end_source_index,
                                           hmax,
                                           origin_stride,
                                           forecast_protocol = "rolling_origin_no_refit_state_update") {
  train_end_source_index <- as.integer(train_end_source_index)[1L]
  forecast_start_source_index <- as.integer(forecast_start_source_index)[1L]
  forecast_end_source_index <- as.integer(forecast_end_source_index)[1L]
  hmax <- as.integer(hmax)[1L]
  origin_stride <- as.integer(origin_stride)[1L]
  if (!all(is.finite(c(train_end_source_index, forecast_start_source_index, forecast_end_source_index, hmax, origin_stride)))) {
    stop("Rolling-origin grid inputs must be finite integers.", call. = FALSE)
  }
  if (forecast_start_source_index != train_end_source_index + 1L) {
    stop("forecast_start_source_index must equal train_end_source_index + 1.", call. = FALSE)
  }
  if (forecast_end_source_index < forecast_start_source_index) {
    stop("forecast_end_source_index must be >= forecast_start_source_index.", call. = FALSE)
  }
  if (hmax < 1L || origin_stride < 1L) {
    stop("hmax and origin_stride must be >= 1.", call. = FALSE)
  }
  forecast_block_size <- forecast_end_source_index - forecast_start_source_index + 1L
  if (hmax > forecast_block_size) {
    stop("hmax must be <= forecast block size.", call. = FALSE)
  }
  origins <- seq.int(train_end_source_index, forecast_end_source_index - 1L, by = origin_stride)
  raw <- expand.grid(
    forecast_origin_source_index = origins,
    forecast_lead = seq_len(hmax),
    KEEP.OUT.ATTRS = FALSE
  )
  raw$target_source_index <- as.integer(raw$forecast_origin_source_index + raw$forecast_lead)
  raw <- raw[
    raw$target_source_index >= forecast_start_source_index &
      raw$target_source_index <= forecast_end_source_index,
    ,
    drop = FALSE
  ]
  raw <- raw[order(raw$forecast_origin_source_index, raw$forecast_lead), , drop = FALSE]
  rownames(raw) <- NULL
  lead_counts <- table(raw$forecast_lead)
  data.frame(
    forecast_protocol = as.character(forecast_protocol)[1L],
    forecast_block_start_source_index = forecast_start_source_index,
    forecast_block_end_source_index = forecast_end_source_index,
    forecast_block_size = forecast_block_size,
    max_lead_configured = hmax,
    origin_stride = origin_stride,
    origin_sequence_id = as.integer(match(raw$forecast_origin_source_index, origins)),
    forecast_origin_source_index = as.integer(raw$forecast_origin_source_index),
    forecast_lead = as.integer(raw$forecast_lead),
    target_source_index = as.integer(raw$target_source_index),
    n_origins_for_lead = as.integer(lead_counts[as.character(raw$forecast_lead)]),
    stringsAsFactors = FALSE
  )
}

.qdesn_validation_quantile_columns <- function(draws,
                                               probs = c(0.025, 0.25, 0.5, 0.75, 0.975)) {
  draws <- as.matrix(draws)
  qs <- t(apply(draws, 1L, stats::quantile, probs = probs, na.rm = TRUE, names = FALSE))
  colnames(qs) <- paste0("qhat_p", gsub("\\.", "", sprintf("%.3f", probs)))
  as.data.frame(qs, check.names = FALSE)
}

.qdesn_validation_lead_export_scale_spec <- function(forecast_full = list()) {
  meta <- forecast_full$lead_export_scale %||% forecast_full$y_backtransform %||% list()
  transform <- tolower(trimws(as.character(
    meta$transform %||% meta$type %||% meta$method %||% "identity"
  )[1L]))
  if (!nzchar(transform) || is.na(transform)) transform <- "identity"
  if (transform %in% c("none", "raw", "already_original")) transform <- "identity"
  if (transform %in% c("standardized_to_original", "backtransform_affine")) transform <- "affine"
  center <- suppressWarnings(as.numeric(
    meta$center %||% meta$mean %||% meta$y_mean %||% 0
  )[1L])
  scale <- suppressWarnings(as.numeric(
    meta$scale %||% meta$scale_factor %||% meta$sd %||% meta$y_sd %||% 1
  )[1L])
  if (!is.finite(center)) center <- 0
  if (!is.finite(scale) || scale == 0) scale <- 1
  if (!transform %in% c("identity", "affine")) {
    stop(sprintf("Unsupported Q-DESN lead export scale transform: %s", transform), call. = FALSE)
  }
  output_scale <- as.character(meta$output_scale %||% if (identical(transform, "affine")) "standardized_model" else "original")[1L]
  target_scale <- as.character(meta$target_scale %||% "original")[1L]
  scale_source <- as.character(meta$scale_source %||% meta$source %||% "forecast_full$lead_export_scale")[1L]
  if (is.na(output_scale) || !nzchar(output_scale)) output_scale <- NA_character_
  if (is.na(target_scale) || !nzchar(target_scale)) target_scale <- "original"
  if (is.na(scale_source) || !nzchar(scale_source)) scale_source <- "forecast_full$lead_export_scale"
  list(
    transform = transform,
    center = center,
    scale = scale,
    output_scale = output_scale,
    target_scale = target_scale,
    scale_source = scale_source,
    status = if (identical(transform, "affine")) "original_scale_backtransformed" else "original_scale_identity"
  )
}

.qdesn_validation_apply_lead_export_scale <- function(x, scale_spec) {
  if (identical(scale_spec$transform, "identity")) return(x)
  if (identical(scale_spec$transform, "affine")) {
    return(x * scale_spec$scale + scale_spec$center)
  }
  stop(sprintf("Unsupported Q-DESN lead export scale transform: %s", scale_spec$transform), call. = FALSE)
}

.qdesn_validation_rolling_lead_path_file <- function(method_dir) {
  file.path(method_dir, "tables", "forecast_rolling_origin_paths.csv")
}

.qdesn_validation_rolling_lead_metrics_file <- function(method_dir) {
  file.path(method_dir, "tables", "forecast_lead_metrics.csv")
}

.qdesn_validation_qdesn_lead_path_df <- function(summary_obj,
                                                 root_spec,
                                                 defaults = NULL) {
  cfg <- .qdesn_validation_rolling_origin_cfg(defaults)
  if (!isTRUE(cfg$enabled)) return(data.frame(stringsAsFactors = FALSE))
  if (!identical(cfg$forecast_protocol, "rolling_origin_no_refit_state_update")) {
    stop(sprintf("Unsupported Q-DESN forecast_protocol: %s", cfg$forecast_protocol), call. = FALSE)
  }
  fits_fc <- (summary_obj$forecast_objects %||% list())$fits_fc %||% list()
  if (!length(fits_fc)) {
    if (isTRUE(cfg$require_lead_export)) stop("Q-DESN rolling lead export requires forecast_objects$fits_fc.", call. = FALSE)
    return(data.frame(stringsAsFactors = FALSE))
  }
  fit_entry <- fits_fc[[1L]]
  forecast_full <- fit_entry$forecast_full %||% list()
  scale_spec <- .qdesn_validation_lead_export_scale_spec(forecast_full)
  origins_local <- as.integer(forecast_full$origins %||% integer(0))
  mu_by_origin <- forecast_full$mu_by_origin %||% NULL
  yrep_by_origin <- forecast_full$yrep_by_origin %||% NULL
  missing_origin_draws <- !length(origins_local) ||
    is.null(mu_by_origin) || !length(mu_by_origin) ||
    is.null(yrep_by_origin) || !length(yrep_by_origin)
  if (isTRUE(missing_origin_draws)) {
    msg <- paste(
      "Q-DESN rolling lead export requires forecast_full$origins,",
      "forecast_full$mu_by_origin, and forecast_full$yrep_by_origin.",
      "Set pipeline.outputs.keep_draws=yes or write compact rolling lead rows before pruning."
    )
    if (isTRUE(cfg$require_lead_export)) stop(msg, call. = FALSE)
    return(data.frame(stringsAsFactors = FALSE))
  }
  if (length(mu_by_origin) != length(origins_local) ||
      length(yrep_by_origin) != length(origins_local)) {
    stop("Q-DESN rolling origin draw list lengths do not match forecast_full$origins.", call. = FALSE)
  }

  source_df <- .qdesn_validation_read_source_series(root_spec)
  if (is.null(source_df) || !nrow(source_df)) {
    stop("Q-DESN rolling lead export requires root_spec$source_series_wide_path.", call. = FALSE)
  }
  source_index <- if ("source_index" %in% names(source_df)) {
    as.integer(source_df$source_index)
  } else if ("t" %in% names(source_df)) {
    as.integer(source_df$t)
  } else {
    seq_len(nrow(source_df))
  }
  y <- as.numeric(source_df$y %||% rep(NA_real_, nrow(source_df)))
  q_true <- if ("q_target" %in% names(source_df)) {
    as.numeric(source_df$q_target)
  } else if ("q_true" %in% names(source_df)) {
    as.numeric(source_df$q_true)
  } else if ("mu" %in% names(source_df)) {
    as.numeric(source_df$mu)
  } else {
    rep(NA_real_, nrow(source_df))
  }

  grid <- .qdesn_validation_rolling_grid(
    train_end_source_index = root_spec$train_end_source_index,
    forecast_start_source_index = root_spec$forecast_start_source_index,
    forecast_end_source_index = root_spec$forecast_end_source_index,
    hmax = cfg$max_lead_configured,
    origin_stride = cfg$origin_stride,
    forecast_protocol = cfg$forecast_protocol
  )
  local_origin_for_source <- match(as.integer(grid$forecast_origin_source_index), source_index)
  local_target_for_source <- match(as.integer(grid$target_source_index), source_index)
  if (any(is.na(local_origin_for_source)) || any(is.na(local_target_for_source))) {
    stop("Q-DESN rolling lead grid could not be mapped to staged source rows.", call. = FALSE)
  }

  rows <- vector("list", nrow(grid))
  tau <- as.numeric(root_spec$tau %||% NA_real_)[1L]
  for (i in seq_len(nrow(grid))) {
    origin_local <- as.integer(local_origin_for_source[[i]])
    target_local <- as.integer(local_target_for_source[[i]])
    lead <- as.integer(grid$forecast_lead[[i]])
    origin_pos <- match(origin_local, origins_local)
    if (is.na(origin_pos)) {
      stop(sprintf(
        "Q-DESN rolling lead export is missing local origin %d for source index %d.",
        origin_local,
        as.integer(grid$forecast_origin_source_index[[i]])
      ), call. = FALSE)
    }
    mu_mat <- as.matrix(mu_by_origin[[origin_pos]])
    yrep_mat <- as.matrix(yrep_by_origin[[origin_pos]])
    if (nrow(mu_mat) < lead || nrow(yrep_mat) < lead) {
      stop(sprintf(
        "Q-DESN rolling lead export origin %d has only %d mu rows and %d yrep rows; need lead %d.",
        as.integer(grid$forecast_origin_source_index[[i]]),
        nrow(mu_mat),
        nrow(yrep_mat),
        lead
      ), call. = FALSE)
    }
    draw_row <- .qdesn_validation_apply_lead_export_scale(
      matrix(mu_mat[lead, ], nrow = 1L),
      scale_spec
    )
    qhat <- stats::median(as.numeric(draw_row), na.rm = TRUE)
    qs <- .qdesn_validation_quantile_columns(draw_row)
    y_i <- as.numeric(y[[target_local]])
    q_true_i <- as.numeric(q_true[[target_local]])
    rows[[i]] <- cbind(
      data.frame(
        split_role = "rolling_forecast",
        source_index = as.integer(grid$target_source_index[[i]]),
        y = y_i,
        q_true = q_true_i,
        qhat = qhat,
        q_error = qhat - q_true_i,
        abs_q_error = abs(qhat - q_true_i),
        squared_q_error = (qhat - q_true_i)^2,
        pinball_tau = .qdesn_validation_pinball(y_i, qhat, tau),
        hit = as.integer(y_i <= qhat),
        coverage_minus_tau = as.integer(y_i <= qhat) - tau,
        horizon = lead,
        forecast_protocol = cfg$forecast_protocol,
        state_update_method = cfg$state_update_method,
        refit_per_origin = isTRUE(cfg$refit_per_origin),
        forecast_origin_source_index = as.integer(grid$forecast_origin_source_index[[i]]),
        forecast_lead = lead,
        target_source_index = as.integer(grid$target_source_index[[i]]),
        origin_sequence_id = as.integer(grid$origin_sequence_id[[i]]),
        origin_stride = as.integer(grid$origin_stride[[i]]),
        max_lead_configured = as.integer(grid$max_lead_configured[[i]]),
        n_origins_for_lead = as.integer(grid$n_origins_for_lead[[i]]),
        local_origin_t = origin_local,
        local_target_t = target_local,
        qdesn_forecast_engine = "forecast_lattice.qdesn_fit",
        posterior_draw_source = "mu_by_origin",
        predictive_draws_used_for_primary = FALSE,
        synthesis_enabled = FALSE,
        lead_export_output_scale = scale_spec$output_scale,
        lead_export_target_scale = scale_spec$target_scale,
        lead_export_transform = scale_spec$transform,
        lead_export_center = scale_spec$center,
        lead_export_scale_factor = scale_spec$scale,
        lead_export_scale_source = scale_spec$scale_source,
        lead_export_scale_status = scale_spec$status,
        stringsAsFactors = FALSE
      ),
      qs
    )
  }
  out <- .qdesn_validation_bind_rows(rows)
  out[order(as.integer(out$forecast_origin_source_index), as.integer(out$forecast_lead)), , drop = FALSE]
}

.qdesn_validation_qdesn_lead_metrics_df <- function(path_df, root_spec) {
  path_df <- as.data.frame(path_df %||% data.frame(stringsAsFactors = FALSE), stringsAsFactors = FALSE)
  if (!nrow(path_df)) return(data.frame(stringsAsFactors = FALSE))
  rows <- lapply(split(path_df, path_df$forecast_lead), function(x) {
    data.frame(
      root_id = as.character(root_spec$root_id %||% NA_character_)[1L],
      dataset_cell_id = as.character(root_spec$dataset_cell_id %||% NA_character_)[1L],
      scenario = as.character(root_spec$scenario %||% root_spec$source_scenario %||% NA_character_)[1L],
      family = as.character(root_spec$source_family %||% root_spec$family %||% NA_character_)[1L],
      tau = as.numeric(root_spec$tau %||% NA_real_)[1L],
      fit_size = as.integer(root_spec$effective_fit_size %||% root_spec$fit_size %||% NA_integer_)[1L],
      forecast_protocol = as.character(x$forecast_protocol[[1L]]),
      state_update_method = as.character(x$state_update_method[[1L]]),
      refit_per_origin = isTRUE(x$refit_per_origin[[1L]]),
      forecast_lead = as.integer(x$forecast_lead[[1L]]),
      origin_stride = as.integer(x$origin_stride[[1L]]),
      max_lead_configured = as.integer(x$max_lead_configured[[1L]]),
      n_origins_scored = nrow(x),
      origin_start_source_index = min(as.integer(x$forecast_origin_source_index), na.rm = TRUE),
      origin_end_source_index = max(as.integer(x$forecast_origin_source_index), na.rm = TRUE),
      target_start_source_index = min(as.integer(x$target_source_index), na.rm = TRUE),
      target_end_source_index = max(as.integer(x$target_source_index), na.rm = TRUE),
      forecast_qtrue_mae = mean(as.numeric(x$abs_q_error), na.rm = TRUE),
      forecast_qtrue_rmse = sqrt(mean(as.numeric(x$squared_q_error), na.rm = TRUE)),
      forecast_qtrue_bias = mean(as.numeric(x$q_error), na.rm = TRUE),
      forecast_pinball_mean = mean(as.numeric(x$pinball_tau), na.rm = TRUE),
      forecast_coverage = mean(as.numeric(x$hit), na.rm = TRUE),
      forecast_coverage_error = mean(as.numeric(x$coverage_minus_tau), na.rm = TRUE),
      synthesis_enabled = FALSE,
      posterior_draw_source = "mu_by_origin",
      lead_export_target_scale = if ("lead_export_target_scale" %in% names(x)) as.character(x$lead_export_target_scale[[1L]]) else "original",
      lead_export_transform = if ("lead_export_transform" %in% names(x)) as.character(x$lead_export_transform[[1L]]) else "identity",
      lead_export_scale_status = if ("lead_export_scale_status" %in% names(x)) as.character(x$lead_export_scale_status[[1L]]) else "original_scale_identity",
      stringsAsFactors = FALSE
    )
  })
  out <- .qdesn_validation_bind_rows(rows)
  out[order(as.integer(out$forecast_lead)), , drop = FALSE]
}

.qdesn_validation_write_qdesn_rolling_lead_paths <- function(summary_obj,
                                                            root_spec,
                                                            method_dir,
                                                            defaults = NULL) {
  cfg <- .qdesn_validation_rolling_origin_cfg(defaults)
  if (!isTRUE(cfg$enabled)) {
    return(list(
      path = NA_character_, rows = 0L,
      metrics = NA_character_, metrics_rows = 0L,
      status = "DISABLED"
    ))
  }
  path_df <- .qdesn_validation_qdesn_lead_path_df(summary_obj, root_spec, defaults = defaults)
  metrics_df <- .qdesn_validation_qdesn_lead_metrics_df(path_df, root_spec)
  path_file <- .qdesn_validation_rolling_lead_path_file(method_dir)
  metrics_file <- .qdesn_validation_rolling_lead_metrics_file(method_dir)
  if (nrow(path_df)) .qdesn_validation_write_df(path_df, path_file)
  if (nrow(metrics_df)) .qdesn_validation_write_df(metrics_df, metrics_file)
  list(
    path = if (nrow(path_df)) normalizePath(path_file, winslash = "/", mustWork = FALSE) else NA_character_,
    rows = as.integer(nrow(path_df)),
    metrics = if (nrow(metrics_df)) normalizePath(metrics_file, winslash = "/", mustWork = FALSE) else NA_character_,
    metrics_rows = as.integer(nrow(metrics_df)),
    status = if (nrow(path_df) && nrow(metrics_df)) "PASS" else "EMPTY"
  )
}

.qdesn_validation_write_compact_fit_paths <- function(summary_obj, root_spec, method_dir, defaults = NULL) {
  if (is.null(summary_obj) || is.null(summary_obj$forecast_objects)) {
    return(list(
      train = NA_character_, holdout = NA_character_, train_rows = 0L, holdout_rows = 0L,
      index_alignment = NA_character_, index_alignment_status = "MISSING",
      forecast_horizon_summary = NA_character_, forecast_horizon_rows = 0L,
      forecast_rolling_origin_path = NA_character_, forecast_rolling_origin_rows = 0L,
      forecast_lead_metrics = NA_character_, forecast_lead_metrics_rows = 0L,
      forecast_rolling_origin_status = "MISSING"
    ))
  }
  train_path <- .qdesn_validation_compact_fit_path_file(method_dir, "train")
  holdout_path <- .qdesn_validation_compact_fit_path_file(method_dir, "holdout")
  index_alignment_path <- file.path(method_dir, "tables", "index_alignment.csv")
  forecast_horizon_path <- file.path(method_dir, "tables", "forecast_horizon_summary.csv")
  train_df <- .qdesn_validation_compact_fit_path_df(summary_obj, root_spec, "train")
  holdout_df <- .qdesn_validation_compact_fit_path_df(summary_obj, root_spec, "holdout")
  if (nrow(train_df)) .qdesn_validation_write_df(train_df, train_path)
  if (nrow(holdout_df)) .qdesn_validation_write_df(holdout_df, holdout_path)
  alignment_df <- .qdesn_validation_bind_rows(list(
    .qdesn_validation_split_alignment_row(train_df, root_spec, "train"),
    .qdesn_validation_split_alignment_row(holdout_df, root_spec, "holdout")
  ))
  if (nrow(alignment_df)) .qdesn_validation_write_df(alignment_df, index_alignment_path)
  horizon_summary <- .qdesn_validation_horizon_summary_df(
    holdout_df,
    root_spec,
    horizons = ((defaults %||% list())$metrics %||% list())$forecast_horizons %||% c(100L, 1000L)
  )
  if (nrow(horizon_summary)) .qdesn_validation_write_df(horizon_summary, forecast_horizon_path)
  rolling_leads <- .qdesn_validation_write_qdesn_rolling_lead_paths(
    summary_obj = summary_obj,
    root_spec = root_spec,
    method_dir = method_dir,
    defaults = defaults
  )
  alignment_status <- if (nrow(alignment_df) && all(as.character(alignment_df$status) == "PASS")) "PASS" else "FAIL"
  .qdesn_validation_write_json(file.path(method_dir, "manifest", "index_alignment.json"), list(
    generated_at = as.character(Sys.time()),
    index_alignment_file = normalizePath(index_alignment_path, winslash = "/", mustWork = FALSE),
    status = alignment_status,
    rows = as.integer(nrow(alignment_df))
  ))
  list(
    train = if (nrow(train_df)) normalizePath(train_path, winslash = "/", mustWork = FALSE) else NA_character_,
    holdout = if (nrow(holdout_df)) normalizePath(holdout_path, winslash = "/", mustWork = FALSE) else NA_character_,
    train_rows = as.integer(nrow(train_df)),
    holdout_rows = as.integer(nrow(holdout_df)),
    index_alignment = if (nrow(alignment_df)) normalizePath(index_alignment_path, winslash = "/", mustWork = FALSE) else NA_character_,
    index_alignment_status = alignment_status,
    forecast_horizon_summary = if (nrow(horizon_summary)) normalizePath(forecast_horizon_path, winslash = "/", mustWork = FALSE) else NA_character_,
    forecast_horizon_rows = as.integer(nrow(horizon_summary)),
    forecast_rolling_origin_path = rolling_leads$path,
    forecast_rolling_origin_rows = as.integer(rolling_leads$rows),
    forecast_lead_metrics = rolling_leads$metrics,
    forecast_lead_metrics_rows = as.integer(rolling_leads$metrics_rows),
    forecast_rolling_origin_status = rolling_leads$status
  )
}

.qdesn_validation_output_retention_cfg <- function(defaults = NULL) {
  outputs <- (((defaults %||% list())$pipeline %||% list())$outputs) %||% list()
  profile <- tolower(trimws(as.character(outputs$retention_profile %||% "full_debug")[1L]))
  if (is.na(profile) || !nzchar(profile)) profile <- "full_debug"
  analysis_like <- profile %in% c("analysis", "compact", "lean", "minimal", "minimal_archive", "summary", "summary_only")
  save_forecast_objects <- outputs$save_forecast_objects
  if (is.null(save_forecast_objects) || length(save_forecast_objects) == 0L || is.na(save_forecast_objects[[1L]])) {
    save_forecast_objects <- !analysis_like
  } else {
    save_forecast_objects <- isTRUE(save_forecast_objects)
  }
  save_compact_fit_paths <- outputs$save_compact_fit_paths
  if (is.null(save_compact_fit_paths) || length(save_compact_fit_paths) == 0L || is.na(save_compact_fit_paths[[1L]])) {
    save_compact_fit_paths <- analysis_like
  } else {
    save_compact_fit_paths <- isTRUE(save_compact_fit_paths)
  }
  retain_full_rds_on_failure <- outputs$retain_full_rds_on_failure
  if (is.null(retain_full_rds_on_failure)) {
    retain_cfg <- outputs$retain_full_rds %||% list()
    retain_full_rds_on_failure <- retain_cfg$failures %||% TRUE
  }
  list(
    retention_profile = profile,
    save_forecast_objects = isTRUE(save_forecast_objects),
    save_compact_fit_paths = isTRUE(save_compact_fit_paths),
    retain_full_rds_on_failure = isTRUE(retain_full_rds_on_failure)
  )
}

.qdesn_validation_apply_output_retention <- function(method_dir,
                                                     status,
                                                     defaults = NULL,
                                                     root_spec = list(),
                                                     summary_obj = NULL) {
  cfg <- .qdesn_validation_output_retention_cfg(defaults)
  forecast_path <- file.path(method_dir, "models", "forecast_objects.rds")
  forecast_bytes_before <- if (file.exists(forecast_path)) file.info(forecast_path)$size[[1L]] else 0
  compact_paths <- list(train = NA_character_, holdout = NA_character_, train_rows = 0L, holdout_rows = 0L)
  compact_error <- NA_character_
  if (isTRUE(cfg$save_compact_fit_paths) && !is.null(summary_obj)) {
    compact_paths <- tryCatch(
      .qdesn_validation_write_compact_fit_paths(summary_obj, root_spec, method_dir, defaults = defaults),
      error = function(e) {
        compact_error <<- conditionMessage(e)
        list(train = NA_character_, holdout = NA_character_, train_rows = 0L, holdout_rows = 0L)
      }
    )
  }

  status_chr <- toupper(as.character(status %||% NA_character_)[1L])
  success_like <- identical(status_chr, "SUCCESS")
  alignment_ready <- !isTRUE(cfg$save_compact_fit_paths) ||
    identical(as.character(compact_paths$index_alignment_status %||% NA_character_)[1L], "PASS")
  compact_ready <- !isTRUE(cfg$save_compact_fit_paths) ||
    (is.na(compact_error) && as.integer(compact_paths$train_rows %||% 0L) > 0L && isTRUE(alignment_ready))
  should_prune_forecast <- !isTRUE(cfg$save_forecast_objects) &&
    file.exists(forecast_path) &&
    isTRUE(compact_ready) &&
    (success_like || !isTRUE(cfg$retain_full_rds_on_failure))
  pruned <- FALSE
  prune_error <- NA_character_
  if (isTRUE(should_prune_forecast)) {
    pruned <- tryCatch({
      unlink(forecast_path)
      !file.exists(forecast_path)
    }, error = function(e) {
      prune_error <<- conditionMessage(e)
      FALSE
    })
  }
  manifest <- list(
    generated_at = as.character(Sys.time()),
    method_dir = normalizePath(method_dir, winslash = "/", mustWork = FALSE),
    status = as.character(status %||% NA_character_)[1L],
    retention_profile = cfg$retention_profile,
    save_forecast_objects = isTRUE(cfg$save_forecast_objects),
    save_compact_fit_paths = isTRUE(cfg$save_compact_fit_paths),
    retain_full_rds_on_failure = isTRUE(cfg$retain_full_rds_on_failure),
    compact_train_path = compact_paths$train,
    compact_holdout_path = compact_paths$holdout,
    compact_train_rows = as.integer(compact_paths$train_rows),
    compact_holdout_rows = as.integer(compact_paths$holdout_rows),
    index_alignment_path = compact_paths$index_alignment,
    index_alignment_status = compact_paths$index_alignment_status,
    forecast_horizon_summary_path = compact_paths$forecast_horizon_summary,
    forecast_horizon_summary_rows = as.integer(compact_paths$forecast_horizon_rows %||% 0L),
    forecast_rolling_origin_path = compact_paths$forecast_rolling_origin_path,
    forecast_rolling_origin_rows = as.integer(compact_paths$forecast_rolling_origin_rows %||% 0L),
    forecast_lead_metrics_path = compact_paths$forecast_lead_metrics,
    forecast_lead_metrics_rows = as.integer(compact_paths$forecast_lead_metrics_rows %||% 0L),
    forecast_rolling_origin_status = compact_paths$forecast_rolling_origin_status,
    index_alignment_ready = isTRUE(alignment_ready),
    compact_ready_for_pruning = isTRUE(compact_ready),
    compact_error = compact_error,
    forecast_objects_path = normalizePath(forecast_path, winslash = "/", mustWork = FALSE),
    forecast_objects_bytes_before = as.numeric(forecast_bytes_before),
    forecast_objects_prune_requested = isTRUE(should_prune_forecast),
    forecast_objects_pruned = isTRUE(pruned),
    forecast_objects_prune_error = prune_error,
    forecast_objects_exists_after = file.exists(forecast_path)
  )
  .qdesn_validation_write_json(file.path(method_dir, "manifest", "output_retention.json"), manifest)
  invisible(manifest)
}

.qdesn_validation_safe_acf1 <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (length(x) < 3L) return(NA_real_)
  out <- tryCatch(stats::acf(x, plot = FALSE, lag.max = 1L)$acf[2L], error = function(...) NA_real_)
  as.numeric(out)
}

.qdesn_validation_safe_ess <- function(x) {
  .qdesn_validation_require_namespace("coda")
  out <- tryCatch(coda::effectiveSize(coda::as.mcmc(as.numeric(x))), error = function(...) NA_real_)
  as.numeric(out)[1L]
}

.qdesn_validation_safe_geweke_absz <- function(x) {
  .qdesn_validation_require_namespace("coda")
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (length(x) < 10L) return(NA_real_)
  out <- tryCatch(coda::geweke.diag(coda::as.mcmc(x))$z, error = function(...) NA_real_)
  abs(as.numeric(out)[1L])
}

.qdesn_validation_halfchain_drift <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  n <- length(x)
  if (n < 8L) return(NA_real_)
  n1 <- floor(n / 2L)
  x1 <- x[seq_len(n1)]
  x2 <- x[seq.int(n1 + 1L, n)]
  s_full <- stats::sd(x)
  if (!is.finite(s_full) || s_full <= 1e-12) {
    return(if (isTRUE(all.equal(mean(x1), mean(x2), tolerance = 1e-12))) 0 else NA_real_)
  }
  abs(mean(x1) - mean(x2)) / s_full
}

.qdesn_validation_trace_tail_metrics <- function(x, tail_window = 5L, scale_floor = 1e-8, unit_floor = FALSE) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (!length(x)) {
    return(list(
      n_total = 0L,
      n_tail = 0L,
      last = NA_real_,
      rel_range = NA_real_,
      rel_drift = NA_real_,
      rel_step_max = NA_real_
    ))
  }
  tail_window <- max(2L, as.integer(tail_window)[1L])
  tail_x <- utils::tail(x, min(length(x), tail_window))
  scale <- max(scale_floor, stats::median(abs(tail_x)), abs(tail_x[[length(tail_x)]]))
  if (isTRUE(unit_floor)) scale <- max(scale, 1)
  list(
    n_total = length(x),
    n_tail = length(tail_x),
    last = as.numeric(tail_x[[length(tail_x)]]),
    rel_range = if (length(tail_x) > 1L) (max(tail_x) - min(tail_x)) / scale else 0,
    rel_drift = if (length(tail_x) > 1L) abs(tail_x[[length(tail_x)]] - tail_x[[1L]]) / scale else 0,
    rel_step_max = if (length(tail_x) > 1L) max(abs(diff(tail_x))) / scale else 0
  )
}

.qdesn_validation_signoff_cfg <- function(defaults = NULL) {
  base <- list(
    vb = list(
      tail_window = 5L,
      min_trace_length = 5L,
      elbo_rel_range_pass = 0.01,
      elbo_rel_range_warn = 0.05,
      core_rel_range_pass = 0.02,
      core_rel_range_warn = 0.10,
      rhs_rel_range_pass = 0.05,
      rhs_rel_range_warn = 0.20,
      require_converged_for_pass = TRUE
    ),
    mcmc = list(
      min_keep_pass = 160L,
      min_keep_warn = 100L,
      ess_pass = 30,
      ess_warn = 10,
      acf1_pass = 0.90,
      acf1_warn = 0.98,
      geweke_absz_pass = 2.0,
      geweke_absz_warn = 3.0,
      half_drift_pass = 0.25,
      half_drift_warn = 0.50
    )
  )
  if (is.list(defaults) && is.list(defaults$signoff)) {
    base <- utils::modifyList(base, defaults$signoff)
  }
  base
}

.qdesn_validation_bind_rows <- function(rows) {
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) return(data.frame(stringsAsFactors = FALSE))
  cols <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows2 <- lapply(rows, function(df) {
    miss <- setdiff(cols, names(df))
    for (nm in miss) df[[nm]] <- rep(NA, nrow(df))
    df[, cols, drop = FALSE]
  })
  do.call(rbind, rows2)
}

.qdesn_validation_write_df <- function(df, path) {
  .qdesn_validation_dir_create(dirname(path))
  if (!ncol(df)) {
    invisible(file.create(path))
    return(invisible(path))
  }
  utils::write.csv(df, path, row.names = FALSE)
  invisible(path)
}

.qdesn_validation_group_numeric <- function(df, group_cols, numeric_cols) {
  if (!nrow(df)) return(data.frame(stringsAsFactors = FALSE))
  group_cols <- group_cols[group_cols %in% names(df)]
  numeric_cols <- numeric_cols[numeric_cols %in% names(df)]
  if (!length(group_cols) || !length(numeric_cols)) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  split_idx <- split(seq_len(nrow(df)), interaction(df[, group_cols, drop = FALSE], drop = TRUE, lex.order = TRUE))
  rows <- lapply(split_idx, function(idx) {
    sub <- df[idx, , drop = FALSE]
    row <- sub[1L, group_cols, drop = FALSE]
    row$n_rows <- nrow(sub)
    for (nm in numeric_cols) {
      x <- as.numeric(sub[[nm]])
      ok <- is.finite(x)
      row[[paste0(nm, "_n_finite")]] <- sum(ok)
      row[[paste0(nm, "_mean")]] <- if (any(ok)) mean(x[ok]) else NA_real_
      row[[paste0(nm, "_median")]] <- if (any(ok)) stats::median(x[ok]) else NA_real_
      row[[paste0(nm, "_sd")]] <- if (sum(ok) > 1L) stats::sd(x[ok]) else NA_real_
      row[[paste0(nm, "_min")]] <- if (any(ok)) min(x[ok]) else NA_real_
      row[[paste0(nm, "_max")]] <- if (any(ok)) max(x[ok]) else NA_real_
    }
    row
  })
  .qdesn_validation_bind_rows(rows)
}

.qdesn_validation_df_to_markdown <- function(df, digits = 3L) {
  if (is.null(df) || !nrow(df)) {
    return(c("| empty |", "|---|", "| no rows |"))
  }
  fmt_one <- function(x) {
    if (is.numeric(x)) {
      ifelse(is.finite(x), format(round(x, digits), nsmall = 0L, trim = TRUE), "NA")
    } else {
      out <- as.character(x)
      out[is.na(out) | !nzchar(out)] <- "NA"
      out
    }
  }
  df_fmt <- as.data.frame(lapply(df, fmt_one), stringsAsFactors = FALSE)
  header <- paste0("| ", paste(names(df_fmt), collapse = " | "), " |")
  rule <- paste0("|", paste(rep("---", ncol(df_fmt)), collapse = "|"), "|")
  body <- apply(df_fmt, 1L, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  c(header, rule, body)
}

.qdesn_validation_append_latent_v_failure_fields <- function(base, latent_v_failure = NULL) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  failure <- latent_v_failure %||% list()
  chi_v <- failure$chi_v %||% list()
  psi_v <- failure$psi_v %||% list()

  base$mcmc_failure_family <- as.character(failure$failure_family %||% NA_character_)[1L]
  base$mcmc_failure_iteration <- as.integer(failure$iteration %||% NA_integer_)[1L]
  base$mcmc_failure_phase <- as.character(failure$phase %||% NA_character_)[1L]
  base$mcmc_failure_sigma <- as.numeric(failure$sigma %||% NA_real_)[1L]
  base$mcmc_failure_gamma <- as.numeric(failure$gamma %||% NA_real_)[1L]
  base$mcmc_failure_tau <- as.numeric(failure$tau %||% NA_real_)[1L]
  base$mcmc_failure_c2 <- as.numeric(failure$c2 %||% NA_real_)[1L]
  base$mcmc_failure_beta_norm <- as.numeric(failure$beta_norm %||% NA_real_)[1L]
  base$mcmc_failure_latent_v_warmup_active <- if (is.null(failure$latent_v_warmup_active)) NA else isTRUE(failure$latent_v_warmup_active)
  base$mcmc_failure_latent_v_update_reason <- as.character(failure$latent_v_update_reason %||% NA_character_)[1L]
  base$mcmc_failure_latent_v_rescue_enabled <- if (is.null(failure$latent_v_rescue_enabled)) NA else isTRUE(failure$latent_v_rescue_enabled)
  base$mcmc_failure_latent_v_rescue_strategy <- as.character(failure$latent_v_rescue_strategy %||% NA_character_)[1L]
  base$mcmc_failure_latent_v_rescue_count <- as.integer(failure$latent_v_rescue_count %||% NA_integer_)[1L]
  base$mcmc_failure_latent_v_rescue_consecutive <- as.integer(failure$latent_v_rescue_consecutive %||% NA_integer_)[1L]
  base$mcmc_failure_theta_warmup_active <- if (is.null(failure$theta_warmup_active)) NA else isTRUE(failure$theta_warmup_active)
  base$mcmc_failure_theta_update_reason <- as.character(failure$theta_update_reason %||% NA_character_)[1L]
  base$mcmc_failure_chi_v_min <- as.numeric(chi_v$min %||% NA_real_)[1L]
  base$mcmc_failure_chi_v_max <- as.numeric(chi_v$max %||% NA_real_)[1L]
  base$mcmc_failure_chi_v_mean <- as.numeric(chi_v$mean %||% NA_real_)[1L]
  base$mcmc_failure_chi_v_nonfinite_n <- as.integer(chi_v$n_nonfinite %||% NA_integer_)[1L]
  base$mcmc_failure_psi_v_min <- as.numeric(psi_v$min %||% NA_real_)[1L]
  base$mcmc_failure_psi_v_max <- as.numeric(psi_v$max %||% NA_real_)[1L]
  base$mcmc_failure_psi_v_mean <- as.numeric(psi_v$mean %||% NA_real_)[1L]
  base$mcmc_failure_psi_v_nonfinite_n <- as.integer(psi_v$n_nonfinite %||% NA_integer_)[1L]
  base
}

.qdesn_validation_append_precision_beta_failure_fields <- function(base, precision_beta_failure = NULL) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  failure <- precision_beta_failure %||% list()

  base$mcmc_failure_family <- as.character(failure$failure_family %||% base$mcmc_failure_family %||% NA_character_)[1L]
  base$mcmc_failure_iteration <- as.integer(failure$iteration %||% base$mcmc_failure_iteration %||% NA_integer_)[1L]
  base$mcmc_failure_phase <- as.character(failure$phase %||% base$mcmc_failure_phase %||% NA_character_)[1L]
  base$mcmc_failure_sigma <- as.numeric(failure$sigma %||% base$mcmc_failure_sigma %||% NA_real_)[1L]
  base$mcmc_failure_gamma <- as.numeric(failure$gamma %||% base$mcmc_failure_gamma %||% NA_real_)[1L]
  base$mcmc_failure_tau <- as.numeric(failure$tau %||% base$mcmc_failure_tau %||% NA_real_)[1L]
  base$mcmc_failure_c2 <- as.numeric(failure$c2 %||% base$mcmc_failure_c2 %||% NA_real_)[1L]
  base$mcmc_failure_beta_norm <- as.numeric(failure$beta_norm %||% base$mcmc_failure_beta_norm %||% NA_real_)[1L]
  base$mcmc_failure_theta_update_reason <- as.character(failure$theta_update_reason %||% base$mcmc_failure_theta_update_reason %||% NA_character_)[1L]
  base$mcmc_failure_precision_strategy <- as.character(failure$precision_strategy %||% NA_character_)[1L]
  base$mcmc_failure_precision_attempt_count <- as.integer(failure$precision_attempt_count %||% NA_integer_)[1L]
  base$mcmc_failure_precision_jitter_used <- as.numeric(failure$precision_jitter_used %||% NA_real_)[1L]
  base$mcmc_failure_precision_max_jitter_tried <- as.numeric(failure$precision_max_jitter_tried %||% NA_real_)[1L]
  base$mcmc_failure_precision_eigen_attempted <- if (is.null(failure$precision_eigen_attempted)) NA else isTRUE(failure$precision_eigen_attempted)
  base$mcmc_failure_precision_eigen_floor <- as.numeric(failure$precision_eigen_floor %||% NA_real_)[1L]
  base$mcmc_failure_precision_min_eigen <- as.numeric(failure$precision_min_eigen %||% NA_real_)[1L]
  base$mcmc_failure_precision_matrix_dim <- as.integer(failure$precision_matrix_dim %||% NA_integer_)[1L]
  base$mcmc_failure_precision_diag_min <- as.numeric(failure$precision_diag_min %||% NA_real_)[1L]
  base$mcmc_failure_precision_diag_mean <- as.numeric(failure$precision_diag_mean %||% NA_real_)[1L]
  base$mcmc_failure_precision_diag_max <- as.numeric(failure$precision_diag_max %||% NA_real_)[1L]
  base$mcmc_failure_precision_symmetry_max_abs_diff <- as.numeric(failure$precision_symmetry_max_abs_diff %||% NA_real_)[1L]
  base$mcmc_failure_conditioning_mode <- as.character(failure$conditioning_mode %||% NA_character_)[1L]
  base$mcmc_failure_core_update_mode <- as.character(failure$core_update_mode %||% NA_character_)[1L]
  base
}

.qdesn_validation_extract_error_payload <- function(err = NULL, log_lines = NULL) {
  out <- list()
  if (!is.null(err) && !is.null(err$latent_v_failure)) {
    out$latent_v_failure <- err$latent_v_failure
  }
  if (!is.null(err) && !is.null(err$precision_beta_failure)) {
    out$precision_beta_failure <- err$precision_beta_failure
  }
  if (!length(out)) {
    lines <- as.character(log_lines %||% character(0))
    marker_idx <- grep("^QDESN_LATENT_V_FAILURE_JSON=", lines)
    if (length(marker_idx)) {
      json_line <- sub("^QDESN_LATENT_V_FAILURE_JSON=", "", lines[max(marker_idx)])
      parsed <- tryCatch(jsonlite::fromJSON(json_line, simplifyVector = FALSE), error = function(...) NULL)
      if (is.list(parsed)) out$latent_v_failure <- parsed
    }
    marker_idx <- grep("^QDESN_PRECISION_BETA_FAILURE_JSON=", lines)
    if (length(marker_idx)) {
      json_line <- sub("^QDESN_PRECISION_BETA_FAILURE_JSON=", "", lines[max(marker_idx)])
      parsed <- tryCatch(jsonlite::fromJSON(json_line, simplifyVector = FALSE), error = function(...) NULL)
      if (is.list(parsed)) out$precision_beta_failure <- parsed
    }
  }
  out
}

.qdesn_validation_failure_health_row <- function(method, root_spec, status, error_payload = NULL) {
  base <- data.frame(
    root_id = root_spec$root_id,
    scenario = root_spec$scenario,
    tau = as.numeric(root_spec$tau),
    likelihood_family = as.character(root_spec$likelihood_family %||% "exal")[1L],
    beta_prior_type = root_spec$beta_prior_type,
    seed = as.integer(root_spec$seed),
    reservoir_profile = root_spec$reservoir_profile,
    method = method,
    status = as.character(status %||% NA_character_)[1L],
    wall_seconds = NA_real_,
    total_stage_seconds = NA_real_,
    forecast_CRPS_mean = NA_real_,
    forecast_PinballMean_mean = NA_real_,
    forecast_S_mean = NA_real_,
    forecast_qhat_mae = NA_real_,
    forecast_qhat_rmse = NA_real_,
    forecast_pinball_tau = NA_real_,
    forecast_qhat_bias = NA_real_,
    signal_qhat_mae = NA_real_,
    signal_qhat_rmse = NA_real_,
    signal_qhat_corr = NA_real_,
    rhs_diag_available = NA,
    rhs_collapse_flag = NA,
    rhs_collapse_flag_bound = NA,
    rhs_collapse_flag_shrink = NA,
    rhs_diag_tau_last = NA_real_,
    rhs_diag_E_invV_med_last = NA_real_,
    rhs_diag_beta_l2_last = NA_real_,
    rhs_diag_beta_small_frac_1e4_last = NA_real_,
    rhs_root_cause_context = NA_character_,
    unhealthy = FALSE,
    unhealthy_reason = "",
    fit_class = NA_character_,
    fit_runtime_seconds = NA_real_,
    finite_ok = FALSE,
    domain_ok = FALSE,
    mcmc_latent_v_warmup_iters = NA_integer_,
    mcmc_latent_v_sparse_update_every = NA_integer_,
    mcmc_latent_v_sparse_update_until_iter = NA_integer_,
    mcmc_latent_v_first_postwarmup_update_iter = NA_integer_,
    mcmc_latent_v_updates_burn = NA_integer_,
    mcmc_latent_v_updates_keep = NA_integer_,
    mcmc_latent_v_frozen_burn_rate = NA_real_,
    mcmc_latent_v_sparse_hold_burn_rate = NA_real_,
    mcmc_latent_v_rescue_on_invalid = NA,
    mcmc_latent_v_rescue_strategy = NA_character_,
    mcmc_latent_v_rescue_max_consecutive = NA_integer_,
    mcmc_latent_v_rescues_burn = NA_integer_,
    mcmc_latent_v_rescues_keep = NA_integer_,
    mcmc_latent_v_rescue_burn_rate = NA_real_,
    mcmc_latent_v_rescue_max_streak = NA_integer_,
    mcmc_theta_warmup_iters = NA_integer_,
    mcmc_theta_sparse_update_every = NA_integer_,
    mcmc_theta_sparse_update_until_iter = NA_integer_,
    mcmc_theta_first_postwarmup_update_iter = NA_integer_,
    mcmc_theta_updates_burn = NA_integer_,
    mcmc_theta_updates_keep = NA_integer_,
    mcmc_theta_frozen_burn_rate = NA_real_,
    mcmc_theta_sparse_hold_burn_rate = NA_real_,
    stringsAsFactors = FALSE
  )
  base <- .qdesn_validation_append_latent_v_failure_fields(base, (error_payload %||% list())$latent_v_failure %||% NULL)
  .qdesn_validation_append_precision_beta_failure_fields(base, (error_payload %||% list())$precision_beta_failure %||% NULL)
}

.qdesn_validation_method_health <- function(method, root_spec, summary_obj) {
  fit <- .qdesn_validation_extract_fit(summary_obj)
  summary_row <- summary_obj$summary
  forecast_df <- .qdesn_validation_extract_forecast_df(summary_obj)
  add_reason <- function(curr, new_reason) {
    curr <- as.character(curr %||% NA_character_)[1L]
    new_reason <- as.character(new_reason %||% NA_character_)[1L]
    if (is.na(new_reason) || !nzchar(new_reason)) return(if (is.na(curr)) "" else curr)
    if (is.na(curr) || !nzchar(curr)) return(new_reason)
    .qdesn_validation_join_reasons(c(curr, new_reason))
  }
  pinball_tau <- NA_real_
  qhat_mae <- NA_real_
  qhat_rmse <- NA_real_
  qhat_corr <- NA_real_
  qhat_bias <- NA_real_
  if (!is.null(forecast_df) && nrow(forecast_df) &&
      all(c("q_pred", "q_true", "y") %in% names(forecast_df))) {
    q_pred <- as.numeric(forecast_df$q_pred)
    q_true <- as.numeric(forecast_df$q_true)
    err_y <- as.numeric(forecast_df$y) - as.numeric(forecast_df$q_pred)
    p0 <- as.numeric(root_spec$tau)
    pinball_tau <- mean((p0 - (err_y < 0)) * err_y, na.rm = TRUE)
    q_err <- q_pred - q_true
    qhat_mae <- mean(abs(q_err), na.rm = TRUE)
    qhat_rmse <- sqrt(mean(q_err^2, na.rm = TRUE))
    qhat_bias <- mean(q_err, na.rm = TRUE)
    keep_idx <- is.finite(q_pred) & is.finite(q_true)
    if (sum(keep_idx) >= 3L) {
      qhat_corr <- suppressWarnings(stats::cor(q_pred[keep_idx], q_true[keep_idx]))
      if (!is.finite(qhat_corr)) qhat_corr <- NA_real_
    }
  }
  rhs_diag_available <- as.logical(summary_row$rhs_diag_available[1L] %||% NA)
  rhs_collapse_flag <- as.logical(summary_row$rhs_collapse_flag_any[1L] %||% NA)
  rhs_collapse_flag_bound <- as.logical(summary_row$rhs_collapse_flag_bound_any[1L] %||% NA)
  rhs_collapse_flag_shrink <- as.logical(summary_row$rhs_collapse_flag_shrink_any[1L] %||% NA)
  rhs_unhealthy_any <- as.logical(summary_row$rhs_unhealthy_any[1L] %||% NA)
  rhs_unhealthy_reason <- as.character(summary_row$rhs_unhealthy_reason[1L] %||% NA_character_)
  rhs_root_cause_context <- as.character(summary_row$rhs_root_cause_context[1L] %||% NA_character_)
  base <- data.frame(
    root_id = root_spec$root_id,
    scenario = root_spec$scenario,
    tau = as.numeric(root_spec$tau),
    likelihood_family = as.character(root_spec$likelihood_family %||% "exal")[1L],
    beta_prior_type = root_spec$beta_prior_type,
    seed = as.integer(root_spec$seed),
    reservoir_profile = root_spec$reservoir_profile,
    method = method,
    status = as.character(summary_row$status[1L] %||% NA_character_),
    wall_seconds = as.numeric(summary_row$wall_seconds[1L] %||% NA_real_),
    total_stage_seconds = as.numeric(summary_row$total_stage_seconds[1L] %||% NA_real_),
    forecast_CRPS_mean = as.numeric(summary_row$forecast_CRPS_mean[1L] %||% NA_real_),
    forecast_PinballMean_mean = as.numeric(summary_row$forecast_PinballMean_mean[1L] %||% NA_real_),
    forecast_S_mean = as.numeric(summary_row$forecast_S_mean[1L] %||% NA_real_),
    forecast_qhat_mae = qhat_mae,
    forecast_qhat_rmse = qhat_rmse,
    forecast_pinball_tau = pinball_tau,
    forecast_qhat_bias = qhat_bias,
    signal_qhat_mae = qhat_mae,
    signal_qhat_rmse = qhat_rmse,
    signal_qhat_corr = qhat_corr,
    rhs_diag_available = rhs_diag_available,
    rhs_collapse_flag = rhs_collapse_flag,
    rhs_collapse_flag_bound = rhs_collapse_flag_bound,
    rhs_collapse_flag_shrink = rhs_collapse_flag_shrink,
    rhs_diag_tau_last = as.numeric(summary_row$rhs_tau_last[1L] %||% NA_real_),
    rhs_diag_E_invV_med_last = as.numeric(summary_row$rhs_E_invV_med_last[1L] %||% NA_real_),
    rhs_diag_beta_l2_last = as.numeric(summary_row$rhs_beta_l2_last[1L] %||% NA_real_),
    rhs_diag_beta_small_frac_1e4_last = as.numeric(summary_row$rhs_beta_small_frac_1e4_last[1L] %||% NA_real_),
    rhs_root_cause_context = rhs_root_cause_context,
    unhealthy = FALSE,
    unhealthy_reason = "",
    mcmc_latent_v_warmup_iters = NA_integer_,
    mcmc_latent_v_sparse_update_every = NA_integer_,
    mcmc_latent_v_sparse_update_until_iter = NA_integer_,
    mcmc_latent_v_first_postwarmup_update_iter = NA_integer_,
    mcmc_latent_v_updates_burn = NA_integer_,
    mcmc_latent_v_updates_keep = NA_integer_,
    mcmc_latent_v_frozen_burn_rate = NA_real_,
    mcmc_latent_v_sparse_hold_burn_rate = NA_real_,
    mcmc_latent_v_rescue_on_invalid = NA,
    mcmc_latent_v_rescue_strategy = NA_character_,
    mcmc_latent_v_rescue_max_consecutive = NA_integer_,
    mcmc_latent_v_rescues_burn = NA_integer_,
    mcmc_latent_v_rescues_keep = NA_integer_,
    mcmc_latent_v_rescue_burn_rate = NA_real_,
    mcmc_latent_v_rescue_max_streak = NA_integer_,
    mcmc_theta_warmup_iters = NA_integer_,
    mcmc_theta_sparse_update_every = NA_integer_,
    mcmc_theta_sparse_update_until_iter = NA_integer_,
    mcmc_theta_first_postwarmup_update_iter = NA_integer_,
    mcmc_theta_updates_burn = NA_integer_,
    mcmc_theta_updates_keep = NA_integer_,
    mcmc_theta_frozen_burn_rate = NA_real_,
    mcmc_theta_sparse_hold_burn_rate = NA_real_,
    stringsAsFactors = FALSE
  )
  base <- .qdesn_validation_append_latent_v_failure_fields(base, NULL)
  if (isTRUE(rhs_unhealthy_any)) {
    base$unhealthy <- TRUE
    base$unhealthy_reason <- add_reason(base$unhealthy_reason, rhs_unhealthy_reason %||% "rhs_unhealthy")
  }
  if (isTRUE(rhs_collapse_flag_shrink)) {
    base$unhealthy <- TRUE
    base$unhealthy_reason <- add_reason(base$unhealthy_reason, "rhs_shrinkage_collapse")
  }
  if (isTRUE(rhs_collapse_flag_bound)) {
    base$unhealthy <- TRUE
    base$unhealthy_reason <- add_reason(base$unhealthy_reason, "rhs_tau_bound_collapse")
  }
  if (root_spec$beta_prior_type %in% c("rhs", "rhs_ns") &&
      identical(method, "vb") &&
      !isTRUE(rhs_diag_available)) {
    base$unhealthy <- TRUE
    base$unhealthy_reason <- add_reason(base$unhealthy_reason, "rhs_diagnostics_missing")
  }
  if (is.null(fit)) {
    base$fit_class <- NA_character_
    base$fit_runtime_seconds <- NA_real_
    base$finite_ok <- FALSE
    base$domain_ok <- FALSE
    return(base)
  }

  if (.qdesn_validation_is_vb_fit(fit)) {
    gamma_trace <- as.numeric(fit$misc$gamma_trace %||% numeric(0))
    sigma_trace <- as.numeric(fit$misc$sigma_trace %||% numeric(0))
    elbo_trace <- as.numeric(fit$misc$elbo_trace %||% numeric(0))
    beta_mean <- as.numeric(fit$qbeta$m %||% numeric(0))
    rhs_tau_trace <- as.numeric(fit$misc$rhs_tau_trace %||% numeric(0))
    rhs_c2_trace <- as.numeric(fit$misc$rhs_c2_trace %||% numeric(0))

    base$fit_class <- "exal_vb"
    base$fit_runtime_seconds <- as.numeric(fit$run.time %||% NA_real_)
    base$vb_converged <- isTRUE(fit$converged)
    base$vb_iter <- as.integer(fit$iter %||% NA_integer_)
    base$vb_gamma_last <- if (length(gamma_trace)) utils::tail(gamma_trace, 1L) else as.numeric(fit$qsiggam$gamma_mean %||% NA_real_)
    base$vb_sigma_last <- if (length(sigma_trace)) utils::tail(sigma_trace, 1L) else as.numeric(fit$qsiggam$sigma_mean %||% NA_real_)
    base$vb_elbo_last <- if (length(elbo_trace)) utils::tail(elbo_trace, 1L) else as.numeric(fit$misc$elbo %||% NA_real_)
    base$vb_beta_norm <- sqrt(sum(beta_mean * beta_mean))
    base$vb_sigmagam_warmup_iters <- as.integer((fit$misc$sigmagam %||% list())$freeze_warmup_iters %||% NA_integer_)
    base$vb_sigmagam_required_postwarmup_updates <- as.integer(fit$misc$sigmagam_required_postwarmup_updates %||% NA_integer_)
    base$vb_sigmagam_first_active_iter <- as.integer(fit$misc$sigmagam_first_active_iter %||% NA_integer_)
    base$vb_sigmagam_update_count <- as.integer(fit$misc$sigmagam_update_count %||% NA_integer_)
    base$vb_sigmagam_postwarmup_update_count <- as.integer(fit$misc$sigmagam_postwarmup_update_count %||% NA_integer_)
    base$rhs_tau_last <- if (length(rhs_tau_trace)) utils::tail(rhs_tau_trace, 1L) else NA_real_
    base$rhs_c2_last <- if (length(rhs_c2_trace)) utils::tail(rhs_c2_trace, 1L) else NA_real_
    base$finite_ok <- all(is.finite(c(base$vb_gamma_last, base$vb_sigma_last, base$vb_beta_norm)))
    base$domain_ok <- is.finite(base$vb_sigma_last) && base$vb_sigma_last > 0
    return(base)
  }

  if (.qdesn_validation_is_mcmc_fit(fit)) {
    beta_draws <- as.matrix(fit$samp.beta)
    gamma_draws <- as.numeric(fit$samp.gamma)
    sigma_draws <- as.numeric(fit$samp.sigma)
    beta_norm <- sqrt(rowSums(beta_draws * beta_draws))
    tau_draws <- if (!is.null(fit$samp.tau)) as.numeric(fit$samp.tau) else numeric(0)
    c2_draws <- if (!is.null(fit$samp.c2)) as.numeric(fit$samp.c2) else numeric(0)
    lambda_mean_draws <- if (!is.null(fit$samp.lambda_mean)) as.numeric(fit$samp.lambda_mean) else numeric(0)

    base$fit_class <- "exal_mcmc"
    base$fit_runtime_seconds <- as.numeric(fit$run.time %||% NA_real_)
    base$mcmc_n_keep <- as.integer(length(gamma_draws))
    base$mcmc_gamma_mean <- if (length(gamma_draws)) mean(gamma_draws) else NA_real_
    base$mcmc_sigma_mean <- if (length(sigma_draws)) mean(sigma_draws) else NA_real_
    base$mcmc_beta_norm_mean <- if (length(beta_norm)) mean(beta_norm) else NA_real_
    base$mcmc_ess_gamma <- .qdesn_validation_safe_ess(gamma_draws)
    base$mcmc_ess_sigma <- .qdesn_validation_safe_ess(sigma_draws)
    base$mcmc_ess_beta_norm <- .qdesn_validation_safe_ess(beta_norm)
    base$mcmc_acf1_gamma <- .qdesn_validation_safe_acf1(gamma_draws)
    base$mcmc_acf1_sigma <- .qdesn_validation_safe_acf1(sigma_draws)
    base$mcmc_acf1_beta_norm <- .qdesn_validation_safe_acf1(beta_norm)
    base$mcmc_gamma_slice_steps_out_mean <- as.numeric(fit$diagnostics$gamma_slice_steps_out_mean %||% NA_real_)
    base$mcmc_gamma_slice_shrink_mean <- as.numeric(fit$diagnostics$gamma_slice_shrink_mean %||% NA_real_)
    base$mcmc_core_update_mode <- as.character(fit$diagnostics$core_update_mode %||% (fit$control$slice %||% list())$core_update_mode %||% NA_character_)
    base$mcmc_core_extra_passes <- as.integer((fit$control$slice %||% list())$core_extra_passes %||% NA_integer_)
    base$mcmc_use_log_sigma <- isTRUE((fit$control$transforms %||% list())$use_log_sigma %||% (fit$control$transforms %||% list())$use_transformed_sigma %||% FALSE)
    base$mcmc_width_gamma <- as.numeric((fit$control$slice %||% list())$width_gamma %||% NA_real_)
    base$mcmc_width_sigma <- as.numeric((fit$control$slice %||% list())$width_sigma %||% (fit$control$slice %||% list())$width_log_sigma %||% NA_real_)
    base$mcmc_max_steps_out <- as.integer((fit$control$slice %||% list())$max_steps_out %||% NA_integer_)
    base$mcmc_max_shrink <- as.integer((fit$control$slice %||% list())$max_shrink %||% NA_integer_)
    base$mcmc_max_steps_out_sigma <- as.integer((fit$control$slice %||% list())$max_steps_out_sigma %||% (fit$control$slice %||% list())$max_steps_out %||% NA_integer_)
    base$mcmc_max_shrink_sigma <- as.integer((fit$control$slice %||% list())$max_shrink_sigma %||% (fit$control$slice %||% list())$max_shrink %||% NA_integer_)
    base$mcmc_conditioning_mode <- as.character((fit$diagnostics$conditioning %||% list())$mode %||% NA_character_)
    base$mcmc_conditioning_active <- isTRUE((fit$diagnostics$conditioning %||% list())$active %||% FALSE)
    base$mcmc_conditioning_raw_kappa <- as.numeric((fit$diagnostics$conditioning %||% list())$raw_condition_kappa %||% NA_real_)
    base$mcmc_conditioning_work_kappa <- as.numeric((fit$diagnostics$conditioning %||% list())$conditioned_condition_kappa %||% NA_real_)
    base$mcmc_conditioning_gain_ratio <- as.numeric((fit$diagnostics$conditioning %||% list())$condition_gain_ratio %||% NA_real_)
    base$mcmc_conditioning_scaled_columns_n <- as.integer((fit$diagnostics$conditioning %||% list())$scaled_columns_n %||% NA_integer_)
    base$mcmc_precision_beta_enabled <- isTRUE((fit$diagnostics$precision_beta %||% list())$enabled %||% FALSE)
    base$mcmc_precision_beta_preset <- as.character((fit$diagnostics$precision_beta %||% list())$preset %||% NA_character_)[1L]
    base$mcmc_precision_beta_symmetrize <- isTRUE((fit$diagnostics$precision_beta %||% list())$symmetrize %||% FALSE)
    base$mcmc_precision_beta_eigen_fallback <- isTRUE((fit$diagnostics$precision_beta %||% list())$eigen_fallback %||% FALSE)
    base$mcmc_precision_beta_jitter_ladder_max <- suppressWarnings(max(as.numeric((fit$diagnostics$precision_beta %||% list())$jitter_ladder %||% NA_real_), na.rm = TRUE))
    if (!is.finite(base$mcmc_precision_beta_jitter_ladder_max)) base$mcmc_precision_beta_jitter_ladder_max <- NA_real_
    base$mcmc_precision_beta_direct_successes <- as.integer((fit$diagnostics$precision_beta %||% list())$direct_successes %||% NA_integer_)
    base$mcmc_precision_beta_jitter_successes <- as.integer((fit$diagnostics$precision_beta %||% list())$jitter_successes %||% NA_integer_)
    base$mcmc_precision_beta_eigen_successes <- as.integer((fit$diagnostics$precision_beta %||% list())$eigen_successes %||% NA_integer_)
    base$mcmc_precision_beta_rescue_count <- as.integer((fit$diagnostics$precision_beta %||% list())$rescue_count %||% NA_integer_)
    base$mcmc_precision_beta_first_rescue_iter <- as.integer((fit$diagnostics$precision_beta %||% list())$first_rescue_iter %||% NA_integer_)
    base$mcmc_precision_beta_max_jitter_used <- as.numeric((fit$diagnostics$precision_beta %||% list())$max_jitter_used %||% NA_real_)
    base$mcmc_latent_v_warmup_iters <- as.integer((fit$diagnostics$latent_v %||% list())$freeze_burnin_iters %||% NA_integer_)
    base$mcmc_latent_v_sparse_update_every <- as.integer((fit$diagnostics$latent_v %||% list())$sparse_update_every %||% NA_integer_)
    base$mcmc_latent_v_sparse_update_until_iter <- as.integer((fit$diagnostics$latent_v %||% list())$sparse_update_until_iter %||% NA_integer_)
    base$mcmc_latent_v_first_postwarmup_update_iter <- as.integer((fit$diagnostics$latent_v %||% list())$first_postwarmup_update_iter %||% NA_integer_)
    base$mcmc_latent_v_updates_burn <- as.integer((fit$diagnostics$latent_v %||% list())$updates_burn %||% NA_integer_)
    base$mcmc_latent_v_updates_keep <- as.integer((fit$diagnostics$latent_v %||% list())$updates_keep %||% NA_integer_)
    base$mcmc_latent_v_frozen_burn_rate <- as.numeric((fit$diagnostics$latent_v %||% list())$frozen_burn_rate %||% NA_real_)
    base$mcmc_latent_v_sparse_hold_burn_rate <- as.numeric((fit$diagnostics$latent_v %||% list())$sparse_hold_burn_rate %||% NA_real_)
    base$mcmc_latent_v_rescue_on_invalid <- isTRUE((fit$diagnostics$latent_v %||% list())$rescue_on_invalid %||% FALSE)
    base$mcmc_latent_v_rescue_strategy <- as.character((fit$diagnostics$latent_v %||% list())$rescue_strategy %||% NA_character_)
    base$mcmc_latent_v_rescue_max_consecutive <- as.integer((fit$diagnostics$latent_v %||% list())$rescue_max_consecutive %||% NA_integer_)
    base$mcmc_latent_v_rescues_burn <- as.integer((fit$diagnostics$latent_v %||% list())$rescues_burn %||% NA_integer_)
    base$mcmc_latent_v_rescues_keep <- as.integer((fit$diagnostics$latent_v %||% list())$rescues_keep %||% NA_integer_)
    base$mcmc_latent_v_rescue_burn_rate <- as.numeric((fit$diagnostics$latent_v %||% list())$rescue_burn_rate %||% NA_real_)
    base$mcmc_latent_v_rescue_max_streak <- as.integer((fit$diagnostics$latent_v %||% list())$rescue_max_streak %||% NA_integer_)
    base$mcmc_latent_s_warmup_iters <- as.integer((fit$diagnostics$latent_s %||% list())$freeze_burnin_iters %||% NA_integer_)
    base$mcmc_latent_s_sparse_update_every <- as.integer((fit$diagnostics$latent_s %||% list())$sparse_update_every %||% NA_integer_)
    base$mcmc_latent_s_sparse_update_until_iter <- as.integer((fit$diagnostics$latent_s %||% list())$sparse_update_until_iter %||% NA_integer_)
    base$mcmc_latent_s_first_postwarmup_update_iter <- as.integer((fit$diagnostics$latent_s %||% list())$first_postwarmup_update_iter %||% NA_integer_)
    base$mcmc_latent_s_updates_burn <- as.integer((fit$diagnostics$latent_s %||% list())$updates_burn %||% NA_integer_)
    base$mcmc_latent_s_updates_keep <- as.integer((fit$diagnostics$latent_s %||% list())$updates_keep %||% NA_integer_)
    base$mcmc_latent_s_frozen_burn_rate <- as.numeric((fit$diagnostics$latent_s %||% list())$frozen_burn_rate %||% NA_real_)
    base$mcmc_latent_s_sparse_hold_burn_rate <- as.numeric((fit$diagnostics$latent_s %||% list())$sparse_hold_burn_rate %||% NA_real_)
    base$mcmc_theta_warmup_iters <- as.integer((fit$diagnostics$theta %||% list())$freeze_burnin_iters %||% NA_integer_)
    base$mcmc_theta_sparse_update_every <- as.integer((fit$diagnostics$theta %||% list())$sparse_update_every %||% NA_integer_)
    base$mcmc_theta_sparse_update_until_iter <- as.integer((fit$diagnostics$theta %||% list())$sparse_update_until_iter %||% NA_integer_)
    base$mcmc_theta_first_postwarmup_update_iter <- as.integer((fit$diagnostics$theta %||% list())$first_postwarmup_update_iter %||% NA_integer_)
    base$mcmc_theta_updates_burn <- as.integer((fit$diagnostics$theta %||% list())$updates_burn %||% NA_integer_)
    base$mcmc_theta_updates_keep <- as.integer((fit$diagnostics$theta %||% list())$updates_keep %||% NA_integer_)
    base$mcmc_theta_frozen_burn_rate <- as.numeric((fit$diagnostics$theta %||% list())$frozen_burn_rate %||% NA_real_)
    base$mcmc_theta_sparse_hold_burn_rate <- as.numeric((fit$diagnostics$theta %||% list())$sparse_hold_burn_rate %||% NA_real_)
    base$mcmc_sigmagam_warmup_iters <- as.integer((fit$diagnostics$sigmagam %||% list())$freeze_burnin_iters %||% NA_integer_)
    base$mcmc_sigmagam_first_active_iter <- as.integer((fit$diagnostics$sigmagam %||% list())$first_active_iter %||% NA_integer_)
    base$mcmc_sigmagam_updates_burn <- as.integer((fit$diagnostics$sigmagam %||% list())$updates_burn %||% NA_integer_)
    base$mcmc_sigmagam_updates_keep <- as.integer((fit$diagnostics$sigmagam %||% list())$updates_keep %||% NA_integer_)
    base$mcmc_sigmagam_frozen_burn_rate <- as.numeric((fit$diagnostics$sigmagam %||% list())$frozen_burn_rate %||% NA_real_)
    base$rhs_tau_mean <- if (length(tau_draws)) mean(tau_draws) else NA_real_
    base$rhs_c2_mean <- if (length(c2_draws)) mean(c2_draws) else NA_real_
    base$rhs_lambda_mean <- if (length(lambda_mean_draws)) mean(lambda_mean_draws) else NA_real_
    if (is.finite(base$fit_runtime_seconds) && base$fit_runtime_seconds > 0) {
      base$mcmc_ess_per_second_gamma <- base$mcmc_ess_gamma / base$fit_runtime_seconds
      base$mcmc_ess_per_second_sigma <- base$mcmc_ess_sigma / base$fit_runtime_seconds
      base$mcmc_ess_per_second_beta_norm <- base$mcmc_ess_beta_norm / base$fit_runtime_seconds
    } else {
      base$mcmc_ess_per_second_gamma <- NA_real_
      base$mcmc_ess_per_second_sigma <- NA_real_
      base$mcmc_ess_per_second_beta_norm <- NA_real_
    }
    base$finite_ok <- all(is.finite(c(base$mcmc_gamma_mean, base$mcmc_sigma_mean, base$mcmc_beta_norm_mean)))
    base$domain_ok <- all(is.finite(sigma_draws)) && all(sigma_draws > 0) &&
      all(is.finite(gamma_draws)) &&
      all(gamma_draws > fit$bounds[["L"]] & gamma_draws < fit$bounds[["U"]])
    return(base)
  }

  base$fit_class <- class(fit)[1L]
  base$fit_runtime_seconds <- NA_real_
  base$finite_ok <- FALSE
  base$domain_ok <- FALSE
  base
}

.qdesn_validation_join_reasons <- function(x) {
  x <- as.character(x)
  x <- x[!is.na(x) & nzchar(x)]
  if (!length(x)) return("")
  paste(unique(x), collapse = "; ")
}

.qdesn_validation_vb_signoff_from_rows <- function(meta_row, health_row, progress_rows, cfg) {
  out <- meta_row
  out$method <- "vb"
  out$signoff_grade <- "FAIL"
  out$comparison_eligible <- FALSE
  out$signoff_reason <- ""

  status <- as.character(health_row$status[1L] %||% NA_character_)
  finite_ok <- isTRUE(health_row$finite_ok[1L])
  domain_ok <- isTRUE(health_row$domain_ok[1L])
  converged <- isTRUE(health_row$vb_converged[1L])
  unhealthy <- isTRUE(health_row$unhealthy[1L])
  unhealthy_reason <- as.character(health_row$unhealthy_reason[1L] %||% NA_character_)

  out$vb_tail_window <- as.integer(cfg$tail_window %||% 5L)[1L]
  out$vb_trace_length <- if (nrow(progress_rows)) nrow(progress_rows) else 0L
  out$vb_converged <- converged

  elbo_tail <- .qdesn_validation_trace_tail_metrics(progress_rows$elbo %||% numeric(0), tail_window = out$vb_tail_window, unit_floor = TRUE)
  gamma_tail <- .qdesn_validation_trace_tail_metrics(progress_rows$gamma %||% numeric(0), tail_window = out$vb_tail_window)
  sigma_tail <- .qdesn_validation_trace_tail_metrics(progress_rows$sigma %||% numeric(0), tail_window = out$vb_tail_window)
  beta_tail <- .qdesn_validation_trace_tail_metrics(progress_rows$beta_norm %||% numeric(0), tail_window = out$vb_tail_window)
  tau_tail <- .qdesn_validation_trace_tail_metrics(progress_rows$rhs_tau %||% numeric(0), tail_window = out$vb_tail_window)
  c2_tail <- .qdesn_validation_trace_tail_metrics(progress_rows$rhs_c2 %||% numeric(0), tail_window = out$vb_tail_window)
  lambda_tail <- .qdesn_validation_trace_tail_metrics(progress_rows$rhs_lambda_mean %||% numeric(0), tail_window = out$vb_tail_window)

  out$vb_elbo_tail_rel_range <- elbo_tail$rel_range
  out$vb_elbo_tail_rel_drift <- elbo_tail$rel_drift
  out$vb_gamma_tail_rel_range <- gamma_tail$rel_range
  out$vb_sigma_tail_rel_range <- sigma_tail$rel_range
  out$vb_beta_norm_tail_rel_range <- beta_tail$rel_range
  out$vb_rhs_tau_tail_rel_range <- tau_tail$rel_range
  out$vb_rhs_c2_tail_rel_range <- c2_tail$rel_range
  out$vb_rhs_lambda_mean_tail_rel_range <- lambda_tail$rel_range

  core_vals <- c(gamma_tail$rel_range, sigma_tail$rel_range, beta_tail$rel_range)
  rhs_vals <- c(tau_tail$rel_range, c2_tail$rel_range, lambda_tail$rel_range)
  out$vb_core_tail_rel_range_max <- if (any(is.finite(core_vals))) max(core_vals, na.rm = TRUE) else NA_real_
  out$vb_rhs_tail_rel_range_max <- if (any(is.finite(rhs_vals))) max(rhs_vals, na.rm = TRUE) else NA_real_
  out$vb_tail_trace_ready <- is.finite(out$vb_trace_length) &&
    out$vb_trace_length >= as.integer(cfg$min_trace_length %||% 5L)[1L]

  reasons <- character(0)
  if (!identical(status, "SUCCESS")) reasons <- c(reasons, "status_not_success")
  if (!finite_ok) reasons <- c(reasons, "non_finite_fit")
  if (!domain_ok) reasons <- c(reasons, "domain_violation")
  if (unhealthy) {
    u_reason <- as.character(unhealthy_reason)[1L]
    if (is.na(u_reason) || !nzchar(u_reason)) u_reason <- "unhealthy_fit"
    reasons <- c(reasons, u_reason)
  }
  if (!isTRUE(out$vb_tail_trace_ready)) reasons <- c(reasons, "short_trace")

  if (length(reasons)) {
    out$signoff_reason <- .qdesn_validation_join_reasons(reasons)
    return(out)
  }

  core_pass <- is.finite(out$vb_core_tail_rel_range_max) &&
    out$vb_core_tail_rel_range_max <= as.numeric(cfg$core_rel_range_pass %||% 0.02)
  core_warn <- is.finite(out$vb_core_tail_rel_range_max) &&
    out$vb_core_tail_rel_range_max <= as.numeric(cfg$core_rel_range_warn %||% 0.10)
  elbo_pass <- is.finite(out$vb_elbo_tail_rel_range) &&
    out$vb_elbo_tail_rel_range <= as.numeric(cfg$elbo_rel_range_pass %||% 0.01)
  elbo_warn <- is.finite(out$vb_elbo_tail_rel_range) &&
    out$vb_elbo_tail_rel_range <= as.numeric(cfg$elbo_rel_range_warn %||% 0.05)

  rhs_present <- any(is.finite(rhs_vals))
  rhs_pass <- !rhs_present || (is.finite(out$vb_rhs_tail_rel_range_max) &&
    out$vb_rhs_tail_rel_range_max <= as.numeric(cfg$rhs_rel_range_pass %||% 0.05))
  rhs_warn <- !rhs_present || (is.finite(out$vb_rhs_tail_rel_range_max) &&
    out$vb_rhs_tail_rel_range_max <= as.numeric(cfg$rhs_rel_range_warn %||% 0.20))

  if (!converged) reasons <- c(reasons, "vb_converged_false")
  if (!elbo_warn) reasons <- c(reasons, "elbo_tail_unstable")
  if (!core_warn) reasons <- c(reasons, "core_parameter_tail_unstable")
  if (rhs_present && !rhs_warn) reasons <- c(reasons, "rhs_parameter_tail_unstable")

  if (isTRUE(converged) && core_pass && elbo_pass && rhs_pass) {
    out$signoff_grade <- "PASS"
    out$comparison_eligible <- TRUE
    out$signoff_reason <- "vb_converged; stable_tail"
    return(out)
  }

  if (core_warn && elbo_warn && rhs_warn) {
    out$signoff_grade <- "WARN"
    out$comparison_eligible <- TRUE
    if (!length(reasons)) reasons <- "stable_tail_but_not_certified"
    out$signoff_reason <- .qdesn_validation_join_reasons(reasons)
    return(out)
  }

  out$signoff_reason <- .qdesn_validation_join_reasons(reasons)
  out
}

.qdesn_validation_mcmc_chain_diagnostics <- function(progress_rows, health_row) {
  likelihood_family <- tolower(as.character(health_row$likelihood_family[1L] %||% "exal"))
  params <- if (identical(likelihood_family, "al")) c("sigma", "beta_norm") else c("gamma", "sigma", "beta_norm")
  if ("rhs_tau" %in% names(progress_rows) && any(is.finite(progress_rows$rhs_tau))) params <- c(params, "rhs_tau")
  if ("rhs_c2" %in% names(progress_rows) && any(is.finite(progress_rows$rhs_c2))) params <- c(params, "rhs_c2")
  if ("rhs_lambda_mean" %in% names(progress_rows) && any(is.finite(progress_rows$rhs_lambda_mean))) params <- c(params, "rhs_lambda_mean")

  rows <- lapply(params, function(nm) {
    x <- as.numeric(progress_rows[[nm]])
    x <- x[is.finite(x)]
    if (!length(x)) return(NULL)
    data.frame(
      parameter = nm,
      ess = .qdesn_validation_safe_ess(x),
      acf1 = .qdesn_validation_safe_acf1(x),
      geweke_absz = .qdesn_validation_safe_geweke_absz(x),
      half_drift = .qdesn_validation_halfchain_drift(x),
      stringsAsFactors = FALSE
    )
  })
  out <- .qdesn_validation_bind_rows(rows)
  if (!nrow(out) && "mcmc_n_keep" %in% names(health_row)) {
    out$n_keep <- as.integer(health_row$mcmc_n_keep[1L] %||% NA_integer_)
  }
  out
}

.qdesn_validation_mcmc_signoff_from_rows <- function(meta_row, health_row, progress_rows, cfg) {
  out <- meta_row
  out$method <- "mcmc"
  out$signoff_grade <- "FAIL"
  out$comparison_eligible <- FALSE
  out$signoff_reason <- ""

  status <- as.character(health_row$status[1L] %||% NA_character_)
  finite_ok <- isTRUE(health_row$finite_ok[1L])
  domain_ok <- isTRUE(health_row$domain_ok[1L])
  unhealthy <- isTRUE(health_row$unhealthy[1L])
  unhealthy_reason <- as.character(health_row$unhealthy_reason[1L] %||% NA_character_)
  n_keep <- as.integer(health_row$mcmc_n_keep[1L] %||% if (nrow(progress_rows)) nrow(progress_rows) else NA_integer_)
  out$mcmc_n_keep <- n_keep

  diag_rows <- .qdesn_validation_mcmc_chain_diagnostics(progress_rows, health_row)
  if (!nrow(diag_rows)) {
    out$signoff_reason <- .qdesn_validation_join_reasons(c("missing_chain_diagnostics"))
    return(out)
  }

  likelihood_family <- tolower(as.character(health_row$likelihood_family[1L] %||% "exal"))
  core_params <- if (identical(likelihood_family, "al")) c("sigma", "beta_norm") else c("gamma", "sigma", "beta_norm")
  rhs_params <- c("rhs_tau", "rhs_c2", "rhs_lambda_mean")
  core_rows <- diag_rows[diag_rows$parameter %in% core_params, , drop = FALSE]
  rhs_rows <- diag_rows[diag_rows$parameter %in% rhs_params, , drop = FALSE]

  out$mcmc_min_ess_core <- if (nrow(core_rows) && any(is.finite(core_rows$ess))) min(core_rows$ess, na.rm = TRUE) else NA_real_
  out$mcmc_max_acf1_core <- if (nrow(core_rows) && any(is.finite(core_rows$acf1))) max(core_rows$acf1, na.rm = TRUE) else NA_real_
  out$mcmc_max_geweke_absz_core <- if (nrow(core_rows) && any(is.finite(core_rows$geweke_absz))) max(core_rows$geweke_absz, na.rm = TRUE) else NA_real_
  out$mcmc_max_half_drift_core <- if (nrow(core_rows) && any(is.finite(core_rows$half_drift))) max(core_rows$half_drift, na.rm = TRUE) else NA_real_
  out$mcmc_min_ess_rhs <- if (nrow(rhs_rows) && any(is.finite(rhs_rows$ess))) min(rhs_rows$ess, na.rm = TRUE) else NA_real_
  out$mcmc_max_acf1_rhs <- if (nrow(rhs_rows) && any(is.finite(rhs_rows$acf1))) max(rhs_rows$acf1, na.rm = TRUE) else NA_real_
  out$mcmc_max_geweke_absz_rhs <- if (nrow(rhs_rows) && any(is.finite(rhs_rows$geweke_absz))) max(rhs_rows$geweke_absz, na.rm = TRUE) else NA_real_
  out$mcmc_max_half_drift_rhs <- if (nrow(rhs_rows) && any(is.finite(rhs_rows$half_drift))) max(rhs_rows$half_drift, na.rm = TRUE) else NA_real_

  reasons <- character(0)
  if (!identical(status, "SUCCESS")) reasons <- c(reasons, "status_not_success")
  if (!finite_ok) reasons <- c(reasons, "non_finite_fit")
  if (!domain_ok) reasons <- c(reasons, "domain_violation")
  if (unhealthy) {
    u_reason <- as.character(unhealthy_reason)[1L]
    if (is.na(u_reason) || !nzchar(u_reason)) u_reason <- "unhealthy_fit"
    reasons <- c(reasons, u_reason)
  }
  if (!is.finite(n_keep) || n_keep < as.integer(cfg$min_keep_warn %||% 100L)) reasons <- c(reasons, "short_chain")

  fail_ess <- c(out$mcmc_min_ess_core, out$mcmc_min_ess_rhs)
  fail_acf <- c(out$mcmc_max_acf1_core, out$mcmc_max_acf1_rhs)
  fail_geweke <- c(out$mcmc_max_geweke_absz_core, out$mcmc_max_geweke_absz_rhs)
  fail_drift <- c(out$mcmc_max_half_drift_core, out$mcmc_max_half_drift_rhs)

  if (any(is.finite(fail_ess) & fail_ess < as.numeric(cfg$ess_warn %||% 10), na.rm = TRUE)) {
    reasons <- c(reasons, "low_ess")
  }
  if (any(is.finite(fail_acf) & fail_acf > as.numeric(cfg$acf1_warn %||% 0.98), na.rm = TRUE)) {
    reasons <- c(reasons, "high_autocorrelation")
  }
  if (any(is.finite(fail_geweke) & fail_geweke > as.numeric(cfg$geweke_absz_warn %||% 3), na.rm = TRUE)) {
    reasons <- c(reasons, "geweke_drift")
  }
  if (any(is.finite(fail_drift) & fail_drift > as.numeric(cfg$half_drift_warn %||% 0.5), na.rm = TRUE)) {
    reasons <- c(reasons, "half_chain_drift")
  }

  pass_keep <- is.finite(n_keep) && n_keep >= as.integer(cfg$min_keep_pass %||% 160L)
  pass_ess <- all(c(
    !is.finite(out$mcmc_min_ess_core) || out$mcmc_min_ess_core >= as.numeric(cfg$ess_pass %||% 30),
    !is.finite(out$mcmc_min_ess_rhs) || out$mcmc_min_ess_rhs >= as.numeric(cfg$ess_pass %||% 30)
  ))
  pass_acf <- all(c(
    !is.finite(out$mcmc_max_acf1_core) || out$mcmc_max_acf1_core <= as.numeric(cfg$acf1_pass %||% 0.90),
    !is.finite(out$mcmc_max_acf1_rhs) || out$mcmc_max_acf1_rhs <= as.numeric(cfg$acf1_pass %||% 0.90)
  ))
  pass_geweke <- all(c(
    !is.finite(out$mcmc_max_geweke_absz_core) || out$mcmc_max_geweke_absz_core <= as.numeric(cfg$geweke_absz_pass %||% 2),
    !is.finite(out$mcmc_max_geweke_absz_rhs) || out$mcmc_max_geweke_absz_rhs <= as.numeric(cfg$geweke_absz_pass %||% 2)
  ))
  pass_drift <- all(c(
    !is.finite(out$mcmc_max_half_drift_core) || out$mcmc_max_half_drift_core <= as.numeric(cfg$half_drift_pass %||% 0.25),
    !is.finite(out$mcmc_max_half_drift_rhs) || out$mcmc_max_half_drift_rhs <= as.numeric(cfg$half_drift_pass %||% 0.25)
  ))

  warn_ess <- all(c(
    !is.finite(out$mcmc_min_ess_core) || out$mcmc_min_ess_core >= as.numeric(cfg$ess_warn %||% 10),
    !is.finite(out$mcmc_min_ess_rhs) || out$mcmc_min_ess_rhs >= as.numeric(cfg$ess_warn %||% 10)
  ))
  warn_acf <- all(c(
    !is.finite(out$mcmc_max_acf1_core) || out$mcmc_max_acf1_core <= as.numeric(cfg$acf1_warn %||% 0.98),
    !is.finite(out$mcmc_max_acf1_rhs) || out$mcmc_max_acf1_rhs <= as.numeric(cfg$acf1_warn %||% 0.98)
  ))
  warn_geweke <- all(c(
    !is.finite(out$mcmc_max_geweke_absz_core) || out$mcmc_max_geweke_absz_core <= as.numeric(cfg$geweke_absz_warn %||% 3),
    !is.finite(out$mcmc_max_geweke_absz_rhs) || out$mcmc_max_geweke_absz_rhs <= as.numeric(cfg$geweke_absz_warn %||% 3)
  ))
  warn_drift <- all(c(
    !is.finite(out$mcmc_max_half_drift_core) || out$mcmc_max_half_drift_core <= as.numeric(cfg$half_drift_warn %||% 0.5),
    !is.finite(out$mcmc_max_half_drift_rhs) || out$mcmc_max_half_drift_rhs <= as.numeric(cfg$half_drift_warn %||% 0.5)
  ))

  if (!length(reasons) && pass_keep && pass_ess && pass_acf && pass_geweke && pass_drift) {
    out$signoff_grade <- "PASS"
    out$comparison_eligible <- TRUE
    out$signoff_reason <- "adequate_chain_length; acceptable_ess_acf_geweke_drift"
    return(out)
  }

  if (identical(status, "SUCCESS") && finite_ok && domain_ok && warn_ess && warn_acf && warn_geweke && warn_drift) {
    out$signoff_grade <- "WARN"
    out$comparison_eligible <- TRUE
    if (!length(reasons)) reasons <- "chain_marginal_but_usable"
    out$signoff_reason <- .qdesn_validation_join_reasons(reasons)
    return(out)
  }

  out$signoff_reason <- .qdesn_validation_join_reasons(reasons)
  out
}

.qdesn_validation_method_fit_summary <- function(method, root_spec, cfg, summary_obj, error_message = NA_character_) {
  health <- .qdesn_validation_method_health(method, root_spec, summary_obj)
  list(
    root_id = root_spec$root_id,
    scenario = root_spec$scenario,
    tau = as.numeric(root_spec$tau),
    likelihood_family = as.character(root_spec$likelihood_family %||% "exal")[1L],
    beta_prior_type = root_spec$beta_prior_type,
    seed = as.integer(root_spec$seed),
    reservoir_profile = root_spec$reservoir_profile,
    method = method,
    status = as.character(health$status[1L]),
    error_message = if (is.na(error_message)) NULL else as.character(error_message),
    config = cfg,
    summary = as.list(health[1L, , drop = FALSE]),
    pipeline_summary = as.list(summary_obj$summary[1L, , drop = FALSE])
  )
}

.qdesn_validation_method_progress_trace <- function(method, summary_obj) {
  fit <- .qdesn_validation_extract_fit(summary_obj)
  if (is.null(fit)) return(data.frame(stringsAsFactors = FALSE))

  if (.qdesn_validation_is_vb_fit(fit)) {
    n_iter <- length(fit$misc$gamma_trace %||% numeric(0))
    if (n_iter <= 0L) return(data.frame(stringsAsFactors = FALSE))
    out <- data.frame(
      method = method,
      step = seq_len(n_iter),
      gamma = as.numeric(fit$misc$gamma_trace %||% rep(NA_real_, n_iter)),
      sigma = as.numeric(fit$misc$sigma_trace %||% rep(NA_real_, n_iter)),
      elbo = as.numeric(fit$misc$elbo_trace %||% rep(NA_real_, n_iter)),
      beta_norm = sqrt(sum((as.numeric(fit$qbeta$m %||% numeric(0)))^2)),
      stringsAsFactors = FALSE
    )
    rhs_tau <- as.numeric(fit$misc$rhs_tau_trace %||% numeric(0))
    rhs_c2 <- as.numeric(fit$misc$rhs_c2_trace %||% numeric(0))
    rhs_lambda_mean <- as.numeric(fit$misc$rhs_lambda_mean_trace %||% numeric(0))
    sigmagam_frozen <- as.logical(fit$misc$sigmagam_frozen_trace %||% logical(0))
    sigmagam_update_reason <- as.character(fit$misc$sigmagam_update_reason_trace %||% character(0))
    sigmagam_forced <- as.logical(fit$misc$sigmagam_forced_postwarmup_trace %||% logical(0))
    sigmagam_update_count <- as.integer(
      fit$misc$sigmagam_update_count_trace %||%
        cumsum(as.integer(fit$misc$sigmagam_update_performed_trace %||% logical(0)))
    )
    if (length(rhs_tau) == n_iter) out$rhs_tau <- rhs_tau
    if (length(rhs_c2) == n_iter) out$rhs_c2 <- rhs_c2
    if (length(rhs_lambda_mean) == n_iter) out$rhs_lambda_mean <- rhs_lambda_mean
    if (length(sigmagam_frozen) == n_iter) out$sigmagam_frozen <- sigmagam_frozen
    if (length(sigmagam_update_reason) == n_iter) out$sigmagam_update_reason <- sigmagam_update_reason
    if (length(sigmagam_update_count) == n_iter) out$sigmagam_update_count <- sigmagam_update_count
    if (length(sigmagam_forced) == n_iter) out$sigmagam_forced_postwarmup <- sigmagam_forced
    return(out)
  }

  if (.qdesn_validation_is_mcmc_fit(fit)) {
    beta_draws <- as.matrix(fit$samp.beta)
    out <- data.frame(
      method = method,
      step = seq_len(nrow(beta_draws)),
      gamma = as.numeric(fit$samp.gamma),
      sigma = as.numeric(fit$samp.sigma),
      elbo = NA_real_,
      beta_norm = sqrt(rowSums(beta_draws * beta_draws)),
      stringsAsFactors = FALSE
    )
    rhs_tau <- if (!is.null(fit$samp.tau)) as.numeric(fit$samp.tau) else numeric(0)
    rhs_c2 <- if (!is.null(fit$samp.c2)) as.numeric(fit$samp.c2) else numeric(0)
    rhs_lambda_mean <- if (!is.null(fit$samp.lambda_mean)) as.numeric(fit$samp.lambda_mean) else numeric(0)
    if (length(rhs_tau) == nrow(out)) out$rhs_tau <- rhs_tau
    if (length(rhs_c2) == nrow(out)) out$rhs_c2 <- rhs_c2
    if (length(rhs_lambda_mean) == nrow(out)) out$rhs_lambda_mean <- rhs_lambda_mean
    return(out)
  }

  data.frame(stringsAsFactors = FALSE)
}

.qdesn_validation_method_latent_v_trace <- function(method, summary_obj) {
  fit <- .qdesn_validation_extract_fit(summary_obj)
  if (is.null(fit) || !.qdesn_validation_is_mcmc_fit(fit)) return(data.frame(stringsAsFactors = FALSE))

  gamma_trace <- as.numeric(fit$misc$gamma_trace %||% numeric(0))
  sigma_trace <- as.numeric(fit$misc$sigma_trace %||% numeric(0))
  n_iter <- length(gamma_trace)
  if (n_iter <= 0L || length(sigma_trace) != n_iter) return(data.frame(stringsAsFactors = FALSE))

  n_burn <- as.integer(fit$control$n_burn %||% NA_integer_)
  out <- data.frame(
    method = method,
    step = seq_len(n_iter),
    phase = if (!is.na(n_burn)) ifelse(seq_len(n_iter) <= n_burn, "burn", "keep") else NA_character_,
    gamma = gamma_trace,
    sigma = sigma_trace,
    stringsAsFactors = FALSE
  )

  warmup_active <- as.logical(fit$misc$latent_v_warmup_active_trace %||% logical(0))
  hard_freeze <- as.logical(fit$misc$latent_v_hard_freeze_trace %||% logical(0))
  sparse_window <- as.logical(fit$misc$latent_v_sparse_window_trace %||% logical(0))
  force_update <- as.logical(fit$misc$latent_v_force_update_trace %||% logical(0))
  update_performed <- as.logical(fit$misc$latent_v_update_performed_trace %||% logical(0))
  reason <- as.character(fit$misc$latent_v_update_reason_trace %||% character(0))
  update_count <- as.integer(fit$misc$latent_v_update_count_trace %||% integer(0))
  rescue_applied <- as.logical(fit$misc$latent_v_rescue_applied_trace %||% logical(0))
  rescue_strategy <- as.character(fit$misc$latent_v_rescue_strategy_trace %||% character(0))
  rescue_count <- as.integer(fit$misc$latent_v_rescue_count_trace %||% integer(0))
  rescue_consecutive <- as.integer(fit$misc$latent_v_rescue_consecutive_trace %||% integer(0))
  latent_s_warmup_active <- as.logical(fit$misc$latent_s_warmup_active_trace %||% logical(0))
  latent_s_hard_freeze <- as.logical(fit$misc$latent_s_hard_freeze_trace %||% logical(0))
  latent_s_sparse_window <- as.logical(fit$misc$latent_s_sparse_window_trace %||% logical(0))
  latent_s_force_update <- as.logical(fit$misc$latent_s_force_update_trace %||% logical(0))
  latent_s_update_performed <- as.logical(fit$misc$latent_s_update_performed_trace %||% logical(0))
  latent_s_reason <- as.character(fit$misc$latent_s_update_reason_trace %||% character(0))
  latent_s_update_count <- as.integer(fit$misc$latent_s_update_count_trace %||% integer(0))
  theta_warmup_active <- as.logical(fit$misc$theta_warmup_active_trace %||% logical(0))
  theta_hard_freeze <- as.logical(fit$misc$theta_hard_freeze_trace %||% logical(0))
  theta_sparse_window <- as.logical(fit$misc$theta_sparse_window_trace %||% logical(0))
  theta_force_update <- as.logical(fit$misc$theta_force_update_trace %||% logical(0))
  theta_update_performed <- as.logical(fit$misc$theta_update_performed_trace %||% logical(0))
  theta_reason <- as.character(fit$misc$theta_update_reason_trace %||% character(0))
  theta_update_count <- as.integer(fit$misc$theta_update_count_trace %||% integer(0))

  if (length(warmup_active) == n_iter) out$latent_v_warmup_active <- warmup_active
  if (length(hard_freeze) == n_iter) out$latent_v_hard_freeze <- hard_freeze
  if (length(sparse_window) == n_iter) out$latent_v_sparse_window <- sparse_window
  if (length(force_update) == n_iter) out$latent_v_force_update <- force_update
  if (length(update_performed) == n_iter) out$latent_v_update_performed <- update_performed
  if (length(reason) == n_iter) out$latent_v_update_reason <- reason
  if (length(update_count) == n_iter) out$latent_v_update_count <- update_count
  if (length(rescue_applied) == n_iter) out$latent_v_rescue_applied <- rescue_applied
  if (length(rescue_strategy) == n_iter) out$latent_v_rescue_strategy <- rescue_strategy
  if (length(rescue_count) == n_iter) out$latent_v_rescue_count <- rescue_count
  if (length(rescue_consecutive) == n_iter) out$latent_v_rescue_consecutive <- rescue_consecutive
  if (length(latent_s_warmup_active) == n_iter) out$latent_s_warmup_active <- latent_s_warmup_active
  if (length(latent_s_hard_freeze) == n_iter) out$latent_s_hard_freeze <- latent_s_hard_freeze
  if (length(latent_s_sparse_window) == n_iter) out$latent_s_sparse_window <- latent_s_sparse_window
  if (length(latent_s_force_update) == n_iter) out$latent_s_force_update <- latent_s_force_update
  if (length(latent_s_update_performed) == n_iter) out$latent_s_update_performed <- latent_s_update_performed
  if (length(latent_s_reason) == n_iter) out$latent_s_update_reason <- latent_s_reason
  if (length(latent_s_update_count) == n_iter) out$latent_s_update_count <- latent_s_update_count
  if (length(theta_warmup_active) == n_iter) out$theta_warmup_active <- theta_warmup_active
  if (length(theta_hard_freeze) == n_iter) out$theta_hard_freeze <- theta_hard_freeze
  if (length(theta_sparse_window) == n_iter) out$theta_sparse_window <- theta_sparse_window
  if (length(theta_force_update) == n_iter) out$theta_force_update <- theta_force_update
  if (length(theta_update_performed) == n_iter) out$theta_update_performed <- theta_update_performed
  if (length(theta_reason) == n_iter) out$theta_update_reason <- theta_reason
  if (length(theta_update_count) == n_iter) out$theta_update_count <- theta_update_count
  out
}

.qdesn_validation_method_theta_trace <- function(method, summary_obj) {
  fit <- .qdesn_validation_extract_fit(summary_obj)
  if (is.null(fit) || !.qdesn_validation_is_mcmc_fit(fit)) return(data.frame(stringsAsFactors = FALSE))

  gamma_trace <- as.numeric(fit$misc$gamma_trace %||% numeric(0))
  sigma_trace <- as.numeric(fit$misc$sigma_trace %||% numeric(0))
  n_iter <- length(gamma_trace)
  if (n_iter <= 0L || length(sigma_trace) != n_iter) return(data.frame(stringsAsFactors = FALSE))

  n_burn <- as.integer(fit$control$n_burn %||% NA_integer_)
  out <- data.frame(
    method = method,
    step = seq_len(n_iter),
    phase = if (!is.na(n_burn)) ifelse(seq_len(n_iter) <= n_burn, "burn", "keep") else NA_character_,
    gamma = gamma_trace,
    sigma = sigma_trace,
    stringsAsFactors = FALSE
  )

  warmup_active <- as.logical(fit$misc$theta_warmup_active_trace %||% logical(0))
  hard_freeze <- as.logical(fit$misc$theta_hard_freeze_trace %||% logical(0))
  sparse_window <- as.logical(fit$misc$theta_sparse_window_trace %||% logical(0))
  force_update <- as.logical(fit$misc$theta_force_update_trace %||% logical(0))
  update_performed <- as.logical(fit$misc$theta_update_performed_trace %||% logical(0))
  reason <- as.character(fit$misc$theta_update_reason_trace %||% character(0))
  update_count <- as.integer(fit$misc$theta_update_count_trace %||% integer(0))
  if (!any(c(
    length(warmup_active) == n_iter,
    length(hard_freeze) == n_iter,
    length(sparse_window) == n_iter,
    length(force_update) == n_iter,
    length(update_performed) == n_iter,
    length(reason) == n_iter,
    length(update_count) == n_iter
  ))) {
    return(data.frame(stringsAsFactors = FALSE))
  }

  if (length(warmup_active) == n_iter) out$theta_warmup_active <- warmup_active
  if (length(hard_freeze) == n_iter) out$theta_hard_freeze <- hard_freeze
  if (length(sparse_window) == n_iter) out$theta_sparse_window <- sparse_window
  if (length(force_update) == n_iter) out$theta_force_update <- force_update
  if (length(update_performed) == n_iter) out$theta_update_performed <- update_performed
  if (length(reason) == n_iter) out$theta_update_reason <- reason
  if (length(update_count) == n_iter) out$theta_update_count <- update_count
  out
}

.qdesn_validation_method_sigmagam_trace <- function(method, summary_obj) {
  fit <- .qdesn_validation_extract_fit(summary_obj)
  if (is.null(fit)) return(data.frame(stringsAsFactors = FALSE))

  if (.qdesn_validation_is_vb_fit(fit)) {
    n_iter <- length(fit$misc$gamma_trace %||% numeric(0))
    if (n_iter <= 0L) return(data.frame(stringsAsFactors = FALSE))
    out <- data.frame(
      method = method,
      step = seq_len(n_iter),
      phase = rep("vb", n_iter),
      gamma = as.numeric(fit$misc$gamma_trace %||% rep(NA_real_, n_iter)),
      sigma = as.numeric(fit$misc$sigma_trace %||% rep(NA_real_, n_iter)),
      elbo = as.numeric(fit$misc$elbo_trace %||% rep(NA_real_, n_iter)),
      stringsAsFactors = FALSE
    )
    frozen <- as.logical(fit$misc$sigmagam_frozen_trace %||% logical(0))
    reason <- as.character(fit$misc$sigmagam_update_reason_trace %||% character(0))
    forced <- as.logical(fit$misc$sigmagam_forced_postwarmup_trace %||% logical(0))
    if (length(frozen) == n_iter) out$sigmagam_frozen <- frozen
    if (length(reason) == n_iter) out$sigmagam_update_reason <- reason
    if (length(forced) == n_iter) out$sigmagam_forced_postwarmup <- forced
    return(out)
  }

  if (.qdesn_validation_is_mcmc_fit(fit)) {
    gamma_trace <- as.numeric(fit$misc$gamma_trace %||% numeric(0))
    sigma_trace <- as.numeric(fit$misc$sigma_trace %||% numeric(0))
    n_iter <- length(gamma_trace)
    if (n_iter <= 0L || length(sigma_trace) != n_iter) return(data.frame(stringsAsFactors = FALSE))
    n_burn <- as.integer(fit$control$n_burn %||% NA_integer_)
    out <- data.frame(
      method = method,
      step = seq_len(n_iter),
      phase = if (!is.na(n_burn)) ifelse(seq_len(n_iter) <= n_burn, "burn", "keep") else NA_character_,
      gamma = gamma_trace,
      sigma = sigma_trace,
      stringsAsFactors = FALSE
    )
    frozen <- as.logical(fit$misc$sigmagam_frozen_trace %||% logical(0))
    reason <- as.character(fit$misc$sigmagam_update_reason_trace %||% character(0))
    forced <- as.logical(fit$misc$sigmagam_forced_postwarmup_trace %||% logical(0))
    update_count <- as.integer(fit$misc$sigmagam_update_count_trace %||% integer(0))
    gamma_steps <- as.numeric(fit$misc$gamma_slice_steps_out %||% numeric(0))
    gamma_shrink <- as.numeric(fit$misc$gamma_slice_shrink %||% numeric(0))
    if (length(frozen) == n_iter) out$sigmagam_frozen <- frozen
    if (length(reason) == n_iter) out$sigmagam_update_reason <- reason
    if (length(forced) == n_iter) out$sigmagam_forced_postwarmup <- forced
    if (length(update_count) == n_iter) out$sigmagam_update_count <- update_count
    if (length(gamma_steps) == n_iter) out$gamma_slice_steps_out <- gamma_steps
    if (length(gamma_shrink) == n_iter) out$gamma_slice_shrink <- gamma_shrink
    return(out)
  }

  data.frame(stringsAsFactors = FALSE)
}

.qdesn_validation_mcmc_chain_summary <- function(summary_obj) {
  fit <- .qdesn_validation_extract_fit(summary_obj)
  if (is.null(fit) || !.qdesn_validation_is_mcmc_fit(fit)) return(data.frame(stringsAsFactors = FALSE))

  draws <- list(
    gamma = as.numeric(fit$samp.gamma),
    sigma = as.numeric(fit$samp.sigma),
    beta_norm = sqrt(rowSums(as.matrix(fit$samp.beta)^2))
  )
  if (!is.null(fit$samp.tau)) draws$tau <- as.numeric(fit$samp.tau)
  if (!is.null(fit$samp.c2)) draws$c2 <- as.numeric(fit$samp.c2)
  if (!is.null(fit$samp.lambda_mean)) draws$lambda_mean <- as.numeric(fit$samp.lambda_mean)

  rows <- lapply(names(draws), function(nm) {
    x <- as.numeric(draws[[nm]])
    data.frame(
      parameter = nm,
      mean = mean(x),
      sd = stats::sd(x),
      min = min(x),
      max = max(x),
      ess = .qdesn_validation_safe_ess(x),
      acf1 = .qdesn_validation_safe_acf1(x),
      geweke_absz = .qdesn_validation_safe_geweke_absz(x),
      half_drift = .qdesn_validation_halfchain_drift(x),
      stringsAsFactors = FALSE
    )
  })
  .qdesn_validation_bind_rows(rows)
}

.qdesn_validation_write_toy_data <- function(root_dir, toy_obj) {
  data_dir <- file.path(root_dir, "data")
  .qdesn_validation_dir_create(data_dir)
  .qdesn_validation_write_df(toy_obj$long, file.path(data_dir, "series_long.csv"))
  .qdesn_validation_write_df(toy_obj$wide, file.path(data_dir, "series_wide.csv"))
  .qdesn_validation_write_df(toy_obj$split, file.path(data_dir, "split_summary.csv"))
}

.qdesn_validation_plot_series_overview <- function(root_dir, root_spec, toy_obj) {
  .qdesn_validation_require_namespace("ggplot2")
  .qdesn_validation_require_namespace("dplyr")

  tau <- as.numeric(root_spec$tau)
  q_tau <- subset(toy_obj$long, abs(p - tau) < 1e-12, select = c("t", "q"))
  df <- data.frame(t = toy_obj$wide$t, y = toy_obj$wide$y, mu = toy_obj$wide$mu, stringsAsFactors = FALSE)
  df$q_true <- q_tau$q
  split_n <- as.integer(toy_obj$split$n_train[1L])

  p <- ggplot2::ggplot(df, ggplot2::aes(x = t)) +
    ggplot2::geom_line(ggplot2::aes(y = y, colour = "y"), linewidth = 0.6) +
    ggplot2::geom_line(ggplot2::aes(y = mu, colour = "mu"), linewidth = 0.8) +
    ggplot2::geom_line(ggplot2::aes(y = q_true, colour = "q_true"), linewidth = 0.8, linetype = 2) +
    ggplot2::geom_vline(xintercept = split_n, linetype = 3, linewidth = 0.6) +
    ggplot2::scale_colour_manual(values = c(y = "#1f2937", mu = "#0f766e", q_true = "#b45309")) +
    ggplot2::labs(
      title = sprintf("Toy Validation Series: %s", root_spec$root_id),
      subtitle = sprintf("Scenario=%s | tau=%0.2f | train/test split at t=%d", root_spec$scenario, tau, split_n),
      x = "t",
      y = "value",
      colour = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "top")

  ggplot2::ggsave(file.path(root_dir, "plots", "series_overview.png"), p, width = 9, height = 4.5, dpi = 150)
}

.qdesn_validation_plot_forecast_compare <- function(root_dir, method_rows, forecast_rows) {
  .qdesn_validation_require_namespace("ggplot2")
  if (!nrow(forecast_rows)) return(invisible(NULL))

  p <- ggplot2::ggplot(forecast_rows, ggplot2::aes(x = h)) +
    ggplot2::geom_line(ggplot2::aes(y = q_true, colour = "true q"), linewidth = 0.8, linetype = 2) +
    ggplot2::geom_point(ggplot2::aes(y = y, colour = "y"), size = 1.2, alpha = 0.7) +
    ggplot2::geom_line(ggplot2::aes(y = q_pred, colour = method), linewidth = 0.9) +
    ggplot2::scale_colour_manual(values = c("true q" = "#111827", "y" = "#6b7280", "vb" = "#2563eb", "mcmc" = "#dc2626")) +
    ggplot2::labs(
      title = "Forecast Quantile Comparison",
      subtitle = sprintf("Methods: %s", paste(sort(unique(method_rows$method)), collapse = ", ")),
      x = "forecast horizon h",
      y = "quantile / observation",
      colour = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "top")

  ggplot2::ggsave(file.path(root_dir, "plots", "forecast_compare.png"), p, width = 9, height = 4.5, dpi = 150)
  invisible(NULL)
}

.qdesn_validation_plot_runtime_compare <- function(root_dir, method_rows) {
  .qdesn_validation_require_namespace("ggplot2")
  if (!nrow(method_rows)) return(invisible(NULL))
  df <- rbind(
    data.frame(method = method_rows$method, metric = "wall_seconds", value = method_rows$wall_seconds, stringsAsFactors = FALSE),
    data.frame(method = method_rows$method, metric = "timed_stage_seconds", value = method_rows$total_stage_seconds, stringsAsFactors = FALSE)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = method, y = value, fill = method)) +
    ggplot2::geom_col(width = 0.65) +
    ggplot2::facet_wrap(~ metric, scales = "free_y") +
    ggplot2::scale_fill_manual(values = c(vb = "#2563eb", mcmc = "#dc2626")) +
    ggplot2::labs(title = "Runtime Comparison", x = NULL, y = "seconds", fill = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "none")
  ggplot2::ggsave(file.path(root_dir, "plots", "runtime_compare.png"), p, width = 8, height = 4.2, dpi = 150)
  invisible(NULL)
}

.qdesn_validation_plot_score_compare <- function(root_dir, method_rows) {
  .qdesn_validation_require_namespace("ggplot2")
  if (!nrow(method_rows)) return(invisible(NULL))
  df <- .qdesn_validation_bind_rows(list(
    data.frame(method = method_rows$method, metric = "forecast_CRPS_mean", value = method_rows$forecast_CRPS_mean, stringsAsFactors = FALSE),
    data.frame(method = method_rows$method, metric = "forecast_PinballMean_mean", value = method_rows$forecast_PinballMean_mean, stringsAsFactors = FALSE),
    data.frame(method = method_rows$method, metric = "forecast_S_mean", value = method_rows$forecast_S_mean, stringsAsFactors = FALSE),
    data.frame(method = method_rows$method, metric = "forecast_qhat_mae", value = method_rows$forecast_qhat_mae, stringsAsFactors = FALSE),
    data.frame(method = method_rows$method, metric = "forecast_pinball_tau", value = method_rows$forecast_pinball_tau, stringsAsFactors = FALSE)
  ))
  df <- df[is.finite(df$value), , drop = FALSE]
  if (!nrow(df)) return(invisible(NULL))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = method, y = value, fill = method)) +
    ggplot2::geom_col(width = 0.65) +
    ggplot2::facet_wrap(~ metric, scales = "free_y") +
    ggplot2::scale_fill_manual(values = c(vb = "#2563eb", mcmc = "#dc2626")) +
    ggplot2::labs(title = "Forecast Score Comparison", x = NULL, y = "value", fill = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "none")
  ggplot2::ggsave(file.path(root_dir, "plots", "score_compare.png"), p, width = 8, height = 4.2, dpi = 150)
  invisible(NULL)
}

.qdesn_validation_plot_algorithm_progress <- function(root_dir, progress_rows) {
  .qdesn_validation_require_namespace("ggplot2")
  if (!nrow(progress_rows)) return(invisible(NULL))

  rows <- list(
    data.frame(method = progress_rows$method, step = progress_rows$step, metric = "gamma", value = progress_rows$gamma, stringsAsFactors = FALSE),
    data.frame(method = progress_rows$method, step = progress_rows$step, metric = "sigma", value = progress_rows$sigma, stringsAsFactors = FALSE),
    data.frame(method = progress_rows$method, step = progress_rows$step, metric = "beta_norm", value = progress_rows$beta_norm, stringsAsFactors = FALSE)
  )
  if ("elbo" %in% names(progress_rows) && any(is.finite(progress_rows$elbo))) {
    rows[[length(rows) + 1L]] <- data.frame(method = progress_rows$method, step = progress_rows$step, metric = "elbo", value = progress_rows$elbo, stringsAsFactors = FALSE)
  }
  df <- .qdesn_validation_bind_rows(rows)
  df <- df[is.finite(df$value), , drop = FALSE]
  if (!nrow(df)) return(invisible(NULL))

  p <- ggplot2::ggplot(df, ggplot2::aes(x = step, y = value, colour = method)) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::facet_wrap(~ metric, scales = "free_y", ncol = 2) +
    ggplot2::scale_colour_manual(values = c(vb = "#2563eb", mcmc = "#dc2626")) +
    ggplot2::labs(title = "Algorithm Progress", x = "step", y = NULL, colour = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "top")
  ggplot2::ggsave(file.path(root_dir, "plots", "algorithm_progress.png"), p, width = 8.5, height = 6.5, dpi = 150)
  invisible(NULL)
}

.qdesn_validation_plot_rhs_progress <- function(root_dir, progress_rows) {
  .qdesn_validation_require_namespace("ggplot2")
  needed <- c("rhs_tau", "rhs_c2", "rhs_lambda_mean")
  keep <- needed[needed %in% names(progress_rows)]
  if (!length(keep)) return(invisible(NULL))
  rows <- lapply(keep, function(nm) {
    data.frame(method = progress_rows$method, step = progress_rows$step, metric = nm, value = progress_rows[[nm]], stringsAsFactors = FALSE)
  })
  df <- .qdesn_validation_bind_rows(rows)
  df <- df[is.finite(df$value), , drop = FALSE]
  if (!nrow(df)) return(invisible(NULL))

  p <- ggplot2::ggplot(df, ggplot2::aes(x = step, y = value, colour = method)) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::facet_wrap(~ metric, scales = "free_y", ncol = 1) +
    ggplot2::scale_colour_manual(values = c(vb = "#2563eb", mcmc = "#dc2626")) +
    ggplot2::labs(title = "RHS Shrinkage Progress", x = "step", y = NULL, colour = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "top")
  ggplot2::ggsave(file.path(root_dir, "plots", "rhs_progress.png"), p, width = 7.5, height = 7, dpi = 150)
  invisible(NULL)
}

.qdesn_validation_update_method_status <- function(root_dir, method_status_rows) {
  .qdesn_validation_write_df(method_status_rows, file.path(root_dir, "manifest", "method_status.csv"))
}

.qdesn_validation_write_method_runtime <- function(method_dir, method, root_spec, run_res, status) {
  manifest_dir <- file.path(method_dir, "manifest")
  .qdesn_validation_dir_create(manifest_dir)
  .qdesn_validation_write_lines(file.path(manifest_dir, "status.txt"), status)
  .qdesn_validation_write_json(file.path(manifest_dir, "runtime_summary.json"), list(
    started_at = NA_character_,
    finished_at = as.character(Sys.time()),
    elapsed_seconds = as.numeric(run_res$elapsed_seconds %||% NA_real_),
    elapsed_minutes = as.numeric(run_res$elapsed_seconds %||% NA_real_) / 60,
    status = status,
    dataset_slug = root_spec$scenario,
    spec = paste(root_spec$root_id, method, sep = "::"),
    mode = "sim",
    inference_method = method,
    likelihood_family = as.character(root_spec$likelihood_family %||% "exal")[1L],
    beta_prior_type = root_spec$beta_prior_type
  ))
}

.qdesn_validation_run_one_method <- function(method, root_spec, defaults, file_long, method_dir, verbose = TRUE) {
  cfg <- qdesn_validation_build_pipeline_cfg(root_spec, defaults = defaults, method = method)
  start_time <- Sys.time()
  status <- "SUCCESS"
  error_message <- NA_character_
  error_payload <- list()

  .qdesn_validation_dir_create(file.path(method_dir, "logs"))
  .qdesn_validation_write_json(file.path(method_dir, "fit_request.json"), list(root_spec = root_spec, method = method, config = cfg))

  run_res <- tryCatch(
    run_esn_pipeline_from_cfg(
      cfg = cfg,
      file_long = file_long,
      out_dir = method_dir,
      save_outputs = TRUE,
      verbose = FALSE
    ),
    error = function(e) {
      status <<- "FAIL"
      error_message <<- conditionMessage(e)
      error_payload <<- .qdesn_validation_extract_error_payload(e)
      NULL
    }
  )
  if (!is.null(run_res) && !identical(as.integer(run_res$status), 0L)) {
    status <- "FAIL"
    if (is.na(error_message)) {
      error_message <- sprintf("pipeline exited with status %s", as.integer(run_res$status))
    }
  }
  if (!is.null(run_res)) {
    .qdesn_validation_write_method_runtime(method_dir, method, root_spec, run_res, if (identical(status, "SUCCESS")) "SUCCESS" else "FAIL")
  }

  log_lines <- if (!is.null(run_res)) run_res$stdout else error_message
  if (length(log_lines)) {
    .qdesn_validation_write_lines(file.path(method_dir, "logs", "pipeline_stdout.log"), log_lines)
  }
  if (!length(error_payload)) {
    error_payload <- .qdesn_validation_extract_error_payload(log_lines = log_lines)
  }

  summary_obj <- NULL
  if (identical(status, "SUCCESS")) {
    summary_obj <- tryCatch(
      collect_pipeline_run_summary(method_dir),
      error = function(e) {
        status <<- "FAIL"
        error_message <<- conditionMessage(e)
        error_payload <<- .qdesn_validation_extract_error_payload(e)
        NULL
      }
    )
  }

  if (!is.null(summary_obj) && !identical(as.character(summary_obj$status), "SUCCESS")) {
    status <- as.character(summary_obj$status)
  }

  health_row <- if (!is.null(summary_obj)) {
    .qdesn_validation_method_health(method, root_spec, summary_obj)
  } else {
    .qdesn_validation_failure_health_row(
      method = method,
      root_spec = root_spec,
      status = status,
      error_payload = error_payload
    )
  }
  if (!("status" %in% names(health_row)) || is.na(health_row$status[[1L]]) || !nzchar(as.character(health_row$status[[1L]]))) {
    health_row$status <- status
  }

  fit_summary <- if (!is.null(summary_obj)) {
    .qdesn_validation_method_fit_summary(method, root_spec, cfg, summary_obj, error_message = error_message)
  } else {
    list(
      root_id = root_spec$root_id,
      scenario = root_spec$scenario,
      tau = as.numeric(root_spec$tau),
      likelihood_family = as.character(root_spec$likelihood_family %||% "exal")[1L],
      beta_prior_type = root_spec$beta_prior_type,
      seed = as.integer(root_spec$seed),
      reservoir_profile = root_spec$reservoir_profile,
      method = method,
      status = status,
      error_message = if (is.na(error_message)) NULL else error_message,
      config = cfg,
      summary = as.list(health_row[1L, , drop = FALSE]),
      error_payload = error_payload
    )
  }

  .qdesn_validation_write_json(file.path(method_dir, "fit_summary.json"), fit_summary)
  .qdesn_validation_write_df(health_row, file.path(method_dir, "health_summary.csv"))

  progress_trace <- if (!is.null(summary_obj)) .qdesn_validation_method_progress_trace(method, summary_obj) else data.frame(stringsAsFactors = FALSE)
  if (nrow(progress_trace)) {
    .qdesn_validation_write_df(progress_trace, file.path(method_dir, "progress_trace.csv"))
  }
  latent_v_trace <- if (!is.null(summary_obj)) .qdesn_validation_method_latent_v_trace(method, summary_obj) else data.frame(stringsAsFactors = FALSE)
  if (nrow(latent_v_trace)) {
    .qdesn_validation_write_df(latent_v_trace, file.path(method_dir, "latent_v_trace.csv"))
  }
  sigmagam_trace <- if (!is.null(summary_obj)) .qdesn_validation_method_sigmagam_trace(method, summary_obj) else data.frame(stringsAsFactors = FALSE)
  if (nrow(sigmagam_trace)) {
    .qdesn_validation_write_df(sigmagam_trace, file.path(method_dir, "sigmagam_trace.csv"))
  }
  theta_trace <- if (!is.null(summary_obj)) .qdesn_validation_method_theta_trace(method, summary_obj) else data.frame(stringsAsFactors = FALSE)
  if (nrow(theta_trace)) {
    .qdesn_validation_write_df(theta_trace, file.path(method_dir, "theta_trace.csv"))
  }
  if (identical(method, "mcmc") && !is.null(summary_obj)) {
    chain_summary <- .qdesn_validation_mcmc_chain_summary(summary_obj)
    if (nrow(chain_summary)) {
      .qdesn_validation_write_df(chain_summary, file.path(method_dir, "chain_summary.csv"))
    }
  }
  retention_manifest <- .qdesn_validation_apply_output_retention(
    method_dir = method_dir,
    status = status,
    defaults = defaults,
    root_spec = root_spec,
    summary_obj = summary_obj
  )

  end_time <- Sys.time()
  list(
    method = method,
    status = status,
    error_message = error_message,
    cfg = cfg,
    start_time = as.character(start_time),
    end_time = as.character(end_time),
    elapsed_seconds = as.numeric(difftime(end_time, start_time, units = "secs")),
    run = run_res,
    summary = summary_obj,
    health = health_row,
    progress_trace = progress_trace,
    latent_v_trace = latent_v_trace,
    sigmagam_trace = sigmagam_trace,
    theta_trace = theta_trace,
    output_retention = retention_manifest,
    forecast_df = if (!is.null(summary_obj)) .qdesn_validation_extract_forecast_df(summary_obj) else data.frame(stringsAsFactors = FALSE)
  )
}

.qdesn_validation_pair_summary <- function(method_rows) {
  if (!nrow(method_rows)) return(data.frame(stringsAsFactors = FALSE))
  keys <- c("root_id", "scenario", "tau", "likelihood_family", "beta_prior_type", "seed", "reservoir_profile")
  vb <- method_rows[method_rows$method == "vb", , drop = FALSE]
  mc <- method_rows[method_rows$method == "mcmc", , drop = FALSE]
  if (!nrow(vb) || !nrow(mc)) return(data.frame(stringsAsFactors = FALSE))

  keep_vb <- c(keys, "status", "wall_seconds", "total_stage_seconds", "forecast_CRPS_mean",
               "forecast_PinballMean_mean", "forecast_S_mean", "forecast_qhat_mae",
               "forecast_qhat_rmse", "forecast_pinball_tau", "forecast_qhat_bias",
               "signal_qhat_mae", "signal_qhat_rmse", "signal_qhat_corr", "fit_runtime_seconds",
               "finite_ok", "domain_ok", "vb_converged", "vb_iter", "vb_gamma_last",
               "vb_sigma_last", "vb_elbo_last", "vb_beta_norm", "rhs_tau_last", "rhs_c2_last",
               "unhealthy", "unhealthy_reason", "rhs_collapse_flag", "rhs_collapse_flag_shrink",
               "signoff_grade", "comparison_eligible", "signoff_reason")
  keep_mc <- c(keys, "status", "wall_seconds", "total_stage_seconds", "forecast_CRPS_mean",
               "forecast_PinballMean_mean", "forecast_S_mean", "forecast_qhat_mae",
               "forecast_qhat_rmse", "forecast_pinball_tau", "forecast_qhat_bias",
               "signal_qhat_mae", "signal_qhat_rmse", "signal_qhat_corr", "fit_runtime_seconds",
               "finite_ok", "domain_ok", "unhealthy", "unhealthy_reason",
               "rhs_collapse_flag", "rhs_collapse_flag_shrink",
               "signoff_grade", "comparison_eligible", "signoff_reason",
               "mcmc_n_keep", "mcmc_ess_gamma", "mcmc_ess_sigma", "mcmc_ess_beta_norm",
               "mcmc_ess_per_second_gamma", "mcmc_ess_per_second_sigma", "mcmc_ess_per_second_beta_norm",
               "mcmc_gamma_mean", "mcmc_sigma_mean", "mcmc_beta_norm_mean",
               "rhs_tau_mean", "rhs_c2_mean", "rhs_lambda_mean")
  keep_vb <- keep_vb[keep_vb %in% names(vb)]
  keep_mc <- keep_mc[keep_mc %in% names(mc)]
  keys_eff <- keys[keys %in% keep_vb & keys %in% keep_mc]
  if (!length(keys_eff)) return(data.frame(stringsAsFactors = FALSE))

  vb_sub <- vb[, keep_vb, drop = FALSE]
  mc_sub <- mc[, keep_mc, drop = FALSE]
  names(vb_sub) <- c(keys_eff, paste0("vb_", setdiff(keep_vb, keys_eff)))
  names(mc_sub) <- c(keys_eff, paste0("mcmc_", setdiff(keep_mc, keys_eff)))
  out <- merge(vb_sub, mc_sub, by = keys_eff, all = TRUE, sort = FALSE)
  if ("mcmc_wall_seconds" %in% names(out) && "vb_wall_seconds" %in% names(out)) {
    out$runtime_ratio_mcmc_vs_vb <- with(out, ifelse(is.finite(vb_wall_seconds) & vb_wall_seconds > 0, mcmc_wall_seconds / vb_wall_seconds, NA_real_))
  }
  if ("mcmc_total_stage_seconds" %in% names(out) && "vb_total_stage_seconds" %in% names(out)) {
    out$stage_runtime_ratio_mcmc_vs_vb <- with(out, ifelse(
      is.finite(vb_total_stage_seconds) & vb_total_stage_seconds > 0,
      mcmc_total_stage_seconds / vb_total_stage_seconds,
      NA_real_
    ))
  }
  if ("mcmc_forecast_CRPS_mean" %in% names(out) && "vb_forecast_CRPS_mean" %in% names(out)) {
    out$forecast_CRPS_delta_mcmc_minus_vb <- out$mcmc_forecast_CRPS_mean - out$vb_forecast_CRPS_mean
  }
  if ("mcmc_forecast_PinballMean_mean" %in% names(out) && "vb_forecast_PinballMean_mean" %in% names(out)) {
    out$forecast_Pinball_delta_mcmc_minus_vb <- out$mcmc_forecast_PinballMean_mean - out$vb_forecast_PinballMean_mean
  }
  if ("mcmc_forecast_S_mean" %in% names(out) && "vb_forecast_S_mean" %in% names(out)) {
    out$forecast_S_delta_mcmc_minus_vb <- out$mcmc_forecast_S_mean - out$vb_forecast_S_mean
  }
  if ("mcmc_forecast_qhat_mae" %in% names(out) && "vb_forecast_qhat_mae" %in% names(out)) {
    out$forecast_qhat_mae_delta_mcmc_minus_vb <- out$mcmc_forecast_qhat_mae - out$vb_forecast_qhat_mae
  }
  if ("mcmc_forecast_qhat_rmse" %in% names(out) && "vb_forecast_qhat_rmse" %in% names(out)) {
    out$forecast_qhat_rmse_delta_mcmc_minus_vb <- out$mcmc_forecast_qhat_rmse - out$vb_forecast_qhat_rmse
  }
  if ("mcmc_forecast_pinball_tau" %in% names(out) && "vb_forecast_pinball_tau" %in% names(out)) {
    out$forecast_pinball_tau_delta_mcmc_minus_vb <- out$mcmc_forecast_pinball_tau - out$vb_forecast_pinball_tau
  }
  if ("mcmc_signal_qhat_rmse" %in% names(out) && "vb_signal_qhat_rmse" %in% names(out)) {
    out$signal_qhat_rmse_delta_mcmc_minus_vb <- out$mcmc_signal_qhat_rmse - out$vb_signal_qhat_rmse
  }
  if ("mcmc_signal_qhat_corr" %in% names(out) && "vb_signal_qhat_corr" %in% names(out)) {
    out$signal_qhat_corr_delta_mcmc_minus_vb <- out$mcmc_signal_qhat_corr - out$vb_signal_qhat_corr
  }
  if ("mcmc_status" %in% names(out) && "vb_status" %in% names(out)) {
    out$both_success <- as.logical(out$vb_status == "SUCCESS" & out$mcmc_status == "SUCCESS")
  }
  if (all(c("vb_finite_ok", "mcmc_finite_ok") %in% names(out))) {
    out$both_finite_ok <- as.logical(out$vb_finite_ok & out$mcmc_finite_ok)
  }
  if (all(c("vb_domain_ok", "mcmc_domain_ok") %in% names(out))) {
    out$both_domain_ok <- as.logical(out$vb_domain_ok & out$mcmc_domain_ok)
  }
  if ("forecast_qhat_mae_delta_mcmc_minus_vb" %in% names(out)) {
    out$mcmc_better_qhat_mae <- as.logical(is.finite(out$forecast_qhat_mae_delta_mcmc_minus_vb) &
      out$forecast_qhat_mae_delta_mcmc_minus_vb < 0)
  }
  if ("forecast_pinball_tau_delta_mcmc_minus_vb" %in% names(out)) {
    out$mcmc_better_pinball_tau <- as.logical(is.finite(out$forecast_pinball_tau_delta_mcmc_minus_vb) &
      out$forecast_pinball_tau_delta_mcmc_minus_vb < 0)
  }
  if (all(c("vb_signoff_grade", "mcmc_signoff_grade") %in% names(out))) {
    out$pair_signoff_grade <- ifelse(
      out$vb_signoff_grade == "PASS" & out$mcmc_signoff_grade == "PASS",
      "PASS",
      ifelse(out$vb_signoff_grade != "FAIL" & out$mcmc_signoff_grade != "FAIL", "WARN", "FAIL")
    )
  }
  if (all(c("vb_comparison_eligible", "mcmc_comparison_eligible") %in% names(out))) {
    out$pair_comparison_eligible <- as.logical(out$vb_comparison_eligible & out$mcmc_comparison_eligible)
  }
  out
}

.qdesn_validation_root_summary <- function(root_spec, method_rows, pair_summary) {
  status_vec <- if ("status" %in% names(method_rows)) as.character(method_rows$status) else character(0)
  status_vec[!nzchar(status_vec) | is.na(status_vec)] <- "FAIL"
  root_status <- if (nrow(method_rows) >= 2L && length(status_vec) >= 2L && all(status_vec == "SUCCESS")) "SUCCESS" else "FAIL"
  data.frame(
    root_id = root_spec$root_id,
    scenario = root_spec$scenario,
    tau = as.numeric(root_spec$tau),
    likelihood_family = as.character(root_spec$likelihood_family %||% "exal")[1L],
    beta_prior_type = root_spec$beta_prior_type,
    seed = as.integer(root_spec$seed),
    reservoir_profile = root_spec$reservoir_profile,
    root_status = root_status,
    n_methods = nrow(method_rows),
    vb_status = if (any(method_rows$method == "vb")) as.character(method_rows$status[method_rows$method == "vb"][1L]) else NA_character_,
    mcmc_status = if (any(method_rows$method == "mcmc")) as.character(method_rows$status[method_rows$method == "mcmc"][1L]) else NA_character_,
    vb_signoff_grade = if (any(method_rows$method == "vb")) as.character(method_rows$signoff_grade[method_rows$method == "vb"][1L] %||% NA_character_) else NA_character_,
    mcmc_signoff_grade = if (any(method_rows$method == "mcmc")) as.character(method_rows$signoff_grade[method_rows$method == "mcmc"][1L] %||% NA_character_) else NA_character_,
    pair_signoff_grade = as.character(pair_summary$pair_signoff_grade[1L] %||% NA_character_),
    pair_comparison_eligible = as.logical(pair_summary$pair_comparison_eligible[1L] %||% FALSE),
    both_finite_ok = as.logical(pair_summary$both_finite_ok[1L] %||% FALSE),
    both_domain_ok = as.logical(pair_summary$both_domain_ok[1L] %||% FALSE),
    runtime_ratio_mcmc_vs_vb = as.numeric(pair_summary$runtime_ratio_mcmc_vs_vb[1L] %||% NA_real_),
    stage_runtime_ratio_mcmc_vs_vb = as.numeric(pair_summary$stage_runtime_ratio_mcmc_vs_vb[1L] %||% NA_real_),
    forecast_CRPS_delta_mcmc_minus_vb = as.numeric(pair_summary$forecast_CRPS_delta_mcmc_minus_vb[1L] %||% NA_real_),
    forecast_Pinball_delta_mcmc_minus_vb = as.numeric(pair_summary$forecast_Pinball_delta_mcmc_minus_vb[1L] %||% NA_real_),
    forecast_S_delta_mcmc_minus_vb = as.numeric(pair_summary$forecast_S_delta_mcmc_minus_vb[1L] %||% NA_real_),
    forecast_qhat_mae_delta_mcmc_minus_vb = as.numeric(pair_summary$forecast_qhat_mae_delta_mcmc_minus_vb[1L] %||% NA_real_),
    forecast_qhat_rmse_delta_mcmc_minus_vb = as.numeric(pair_summary$forecast_qhat_rmse_delta_mcmc_minus_vb[1L] %||% NA_real_),
    forecast_pinball_tau_delta_mcmc_minus_vb = as.numeric(pair_summary$forecast_pinball_tau_delta_mcmc_minus_vb[1L] %||% NA_real_),
    signal_qhat_rmse_delta_mcmc_minus_vb = as.numeric(pair_summary$signal_qhat_rmse_delta_mcmc_minus_vb[1L] %||% NA_real_),
    signal_qhat_corr_delta_mcmc_minus_vb = as.numeric(pair_summary$signal_qhat_corr_delta_mcmc_minus_vb[1L] %||% NA_real_),
    stringsAsFactors = FALSE
  )
}

qdesn_validation_run_root <- function(root_spec,
                                      defaults = NULL,
                                      defaults_path = file.path("config", "validation", "qdesn_mcmc_pilot_defaults.yaml"),
                                      output_root,
                                      create_plots = TRUE,
                                      verbose = TRUE) {
  defaults <- defaults %||% qdesn_validation_load_defaults(defaults_path)
  root_spec <- qdesn_validation_enrich_root_spec(root_spec, defaults)
  threads <- as.integer(((defaults$runtime %||% list())$threads %||% 1L)[1L])
  .qdesn_validation_apply_thread_caps(threads)

  root_dir <- file.path(output_root, root_spec$root_id)
  if (dir.exists(root_dir) && length(list.files(root_dir, all.files = TRUE, no.. = TRUE)) > 0L) {
    stop(sprintf("Validation root already exists and is not empty: %s", root_dir), call. = FALSE)
  }

  for (d in c("manifest", "config", "data", "fits", "fits/vb", "fits/mcmc", "tables", "plots")) {
    .qdesn_validation_dir_create(file.path(root_dir, d))
  }
  .qdesn_validation_write_lines(file.path(root_dir, "manifest", "root_status.txt"), "RUNNING")

  scenario_cfg <- .qdesn_validation_scenario_cfg(defaults, root_spec$scenario)
  p_grid <- as.numeric((defaults$toy %||% list())$p_grid %||% seq(0.01, 0.99, by = 0.01))
  toy_obj <- qdesn_validation_generate_toy_series(
    scenario = root_spec$scenario,
    seed = root_spec$seed,
    p_grid = p_grid,
    scenario_cfg = scenario_cfg
  )
  .qdesn_validation_write_toy_data(root_dir, toy_obj)

  root_manifest <- list(
    root_id = root_spec$root_id,
    scenario = root_spec$scenario,
    tau = as.numeric(root_spec$tau),
    likelihood_family = as.character(root_spec$likelihood_family %||% "exal")[1L],
    beta_prior_type = root_spec$beta_prior_type,
    seed = as.integer(root_spec$seed),
    reservoir_profile = root_spec$reservoir_profile,
    git_sha = .qdesn_validation_git_sha(),
    started_at = as.character(Sys.time()),
    defaults_path = defaults_path
  )
  .qdesn_validation_write_json(file.path(root_dir, "manifest", "root_manifest.json"), root_manifest)
  .qdesn_validation_write_json(file.path(root_dir, "config", "root_config.json"), list(root_spec = root_spec, defaults = defaults))

  method_status_rows <- data.frame(stringsAsFactors = FALSE)
  results <- list()
  file_long <- file.path(root_dir, "data", "series_long.csv")

  for (method in c("vb", "mcmc")) {
    if (isTRUE(verbose)) {
      message(sprintf("[qdesn_validation_run_root] %s | %s", root_spec$root_id, method))
    }
    method_dir <- file.path(root_dir, "fits", method)
    res <- .qdesn_validation_run_one_method(method, root_spec, defaults, file_long, method_dir, verbose = verbose)
    results[[method]] <- res
    method_status_rows <- .qdesn_validation_bind_rows(list(method_status_rows, data.frame(
      root_id = root_spec$root_id,
      method = method,
      status = res$status,
      start_time = res$start_time,
      end_time = res$end_time,
      elapsed_seconds = res$elapsed_seconds,
      error_message = if (is.na(res$error_message)) "" else res$error_message,
      stringsAsFactors = FALSE
    )))
    .qdesn_validation_update_method_status(root_dir, method_status_rows)
  }

  method_rows <- .qdesn_validation_bind_rows(lapply(results, function(x) x$health))
  signoff_rows <- .qdesn_validation_collect_method_signoff_rows(root_dir, defaults = defaults)
  if (nrow(signoff_rows)) {
    method_rows <- merge(
      method_rows,
      signoff_rows,
      by = c("root_id", "scenario", "tau", "likelihood_family", "beta_prior_type", "seed", "reservoir_profile", "method"),
      all.x = TRUE,
      sort = FALSE
    )
    .qdesn_validation_write_df(signoff_rows, file.path(root_dir, "tables", "method_signoff_long.csv"))
  }
  if (nrow(method_rows)) {
    .qdesn_validation_write_df(method_rows, file.path(root_dir, "tables", "method_compare_long.csv"))
  }

  pair_summary <- .qdesn_validation_pair_summary(method_rows)
  if (nrow(pair_summary)) {
    .qdesn_validation_write_df(pair_summary, file.path(root_dir, "tables", "method_compare_summary.csv"))
  }

  root_summary <- .qdesn_validation_root_summary(root_spec, method_rows, pair_summary)
  .qdesn_validation_write_df(root_summary, file.path(root_dir, "tables", "root_summary.csv"))

  progress_rows <- .qdesn_validation_bind_rows(lapply(results, function(x) x$progress_trace))
  if (nrow(progress_rows)) {
    .qdesn_validation_write_df(progress_rows, file.path(root_dir, "tables", "algorithm_progress_long.csv"))
  }

  forecast_rows <- .qdesn_validation_bind_rows(lapply(results, function(x) {
    df <- x$forecast_df
    if (!nrow(df)) return(NULL)
    df$method <- x$method
    df
  }))
  if (nrow(forecast_rows)) {
    .qdesn_validation_write_df(forecast_rows, file.path(root_dir, "tables", "forecast_compare_long.csv"))
  }

  if (isTRUE(create_plots)) {
    .qdesn_validation_plot_series_overview(root_dir, root_spec, toy_obj)
    .qdesn_validation_plot_forecast_compare(root_dir, method_rows, forecast_rows)
    .qdesn_validation_plot_runtime_compare(root_dir, method_rows)
    .qdesn_validation_plot_score_compare(root_dir, method_rows)
    .qdesn_validation_plot_algorithm_progress(root_dir, progress_rows)
    if (root_spec$beta_prior_type %in% c("rhs", "rhs_ns")) {
      .qdesn_validation_plot_rhs_progress(root_dir, progress_rows)
    }
  }

  root_status <- if (nrow(method_rows) >= 2L && all(as.character(method_rows$status) == "SUCCESS")) "SUCCESS" else "FAIL"
  .qdesn_validation_write_lines(file.path(root_dir, "manifest", "root_status.txt"), root_status)
  .qdesn_validation_write_json(file.path(root_dir, "manifest", "runtime_summary.json"), list(
    root_status = root_status,
    started_at = root_manifest$started_at,
    finished_at = as.character(Sys.time()),
    methods = method_status_rows
  ))

  list(
    root_dir = root_dir,
    root_spec = root_spec,
    root_status = root_status,
    method_rows = method_rows,
    pair_summary = pair_summary,
    root_summary = root_summary
  )
}

.qdesn_validation_collect_root_meta <- function(root_dir) {
  root_summary_path <- file.path(root_dir, "tables", "root_summary.csv")
  if (file.exists(root_summary_path)) {
    out <- utils::read.csv(root_summary_path, stringsAsFactors = FALSE)
    if (nrow(out)) {
      if (!("likelihood_family" %in% names(out))) {
        out$likelihood_family <- "exal"
      }
      return(out[1L, , drop = FALSE])
    }
  }
  root_manifest_path <- file.path(root_dir, "manifest", "root_manifest.json")
  manifest <- .qdesn_validation_read_json_if_exists(root_manifest_path)
  if (is.null(manifest)) return(data.frame(stringsAsFactors = FALSE))
  data.frame(
    root_id = as.character(manifest$root_id %||% basename(root_dir)),
    scenario = as.character(manifest$scenario %||% NA_character_),
    tau = as.numeric(manifest$tau %||% NA_real_),
    likelihood_family = as.character(manifest$likelihood_family %||% "exal"),
    beta_prior_type = as.character(manifest$beta_prior_type %||% NA_character_),
    seed = as.integer(manifest$seed %||% NA_integer_),
    reservoir_profile = as.character(manifest$reservoir_profile %||% NA_character_),
    stringsAsFactors = FALSE
  )
}

.qdesn_validation_collect_stage_rows <- function(root_dirs) {
  rows <- list()
  for (root_dir in root_dirs) {
    meta <- .qdesn_validation_collect_root_meta(root_dir)
    if (!nrow(meta)) next
    for (method in c("vb", "mcmc")) {
      stage_path <- file.path(root_dir, "fits", method, "tables", "timing_breakdown.csv")
      if (!file.exists(stage_path)) next
      stage_df <- utils::read.csv(stage_path, stringsAsFactors = FALSE)
      if (!nrow(stage_df)) next
      rows[[length(rows) + 1L]] <- cbind(
        meta[rep(1L, nrow(stage_df)), , drop = FALSE],
        data.frame(method = method, stringsAsFactors = FALSE),
        stage_df,
        stringsAsFactors = FALSE
      )
    }
  }
  .qdesn_validation_bind_rows(rows)
}

.qdesn_validation_collect_chain_rows <- function(root_dirs) {
  rows <- list()
  for (root_dir in root_dirs) {
    meta <- .qdesn_validation_collect_root_meta(root_dir)
    if (!nrow(meta)) next
    chain_path <- file.path(root_dir, "fits", "mcmc", "chain_summary.csv")
    if (!file.exists(chain_path)) next
    chain_df <- utils::read.csv(chain_path, stringsAsFactors = FALSE)
    if (!nrow(chain_df)) next
    rows[[length(rows) + 1L]] <- cbind(meta[rep(1L, nrow(chain_df)), , drop = FALSE], chain_df, stringsAsFactors = FALSE)
  }
  .qdesn_validation_bind_rows(rows)
}

.qdesn_validation_collect_method_signoff_rows <- function(root_dirs, defaults = NULL) {
  cfg <- .qdesn_validation_signoff_cfg(defaults)
  rows <- list()
  for (root_dir in root_dirs) {
    meta <- .qdesn_validation_collect_root_meta(root_dir)
    if (!nrow(meta)) next
    for (method in c("vb", "mcmc")) {
      health_path <- file.path(root_dir, "fits", method, "health_summary.csv")
      if (!file.exists(health_path)) next
      health_row <- utils::read.csv(health_path, stringsAsFactors = FALSE)
      if (!nrow(health_row)) next
      progress_path <- file.path(root_dir, "fits", method, "progress_trace.csv")
      progress_rows <- if (file.exists(progress_path)) {
        utils::read.csv(progress_path, stringsAsFactors = FALSE)
      } else {
        data.frame(stringsAsFactors = FALSE)
      }
      signoff_row <- if (identical(method, "vb")) {
        .qdesn_validation_vb_signoff_from_rows(meta[1L, , drop = FALSE], health_row[1L, , drop = FALSE], progress_rows, cfg$vb)
      } else {
        .qdesn_validation_mcmc_signoff_from_rows(meta[1L, , drop = FALSE], health_row[1L, , drop = FALSE], progress_rows, cfg$mcmc)
      }
      rows[[length(rows) + 1L]] <- signoff_row
    }
  }
  .qdesn_validation_bind_rows(rows)
}

.qdesn_validation_group_method_summary <- function(method_summary) {
  if (!nrow(method_summary)) return(data.frame(stringsAsFactors = FALSE))
  group_cols <- c("scenario", "tau", "likelihood_family", "beta_prior_type", "reservoir_profile", "method")
  group_cols <- group_cols[group_cols %in% names(method_summary)]
  if (!length(group_cols)) return(data.frame(stringsAsFactors = FALSE))
  numeric_cols <- c(
    "wall_seconds", "total_stage_seconds", "forecast_CRPS_mean",
    "forecast_PinballMean_mean", "forecast_S_mean", "forecast_qhat_mae",
    "forecast_qhat_rmse", "forecast_pinball_tau", "forecast_qhat_bias",
    "signal_qhat_mae", "signal_qhat_rmse", "signal_qhat_corr", "fit_runtime_seconds",
    "mcmc_ess_gamma", "mcmc_ess_sigma", "mcmc_ess_beta_norm",
    "mcmc_ess_per_second_gamma", "mcmc_ess_per_second_sigma",
    "mcmc_ess_per_second_beta_norm"
  )
  numeric_part <- .qdesn_validation_group_numeric(method_summary, group_cols, numeric_cols)
  split_idx <- split(seq_len(nrow(method_summary)), interaction(method_summary[, group_cols, drop = FALSE], drop = TRUE, lex.order = TRUE))
  status_rows <- lapply(split_idx, function(idx) {
    sub <- method_summary[idx, , drop = FALSE]
    row <- sub[1L, group_cols, drop = FALSE]
    row$n_roots <- nrow(sub)
    row$n_success <- sum(as.character(sub$status) == "SUCCESS", na.rm = TRUE)
    row$success_rate <- row$n_success / row$n_roots
    row$finite_ok_rate <- mean(as.logical(sub$finite_ok), na.rm = TRUE)
    row$domain_ok_rate <- mean(as.logical(sub$domain_ok), na.rm = TRUE)
    row$n_signoff_pass <- sum(as.character(sub$signoff_grade) == "PASS", na.rm = TRUE)
    row$n_signoff_warn <- sum(as.character(sub$signoff_grade) == "WARN", na.rm = TRUE)
    row$n_signoff_fail <- sum(as.character(sub$signoff_grade) == "FAIL", na.rm = TRUE)
    row$signoff_pass_rate <- row$n_signoff_pass / row$n_roots
    row$comparison_eligible_rate <- mean(as.logical(sub$comparison_eligible), na.rm = TRUE)
    row
  })
  status_part <- .qdesn_validation_bind_rows(status_rows)
  if (!nrow(status_part)) return(numeric_part)
  if (!nrow(numeric_part)) return(status_part)
  by_cols <- intersect(group_cols, intersect(names(status_part), names(numeric_part)))
  if (!length(by_cols)) return(status_part)
  merge(status_part, numeric_part, by = by_cols, all = TRUE, sort = FALSE)
}

.qdesn_validation_group_pair_summary <- function(pair_summary) {
  if (!nrow(pair_summary)) return(data.frame(stringsAsFactors = FALSE))
  group_cols <- c("scenario", "tau", "likelihood_family", "beta_prior_type", "reservoir_profile")
  group_cols <- group_cols[group_cols %in% names(pair_summary)]
  if (!length(group_cols)) return(data.frame(stringsAsFactors = FALSE))
  numeric_cols <- c(
    "vb_wall_seconds", "mcmc_wall_seconds", "vb_total_stage_seconds",
    "mcmc_total_stage_seconds", "runtime_ratio_mcmc_vs_vb",
    "stage_runtime_ratio_mcmc_vs_vb", "vb_forecast_CRPS_mean",
    "mcmc_forecast_CRPS_mean", "forecast_CRPS_delta_mcmc_minus_vb",
    "vb_forecast_PinballMean_mean", "mcmc_forecast_PinballMean_mean",
    "forecast_Pinball_delta_mcmc_minus_vb", "vb_forecast_S_mean",
    "mcmc_forecast_S_mean", "forecast_S_delta_mcmc_minus_vb",
    "vb_forecast_qhat_mae", "mcmc_forecast_qhat_mae",
    "forecast_qhat_mae_delta_mcmc_minus_vb",
    "vb_forecast_qhat_rmse", "mcmc_forecast_qhat_rmse",
    "forecast_qhat_rmse_delta_mcmc_minus_vb",
    "vb_signal_qhat_rmse", "mcmc_signal_qhat_rmse",
    "signal_qhat_rmse_delta_mcmc_minus_vb",
    "vb_signal_qhat_corr", "mcmc_signal_qhat_corr",
    "signal_qhat_corr_delta_mcmc_minus_vb",
    "vb_forecast_pinball_tau", "mcmc_forecast_pinball_tau",
    "forecast_pinball_tau_delta_mcmc_minus_vb"
  )
  numeric_part <- .qdesn_validation_group_numeric(pair_summary, group_cols, numeric_cols)
  split_idx <- split(seq_len(nrow(pair_summary)), interaction(pair_summary[, group_cols, drop = FALSE], drop = TRUE, lex.order = TRUE))
  status_rows <- lapply(split_idx, function(idx) {
    sub <- pair_summary[idx, , drop = FALSE]
    row <- sub[1L, group_cols, drop = FALSE]
    row$n_pairs <- nrow(sub)
    row$n_both_success <- sum(as.logical(sub$both_success), na.rm = TRUE)
    row$both_success_rate <- row$n_both_success / row$n_pairs
    row$both_finite_ok_rate <- mean(as.logical(sub$both_finite_ok), na.rm = TRUE)
    row$both_domain_ok_rate <- mean(as.logical(sub$both_domain_ok), na.rm = TRUE)
    row$n_pair_signoff_pass <- sum(as.character(sub$pair_signoff_grade) == "PASS", na.rm = TRUE)
    row$n_pair_signoff_warn <- sum(as.character(sub$pair_signoff_grade) == "WARN", na.rm = TRUE)
    row$n_pair_signoff_fail <- sum(as.character(sub$pair_signoff_grade) == "FAIL", na.rm = TRUE)
    row$pair_signoff_pass_rate <- row$n_pair_signoff_pass / row$n_pairs
    row$pair_comparison_eligible_rate <- mean(as.logical(sub$pair_comparison_eligible), na.rm = TRUE)
    row$n_mcmc_better_qhat_mae <- sum(as.logical(sub$mcmc_better_qhat_mae), na.rm = TRUE)
    row$n_mcmc_better_pinball_tau <- sum(as.logical(sub$mcmc_better_pinball_tau), na.rm = TRUE)
    row$mcmc_better_qhat_mae_rate <- row$n_mcmc_better_qhat_mae / row$n_pairs
    row$mcmc_better_pinball_tau_rate <- row$n_mcmc_better_pinball_tau / row$n_pairs
    row
  })
  status_part <- .qdesn_validation_bind_rows(status_rows)
  if (!nrow(status_part)) return(numeric_part)
  if (!nrow(numeric_part)) return(status_part)
  by_cols <- intersect(group_cols, intersect(names(status_part), names(numeric_part)))
  if (!length(by_cols)) return(status_part)
  merge(status_part, numeric_part, by = by_cols, all = TRUE, sort = FALSE)
}

.qdesn_validation_resolve_tau_targets <- function(method_summary, defaults = NULL) {
  cfg_tau <- ((defaults %||% list())$pipeline %||% list())$validation_p_vec %||% NULL
  tau_targets <- as.numeric(unlist(cfg_tau %||% numeric(0), use.names = FALSE))
  tau_targets <- tau_targets[is.finite(tau_targets) & tau_targets > 0 & tau_targets < 1]
  if (!length(tau_targets) && nrow(method_summary) && "tau" %in% names(method_summary)) {
    tau_targets <- as.numeric(method_summary$tau)
  }
  tau_targets <- sort(unique(tau_targets))
  if (!length(tau_targets)) tau_targets <- 0.5
  tau_targets
}

.qdesn_validation_row_health_flag <- function(df) {
  status_ok <- if ("status" %in% names(df)) as.character(df$status) == "SUCCESS" else FALSE
  finite_ok <- if ("finite_ok" %in% names(df)) as.logical(df$finite_ok) else FALSE
  domain_ok <- if ("domain_ok" %in% names(df)) as.logical(df$domain_ok) else FALSE
  signoff_ok <- if ("signoff_grade" %in% names(df)) {
    sg <- as.character(df$signoff_grade)
    !is.na(sg) & nzchar(sg) & sg != "FAIL"
  } else {
    FALSE
  }
  unhealthy <- if ("unhealthy" %in% names(df)) as.logical(df$unhealthy) else FALSE
  as.logical(status_ok & finite_ok & domain_ok & signoff_ok & !unhealthy)
}

.qdesn_validation_group_tau_set_method_summary <- function(method_summary, tau_targets = NULL) {
  if (!nrow(method_summary)) return(data.frame(stringsAsFactors = FALSE))
  tau_targets <- as.numeric(tau_targets %||% numeric(0))
  tau_targets <- tau_targets[is.finite(tau_targets) & tau_targets > 0 & tau_targets < 1]
  if (!length(tau_targets)) {
    tau_targets <- sort(unique(as.numeric(method_summary$tau)))
  }
  tau_targets <- sort(unique(tau_targets))
  tau_target_keys <- .qdesn_validation_tau_key(tau_targets)
  tau_targets_label <- paste(tau_target_keys, collapse = ",")

  group_cols <- c("scenario", "likelihood_family", "beta_prior_type", "seed", "reservoir_profile", "method")
  group_cols <- group_cols[group_cols %in% names(method_summary)]
  split_idx <- split(
    seq_len(nrow(method_summary)),
    interaction(method_summary[, group_cols, drop = FALSE], drop = TRUE, lex.order = TRUE)
  )

  mean_if_finite <- function(x) {
    x <- as.numeric(x)
    ok <- is.finite(x)
    if (!any(ok)) return(NA_real_)
    mean(x[ok])
  }
  sum_if_finite <- function(x) {
    x <- as.numeric(x)
    ok <- is.finite(x)
    if (!any(ok)) return(NA_real_)
    sum(x[ok])
  }

  rows <- lapply(split_idx, function(idx) {
    sub <- method_summary[idx, , drop = FALSE]
    sub$tau_key <- .qdesn_validation_tau_key(sub$tau)
    sub <- sub[sub$tau_key %in% tau_target_keys, , drop = FALSE]

    key_present <- setNames(rep(FALSE, length(tau_target_keys)), tau_target_keys)
    key_success <- setNames(rep(FALSE, length(tau_target_keys)), tau_target_keys)
    key_healthy <- setNames(rep(FALSE, length(tau_target_keys)), tau_target_keys)
    if (nrow(sub)) {
      split_key <- split(seq_len(nrow(sub)), sub$tau_key)
      for (k in names(split_key)) {
        jj <- split_key[[k]]
        key_present[[k]] <- TRUE
        key_success[[k]] <- any(as.character(sub$status[jj]) == "SUCCESS", na.rm = TRUE)
        key_healthy[[k]] <- any(.qdesn_validation_row_health_flag(sub[jj, , drop = FALSE]), na.rm = TRUE)
      }
    }

    n_tau_targets <- length(tau_target_keys)
    n_tau_present <- sum(key_present)
    n_tau_success <- sum(key_success)
    n_tau_healthy <- sum(key_healthy)
    tau_complete_present <- n_tau_present == n_tau_targets
    tau_complete_success <- tau_complete_present && n_tau_success == n_tau_targets
    tau_complete_healthy <- tau_complete_present && n_tau_healthy == n_tau_targets
    synthesis_status <- if (!tau_complete_present) {
      "INCOMPLETE"
    } else if (tau_complete_healthy) {
      "COMPLETE_HEALTHY"
    } else if (tau_complete_success) {
      "COMPLETE_UNHEALTHY"
    } else {
      "INCOMPLETE"
    }

    row <- sub[1L, group_cols, drop = FALSE]
    row$tau_targets <- tau_targets_label
    row$n_tau_targets <- n_tau_targets
    row$n_tau_present <- n_tau_present
    row$n_tau_success <- n_tau_success
    row$n_tau_healthy <- n_tau_healthy
    row$tau_complete_present <- tau_complete_present
    row$tau_complete_success <- tau_complete_success
    row$tau_complete_healthy <- tau_complete_healthy
    row$synthesis_status <- synthesis_status

    row$wall_seconds_sum <- if ("wall_seconds" %in% names(sub)) sum_if_finite(sub$wall_seconds) else NA_real_
    row$total_stage_seconds_sum <- if ("total_stage_seconds" %in% names(sub)) sum_if_finite(sub$total_stage_seconds) else NA_real_
    row$fit_runtime_seconds_sum <- if ("fit_runtime_seconds" %in% names(sub)) sum_if_finite(sub$fit_runtime_seconds) else NA_real_
    row$forecast_CRPS_mean_avg <- if ("forecast_CRPS_mean" %in% names(sub)) mean_if_finite(sub$forecast_CRPS_mean) else NA_real_
    row$forecast_PinballMean_mean_avg <- if ("forecast_PinballMean_mean" %in% names(sub)) mean_if_finite(sub$forecast_PinballMean_mean) else NA_real_
    row$forecast_S_mean_avg <- if ("forecast_S_mean" %in% names(sub)) mean_if_finite(sub$forecast_S_mean) else NA_real_
    row$forecast_qhat_mae_avg <- if ("forecast_qhat_mae" %in% names(sub)) mean_if_finite(sub$forecast_qhat_mae) else NA_real_
    row$forecast_qhat_rmse_avg <- if ("forecast_qhat_rmse" %in% names(sub)) mean_if_finite(sub$forecast_qhat_rmse) else NA_real_
    row$forecast_pinball_tau_avg <- if ("forecast_pinball_tau" %in% names(sub)) mean_if_finite(sub$forecast_pinball_tau) else NA_real_
    row$signal_qhat_rmse_avg <- if ("signal_qhat_rmse" %in% names(sub)) mean_if_finite(sub$signal_qhat_rmse) else NA_real_
    row$signal_qhat_corr_avg <- if ("signal_qhat_corr" %in% names(sub)) mean_if_finite(sub$signal_qhat_corr) else NA_real_

    if ("signoff_grade" %in% names(sub)) {
      sg <- as.character(sub$signoff_grade)
      row$n_signoff_pass <- sum(sg == "PASS", na.rm = TRUE)
      row$n_signoff_warn <- sum(sg == "WARN", na.rm = TRUE)
      row$n_signoff_fail <- sum(sg == "FAIL", na.rm = TRUE)
    } else {
      row$n_signoff_pass <- NA_integer_
      row$n_signoff_warn <- NA_integer_
      row$n_signoff_fail <- NA_integer_
    }
    row
  })
  .qdesn_validation_bind_rows(rows)
}

.qdesn_validation_group_tau_set_pair_summary <- function(tau_method_summary) {
  if (!nrow(tau_method_summary)) return(data.frame(stringsAsFactors = FALSE))
  keys <- c("scenario", "likelihood_family", "beta_prior_type", "seed", "reservoir_profile")
  keys <- keys[keys %in% names(tau_method_summary)]
  vb <- tau_method_summary[tolower(as.character(tau_method_summary$method)) == "vb", , drop = FALSE]
  mc <- tau_method_summary[tolower(as.character(tau_method_summary$method)) == "mcmc", , drop = FALSE]
  if (!nrow(vb) || !nrow(mc)) return(data.frame(stringsAsFactors = FALSE))

  rename_non_keys <- function(df, prefix) {
    nms <- names(df)
    names(df) <- ifelse(nms %in% keys, nms, paste0(prefix, nms))
    df
  }
  vb2 <- rename_non_keys(vb, "vb_")
  mc2 <- rename_non_keys(mc, "mcmc_")
  out <- merge(vb2, mc2, by = keys, all = TRUE, sort = FALSE)
  if (!nrow(out)) return(out)

  vb_complete <- as.character(out$vb_synthesis_status) %in% c("COMPLETE_HEALTHY", "COMPLETE_UNHEALTHY")
  mc_complete <- as.character(out$mcmc_synthesis_status) %in% c("COMPLETE_HEALTHY", "COMPLETE_UNHEALTHY")
  vb_healthy <- as.character(out$vb_synthesis_status) == "COMPLETE_HEALTHY"
  mc_healthy <- as.character(out$mcmc_synthesis_status) == "COMPLETE_HEALTHY"

  out$pair_synthesis_status <- ifelse(
    vb_healthy & mc_healthy,
    "COMPLETE_HEALTHY",
    ifelse(vb_complete & mc_complete, "COMPLETE_UNHEALTHY", "INCOMPLETE")
  )
  out$pair_comparison_eligible <- as.logical(vb_healthy & mc_healthy)
  out$pair_signoff_grade <- ifelse(
    out$pair_synthesis_status == "COMPLETE_HEALTHY", "PASS",
    ifelse(out$pair_synthesis_status == "COMPLETE_UNHEALTHY", "WARN", "FAIL")
  )
  out$both_tau_complete_present <- as.logical(out$vb_tau_complete_present & out$mcmc_tau_complete_present)
  out$both_tau_complete_success <- as.logical(out$vb_tau_complete_success & out$mcmc_tau_complete_success)
  out$both_tau_complete_healthy <- as.logical(out$vb_tau_complete_healthy & out$mcmc_tau_complete_healthy)
  out$runtime_ratio_mcmc_vs_vb <- with(
    out,
    ifelse(is.finite(vb_wall_seconds_sum) & vb_wall_seconds_sum > 0, mcmc_wall_seconds_sum / vb_wall_seconds_sum, NA_real_)
  )
  out$fit_runtime_ratio_mcmc_vs_vb <- with(
    out,
    ifelse(is.finite(vb_fit_runtime_seconds_sum) & vb_fit_runtime_seconds_sum > 0, mcmc_fit_runtime_seconds_sum / vb_fit_runtime_seconds_sum, NA_real_)
  )
  out$forecast_CRPS_delta_mcmc_minus_vb <- out$mcmc_forecast_CRPS_mean_avg - out$vb_forecast_CRPS_mean_avg
  out$forecast_PinballMean_delta_mcmc_minus_vb <- out$mcmc_forecast_PinballMean_mean_avg - out$vb_forecast_PinballMean_mean_avg
  out$forecast_S_delta_mcmc_minus_vb <- out$mcmc_forecast_S_mean_avg - out$vb_forecast_S_mean_avg
  out$forecast_qhat_mae_delta_mcmc_minus_vb <- out$mcmc_forecast_qhat_mae_avg - out$vb_forecast_qhat_mae_avg
  out$forecast_qhat_rmse_delta_mcmc_minus_vb <- out$mcmc_forecast_qhat_rmse_avg - out$vb_forecast_qhat_rmse_avg
  out$forecast_pinball_tau_delta_mcmc_minus_vb <- out$mcmc_forecast_pinball_tau_avg - out$vb_forecast_pinball_tau_avg
  out$signal_qhat_rmse_delta_mcmc_minus_vb <- out$mcmc_signal_qhat_rmse_avg - out$vb_signal_qhat_rmse_avg
  out$signal_qhat_corr_delta_mcmc_minus_vb <- out$mcmc_signal_qhat_corr_avg - out$vb_signal_qhat_corr_avg
  out
}

.qdesn_validation_group_stage_summary <- function(stage_rows) {
  if (!nrow(stage_rows)) return(data.frame(stringsAsFactors = FALSE))
  .qdesn_validation_group_numeric(
    stage_rows,
    group_cols = c("scenario", "tau", "likelihood_family", "beta_prior_type", "reservoir_profile", "method", "tag"),
    numeric_cols = c("seconds")
  )
}

.qdesn_validation_group_chain_summary <- function(chain_rows) {
  if (!nrow(chain_rows)) return(data.frame(stringsAsFactors = FALSE))
  .qdesn_validation_group_numeric(
    chain_rows,
    group_cols = c("scenario", "tau", "likelihood_family", "beta_prior_type", "reservoir_profile", "parameter"),
    numeric_cols = c("mean", "sd", "min", "max", "ess", "acf1", "geweke_absz", "half_drift")
  )
}

.qdesn_validation_campaign_overview_lines <- function(report_root,
                                                      campaign_status,
                                                      root_summary,
                                                      method_group,
                                                      pair_group) {
  n_scenarios <- length(unique(as.character(root_summary$scenario %||% character(0))))
  n_taus <- length(unique(as.numeric(root_summary$tau %||% numeric(0))))
  n_priors <- length(unique(as.character(root_summary$beta_prior_type %||% character(0))))
  n_seeds <- length(unique(as.integer(root_summary$seed %||% integer(0))))

  pair_rollup <- if (nrow(pair_group)) {
    pair_group[, c("scenario", "tau", "likelihood_family", "beta_prior_type", "n_pairs", "both_success_rate",
                   "both_finite_ok_rate", "pair_comparison_eligible_rate",
                   "pair_signoff_pass_rate", "runtime_ratio_mcmc_vs_vb_mean",
                   "forecast_qhat_mae_delta_mcmc_minus_vb_mean",
                   "forecast_pinball_tau_delta_mcmc_minus_vb_mean"),
               drop = FALSE]
  } else {
    data.frame(stringsAsFactors = FALSE)
  }

  method_rollup <- if (nrow(method_group)) {
    method_group[, c("scenario", "tau", "likelihood_family", "beta_prior_type", "method", "n_roots",
                     "success_rate", "comparison_eligible_rate", "signoff_pass_rate",
                     "fit_runtime_seconds_mean"),
                 drop = FALSE]
  } else {
    data.frame(stringsAsFactors = FALSE)
  }

  lines <- c(
    "# Q-DESN MCMC Validation Campaign",
    "",
    sprintf("- Report root: `%s`", report_root),
    sprintf("- Roots: `%d`", as.integer(campaign_status$n_roots[1L] %||% 0L)),
    sprintf("- Successful roots: `%d`", as.integer(campaign_status$n_root_success[1L] %||% 0L)),
    sprintf("- Failed roots: `%d`", as.integer(campaign_status$n_root_fail[1L] %||% 0L)),
    sprintf("- Unique scenarios: `%d`", n_scenarios),
    sprintf("- Unique taus: `%d`", n_taus),
    sprintf("- Unique priors: `%d`", n_priors),
    sprintf("- Unique seeds: `%d`", n_seeds),
    "",
    "## Pair Rollup",
    ""
  )
  lines <- c(lines, .qdesn_validation_df_to_markdown(utils::head(pair_rollup, 20L)))
  lines <- c(lines, "", "## Method Rollup", "")
  lines <- c(lines, .qdesn_validation_df_to_markdown(utils::head(method_rollup, 20L)))
  lines
}

qdesn_validation_collect_campaign <- function(results_root,
                                             report_root,
                                             create_plots = TRUE,
                                             defaults = NULL,
                                             defaults_path = file.path("config", "validation", "qdesn_mcmc_compare_defaults.yaml"),
                                             signoff_cfg = NULL) {
  .qdesn_validation_dir_create(report_root)
  .qdesn_validation_dir_create(file.path(report_root, "tables"))
  .qdesn_validation_dir_create(file.path(report_root, "plots"))
  .qdesn_validation_dir_create(file.path(report_root, "manifest"))

  defaults <- defaults %||% tryCatch(qdesn_validation_load_defaults(defaults_path), error = function(...) NULL)
  signoff_cfg <- signoff_cfg %||% .qdesn_validation_signoff_cfg(defaults)

  roots_dir <- file.path(results_root, "roots")
  root_dirs <- sort(list.dirs(roots_dir, recursive = FALSE, full.names = TRUE))
  root_summary_rows <- list()
  method_rows <- list()
  pair_rows <- list()

  for (root_dir in root_dirs) {
    root_summary_path <- file.path(root_dir, "tables", "root_summary.csv")
    method_path <- file.path(root_dir, "tables", "method_compare_long.csv")
    pair_path <- file.path(root_dir, "tables", "method_compare_summary.csv")
    if (file.exists(root_summary_path)) root_summary_rows[[length(root_summary_rows) + 1L]] <- utils::read.csv(root_summary_path, stringsAsFactors = FALSE)
    if (file.exists(method_path)) method_rows[[length(method_rows) + 1L]] <- utils::read.csv(method_path, stringsAsFactors = FALSE)
    if (file.exists(pair_path)) pair_rows[[length(pair_rows) + 1L]] <- utils::read.csv(pair_path, stringsAsFactors = FALSE)
  }

  root_summary <- .qdesn_validation_bind_rows(root_summary_rows)
  method_summary <- .qdesn_validation_bind_rows(method_rows)
  signoff_rows <- .qdesn_validation_collect_method_signoff_rows(root_dirs, defaults = defaults)
  if (nrow(signoff_rows) && nrow(method_summary)) {
    drop_cols <- intersect(
      names(method_summary),
      setdiff(names(signoff_rows), c("root_id", "scenario", "tau", "likelihood_family", "beta_prior_type", "seed", "reservoir_profile", "method"))
    )
    if (length(drop_cols)) {
      method_summary <- method_summary[, setdiff(names(method_summary), drop_cols), drop = FALSE]
    }
    method_summary <- merge(
      method_summary,
      signoff_rows,
      by = c("root_id", "scenario", "tau", "likelihood_family", "beta_prior_type", "seed", "reservoir_profile", "method"),
      all.x = TRUE,
      sort = FALSE
    )
  }
  pair_summary <- if (nrow(method_summary)) .qdesn_validation_pair_summary(method_summary) else .qdesn_validation_bind_rows(pair_rows)
  if (nrow(method_summary)) {
    root_summary <- .qdesn_validation_bind_rows(lapply(split(method_summary, method_summary$root_id), function(sub) {
      pair_sub <- pair_summary[pair_summary$root_id == as.character(sub$root_id[1L]), , drop = FALSE]
      .qdesn_validation_root_summary(
        root_spec = as.list(sub[1L, c("root_id", "scenario", "tau", "likelihood_family", "beta_prior_type", "seed", "reservoir_profile"), drop = FALSE]),
        method_rows = sub,
        pair_summary = pair_sub
      )
    }))
  }
  stage_rows <- .qdesn_validation_collect_stage_rows(root_dirs)
  chain_rows <- .qdesn_validation_collect_chain_rows(root_dirs)
  method_group <- .qdesn_validation_group_method_summary(method_summary)
  pair_group <- .qdesn_validation_group_pair_summary(pair_summary)
  tau_targets <- .qdesn_validation_resolve_tau_targets(method_summary, defaults = defaults)
  tau_method_group <- .qdesn_validation_group_tau_set_method_summary(method_summary, tau_targets = tau_targets)
  tau_pair_group <- .qdesn_validation_group_tau_set_pair_summary(tau_method_group)
  stage_group <- .qdesn_validation_group_stage_summary(stage_rows)
  chain_group <- .qdesn_validation_group_chain_summary(chain_rows)

  .qdesn_validation_write_df(root_summary, file.path(report_root, "tables", "campaign_root_summary.csv"))
  .qdesn_validation_write_df(method_summary, file.path(report_root, "tables", "campaign_method_summary.csv"))
  .qdesn_validation_write_df(signoff_rows, file.path(report_root, "tables", "campaign_method_signoff.csv"))
  .qdesn_validation_write_df(pair_summary, file.path(report_root, "tables", "campaign_pair_summary.csv"))
  .qdesn_validation_write_df(stage_rows, file.path(report_root, "tables", "campaign_stage_timing_long.csv"))
  .qdesn_validation_write_df(chain_rows, file.path(report_root, "tables", "campaign_chain_summary.csv"))
  .qdesn_validation_write_df(method_group, file.path(report_root, "tables", "campaign_method_group_summary.csv"))
  .qdesn_validation_write_df(pair_group, file.path(report_root, "tables", "campaign_pair_group_summary.csv"))
  .qdesn_validation_write_df(tau_method_group, file.path(report_root, "tables", "campaign_tau_set_method_summary.csv"))
  .qdesn_validation_write_df(tau_pair_group, file.path(report_root, "tables", "campaign_tau_set_pair_summary.csv"))
  .qdesn_validation_write_df(stage_group, file.path(report_root, "tables", "campaign_stage_group_summary.csv"))
  .qdesn_validation_write_df(chain_group, file.path(report_root, "tables", "campaign_chain_group_summary.csv"))

  status_vec <- if (nrow(root_summary) && "root_status" %in% names(root_summary)) as.character(root_summary$root_status) else character(0)
  campaign_status <- data.frame(
    n_roots = nrow(root_summary),
    n_root_success = sum(status_vec == "SUCCESS"),
    n_root_fail = sum(status_vec != "SUCCESS"),
    n_method_rows = nrow(method_summary),
    n_pair_rows = nrow(pair_summary),
    n_stage_rows = nrow(stage_rows),
    n_chain_rows = nrow(chain_rows),
    stringsAsFactors = FALSE
  )
  .qdesn_validation_write_df(campaign_status, file.path(report_root, "tables", "campaign_status.csv"))
  .qdesn_validation_write_json(file.path(report_root, "manifest", "report_manifest.json"), list(
    generated_at = as.character(Sys.time()),
    report_root = report_root,
    results_root = results_root,
    analysis_git_sha = .qdesn_validation_git_sha(),
    defaults_path = defaults_path,
    signoff = signoff_cfg
  ))
  .qdesn_validation_write_lines(
    file.path(report_root, "campaign_summary.md"),
    .qdesn_validation_campaign_overview_lines(
      report_root = report_root,
      campaign_status = campaign_status,
      root_summary = root_summary,
      method_group = method_group,
      pair_group = pair_group
    )
  )

  if (isTRUE(create_plots) && nrow(method_summary)) {
    .qdesn_validation_require_namespace("ggplot2")
    method_summary$case_label <- .qdesn_validation_case_label(
      method_summary$scenario,
      method_summary$tau,
      seed = method_summary$seed,
      reservoir_profile = method_summary$reservoir_profile
    )
    method_summary$tau_label <- .qdesn_validation_tau_label(method_summary$tau)
    runtime_df <- method_summary[is.finite(method_summary$wall_seconds), c("scenario", "tau_label", "beta_prior_type", "method", "case_label", "wall_seconds"), drop = FALSE]
    if (nrow(runtime_df)) {
      p_runtime <- ggplot2::ggplot(runtime_df, ggplot2::aes(x = case_label, y = wall_seconds, fill = method)) +
        ggplot2::geom_col(position = "dodge", width = 0.65) +
        ggplot2::facet_wrap(~ beta_prior_type, scales = "free_x") +
        ggplot2::scale_fill_manual(values = c(vb = "#2563eb", mcmc = "#dc2626")) +
        ggplot2::labs(title = "Campaign Runtime by Case", x = NULL, y = "wall seconds", fill = NULL) +
        ggplot2::theme_minimal(base_size = 11) +
        ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 35, hjust = 1), legend.position = "top")
      ggplot2::ggsave(file.path(report_root, "plots", "campaign_runtime_compare.png"), p_runtime, width = 11, height = 5.5, dpi = 150)
    }

    score_long <- .qdesn_validation_bind_rows(list(
      data.frame(scenario = method_summary$scenario, tau_label = method_summary$tau_label, beta_prior_type = method_summary$beta_prior_type, method = method_summary$method, metric = "forecast_CRPS_mean", value = method_summary$forecast_CRPS_mean, stringsAsFactors = FALSE),
      data.frame(scenario = method_summary$scenario, tau_label = method_summary$tau_label, beta_prior_type = method_summary$beta_prior_type, method = method_summary$method, metric = "forecast_PinballMean_mean", value = method_summary$forecast_PinballMean_mean, stringsAsFactors = FALSE),
      data.frame(scenario = method_summary$scenario, tau_label = method_summary$tau_label, beta_prior_type = method_summary$beta_prior_type, method = method_summary$method, metric = "forecast_S_mean", value = method_summary$forecast_S_mean, stringsAsFactors = FALSE),
      data.frame(scenario = method_summary$scenario, tau_label = method_summary$tau_label, beta_prior_type = method_summary$beta_prior_type, method = method_summary$method, metric = "forecast_qhat_mae", value = method_summary$forecast_qhat_mae, stringsAsFactors = FALSE),
      data.frame(scenario = method_summary$scenario, tau_label = method_summary$tau_label, beta_prior_type = method_summary$beta_prior_type, method = method_summary$method, metric = "forecast_pinball_tau", value = method_summary$forecast_pinball_tau, stringsAsFactors = FALSE)
    ))
    score_long <- score_long[is.finite(score_long$value), , drop = FALSE]
    if (nrow(score_long)) {
      p_score <- ggplot2::ggplot(score_long, ggplot2::aes(x = tau_label, y = value, fill = method)) +
        ggplot2::geom_col(position = "dodge", width = 0.65) +
        ggplot2::facet_grid(metric ~ scenario + beta_prior_type, scales = "free_y") +
        ggplot2::scale_fill_manual(values = c(vb = "#2563eb", mcmc = "#dc2626")) +
        ggplot2::labs(title = "Campaign Forecast Score Comparison", x = "tau", y = "value", fill = NULL) +
        ggplot2::theme_minimal(base_size = 11) +
        ggplot2::theme(legend.position = "top")
      ggplot2::ggsave(file.path(report_root, "plots", "campaign_score_compare.png"), p_score, width = 13, height = 8, dpi = 150)
    }

    health_df <- method_summary[, c("scenario", "tau_label", "beta_prior_type", "method", "status", "finite_ok", "domain_ok", "signoff_grade"), drop = FALSE]
    health_df$health_flag <- ifelse(
      as.character(health_df$status) != "SUCCESS",
      "FAIL",
      ifelse(
        !(as.logical(health_df$finite_ok) & as.logical(health_df$domain_ok)),
        "FAIL",
        ifelse(is.na(health_df$signoff_grade) | !nzchar(as.character(health_df$signoff_grade)), "FAIL", as.character(health_df$signoff_grade))
      )
    )
    health_df$row_label <- paste(health_df$scenario, health_df$likelihood_family, health_df$beta_prior_type, sep = " | ")
    if (nrow(health_df)) {
      p_health <- ggplot2::ggplot(health_df, ggplot2::aes(x = tau_label, y = row_label, fill = health_flag)) +
        ggplot2::geom_tile(colour = "white", linewidth = 0.4) +
        ggplot2::facet_wrap(~ method) +
        ggplot2::scale_fill_manual(values = c(PASS = "#059669", WARN = "#d97706", FAIL = "#dc2626")) +
        ggplot2::labs(title = "Campaign Inference Signoff Matrix", x = "tau", y = NULL, fill = NULL) +
        ggplot2::theme_minimal(base_size = 11) +
        ggplot2::theme(legend.position = "top")
      ggplot2::ggsave(file.path(report_root, "plots", "campaign_health_matrix.png"), p_health, width = 10, height = 5.5, dpi = 150)
    }

    if (nrow(pair_summary)) {
      pair_summary$case_label <- .qdesn_validation_case_label(
        pair_summary$scenario,
        pair_summary$tau,
        seed = pair_summary$seed,
        reservoir_profile = pair_summary$reservoir_profile
      )
      pair_summary$tau_label <- .qdesn_validation_tau_label(pair_summary$tau)
      pair_summary$row_label <- paste(pair_summary$scenario, pair_summary$likelihood_family, pair_summary$beta_prior_type, sep = " | ")
      if ("pair_signoff_grade" %in% names(pair_summary)) {
        pair_heat <- pair_summary[, c("tau_label", "row_label", "pair_signoff_grade"), drop = FALSE]
        pair_heat <- pair_heat[!is.na(pair_heat$pair_signoff_grade) & nzchar(pair_heat$pair_signoff_grade), , drop = FALSE]
        if (nrow(pair_heat)) {
          p_pair_health <- ggplot2::ggplot(pair_heat, ggplot2::aes(x = tau_label, y = row_label, fill = pair_signoff_grade)) +
            ggplot2::geom_tile(colour = "white", linewidth = 0.4) +
            ggplot2::scale_fill_manual(values = c(PASS = "#059669", WARN = "#d97706", FAIL = "#dc2626")) +
            ggplot2::labs(title = "Pair Comparison Signoff Matrix", x = "tau", y = NULL, fill = NULL) +
            ggplot2::theme_minimal(base_size = 11) +
            ggplot2::theme(legend.position = "top")
          ggplot2::ggsave(file.path(report_root, "plots", "campaign_pair_signoff_matrix.png"), p_pair_health, width = 10, height = 5.5, dpi = 150)
        }
      }
    }

    if (nrow(pair_summary) && "runtime_ratio_mcmc_vs_vb" %in% names(pair_summary)) {
      ratio_df <- pair_summary[is.finite(pair_summary$runtime_ratio_mcmc_vs_vb), c("scenario", "tau_label", "beta_prior_type", "runtime_ratio_mcmc_vs_vb"), drop = FALSE]
      if (nrow(ratio_df)) {
        p_ratio <- ggplot2::ggplot(ratio_df, ggplot2::aes(x = tau_label, y = runtime_ratio_mcmc_vs_vb, fill = beta_prior_type)) +
          ggplot2::geom_col(position = "dodge", width = 0.65) +
          ggplot2::facet_wrap(~ scenario, scales = "free_x") +
          ggplot2::labs(title = "MCMC / VB Runtime Ratio", x = "tau", y = "ratio", fill = "prior") +
          ggplot2::theme_minimal(base_size = 11) +
          ggplot2::theme(legend.position = "top")
        ggplot2::ggsave(file.path(report_root, "plots", "campaign_runtime_ratio.png"), p_ratio, width = 10.5, height = 5, dpi = 150)
      }
    }

    if (nrow(pair_summary)) {
      delta_long <- .qdesn_validation_bind_rows(list(
        data.frame(scenario = pair_summary$scenario, tau_label = pair_summary$tau_label, beta_prior_type = pair_summary$beta_prior_type, metric = "forecast_qhat_mae_delta_mcmc_minus_vb", value = pair_summary$forecast_qhat_mae_delta_mcmc_minus_vb, stringsAsFactors = FALSE),
        data.frame(scenario = pair_summary$scenario, tau_label = pair_summary$tau_label, beta_prior_type = pair_summary$beta_prior_type, metric = "forecast_pinball_tau_delta_mcmc_minus_vb", value = pair_summary$forecast_pinball_tau_delta_mcmc_minus_vb, stringsAsFactors = FALSE),
        data.frame(scenario = pair_summary$scenario, tau_label = pair_summary$tau_label, beta_prior_type = pair_summary$beta_prior_type, metric = "forecast_CRPS_delta_mcmc_minus_vb", value = pair_summary$forecast_CRPS_delta_mcmc_minus_vb, stringsAsFactors = FALSE),
        data.frame(scenario = pair_summary$scenario, tau_label = pair_summary$tau_label, beta_prior_type = pair_summary$beta_prior_type, metric = "forecast_S_delta_mcmc_minus_vb", value = pair_summary$forecast_S_delta_mcmc_minus_vb, stringsAsFactors = FALSE)
      ))
      delta_long <- delta_long[is.finite(delta_long$value), , drop = FALSE]
      if (nrow(delta_long)) {
        p_delta <- ggplot2::ggplot(delta_long, ggplot2::aes(x = tau_label, y = value, colour = beta_prior_type, group = beta_prior_type)) +
          ggplot2::geom_hline(yintercept = 0, linetype = 2, linewidth = 0.5, colour = "#6b7280") +
          ggplot2::geom_point(size = 2) +
          ggplot2::facet_grid(metric ~ scenario, scales = "free_y") +
          ggplot2::labs(title = "MCMC - VB Score Deltas", x = "tau", y = "delta", colour = "prior") +
          ggplot2::theme_minimal(base_size = 11) +
          ggplot2::theme(legend.position = "top")
        line_groups <- interaction(delta_long$scenario, delta_long$metric, delta_long$beta_prior_type, drop = TRUE)
        if (any(table(line_groups) > 1L)) {
          p_delta <- p_delta + ggplot2::geom_line(linewidth = 0.8)
        }
        ggplot2::ggsave(file.path(report_root, "plots", "campaign_score_delta.png"), p_delta, width = 12.5, height = 8.5, dpi = 150)
      }
    }
  }

  if (isTRUE(create_plots) && nrow(chain_group)) {
    .qdesn_validation_require_namespace("ggplot2")
    chain_group$tau_label <- .qdesn_validation_tau_label(chain_group$tau)
    ess_df <- chain_group[is.finite(chain_group$ess_mean), c("scenario", "tau_label", "beta_prior_type", "parameter", "ess_mean"), drop = FALSE]
    if (nrow(ess_df)) {
      p_ess <- ggplot2::ggplot(ess_df, ggplot2::aes(x = tau_label, y = ess_mean, fill = beta_prior_type)) +
        ggplot2::geom_col(position = "dodge", width = 0.65) +
        ggplot2::facet_grid(parameter ~ scenario, scales = "free_y") +
        ggplot2::labs(title = "MCMC ESS by Scenario and Tau", x = "tau", y = "ESS", fill = "prior") +
        ggplot2::theme_minimal(base_size = 11) +
        ggplot2::theme(legend.position = "top")
      ggplot2::ggsave(file.path(report_root, "plots", "campaign_chain_ess.png"), p_ess, width = 12, height = 8, dpi = 150)
    }
  }

  if (isTRUE(create_plots) && nrow(stage_group)) {
    .qdesn_validation_require_namespace("ggplot2")
    stage_df <- stage_group[is.finite(stage_group$seconds_mean), c("scenario", "likelihood_family", "beta_prior_type", "method", "tag", "seconds_mean"), drop = FALSE]
    if (nrow(stage_df)) {
      p_stage <- ggplot2::ggplot(stage_df, ggplot2::aes(x = tag, y = seconds_mean, fill = method)) +
        ggplot2::geom_col(position = "dodge", width = 0.7) +
        ggplot2::facet_grid(scenario ~ beta_prior_type, scales = "free_x") +
        ggplot2::scale_fill_manual(values = c(vb = "#2563eb", mcmc = "#dc2626")) +
        ggplot2::labs(title = "Average Stage Runtime Profile", x = NULL, y = "mean seconds", fill = NULL) +
        ggplot2::theme_minimal(base_size = 11) +
        ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 35, hjust = 1), legend.position = "top")
      ggplot2::ggsave(file.path(report_root, "plots", "campaign_stage_profile.png"), p_stage, width = 12.5, height = 8.5, dpi = 150)
    }
  }

  invisible(list(
    root_summary = root_summary,
    method_summary = method_summary,
    method_signoff = signoff_rows,
    pair_summary = pair_summary,
    stage_rows = stage_rows,
    chain_rows = chain_rows,
    method_group = method_group,
    pair_group = pair_group,
    tau_method_group = tau_method_group,
    tau_pair_group = tau_pair_group,
    stage_group = stage_group,
    chain_group = chain_group,
    report_root = report_root
  ))
}

qdesn_validation_run_campaign <- function(grid = NULL,
                                          defaults = NULL,
                                          grid_path = file.path("config", "validation", "qdesn_mcmc_pilot_grid.csv"),
                                          defaults_path = file.path("config", "validation", "qdesn_mcmc_pilot_defaults.yaml"),
                                          results_root = NULL,
                                          report_root = NULL,
                                          create_plots = TRUE,
                                          root_filter = NULL,
                                          verbose = TRUE,
                                          workers = NULL) {
  defaults <- defaults %||% qdesn_validation_load_defaults(defaults_path)
  grid <- grid %||% qdesn_validation_load_grid(grid_path)

  campaign_cfg <- defaults$campaign %||% list()
  runtime_cfg <- defaults$runtime %||% list()
  workers <- as.integer(workers %||% runtime_cfg$campaign_workers %||% runtime_cfg$workers %||% 1L)[1L]
  if (!is.finite(workers) || is.na(workers) || workers < 1L) workers <- 1L
  results_root <- results_root %||% .qdesn_validation_resolve_path(
    campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "pilot"),
    must_work = FALSE
  )
  report_root <- report_root %||% .qdesn_validation_resolve_path(
    campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "pilot"),
    must_work = FALSE
  )
  timestamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  run_stub <- sprintf("%s__git-%s", timestamp, .qdesn_validation_git_sha() %||% "unknown")
  results_run_root <- file.path(results_root, run_stub)
  report_run_root <- file.path(report_root, run_stub)

  for (d in c(results_run_root, file.path(results_run_root, "roots"), report_run_root, file.path(report_run_root, "tables"), file.path(report_run_root, "plots"), file.path(report_run_root, "manifest"))) {
    .qdesn_validation_dir_create(d)
  }
  .qdesn_validation_write_json(file.path(report_run_root, "manifest", "campaign_manifest.json"), list(
    campaign_name = campaign_cfg$name %||% "qdesn_mcmc_validation_pilot",
    started_at = as.character(Sys.time()),
    results_root = results_run_root,
    report_root = report_run_root,
    grid_path = grid_path,
    defaults_path = defaults_path,
    git_sha = .qdesn_validation_git_sha()
  ))

  root_filter <- as.character(root_filter %||% character(0))
  root_targets <- list()
  for (i in seq_len(nrow(grid))) {
    root_spec <- qdesn_validation_enrich_root_spec(as.list(grid[i, , drop = FALSE]), defaults)
    if (!isTRUE(root_spec$enabled)) next
    if (length(root_filter) && !(root_spec$root_id %in% root_filter)) next
    root_targets[[length(root_targets) + 1L]] <- list(
      root_spec = root_spec,
      grid_index = i
    )
  }

  run_status_rows <- list()
  run_one <- function(target, seq_id, n_total) {
    root_spec <- target$root_spec
    if (isTRUE(verbose)) {
      message(sprintf("[qdesn_validation_run_campaign] root %d/%d | %s", seq_id, n_total, root_spec$root_id))
    }
    res <- tryCatch(
      qdesn_validation_run_root(
        root_spec = root_spec,
        defaults = defaults,
        output_root = file.path(results_run_root, "roots"),
        create_plots = create_plots,
        verbose = verbose
      ),
      error = function(e) {
        data.frame(
          root_id = root_spec$root_id,
          scenario = root_spec$scenario,
          tau = as.numeric(root_spec$tau),
          likelihood_family = as.character(root_spec$likelihood_family %||% "exal")[1L],
          beta_prior_type = root_spec$beta_prior_type,
          seed = as.integer(root_spec$seed),
          reservoir_profile = root_spec$reservoir_profile,
          root_status = "FAIL",
          error_message = conditionMessage(e),
          stringsAsFactors = FALSE
        )
      }
    )
    if (is.data.frame(res)) {
      return(res)
    }
    tmp <- res$root_summary
    tmp$error_message <- ""
    tmp
  }

  n_targets <- length(root_targets)
  if (!n_targets) {
    if (isTRUE(verbose)) message("[qdesn_validation_run_campaign] no enabled roots after filtering.")
  } else if (workers > 1L && .Platform$OS.type == "unix" && n_targets > 1L) {
    if (isTRUE(verbose)) {
      message(sprintf("[qdesn_validation_run_campaign] running in parallel | workers=%d | roots=%d", workers, n_targets))
    }
    run_status_rows <- parallel::mclapply(
      X = seq_len(n_targets),
      FUN = function(jj) run_one(root_targets[[jj]], jj, n_targets),
      mc.cores = workers,
      mc.preschedule = TRUE
    )
    .qdesn_validation_write_df(.qdesn_validation_bind_rows(run_status_rows), file.path(report_run_root, "tables", "campaign_progress.csv"))
  } else {
    if (isTRUE(workers > 1L) && .Platform$OS.type != "unix" && isTRUE(verbose)) {
      message("[qdesn_validation_run_campaign] workers>1 requested but OS is non-unix; falling back to serial.")
    }
    for (jj in seq_len(n_targets)) {
      row <- run_one(root_targets[[jj]], jj, n_targets)
      run_status_rows[[length(run_status_rows) + 1L]] <- row
      .qdesn_validation_write_df(.qdesn_validation_bind_rows(run_status_rows), file.path(report_run_root, "tables", "campaign_progress.csv"))
      qdesn_validation_collect_campaign(
        results_root = results_run_root,
        report_root = report_run_root,
        create_plots = create_plots,
        defaults = defaults,
        defaults_path = defaults_path
      )
    }
  }

  final <- qdesn_validation_collect_campaign(
    results_root = results_run_root,
    report_root = report_run_root,
    create_plots = create_plots,
    defaults = defaults,
    defaults_path = defaults_path
  )
  .qdesn_validation_write_json(file.path(report_run_root, "manifest", "campaign_completed.json"), list(
    finished_at = as.character(Sys.time()),
    results_root = results_run_root,
    report_root = report_run_root,
    n_roots = nrow(final$root_summary),
    n_methods = nrow(final$method_summary)
  ))
  invisible(list(
    results_root = results_run_root,
    report_root = report_run_root,
    summary = final
  ))
}

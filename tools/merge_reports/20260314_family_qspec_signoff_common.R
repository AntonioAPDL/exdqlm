`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

fqsg_require_namespace <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Required package not installed: ", pkg, call. = FALSE)
  }
}

fqsg_bind_rows <- function(rows) {
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) return(data.frame(stringsAsFactors = FALSE))
  cols <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows2 <- lapply(rows, function(df) {
    miss <- setdiff(cols, names(df))
    if (length(miss)) {
      for (nm in miss) df[[nm]] <- NA
    }
    df[, cols, drop = FALSE]
  })
  do.call(rbind, rows2)
}

fqsg_join_reasons <- function(x) {
  x <- unique(as.character(x))
  x <- x[!is.na(x) & nzchar(x)]
  if (!length(x)) return("")
  paste(x, collapse = "; ")
}

fqsg_safe_num <- function(x) {
  out <- suppressWarnings(as.numeric(x))
  if (!length(out)) return(NA_real_)
  out[[1L]]
}

fqsg_env_num <- function(name, default) {
  raw <- Sys.getenv(name, "")
  if (!nzchar(raw)) return(default)
  val <- suppressWarnings(as.numeric(raw)[1L])
  if (!is.finite(val) || is.na(val)) return(default)
  val
}

fqsg_env_int <- function(name, default) {
  raw <- Sys.getenv(name, "")
  if (!nzchar(raw)) return(default)
  val <- suppressWarnings(as.integer(raw)[1L])
  if (!is.finite(val) || is.na(val)) return(default)
  val
}

fqsg_strip_attrs <- function(x) {
  y <- unclass(x)
  attributes(y) <- attributes(y)[setdiff(names(attributes(y)), "class")]
  y
}

fqsg_as_numeric_matrix <- function(x) {
  if (is.null(x)) return(matrix(numeric(0), nrow = 0L))
  y <- fqsg_strip_attrs(x)
  if (is.data.frame(y)) return(as.matrix(y))
  if (is.matrix(y)) return(matrix(as.numeric(y), nrow = nrow(y), ncol = ncol(y), dimnames = dimnames(y)))
  if (is.array(y)) {
    dims <- dim(y)
    if (length(dims) == 1L) return(matrix(as.numeric(y), ncol = 1L))
    if (length(dims) == 2L) return(matrix(as.numeric(y), nrow = dims[[1L]], ncol = dims[[2L]], dimnames = dimnames(y)))
    return(matrix(as.numeric(y), nrow = prod(dims[-length(dims)]), ncol = dims[[length(dims)]]))
  }
  matrix(as.numeric(y), ncol = 1L)
}

fqsg_iteration_norm <- function(x) {
  if (is.null(x)) return(numeric(0))
  y <- fqsg_strip_attrs(x)
  dims <- dim(y)
  vals <- as.numeric(y)
  vals <- vals[is.finite(vals) | is.na(vals)]
  if (is.null(dims)) return(abs(as.numeric(y)))
  arr <- array(as.numeric(y), dim = dims)
  if (length(dims) == 1L) return(abs(as.numeric(arr)))
  if (length(dims) == 2L) return(sqrt(rowSums(arr^2)))
  draw_dim <- dims[[length(dims)]]
  collapsed <- matrix(as.numeric(arr)^2, nrow = prod(dims[-length(dims)]), ncol = draw_dim)
  sqrt(colSums(collapsed, na.rm = TRUE))
}

fqsg_safe_acf1 <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (length(x) < 3L) return(NA_real_)
  out <- tryCatch(stats::acf(x, plot = FALSE, lag.max = 1L)$acf[2L], error = function(...) NA_real_)
  as.numeric(out)
}

fqsg_safe_ess <- function(x) {
  fqsg_require_namespace("coda")
  x <- as.numeric(unclass(x))
  attributes(x) <- NULL
  x <- x[is.finite(x)]
  if (length(x) < 3L) return(NA_real_)
  out <- tryCatch(coda::effectiveSize(coda::mcmc(matrix(x, ncol = 1L))), error = function(...) NA_real_)
  as.numeric(out)[1L]
}

fqsg_safe_geweke_absz <- function(x) {
  fqsg_require_namespace("coda")
  x <- as.numeric(unclass(x))
  attributes(x) <- NULL
  x <- x[is.finite(x)]
  if (length(x) < 10L) return(NA_real_)
  out <- tryCatch(coda::geweke.diag(coda::mcmc(matrix(x, ncol = 1L)))$z, error = function(...) NA_real_)
  abs(as.numeric(out)[1L])
}

fqsg_halfchain_drift <- function(x) {
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

fqsg_trace_tail_metrics <- function(x, tail_window = 5L, scale_floor = 1e-8, unit_floor = FALSE) {
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

fqsg_signoff_cfg <- function() {
  list(
    vb = list(
      tail_window = fqsg_env_int("EXDQLM_FQSG_VB_TAIL_WINDOW", 5L),
      min_trace_length = fqsg_env_int("EXDQLM_FQSG_VB_MIN_TRACE_LENGTH", 5L),
      elbo_rel_range_pass = fqsg_env_num("EXDQLM_FQSG_VB_ELBO_REL_RANGE_PASS", 0.01),
      elbo_rel_range_warn = fqsg_env_num("EXDQLM_FQSG_VB_ELBO_REL_RANGE_WARN", 0.05),
      core_rel_range_pass = fqsg_env_num("EXDQLM_FQSG_VB_CORE_REL_RANGE_PASS", 0.02),
      core_rel_range_warn = fqsg_env_num("EXDQLM_FQSG_VB_CORE_REL_RANGE_WARN", 0.10),
      rhs_rel_range_pass = fqsg_env_num("EXDQLM_FQSG_VB_RHS_REL_RANGE_PASS", 0.05),
      rhs_rel_range_warn = fqsg_env_num("EXDQLM_FQSG_VB_RHS_REL_RANGE_WARN", 0.20),
      delta_state_pass = fqsg_env_num("EXDQLM_FQSG_VB_DELTA_STATE_PASS", 0.02),
      delta_state_warn = fqsg_env_num("EXDQLM_FQSG_VB_DELTA_STATE_WARN", 0.10),
      delta_sigma_pass = fqsg_env_num("EXDQLM_FQSG_VB_DELTA_SIGMA_PASS", 0.02),
      delta_sigma_warn = fqsg_env_num("EXDQLM_FQSG_VB_DELTA_SIGMA_WARN", 0.10),
      delta_gamma_pass = fqsg_env_num("EXDQLM_FQSG_VB_DELTA_GAMMA_PASS", 0.02),
      delta_gamma_warn = fqsg_env_num("EXDQLM_FQSG_VB_DELTA_GAMMA_WARN", 0.10),
      delta_s_pass = fqsg_env_num("EXDQLM_FQSG_VB_DELTA_S_PASS", 0.02),
      delta_s_warn = fqsg_env_num("EXDQLM_FQSG_VB_DELTA_S_WARN", 0.10),
      require_converged_for_pass = TRUE
    ),
    mcmc = list(
      min_keep_pass = fqsg_env_int("EXDQLM_FQSG_MCMC_MIN_KEEP_PASS", 160L),
      min_keep_warn = fqsg_env_int("EXDQLM_FQSG_MCMC_MIN_KEEP_WARN", 100L),
      ess_sigma_pass = fqsg_env_num("EXDQLM_FQSG_MCMC_ESS_SIGMA_PASS", 30),
      ess_sigma_warn = fqsg_env_num("EXDQLM_FQSG_MCMC_ESS_SIGMA_WARN", 10),
      ess_gamma_pass = fqsg_env_num("EXDQLM_FQSG_MCMC_ESS_GAMMA_PASS", 20),
      ess_gamma_warn = fqsg_env_num("EXDQLM_FQSG_MCMC_ESS_GAMMA_WARN", 10),
      ess_state_pass = fqsg_env_num("EXDQLM_FQSG_MCMC_ESS_STATE_PASS", 30),
      ess_state_warn = fqsg_env_num("EXDQLM_FQSG_MCMC_ESS_STATE_WARN", 10),
      acf1_pass = fqsg_env_num("EXDQLM_FQSG_MCMC_ACF1_PASS", 0.90),
      acf1_warn = fqsg_env_num("EXDQLM_FQSG_MCMC_ACF1_WARN", 0.98),
      geweke_absz_pass = fqsg_env_num("EXDQLM_FQSG_MCMC_GEWEKE_ABSZ_PASS", 2.0),
      geweke_absz_warn = fqsg_env_num("EXDQLM_FQSG_MCMC_GEWEKE_ABSZ_WARN", 3.0),
      half_drift_pass = fqsg_env_num("EXDQLM_FQSG_MCMC_HALF_DRIFT_PASS", 0.25),
      half_drift_warn = fqsg_env_num("EXDQLM_FQSG_MCMC_HALF_DRIFT_WARN", 0.50),
      require_signoff_ready_for_extended = TRUE
    )
  )
}

fqsg_pair_grade <- function(a, b) {
  a <- as.character(a %||% NA_character_)
  b <- as.character(b %||% NA_character_)
  if (identical(a, "PASS") && identical(b, "PASS")) return("PASS")
  if (!is.na(a) && !is.na(b) && a != "FAIL" && b != "FAIL") return("WARN")
  "FAIL"
}

fqsg_make_execution_flags <- function(status_ok, finite_ok, domain_ok) {
  list(
    status = if (isTRUE(status_ok)) "SUCCESS" else "FAIL",
    execution_healthy = isTRUE(status_ok) && isTRUE(finite_ok) && isTRUE(domain_ok)
  )
}

fqsg_method_meta <- function(root_row, inference, model) {
  data.frame(
    root_id = root_row$root_id,
    root_kind = root_row$root_kind,
    family = root_row$family,
    tau = fqsg_safe_num(root_row$tau),
    fit_size = as.integer(root_row$fit_size),
    prior = as.character(root_row$prior),
    inference = as.character(inference),
    model = as.character(model),
    stringsAsFactors = FALSE
  )
}

fqsg_resolve_root_row <- function(run_root, repo_root) {
  catalog <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_root_catalog.tsv"))
  rel_run_root <- sub(
    paste0("^", normalizePath(repo_root, winslash = "/", mustWork = TRUE), "/"),
    "",
    normalizePath(run_root, winslash = "/", mustWork = TRUE)
  )
  idx <- match(rel_run_root, catalog$run_root)
  if (is.na(idx)) stop("Run root not found in root catalog: ", rel_run_root, call. = FALSE)
  catalog[idx, , drop = FALSE]
}

fqsg_root_file <- function(run_root, name) {
  file.path(run_root, "tables", name)
}

fqsg_required_signoff_files <- function(run_root) {
  c(
    fqsg_root_file(run_root, "method_signoff_long.csv"),
    fqsg_root_file(run_root, "algorithm_pair_signoff.csv"),
    fqsg_root_file(run_root, "model_pair_signoff.csv"),
    fqsg_root_file(run_root, "root_signoff_summary.csv"),
    fqsg_root_file(run_root, "repair_targets.csv")
  )
}

fqsg_safe_read_fit_object <- function(path) {
  if (is.na(path) || !nzchar(path) || !file.exists(path)) {
    return(list(ok = FALSE, obj = NULL, error = "fit_file_missing"))
  }
  out <- tryCatch(readRDS(path), error = function(e) e)
  if (inherits(out, "error")) {
    return(list(ok = FALSE, obj = NULL, error = conditionMessage(out)))
  }
  list(ok = TRUE, obj = out, error = NA_character_)
}

fqsg_vec_finite_positive <- function(x) {
  x <- as.numeric(x)
  length(x) > 0L && all(is.finite(x)) && all(x > 0)
}

fqsg_vec_finite <- function(x) {
  x <- as.numeric(x)
  length(x) > 0L && all(is.finite(x))
}

fqsg_static_vb_diagnostics <- function(vb_obj, fit_row, ld_row = NULL, rhs_row = NULL) {
  fit <- vb_obj$fit
  norm <- vb_obj$normalized %||% .static_normalize_vb_fit(fit, model_name = fit_row$model, tau = fit_row$tau)
  conv <- norm$diagnostics$convergence %||% list()
  ld_block <- norm$diagnostics$ld_block %||% list()
  ld_trace <- ld_block$trace %||% data.frame()
  rhs_summary <- norm$diagnostics$rhs$summary %||% fit$beta_prior$summary %||% list()
  deltas <- fit$diagnostics$deltas %||% list()
  elbo_trace <- norm$diagnostics$elbo$trace %||% numeric(0)

  sigma_trace <- if (is.data.frame(ld_trace) && "sigma" %in% names(ld_trace)) ld_trace$sigma else numeric(0)
  gamma_trace <- if (is.data.frame(ld_trace) && "gamma" %in% names(ld_trace)) ld_trace$gamma else numeric(0)
  s_trace <- if (is.data.frame(ld_trace) && "s_mean" %in% names(ld_trace)) ld_trace$s_mean else numeric(0)
  sigma_est <- fqsg_safe_num(norm$sigma_est %||% fit$qsig$E_sigma %||% fit$qsiggam$sigma_mean)
  gamma_est <- fqsg_safe_num(norm$gamma_est %||% fit$qsiggam$gamma_mean)
  beta_vec <- as.numeric(fit$qbeta$m %||% numeric(0))
  v_vec <- as.numeric(fit$qv$E_v %||% numeric(0))
  s_vec <- as.numeric(fit$qs$E_s %||% numeric(0))

  list(
    fit = fit,
    norm = norm,
    state_vector = beta_vec,
    sigma_est = sigma_est,
    gamma_est = gamma_est,
    positive_aux_ok = if (length(v_vec)) fqsg_vec_finite_positive(v_vec) else TRUE,
    finite_aux_ok = if (length(s_vec)) fqsg_vec_finite(s_vec) else TRUE,
    converged = isTRUE(conv$converged),
    stop_reason = as.character(conv$stop_reason %||% fit_row$stop_reason %||% NA_character_)[1L],
    trace_length = max(length(elbo_trace), nrow(ld_trace), length(as.numeric(deltas$state %||% numeric(0))), na.rm = TRUE),
    elbo_tail = fqsg_trace_tail_metrics(elbo_trace, tail_window = 5L, unit_floor = TRUE),
    sigma_tail = fqsg_trace_tail_metrics(sigma_trace, tail_window = 5L),
    gamma_tail = fqsg_trace_tail_metrics(gamma_trace, tail_window = 5L),
    s_tail = fqsg_trace_tail_metrics(s_trace, tail_window = 5L),
    delta_state_last = fqsg_safe_num(fit_row$delta_state_last %||% utils::tail(as.numeric(deltas$state %||% numeric(0)), 1L)),
    delta_sigma_last = fqsg_safe_num(fit_row$delta_sigma_last %||% utils::tail(as.numeric(deltas$sigma %||% numeric(0)), 1L)),
    delta_gamma_last = fqsg_safe_num(fit_row$delta_gamma_last %||% utils::tail(as.numeric(deltas$gamma %||% numeric(0)), 1L)),
    delta_s_last = fqsg_safe_num(fit_row$delta_s_last %||% utils::tail(as.numeric(deltas$s %||% numeric(0)), 1L)),
    ld_trace_rows = nrow(ld_trace),
    ld_local_mode_pass = isTRUE(ld_row$ld_local_mode_pass[[1]] %||% ld_block$mode_quality$local_mode_pass),
    ld_committed_stable_tail = isTRUE(ld_row$ld_committed_stable_tail[[1]] %||% ld_block$signoff_summary$committed_stable),
    ld_candidate_local_pass_rate_tail = fqsg_safe_num(ld_row$ld_candidate_local_pass_rate_tail[[1]] %||% ld_block$signoff_summary$candidate_local_pass_rate),
    ld_committed_local_pass_rate_tail = fqsg_safe_num(ld_row$ld_committed_local_pass_rate_tail[[1]] %||% ld_block$signoff_summary$committed_local_pass_rate),
    ld_mode_fallback_rate = fqsg_safe_num(ld_row$ld_mode_fallback_rate[[1]] %||% ld_block$signoff_summary$fallback_rate),
    ld_stabilized_rate_tail = fqsg_safe_num(ld_row$ld_stabilized_rate_tail[[1]] %||% ld_block$signoff_summary$stabilized_rate),
    rhs_collapse_flag = isTRUE(rhs_row$rhs_collapse_flag[[1]] %||% rhs_summary$collapse_flag),
    rhs_tau_near_zero = isTRUE(rhs_row$rhs_tau_near_zero[[1]] %||% rhs_summary$collapse_tau_near_zero),
    rhs_beta_collapse = isTRUE(rhs_row$rhs_beta_collapse[[1]] %||% rhs_summary$collapse_beta),
    rhs_tau = fqsg_safe_num(rhs_row$rhs_tau[[1]] %||% rhs_summary$tau),
    rhs_c2 = fqsg_safe_num(rhs_row$rhs_c2[[1]] %||% rhs_summary$c2),
    rhs_lambda_mean = fqsg_safe_num(rhs_row$rhs_lambda_mean[[1]] %||% rhs_summary$lambda_mean)
  )
}

fqsg_dynamic_vb_diagnostics <- function(vb_obj, fit_row, ld_row = NULL) {
  fit <- vb_obj$fit
  ld_block <- fit$gammasig.out$ld %||% fit$diagnostics$ld_block %||% list()
  ld_trace <- ld_block$trace %||% data.frame()
  deltas <- fit$diagnostics$deltas %||% list()
  elbo_trace <- as.numeric(fit$diagnostics$elbo %||% numeric(0))
  sigma_trace <- as.numeric(fit$seq.sigma %||% if (is.data.frame(ld_trace) && "sigma" %in% names(ld_trace)) ld_trace$sigma else numeric(0))
  gamma_trace <- as.numeric(fit$seq.gamma %||% if (is.data.frame(ld_trace) && "gamma" %in% names(ld_trace)) ld_trace$gamma else numeric(0))
  s_trace <- if (is.data.frame(ld_trace) && "s_mean" %in% names(ld_trace)) ld_trace$s_mean else numeric(0)
  conv <- fit$diagnostics$convergence %||% list()
  state_vec <- as.numeric((fit$theta.out %||% list())$sm %||% numeric(0))
  sigma_est <- fqsg_safe_num((fit$sig.out %||% list())$E.sigma %||% (fit$gammasig.out %||% list())$E.sigma %||% fit_row$sigma_mean)
  gamma_est <- fqsg_safe_num((fit$gammasig.out %||% list())$E.gam %||% fit_row$gamma_mean)
  candidate_local <- (ld_block$candidate_mode_quality %||% list())$local_mode_pass
  committed_local <- (ld_block$committed_mode_quality %||% list())$local_mode_pass
  list(
    fit = fit,
    state_vector = state_vec,
    sigma_est = sigma_est,
    gamma_est = gamma_est,
    positive_aux_ok = TRUE,
    finite_aux_ok = TRUE,
    converged = isTRUE(fit$converged) || isTRUE(conv$converged),
    stop_reason = as.character(conv$stop_reason %||% fit_row$stop_reason %||% NA_character_)[1L],
    trace_length = max(length(elbo_trace), nrow(ld_trace), length(as.numeric(deltas$state %||% numeric(0))), na.rm = TRUE),
    elbo_tail = fqsg_trace_tail_metrics(elbo_trace, tail_window = 5L, unit_floor = TRUE),
    sigma_tail = fqsg_trace_tail_metrics(sigma_trace, tail_window = 5L),
    gamma_tail = fqsg_trace_tail_metrics(gamma_trace, tail_window = 5L),
    s_tail = fqsg_trace_tail_metrics(s_trace, tail_window = 5L),
    delta_state_last = fqsg_safe_num(fit_row$delta_state_last %||% utils::tail(as.numeric(deltas$state %||% numeric(0)), 1L)),
    delta_sigma_last = fqsg_safe_num(fit_row$delta_sigma_last %||% utils::tail(as.numeric(deltas$sigma %||% numeric(0)), 1L)),
    delta_gamma_last = fqsg_safe_num(fit_row$delta_gamma_last %||% utils::tail(as.numeric(deltas$gamma %||% numeric(0)), 1L)),
    delta_s_last = fqsg_safe_num(fit_row$delta_s_last %||% utils::tail(as.numeric(deltas$s %||% numeric(0)), 1L)),
    ld_trace_rows = nrow(ld_trace),
    ld_local_mode_pass = isTRUE(ld_row$ld_local_mode_pass[[1]] %||% ld_block$mode_quality$local_mode_pass %||% candidate_local),
    ld_committed_stable_tail = isTRUE(ld_row$ld_committed_stable_tail[[1]] %||% ld_block$signoff_summary$committed_stable %||% ld_block$stabilized),
    ld_candidate_local_pass_rate_tail = fqsg_safe_num(ld_row$ld_candidate_local_pass_rate_tail[[1]] %||% if (!is.null(candidate_local)) as.numeric(isTRUE(candidate_local)) else NA_real_),
    ld_committed_local_pass_rate_tail = fqsg_safe_num(ld_row$ld_committed_local_pass_rate_tail[[1]] %||% if (!is.null(committed_local)) as.numeric(isTRUE(committed_local)) else NA_real_),
    ld_mode_fallback_rate = fqsg_safe_num(ld_row$ld_mode_fallback_rate[[1]] %||% if (!is.null(ld_block$used_fallback)) as.numeric(isTRUE(ld_block$used_fallback)) else NA_real_),
    ld_stabilized_rate_tail = fqsg_safe_num(ld_row$ld_stabilized_rate_tail[[1]] %||% if (!is.null(ld_block$stabilized)) as.numeric(isTRUE(ld_block$stabilized)) else NA_real_)
  )
}

fqsg_static_mcmc_diagnostics <- function(mc_obj, fit_row, mc_diag_row = NULL) {
  fit <- mc_obj$fit
  norm <- mc_obj$normalized %||% .static_normalize_mcmc_fit(fit, model_name = fit_row$model, tau = fit_row$tau)
  beta_draws <- fqsg_as_numeric_matrix(fit$samp.beta)
  sigma_draws <- if (!is.null(fit$samp.sigma)) as.numeric(fit$samp.sigma) else numeric(0)
  gamma_draws <- if (!is.null(fit$samp.gamma)) as.numeric(fit$samp.gamma) else numeric(0)
  tau_draws <- if (!is.null(fit$samp.tau)) as.numeric(fit$samp.tau) else numeric(0)
  c2_draws <- if (!is.null(fit$samp.c2)) as.numeric(fit$samp.c2) else numeric(0)
  lambda_draws <- fqsg_as_numeric_matrix(fit$samp.lambda)
  list(
    fit = fit,
    norm = norm,
    n_keep = if (!is.null(fit$n.mcmc)) as.integer(fit$n.mcmc)[1L] else length(sigma_draws),
    sigma_draws = sigma_draws,
    gamma_draws = gamma_draws,
    state_norm_draws = fqsg_iteration_norm(beta_draws),
    rhs_tau_draws = tau_draws,
    rhs_c2_draws = c2_draws,
    rhs_lambda_mean_draws = if (length(lambda_draws)) rowMeans(lambda_draws, na.rm = TRUE) else numeric(0),
    ess_sigma = fqsg_safe_num(mc_diag_row$ess_sigma[[1]] %||% norm$diagnostics$ess$sigma),
    ess_gamma = fqsg_safe_num(mc_diag_row$ess_gamma[[1]] %||% norm$diagnostics$ess$gamma),
    accept_rate = fqsg_safe_num(mc_diag_row$accept_rate[[1]] %||% norm$diagnostics$acceptance$total),
    accept_rate_burn = fqsg_safe_num(mc_diag_row$accept_rate_burn[[1]] %||% norm$diagnostics$acceptance$burn),
    accept_rate_keep = fqsg_safe_num(mc_diag_row$accept_rate_keep[[1]] %||% norm$diagnostics$acceptance$keep),
    kernel_exact = isTRUE(mc_diag_row$mh_kernel_exact[[1]] %||% norm$diagnostics$mh$kernel_exact),
    signoff_ready = isTRUE(mc_diag_row$mh_signoff_ready[[1]] %||% norm$diagnostics$mh$signoff_ready)
  )
}

fqsg_dynamic_mcmc_diagnostics <- function(mc_obj, fit_row, mc_diag_row = NULL) {
  fit <- mc_obj$fit
  theta_draws <- fqsg_as_numeric_matrix(fit$samp.theta)
  sigma_draws <- if (!is.null(fit$samp.sigma)) as.numeric(fit$samp.sigma) else numeric(0)
  gamma_draws <- if (!is.null(fit$samp.gamma)) as.numeric(fit$samp.gamma) else numeric(0)
  list(
    fit = fit,
    n_keep = if (!is.null(fit$n.mcmc)) as.integer(fit$n.mcmc)[1L] else length(sigma_draws),
    sigma_draws = sigma_draws,
    gamma_draws = gamma_draws,
    state_norm_draws = fqsg_iteration_norm(theta_draws),
    ess_sigma = fqsg_safe_num(mc_diag_row$ess_sigma[[1]] %||% fit$diagnostics$ess$sigma),
    ess_gamma = fqsg_safe_num(mc_diag_row$ess_gamma[[1]] %||% fit$diagnostics$ess$gamma),
    accept_rate = fqsg_safe_num(mc_diag_row$accept_rate[[1]] %||% fit$accept.rate),
    accept_rate_burn = fqsg_safe_num(mc_diag_row$accept_rate_burn[[1]] %||% fit$accept.rate.burn),
    accept_rate_keep = fqsg_safe_num(mc_diag_row$accept_rate_keep[[1]] %||% fit$accept.rate.keep),
    kernel_exact = isTRUE((fit$mh.diagnostics %||% list())$kernel_exact),
    signoff_ready = if (!is.null((fit$mh.diagnostics %||% list())$signoff_ready)) isTRUE(fit$mh.diagnostics$signoff_ready) else TRUE
  )
}

fqsg_vb_signoff <- function(meta_row, diag, cfg, extended_model = FALSE, rhs_model = FALSE) {
  out <- meta_row
  out$method <- paste0(meta_row$inference[[1L]], "::", meta_row$model[[1L]])
  out$signoff_grade <- "FAIL"
  out$comparison_eligible <- FALSE
  out$convergence_certified <- FALSE
  out$signoff_reason <- ""

  sigma_est <- fqsg_safe_num(diag$sigma_est)
  gamma_est <- fqsg_safe_num(diag$gamma_est)
  state_vec <- as.numeric(diag$state_vector %||% numeric(0))
  finite_ok <- fqsg_vec_finite(state_vec) && is.finite(sigma_est) && (!extended_model || is.finite(gamma_est)) &&
    isTRUE(diag$positive_aux_ok %||% TRUE) && isTRUE(diag$finite_aux_ok %||% TRUE)
  domain_ok <- is.finite(sigma_est) && sigma_est > 0 && (!rhs_model || (!is.na(diag$rhs_tau) && diag$rhs_tau > 0 && !is.na(diag$rhs_c2) && diag$rhs_c2 > 0))
  status_ok <- TRUE
  flags <- fqsg_make_execution_flags(status_ok, finite_ok, domain_ok)

  out$status <- flags$status
  out$finite_ok <- finite_ok
  out$domain_ok <- domain_ok
  out$execution_healthy <- flags$execution_healthy
  out$vb_converged <- isTRUE(diag$converged)
  out$vb_stop_reason <- as.character(diag$stop_reason %||% NA_character_)
  out$vb_trace_length <- as.integer(diag$trace_length %||% 0L)
  out$vb_elbo_tail_rel_range <- diag$elbo_tail$rel_range
  out$vb_elbo_tail_rel_drift <- diag$elbo_tail$rel_drift
  out$vb_sigma_tail_rel_range <- diag$sigma_tail$rel_range
  out$vb_gamma_tail_rel_range <- diag$gamma_tail$rel_range
  out$vb_s_tail_rel_range <- diag$s_tail$rel_range
  out$vb_delta_state_last <- diag$delta_state_last
  out$vb_delta_sigma_last <- diag$delta_sigma_last
  out$vb_delta_gamma_last <- diag$delta_gamma_last
  out$vb_delta_s_last <- diag$delta_s_last
  out$vb_ld_trace_rows <- as.integer(diag$ld_trace_rows %||% 0L)
  out$vb_ld_local_mode_pass <- isTRUE(diag$ld_local_mode_pass)
  out$vb_ld_committed_stable_tail <- isTRUE(diag$ld_committed_stable_tail)
  out$vb_ld_candidate_local_pass_rate_tail <- fqsg_safe_num(diag$ld_candidate_local_pass_rate_tail)
  out$vb_ld_committed_local_pass_rate_tail <- fqsg_safe_num(diag$ld_committed_local_pass_rate_tail)
  out$vb_ld_mode_fallback_rate <- fqsg_safe_num(diag$ld_mode_fallback_rate)
  out$vb_ld_stabilized_rate_tail <- fqsg_safe_num(diag$ld_stabilized_rate_tail)
  out$vb_rhs_collapse_flag <- isTRUE(diag$rhs_collapse_flag)
  out$vb_rhs_tau_near_zero <- isTRUE(diag$rhs_tau_near_zero)
  out$vb_rhs_beta_collapse <- isTRUE(diag$rhs_beta_collapse)
  out$vb_rhs_tau <- fqsg_safe_num(diag$rhs_tau)
  out$vb_rhs_c2 <- fqsg_safe_num(diag$rhs_c2)
  out$vb_rhs_lambda_mean <- fqsg_safe_num(diag$rhs_lambda_mean)

  reasons <- character(0)
  if (!finite_ok) reasons <- c(reasons, "non_finite_fit")
  if (!domain_ok) reasons <- c(reasons, "domain_violation")
  if (out$vb_trace_length < as.integer(cfg$min_trace_length %||% 5L)) reasons <- c(reasons, "short_trace")
  if (!is.finite(out$vb_elbo_tail_rel_range)) reasons <- c(reasons, "missing_elbo_trace")
  if (extended_model && (!isTRUE(out$vb_ld_committed_stable_tail) || !isTRUE(out$vb_ld_local_mode_pass))) reasons <- c(reasons, "ld_unstable")
  if (rhs_model && (isTRUE(out$vb_rhs_collapse_flag) || isTRUE(out$vb_rhs_tau_near_zero) || isTRUE(out$vb_rhs_beta_collapse))) reasons <- c(reasons, "rhs_collapse")

  core_vals <- c(out$vb_sigma_tail_rel_range, out$vb_gamma_tail_rel_range, out$vb_s_tail_rel_range)
  core_vals <- core_vals[is.finite(core_vals)]
  core_max <- if (length(core_vals)) max(core_vals, na.rm = TRUE) else NA_real_
  rhs_vals <- c(out$vb_rhs_tau, out$vb_rhs_c2, out$vb_rhs_lambda_mean)
  rhs_finite <- rhs_vals[is.finite(rhs_vals)]

  pass_converged <- isTRUE(out$vb_converged) || !isTRUE(cfg$require_converged_for_pass)
  pass_elbo <- is.finite(out$vb_elbo_tail_rel_range) && out$vb_elbo_tail_rel_range <= as.numeric(cfg$elbo_rel_range_pass %||% 0.01)
  warn_elbo <- is.finite(out$vb_elbo_tail_rel_range) && out$vb_elbo_tail_rel_range <= as.numeric(cfg$elbo_rel_range_warn %||% 0.05)
  pass_core <- (!length(core_vals) || (is.finite(core_max) && core_max <= as.numeric(cfg$core_rel_range_pass %||% 0.02))) &&
    (!is.finite(out$vb_delta_state_last) || abs(out$vb_delta_state_last) <= as.numeric(cfg$delta_state_pass %||% 0.02)) &&
    (!is.finite(out$vb_delta_sigma_last) || abs(out$vb_delta_sigma_last) <= as.numeric(cfg$delta_sigma_pass %||% 0.02)) &&
    (!is.finite(out$vb_delta_gamma_last) || abs(out$vb_delta_gamma_last) <= as.numeric(cfg$delta_gamma_pass %||% 0.02)) &&
    (!is.finite(out$vb_delta_s_last) || abs(out$vb_delta_s_last) <= as.numeric(cfg$delta_s_pass %||% 0.02))
  warn_core <- (!length(core_vals) || (is.finite(core_max) && core_max <= as.numeric(cfg$core_rel_range_warn %||% 0.10))) &&
    (!is.finite(out$vb_delta_state_last) || abs(out$vb_delta_state_last) <= as.numeric(cfg$delta_state_warn %||% 0.10)) &&
    (!is.finite(out$vb_delta_sigma_last) || abs(out$vb_delta_sigma_last) <= as.numeric(cfg$delta_sigma_warn %||% 0.10)) &&
    (!is.finite(out$vb_delta_gamma_last) || abs(out$vb_delta_gamma_last) <= as.numeric(cfg$delta_gamma_warn %||% 0.10)) &&
    (!is.finite(out$vb_delta_s_last) || abs(out$vb_delta_s_last) <= as.numeric(cfg$delta_s_warn %||% 0.10))
  pass_rhs <- !rhs_model || (!isTRUE(out$vb_rhs_collapse_flag) && !isTRUE(out$vb_rhs_tau_near_zero) && !isTRUE(out$vb_rhs_beta_collapse) && length(rhs_finite) >= 3L)
  warn_rhs <- !rhs_model || (!isTRUE(out$vb_rhs_collapse_flag) && !isTRUE(out$vb_rhs_beta_collapse))

  if (!pass_converged) reasons <- c(reasons, "vb_converged_false")
  if (!warn_elbo) reasons <- c(reasons, "elbo_tail_unstable")
  if (!warn_core) reasons <- c(reasons, "core_parameter_tail_unstable")
  if (rhs_model && !warn_rhs) reasons <- c(reasons, "rhs_parameter_unstable")

  if (flags$execution_healthy && pass_converged && pass_elbo && pass_core && pass_rhs && (!extended_model || (isTRUE(out$vb_ld_committed_stable_tail) && isTRUE(out$vb_ld_local_mode_pass)))) {
    out$signoff_grade <- "PASS"
    out$comparison_eligible <- TRUE
    out$convergence_certified <- TRUE
    out$signoff_reason <- "vb_converged; stable_tail"
    return(out)
  }

  if (flags$execution_healthy && warn_elbo && warn_core && warn_rhs) {
    out$signoff_grade <- "WARN"
    out$comparison_eligible <- TRUE
    if (!length(reasons)) reasons <- "stable_tail_but_not_certified"
    out$signoff_reason <- fqsg_join_reasons(reasons)
    return(out)
  }

  out$signoff_reason <- fqsg_join_reasons(reasons)
  out
}

fqsg_mcmc_signoff <- function(meta_row, diag, cfg, extended_model = FALSE, rhs_model = FALSE) {
  out <- meta_row
  out$method <- paste0(meta_row$inference[[1L]], "::", meta_row$model[[1L]])
  out$signoff_grade <- "FAIL"
  out$comparison_eligible <- FALSE
  out$convergence_certified <- FALSE
  out$signoff_reason <- ""

  sigma_draws <- diag$sigma_draws %||% numeric(0)
  gamma_draws <- diag$gamma_draws %||% numeric(0)
  state_norm_draws <- diag$state_norm_draws %||% numeric(0)
  tau_draws <- diag$rhs_tau_draws %||% numeric(0)
  c2_draws <- diag$rhs_c2_draws %||% numeric(0)
  lambda_mean_draws <- diag$rhs_lambda_mean_draws %||% numeric(0)

  finite_ok <- fqsg_vec_finite_positive(sigma_draws) && fqsg_vec_finite(state_norm_draws) && (!extended_model || fqsg_vec_finite(gamma_draws)) &&
    (!rhs_model || (fqsg_vec_finite_positive(tau_draws) && fqsg_vec_finite_positive(c2_draws) && fqsg_vec_finite_positive(lambda_mean_draws)))
  domain_ok <- all(sigma_draws > 0) && (!rhs_model || (all(tau_draws > 0) && all(c2_draws > 0) && all(lambda_mean_draws > 0))) &&
    (!is.finite(diag$accept_rate) || (diag$accept_rate >= 0 && diag$accept_rate <= 1)) &&
    (!is.finite(diag$accept_rate_keep) || (diag$accept_rate_keep >= 0 && diag$accept_rate_keep <= 1))
  status_ok <- length(sigma_draws) > 0L
  flags <- fqsg_make_execution_flags(status_ok, finite_ok, domain_ok)

  sigma_acf1 <- fqsg_safe_acf1(sigma_draws)
  gamma_acf1 <- fqsg_safe_acf1(gamma_draws)
  state_acf1 <- fqsg_safe_acf1(state_norm_draws)
  sigma_geweke <- fqsg_safe_geweke_absz(sigma_draws)
  gamma_geweke <- fqsg_safe_geweke_absz(gamma_draws)
  state_geweke <- fqsg_safe_geweke_absz(state_norm_draws)
  sigma_drift <- fqsg_halfchain_drift(sigma_draws)
  gamma_drift <- fqsg_halfchain_drift(gamma_draws)
  state_drift <- fqsg_halfchain_drift(state_norm_draws)
  tau_ess <- fqsg_safe_ess(tau_draws)
  c2_ess <- fqsg_safe_ess(c2_draws)
  lambda_ess <- fqsg_safe_ess(lambda_mean_draws)

  out$status <- flags$status
  out$finite_ok <- finite_ok
  out$domain_ok <- domain_ok
  out$execution_healthy <- flags$execution_healthy
  out$mcmc_n_keep <- as.integer(diag$n_keep %||% length(sigma_draws))
  out$mcmc_ess_sigma <- fqsg_safe_num(diag$ess_sigma)
  out$mcmc_ess_gamma <- fqsg_safe_num(diag$ess_gamma)
  out$mcmc_ess_state <- fqsg_safe_ess(state_norm_draws)
  out$mcmc_ess_tau <- tau_ess
  out$mcmc_ess_c2 <- c2_ess
  out$mcmc_ess_lambda_mean <- lambda_ess
  out$mcmc_acf1_sigma <- sigma_acf1
  out$mcmc_acf1_gamma <- gamma_acf1
  out$mcmc_acf1_state <- state_acf1
  out$mcmc_geweke_absz_sigma <- sigma_geweke
  out$mcmc_geweke_absz_gamma <- gamma_geweke
  out$mcmc_geweke_absz_state <- state_geweke
  out$mcmc_half_drift_sigma <- sigma_drift
  out$mcmc_half_drift_gamma <- gamma_drift
  out$mcmc_half_drift_state <- state_drift
  out$mcmc_accept_rate <- fqsg_safe_num(diag$accept_rate)
  out$mcmc_accept_rate_burn <- fqsg_safe_num(diag$accept_rate_burn)
  out$mcmc_accept_rate_keep <- fqsg_safe_num(diag$accept_rate_keep)
  out$mcmc_kernel_exact <- isTRUE(diag$kernel_exact)
  out$mcmc_signoff_ready <- isTRUE(diag$signoff_ready)

  reasons <- character(0)
  if (!finite_ok) reasons <- c(reasons, "non_finite_fit")
  if (!domain_ok) reasons <- c(reasons, "domain_violation")
  if (!is.finite(out$mcmc_n_keep) || out$mcmc_n_keep < as.integer(cfg$min_keep_warn %||% 100L)) reasons <- c(reasons, "short_chain")
  if (extended_model && isTRUE(cfg$require_signoff_ready_for_extended) && !isTRUE(out$mcmc_signoff_ready)) reasons <- c(reasons, "kernel_not_signoff_ready")

  ess_core <- c(out$mcmc_ess_sigma, out$mcmc_ess_gamma, out$mcmc_ess_state)
  acf_core <- c(out$mcmc_acf1_sigma, out$mcmc_acf1_gamma, out$mcmc_acf1_state)
  geweke_core <- c(out$mcmc_geweke_absz_sigma, out$mcmc_geweke_absz_gamma, out$mcmc_geweke_absz_state)
  drift_core <- c(out$mcmc_half_drift_sigma, out$mcmc_half_drift_gamma, out$mcmc_half_drift_state)
  ess_rhs <- c(out$mcmc_ess_tau, out$mcmc_ess_c2, out$mcmc_ess_lambda_mean)

  if (any(is.finite(ess_core) & ess_core < as.numeric(cfg$ess_state_warn %||% 10), na.rm = TRUE) || any(is.finite(ess_rhs) & ess_rhs < as.numeric(cfg$ess_state_warn %||% 10), na.rm = TRUE)) reasons <- c(reasons, "low_ess")
  if (any(is.finite(acf_core) & acf_core > as.numeric(cfg$acf1_warn %||% 0.98), na.rm = TRUE)) reasons <- c(reasons, "high_autocorrelation")
  if (any(is.finite(geweke_core) & geweke_core > as.numeric(cfg$geweke_absz_warn %||% 3), na.rm = TRUE)) reasons <- c(reasons, "geweke_drift")
  if (any(is.finite(drift_core) & drift_core > as.numeric(cfg$half_drift_warn %||% 0.5), na.rm = TRUE)) reasons <- c(reasons, "half_chain_drift")

  pass_keep <- is.finite(out$mcmc_n_keep) && out$mcmc_n_keep >= as.integer(cfg$min_keep_pass %||% 160L)
  pass_ess <- (!is.finite(out$mcmc_ess_sigma) || out$mcmc_ess_sigma >= as.numeric(cfg$ess_sigma_pass %||% 30)) &&
    (!extended_model || !is.finite(out$mcmc_ess_gamma) || out$mcmc_ess_gamma >= as.numeric(cfg$ess_gamma_pass %||% 20)) &&
    (!is.finite(out$mcmc_ess_state) || out$mcmc_ess_state >= as.numeric(cfg$ess_state_pass %||% 30)) &&
    (!rhs_model || all(!is.finite(ess_rhs) | ess_rhs >= as.numeric(cfg$ess_state_pass %||% 30)))
  warn_ess <- (!is.finite(out$mcmc_ess_sigma) || out$mcmc_ess_sigma >= as.numeric(cfg$ess_sigma_warn %||% 10)) &&
    (!extended_model || !is.finite(out$mcmc_ess_gamma) || out$mcmc_ess_gamma >= as.numeric(cfg$ess_gamma_warn %||% 10)) &&
    (!is.finite(out$mcmc_ess_state) || out$mcmc_ess_state >= as.numeric(cfg$ess_state_warn %||% 10)) &&
    (!rhs_model || all(!is.finite(ess_rhs) | ess_rhs >= as.numeric(cfg$ess_state_warn %||% 10)))
  pass_acf <- all(!is.finite(acf_core) | acf_core <= as.numeric(cfg$acf1_pass %||% 0.90))
  warn_acf <- all(!is.finite(acf_core) | acf_core <= as.numeric(cfg$acf1_warn %||% 0.98))
  pass_geweke <- all(!is.finite(geweke_core) | geweke_core <= as.numeric(cfg$geweke_absz_pass %||% 2.0))
  warn_geweke <- all(!is.finite(geweke_core) | geweke_core <= as.numeric(cfg$geweke_absz_warn %||% 3.0))
  pass_drift <- all(!is.finite(drift_core) | drift_core <= as.numeric(cfg$half_drift_pass %||% 0.25))
  warn_drift <- all(!is.finite(drift_core) | drift_core <= as.numeric(cfg$half_drift_warn %||% 0.50))

  if (flags$execution_healthy && (!extended_model || !isTRUE(cfg$require_signoff_ready_for_extended) || isTRUE(out$mcmc_signoff_ready)) && pass_keep && pass_ess && pass_acf && pass_geweke && pass_drift) {
    out$signoff_grade <- "PASS"
    out$comparison_eligible <- TRUE
    out$convergence_certified <- TRUE
    out$signoff_reason <- "adequate_chain_length; acceptable_ess_acf_geweke_drift"
    return(out)
  }

  if (flags$execution_healthy && (!extended_model || !isTRUE(cfg$require_signoff_ready_for_extended) || isTRUE(out$mcmc_signoff_ready)) && warn_ess && warn_acf && warn_geweke && warn_drift) {
    out$signoff_grade <- "WARN"
    out$comparison_eligible <- TRUE
    if (!length(reasons)) reasons <- "chain_marginal_but_usable"
    out$signoff_reason <- fqsg_join_reasons(reasons)
    return(out)
  }

  out$signoff_reason <- fqsg_join_reasons(reasons)
  out
}

fqsg_method_signoff_from_root <- function(root_row, fit_row, fit_file_obj, vb_conv, ld_diag, mc_diag, rhs_diag, cfg) {
  meta <- fqsg_method_meta(root_row, fit_row$inference, fit_row$model)
  if (!isTRUE(fit_file_obj$ok)) {
    out <- meta
    out$method <- paste0(meta$inference[[1L]], "::", meta$model[[1L]])
    out$status <- "FAIL"
    out$finite_ok <- FALSE
    out$domain_ok <- FALSE
    out$execution_healthy <- FALSE
    out$comparison_eligible <- FALSE
    out$convergence_certified <- FALSE
    out$signoff_grade <- "FAIL"
    out$signoff_reason <- paste0("fit_load_error: ", fit_file_obj$error)
    return(out)
  }

  model <- as.character(fit_row$model)
  inference <- as.character(fit_row$inference)
  extended_model <- model %in% c("exal", "exdqlm")
  rhs_model <- root_row$root_kind == "static_shrink" && root_row$prior == "rhs"
  fit_row_one <- fit_row[1L, , drop = FALSE]
  vb_row <- vb_conv[vb_conv$model == model & abs(as.numeric(vb_conv$tau) - as.numeric(fit_row$tau)) < 1e-8, , drop = FALSE]
  ld_row <- ld_diag[ld_diag$model == model & abs(as.numeric(ld_diag$tau) - as.numeric(fit_row$tau)) < 1e-8, , drop = FALSE]
  mc_row <- mc_diag[mc_diag$model == model & abs(as.numeric(mc_diag$tau) - as.numeric(fit_row$tau)) < 1e-8, , drop = FALSE]
  rhs_row <- rhs_diag[rhs_diag$inference == inference & rhs_diag$model == model & abs(as.numeric(rhs_diag$tau) - as.numeric(fit_row$tau)) < 1e-8, , drop = FALSE]

  if (inference == "vb") {
    diag <- if (root_row$root_kind == "dynamic") {
      fqsg_dynamic_vb_diagnostics(fit_file_obj$obj, if (nrow(vb_row)) vb_row else fit_row_one, if (nrow(ld_row)) ld_row else NULL)
    } else {
      fqsg_static_vb_diagnostics(fit_file_obj$obj, if (nrow(vb_row)) vb_row else fit_row_one, if (nrow(ld_row)) ld_row else NULL, if (nrow(rhs_row)) rhs_row else NULL)
    }
    return(fqsg_vb_signoff(meta, diag, cfg$vb, extended_model = extended_model, rhs_model = rhs_model))
  }

  diag <- if (root_row$root_kind == "dynamic") {
    fqsg_dynamic_mcmc_diagnostics(fit_file_obj$obj, fit_row_one, if (nrow(mc_row)) mc_row else NULL)
  } else {
    fqsg_static_mcmc_diagnostics(fit_file_obj$obj, fit_row_one, if (nrow(mc_row)) mc_row else NULL)
  }
  fqsg_mcmc_signoff(meta, diag, cfg$mcmc, extended_model = extended_model, rhs_model = rhs_model)
}

fqsg_algorithm_pair_signoff <- function(root_row, method_signoff) {
  models <- c(root_row$model_a[[1L]], root_row$model_b[[1L]])
  rows <- lapply(models, function(model) {
    vb <- method_signoff[method_signoff$inference == "vb" & method_signoff$model == model, , drop = FALSE]
    mc <- method_signoff[method_signoff$inference == "mcmc" & method_signoff$model == model, , drop = FALSE]
    if (!nrow(vb) || !nrow(mc)) return(NULL)
    data.frame(
      root_id = root_row$root_id,
      root_kind = root_row$root_kind,
      family = root_row$family,
      tau = fqsg_safe_num(root_row$tau),
      fit_size = as.integer(root_row$fit_size),
      prior = root_row$prior,
      model = model,
      vb_signoff_grade = as.character(vb$signoff_grade[[1L]]),
      mcmc_signoff_grade = as.character(mc$signoff_grade[[1L]]),
      vb_comparison_eligible = isTRUE(vb$comparison_eligible[[1L]]),
      mcmc_comparison_eligible = isTRUE(mc$comparison_eligible[[1L]]),
      pair_signoff_grade = fqsg_pair_grade(vb$signoff_grade[[1L]], mc$signoff_grade[[1L]]),
      pair_comparison_eligible = isTRUE(vb$comparison_eligible[[1L]]) && isTRUE(mc$comparison_eligible[[1L]]),
      runtime_ratio_mcmc_vs_vb = NA_real_,
      stringsAsFactors = FALSE
    )
  })
  fqsg_bind_rows(rows)
}

fqsg_model_pair_signoff <- function(root_row, method_signoff) {
  baseline_model <- root_row$model_a[[1L]]
  extended_model <- root_row$model_b[[1L]]
  rows <- lapply(c("vb", "mcmc"), function(inference) {
    base <- method_signoff[method_signoff$inference == inference & method_signoff$model == baseline_model, , drop = FALSE]
    ext <- method_signoff[method_signoff$inference == inference & method_signoff$model == extended_model, , drop = FALSE]
    if (!nrow(base) || !nrow(ext)) return(NULL)
    data.frame(
      root_id = root_row$root_id,
      root_kind = root_row$root_kind,
      family = root_row$family,
      tau = fqsg_safe_num(root_row$tau),
      fit_size = as.integer(root_row$fit_size),
      prior = root_row$prior,
      inference = inference,
      baseline_model = baseline_model,
      extended_model = extended_model,
      baseline_signoff_grade = as.character(base$signoff_grade[[1L]]),
      extended_signoff_grade = as.character(ext$signoff_grade[[1L]]),
      baseline_comparison_eligible = isTRUE(base$comparison_eligible[[1L]]),
      extended_comparison_eligible = isTRUE(ext$comparison_eligible[[1L]]),
      pair_signoff_grade = fqsg_pair_grade(base$signoff_grade[[1L]], ext$signoff_grade[[1L]]),
      pair_comparison_eligible = isTRUE(base$comparison_eligible[[1L]]) && isTRUE(ext$comparison_eligible[[1L]]),
      stringsAsFactors = FALSE
    )
  })
  fqsg_bind_rows(rows)
}

fqsg_root_signoff_summary <- function(root_row, method_signoff, algorithm_pairs, model_pairs) {
  n_methods <- nrow(method_signoff)
  n_pass <- sum(method_signoff$signoff_grade == "PASS", na.rm = TRUE)
  n_warn <- sum(method_signoff$signoff_grade == "WARN", na.rm = TRUE)
  n_fail <- sum(method_signoff$signoff_grade == "FAIL", na.rm = TRUE)
  data.frame(
    root_id = root_row$root_id,
    root_kind = root_row$root_kind,
    family = root_row$family,
    tau = fqsg_safe_num(root_row$tau),
    fit_size = as.integer(root_row$fit_size),
    prior = root_row$prior,
    n_methods = n_methods,
    n_signoff_pass = n_pass,
    n_signoff_warn = n_warn,
    n_signoff_fail = n_fail,
    method_comparison_eligible_rate = if (n_methods) mean(as.logical(method_signoff$comparison_eligible), na.rm = TRUE) else NA_real_,
    n_algorithm_pairs = nrow(algorithm_pairs),
    n_algorithm_pair_pass = sum(algorithm_pairs$pair_signoff_grade == "PASS", na.rm = TRUE),
    n_algorithm_pair_warn = sum(algorithm_pairs$pair_signoff_grade == "WARN", na.rm = TRUE),
    n_algorithm_pair_fail = sum(algorithm_pairs$pair_signoff_grade == "FAIL", na.rm = TRUE),
    algorithm_pair_comparison_eligible_rate = if (nrow(algorithm_pairs)) mean(as.logical(algorithm_pairs$pair_comparison_eligible), na.rm = TRUE) else NA_real_,
    n_model_pairs = nrow(model_pairs),
    n_model_pair_pass = sum(model_pairs$pair_signoff_grade == "PASS", na.rm = TRUE),
    n_model_pair_warn = sum(model_pairs$pair_signoff_grade == "WARN", na.rm = TRUE),
    n_model_pair_fail = sum(model_pairs$pair_signoff_grade == "FAIL", na.rm = TRUE),
    model_pair_comparison_eligible_rate = if (nrow(model_pairs)) mean(as.logical(model_pairs$pair_comparison_eligible), na.rm = TRUE) else NA_real_,
    root_comparison_eligible_any = any(as.logical(c(algorithm_pairs$pair_comparison_eligible, model_pairs$pair_comparison_eligible))),
    root_comparison_eligible_full = all(as.logical(c(algorithm_pairs$pair_comparison_eligible, model_pairs$pair_comparison_eligible))),
    stringsAsFactors = FALSE
  )
}

fqsg_repair_targets <- function(root_row, method_signoff) {
  if (!nrow(method_signoff)) return(data.frame(stringsAsFactors = FALSE))
  bad <- method_signoff[!as.logical(method_signoff$comparison_eligible), , drop = FALSE]
  if (!nrow(bad)) {
    return(data.frame(
      root_id = character(0),
      root_kind = character(0),
      family = character(0),
      tau = numeric(0),
      fit_size = integer(0),
      prior = character(0),
      inference = character(0),
      model = character(0),
      signoff_grade = character(0),
      signoff_reason = character(0),
      suggested_action = character(0),
      stringsAsFactors = FALSE
    ))
  }
  bad$suggested_action <- ifelse(
    bad$inference == "vb",
    "fresh_vb_then_mcmc",
    "rerun_mcmc_from_existing_vb"
  )
  bad[, c("root_id", "root_kind", "family", "tau", "fit_size", "prior", "inference", "model", "signoff_grade", "signoff_reason", "suggested_action"), drop = FALSE]
}

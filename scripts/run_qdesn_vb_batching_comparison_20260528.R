#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(flag, default = NULL) {
  hit <- which(args == flag)
  if (!length(hit) || hit[[1L]] >= length(args)) return(default)
  args[[hit[[1L]] + 1L]]
}

repo_root <- normalizePath(
  arg_value("--repo", getwd()),
  mustWork = TRUE
)
output_dir <- arg_value(
  "--output-dir",
  file.path(repo_root, "results", "qdesn_vb_batching_comparison_20260528")
)
seed <- as.integer(arg_value("--seed", "20260528"))
if (!is.finite(seed)) stop("--seed must be a finite integer.", call. = FALSE)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
setwd(repo_root)

`%||%` <- function(a, b) if (is.null(a)) b else a

if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("The package comparison harness requires pkgload.", call. = FALSE)
}
pkgload::load_all(repo_root, quiet = TRUE)

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, quote = TRUE)
  invisible(path)
}

git_value <- function(cmd) {
  out <- tryCatch(
    system2("git", cmd, stdout = TRUE, stderr = TRUE),
    error = function(e) NA_character_
  )
  if (!length(out)) return(NA_character_)
  out[[1L]]
}

max_abs <- function(x) {
  x <- as.numeric(x)
  if (!length(x)) return(NA_real_)
  max(abs(x), na.rm = TRUE)
}

fit_static <- function(label, X, y, family, ctrl, prior, al_fixed_gamma = NULL) {
  tm <- system.time({
    fit <- exdqlm::exal_fit(
      y = y,
      X = X,
      p0 = 0.5,
      gamma_bounds = c(-3, 3),
      method = "vb",
      likelihood_family = family,
      al_fixed_gamma = al_fixed_gamma,
      vb_control = ctrl,
      prior_gamma = list(mu0 = 0, s20 = 10),
      prior_sigma = list(a = 1, b = 1),
      beta_prior_obj = prior
    )
  })
  list(
    label = label,
    method_family = "package_static",
    likelihood_family = family,
    fit = fit,
    elapsed_sec = unname(tm[["elapsed"]])
  )
}

fit_qdesn <- function(label, y, family, vb_args, seed_fit) {
  tm <- system.time({
    fit <- exdqlm::qdesn_fit_vb(
      y = y,
      p0 = 0.5,
      D = 1L,
      n = 4L,
      n_tilde = integer(0),
      m = 1L,
      washout = 4L,
      add_bias = TRUE,
      seed = seed_fit,
      vb_args = vb_args
    )
  })
  list(
    label = label,
    method_family = "univariate_qdesn",
    likelihood_family = family,
    fit = fit,
    elapsed_sec = unname(tm[["elapsed"]])
  )
}

extract_readout_fit <- function(obj) {
  if (identical(obj$method_family, "package_static")) return(obj$fit)
  obj$fit$fit
}

extract_qdesn_X <- function(obj) {
  if (!identical(obj$method_family, "univariate_qdesn")) return(NULL)
  obj$fit$X
}

summarize_fit <- function(obj, ref = NULL) {
  fit <- extract_readout_fit(obj)
  qbeta_m <- as.numeric(fit$qbeta$m)
  qbeta_vdiag <- diag(as.matrix(fit$qbeta$V))
  misc <- fit$misc %||% list()
  chunk_cfg <- misc$chunking %||% list()
  chunking_mode <- if (isTRUE(chunk_cfg$enabled)) {
    as.character(chunk_cfg$mode %||% "unknown")
  } else {
    "none"
  }
  sigma_last <- tail(as.numeric(misc$sigma_trace %||% NA_real_), 1L)
  gamma_last <- tail(as.numeric(misc$gamma_trace %||% NA_real_), 1L)
  ref_fit <- if (is.null(ref)) NULL else extract_readout_fit(ref)
  ref_m <- if (is.null(ref_fit)) qbeta_m else as.numeric(ref_fit$qbeta$m)
  ref_v <- if (is.null(ref_fit)) qbeta_vdiag else diag(as.matrix(ref_fit$qbeta$V))

  data.frame(
    label = obj$label,
    method_family = obj$method_family,
    likelihood_family = obj$likelihood_family,
    chunking_mode = chunking_mode,
    stochastic = isTRUE(misc$stochastic),
    converged = isTRUE(fit$converged),
    iter = as.integer(fit$iter),
    elapsed_sec = as.numeric(obj$elapsed_sec),
    p = length(qbeta_m),
    beta_l2 = sqrt(sum(qbeta_m^2)),
    beta_first = qbeta_m[[1L]],
    sigma_last = sigma_last,
    gamma_last = gamma_last,
    max_abs_beta_diff_vs_reference = max_abs(qbeta_m - ref_m),
    max_abs_beta_var_diff_vs_reference = max_abs(qbeta_vdiag - ref_v),
    finite_state = all(is.finite(qbeta_m)) &&
      all(is.finite(qbeta_vdiag)) &&
      is.finite(sigma_last) &&
      is.finite(gamma_last),
    stringsAsFactors = FALSE
  )
}

compare_exact_pair <- function(left, right, tolerance = 1e-7) {
  lf <- extract_readout_fit(left)
  rf <- extract_readout_fit(right)
  lx <- extract_qdesn_X(left)
  rx <- extract_qdesn_X(right)
  beta_mean_diff <- max_abs(as.numeric(lf$qbeta$m) - as.numeric(rf$qbeta$m))
  beta_cov_diff <- max_abs(as.matrix(lf$qbeta$V) - as.matrix(rf$qbeta$V))
  sigma_trace_diff <- max_abs(as.numeric(lf$misc$sigma_trace) - as.numeric(rf$misc$sigma_trace))
  gamma_trace_diff <- max_abs(as.numeric(lf$misc$gamma_trace) - as.numeric(rf$misc$gamma_trace))
  elbo_diff <- max_abs(as.numeric(lf$misc$elbo_trace) - as.numeric(rf$misc$elbo_trace))
  x_diff <- if (is.null(lx) || is.null(rx)) NA_real_ else max_abs(lx - rx)
  gate_diff <- max(beta_mean_diff, beta_cov_diff, sigma_trace_diff, gamma_trace_diff, elbo_diff, x_diff, na.rm = TRUE)
  data.frame(
    left_label = left$label,
    right_label = right$label,
    same_likelihood_family = identical(left$likelihood_family, right$likelihood_family),
    same_convergence_status = identical(isTRUE(lf$converged), isTRUE(rf$converged)),
    left_iter = as.integer(lf$iter),
    right_iter = as.integer(rf$iter),
    beta_mean_max_abs_diff = beta_mean_diff,
    beta_cov_max_abs_diff = beta_cov_diff,
    sigma_trace_max_abs_diff = sigma_trace_diff,
    gamma_trace_max_abs_diff = gamma_trace_diff,
    elbo_trace_max_abs_diff = elbo_diff,
    qdesn_design_max_abs_diff = x_diff,
    max_gate_diff = gate_diff,
    tolerance = tolerance,
    passed = is.finite(gate_diff) && gate_diff <= tolerance,
    stringsAsFactors = FALSE
  )
}

compare_stochastic <- function(reference, stochastic, tolerance = 0.25) {
  rf <- extract_readout_fit(reference)
  sf <- extract_readout_fit(stochastic)
  misc <- sf$misc %||% list()
  beta_diff <- max_abs(as.numeric(sf$qbeta$m) - as.numeric(rf$qbeta$m))
  beta_var_diff <- max_abs(diag(as.matrix(sf$qbeta$V)) - diag(as.matrix(rf$qbeta$V)))
  data.frame(
    reference_label = reference$label,
    stochastic_label = stochastic$label,
    stochastic_label_present = isTRUE(misc$stochastic),
    approximate_note_present = grepl("approximate", as.character(misc$stochastic_objective_note %||% "")),
    stochastic_trace_rows = if (is.data.frame(misc$stochastic_trace)) nrow(misc$stochastic_trace) else 0L,
    max_abs_beta_diff = beta_diff,
    max_abs_beta_var_diff = beta_var_diff,
    tolerance = tolerance,
    finite_state = all(is.finite(as.numeric(sf$qbeta$m))) &&
      all(is.finite(diag(as.matrix(sf$qbeta$V)))) &&
      all(is.finite(as.numeric(sf$qv$E_v))) &&
      all(is.finite(as.numeric(sf$qv$E_inv_v))),
    passed = is.finite(beta_diff) && beta_diff <= tolerance,
    stringsAsFactors = FALSE
  )
}

cat("Q-DESN VB batching comparison harness\n")
cat("repo:", repo_root, "\n")
cat("output_dir:", output_dir, "\n")
cat("seed:", seed, "\n")

set.seed(seed)
n_static <- 100L
x <- seq(-1, 1, length.out = n_static)
X_static <- cbind(`(Intercept)` = 1, x = x, x2 = x^2)
beta_true <- c(0.2, 0.6, -0.3)
y_static <- as.numeric(X_static %*% beta_true + stats::rnorm(n_static, sd = 0.08))

t_seq <- seq_len(30L)
y_qdesn <- as.numeric(0.2 * sin(t_seq / 3) + 0.05 * cos(t_seq / 5))

prior <- exdqlm:::exal_make_beta_prior(type = "ridge", tau2 = 50)

base_ctrl <- list(
  max_iter = 35L,
  min_iter_elbo = 10L,
  tol = 0,
  tol_par = 0,
  n_samp_xi = 32L,
  verbose = FALSE
)
exact_ctrl <- utils::modifyList(base_ctrl, list(
  chunking = list(enabled = TRUE, mode = "exact", chunk_size = 17L)
))
stoch_ctrl <- utils::modifyList(base_ctrl, list(
  max_iter = 80L,
  chunking = list(
    enabled = TRUE,
    mode = "stochastic",
    chunk_size = 20L,
    order = "random",
    seed = seed,
    learning_rate = list(t0 = 10, kappa = 0.75, rho_min = 0.02),
    refresh = list(
      full_every = 20L,
      objective_every = 20L,
      sigma_every = 5L,
      rhs_every = 20L,
      local_every = 20L
    ),
    diagnostics = list(
      trace = TRUE,
      store_batch_ids = TRUE,
      check_finite_every = 1L
    )
  )
))

qdesn_base_args <- list(
  likelihood_family = "al",
  al_fixed_gamma = 0,
  max_iter = 20L,
  min_iter_elbo = 5L,
  tol = 0,
  tol_par = 0,
  n_samp_xi = 16L,
  verbose = FALSE,
  beta_prior_type = "ridge",
  beta_ridge_tau2 = 10
)
qdesn_exact_args <- utils::modifyList(qdesn_base_args, list(
  chunking = list(enabled = TRUE, mode = "exact", chunk_size = 5L)
))
qdesn_stoch_args <- utils::modifyList(qdesn_base_args, list(
  max_iter = 40L,
  chunking = list(
    enabled = TRUE,
    mode = "stochastic",
    chunk_size = 5L,
    order = "random",
    seed = 43L,
    learning_rate = list(t0 = 5, kappa = 0.75, rho_min = 0.02),
    refresh = list(
      full_every = 10L,
      objective_every = 10L,
      sigma_every = 5L,
      rhs_every = 10L,
      local_every = 10L
    ),
    diagnostics = list(
      trace = TRUE,
      store_batch_ids = TRUE,
      check_finite_every = 1L
    )
  )
))
qdesn_exal_args <- qdesn_base_args
qdesn_exal_args$likelihood_family <- "exal"
qdesn_exal_args$al_fixed_gamma <- NULL
qdesn_exal_exact_args <- utils::modifyList(qdesn_exal_args, list(
  chunking = list(enabled = TRUE, mode = "exact", chunk_size = 5L)
))

fits <- list(
  fit_static("static_al_unchunked", X_static, y_static, "al", base_ctrl, prior, al_fixed_gamma = 0),
  fit_static("static_al_exact_chunked", X_static, y_static, "al", exact_ctrl, prior, al_fixed_gamma = 0),
  fit_static("static_al_stochastic", X_static, y_static, "al", stoch_ctrl, prior, al_fixed_gamma = 0),
  fit_static("static_exal_unchunked", X_static, y_static, "exal", base_ctrl, prior),
  fit_static("static_exal_exact_chunked", X_static, y_static, "exal", exact_ctrl, prior),
  fit_qdesn("qdesn_al_unchunked", y_qdesn, "al", qdesn_base_args, seed_fit = 20260532L),
  fit_qdesn("qdesn_al_exact_chunked", y_qdesn, "al", qdesn_exact_args, seed_fit = 20260532L),
  fit_qdesn("qdesn_al_stochastic", y_qdesn, "al", qdesn_stoch_args, seed_fit = 20260532L),
  fit_qdesn("qdesn_exal_unchunked", y_qdesn, "exal", qdesn_exal_args, seed_fit = 20260533L),
  fit_qdesn("qdesn_exal_exact_chunked", y_qdesn, "exal", qdesn_exal_exact_args, seed_fit = 20260533L)
)
names(fits) <- vapply(fits, `[[`, character(1), "label")

exal_stochastic_error <- tryCatch({
  exdqlm::exal_fit(
    y = y_static,
    X = X_static,
    p0 = 0.5,
    gamma_bounds = c(-3, 3),
    method = "vb",
    likelihood_family = "exal",
    vb_control = stoch_ctrl,
    prior_gamma = list(mu0 = 0, s20 = 10),
    prior_sigma = list(a = 1, b = 1),
    beta_prior_obj = prior
  )
  NA_character_
}, error = function(e) conditionMessage(e))

summary_rows <- do.call(rbind, list(
  summarize_fit(fits$static_al_unchunked),
  summarize_fit(fits$static_al_exact_chunked, fits$static_al_unchunked),
  summarize_fit(fits$static_al_stochastic, fits$static_al_unchunked),
  summarize_fit(fits$static_exal_unchunked),
  summarize_fit(fits$static_exal_exact_chunked, fits$static_exal_unchunked),
  summarize_fit(fits$qdesn_al_unchunked),
  summarize_fit(fits$qdesn_al_exact_chunked, fits$qdesn_al_unchunked),
  summarize_fit(fits$qdesn_al_stochastic, fits$qdesn_al_unchunked),
  summarize_fit(fits$qdesn_exal_unchunked),
  summarize_fit(fits$qdesn_exal_exact_chunked, fits$qdesn_exal_unchunked)
))

exact_rows <- do.call(rbind, list(
  compare_exact_pair(fits$static_al_unchunked, fits$static_al_exact_chunked),
  compare_exact_pair(fits$static_exal_unchunked, fits$static_exal_exact_chunked),
  compare_exact_pair(fits$qdesn_al_unchunked, fits$qdesn_al_exact_chunked),
  compare_exact_pair(fits$qdesn_exal_unchunked, fits$qdesn_exal_exact_chunked)
))

stochastic_rows <- do.call(rbind, list(
  compare_stochastic(fits$static_al_unchunked, fits$static_al_stochastic),
  compare_stochastic(fits$qdesn_al_unchunked, fits$qdesn_al_stochastic)
))

forbidden_rows <- data.frame(
  method = "stochastic exAL",
  attempted = TRUE,
  failed_early = is.character(exal_stochastic_error) && grepl("supported only for likelihood_family = 'al'", exal_stochastic_error, fixed = TRUE),
  message = as.character(exal_stochastic_error),
  stringsAsFactors = FALSE
)

repo_state <- data.frame(
  repo = repo_root,
  branch = git_value(c("rev-parse", "--abbrev-ref", "HEAD")),
  head = git_value(c("rev-parse", "HEAD")),
  upstream = git_value(c("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")),
  seed = seed,
  stringsAsFactors = FALSE
)

write_csv(repo_state, file.path(output_dir, "repo_state.csv"))
write_csv(summary_rows, file.path(output_dir, "method_summary.csv"))
write_csv(exact_rows, file.path(output_dir, "exact_equivalence.csv"))
write_csv(stochastic_rows, file.path(output_dir, "stochastic_diagnostics.csv"))
write_csv(forbidden_rows, file.path(output_dir, "forbidden_modes.csv"))

md_path <- file.path(output_dir, "qdesn_vb_batching_comparison_summary.md")
con <- file(md_path, open = "wt")
on.exit(close(con), add = TRUE)
w <- function(...) writeLines(paste0(...), con)
md_table <- function(df) {
  cols <- names(df)
  w("| ", paste(cols, collapse = " | "), " |")
  w("| ", paste(rep("---", length(cols)), collapse = " | "), " |")
  for (i in seq_len(nrow(df))) {
    vals <- vapply(df[i, , drop = FALSE], function(x) {
      x <- x[[1L]]
      if (is.numeric(x)) format(x, digits = 12, scientific = TRUE) else as.character(x)
    }, character(1))
    w("| ", paste(vals, collapse = " | "), " |")
  }
}

w("# Q-DESN VB Batching Comparison Summary")
w("")
w("Seed: `", seed, "`")
w("")
w("Package HEAD: `", repo_state$head, "`")
w("")
w("## Method Summary")
md_table(summary_rows)
w("")
w("## Exact Equivalence")
md_table(exact_rows)
w("")
w("## Stochastic Diagnostics")
md_table(stochastic_rows)
w("")
w("## Forbidden Modes")
md_table(forbidden_rows)
w("")
w("Exact chunking is full-data equivalent. Stochastic AL is approximate.")

cat("Wrote:\n")
cat(" -", file.path(output_dir, "method_summary.csv"), "\n")
cat(" -", file.path(output_dir, "exact_equivalence.csv"), "\n")
cat(" -", file.path(output_dir, "stochastic_diagnostics.csv"), "\n")
cat(" -", file.path(output_dir, "forbidden_modes.csv"), "\n")
cat(" -", md_path, "\n")

if (!all(exact_rows$passed)) {
  stop("At least one exact chunked equivalence gate failed.", call. = FALSE)
}
if (!all(stochastic_rows$finite_state) || !all(stochastic_rows$stochastic_label_present)) {
  stop("At least one stochastic AL diagnostic gate failed.", call. = FALSE)
}
if (!all(stochastic_rows$passed)) {
  stop("At least one stochastic AL approximation-distance gate failed.", call. = FALSE)
}
if (!isTRUE(forbidden_rows$failed_early[[1L]])) {
  stop("Stochastic exAL did not fail early as expected.", call. = FALSE)
}

cat("All comparison gates passed.\n")

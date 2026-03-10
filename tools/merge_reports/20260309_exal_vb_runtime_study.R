#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(devtools)
  library(tools)
})

repo_root <- normalizePath(getwd())
devtools::load_all(repo_root, quiet = TRUE, export_all = FALSE)
audit_root <- file.path(repo_root, "results", "sim_suite_static", "audits", "exal_runtime_microbenchmark_delta_20260309")
dir.create(audit_root, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(audit_root, "tables"), recursive = TRUE, showWarnings = FALSE)

sim_path <- file.path(repo_root, "results", "sim_suite_static", "audits", "exal_vb_ld_stabilization_20260309", "sim_output_n100.rds")
stopifnot(file.exists(sim_path))
sim <- readRDS(sim_path)
X <- sim$X
if (is.null(X) && !is.null(sim$Xmat)) X <- sim$Xmat
if (is.null(X) && !is.null(sim$extras$X)) X <- sim$extras$X
stopifnot(!is.null(X), !is.null(sim$y))
y <- as.numeric(sim$y)
X <- as.matrix(X)
if (!("(Intercept)" %in% colnames(X)) && !("Intercept" %in% colnames(X))) {
  X <- cbind(`(Intercept)` = 1, X)
}

truth <- NULL
if (!is.null(sim$truth) && !is.null(sim$truth$mu)) truth <- as.numeric(sim$truth$mu)
if (is.null(truth) && !is.null(sim$truth_mu)) truth <- as.numeric(sim$truth_mu)
if (is.null(truth) && !is.null(sim$mu_true)) truth <- as.numeric(sim$mu_true)
if (is.null(truth) && !is.null(sim$q)) truth <- as.numeric(sim$q[, 1])
if (is.null(truth) && !is.null(sim$extras$mu)) truth <- as.numeric(sim$extras$mu)
if (is.null(truth) && !is.null(sim$beta)) truth <- as.numeric(X %*% sim$beta)
if (is.null(truth)) stop("Could not recover truth mean/quantile from sim object")

beta_true <- NULL
if (!is.null(sim$beta)) beta_true <- as.numeric(sim$beta)
if (is.null(beta_true) && !is.null(sim$truth_beta)) beta_true <- as.numeric(sim$truth_beta)
if (is.null(beta_true) && !is.null(sim$extras$beta_true)) beta_true <- as.numeric(sim$extras$beta_true)

extract_fit <- function(fit, method, model, variant) {
  beta_hat <- if (method == "vb") {
    as.numeric(fit$qbeta$m)
  } else {
    colMeans(as.matrix(fit$samp.beta))
  }
  mu_hat <- as.numeric(X %*% beta_hat)
  data.frame(
    variant = variant,
    model = model,
    method = method,
    elapsed_sec = as.numeric(fit$run.time %||% fit$runtime %||% NA_real_),
    converged = if (!is.null(fit$converged)) isTRUE(fit$converged) else NA,
    iter = if (!is.null(fit$iter)) fit$iter else NA_integer_,
    quantile_rmse = sqrt(mean((mu_hat - truth)^2)),
    beta_rmse = if (!is.null(beta_true) && length(beta_true) == length(beta_hat)) sqrt(mean((beta_hat - beta_true)^2)) else NA_real_,
    stringsAsFactors = FALSE
  )
}
`%||%` <- function(x, y) if (is.null(x)) y else x

run_vb <- function(model = c("al", "exal"), variant, ld_controls = list(), max_iter = 300L, verbose = FALSE) {
  model <- match.arg(model)
  old_opts <- options(
    exdqlm.tol_sigma = 1e-4,
    exdqlm.tol_gamma = 1e-4,
    exdqlm.tol_elbo = 1e-4,
    exdqlm.vb.min_iter = 50L,
    exdqlm.vb.patience = 20L,
    exdqlm.vb.allow_elbo_drop = 1e-4
  )
  on.exit(options(old_opts), add = TRUE)
  fit <- exal_static_LDVB(
    y = y, X = X, p0 = 0.05,
    dqlm.ind = identical(model, "al"),
    max_iter = max_iter, tol = 1e-4,
    n_samp_xi = 200L,
    ld_controls = utils::modifyList(list(profile_timing = TRUE, profile_iter_trace = FALSE), ld_controls),
    verbose = verbose
  )
  list(summary = extract_fit(fit, "vb", model, variant), fit = fit)
}

run_mcmc <- function(model = c("al", "exal"), variant, proposal = "slice") {
  model <- match.arg(model)
  fit <- exal_static_mcmc(
    y = y, X = X, p0 = 0.05,
    dqlm.ind = identical(model, "al"),
    n.burn = 200L, n.mcmc = 100L, thin = 1L,
    mh.proposal = proposal,
    trace.diagnostics = FALSE,
    verbose = FALSE
  )
  list(summary = extract_fit(fit, "mcmc", model, variant), fit = fit)
}

variants <- list(
  vb_al_ref = function() run_vb("al", "vb_al_ref", ld_controls = list(store_trace = FALSE)),
  vb_exal_delta_default_trace = function() run_vb("exal", "vb_exal_delta_default_trace", ld_controls = list(store_trace = TRUE)),
  vb_exal_delta_default_notrace = function() run_vb("exal", "vb_exal_delta_default_notrace", ld_controls = list(store_trace = FALSE)),
  vb_exal_delta_strictchecks = function() run_vb(
    "exal",
    "vb_exal_delta_strictchecks",
    ld_controls = list(
      store_trace = FALSE,
      candidate_mode_check_every = 1L,
      stabilize_candidate_mode_check_every = 1L,
      committed_mode_check_every = 1L,
      committed_mode_check_stabilized = TRUE
    )
  ),
  mcmc_al_ref = function() run_mcmc("al", "mcmc_al_ref"),
  mcmc_exal_ref = function() run_mcmc("exal", "mcmc_exal_ref")
)

results <- list()
summaries <- list()
for (nm in names(variants)) {
  fit_path <- file.path(audit_root, sprintf("%s.rds", nm))
  if (file.exists(fit_path)) {
    cat(sprintf("Reusing %s\n", nm))
    fit <- readRDS(fit_path)
    method <- if (startsWith(nm, "mcmc")) "mcmc" else "vb"
    model <- if (grepl("_al_", nm, fixed = TRUE)) "al" else "exal"
    results[[nm]] <- fit
    summaries[[nm]] <- extract_fit(fit, method, model, nm)
    next
  }
  cat(sprintf("Running %s\n", nm))
  out <- variants[[nm]]()
  results[[nm]] <- out$fit
  summaries[[nm]] <- out$summary
  saveRDS(out$fit, fit_path)
}
summary_df <- do.call(rbind, summaries)
write.csv(summary_df, file.path(audit_root, "tables", "runtime_summary_small_n100.csv"), row.names = FALSE)

ld_rows <- lapply(names(results), function(nm) {
  fit <- results[[nm]]
  if (is.null(fit$diagnostics$ld_block$timing$totals)) return(NULL)
  totals <- fit$diagnostics$ld_block$timing$totals
  data.frame(
    variant = nm,
    component = names(totals),
    seconds = as.numeric(unlist(totals)),
    stringsAsFactors = FALSE
  )
})
ld_df <- do.call(rbind, Filter(Negate(is.null), ld_rows))
if (!is.null(ld_df) && nrow(ld_df)) {
  total_map <- aggregate(seconds ~ variant, ld_df, sum)
  names(total_map)[2] <- "variant_total"
  ld_df <- merge(ld_df, total_map, by = "variant", all.x = TRUE, sort = FALSE)
  ld_df$share <- ld_df$seconds / pmax(ld_df$variant_total, 1e-12)
  write.csv(ld_df, file.path(audit_root, "tables", "ld_timing_breakdown_small_n100.csv"), row.names = FALSE)
  top_df <- do.call(rbind, lapply(split(ld_df, ld_df$variant), function(df) {
    df <- df[order(-df$seconds), ]
    head(df, 5)
  }))
  write.csv(top_df, file.path(audit_root, "tables", "ld_timing_top5_small_n100.csv"), row.names = FALSE)
}

sig_df <- do.call(rbind, lapply(names(results), function(nm) {
  fit <- results[[nm]]
  ld_block <- fit$diagnostics$ld_block
  if (is.null(ld_block)) return(NULL)
  signoff <- ld_block$signoff_summary %||% list()
  stab <- ld_block$stabilization %||% list()
  data.frame(
    variant = nm,
    candidate_local_pass_rate = signoff$candidate_local_pass_rate %||% NA_real_,
    committed_local_pass_rate = signoff$committed_local_pass_rate %||% NA_real_,
    committed_stable = signoff$committed_stable %||% NA,
    stabilized_iter_count = stab$stabilized_iter_count %||% NA_integer_,
    cycle_detect_count = stab$cycle_detect_count %||% NA_integer_,
    active_final = stab$active_final %||% NA,
    final_reason = stab$reason %||% NA_character_,
    stringsAsFactors = FALSE
  )
}))
if (!is.null(sig_df) && nrow(sig_df)) {
  write.csv(sig_df, file.path(audit_root, "tables", "ld_signoff_overview_small_n100.csv"), row.names = FALSE)
}

cat("Done\n")

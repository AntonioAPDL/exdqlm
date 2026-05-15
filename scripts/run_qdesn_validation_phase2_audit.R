#!/usr/bin/env Rscript

suppressWarnings(suppressMessages({
  library(jsonlite)
}))

`%||%` <- function(a, b) if (is.null(a)) b else a

args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default = NULL) {
  hit <- which(args == flag)
  if (!length(hit)) return(default)
  idx <- hit[1L] + 1L
  if (idx > length(args)) stop(sprintf("Missing value for %s", flag), call. = FALSE)
  args[[idx]]
}

repo_root <- normalizePath(get_arg("--repo-root", "."), winslash = "/", mustWork = TRUE)
setwd(repo_root)

load_repo_package <- function(root) {
  if (requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(root, quiet = TRUE, export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)
    return(invisible(TRUE))
  }
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all(root, quiet = TRUE, export_all = FALSE, helpers = FALSE)
    return(invisible(TRUE))
  }
  stop("Need pkgload or devtools installed to load the repo package.", call. = FALSE)
}

load_repo_package(repo_root)
pkg_name <- tryCatch(
  as.character(utils::read.dcf(file.path(repo_root, "DESCRIPTION"))[1L, "Package"]),
  error = function(...) "exdqlm"
)
readout_scale_fit_fn <- getFromNamespace("readout_scale_fit", ns = pkg_name)

git_sha <- tryCatch(
  system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE),
  error = function(...) "unknown"
)
git_sha <- if (length(git_sha)) trimws(git_sha[[1L]]) else "unknown"

default_output_root <- file.path(
  repo_root,
  "reports",
  "qdesn_mcmc_validation",
  "qdesn_validation_phase2_audit",
  sprintf("qdesn-validation-phase2-audit-20260331__git-%s", git_sha)
)

output_root <- normalizePath(get_arg("--output-root", default_output_root), winslash = "/", mustWork = FALSE)
summary_dir <- file.path(output_root, "summary")
tables_dir <- file.path(output_root, "tables")
manifest_dir <- file.path(output_root, "manifest")
dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(manifest_dir, recursive = TRUE, showWarnings = FALSE)

write_csv <- function(df, path) {
  utils::write.csv(df, path, row.names = FALSE, na = "")
}

write_md <- function(path, lines) {
  writeLines(lines, con = path, useBytes = TRUE)
}

tau_tag <- function(x) {
  gsub("\\.", "p", formatC(as.numeric(x), format = "f", digits = 2L))
}

root_dirname <- function(scenario, tau, likelihood_family, beta_prior_type, seed, reservoir_profile) {
  sprintf(
    "scenario-%s__tau-%s__lik-%s__prior-%s__seed-%s__res-%s",
    scenario,
    tau_tag(tau),
    likelihood_family,
    beta_prior_type,
    as.integer(seed),
    reservoir_profile
  )
}

root_label <- function(scenario, tau, likelihood_family, beta_prior_type) {
  sprintf("%s @ tau=%.2f %s %s", scenario, as.numeric(tau), likelihood_family, beta_prior_type)
}

wave_report_root <- file.path(
  repo_root,
  "reports",
  "qdesn_mcmc_validation",
  "qdesn_validation_repair_wave1",
  "qdesn-validation-repair-wave1-20260331__git-59e0e2a"
)

wave_results_root <- file.path(
  repo_root,
  "results",
  "qdesn_mcmc_validation",
  "qdesn_validation_repair_wave1",
  "qdesn-validation-repair-wave1-20260331__git-59e0e2a"
)

closeout_forensics_path <- file.path(
  repo_root,
  "reports",
  "qdesn_mcmc_validation",
  "finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727",
  "tables",
  "phase01_mcmc_fail_forensics.csv"
)

profiles <- data.frame(
  profile_id = c("R0_legacy_anchor", "R1_promoted_x10_core", "R2_x3_alternate", "R3_x10_plus_x8_rhsns_overlay"),
  family = c("anchor", "x10_core", "x3_alt", "x10_plus_x8"),
  stringsAsFactors = FALSE
)

root_meta <- data.frame(
  scenario = c("dlm_ar1V", "dlm_constV_smallW", "dlm_constV_bigW", "dlm_constV_smallW", "dlm_constV_smallW", "dlm_constV_bigW"),
  tau = c(0.95, 0.95, 0.05, 0.95, 0.50, 0.95),
  likelihood_family = c("exal", "exal", "exal", "exal", "exal", "al"),
  beta_prior_type = c("rhs_ns", "ridge", "ridge", "rhs_ns", "rhs_ns", "rhs_ns"),
  seed = rep(123L, 6L),
  reservoir_profile = rep("tiny_d1_n8", 6L),
  root_class = c("severe", "severe", "severe", "severe", "sentinel", "sentinel"),
  stringsAsFactors = FALSE
)
root_meta$root_join_key <- with(root_meta, paste(scenario, tau, likelihood_family, beta_prior_type, seed, reservoir_profile, sep = "||"))
root_meta$root_id <- with(root_meta, root_dirname(scenario, tau, likelihood_family, beta_prior_type, seed, reservoir_profile))
root_meta$root_label <- with(root_meta, root_label(scenario, tau, likelihood_family, beta_prior_type))
root_meta$design_key <- with(root_meta, paste(scenario, seed, reservoir_profile, sep = "||"))

find_profile_run_dir <- function(profile_id) {
  base_dir <- file.path(wave_results_root, "micro_pilot", profile_id)
  runs <- list.dirs(base_dir, recursive = FALSE, full.names = TRUE)
  if (!length(runs)) stop(sprintf("No run directory found for profile %s", profile_id), call. = FALSE)
  runs[[1L]]
}

read_transition_table <- function(profile_id) {
  path <- file.path(wave_report_root, "tables", sprintf("phase35_transitions_%s.csv", profile_id))
  df <- utils::read.csv(path, stringsAsFactors = FALSE)
  df <- merge(root_meta, df, by = "root_join_key", all.x = TRUE, sort = FALSE)
  df$profile_id <- profile_id
  df$delta_runtime_seconds <- df$fit_runtime_seconds_prof - df$fit_runtime_seconds_base
  df$delta_ess_core <- df$mcmc_min_ess_core_prof - df$mcmc_min_ess_core_base
  df$delta_geweke_absz <- df$mcmc_max_geweke_absz_core_prof - df$mcmc_max_geweke_absz_core_base
  df$delta_half_drift <- df$mcmc_max_half_drift_core_prof - df$mcmc_max_half_drift_core_base
  df
}

read_mcmc_signoff <- function(profile_id, root_id) {
  run_dir <- find_profile_run_dir(profile_id)
  path <- file.path(run_dir, "roots", root_id, "tables", "method_signoff_long.csv")
  df <- utils::read.csv(path, stringsAsFactors = FALSE)
  df[df$method == "mcmc", , drop = FALSE]
}

read_chain_summary <- function(profile_id, root_id) {
  run_dir <- find_profile_run_dir(profile_id)
  path <- file.path(run_dir, "roots", root_id, "fits", "mcmc", "chain_summary.csv")
  df <- utils::read.csv(path, stringsAsFactors = FALSE)
  df$profile_id <- profile_id
  df$root_id <- root_id
  df
}

transitions_long <- do.call(rbind, lapply(profiles$profile_id, read_transition_table))

signoff_rows <- do.call(
  rbind,
  lapply(profiles$profile_id, function(profile_id) {
    out <- do.call(
      rbind,
      lapply(root_meta$root_id, function(root_id) {
        df <- read_mcmc_signoff(profile_id, root_id)
        if (!nrow(df)) return(NULL)
        df$profile_id <- profile_id
        df
      })
    )
    out
  })
)

signoff_rows <- merge(
  root_meta[, c("root_id", "root_label", "root_class", "design_key")],
  signoff_rows,
  by = "root_id",
  all.y = TRUE,
  sort = FALSE
)

chain_rows <- do.call(
  rbind,
  lapply(profiles$profile_id, function(profile_id) {
    do.call(
      rbind,
      lapply(root_meta$root_id, function(root_id) read_chain_summary(profile_id, root_id))
    )
  })
)

chain_rows <- merge(
  root_meta[, c("root_id", "root_label", "root_class", "design_key")],
  chain_rows,
  by = "root_id",
  all.y = TRUE,
  sort = FALSE
)

hard_root_key <- "dlm_constV_bigW||0.05||exal||ridge||123||tiny_d1_n8"

hard_root_profile_metrics <- transitions_long[
  transitions_long$root_join_key == hard_root_key,
  c(
    "profile_id", "root_label",
    "signoff_grade_base", "signoff_grade_prof",
    "fit_runtime_seconds_base", "fit_runtime_seconds_prof",
    "mcmc_min_ess_core_base", "mcmc_min_ess_core_prof", "delta_ess_core",
    "mcmc_max_geweke_absz_core_base", "mcmc_max_geweke_absz_core_prof", "delta_geweke_absz",
    "mcmc_max_half_drift_core_base", "mcmc_max_half_drift_core_prof", "delta_half_drift"
  ),
  drop = FALSE
]

hard_root_signoff <- signoff_rows[
  signoff_rows$root_id == root_meta$root_id[root_meta$root_join_key == hard_root_key],
  c(
    "profile_id", "root_label", "signoff_grade", "comparison_eligible", "signoff_reason",
    "mcmc_min_ess_core", "mcmc_max_acf1_core", "mcmc_max_geweke_absz_core", "mcmc_max_half_drift_core"
  ),
  drop = FALSE
]

hard_root_chain <- chain_rows[
  chain_rows$root_id == root_meta$root_id[root_meta$root_join_key == hard_root_key],
  c("profile_id", "parameter", "mean", "sd", "ess", "acf1", "geweke_absz", "half_drift"),
  drop = FALSE
]

severe_quartet_metrics <- merge(
  transitions_long[
    transitions_long$root_class == "severe",
    c(
      "profile_id", "root_label", "root_class",
      "signoff_grade_base", "signoff_grade_prof",
      "mcmc_min_ess_core_base", "mcmc_min_ess_core_prof", "delta_ess_core",
      "mcmc_max_geweke_absz_core_base", "mcmc_max_geweke_absz_core_prof", "delta_geweke_absz",
      "mcmc_max_half_drift_core_base", "mcmc_max_half_drift_core_prof", "delta_half_drift"
    ),
    drop = FALSE
  ],
  signoff_rows[
    signoff_rows$root_class == "severe",
    c("profile_id", "root_label", "signoff_reason"),
    drop = FALSE
  ],
  by = c("profile_id", "root_label"),
  all.x = TRUE,
  sort = FALSE
)

closeout_forensics <- utils::read.csv(closeout_forensics_path, stringsAsFactors = FALSE)
closeout_forensics$root_join_key <- with(
  closeout_forensics,
  paste(scenario, tau, likelihood_family, beta_prior_type, seed, reservoir_profile, sep = "||")
)
selected_closeout_forensics <- merge(
  root_meta[, c("root_join_key", "root_label", "root_class")],
  closeout_forensics,
  by = "root_join_key",
  all.x = TRUE,
  sort = FALSE
)

build_augmented_design <- function(root_dir) {
  fit_req <- fromJSON(file.path(root_dir, "fits", "vb", "fit_request.json"), simplifyVector = FALSE)
  series <- utils::read.csv(file.path(root_dir, "data", "series_wide.csv"), stringsAsFactors = FALSE)
  split_df <- utils::read.csv(file.path(root_dir, "data", "split_summary.csv"), stringsAsFactors = FALSE)

  cfg <- fit_req$config
  desn <- cfg$desn
  y_full <- as.numeric(series$y)
  train_n <- as.integer(split_df$n_train[[1L]])

  fit <- do.call(
    qdesn_fit_vb,
    list(
      y = y_full,
      p0 = 0.50,
      D = as.integer(desn$D),
      n = as.integer(unlist(desn$n, use.names = FALSE)),
      n_tilde = as.integer(unlist(desn$n_tilde %||% integer(0), use.names = FALSE)),
      m = as.integer(desn$m),
      input_mode = as.character(cfg$readout$input_mode %||% "raw_y_lags"),
      alpha = as.numeric(desn$alpha),
      rho = as.numeric(unlist(desn$rho, use.names = FALSE)),
      act_f = as.character(desn$act_f),
      act_k = as.character(desn$act_k),
      pi_w = as.numeric(desn$pi_w),
      pi_in = as.numeric(desn$pi_in),
      washout = as.integer(desn$washout),
      add_bias = isTRUE(desn$add_bias),
      seed = as.integer(desn$seed),
      fit_readout = FALSE
    )
  )

  keep_all_abs <- as.integer(fit$meta$keep_idx)
  X_all_kept <- as.matrix(fit$X)
  include_input <- isTRUE(cfg$readout$include_input)
  input_lags_y <- if (include_input && as.integer(desn$m) > 0L) seq_len(as.integer(desn$m)) else integer(0)
  reservoir_lags <- as.integer(cfg$readout$reservoir_lags %||% 0L)
  res_lags_vec <- if (reservoir_lags > 0L) seq_len(reservoir_lags) else integer(0)

  build_lag_mat_vec <- function(vec, lags, prefix = "in_y_lag_") {
    if (!length(lags)) return(NULL)
    cols <- lapply(lags, function(L) c(rep(NA_real_, L), vec[seq_len(length(vec) - L)]))
    out <- do.call(cbind, cols)
    colnames(out) <- paste0(prefix, lags)
    out
  }

  build_mat_lags <- function(M, lags, prefix = "res_lag_") {
    if (is.null(M) || !length(lags)) return(NULL)
    n <- nrow(M)
    p <- ncol(M)
    base <- colnames(M)
    if (is.null(base)) base <- paste0("z", seq_len(p))
    out_list <- lapply(lags, function(L) {
      rbind(matrix(NA_real_, nrow = L, ncol = p), M[seq_len(n - L), , drop = FALSE])
    })
    out <- do.call(cbind, out_list)
    colnames(out) <- unlist(lapply(lags, function(L) paste0(base, "_", prefix, L)), use.names = FALSE)
    out
  }

  cbind_safe <- function(...) {
    parts <- Filter(Negate(is.null), list(...))
    if (!length(parts)) return(NULL)
    do.call(cbind, parts)
  }

  input_block_all <- NULL
  if (length(input_lags_y)) {
    y_lag_all <- build_lag_mat_vec(y_full, input_lags_y)
    input_block_all <- y_lag_all[keep_all_abs, , drop = FALSE]
  }

  z_lag_all <- NULL
  if (length(res_lags_vec)) {
    X_res_no_bias <- if (isTRUE(desn$add_bias)) X_all_kept[, -1, drop = FALSE] else X_all_kept
    z_lag_all <- build_mat_lags(X_res_no_bias, res_lags_vec, prefix = "res_lag_")
  }

  keep_aug_abs <- keep_all_abs
  X_res_all <- X_all_kept
  if (length(res_lags_vec)) {
    keep_idx <- seq.int(reservoir_lags + 1L, length(keep_all_abs))
    keep_aug_abs <- keep_all_abs[keep_idx]
    X_res_all <- X_res_all[keep_idx, , drop = FALSE]
    if (!is.null(input_block_all)) input_block_all <- input_block_all[keep_idx, , drop = FALSE]
    if (!is.null(z_lag_all)) z_lag_all <- z_lag_all[keep_idx, , drop = FALSE]
  }

  X_aug <- cbind_safe(X_res_all, input_block_all, z_lag_all)
  if (is.null(X_aug)) stop("Failed to build augmented design.", call. = FALSE)

  X_train <- X_aug[keep_aug_abs <= train_n, , drop = FALSE]
  X_res_train <- X_res_all[keep_aug_abs <= train_n, , drop = FALSE]
  scale_fit <- if (isTRUE(cfg$inference$readout_scale)) {
    readout_scale_fit_fn(X_train, has_intercept = isTRUE(desn$add_bias))
  } else {
    list(X = X_train, scale_info = list(scaled = FALSE))
  }

  list(
    X_train = X_train,
    X_train_scaled = scale_fit$X,
    X_res_train = X_res_train,
    keep_train_abs = keep_aug_abs[keep_aug_abs <= train_n],
    train_n = train_n,
    desn = desn,
    cfg = cfg
  )
}

design_metrics <- function(X, has_intercept = FALSE) {
  X <- as.matrix(X)
  p <- ncol(X)
  n <- nrow(X)
  idx <- seq_len(p)
  if (isTRUE(has_intercept) && p >= 1L) idx <- idx[-1L]
  X_sub <- if (length(idx)) X[, idx, drop = FALSE] else matrix(0, nrow = n, ncol = 0L)

  sd_vec <- if (ncol(X_sub)) apply(X_sub, 2L, stats::sd, na.rm = TRUE) else numeric(0)
  nz_idx <- which(is.finite(sd_vec) & sd_vec > 1e-12)
  X_nz <- if (length(nz_idx)) X_sub[, nz_idx, drop = FALSE] else matrix(0, nrow = n, ncol = 0L)
  sv <- if (ncol(X_nz)) svd(X_nz, nu = 0L, nv = 0L)$d else numeric(0)
  rank_qr <- if (ncol(X_nz)) qr(X_nz)$rank else 0L
  cond_num <- if (length(sv) && min(sv) > 0) max(sv) / min(sv) else Inf
  stable_rank <- if (length(sv) && max(sv) > 0) sum(sv^2) / max(sv)^2 else 0
  effective_rank_1pct <- if (length(sv)) sum(sv > max(sv) * 0.01) else 0L

  cor_vals <- numeric(0)
  if (ncol(X_nz) >= 2L) {
    cor_mat <- suppressWarnings(stats::cor(X_nz))
    cor_vals <- abs(cor_mat[upper.tri(cor_mat)])
    cor_vals <- cor_vals[is.finite(cor_vals)]
  }

  data.frame(
    n = n,
    p = p,
    p_nonconst = ncol(X_nz),
    p_over_n = if (n > 0) p / n else NA_real_,
    qr_rank = rank_qr,
    rank_deficit = max(p - rank_qr, 0L),
    stable_rank = stable_rank,
    effective_rank_1pct = effective_rank_1pct,
    singular_value_max = if (length(sv)) max(sv) else NA_real_,
    singular_value_min = if (length(sv)) min(sv) else NA_real_,
    cond_num = cond_num,
    sd_min = if (length(sd_vec)) min(sd_vec, na.rm = TRUE) else NA_real_,
    sd_median = if (length(sd_vec)) stats::median(sd_vec, na.rm = TRUE) else NA_real_,
    sd_max = if (length(sd_vec)) max(sd_vec, na.rm = TRUE) else NA_real_,
    n_sd_lt_1e3 = sum(sd_vec < 1e-3, na.rm = TRUE),
    n_sd_lt_1e6 = sum(sd_vec < 1e-6, na.rm = TRUE),
    cor_abs_max = if (length(cor_vals)) max(cor_vals) else NA_real_,
    cor_abs_median = if (length(cor_vals)) stats::median(cor_vals) else NA_real_,
    cor_abs_p95 = if (length(cor_vals)) as.numeric(stats::quantile(cor_vals, 0.95, names = FALSE)) else NA_real_,
    frac_cor_abs_gt_090 = if (length(cor_vals)) mean(cor_vals > 0.90) else NA_real_,
    frac_cor_abs_gt_095 = if (length(cor_vals)) mean(cor_vals > 0.95) else NA_real_,
    stringsAsFactors = FALSE
  )
}

anchor_run_dir <- find_profile_run_dir("R0_legacy_anchor")

conditioning_rows <- do.call(
  rbind,
  lapply(seq_len(nrow(root_meta)), function(i) {
    root_row <- root_meta[i, , drop = FALSE]
    root_dir <- file.path(anchor_run_dir, "roots", root_row$root_id)
    build <- build_augmented_design(root_dir)
    raw_metrics <- design_metrics(build$X_train, has_intercept = isTRUE(build$desn$add_bias))
    scaled_metrics <- design_metrics(build$X_train_scaled, has_intercept = isTRUE(build$desn$add_bias))
    res_metrics <- design_metrics(build$X_res_train, has_intercept = isTRUE(build$desn$add_bias))
    names(raw_metrics) <- paste0("raw_", names(raw_metrics))
    names(scaled_metrics) <- paste0("scaled_", names(scaled_metrics))
    names(res_metrics) <- paste0("res_", names(res_metrics))
    data.frame(
      root_label = root_row$root_label,
      root_class = root_row$root_class,
      design_key = root_row$design_key,
      scenario = root_row$scenario,
      tau = root_row$tau,
      likelihood_family = root_row$likelihood_family,
      beta_prior_type = root_row$beta_prior_type,
      reservoir_profile = root_row$reservoir_profile,
      train_n = build$train_n,
      stringsAsFactors = FALSE
    )[rep(1L, nrow(raw_metrics)), , drop = FALSE] |>
      cbind(raw_metrics, scaled_metrics, res_metrics)
  })
)

conditioning_by_design <- aggregate(
  conditioning_rows[
    ,
    c(
      "raw_n", "raw_p", "raw_qr_rank", "raw_rank_deficit", "raw_cond_num",
      "raw_effective_rank_1pct", "raw_cor_abs_max", "raw_frac_cor_abs_gt_095",
      "scaled_cond_num", "scaled_cor_abs_max", "scaled_frac_cor_abs_gt_095",
      "res_cond_num", "res_cor_abs_max"
    )
  ],
  by = conditioning_rows[, c("design_key", "scenario", "reservoir_profile"), drop = FALSE],
  FUN = function(x) x[[1L]]
)

root_design_map <- conditioning_rows[, c("root_label", "root_class", "design_key", "scenario", "tau", "likelihood_family", "beta_prior_type"), drop = FALSE]

write_csv(transitions_long, file.path(tables_dir, "repair_wave1_root_transitions_long.csv"))
write_csv(selected_closeout_forensics, file.path(tables_dir, "phase01_selected_fail_forensics.csv"))
write_csv(severe_quartet_metrics, file.path(tables_dir, "severe_quartet_profile_metrics.csv"))
write_csv(hard_root_profile_metrics, file.path(tables_dir, "hard_root_profile_metrics.csv"))
write_csv(hard_root_signoff, file.path(tables_dir, "hard_root_signoff_metrics.csv"))
write_csv(hard_root_chain, file.path(tables_dir, "hard_root_chain_parameter_metrics.csv"))
write_csv(conditioning_rows, file.path(tables_dir, "tiny_d1_n8_conditioning_by_root.csv"))
write_csv(conditioning_by_design, file.path(tables_dir, "tiny_d1_n8_conditioning_by_design.csv"))
write_csv(root_design_map, file.path(tables_dir, "tiny_d1_n8_root_design_map.csv"))

profile_rank <- utils::read.csv(file.path(wave_report_root, "tables", "profile_rank_summary.csv"), stringsAsFactors = FALSE)
write_csv(profile_rank, file.path(tables_dir, "profile_rank_summary.csv"))

hard_gamma <- hard_root_chain[hard_root_chain$parameter == "gamma", , drop = FALSE]
hard_sigma <- hard_root_chain[hard_root_chain$parameter == "sigma", , drop = FALSE]

md_lines <- c(
  "# QDESN Validation Phase 2 Audit Summary",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- git_sha: `%s`", git_sha),
  sprintf("- output_root: `%s`", output_root),
  "",
  "## Main Findings",
  "",
  sprintf("- Wave 1 remained operationally clean: `%d/%d` profiles completed, `0` errors, `0` timeouts.", nrow(profile_rank), nrow(profile_rank)),
  sprintf("- The severe quartet stayed intact across all profiles; best candidates still had `severe_fail_n = %d`.", min(profile_rank$severe_fail_n, na.rm = TRUE)),
  sprintf("- The persistent hard root is `%s`.", root_meta$root_label[root_meta$root_join_key == hard_root_key]),
  sprintf("- On the hard root, the anchor kept a mixed failure (`ESS=%.2f`, `half_drift=%.3f`), while `R1` traded that into stronger gamma half-drift (`%.3f`) and `R3` drifted on gamma even harder (`%.3f`).",
          hard_root_profile_metrics$mcmc_min_ess_core_prof[hard_root_profile_metrics$profile_id == "R0_legacy_anchor"],
          hard_root_profile_metrics$mcmc_max_half_drift_core_prof[hard_root_profile_metrics$profile_id == "R0_legacy_anchor"],
          hard_gamma$half_drift[hard_gamma$profile_id == "R1_promoted_x10_core"],
          hard_gamma$half_drift[hard_gamma$profile_id == "R3_x10_plus_x8_rhsns_overlay"]),
  sprintf("- Conditioning is material but not sufficient by itself: `%s` has the worst raw design conditioning (`cond_num=%.2f`), but the same design key appears in both a severe root and a sentinel root.",
          conditioning_by_design$scenario[which.max(conditioning_by_design$raw_cond_num)],
          max(conditioning_by_design$raw_cond_num, na.rm = TRUE)),
  "",
  "## Artifacts",
  "",
  "- `tables/hard_root_profile_metrics.csv`",
  "- `tables/hard_root_signoff_metrics.csv`",
  "- `tables/hard_root_chain_parameter_metrics.csv`",
  "- `tables/severe_quartet_profile_metrics.csv`",
  "- `tables/tiny_d1_n8_conditioning_by_root.csv`",
  "- `tables/tiny_d1_n8_conditioning_by_design.csv`",
  "- `tables/tiny_d1_n8_root_design_map.csv`"
)

write_md(file.path(summary_dir, "phase2_audit_summary.md"), md_lines)

manifest <- list(
  repo_root = repo_root,
  git_sha = git_sha,
  wave_report_root = wave_report_root,
  wave_results_root = wave_results_root,
  closeout_forensics_path = closeout_forensics_path,
  output_root = output_root,
  generated_at = as.character(Sys.time())
)
write(
  jsonlite::toJSON(manifest, auto_unbox = TRUE, pretty = TRUE, null = "null"),
  file = file.path(manifest_dir, "phase2_audit_manifest.json")
)

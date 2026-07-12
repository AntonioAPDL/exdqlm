#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload", "yaml")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[[1L]]
  if (idx >= length(args)) return(default)
  args[[idx + 1L]]
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}
int_arg <- function(flag, default) {
  val <- suppressWarnings(as.integer(get_arg(flag, as.character(default)))[1L])
  if (is.finite(val)) val else as.integer(default)
}
num_arg <- function(flag, default) {
  val <- suppressWarnings(as.numeric(get_arg(flag, as.character(default)))[1L])
  if (is.finite(val)) val else as.numeric(default)
}
write_df <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
bind_rows <- function(xs) {
  xs <- Filter(function(x) is.data.frame(x) && nrow(x) > 0L, xs)
  if (!length(xs)) return(data.frame(stringsAsFactors = FALSE))
  cols <- unique(unlist(lapply(xs, names), use.names = FALSE))
  xs <- lapply(xs, function(x) {
    missing <- setdiff(cols, names(x))
    for (nm in missing) x[[nm]] <- NA
    x[, cols, drop = FALSE]
  })
  do.call(rbind, xs)
}
slug_num <- function(x) {
  out <- format(as.numeric(x), scientific = FALSE, trim = TRUE)
  out <- sub("0+$", "", out)
  out <- sub("\\.$", "", out)
  out[!nzchar(out)] <- "0"
  gsub("-", "m", gsub("\\.", "p", out))
}
tau_key <- function(x) sprintf("%.8f", as.numeric(x))
tau_token <- function(x) paste0("tau", gsub("\\.", "p", sprintf("%.2f", as.numeric(x))))
cell_token <- function(family, tau) paste(as.character(family), tau_token(tau), sep = "_")
finite_num <- function(x, default = NA_real_) {
  val <- suppressWarnings(as.numeric(x)[1L])
  if (is.finite(val)) val else default
}
finite_int <- function(x, default = NA_integer_) {
  val <- suppressWarnings(as.integer(x)[1L])
  if (is.finite(val)) val else default
}
bool_value <- function(x) {
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
}
nearest_values <- function(x, grid, k = 3L) {
  x <- finite_num(x, NA_real_)
  grid <- sort(unique(as.numeric(grid)))
  if (!is.finite(x)) return(utils::head(grid, k))
  grid[order(abs(grid - x), grid)][seq_len(min(length(grid), k))]
}
md_table <- function(x, cols) {
  cols <- intersect(cols, names(x))
  if (!length(cols) || !nrow(x)) return("| none |\n|---|")
  y <- x[, cols, drop = FALSE]
  fmt <- function(z) {
    if (is.numeric(z)) {
      out <- ifelse(is.na(z), "NA", formatC(z, digits = 4, format = "fg", flag = "#"))
    } else {
      out <- as.character(z)
      out[is.na(out)] <- "NA"
    }
    out
  }
  out <- c(
    paste("|", paste(cols, collapse = " | "), "|"),
    paste("|", paste(rep("---", length(cols)), collapse = " | "), "|")
  )
  for (i in seq_len(nrow(y))) {
    vals <- unlist(lapply(y[i, , drop = FALSE], fmt), use.names = FALSE)
    out <- c(out, paste("|", paste(vals, collapse = " | "), "|"))
  }
  out
}

stage_file <- as.character(get_arg(
  "--stage-file",
  "qdesn_dynamic_fitforecast_v2_tt500_vb_case_specific_rhs_screen"
))[1L]
screen_mode <- as.character(get_arg("--screen-mode", "case_specific_rhs"))[1L]
is_fitrmse_v50 <- screen_mode %in% c("fitrmse_v50", "case_targeted_rhs_v50", "case_targeted_rhs_v5", "case_targeted_rhs_v5p0")
is_fitrmse_v49 <- screen_mode %in% c("fitrmse_v49", "case_targeted_rhs_v49", "case_targeted_rhs_v4p9")
is_fitrmse_v48 <- screen_mode %in% c("fitrmse_v48", "case_targeted_rhs_v48", "case_targeted_rhs_v4p8")
is_fitrmse_v47 <- screen_mode %in% c("fitrmse_v47", "case_targeted_rhs_v47", "case_targeted_rhs_v4p7")
is_fitrmse_v46 <- screen_mode %in% c("fitrmse_v46", "case_targeted_rhs_v46", "case_targeted_rhs_v4p6")
is_fitrmse_v45 <- screen_mode %in% c("fitrmse_v45", "case_targeted_rhs_v45", "case_targeted_rhs_v4p5")
is_fitrmse_v4 <- screen_mode %in% c("fitrmse_v4", "case_targeted_rhs_v4")
is_fitrmse_v3 <- screen_mode %in% c("fitrmse_v3", "case_targeted_rhs_v3", "case_targeted_rhs")
is_fitrmse_followup <- isTRUE(is_fitrmse_v3) || isTRUE(is_fitrmse_v4) || isTRUE(is_fitrmse_v45) || isTRUE(is_fitrmse_v46) || isTRUE(is_fitrmse_v47) || isTRUE(is_fitrmse_v48) || isTRUE(is_fitrmse_v49) || isTRUE(is_fitrmse_v50)
is_fitrmse_v4plus <- isTRUE(is_fitrmse_v4) || isTRUE(is_fitrmse_v45) || isTRUE(is_fitrmse_v46) || isTRUE(is_fitrmse_v47) || isTRUE(is_fitrmse_v48) || isTRUE(is_fitrmse_v49) || isTRUE(is_fitrmse_v50)
is_fitrmse_v47plus <- isTRUE(is_fitrmse_v47) || isTRUE(is_fitrmse_v48) || isTRUE(is_fitrmse_v49) || isTRUE(is_fitrmse_v50)
is_fitrmse_v48plus <- isTRUE(is_fitrmse_v48) || isTRUE(is_fitrmse_v49) || isTRUE(is_fitrmse_v50)
screening_stage_label <- if (isTRUE(is_fitrmse_v50)) {
  "vb_case_targeted_rhs_v50"
} else if (isTRUE(is_fitrmse_v49)) {
  "vb_case_targeted_rhs_v49"
} else if (isTRUE(is_fitrmse_v48plus)) {
  "vb_case_targeted_rhs_v48"
} else if (isTRUE(is_fitrmse_v47)) {
  "vb_case_targeted_rhs_v47"
} else if (isTRUE(is_fitrmse_v46)) {
  "vb_case_targeted_rhs_v46"
} else if (isTRUE(is_fitrmse_v45)) {
  "vb_case_targeted_rhs_v45"
} else if (isTRUE(is_fitrmse_v4)) {
  "vb_case_targeted_rhs_v4"
} else if (isTRUE(is_fitrmse_v3)) {
  "vb_case_targeted_rhs_v3"
} else {
  "vb_case_specific_rhs_screen"
}
screening_stage_stub <- if (isTRUE(is_fitrmse_v50)) {
  "case_targeted_rhs_v50"
} else if (isTRUE(is_fitrmse_v49)) {
  "case_targeted_rhs_v49"
} else if (isTRUE(is_fitrmse_v48plus)) {
  "case_targeted_rhs_v48"
} else if (isTRUE(is_fitrmse_v47)) {
  "case_targeted_rhs_v47"
} else if (isTRUE(is_fitrmse_v46)) {
  "case_targeted_rhs_v46"
} else if (isTRUE(is_fitrmse_v45)) {
  "case_targeted_rhs_v45"
} else if (isTRUE(is_fitrmse_v4)) {
  "case_targeted_rhs_v4"
} else if (isTRUE(is_fitrmse_v3)) {
  "case_targeted_rhs_v3"
} else {
  "case_specific_rhs_screen"
}
diagnostic_stub <- if (isTRUE(is_fitrmse_v50)) {
  "qdesn_tt500_vb_case_targeted_rhs_v50"
} else if (isTRUE(is_fitrmse_v49)) {
  "qdesn_tt500_vb_case_targeted_rhs_v49"
} else if (isTRUE(is_fitrmse_v48plus)) {
  "qdesn_tt500_vb_case_targeted_rhs_v48"
} else if (isTRUE(is_fitrmse_v47)) {
  "qdesn_tt500_vb_case_targeted_rhs_v47"
} else if (isTRUE(is_fitrmse_v46)) {
  "qdesn_tt500_vb_case_targeted_rhs_v46"
} else if (isTRUE(is_fitrmse_v45)) {
  "qdesn_tt500_vb_case_targeted_rhs_v45"
} else if (isTRUE(is_fitrmse_v4)) {
  "qdesn_tt500_vb_case_targeted_rhs_v4"
} else if (isTRUE(is_fitrmse_v3)) {
  "qdesn_tt500_vb_case_targeted_rhs_v3"
} else {
  "qdesn_tt500_vb_case_specific_rhs"
}
default_source_report <- file.path(
  "reports", "qdesn_mcmc_validation",
  "qdesn_dynamic_fitforecast_v2_tt500_vb_historical_winner_handoff",
  "qdesn-vb-historical-winner-handoff-full-20260709__git-feaf0f9",
  "20260709-001015__git-feaf0f9"
)
source_report_root <- resolve_path(get_arg("--source-report-root", default_source_report), must_work = TRUE)
cell_summary_path <- resolve_path(get_arg(
  "--cell-summary",
  file.path(source_report_root, "tables", "qdesn_tt500_vb_dominance_cell_summary.csv")
), must_work = TRUE)
fit_summary_path <- resolve_path(get_arg(
  "--fit-summary",
  file.path(source_report_root, "tables", "qdesn_tt500_vb_screen_fit_forecast_summary.csv")
), must_work = TRUE)
audit_summary_path <- resolve_path(get_arg(
  "--audit-summary",
  file.path(source_report_root, "audit", "tables", "qdesn_tt500_vb_screen_audit_summary.csv")
), must_work = TRUE)
baseline_path <- resolve_path(get_arg(
  "--baseline",
  "validation/fitforecast_v2/docs/validation_local_exdqlm_dqlm_vb_baseline_20260708.csv"
), must_work = TRUE)
base_defaults_path <- resolve_path(get_arg(
  "--base-defaults",
  "config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_historical_winner_handoff_defaults.yaml"
), must_work = TRUE)
profiles_out <- resolve_path(get_arg(
  "--profiles-out",
  file.path("config", "validation", paste0(stage_file, "_profiles.csv"))
), must_work = FALSE)
assignments_out <- resolve_path(get_arg(
  "--assignments-out",
  file.path("config", "validation", paste0(stage_file, "_cell_assignments.csv"))
), must_work = FALSE)
defaults_out <- resolve_path(get_arg(
  "--defaults-out",
  file.path("config", "validation", paste0(stage_file, "_defaults.yaml"))
), must_work = FALSE)
grid_out <- resolve_path(get_arg(
  "--grid-out",
  file.path("config", "validation", paste0(stage_file, "_grid.csv"))
), must_work = FALSE)
manifest_path <- resolve_path(get_arg(
  "--manifest-out",
  file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json"))
), must_work = FALSE)
diagnostic_out <- resolve_path(get_arg(
  "--diagnostic-out",
  file.path("reports", "qdesn_mcmc_validation", stage_file, "materialization_diagnostics")
), must_work = FALSE)
doc_out <- resolve_path(get_arg(
  "--doc-out",
  "validation/fitforecast_v2/docs/QDESN_500OBS_VB_CASE_SPECIFIC_RHS_SCREEN_PLAN_2026-07-09.md"
), must_work = FALSE)

workers <- int_arg("--workers", 32L)
max_profiles_per_cell <- int_arg("--max-profiles-per-cell", if (isTRUE(is_fitrmse_v50)) 72L else if (isTRUE(is_fitrmse_v49)) 56L else if (isTRUE(is_fitrmse_v48plus)) 48L else if (isTRUE(is_fitrmse_v47)) 36L else if (isTRUE(is_fitrmse_v45)) 36L else if (isTRUE(is_fitrmse_v3)) 34L else 28L)
max_p_over_n <- num_arg("--max-p-over-n", 0.45)
screening_wave <- as.character(get_arg(
  "--screening-wave",
  paste0(screening_stage_stub, "_", format(Sys.Date(), "%Y_%m_%d"))
))[1L]
likelihoods <- strsplit(as.character(get_arg("--likelihoods", "al,exal"))[1L], ",", fixed = TRUE)[[1L]]
likelihoods <- trimws(likelihoods[nzchar(trimws(likelihoods))])
if (!length(likelihoods)) likelihoods <- c("al", "exal")
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")

cell <- utils::read.csv(cell_summary_path, check.names = FALSE, stringsAsFactors = FALSE)
fit <- utils::read.csv(fit_summary_path, check.names = FALSE, stringsAsFactors = FALSE)
audit <- utils::read.csv(audit_summary_path, check.names = FALSE, stringsAsFactors = FALSE)
required_cell <- c(
  "family", "tau", "screening_profile_base", "screening_profile_id_representative",
  "forecast_mae_ratio_vs_best_vb_baseline", "forecast_pinball_ratio_vs_best_vb_baseline",
  "fit_rmse_ratio_vs_best_vb_baseline", "fit_pinball_ratio_vs_best_vb_baseline",
  "D", "n_each", "alpha", "rho", "m", "readout_y_lags", "reservoir_lags", "pi_w", "pi_in"
)
missing_cell <- setdiff(required_cell, names(cell))
if (length(missing_cell)) stop(sprintf("Cell summary missing column(s): %s", paste(missing_cell, collapse = ", ")), call. = FALSE)
required_fit <- c("family", "tau", "screening_profile_id", "screening_profile_base", "status", "comparison_eligible", "rhs_tau0")
missing_fit <- setdiff(required_fit, names(fit))
if (length(missing_fit)) stop(sprintf("Fit summary missing column(s): %s", paste(missing_fit, collapse = ", ")), call. = FALSE)
if (nrow(audit) && "strict_ready" %in% names(audit) && !all(bool_value(audit$strict_ready))) {
  stop("Source audit is not strict-ready; refusing to materialize a follow-up screen.", call. = FALSE)
}

ratio_cols <- c(
  forecast_mae = "forecast_mae_ratio_vs_best_vb_baseline",
  forecast_check = "forecast_pinball_ratio_vs_best_vb_baseline",
  fit_rmse = "fit_rmse_ratio_vs_best_vb_baseline",
  fit_check = "fit_pinball_ratio_vs_best_vb_baseline"
)
for (nm in ratio_cols) cell[[nm]] <- as.numeric(cell[[nm]])
cell$primary_worst_ratio <- do.call(pmax, c(cell[ratio_cols], list(na.rm = TRUE)))
cell$family <- as.character(cell$family)
cell$tau <- as.numeric(cell$tau)
fit$family <- as.character(fit$family)
fit$tau <- as.numeric(fit$tau)
fit$status <- toupper(as.character(fit$status))
fit$comparison_eligible <- bool_value(fit$comparison_eligible)
fit <- fit[fit$status == "SUCCESS" & fit$comparison_eligible, , drop = FALSE]

row_by_metric <- function(df, metric_col) {
  vals <- as.numeric(df[[metric_col]])
  vals[!is.finite(vals)] <- Inf
  df[order(vals, df$primary_worst_ratio, df$screening_profile_base), , drop = FALSE][1L, , drop = FALSE]
}
fit_lookup <- function(r) {
  sub <- fit[
    fit$family == as.character(r$family[[1L]]) &
      abs(fit$tau - as.numeric(r$tau[[1L]])) < 1e-8 &
      (
        fit$screening_profile_id == as.character(r$screening_profile_id_representative[[1L]]) |
          fit$screening_profile_base == as.character(r$screening_profile_base[[1L]])
      ),
    ,
    drop = FALSE
  ]
  if (nrow(sub)) sub[1L, , drop = FALSE] else NULL
}
get_param <- function(r, f, nm, default) {
  if (!is.null(f) && nm %in% names(f)) {
    val <- f[[nm]][[1L]]
    if (!is.na(val) && nzchar(as.character(val))) return(val)
  }
  if (nm %in% names(r)) {
    val <- r[[nm]][[1L]]
    if (!is.na(val) && nzchar(as.character(val))) return(val)
  }
  default
}
dimension_estimate <- function(D, n_each, readout_y_lags, add_bias = TRUE, x_feature_count = 5L) {
  D <- as.integer(D)
  n_each <- as.integer(n_each)
  n_tilde_each <- if (D > 1L) n_each else 0L
  as.integer(D * n_each + max(0L, D - 1L) * n_tilde_each + as.integer(readout_y_lags) + as.integer(isTRUE(add_bias)) + as.integer(x_feature_count))
}
profile_id <- function(family, tau, role, D, n_each, alpha, rho, m, reservoir_lags, pi_w, pi_in, rhs_tau0, seed) {
  paste0(
    "tt500vb_case_", cell_token(family, tau), "_", role,
    "_d", as.integer(D),
    "_n", as.integer(n_each),
    "_a", slug_num(alpha),
    "_r", slug_num(rho),
    "_m", as.integer(m),
    "_rl", as.integer(reservoir_lags),
    "_pw", slug_num(pi_w),
    "_pin", slug_num(pi_in),
    "_tau", slug_num(rhs_tau0),
    "_s", as.integer(seed)
  )
}
make_profile <- function(family, tau, role, source_row, source_metric, D, n_each, alpha, rho, m,
                         pi_w, pi_in, rhs_tau0, reservoir_lags = 0L, seed = 123L) {
  D <- as.integer(D)
  n_each <- as.integer(n_each)
  m <- as.integer(m)
  p_est <- dimension_estimate(D, n_each, m)
  source_value <- function(names, default = NA) {
    for (nm in names) {
      if (nm %in% colnames(source_row)) {
        val <- source_row[[nm]][[1L]]
        if (!is.na(val) && nzchar(as.character(val))) return(val)
      }
    }
    default
  }
  data.frame(
    screening_profile_id = profile_id(family, tau, role, D, n_each, alpha, rho, m, reservoir_lags, pi_w, pi_in, rhs_tau0, seed),
    screening_stage = screening_stage_label,
    screening_wave = screening_wave,
    profile_role = role,
    enabled = TRUE,
    D = D,
    n_each = n_each,
    n_tilde_each = if (D > 1L) n_each else 0L,
    m = m,
    alpha = as.numeric(alpha),
    rho = as.numeric(rho),
    pi_w = as.numeric(pi_w),
    pi_in = as.numeric(pi_in),
    washout = 300L,
    add_bias = TRUE,
    seed = as.integer(seed),
    readout_y_lags = m,
    reservoir_lags = as.integer(reservoir_lags),
    rhs_tau0 = as.numeric(rhs_tau0),
    dimension_p_estimate = p_est,
    p_over_n_tt500 = as.numeric(p_est) / 500,
    x_feature_count = 5L,
    target_family = as.character(family),
    target_tau = as.numeric(tau),
    target_source_metric = as.character(source_metric),
    target_source_profile = as.character(source_value(c("screening_profile_base", "target_source_profile", "screening_profile_id"), NA_character_)),
    target_source_representative = as.character(source_value(c("screening_profile_id_representative", "target_source_representative", "screening_profile_id"), NA_character_)),
    target_source_worst_ratio = finite_num(source_value(c("primary_worst_ratio", "target_source_worst_ratio"), NA_real_), NA_real_),
    target_source_fit_rmse_ratio = finite_num(source_value(c("fit_rmse_ratio_vs_best_vb_baseline", "target_source_fit_rmse_ratio"), NA_real_), NA_real_),
    target_source_fit_check_ratio = finite_num(source_value(c("fit_pinball_ratio_vs_best_vb_baseline", "target_source_fit_check_ratio"), NA_real_), NA_real_),
    target_source_forecast_mae_ratio = finite_num(source_value(c("forecast_mae_ratio_vs_best_vb_baseline", "target_source_forecast_mae_ratio"), NA_real_), NA_real_),
    target_source_forecast_check_ratio = finite_num(source_value(c("forecast_pinball_ratio_vs_best_vb_baseline", "target_source_forecast_check_ratio"), NA_real_), NA_real_),
    stringsAsFactors = FALSE
  )
}
profile_from_row <- function(r, role, metric) {
  f <- fit_lookup(r)
  make_profile(
    family = r$family[[1L]],
    tau = r$tau[[1L]],
    role = role,
    source_row = r,
    source_metric = metric,
    D = finite_int(get_param(r, f, "D", 1L), 1L),
    n_each = finite_int(get_param(r, f, "n_each", 20L), 20L),
    alpha = finite_num(get_param(r, f, "alpha", 0.02), 0.02),
    rho = finite_num(get_param(r, f, "rho", 0.45), 0.45),
    m = finite_int(get_param(r, f, "m", get_param(r, f, "readout_y_lags", 15L)), 15L),
    pi_w = finite_num(get_param(r, f, "pi_w", 0.03), 0.03),
    pi_in = finite_num(get_param(r, f, "pi_in", 0.30), 0.30),
    rhs_tau0 = finite_num(get_param(r, f, "rhs_tau0", 1e-4), 1e-4),
    reservoir_lags = finite_int(get_param(r, f, "reservoir_lags", 0L), 0L),
    seed = finite_int(get_param(r, f, "seed", 123L), 123L)
  )
}
classify_cell <- function(best) {
  ratios <- c(
    forecast_mae = finite_num(best$forecast_mae_ratio_vs_best_vb_baseline, NA_real_),
    forecast_check = finite_num(best$forecast_pinball_ratio_vs_best_vb_baseline, NA_real_),
    fit_rmse = finite_num(best$fit_rmse_ratio_vs_best_vb_baseline, NA_real_),
    fit_check = finite_num(best$fit_pinball_ratio_vs_best_vb_baseline, NA_real_)
  )
  worst <- max(ratios, na.rm = TRUE)
  bottleneck <- names(which.max(ratios))[[1L]]
  status <- if (!is.finite(worst)) {
    "unknown"
  } else if (isTRUE(is_fitrmse_v4plus) && identical(bottleneck, "forecast_mae") && ratios[["forecast_mae"]] >= 1.25) {
    "forecast_mae_hard"
  } else if (ratios[["fit_rmse"]] >= 1.75) {
    "fit_rmse_extreme"
  } else if (ratios[["fit_rmse"]] >= 1.25) {
    "fit_rmse_hard"
  } else if (worst >= 1.05) {
    "mixed_near"
  } else if (worst >= 1.00) {
    "near_pass"
  } else {
    "confirmation"
  }
  list(status = status, bottleneck = bottleneck, worst = worst, ratios = ratios)
}
target_n_for_status <- function(status) {
  base <- if (isTRUE(is_fitrmse_v50)) {
    switch(as.character(status)[1L],
      forecast_mae_hard = 72L,
      fit_rmse_extreme = 72L,
      fit_rmse_hard = 72L,
      mixed_near = 64L,
      near_pass = 60L,
      confirmation = 32L,
      64L
    )
  } else if (isTRUE(is_fitrmse_v49)) {
    switch(as.character(status)[1L],
      forecast_mae_hard = 56L,
      fit_rmse_extreme = 56L,
      fit_rmse_hard = 56L,
      mixed_near = 52L,
      near_pass = 48L,
      confirmation = 28L,
      52L
    )
  } else if (isTRUE(is_fitrmse_v48plus)) {
    switch(as.character(status)[1L],
      forecast_mae_hard = 48L,
      fit_rmse_extreme = 48L,
      fit_rmse_hard = 48L,
      mixed_near = 42L,
      near_pass = 40L,
      confirmation = 24L,
      42L
    )
  } else if (isTRUE(is_fitrmse_v47)) {
    switch(as.character(status)[1L],
      forecast_mae_hard = 36L,
      fit_rmse_extreme = 36L,
      fit_rmse_hard = 36L,
      mixed_near = 32L,
      near_pass = 30L,
      confirmation = 20L,
      32L
    )
  } else if (isTRUE(is_fitrmse_v46)) {
    switch(as.character(status)[1L],
      forecast_mae_hard = 28L,
      fit_rmse_extreme = 28L,
      fit_rmse_hard = 28L,
      mixed_near = 24L,
      near_pass = 22L,
      confirmation = 16L,
      24L
    )
  } else if (isTRUE(is_fitrmse_v45)) {
    switch(as.character(status)[1L],
      forecast_mae_hard = 36L,
      fit_rmse_extreme = 36L,
      fit_rmse_hard = 36L,
      mixed_near = 34L,
      near_pass = 32L,
      confirmation = 20L,
      32L
    )
  } else if (isTRUE(is_fitrmse_v4)) {
    switch(as.character(status)[1L],
      forecast_mae_hard = 28L,
      fit_rmse_extreme = 28L,
      fit_rmse_hard = 28L,
      mixed_near = 26L,
      near_pass = 24L,
      confirmation = 20L,
      24L
    )
  } else if (isTRUE(is_fitrmse_v3)) {
    switch(as.character(status)[1L],
      fit_rmse_extreme = 34L,
      fit_rmse_hard = 34L,
      mixed_near = 32L,
      near_pass = 28L,
      confirmation = 24L,
      30L
    )
  } else {
    switch(as.character(status)[1L],
      fit_rmse_extreme = 32L,
      fit_rmse_hard = 30L,
      mixed_near = 26L,
      near_pass = 22L,
      confirmation = 18L,
      24L
    )
  }
  min(as.integer(max_profiles_per_cell), base)
}
role_quota <- function(status, target_n) {
  desired <- if (isTRUE(is_fitrmse_v50)) {
    switch(as.character(status)[1L],
      forecast_mae_hard = c(anchor = 5L, forecast_mae_rescue = 17L, forecast_guardrail = 13L, forecast_hybrid = 10L, memory_guardrail = 8L, structural_bridge = 6L, local_fit = 5L, fit_check_bridge = 4L, seed_check = 2L, fit_micro = 2L),
      fit_rmse_extreme = c(anchor = 5L, structural_bridge = 14L, short_memory_rescue = 12L, fit_micro = 10L, fit_compact = 9L, local_fit = 8L, fit_check_bridge = 6L, fit_check_guardrail = 4L, shrinkage = 3L, forecast_guardrail = 1L),
      fit_rmse_hard = c(anchor = 5L, structural_bridge = 14L, short_memory_rescue = 12L, fit_micro = 10L, fit_compact = 9L, local_fit = 8L, fit_check_bridge = 6L, fit_check_guardrail = 4L, shrinkage = 3L, forecast_guardrail = 1L),
      mixed_near = c(anchor = 5L, fit_check_bridge = 14L, fit_check_hybrid = 10L, fit_check_guardrail = 9L, structural_bridge = 8L, local_fit = 7L, forecast_mae_rescue = 5L, fit_micro = 4L, seed_check = 2L),
      near_pass = c(anchor = 5L, fit_check_bridge = 14L, fit_check_hybrid = 10L, fit_check_guardrail = 9L, structural_bridge = 7L, local_fit = 6L, forecast_mae_rescue = 4L, fit_micro = 3L, seed_check = 2L),
      confirmation = c(anchor = 5L, fit_check_bridge = 8L, fit_check_guardrail = 6L, structural_bridge = 5L, forecast_mae_rescue = 4L, local_fit = 3L, seed_check = 1L),
      c(anchor = 5L, fit_check_bridge = 12L, structural_bridge = 10L, forecast_mae_rescue = 8L, local_fit = 7L, fit_micro = 5L, fit_compact = 5L, fit_check_guardrail = 5L, seed_check = 2L)
    )
  } else if (isTRUE(is_fitrmse_v49)) {
    switch(as.character(status)[1L],
      forecast_mae_hard = c(anchor = 5L, forecast_guardrail = 14L, forecast_hybrid = 10L, memory_guardrail = 10L, local_fit = 7L, fit_check_guardrail = 5L, fit_micro = 3L, fit_compact = 2L),
      fit_rmse_extreme = c(anchor = 5L, fit_micro = 11L, fit_compact = 11L, local_fit = 9L, fit_check_guardrail = 7L, fit_check_hybrid = 6L, shrinkage = 5L, forecast_guardrail = 2L),
      fit_rmse_hard = c(anchor = 5L, fit_micro = 11L, fit_compact = 11L, local_fit = 9L, fit_check_guardrail = 7L, fit_check_hybrid = 6L, shrinkage = 5L, forecast_guardrail = 2L),
      mixed_near = c(anchor = 5L, fit_check_guardrail = 10L, fit_check_hybrid = 10L, local_fit = 8L, fit_micro = 6L, fit_compact = 5L, forecast_guardrail = 4L, seed_check = 2L),
      near_pass = c(anchor = 5L, fit_check_guardrail = 10L, fit_check_hybrid = 9L, local_fit = 7L, fit_micro = 6L, fit_compact = 5L, forecast_guardrail = 4L, seed_check = 2L),
      confirmation = c(anchor = 5L, fit_check_guardrail = 6L, fit_check_hybrid = 5L, local_fit = 5L, forecast_guardrail = 4L, seed_check = 2L, fit_micro = 2L),
      c(anchor = 5L, fit_check_guardrail = 9L, fit_check_hybrid = 9L, local_fit = 8L, fit_micro = 7L, fit_compact = 6L, forecast_guardrail = 4L, seed_check = 2L)
    )
  } else if (isTRUE(is_fitrmse_v48plus)) {
    switch(as.character(status)[1L],
      forecast_mae_hard = c(anchor = 5L, forecast_guardrail = 12L, forecast_hybrid = 8L, memory_guardrail = 8L, local_fit = 6L, fit_check_guardrail = 4L, fit_micro = 3L, fit_compact = 2L),
      fit_rmse_extreme = c(anchor = 5L, fit_micro = 9L, fit_compact = 9L, local_fit = 8L, fit_check_guardrail = 6L, fit_check_hybrid = 5L, shrinkage = 4L, forecast_guardrail = 2L),
      fit_rmse_hard = c(anchor = 5L, fit_micro = 9L, fit_compact = 9L, local_fit = 8L, fit_check_guardrail = 6L, fit_check_hybrid = 5L, shrinkage = 4L, forecast_guardrail = 2L),
      mixed_near = c(anchor = 5L, fit_check_guardrail = 8L, fit_check_hybrid = 8L, local_fit = 7L, fit_micro = 5L, fit_compact = 4L, forecast_guardrail = 3L, seed_check = 2L),
      near_pass = c(anchor = 5L, fit_check_guardrail = 8L, fit_check_hybrid = 8L, local_fit = 6L, fit_micro = 5L, fit_compact = 4L, forecast_guardrail = 3L, seed_check = 1L),
      confirmation = c(anchor = 5L, fit_check_guardrail = 5L, fit_check_hybrid = 4L, local_fit = 4L, forecast_guardrail = 3L, seed_check = 2L, fit_micro = 1L),
      c(anchor = 5L, fit_check_guardrail = 7L, fit_check_hybrid = 7L, local_fit = 7L, fit_micro = 6L, fit_compact = 5L, forecast_guardrail = 4L, seed_check = 1L)
    )
  } else if (isTRUE(is_fitrmse_v47)) {
    switch(as.character(status)[1L],
      forecast_mae_hard = c(anchor = 5L, forecast_guardrail = 10L, memory_guardrail = 8L, fit_check_guardrail = 4L, local_fit = 4L, fit_micro = 3L, fit_compact = 2L),
      fit_rmse_extreme = c(anchor = 5L, fit_micro = 7L, fit_compact = 7L, local_fit = 6L, fit_check_guardrail = 5L, shrinkage = 4L, forecast_guardrail = 2L),
      fit_rmse_hard = c(anchor = 5L, fit_micro = 7L, fit_compact = 7L, local_fit = 6L, fit_check_guardrail = 5L, shrinkage = 4L, forecast_guardrail = 2L),
      mixed_near = c(anchor = 5L, fit_check_guardrail = 8L, local_fit = 6L, fit_micro = 4L, fit_compact = 4L, forecast_guardrail = 3L, seed_check = 2L),
      near_pass = c(anchor = 5L, fit_check_guardrail = 8L, local_fit = 6L, fit_micro = 4L, fit_compact = 4L, forecast_guardrail = 2L, seed_check = 1L),
      confirmation = c(anchor = 5L, fit_check_guardrail = 5L, local_fit = 4L, forecast_guardrail = 3L, seed_check = 2L, fit_micro = 1L),
      c(anchor = 5L, fit_check_guardrail = 6L, local_fit = 6L, fit_micro = 5L, fit_compact = 5L, forecast_guardrail = 3L)
    )
  } else if (isTRUE(is_fitrmse_v46)) {
    switch(as.character(status)[1L],
      forecast_mae_hard = c(anchor = 5L, forecast_guardrail = 9L, memory_guardrail = 6L, local_fit = 4L, fit_micro = 2L, fit_compact = 2L),
      fit_rmse_extreme = c(anchor = 5L, fit_micro = 7L, fit_compact = 7L, local_fit = 5L, shrinkage = 3L, memory_guardrail = 1L),
      fit_rmse_hard = c(anchor = 5L, fit_micro = 7L, fit_compact = 7L, local_fit = 5L, shrinkage = 3L, forecast_guardrail = 1L),
      mixed_near = c(anchor = 5L, local_fit = 6L, fit_micro = 4L, fit_compact = 4L, forecast_guardrail = 3L, seed_check = 2L),
      near_pass = c(anchor = 5L, local_fit = 5L, fit_micro = 4L, fit_compact = 4L, forecast_guardrail = 2L, seed_check = 2L),
      confirmation = c(anchor = 5L, local_fit = 4L, forecast_guardrail = 3L, seed_check = 2L, fit_micro = 2L),
      c(anchor = 5L, fit_micro = 5L, local_fit = 5L, fit_compact = 5L, forecast_guardrail = 3L)
    )
  } else if (isTRUE(is_fitrmse_v45)) {
    switch(as.character(status)[1L],
      forecast_mae_hard = c(anchor = 5L, forecast_guardrail = 10L, memory_guardrail = 8L, local_fit = 5L, fit_micro = 4L, fit_compact = 4L),
      fit_rmse_extreme = c(anchor = 5L, fit_micro = 9L, fit_compact = 9L, local_fit = 7L, shrinkage = 4L, forecast_guardrail = 2L),
      fit_rmse_hard = c(anchor = 5L, fit_micro = 8L, fit_compact = 8L, local_fit = 7L, shrinkage = 4L, memory_guardrail = 2L, forecast_guardrail = 2L),
      mixed_near = c(anchor = 5L, fit_micro = 6L, fit_compact = 6L, local_fit = 8L, forecast_guardrail = 5L, seed_check = 4L),
      near_pass = c(anchor = 5L, fit_micro = 5L, fit_compact = 5L, local_fit = 8L, forecast_guardrail = 5L, seed_check = 4L),
      confirmation = c(anchor = 5L, local_fit = 5L, forecast_guardrail = 4L, seed_check = 4L, fit_micro = 2L),
      c(anchor = 5L, fit_micro = 7L, local_fit = 8L, fit_compact = 7L, forecast_guardrail = 5L)
    )
  } else if (isTRUE(is_fitrmse_v4)) {
    switch(as.character(status)[1L],
      forecast_mae_hard = c(anchor = 5L, forecast_guardrail = 8L, memory_guardrail = 6L, local_fit = 4L, fit_micro = 3L, fit_compact = 2L),
      fit_rmse_extreme = c(anchor = 5L, fit_micro = 8L, fit_compact = 8L, local_fit = 5L, shrinkage = 2L),
      fit_rmse_hard = c(anchor = 5L, fit_micro = 7L, fit_compact = 7L, local_fit = 6L, shrinkage = 2L, forecast_guardrail = 1L),
      mixed_near = c(anchor = 5L, fit_micro = 5L, fit_compact = 5L, local_fit = 6L, forecast_guardrail = 4L, seed_check = 1L),
      near_pass = c(anchor = 5L, fit_micro = 4L, local_fit = 6L, forecast_guardrail = 5L, seed_check = 4L),
      confirmation = c(anchor = 5L, local_fit = 5L, forecast_guardrail = 4L, seed_check = 4L, fit_micro = 2L),
      c(anchor = 5L, fit_micro = 6L, local_fit = 6L, fit_compact = 5L, forecast_guardrail = 2L)
    )
  } else if (isTRUE(is_fitrmse_v3)) {
    switch(as.character(status)[1L],
      fit_rmse_extreme = c(anchor = 5L, fit_micro = 8L, fit_compact = 9L, local_fit = 6L, shrinkage = 4L, forecast_guardrail = 2L),
      fit_rmse_hard = c(anchor = 5L, fit_micro = 7L, fit_compact = 8L, local_fit = 7L, shrinkage = 4L, forecast_guardrail = 3L),
      mixed_near = c(anchor = 5L, fit_micro = 5L, local_fit = 9L, fit_compact = 5L, forecast_guardrail = 5L, seed_check = 3L),
      near_pass = c(anchor = 5L, fit_micro = 4L, local_fit = 8L, forecast_guardrail = 6L, seed_check = 5L),
      confirmation = c(anchor = 5L, local_fit = 6L, forecast_guardrail = 5L, seed_check = 4L, fit_micro = 4L),
      c(anchor = 5L, fit_micro = 6L, local_fit = 8L, fit_compact = 6L, forecast_guardrail = 5L)
    )
  } else {
    switch(as.character(status)[1L],
      fit_rmse_extreme = c(anchor = 5L, fit_compact = 9L, local_fit = 7L, shrinkage = 5L, memory_guardrail = 4L, forecast_guardrail = 2L),
      fit_rmse_hard = c(anchor = 5L, fit_compact = 8L, local_fit = 7L, shrinkage = 4L, memory_guardrail = 4L, forecast_guardrail = 2L),
      mixed_near = c(anchor = 5L, local_fit = 8L, fit_compact = 5L, forecast_guardrail = 5L, memory_guardrail = 3L),
      near_pass = c(anchor = 5L, local_fit = 8L, forecast_guardrail = 5L, seed_check = 4L),
      confirmation = c(anchor = 5L, local_fit = 5L, forecast_guardrail = 4L, seed_check = 4L),
      c(anchor = 5L, local_fit = 8L, fit_compact = 6L, forecast_guardrail = 5L)
    )
  }
  target_n <- as.integer(target_n)[1L]
  if (sum(desired) <= target_n) return(desired)
  out <- pmax(1L, floor(desired * target_n / sum(desired)))
  while (sum(out) < target_n) {
    room <- desired - out
    if (!any(room > 0L)) break
    out[[which.max(room)]] <- out[[which.max(room)]] + 1L
  }
  while (sum(out) > target_n) {
    j <- which.max(out)
    out[[j]] <- out[[j]] - 1L
  }
  out[out > 0L]
}
candidate_pool_for_cell <- function(sub) {
  best_fit <- row_by_metric(sub, "fit_rmse_ratio_vs_best_vb_baseline")
  best_fit_check <- row_by_metric(sub, "fit_pinball_ratio_vs_best_vb_baseline")
  best_mae <- row_by_metric(sub, "forecast_mae_ratio_vs_best_vb_baseline")
  best_check <- row_by_metric(sub, "forecast_pinball_ratio_vs_best_vb_baseline")
  best_joint <- row_by_metric(sub, "primary_worst_ratio")
  class <- classify_cell(best_joint)
  family <- as.character(best_joint$family[[1L]])
  tau <- as.numeric(best_joint$tau[[1L]])
  target_n <- target_n_for_status(class$status)

  anchors <- bind_rows(list(
    profile_from_row(best_fit, "anchor_fit_rmse", "fit_rmse"),
    profile_from_row(best_fit_check, "anchor_fit_check", "fit_check"),
    profile_from_row(best_mae, "anchor_forecast_mae", "forecast_mae"),
    profile_from_row(best_check, "anchor_forecast_check", "forecast_check"),
    profile_from_row(best_joint, "anchor_balanced", "joint")
  ))
  anchor_fit <- anchors[anchors$profile_role == "anchor_fit_rmse", , drop = FALSE][1L, , drop = FALSE]
  anchor_fit_check <- anchors[anchors$profile_role == "anchor_fit_check", , drop = FALSE][1L, , drop = FALSE]
  anchor_forecast <- anchors[anchors$profile_role == "anchor_forecast_check", , drop = FALSE][1L, , drop = FALSE]
  anchor_tune <- if (isTRUE(is_fitrmse_v47plus) && identical(class$bottleneck, "fit_check")) {
    anchor_fit_check
  } else if (isTRUE(is_fitrmse_v47plus) && identical(class$status, "forecast_mae_hard")) {
    anchor_forecast
  } else {
    anchor_fit
  }

  alpha_grid <- if (isTRUE(is_fitrmse_v50)) {
    c(0.00002, 0.00003, 0.00004, 0.00005, 0.00006, 0.000075, 0.00008, 0.0001, 0.0002, 0.0003, 0.0005, 0.0006, 0.00075, 0.0009, 0.001, 0.0012, 0.0015, 0.002, 0.0025, 0.0035, 0.005, 0.0075, 0.01, 0.015, 0.02, 0.025, 0.03, 0.05, 0.08, 0.10, 0.12, 0.20, 0.30, 0.40, 0.50, 0.60)
  } else if (isTRUE(is_fitrmse_v48plus)) {
    c(0.00003, 0.00005, 0.000075, 0.0001, 0.0002, 0.0003, 0.0005, 0.0006, 0.00075, 0.0009, 0.001, 0.0012, 0.0015, 0.002, 0.0025, 0.0035, 0.005, 0.0075, 0.01, 0.015, 0.02, 0.025, 0.03, 0.05, 0.08, 0.12, 0.20, 0.30, 0.40, 0.50)
  } else if (isTRUE(is_fitrmse_v47)) {
    c(0.00003, 0.00005, 0.000075, 0.0001, 0.0002, 0.0003, 0.0005, 0.00075, 0.001, 0.0015, 0.0025, 0.0035, 0.005, 0.0075, 0.01, 0.02, 0.03, 0.05, 0.08, 0.12, 0.20, 0.30, 0.40, 0.50)
  } else if (isTRUE(is_fitrmse_v46)) {
    c(0.00005, 0.000075, 0.0001, 0.0002, 0.0003, 0.0005, 0.00075, 0.001, 0.0015, 0.0025, 0.0035, 0.005, 0.0075, 0.01, 0.02, 0.03, 0.05, 0.08, 0.12, 0.20, 0.30)
  } else if (isTRUE(is_fitrmse_v45)) {
    c(0.00005, 0.0001, 0.0002, 0.0003, 0.0005, 0.00075, 0.001, 0.0015, 0.0025, 0.0035, 0.005, 0.0075, 0.01, 0.02, 0.03, 0.05, 0.08, 0.12, 0.20, 0.30)
  } else if (isTRUE(is_fitrmse_v4)) {
    c(0.0001, 0.0002, 0.0003, 0.0005, 0.00075, 0.001, 0.0015, 0.0025, 0.0035, 0.005, 0.0075, 0.01, 0.02, 0.03, 0.05, 0.08, 0.12, 0.20, 0.30)
  } else if (isTRUE(is_fitrmse_v3)) {
    c(0.0003, 0.0005, 0.00075, 0.001, 0.0015, 0.0025, 0.005, 0.01, 0.02, 0.03, 0.05, 0.08, 0.12, 0.20, 0.30, 0.40)
  } else {
    c(0.00075, 0.001, 0.0015, 0.0025, 0.005, 0.01, 0.02, 0.03, 0.05, 0.08, 0.12, 0.20, 0.30, 0.40)
  }
  rho_grid <- if (isTRUE(is_fitrmse_v50)) {
    c(0.02, 0.05, 0.08, 0.10, 0.15, 0.20, 0.25, 0.30, 0.32, 0.35, 0.36, 0.38, 0.40, 0.42, 0.44, 0.45, 0.48, 0.50, 0.52, 0.55, 0.58, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.88, 0.90, 0.95)
  } else if (isTRUE(is_fitrmse_v48plus)) {
    c(0.02, 0.05, 0.08, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.38, 0.40, 0.42, 0.45, 0.48, 0.50, 0.52, 0.55, 0.60, 0.65, 0.70, 0.80, 0.85, 0.90, 0.95)
  } else if (isTRUE(is_fitrmse_v47)) {
    c(0.02, 0.05, 0.08, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.70, 0.80, 0.85, 0.90, 0.95)
  } else if (isTRUE(is_fitrmse_v46)) {
    c(0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.70, 0.80, 0.85, 0.90)
  } else if (isTRUE(is_fitrmse_v45)) {
    c(0.01, 0.02, 0.05, 0.08, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.60, 0.70, 0.80, 0.85, 0.90)
  } else if (isTRUE(is_fitrmse_v4)) {
    c(0.02, 0.05, 0.08, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.45, 0.50, 0.60, 0.70, 0.80, 0.85, 0.90)
  } else if (isTRUE(is_fitrmse_v3)) {
    c(0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.45, 0.50, 0.60, 0.70, 0.80, 0.85, 0.90)
  } else {
    c(0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.45, 0.50, 0.60, 0.70, 0.80, 0.85, 0.90)
  }
  memory_grid <- if (isTRUE(is_fitrmse_v50)) c(1L, 2L, 3L, 4L, 5L, 6L, 7L, 8L, 9L, 10L, 12L, 15L, 16L, 18L, 20L, 24L, 25L, 30L, 35L, 36L, 45L, 60L, 75L, 90L, 105L, 120L, 150L) else if (isTRUE(is_fitrmse_v48plus)) c(1L, 2L, 3L, 5L, 6L, 8L, 10L, 12L, 15L, 16L, 20L, 24L, 30L, 36L, 45L, 60L, 90L, 120L, 150L) else if (isTRUE(is_fitrmse_v47)) c(1L, 2L, 3L, 5L, 8L, 10L, 12L, 15L, 20L, 30L, 45L, 60L, 90L, 120L, 150L) else if (isTRUE(is_fitrmse_v46)) c(1L, 2L, 3L, 5L, 8L, 10L, 12L, 15L, 20L, 30L, 45L, 60L, 90L, 120L) else if (isTRUE(is_fitrmse_v45)) c(1L, 2L, 3L, 5L, 8L, 10L, 12L, 15L, 20L, 30L, 45L, 60L, 90L) else if (isTRUE(is_fitrmse_v4)) c(1L, 2L, 3L, 5L, 8L, 10L, 12L, 15L, 20L, 30L, 45L, 60L, 90L) else if (isTRUE(is_fitrmse_v3)) c(3L, 5L, 10L, 15L, 20L, 30L, 45L, 60L, 90L) else c(5L, 10L, 15L, 20L, 30L, 45L, 60L, 90L)
  tau0_grid <- if (isTRUE(is_fitrmse_v50)) c(1e-7, 3e-7, 5e-7, 1e-6, 3e-6, 1e-5, 3e-5, 5e-5, 1e-4, 3e-4, 5e-4, 1e-3, 3e-3, 1e-2, 3e-2) else if (isTRUE(is_fitrmse_v48plus)) c(3e-7, 1e-6, 3e-6, 1e-5, 3e-5, 1e-4, 3e-4, 1e-3, 3e-3, 1e-2, 3e-2) else if (isTRUE(is_fitrmse_v47)) c(3e-7, 1e-6, 3e-6, 1e-5, 3e-5, 1e-4, 3e-4, 1e-3, 3e-3, 1e-2, 3e-2) else if (isTRUE(is_fitrmse_v46)) c(1e-6, 3e-6, 1e-5, 3e-5, 1e-4, 3e-4, 1e-3, 3e-3, 1e-2) else if (isTRUE(is_fitrmse_v45)) c(1e-6, 3e-6, 1e-5, 3e-5, 1e-4, 3e-4, 1e-3, 3e-3, 1e-2) else if (isTRUE(is_fitrmse_v4)) c(3e-6, 1e-5, 3e-5, 1e-4, 3e-4, 1e-3, 3e-3) else if (isTRUE(is_fitrmse_v3)) c(1e-5, 3e-5, 1e-4, 3e-4, 1e-3, 3e-3) else c(1e-4, 3e-4, 1e-3, 3e-3)
  sparse_grid <- if (isTRUE(is_fitrmse_v50)) {
    data.frame(
      pi_w = c(0.00025, 0.0005, 0.00075, 0.001, 0.002, 0.0025, 0.005, 0.0075, 0.01, 0.0125, 0.015, 0.02, 0.025, 0.03, 0.04, 0.05, 0.075, 0.08, 0.10, 0.12, 0.15),
      pi_in = c(0.015, 0.02, 0.03, 0.04, 0.05, 0.075, 0.10, 0.15, 0.20, 0.25, 0.25, 0.20, 0.30, 0.30, 0.40, 0.35, 0.45, 0.50, 0.60, 0.70, 0.80)
    )
  } else if (isTRUE(is_fitrmse_v48plus)) {
    data.frame(
      pi_w = c(0.0005, 0.001, 0.0025, 0.005, 0.01, 0.015, 0.02, 0.025, 0.03, 0.04, 0.05, 0.08, 0.10, 0.15),
      pi_in = c(0.02, 0.03, 0.05, 0.10, 0.20, 0.25, 0.20, 0.30, 0.30, 0.40, 0.30, 0.50, 0.60, 0.80)
    )
  } else if (isTRUE(is_fitrmse_v47)) {
    data.frame(
      pi_w = c(0.0005, 0.001, 0.0025, 0.005, 0.01, 0.02, 0.03, 0.05, 0.08, 0.10, 0.15),
      pi_in = c(0.02, 0.03, 0.05, 0.10, 0.20, 0.20, 0.30, 0.30, 0.50, 0.60, 0.80)
    )
  } else if (isTRUE(is_fitrmse_v46)) {
    data.frame(
      pi_w = c(0.0005, 0.001, 0.0025, 0.005, 0.01, 0.02, 0.03, 0.05),
      pi_in = c(0.02, 0.03, 0.05, 0.10, 0.20, 0.20, 0.30, 0.30)
    )
  } else if (isTRUE(is_fitrmse_v45)) {
    data.frame(
      pi_w = c(0.0005, 0.001, 0.0025, 0.005, 0.01, 0.02, 0.03, 0.05, 0.08),
      pi_in = c(0.02, 0.03, 0.05, 0.10, 0.20, 0.20, 0.30, 0.30, 0.50)
    )
  } else if (isTRUE(is_fitrmse_v4)) {
    data.frame(
      pi_w = c(0.001, 0.0025, 0.005, 0.01, 0.02, 0.03, 0.05, 0.08),
      pi_in = c(0.03, 0.05, 0.10, 0.20, 0.20, 0.30, 0.30, 0.50)
    )
  } else if (isTRUE(is_fitrmse_v3)) {
    data.frame(
      pi_w = c(0.0025, 0.005, 0.01, 0.02, 0.03, 0.05, 0.08),
      pi_in = c(0.05, 0.10, 0.20, 0.20, 0.30, 0.30, 0.50)
    )
  } else {
    data.frame(pi_w = c(0.005, 0.01, 0.02, 0.03, 0.05, 0.08), pi_in = c(0.10, 0.20, 0.20, 0.30, 0.30, 0.50))
  }

  local_depth <- unique(pmax(1L, pmin(3L, c(anchor_tune$D - 1L, anchor_tune$D, anchor_tune$D + 1L, 1L, 2L))))
  local_n_cap <- if (isTRUE(is_fitrmse_v50)) 100L else if (isTRUE(is_fitrmse_v49)) 80L else if (isTRUE(is_fitrmse_v48plus)) 70L else if (isTRUE(is_fitrmse_v47)) 60L else 50L
  local_n <- sort(unique(pmax(8L, pmin(local_n_cap, c(anchor_tune$n_each - 10L, anchor_tune$n_each - 5L, anchor_tune$n_each, anchor_tune$n_each + 5L, anchor_tune$n_each + 10L, 10L, 15L, 20L, 30L)))))
  if (isTRUE(is_fitrmse_followup)) {
    local_depth <- sort(unique(pmax(1L, pmin(3L, c(local_depth, 1L, 2L, 3L)))))
    local_n <- sort(unique(pmax(if (isTRUE(is_fitrmse_v4plus)) 4L else 6L, pmin(local_n_cap, c(local_n, 4L, 6L, 8L, 10L, 12L, 15L, 20L, 25L, 30L, 40L, 50L, 60L)))))
  }
  local_alpha <- nearest_values(anchor_tune$alpha, alpha_grid, if (isTRUE(is_fitrmse_v47plus)) 7L else 5L)
  local_rho <- nearest_values(anchor_tune$rho, rho_grid, if (isTRUE(is_fitrmse_v47plus)) 7L else 5L)
  local_m <- sort(unique(c(nearest_values(anchor_tune$m, memory_grid, if (isTRUE(is_fitrmse_v47plus)) 6L else 4L), 15L, 30L)))
  if (isTRUE(is_fitrmse_v50)) local_m <- sort(unique(c(local_m, 1L, 2L, 3L, 4L, 5L, 6L, 7L, 8L, 9L, 10L, 12L, 15L, 16L, 18L, 20L, 24L, 25L, 30L, 35L, 36L, 45L, 60L, 75L, 90L, 105L, 120L, 150L)))
  if (isTRUE(is_fitrmse_v48plus)) local_m <- sort(unique(c(local_m, 1L, 2L, 3L, 5L, 6L, 8L, 10L, 12L, 15L, 16L, 20L, 24L, 30L, 36L, 45L, 60L, 90L, 120L, 150L)))
  if (isTRUE(is_fitrmse_v47)) local_m <- sort(unique(c(local_m, 1L, 2L, 3L, 5L, 8L, 10L, 12L, 15L, 20L, 30L, 45L, 60L, 90L, 120L, 150L)))
  if (isTRUE(is_fitrmse_v46)) local_m <- sort(unique(c(local_m, 1L, 2L, 3L, 5L, 8L, 10L, 12L, 15L, 20L, 30L, 45L, 60L)))
  if (isTRUE(is_fitrmse_v45)) local_m <- sort(unique(c(local_m, 1L, 2L, 3L, 5L, 8L, 10L, 12L, 15L, 20L, 30L, 45L)))
  if (isTRUE(is_fitrmse_v4)) local_m <- sort(unique(c(local_m, 1L, 2L, 3L, 5L, 8L, 10L, 12L, 20L)))
  if (isTRUE(is_fitrmse_v3)) local_m <- sort(unique(c(local_m, 3L, 5L, 10L, 20L)))
  if (identical(family, "gausmix") || (identical(family, "laplace") && tau <= 0.05) || (isTRUE(is_fitrmse_v47plus) && identical(family, "normal") && abs(tau - 0.5) < 1e-8)) {
    local_m <- sort(unique(c(local_m, 60L, 90L)))
  }
  if (isTRUE(is_fitrmse_v47plus) && (tau <= 0.05 || (identical(family, "normal") && abs(tau - 0.5) < 1e-8))) {
    local_m <- sort(unique(c(local_m, 120L, 150L)))
  }
  local_tau0 <- if (isTRUE(is_fitrmse_v50)) {
    sort(unique(c(nearest_values(anchor_tune$rhs_tau0, tau0_grid, 8L), 1e-7, 5e-7, 1e-6, 3e-6, 1e-5, 3e-5, 5e-5, 1e-4, 3e-4, 5e-4, 1e-3)))
  } else if (isTRUE(is_fitrmse_v48plus)) {
    sort(unique(c(nearest_values(anchor_tune$rhs_tau0, tau0_grid, 7L), 1e-6, 3e-6, 1e-5, 3e-5, 1e-4, 3e-4, 1e-3)))
  } else if (isTRUE(is_fitrmse_v47)) {
    sort(unique(c(nearest_values(anchor_tune$rhs_tau0, tau0_grid, 7L), 3e-7, 1e-6, 3e-6, 1e-5, 3e-5, 1e-4, 3e-4, 1e-3, 3e-3)))
  } else if (isTRUE(is_fitrmse_v46)) {
    sort(unique(c(nearest_values(anchor_fit$rhs_tau0, tau0_grid, 5L), 3e-6, 1e-5, 3e-5, 1e-4, 3e-4, 1e-3)))
  } else if (isTRUE(is_fitrmse_v45)) {
    sort(unique(c(nearest_values(anchor_fit$rhs_tau0, tau0_grid, 5L), 3e-6, 1e-5, 3e-5, 1e-4, 3e-4, 1e-3)))
  } else if (isTRUE(is_fitrmse_v4)) {
    sort(unique(c(nearest_values(anchor_fit$rhs_tau0, tau0_grid, 4L), 1e-5, 3e-5, 1e-4, 3e-4)))
  } else {
    c(1e-4, 3e-4, 1e-3)
  }

  generated <- list()
  add_grid <- function(role, D_vals, n_vals, alpha_vals, rho_vals, m_vals, tau0_vals, sparse_rows,
                       seed_vals = 123L, source = anchor_fit, pool_limit = 80L) {
    score_source <- source
    if (!is.data.frame(score_source) || !nrow(score_source)) score_source <- anchor_fit
    if (isTRUE(is_fitrmse_v48plus)) {
      cap_near <- function(vals, center, max_n) {
        vals <- sort(unique(vals))
        if (length(vals) <= max_n) return(vals)
        nearest_values(center, vals, max_n)
      }
      cap_sparse <- function(rows, source_row, max_n) {
        if (!nrow(rows) || nrow(rows) <= max_n) return(rows)
        score <- abs(as.numeric(rows$pi_w) - as.numeric(source_row$pi_w)) +
          abs(as.numeric(rows$pi_in) - as.numeric(source_row$pi_in))
        rows[order(score, rows$pi_w, rows$pi_in)[seq_len(max_n)], , drop = FALSE]
      }
      role_caps <- switch(as.character(role)[1L],
        structural_bridge = c(D = 2L, n = 12L, alpha = 9L, rho = 9L, m = 9L, tau0 = 7L, sparse = 5L),
        short_memory_rescue = c(D = 2L, n = 12L, alpha = 9L, rho = 8L, m = 8L, tau0 = 7L, sparse = 5L),
        forecast_mae_rescue = c(D = 3L, n = 10L, alpha = 8L, rho = 8L, m = 9L, tau0 = 6L, sparse = 5L),
        fit_check_bridge = c(D = 3L, n = 10L, alpha = 8L, rho = 8L, m = 9L, tau0 = 7L, sparse = 5L),
        fit_micro = c(D = 2L, n = 9L, alpha = 8L, rho = 8L, m = 8L, tau0 = 6L, sparse = 4L),
        fit_compact = c(D = 2L, n = 9L, alpha = 8L, rho = 8L, m = 8L, tau0 = 6L, sparse = 4L),
        local_fit = c(D = 3L, n = 10L, alpha = 5L, rho = 5L, m = 8L, tau0 = 5L, sparse = 4L),
        fit_check_guardrail = c(D = 3L, n = 8L, alpha = 5L, rho = 5L, m = 8L, tau0 = 5L, sparse = 4L),
        fit_check_hybrid = c(D = 3L, n = 8L, alpha = 5L, rho = 5L, m = 8L, tau0 = 5L, sparse = 4L),
        forecast_guardrail = c(D = 3L, n = 8L, alpha = 5L, rho = 5L, m = 7L, tau0 = 5L, sparse = 4L),
        forecast_hybrid = c(D = 3L, n = 8L, alpha = 5L, rho = 5L, m = 7L, tau0 = 5L, sparse = 4L),
        memory_guardrail = c(D = 2L, n = 6L, alpha = 5L, rho = 5L, m = 6L, tau0 = 5L, sparse = 4L),
        shrinkage = c(D = 2L, n = 5L, alpha = 4L, rho = 4L, m = 4L, tau0 = 5L, sparse = 3L),
        seed_check = c(D = 1L, n = 1L, alpha = 1L, rho = 1L, m = 1L, tau0 = 2L, sparse = 1L),
        c(D = 3L, n = 8L, alpha = 5L, rho = 5L, m = 7L, tau0 = 5L, sparse = 4L)
      )
      D_vals <- cap_near(D_vals, score_source$D, role_caps[["D"]])
      n_vals <- cap_near(n_vals, score_source$n_each, role_caps[["n"]])
      alpha_vals <- cap_near(alpha_vals, score_source$alpha, role_caps[["alpha"]])
      rho_vals <- cap_near(rho_vals, score_source$rho, role_caps[["rho"]])
      m_vals <- cap_near(m_vals, score_source$m, role_caps[["m"]])
      tau0_vals <- cap_near(tau0_vals, score_source$rhs_tau0, role_caps[["tau0"]])
      sparse_rows <- cap_sparse(sparse_rows, score_source, role_caps[["sparse"]])
    }
    grid <- expand.grid(
      D = D_vals,
      n_each = n_vals,
      alpha = alpha_vals,
      rho = rho_vals,
      m = m_vals,
      tau0 = tau0_vals,
      sparse_row = seq_len(nrow(sparse_rows)),
      seed = seed_vals,
      stringsAsFactors = FALSE
    )
    if (nrow(grid)) {
      tau0_priority <- ifelse(abs(as.numeric(grid$tau0) - 3e-4) < 1e-12, 0L,
        ifelse(abs(as.numeric(grid$tau0) - 1e-4) < 1e-12, 1L,
          ifelse(abs(as.numeric(grid$tau0) - 1e-3) < 1e-12, 2L, 3L)
        )
      )
      if (isTRUE(is_fitrmse_v4plus) && role %in% c("fit_micro", "fit_compact")) {
        grid$pre_score <- 5000 * tau0_priority +
          800 * as.numeric(grid$D) +
          35 * as.numeric(grid$n_each) +
          4 * as.numeric(grid$m) +
          100 * abs(as.numeric(grid$alpha) - as.numeric(score_source$alpha)) +
          50 * abs(as.numeric(grid$rho) - as.numeric(score_source$rho)) +
          10 * abs(as.numeric(sparse_rows$pi_w[grid$sparse_row]) - as.numeric(score_source$pi_w)) +
          5 * abs(as.numeric(sparse_rows$pi_in[grid$sparse_row]) - as.numeric(score_source$pi_in))
      } else {
        grid$pre_score <- 5000 * tau0_priority +
          500 * abs(as.numeric(grid$D) - as.numeric(score_source$D)) +
          10 * abs(as.numeric(grid$n_each) - as.numeric(score_source$n_each)) +
          100 * abs(as.numeric(grid$alpha) - as.numeric(score_source$alpha)) +
          50 * abs(as.numeric(grid$rho) - as.numeric(score_source$rho)) +
          1 * abs(as.numeric(grid$m) - as.numeric(score_source$m)) +
          10 * abs(as.numeric(sparse_rows$pi_w[grid$sparse_row]) - as.numeric(score_source$pi_w)) +
          5 * abs(as.numeric(sparse_rows$pi_in[grid$sparse_row]) - as.numeric(score_source$pi_in))
      }
      grid_ranked <- grid[order(grid$pre_score, grid$D, grid$n_each, grid$m, grid$tau0), , drop = FALSE]
      if (isTRUE(is_fitrmse_v4plus) && role %in% c("fit_micro", "fit_compact")) {
        diversity_ranked <- grid[order(grid$n_each, grid$m, grid$D, grid$pre_score, grid$tau0), , drop = FALSE]
        diverse_n <- diversity_ranked[!duplicated(diversity_ranked$n_each), , drop = FALSE]
        diverse_nm <- diversity_ranked[!duplicated(paste(diversity_ranked$n_each, diversity_ranked$m, sep = "\r")), , drop = FALSE]
        grid <- bind_rows(list(diverse_n, diverse_nm, grid_ranked))
        grid_key <- paste(grid$D, grid$n_each, grid$alpha, grid$rho, grid$m, grid$tau0, grid$sparse_row, grid$seed, sep = "\r")
        grid <- grid[!duplicated(grid_key), , drop = FALSE]
      } else {
        grid <- grid_ranked
      }
      grid <- utils::head(grid, as.integer(pool_limit)[1L])
    }
    for (i in seq_len(nrow(grid))) {
      sp <- sparse_rows[grid$sparse_row[[i]], , drop = FALSE]
      generated[[length(generated) + 1L]] <<- make_profile(
        family = family,
        tau = tau,
        role = role,
        source_row = source,
        source_metric = role,
        D = grid$D[[i]],
        n_each = grid$n_each[[i]],
        alpha = grid$alpha[[i]],
        rho = grid$rho[[i]],
        m = grid$m[[i]],
        pi_w = sp$pi_w[[1L]],
        pi_in = sp$pi_in[[1L]],
        rhs_tau0 = grid$tau0[[i]],
        reservoir_lags = 0L,
        seed = grid$seed[[i]]
      )
    }
  }
  if (isTRUE(is_fitrmse_v48plus)) {
    add_grid(
      "fit_micro",
      c(1L, 2L),
      c(4L, 6L, 8L, 10L, 12L, 16L, 20L, 24L, 30L),
      alpha_grid[1:12],
      rho_grid[1:10],
      c(1L, 2L, 3L, 5L, 8L, 12L, 15L, 20L),
      tau0_grid[2:8],
      sparse_grid[1:4, , drop = FALSE],
      source = anchor_fit,
      pool_limit = 180L
    )
  } else if (isTRUE(is_fitrmse_v47)) {
    add_grid(
      "fit_micro",
      c(1L, 2L),
      c(4L, 6L, 8L, 10L, 12L, 16L, 20L, 24L, 30L),
      alpha_grid[1:14],
      rho_grid[1:12],
      c(1L, 2L, 3L, 5L, 8L, 12L, 15L, 20L),
      tau0_grid[2:9],
      sparse_grid[1:5, , drop = FALSE],
      source = anchor_fit,
      pool_limit = 160L
    )
  } else if (isTRUE(is_fitrmse_v46)) {
    add_grid(
      "fit_micro",
      c(1L, 2L),
      c(4L, 6L, 8L, 10L, 12L, 16L, 20L),
      alpha_grid[1:12],
      rho_grid[1:10],
      c(1L, 2L, 3L, 5L, 8L, 12L, 15L),
      tau0_grid[2:7],
      sparse_grid[1:4, , drop = FALSE],
      pool_limit = 120L
    )
  } else if (isTRUE(is_fitrmse_v45)) {
    add_grid(
      "fit_micro",
      c(1L, 2L),
      c(4L, 6L, 8L, 10L, 12L, 20L),
      alpha_grid[1:10],
      rho_grid[1:10],
      c(1L, 2L, 3L, 5L, 8L, 15L),
      tau0_grid[2:7],
      sparse_grid[1:4, , drop = FALSE],
      pool_limit = 140L
    )
  } else if (isTRUE(is_fitrmse_v4)) {
    add_grid(
      "fit_micro",
      c(1L, 2L),
      c(4L, 6L, 8L, 10L, 12L, 15L, 20L),
      alpha_grid[1:12],
      rho_grid[1:10],
      c(1L, 2L, 3L, 5L, 8L, 10L, 15L),
      tau0_grid,
      sparse_grid[1:5, , drop = FALSE],
      pool_limit = 180L
    )
  } else if (isTRUE(is_fitrmse_v3)) {
    add_grid(
      "fit_micro",
      c(1L, 2L, 3L),
      c(6L, 8L, 10L, 12L, 15L, 20L),
      alpha_grid[1:8],
      rho_grid[1:8],
      c(3L, 5L, 10L, 15L, 20L),
      tau0_grid,
      sparse_grid[1:4, , drop = FALSE],
      pool_limit = 160L
    )
  }
  add_grid("local_fit", local_depth, local_n, local_alpha, local_rho, local_m, local_tau0, sparse_grid[2:min(5L, nrow(sparse_grid)), , drop = FALSE], source = anchor_tune, pool_limit = if (isTRUE(is_fitrmse_v48plus)) 240L else if (isTRUE(is_fitrmse_v47)) 180L else if (isTRUE(is_fitrmse_v46)) 150L else if (isTRUE(is_fitrmse_v45)) 180L else if (isTRUE(is_fitrmse_v4)) 150L else 120L)
  if (isTRUE(is_fitrmse_v47plus)) {
    add_grid(
      "fit_check_guardrail",
      unique(c(anchor_fit_check$D, 1L, 2L)),
      unique(c(anchor_fit_check$n_each, 6L, 8L, 12L, 16L, 20L, 30L, 40L, if (isTRUE(is_fitrmse_v48plus)) 50L else integer(0))),
      nearest_values(anchor_fit_check$alpha, alpha_grid, if (isTRUE(is_fitrmse_v48plus)) 5L else 7L),
      nearest_values(anchor_fit_check$rho, rho_grid, if (isTRUE(is_fitrmse_v48plus)) 5L else 7L),
      unique(c(anchor_fit_check$m, 1L, 2L, 3L, 5L, 8L, 15L, 30L, 45L, if (isTRUE(is_fitrmse_v48plus)) 60L else integer(0))),
      sort(unique(c(nearest_values(anchor_fit_check$rhs_tau0, tau0_grid, if (isTRUE(is_fitrmse_v48plus)) 5L else 7L), 1e-6, 3e-6, 1e-5, 1e-4, 3e-4))),
      sparse_grid[1:min(if (isTRUE(is_fitrmse_v48plus)) 4L else 6L, nrow(sparse_grid)), , drop = FALSE],
      source = anchor_fit_check,
      pool_limit = if (isTRUE(is_fitrmse_v48plus)) 160L else 160L
    )
  }
  if (isTRUE(is_fitrmse_v48plus)) {
    hybrid_sparse <- sparse_grid[1:min(4L, nrow(sparse_grid)), , drop = FALSE]
    add_grid(
      "fit_check_hybrid",
      unique(c(anchor_fit_check$D, anchor_fit$D, best_joint$D, 1L, 2L)),
      unique(c(anchor_fit_check$n_each, anchor_fit$n_each, best_joint$n_each, 4L, 6L, 8L, 12L, 20L, 30L, 40L)),
      sort(unique(c(nearest_values(anchor_fit_check$alpha, alpha_grid, 4L), nearest_values(anchor_fit$alpha, alpha_grid, 3L), nearest_values(best_joint$alpha, alpha_grid, 3L)))),
      sort(unique(c(nearest_values(anchor_fit_check$rho, rho_grid, 4L), nearest_values(anchor_fit$rho, rho_grid, 3L), nearest_values(best_joint$rho, rho_grid, 3L)))),
      unique(c(anchor_fit_check$m, anchor_fit$m, best_joint$m, 1L, 2L, 3L, 5L, 8L, 15L, 30L)),
      sort(unique(c(nearest_values(anchor_fit_check$rhs_tau0, tau0_grid, 4L), nearest_values(anchor_fit$rhs_tau0, tau0_grid, 3L), 1e-6, 3e-6, 1e-5, 1e-4, 3e-4))),
      hybrid_sparse,
      source = anchor_fit_check,
      pool_limit = 160L
    )
    add_grid(
      "forecast_hybrid",
      unique(c(anchor_forecast$D, best_joint$D, anchor_tune$D, 1L, 2L)),
      unique(c(anchor_forecast$n_each, best_joint$n_each, anchor_tune$n_each, 8L, 12L, 20L, 30L, 40L, 50L)),
      sort(unique(c(nearest_values(anchor_forecast$alpha, alpha_grid, 4L), nearest_values(best_joint$alpha, alpha_grid, 3L), nearest_values(anchor_tune$alpha, alpha_grid, 3L)))),
      sort(unique(c(nearest_values(anchor_forecast$rho, rho_grid, 4L), nearest_values(best_joint$rho, rho_grid, 3L), nearest_values(anchor_tune$rho, rho_grid, 3L)))),
      unique(c(anchor_forecast$m, best_joint$m, anchor_tune$m, 15L, 20L, 30L, 45L, 60L, 90L, 120L)),
      sort(unique(c(nearest_values(anchor_forecast$rhs_tau0, tau0_grid, 4L), nearest_values(best_joint$rhs_tau0, tau0_grid, 3L), 1e-5, 3e-5, 1e-4, 3e-4))),
      sparse_grid[3:min(7L, nrow(sparse_grid)), , drop = FALSE],
      source = anchor_forecast,
      pool_limit = 160L
    )
  }
  if (isTRUE(is_fitrmse_v50)) {
    bridge_alpha <- sort(unique(c(
      nearest_values(anchor_fit_check$alpha, alpha_grid, 5L),
      nearest_values(anchor_fit$alpha, alpha_grid, 5L),
      nearest_values(best_joint$alpha, alpha_grid, 4L),
      0.01, 0.02, 0.05, 0.08, 0.12, 0.20, 0.30
    )))
    bridge_rho <- sort(unique(c(
      nearest_values(anchor_fit_check$rho, rho_grid, 5L),
      nearest_values(anchor_fit$rho, rho_grid, 5L),
      nearest_values(best_joint$rho, rho_grid, 4L),
      0.35, 0.45, 0.58, 0.70, 0.80, 0.88
    )))
    bridge_m <- sort(unique(c(anchor_fit_check$m, anchor_fit$m, best_joint$m, 1L, 2L, 3L, 4L, 5L, 7L, 10L, 15L, 18L, 30L, 45L, 60L, 90L)))
    bridge_n <- sort(unique(c(anchor_fit_check$n_each, anchor_fit$n_each, best_joint$n_each, 4L, 6L, 8L, 10L, 12L, 16L, 20L, 30L, 40L, 50L, 60L)))
    add_grid(
      "fit_check_bridge",
      unique(c(anchor_fit_check$D, anchor_fit$D, best_joint$D, 1L, 2L)),
      bridge_n,
      bridge_alpha,
      bridge_rho,
      bridge_m,
      sort(unique(c(nearest_values(anchor_fit_check$rhs_tau0, tau0_grid, 5L), nearest_values(anchor_fit$rhs_tau0, tau0_grid, 5L), 1e-6, 3e-6, 1e-5, 3e-5, 1e-4, 3e-4, 5e-4))),
      sparse_grid[1:min(8L, nrow(sparse_grid)), , drop = FALSE],
      source = anchor_fit_check,
      pool_limit = 260L
    )
    add_grid(
      "structural_bridge",
      c(1L, 2L),
      c(4L, 6L, 8L, 10L, 12L, 16L, 20L, 24L, 30L, 36L, 40L),
      sort(unique(c(alpha_grid[1:22], nearest_values(best_joint$alpha, alpha_grid, 4L)))),
      sort(unique(c(rho_grid[1:22], nearest_values(best_joint$rho, rho_grid, 4L)))),
      c(1L, 2L, 3L, 4L, 5L, 7L, 9L, 10L, 12L, 15L, 18L, 20L, 25L, 30L, 35L),
      tau0_grid[1:12],
      sparse_grid[1:min(8L, nrow(sparse_grid)), , drop = FALSE],
      source = anchor_fit,
      pool_limit = 300L
    )
    add_grid(
      "short_memory_rescue",
      c(1L, 2L),
      c(4L, 6L, 8L, 10L, 12L, 16L, 20L, 24L, 30L),
      alpha_grid[1:18],
      rho_grid[1:20],
      c(1L, 2L, 3L, 4L, 5L, 7L, 9L, 10L, 12L, 15L),
      tau0_grid[1:11],
      sparse_grid[1:min(7L, nrow(sparse_grid)), , drop = FALSE],
      source = anchor_fit,
      pool_limit = 260L
    )
    add_grid(
      "forecast_mae_rescue",
      unique(c(anchor_forecast$D, best_joint$D, 1L, 2L)),
      sort(unique(c(anchor_forecast$n_each, best_joint$n_each, 4L, 6L, 8L, 12L, 20L, 25L, 30L, 40L, 50L, 60L, 70L))),
      sort(unique(c(nearest_values(anchor_forecast$alpha, alpha_grid, 7L), 0.0006, 0.001, 0.0025, 0.005, 0.01, 0.02, 0.05, 0.08))),
      sort(unique(c(nearest_values(anchor_forecast$rho, rho_grid, 7L), 0.35, 0.45, 0.58, 0.60, 0.70, 0.75, 0.80))),
      sort(unique(c(anchor_forecast$m, best_joint$m, 3L, 5L, 7L, 10L, 15L, 18L, 25L, 30L, 35L, 45L, 60L, 75L, 90L, 105L, 120L))),
      sort(unique(c(nearest_values(anchor_forecast$rhs_tau0, tau0_grid, 5L), 1e-5, 3e-5, 1e-4, 3e-4, 5e-4, 1e-3))),
      sparse_grid[3:min(12L, nrow(sparse_grid)), , drop = FALSE],
      source = anchor_forecast,
      pool_limit = 300L
    )
  }
  compact_n <- if (isTRUE(is_fitrmse_v50)) c(4L, 6L, 8L, 10L, 12L, 16L, 20L, 24L, 30L, 36L, 40L) else if (isTRUE(is_fitrmse_v48plus)) c(4L, 6L, 8L, 10L, 12L, 16L, 20L, 24L, 30L, 36L) else if (isTRUE(is_fitrmse_v47)) c(4L, 6L, 8L, 10L, 12L, 16L, 20L, 24L, 30L) else if (isTRUE(is_fitrmse_v46)) c(4L, 6L, 8L, 10L, 12L, 16L, 20L) else if (isTRUE(is_fitrmse_v45)) c(4L, 6L, 8L, 10L, 12L, 15L, 20L, 25L) else if (isTRUE(is_fitrmse_v4)) c(4L, 6L, 8L, 10L, 12L, 15L, 20L, 25L) else c(8L, 10L, 12L, 15L, 20L, 25L)
  compact_m <- if (isTRUE(is_fitrmse_v50)) c(1L, 2L, 3L, 4L, 5L, 7L, 9L, 10L, 12L, 15L, 18L, 20L, 24L, 25L, 30L) else if (isTRUE(is_fitrmse_v48plus)) c(1L, 2L, 3L, 5L, 6L, 8L, 12L, 15L, 20L, 24L) else if (isTRUE(is_fitrmse_v47)) c(1L, 2L, 3L, 5L, 8L, 12L, 15L, 20L) else if (isTRUE(is_fitrmse_v46)) c(1L, 2L, 3L, 5L, 8L, 12L, 15L) else if (isTRUE(is_fitrmse_v45)) c(1L, 2L, 3L, 5L, 8L, 15L, 20L) else if (isTRUE(is_fitrmse_v4)) c(1L, 2L, 3L, 5L, 8L, 10L, 15L, 20L) else c(5L, 10L, 15L, 20L, 30L)
  compact_alpha <- alpha_grid[seq_len(if (isTRUE(is_fitrmse_v50)) 22L else if (isTRUE(is_fitrmse_v48plus)) 18L else if (isTRUE(is_fitrmse_v47)) 14L else if (isTRUE(is_fitrmse_v46)) 12L else if (isTRUE(is_fitrmse_v45)) 10L else if (isTRUE(is_fitrmse_v4)) 12L else 7L)]
  compact_rho <- rho_grid[seq_len(if (isTRUE(is_fitrmse_v50)) 22L else if (isTRUE(is_fitrmse_v48plus)) 16L else if (isTRUE(is_fitrmse_v47)) 12L else if (isTRUE(is_fitrmse_v46)) 10L else if (isTRUE(is_fitrmse_v45)) 10L else if (isTRUE(is_fitrmse_v4)) 10L else 8L)]
  compact_tau0 <- tau0_grid[seq.int(2L, if (isTRUE(is_fitrmse_v50)) 12L else if (isTRUE(is_fitrmse_v48plus)) 9L else if (isTRUE(is_fitrmse_v47)) 9L else 7L)]
  add_grid("fit_compact", c(1L, 2L), compact_n, compact_alpha, compact_rho, compact_m, compact_tau0, sparse_grid[1:min(if (isTRUE(is_fitrmse_v48plus)) 7L else if (isTRUE(is_fitrmse_v47)) 5L else 4L, nrow(sparse_grid)), , drop = FALSE], source = anchor_fit, pool_limit = if (isTRUE(is_fitrmse_v48plus)) 220L else if (isTRUE(is_fitrmse_v47)) 150L else if (isTRUE(is_fitrmse_v46)) 120L else if (isTRUE(is_fitrmse_v45)) 140L else if (isTRUE(is_fitrmse_v4)) 150L else 120L)
  add_grid("shrinkage", c(1L, 2L), c(10L, 15L, 20L, 30L), nearest_values(anchor_fit$alpha, alpha_grid, 4L), nearest_values(anchor_fit$rho, rho_grid, 4L), c(10L, 15L, 30L), tau0_grid, sparse_grid[1:3, , drop = FALSE], pool_limit = 80L)
  memory_tau0 <- if (isTRUE(is_fitrmse_v47plus)) c(1e-5, 3e-5, 1e-4, 3e-4, 1e-3) else c(1e-4, 3e-4, 1e-3)
  add_grid("memory_guardrail", c(1L, 2L), c(20L, 30L, 40L, if (isTRUE(is_fitrmse_v47plus)) 50L else integer(0), if (isTRUE(is_fitrmse_v48plus)) 60L else integer(0)), c(0.05, 0.10, 0.20, 0.30, 0.40, if (isTRUE(is_fitrmse_v47plus)) 0.50 else numeric(0), if (isTRUE(is_fitrmse_v48plus)) 0.60 else numeric(0)), c(0.60, 0.70, 0.80, 0.85, 0.90, if (isTRUE(is_fitrmse_v47plus)) 0.95 else numeric(0)), c(45L, 60L, 90L, if (isTRUE(is_fitrmse_v47plus)) c(120L, 150L) else integer(0)), memory_tau0, sparse_grid[3:min(if (isTRUE(is_fitrmse_v48plus)) 10L else if (isTRUE(is_fitrmse_v47)) 8L else 5L, nrow(sparse_grid)), , drop = FALSE], source = anchor_forecast, pool_limit = if (isTRUE(is_fitrmse_v48plus)) 160L else if (isTRUE(is_fitrmse_v47)) 120L else 80L)
  add_grid("forecast_guardrail", unique(c(anchor_forecast$D, 1L, 2L)), unique(c(anchor_forecast$n_each, 20L, 30L, 40L, if (isTRUE(is_fitrmse_v47plus)) 50L else integer(0), if (isTRUE(is_fitrmse_v48plus)) 60L else integer(0))), nearest_values(anchor_forecast$alpha, alpha_grid, if (isTRUE(is_fitrmse_v48plus)) 9L else if (isTRUE(is_fitrmse_v47)) 7L else 5L), nearest_values(anchor_forecast$rho, rho_grid, if (isTRUE(is_fitrmse_v48plus)) 9L else if (isTRUE(is_fitrmse_v47)) 7L else 5L), unique(c(anchor_forecast$m, 30L, 60L, 90L, if (isTRUE(is_fitrmse_v47plus)) c(120L, 150L) else integer(0))), c(1e-5, 3e-5, 1e-4, 3e-4), sparse_grid[3:min(if (isTRUE(is_fitrmse_v48plus)) 10L else if (isTRUE(is_fitrmse_v47)) 8L else 6L, nrow(sparse_grid)), , drop = FALSE], source = anchor_forecast, pool_limit = if (isTRUE(is_fitrmse_v48plus)) 160L else if (isTRUE(is_fitrmse_v47)) 120L else 80L)
  seed_anchor <- if (isTRUE(is_fitrmse_v47plus)) anchor_tune else anchor_fit
  add_grid("seed_check", seed_anchor$D, seed_anchor$n_each, seed_anchor$alpha, seed_anchor$rho, seed_anchor$m, c(seed_anchor$rhs_tau0, 3e-4), sparse_grid[which.min(abs(sparse_grid$pi_w - seed_anchor$pi_w) + abs(sparse_grid$pi_in - seed_anchor$pi_in)), , drop = FALSE], seed_vals = c(777L, 2027L), source = seed_anchor, pool_limit = 8L)

  candidates <- bind_rows(c(list(anchors), generated))
  candidates <- candidates[is.finite(as.numeric(candidates$p_over_n_tt500)) & as.numeric(candidates$p_over_n_tt500) <= max_p_over_n, , drop = FALSE]
  candidates <- candidates[!duplicated(as.character(candidates$screening_profile_id)), , drop = FALSE]
  if (!nrow(candidates)) stop(sprintf("No candidates generated for %s tau %.2f.", family, tau), call. = FALSE)
  role_order <- c(anchor = 1L, structural_bridge = 2L, short_memory_rescue = 3L, fit_micro = 4L, fit_compact = 5L, local_fit = 6L, fit_check_bridge = 7L, fit_check_guardrail = 8L, fit_check_hybrid = 9L, shrinkage = 10L, forecast_mae_rescue = 11L, memory_guardrail = 12L, forecast_guardrail = 13L, forecast_hybrid = 14L, seed_check = 15L)
  candidates$role_group <- sub("^anchor_.*$", "anchor", as.character(candidates$profile_role))
  candidates$role_group[!candidates$role_group %in% names(role_order)] <- as.character(candidates$profile_role[!candidates$role_group %in% names(role_order)])
  candidates$tau0_priority <- ifelse(abs(as.numeric(candidates$rhs_tau0) - 3e-4) < 1e-12, 0L,
    ifelse(abs(as.numeric(candidates$rhs_tau0) - 1e-4) < 1e-12, 1L,
      ifelse(abs(as.numeric(candidates$rhs_tau0) - 1e-3) < 1e-12, 2L, 3L)
    )
  )
  candidates$local_score <- unname(role_order[candidates$role_group])
  candidates$local_score[!is.finite(candidates$local_score)] <- 99
  base_role_score <- candidates$local_score * 1e6 +
    5000 * as.numeric(candidates$tau0_priority)
  compact_first <- isTRUE(is_fitrmse_v4plus) & candidates$role_group %in% c("structural_bridge", "short_memory_rescue", "fit_micro", "fit_compact")
  score_against <- function(anchor) {
    500 * abs(as.numeric(candidates$D) - as.numeric(anchor$D)) +
      10 * abs(as.numeric(candidates$n_each) - as.numeric(anchor$n_each)) +
      100 * abs(as.numeric(candidates$alpha) - as.numeric(anchor$alpha)) +
      50 * abs(as.numeric(candidates$rho) - as.numeric(anchor$rho)) +
      1 * abs(as.numeric(candidates$m) - as.numeric(anchor$m)) +
      100 * as.numeric(candidates$p_over_n_tt500)
  }
  anchor_distance_score <- score_against(anchor_fit)
  if (isTRUE(is_fitrmse_v47plus)) {
    check_roles <- candidates$role_group %in% c("fit_check_bridge", "fit_check_guardrail", "fit_check_hybrid") |
      (identical(class$bottleneck, "fit_check") & candidates$role_group %in% c("local_fit", "seed_check"))
    forecast_roles <- candidates$role_group %in% c("forecast_mae_rescue", "forecast_guardrail", "forecast_hybrid", "memory_guardrail") |
      (identical(class$status, "forecast_mae_hard") & candidates$role_group %in% c("local_fit", "seed_check"))
    check_score <- score_against(anchor_fit_check)
    forecast_score <- score_against(anchor_forecast)
    anchor_distance_score[check_roles] <- check_score[check_roles]
    anchor_distance_score[forecast_roles] <- forecast_score[forecast_roles]
  }
  compact_shape_score <- 800 * as.numeric(candidates$D) +
    35 * as.numeric(candidates$n_each) +
    4 * as.numeric(candidates$m) +
    100 * abs(as.numeric(candidates$alpha) - as.numeric(anchor_fit$alpha)) +
    50 * abs(as.numeric(candidates$rho) - as.numeric(anchor_fit$rho)) +
    100 * as.numeric(candidates$p_over_n_tt500)
  candidates$local_score <- base_role_score + ifelse(compact_first, compact_shape_score, anchor_distance_score)

  quotas <- role_quota(class$status, target_n)
  select_role_candidates <- function(sub, role, n) {
    sub <- sub[order(sub$local_score, sub$p_over_n_tt500, sub$screening_profile_id), , drop = FALSE]
    n <- as.integer(n)[1L]
    if (!nrow(sub) || n <= 0L) return(sub[0L, , drop = FALSE])
    if (isTRUE(is_fitrmse_v4plus) && role %in% c("fit_micro", "fit_compact")) {
      compact_order <- sub[order(sub$n_each, sub$m, sub$D, sub$local_score, sub$screening_profile_id), , drop = FALSE]
      diverse_n <- compact_order[!duplicated(compact_order$n_each), , drop = FALSE]
      diverse_shape <- compact_order[!duplicated(paste(compact_order$D, compact_order$n_each, compact_order$m, sep = "\r")), , drop = FALSE]
      out <- bind_rows(list(utils::head(diverse_n, ceiling(n / 2)), diverse_shape))
      out <- out[!duplicated(out$screening_profile_id), , drop = FALSE]
      if (nrow(out) < n) {
        out <- bind_rows(list(out, sub[!sub$screening_profile_id %in% out$screening_profile_id, , drop = FALSE]))
      }
      return(utils::head(out, n))
    }
    utils::head(sub, n)
  }
  selected <- bind_rows(lapply(names(quotas), function(role) {
    sub <- candidates[candidates$role_group == role, , drop = FALSE]
    select_role_candidates(sub, role, quotas[[role]])
  }))
  if (nrow(selected) < target_n) {
    remaining <- candidates[!candidates$screening_profile_id %in% selected$screening_profile_id, , drop = FALSE]
    remaining <- remaining[order(remaining$local_score, remaining$p_over_n_tt500, remaining$screening_profile_id), , drop = FALSE]
    selected <- bind_rows(list(selected, utils::head(remaining, target_n - nrow(selected))))
  }
  selected <- selected[!duplicated(as.character(selected$screening_profile_id)), , drop = FALSE]
  selected <- selected[order(selected$role_group, selected$local_score, selected$p_over_n_tt500), , drop = FALSE]
  selected$case_specific_profile_rank <- seq_len(nrow(selected))
  selected$target_cells <- paste(family, sprintf("%.2f", tau), sep = ":")
  selected$target_cell_statuses <- class$status
  selected$target_bottleneck_metrics <- class$bottleneck
  selected$role_group <- NULL
  selected$tau0_priority <- NULL
  selected$local_score <- NULL

  cell_plan <- data.frame(
    family = family,
    tau = tau,
    fit_size = 500L,
    cell_status = class$status,
    bottleneck_metric = class$bottleneck,
    target_profiles = nrow(selected),
    source_rows = nrow(sub),
    best_balanced_profile = as.character(best_joint$screening_profile_base[[1L]]),
    best_fit_rmse_profile = as.character(best_fit$screening_profile_base[[1L]]),
    best_forecast_mae_profile = as.character(best_mae$screening_profile_base[[1L]]),
    best_forecast_check_profile = as.character(best_check$screening_profile_base[[1L]]),
    current_best_worst_ratio = class$worst,
    min_forecast_mae_ratio = min(as.numeric(sub$forecast_mae_ratio_vs_best_vb_baseline), na.rm = TRUE),
    min_forecast_check_ratio = min(as.numeric(sub$forecast_pinball_ratio_vs_best_vb_baseline), na.rm = TRUE),
    min_fit_rmse_ratio = min(as.numeric(sub$fit_rmse_ratio_vs_best_vb_baseline), na.rm = TRUE),
    min_fit_check_ratio = min(as.numeric(sub$fit_pinball_ratio_vs_best_vb_baseline), na.rm = TRUE),
    selected_role_counts = paste(names(table(selected$profile_role)), as.integer(table(selected$profile_role)), sep = ":", collapse = ";"),
    stringsAsFactors = FALSE
  )
  assignments <- data.frame(
    family = family,
    tau = tau,
    cell_status = class$status,
    priority_rank = NA_integer_,
    target_profile_rank = as.integer(selected$case_specific_profile_rank),
    screening_profile_id = as.character(selected$screening_profile_id),
    source_profile = as.character(selected$target_source_profile),
    source_worst_ratio = as.numeric(selected$target_source_worst_ratio),
    bottleneck_metric = class$bottleneck,
    assignment_key = paste(as.character(selected$screening_profile_id), family, tau_key(tau), sep = "\r"),
    assignment_id = NA_character_,
    stringsAsFactors = FALSE
  )
  list(cell_plan = cell_plan, profiles = selected, assignments = assignments, candidate_pool = candidates)
}

cell_keys <- sort(unique(paste(cell$family, tau_key(cell$tau), sep = "\r")))
case_objects <- lapply(cell_keys, function(key) {
  sub <- cell[paste(cell$family, tau_key(cell$tau), sep = "\r") == key, , drop = FALSE]
  candidate_pool_for_cell(sub)
})
cell_plan <- bind_rows(lapply(case_objects, `[[`, "cell_plan"))
status_order <- c(fit_rmse_extreme = 1L, fit_rmse_hard = 2L, forecast_mae_hard = 3L, mixed_near = 4L, near_pass = 5L, confirmation = 6L, unknown = 7L)
cell_plan$priority <- unname(status_order[as.character(cell_plan$cell_status)])
cell_plan$priority[!is.finite(cell_plan$priority)] <- 99L
cell_plan <- cell_plan[order(cell_plan$priority, -cell_plan$current_best_worst_ratio, cell_plan$family, cell_plan$tau), , drop = FALSE]
cell_plan$priority_rank <- seq_len(nrow(cell_plan))
priority_lookup <- setNames(cell_plan$priority_rank, paste(cell_plan$family, tau_key(cell_plan$tau), sep = "\r"))

profiles <- bind_rows(lapply(case_objects, `[[`, "profiles"))
profiles <- profiles[order(profiles$target_family, profiles$target_tau, profiles$case_specific_profile_rank), , drop = FALSE]
assignments <- bind_rows(lapply(case_objects, `[[`, "assignments"))
assign_key <- paste(assignments$family, tau_key(assignments$tau), sep = "\r")
assignments$priority_rank <- as.integer(priority_lookup[assign_key])
assignments <- assignments[order(assignments$priority_rank, assignments$target_profile_rank, assignments$screening_profile_id), , drop = FALSE]
assignments$assignment_id <- sprintf("case_specific_rhs_cell_%04d", seq_len(nrow(assignments)))
candidate_pool <- bind_rows(lapply(case_objects, `[[`, "candidate_pool"))

plan <- list(
  cell_plan = cell_plan,
  candidate_ledger = candidate_pool,
  profiles = profiles,
  assignments = assignments,
  manifest = list(
    stage = screening_stage_label,
    screen_mode = screen_mode,
    screening_wave = screening_wave,
    source_report_root = source_report_root,
    target_cells = nrow(cell_plan),
    selected_profiles = nrow(profiles),
    selected_assignments = nrow(assignments),
    likelihoods = as.list(likelihoods),
    max_profiles_per_cell = as.integer(max_profiles_per_cell),
    max_p_over_n = as.numeric(max_p_over_n),
    design = if (isTRUE(is_fitrmse_v50)) {
      "Eighth-generation case-targeted Q-DESN RHS VB calibration: each family/tau case receives a v4.9-anchored two-lane follow-up, with fit-check bridge designs for near misses and structural/forecast rescue designs for hard cells; no MCMC promotion without fresh all-primary dominance."
    } else if (isTRUE(is_fitrmse_v49)) {
      "Seventh-generation case-targeted Q-DESN RHS VB calibration: each family/tau case receives a v4.8-anchored follow-up with expanded but capped bridge, fit-check, compact-fit, and forecast guardrail quotas, and no MCMC promotion without fresh all-primary dominance."
    } else if (isTRUE(is_fitrmse_v48plus)) {
      "Sixth-generation case-targeted Q-DESN RHS VB calibration: each family/tau case receives a v4.7-anchored follow-up with explicit fit-check and forecast hybrid bridge roles, larger budgets only for hard blockers, and no MCMC promotion without fresh all-primary dominance."
    } else if (isTRUE(is_fitrmse_v47)) {
      "Fifth-generation case-targeted Q-DESN RHS VB calibration: each family/tau case receives a v4.6-anchored follow-up with explicit fit-check guardrails, blocker-specific local scoring, wider memory/tau0/sparsity probes only where warranted, and no MCMC promotion without fresh all-primary dominance."
    } else if (isTRUE(is_fitrmse_v46)) {
      "Fourth-generation case-targeted Q-DESN RHS VB calibration: each family/tau case receives a v4.5-anchored follow-up focused on its observed blocker, with smaller per-cell budgets, sharper compact fit/check neighborhoods, and no MCMC promotion without fresh all-primary dominance."
    } else if (isTRUE(is_fitrmse_v45)) {
      "Third-generation case-targeted Q-DESN RHS VB calibration: each family/tau case receives a per-cell neighborhood anchored on the completed v4 screen, with near-miss check-loss refinements and hard-cell fit-RMSE/forecast-MAE rescue branches."
    } else if (isTRUE(is_fitrmse_v4)) {
      "Second-generation case-targeted Q-DESN RHS VB calibration: each family/tau case receives a compact fit-RMSE-first neighborhood anchored on the completed v3 screen, with forecast-MAE guardrails for median cells."
    } else if (isTRUE(is_fitrmse_v3)) {
      "Fit-RMSE-targeted Q-DESN RHS VB calibration: each family/tau case receives a compact, case-specific candidate neighborhood anchored on the completed v2 screen."
    } else {
      "Cell-specific Q-DESN RHS VB calibration: each family/tau case receives its own anchored candidate neighborhood."
    }
  )
)

diag_tables <- file.path(diagnostic_out, "tables")
diag_summary <- file.path(diagnostic_out, "summary")
diag_manifest <- file.path(diagnostic_out, "manifest")
dir.create(diag_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_summary, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_manifest, recursive = TRUE, showWarnings = FALSE)
diagnostic_paths <- list(
  cell_plan = file.path(diag_tables, paste0(diagnostic_stub, "_cell_plan.csv")),
  candidate_ledger = file.path(diag_tables, paste0(diagnostic_stub, "_candidate_ledger.csv")),
  selected_profiles = file.path(diag_tables, paste0(diagnostic_stub, "_profiles.csv")),
  cell_assignments = file.path(diag_tables, paste0(diagnostic_stub, "_cell_assignments.csv")),
  source_cell_summary = cell_summary_path,
  source_fit_summary = fit_summary_path,
  source_audit_summary = audit_summary_path,
  summary = file.path(diag_summary, paste0(diagnostic_stub, "_screen.md")),
  manifest = file.path(diag_manifest, paste0(diagnostic_stub, "_screen_manifest.json"))
)
write_df(cell_plan, diagnostic_paths$cell_plan)
write_df(candidate_pool, diagnostic_paths$candidate_ledger)
write_df(profiles, diagnostic_paths$selected_profiles)
write_df(assignments, diagnostic_paths$cell_assignments)

materialized <- exdqlm:::qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage(
  plan = plan,
  base_defaults_path = base_defaults_path,
  profiles_out = profiles_out,
  assignments_out = assignments_out,
  defaults_out = defaults_out,
  grid_out = grid_out,
  workers = workers,
  refresh_grid = refresh_grid,
  refresh_materialized = refresh_materialized,
  stage_stub = stage_file,
  stage_desc = if (isTRUE(is_fitrmse_v50)) {
    "Q-DESN 500-observation VB case-targeted RHS v5.0 screen with v4.9-anchored fit-check bridge, structural fit-RMSE rescue, and forecast-MAE rescue lanes under unchanged storage-light promotion gates."
  } else if (isTRUE(is_fitrmse_v49)) {
    "Q-DESN 500-observation VB case-targeted RHS v4.9 screen with v4.8-anchored targeted guardrails, expanded per-cell budgets, and storage-light promotion gates."
  } else if (isTRUE(is_fitrmse_v48plus)) {
    "Q-DESN 500-observation VB case-targeted RHS v4.8 screen with v4.7-anchored fit-check/forecast hybrid bridges, blocker-specific budgets, and storage-light promotion gates."
  } else if (isTRUE(is_fitrmse_v47)) {
    "Q-DESN 500-observation VB case-targeted RHS v4.7 screen with v4.6-anchored fit-check guardrails, blocker-specific scoring, and storage-light promotion gates."
  } else if (isTRUE(is_fitrmse_v46)) {
    "Q-DESN 500-observation VB case-targeted RHS v4.6 screen with v4.5-anchored per-cell blocker refinements and storage-light promotion gates."
  } else if (isTRUE(is_fitrmse_v45)) {
    "Q-DESN 500-observation VB case-targeted RHS v4.5 screen with per-cell near-miss check-loss refinements and hard-cell fit-RMSE/forecast-MAE rescue branches."
  } else if (isTRUE(is_fitrmse_v4)) {
    "Q-DESN 500-observation VB case-targeted RHS v4 screen with compact fit-RMSE-first per-family/quantile DESN specifications and forecast-MAE guardrails."
  } else if (isTRUE(is_fitrmse_v3)) {
    "Q-DESN 500-observation VB case-targeted RHS v3 screen with fit-RMSE-focused per-family/quantile DESN specifications."
  } else {
    "Q-DESN 500-observation VB case-specific RHS screen with per-family/quantile DESN specifications."
  },
  stage = screening_stage_stub,
  priors = "rhs_ns"
)

defaults <- yaml::read_yaml(defaults_out)
defaults$execution <- defaults$execution %||% list()
defaults$execution$methods <- "vb"
defaults$execution$likelihood_families <- as.list(likelihoods)
defaults$reference_contract$expected_selected_qdesn_roots <- as.integer(materialized$expected_qdesn_roots)
defaults$screening_profiles$selected_assignment_root_count <- as.integer(materialized$expected_qdesn_roots)
defaults$screening_profiles$design <- sprintf(
  "Q-DESN RHS VB %s screen. Profiles/assignments: %d; likelihoods per root: %s.",
  if (isTRUE(is_fitrmse_v50)) "case-targeted v5 two-lane bridge/rescue follow-up" else if (isTRUE(is_fitrmse_v49)) "case-targeted v4.9 targeted-guardrail follow-up" else if (isTRUE(is_fitrmse_v48plus)) "case-targeted v4.8 fit-check/forecast hybrid follow-up" else if (isTRUE(is_fitrmse_v47)) "case-targeted v4.7 fit-check/blocker follow-up" else if (isTRUE(is_fitrmse_v46)) "case-targeted v4.6 blocker follow-up" else if (isTRUE(is_fitrmse_v45)) "case-targeted v4.5 bottleneck refinement" else if (isTRUE(is_fitrmse_v4)) "case-targeted v4 fit-RMSE/forecast-MAE" else if (isTRUE(is_fitrmse_v3)) "case-targeted v3 fit-RMSE" else "case-specific",
  as.integer(materialized$expected_qdesn_roots),
  paste(likelihoods, collapse = ",")
)
defaults$screening_profiles[[paste0(screening_stage_stub, "_design")]] <- list(
  screen_mode = screen_mode,
  source_report_root = source_report_root,
  source_cell_summary = cell_summary_path,
  source_fit_summary = fit_summary_path,
  baseline_path = baseline_path,
  max_profiles_per_cell = as.integer(max_profiles_per_cell),
  max_p_over_n = as.numeric(max_p_over_n),
  profile_ownership = "profile IDs are family/tau specific; identical numeric specs are not shared across cells",
  promotion_policy = "promote per-cell winners only after fresh VB dominance and strict audit; do not require one shared spec"
)
defaults$study_contract$description <- paste(
  if (isTRUE(is_fitrmse_v50)) "Q-DESN RHS VB case-targeted v5 calibration for the 500-observation simulation validation." else if (isTRUE(is_fitrmse_v49)) "Q-DESN RHS VB case-targeted v4.9 calibration for the 500-observation simulation validation." else if (isTRUE(is_fitrmse_v48plus)) "Q-DESN RHS VB case-targeted v4.8 calibration for the 500-observation simulation validation." else if (isTRUE(is_fitrmse_v47)) "Q-DESN RHS VB case-targeted v4.7 calibration for the 500-observation simulation validation." else if (isTRUE(is_fitrmse_v46)) "Q-DESN RHS VB case-targeted v4.6 calibration for the 500-observation simulation validation." else if (isTRUE(is_fitrmse_v45)) "Q-DESN RHS VB case-targeted v4.5 calibration for the 500-observation simulation validation." else if (isTRUE(is_fitrmse_v4)) "Q-DESN RHS VB case-targeted v4 calibration for the 500-observation simulation validation." else if (isTRUE(is_fitrmse_v3)) "Q-DESN RHS VB case-targeted v3 fit-RMSE calibration for the 500-observation simulation validation." else "Q-DESN RHS VB case-specific calibration for the 500-observation simulation validation.",
  if (isTRUE(is_fitrmse_v50)) "Each family/quantile cell receives its own v4.9-anchored profile neighborhood; v5 explicitly separates near-miss fit-check bridge searches from hard-cell structural fit-RMSE and forecast-MAE rescue searches, while keeping the same all-primary dominance and storage-light gates." else if (isTRUE(is_fitrmse_v49)) "Each family/quantile cell receives its own v4.8-anchored profile neighborhood; v4.9 keeps the bridge logic that was scientifically useful in v4.8, slightly expands hard-cell budgets, and adds tighter targeted guardrails around the observed remaining blockers without relaxing the dominance gate." else if (isTRUE(is_fitrmse_v48plus)) "Each family/quantile cell receives its own v4.7-anchored profile neighborhood; v4.8 adds fit-check/forecast bridge candidates so near-pass cells can combine the best fit-check profile with the best fit-RMSE/forecast profile, while hard cells receive larger but still capped blocker-specific budgets." else if (isTRUE(is_fitrmse_v47)) "Each family/quantile cell receives its own v4.6-anchored profile neighborhood; near-pass cells receive explicit fit-check guardrails, hard lower-tail cells retain compact fit-RMSE rescue, and normal-median/forecast-blocked cells receive longer-memory forecast guardrails." else if (isTRUE(is_fitrmse_v46)) "Each family/quantile cell receives its own v4.5-anchored profile neighborhood; hard cells focus on fit-RMSE or forecast-MAE rescue, while near-miss cells focus on the remaining fit-check or forecast blocker." else if (isTRUE(is_fitrmse_v45)) "Each family/quantile cell receives its own v4-anchored profile neighborhood; near-miss cells focus on the remaining check-loss or forecast-MAE blocker, while hard cells receive broader compact fit-RMSE or forecast-memory rescue candidates." else if (isTRUE(is_fitrmse_v4)) "Each family/quantile cell receives its own compact fit-first profile neighborhood from the completed v3 screen; cells whose bottleneck is forecast MAE receive extra forecast-memory guardrails." else if (isTRUE(is_fitrmse_v3)) "Each family/quantile cell receives its own compact fit-first profile neighborhood from the completed case-specific v2 screen." else "Each family/quantile cell receives its own profile neighborhood from the completed historical-winner handoff.",
  "This stage is screening-only until strict audit and explicit promotion."
)
smoke_assignment <- assignments[order(assignments$priority_rank, assignments$target_profile_rank), , drop = FALSE][1L, , drop = FALSE]
defaults$smoke <- defaults$smoke %||% list()
defaults$smoke$family <- as.character(smoke_assignment$family[[1L]])
defaults$smoke$tau <- as.numeric(smoke_assignment$tau[[1L]])
defaults$smoke$screening_profile_ids <- as.list(as.character(smoke_assignment$screening_profile_id[[1L]]))
defaults$smoke$fit_sizes <- 500L
defaults$smoke$priors <- as.list("rhs_ns")
defaults$smoke$max_roots <- 1L
defaults$smoke$case_specific_rhs_smoke_profile <- as.character(smoke_assignment$screening_profile_id[[1L]])
yaml::write_yaml(defaults, defaults_out)

cell_display <- cell_plan[, intersect(c(
  "priority_rank", "family", "tau", "cell_status", "bottleneck_metric",
  "target_profiles", "current_best_worst_ratio", "min_fit_rmse_ratio",
  "min_fit_check_ratio", "min_forecast_mae_ratio", "min_forecast_check_ratio",
  "best_fit_rmse_profile", "best_forecast_check_profile"
), names(cell_plan)), drop = FALSE]
profile_display <- profiles[, intersect(c(
  "target_family", "target_tau", "case_specific_profile_rank", "screening_profile_id",
  "profile_role", "D", "n_each", "alpha", "rho", "m", "pi_w", "pi_in", "rhs_tau0",
  "p_over_n_tt500", "target_source_profile"
), names(profiles)), drop = FALSE]
profile_display <- utils::head(profile_display, 80L)
summary_lines <- c(
  if (isTRUE(is_fitrmse_v50)) "# Q-DESN 500-Observation VB Case-Targeted RHS v5 Screen" else if (isTRUE(is_fitrmse_v49)) "# Q-DESN 500-Observation VB Case-Targeted RHS v4.9 Screen" else if (isTRUE(is_fitrmse_v48plus)) "# Q-DESN 500-Observation VB Case-Targeted RHS v4.8 Screen" else if (isTRUE(is_fitrmse_v47)) "# Q-DESN 500-Observation VB Case-Targeted RHS v4.7 Screen" else if (isTRUE(is_fitrmse_v46)) "# Q-DESN 500-Observation VB Case-Targeted RHS v4.6 Screen" else if (isTRUE(is_fitrmse_v45)) "# Q-DESN 500-Observation VB Case-Targeted RHS v4.5 Screen" else if (isTRUE(is_fitrmse_v4)) "# Q-DESN 500-Observation VB Case-Targeted RHS v4 Screen" else if (isTRUE(is_fitrmse_v3)) "# Q-DESN 500-Observation VB Case-Targeted RHS v3 Fit-RMSE Screen" else "# Q-DESN 500-Observation VB Case-Specific RHS Screen",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- screen_mode: `%s`", screen_mode),
  sprintf("- source_report_root: `%s`", source_report_root),
  sprintf("- baseline_path: `%s`", baseline_path),
  sprintf("- base_defaults_path: `%s`", base_defaults_path),
  sprintf("- likelihoods: `%s`", paste(likelihoods, collapse = ",")),
  sprintf("- target_cells: `%d`", nrow(cell_plan)),
  sprintf("- selected_profiles_and_roots: `%d`", as.integer(materialized$expected_qdesn_roots)),
  sprintf("- expected_vb_fits: `%d`", as.integer(materialized$expected_qdesn_roots) * length(likelihoods)),
  sprintf("- max_profiles_per_cell: `%d`", as.integer(max_profiles_per_cell)),
  sprintf("- max_p_over_n: `%s`", as.character(max_p_over_n)),
  "",
  "## Decision",
  "",
  if (isTRUE(is_fitrmse_v50)) {
    "The completed v4.9 screen is frozen as diagnostic evidence. It was technically complete and storage-light, but no family/quantile cell cleared the all-primary VB dominance gate. The useful signal is sharply cell-specific: near-miss cells need bridge designs that join fit-check and compact-fit anchors, while hard lower-tail or median cells need structural fit-RMSE or forecast-MAE rescue. This v5 follow-up keeps per-case specifications, uses exact v4.9 strict-audited anchors, expands only the blocker-relevant lanes, and still forbids MCMC promotion until a fresh strict-audited dominance ranking justifies it."
  } else if (isTRUE(is_fitrmse_v49)) {
    "The completed v4.8 screen is frozen as diagnostic evidence. It was technically complete and storage-light, but no family/quantile cell cleared the all-primary VB dominance gate. The useful signal remains cell-specific: some cells are close on all primary metrics, others need a narrower fit-check, forecast, or fit-RMSE rescue. This v4.9 follow-up keeps per-case specifications, uses the exact v4.8 strict-audited anchors, slightly expands candidate budgets only where the observed blocker warrants it, and still forbids MCMC promotion until a fresh strict-audited dominance ranking justifies it."
  } else if (isTRUE(is_fitrmse_v48plus)) {
    "The completed v4.7 screen is frozen as diagnostic evidence. It was technically complete and storage-light, but no family/quantile cell cleared the all-primary VB dominance gate. The useful signal is now cell-specific: several cells have metricwise winners but no single profile joining fit RMSE, fit check loss, forecast MAE, and forecast check loss, while the lower-tail and normal-median cells still need targeted blocker rescue. This v4.8 follow-up keeps per-case specifications, adds bridge candidates between the best metric-specific anchors, expands only hard-cell budgets, and still forbids MCMC promotion until a fresh strict-audited dominance ranking justifies it."
  } else if (isTRUE(is_fitrmse_v47)) {
    "The completed v4.6 screen is frozen as diagnostic evidence. It was technically complete and storage-light, but no family/quantile cell cleared the all-primary VB dominance gate. The key pattern is now clear: many cells are near misses blocked by fit check loss, while lower-tail hard cells still need fit-RMSE rescue and the normal median remains forecast-MAE sensitive. This v4.7 follow-up keeps case-specific specifications, adds an explicit fit-check guardrail role, centers local/scoring choices on the relevant blocker anchor, and still forbids MCMC promotion until a fresh strict-audited dominance ranking justifies it."
  } else if (isTRUE(is_fitrmse_v46)) {
    "The completed v4.5 screen is frozen as diagnostic evidence. It was technically complete and storage-light, but no family/quantile cell cleared the all-primary VB dominance gate. The strongest v4.5 candidates exposed one blocker per cell: fit RMSE in lower-tail hard cells, fit check loss in most near-pass cells, and forecast MAE for the normal median. This v4.6 follow-up keeps the user's per-case specification policy, reduces wasteful broad searching, and searches only blocker-specific neighborhoods before any MCMC promotion is considered."
  } else if (isTRUE(is_fitrmse_v45)) {
    "The completed v4 screen is frozen as diagnostic evidence. It was technically complete and storage-light, but no family/quantile cell cleared the all-primary VB dominance gate. Five cells are near misses, usually blocked by fit check loss or one forecast-MAE ratio; four cells remain hard because fit RMSE or forecast MAE is materially above the DQLM/exDQLM VB baseline. This v4.5 follow-up keeps case-specific specifications, expands the local compact neighborhood just enough to search the remaining bottleneck, and still forbids MCMC promotion until a fresh strict-audited dominance ranking justifies it."
  } else if (isTRUE(is_fitrmse_v4)) {
    "The completed v3 screen is frozen as diagnostic evidence. It was technically complete and storage-light, but no family/quantile cell cleared the all-primary gate because fit RMSE remained the universal bottleneck and median cells also showed forecast-MAE pressure. This v4 follow-up keeps case-specific specifications, concentrates on compact fit-first neighborhoods, and reserves forecast guardrails for cells where forecast MAE is the largest blocker."
  } else if (isTRUE(is_fitrmse_v3)) {
    "The completed case-specific RHS v2 screen is frozen as diagnostic evidence. It was technically complete and storage-light, but no candidate beat the current VB baseline on fit RMSE. This v3 follow-up keeps the user's case-specific policy: each family/quantile cell receives its own compact fit-first neighborhood, while forecast/check-loss guardrails remain in the candidate set."
  } else {
    "The historical-winner handoff is frozen as a diagnostic run. It is technically complete and storage-light, but it does not clear the current all-primary gate. This follow-up does not search for one global DESN specification. It assigns a separate candidate neighborhood to each family/quantile cell and permits the eventual winner to be case-specific."
  },
  "",
  "## Cell-Specific Diagnosis",
  "",
  md_table(cell_display, names(cell_display)),
  "",
  "## Selected Profile Preview",
  "",
  md_table(profile_display, names(profile_display)),
  "",
  "## Gates",
  "",
  "- This is VB-only screening with storage-light outputs.",
  if (isTRUE(is_fitrmse_v50)) "- The primary scientific gate is all-primary dominance; v5 is not MCMC-promotable unless a family/quantile winner beats the current VB baseline on fit RMSE, fit check loss, forecast MAE, and forecast check loss." else if (isTRUE(is_fitrmse_v49)) "- The primary scientific gate is all-primary dominance; v4.9 is not MCMC-promotable unless a family/quantile winner beats the current VB baseline on fit RMSE, fit check loss, forecast MAE, and forecast check loss." else if (isTRUE(is_fitrmse_v48plus)) "- The primary scientific gate is all-primary dominance; v4.8 is not MCMC-promotable unless a family/quantile winner beats the current VB baseline on fit RMSE, fit check loss, forecast MAE, and forecast check loss." else if (isTRUE(is_fitrmse_v47)) "- The primary scientific gate is all-primary dominance; v4.7 is not MCMC-promotable unless a family/quantile winner beats the current VB baseline on fit RMSE, fit check loss, forecast MAE, and forecast check loss." else if (isTRUE(is_fitrmse_v46)) "- The primary scientific gate is all-primary dominance; v4.6 is not MCMC-promotable unless a family/quantile winner beats the current VB baseline on fit RMSE, fit check loss, forecast MAE, and forecast check loss." else if (isTRUE(is_fitrmse_v45)) "- The primary scientific gate is all-primary dominance; v4.5 is not MCMC-promotable unless a family/quantile winner beats the current VB baseline on fit RMSE, fit check loss, forecast MAE, and forecast check loss." else if (isTRUE(is_fitrmse_v4)) "- The primary scientific gate is all-primary dominance; v4 is not MCMC-promotable unless a family/quantile winner beats the current VB baseline on fit RMSE, fit check loss, forecast MAE, and forecast check loss." else if (isTRUE(is_fitrmse_v3)) "- The primary scientific gate is all-primary dominance; the first bottleneck under v2 was fit RMSE, so v3 intentionally allocates more candidates to compact fit-first profiles." else "- The primary scientific gate is all-primary dominance against the current DQLM/exDQLM VB baseline.",
  "- MCMC promotion is per family/quantile cell, not global-profile based.",
  "- Article tables remain unchanged until a strict-audited promotion bundle is explicitly frozen.",
  "- Failed exploratory roots may be tolerated only as screening evidence; promoted rows must be terminal, metric-complete, and documented.",
  "",
  sprintf("- profiles: `%s`", profiles_out),
  sprintf("- assignments: `%s`", assignments_out),
  sprintf("- defaults: `%s`", defaults_out),
  sprintf("- grid: `%s`", grid_out),
  sprintf("- manifest: `%s`", manifest_path)
)
writeLines(summary_lines, diagnostic_paths$summary, useBytes = TRUE)
writeLines(summary_lines, doc_out, useBytes = TRUE)

file_manifest <- exdqlm:::qdesn_validation_file_manifest(c(
  cell_summary_path, fit_summary_path, audit_summary_path, baseline_path, base_defaults_path,
  profiles_out, assignments_out, defaults_out, grid_out,
  diagnostic_paths$cell_plan, diagnostic_paths$candidate_ledger,
  diagnostic_paths$selected_profiles, diagnostic_paths$cell_assignments,
  diagnostic_paths$summary, doc_out
))
manifest <- list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  stage_file = stage_file,
  screen_mode = screen_mode,
  source_report_root = source_report_root,
  cell_summary_path = cell_summary_path,
  fit_summary_path = fit_summary_path,
  audit_summary_path = audit_summary_path,
  baseline_path = baseline_path,
  base_defaults_path = base_defaults_path,
  likelihoods = as.list(likelihoods),
  workers = as.integer(workers),
  max_profiles_per_cell = as.integer(max_profiles_per_cell),
  max_p_over_n = as.numeric(max_p_over_n),
  refresh_grid = refresh_grid,
  refresh_materialized = refresh_materialized,
  plan = plan$manifest,
  materialized = materialized,
  diagnostic_paths = diagnostic_paths,
  doc_out = doc_out,
  file_manifest = file_manifest
)
write_json(manifest, diagnostic_paths$manifest)
write_json(manifest, manifest_path)

cat(sprintf("diagnostics: %s\n", diagnostic_out))
cat(sprintf("doc: %s\n", doc_out))
cat(sprintf("profiles: %s\n", profiles_out))
cat(sprintf("assignments: %s\n", assignments_out))
cat(sprintf("defaults: %s\n", defaults_out))
cat(sprintf("grid: %s\n", grid_out))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("n_profiles: %d\n", as.integer(materialized$n_profiles)))
cat(sprintf("n_assignments: %d\n", as.integer(materialized$n_assignments)))
cat(sprintf("n_grid_rows: %d\n", as.integer(materialized$n_grid_rows)))
cat(sprintf("expected_qdesn_roots: %d\n", as.integer(materialized$expected_qdesn_roots)))
cat(sprintf("expected_vb_fits: %d\n", as.integer(materialized$expected_qdesn_roots) * length(likelihoods)))

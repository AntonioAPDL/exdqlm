#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(raw)) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}
write_csv <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  path
}
fmt <- function(x, digits = 4) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.finite(x), formatC(x, digits = digits, format = "fg", flag = "#"), "NA")
}
md_table <- function(x, cols = names(x), max_rows = Inf) {
  cols <- intersect(cols, names(x))
  if (!length(cols) || !nrow(x)) return(c("| none |", "|---|"))
  y <- utils::head(x[, cols, drop = FALSE], max_rows)
  out <- c(
    paste("|", paste(cols, collapse = " | "), "|"),
    paste("|", paste(rep("---", length(cols)), collapse = " | "), "|")
  )
  for (i in seq_len(nrow(y))) {
    vals <- vapply(y[i, , drop = FALSE], function(z) {
      if (is.numeric(z)) fmt(z, 5) else {
        zz <- as.character(z)
        zz[is.na(zz)] <- "NA"
        zz
      }
    }, character(1))
    out <- c(out, paste("|", paste(vals, collapse = " | "), "|"))
  }
  out
}
bind_fill <- function(xs) {
  all_names <- unique(unlist(lapply(xs, names), use.names = FALSE))
  xs <- lapply(xs, function(x) {
    missing <- setdiff(all_names, names(x))
    for (nm in missing) x[[nm]] <- NA
    x[, all_names, drop = FALSE]
  })
  do.call(rbind, xs)
}

baseline_path <- resolve_path(get_arg(
  "--baseline",
  "validation/fitforecast_v2/docs/validation_local_exdqlm_dqlm_vb_baseline_20260708.csv"
))
out_root <- resolve_path(get_arg(
  "--out-root",
  file.path("reports", "qdesn_mcmc_validation", "posthoc", "qdesn_tt500_vb_break_surface_redesign_20260713")
), must_work = FALSE)

baseline <- utils::read.csv(baseline_path, check.names = FALSE, stringsAsFactors = FALSE)
baseline$tau <- suppressWarnings(as.numeric(baseline$tau))
baseline_best <- do.call(rbind, lapply(split(baseline, paste(baseline$family, baseline$tau)), function(z) {
  data.frame(
    family = as.character(z$family[[1L]]),
    tau = as.numeric(z$tau[[1L]]),
    b_fit_rmse = min(as.numeric(z$fit_qtrue_rmse), na.rm = TRUE),
    b_fit_check = min(as.numeric(z$fit_check_loss), na.rm = TRUE),
    b_forecast_mae = min(as.numeric(z$forecast_qtrue_mae_lead_weighted), na.rm = TRUE),
    b_forecast_check = min(as.numeric(z$forecast_check_loss_lead_weighted), na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))

screen_files <- list.files(
  file.path("reports", "qdesn_mcmc_validation"),
  pattern = "qdesn_tt500_vb_screen_fit_forecast_summary[.]csv$",
  recursive = TRUE,
  full.names = TRUE
)
screen_files <- screen_files[!grepl("smoke|pilot", screen_files, ignore.case = TRUE)]

read_screen <- function(path) {
  x <- tryCatch(utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) NULL)
  required <- c(
    "family", "tau", "likelihood_family", "status", "train_qtrue_rmse",
    "train_pinball_tau", "forecast_all_qtrue_mae", "forecast_all_pinball_mean"
  )
  if (is.null(x) || !all(required %in% names(x))) return(NULL)
  parts <- strsplit(path, "/", fixed = TRUE)[[1L]]
  x$file <- path
  x$stage <- parts[[length(parts) - 4L]]
  x$run_tag <- parts[[length(parts) - 3L]]
  x$stamp <- parts[[length(parts) - 2L]]
  x
}
screens <- Filter(Negate(is.null), lapply(screen_files, read_screen))
if (!length(screens)) stop("No compatible Q-DESN VB screen summaries found.", call. = FALSE)
screen <- bind_fill(screens)
screen <- screen[toupper(as.character(screen$status)) == "SUCCESS", , drop = FALSE]
screen$tau <- suppressWarnings(as.numeric(screen$tau))

screen <- merge(screen, baseline_best, by = c("family", "tau"), all.x = TRUE)
screen$r_fit_rmse <- suppressWarnings(as.numeric(screen$train_qtrue_rmse) / screen$b_fit_rmse)
screen$r_fit_check <- suppressWarnings(as.numeric(screen$train_pinball_tau) / screen$b_fit_check)
screen$r_forecast_mae <- suppressWarnings(as.numeric(screen$forecast_all_qtrue_mae) / screen$b_forecast_mae)
screen$r_forecast_check <- suppressWarnings(as.numeric(screen$forecast_all_pinball_mean) / screen$b_forecast_check)
screen$joint_worst_ratio <- do.call(pmax, c(
  screen[c("r_fit_rmse", "r_fit_check", "r_forecast_mae", "r_forecast_check")],
  list(na.rm = TRUE)
))
screen$beats_current_all_primary <- with(
  screen,
  r_fit_rmse < 1 & r_fit_check < 1 & r_forecast_mae < 1 & r_forecast_check < 1
)
screen$cell <- paste(screen$family, sprintf("%.2f", screen$tau), screen$likelihood_family, sep = ":")

best_by_run_cell <- do.call(rbind, lapply(split(screen, paste(screen$run_tag, screen$cell)), function(z) {
  z[order(z$joint_worst_ratio), , drop = FALSE][1L, , drop = FALSE]
}))

run_trend <- do.call(rbind, lapply(split(best_by_run_cell, best_by_run_cell$run_tag), function(z) {
  data.frame(
    stamp = as.character(z$stamp[[1L]]),
    stage = as.character(z$stage[[1L]]),
    run_tag = as.character(z$run_tag[[1L]]),
    n_cells = length(unique(z$cell)),
    n_cell_likelihood_pass = sum(z$beats_current_all_primary, na.rm = TRUE),
    median_best_joint_worst = median(z$joint_worst_ratio, na.rm = TRUE),
    max_best_joint_worst = max(z$joint_worst_ratio, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))
run_trend <- run_trend[order(run_trend$stamp, run_trend$run_tag), , drop = FALSE]

frontier <- do.call(rbind, lapply(split(screen, screen$cell), function(z) {
  metric_mins <- c(
    fit_rmse = min(z$r_fit_rmse, na.rm = TRUE),
    fit_check = min(z$r_fit_check, na.rm = TRUE),
    forecast_mae = min(z$r_forecast_mae, na.rm = TRUE),
    forecast_check = min(z$r_forecast_check, na.rm = TRUE)
  )
  joint <- z[order(z$joint_worst_ratio), , drop = FALSE][1L, , drop = FALSE]
  blockers <- names(metric_mins)[metric_mins >= 1]
  data.frame(
    family = as.character(joint$family[[1L]]),
    tau = as.numeric(joint$tau[[1L]]),
    likelihood_family = as.character(joint$likelihood_family[[1L]]),
    best_joint_worst_ratio = as.numeric(joint$joint_worst_ratio[[1L]]),
    best_current_all_primary = isTRUE(joint$beats_current_all_primary[[1L]]),
    min_fit_rmse_ratio = metric_mins[["fit_rmse"]],
    min_fit_check_ratio = metric_mins[["fit_check"]],
    min_forecast_mae_ratio = metric_mins[["forecast_mae"]],
    min_forecast_check_ratio = metric_mins[["forecast_check"]],
    metricwise_blockers = if (length(blockers)) paste(blockers, collapse = ";") else "none",
    best_stage = as.character(joint$stage[[1L]]),
    best_run_tag = as.character(joint$run_tag[[1L]]),
    best_profile_role = as.character(joint$profile_role[[1L]] %||% NA_character_),
    best_profile_id = as.character(joint$screening_profile_id[[1L]] %||% joint$screening_profile_base[[1L]] %||% NA_character_),
    stringsAsFactors = FALSE
  )
}))
frontier <- frontier[order(frontier$family, frontier$tau, frontier$likelihood_family), , drop = FALSE]

v51 <- screen[grepl("case_targeted_rhs_v51", screen$file), , drop = FALSE]
v51_best <- if (nrow(v51)) {
  do.call(rbind, lapply(split(v51, v51$cell), function(z) {
    best <- z[order(z$joint_worst_ratio), , drop = FALSE][1L, , drop = FALSE]
    ratios <- c(
      fit_rmse = best$r_fit_rmse,
      fit_check = best$r_fit_check,
      forecast_mae = best$r_forecast_mae,
      forecast_check = best$r_forecast_check
    )
    blockers <- names(ratios)[ratios >= 1]
    data.frame(
      family = as.character(best$family[[1L]]),
      tau = as.numeric(best$tau[[1L]]),
      likelihood_family = as.character(best$likelihood_family[[1L]]),
      joint_worst_ratio = as.numeric(best$joint_worst_ratio[[1L]]),
      blockers = if (length(blockers)) paste(blockers, collapse = ";") else "none",
      iter_like = suppressWarnings(as.integer(best$iter_like[[1L]] %||% NA_integer_)),
      converged = as.character(best$converged[[1L]] %||% NA_character_),
      stop_reason = as.character(best$stop_reason[[1L]] %||% NA_character_),
      profile_role = as.character(best$profile_role[[1L]] %||% NA_character_),
      screening_profile_id = as.character(best$screening_profile_id[[1L]] %||% NA_character_),
      stringsAsFactors = FALSE
    )
  }))
} else {
  data.frame()
}
if (nrow(v51_best)) v51_best <- v51_best[order(v51_best$family, v51_best$tau, v51_best$likelihood_family), , drop = FALSE]

param_cols <- intersect(c("D", "n_each", "alpha", "rho", "m", "pi_w", "pi_in", "rhs_tau0", "p_over_n_tt500"), names(v51))
cor_rows <- list()
if (nrow(v51) && length(param_cols)) {
  for (param in param_cols) {
    v51[[param]] <- suppressWarnings(as.numeric(v51[[param]]))
    for (metric in c("joint_worst_ratio", "r_fit_rmse", "r_fit_check", "r_forecast_mae", "r_forecast_check")) {
      cor_rows[[length(cor_rows) + 1L]] <- data.frame(
        parameter = param,
        metric = metric,
        spearman = suppressWarnings(cor(v51[[param]], v51[[metric]], method = "spearman", use = "pairwise.complete.obs")),
        stringsAsFactors = FALSE
      )
    }
  }
}
parameter_correlations_v51 <- if (length(cor_rows)) do.call(rbind, cor_rows) else data.frame()

near_rule <- frontier$best_joint_worst_ratio <= 1.08 |
  (!grepl("fit_rmse|forecast_mae|forecast_check", frontier$metricwise_blockers) & frontier$best_joint_worst_ratio <= 1.12)
frontier$recommended_lane <- ifelse(
  frontier$best_current_all_primary,
  "eligible_for_confirmation_not_automatic_mcmc",
  ifelse(
    near_rule,
    "small_metric_bridge_screen",
    ifelse(
      grepl("fit_rmse|forecast_mae|forecast_check", frontier$metricwise_blockers),
      "new_design_axis_required",
      "narrow_check_loss_bridge"
    )
  )
)

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
run_path <- write_csv(run_trend, file.path(out_root, "tables", "qdesn_tt500_vb_current_baseline_run_trend.csv"))
frontier_path <- write_csv(frontier, file.path(out_root, "tables", "qdesn_tt500_vb_current_baseline_frontier.csv"))
v51_path <- write_csv(v51_best, file.path(out_root, "tables", "qdesn_tt500_vb_v51_by_likelihood_blockers.csv"))
cor_path <- write_csv(parameter_correlations_v51, file.path(out_root, "tables", "qdesn_tt500_vb_v51_parameter_correlations.csv"))

summary <- data.frame(
  generated_at = as.character(Sys.time()),
  baseline_path = baseline_path,
  n_screen_files = length(unique(screen$file)),
  n_success_rows = nrow(screen),
  n_cell_likelihoods = length(unique(screen$cell)),
  n_current_all_primary_frontier = sum(frontier$best_current_all_primary, na.rm = TRUE),
  n_new_design_axis_required = sum(frontier$recommended_lane == "new_design_axis_required", na.rm = TRUE),
  n_small_bridge = sum(frontier$recommended_lane %in% c("small_metric_bridge_screen", "narrow_check_loss_bridge"), na.rm = TRUE),
  run_trend_csv = run_path,
  frontier_csv = frontier_path,
  v51_blockers_csv = v51_path,
  v51_correlations_csv = cor_path,
  stringsAsFactors = FALSE
)
summary_path <- write_csv(summary, file.path(out_root, "tables", "qdesn_tt500_vb_break_surface_redesign_summary.csv"))

lines <- c(
  "# Q-DESN VB Break-Surface Redesign Audit",
  "",
  sprintf("- generated_at: `%s`", summary$generated_at[[1L]]),
  sprintf("- baseline: `%s`", baseline_path),
  sprintf("- screen_files: `%s`", summary$n_screen_files[[1L]]),
  sprintf("- success_rows_rescored: `%s`", summary$n_success_rows[[1L]]),
  sprintf("- output_root: `%s`", out_root),
  "",
  "## Summary",
  "",
  md_table(summary, c(
    "n_screen_files", "n_success_rows", "n_cell_likelihoods",
    "n_current_all_primary_frontier", "n_new_design_axis_required", "n_small_bridge"
  )),
  "",
  "## Frontier By Cell And Likelihood",
  "",
  md_table(frontier, c(
    "family", "tau", "likelihood_family", "best_joint_worst_ratio",
    "metricwise_blockers", "recommended_lane", "best_stage", "best_profile_role"
  )),
  "",
  "## v5.1 Best Rows By Cell And Likelihood",
  "",
  md_table(v51_best, c(
    "family", "tau", "likelihood_family", "joint_worst_ratio",
    "blockers", "iter_like", "converged", "stop_reason", "profile_role"
  )),
  "",
  "## Output Tables",
  "",
  sprintf("- summary_csv: `%s`", summary_path),
  sprintf("- run_trend_csv: `%s`", run_path),
  sprintf("- frontier_csv: `%s`", frontier_path),
  sprintf("- v51_blockers_csv: `%s`", v51_path),
  sprintf("- v51_correlations_csv: `%s`", cor_path)
)
summary_md <- file.path(out_root, "summary", "qdesn_tt500_vb_break_surface_redesign_audit.md")
dir.create(dirname(summary_md), recursive = TRUE, showWarnings = FALSE)
writeLines(lines, summary_md)
message("Wrote audit summary: ", summary_md)

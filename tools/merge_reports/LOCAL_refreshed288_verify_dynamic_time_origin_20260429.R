#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- grep(paste0("^", prefix), args, value = TRUE)
  if (!length(hit)) {
    return(default)
  }
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

repo_root <- normalizePath(arg_value("repo-root", getwd()), mustWork = TRUE)
run_tag <- arg_value("run-tag", "20260429_p90_dynamic72_qdesn_comparable_v1")
registry_path <- arg_value(
  "registry",
  file.path(repo_root, "tools/merge_reports/LOCAL_refreshed288_dataset_registry_20260429_p90_dynamic72_qdesn_comparable_v1.csv")
)
report_dir <- arg_value("report-dir", file.path(repo_root, "reports/static_exal_tuning_20260429"))
stop_on_fail <- tolower(arg_value("stop-on-fail", "true")) %in% c("1", "true", "yes", "y")

dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)

out_csv <- file.path(report_dir, sprintf("refreshed288_dynamic72_time_origin_verification_%s.csv", run_tag))
out_md <- file.path(report_dir, sprintf("refreshed288_dynamic72_time_origin_verification_%s.md", run_tag))

load_ok <- requireNamespace("pkgload", quietly = TRUE)
if (load_ok) {
  pkgload::load_all(repo_root, quiet = TRUE)
}
source(file.path(repo_root, "tools/merge_reports/20260305_dynamic_dgp_model_helpers.R"))

read_required_csv <- function(path) {
  if (!file.exists(path)) {
    stop("Missing required CSV: ", path, call. = FALSE)
  }
  read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}

as_num_vec <- function(x, default = NA_real_) {
  if (is.null(x) || !length(x) || is.na(x[1L]) || !nzchar(as.character(x[1L]))) {
    return(default)
  }
  vals <- suppressWarnings(as.numeric(trimws(strsplit(as.character(x[1L]), ",", fixed = TRUE)[[1L]])))
  vals[is.finite(vals)]
}

safe_num <- function(x, default = NA_real_) {
  val <- suppressWarnings(as.numeric(x[1L]))
  if (!is.finite(val)) default else val
}

safe_int <- function(x, default = NA_integer_) {
  val <- suppressWarnings(as.integer(x[1L]))
  if (!is.finite(val)) default else val
}

dynamic_params_from_registry_row <- function(row) {
  list(
    period = safe_int(row$period, 90L),
    harmonics = as.integer(as_num_vec(row$harmonics, c(1, 2))),
    C0_scale = safe_num(row$dynamic_C0_scale, 0.01),
    initial_state_mode = as.character(row$dynamic_initial_state_mode[1L]),
    level0 = safe_num(row$dynamic_level0, 0),
    slope0 = safe_num(row$dynamic_slope0, 0),
    seasonal_amplitudes = c(
      safe_num(row$dynamic_harmonic1_amplitude, 0),
      safe_num(row$dynamic_harmonic2_amplitude, 0)
    ),
    seasonal_phases = c(
      safe_num(row$dynamic_harmonic1_phase, 0),
      safe_num(row$dynamic_harmonic2_phase, 0)
    )
  )
}

first_one_step_signal <- function(model) {
  state1 <- as.numeric(as.matrix(model$GG) %*% as.numeric(model$m0))
  sum(as.numeric(model$FF) * state1)
}

format_num <- function(x, digits = 4L) {
  ifelse(is.na(x), "NA", format(round(x, digits), nsmall = digits, trim = TRUE))
}

registry <- read_required_csv(registry_path)
dynamic_registry <- registry[registry$block == "dynamic" & registry$root_kind == "dynamic", , drop = FALSE]

if (nrow(dynamic_registry) != 18L) {
  stop("Expected 18 dynamic registry rows, found ", nrow(dynamic_registry), call. = FALSE)
}

results <- lapply(seq_len(nrow(dynamic_registry)), function(i) {
  row <- dynamic_registry[i, , drop = FALSE]
  series <- read_required_csv(row$series_wide_path[1L])
  if (!nrow(series)) {
    stop("Empty dynamic series: ", row$series_wide_path[1L], call. = FALSE)
  }
  if (!"t" %in% names(series)) {
    stop("Dynamic series does not contain source index column `t`: ", row$series_wide_path[1L], call. = FALSE)
  }
  q_col <- if ("q_target" %in% names(series)) "q_target" else if ("mu" %in% names(series)) "mu" else NA_character_
  if (is.na(q_col)) {
    stop("Dynamic series lacks both `q_target` and `mu`: ", row$series_wide_path[1L], call. = FALSE)
  }

  params <- dynamic_params_from_registry_row(row)
  source_start <- safe_int(series$t[1L], 1L)
  TT <- nrow(series)
  local_model <- build_dynamic_dgp_matched_model(params = params, TT = TT, backend = "R", start_index = 1L)
  aligned_model <- build_dynamic_dgp_matched_model(params = params, TT = TT, backend = "R", start_index = source_start)

  q_first <- safe_num(series[[q_col]][1L], NA_real_)
  local_signal <- first_one_step_signal(local_model)
  aligned_signal <- first_one_step_signal(aligned_model)
  local_abs_error <- abs(local_signal - q_first)
  aligned_abs_error <- abs(aligned_signal - q_first)

  data.frame(
    dataset_id = row$dataset_id[1L],
    family = row$family[1L],
    tau_label = row$tau_label[1L],
    fit_size = safe_int(row$fit_size, NA_integer_),
    source_index_start = source_start,
    source_index_end = safe_int(utils::tail(series$t, 1L), NA_integer_),
    q_true_first = q_first,
    local_first_signal = local_signal,
    source_aligned_first_signal = aligned_signal,
    local_abs_error = local_abs_error,
    source_aligned_abs_error = aligned_abs_error,
    improvement_factor = if (aligned_abs_error > 0) local_abs_error / aligned_abs_error else Inf,
    status = if (is.finite(aligned_abs_error) && aligned_abs_error < local_abs_error) "pass" else "fail",
    series_wide_path = row$series_wide_path[1L],
    stringsAsFactors = FALSE
  )
})

out <- do.call(rbind, results)
utils::write.csv(out, out_csv, row.names = FALSE)

all_improved <- all(out$status == "pass")
median_local <- stats::median(out$local_abs_error, na.rm = TRUE)
median_aligned <- stats::median(out$source_aligned_abs_error, na.rm = TRUE)
median_pass <- is.finite(median_local) && is.finite(median_aligned) && median_aligned < median_local / 2
overall_status <- if (all_improved && median_pass) "PASS" else "FAIL"

md <- c(
  "# Dynamic Time-Origin Verification",
  "",
  sprintf("- Generated: `%s`", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  sprintf("- Run tag: `%s`", run_tag),
  sprintf("- Registry: `%s`", registry_path),
  sprintf("- Overall status: `%s`", overall_status),
  "",
  "## Purpose",
  "",
  "This check verifies that canonical tail-window dynamic fits start the DQLM/exDQLM model at the same source time as the data window. It compares the first one-step model signal under the old local-origin convention (`start_index = 1`) against the source-index aligned convention (`start_index = first t in series_wide.csv`).",
  "",
  "The fix does not add Q-DESN washout observations. It only aligns the model prior mean to the canonical source index of the existing `fit_input_lastTT500` or `fit_input_lastTT5000` window.",
  "",
  "## Summary",
  "",
  "| Check | Value |",
  "| --- | ---: |",
  sprintf("| Dynamic windows checked | %d |", nrow(out)),
  sprintf("| Rows improved by source alignment | %d |", sum(out$status == "pass")),
  sprintf("| Median local-origin first-signal abs error | %s |", format_num(median_local)),
  sprintf("| Median source-aligned first-signal abs error | %s |", format_num(median_aligned)),
  sprintf("| Overall status | `%s` |", overall_status),
  "",
  "## Row-Level Evidence",
  "",
  "| Dataset | Source Start | q_true First | Local Signal | Aligned Signal | Local Abs Err | Aligned Abs Err | Status |",
  "| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |"
)

row_lines <- vapply(seq_len(nrow(out)), function(i) {
  sprintf(
    "| `%s` | %d | %s | %s | %s | %s | %s | `%s` |",
    out$dataset_id[i],
    out$source_index_start[i],
    format_num(out$q_true_first[i]),
    format_num(out$local_first_signal[i]),
    format_num(out$source_aligned_first_signal[i]),
    format_num(out$local_abs_error[i]),
    format_num(out$source_aligned_abs_error[i]),
    out$status[i]
  )
}, character(1))

md <- c(
  md,
  row_lines,
  "",
  "## Interpretation",
  "",
  "The old local-origin convention is a poor match for late windows because it restarts the trend and seasonal state at the root initial state. The aligned convention propagates the DGP-matched prior mean to the state immediately before the first retained source observation, preserving the same tail-window observations and the same compact retention policy.",
  "",
  sprintf("CSV details: `%s`", out_csv),
  ""
)

writeLines(md, out_md)

cat(sprintf("time_origin_verification=%s rows=%d improved=%d median_local=%.6f median_aligned=%.6f\n",
            overall_status, nrow(out), sum(out$status == "pass"), median_local, median_aligned))
cat(sprintf("wrote_csv=%s\n", out_csv))
cat(sprintf("wrote_md=%s\n", out_md))

if (stop_on_fail && !identical(overall_status, "PASS")) {
  stop("Dynamic time-origin verification failed.", call. = FALSE)
}

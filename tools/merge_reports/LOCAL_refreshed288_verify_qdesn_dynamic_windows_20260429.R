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
scenario_id <- arg_value("scenario-id", "dlm_constV_p90_m0amp_highnoise_steepertrend_v1")

registry_path <- arg_value(
  "registry",
  file.path(
    repo_root,
    "tools/merge_reports/LOCAL_refreshed288_dataset_registry_20260422_dynamic_p90_steepertrend_v1.csv"
  )
)

qdesn_source_root <- arg_value(
  "qdesn-source-root",
  file.path(
    "/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration",
    "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_main_sources",
    scenario_id
  )
)

report_dir <- arg_value(
  "report-dir",
  file.path(repo_root, "reports/static_exal_tuning_20260429")
)

tol <- as.numeric(arg_value("tol", "1e-10"))
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)

out_csv <- file.path(report_dir, "refreshed288_dynamic72_qdesn_window_verification_20260429.csv")
out_md <- file.path(report_dir, "refreshed288_dynamic72_qdesn_window_verification_20260429.md")

safe_sys <- function(cmd, args = character()) {
  out <- tryCatch(
    system2(cmd, args = args, stdout = TRUE, stderr = TRUE),
    error = function(e) NA_character_
  )
  if (!length(out)) {
    return(NA_character_)
  }
  paste(out, collapse = " ")
}

hash_object <- function(x) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    return(NA_character_)
  }
  digest::digest(x, algo = "sha256")
}

read_required_csv <- function(path) {
  if (!file.exists(path)) {
    stop("Missing required CSV: ", path, call. = FALSE)
  }
  read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}

format_tau_dir <- function(tau_label) {
  paste0("tau_", tau_label)
}

qdesn_window_label <- function(fit_size) {
  if (fit_size == 500L) {
    return("effTT500_totalTT813")
  }
  if (fit_size == 5000L) {
    return("effTT5000_totalTT5313")
  }
  stop("Unexpected dynamic fit_size: ", fit_size, call. = FALSE)
}

qdesn_total_size <- function(fit_size) {
  if (fit_size == 500L) {
    return(813L)
  }
  if (fit_size == 5000L) {
    return(5313L)
  }
  stop("Unexpected dynamic fit_size: ", fit_size, call. = FALSE)
}

max_abs_diff <- function(a, b, cols) {
  if (!length(cols)) {
    return(0)
  }
  diffs <- vapply(cols, function(col) {
    max(abs(a[[col]] - b[[col]]), na.rm = TRUE)
  }, numeric(1))
  max(diffs, na.rm = TRUE)
}

registry <- read_required_csv(registry_path)
dynamic_registry <- registry[registry$block == "dynamic" & registry$root_kind == "dynamic", , drop = FALSE]

if (nrow(dynamic_registry) != 18L) {
  stop("Expected 18 dynamic registry rows, found ", nrow(dynamic_registry), call. = FALSE)
}

missing_inputs <- dynamic_registry$missing_inputs %in% TRUE | dynamic_registry$missing_inputs == "TRUE"
if (any(missing_inputs, na.rm = TRUE)) {
  stop(
    "Dynamic registry has missing inputs for: ",
    paste(dynamic_registry$dataset_id[missing_inputs], collapse = ", "),
    call. = FALSE
  )
}

results <- lapply(seq_len(nrow(dynamic_registry)), function(i) {
  row <- dynamic_registry[i, , drop = FALSE]
  fit_size <- as.integer(row$fit_size)
  expected_qdesn_n <- qdesn_total_size(fit_size)
  window_label <- qdesn_window_label(fit_size)
  canonical_path <- row$series_wide_path
  canonical_true_path <- row$true_quantile_grid_path
  qdesn_path <- file.path(
    qdesn_source_root,
    row$family,
    format_tau_dir(row$tau_label),
    paste0("fit_input_", window_label),
    "series_wide.csv"
  )

  canonical_exists <- file.exists(canonical_path)
  qdesn_exists <- file.exists(qdesn_path)
  true_grid_exists <- file.exists(canonical_true_path)

  if (!canonical_exists || !qdesn_exists || !true_grid_exists) {
    return(data.frame(
      dataset_id = row$dataset_id,
      family = row$family,
      tau = as.numeric(row$tau),
      tau_label = row$tau_label,
      fit_size = fit_size,
      qdesn_window_label = window_label,
      expected_qdesn_rows = expected_qdesn_n,
      canonical_rows = NA_integer_,
      qdesn_rows = NA_integer_,
      canonical_t_start = NA_integer_,
      canonical_t_end = NA_integer_,
      qdesn_tail_t_start = NA_integer_,
      qdesn_tail_t_end = NA_integer_,
      compared_columns = NA_character_,
      max_numeric_abs_diff = NA_real_,
      max_qtrue_mu_abs_diff_canonical = NA_real_,
      max_qtrue_mu_abs_diff_qdesn_tail = NA_real_,
      column_names_match = FALSE,
      non_numeric_values_match = FALSE,
      hashes_match = FALSE,
      canonical_tail_hash = NA_character_,
      qdesn_tail_hash = NA_character_,
      status = "fail",
      issue = paste(
        c(
          if (!canonical_exists) "missing canonical series_wide",
          if (!qdesn_exists) "missing qdesn staged series_wide",
          if (!true_grid_exists) "missing canonical true_quantile_grid"
        ),
        collapse = "; "
      ),
      canonical_path = canonical_path,
      qdesn_path = qdesn_path,
      stringsAsFactors = FALSE
    ))
  }

  canonical <- read_required_csv(canonical_path)
  qdesn <- read_required_csv(qdesn_path)
  qdesn_tail <- utils::tail(qdesn, fit_size)

  names_match <- identical(names(canonical), names(qdesn_tail))
  common_cols <- intersect(names(canonical), names(qdesn_tail))
  numeric_cols <- common_cols[
    vapply(canonical[common_cols], is.numeric, logical(1)) &
      vapply(qdesn_tail[common_cols], is.numeric, logical(1))
  ]
  non_numeric_cols <- setdiff(common_cols, numeric_cols)

  numeric_diff <- max_abs_diff(canonical, qdesn_tail, numeric_cols)
  non_numeric_match <- TRUE
  if (length(non_numeric_cols)) {
    non_numeric_match <- all(vapply(non_numeric_cols, function(col) {
      identical(as.character(canonical[[col]]), as.character(qdesn_tail[[col]]))
    }, logical(1)))
  }

  canonical_qtrue_mu_diff <- if (all(c("q_target", "mu") %in% names(canonical))) {
    max(abs(canonical$q_target - canonical$mu), na.rm = TRUE)
  } else {
    NA_real_
  }
  qdesn_qtrue_mu_diff <- if (all(c("q_target", "mu") %in% names(qdesn_tail))) {
    max(abs(qdesn_tail$q_target - qdesn_tail$mu), na.rm = TRUE)
  } else {
    NA_real_
  }

  canonical_hash <- hash_object(canonical[common_cols])
  qdesn_hash <- hash_object(qdesn_tail[common_cols])
  hashes_match <- !is.na(canonical_hash) && identical(canonical_hash, qdesn_hash)

  pass <- isTRUE(nrow(canonical) == fit_size) &&
    isTRUE(nrow(qdesn) == expected_qdesn_n) &&
    names_match &&
    isTRUE(numeric_diff <= tol) &&
    non_numeric_match &&
    isTRUE(canonical_qtrue_mu_diff <= tol) &&
    isTRUE(qdesn_qtrue_mu_diff <= tol) &&
    isTRUE(canonical$t[1] == qdesn_tail$t[1]) &&
    isTRUE(canonical$t[nrow(canonical)] == qdesn_tail$t[nrow(qdesn_tail)])

  issues <- character()
  if (nrow(canonical) != fit_size) {
    issues <- c(issues, paste0("canonical row count ", nrow(canonical), " != ", fit_size))
  }
  if (nrow(qdesn) != expected_qdesn_n) {
    issues <- c(issues, paste0("qdesn row count ", nrow(qdesn), " != ", expected_qdesn_n))
  }
  if (!names_match) {
    issues <- c(issues, "column names differ")
  }
  if (!isTRUE(numeric_diff <= tol)) {
    issues <- c(issues, paste0("numeric max abs diff ", signif(numeric_diff, 6), " > ", tol))
  }
  if (!non_numeric_match) {
    issues <- c(issues, "non-numeric values differ")
  }
  if (!isTRUE(canonical_qtrue_mu_diff <= tol) || !isTRUE(qdesn_qtrue_mu_diff <= tol)) {
    issues <- c(issues, "q_target != mu")
  }

  data.frame(
    dataset_id = row$dataset_id,
    family = row$family,
    tau = as.numeric(row$tau),
    tau_label = row$tau_label,
    fit_size = fit_size,
    qdesn_window_label = window_label,
    expected_qdesn_rows = expected_qdesn_n,
    canonical_rows = nrow(canonical),
    qdesn_rows = nrow(qdesn),
    canonical_t_start = canonical$t[1],
    canonical_t_end = canonical$t[nrow(canonical)],
    qdesn_tail_t_start = qdesn_tail$t[1],
    qdesn_tail_t_end = qdesn_tail$t[nrow(qdesn_tail)],
    compared_columns = paste(common_cols, collapse = "|"),
    max_numeric_abs_diff = numeric_diff,
    max_qtrue_mu_abs_diff_canonical = canonical_qtrue_mu_diff,
    max_qtrue_mu_abs_diff_qdesn_tail = qdesn_qtrue_mu_diff,
    column_names_match = names_match,
    non_numeric_values_match = non_numeric_match,
    hashes_match = hashes_match,
    canonical_tail_hash = canonical_hash,
    qdesn_tail_hash = qdesn_hash,
    status = if (pass) "pass" else "fail",
    issue = if (length(issues)) paste(issues, collapse = "; ") else "",
    canonical_path = canonical_path,
    qdesn_path = qdesn_path,
    stringsAsFactors = FALSE
  )
})

verification <- do.call(rbind, results)
utils::write.csv(verification, out_csv, row.names = FALSE, na = "")

status_counts <- as.data.frame(table(verification$status), stringsAsFactors = FALSE)
names(status_counts) <- c("status", "n")

by_fit <- aggregate(
  list(rows = verification$status == "pass"),
  by = list(fit_size = verification$fit_size),
  FUN = sum
)
by_fit$total <- as.integer(table(verification$fit_size)[as.character(by_fit$fit_size)])
by_fit$pct_pass <- round(100 * by_fit$rows / by_fit$total, 1)

by_family <- aggregate(
  list(rows = verification$status == "pass"),
  by = list(family = verification$family),
  FUN = sum
)
by_family$total <- as.integer(table(verification$family)[as.character(by_family$family)])
by_family$pct_pass <- round(100 * by_family$rows / by_family$total, 1)

md_table <- function(x) {
  if (!nrow(x)) {
    return("_No rows._")
  }
  cols <- names(x)
  lines <- c(
    paste0("| ", paste(cols, collapse = " | "), " |"),
    paste0("| ", paste(rep("---", length(cols)), collapse = " | "), " |")
  )
  for (i in seq_len(nrow(x))) {
    lines <- c(lines, paste0("| ", paste(as.character(x[i, , drop = TRUE]), collapse = " | "), " |"))
  }
  paste(lines, collapse = "\n")
}

git_branch <- safe_sys("git", c("-C", repo_root, "branch", "--show-current"))
git_sha <- safe_sys("git", c("-C", repo_root, "rev-parse", "--short=12", "HEAD"))
timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")

summary_lines <- c(
  "# Dynamic 72 Q-DESN Window Verification",
  "",
  paste0("- Timestamp: `", timestamp, "`"),
  paste0("- Run tag: `", run_tag, "`"),
  paste0("- Branch: `", git_branch, "`"),
  paste0("- Git SHA: `", git_sha, "`"),
  paste0("- Scenario: `", scenario_id, "`"),
  paste0("- Validation registry: `", registry_path, "`"),
  paste0("- Q-DESN staged source root: `", qdesn_source_root, "`"),
  "",
  "## Contract",
  "",
  "- The 0.4.0 validation relaunch uses only canonical `fit_input_lastTT500` and `fit_input_lastTT5000` windows.",
  "- Q-DESN uses staged source windows of length `813` and `5313`; only their final `500` or `5000` rows are effective after washout.",
  "- DQLM/exDQLM must not receive the Q-DESN washout prefix as extra fitting data.",
  "- The quantile truth convention is `q_true = mu`, represented in these CSVs as `q_target = mu`.",
  "",
  "## Result",
  "",
  md_table(status_counts),
  "",
  "## Pass Counts By Fit Size",
  "",
  md_table(by_fit),
  "",
  "## Pass Counts By Family",
  "",
  md_table(by_family),
  "",
  "## Numeric Tolerances",
  "",
  paste0("- Max allowed absolute numeric difference: `", tol, "`"),
  paste0("- Observed max numeric absolute difference: `", signif(max(verification$max_numeric_abs_diff, na.rm = TRUE), 8), "`"),
  paste0("- Observed max canonical `abs(q_target - mu)`: `", signif(max(verification$max_qtrue_mu_abs_diff_canonical, na.rm = TRUE), 8), "`"),
  paste0("- Observed max Q-DESN-tail `abs(q_target - mu)`: `", signif(max(verification$max_qtrue_mu_abs_diff_qdesn_tail, na.rm = TRUE), 8), "`"),
  "",
  "## Detailed CSV",
  "",
  paste0("- `", out_csv, "`")
)

if (any(verification$status != "pass")) {
  failures <- verification[verification$status != "pass", c("dataset_id", "issue"), drop = FALSE]
  summary_lines <- c(
    summary_lines,
    "",
    "## Failures",
    "",
    md_table(failures)
  )
}

writeLines(summary_lines, out_md)

cat("Wrote verification CSV: ", out_csv, "\n", sep = "")
cat("Wrote verification report: ", out_md, "\n", sep = "")
cat("Status counts:\n")
print(status_counts, row.names = FALSE)

if (any(verification$status != "pass")) {
  stop("Dataset-window verification failed; see report for details.", call. = FALSE)
}

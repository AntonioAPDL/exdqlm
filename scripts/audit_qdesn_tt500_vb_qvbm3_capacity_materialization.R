#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "yaml")
  missing <- setdiff(req, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

write_csv <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

write_json <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

sha256_file <- function(path) unname(tools::sha256sum(resolve_path(path)))
num <- function(x) suppressWarnings(as.numeric(x))

md_table <- function(df, cols = names(df), max_rows = Inf) {
  if (!nrow(df)) return("_No rows._")
  cols <- intersect(cols, names(df))
  x <- df[, cols, drop = FALSE]
  if (is.finite(max_rows) && nrow(x) > max_rows) x <- utils::head(x, max_rows)
  x[] <- lapply(x, function(col) {
    if (is.numeric(col)) {
      ifelse(is.na(col), "", format(round(col, 4), trim = TRUE, scientific = FALSE))
    } else {
      val <- as.character(col)
      val[is.na(val)] <- ""
      val
    }
  })
  header <- paste0("| ", paste(cols, collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", length(cols)), collapse = "|"), "|")
  rows <- apply(x, 1L, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
  paste(c(header, sep, rows), collapse = "\n")
}

index_path <- get_arg("--bundle-index", "config/validation/qvbm3_capacity_bundle_index.csv")
index_path <- resolve_path(index_path)
index <- utils::read.csv(index_path, stringsAsFactors = FALSE, check.names = FALSE)

required_index <- c("bundle_code", "defaults_path", "grid_path", "profiles_path", "assignments_path", "target_spec_ids_path", "manifest_path")
if (!all(required_index %in% names(index))) {
  stop(sprintf("Bundle index missing required columns: %s", paste(setdiff(required_index, names(index)), collapse = ", ")), call. = FALSE)
}

required_profile_cols <- c(
  "screening_profile_id", "D", "n_each", "m", "readout_y_lags", "reservoir_lags",
  "alpha", "rho", "pi_w", "pi_in", "rhs_tau0", "dimension_p_estimate",
  "p_over_n_tt500", "capacity_tier", "cell_target_role", "target_family",
  "target_tau", "likelihood_target", "blocker_target", "source_baseline_screen",
  "source_frontier_row", "launch_gate", "article_facing"
)

rows <- list()
problems <- character()
all_profiles <- list()
all_paths <- c(index_path)

for (i in seq_len(nrow(index))) {
  idx <- index[i, , drop = FALSE]
  paths <- vapply(required_index[-1L], function(col) resolve_path(idx[[col]][[1L]]), character(1L))
  all_paths <- c(all_paths, paths)
  profiles <- utils::read.csv(paths[["profiles_path"]], stringsAsFactors = FALSE, check.names = FALSE)
  grid <- utils::read.csv(paths[["grid_path"]], stringsAsFactors = FALSE, check.names = FALSE)
  assignments <- utils::read.csv(paths[["assignments_path"]], stringsAsFactors = FALSE, check.names = FALSE)
  target_specs <- utils::read.csv(paths[["target_spec_ids_path"]], stringsAsFactors = FALSE, check.names = FALSE)
  defaults <- yaml::read_yaml(paths[["defaults_path"]])
  manifest <- jsonlite::read_json(paths[["manifest_path"]], simplifyVector = TRUE)
  all_profiles[[length(all_profiles) + 1L]] <- profiles

  bundle_problems <- character()
  missing_profile <- setdiff(required_profile_cols, names(profiles))
  if (length(missing_profile)) bundle_problems <- c(bundle_problems, sprintf("missing_profile_cols=%s", paste(missing_profile, collapse = "|")))
  methods <- as.character((defaults$execution %||% list())$methods %||% character())
  if (!identical(methods, "vb")) bundle_problems <- c(bundle_problems, sprintf("active_methods_not_vb_only=%s", paste(methods, collapse = "|")))
  if (!isTRUE((defaults$pipeline$validation_guardrails %||% list())$allow_dlm_decomp_lags)) {
    bundle_problems <- c(bundle_problems, "decomp_lag_guard_not_explicitly_allowed")
  }
  if (any(num(profiles$rhs_tau0) <= 0 | !is.finite(num(profiles$rhs_tau0)))) bundle_problems <- c(bundle_problems, "invalid_rhs_tau0")
  if (any(abs(num(profiles$rhs_tau0) - 3e-05) < .Machine$double.eps^0.5, na.rm = TRUE)) bundle_problems <- c(bundle_problems, "forbidden_qvbm2_p03_tau0_present")
  if (nrow(grid) != nrow(profiles)) bundle_problems <- c(bundle_problems, sprintf("grid_profile_count_mismatch=%d_vs_%d", nrow(grid), nrow(profiles)))
  if (nrow(assignments) != nrow(profiles)) bundle_problems <- c(bundle_problems, sprintf("assignment_profile_count_mismatch=%d_vs_%d", nrow(assignments), nrow(profiles)))
  if (nrow(target_specs) != nrow(grid)) bundle_problems <- c(bundle_problems, sprintf("target_specs_grid_count_mismatch=%d_vs_%d", nrow(target_specs), nrow(grid)))
  if (!all(as.character(target_specs$method) == "vb")) bundle_problems <- c(bundle_problems, "target_specs_not_vb_only")
  if (any(!as.character(target_specs$likelihood_target) %in% c("al", "exal"))) bundle_problems <- c(bundle_problems, "target_specs_invalid_likelihood")
  if (isTRUE(manifest$launch_policy$approval_required_before_compute) == FALSE) bundle_problems <- c(bundle_problems, "manifest_missing_compute_approval_gate")
  if (any(num(profiles$D) > 4)) bundle_problems <- c(bundle_problems, "D_above_qvbm3_cap")
  if (any(num(profiles$n_each) > 300)) bundle_problems <- c(bundle_problems, "n_each_above_qvbm3_cap")
  if (any(num(profiles$m) > 150)) bundle_problems <- c(bundle_problems, "m_above_qvbm3_cap")

  rows[[length(rows) + 1L]] <- data.frame(
    bundle_code = as.character(idx$bundle_code[[1L]]),
    status = if (length(bundle_problems)) "DRY_FAIL" else "DRY_PASS",
    n_profiles = nrow(profiles),
    n_grid_rows = nrow(grid),
    n_target_specs = nrow(target_specs),
    n_red_tier = sum(as.character(profiles$capacity_tier) == "red"),
    n_extreme = sum(as.character(profiles$profile_role) == "red_extreme_single"),
    max_D = max(num(profiles$D), na.rm = TRUE),
    max_n_each = max(num(profiles$n_each), na.rm = TRUE),
    max_m = max(num(profiles$m), na.rm = TRUE),
    max_p_over_n_tt500 = max(num(profiles$p_over_n_tt500), na.rm = TRUE),
    active_methods = paste(methods, collapse = "|"),
    problems = paste(bundle_problems, collapse = "; "),
    stringsAsFactors = FALSE
  )
  problems <- c(problems, if (length(bundle_problems)) paste(as.character(idx$bundle_code[[1L]]), bundle_problems, sep = ":") else character())
}

audit <- do.call(rbind, rows)
profiles_all <- do.call(rbind, all_profiles)

generated_text <- paste(vapply(all_paths, function(path) {
  paste(readLines(path, warn = FALSE), collapse = "\n")
}, character(1L)), collapse = "\n")
if (grepl("/home/jaguir26/local/src", generated_text, fixed = TRUE)) problems <- c(problems, "stale_home_src_path_found")
if (grepl("Article-Q-DESN|PriceFM|GloFAS|joint-QVP", generated_text)) problems <- c(problems, "wrong_lane_path_or_label_found")

forbidden <- character()
for (root in c(file.path("results", "qvbm3_capacity"), file.path("reports", "qvbm3_capacity"))) {
  if (dir.exists(resolve_path(root, must_work = FALSE))) {
    forbidden <- c(forbidden, list.files(root, pattern = "[.](rds|rda|RData)$|__design[.]rds$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE))
  }
}
if (length(forbidden)) problems <- c(problems, sprintf("forbidden_binary_payloads=%d", length(forbidden)))

total_extreme <- sum(audit$n_extreme)
if (total_extreme > 2L) problems <- c(problems, sprintf("too_many_extreme_stress_rows=%d", total_extreme))
if (!any(num(profiles_all$D) == 4 & num(profiles_all$n_each) == 300 & num(profiles_all$m) == 150)) {
  problems <- c(problems, "missing_D4_n300_m150_stress_canary")
}
if (!any(num(profiles_all$D) == 3 & num(profiles_all$n_each) == 100 & num(profiles_all$m) == 60)) {
  problems <- c(problems, "missing_green_deep_balanced_row")
}

overall_status <- if (length(problems)) "DRY_FAIL" else "DRY_PASS"

out_dir <- file.path("reports", "qvbm3_capacity", "audit", "qvbm3_capacity_materialization_20260715")
tables_dir <- file.path(out_dir, "tables")
summary_dir <- file.path(out_dir, "summary")
manifest_dir <- file.path(out_dir, "manifest")
audit_path <- write_csv(audit, file.path(tables_dir, "qvbm3_capacity_materialization_audit.csv"))
profile_inventory <- data.frame(
  capacity_tier = names(table(profiles_all$capacity_tier)),
  n_profiles = as.integer(table(profiles_all$capacity_tier)),
  stringsAsFactors = FALSE
)
inventory_path <- write_csv(profile_inventory, file.path(tables_dir, "qvbm3_capacity_profile_inventory.csv"))
forbidden_path <- write_csv(
  data.frame(path = forbidden, stringsAsFactors = FALSE),
  file.path(tables_dir, "qvbm3_capacity_forbidden_payloads.csv")
)
manifest_path <- write_json(
  list(
    generated_at = as.character(Sys.time()),
    repo_root = repo_root,
    git_branch = system("git branch --show-current", intern = TRUE)[[1L]],
    git_sha = system("git rev-parse HEAD", intern = TRUE)[[1L]],
    bundle_index = index_path,
    overall_status = overall_status,
    problems = as.list(problems),
    output_paths = list(
      audit = audit_path,
      inventory = inventory_path,
      forbidden_payloads = forbidden_path
    ),
    hashes = list(
      audit_sha256 = sha256_file(audit_path),
      inventory_sha256 = sha256_file(inventory_path),
      forbidden_payloads_sha256 = sha256_file(forbidden_path)
    )
  ),
  file.path(manifest_dir, "qvbm3_capacity_materialization_audit_manifest.json")
)

summary_path <- resolve_path(file.path(summary_dir, "qvbm3_capacity_materialization_audit.md"), must_work = FALSE)
dir.create(dirname(summary_path), recursive = TRUE, showWarnings = FALSE)
writeLines(c(
  "# QVBM3 Capacity Materialization Dry Audit",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- worktree: `%s`", repo_root),
  sprintf("- branch: `%s`", system("git branch --show-current", intern = TRUE)[[1L]]),
  sprintf("- head: `%s`", system("git rev-parse HEAD", intern = TRUE)[[1L]]),
  sprintf("- status: `%s`", overall_status),
  sprintf("- manifest: `%s`", manifest_path),
  "",
  "## Bundle Audit",
  "",
  md_table(audit),
  "",
  "## Profile Inventory",
  "",
  md_table(profile_inventory),
  "",
  "## Problems",
  "",
  if (length(problems)) paste(sprintf("- `%s`", problems), collapse = "\n") else "- none",
  "",
  "## Decision",
  "",
  if (identical(overall_status, "DRY_PASS")) {
    "The qvbm3 capacity expansion is materialized and dry-audited as VB-only, storage-light, and launch-gated. No compute has been launched."
  } else {
    "The qvbm3 capacity expansion failed dry audit. Do not launch until the listed problems are fixed."
  }
), summary_path, useBytes = TRUE)

cat(sprintf("status: %s\n", overall_status))
cat(sprintf("audit: %s\n", audit_path))
cat(sprintf("summary: %s\n", summary_path))
cat(sprintf("manifest: %s\n", manifest_path))
if (length(problems)) {
  cat(paste(sprintf("problem: %s", problems), collapse = "\n"), "\n")
  stop("qvbm3 materialization dry audit failed.", call. = FALSE)
}
cat("qvbm3_materialization_audit=PASS\n")

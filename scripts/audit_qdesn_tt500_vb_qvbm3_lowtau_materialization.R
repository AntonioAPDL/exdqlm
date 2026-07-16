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

md_table <- function(df, cols = names(df)) {
  if (!nrow(df)) return("_No rows._")
  cols <- intersect(cols, names(df))
  x <- df[, cols, drop = FALSE]
  x[] <- lapply(x, function(col) {
    if (is.numeric(col)) {
      ifelse(is.na(col), "", format(round(col, 6), trim = TRUE, scientific = FALSE))
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

stage_prefix <- get_arg("--stage-prefix", "qvbm3_lowtau")
allow_ultra_low_tau0 <- "--allow-ultra-low-tau0" %in% args
index_path <- resolve_path(get_arg("--bundle-index", file.path("config", "validation", paste0(stage_prefix, "_bundle_index.csv"))))
index <- utils::read.csv(index_path, stringsAsFactors = FALSE, check.names = FALSE)

required_index <- c("bundle_code", "defaults_path", "grid_path", "profiles_path", "assignments_path", "target_spec_ids_path", "manifest_path")
if (!all(required_index %in% names(index))) {
  stop(sprintf("Bundle index missing required columns: %s", paste(setdiff(required_index, names(index)), collapse = ", ")), call. = FALSE)
}

required_profile <- c(
  "screening_profile_id", "source_qvbm3_profile_id", "rhs_tau0_original",
  "rhs_tau0", "rhs_tau0_ratio_vs_qvbm3", "rhs_tau0_relaunch_policy",
  "target_family", "target_tau", "likelihood_target", "launch_gate", "article_facing"
)

problems <- character()
rows <- list()
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
  missing_profile <- setdiff(required_profile, names(profiles))
  if (length(missing_profile)) bundle_problems <- c(bundle_problems, sprintf("missing_profile_cols=%s", paste(missing_profile, collapse = "|")))
  if (nrow(grid) != nrow(profiles)) bundle_problems <- c(bundle_problems, sprintf("grid_profile_count_mismatch=%d_vs_%d", nrow(grid), nrow(profiles)))
  if (nrow(assignments) != nrow(profiles)) bundle_problems <- c(bundle_problems, sprintf("assignment_profile_count_mismatch=%d_vs_%d", nrow(assignments), nrow(profiles)))
  if (nrow(target_specs) != nrow(grid)) bundle_problems <- c(bundle_problems, sprintf("target_specs_grid_count_mismatch=%d_vs_%d", nrow(target_specs), nrow(grid)))
  methods <- as.character((defaults$execution %||% list())$methods %||% character())
  if (!identical(methods, "vb")) bundle_problems <- c(bundle_problems, sprintf("active_methods_not_vb_only=%s", paste(methods, collapse = "|")))
  if (!all(as.character(target_specs$method) == "vb")) bundle_problems <- c(bundle_problems, "target_specs_not_vb_only")
  if (any(!as.character(target_specs$likelihood_target) %in% c("al", "exal"))) bundle_problems <- c(bundle_problems, "target_specs_invalid_likelihood")
  if (!isTRUE((defaults$pipeline$validation_guardrails %||% list())$allow_dlm_decomp_lags)) bundle_problems <- c(bundle_problems, "decomp_lag_guard_not_explicitly_allowed")
  if (any(num(profiles$rhs_tau0) <= 3e-5, na.rm = TRUE) && !isTRUE(allow_ultra_low_tau0)) bundle_problems <- c(bundle_problems, "tau0_at_or_below_known_failed_p03")
  if (any(num(profiles$rhs_tau0) <= 3e-5, na.rm = TRUE) && isTRUE(allow_ultra_low_tau0)) bundle_problems <- c(bundle_problems, character(0))
  if (any(num(profiles$rhs_tau0) >= num(profiles$rhs_tau0_original), na.rm = TRUE)) bundle_problems <- c(bundle_problems, "tau0_not_reduced_vs_qvbm3")
  if (!any(num(profiles$rhs_tau0) < 1e-4, na.rm = TRUE)) bundle_problems <- c(bundle_problems, "no_below_previous_safe_floor_canary")
  if (!isTRUE(manifest$launch_policy$approval_required_before_compute)) bundle_problems <- c(bundle_problems, "manifest_missing_compute_approval_gate")
  if (!isTRUE(manifest$launch_policy$mcmc_closed)) bundle_problems <- c(bundle_problems, "manifest_does_not_close_mcmc")

  rows[[length(rows) + 1L]] <- data.frame(
    bundle_code = as.character(idx$bundle_code[[1L]]),
    status = if (length(bundle_problems)) "DRY_FAIL" else "DRY_PASS",
    n_profiles = nrow(profiles),
    n_target_specs = nrow(target_specs),
    min_rhs_tau0 = min(num(profiles$rhs_tau0), na.rm = TRUE),
    max_rhs_tau0 = max(num(profiles$rhs_tau0), na.rm = TRUE),
    n_below_previous_safe_floor = sum(num(profiles$rhs_tau0) < 1e-4, na.rm = TRUE),
    n_at_or_below_known_failed_tau0 = sum(num(profiles$rhs_tau0) <= 3e-5, na.rm = TRUE),
    ultra_low_tau0_allowed_by_flag = isTRUE(allow_ultra_low_tau0),
    max_p_over_n_tt500 = max(num(profiles$p_over_n_tt500), na.rm = TRUE),
    active_methods = paste(methods, collapse = "|"),
    problems = paste(bundle_problems, collapse = "; "),
    stringsAsFactors = FALSE
  )
  problems <- c(problems, if (length(bundle_problems)) paste(as.character(idx$bundle_code[[1L]]), bundle_problems, sep = ":") else character())
}

profiles_all <- do.call(rbind, all_profiles)
generated_text <- paste(vapply(all_paths, function(path) paste(readLines(path, warn = FALSE), collapse = "\n"), character(1L)), collapse = "\n")
if (grepl("/home/jaguir26/local/src", generated_text, fixed = TRUE)) problems <- c(problems, "stale_home_src_path_found")
if (grepl("Article-Q-DESN|PriceFM|GloFAS|joint-QVP", generated_text)) problems <- c(problems, "wrong_lane_path_or_label_found")

forbidden <- character()
for (root in c(file.path("results", stage_prefix), file.path("reports", stage_prefix))) {
  if (dir.exists(resolve_path(root, must_work = FALSE))) {
    forbidden <- c(forbidden, list.files(root, pattern = "[.](rds|rda|RData)$|__design[.]rds$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE))
  }
}
if (length(forbidden)) problems <- c(problems, sprintf("forbidden_binary_payloads=%d", length(forbidden)))

audit <- do.call(rbind, rows)
overall_status <- if (length(problems)) "DRY_FAIL" else "DRY_PASS"
profile_inventory <- aggregate(
  list(n_profiles = profiles_all$screening_profile_id),
  by = list(
    rhs_tau0 = num(profiles_all$rhs_tau0),
    relaunch_policy = as.character(profiles_all$rhs_tau0_relaunch_policy),
    capacity_tier = as.character(profiles_all$capacity_tier)
  ),
  FUN = length
)

out_dir <- file.path("reports", stage_prefix, "audit", paste0(stage_prefix, "_materialization_20260715"))
tables_dir <- file.path(out_dir, "tables")
summary_dir <- file.path(out_dir, "summary")
manifest_dir <- file.path(out_dir, "manifest")
audit_path <- write_csv(audit, file.path(tables_dir, paste0(stage_prefix, "_materialization_audit.csv")))
inventory_path <- write_csv(profile_inventory, file.path(tables_dir, paste0(stage_prefix, "_profile_inventory.csv")))
forbidden_path <- write_csv(data.frame(path = forbidden, stringsAsFactors = FALSE), file.path(tables_dir, paste0(stage_prefix, "_forbidden_payloads.csv")))
manifest_path <- write_json(
  list(
    generated_at = as.character(Sys.time()),
    repo_root = repo_root,
    git_branch = system("git branch --show-current", intern = TRUE)[[1L]],
    git_sha = system("git rev-parse HEAD", intern = TRUE)[[1L]],
    bundle_index = index_path,
    overall_status = overall_status,
    problems = as.list(problems),
    output_paths = list(audit = audit_path, inventory = inventory_path, forbidden_payloads = forbidden_path),
    hashes = list(
      audit_sha256 = sha256_file(audit_path),
      inventory_sha256 = sha256_file(inventory_path),
      forbidden_payloads_sha256 = sha256_file(forbidden_path)
    )
  ),
  file.path(manifest_dir, paste0(stage_prefix, "_materialization_audit_manifest.json"))
)

summary_path <- resolve_path(file.path(summary_dir, paste0(stage_prefix, "_materialization_audit.md")), must_work = FALSE)
dir.create(dirname(summary_path), recursive = TRUE, showWarnings = FALSE)
writeLines(c(
  "# QVBM3 Low-Tau Materialization Dry Audit",
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
  "## Tau0 Inventory",
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
    "The qvbm3 low-tau relaunch surface is materialized and dry-audited as VB-only, storage-light, exact-spec filtered, and launch-gated. No compute has been launched."
  } else {
    "The qvbm3 low-tau relaunch surface failed dry audit. Do not launch until the listed problems are fixed."
  }
), summary_path, useBytes = TRUE)

cat(sprintf("status: %s\n", overall_status))
cat(sprintf("audit: %s\n", audit_path))
cat(sprintf("summary: %s\n", summary_path))
cat(sprintf("manifest: %s\n", manifest_path))
if (length(problems)) {
  cat(paste(sprintf("problem: %s", problems), collapse = "\n"), "\n")
  stop("qvbm3 low-tau materialization dry audit failed.", call. = FALSE)
}
cat("qvbm3_lowtau_materialization_audit=PASS\n")

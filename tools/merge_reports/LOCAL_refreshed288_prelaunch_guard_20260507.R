#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- grep(paste0("^", prefix), args, value = TRUE)
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

truthy <- function(x) tolower(trimws(as.character(x)[1L])) %in% c("1", "true", "yes", "y")

repo_root <- normalizePath(arg_value("repo-root", getwd()), winslash = "/", mustWork = TRUE)
run_tag <- arg_value("run-tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = "20260507_p90_dynamic72_qdesn_comparable_fresh_v1"))
registry_path <- arg_value("registry", file.path(repo_root, "tools/merge_reports", sprintf("LOCAL_refreshed288_dataset_registry_%s.csv", run_tag)))
manifest_path <- arg_value("manifest", file.path(repo_root, "tools/merge_reports", sprintf("LOCAL_refreshed288_full_manifest_%s.csv", run_tag)))
require_manifest <- truthy(arg_value("require-manifest", "true"))
forbid_pattern <- arg_value("forbid-pattern", "/home/jaguir26/local/src")
expected_dynamic_datasets <- as.integer(arg_value("expected-dynamic-datasets", "18"))
expected_dynamic_manifest_rows <- as.integer(arg_value("expected-dynamic-manifest-rows", "72"))

source(file.path(repo_root, "tools/merge_reports/LOCAL_refreshed288_helpers_20260422_p90_full288.R"))

read_required_csv <- function(path) {
  if (!file.exists(path)) stop("Missing required CSV: ", path, call. = FALSE)
  read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

issues <- character()
add_issue <- function(...) {
  issues <<- c(issues, paste0(...))
}

check_forbidden <- function(df, label) {
  if (!nzchar(forbid_pattern)) return(invisible(FALSE))
  chr_cols <- names(df)[vapply(df, is.character, logical(1))]
  hits <- vapply(chr_cols, function(col) any(grepl(forbid_pattern, df[[col]], fixed = TRUE), na.rm = TRUE), logical(1))
  if (any(hits)) {
    add_issue(label, " contains forbidden path root in columns: ", paste(chr_cols[hits], collapse = ", "))
  }
}

if (!file.exists(registry_path)) {
  add_issue("registry missing: ", registry_path)
} else {
  registry <- read_required_csv(registry_path)
  check_forbidden(registry, "registry")
  dynamic <- registry[registry$block == "dynamic" & registry$root_kind == "dynamic", , drop = FALSE]
  if (nrow(dynamic) != expected_dynamic_datasets) {
    add_issue("dynamic registry row count ", nrow(dynamic), " != ", expected_dynamic_datasets)
  }
  path_cols <- intersect(c("series_wide_path", "true_quantile_grid_path", "selection_indices_path"), names(dynamic))
  missing_paths <- unlist(lapply(path_cols, function(col) {
    vals <- dynamic[[col]]
    vals[is.na(vals) | !nzchar(vals)] <- NA_character_
    vals[!is.na(vals) & !file.exists(vals)]
  }), use.names = FALSE)
  if (length(missing_paths)) {
    add_issue("dynamic registry has missing source paths: ", paste(unique(missing_paths), collapse = "; "))
  }
  if ("missing_inputs" %in% names(dynamic)) {
    missing_inputs <- tolower(as.character(dynamic$missing_inputs)) %in% c("true", "1", "yes")
    if (any(missing_inputs, na.rm = TRUE)) {
      add_issue("dynamic registry marks missing_inputs for dataset_id(s): ", paste(dynamic$dataset_id[missing_inputs], collapse = ", "))
    }
  }
}

if (!file.exists(manifest_path)) {
  if (require_manifest) add_issue("manifest missing: ", manifest_path)
} else {
  manifest <- read_required_csv(manifest_path)
  check_forbidden(manifest, "manifest")
  dynamic_manifest <- manifest[manifest$block == "dynamic", , drop = FALSE]
  if (nrow(dynamic_manifest) != expected_dynamic_manifest_rows) {
    add_issue("dynamic manifest row count ", nrow(dynamic_manifest), " != ", expected_dynamic_manifest_rows)
  }
  bad_phase <- dynamic_manifest$phase[!dynamic_manifest$phase %in% c("full_dynamic_vb", "full_dynamic_mcmc")]
  if (length(bad_phase)) add_issue("dynamic manifest has unexpected phases: ", paste(unique(bad_phase), collapse = ", "))
  if ("retention_mode" %in% names(dynamic_manifest) && any(dynamic_manifest$retention_mode != "comparison_plus_plot", na.rm = TRUE)) {
    add_issue("dynamic manifest has retention_mode values other than comparison_plus_plot")
  }
  flag_cols <- intersect(c("retain_candidate_fit_binaries", "retain_draw_binaries", "retain_vb_init_binaries"), names(dynamic_manifest))
  for (col in flag_cols) {
    vals <- tolower(as.character(dynamic_manifest[[col]])) %in% c("true", "1", "yes")
    if (any(vals, na.rm = TRUE)) add_issue("dynamic manifest has ", col, "=TRUE")
  }
}

status <- if (length(issues)) "FAIL" else "PASS"
cat(sprintf("prelaunch_guard_status=%s run_tag=%s\n", status, run_tag))
cat(sprintf("registry=%s\n", registry_path))
cat(sprintf("manifest=%s\n", manifest_path))
if (length(issues)) {
  cat("issues:\n")
  cat(sprintf("- %s\n", issues), sep = "")
  stop("Prelaunch guard failed.", call. = FALSE)
}

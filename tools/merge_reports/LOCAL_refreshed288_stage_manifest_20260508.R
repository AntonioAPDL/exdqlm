#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- grep(paste0("^", prefix), args, value = TRUE)
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

truthy <- function(x) tolower(x) %in% c("1", "true", "yes", "y")

repo_root <- normalizePath(arg_value("repo-root", getwd()), winslash = "/", mustWork = TRUE)
run_tag <- arg_value("run-tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = "20260507_p90_dynamic72_qdesn_comparable_fresh_v1"))
stage <- arg_value("stage", "dynamic-vb")
manifest_path <- arg_value("manifest", file.path(repo_root, "tools/merge_reports", sprintf("LOCAL_refreshed288_full_manifest_%s.csv", run_tag)))
out_csv <- arg_value("out", file.path(repo_root, "tools/merge_reports", sprintf("LOCAL_refreshed288_stage_%s_manifest_%s.csv", stage, run_tag)))
include_completed <- truthy(arg_value("include-completed", Sys.getenv("REFRESHED288_STAGE_INCLUDE_COMPLETED", unset = "false")))

read_required_csv <- function(path) {
  if (!file.exists(path)) stop("Missing required CSV: ", path, call. = FALSE)
  read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

read_row_status <- function(path) {
  if (is.na(path) || !nzchar(path) || !file.exists(path)) return("not_started")
  status <- tryCatch(read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)$status[1L], error = function(e) NA_character_)
  if (is.na(status) || !nzchar(status)) "unknown" else status
}

manifest <- read_required_csv(manifest_path)
needed <- c("row_id", "block", "inference", "fit_size", "family", "tau_label", "model", "retention_mode")
missing <- setdiff(needed, names(manifest))
if (length(missing)) stop("Manifest missing columns: ", paste(missing, collapse = ", "), call. = FALSE)

keep <- manifest$block == "dynamic"
if (stage == "dynamic-vb") {
  keep <- keep & manifest$inference == "vb"
} else if (stage == "mcmc-tt500") {
  keep <- keep & manifest$inference == "mcmc" & as.integer(manifest$fit_size) == 500L
} else if (stage == "mcmc-tt5000") {
  keep <- keep & manifest$inference == "mcmc" & as.integer(manifest$fit_size) == 5000L
} else {
  stop("Unknown stage: ", stage, call. = FALSE)
}

stage_manifest <- manifest[keep, , drop = FALSE]
if (!nrow(stage_manifest)) stop("No rows selected for stage: ", stage, call. = FALSE)

status_path_col <- if ("row_status_path" %in% names(stage_manifest)) "row_status_path" else "status_path"
if (!status_path_col %in% names(stage_manifest)) {
  stage_manifest$row_status_current <- rep("not_started", nrow(stage_manifest))
} else {
  stage_manifest$row_status_current <- vapply(stage_manifest[[status_path_col]], read_row_status, character(1L))
}
if (!include_completed) {
  terminal_or_active <- c("done", "skipped_existing", "failed_runtime", "running")
  stage_manifest <- stage_manifest[!(stage_manifest$row_status_current %in% terminal_or_active), , drop = FALSE]
}

if (nrow(stage_manifest)) {
  order_cols <- intersect(c("fit_size", "family", "tau", "tau_label", "model", "inference", "row_id"), names(stage_manifest))
  ord <- do.call(order, stage_manifest[order_cols])
  stage_manifest <- stage_manifest[ord, , drop = FALSE]
}

dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
write.csv(stage_manifest, out_csv, row.names = FALSE, na = "")
cat(sprintf("stage=%s\n", stage))
cat(sprintf("include_completed=%s\n", include_completed))
cat(sprintf("stage_rows=%d\n", nrow(stage_manifest)))
cat(sprintf("wrote_csv=%s\n", out_csv))
if (nrow(stage_manifest)) cat(sprintf("row_ids=%s\n", paste(stage_manifest$row_id, collapse = ",")))

#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
`%||%` <- function(a, b) if (is.null(a)) b else a
has_flag <- function(flag) any(args == flag)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[[1L]]
  if (idx >= length(args)) return(default)
  args[[idx + 1L]]
}

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

read_csv_if_exists <- function(path) {
  if (!nzchar(as.character(path %||% "")[1L]) || !file.exists(path)) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

copy_backup <- function(paths, backup_dir) {
  dir.create(backup_dir, recursive = TRUE, showWarnings = FALSE)
  copied <- character(0)
  for (path in paths) {
    if (!file.exists(path)) next
    dest <- file.path(backup_dir, basename(path))
    if (!file.exists(dest)) {
      ok <- file.copy(path, dest, overwrite = FALSE)
      if (isTRUE(ok)) copied <- c(copied, dest)
    }
  }
  copied
}

annotate_split <- function(df, root_spec, split) {
  if (!nrow(df) || !"source_index" %in% names(df)) return(df)
  roles <- exdqlm:::.qdesn_validation_source_split_roles(
    root_spec = root_spec,
    source_index = df$source_index,
    split = split
  )
  for (nm in names(roles)) df[[nm]] <- roles[[nm]]
  df
}

results_root <- resolve_path(get_arg("--results-root", ""), must_work = TRUE)
report_root <- resolve_path(get_arg("--report-root", ""), must_work = FALSE)
out_dir <- resolve_path(get_arg("--out-dir", ""), must_work = FALSE)
dry_run <- has_flag("--dry-run")
if (is.null(out_dir)) out_dir <- file.path(report_root %||% results_root, "audit", "effective_train_contract_repair")
tables_dir <- file.path(out_dir, "tables")
manifest_dir <- file.path(out_dir, "manifest")
backup_dir <- file.path(out_dir, "backup")
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(manifest_dir, recursive = TRUE, showWarnings = FALSE)

roots_dir <- file.path(results_root, "roots")
root_dirs <- if (dir.exists(roots_dir)) sort(list.dirs(roots_dir, recursive = FALSE, full.names = TRUE)) else character(0)
rows <- vector("list", length(root_dirs))

for (i in seq_along(root_dirs)) {
  root_dir <- root_dirs[[i]]
  root_id <- basename(root_dir)
  method_dir <- file.path(root_dir, "fits", "mcmc_exal")
  root_manifest_path <- file.path(root_dir, "manifest", "root_manifest.json")
  root_spec <- exdqlm:::.qdesn_validation_read_json_if_exists(root_manifest_path) %||% list(root_id = root_id)
  root_spec$root_id <- root_spec$root_id %||% root_id

  train_path <- file.path(method_dir, "tables", "fit_quantile_path_train.csv")
  holdout_path <- file.path(method_dir, "tables", "fit_quantile_path_holdout.csv")
  index_alignment_path <- file.path(method_dir, "tables", "index_alignment.csv")
  index_alignment_json_path <- file.path(method_dir, "manifest", "index_alignment.json")
  retention_path <- file.path(method_dir, "manifest", "output_retention.json")

  train_df <- annotate_split(read_csv_if_exists(train_path), root_spec, "train")
  holdout_df <- annotate_split(read_csv_if_exists(holdout_path), root_spec, "holdout")
  alignment_df <- exdqlm:::.qdesn_validation_bind_rows(list(
    exdqlm:::.qdesn_validation_split_alignment_row(train_df, root_spec, "train"),
    exdqlm:::.qdesn_validation_split_alignment_row(holdout_df, root_spec, "holdout")
  ))
  alignment_status <- if (nrow(alignment_df) && all(as.character(alignment_df$status) == "PASS")) "PASS" else "FAIL"
  effective_train_rows <- if ("effective_train" %in% names(train_df)) {
    sum(exdqlm:::.qdesn_validation_bool_vec(train_df$effective_train, nrow(train_df), default = FALSE), na.rm = TRUE)
  } else {
    NA_integer_
  }

  backed_up <- character(0)
  if (!isTRUE(dry_run)) {
    backed_up <- copy_backup(
      c(train_path, holdout_path, index_alignment_path, index_alignment_json_path, retention_path),
      file.path(backup_dir, root_id, "fits_mcmc_exal")
    )
    if (nrow(train_df)) exdqlm:::.qdesn_validation_write_df(train_df, train_path)
    if (nrow(holdout_df)) exdqlm:::.qdesn_validation_write_df(holdout_df, holdout_path)
    if (nrow(alignment_df)) exdqlm:::.qdesn_validation_write_df(alignment_df, index_alignment_path)
    exdqlm:::.qdesn_validation_write_json(index_alignment_json_path, list(
      generated_at = as.character(Sys.time()),
      index_alignment_file = normalizePath(index_alignment_path, winslash = "/", mustWork = FALSE),
      status = alignment_status,
      rows = as.integer(nrow(alignment_df)),
      repaired_by = "scripts/repair_qdesn_tt500_mcmc_vbwin_effective_train_contract.R",
      effective_train_contract = "score train alignment on source indices 8501:9000; preserve pretrain context rows"
    ))
    retention <- exdqlm:::.qdesn_validation_read_json_if_exists(retention_path) %||% list()
    retention$index_alignment_status <- alignment_status
    retention$index_alignment_repaired_at <- as.character(Sys.time())
    retention$compact_train_rows_total <- as.integer(nrow(train_df))
    retention$compact_train_effective_rows <- as.integer(effective_train_rows)
    retention$compact_train_context_rows <- as.integer(nrow(train_df) - effective_train_rows)
    retention$effective_train_contract_repair <- list(
      repaired_by = "scripts/repair_qdesn_tt500_mcmc_vbwin_effective_train_contract.R",
      backup_dir = normalizePath(file.path(backup_dir, root_id, "fits_mcmc_exal"), winslash = "/", mustWork = FALSE),
      dry_run = FALSE
    )
    exdqlm:::.qdesn_validation_write_json(retention_path, retention)
  }

  rows[[i]] <- data.frame(
    root_id = root_id,
    method_dir = normalizePath(method_dir, winslash = "/", mustWork = FALSE),
    train_rows_total = as.integer(nrow(train_df)),
    train_rows_effective = as.integer(effective_train_rows),
    holdout_rows = as.integer(nrow(holdout_df)),
    alignment_status = alignment_status,
    backup_file_count = length(backed_up),
    dry_run = isTRUE(dry_run),
    stringsAsFactors = FALSE
  )
}

summary_df <- exdqlm:::.qdesn_validation_bind_rows(rows)
summary_path <- file.path(tables_dir, "qdesn_tt500_mcmc_vbwin_effective_train_contract_repair.csv")
exdqlm:::.qdesn_validation_write_df(summary_df, summary_path)
manifest_path <- file.path(manifest_dir, "qdesn_tt500_mcmc_vbwin_effective_train_contract_repair.json")
exdqlm:::.qdesn_validation_write_json(manifest_path, list(
  generated_at = as.character(Sys.time()),
  dry_run = isTRUE(dry_run),
  results_root = normalizePath(results_root, winslash = "/", mustWork = FALSE),
  report_root = normalizePath(report_root %||% out_dir, winslash = "/", mustWork = FALSE),
  out_dir = normalizePath(out_dir, winslash = "/", mustWork = FALSE),
  roots = as.integer(nrow(summary_df)),
  alignment_pass = as.integer(sum(as.character(summary_df$alignment_status) == "PASS")),
  summary_csv = normalizePath(summary_path, winslash = "/", mustWork = FALSE)
))

cat(sprintf("summary_csv: %s\n", summary_path))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf(
  "roots=%d alignment_pass=%d dry_run=%s\n",
  nrow(summary_df),
  sum(as.character(summary_df$alignment_status) == "PASS"),
  as.character(isTRUE(dry_run))
))

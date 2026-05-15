#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(flag, default = NULL) {
  idx <- match(flag, args)
  if (is.na(idx) || idx >= length(args)) return(default)
  args[[idx + 1L]]
}

arg_flag <- function(flag) flag %in% args

results_root_arg <- arg_value("--results-root")
out_dir_arg <- arg_value("--out-dir", default = NULL)
overwrite <- arg_flag("--overwrite")

if (is.null(results_root_arg)) {
  stop(
    "Usage: materialize_qdesn_compact_fit_paths_for_run.R --results-root <campaign-run-root-or-outer-root> [--out-dir <dir>] [--overwrite]",
    call. = FALSE
  )
}

repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
suppressPackageStartupMessages(pkgload::load_all(repo_root, quiet = TRUE))

resolve_campaign_results_root <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (dir.exists(file.path(path, "roots"))) return(path)
  children <- if (dir.exists(path)) list.dirs(path, recursive = FALSE, full.names = TRUE) else character(0)
  hits <- children[dir.exists(file.path(children, "roots"))]
  if (length(hits) == 1L) return(normalizePath(hits[[1L]], winslash = "/", mustWork = TRUE))
  if (length(hits) > 1L) {
    newest <- hits[order(file.info(hits)$mtime, decreasing = TRUE)][[1L]]
    return(normalizePath(newest, winslash = "/", mustWork = TRUE))
  }
  stop(sprintf("Could not resolve a campaign results root with roots/: %s", path), call. = FALSE)
}

read_root_spec <- function(root_dir) {
  manifest_path <- file.path(root_dir, "manifest", "root_manifest.json")
  if (!file.exists(manifest_path)) return(NULL)
  jsonlite::fromJSON(manifest_path, simplifyVector = FALSE)
}

materialize_method <- function(root_spec, method_dir) {
  method_name <- basename(method_dir)
  parts <- strsplit(method_name, "_", fixed = TRUE)[[1L]]
  if (length(parts) != 2L || !(parts[[1L]] %in% c("vb", "mcmc")) || !(parts[[2L]] %in% c("al", "exal"))) {
    return(NULL)
  }

  train_path <- exdqlm:::.qdesn_validation_compact_fit_path_file(method_dir, "train")
  holdout_path <- exdqlm:::.qdesn_validation_compact_fit_path_file(method_dir, "holdout")
  forecast_path <- file.path(method_dir, "models", "forecast_objects.rds")
  if (!overwrite && file.exists(train_path) && file.exists(holdout_path)) {
    return(data.frame(
      root_id = root_spec$root_id,
      method_dir = normalizePath(method_dir, winslash = "/", mustWork = FALSE),
      method = parts[[1L]],
      likelihood_family = parts[[2L]],
      status = "SKIP_EXISTING",
      train_path = normalizePath(train_path, winslash = "/", mustWork = FALSE),
      train_rows = as.integer(nrow(utils::read.csv(train_path, stringsAsFactors = FALSE))),
      holdout_path = normalizePath(holdout_path, winslash = "/", mustWork = FALSE),
      holdout_rows = as.integer(nrow(utils::read.csv(holdout_path, stringsAsFactors = FALSE))),
      error_message = NA_character_,
      stringsAsFactors = FALSE
    ))
  }
  if (!file.exists(forecast_path)) {
    return(data.frame(
      root_id = root_spec$root_id,
      method_dir = normalizePath(method_dir, winslash = "/", mustWork = FALSE),
      method = parts[[1L]],
      likelihood_family = parts[[2L]],
      status = "MISSING_FORECAST_OBJECTS",
      train_path = train_path,
      train_rows = 0L,
      holdout_path = holdout_path,
      holdout_rows = 0L,
      error_message = "models/forecast_objects.rds is missing",
      stringsAsFactors = FALSE
    ))
  }

  root_spec_lik <- modifyList(root_spec, list(likelihood_family = parts[[2L]], method = parts[[1L]]))
  tryCatch({
    summary_obj <- exdqlm:::collect_pipeline_run_summary(method_dir)
    paths <- exdqlm:::.qdesn_validation_write_compact_fit_paths(summary_obj, root_spec_lik, method_dir)
    data.frame(
      root_id = root_spec$root_id,
      method_dir = normalizePath(method_dir, winslash = "/", mustWork = FALSE),
      method = parts[[1L]],
      likelihood_family = parts[[2L]],
      status = "WRITTEN",
      train_path = as.character(paths$train),
      train_rows = as.integer(paths$train_rows),
      holdout_path = as.character(paths$holdout),
      holdout_rows = as.integer(paths$holdout_rows),
      error_message = NA_character_,
      stringsAsFactors = FALSE
    )
  }, error = function(e) {
    data.frame(
      root_id = root_spec$root_id,
      method_dir = normalizePath(method_dir, winslash = "/", mustWork = FALSE),
      method = parts[[1L]],
      likelihood_family = parts[[2L]],
      status = "ERROR",
      train_path = train_path,
      train_rows = 0L,
      holdout_path = holdout_path,
      holdout_rows = 0L,
      error_message = conditionMessage(e),
      stringsAsFactors = FALSE
    )
  })
}

campaign_results_root <- resolve_campaign_results_root(results_root_arg)
if (is.null(out_dir_arg)) {
  out_dir_arg <- file.path(campaign_results_root, "compact_fit_path_materialization", format(Sys.time(), "%Y%m%d-%H%M%S"))
}
out_dir <- normalizePath(out_dir_arg, winslash = "/", mustWork = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

root_dirs <- sort(list.dirs(file.path(campaign_results_root, "roots"), recursive = FALSE, full.names = TRUE))
rows <- vector("list", length(root_dirs))
for (i in seq_along(root_dirs)) {
  root_dir <- root_dirs[[i]]
  cat(sprintf("[%s] compact path audit %d/%d: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), i, length(root_dirs), basename(root_dir)))
  flush.console()
  root_spec <- read_root_spec(root_dir)
  if (is.null(root_spec)) next
  method_dirs <- sort(list.dirs(file.path(root_dir, "fits"), recursive = FALSE, full.names = TRUE))
  method_dirs <- method_dirs[grepl("^(vb|mcmc)_(al|exal)$", basename(method_dirs))]
  rows[[i]] <- exdqlm:::.qdesn_validation_bind_rows(lapply(method_dirs, materialize_method, root_spec = root_spec))
}

audit <- exdqlm:::.qdesn_validation_bind_rows(rows)
exdqlm:::.qdesn_validation_write_df(audit, file.path(out_dir, "compact_fit_path_materialization_audit.csv"))
exdqlm:::.qdesn_validation_write_json(file.path(out_dir, "compact_fit_path_materialization_manifest.json"), list(
  generated_at = as.character(Sys.time()),
  campaign_results_root = campaign_results_root,
  out_dir = out_dir,
  overwrite = overwrite,
  method_rows = nrow(audit),
  status_counts = as.list(table(audit$status, useNA = "ifany")),
  train_paths_written_or_existing = sum(audit$train_rows > 0L, na.rm = TRUE),
  holdout_paths_written_or_existing = sum(audit$holdout_rows > 0L, na.rm = TRUE)
))

cat(sprintf("campaign_results_root: %s\n", campaign_results_root))
cat(sprintf("audit: %s\n", file.path(out_dir, "compact_fit_path_materialization_audit.csv")))
print(table(audit$status, useNA = "ifany"))
cat(sprintf("train_paths_ready: %d / %d\n", sum(audit$train_rows > 0L, na.rm = TRUE), nrow(audit)))
cat(sprintf("holdout_paths_ready: %d / %d\n", sum(audit$holdout_rows > 0L, na.rm = TRUE), nrow(audit)))

#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- tryCatch(
  {
    script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
    normalizePath(file.path(dirname(normalizePath(script_file, winslash = "/", mustWork = TRUE)), ".."), winslash = "/", mustWork = TRUE)
  },
  error = function(...) normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

resolve_campaign_root <- function(run_root, child) {
  if (!dir.exists(run_root)) return(run_root)
  direct <- file.path(run_root, child)
  if (dir.exists(direct)) return(run_root)
  kids <- sort(list.dirs(run_root, recursive = FALSE, full.names = TRUE), decreasing = TRUE)
  for (k in kids) {
    if (dir.exists(file.path(k, child))) return(k)
  }
  run_root
}

source_run_tag <- as.character(get_arg(
  "--source-run-tag",
  "qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674"
))[1L]

canonical_grid_path <- resolve_path(
  get_arg(
    "--canonical-grid",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.csv")
  ),
  must_work = TRUE
)

source_results_base <- resolve_path(
  get_arg(
    "--source-results-root",
    file.path(
      "results",
      "qdesn_mcmc_validation",
      "dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation"
    )
  ),
  must_work = TRUE
)

al_output_path <- resolve_path(
  get_arg(
    "--mcmc-al-output",
    file.path(
      "config",
      "validation",
      "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_al_grid.csv"
    )
  ),
  must_work = FALSE
)
exal_output_path <- resolve_path(
  get_arg(
    "--mcmc-exal-output",
    file.path(
      "config",
      "validation",
      "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_exal_grid.csv"
    )
  ),
  must_work = FALSE
)

source_outer_results_root <- file.path(source_results_base, source_run_tag)
source_results_root <- resolve_campaign_root(source_outer_results_root, "roots")
root_base <- file.path(source_results_root, "roots")
if (!dir.exists(root_base)) {
  stop(sprintf("Source run roots directory not found: %s", root_base), call. = FALSE)
}

canonical_grid <- read.csv(canonical_grid_path, stringsAsFactors = FALSE)
fit_summary_paths <- Sys.glob(file.path(root_base, "*", "fits", "*", "fit_summary_row.csv"))
if (!length(fit_summary_paths)) {
  stop(sprintf("No fit summary rows found under source run: %s", source_results_root), call. = FALSE)
}

failed_rows <- lapply(fit_summary_paths, function(path) {
  row <- tryCatch(read.csv(path, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(row) || !nrow(row) || !identical(as.character(row$status[[1L]]), "FAIL")) return(NULL)
  method <- basename(dirname(path))
  if (!method %in% c("mcmc_al", "mcmc_exal")) return(NULL)
  data.frame(
    root_id = basename(dirname(dirname(dirname(path)))),
    method = method,
    stringsAsFactors = FALSE
  )
})
failed_df <- do.call(rbind, Filter(Negate(is.null), failed_rows))
if (is.null(failed_df) || !nrow(failed_df)) {
  stop(sprintf("No failed MCMC fits found under source run: %s", source_run_tag), call. = FALSE)
}

materialize_failed_grid <- function(method, output_path) {
  failed_root_ids <- sort(unique(failed_df$root_id[failed_df$method == method]))
  if (!length(failed_root_ids)) {
    stop(sprintf("No failed roots found for method '%s'.", method), call. = FALSE)
  }
  subset_grid <- canonical_grid[match(failed_root_ids, canonical_grid$root_id, nomatch = 0L), , drop = FALSE]
  if (nrow(subset_grid) != length(failed_root_ids)) {
    missing_ids <- setdiff(failed_root_ids, as.character(subset_grid$root_id))
    stop(
      sprintf(
        "Failed to recover %d failed roots for method '%s' from canonical grid: %s",
        length(missing_ids),
        method,
        paste(missing_ids, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  subset_grid <- subset_grid[order(subset_grid$root_id), , drop = FALSE]
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(subset_grid, output_path, row.names = FALSE)
  subset_grid
}

al_grid <- materialize_failed_grid("mcmc_al", al_output_path)
exal_grid <- materialize_failed_grid("mcmc_exal", exal_output_path)
overlap_roots <- intersect(as.character(al_grid$root_id), as.character(exal_grid$root_id))

cat(sprintf("source_run_tag=%s\n", source_run_tag))
cat(sprintf("source_results_root=%s\n", source_results_root))
cat(sprintf("canonical_grid_path=%s\n", canonical_grid_path))
cat(sprintf("mcmc_al_output=%s\n", al_output_path))
cat(sprintf("mcmc_exal_output=%s\n", exal_output_path))
cat(sprintf("failed_fit_total=%d\n", nrow(failed_df)))
cat(sprintf("failed_mcmc_al_roots=%d\n", nrow(al_grid)))
cat(sprintf("failed_mcmc_exal_roots=%d\n", nrow(exal_grid)))
cat(sprintf("failed_root_overlap=%d\n", length(overlap_roots)))

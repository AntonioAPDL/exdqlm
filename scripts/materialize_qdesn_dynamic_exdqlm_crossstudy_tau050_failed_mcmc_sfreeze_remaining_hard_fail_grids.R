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

canonical_al_grid_path <- resolve_path(
  get_arg(
    "--canonical-al-grid",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_al_grid.csv")
  ),
  must_work = TRUE
)
canonical_exal_grid_path <- resolve_path(
  get_arg(
    "--canonical-exal-grid",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_exal_grid.csv")
  ),
  must_work = TRUE
)

results_base <- resolve_path(
  get_arg(
    "--results-root",
    file.path(
      "results",
      "qdesn_mcmc_validation",
      "dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_validation"
    )
  ),
  must_work = TRUE
)

al_run_tag <- as.character(get_arg(
  "--mcmc-al-run-tag",
  "qdesn-dynamic-exdqlm-crossstudy-tau050-failed_mcmc_al_sfreeze-20260419-031755__git-e44a56a"
))[1L]
exal_run_tag <- as.character(get_arg(
  "--mcmc-exal-run-tag",
  "qdesn-dynamic-exdqlm-crossstudy-tau050-failed_mcmc_exal_sfreeze-20260419-031810__git-e44a56a"
))[1L]

al_output_path <- resolve_path(
  get_arg(
    "--mcmc-al-output",
    file.path(
      "config",
      "validation",
      "qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_remaining_hard_fail_al_grid.csv"
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
      "qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_remaining_hard_fail_exal_grid.csv"
    )
  ),
  must_work = FALSE
)

canonical_al_grid <- read.csv(canonical_al_grid_path, stringsAsFactors = FALSE)
canonical_exal_grid <- read.csv(canonical_exal_grid_path, stringsAsFactors = FALSE)

collect_failed_roots <- function(run_tag) {
  outer_root <- file.path(results_base, run_tag)
  run_root <- resolve_campaign_root(outer_root, "roots")
  roots_dir <- file.path(run_root, "roots")
  if (!dir.exists(roots_dir)) {
    stop(sprintf("Roots directory not found for run '%s': %s", run_tag, roots_dir), call. = FALSE)
  }
  status_paths <- Sys.glob(file.path(roots_dir, "*", "manifest", "root_status.txt"))
  if (!length(status_paths)) {
    stop(sprintf("No root status files found under run '%s'.", run_tag), call. = FALSE)
  }
  root_ids <- basename(dirname(dirname(status_paths)))
  statuses <- trimws(vapply(status_paths, function(path) paste(readLines(path, warn = FALSE), collapse = "\n"), character(1L)))
  failed_root_ids <- sort(unique(root_ids[statuses == "FAIL"]))
  list(
    run_root = run_root,
    failed_root_ids = failed_root_ids,
    n_total = length(status_paths),
    n_fail = length(failed_root_ids)
  )
}

materialize_grid <- function(root_ids, canonical_grid, output_path, method) {
  if (!length(root_ids)) {
    stop(sprintf("No remaining hard-fail roots found for method '%s'.", method), call. = FALSE)
  }
  subset_grid <- canonical_grid[match(root_ids, canonical_grid$root_id, nomatch = 0L), , drop = FALSE]
  if (nrow(subset_grid) != length(root_ids)) {
    missing_ids <- setdiff(root_ids, as.character(subset_grid$root_id))
    stop(
      sprintf(
        "Failed to recover %d hard-fail roots for method '%s' from canonical grid: %s",
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

al_failed <- collect_failed_roots(al_run_tag)
exal_failed <- collect_failed_roots(exal_run_tag)

al_grid <- materialize_grid(al_failed$failed_root_ids, canonical_al_grid, al_output_path, "mcmc_al")
exal_grid <- materialize_grid(exal_failed$failed_root_ids, canonical_exal_grid, exal_output_path, "mcmc_exal")

cat(sprintf("results_base=%s\n", results_base))
cat(sprintf("mcmc_al_run_tag=%s\n", al_run_tag))
cat(sprintf("mcmc_al_run_root=%s\n", al_failed$run_root))
cat(sprintf("mcmc_al_output=%s\n", al_output_path))
cat(sprintf("mcmc_al_remaining_hard_fail_roots=%d\n", nrow(al_grid)))
cat(sprintf("mcmc_exal_run_tag=%s\n", exal_run_tag))
cat(sprintf("mcmc_exal_run_root=%s\n", exal_failed$run_root))
cat(sprintf("mcmc_exal_output=%s\n", exal_output_path))
cat(sprintf("mcmc_exal_remaining_hard_fail_roots=%d\n", nrow(exal_grid)))

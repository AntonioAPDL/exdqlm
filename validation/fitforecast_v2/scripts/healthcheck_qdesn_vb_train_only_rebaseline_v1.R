#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                           winslash = "/", mustWork = TRUE)
setwd(repo_root)
stage <- "qdesn_dynamic_fitforecast_v2_500obs_vb_trainonly_rebaseline_v1"
stub <- file.path("config", "validation", stage)
targets <- utils::read.csv(paste0(stub, "_target_spec_ids.csv"), check.names = FALSE,
                           stringsAsFactors = FALSE)
state_parent <- file.path("reports", "shared_fitforecast_v2_orchestration")
run_id <- as.character(get_arg("--run-id", ""))[1L]
if (!nzchar(run_id)) {
  candidates <- list.dirs(state_parent, recursive = FALSE, full.names = FALSE)
  candidates <- candidates[grepl("^qdesn_vb_trainonly_rebaseline_v1_", candidates)]
  if (length(candidates)) run_id <- candidates[[which.max(file.info(
    file.path(state_parent, candidates))$mtime)]]
}
state_root <- if (nzchar(run_id)) file.path(state_parent, run_id) else NA_character_
env <- character()
if (nzchar(run_id) && file.exists(file.path(state_root, "run_tags.env"))) {
  for (line in readLines(file.path(state_root, "run_tags.env"), warn = FALSE)) {
    pieces <- strsplit(line, "=", fixed = TRUE)[[1L]]
    if (length(pieces) >= 2L) env[[pieces[[1L]]]] <- paste(pieces[-1L], collapse = "=")
  }
}
full_tag <- unname(env["FULL_TAG"])
if (!length(full_tag) || is.na(full_tag)) full_tag <- ""
results_root <- file.path("results", "qdesn_mcmc_validation", stage, full_tag)
all_dirs <- if (nzchar(full_tag) && dir.exists(results_root)) {
  list.dirs(results_root, recursive = TRUE, full.names = TRUE)
} else character()
ps_lines <- tryCatch(system("ps -eo args", intern = TRUE), error = function(e) character())

rows <- lapply(seq_len(nrow(targets)), function(i) {
  spec <- targets[i, , drop = FALSE]
  root_id <- as.character(spec$root_id)
  likelihood <- as.character(spec$likelihood_family)
  roots <- all_dirs[basename(all_dirs) == root_id]
  method_dir <- if (length(roots)) file.path(roots[[1L]], "fits", paste0("vb_", likelihood)) else NA_character_
  fit_path <- if (!is.na(method_dir)) file.path(method_dir, "fit_summary_row.csv") else NA_character_
  horizon_path <- if (!is.na(method_dir)) file.path(method_dir, "tables", "forecast_horizon_summary.csv") else NA_character_
  log_path <- if (!is.na(method_dir)) file.path(method_dir, "logs", "pipeline_child_live.log") else NA_character_
  complete <- file.exists(fit_path) && file.exists(horizon_path)
  active <- any(grepl(root_id, ps_lines, fixed = TRUE))
  iteration <- 0L
  if (file.exists(log_path)) {
    lines <- tail(readLines(log_path, warn = FALSE), 2000L)
    hits <- regmatches(lines, regexec("(?:VB|iteration)[^0-9]*([0-9]+)", lines,
                                     ignore.case = TRUE, perl = TRUE))
    values <- suppressWarnings(as.integer(vapply(hits, function(x) {
      if (length(x) >= 2L) x[[2L]] else NA_character_
    }, character(1L))))
    values <- values[is.finite(values) & values <= 150L]
    if (length(values)) iteration <- max(values)
  }
  if (complete) iteration <- 150L
  progress_files <- c(log_path, fit_path, horizon_path)
  progress_files <- progress_files[file.exists(progress_files)]
  age <- if (length(progress_files)) as.numeric(difftime(
    Sys.time(), max(file.info(progress_files)$mtime), units = "mins")) else NA_real_
  data.frame(model = spec$model_variant, family = spec$family, tau = spec$tau,
             likelihood = likelihood,
             status = if (complete) "COMPLETE" else if (active) "RUNNING" else
               if (!is.na(method_dir) && dir.exists(method_dir)) "STARTED" else "QUEUED",
             iteration = iteration, total_iterations = 150L,
             percent = round(100 * iteration / 150, 1), active_process = active,
             progress_age_min = round(age, 1), stale_over_30m = active && is.finite(age) && age > 30,
             spec_id = spec$spec_id, stringsAsFactors = FALSE)
})
health <- do.call(rbind, rows)
completed <- sum(health$status == "COMPLETE")
active <- sum(health$active_process)
classification <- if (completed == nrow(targets)) "COMPLETED" else if (active > 0L) "RUNNING" else
  if (any(health$status == "STARTED")) "INCOMPLETE_NO_ACTIVE_WORKER" else "NOT_LAUNCHED"
cat(sprintf("run_id: %s\nfull_tag: %s\nclassification: %s\n",
            if (nzchar(run_id)) run_id else "none",
            if (nzchar(full_tag)) full_tag else "none", classification))
cat(sprintf("progress: %d/%d complete (%.1f%%), %d active, %d remaining\n",
            completed, nrow(targets), 100 * completed / nrow(targets), active,
            nrow(targets) - completed))
print(health[, c("model", "family", "tau", "status", "iteration",
                 "total_iterations", "percent", "active_process",
                 "progress_age_min", "stale_over_30m")], row.names = FALSE)

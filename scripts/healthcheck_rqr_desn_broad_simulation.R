#!/usr/bin/env Rscript

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

parse_cli <- function(args) {
  out <- list()
  ii <- 1L
  while (ii <= length(args)) {
    key <- args[[ii]]
    if (!startsWith(key, "--")) {
      stop(sprintf("Unexpected positional argument: %s", key), call. = FALSE)
    }
    key <- sub("^--", "", key)
    value <- "true"
    if (ii < length(args) && !startsWith(args[[ii + 1L]], "--")) {
      value <- args[[ii + 1L]]
      ii <- ii + 1L
    }
    out[[key]] <- value
    ii <- ii + 1L
  }
  out
}

write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, file = path, row.names = FALSE, na = "")
}

read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame())
  tryCatch(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) data.frame())
}

combine_csvs <- function(paths) {
  paths <- paths[file.exists(paths)]
  if (!length(paths)) return(data.frame())
  parts <- lapply(paths, read_csv_safe)
  parts <- Filter(function(x) nrow(x) > 0L, parts)
  if (!length(parts)) return(data.frame())
  all_names <- unique(unlist(lapply(parts, names), use.names = FALSE))
  parts <- lapply(parts, function(x) {
    missing <- setdiff(all_names, names(x))
    for (nm in missing) x[[nm]] <- NA
    x[all_names]
  })
  do.call(rbind, parts)
}

latest_run_dir <- function(repo_root) {
  roots <- c(
    file.path(repo_root, "reports", "rqr_desn_broad_simulation"),
    file.path(repo_root, "reports", "rqr_desn_broad_simulation_smoke")
  )
  dirs <- unlist(lapply(roots, function(root) {
    if (!dir.exists(root)) character(0) else list.dirs(root, recursive = FALSE, full.names = TRUE)
  }), use.names = FALSE)
  dirs <- dirs[grepl("rqr_desn_broad_run_", basename(dirs), fixed = TRUE)]
  if (!length(dirs)) stop("No RQR-DESN broad run directories found.", call. = FALSE)
  dirs[order(file.info(dirs)$mtime, decreasing = TRUE)][1L]
}

healthcheck_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  cli <- parse_cli(args)
  repo_root <- cli[["repo-root"]] %||% tryCatch(system("git rev-parse --show-toplevel", intern = TRUE), error = function(e) "")
  if (!nzchar(repo_root)) repo_root <- getwd()
  repo_root <- normalizePath(repo_root, mustWork = TRUE)
  output_dir <- cli[["output-dir"]] %||% latest_run_dir(repo_root)
  output_dir <- normalizePath(output_dir, mustWork = TRUE)

  launch_manifest <- read_csv_safe(file.path(output_dir, "launch_manifest.csv"))
  if (!nrow(launch_manifest)) {
    launch_manifest <- read_csv_safe(file.path(output_dir, "scenario_manifest.csv"))
  }
  if (!nrow(launch_manifest)) stop("No launch_manifest.csv or scenario_manifest.csv found.", call. = FALSE)

  scenario_dirs <- as.character(launch_manifest$scenario_output_dir)
  statuses <- combine_csvs(file.path(scenario_dirs, "scenario_status.csv"))
  metrics <- combine_csvs(file.path(scenario_dirs, "interval_metrics.csv"))
  failures <- combine_csvs(file.path(scenario_dirs, "failure_log.csv"))
  mcmc_diag <- combine_csvs(file.path(scenario_dirs, "mcmc_diagnostics.csv"))
  vb_diag <- combine_csvs(file.path(scenario_dirs, "vb_diagnostics.csv"))

  total <- nrow(launch_manifest)
  completed <- sum(statuses$status == "completed", na.rm = TRUE)
  failed <- sum(statuses$status == "failed", na.rm = TRUE)
  running <- sum(statuses$status == "running", na.rm = TRUE)
  terminal <- completed + failed
  pending <- max(0L, total - terminal - running)
  pct_terminal <- if (total) 100 * terminal / total else NA_real_

  by_status <- if (nrow(statuses)) {
    as.data.frame(table(statuses$status), stringsAsFactors = FALSE)
  } else {
    data.frame(Var1 = character(0), Freq = integer(0))
  }
  names(by_status) <- c("status", "n")

  summary <- data.frame(
    output_dir = output_dir,
    total_selected = total,
    completed = completed,
    failed = failed,
    running = running,
    pending = pending,
    terminal = terminal,
    pct_terminal = round(pct_terminal, 2),
    metric_rows = nrow(metrics),
    failure_rows = nrow(failures),
    mcmc_diag_rows = nrow(mcmc_diag),
    vb_diag_rows = nrow(vb_diag),
    checked_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    stringsAsFactors = FALSE
  )

  write_csv(summary, file.path(output_dir, "healthcheck_latest.csv"))
  write_csv(by_status, file.path(output_dir, "healthcheck_status_counts.csv"))

  lines <- c(
    "# RQR-DESN Broad Simulation Healthcheck",
    "",
    sprintf("Checked: %s", summary$checked_at[1L]),
    sprintf("Output directory: `%s`", output_dir),
    "",
    sprintf("- selected rows: `%d`", total),
    sprintf("- completed: `%d`", completed),
    sprintf("- failed: `%d`", failed),
    sprintf("- running: `%d`", running),
    sprintf("- pending: `%d`", pending),
    sprintf("- terminal percent: `%.2f`", pct_terminal),
    sprintf("- metric rows: `%d`", nrow(metrics)),
    sprintf("- failure-log rows: `%d`", nrow(failures)),
    sprintf("- MCMC diagnostics rows: `%d`", nrow(mcmc_diag)),
    sprintf("- VB diagnostics rows: `%d`", nrow(vb_diag))
  )
  writeLines(lines, file.path(output_dir, "healthcheck_latest.md"))

  print(summary, row.names = FALSE)
  if (nrow(by_status)) print(by_status, row.names = FALSE)
  invisible(summary)
}

if (sys.nframe() == 0L) {
  healthcheck_main()
}

#!/usr/bin/env Rscript

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

parse_cli <- function(args) {
  out <- list()
  ii <- 1L
  while (ii <= length(args)) {
    key <- args[[ii]]
    if (!startsWith(key, "--")) stop(sprintf("Unexpected positional argument: %s", key), call. = FALSE)
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

read_csv_maybe <- function(path) {
  if (!file.exists(path)) return(data.frame())
  tryCatch(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) data.frame())
}

write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
}

bind_rows <- function(parts) {
  parts <- Filter(function(x) nrow(x) > 0L || length(names(x)) > 0L, parts)
  if (!length(parts)) return(data.frame())
  all_names <- unique(unlist(lapply(parts, names), use.names = FALSE))
  parts <- lapply(parts, function(x) {
    missing <- setdiff(all_names, names(x))
    for (nm in missing) x[[nm]] <- NA
    x[all_names]
  })
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}

combine_pairwise_deltas <- function(metrics) {
  if (!nrow(metrics)) return(data.frame())
  baseline <- metrics[
    metrics$method_id == "empirical_train_interval",
    c("stage_id", "family_id", "replicate_id", "coverage_level", "scenario_id", "interval_score_mean", "mean_width"),
    drop = FALSE
  ]
  if (!nrow(baseline)) return(data.frame())
  names(baseline)[names(baseline) == "scenario_id"] <- "baseline_scenario_id"
  names(baseline)[names(baseline) == "interval_score_mean"] <- "baseline_interval_score_mean"
  names(baseline)[names(baseline) == "mean_width"] <- "baseline_mean_width"
  model <- metrics[metrics$method_id != "empirical_train_interval", , drop = FALSE]
  if (!nrow(model)) return(data.frame())
  out <- merge(model, baseline, by = c("stage_id", "family_id", "replicate_id", "coverage_level"), all.x = TRUE, sort = FALSE)
  out$interval_score_delta <- out$interval_score_mean - out$baseline_interval_score_mean
  out$width_ratio <- out$mean_width / out$baseline_mean_width
  out
}

hash_outputs <- function(output_root) {
  files <- list.files(output_root, full.names = TRUE, recursive = FALSE)
  files <- files[file.info(files)$isdir %in% FALSE]
  files <- files[basename(files) != "output_hashes.csv"]
  write_csv(data.frame(file = basename(files), md5 = unname(tools::md5sum(files))), file.path(output_root, "output_hashes.csv"))
}

main <- function(args = commandArgs(trailingOnly = TRUE)) {
  cli <- parse_cli(args)
  output_root <- normalizePath(cli[["output-root"]] %||% stop("--output-root is required.", call. = FALSE), mustWork = TRUE)
  repo_root <- normalizePath(cli[["repo-root"]] %||% system("git rev-parse --show-toplevel", intern = TRUE)[1L], mustWork = TRUE)
  shards_root <- file.path(output_root, "shards")
  shard_dirs <- list.dirs(shards_root, recursive = FALSE, full.names = TRUE)
  shard_dirs <- shard_dirs[grepl("^shard_[0-9]+$", basename(shard_dirs))]
  if (!length(shard_dirs)) stop(sprintf("No shard directories found under %s.", shards_root), call. = FALSE)

  launch <- bind_rows(lapply(shard_dirs, function(d) read_csv_maybe(file.path(d, "launch_manifest.csv"))))
  metrics <- bind_rows(lapply(shard_dirs, function(d) read_csv_maybe(file.path(d, "interval_metrics.csv"))))
  mcmc <- bind_rows(lapply(shard_dirs, function(d) read_csv_maybe(file.path(d, "mcmc_diagnostics.csv"))))
  failures <- bind_rows(lapply(shard_dirs, function(d) read_csv_maybe(file.path(d, "failure_log.csv"))))
  statuses <- bind_rows(lapply(shard_dirs, function(d) read_csv_maybe(file.path(d, "run_status.csv"))))
  worker_status <- read_csv_maybe(file.path(output_root, "worker_status.csv"))

  write_csv(launch, file.path(output_root, "launch_manifest.csv"))
  write_csv(metrics, file.path(output_root, "interval_metrics.csv"))
  write_csv(mcmc, file.path(output_root, "mcmc_diagnostics.csv"))
  write_csv(failures, file.path(output_root, "failure_log.csv"))
  write_csv(statuses, file.path(output_root, "run_status.csv"))
  write_csv(combine_pairwise_deltas(metrics), file.path(output_root, "replicate_pairwise_deltas.csv"))

  terminal_ok <- nrow(statuses) == nrow(launch) && nrow(launch) > 0L &&
    all(statuses$status %in% c("completed", "failed"))
  worker_ok <- nrow(worker_status) > 0L && all(as.integer(worker_status$exit_code) == 0L)
  gates <- data.frame(
    gate = c("all_workers_exit_zero", "all_launch_rows_terminal", "no_rqr_predictive_response_draws", "no_qdesn_pair_scalar_density_claim"),
    status = c(
      if (worker_ok) "pass" else "fail",
      if (terminal_ok) "pass" else "fail",
      if (!nrow(metrics) || !any(tolower(as.character(metrics$rqr_response_predictive_draws)) %in% c("true", "t", "1", "yes"))) "pass" else "fail",
      if (!nrow(metrics) || !any(tolower(as.character(metrics$qdesn_pair_scalar_density)) %in% c("true", "t", "1", "yes"))) "pass" else "fail"
    ),
    observed = c(
      if (nrow(worker_status)) sum(as.integer(worker_status$exit_code) == 0L) else 0L,
      nrow(statuses),
      NA,
      NA
    ),
    expected = c(nrow(worker_status), nrow(launch), 0, 0)
  )
  write_csv(gates, file.path(output_root, "readiness_gates.csv"))
  writeLines(c(
    "# RQR-DESN Article-Congruent Shard Collection",
    "",
    sprintf("- output root: `%s`", output_root),
    sprintf("- shard directories: `%d`", length(shard_dirs)),
    sprintf("- launch rows: `%d`", nrow(launch)),
    sprintf("- metric rows: `%d`", nrow(metrics)),
    sprintf("- failed rows: `%d`", nrow(failures)),
    sprintf("- completed rows: `%d`", sum(statuses$status == "completed", na.rm = TRUE)),
    "",
    "This collector combines package-ready shard outputs. Article promotion still requires the results audit."
  ), file.path(output_root, "closeout.md"))
  hash_outputs(output_root)

  audit_script <- file.path(repo_root, "scripts", "audit_rqr_desn_article_congruent_results.R")
  if (file.exists(audit_script)) {
    audit_dir <- file.path(output_root, "results_audit")
    out <- system2(file.path(R.home("bin"), "Rscript"), c(audit_script, "--run-dir", output_root, "--output-dir", audit_dir), stdout = TRUE, stderr = TRUE)
    status <- attr(out, "status", exact = TRUE) %||% 0L
    writeLines(out, file.path(output_root, "collector_audit.log"))
    if (!identical(as.integer(status), 0L)) stop(sprintf("Combined audit failed:\n%s", paste(out, collapse = "\n")), call. = FALSE)
  }
  message(sprintf("Collected RQR-DESN article-congruent shards into %s", output_root))
  invisible(output_root)
}

if (sys.nframe() == 0L) main()

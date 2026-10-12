#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) stop("Usage: <command> <repo> [arguments]")
command <- args[1L]
repo <- normalizePath(args[2L], mustWork = TRUE)

for (file in c("independent_qdesn_training1000_runtime_v1.R",
    "independent_qdesn_training1000_campaign_v1.R",
    "independent_qdesn_sentinel_mechanism_v1.R",
    "independent_qdesn_training_size_mechanism_v6.R",
    "independent_qdesn_gausmix_conditioning_v7.R",
    "independent_qdesn_forecast_uncertainty_v8.R",
    "independent_qdesn_rhs_uncertainty_v9.R",
    "independent_qdesn_layerwise_readout_v10.R"))
  source(file.path(repo, "validation/fitforecast_v2/R", file))

if (command == "materialize") {
  stopifnot(length(args) >= 4L)
  invisible(ilr10_materialize(repo, args[3L], args[4L],
    if (length(args) >= 5L) args[5L] else ilr10_parent_run))
} else if (command == "worker") {
  stopifnot(length(args) == 3L)
  invisible(ilr10_worker(args[3L]))
} else if (command == "pending") {
  stopifnot(length(args) == 4L)
  run <- normalizePath(args[3L], mustWork = TRUE)
  stage <- args[4L]
  plan <- read.csv(file.path(run, "plans", paste0(stage, ".csv")),
    stringsAsFactors = FALSE)
  for (i in seq_len(nrow(plan))) {
    status <- if (file.exists(plan$status_path[i]))
      iqt12_read(plan$status_path[i])$status else "PENDING"
    if (status == "PENDING")
      cat(paste(plan$id[i], plan$config_path[i], plan$timeout[i], sep = "\t"),
        "\n", sep = "")
  }
} else if (command == "advance") {
  stopifnot(length(args) == 4L)
  invisible(ilr10_advance(normalizePath(args[3L], mustWork = TRUE), args[4L]))
} else if (command == "health") {
  stopifnot(length(args) == 3L)
  print(ilr10_health(normalizePath(args[3L], mustWork = TRUE)), row.names = FALSE)
} else if (command == "verify") {
  stopifnot(length(args) == 3L)
  run <- normalizePath(args[3L], mustWork = TRUE)
  if (file.exists(file.path(run, "closeout_manifest.csv")))
    iqt12_verify(file.path(run, "closeout_manifest.csv"))
  health <- ilr10_health(run)
  stopifnot(!nrow(health) || all(health$failed == 0L))
  print(health, row.names = FALSE)
} else if (command == "resources") {
  workers <- if (length(args) >= 3L) as.integer(args[3L]) else 30L
  cat(paste(ilr10_resources(workers), collapse = ","), "\n", sep = "")
} else if (command == "exit") {
  stopifnot(length(args) == 5L)
  config <- iqt12_read(args[3L])
  code <- as.integer(args[4L])
  elapsed <- as.numeric(args[5L])
  status <- if (file.exists(config$status_path))
    iqt12_read(config$status_path) else NULL
  if (code != 0L && (is.null(status) || status$status == "RUNNING"))
    iqt12_json(list(status = "FAILED_PROCESS_EXIT", id = config$id,
      exit_code = code, elapsed = elapsed), config$status_path)
  status <- iqt12_read(config$status_path)
  if (status$status != "SUCCESS") stop("Worker did not succeed: ", config$id,
    " [", status$status, "]")
} else {
  stop("Unknown command: ", command)
}

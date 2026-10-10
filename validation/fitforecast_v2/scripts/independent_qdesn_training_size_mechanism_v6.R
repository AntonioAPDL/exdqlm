#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) stop("Usage: <command> <repo> [arguments]")
command <- args[1L]
repo <- normalizePath(args[2L], mustWork = TRUE)

source(file.path(repo, "validation/fitforecast_v2/R",
  "independent_qdesn_training1000_runtime_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R",
  "independent_qdesn_training1000_campaign_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R",
  "independent_qdesn_sentinel_mechanism_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R",
  "independent_qdesn_training_size_mechanism_v6.R"))

if (command == "materialize") {
  stopifnot(length(args) >= 4L)
  invisible(itm6_materialize(repo, args[3L], args[4L],
    if (length(args) >= 5L) args[5L] else itm6_parent_run,
    if (length(args) >= 6L) args[6L] else itm6_sentinel_run))
} else if (command == "worker") {
  stopifnot(length(args) == 3L)
  invisible(itm6_worker(args[3L]))
} else if (command == "pending") {
  stopifnot(length(args) == 4L)
  run <- normalizePath(args[3L], mustWork = TRUE)
  stage <- args[4L]
  plan <- read.csv(file.path(run, "plans", paste0(stage, ".csv")),
    stringsAsFactors = FALSE)
  if (nrow(plan)) for (i in seq_len(nrow(plan))) {
    status <- if (file.exists(plan$status_path[i]))
      iqt12_read(plan$status_path[i])$status else "PENDING"
    if (status == "PENDING") {
      cat(paste(plan$id[i], plan$config_path[i], plan$timeout[i], sep = "\t"),
        "\n", sep = "")
    }
  }
} else if (command == "advance") {
  stopifnot(length(args) == 4L)
  invisible(itm6_advance(normalizePath(args[3L], mustWork = TRUE), args[4L]))
} else if (command == "health") {
  stopifnot(length(args) == 3L)
  print(itm6_health(normalizePath(args[3L], mustWork = TRUE)), row.names = FALSE)
} else if (command == "resources") {
  workers <- if (length(args) >= 3L) as.integer(args[3L]) else 30L
  cat(paste(itm6_resources(workers), collapse = ","), "\n", sep = "")
} else if (command == "exit") {
  stopifnot(length(args) == 5L)
  config <- iqt12_read(args[3L])
  code <- as.integer(args[4L])
  elapsed <- as.numeric(args[5L])
  status <- if (file.exists(config$status_path))
    iqt12_read(config$status_path) else NULL
  if (code != 0L && (is.null(status) || status$status == "RUNNING")) {
    iqt12_json(list(status = "FAILED_PROCESS_EXIT", id = config$id,
      exit_code = code, elapsed = elapsed), config$status_path)
  }
  status <- iqt12_read(config$status_path)
  if (status$status != "SUCCESS") stop("Worker did not succeed: ", config$id,
    " [", status$status, "]")
} else {
  stop("Unknown command: ", command)
}

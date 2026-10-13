#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 2L)
command <- args[1L]; repo <- normalizePath(args[2L], mustWork = TRUE)
for (file in c("independent_qdesn_training1000_runtime_v1.R",
    "independent_qdesn_training1000_campaign_v1.R", "independent_qdesn_sentinel_mechanism_v1.R",
    "independent_qdesn_training_size_mechanism_v6.R", "independent_qdesn_gausmix_conditioning_v7.R",
    "independent_qdesn_forecast_uncertainty_v8.R", "independent_qdesn_rhs_uncertainty_v9.R",
    "independent_qdesn_layerwise_readout_v10.R", "independent_qdesn_fresh_dgp_v11.R",
    "independent_qdesn_dynamic_location_v12.R", "independent_qdesn_readout_memory_v13.R"))
  source(file.path(repo, "validation/fitforecast_v2/R", file))
if (command == "history-roots") {
  stopifnot(length(args) == 3L)
  roots <- sort(unique(c(Sys.glob("/data/jaguir26/local/src/exdqlm__wt__independent_qdesn_*"),
    Sys.glob("/data/jaguir26/local/src/Article-Q-DESN/.worktrees/ind_qdesn_*"))))
  roots <- roots[dir.exists(roots) & roots != repo]
  stopifnot(length(roots) > 0L)
  dir.create(dirname(args[3L]), recursive = TRUE, showWarnings = FALSE)
  writeLines(roots, args[3L])
  cat(length(roots), "IND roots recorded\n")
} else if (command == "materialize") {
  stopifnot(length(args) == 6L)
  roots <- readLines(args[6L]); stopifnot(all(dir.exists(roots)))
  irm13_materialize(repo, args[3L], args[4L], args[5L], roots)
} else if (command == "worker") {
  stopifnot(length(args) == 3L); irm13_worker(args[3L])
} else if (command == "pending") {
  stopifnot(length(args) == 4L)
  p <- ifd11_plan_status(args[3L], args[4L])
  stopifnot(!is.null(p), !any(grepl("^FAILED", p$status)), !any(p$status == "RUNNING"))
  for (i in which(p$status == "PENDING"))
    cat(paste(p$id[i], p$config_path[i], p$timeout[i], sep = "\t"), "\n", sep = "")
} else if (command == "advance") {
  stopifnot(length(args) == 4L); irm13_advance(args[3L], args[4L])
} else if (command == "continue") {
  stopifnot(length(args) == 4L); irm13_continue(args[3L], args[4L])
} else if (command == "health") {
  stopifnot(length(args) == 3L); print(irm13_health(args[3L]), row.names = FALSE)
} else if (command == "verify") {
  stopifnot(length(args) == 3L); irm13_verify(args[3L]); cat("All manifests verified\n")
} else if (command == "resources") {
  count <- if (length(args) >= 3L) as.integer(args[3L]) else 30L
  evidence <- if (length(args) >= 4L) args[4L] else NULL
  cat(paste(ifd11_resources(count, evidence), collapse = ","), "\n", sep = "")
} else if (command == "exit") {
  stopifnot(length(args) == 5L)
  cfg <- iqt12_read(args[3L]); code <- as.integer(args[4L])
  status <- if (file.exists(cfg$status_path)) iqt12_read(cfg$status_path) else NULL
  if (code != 0L || is.null(status) || status$status != "SUCCESS") {
    iqt12_json(list(status = "FAILED_PROCESS_OR_AUDIT", id = cfg$id, exit_code = code,
      previous = status, elapsed = as.numeric(args[5L])), cfg$status_path)
    stop("Worker or final audit failed: ", cfg$id)
  }
  iqt12_verify(status$manifest)
} else stop("Unknown command: ", command)

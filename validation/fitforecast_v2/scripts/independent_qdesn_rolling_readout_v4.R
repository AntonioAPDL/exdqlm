args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 2L)
action <- args[1L]
repo <- normalizePath(args[2L], mustWork = TRUE)
for (file in c("independent_qdesn_training1000_runtime_v1.R",
    "independent_qdesn_training1000_campaign_v1.R",
    "independent_qdesn_sentinel_mechanism_v1.R",
    "independent_qdesn_sentinel_mechanism_recovery_v1.R",
    "independent_qdesn_causal_adaptation_v2.R",
    "independent_qdesn_mcmc_finalist_bridge_v3.R",
    "independent_qdesn_rolling_readout_v4.R"))
  source(file.path(repo, "validation/fitforecast_v2/R", file))

if (action == "materialize") {
  stopifnot(length(args) == 5L)
  irrv4_materialize(repo, args[3L], args[4L], args[5L])
  cat("MATERIALIZED\n")
} else if (action == "recover") {
  stopifnot(length(args) == 5L)
  irrv4_recover_materialize(repo, args[3L], args[4L], args[5L])
  cat("RECOVERED\n")
} else if (action == "worker") {
  stopifnot(length(args) == 3L)
  irrv4_worker(args[3L])
} else if (action == "advance") {
  stopifnot(length(args) == 4L)
  cat(irrv4_advance(args[3L], args[4L]), "\n")
} else if (action == "health") {
  stopifnot(length(args) == 3L)
  print(irrv4_health(args[3L]), row.names = FALSE)
} else if (action == "pending") {
  stopifnot(length(args) == 4L)
  plan <- read.csv(file.path(args[3L], "plans", paste0(args[4L], ".csv")),
    stringsAsFactors = FALSE)
  status <- vapply(plan$status_path, irrv4_status, "")
  if (any(!status %in% c("PENDING", "SUCCESS")))
    stop("Unresolved worker status in frozen stage")
  write.table(plan[status == "PENDING", c("id", "config_path", "timeout")],
    stdout(), sep = "\t", quote = FALSE, row.names = FALSE, col.names = FALSE)
} else if (action == "exit") {
  stopifnot(length(args) == 4L)
  cfg <- iqt12_read(args[3L]); code <- as.integer(args[4L])
  status <- if (file.exists(cfg$status_path)) iqt12_read(cfg$status_path) else
    list(status = "ABSENT")
  if (code != 0L || status$status != "SUCCESS") {
    if (!status$status %in% c("SUCCESS", "FAILED_IMPLEMENTATION"))
      iqt12_json(list(status = "FAILED_EXIT", exit_code = code, id = cfg$id),
        cfg$status_path)
    quit(status = 1L)
  }
} else if (action == "resources") {
  readstat <- function() {
    x <- readLines("/proc/stat"); x <- x[grepl("^cpu[0-9]+ ", x)]
    lapply(strsplit(trimws(x), " +"), function(z) as.numeric(z[-1L]))
  }
  a <- readstat(); Sys.sleep(2); b <- readstat()
  idle <- vapply(seq_along(a), function(i) {
    d <- b[[i]] - a[[i]]; (d[4L] + d[5L]) / sum(d[1:8])
  }, 0.0)
  allowed <- system2("taskset", c("-pc", Sys.getpid()), stdout = TRUE)
  affinity <- trimws(sub(".*: ", "", tail(allowed, 1L)))
  permitted <- unlist(lapply(strsplit(affinity, ",")[[1L]], function(z) {
    r <- as.integer(strsplit(z, "-", fixed = TRUE)[[1L]])
    if (length(r) == 1L) r else seq.int(r[1L], r[2L])
  }))
  topo <- read.csv(text = system2("lscpu", "-p=CPU,CORE,SOCKET", stdout = TRUE),
    comment.char = "#", header = FALSE, col.names = c("cpu", "core", "socket"))
  topo$idle <- idle[topo$cpu + 1L]
  physical <- paste(topo$core, topo$socket)
  occupied <- unique(physical[!is.finite(topo$idle) | topo$idle < .85])
  topo <- topo[topo$cpu %in% permitted & topo$idle >= .85 &
    !physical %in% occupied, ]
  topo <- topo[order(-topo$idle, topo$cpu), ]
  topo <- topo[!duplicated(paste(topo$core, topo$socket)), ]
  mem <- readLines("/proc/meminfo")
  available <- as.numeric(gsub("[^0-9]", "",
    mem[grepl("^MemAvailable:", mem)])) / 1024^2
  n <- min(15L, nrow(topo), floor(max(0, available - 32) / 10))
  if (n < 1L) stop("No safe unused physical-core/RAM capacity")
  cat(paste(head(topo$cpu, n), collapse = ","), "\n", sep = "")
} else stop("Unknown action")

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 2L)
action <- args[1]; repo <- normalizePath(args[2], mustWork = TRUE)
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_runtime_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_campaign_v1.R"))
library_path <- file.path(repo, "validation/fitforecast_v2/local_trackers/training1000_exdqlm112_runtime/Rlib")
if (action == "materialize") {
  stopifnot(length(args) == 7L)
  invisible(iqt12_materialize(repo, args[3], library_path, args[4], args[5], args[6], args[7]))
  cat("Frozen campaign:", args[3], "\n")
} else if (action == "worker") {
  iqt12_worker(args[3])
} else if (action == "advance") {
  cat(iqt12_advance(args[3], args[4]), "\n")
} else if (action == "health") {
  print(iqt12_health(args[3]), row.names = FALSE)
} else if (action == "pending") {
  z <- read.csv(file.path(args[3], "plans", paste0(args[4], ".csv")))
  if (nrow(z)) {
    exists <- file.exists(z$status_path)
    statuses <- rep("PENDING", nrow(z))
    statuses[exists] <- vapply(z$status_path[exists], function(p) iqt12_read(p)$status, "")
    if (any(statuses != "PENDING" & statuses != "SUCCESS"))
      stop("Unresolved previous worker status; audit before resuming.")
    write.table(z[statuses == "PENDING", c("id", "config_path", "timeout")],
      stdout(), sep = "\t", quote = FALSE, row.names = FALSE, col.names = FALSE)
  }
} else if (action == "exit") {
  cfg <- iqt12_read(args[3]); code <- as.integer(args[4])
  status <- if (file.exists(cfg$status_path)) iqt12_read(cfg$status_path) else list(status = "ABSENT")
  if (code != 0L || status$status != "SUCCESS") {
    iqt12_json(list(status = "FAILED_EXIT", exit_code = code, previous_status = status,
      config = cfg$path), file.path(cfg$evidence, "worker_exit_failure.json"))
    if (!status$status %in% c("SUCCESS", "FAILED_IMPLEMENTATION"))
      iqt12_json(list(status = "FAILED_EXIT", exit_code = code, id = cfg$id), cfg$status_path)
    quit(status = 1L)
  }
} else if (action == "resources") {
  # Sample idle logical CPUs, then select only one sibling per physical core.
  readstat <- function() {
    x <- readLines("/proc/stat"); x <- x[grepl("^cpu[0-9]+ ", x)]
    lapply(strsplit(trimws(x), " +"), function(z) as.numeric(z[-1]))
  }
  a <- readstat(); Sys.sleep(2); b <- readstat()
  idle <- vapply(seq_along(a), function(i) {
    d <- b[[i]] - a[[i]]; (d[4] + d[5]) / sum(d[1:8])
  }, 0.0)
  allowed <- system2("taskset", c("-pc", Sys.getpid()), stdout = TRUE)
  affinity <- trimws(sub(".*: ", "", tail(allowed, 1)))
  permitted <- unlist(lapply(strsplit(affinity, ",")[[1]], function(z) {
    r <- as.integer(strsplit(z, "-", fixed = TRUE)[[1]])
    if (length(r) == 1) r else seq.int(r[1], r[2])
  }))
  topo <- read.csv(text = system2("lscpu", "-p=CPU,CORE,SOCKET", stdout = TRUE),
    comment.char = "#", header = FALSE, col.names = c("cpu", "core", "socket"))
  topo$idle <- idle[topo$cpu + 1L]
  physical <- paste(topo$core, topo$socket)
  occupied <- unique(physical[!is.finite(topo$idle) | topo$idle < .85])
  topo <- topo[topo$cpu %in% permitted & topo$idle >= .85 & !physical %in% occupied, ]
  topo <- topo[order(-topo$idle, topo$cpu), ]
  topo <- topo[!duplicated(paste(topo$core, topo$socket)), ]
  mem <- readLines("/proc/meminfo")
  available <- as.numeric(gsub("[^0-9]", "", mem[grepl("^MemAvailable:", mem)])) / 1024^2
  n <- min(15L, nrow(topo), floor(max(0, available - 24) / 12))
  if (n < 1L) stop("No safe unused physical-core/RAM capacity.")
  cat(paste(head(topo$cpu, n), collapse = ","), "\n", sep = "")
} else stop("Unknown action: ", action)

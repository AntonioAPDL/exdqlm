iqt12r_stages <- c("bridge", "final_vb", "final_warm", "final_mcmc")

iqt12r_jobs <- function(run) {
  paths <- list.files(file.path(run, "plans"), "[.]csv$", full.names = TRUE)
  paths <- paths[!grepl("_hashes[.]csv$", paths)]
  z <- do.call(rbind, lapply(paths, read.csv))
  stopifnot(!is.null(z), !anyDuplicated(z$id))
  z$status <- vapply(z$status_path, function(p)
    if (file.exists(p)) iqt12_read(p)$status else "PENDING", "")
  z
}

iqt12r_reconcile <- function(run, jobs = iqt12r_jobs(run)) {
  if (any(!jobs$status %in% c("PENDING", "SUCCESS")))
    stop("Unresolved worker status; do not relaunch or overwrite it.")
  old <- file.path(run, "receipts/exits.tsv")
  exits <- if (file.exists(old) && file.info(old)$size > 0) read.delim(old, header = FALSE,
    col.names = c("id", "exit_code", "wall_seconds", "cpu")) else
      data.frame(id = character(), exit_code = integer(), wall_seconds = numeric(), cpu = integer())
  stopifnot(!anyDuplicated(exits$id), all(exits$exit_code == 0L),
    all(is.finite(exits$wall_seconds)), all(exits$wall_seconds >= 0), all(exits$id %in% jobs$id))
  recovered <- list.files(file.path(run, "recovery"), "[.]json$", recursive = TRUE, full.names = TRUE)
  recovered <- recovered[grepl("/scheduler_exits/", recovered, fixed = TRUE)]
  extra <- lapply(recovered, iqt12_read)
  extra_ids <- vapply(extra, function(x) x$id, "")
  stopifnot(!anyDuplicated(extra_ids), !any(extra_ids %in% exits$id), all(extra_ids %in% jobs$id))
  success <- jobs[jobs$status == "SUCCESS", ]
  ledger <- lapply(seq_len(nrow(success)), function(i) {
    p <- success[i, ]; s <- iqt12_read(p$status_path)
    stopifnot(is.finite(s$elapsed), s$elapsed >= 0, is.finite(s$cpu_seconds), s$cpu_seconds >= 0)
    reported <- exits$wall_seconds[exits$id == p$id]
    previous <- vapply(extra[extra_ids == p$id], function(x) x$budget_seconds, 0.0)
    data.frame(id = p$id, elapsed = s$elapsed, cpu_seconds = s$cpu_seconds,
      collected_wall_seconds = if (length(reported)) reported else NA_real_,
      recovered_budget_seconds = if (length(previous)) previous else NA_real_,
      budget_seconds = ceiling(max(c(s$elapsed, s$cpu_seconds, reported, previous))),
      original_exit_collected = length(reported) == 1L)
  })
  if (!length(ledger)) return(data.frame(id = character(), budget_seconds = numeric()))
  do.call(rbind, ledger)
}

iqt12r_process_matches <- function(pid, token, reader = function(p) {
  path <- file.path("/proc", p, "cmdline")
  if (!file.exists(path)) return("")
  x <- readBin(path, "raw", n = 131072L)
  x[x == as.raw(0)] <- as.raw(32)
  rawToChar(x)
}) {
  if (!is.numeric(pid) || length(pid) != 1L || !is.finite(pid) || pid <= 1) return(FALSE)
  tryCatch(grepl(token, reader(as.integer(pid)), fixed = TRUE), error = function(e) FALSE)
}

iqt12r_run_command <- function(command, args) {
  out <- tempfile(); err <- tempfile()
  on.exit(unlink(c(out, err)))
  code <- suppressWarnings(system2(command, args, stdout = out, stderr = err))
  list(code = as.integer(code), stdout = readLines(out, warn = FALSE),
    stderr = readLines(err, warn = FALSE))
}

iqt12r_transient_du <- function(lines, run) {
  if (!length(lines)) return(FALSE)
  prefix <- "du: cannot access '"; suffix <- "': No such file or directory"
  all(vapply(lines, function(line) {
    if (!startsWith(line, prefix) || !endsWith(line, suffix)) return(FALSE)
    path <- substr(line, nchar(prefix) + 1L, nchar(line) - nchar(suffix))
    relative <- if (startsWith(path, paste0(run, "/"))) substring(path, nchar(run) + 2L) else ""
    if (grepl("[.][.]/", relative)) return(FALSE)
    flat_status <- startsWith(relative, "status/") &&
      !grepl("/", substring(relative, 8L), fixed = TRUE)
    nested_atomic <- any(startsWith(relative, c("evidence/", "recovery/", "diagnostics/")))
    (flat_status || nested_atomic) && grepl("/[A-Za-z0-9_]+[.]json[.]tmp[.][0-9]+$", relative)
  }, TRUE))
}

iqt12r_disk <- function(run, runner = iqt12r_run_command, retry = 3L,
  sleeper = Sys.sleep, maximum_kib = 41943040, minimum_free_kib = 20971520) {
  history <- list()
  for (i in seq_len(retry)) {
    value <- runner("du", c("-sk", shQuote(run)))
    history[[i]] <- value
    if (value$code == 0L) break
    if (value$code != 1L || !iqt12r_transient_du(value$stderr, run))
      stop("Non-transient disk telemetry failure: ", paste(value$stderr, collapse = " | "))
    if (i == retry) stop("Transient disk telemetry retries exhausted; stop dispatch and drain.")
    sleeper(.2)
  }
  if (length(value$stderr)) stop("Unexpected stderr on successful disk scan.")
  text <- strsplit(trimws(value$stdout), "[[:space:]]+")
  if (length(text) != 1L || length(text[[1]]) < 2L || !grepl("^[0-9]+$", text[[1]][1]))
    stop("Invalid disk aggregate; cannot enforce run-size bound.")
  size <- as.numeric(text[[1]][1])
  free <- runner("df", c("-Pk", shQuote(run)))
  if (free$code != 0L || length(free$stderr) || length(free$stdout) != 2L)
    stop("Invalid free-space telemetry; stop dispatch and drain.")
  fields <- strsplit(trimws(free$stdout[2]), "[[:space:]]+")[[1]]
  if (length(fields) < 6L || !grepl("^[0-9]+$", fields[4])) stop("Invalid free-space aggregate.")
  available <- as.numeric(fields[4])
  if (!is.finite(size) || !is.finite(available) || size > maximum_kib || available < minimum_free_kib)
    stop("Disk budget review required.")
  list(size_kib = size, free_kib = available, attempts = length(history))
}

iqt12r_epoch <- function(run, stage, context) {
  stopifnot(stage %in% iqt12r_stages)
  plan <- file.path(run, "plans", paste0(stage, ".csv"))
  if (!file.exists(plan)) stop("Missing frozen stage plan: ", stage)
  epoch <- floor(as.numeric(file.info(plan)$mtime))
  if (stage == "bridge") epoch <- min(epoch, context$original_bridge_epoch)
  stopifnot(is.finite(epoch), epoch > 0)
  epoch
}

iqt12r_prepare <- function(driver, science, run, control) {
  stopifnot(!file.exists(file.path(control, "context.json")))
  state <- iqt12_read(file.path(run, "campaign.json"))
  head <- function(repo) system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE)
  stopifnot(state$protocol == "training1000_targeted_v2_case_specific_continuation",
    normalizePath(state$repo) == science, normalizePath(state$run) == run,
    state$head == head(science), state$head == "c27fc70afd6c19366eff551d693f2bbe1d76bdbc",
    length(system2("git", c("-C", science, "status", "--porcelain"), stdout = TRUE)) == 0L,
    length(system2("git", c("-C", driver, "status", "--porcelain"), stdout = TRUE)) == 0L)
  for (name in c("source_hashes.csv", "input_hashes.csv", "package_hashes.csv", "frozen_hashes.csv"))
    iqt12_verify(file.path(run, name))
  jobs <- iqt12r_jobs(run); budget <- iqt12r_reconcile(run, jobs)
  success <- jobs[jobs$status == "SUCCESS", ]
  for (path in success$status_path) iqt12_verify(iqt12_read(path)$manifest)
  for (path in list.files(file.path(run, "plans"), "_hashes[.]csv$", full.names = TRUE)) iqt12_verify(path)
  status <- readLines(file.path(run, "scheduler.status"))
  parts <- strsplit(status[1], "\t")[[1]]
  stopifnot(length(parts) >= 3L, "stage=bridge" %in% parts)
  epoch <- as.numeric(as.POSIXct(parts[2], format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  stopifnot(is.finite(epoch), state$maximum_campaign_cpu_hours == 400,
    state$max_workers == 15L, sum(budget$budget_seconds) < 400 * 3600,
    startsWith(control, paste0(run, "/recovery/")))
  dir.create(control, recursive = TRUE, showWarnings = FALSE)
  file.copy(file.path(run, "scheduler.status"), file.path(control, "pre_recovery_scheduler.status"))
  iqt12_csv(budget, file.path(control, "initial_budget_ledger.csv"))
  success$status_sha <- unname(tools::sha256sum(success$status_path))
  iqt12_csv(success, file.path(control, "protected_successes.csv"))
  pending <- jobs[jobs$status == "PENDING" & jobs$stage == "bridge", c("id", "config_path", "timeout")]
  stopifnot(nrow(pending) > 0L, !any(pending$id %in% success$id))
  iqt12_csv(pending, file.path(control, "initial_pending_bridge.csv"))
  context <- list(schema = "IND_training1000_scheduler_recovery_v1", science_repo = science,
    run = run, control = control, driver_repo = driver, scientific_HEAD = state$head,
    driver_HEAD = head(driver), original_bridge_epoch = epoch,
    initial_spent_seconds = sum(budget$budget_seconds), initial_success_jobs = nrow(success),
    initial_pending_bridge_jobs = nrow(pending), initial_missing_original_exits = sum(!budget$original_exit_collected),
    cpu_budget_seconds = 400L * 3600L, stage_wall_seconds = 172800L, max_workers = 15L,
    minimum_dispatch_memory_kib = 37748736L, max_worker_RSS_kib = 12582912L,
    stages = iqt12r_stages, scientific_configs_changed = FALSE,
    scientific_cli = file.path(science, "validation/fitforecast_v2/scripts/independent_qdesn_training1000_targeted_v2.R"))
  iqt12_json(context, file.path(control, "context.json"))
  sources <- c(file.path(driver, "validation/fitforecast_v2/R", c("independent_qdesn_training1000_recovery_v1.R",
    "independent_qdesn_training1000_runtime_v1.R")),
    file.path(driver, "validation/fitforecast_v2/scripts", c("independent_qdesn_training1000_recovery_v1.R",
      "run_independent_qdesn_training1000_recovery_v1.sh")))
  iqt12_hash(sources, file.path(control, "driver_hashes.csv"))
  iqt12_hash(c(file.path(control, c("context.json", "driver_hashes.csv", "initial_budget_ledger.csv",
    "protected_successes.csv", "initial_pending_bridge.csv", "pre_recovery_scheduler.status")),
    success$status_path), file.path(control, "context_hashes.csv"))
  invisible(context)
}

iqt12r_validate <- function(control) {
  iqt12_verify(file.path(control, "context_hashes.csv"))
  iqt12_verify(file.path(control, "driver_hashes.csv"))
  context <- iqt12_read(file.path(control, "context.json"))
  for (name in c("source_hashes.csv", "input_hashes.csv", "package_hashes.csv", "frozen_hashes.csv"))
    iqt12_verify(file.path(context$run, name))
  context
}

iqt12r_account <- function(control, config, code, wall, cpu) {
  context <- iqt12_read(file.path(control, "context.json")); cfg <- iqt12_read(config)
  stopifnot(cfg$run == context$run, cfg$repo == context$science_repo,
    is.finite(wall), wall >= 0, is.finite(cpu), cpu >= 0)
  path <- file.path(control, "scheduler_exits", paste0(cfg$id, ".json"))
  stopifnot(!file.exists(path))
  status <- if (file.exists(cfg$status_path)) iqt12_read(cfg$status_path) else list(status = "ABSENT")
  value <- ceiling(max(c(wall, status$elapsed %||% 0, status$cpu_seconds %||% 0)))
  stopifnot(is.finite(value), value >= 0)
  iqt12_json(list(id = cfg$id, code = code, wall_seconds = wall, cpu = cpu,
    worker_status = status$status, budget_seconds = value,
    observed_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")), path)
  value
}

iqt12r_health <- function(control, matcher = iqt12r_process_matches) {
  context <- iqt12_read(file.path(control, "context.json"))
  pid <- suppressWarnings(as.numeric(readLines(file.path(control, "scheduler.pid"))))
  alive <- matcher(pid, control)
  heartbeat <- file.path(control, "heartbeat.epoch")
  epoch <- if (file.exists(heartbeat)) suppressWarnings(as.numeric(readLines(heartbeat))) else NA_real_
  age <- as.numeric(Sys.time()) - epoch
  jobs <- iqt12r_jobs(context$run)
  worker_states <- jobs[jobs$status == "RUNNING", ]
  live <- vapply(worker_states$status_path, function(p) {
    status <- iqt12_read(p)
    matcher(status$pid, context$run)
  }, TRUE)
  raw <- readLines(file.path(context$run, "scheduler.status"))
  effective <- if (alive && is.finite(age) && age <= 120) "SCHEDULER_LIVE" else
    if (alive) "SCHEDULER_LIVE_HEARTBEAT_STALE_REVIEW" else if (any(live))
      "SCHEDULER_DEAD_WORKERS_DRAINING" else if (sum(jobs$status == "PENDING"))
        "SCHEDULER_STOPPED_WITH_PENDING_JOBS" else "NO_ACTIVE_PROCESSES_REVIEW_CLOSEOUT"
  list(effective_status = effective, scheduler_alive = alive, heartbeat_age_seconds = age,
    complete = sum(jobs$status == "SUCCESS"), pending = sum(jobs$status == "PENDING"),
    active_worker_processes = sum(live), stale_RUNNING_workers = sum(!live),
    failed = sum(grepl("FAILED", jobs$status)), raw_scheduler_status = raw,
    scientific_HEAD = context$scientific_HEAD, driver_HEAD = context$driver_HEAD)
}

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 3L)
action <- args[1]; driver <- normalizePath(args[2], mustWork = TRUE); control <- args[3]
source(file.path(driver, "validation/fitforecast_v2/R/independent_qdesn_training1000_runtime_v1.R"))
source(file.path(driver, "validation/fitforecast_v2/R/independent_qdesn_training1000_recovery_v1.R"))
if (action == "prepare") {
  stopifnot(length(args) == 5L)
  iqt12r_prepare(driver, normalizePath(args[4]), normalizePath(args[5]), control)
} else if (action == "context") {
  c <- iqt12r_validate(control)
  ledger <- iqt12r_reconcile(c$run)
  cat(sum(ledger$budget_seconds), c$cpu_budget_seconds, c$max_workers, sep = "\t")
  cat("\n")
} else if (action == "stage") {
  c <- iqt12r_validate(control); stopifnot(length(args) == 4L)
  iqt12_verify(file.path(c$run, "plans", paste0(args[4], "_hashes.csv")))
  cat(iqt12r_epoch(c$run, args[4], c), "\n", sep = "")
} else if (action == "telemetry") {
  c <- iqt12_read(file.path(control, "context.json"))
  d <- iqt12r_disk(c$run)
  iqt12_json(d, file.path(control, "latest_disk.json"))
  cat(d$size_kib, d$free_kib, sep = "\t"); cat("\n")
} else if (action == "account") {
  stopifnot(length(args) == 7L)
  cat(iqt12r_account(control, args[4], as.integer(args[5]), as.numeric(args[6]), as.numeric(args[7])), "\n", sep = "")
} else if (action == "health") {
  h <- iqt12r_health(control)
  iqt12_json(h, file.path(control, "effective_health.json"))
  print(h)
} else stop("Unknown recovery action: ", action)

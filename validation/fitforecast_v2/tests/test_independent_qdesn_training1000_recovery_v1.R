repo <- normalizePath(Sys.getenv("IQT12_REPO", "."), mustWork = TRUE)
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_runtime_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_recovery_v1.R"))

testthat::test_that("only verified atomic JSON disappearances are transient", {
  line <- "du: cannot access '/tmp/run/status/bridge__a.json.tmp.123': No such file or directory"
  testthat::expect_true(iqt12r_transient_du(line, "/tmp/run"))
  testthat::expect_true(iqt12r_transient_du(sub("status/bridge__a", "evidence/bridge__a/diagnostics", line), "/tmp/run"))
  testthat::expect_true(iqt12r_transient_du(sub("status/bridge__a", "recovery/epoch/latest_disk", line), "/tmp/run"))
  testthat::expect_true(iqt12r_transient_du(sub("status/bridge__a", "diagnostics/health/audit_receipt", line), "/tmp/run"))
  testthat::expect_false(iqt12r_transient_du(character(), "/tmp/run"))
  testthat::expect_false(iqt12r_transient_du(sub("[.]tmp.123", "", line), "/tmp/run"))
  testthat::expect_false(iqt12r_transient_du(line, "/tmp/another"))
  testthat::expect_false(iqt12r_transient_du(sub("No such file or directory", "Permission denied", line), "/tmp/run"))
  testthat::expect_false(iqt12r_transient_du(c(line, "du: other error"), "/tmp/run"))
  testthat::expect_false(iqt12r_transient_du(sub("status/", "status/../", line, fixed = TRUE), "/tmp/run"))
  testthat::expect_false(iqt12r_transient_du(sub("status/", "sources/", line, fixed = TRUE), "/tmp/run"))
})

testthat::test_that("disk telemetry retries known races and fails closed otherwise", {
  error <- list(code = 1L, stdout = "100\t/tmp/run",
    stderr = "du: cannot access '/tmp/run/status/a.json.tmp.123': No such file or directory")
  ok <- list(code = 0L, stdout = "100\t/tmp/run", stderr = character())
  df <- list(code = 0L, stdout = c("Filesystem 1024-blocks Used Available Capacity Mounted",
    "/dev/a 90000000 20000000 70000000 23% /tmp"), stderr = character())
  make <- function(sequence, free = df) {
    i <- 0L
    function(command, args) {
      if (command == "df") return(free)
      i <<- i + 1L
      sequence[[min(i, length(sequence))]]
    }
  }
  value <- iqt12r_disk("/tmp/run", make(list(error, ok)), sleeper = function(x) NULL)
  testthat::expect_equal(value$attempts, 2L)
  testthat::expect_equal(value$size_kib, 100)
  testthat::expect_equal(value$free_kib, 70000000)
  testthat::expect_error(iqt12r_disk("/tmp/run", make(list(error)), sleeper = function(x) NULL), "exhausted")
  wrong <- error; wrong$stderr <- "du: cannot access '/tmp/run/source.csv': No such file or directory"
  testthat::expect_error(iqt12r_disk("/tmp/run", make(list(wrong))), "Non-transient")
  wrong <- error; wrong$stderr <- "Permission denied"
  testthat::expect_error(iqt12r_disk("/tmp/run", make(list(wrong))), "Non-transient")
  wrong <- ok; wrong$stdout <- "not_a_size\t/tmp/run"
  testthat::expect_error(iqt12r_disk("/tmp/run", make(list(wrong))), "Invalid disk")
  wrong <- ok; wrong$stderr <- "unexpected warning"
  testthat::expect_error(iqt12r_disk("/tmp/run", make(list(wrong))), "Unexpected stderr")
  wrong <- ok; wrong$stdout <- "41943041\t/tmp/run"
  testthat::expect_error(iqt12r_disk("/tmp/run", make(list(wrong))), "Disk budget")
  wrong <- df; wrong$stdout[2] <- "/dev/a 90000000 70000000 20000000 77% /tmp"
  testthat::expect_error(iqt12r_disk("/tmp/run", make(list(ok), wrong)), "Disk budget")
  wrong <- df; wrong$code <- 1L
  testthat::expect_error(iqt12r_disk("/tmp/run", make(list(ok), wrong)), "free-space")
})

iqt12r_budget_fixture <- function() {
  root <- tempfile(); dir.create(root)
  dir.create(file.path(root, "receipts"))
  a <- file.path(root, "a.json"); b <- file.path(root, "b.json")
  iqt12_json(list(status = "SUCCESS", elapsed = 20, cpu_seconds = 19), a)
  iqt12_json(list(status = "SUCCESS", elapsed = 22, cpu_seconds = 25), b)
  write.table(data.frame(id = "a", exit_code = 0, wall_seconds = 18, cpu = 1),
    file.path(root, "receipts/exits.tsv"), sep = "\t", quote = FALSE,
    row.names = FALSE, col.names = FALSE)
  list(root = root, jobs = data.frame(id = c("a", "b", "c"),
    status = c("SUCCESS", "SUCCESS", "PENDING"), status_path = c(a, b, file.path(root, "c.json"))))
}

testthat::test_that("budget reconstruction counts orphan successes exactly once", {
  f <- iqt12r_budget_fixture()
  z <- iqt12r_reconcile(f$root, f$jobs)
  testthat::expect_equal(sum(z$budget_seconds), 45)
  testthat::expect_equal(sum(!z$original_exit_collected), 1L)
  iqt12_json(list(id = "b", budget_seconds = 30), file.path(f$root, "recovery/e1/scheduler_exits/b.json"))
  z <- iqt12r_reconcile(f$root, f$jobs)
  testthat::expect_equal(sum(z$budget_seconds), 50)
  testthat::expect_equal(nrow(z), 2L)
  f$jobs$status[3] <- "RUNNING"
  testthat::expect_error(iqt12r_reconcile(f$root, f$jobs), "Unresolved")
  f$jobs$status[3] <- "FAILED_IMPLEMENTATION"
  testthat::expect_error(iqt12r_reconcile(f$root, f$jobs), "Unresolved")
  f$jobs$status[3] <- "PENDING"
  iqt12_json(list(id = "a", budget_seconds = 30), file.path(f$root, "recovery/e1/scheduler_exits/a.json"))
  testthat::expect_error(iqt12r_reconcile(f$root, f$jobs))
})

testthat::test_that("stage clocks retain the original deadline rather than reset", {
  root <- tempfile(); dir.create(file.path(root, "plans"), recursive = TRUE)
  p <- file.path(root, "plans/bridge.csv"); writeLines("synthetic", p)
  old <- floor(as.numeric(Sys.time())) - 3600
  testthat::expect_equal(iqt12r_epoch(root, "bridge", list(original_bridge_epoch = old)), old)
  Sys.setFileTime(p, as.POSIXct(old - 60, origin = "1970-01-01", tz = "UTC"))
  testthat::expect_equal(iqt12r_epoch(root, "bridge", list(original_bridge_epoch = old)), old - 60)
  testthat::expect_error(iqt12r_epoch(root, "quantile_A", list(original_bridge_epoch = old)))
  testthat::expect_error(iqt12r_epoch(root, "final_mcmc", list(original_bridge_epoch = old)), "Missing")
})

testthat::test_that("health verifies PID identity rather than trusting RUNNING", {
  testthat::expect_false(iqt12r_process_matches(1, "run", function(p) "run"))
  testthat::expect_false(iqt12r_process_matches(20, "run", function(p) "another process"))
  testthat::expect_true(iqt12r_process_matches(20, "/tmp/run", function(p) "/tmp/run/scheduler"))
  root <- tempfile(); dir.create(file.path(root, "plans"), recursive = TRUE)
  control <- file.path(root, "recovery/test"); dir.create(control, recursive = TRUE)
  iqt12_csv(data.frame(id = "a", status_path = file.path(root, "a.json")), file.path(root, "plans/bridge.csv"))
  iqt12_json(list(run = root, scientific_HEAD = "science", driver_HEAD = "driver"), file.path(control, "context.json"))
  writeLines("1234", file.path(control, "scheduler.pid"))
  writeLines(as.character(as.numeric(Sys.time())), file.path(control, "heartbeat.epoch"))
  writeLines("RUNNING", file.path(root, "scheduler.status"))
  h <- iqt12r_health(control, function(...) FALSE)
  testthat::expect_equal(h$effective_status, "SCHEDULER_STOPPED_WITH_PENDING_JOBS")
  testthat::expect_false(h$scheduler_alive)
  testthat::expect_equal(h$pending, 1L)
  h <- iqt12r_health(control, function(...) TRUE)
  testthat::expect_equal(h$effective_status, "SCHEDULER_LIVE")
  iqt12_json(list(status = "RUNNING", pid = 12345), file.path(root, "a.json"))
  h <- iqt12r_health(control, function(...) FALSE)
  testthat::expect_equal(h$stale_RUNNING_workers, 1L)
  h <- iqt12r_health(control, function(pid, token) pid == 12345)
  testthat::expect_equal(h$effective_status, "SCHEDULER_DEAD_WORKERS_DRAINING")
})

testthat::test_that("exit receipts are immutable and carry conservative costs", {
  root <- tempfile(); dir.create(root)
  control <- file.path(root, "recovery/test")
  iqt12_json(list(run = root, science_repo = "science"), file.path(control, "context.json"))
  cfg <- file.path(root, "config.json"); status <- file.path(root, "status.json")
  iqt12_json(list(id = "a", run = root, repo = "science", status_path = status), cfg)
  iqt12_json(list(status = "SUCCESS", elapsed = 3, cpu_seconds = 4), status)
  testthat::expect_equal(iqt12r_account(control, cfg, 0L, 5, 1), 5)
  testthat::expect_error(iqt12r_account(control, cfg, 0L, 5, 1))
  testthat::expect_equal(iqt12_read(file.path(control, "scheduler_exits/a.json"))$worker_status, "SUCCESS")
})

iqt12r_shell_fixture <- function(mode) {
  root <- tempfile(); dir.create(root)
  science <- file.path(root, "science"); dir.create(science)
  run <- file.path(root, "run"); dir.create(run)
  control <- file.path(run, "recovery/test"); dir.create(control, recursive = TRUE)
  writeLines(mode, file.path(control, "mode"))
  writeLines("synthetic", file.path(control, "config.json"))
  script <- file.path(root, "fake_Rscript.sh")
  writeLines(c("#!/usr/bin/env bash", "set -euo pipefail", "action=$2; control=${IQT12R_FIXTURE_CONTROL:?}",
    "mode=$(<\"$control/mode\")",
    "case $action in",
    "context) if [[ $mode == budget ]]; then printf '1440000\\t1440000\\t15\\n'; else printf '0\\t1440000\\t15\\n'; fi;;",
    "resources) taskset -pc $$ | awk -F ': ' '{split($2,a,\",|-\"); print a[1]}';;",
    "stage) if [[ $mode == deadline ]]; then printf '%s\\n' \"$(( $(date +%s) - 172801 ))\"; else date +%s; fi;;",
    "pending) printf 'fresh_job\\t%s/config.json\\t30\\n' \"$control\";;",
    "telemetry) if [[ $mode == drain && -f $control/started ]]; then exit 1; fi; printf '100\\t70000000\\n';;",
    "worker) touch \"$control/started\"; if [[ $mode == signal ]]; then sleep 1; kill -TERM \"$(<\"$control/scheduler.pid\")\"; sleep 1; elif [[ $mode == drain ]]; then sleep 7; else sleep 1; fi; touch \"$control/finished\";;",
    "exit) [[ -f $control/finished ]];;",
    "account) touch \"$control/accounted\"; printf '8\\n';;",
    "advance) touch \"$control/advanced\" \"$(dirname \"$(dirname \"$control\")\")/early_complete.json\";;",
    "*) exit 90;;", "esac"), script)
  Sys.chmod(script, "0755")
  list(root = root, science = science, run = run, control = control, script = script)
}

testthat::test_that("real shell driver drains own jobs on telemetry failure and preserves outcomes", {
  f <- iqt12r_shell_fixture("drain")
  driver <- file.path(repo, "validation/fitforecast_v2/scripts/run_independent_qdesn_training1000_recovery_v1.sh")
  old <- Sys.getenv("RSCRIPT", unset = NA_character_)
  Sys.setenv(RSCRIPT = f$script, IQT12R_FIXTURE_CONTROL = f$control)
  on.exit({if (is.na(old)) Sys.unsetenv("RSCRIPT") else Sys.setenv(RSCRIPT = old); Sys.unsetenv("IQT12R_FIXTURE_CONTROL")})
  code <- suppressWarnings(system2("bash", c(driver, repo, f$science, f$run, f$control),
    stdout = file.path(f$root, "out"), stderr = file.path(f$root, "err")))
  testthat::expect_equal(code, 1L)
  testthat::expect_true(file.exists(file.path(f$control, "finished")))
  testthat::expect_true(file.exists(file.path(f$control, "accounted")))
  testthat::expect_false(file.exists(file.path(f$control, "advanced")))
  testthat::expect_match(readLines(file.path(f$run, "scheduler.status")), "PAUSED_REVIEW_REQUIRED")
})

testthat::test_that("real shell driver closes successfully and never advances an expired stage", {
  driver <- file.path(repo, "validation/fitforecast_v2/scripts/run_independent_qdesn_training1000_recovery_v1.sh")
  old <- Sys.getenv("RSCRIPT", unset = NA_character_)
  on.exit({if (is.na(old)) Sys.unsetenv("RSCRIPT") else Sys.setenv(RSCRIPT = old); Sys.unsetenv("IQT12R_FIXTURE_CONTROL")})
  for (mode in c("complete", "deadline", "budget")) {
    f <- iqt12r_shell_fixture(mode); Sys.setenv(RSCRIPT = f$script, IQT12R_FIXTURE_CONTROL = f$control)
    code <- suppressWarnings(system2("bash", c(driver, repo, f$science, f$run, f$control),
      stdout = file.path(f$root, "out"), stderr = file.path(f$root, "err")))
    testthat::expect_equal(code, if (mode == "complete") 0L else 1L)
    testthat::expect_equal(file.exists(file.path(f$control, "started")), mode == "complete")
    testthat::expect_equal(file.exists(file.path(f$control, "advanced")), mode == "complete")
    testthat::expect_match(readLines(file.path(f$run, "scheduler.status")),
      if (mode == "complete") "COMPLETE_REVIEW_REQUIRED" else if (mode == "deadline")
        "48h_original_stage_deadline" else "worker_hour_budget")
  }
})

testthat::test_that("TERM failure records a paused state after draining only fixture workers", {
  f <- iqt12r_shell_fixture("signal")
  driver <- file.path(repo, "validation/fitforecast_v2/scripts/run_independent_qdesn_training1000_recovery_v1.sh")
  old <- Sys.getenv("RSCRIPT", unset = NA_character_)
  Sys.setenv(RSCRIPT = f$script, IQT12R_FIXTURE_CONTROL = f$control)
  on.exit({if (is.na(old)) Sys.unsetenv("RSCRIPT") else Sys.setenv(RSCRIPT = old); Sys.unsetenv("IQT12R_FIXTURE_CONTROL")})
  code <- suppressWarnings(system2("bash", c(driver, repo, f$science, f$run, f$control),
    stdout = file.path(f$root, "out"), stderr = file.path(f$root, "err")))
  testthat::expect_equal(code, 1L)
  testthat::expect_true(file.exists(file.path(f$control, "finished")))
  testthat::expect_true(file.exists(file.path(f$control, "accounted")))
  testthat::expect_match(readLines(file.path(f$run, "scheduler.status")), "driver_signal_TERM")
})

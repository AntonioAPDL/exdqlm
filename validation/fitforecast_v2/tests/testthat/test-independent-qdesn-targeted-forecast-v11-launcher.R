iqtf_launcher_fixture <- function(mode = "success") {
  root <- tempfile("v11-launcher-"); dir.create(root)
  repo <- file.path(root, "repo"); run <- file.path(root, "run")
  scripts <- file.path(repo, "validation/fitforecast_v2/scripts")
  dir.create(scripts, recursive = TRUE); dir.create(run)
  for (name in c("independent_qdesn_targeted_forecast_v11.R",
    "resource_independent_qdesn_mcmc_bridge_v9.R")) writeLines("# mock", file.path(scripts, name))
  wrapper <- file.path(root, "mock-rscript")
  writeLines(c("#!/usr/bin/env bash", "set -euo pipefail",
    "if [[ $2 == *resource_independent_qdesn_mcmc_bridge_v9.R ]]; then exit 0; fi",
    "case $4 in",
    "dispatch)",
    " if [[ $MOCK_MODE == bad_plan ]]; then exit 53; fi",
    " if [[ $6 == cost ]]; then",
    "  for i in $(seq 1 8); do printf 'job%02d\\tjob%02d\\n' \"$i\" \"$i\"; done",
    " fi",
    " ;;",
    "worker)",
    " mkdir -p \"$RUN_ROOT/started\" \"$RUN_ROOT/finished\"",
    " printf '%s\\n' \"$BASHPID\" > \"$RUN_ROOT/started/$5\"",
    " if [[ $MOCK_MODE == worker_fail && $5 == job01 ]]; then exit 17; fi",
    " sleep .4",
    " printf 'done\\n' > \"$RUN_ROOT/finished/$5\"",
    " ;;",
    "advance)",
    " if [[ $MOCK_MODE == gate_fail ]]; then exit 39; fi",
    " printf '%s\\n' \"$6\" >> \"$RUN_ROOT/advanced\"",
    " ;;",
    "closeout)",
    " if [[ $MOCK_MODE == closeout_fail ]]; then exit 32; fi",
    " printf '{}\\n' > \"$RUN_ROOT/closeout.json\"",
    " ;;",
    "*) exit 54 ;;", "esac"), wrapper)
  Sys.chmod(wrapper, "0755")
  list(root = root, run = run, env = c(REPO_ROOT = repo, RUN_ROOT = run,
    RSCRIPT = wrapper, CPU_LIST = Sys.getenv("IQFP_TEST_CPU_LIST", "25,26,27,28,29,30"),
    MOCK_MODE = mode))
}
iqtf_launcher_start <- function(f) processx::process$new("bash",
  file.path(harness_root, "scripts/run_independent_qdesn_targeted_forecast_v11.sh"),
  env = f$env, stdout = file.path(f$root, "out"), stderr = file.path(f$root, "err"))
iqtf_launcher_wait <- function(p) {
  p$wait(30000)
  if (p$is_alive()) { p$signal(15); p$wait(10000); stop("Mock scheduler exceeded test budget.") }
  p$get_exit_status()
}
iqtf_launcher_state <- function(f) {
  p <- file.path(f$run, "pipeline.status")
  if (!file.exists(p)) return("")
  sub("^status=", "", grep("^status=", readLines(p), value = TRUE))
}

test_that("real Bash handles multiple waves and conditional empty stages", {
  f <- iqtf_launcher_fixture(); p <- iqtf_launcher_start(f)
  expect_equal(iqtf_launcher_wait(p), 0)
  expect_identical(iqtf_launcher_state(f), "COMPLETE")
  x <- read.csv(file.path(f$run, "launcher_exit_codes.csv"))
  expect_equal(nrow(x), 8); expect_true(all(x$exit_code == 0))
  expect_length(unique(x$cpu), 6)
  expect_identical(readLines(file.path(f$run, "advanced")), iqtf_v11_stages)
  old <- readLines(file.path(f$run, "pipeline.status"))
  expect_equal(iqtf_launcher_wait(iqtf_launcher_start(f)), 74)
  expect_identical(readLines(file.path(f$run, "pipeline.status")), old)
})

test_that("worker failure drains active peers and schedules no replacements", {
  f <- iqtf_launcher_fixture("worker_fail"); p <- iqtf_launcher_start(f)
  expect_equal(iqtf_launcher_wait(p), 1)
  expect_identical(iqtf_launcher_state(f), "FAILED_WORKER")
  x <- read.csv(file.path(f$run, "launcher_exit_codes.csv"))
  expect_equal(nrow(x), 6); expect_equal(sum(x$exit_code != 0), 1)
  expect_length(list.files(file.path(f$run, "finished")), 5)
  expect_false(file.exists(file.path(f$run, "advanced")))
})

test_that("plan gate and closeout failures cannot be marked complete", {
  for (mode in c("bad_plan", "gate_fail", "closeout_fail")) {
    f <- iqtf_launcher_fixture(mode); p <- iqtf_launcher_start(f)
    expect_true(iqtf_launcher_wait(p) != 0, info = mode)
    expect_identical(iqtf_launcher_state(f), switch(mode,
      bad_plan = "FAILED_MANIFEST_OR_PLAN", gate_fail = "FAILED_STAGE_GATE",
      closeout_fail = "FAILED_CLOSEOUT"))
  }
})

test_that("a duplicate launcher cannot corrupt the owning attempt", {
  f <- iqtf_launcher_fixture(); p <- iqtf_launcher_start(f)
  deadline <- Sys.time() + 10
  while (iqtf_launcher_state(f) != "RUNNING" && p$is_alive() && Sys.time() < deadline) Sys.sleep(.02)
  expect_equal(iqtf_launcher_wait(iqtf_launcher_start(f)), 73)
  expect_equal(iqtf_launcher_wait(p), 0)
})

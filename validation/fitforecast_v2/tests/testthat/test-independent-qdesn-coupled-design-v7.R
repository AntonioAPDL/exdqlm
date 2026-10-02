iqdr_test_load <- function() {
  source(file.path(harness_root, "R/independent_qdesn_coupled_design_v7.R"), local = FALSE)
  iqdr_v7_source(repo_root)
}

iqdr_test_fixture <- function() {
  reference <- setNames(rep(list(1), length(iqbs_v5_science_fields)), iqbs_v5_science_fields)
  reference$candidate <- list(family = "normal", rhs_tau0 = .003, rhs_tau0_source_scale = .06,
    candidate_id = "original", candidate_signature = "fixture", D = 1L, n = "400", m = 120L)
  reference$probability <- .05; reference$likelihood_family <- "al"
  reference$source <- list(frozen_sha256 = "same_data")
  reference$budget <- list(max_iter = 750L, tol = 1e-4, n_samp_xi = 400L)
  reference$outer_draws <- 16L; reference$inner_path_grid <- 128L
  reference$origins <- list(start = 8750L, end = 8970L, stride = 5L)
  cfg <- reference
  cfg$stage <- "design_replay"; cfg$beta_covariance_approximation <- "full"
  cfg$allowed_model_tau0 <- .1; cfg$response_scale_frozen <- 20
  cfg$candidate$rhs_tau0 <- .1; cfg$candidate$rhs_tau0_source_scale <- 2
  cfg$candidate$tau0_multiplier <- .1 / .003
  list(original = reference, reference = reference, cfg = cfg)
}

test_that("v7 freezes case protocol and permits only declared prior changes", {
  iqdr_test_load(); f <- iqdr_test_fixture()
  expect_true(iqdr_v7_science_check(f$original, f$reference, f$cfg))
  for (field in c("seed", "horizon", "fit_end", "rhs_s2")) {
    changed <- f$cfg; changed[[field]] <- 2
    expect_false(iqdr_v7_science_check(f$original, f$reference, changed))
  }
  changed <- f$cfg; changed$candidate$m <- 121L
  expect_false(iqdr_v7_science_check(f$original, f$reference, changed))
  changed <- f$cfg; changed$candidate$rhs_tau0 <- .01
  expect_false(iqdr_v7_science_check(f$original, f$reference, changed))
  changed <- f$cfg; changed$candidate$rhs_tau0_source_scale <- .1
  expect_false(iqdr_v7_science_check(f$original, f$reference, changed))
  changed <- f$cfg; changed$beta_covariance_approximation <- "diagonal"
  expect_false(iqdr_v7_science_check(f$original, f$reference, changed))
  different <- f$original; different$source$frozen_sha256 <- "different"
  expect_false(iqdr_v7_science_check(different, f$reference, f$cfg))
})

test_that("engineering jobs have a separate fixed budget and never become ranking rows", {
  iqdr_test_load(); f <- iqdr_test_fixture()
  cfg <- iqdr_v7_expected_contract(f$cfg, "engineering_cost_smoke")
  cfg$stage <- "engineering_cost_smoke"
  expect_true(iqdr_v7_science_check(f$original, f$reference, cfg))
  expect_equal(cfg$outer_draws, 4L)
  expect_equal(cfg$inner_path_grid, 32L)
  expect_equal(cfg$budget$max_iter, 8L)
  expect_error(iqdr_v7_expected_contract(f$reference, "other"))
  text <- paste(deparse(iqdr_v7_audit), collapse = "\n")
  expect_match(text, 'stage == "design_replay"', fixed = TRUE)
})

test_that("cost projection scales weighted fitting and full recursive forecasts", {
  iqdr_test_load()
  timing <- list(iterations = 8L, quantile_seconds = 8, forecast_and_artifact_seconds = 1)
  expect_equal(iqdr_v7_project_cost(timing), 1110)
  bad <- timing; bad$iterations <- 7L
  expect_error(iqdr_v7_project_cost(bad))
  bad <- timing; bad$forecast_and_artifact_seconds <- Inf
  expect_error(iqdr_v7_project_cost(bad))
})

test_that("health uses job identities for dynamic scheduling exits", {
  iqdr_test_load()
  root <- tempfile("v7_health_"); dir.create(root)
  p <- data.frame(job_id = c("first", "second"), stage = "design_replay", case_id = "normal_al_p005",
    tau0 = .1, columns = 21L, config_path = file.path(root, c("a.json", "b.json")),
    status_path = file.path(root, c("sa.json", "sb.json")))
  iqfr_v2_write_csv(p, file.path(root, "plan.csv"))
  iqfr_v2_write_csv(data.frame(stage = "design_replay", job_id = "second", pid = 111L,
    cpu = 49L, exit_code = 124L), file.path(root, "launcher_exit_codes.csv"))
  h <- iqdr_v7_health(root)
  expect_equal(h$status, c("PENDING", "FAILED_EXIT_124"))
})

test_that("the bounded launcher gates production and releases individual CPU slots", {
  iqdr_test_load()
  shell <- paste(readLines(file.path(harness_root, "scripts/run_independent_qdesn_coupled_design_v7.sh")), collapse = "\n")
  expect_lt(regexpr("cost-gate", shell, fixed = TRUE)[1], regexpr("run_stage design_replay", shell, fixed = TRUE)[1])
  expect_match(shell, "run_stage engineering_cost_smoke 2 2 1800", fixed = TRUE)
  expect_match(shell, "run_stage design_replay 12 6 21600", fixed = TRUE)
  expect_match(shell, 'wait "$finished"', fixed = TRUE)
  expect_false(grepl("wait -n|wait -p", shell))
  expect_match(shell, "OMP_NUM_THREADS=1", fixed = TRUE)
  expect_match(shell, "flock -n 9", fixed = TRUE)
  expect_false(grepl("git push|pkill|killall|rm -rf", shell))
  expect_equal(length(iqdr_v7_design_ids), 6L)
  expect_equal(anyDuplicated(iqdr_v7_design_ids), 0L)
})

test_that("the launcher runs cleanly on host Bash and holds after failures", {
  iqdr_test_load()
  cpus <- strsplit(sub(".*:[[:space:]]*", "", grep("^Cpus_allowed_list:",
    readLines("/proc/self/status"), value = TRUE)), ",")[[1L]]
  cpus <- unlist(lapply(cpus, function(s) {
    bounds <- as.integer(strsplit(s, "-", fixed = TRUE)[[1L]])
    if (length(bounds) == 1L) bounds else seq.int(bounds[1], bounds[2])
  }))
  expect_gte(length(cpus), 6L)
  cpu_list <- paste(head(cpus, 6L), collapse = ",")
  launcher <- file.path(harness_root, "scripts/run_independent_qdesn_coupled_design_v7.sh")
  for (scenario in c("success", "cost_failure", "worker_failure")) {
    root <- tempfile(paste0("v7_launcher_", scenario, "_")); dir.create(root)
    p <- data.frame(job_id = c("cost1", "cost2", paste0("job", 1:12)),
      stage = c(rep("engineering_cost_smoke", 2), rep("design_replay", 12)),
      config_path = file.path(root, c("cost1", "cost2", paste0("job", 1:12))))
    write.csv(p, file.path(root, "plan.csv"), row.names = FALSE)
    mock <- file.path(root, "mock_Rscript")
    real <- file.path(R.home("bin"), "Rscript")
    writeLines(c("#!/usr/bin/env bash", "set -eu",
      paste0('if [[ $2 == "-e" ]]; then exec ', shQuote(real), ' "$@"; fi'),
      'case $4 in',
      'worker)',
      '  id=$(basename "$5")',
      '  printf "%s\\n" "$$" > "$RUN_ROOT/$id.started"',
      '  if [[ $SCENARIO == worker_failure && $id == job1 ]]; then exit 42; fi',
      '  if [[ $id == job* ]]; then sleep 0.5; else sleep 0.05; fi',
      '  touch "$RUN_ROOT/$id.finished" ;;',
      'cost-gate)',
      '  touch "$RUN_ROOT/gate.checked"',
      '  if [[ $SCENARIO == cost_failure ]]; then exit 43; fi ;;',
      'audit) touch "$RUN_ROOT/audit.finished" ;;',
      '*) exit 99 ;;', 'esac'), mock)
    Sys.chmod(mock, "0755")
    output <- file.path(root, "launch.log")
    status <- suppressWarnings(system2("bash", shQuote(launcher), stdout = output, stderr = output,
      env = c(paste0("REPO_ROOT=", shQuote(repo_root)), paste0("RUN_ROOT=", shQuote(root)),
        paste0("RSCRIPT=", shQuote(mock)), paste0("CPU_LIST=", cpu_list), paste0("SCENARIO=", scenario))))
    exits <- read.csv(file.path(root, "launcher_exit_codes.csv"))
    state <- readLines(file.path(root, "pipeline.status"))
    expect_true(file.exists(file.path(root, "final_artifact_manifest.csv")))
    expect_true(file.exists(file.path(root, "gate.checked")))
    if (scenario == "success") {
      expect_equal(status, 0L)
      expect_equal(nrow(exits), 14L)
      expect_true(all(exits$exit_code == 0L))
      expect_equal(length(unique(exits$cpu[exits$stage == "design_replay"])), 6L)
      expect_true(file.exists(file.path(root, "audit.finished")))
      expect_match(state[1], "status=COMPLETE", fixed = TRUE)
    } else {
      expect_gt(status, 0L)
      expect_false(file.exists(file.path(root, "audit.finished")))
      expect_match(state[1], "FAILED_OR_INTERRUPTED", fixed = TRUE)
      if (scenario == "cost_failure") expect_equal(nrow(exits), 2L)
      if (scenario == "worker_failure") {
        expect_lte(sum(exits$stage == "design_replay"), 6L)
        expect_true(any(exits$exit_code == 42L))
        good <- exits$job_id[exits$exit_code == 0L]
        expect_true(all(file.exists(file.path(root, paste0(good, ".finished")))))
      }
    }
  }
})

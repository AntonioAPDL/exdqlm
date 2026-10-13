iqps_test_load <- function() {
  source(file.path(harness_root, "R/independent_qdesn_paired_forecast_v8.R"), local = FALSE)
  iqps_v8_source(repo_root)
}

iqps_test_fixture <- function() {
  reference <- setNames(rep(list(1L), length(iqbs_v5_science_fields)), iqbs_v5_science_fields)
  reference$candidate <- list(family = "normal", D = 4L, n = "20;20;20;20", m = 120L,
    rhs_tau0 = 1, alpha = .74, rho = .76)
  reference$probability <- .05; reference$likelihood_family <- "al"
  reference$budget <- list(max_iter = 750L, tol = 1e-4, n_samp_xi = 400L)
  reference$origins <- list(start = 8750L, end = 8970L, stride = 5L)
  reference$outer_draws <- 16L; reference$inner_path_grid <- 128L
  reference$seed <- 1000L; reference$beta_covariance_approximation <- "full"
  reference$case_id <- iqdr_v7_case(reference)
  reference$collect_solver_diagnostics <- TRUE
  reference$baseline_config_path <- "original"; reference$baseline_config_sha256 <- "original_sha"
  reference$frozen_initializer_sha256 <- "init_sha"
  cfg <- iqps_v8_expected(reference, "paired_confirmation", 101003L)
  cfg$stage <- "paired_confirmation"; cfg$pair_role <- "challenger"; cfg$seed_index <- 2L
  list(reference = reference, cfg = cfg)
}

test_that("v8 changes only declared Monte Carlo budgets and forecast seed", {
  iqps_test_load(); f <- iqps_test_fixture()
  expect_true(iqps_v8_science_check(f$reference, f$cfg))
  for (field in c("rhs_s2", "fit_end", "rollout_end", "horizon", "inner_path_grid")) {
    changed <- f$cfg; changed[[field]] <- 3L
    expect_false(iqps_v8_science_check(f$reference, changed))
  }
  for (field in c("m", "alpha", "rho", "rhs_tau0")) {
    changed <- f$cfg; changed$candidate[[field]] <- 3L
    expect_false(iqps_v8_science_check(f$reference, changed))
  }
  changed <- f$cfg; changed$beta_covariance_approximation <- "diagonal"
  expect_false(iqps_v8_science_check(f$reference, changed))
  changed <- f$cfg; changed$budget$max_iter <- 751L
  expect_false(iqps_v8_science_check(f$reference, changed))
  changed <- f$cfg; changed$frozen_initializer_sha256 <- "new"
  expect_false(iqps_v8_science_check(f$reference, changed))
  changed <- f$cfg; changed$case_id <- "wrong_case"
  expect_false(iqps_v8_science_check(f$reference, changed))
  expect_error(iqps_v8_expected(f$reference, "unknown", 1L))
})

test_that("replays and cost tests have explicit separately validated contracts", {
  iqps_test_load(); f <- iqps_test_fixture()
  for (stage in c("same_seed_replay", "cost_smoke")) {
    cfg <- iqps_v8_expected(f$reference, stage, f$reference$seed)
    cfg$stage <- stage; cfg$pair_role <- "control"; cfg$seed_index <- 1L
    expect_true(iqps_v8_science_check(f$reference, cfg))
    changed <- cfg; changed$seed <- 2L
    expect_false(iqps_v8_science_check(f$reference, changed))
    roundtrip <- function(x) jsonlite::fromJSON(jsonlite::toJSON(x,
      auto_unbox = TRUE, digits = NA, null = "null"), simplifyVector = TRUE)
    expect_true(iqps_v8_science_check(roundtrip(f$reference), roundtrip(cfg)))
  }
  cost <- iqps_v8_expected(f$reference, "cost_smoke", 1000L)
  expect_equal(cost$budget, f$reference$budget)
  expect_equal(cost$origins$end, 8755L)
  expect_equal(cost$outer_draws, 4L)
  expect_equal(cost$inner_path_grid, 32L)
  expect_equal(iqps_v8_project_cost(list(quantile_seconds = 8,
    forecast_and_artifact_seconds = 2)), 2888)
  expect_error(iqps_v8_project_cost(list(quantile_seconds = 8,
    forecast_and_artifact_seconds = Inf)))
})

test_that("reproduction tolerance is not a metric promotion threshold", {
  iqps_test_load()
  x <- data.frame(estimator = c("a", "b"), inner_paths = 128L,
    forecast_qtrue_mae = c(1,2), forecast_qtrue_rmse = c(2,3), forecast_check_loss = c(.1,.2),
    fit_qtrue_rmse_mean = 1, fit_qtrue_mae_mean = 1, fit_check_loss_mean = 1)
  y <- x[2:1, ]; y$forecast_qtrue_mae <- y$forecast_qtrue_mae + 5e-7
  expect_true(all(iqps_v8_compare_scores(x,y)$pass))
  y$forecast_qtrue_mae <- y$forecast_qtrue_mae + 2e-6
  expect_false(all(iqps_v8_compare_scores(x,y)$pass))
  expect_error(iqps_v8_compare_scores(x,y[1, ]))
  expect_error(iqps_v8_compare_scores(x,y[setdiff(names(y),"forecast_qtrue_mae")]))
  expect_error(iqps_v8_compare_scores(x[FALSE, ],y[FALSE, ]))
  z <- data.frame(case_id = "normal_al_p005", seed_index = rep(1:3,each=2),
    seed = rep(1:3,each=2), pair_role = rep(c("challenger","control"),3),
    job_id = paste0("job",1:6), vb_converged = FALSE,
    forecast_mae = rep(c(1-1e-9,1),3), forecast_rmse = 2,
    conditional_check_loss = 3, pooled_predictive_check_loss = 4, fit_point_rmse = 5)
  ledger <- iqps_v8_paired_ledger(z)
  expect_equal(nrow(ledger),15L)
  expect_equal(sum(ledger$strict_gain),3L)
  expect_true(all(ledger$gain[ledger$strict_gain] < 1e-6))
  bad <- z; bad$seed[1] <- 4L
  expect_error(iqps_v8_paired_ledger(bad))
})

test_that("granular gains align origins and leads without silently dropping pairs", {
  iqps_test_load()
  x <- data.frame(case_id = "case", seed_index = 1L, seed = 99L,
    pair_role = rep(c("challenger","control"),each=2), lead = rep(1:2,2),
    absolute_oracle_error = c(1,4,2,3), check_loss = c(.1,.3,.2,.2))
  p <- iqps_v8_granular_pairs(x,"lead")
  expect_equal(p$mae_gain,c(1,-1))
  expect_equal(p$conditional_check_gain,c(.1,-.1))
  bad <- x; bad$lead[4] <- 3L
  expect_error(iqps_v8_granular_pairs(bad,"lead"))
})

test_that("resume requires hash-valid successful post-fit contract checks", {
  iqps_test_load()
  root <- tempfile("v8_status_"); dir.create(root)
  cfg <- list(config_path = file.path(root,"config.json"), status_path = file.path(root,"status.json"),
    stage = "paired_confirmation")
  iqfr_v2_write_json(cfg,cfg$config_path)
  result <- iqfr_v2_write_csv(data.frame(score=1),file.path(root,"result.csv"))
  check <- iqfr_v2_write_csv(data.frame(pass=TRUE),file.path(root,"check.csv"))
  timing <- iqfr_v2_write_json(list(seconds=1),file.path(root,"timing.json"))
  save_status <- function(paths) iqfr_v2_write_json(list(status="SUCCESS",
    config_sha256=iqfr_v2_sha256(cfg$config_path), artifact_paths=as.list(paths),
    artifact_sha256=lapply(paths,iqfr_v2_sha256)),cfg$status_path)
  save_status(c(result=result))
  expect_false(iqps_v8_status_valid(cfg$config_path))
  paths <- c(result=result,fit_contract=check,worker_timing=timing)
  save_status(paths)
  expect_true(iqps_v8_status_valid(cfg$config_path))
  iqfr_v2_write_csv(data.frame(pass=FALSE),check)
  expect_false(iqps_v8_status_valid(cfg$config_path))
  save_status(paths)
  expect_false(iqps_v8_status_valid(cfg$config_path))
})

test_that("v8 never conflates conditional and pooled check losses or launches MCMC", {
  iqps_test_load()
  text <- paste(deparse(iqps_v8_audit),collapse="\n")
  expect_match(text,'stage == "paired_confirmation"',fixed=TRUE)
  expect_match(text,'conditional_check_loss',fixed=TRUE)
  expect_match(text,'pooled_predictive_check_loss',fixed=TRUE)
  expect_match(text,'automatic_MCMC = FALSE',fixed=TRUE)
  expect_match(text,'diagnostic_exclusion = FALSE',fixed=TRUE)
  expect_false(grepl('vb_converged == TRUE|minimum_gain_threshold = 1e',text))
})

test_that("v8 launcher gates, drains failures and runs under host Bash", {
  iqps_test_load()
  cpus <- strsplit(sub(".*:[[:space:]]*","",grep("^Cpus_allowed_list:",
    readLines("/proc/self/status"),value=TRUE)),",")[[1]]
  cpus <- unlist(lapply(cpus,function(s) { b<-as.integer(strsplit(s,"-",fixed=TRUE)[[1]]);
    if(length(b)==1) b else seq.int(b[1],b[2]) }))
  cpu_list <- paste(head(cpus,6L),collapse=",")
  launcher <- file.path(harness_root,"scripts/run_independent_qdesn_paired_forecast_v8.sh")
  for (scenario in c("success","cost_failure","replay_failure","worker_failure")) {
    root <- tempfile(paste0("v8_",scenario,"_")); dir.create(root)
    ids <- c(paste0("cost",1:4),paste0("replay",1:4),paste0("job",1:12))
    p <- data.frame(job_id=ids,stage=c(rep("cost_smoke",4),rep("same_seed_replay",4),
      rep("paired_confirmation",12)),config_path=file.path(root,ids))
    write.csv(p,file.path(root,"plan.csv"),row.names=FALSE)
    mock <- file.path(root,"mock_Rscript")
    real <- file.path(R.home("bin"),"Rscript")
    writeLines(c("#!/usr/bin/env bash","set -eu",
      paste0('if [[ $2 == "-e" ]]; then exec ',shQuote(real),' "$@"; fi'),
      'case $4 in','worker)',
      'id=$(basename "$5")',
      'if [[ $SCENARIO == worker_failure && $id == job1 ]]; then exit 42; fi',
      'if [[ $id == job* ]]; then sleep 0.5; else sleep 0.05; fi',
      'touch "$RUN_ROOT/$id.finished" ;;',
      'cost_gate) if [[ $SCENARIO == cost_failure ]]; then exit 43; fi ;;',
      'replay_gate) if [[ $SCENARIO == replay_failure ]]; then exit 44; fi ;;',
      'audit) touch "$RUN_ROOT/audit.finished" ;;','*) exit 99 ;;','esac'),mock)
    Sys.chmod(mock,"0755")
    log <- file.path(root,"log")
    rc <- suppressWarnings(system2("bash",shQuote(launcher),stdout=log,stderr=log,
      env=c(paste0("REPO_ROOT=",shQuote(repo_root)),paste0("RUN_ROOT=",shQuote(root)),
        paste0("RSCRIPT=",shQuote(mock)),paste0("CPU_LIST=",cpu_list),paste0("SCENARIO=",scenario))))
    exits <- read.csv(file.path(root,"launcher_exit_codes.csv"))
    expect_true(file.exists(file.path(root,"final_artifact_manifest.csv")))
    if(scenario=="success") {
      expect_equal(rc,0L); expect_equal(nrow(exits),20L)
      expect_true(all(exits$exit_code==0L)); expect_true(file.exists(file.path(root,"audit.finished")))
    } else {
      expect_gt(rc,0L); expect_false(file.exists(file.path(root,"audit.finished")))
      if(scenario=="cost_failure") expect_equal(nrow(exits),4L)
      if(scenario=="replay_failure") expect_equal(nrow(exits),8L)
      if(scenario=="worker_failure") {
        expect_lte(sum(exits$stage=="paired_confirmation"),6L)
        expect_true(any(exits$exit_code==42L))
      }
    }
  }
})

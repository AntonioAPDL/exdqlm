iqmb_load <- function() {
  source(file.path(harness_root, "R/independent_qdesn_mcmc_bridge_v9.R"), local = FALSE)
  iqmb_v9_source(repo_root)
}

test_that("MCMC budgets and explicit starts cannot silently use diagonal warm fits", {
  iqmb_load()
  expect_equal(iqmb_v9_budget("pilot"), list(burn = 1000L, retained = 4000L, outer = 120L, inner = 128L))
  expect_equal(iqmb_v9_budget("confirmation")$retained, 20000L)
  expect_error(iqmb_v9_budget("other"))
  v <- list(qbeta = list(m = c(1,2)), qsiggam = list(sigma_mean = 2, gamma_mean = .1),
    qv = list(E_v = c(1,2)), qs = list(E_s = c(.1,.2)))
  init <- iqmb_v9_explicit_init(v, "exal")
  expect_equal(init$beta, c(1,2))
  expect_false(any(c("rhs_state", "beta_prior_state") %in% names(init)))
  expect_equal(iqmb_v9_explicit_init(v,"al")$gamma, 0)
  v$qv$E_v[1] <- -1
  expect_error(iqmb_v9_explicit_init(v,"exal"))
  cfg <- list(likelihood_family = "exal", candidate = list(rhs_tau0 = .01), rhs_s2 = 1,
    mcmc_burn = 5L, mcmc_retained = 10L, chain_seed = 99L)
  a <- iqmb_v9_mcmc_args(cfg, init)
  expect_false(a$init_from_vb)
  expect_identical(a$slice$core_update_mode, "m0_v_collapsed_support_logit")
  expect_equal(a$beta_rhs$tau0, .01)
  expect_false(a$beta_rhs$shrink_intercept)
  cfg$likelihood_family <- "al"
  expect_identical(iqmb_v9_mcmc_args(cfg, init)$slice$core_update_mode, "sigma_then_gamma")
})

test_that("scientific identities and priors remain fixed while budgets change", {
  iqmb_load()
  root <- tempfile(); dir.create(root)
  ref <- list(candidate = list(rhs_tau0 = 1, m = 240L), source = list(seed = 1L), probability = .25,
    likelihood_family = "exal", rhs_s2 = 1, fit_end = 8750L, rollout_end = 9000L, horizon = 30L,
    budget = list(max_iter = 750L), beta_covariance_approximation = "full",
    case_id = "normal_exal_p025", pair_role = "challenger",
    origins = list(start = 8750L, end = 8970L, stride = 5L))
  ref$config_path <- file.path(root,"ref.json"); iqfr_v2_write_json(ref,ref$config_path)
  for (stage in iqmb_v9_stages) {
    cfg <- iqmb_v9_config(ref, stage, 1L, repo_root, root)
    expect_true(iqmb_v9_science_check(ref,cfg))
    for (field in c("fit_end", "rhs_s2", "horizon", "mcmc_retained", "outer_draws")) {
      bad <- cfg; bad[[field]] <- 999L
      expect_false(iqmb_v9_science_check(ref,bad))
    }
    bad <- cfg; bad$candidate$m <- 30L
    expect_false(iqmb_v9_science_check(ref,bad))
    bad <- cfg; bad$beta_covariance_approximation <- "diagonal"
    expect_false(iqmb_v9_science_check(ref,bad))
  }
  a <- iqmb_v9_config(ref,"confirmation",1L,repo_root,root)
  b <- iqmb_v9_config(ref,"confirmation",2L,repo_root,root)
  expect_false(a$chain_seed == b$chain_seed)
  ref$pair_role <- "control"
  c <- iqmb_v9_config(ref,"confirmation",1L,repo_root,root)
  expect_equal(a$seed,c$seed)
})

test_that("finite tiny forecast gains qualify regardless of diagnostic grades", {
  iqmb_load()
  x <- data.frame(case_id = rep(c("a","b"),each=2), pair_role = rep(c("challenger","control"),2),
    forecast_mae = c(1-1e-9,1,2,1), conditional_check_loss = 3, pooled_predictive_check_loss = 4,
    diagnostic_grade = "FAIL", fit_point_rmse = c(1,2,1,2))
  cost <- data.frame(case_id = rep(c("a","b"),each=2), pass = TRUE)
  g <- iqmb_v9_select(x,cost)
  expect_equal(g$selected,c(TRUE,FALSE))
  expect_lt(g$mae_gain[1],1e-6)
  x$forecast_mae[1] <- 1; x$conditional_check_loss[1] <- 3-1e-9
  expect_true(iqmb_v9_select(x,cost)$selected[1])
  cost$pass[1] <- FALSE
  expect_false(iqmb_v9_select(x,cost)$selected[1])
  x$forecast_mae[1] <- NA_real_
  expect_error(iqmb_v9_select(x,cost))
  expect_error(iqmb_v9_select(x[-1,],cost))
})

test_that("measured cost projects inference and forecasting separately", {
  iqmb_load()
  t <- list(warm_seconds = 10, mcmc_seconds = 3, forecast_seconds = 2,
    burn = 100L, retained = 200L, origins = 2L, outer = 8L, inner = 32L)
  expect_equal(iqmb_v9_project(t,"pilot"), 2760)
  t$forecast_seconds <- Inf
  expect_error(iqmb_v9_project(t,"pilot"))
})

test_that("worker exports corrected scores, diagnostics and compact draw evidence", {
  iqmb_load()
  body <- paste(deparse(iqmb_v9_compute),collapse="\n")
  expect_match(body, "iqps_v8_fit_check",fixed=TRUE)
  expect_match(body, "iqcf_v3_nested_lattice",fixed=TRUE)
  expect_match(body, "mean_conditional_location",fixed=TRUE)
  expect_match(body, "forecast_location_draws",fixed=TRUE)
  expect_false(grepl("saveRDS|save\\(",body))
  launcher <- file.path(harness_root,"scripts/run_independent_qdesn_mcmc_bridge_v9.sh")
  expect_equal(system2("bash",c("-n",launcher)),0L)
  text <- paste(readLines(launcher),collapse="\n")
  expect_match(text, "run_stage confirmation 6 43200",fixed=TRUE)
  expect_match(text, "failed==0",fixed=TRUE)
  expect_match(text, "flock -n",fixed=TRUE)
})

test_that("v9 launcher actually gates, skips nonselected chains and drains failures", {
  iqmb_load()
  allowed <- sub(".*:[[:space:]]*","",grep("^Cpus_allowed_list:",readLines("/proc/self/status"),value=TRUE))
  cpus <- unlist(lapply(strsplit(allowed,",")[[1]],function(x) {
    b<-as.integer(strsplit(x,"-",fixed=TRUE)[[1]]); if(length(b)==1) b else seq.int(b[1],b[2]) }))
  launcher <- file.path(harness_root,"scripts/run_independent_qdesn_mcmc_bridge_v9.sh")
  for (scenario in c("success","none_selected","cost_failure","worker_failure")) {
    root<-tempfile();dir.create(root)
    ids<-c(paste0("cost",1:4),paste0("pilot",1:4),paste0("chain",1:12))
    p<-data.frame(job_id=ids,stage=c(rep("cost_smoke",4),rep("pilot",4),rep("confirmation",12)),
      case_id="case",config_path=file.path(root,ids))
    write.csv(p,file.path(root,"plan.csv"),row.names=FALSE)
    write.csv(data.frame(case_id="case",selected=scenario!="none_selected"),file.path(root,"confirmation_gate.csv"),row.names=FALSE)
    mock<-file.path(root,"Rscript");real<-file.path(R.home("bin"),"Rscript")
    writeLines(c("#!/usr/bin/env bash","set -eu",
      paste0('if [[ $2 == "-e" ]]; then exec ',shQuote(real),' "$@"; fi'),
      'if [[ $2 == *resource_independent_qdesn_mcmc_bridge_v9.R ]]; then exit 0; fi',
      'case $4 in', 'worker)', 'id=$(basename "$5")',
      'if [[ $SCENARIO == worker_failure && $id == pilot1 ]]; then exit 42; fi',
      'sleep 0.2 ;;', 'cost_gate) if [[ $SCENARIO == cost_failure ]]; then exit 43; fi ;;',
      'pilot_gate) : ;;', 'audit) touch "$RUN_ROOT/audit.finished" ;;', '*) exit 99 ;;', 'esac'),mock)
    Sys.chmod(mock,"0755")
    log<-file.path(root,"log")
    rc<-suppressWarnings(system2("bash",shQuote(launcher),stdout=log,stderr=log,
      env=c(paste0("REPO_ROOT=",shQuote(repo_root)),paste0("RUN_ROOT=",shQuote(root)),
        paste0("RSCRIPT=",shQuote(mock)),paste0("CPU_LIST=",paste(head(cpus,6),collapse=",")),paste0("SCENARIO=",scenario))))
    exits<-read.csv(file.path(root,"launcher_exit_codes.csv"))
    expect_true(file.exists(file.path(root,"final_artifact_manifest.csv")))
    if(scenario %in% c("success","none_selected")) {
      expect_equal(rc,0L);expect_equal(nrow(exits),if(scenario=="success")20L else 8L)
      expect_true(all(exits$exit_code==0));expect_true(file.exists(file.path(root,"audit.finished")))
    } else {
      expect_gt(rc,0L);expect_false(file.exists(file.path(root,"audit.finished")))
      if(scenario=="cost_failure")expect_equal(nrow(exits),4L)
      if(scenario=="worker_failure") {
        expect_lte(sum(exits$stage=="pilot"),4L)
        expect_true(any(exits$exit_code==42L));expect_equal(sum(exits$stage=="confirmation"),0L)
      }
    }
  }
})

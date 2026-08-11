repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                           winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_exal_m0_structural_screen_v2.R"))

testthat::test_that("target ledger is cell-specific and preserves the seven remaining gaps", {
  targets <- qdesn_ssv2_targets(repo_root)
  testthat::expect_equal(nrow(targets), 7L)
  testthat::expect_equal(sum(targets$priority == "primary_lower_quantile"), 5L)
  testthat::expect_equal(sum(targets$priority == "secondary_median"), 2L)
  testthat::expect_equal(sum(targets$designs_wave1), 96L)
  testthat::expect_equal(sum(targets$survivors_wave2), 48L)
  testthat::expect_equal(sum(targets$adaptive_wave3), 24L)
  testthat::expect_equal(sum(targets$finalists_sealed), 12L)
  testthat::expect_setequal(targets$target_cell_id, c(
    "normal_t0p05", "normal_t0p25", "normal_t0p50", "laplace_t0p05",
    "gausmix_t0p05", "gausmix_t0p25", "gausmix_t0p50"
  ))
  testthat::expect_true(all(file.exists(targets$parent_request_path)))
  testthat::expect_true(all(nzchar(targets$parent_request_sha256)))
})

testthat::test_that("virtual universe is deterministic, multiscale, and topology-active", {
  a <- qdesn_ssv2_virtual_universe(1000L, 991L)
  b <- qdesn_ssv2_virtual_universe(1000L, 991L)
  testthat::expect_identical(a, b)
  testthat::expect_equal(nrow(a), 1000L)
  testthat::expect_equal(anyDuplicated(a$profile_signature), 0L)
  testthat::expect_true(all(a$D %in% 1:4))
  testthat::expect_true(all(a$total_states >= 20L & a$total_states <= 600L))
  testthat::expect_true(all(a$m %in% c(1L, 5L, 15L, 30L, 45L, 60L, 90L, 120L, 150L)))
  testthat::expect_true(all(a$expected_degree %in% c(2L, 4L, 8L, 16L)))
  testthat::expect_true(all(a$max_alpha < 1 & a$min_alpha > 0))
  testthat::expect_true(all(a$max_rho < 1 & a$min_rho > 0))
  testthat::expect_true(any(a$max_alpha >= .99))
  testthat::expect_true(any(a$m == 150L))
  testthat::expect_true(any(a$D == 4L))
  testthat::expect_true(all(is.finite(a$effective_readout_dimension)))
})

testthat::test_that("effective readout dimension matches observed design-matrix construction", {
  testthat::expect_identical(
    qdesn_ssv2_effective_readout_dimension("300;300", "300", 3L, 6L),
    2412L
  )
  testthat::expect_identical(
    qdesn_ssv2_effective_readout_dimension(
      "202;168;132;98", "168;132;98", 0L, 12L
    ),
    514L
  )
  testthat::expect_identical(
    qdesn_ssv2_effective_readout_dimension("600", "", 0L, 2L),
    608L
  )
})

testthat::test_that("single-layer profiles survive empty JSON fields", {
  job <- list(
    candidate_id = "d1_candidate",
    target_cell_id = "normal_t0p05",
    profile = list(
      D = 1L, n = "12", n_tilde = NULL, m = 5L, alpha = "0.4", rho = "0.9",
      pi_w = "0.2", pi_in = "0.2", rhs_tau0 = 1e-6,
      readout_y_lags = 1L, reservoir_lags = 0L, washout = 300L
    )
  )
  profile <- qdesn_ssv2_profile_from_job(job)
  testthat::expect_equal(nrow(profile), 1L)
  testthat::expect_identical(profile$n_tilde, "")
  testthat::expect_identical(profile$candidate_id, "d1_candidate")
  testthat::expect_identical(profile$target_cell_id, "normal_t0p05")
  testthat::expect_identical(profile$effective_readout_dimension, 19L)
})

testthat::test_that("profile extraction removes selector-only adaptive metadata", {
  base <- as.list(setNames(rep(1, length(qdesn_ssv2_profile_fields)),
                           qdesn_ssv2_profile_fields))
  base$n <- "30"; base$n_tilde <- ""; base$alpha <- "0.5"; base$rho <- "0.9"
  base$D <- 1L; base$m <- 5L; base$readout_y_lags <- 1L
  base$reservoir_lags <- 0L; base$washout <- 300L
  base$virtual_id <- "selector_only"
  base$predicted_objective_ratio <- 0.75
  job <- list(candidate_id = "adaptive_candidate", target_cell_id = "normal_t0p25",
              profile = base)
  profile <- qdesn_ssv2_profile_from_job(job)
  testthat::expect_identical(names(profile), qdesn_ssv2_profile_fields)
  testthat::expect_false(any(c("virtual_id", "predicted_objective_ratio") %in% names(profile)))
})

testthat::test_that("latest stage supersedes repeated candidate-source evidence", {
  rows <- data.frame(
    stage = c("wave1", "wave1", "wave2", "wave2"),
    job_id = c("early_repeat", "early_unique", "late_repeat", "late_unique"),
    target_cell_id = "normal_t0p25",
    candidate_id = c("candidate_a", "candidate_b", "candidate_a", "candidate_a"),
    chain_id = 1L,
    source_id = c("dev09", "dev09", "dev09", "dev10"),
    objective_metric = "forecast_mae",
    objective_value = c(3.0, 2.0, 1.5, 1.0),
    stringsAsFactors = FALSE
  )
  resolved <- qdesn_ssv2_resolve_stage_repeats(rows, c("wave1", "wave2"))
  testthat::expect_equal(nrow(resolved$results), 3L)
  testthat::expect_equal(nrow(resolved$ledger), 1L)
  retained <- resolved$results[
    resolved$results$candidate_id == "candidate_a" &
      resolved$results$source_id == "dev09", , drop = FALSE
  ]
  testthat::expect_identical(retained$stage, "wave2")
  testthat::expect_identical(retained$objective_value, 1.5)
  testthat::expect_identical(resolved$ledger$superseded_job_id, "early_repeat")
  testthat::expect_identical(resolved$ledger$retained_job_id, "late_repeat")
  testthat::expect_identical(
    resolved$ledger$resolution, "latest_stage_supersedes_earlier_repeat"
  )
})

testthat::test_that("capacity repair changes only the eleven infeasible frozen designs", {
  stub <- file.path(repo_root, "config", "validation", qdesn_ssv2_stage)
  profiles <- qdesn_ssv2_read_csv(paste0(stub, "_wave1_profiles.csv"))
  ledger <- qdesn_ssv2_read_csv(paste0(stub, "_capacity_repair_ledger.csv"))
  manifest <- qdesn_ssv2_read_json(paste0(stub, "_capacity_repair_manifest.json"))
  testthat::expect_equal(nrow(profiles), 96L)
  testthat::expect_true(all(profiles$effective_readout_dimension <= 900L))
  testthat::expect_equal(sum(ledger$action == "retained_exact"), 85L)
  testthat::expect_equal(sum(ledger$action == "replaced_above_capacity_contract"), 11L)
  retained <- ledger$action == "retained_exact"
  testthat::expect_identical(
    ledger$predecessor_candidate_id[retained], ledger$repaired_candidate_id[retained]
  )
  testthat::expect_identical(as.integer(manifest$replaced_profiles), 11L)
  testthat::expect_identical(
    as.integer(manifest$maximum_effective_readout_dimension), 900L
  )
})

testthat::test_that("fixed-seed selector allocates local, broad, boundary, and transfer arms", {
  targets <- qdesn_ssv2_targets(repo_root)
  universe <- qdesn_ssv2_virtual_universe(1500L, qdesn_ssv2_virtual_seed)
  history <- data.frame(profile_signature = character(), stringsAsFactors = FALSE)
  plan <- qdesn_ssv2_select_wave1(repo_root, universe, history, targets)
  testthat::expect_equal(nrow(plan$selected), 96L)
  testthat::expect_equal(nrow(plan$parents), 7L)
  testthat::expect_equal(anyDuplicated(plan$selected$candidate_id), 0L)
  testthat::expect_true(all(
    plan$selected$effective_readout_dimension <=
      qdesn_ssv2_max_effective_readout_dimension
  ))
  primary <- plan$selected$priority == "primary_lower_quantile"
  primary_arms <- table(plan$selected$selection_arm[primary])
  secondary_arms <- table(plan$selected$selection_arm[!primary])
  testthat::expect_equal(names(primary_arms), c("boundary", "broad", "local", "transfer"))
  testthat::expect_equal(as.integer(primary_arms), c(10L, 40L, 20L, 10L))
  testthat::expect_equal(names(secondary_arms), c("boundary", "broad", "local", "transfer"))
  testthat::expect_equal(as.integer(secondary_arms), c(2L, 8L, 4L, 2L))
  testthat::expect_true(all(plan$parents$selection_arm == "parent"))
})

testthat::test_that("source and stage contracts freeze the intended budget", {
  cfg <- yaml::read_yaml(file.path(
    repo_root, "config", "validation",
    paste0(qdesn_ssv2_stage, "_sources.yaml")
  ))
  roles <- vapply(cfg$replicates, function(x) as.character(x$role), character(1L))
  testthat::expect_equal(cfg$generation$TT_warmup, 2000L)
  testthat::expect_equal(cfg$generation$TT_main, 10000L)
  testthat::expect_equal(cfg$generation$TT_total, 12000L)
  testthat::expect_equal(cfg$generation$taus, c(.05, .25, .50))
  testthat::expect_equal(sum(roles == "discovery"), 3L)
  testthat::expect_equal(sum(roles == "sealed_holdout"), 1L)
  testthat::expect_equal(sum(roles == "sealed_reserve"), 1L)
  testthat::expect_equal(cfg$selection_contract$maximum_exploratory_roots, 428L)
  testthat::expect_equal(cfg$selection_contract$maximum_effective_readout_dimension, 900L)
  testthat::expect_equal(cfg$selection_contract$calibration_timeout_seconds, 21600L)
  testthat::expect_equal(cfg$selection_contract$workers, 20L)
  testthat::expect_identical(qdesn_ssv2_budget("wave1")$n_burn, 1000L)
  testthat::expect_identical(qdesn_ssv2_budget("wave1")$n_mcmc, 3000L)
  testthat::expect_identical(qdesn_ssv2_budget("confirmation")$n_mcmc, 20000L)
  testthat::expect_identical(qdesn_ssv2_timeout_seconds("calibration"), 21600L)
})

testthat::test_that("staged windows preserve local and global source indices", {
  tmp <- tempfile("ssv2-source-window-")
  dir.create(tmp, recursive = TRUE)
  source_path <- file.path(tmp, "series_wide.csv")
  source_df <- data.frame(
    t = 1:10000,
    y = sin((1:10000) / 20),
    mu = cos((1:10000) / 25),
    q_target = cos((1:10000) / 25) - 1,
    eps = 0,
    stringsAsFactors = FALSE
  )
  qdesn_ssv2_write_csv(source_df, source_path)
  root_row <- data.frame(
    series_wide_path = source_path,
    source_role = "discovery",
    scenario = "index_contract_fixture",
    family = "normal",
    tau = 0.25,
    sim_output_path = file.path(tmp, "sim_output.rds"),
    sim_output_sha256 = "fixture",
    latent_seed = 101L,
    noise_seed = 102L,
    stringsAsFactors = FALSE
  )
  staged <- qdesn_ssv2_stage_source_window(
    root_row, "dev09", m = 5L, washout = 300L,
    output_root = file.path(tmp, "staged")
  )
  series <- qdesn_ssv2_read_csv(staged$source_series_wide_path)
  selection <- qdesn_ssv2_read_csv(staged$source_selection_indices_path)
  testthat::expect_identical(as.integer(series$t), seq_len(nrow(series)))
  testthat::expect_identical(as.integer(series$source_index),
                             as.integer(selection$source_index))
  testthat::expect_identical(min(as.integer(series$source_index)), 8196L)
  testthat::expect_identical(max(as.integer(series$source_index)), 10000L)
  testthat::expect_identical(staged$source_latent_seed, 101L)
  testthat::expect_identical(staged$source_noise_seed, 102L)
})

testthat::test_that("paired seed mode separates source, reservoir, and chain randomness", {
  tmp <- tempfile("ssv2-seed-contract-")
  dir.create(tmp, recursive = TRUE)
  source_path <- file.path(tmp, "series_wide.csv")
  qdesn_ssv2_write_csv(data.frame(
    t = 1:10000, y = 1:10000, mu = 1:10000,
    q_target = 1:10000, eps = 0
  ), source_path)
  root_row <- data.frame(
    series_wide_path = source_path, source_role = "discovery",
    scenario = "seed_contract_fixture", family = "normal", tau = 0.25,
    sim_output_path = file.path(tmp, "sim_output.rds"),
    sim_output_sha256 = "fixture", latent_seed = 201L, noise_seed = 202L,
    stringsAsFactors = FALSE
  )
  staged_a <- qdesn_ssv2_stage_source_window(
    root_row, "dev09", 5L, 300L, file.path(tmp, "staged")
  )
  staged_b <- staged_a
  staged_b$source_id <- "dev10"
  registry_path <- qdesn_ssv2_write_csv(
    rbind(staged_a, staged_b), file.path(tmp, "registry.csv")
  )
  targets <- qdesn_ssv2_targets(repo_root)
  target <- targets[targets$target_cell_id == "normal_t0p25", , drop = FALSE]
  profiles <- qdesn_ssv2_read_csv(file.path(
    repo_root, "config", "validation",
    paste0(qdesn_ssv2_stage, "_wave1_profiles.csv")
  ))
  profiles <- profiles[profiles$target_cell_id == "normal_t0p25", , drop = FALSE]
  profile_a <- profiles[1L, , drop = FALSE]
  profile_b <- profiles[2L, , drop = FALSE]
  a1 <- qdesn_ssv2_make_job(
    repo_root, profile_a, target, staged_a, "smoke", registry_path,
    chain_id = 1L, reservoir_seed_id = "r01"
  )
  a2 <- qdesn_ssv2_make_job(
    repo_root, profile_a, target, staged_b, "smoke", registry_path,
    chain_id = 2L, reservoir_seed_id = "r01"
  )
  b1 <- qdesn_ssv2_make_job(
    repo_root, profile_b, target, staged_a, "smoke", registry_path,
    chain_id = 1L, reservoir_seed_id = "r01"
  )
  r02 <- qdesn_ssv2_make_job(
    repo_root, profile_a, target, staged_a, "smoke", registry_path,
    chain_id = 1L, reservoir_seed_id = "r02"
  )
  testthat::expect_identical(a1$config$desn$seed, a2$config$desn$seed)
  testthat::expect_identical(a1$config$desn$seed, b1$config$desn$seed)
  testthat::expect_false(identical(a1$config$desn$seed, r02$config$desn$seed))
  testthat::expect_false(identical(
    a1$config$inference$mcmc$control$seed,
    a2$config$inference$mcmc$control$seed
  ))
  testthat::expect_identical(
    a1$seed_contract_mode,
    "paired_target_cell_panel_independent_of_source_and_candidate"
  )
  testthat::expect_match(a1$job_id, "__r01__c01$", perl = TRUE)
})

testthat::test_that("rolling artifact audit enforces the complete lead-grid contract", {
  tmp <- tempfile("ssv2-rolling-audit-")
  dir.create(file.path(tmp, "tables"), recursive = TRUE)
  dir.create(file.path(tmp, "manifest"), recursive = TRUE)
  target <- 9001:10000
  origin <- 9000L + 30L * ((target - 9001L) %/% 30L)
  lead <- target - origin
  rolling <- data.frame(
    forecast_lead = lead,
    forecast_origin_source_index = origin,
    target_source_index = target,
    origin_stride = 30L,
    refit_per_origin = FALSE,
    qhat = 1,
    abs_q_error = 2,
    pinball_tau = 3,
    stringsAsFactors = FALSE
  )
  lead_metrics <- data.frame(
    forecast_lead = 1:30,
    n_origins_scored = as.integer(table(factor(lead, levels = 1:30))),
    forecast_qtrue_mae = 2,
    forecast_pinball_mean = 3,
    stringsAsFactors = FALSE
  )
  qdesn_ssv2_write_csv(rolling, file.path(tmp, "tables", "forecast_rolling_origin_paths.csv"))
  qdesn_ssv2_write_csv(lead_metrics, file.path(tmp, "tables", "forecast_lead_metrics.csv"))
  qdesn_ssv2_write_json(list(
    forecast_rolling_origin_status = "PASS",
    forecast_rolling_origin_rows = 1000L,
    forecast_lead_metrics_rows = 30L,
    rolling_origin_ready_for_pruning = TRUE,
    required_lead_export_failure = FALSE
  ), file.path(tmp, "manifest", "output_retention.json"))
  audit <- qdesn_ssv2_rolling_artifact_audit(tmp)
  testthat::expect_identical(audit$decision, "PASS")
  testthat::expect_identical(audit$rolling_rows, 1000L)
  testthat::expect_identical(audit$lead_rows, 30L)
  testthat::expect_equal(audit$forecast_qtrue_mae, 2)
  testthat::expect_equal(audit$forecast_check_loss, 3)
  testthat::expect_equal(
    qdesn_ssv2_metric_value(tmp, "forecast_qtrue_mae_H1000", require_rolling = TRUE),
    2
  )
  rolling$target_source_index[[1L]] <- 9002L
  qdesn_ssv2_write_csv(rolling, file.path(tmp, "tables", "forecast_rolling_origin_paths.csv"))
  testthat::expect_identical(qdesn_ssv2_rolling_artifact_audit(tmp)$decision, "FAIL")
})

testthat::test_that("paired rolling repair is paired, gated, and storage-light", {
  scripts <- file.path(repo_root, "validation", "fitforecast_v2", "scripts")
  launcher <- file.path(
    scripts, "launch_independent_exal_m0_paired_rolling_repair_v1.sh"
  )
  testthat::expect_equal(system2("bash", c("-n", launcher)), 0L)
  text <- paste(readLines(launcher, warn = FALSE), collapse = "\n")
  testthat::expect_match(text, "QDESN_PAIRED_REPAIR_APPROVAL", fixed = TRUE)
  testthat::expect_match(text, "WORKERS > 20", fixed = TRUE)
  testthat::expect_match(text, "xargs -r -n 1 -P", fixed = TRUE)
  testthat::expect_match(text, "flock -n", fixed = TRUE)
  testthat::expect_match(text, "HEARTBEAT_SECONDS", fixed = TRUE)
  testthat::expect_match(text, "select_idle_cpus", fixed = TRUE)
  testthat::expect_match(text, "taskset -c", fixed = TRUE)
  testthat::expect_match(text, "git status --porcelain", fixed = TRUE)
  testthat::expect_match(text, "same_tag_resume_supported", fixed = TRUE)
  testthat::expect_match(
    text, "closeout_independent_exal_m0_paired_rolling_repair_v1.R", fixed = TRUE
  )
  testthat::expect_false(grepl("git commit|git push", text))

  for (script in c(
    "audit_qdesn_article_rolling_metric_contract_v1.R",
    "materialize_independent_exal_m0_paired_rolling_repair_v1.R",
    "verify_independent_exal_m0_paired_rolling_repair_v1.R",
    "healthcheck_independent_exal_m0_paired_rolling_repair_v1.R",
    "closeout_independent_exal_m0_paired_rolling_repair_v1.R"
  )) {
    testthat::expect_silent(parse(file.path(scripts, script)))
  }

  root <- file.path(
    repo_root, "reports", "shared_fitforecast_v2_orchestration",
    "independent_exal_m0_paired_rolling_repair_v1_materialization"
  )
  testthat::skip_if_not(file.exists(file.path(root, "materialization_manifest.json")))
  smoke <- qdesn_ssv2_read_csv(file.path(root, "smoke_plan.csv"))
  calibration <- qdesn_ssv2_read_csv(file.path(root, "calibration_plan.csv"))
  testthat::expect_equal(nrow(smoke), 2L)
  testthat::expect_equal(nrow(calibration), 84L)
  testthat::expect_equal(length(unique(calibration$target_cell_id)), 7L)
  key <- paste(calibration$target_cell_id, calibration$source_id,
               calibration$reservoir_seed_id, sep = "|")
  groups <- split(calibration, key)
  testthat::expect_equal(length(groups), 42L)
  testthat::expect_true(all(vapply(groups, function(x) {
    nrow(x) == 2L && length(unique(x$reservoir_seed)) == 1L &&
      identical(sort(x$candidate_role),
                sort(c("current_anchor", "prior_screen_finalist")))
  }, logical(1L))))
  testthat::expect_true(all(calibration$require_lead_export))
  testthat::expect_false(any(calibration$article_promotion_automatic))
  manifest <- qdesn_ssv2_read_json(file.path(root, "materialization_manifest.json"))
  testthat::expect_equal(
    sort(unlist(manifest$selection_contract$metrics, use.names = FALSE)),
    sort(c(
      "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
      "forecast_check_loss_H1000"
    ))
  )
  testthat::expect_identical(
    as.numeric(manifest$selection_contract$minimum_effect_threshold), 0
  )
  testthat::expect_true(
    isTRUE(manifest$selection_contract$promote_every_paired_consistent_metric_gain)
  )
  closeout_text <- paste(readLines(
    file.path(scripts, "closeout_independent_exal_m0_paired_rolling_repair_v1.R"),
    warn = FALSE
  ), collapse = "\n")
  testthat::expect_match(
    closeout_text, "paired_metric_selection_ledger.csv", fixed = TRUE
  )
  testthat::expect_match(
    closeout_text, "every_paired_consistent_metric_gain_advances", fixed = TRUE
  )
  testthat::expect_length(list.files(
    root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
    full.names = TRUE, ignore.case = TRUE
  ), 0L)
})

testthat::test_that("live child-log telemetry parses burn-in and sampling progress", {
  burn <- qdesn_ssv2_parse_progress_lines(c(
    "burn-in iteration 50 | sigma=1.000",
    "burn-in iteration 100 | sigma=0.165"
  ), 200L, 500L)
  testthat::expect_identical(burn$iteration, 100L)
  testthat::expect_identical(burn$total, 700L)
  testthat::expect_identical(burn$phase, "burnin")
  sampling <- qdesn_ssv2_parse_progress_lines(c(
    "burn-in iteration 200 | sigma=0.2",
    "MCMC iteration 250 | sigma=0.2",
    "MCMC iteration 300 | sigma=0.2"
  ), 200L, 500L)
  testthat::expect_identical(sampling$iteration, 300L)
  testthat::expect_identical(sampling$total, 700L)
  testthat::expect_identical(sampling$phase, "sampling")
})

testthat::test_that("launcher is staged, resumable, and cannot launch confirmation", {
  scripts <- file.path(repo_root, "validation", "fitforecast_v2", "scripts")
  pipeline_path <- file.path(scripts, "run_independent_exal_m0_structural_screen_v2_pipeline.sh")
  launch_path <- file.path(scripts, "launch_independent_exal_m0_structural_screen_v2.sh")
  testthat::expect_equal(system2("bash", c("-n", pipeline_path)), 0L)
  testthat::expect_equal(system2("bash", c("-n", launch_path)), 0L)
  text <- paste(readLines(pipeline_path, warn = FALSE), collapse = "\n")
  testthat::expect_match(text, "WORKERS=\"${WORKERS:-20}\"", fixed = TRUE)
  testthat::expect_match(text, "HEARTBEAT_SECONDS=\"${HEARTBEAT_SECONDS:-1800}\"", fixed = TRUE)
  testthat::expect_match(text, "run_stage wave1", fixed = TRUE)
  testthat::expect_match(text, "run_stage wave2", fixed = TRUE)
  testthat::expect_match(text, "run_stage wave3", fixed = TRUE)
  testthat::expect_match(text, "run_stage sealed", fixed = TRUE)
  testthat::expect_false(grepl("run_stage confirmation", text, fixed = TRUE))
  testthat::expect_match(text, "FULL_CONFIRMATION_LAUNCH_APPROVED=FALSE", fixed = TRUE)
  resume_path <- file.path(
    scripts, "resume_independent_exal_m0_structural_screen_v2_after_wave2.sh"
  )
  resume_launch_path <- file.path(
    scripts, "launch_resume_independent_exal_m0_structural_screen_v2_after_wave2.sh"
  )
  sealed_resume_path <- file.path(
    scripts, "resume_independent_exal_m0_structural_screen_v2_after_wave3.sh"
  )
  sealed_launch_path <- file.path(
    scripts, "launch_resume_independent_exal_m0_structural_screen_v2_after_wave3.sh"
  )
  testthat::expect_equal(system2("bash", c("-n", resume_path)), 0L)
  testthat::expect_equal(system2("bash", c("-n", resume_launch_path)), 0L)
  testthat::expect_equal(system2("bash", c("-n", sealed_resume_path)), 0L)
  testthat::expect_equal(system2("bash", c("-n", sealed_launch_path)), 0L)
  resume_text <- paste(readLines(resume_path, warn = FALSE), collapse = "\n")
  testthat::expect_match(resume_text, "ORIGINAL_COMPLETED_ROOTS=282", fixed = TRUE)
  testthat::expect_match(resume_text, "run_stage wave3", fixed = TRUE)
  testthat::expect_match(resume_text, "run_stage sealed", fixed = TRUE)
  testthat::expect_match(resume_text, 'local stage="$1"\n  local plan=', fixed = TRUE)
  testthat::expect_match(resume_text, 'local stage="$1"\n  local log=', fixed = TRUE)
  testthat::expect_false(grepl('local stage="$1" plan=', resume_text, fixed = TRUE))
  testthat::expect_false(grepl('local stage="$1" log=', resume_text, fixed = TRUE))
  testthat::expect_false(grepl("run_stage wave1", resume_text, fixed = TRUE))
  testthat::expect_false(grepl("run_stage wave2", resume_text, fixed = TRUE))
  testthat::expect_false(grepl("run_stage confirmation", resume_text, fixed = TRUE))
  sealed_text <- paste(readLines(sealed_resume_path, warn = FALSE), collapse = "\n")
  testthat::expect_match(sealed_text, "354 prior roots preserved", fixed = TRUE)
  testthat::expect_match(sealed_text, "jobs=76", fixed = TRUE)
  testthat::expect_false(grepl("--stage wave1", sealed_text, fixed = TRUE))
  testthat::expect_false(grepl("run_stage wave3", sealed_text, fixed = TRUE))
  testthat::expect_false(grepl("run_stage confirmation", sealed_text, fixed = TRUE))
  launch_text <- paste(readLines(launch_path, warn = FALSE), collapse = "\n")
  testthat::expect_match(launch_text, "WORKERS=\"${WORKERS:-20}\"", fixed = TRUE)
  testthat::expect_match(launch_text, "launcher_resources.env", fixed = TRUE)
  testthat::expect_match(launch_text, "exec env WORKERS='$WORKERS'", fixed = TRUE)
  advance_text <- paste(readLines(
    file.path(scripts, "advance_independent_exal_m0_structural_screen_v2.R"),
    warn = FALSE
  ), collapse = "\n")
  testthat::expect_match(
    advance_text, "qdesn_ssv2_max_effective_readout_dimension", fixed = TRUE
  )
  testthat::expect_match(advance_text, "get_args", fixed = TRUE)
  testthat::expect_match(advance_text, "prior_adaptive_roots", fixed = TRUE)
  health_text <- paste(readLines(
    file.path(scripts, "healthcheck_independent_exal_m0_structural_screen_v2.R"),
    warn = FALSE
  ), collapse = "\n")
  testthat::expect_match(health_text, "pipeline_child_live.log", fixed = TRUE)
  testthat::expect_match(health_text, "child_log_open", fixed = TRUE)
})

testthat::test_that("targeted confirmation is two-cell, full-budget, and manual-promotion only", {
  scripts <- file.path(repo_root, "validation", "fitforecast_v2", "scripts")
  pipeline <- file.path(
    scripts, "run_independent_exal_m0_structural_screen_v2_targeted_confirmation.sh"
  )
  launcher <- file.path(
    scripts, "launch_independent_exal_m0_structural_screen_v2_targeted_confirmation.sh"
  )
  testthat::expect_equal(system2("bash", c("-n", pipeline)), 0L)
  testthat::expect_equal(system2("bash", c("-n", launcher)), 0L)
  text <- paste(readLines(pipeline, warn = FALSE), collapse = "\n")
  testthat::expect_match(text, "TARGETED_CONFIRMATION_APPROVED", fixed = TRUE)
  testthat::expect_match(text, "6 full-budget chains", fixed = TRUE)
  testthat::expect_match(text, "article unchanged", fixed = TRUE)
  testthat::expect_match(text, 'HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"',
                         fixed = TRUE)
  testthat::expect_match(text, "taskset -c", fixed = TRUE)
  testthat::expect_match(text, "wait_for_resources", fixed = TRUE)
  testthat::expect_false(grepl("git commit|git push", text))
  materializer <- paste(readLines(file.path(
    scripts, "materialize_independent_exal_m0_structural_screen_v2_targeted_confirmation.R"
  ), warn = FALSE), collapse = "\n")
  testthat::expect_match(materializer, 'target_ids <- c("laplace_t0p05", "normal_t0p25")',
                         fixed = TRUE)
  testthat::expect_match(materializer, '"canonical_article"', fixed = TRUE)
  testthat::expect_match(materializer, "nrow(plan) != 6L", fixed = TRUE)
})

testthat::test_that("paired confirmation freezes evidence and gates canonical full compute", {
  scripts <- file.path(repo_root, "validation", "fitforecast_v2", "scripts")
  pipeline <- file.path(
    scripts, "run_independent_exal_m0_paired_confirmation_v1.sh"
  )
  launcher <- file.path(
    scripts, "launch_independent_exal_m0_paired_confirmation_v1.sh"
  )
  testthat::expect_equal(system2("bash", c("-n", pipeline)), 0L)
  testthat::expect_equal(system2("bash", c("-n", launcher)), 0L)
  pipeline_text <- paste(readLines(pipeline, warn = FALSE), collapse = "\n")
  testthat::expect_match(pipeline_text, "PAIRED_CONFIRMATION_APPROVED", fixed = TRUE)
  testthat::expect_match(pipeline_text, 'HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"',
                         fixed = TRUE)
  testthat::expect_match(pipeline_text, 'STALE_SECONDS="${STALE_SECONDS:-1800}"',
                         fixed = TRUE)
  testthat::expect_match(pipeline_text, "same_tag_resume_supported=true", fixed = TRUE)
  testthat::expect_match(pipeline_text, "taskset -c", fixed = TRUE)
  testthat::expect_match(pipeline_text, "xargs -r -n 1 -P", fixed = TRUE)
  testthat::expect_false(grepl("git commit|git push", pipeline_text))

  for (script in c(
    "seal_independent_exal_m0_paired_rolling_repair_v1_closeout.R",
    "materialize_independent_exal_m0_paired_confirmation_v1.R",
    "verify_independent_exal_m0_paired_confirmation_v1.R",
    "closeout_independent_exal_m0_paired_confirmation_v1.R"
  )) {
    testthat::expect_silent(parse(file.path(scripts, script)))
  }

  contract_path <- file.path(
    repo_root, "config", "validation",
    "qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_paired_confirmation_v1.json"
  )
  contract <- qdesn_ssv2_read_json(contract_path)
  testthat::expect_identical(contract$method_id, "M0_v_collapsed_support_logit")
  testthat::expect_equal(contract$smoke$expected_jobs, 2L)
  testthat::expect_equal(contract$confirmation$expected_jobs, 6L)
  testthat::expect_equal(contract$confirmation$chains_per_candidate, 3L)
  testthat::expect_equal(contract$confirmation$n_burn, 5000L)
  testthat::expect_equal(contract$confirmation$n_mcmc, 20000L)
  testthat::expect_equal(contract$fit_forecast_contract$max_lead, 30L)
  testthat::expect_equal(contract$fit_forecast_contract$origin_stride, 30L)
  testthat::expect_false(contract$fit_forecast_contract$refit_per_origin)
  testthat::expect_false(contract$promotion_contract$article_promotion_automatic)
  testthat::expect_true(contract$promotion_contract$mean_below_current)
  testthat::expect_true(contract$promotion_contract$median_below_current)
  testthat::expect_equal(contract$promotion_contract$minimum_effect_threshold, 0)

  handoff_root <- file.path(repo_root, contract$sealed_handoff$root)
  testthat::expect_identical(
    qdesn_ssv2_sha256(file.path(handoff_root, "canonical_confirmation_profiles.csv")),
    contract$sealed_handoff$profiles_sha256
  )
  testthat::expect_identical(
    qdesn_ssv2_sha256(file.path(handoff_root, "paired_metric_selection_ledger.csv")),
    contract$sealed_handoff$metric_selection_sha256
  )
  testthat::expect_identical(
    qdesn_ssv2_sha256(file.path(handoff_root, "article_metric_baseline.csv")),
    contract$sealed_handoff$article_metric_baseline_sha256
  )
})

testthat::test_that("materialized configs preserve vector and effective-window contracts", {
  root <- file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration",
                    "independent_exal_m0_structural_screen_v2_materialization")
  testthat::skip_if_not(file.exists(file.path(root, "materialization_manifest.json")))
  universe <- qdesn_ssv2_read_csv(file.path(root, "virtual_candidate_universe.csv"))
  testthat::expect_equal(nrow(universe), 50000L)
  expected <- c(smoke = 2L, calibration = 12L, wave1 = 103L)
  for (stage in names(expected)) {
    plan <- qdesn_ssv2_read_csv(file.path(root, paste0(stage, "_plan.csv")))
    testthat::expect_equal(nrow(plan), unname(expected[[stage]]))
    for (path in plan$config_path) {
      job <- qdesn_ssv2_read_json(path)
      D <- as.integer(job$config$desn$D)
      testthat::expect_length(job$config$desn$n, D)
      testthat::expect_length(job$config$desn$n_tilde, max(0L, D - 1L))
      testthat::expect_length(job$config$desn$alpha, D)
      testthat::expect_length(job$config$desn$rho, D)
      testthat::expect_identical(job$config$inference$mcmc$slice$core_update_mode,
                                 qdesn_ssv2_method_id)
      exact_dimension <- qdesn_ssv2_effective_readout_dimension(
        job$config$desn$n, job$config$desn$n_tilde,
        job$config$readout$reservoir_lags, job$config$lags$m_y
      )
      testthat::expect_lte(exact_dimension, qdesn_ssv2_max_effective_readout_dimension)
      testthat::expect_identical(
        as.integer(job$root_spec$effective_readout_dimension), exact_dimension
      )
      testthat::expect_identical(
        as.integer(job$config$validation$timeout_seconds),
        qdesn_ssv2_timeout_seconds(stage)
      )
      testthat::expect_equal(job$root_spec$raw_start_source_index + job$config$desn$m +
                              job$config$desn$washout, 8501L)
      testthat::expect_false(isTRUE(job$config$outputs$keep_draws))
      testthat::expect_false(isTRUE(job$config$outputs$retain_full_rds_on_failure))
    }
  }
})

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
})

testthat::test_that("fixed-seed selector allocates local, broad, boundary, and transfer arms", {
  targets <- qdesn_ssv2_targets(repo_root)
  universe <- qdesn_ssv2_virtual_universe(1500L, qdesn_ssv2_virtual_seed)
  history <- data.frame(profile_signature = character(), stringsAsFactors = FALSE)
  plan <- qdesn_ssv2_select_wave1(repo_root, universe, history, targets)
  testthat::expect_equal(nrow(plan$selected), 96L)
  testthat::expect_equal(nrow(plan$parents), 7L)
  testthat::expect_equal(anyDuplicated(plan$selected$candidate_id), 0L)
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
  testthat::expect_equal(cfg$selection_contract$workers, 20L)
  testthat::expect_identical(qdesn_ssv2_budget("wave1")$n_burn, 1000L)
  testthat::expect_identical(qdesn_ssv2_budget("wave1")$n_mcmc, 3000L)
  testthat::expect_identical(qdesn_ssv2_budget("confirmation")$n_mcmc, 20000L)
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
      testthat::expect_equal(job$root_spec$raw_start_source_index + job$config$desn$m +
                              job$config$desn$washout, 8501L)
      testthat::expect_false(isTRUE(job$config$outputs$keep_draws))
      testthat::expect_false(isTRUE(job$config$outputs$retain_full_rds_on_failure))
    }
  }
})

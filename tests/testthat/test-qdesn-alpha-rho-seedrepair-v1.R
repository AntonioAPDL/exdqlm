helper_v1 <- file.path(
  testthat::test_path("..", ".."), "validation", "fitforecast_v2", "R",
  "qdesn_alpha_rho_topology_v1.R"
)
helper_v2 <- file.path(
  testthat::test_path("..", ".."), "validation", "fitforecast_v2", "R",
  "qdesn_alpha_rho_cellwise_v2.R"
)
helper_repair <- file.path(
  testthat::test_path("..", ".."), "validation", "fitforecast_v2", "R",
  "qdesn_alpha_rho_seedrepair_v1.R"
)
source(helper_v1, local = TRUE)
source(helper_v2, local = TRUE)
source(helper_repair, local = TRUE)

testthat::test_that("dynamic screening grid separates run and reservoir seeds", {
  profile_path <- tempfile(fileext = ".csv")
  profile <- data.frame(
    screening_profile_id = "seed_contract_fixture",
    enabled = TRUE,
    D = 1L,
    n_each = 4L,
    n_tilde_each = 0L,
    m = 1L,
    alpha = 0.1,
    rho = 0.8,
    pi_w = 1,
    pi_in = 1,
    washout = 2L,
    add_bias = TRUE,
    seed = 987654L,
    readout_y_lags = 1L,
    reservoir_lags = 0L,
    rhs_tau0 = 1e-4,
    dimension_p_estimate = 11L,
    p_over_n_tt500 = 0.022,
    stringsAsFactors = FALSE
  )
  utils::write.csv(profile, profile_path, row.names = FALSE)
  source_series <- tempfile()
  source_indices <- tempfile()
  source_sim <- tempfile()
  file.create(source_series, source_indices, source_sim)
  inventory <- data.frame(
    source_scenario = "fixture_scenario",
    source_family = "normal",
    tau = 0.05,
    fit_size = 500L,
    effective_fit_size = 500L,
    source_total_size = 1890L,
    source_window_label = "fixture_window",
    raw_start_source_index = 8111L,
    raw_end_source_index = 10000L,
    train_start_source_index = 8501L,
    train_end_source_index = 9000L,
    forecast_start_source_index = 9001L,
    forecast_end_source_index = 10000L,
    source_fit_input_dir = tempdir(),
    source_report_root = tempdir(),
    source_series_wide_path = source_series,
    source_selection_indices_path = source_indices,
    source_sim_path = source_sim,
    stringsAsFactors = FALSE
  )
  defaults <- list(
    pilot = list(seed = 123L),
    execution = list(seed_policy = list(mode = "shared")),
    screening_profiles = list(enabled = TRUE, csv = profile_path, priors = "rhs_ns"),
    reference_contract = list(
      families = "normal", taus = 0.05, fit_sizes = 500L, expected_priors = "rhs_ns"
    )
  )
  grid <- qdesn_dynamic_crossstudy_build_grid_from_materialized_sources(defaults, inventory)
  testthat::expect_equal(grid$seed, 123L)
  testthat::expect_equal(grid$desn_seed, 987654L)
  enriched <- qdesn_dynamic_crossstudy_enrich_root_spec(as.list(c(
    as.list(grid[1L, , drop = FALSE]),
    list(mcmc_seed = 810101L, mcmc_rng_seed = 820101L, vb_warm_start_seed = 830101L, synthesis_seed = 840101L)
  )), defaults)
  testthat::expect_equal(enriched$desn_seed, 987654L)
  testthat::expect_equal(enriched$mcmc_seed, 810101L)
  testthat::expect_equal(enriched$mcmc_rng_seed, 820101L)
  testthat::expect_equal(enriched$vb_warm_start_seed, 830101L)
  testthat::expect_equal(enriched$synthesis_seed, 840101L)
})

testthat::test_that("seed-repair plan retains only mechanically valid historical candidates", {
  root <- testthat::test_path("..", "..")
  stub <- file.path(
    root, "config", "validation",
    "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_cellwise_v2"
  )
  historical_state <- file.path(
    root, "reports", "shared_fitforecast_v2_orchestration",
    "qdesn_alpha_rho_cellwise_v2_20260801_011245"
  )
  profiles <- utils::read.csv(paste0(stub, "_profiles.csv"), check.names = FALSE)
  profiles$comparison_role <- "candidate"
  parents <- utils::read.csv(paste0(stub, "_parent_profiles.csv"), check.names = FALSE)
  selected <- utils::read.csv(
    file.path(historical_state, "coarse_audit", "coarse_selected_candidates.csv"),
    check.names = FALSE
  )
  plan <- qdesn_arsr1_build_repair_plan(profiles, parents, selected, actual_seed = 123L)
  testthat::expect_equal(nrow(plan$profiles), 16L)
  testthat::expect_equal(sum(plan$profiles$comparison_role == "candidate"), 11L)
  testthat::expect_equal(sum(plan$profiles$comparison_role == "parent_exact"), 5L)
  testthat::expect_equal(nrow(plan$excluded), 2L)
  testthat::expect_true(all(plan$excluded$target_cell_id == "exal_laplace_t0p25"))
  testthat::expect_true(all(grepl("zero_input", plan$excluded$exclusion_reason, fixed = TRUE)))
})

testthat::test_that("seed contract requires profile seeds and paired sampler seeds", {
  profiles <- data.frame(
    screening_profile_id = c("candidate", "parent"),
    seed = c(900124L, 900124L),
    stringsAsFactors = FALSE
  )
  grid <- data.frame(
    root_id = c("root_candidate", "root_parent"),
    screening_profile_id = c("candidate", "parent"),
    target_cell_id = "cell",
    source_scenario = "source",
    comparison_role = c("candidate", "parent_exact"),
    seed = 123L,
    desn_seed = 900124L,
    mcmc_seed = 810101L,
    mcmc_rng_seed = 820101L,
    vb_warm_start_seed = 830101L,
    synthesis_seed = 840101L,
    sampler_pair_id = "cell::source",
    stringsAsFactors = FALSE
  )
  audit <- qdesn_arsr1_seed_contract_audit(grid, profiles)
  testthat::expect_true(all(audit$status == "PASS"))
  bad <- grid
  bad$desn_seed[[1L]] <- 123L
  testthat::expect_error(
    qdesn_arsr1_seed_contract_audit(bad, profiles),
    "Seed contract failed"
  )
  bad <- grid
  bad$mcmc_rng_seed[[1L]] <- 999L
  testthat::expect_error(
    qdesn_arsr1_seed_contract_audit(bad, profiles),
    "Seed contract failed"
  )
})

testthat::test_that("seed-repair pipeline has explicit smoke, storage, and promotion gates", {
  root <- testthat::test_path("..", "..")
  pipeline <- readLines(file.path(
    root, "validation", "fitforecast_v2", "scripts",
    "run_qdesn_alpha_rho_seedrepair_v1_pipeline.sh"
  ), warn = FALSE)
  testthat::expect_true(any(grepl("seed_smoke_audit", pipeline, fixed = TRUE)))
  testthat::expect_true(any(grepl("STORAGE_POLICY_PASS", pipeline, fixed = TRUE)))
  testthat::expect_true(any(grepl("full_resource_gate", pipeline, fixed = TRUE)))
  testthat::expect_true(any(grepl("full_budget_confirmation_not_launched", pipeline, fixed = TRUE)))
})

testthat::test_that("materialized seed-repair contract has frozen counts and seed separation", {
  root <- testthat::test_path("..", "..")
  stub <- file.path(
    root, "config", "validation",
    "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_seedrepair_v1"
  )
  manifest_path <- paste0(stub, "_materialization_manifest.json")
  testthat::skip_if_not(file.exists(manifest_path), "Seed-repair materialization has not run yet.")
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
  grid <- utils::read.csv(paste0(stub, "_grid.csv"), check.names = FALSE)
  profiles <- utils::read.csv(paste0(stub, "_profiles.csv"), check.names = FALSE)
  seed_audit <- utils::read.csv(paste0(stub, "_seed_contract_audit.csv"), check.names = FALSE)
  smoke_grid <- utils::read.csv(paste0(stub, "_smoke_grid.csv"), check.names = FALSE)
  testthat::expect_identical(manifest$historical_run$classification, "COMPLETE_WITH_REFINEMENT_SEED_CONTRACT_FAILURE")
  testthat::expect_equal(nrow(grid), 48L)
  testthat::expect_equal(nrow(profiles), 16L)
  testthat::expect_true(all(grid$desn_seed == profiles$seed[match(grid$screening_profile_id, profiles$screening_profile_id)]))
  testthat::expect_true(all(seed_audit$status == "PASS"))
  testthat::expect_equal(nrow(smoke_grid), 2L)
  testthat::expect_equal(length(unique(smoke_grid$desn_seed)), 2L)
  testthat::expect_equal(length(unique(smoke_grid$mcmc_rng_seed)), 1L)
})

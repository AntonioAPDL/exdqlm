helper_v1 <- file.path(
  testthat::test_path("..", ".."), "validation", "fitforecast_v2", "R",
  "qdesn_alpha_rho_topology_v1.R"
)
helper_v2 <- file.path(
  testthat::test_path("..", ".."), "validation", "fitforecast_v2", "R",
  "qdesn_alpha_rho_cellwise_v2.R"
)
source(helper_v1, local = TRUE)
source(helper_v2, local = TRUE)

testthat::test_that("cellwise v2 search map has frozen case-specific budgets", {
  map <- qdesn_arv2_search_map()
  testthat::expect_equal(nrow(map), 9L)
  testthat::expect_equal(sum(map$search_budget), 90L)
  testthat::expect_equal(sum(map$search_dimension == "alpha_only"), 6L)
  testthat::expect_equal(sum(map$search_dimension == "alpha_rho"), 3L)
  testthat::expect_equal(table(map$target_cell_id)[["exal_gausmix_t0p25"]], 2L)
})

testthat::test_that("alpha design is broad and never repeats the parent point", {
  parents <- qdesn_arv1_resolve_parent_profiles(testthat::test_path("..", ".."))
  for (parent_alpha in parents$alpha) {
    values <- qdesn_arv2_alpha_levels(parent_alpha)
    testthat::expect_equal(length(values), 10L)
    testthat::expect_true(all(values > 0 & values < 1))
    testthat::expect_false(any(abs(log(values / parent_alpha)) < 1e-12))
    testthat::expect_lte(min(values), 0.0001)
    testthat::expect_gte(max(values), 0.95)
  }
  surface <- qdesn_arv2_alpha_rho_levels(FALSE)
  testthat::expect_equal(nrow(surface), 12L)
  testthat::expect_equal(nrow(unique(surface)), 12L)
  testthat::expect_equal(nrow(qdesn_arv2_alpha_rho_levels(TRUE)), 6L)
})

testthat::test_that("v2 plan is deterministic, cell-specific, and bounded", {
  plan <- qdesn_arv2_build_plan(testthat::test_path("..", ".."))
  testthat::expect_equal(nrow(plan$designs), 90L)
  testthat::expect_equal(nrow(plan$profiles), 180L)
  testthat::expect_equal(nrow(plan$assignments), 180L)
  testthat::expect_equal(sum(plan$profiles$launch_phase == "coarse"), 90L)
  testthat::expect_equal(sum(plan$profiles$launch_phase == "refinement_universe"), 90L)
  testthat::expect_equal(sort(unique(plan$profiles$reservoir_replicate)), c(1L, 2L))
  testthat::expect_equal(length(unique(plan$profiles$candidate_id)), 90L)
  testthat::expect_true(all(plan$profiles$D == 1L))
  testthat::expect_true(all(plan$profiles$rhs_tau0 > 0))
})

testthat::test_that("alpha-only and alpha/rho labels match realized topology", {
  plan <- qdesn_arv2_build_plan(testthat::test_path("..", ".."))
  audit <- qdesn_arv2_topology_audit(plan$profiles)
  testthat::expect_true(all(audit$rho_identifiable[audit$search_dimension == "alpha_rho"]))
  alpha_only <- audit[audit$search_dimension == "alpha_only", , drop = FALSE]
  alpha_groups <- split(alpha_only$rho, paste(alpha_only$target_cell_id, alpha_only$search_id, alpha_only$reservoir_replicate))
  testthat::expect_true(all(vapply(alpha_groups, function(x) length(unique(x)) == 1L, logical(1L))))
  testthat::expect_true(all(audit$input_active))
})

testthat::test_that("objective selection stays per-cell and deduplicates winners", {
  x <- data.frame(
    target_cell_id = rep(c("cell_a", "cell_b"), each = 3L),
    candidate_id = paste0("candidate_", seq_len(6L)),
    median_fit_ratio = c(0.90, 0.99, 1.00, 0.95, 0.99, 1.01),
    median_forecast_mae_ratio = c(1.01, 0.91, 0.99, 0.97, 0.94, 1.00),
    median_forecast_check_ratio = c(1.00, 0.98, 0.92, 0.99, 0.96, 0.97),
    worst_median_ratio = c(1.01, 0.99, 1.00, 0.99, 0.99, 1.01),
    worst_q90_ratio = rep(1.10, 6L),
    n_complete_pairs = rep(3L, 6L),
    stringsAsFactors = FALSE
  )
  selected <- qdesn_arv2_select_objective_candidates(x, max_per_cell = 4L)
  testthat::expect_true(all(table(selected$target_cell_id) <= 4L))
  testthat::expect_equal(anyDuplicated(selected$candidate_id), 0L)
  testthat::expect_true(all(c("cell_a", "cell_b") %in% selected$target_cell_id))
  testthat::expect_true(any(grepl("fit", selected$selection_objective)))
})

testthat::test_that("pipeline resource sampler and stage boundaries are explicit", {
  root <- testthat::test_path("..", "..")
  pipeline <- readLines(file.path(
    root, "validation", "fitforecast_v2", "scripts",
    "run_qdesn_alpha_rho_cellwise_v2_pipeline.sh"
  ), warn = FALSE)
  testthat::expect_true(any(grepl("PIPELINE_SELF_TEST_OK", pipeline, fixed = TRUE)))
  testthat::expect_true(any(grepl("coarse_resource_gate", pipeline, fixed = TRUE)))
  testthat::expect_true(any(grepl("refinement_resource_gate", pipeline, fixed = TRUE)))
  testthat::expect_true(any(grepl("full_budget_confirmation_not_launched", pipeline, fixed = TRUE)))
  testthat::expect_false(any(grepl("awk -v load=", pipeline, fixed = TRUE)))
})

testthat::test_that("materialized contract preserves counts, provenance, and non-repeat gate", {
  root <- testthat::test_path("..", "..")
  stub <- file.path(
    root, "config", "validation",
    "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_cellwise_v2"
  )
  manifest_path <- paste0(stub, "_materialization_manifest.json")
  testthat::expect_true(file.exists(manifest_path))
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
  testthat::expect_identical(manifest$package_version, "1.0.0")
  testthat::expect_identical(
    manifest$source_registry_sha256,
    "07e5f3b11cccd01c5c69ba8ff4794d4d28f583b9c5e8aba8b9dbc953fe862444"
  )
  testthat::expect_equal(unname(unlist(manifest$counts)), c(5L, 9L, 90L, 180L, 270L, 270L))
  testthat::expect_equal(manifest$history$unresolved_profile_count, 0L)
  testthat::expect_equal(manifest$history$exact_overlap_count, 0L)

  coarse <- utils::read.csv(paste0(stub, "_coarse_grid.csv"), check.names = FALSE)
  refinement <- utils::read.csv(paste0(stub, "_refinement_universe_grid.csv"), check.names = FALSE)
  overlap <- utils::read.csv(paste0(stub, "_executed_profile_overlap_audit.csv"), check.names = FALSE)
  topology <- utils::read.csv(paste0(stub, "_topology_audit.csv"), check.names = FALSE)
  testthat::expect_equal(nrow(coarse), 270L)
  testthat::expect_equal(nrow(refinement), 270L)
  testthat::expect_equal(nrow(overlap), 0L)
  testthat::expect_true(all(topology$input_active))
  testthat::expect_true(all(topology$rho_identifiable[topology$search_dimension == "alpha_rho"]))
})

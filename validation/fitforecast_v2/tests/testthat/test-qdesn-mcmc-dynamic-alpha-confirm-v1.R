stage_stub <- file.path(
  repo_root, "config", "validation",
  "qdesn_dynamic_fitforecast_v2_500obs_mcmc_dynamic_alpha_confirm_v1"
)

read_contract_csv <- function(suffix) {
  utils::read.csv(paste0(stage_stub, suffix), check.names = FALSE)
}

test_that("dynamic-alpha shortlist is the six exact discovery designs", {
  shortlist <- read_contract_csv("_shortlist.csv")
  expected <- qdesn_dacf1_expected_shortlist()

  expect_silent(qdesn_dacf1_validate_shortlist(shortlist))
  expect_equal(nrow(shortlist), 6L)
  expect_setequal(shortlist$confirmation_design_id, expected$confirmation_design_id)
  expect_setequal(shortlist$desn_seed, c(900124L, 900126L, 900132L))
  expect_equal(sum(shortlist$likelihood_target == "al"), 3L)
  expect_equal(sum(shortlist$likelihood_target == "exal"), 3L)
})

test_that("confirmation plan reuses four controls across three sampler replicates", {
  shortlist <- read_contract_csv("_shortlist.csv")
  discovery <- utils::read.csv(
    file.path(
      repo_root, "config", "validation",
      "qdesn_dynamic_fitforecast_v2_500obs_mcmc_dynamic_seedrepair_v1_profiles.csv"
    ), check.names = FALSE
  )
  plan <- qdesn_dacf1_build_plan(discovery, shortlist, 3L)

  expect_equal(nrow(plan$base_designs), 10L)
  expect_equal(nrow(plan$profiles), 30L)
  expect_equal(sum(plan$profiles$comparison_role == "candidate"), 18L)
  expect_equal(sum(plan$profiles$comparison_role == "parent_exact_same_reservoir"), 12L)
  expect_equal(length(unique(plan$profiles$control_key)), 4L)
  expect_identical(sort(unique(plan$profiles$sampler_replicate)), 1:3)
  expect_equal(nrow(plan$pair_map), 18L)
  expect_equal(anyDuplicated(plan$pair_map$confirmation_pair_id), 0L)
})

test_that("candidate-parent pairs share reservoir and execution seeds", {
  profiles <- read_contract_csv("_profiles.csv")
  grid <- read_contract_csv("_grid.csv")
  audit <- qdesn_dacf1_seed_contract_audit(grid, profiles, TRUE)

  expect_equal(nrow(audit), 30L)
  expect_true(all(audit$status == "PASS"))
  for (pair_id in unique(audit$sampler_pair_id)) {
    rows <- audit[audit$sampler_pair_id == pair_id, , drop = FALSE]
    expect_equal(sum(rows$comparison_role == "parent_exact_same_reservoir"), 1L)
    expect_true(sum(rows$comparison_role == "candidate") >= 1L)
    expect_equal(length(unique(rows$observed_desn_seed)), 1L)
    expect_equal(length(unique(rows$mcmc_seed)), 1L)
    expect_equal(length(unique(rows$mcmc_rng_seed)), 1L)
    expect_equal(length(unique(rows$vb_warm_start_seed)), 1L)
    expect_equal(length(unique(rows$synthesis_seed)), 1L)
  }
})

test_that("paired metrics preserve all eighteen exact comparisons", {
  profiles <- read_contract_csv("_profiles.csv")
  pair_map <- read_contract_csv("_pair_map.csv")
  metrics <- data.frame(
    screening_profile_id = profiles$screening_profile_id,
    fit_qtrue_rmse = seq_len(nrow(profiles)),
    forecast_qtrue_mae_H1000 = seq_len(nrow(profiles)) + 10,
    forecast_check_loss_H1000 = seq_len(nrow(profiles)) + 20,
    stringsAsFactors = FALSE
  )
  paired <- qdesn_dacf1_pair_metrics(metrics, pair_map)

  expect_equal(nrow(paired), 18L)
  expect_true(all(paired$pair_complete))
  expect_true(all(is.finite(paired$fit_qtrue_rmse_ratio)))
  expect_true(all(is.finite(paired$forecast_qtrue_mae_H1000_ratio)))
  expect_true(all(is.finite(paired$forecast_check_loss_H1000_ratio)))
})

test_that("metric promotion ignores diagnostics but enforces execution contracts", {
  article <- data.frame(
    model_variant = c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
    fit_qtrue_rmse = c(2, 2),
    forecast_qtrue_mae_H1000 = c(3, 3),
    forecast_check_loss_H1000 = c(4, 4),
    stringsAsFactors = FALSE
  )
  metrics <- data.frame(
    spec_id = c("al_fail_better", "al_pass_worse", "exal_bad_contract"),
    screening_profile_id = c("a", "b", "c"),
    likelihood_family = c("al", "al", "exal"),
    status = c("FAILED", "SUCCESS", "SUCCESS"),
    signoff_grade = c("FAIL", "PASS", "PASS"),
    source_registry_hash_match = c(TRUE, TRUE, FALSE),
    seed_contract_match = TRUE,
    budget_contract_match = TRUE,
    expected_spec_match = TRUE,
    fit_qtrue_rmse = c(1.5, 2.5, 1),
    forecast_qtrue_mae_H1000 = c(2.5, 3.5, 1),
    forecast_check_loss_H1000 = c(3.5, 4.5, 1),
    stringsAsFactors = FALSE
  )
  promotion <- qdesn_dacf1_metric_promotion(metrics, article)

  expect_equal(nrow(promotion$winners), 3L)
  expect_true(all(promotion$winners$spec_id == "al_fail_better"))
  expect_false(any(promotion$winners$model_variant == "qdesn_exal_rhs_ns"))
})

test_that("materialized campaign is full-budget, storage-light, and single-threaded", {
  defaults <- yaml::read_yaml(paste0(stage_stub, "_defaults.yaml"))
  grid <- read_contract_csv("_grid.csv")
  specs <- read_contract_csv("_target_spec_ids.csv")
  smoke <- yaml::read_yaml(paste0(stage_stub, "_smoke_defaults.yaml"))

  expect_equal(nrow(grid), 30L)
  expect_equal(nrow(specs), 30L)
  expect_equal(anyDuplicated(specs$spec_id), 0L)
  expect_true(all(specs$likelihood_family == specs$likelihood_target))
  expect_true(all(grid$train_start_source_index == 8501L))
  expect_true(all(grid$train_end_source_index == 9000L))
  expect_true(all(grid$forecast_start_source_index == 9001L))
  expect_true(all(grid$forecast_end_source_index == 10000L))
  expect_equal(defaults$runtime$workers, 20L)
  expect_equal(defaults$runtime$threads, 1L)
  expect_equal(defaults$pipeline$inference$mcmc$n_burn, 5000L)
  expect_equal(defaults$pipeline$inference$mcmc$n_mcmc, 20000L)
  expect_equal(defaults$pipeline$inference$mcmc$progress_every, 50L)
  expect_true(defaults$pipeline$inference$mcmc$init_from_vb)
  expect_false(defaults$pipeline$outputs$keep_draws)
  expect_false(defaults$pipeline$outputs$keep_mcmc_vb_init)
  expect_false(defaults$pipeline$outputs$save_forecast_objects)
  expect_false(defaults$pipeline$outputs$retain_full_rds_on_failure)
  expect_equal(smoke$pipeline$inference$mcmc$n_burn, 4L)
  expect_equal(smoke$pipeline$inference$mcmc$n_mcmc, 4L)
})

test_that("launcher keeps full confirmation staged and article promotion manual", {
  pipeline_path <- file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "run_qdesn_mcmc_dynamic_alpha_confirm_v1_pipeline.sh"
  )
  launcher_path <- file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "launch_qdesn_mcmc_dynamic_alpha_confirm_v1.sh"
  )
  skip_if_not(file.exists(pipeline_path) && file.exists(launcher_path))
  pipeline <- paste(readLines(pipeline_path, warn = FALSE), collapse = "\n")
  launcher <- paste(readLines(launcher_path, warn = FALSE), collapse = "\n")

  expect_match(pipeline, "WORKERS=20", fixed = TRUE)
  expect_match(pipeline, "OPENBLAS_NUM_THREADS=1", fixed = TRUE)
  expect_match(pipeline, "taskset -c", fixed = TRUE)
  expect_match(pipeline, "ARTICLE_UPDATE_AUTOMATIC=FALSE", fixed = TRUE)
  expect_match(pipeline, "closeout_qdesn_mcmc_dynamic_alpha_confirm_v1.R", fixed = TRUE)
  expect_match(launcher, "validation/qdesn-mcmc-dynamic-alpha-confirm-v1-1.0.0", fixed = TRUE)
  expect_match(launcher, "upstream mismatch", fixed = TRUE)
})

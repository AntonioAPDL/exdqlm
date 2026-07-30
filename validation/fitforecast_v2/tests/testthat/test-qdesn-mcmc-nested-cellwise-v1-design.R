test_that("nested cellwise MCMC v1 is reproducible, nonrepeating, and launch-gated", {
  root <- ffv2_repo_root()
  stage_base <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_nested_cellwise_v1"
  promotion_id <- "qdesn_500obs_mcmc_nested_cellwise_v1_design_20260729"
  source_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
  promotion_root <- file.path(
    root, "validation", "fitforecast_v2", "promotions", promotion_id
  )
  read_table <- function(path) {
    read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  }
  promotion_path <- function(suffix) {
    file.path(promotion_root, paste0(promotion_id, suffix))
  }

  expect_true(dir.exists(promotion_root))
  expect_true(file.exists(file.path(
    root, "validation", "fitforecast_v2", "scripts",
    "materialize_qdesn_mcmc_nested_cellwise_v1_20260729.R"
  )))
  expect_true(file.exists(file.path(
    root, "scripts", "orchestrate_qdesn_500obs_mcmc_nested_cellwise_v1.R"
  )))
  expect_true(file.exists(file.path(
    root, "scripts", "closeout_qdesn_500obs_mcmc_nested_cellwise_v1.R"
  )))
  expect_true(file.exists(file.path(
    root, "validation", "fitforecast_v2", "docs",
    "QDESN_500OBS_MCMC_NESTED_CELLWISE_V1_PLAN_2026-07-29.md"
  )))

  summary <- read_table(promotion_path("_summary.csv"))
  profiles <- read_table(promotion_path("_candidate_profiles.csv"))
  assignments <- read_table(promotion_path("_candidate_assignments.csv"))
  repeat_audit <- read_table(promotion_path("_exact_repeat_audit.csv"))
  targets <- read_table(promotion_path("_target_cells.csv"))
  views <- read_table(promotion_path("_calibration_view_registry.csv"))
  history <- read_table(promotion_path("_history_summary.csv"))
  manifest <- jsonlite::read_json(
    promotion_path("_manifest.json"),
    simplifyVector = TRUE
  )
  file_manifest <- read_table(file.path(promotion_root, "file_manifest.csv"))
  source_manifest <- read_table(file.path(promotion_root, "source_manifest.csv"))

  expect_equal(nrow(summary), 1L)
  expect_identical(summary$promotion_id[[1L]], promotion_id)
  expect_identical(summary$source_registry_hash_value[[1L]], source_hash)
  expect_equal(summary$target_cells[[1L]], 15L)
  expect_equal(summary$designs_per_cell[[1L]], 12L)
  expect_equal(summary$reservoir_seeds_per_design[[1L]], 2L)
  expect_equal(summary$calibration_origins[[1L]], 2L)
  expect_equal(summary$selected_roots_total[[1L]], 720L)
  expect_equal(summary$mcmc_seed_reps_per_root[[1L]], 2L)
  expect_equal(summary$planned_chain_fits[[1L]], 1440L)
  expect_equal(summary$mcmc_n_burn[[1L]], 2000L)
  expect_equal(summary$mcmc_n_mcmc[[1L]], 8000L)
  expect_equal(summary$workers_total_cap[[1L]], 16L)
  expect_identical(
    summary$article_update_policy[[1L]],
    "no raw discovery result is article-facing"
  )

  expect_equal(nrow(targets), 15L)
  expect_equal(
    nrow(unique(targets[c("model_variant", "family", "tau", "fit_size")])),
    15L
  )
  expect_true(all(targets$source_registry_hash_value == source_hash))

  expect_equal(nrow(profiles), 360L)
  expect_equal(nrow(assignments), 360L)
  expect_equal(anyDuplicated(profiles$screening_profile_id), 0L)
  expect_equal(anyDuplicated(assignments$assignment_key), 0L)
  expect_equal(
    nrow(unique(assignments[c("family", "tau", "likelihood_target")])),
    15L
  )
  cell_key <- paste(
    assignments$family,
    sprintf("%.8f", assignments$tau),
    assignments$likelihood_target,
    sep = "|"
  )
  expect_true(all(table(cell_key) == 24L))
  design_key <- paste(
    assignments$family,
    sprintf("%.8f", assignments$tau),
    assignments$likelihood_target,
    assignments$target_profile_rank,
    sep = "|"
  )
  expect_true(all(table(design_key) == 2L))
  expect_setequal(profiles$reservoir_seed_rep, c(1L, 2L))
  expect_equal(sum(profiles$repeat_class == "declared_anchor_control"), 60L)
  expect_equal(sum(profiles$repeat_class == "novel_candidate"), 300L)
  expect_true(all(
    profiles$p_over_n_tt500[profiles$repeat_class == "novel_candidate"] <= 0.20
  ))
  expect_lte(max(profiles$p_over_n_tt500), 0.35)
  expect_true(any(profiles$D == 2L))
  expect_true(any(profiles$m == 30L))
  expect_true(any(profiles$reservoir_lags == 1L))

  expect_equal(nrow(repeat_audit), 360L)
  forbidden_repeat <- repeat_audit$exact_history_repeat &
    !repeat_audit$repeat_allowed
  expect_false(any(forbidden_repeat))
  expect_true(all(
    !repeat_audit$exact_history_repeat[
      repeat_audit$repeat_class == "novel_candidate"
    ]
  ))
  expect_gte(history$catalog_count[[1L]], 14L)
  expect_gte(history$catalog_rows[[1L]], 967L)
  expect_gte(history$unique_numeric_designs[[1L]], 180L)

  expect_equal(nrow(views), 2L)
  expect_setequal(views$calibration_origin_source_index, c(7000L, 8000L))
  expect_setequal(views$train_start_source_index, c(6501L, 7501L))
  expect_setequal(views$forecast_start_source_index, c(7001L, 8001L))
  expect_setequal(views$forecast_end_source_index, c(8000L, 9000L))
  expect_true(all(views$selected_roots == 360L))
  expect_true(all(views$mcmc_seed_reps == 2L))

  for (origin in c(7000L, 8000L)) {
    stage <- paste0(stage_base, "_origin", origin)
    defaults_path <- file.path(
      root, "config", "validation", paste0(stage, "_defaults.yaml")
    )
    grid_path <- file.path(
      root, "config", "validation", paste0(stage, "_grid.csv")
    )
    targets_path <- file.path(
      root, "config", "validation", paste0(stage, "_target_spec_ids.csv")
    )
    profiles_path <- file.path(
      root, "config", "validation", paste0(stage, "_profiles.csv")
    )
    assignments_path <- file.path(
      root, "config", "validation", paste0(stage, "_cell_assignments.csv")
    )
    expect_true(all(file.exists(c(
      defaults_path, grid_path, targets_path, profiles_path, assignments_path
    ))))

    defaults <- yaml::read_yaml(defaults_path)
    grid <- read_table(grid_path)
    atomic <- read_table(targets_path)
    expect_equal(nrow(grid), 360L)
    expect_equal(nrow(atomic), 360L)
    expect_equal(anyDuplicated(atomic$spec_id), 0L)
    expect_true(all(grid$train_start_source_index == origin - 499L))
    expect_true(all(grid$train_end_source_index == origin))
    expect_true(all(grid$forecast_start_source_index == origin + 1L))
    expect_true(all(grid$forecast_end_source_index == origin + 1000L))
    expect_false(any(grid$train_end_source_index == 9000L))
    expect_identical(
      defaults$study_contract$source_registry_hash_value,
      source_hash
    )
    expect_equal(as.integer(defaults$study_contract$budget$mcmc_n_burn), 2000L)
    expect_equal(as.integer(defaults$study_contract$budget$mcmc_n_mcmc), 8000L)
    expect_equal(as.integer(defaults$pipeline$inference$mcmc$progress_every), 50L)
    expect_true(isTRUE(defaults$multiseed$enabled))
    expect_equal(as.integer(defaults$multiseed$mcmc_seed_reps), 2L)
    expect_equal(as.integer(defaults$multiseed$parallel_seed_workers), 1L)
    expect_false(isTRUE(defaults$pipeline$outputs$keep_draws))
    expect_false(isTRUE(defaults$pipeline$outputs$save_forecast_objects))
    expect_false(isTRUE(defaults$pipeline$outputs$retain_full_rds_on_failure))
    expect_equal(length(defaults$execution$allowed_fit_spec_ids), 360L)
    expect_equal(as.integer(defaults$smoke$budget$mcmc_n_burn), 4L)
    expect_equal(as.integer(defaults$smoke$budget$mcmc_n_mcmc), 4L)
  }

  expect_identical(manifest$promotion_id, promotion_id)
  expect_identical(manifest$source_registry_hash_value, source_hash)
  expect_equal(as.integer(manifest$target_cells), 15L)
  expect_equal(as.integer(manifest$selected_roots_total), 720L)
  expect_equal(as.integer(manifest$planned_chain_fits), 1440L)
  expect_true(all(file.exists(file_manifest$path)))
  expect_equal(
    unname(tools::sha256sum(file_manifest$path)),
    file_manifest$sha256
  )
  expect_true(all(file.exists(source_manifest$path)))
  expect_equal(
    unname(tools::sha256sum(source_manifest$path)),
    source_manifest$sha256
  )

  tracked_text <- paste(capture.output(str(list(
    summary = summary,
    profiles = profiles,
    assignments = assignments,
    views = views,
    manifest = manifest
  ))), collapse = "\n")
  expect_false(grepl("/home/jaguir26/local/src", tracked_text, fixed = TRUE))
  expect_false(grepl("Article-Q-DESN", tracked_text, fixed = TRUE))

  heavy <- list.files(
    promotion_root,
    pattern = "[.](rds|rda|RData)$|__design[.]rds$",
    recursive = TRUE,
    full.names = TRUE
  )
  expect_length(heavy, 0L)
})

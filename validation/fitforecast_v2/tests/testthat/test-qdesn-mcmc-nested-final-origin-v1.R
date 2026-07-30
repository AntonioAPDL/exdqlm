test_that("nested final-origin MCMC confirmation is frozen and launch-gated", {
  root <- ffv2_repo_root()
  stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_nested_final_origin9000_v1"
  design_id <- "qdesn_500obs_mcmc_nested_final_origin9000_v1_design_20260730"
  source_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
  design_root <- file.path(
    root, "validation", "fitforecast_v2", "promotions", design_id
  )
  read_table <- function(path) {
    read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  }
  col_or <- function(df, candidates) {
    hit <- intersect(candidates, names(df))
    expect_true(length(hit) >= 1L)
    df[[hit[[1L]]]]
  }

  implementation_paths <- c(
    file.path(
      root, "validation", "fitforecast_v2", "scripts",
      "materialize_qdesn_mcmc_nested_final_origin_20260730.R"
    ),
    file.path(
      root, "scripts",
      "orchestrate_qdesn_500obs_mcmc_nested_final_origin_v1.R"
    ),
    file.path(
      root, "scripts",
      "closeout_qdesn_500obs_mcmc_nested_final_origin_v1.R"
    ),
    file.path(
      root, "validation", "fitforecast_v2", "docs",
      "QDESN_500OBS_MCMC_NESTED_FINAL_ORIGIN_V1_2026-07-30.md"
    )
  )
  expect_true(all(file.exists(implementation_paths)))
  invisible(lapply(implementation_paths[grepl("[.]R$", implementation_paths)], parse))

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
    defaults_path,
    grid_path,
    targets_path,
    profiles_path,
    assignments_path
  ))))

  defaults <- yaml::read_yaml(defaults_path)
  grid <- read_table(grid_path)
  targets <- read_table(targets_path)
  profiles <- read_table(profiles_path)
  assignments <- read_table(assignments_path)
  contract <- read_table(file.path(design_root, "confirmation_contract.csv"))
  invalid_runs <- read_table(file.path(design_root, "invalid_run_registry.csv"))
  stability <- read_table(file.path(
    design_root, "originwise_stability_summary.csv"
  ))
  manifest <- jsonlite::read_json(
    file.path(design_root, paste0(design_id, "_manifest.json")),
    simplifyVector = TRUE
  )
  file_manifest <- read_table(file.path(design_root, "file_manifest.csv"))
  source_manifest <- read_table(file.path(design_root, "source_manifest.csv"))

  expect_equal(nrow(contract), 1L)
  expect_identical(contract$design_id[[1L]], design_id)
  expect_identical(contract$source_registry_hash_value[[1L]], source_hash)
  expect_equal(contract$final_origin_source_index[[1L]], 9000L)
  expect_equal(contract$train_start_source_index[[1L]], 8501L)
  expect_equal(contract$train_end_source_index[[1L]], 9000L)
  expect_equal(contract$forecast_start_source_index[[1L]], 9001L)
  expect_equal(contract$forecast_end_source_index[[1L]], 10000L)
  expect_equal(contract$selected_cells[[1L]], 4L)
  expect_equal(contract$selected_roots[[1L]], 8L)
  expect_equal(contract$reservoir_seed_reps[[1L]], 2L)
  expect_equal(contract$mcmc_seed_reps[[1L]], 2L)
  expect_equal(contract$planned_chain_fits[[1L]], 16L)
  expect_equal(contract$mcmc_n_burn[[1L]], 5000L)
  expect_equal(contract$mcmc_n_mcmc[[1L]], 20000L)
  expect_equal(contract$posterior_metric_draws[[1L]], 200L)
  expect_identical(
    contract$article_update_policy[[1L]],
    "manual_after_final_closeout_only"
  )
  expect_equal(nrow(invalid_runs), 1L)
  expect_identical(
    invalid_runs$run_tag[[1L]],
    "qdesn-500obs-mcmc-nested-final-o9000-v1-full-20260730__git-6582f87"
  )
  expect_identical(
    invalid_runs$state[[1L]],
    "ABORTED_INVALID_CONTRACT"
  )
  expect_false(invalid_runs$consumable[[1L]])

  expect_equal(nrow(grid), 8L)
  expect_equal(nrow(targets), 8L)
  expect_equal(nrow(profiles), 8L)
  expect_equal(nrow(assignments), 8L)
  expect_equal(anyDuplicated(col_or(targets, "spec_id")), 0L)
  expect_true(all(grid$train_start_source_index == 8501L))
  expect_true(all(grid$train_end_source_index == 9000L))
  expect_true(all(grid$forecast_start_source_index == 9001L))
  expect_true(all(grid$forecast_end_source_index == 10000L))
  expect_equal(
    nrow(unique(assignments[c("family", "tau", "likelihood_target")])),
    4L
  )
  assignment_cells <- paste(
    assignments$family,
    sprintf("%.8f", assignments$tau),
    assignments$likelihood_target,
    sep = "|"
  )
  expect_true(all(table(assignment_cells) == 2L))
  expect_setequal(assignments$confirmation_role, c(
    "primary_confirmation",
    "instability_sentinel"
  ))
  expect_equal(
    sum(assignments$confirmation_role == "primary_confirmation"),
    6L
  )
  expect_equal(
    sum(assignments$confirmation_role == "instability_sentinel"),
    2L
  )
  expect_setequal(
    assignments$screening_profile_id,
    c(
      "ncv1_183_al_gausmix_t0p50_compact_lhs_06_r01",
      "ncv1_184_al_gausmix_t0p50_compact_lhs_06_r02",
      "ncv1_125_al_laplace_t0p05_compact_lhs_01_r01",
      "ncv1_126_al_laplace_t0p05_compact_lhs_01_r02",
      "ncv1_053_al_normal_t0p05_compact_lhs_01_r01",
      "ncv1_054_al_normal_t0p05_compact_lhs_01_r02",
      "ncv1_207_exal_normal_t0p25_compact_lhs_06_r01",
      "ncv1_208_exal_normal_t0p25_compact_lhs_06_r02"
    )
  )

  expect_equal(nrow(stability), 4L)
  expect_equal(
    sum(stability$confirmation_role == "primary_confirmation"),
    3L
  )
  expect_equal(
    sum(stability$confirmation_role == "instability_sentinel"),
    1L
  )

  expect_identical(
    defaults$study_contract$source_registry_hash_value,
    source_hash
  )
  expect_equal(
    as.integer(defaults$study_contract$budget$mcmc_n_burn),
    5000L
  )
  expect_equal(
    as.integer(defaults$study_contract$budget$mcmc_n_mcmc),
    20000L
  )
  expect_equal(
    as.integer(defaults$study_contract$budget$vb_sampling_nd_draws),
    200L
  )
  expect_equal(
    as.integer(defaults$study_contract$budget$vb_synthesis_n_samp),
    200L
  )
  expect_equal(as.integer(defaults$metrics$posterior_metric_draws), 200L)
  expect_equal(as.integer(defaults$pipeline$sampling$nd_draws), 200L)
  expect_equal(as.integer(defaults$pipeline$synthesis$n_samp), 200L)
  expect_equal(as.integer(defaults$pipeline$inference$mcmc$progress_every), 50L)
  expect_true(isTRUE(defaults$pipeline$inference$mcmc$init_from_vb))
  expect_true(isTRUE(defaults$multiseed$enabled))
  expect_equal(as.integer(defaults$multiseed$mcmc_seed_reps), 2L)
  expect_equal(as.integer(defaults$multiseed$parallel_seed_workers), 1L)
  expect_false(isTRUE(defaults$pipeline$outputs$keep_draws))
  expect_false(isTRUE(defaults$pipeline$outputs$keep_mcmc_vb_init))
  expect_false(isTRUE(defaults$pipeline$outputs$save_forecast_objects))
  expect_false(isTRUE(defaults$pipeline$outputs$retain_full_rds_on_failure))
  expect_equal(length(defaults$execution$allowed_fit_spec_ids), 8L)
  expect_equal(as.integer(defaults$smoke$budget$mcmc_n_burn), 4L)
  expect_equal(as.integer(defaults$smoke$budget$mcmc_n_mcmc), 4L)
  expect_equal(
    as.integer(defaults$smoke$budget$posterior_metric_draws),
    4L
  )
  expect_equal(
    as.integer(defaults$smoke$budget$vb_sampling_nd_draws),
    4L
  )
  expect_equal(
    as.integer(defaults$smoke$budget$vb_synthesis_n_samp),
    4L
  )

  expect_identical(manifest$design_id, design_id)
  expect_identical(manifest$source_registry_hash_value, source_hash)
  expect_equal(as.integer(manifest$selected_cells), 4L)
  expect_equal(as.integer(manifest$selected_roots), 8L)
  expect_equal(as.integer(manifest$planned_chain_fits), 16L)
  expect_equal(as.integer(manifest$primary_confirmations), 3L)
  expect_equal(as.integer(manifest$instability_sentinels), 1L)
  expect_identical(
    unname(manifest$invalid_run_tags),
    invalid_runs$run_tag
  )
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
    defaults = defaults,
    grid = grid,
    targets = targets,
    assignments = assignments,
    contract = contract,
    manifest = manifest
  ))), collapse = "\n")
  expect_false(grepl("/home/jaguir26/local/src", tracked_text, fixed = TRUE))
  expect_false(grepl("Article-Q-DESN", tracked_text, fixed = TRUE))

  heavy <- list.files(
    design_root,
    pattern = "[.](rds|rda|RData)$|__design[.]rds$",
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE
  )
  expect_length(heavy, 0L)
})

test_that("Q-DESN MCMC post-v4 per-cell prelaunch is launchable and storage-light", {
  root <- ffv2_repo_root()
  stage <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_postv4_percell"
  prelaunch_id <- "qdesn_tt500_mcmc_postv4_percell_prelaunch_20260727"
  source_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"

  paths <- list(
    profiles = file.path(root, "config", "validation", paste0(stage, "_profiles.csv")),
    assignments = file.path(root, "config", "validation", paste0(stage, "_cell_assignments.csv")),
    defaults = file.path(root, "config", "validation", paste0(stage, "_defaults.yaml")),
    grid = file.path(root, "config", "validation", paste0(stage, "_grid.csv")),
    target_specs = file.path(root, "config", "validation", paste0(stage, "_target_spec_ids.csv")),
    manifest = file.path(root, "config", "validation", paste0(stage, "_materialization_manifest.json")),
    prelaunch = file.path(root, "validation", "fitforecast_v2", "promotions", prelaunch_id)
  )
  expect_true(all(file.exists(unlist(paths[c("profiles", "assignments", "defaults", "grid", "target_specs", "manifest")]))))
  expect_true(dir.exists(paths$prelaunch))

  profiles <- read.csv(paths$profiles, check.names = FALSE, stringsAsFactors = FALSE)
  assignments <- read.csv(paths$assignments, check.names = FALSE, stringsAsFactors = FALSE)
  grid <- read.csv(paths$grid, check.names = FALSE, stringsAsFactors = FALSE)
  target_specs <- read.csv(paths$target_specs, check.names = FALSE, stringsAsFactors = FALSE)
  defaults <- yaml::read_yaml(paths$defaults)
  manifest <- jsonlite::read_json(paths$manifest, simplifyVector = TRUE)

  expect_equal(nrow(profiles), 90L)
  expect_equal(nrow(assignments), 90L)
  expect_equal(nrow(grid), 90L)
  expect_equal(nrow(target_specs), 90L)
  expect_equal(length(unique(profiles$screening_profile_id)), 90L)
  expect_equal(length(unique(target_specs$spec_id)), 90L)
  expect_equal(length(unique(assignments$root_id)), 90L)

  cell_key <- paste(assignments$likelihood_target, assignments$family, sprintf("%.8f", assignments$tau), sep = "|")
  expect_equal(length(unique(cell_key)), 15L)
  expect_true(all(table(cell_key) == 6L))
  expect_setequal(assignments$likelihood_target, c("al", "exal"))
  expect_setequal(assignments$family, c("gausmix", "laplace", "normal"))
  expect_setequal(sprintf("%.2f", sort(unique(assignments$tau))), c("0.05", "0.25", "0.50"))
  expect_true(all(assignments$launch_status == "prepared_not_launched"))

  expect_identical(defaults$campaign$name, stage)
  expect_identical(defaults$execution$methods, "mcmc")
  expect_setequal(defaults$execution$likelihood_families, c("al", "exal"))
  expect_equal(length(defaults$execution$allowed_fit_spec_ids), 90L)
  expect_setequal(defaults$execution$allowed_fit_spec_ids, target_specs$spec_id)
  expect_equal(defaults$runtime$threads, 1L)
  expect_equal(defaults$runtime$workers, 16L)
  expect_equal(defaults$runtime$campaign_workers, 16L)
  expect_identical(defaults$runtime$root_scheduler, "load_balanced")

  expect_equal(defaults$study_contract$budget$mcmc_n_burn, 2000L)
  expect_equal(defaults$study_contract$budget$mcmc_n_mcmc, 8000L)
  expect_equal(defaults$study_contract$budget$mcmc_thin, 1L)
  expect_true(defaults$study_contract$mcmc$require_init_from_vb)
  expect_equal(defaults$study_contract$screening_policy$candidates_per_cell, 6L)
  expect_identical(defaults$study_contract$screening_policy$launch_status, "prepared_not_launched")
  expect_equal(defaults$study_contract$confirmation_budget$mcmc_n_burn, 5000L)
  expect_equal(defaults$study_contract$confirmation_budget$mcmc_n_mcmc, 20000L)
  expect_true(defaults$study_contract$confirmation_budget$required_before_article_promotion)

  expect_equal(defaults$pipeline$inference$mcmc$n_burn, 2000L)
  expect_equal(defaults$pipeline$inference$mcmc$n_mcmc, 8000L)
  expect_equal(defaults$pipeline$inference$mcmc$thin, 1L)
  expect_equal(defaults$pipeline$inference$mcmc$progress_every, 50L)
  expect_true(defaults$pipeline$inference$mcmc$init_from_vb)
  expect_equal(defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn, 2000L)
  expect_equal(defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc, 8000L)
  expect_equal(defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every, 50L)

  expect_false(defaults$pipeline$outputs$keep_draws)
  expect_false(defaults$pipeline$outputs$keep_mcmc_vb_init)
  expect_false(defaults$pipeline$outputs$save_forecast_objects)
  expect_false(defaults$pipeline$outputs$retain_full_rds_on_failure)
  expect_true(defaults$pipeline$outputs$save_compact_fit_paths)
  expect_true(defaults$pipeline$outputs$save_metric_summaries)

  expect_true(defaults$metrics$rolling_origin$enabled)
  expect_true(defaults$metrics$rolling_origin$require_lead_export)
  expect_equal(defaults$metrics$rolling_origin$max_lead_configured, 30L)
  expect_equal(defaults$metrics$rolling_origin$origin_stride, 30L)
  expect_equal(defaults$source_materialization$forecast_origin_source_index, 9000L)
  expect_equal(defaults$source_materialization$train_end_source_index, 9000L)
  expect_equal(defaults$source_materialization$forecast_horizon, 1000L)
  expect_equal(defaults$metrics$forecast_source_indices, c(9001L, 10000L))
  expect_equal(defaults$metrics$train_effective_source_indices$TT500, c(8501L, 9000L))

  expect_identical(manifest$stage_file, stage)
  expect_identical(manifest$launch_status, "prepared_not_launched")
  expect_identical(manifest$source_registry_hash, source_hash)
  expect_equal(manifest$counts$unresolved_cells, 15L)
  expect_equal(manifest$counts$candidates_per_cell, 6L)
  expect_equal(manifest$counts$profiles, 90L)
  expect_equal(manifest$counts$assignments, 90L)
  expect_equal(manifest$counts$selected_grid_roots, 90L)
  expect_equal(manifest$counts$target_mcmc_atomic_specs, 90L)

  prelaunch_manifest <- jsonlite::read_json(
    file.path(paths$prelaunch, "qdesn_tt500_mcmc_postv4_percell_prelaunch_manifest_20260727.json"),
    simplifyVector = TRUE
  )
  file_manifest <- read.csv(
    file.path(paths$prelaunch, "file_manifest.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  expect_identical(prelaunch_manifest$launch_status, "prepared_not_launched")
  expect_equal(prelaunch_manifest$counts$target_mcmc_atomic_specs, 90L)
  expect_true(all(file.exists(file_manifest$path)))
  expect_equal(unname(tools::sha256sum(file_manifest$path)), file_manifest$sha256)

  heavy <- list.files(
    paths$prelaunch,
    pattern = "[.](rds|rda|RData)$|__design[.]rds$",
    recursive = TRUE,
    full.names = TRUE
  )
  expect_length(heavy, 0L)

  config_text <- paste(
    c(
      readLines(paths$defaults, warn = FALSE),
      readLines(paths$manifest, warn = FALSE),
      readLines(file.path(paths$prelaunch, "README.md"), warn = FALSE)
    ),
    collapse = "\n"
  )
  expect_false(grepl("/home/jaguir26/local/src", config_text, fixed = TRUE))
  expect_false(grepl("Article-Q-DESN", config_text, fixed = TRUE))
})

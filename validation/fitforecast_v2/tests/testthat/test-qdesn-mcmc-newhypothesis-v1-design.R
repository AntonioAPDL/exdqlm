test_that("Q-DESN MCMC new-hypothesis v1 design is launchable and guarded", {
  root <- ffv2_repo_root()
  stage <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_newhypothesis_v1"
  promotion_id <- "qdesn_tt500_mcmc_newhypothesis_v1_design_20260729"
  source_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
  promo_root <- file.path(root, "validation", "fitforecast_v2", "promotions", promotion_id)

  expect_true(dir.exists(promo_root))

  read_table <- function(path) {
    read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  }
  path <- function(suffix) file.path(promo_root, paste0(promotion_id, suffix))

  defaults_path <- file.path(root, "config", "validation", paste0(stage, "_defaults.yaml"))
  profiles_path <- file.path(root, "config", "validation", paste0(stage, "_profiles.csv"))
  assignments_path <- file.path(root, "config", "validation", paste0(stage, "_cell_assignments.csv"))
  grid_path <- file.path(root, "config", "validation", paste0(stage, "_grid.csv"))
  targets_path <- file.path(root, "config", "validation", paste0(stage, "_target_spec_ids.csv"))
  manifest_path <- file.path(root, "config", "validation", paste0(stage, "_materialization_manifest.json"))
  doc_path <- file.path(root, "validation", "fitforecast_v2", "docs", "QDESN_500OBS_MCMC_NEWHYPOTHESIS_V1_OVERNIGHT_PLAN_2026-07-29.md")

  expect_true(file.exists(defaults_path))
  expect_true(file.exists(profiles_path))
  expect_true(file.exists(assignments_path))
  expect_true(file.exists(grid_path))
  expect_true(file.exists(targets_path))
  expect_true(file.exists(manifest_path))
  expect_true(file.exists(doc_path))

  defaults <- yaml::read_yaml(defaults_path)
  profiles <- read_table(profiles_path)
  assignments <- read_table(assignments_path)
  grid <- read_table(grid_path)
  targets <- read_table(targets_path)
  summary <- read_table(path("_summary.csv"))
  handoff <- read_table(path("_parent_handoff_snapshot.csv"))
  design <- read_table(path("_candidate_arm_design.csv"))
  nonrepeat <- read_table(path("_nonrepeat_audit.csv"))
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
  file_manifest <- read_table(file.path(promo_root, "file_manifest.csv"))
  source_manifest <- read_table(file.path(promo_root, "source_manifest.csv"))

  expect_equal(nrow(summary), 1L)
  expect_identical(summary$promotion_id[[1L]], promotion_id)
  expect_identical(summary$parent_closeout_id[[1L]], "qdesn_tt500_mcmc_postv4_percell_closeout_20260728")
  expect_identical(summary$source_registry_hash_value[[1L]], source_hash)
  expect_equal(summary$unresolved_cells[[1L]], 15L)
  expect_equal(summary$candidate_arm_rows[[1L]], 96L)
  expect_equal(summary$selected_target_specs[[1L]], 96L)
  expect_lte(summary$max_p_over_n_tt500[[1L]], 0.35)
  expect_equal(summary$max_m[[1L]], 90L)
  expect_equal(summary$max_readout_y_lags[[1L]], 90L)
  expect_equal(summary$mcmc_n_burn[[1L]], 2000L)
  expect_equal(summary$mcmc_n_mcmc[[1L]], 8000L)
  expect_identical(summary$article_update_decision[[1L]], "do_not_update_article_from_screening_design_or_raw_launch")

  expect_equal(nrow(handoff), 15L)
  expect_equal(nrow(unique(handoff[c("model_variant", "family", "tau", "fit_size")])), 15L)
  expect_true(all(handoff$source_registry_hash_value == source_hash))

  expect_equal(nrow(profiles), 96L)
  expect_equal(nrow(assignments), 96L)
  expect_equal(nrow(grid), 96L)
  expect_equal(nrow(targets), 96L)
  expect_equal(anyDuplicated(profiles$screening_profile_id), 0L)
  expect_equal(anyDuplicated(assignments$assignment_key), 0L)
  expect_equal(anyDuplicated(targets$spec_id), 0L)
  expect_equal(nrow(unique(assignments[c("family", "tau", "likelihood_target")])), 15L)
  expect_true(all(table(paste(assignments$family, assignments$tau, assignments$likelihood_target, sep = "|")) %in% c(6L, 7L)))
  expect_equal(sum(table(paste(assignments$family, assignments$tau, assignments$likelihood_target, sep = "|")) == 7L), 6L)
  expect_equal(sum(table(paste(assignments$family, assignments$tau, assignments$likelihood_target, sep = "|")) == 6L), 9L)

  expect_true(all(profiles$m <= 90L))
  expect_true(all(profiles$readout_y_lags <= 90L))
  expect_lte(max(profiles$p_over_n_tt500), 0.35)
  expect_true(any(profiles$reservoir_lags == 1L))
  expect_true(any(profiles$m == 90L))
  expect_true(any(profiles$D == 3L))
  expect_true(all(profiles$rhs_tau0 %in% c(2e-8, 7e-8, 2e-7, 7e-7)))
  expect_true(all(grepl("^nhv1_", profiles$screening_profile_id)))

  expect_equal(nrow(design), 96L)
  expect_true(all(design$launch_status == "materialized_launchable_pending_smoke"))
  expect_equal(nrow(nonrepeat), 96L)
  expect_true(all(nonrepeat$nonrepeat_status == "PASS"))
  expect_true(all(!nonrepeat$exact_prior_target_duplicate))

  expect_equal(defaults$campaign$name, stage)
  expect_equal(defaults$runtime$root_scheduler, "load_balanced")
  expect_equal(as.integer(defaults$runtime$workers), 16L)
  expect_equal(as.integer(defaults$study_contract$budget$mcmc_n_burn), 2000L)
  expect_equal(as.integer(defaults$study_contract$budget$mcmc_n_mcmc), 8000L)
  expect_equal(as.integer(defaults$pipeline$inference$mcmc$progress_every), 50L)
  expect_true(isTRUE(defaults$pipeline$inference$mcmc$init_from_vb))
  expect_equal(length(defaults$execution$allowed_fit_spec_ids), 96L)
  expect_equal(as.integer(defaults$smoke$budget$mcmc_n_burn), 4L)
  expect_equal(as.integer(defaults$smoke$budget$mcmc_n_mcmc), 4L)

  expect_identical(manifest$stage, stage)
  expect_identical(manifest$promotion_id, promotion_id)
  expect_identical(manifest$source_registry_hash_value, source_hash)
  expect_equal(as.integer(manifest$counts$unresolved_cells), 15L)
  expect_equal(as.integer(manifest$counts$target_specs), 96L)
  expect_lte(as.numeric(manifest$constraints$max_p_over_n_tt500), 0.35)
  expect_identical(manifest$article_update_decision, "do_not_update_article_from_screening_design_or_raw_launch")

  expect_true(all(file.exists(file_manifest$path)))
  expect_equal(unname(tools::sha256sum(file_manifest$path)), file_manifest$sha256)
  expect_true(all(file.exists(source_manifest$path)))
  expect_equal(unname(tools::sha256sum(source_manifest$path)), source_manifest$sha256)

  all_text <- paste(capture.output(str(list(
    defaults = defaults,
    profiles = profiles,
    assignments = assignments,
    grid = grid,
    targets = targets,
    summary = summary,
    manifest = manifest
  ))), collapse = "\n")
  expect_false(grepl("/home/jaguir26/local/src", all_text, fixed = TRUE))
  expect_false(grepl("Article-Q-DESN", all_text, fixed = TRUE))

  heavy <- list.files(
    c(dirname(defaults_path), promo_root),
    pattern = "[.](rds|rda|RData)$|__design[.]rds$",
    recursive = TRUE,
    full.names = TRUE
  )
  heavy <- heavy[grepl("newhypothesis_v1|qdesn_tt500_mcmc_newhypothesis_v1", heavy)]
  expect_length(heavy, 0L)
})

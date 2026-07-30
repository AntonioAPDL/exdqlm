test_that("nested final-origin evidence freeze is immutable and explicit", {
  root <- ffv2_repo_root()
  freeze_id <- paste0(
    "qdesn_500obs_mcmc_nested_final_origin9000_v1_",
    "evidence_freeze_20260730"
  )
  freeze_root <- file.path(
    root, "validation", "fitforecast_v2", "promotions", freeze_id
  )
  manifest_path <- file.path(freeze_root, "evidence_freeze_manifest.json")
  run_path <- file.path(freeze_root, "run_disposition.csv")
  origin_path <- file.path(freeze_root, "origin_disposition.csv")
  ledger_path <- file.path(freeze_root, "frozen_evidence_ledger.csv")
  readme_path <- file.path(freeze_root, "README.md")
  expected_paths <- c(
    manifest_path, run_path, origin_path, ledger_path, readme_path
  )
  expect_true(all(file.exists(expected_paths)))

  manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
  runs <- read.csv(run_path, check.names = FALSE, stringsAsFactors = FALSE)
  origins <- read.csv(
    origin_path, check.names = FALSE, stringsAsFactors = FALSE
  )
  ledger <- read.csv(
    ledger_path, check.names = FALSE, stringsAsFactors = FALSE
  )

  expect_identical(manifest$freeze_id, freeze_id)
  expect_identical(
    manifest$frozen_evidence_git_sha,
    "a02b93bee8cb52c273d989f455f8e7e3fd962f69"
  )
  expect_identical(manifest$package_version, "1.0.0")
  expect_identical(manifest$authority_contract_version, "1.0.0")
  expect_identical(
    manifest$authoritative_numeric_promotion_id,
    "qdesn_dqlm_500obs_mcmc_metric_envelope_20260727"
  )
  expect_equal(as.integer(manifest$authoritative_numeric_row_count), 36L)
  expect_equal(as.integer(manifest$authoritative_candidate_row_count), 129L)
  expect_equal(
    as.integer(manifest$authoritative_displayed_metric_count),
    108L
  )
  expect_identical(
    manifest$source_registry_hash_value,
    "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
  )
  expect_identical(
    manifest$scientific_decision,
    "NO_CONFIRMED_COHERENT_ARTICLE_REFRESH"
  )
  expect_equal(as.integer(manifest$coherent_promotion_cells), 0L)
  expect_equal(as.integer(manifest$article_refresh_metric_rows), 0L)
  expect_false(isTRUE(manifest$origin_9000_untouched_confirmation_eligible))
  expect_identical(
    manifest$article_update_policy,
    "KEEP_CURRENT_ARTICLE_PARENT_ROWS_UNCHANGED"
  )
  expect_identical(
    manifest$article_numeric_state,
    "UNCHANGED_FROM_20260727_AUTHORITY"
  )

  authority_entries <- list(
    manifest$authoritative_numeric_article_envelope,
    manifest$authoritative_numeric_manifest,
    manifest$authoritative_coherent_confirmation
  )
  authority_paths <- vapply(
    authority_entries,
    function(entry) file.path(root, entry$path_relative),
    character(1L)
  )
  authority_hashes <- vapply(
    authority_entries,
    function(entry) entry$sha256,
    character(1L)
  )
  expect_true(all(file.exists(authority_paths)))
  expect_equal(
    unname(tools::sha256sum(authority_paths)),
    unname(authority_hashes)
  )
  envelope <- read.csv(
    authority_paths[[1L]],
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  expect_equal(nrow(envelope), 36L)
  expect_equal(
    nrow(unique(envelope[c("model_variant", "family", "tau")])),
    36L
  )
  numeric_manifest <- jsonlite::read_json(
    authority_paths[[2L]],
    simplifyVector = TRUE
  )
  expect_equal(as.integer(numeric_manifest$n_candidates), 129L)
  expect_equal(as.integer(numeric_manifest$n_envelope_rows), 36L)
  expect_false(isTRUE(numeric_manifest$displayed_envelope_changed))

  valid_tag <- paste0(
    "qdesn-500obs-mcmc-nested-final-o9000-v1-full-",
    "20260730__git-bd4da62"
  )
  invalid_tag <- paste0(
    "qdesn-500obs-mcmc-nested-final-o9000-v1-full-",
    "20260730__git-6582f87"
  )
  expect_identical(
    unname(manifest$consumable_scientific_run_tags), valid_tag
  )
  expect_identical(
    unname(manifest$permanently_rejected_run_tags), invalid_tag
  )
  expect_equal(sum(runs$scientific_evidence), 1L)
  expect_equal(sum(runs$consumable), 1L)
  expect_identical(runs$run_tag[runs$consumable], valid_tag)
  expect_identical(
    runs$evidence_role[runs$consumable],
    "FROZEN_NEGATIVE_CONFIRMATION"
  )
  invalid <- runs[runs$run_tag == invalid_tag, , drop = FALSE]
  expect_equal(nrow(invalid), 1L)
  expect_false(invalid$consumable[[1L]])
  expect_identical(invalid$state[[1L]], "ABORTED_INVALID_CONTRACT")

  expect_equal(nrow(origins), 1L)
  expect_equal(origins$origin_source_index[[1L]], 9000L)
  expect_equal(origins$train_start_source_index[[1L]], 8501L)
  expect_equal(origins$train_end_source_index[[1L]], 9000L)
  expect_equal(origins$forecast_start_source_index[[1L]], 9001L)
  expect_equal(origins$forecast_end_source_index[[1L]], 10000L)
  expect_identical(
    origins$state[[1L]], "EXPOSED_FINAL_CONFIRMATION"
  )
  expect_false(origins$untouched_confirmation_eligible[[1L]])

  evidence_paths <- file.path(root, ledger$path_relative)
  expect_true(all(file.exists(evidence_paths)))
  expect_equal(
    unname(tools::sha256sum(evidence_paths)),
    ledger$sha256
  )
  expect_setequal(
    ledger$role[grepl("^article_", ledger$role)],
    c(
      "article_numeric_envelope",
      "article_numeric_manifest",
      "article_coherent_confirmation"
    )
  )
  bundle_paths <- c(
    readme_path, run_path, origin_path, ledger_path
  )
  bundle_hashes <- c(
    manifest$bundle_hashes$readme_sha256,
    manifest$bundle_hashes$run_disposition_sha256,
    manifest$bundle_hashes$origin_disposition_sha256,
    manifest$bundle_hashes$frozen_evidence_ledger_sha256
  )
  expect_equal(
    unname(tools::sha256sum(bundle_paths)),
    unname(bundle_hashes)
  )

  heavy <- list.files(
    freeze_root,
    pattern = "[.](rds|rda|RData)$|__design[.]rds$",
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE
  )
  expect_length(heavy, 0L)
})

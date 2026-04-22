`%||%` <- function(a, b) if (is.null(a)) b else a

test_that("candidate dataset generator and audit inventory work on a minimal temporary bundle", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  manifest <- exdqlm:::qdesn_dynamic_candidate_load_manifest(
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_manifest.yaml"),
    repo_root = repo_root
  )

  tmp_source_parent <- tempfile("candidate_source_", fileext = "")
  tmp_qdesn_parent <- tempfile("candidate_qdesn_", fileext = "")
  dir.create(tmp_source_parent, recursive = TRUE, showWarnings = FALSE)
  dir.create(tmp_qdesn_parent, recursive = TRUE, showWarnings = FALSE)

  manifest$meta$scenario_id <- "dlm_constV_p90_m0amp_highnoise_test"
  manifest$generation$output_parent <- tmp_source_parent
  manifest$generation$families <- list("normal")
  manifest$generation$taus <- list(0.25)
  manifest$generation$TT_total <- 900L
  manifest$generation$TT_warmup <- 200L
  manifest$generation$TT_main <- 700L
  manifest$generation$tail_fit_sizes <- list(50, 100)
  manifest$qdesn_materialization$staged_root <- tmp_qdesn_parent

  bundle <- exdqlm:::qdesn_dynamic_candidate_generate_bundle(
    manifest = manifest,
    repo_root = repo_root,
    refresh = TRUE,
    verbose = FALSE
  )
  expect_identical(nrow(bundle$root_inventory), 1L)
  expect_identical(sort(bundle$slice_inventory$fit_size), c(50L, 100L))

  defaults <- exdqlm:::qdesn_validation_load_defaults(
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_candidate_materialization_defaults.yaml"),
    repo_root = repo_root
  )
  defaults$source_materialization$dynamic_root <- tmp_source_parent
  defaults$source_materialization$staged_root <- tmp_qdesn_parent
  defaults$source_materialization$scenarios <- list("dlm_constV_p90_m0amp_highnoise_test")
  defaults$source_materialization$families <- list("normal")
  defaults$source_materialization$taus <- list(0.25)
  defaults$source_materialization$windows <- list(
    list(effective_fit_size = 50, source_total_size = 363, source_dir_name = "fit_input_effTT50_totalTT363", label = "effTT50_totalTT363"),
    list(effective_fit_size = 100, source_total_size = 413, source_dir_name = "fit_input_effTT100_totalTT413", label = "effTT100_totalTT413")
  )
  defaults$reference_contract$scenarios <- list("dlm_constV_p90_m0amp_highnoise_test")
  defaults$reference_contract$families <- list("normal")
  defaults$reference_contract$taus <- list(0.25)
  defaults$reference_contract$fit_sizes <- list(50, 100)
  materialized <- exdqlm:::qdesn_dynamic_crossstudy_materialize_source_inputs(defaults, refresh = TRUE, verbose = FALSE)
  expect_identical(nrow(materialized), 2L)

  audit_manifest <- exdqlm:::qdesn_dynamic_candidate_audit_load_manifest(
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_audit_manifest.yaml"),
    repo_root = repo_root
  )
  audit_manifest$analysis$source_root_parent <- tmp_source_parent
  audit_manifest$analysis$scenario_id <- "dlm_constV_p90_m0amp_highnoise_test"
  audit_manifest$analysis$qdesn_materialized_root <- tmp_qdesn_parent
  audit_manifest$selection$families <- list("normal")
  audit_manifest$selection$taus <- list(0.25)
  audit_manifest$selection$fit_sizes <- list(50, 100)

  state <- exdqlm:::.qdesn_dynamic_candidate_audit_resolve_state(audit_manifest, repo_root = repo_root)
  inventory <- exdqlm:::qdesn_dynamic_candidate_audit_build_inventory(audit_manifest, state, repo_root = repo_root)
  expect_identical(nrow(inventory), 4L)
  expect_true(all(file.exists(inventory$observed_path)))
})

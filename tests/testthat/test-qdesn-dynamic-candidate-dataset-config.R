`%||%` <- function(a, b) if (is.null(a)) b else a

test_that("candidate dynamic dataset manifest loads and materialization contract is coherent", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  manifest <- exdqlm:::qdesn_dynamic_candidate_load_manifest(
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_manifest.yaml"),
    repo_root = repo_root
  )
  state <- exdqlm:::.qdesn_dynamic_candidate_resolve_state(manifest, repo_root = repo_root)

  expect_match(state$scenario_id, "dlm_constV_p90_m0amp_highnoise_steepertrend_v1")
  expect_true(grepl("dynamic_exdqlm_crossstudy_candidate_sources", state$source_parent, fixed = TRUE))

  material_defaults <- exdqlm:::qdesn_validation_load_defaults(
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_candidate_materialization_defaults.yaml"),
    repo_root = repo_root
  )
  windows <- exdqlm:::.qdesn_dynamic_crossstudy_materialization_windows(material_defaults)
  expect_identical(unname(sort(vapply(windows, `[[`, integer(1), "effective_fit_size"))), c(500L, 5000L))
  expect_identical(unname(sort(vapply(windows, `[[`, integer(1), "source_total_size"))), c(813L, 5313L))
})

test_that("candidate helper builds a 6-state period-90 dynamic model cleanly", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  helper_env <- exdqlm:::.qdesn_dynamic_candidate_helper_env(repo_root = repo_root, reload = TRUE)

  m0 <- helper_env$dynamic_dgp_make_m0(
    level0 = 40,
    slope0 = 0.005,
    seasonal_amplitudes = c(24, 8),
    seasonal_phases = c(0.35, -0.8)
  )
  model <- helper_env$build_dynamic_dgp_matched_model(
    list(period = 90L, harmonics = c(1L, 2L), m0 = m0, C0_scale = 0.01),
    TT = 24L,
    backend = "R"
  )

  expect_s3_class(model, "exdqlm")
  expect_identical(dim(model$FF), c(6L, 1L))
  expect_identical(dim(model$GG), c(6L, 6L))
  expect_equal(as.numeric(model$m0), m0)
  expect_equal(model$C0, diag(0.01, 6L))
  expect_equal(model$GG[1:2, 1:2], matrix(c(1, 1, 0, 1), nrow = 2, byrow = TRUE))
})

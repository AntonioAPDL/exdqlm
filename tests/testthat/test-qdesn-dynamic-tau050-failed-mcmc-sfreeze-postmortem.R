test_that("sfreeze remaining-hard-fail materializer reproduces the checked-in hard-fail grids", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  results_root <- file.path(
    repo_root,
    "results",
    "qdesn_mcmc_validation",
    "dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_validation"
  )
  skip_if_not(dir.exists(results_root))

  al_out <- tempfile("failed_mcmc_sfreeze_remaining_al_", fileext = ".csv")
  exal_out <- tempfile("failed_mcmc_sfreeze_remaining_exal_", fileext = ".csv")
  script_path <- file.path(
    repo_root,
    "scripts",
    "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_remaining_hard_fail_grids.R"
  )

  status <- system2(
    "Rscript",
    c(
      script_path,
      "--mcmc-al-output", al_out,
      "--mcmc-exal-output", exal_out
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  exit_status <- attr(status, "status", exact = TRUE)
  if (is.null(exit_status)) exit_status <- 0L
  expect_identical(as.integer(exit_status), 0L)

  checked_al <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_remaining_hard_fail_al_grid.csv"
  ))
  checked_exal <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_remaining_hard_fail_exal_grid.csv"
  ))
  materialized_al <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(al_out)
  materialized_exal <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(exal_out)

  expect_identical(sort(materialized_al$root_id), sort(checked_al$root_id))
  expect_identical(sort(materialized_exal$root_id), sort(checked_exal$root_id))
})

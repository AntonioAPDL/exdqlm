test_that("failed-mcmc materializer reproduces the checked-in failed-only grids when source run exists", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  source_root <- file.path(
    repo_root,
    "results",
    "qdesn_mcmc_validation",
    "dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation",
    "qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674"
  )
  skip_if_not(dir.exists(source_root))

  al_out <- tempfile("failed_mcmc_al_", fileext = ".csv")
  exal_out <- tempfile("failed_mcmc_exal_", fileext = ".csv")
  script_path <- file.path(
    repo_root,
    "scripts",
    "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_grids.R"
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
    "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_al_grid.csv"
  ))
  checked_exal <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_exal_grid.csv"
  ))
  materialized_al <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(al_out)
  materialized_exal <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(exal_out)

  expect_identical(sort(materialized_al$root_id), sort(checked_al$root_id))
  expect_identical(sort(materialized_exal$root_id), sort(checked_exal$root_id))
})

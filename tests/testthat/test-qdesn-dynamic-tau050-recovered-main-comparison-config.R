`%||%` <- function(a, b) if (is.null(a)) b else a

test_that("tau050 recovered main comparison override materializer covers the original FAIL surface", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  script_path <- file.path(
    repo_root,
    "scripts",
    "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_recovered_main_comparison_overrides.R"
  )
  override_csv <- tempfile("tau050_recovered_maincmp_", fileext = ".csv")

  output <- system2(
    "Rscript",
    c(script_path, "--output", override_csv),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(output, "status", exact = TRUE) %||% 0L
  expect_identical(as.integer(status), 0L, info = paste(output, collapse = "\n"))

  override_dt <- utils::read.csv(override_csv, stringsAsFactors = FALSE)
  expect_identical(nrow(override_dt), 23L)
  expect_true(all(as.character(override_dt$status) == "SUCCESS"))
  expect_identical(
    length(unique(paste(override_dt$root_id, override_dt$inference, override_dt$model, sep = "||"))),
    23L
  )
  expect_true(all(file.exists(override_dt$fit_summary_path)))
  expect_true(all(file.exists(override_dt$root_summary_path)))
  expect_true(all(c("sfreeze_al", "sfreeze_exal") %in% override_dt$source_wave))
  expect_true(any(grepl("^remaining_hard_fail_", override_dt$source_wave)))
  expect_true(all(c("remaining_precision_closeout_al_ladder_v2", "remaining_precision_closeout_exal_ladder_v2") %in% override_dt$source_wave))

  overrides <- exdqlm:::qdesn_dynamic_maincmp_load_root_profile_overrides_csv(override_csv)
  expect_identical(length(overrides), 23L)

  defaults_path <- file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"
  )
  grid_path <- file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.csv"
  )

  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
  grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(grid_path)
  source_state <- exdqlm:::qdesn_dynamic_crossstudy_fitfail_collect_source_state(
    source_run_tag = "qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674",
    source_report_root = file.path(
      repo_root,
      "reports",
      "qdesn_mcmc_validation",
      "dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation"
    ),
    source_mode = "dynamic_campaign",
    source_root_profile_overrides = overrides,
    defaults = defaults,
    grid = grid,
    defaults_path = defaults_path,
    grid_path = grid_path
  )

  expect_identical(nrow(source_state$fit_summary), 144L)
  expect_identical(sum(as.character(source_state$fit_summary$status) == "FAIL", na.rm = TRUE), 0L)
  expect_identical(sum(as.character(source_state$root_summary$root_status) == "FAIL", na.rm = TRUE), 0L)
  expect_identical(nrow(source_state$root_override_map), 23L)
})

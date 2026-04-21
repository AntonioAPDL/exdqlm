`%||%` <- function(a, b) if (is.null(a)) b else a

test_that("tau050 recovered study-facing analysis pack is reproducible from the canonical recovered comparison root", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  manifest_path <- file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_recovered_study_facing_analysis_manifest.yaml"
  )

  manifest <- exdqlm:::qdesn_dynamic_studyfacing_load_manifest(manifest_path)
  comparison_root <- exdqlm:::`.qdesn_dynamic_studyfacing_resolve_comparison_root`(manifest, repo_root = repo_root)
  source_state <- exdqlm:::qdesn_dynamic_studyfacing_load_source_state(comparison_root)

  expect_identical(nrow(source_state$fit_summary), 144L)
  expect_identical(sum(as.character(source_state$fit_summary$status) == "FAIL", na.rm = TRUE), 0L)
  expect_identical(nrow(source_state$representative_case_table), 36L)
  expect_identical(sum(as.character(source_state$representative_case_table$signoff_grade) == "FAIL", na.rm = TRUE), 0L)
  expect_true(all(as.character(source_state$representative_case_table$inference) == "vb"))

  out_root <- tempfile("tau050_studyfacing_", fileext = "")
  analysis_obj <- exdqlm:::qdesn_dynamic_studyfacing_write_analysis(
    source_state = source_state,
    output_root = out_root,
    manifest = manifest
  )

  overview <- utils::read.csv(file.path(out_root, "tables", "study_analysis_overview.csv"), stringsAsFactors = FALSE)
  metric_value <- function(metric) suppressWarnings(as.numeric(overview$value[overview$metric == metric][1L] %||% NA_real_))

  expect_identical(metric_value("source_fit_rows_total"), 144)
  expect_identical(metric_value("source_runtime_fail_n"), 0)
  expect_identical(metric_value("representative_case_rows"), 36)
  expect_identical(metric_value("representative_fail_n"), 0)
  expect_identical(metric_value("representative_reference_aligned_n"), 24)
  expect_identical(metric_value("representative_reference_gap_n"), 12)

  expect_true(file.exists(file.path(out_root, "summary", "qdesn_tau050_recovered_study_facing_analysis.md")))
  expect_true(file.exists(file.path(out_root, "summary", "qdesn_tau050_representative_case_table.md")))
  expect_identical(nrow(analysis_obj$representative_reference_gap_inventory), 12L)
})

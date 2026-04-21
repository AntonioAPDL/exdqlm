`%||%` <- function(a, b) if (is.null(a)) b else a

test_that("tau050 final analysis pack is reproducible from the canonical study-facing root", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  manifest_path <- file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_final_analysis_pack_manifest.yaml"
  )

  manifest <- exdqlm:::qdesn_dynamic_finalpack_load_manifest(manifest_path)
  study_facing_root <- exdqlm:::`.qdesn_dynamic_finalpack_resolve_studyfacing_root`(manifest, repo_root = repo_root)
  source_state <- exdqlm:::qdesn_dynamic_finalpack_load_source_state(study_facing_root)

  expect_identical(nrow(source_state$representative_case_table), 36L)
  expect_identical(sum(as.character(source_state$representative_case_table$signoff_grade) == "FAIL", na.rm = TRUE), 0L)
  expect_identical(nrow(source_state$comparison_state$fit_summary), 144L)
  expect_identical(sum(as.character(source_state$comparison_state$fit_summary$status) == "FAIL", na.rm = TRUE), 0L)

  out_root <- tempfile("tau050_finalpack_", fileext = "")
  analysis_obj <- exdqlm:::qdesn_dynamic_finalpack_write_analysis(
    source_state = source_state,
    output_root = out_root,
    manifest = manifest
  )

  overview <- utils::read.csv(file.path(out_root, "tables", "final_surface_scorecard.csv"), stringsAsFactors = FALSE)
  decision <- utils::read.csv(file.path(out_root, "tables", "final_reference_alignment_decision.csv"), stringsAsFactors = FALSE)
  figure_index <- utils::read.csv(file.path(out_root, "tables", "final_figure_index.csv"), stringsAsFactors = FALSE)

  expect_true(any(overview$surface == "representative_surface"))
  expect_true(any(overview$surface == "aligned_reference_surface"))
  expect_true(any(overview$surface == "full_recovered_fit_inventory"))
  expect_identical(decision$decision_code[1L], "do_not_launch_now")
  expect_true(file.exists(file.path(out_root, "summary", "qdesn_tau050_final_analysis_report.md")))
  expect_true(file.exists(file.path(out_root, "summary", "qdesn_tau050_final_diagnostic_appendix.md")))
  expect_true(file.exists(file.path(out_root, "summary", "qdesn_tau050_strict_reference_alignment_decision.md")))
  expect_true(all(file.exists(file.path(out_root, figure_index$rel_path))))
  expect_identical(nrow(analysis_obj$representative_case_table_condensed), 36L)
})

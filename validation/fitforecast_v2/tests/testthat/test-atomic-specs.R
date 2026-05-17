test_that("prepared exDQLM/DQLM manifests have stable atomic specs and handoff paths", {
  defaults <- ffv2_test_defaults()
  ffv2_test_write_sources(defaults)
  registry <- ffv2_collect_source_registry(defaults, require_sources = TRUE)
  manifest <- ffv2_prepare_manifest(defaults, registry, dry_run = TRUE)

  expect_true("spec_id" %in% names(manifest))
  expect_true("fit_handoff_path" %in% names(manifest))
  expect_true("vb_init_handoff_path" %in% names(manifest))
  expect_equal(length(unique(manifest$spec_id)), nrow(manifest))
  expect_false(any(grepl("[.]rds$", manifest$fit_handoff_path, ignore.case = TRUE)))
  expect_false(any(grepl("[.]rds$", manifest$vb_init_handoff_path, ignore.case = TRUE)))

  one <- manifest[1L, , drop = FALSE]
  selected <- ffv2_select_manifest_rows(
    manifest,
    phase = "all",
    selectors = list(spec_ids = one$spec_id)
  )
  expect_equal(nrow(selected), 1L)
  expect_identical(selected$spec_id, one$spec_id)
})

test_that("run-specific overrides apply by spec_id without changing other rows", {
  defaults <- ffv2_test_defaults()
  ffv2_test_write_sources(defaults)
  registry <- ffv2_collect_source_registry(defaults, require_sources = TRUE)
  manifest <- ffv2_prepare_manifest(defaults, registry, dry_run = TRUE)
  target <- manifest[1L, , drop = FALSE]
  overrides <- list(
    specs = structure(
      list(list(
        id = "tiny-vb-repair",
        reason = "targeted rerun budget",
        budget = list(vb = list(max_iter = 7L)),
        runtime = list(progress_every = 3L)
      )),
      names = target$spec_id
    )
  )

  cfg <- as.list(target)
  cfg$budget <- defaults$budget
  cfg$runtime <- defaults$runtime
  cfg <- ffv2_apply_row_override(cfg, ffv2_override_for_spec(overrides, target$spec_id, target))

  expect_true(isTRUE(cfg$run_override_applied))
  expect_equal(cfg$run_override_id, "tiny-vb-repair")
  expect_equal(as.integer(cfg$budget$vb$max_iter), 7L)
  expect_equal(as.integer(cfg$runtime$progress_every), 3L)
})

test_that("stage handoffs are explicit, hash-checked, and prunable", {
  root <- tempfile("ffv2_handoff_")
  dir.create(root)
  config <- list(
    spec_id = "spec-test",
    row_id = 1L,
    row_key = "row_0001",
    run_tag = "test"
  )
  path <- file.path(root, "row_0001_fit_object.ffv2handoff")
  manifest_path <- file.path(root, "row_0001_fit_object_manifest.json")
  ffv2_save_handoff(list(a = 1), path, manifest_path, role = "fit", config = config)
  expect_true(file.exists(path))
  expect_true(file.exists(manifest_path))
  expect_equal(ffv2_read_handoff(path, manifest_path, expected_role = "fit")$a, 1)
  ffv2_prune_handoff(path, manifest_path)
  expect_false(file.exists(path))
  manifest <- ffv2_read_json(manifest_path)
  expect_false(isTRUE(manifest$path_exists_after_prune))
})

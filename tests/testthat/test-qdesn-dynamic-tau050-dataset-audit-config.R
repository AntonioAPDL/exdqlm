`%||%` <- function(a, b) if (is.null(a)) b else a

test_that("tau050 dataset audit manifest resolves the full 36-dataset source surface", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  manifest_path <- file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_dataset_audit_manifest.yaml"
  )

  manifest <- exdqlm:::qdesn_dynamic_datasetaudit_load_manifest(manifest_path)
  state <- exdqlm:::.qdesn_dynamic_datasetaudit_resolve_state(manifest, repo_root = repo_root)
  inventory <- exdqlm:::qdesn_dynamic_datasetaudit_build_inventory(
    manifest = manifest,
    state = state,
    repo_root = repo_root
  )

  expect_identical(nrow(inventory), 36L)
  expect_true(all(!grepl("/", inventory$png_file, fixed = TRUE)))
  expect_identical(length(unique(inventory$png_file)), 36L)
  expect_true(all(file.exists(inventory$observed_path)))
})

test_that("tau050 dataset audit can render a single flat PNG cleanly", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  manifest_path <- file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_dataset_audit_manifest.yaml"
  )

  manifest <- exdqlm:::qdesn_dynamic_datasetaudit_load_manifest(manifest_path)
  state <- exdqlm:::.qdesn_dynamic_datasetaudit_resolve_state(manifest, repo_root = repo_root)
  inventory <- exdqlm:::qdesn_dynamic_datasetaudit_build_inventory(
    manifest = manifest,
    state = state,
    repo_root = repo_root
  )

  out_root <- tempfile("tau050_dataset_audit_", fileext = "")
  dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
  one <- inventory[1L, , drop = FALSE]
  render_row <- exdqlm:::.qdesn_dynamic_datasetaudit_plot_one(
    row = one,
    output_root = out_root,
    manifest = manifest
  )

  expect_identical(render_row$root_id[1L], one$root_id[1L])
  expect_true(file.exists(file.path(out_root, one$png_file[1L])))
})


`%||%` <- function(a, b) if (is.null(a)) b else a

test_that("candidate last5000/last500 audit inventory resolves the 9 family-by-tau roots", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  tmp_source_parent <- tempfile("candidate_p90_source_", fileext = "")
  dir.create(tmp_source_parent, recursive = TRUE, showWarnings = FALSE)

  gen_manifest <- exdqlm:::qdesn_dynamic_candidate_load_manifest(
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_manifest.yaml"),
    repo_root = repo_root
  )
  gen_manifest$meta$scenario_id <- "dlm_constV_p90_m0amp_highnoise_test5000"
  gen_manifest$generation$output_parent <- tmp_source_parent
  gen_manifest$generation$families <- list("normal")
  gen_manifest$generation$taus <- list(0.25)
  gen_manifest$generation$TT_total <- 900L
  gen_manifest$generation$TT_warmup <- 200L
  gen_manifest$generation$TT_main <- 700L
  gen_manifest$generation$tail_fit_sizes <- list(500, 600)

  exdqlm:::qdesn_dynamic_candidate_generate_bundle(
    manifest = gen_manifest,
    repo_root = repo_root,
    refresh = TRUE,
    verbose = FALSE
  )

  manifest <- exdqlm:::qdesn_dynamic_candidate_5000_500_audit_load_manifest(
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_candidate_last5000_last500_audit_manifest.yaml"),
    repo_root = repo_root
  )
  manifest$analysis$source_root_parent <- tmp_source_parent
  manifest$analysis$scenario_id <- "dlm_constV_p90_m0amp_highnoise_test5000"
  manifest$selection$families <- list("normal")
  manifest$selection$taus <- list(0.25)
  state <- exdqlm:::.qdesn_dynamic_candidate_5000_500_audit_resolve_state(manifest, repo_root = repo_root)
  inventory <- exdqlm:::.qdesn_dynamic_candidate_5000_500_audit_build_inventory(manifest, state = state, repo_root = repo_root)

  expect_identical(nrow(inventory), 1L)
  expect_true(all(file.exists(inventory$series_wide_path)))
  expect_true(all(!grepl("/", inventory$png_file, fixed = TRUE)))
})

test_that("candidate last5000/last500 audit can render one PNG cleanly", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  tmp_source_parent <- tempfile("candidate_p90_source_", fileext = "")
  dir.create(tmp_source_parent, recursive = TRUE, showWarnings = FALSE)

  gen_manifest <- exdqlm:::qdesn_dynamic_candidate_load_manifest(
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_manifest.yaml"),
    repo_root = repo_root
  )
  gen_manifest$meta$scenario_id <- "dlm_constV_p90_m0amp_highnoise_test5000"
  gen_manifest$generation$output_parent <- tmp_source_parent
  gen_manifest$generation$families <- list("normal")
  gen_manifest$generation$taus <- list(0.25)
  gen_manifest$generation$TT_total <- 900L
  gen_manifest$generation$TT_warmup <- 200L
  gen_manifest$generation$TT_main <- 700L
  gen_manifest$generation$tail_fit_sizes <- list(500, 600)

  exdqlm:::qdesn_dynamic_candidate_generate_bundle(
    manifest = gen_manifest,
    repo_root = repo_root,
    refresh = TRUE,
    verbose = FALSE
  )

  manifest <- exdqlm:::qdesn_dynamic_candidate_5000_500_audit_load_manifest(
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_candidate_last5000_last500_audit_manifest.yaml"),
    repo_root = repo_root
  )
  manifest$analysis$source_root_parent <- tmp_source_parent
  manifest$analysis$scenario_id <- "dlm_constV_p90_m0amp_highnoise_test5000"
  manifest$selection$families <- list("normal")
  manifest$selection$taus <- list(0.25)
  state <- exdqlm:::.qdesn_dynamic_candidate_5000_500_audit_resolve_state(manifest, repo_root = repo_root)
  inventory <- exdqlm:::.qdesn_dynamic_candidate_5000_500_audit_build_inventory(manifest, state = state, repo_root = repo_root)

  out_root <- tempfile("candidate_5000_500_audit_", fileext = "")
  dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
  one <- inventory[1L, , drop = FALSE]
  render_row <- exdqlm:::.qdesn_dynamic_candidate_5000_500_audit_plot_one(
    row = one,
    output_root = out_root,
    manifest = manifest
  )

  expect_identical(render_row$png_file[1L], one$png_file[1L])
  expect_true(file.exists(file.path(out_root, one$png_file[1L])))
})

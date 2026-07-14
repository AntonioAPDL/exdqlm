mechanism_first_repo_root <- function() {
  normalizePath(
    system2("git", c("rev-parse", "--show-toplevel"), stdout = TRUE),
    winslash = "/",
    mustWork = TRUE
  )
}
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

mechanism_first_probe_pipeline_cfg <- function(index_row, defaults_override = NULL) {
  defaults <- defaults_override %||% exdqlm:::qdesn_dynamic_crossstudy_load_defaults(index_row$defaults_path[[1L]])
  grid <- utils::read.csv(index_row$grid_path[[1L]], check.names = FALSE, stringsAsFactors = FALSE)
  target <- utils::read.csv(index_row$target_spec_ids_path[[1L]], check.names = FALSE, stringsAsFactors = FALSE)
  grid_row <- grid[match(target$root_id[[1L]], grid$root_id), , drop = FALSE]
  expect_equal(nrow(grid_row), 1L)
  root_spec <- exdqlm:::qdesn_dynamic_crossstudy_enrich_root_spec(as.list(grid_row), defaults)
  x_cols <- names(exdqlm:::.qdesn_dynamic_crossstudy_make_deterministic_features(
    seq_len(as.integer(root_spec$source_total_size %||% root_spec$fit_size)),
    defaults
  ))
  exdqlm:::qdesn_static_crossstudy_build_pipeline_cfg(
    root_spec = root_spec,
    defaults = defaults,
    method = "vb",
    likelihood_family = tolower(as.character(target$likelihood_target[[1L]])),
    x_cols = x_cols,
    T_use = as.integer(root_spec$source_total_size %||% root_spec$fit_size)
  )
}

test_that("Q-DESN mechanism-first launch scripts are staged and guarded", {
  repo <- mechanism_first_repo_root()
  materializer <- file.path(repo, "scripts", "materialize_qdesn_tt500_vb_mechanism_first_redesign.R")
  auditor <- file.path(repo, "scripts", "audit_qdesn_tt500_vb_mechanism_first_materialization.R")
  orchestrator <- file.path(repo, "scripts", "orchestrate_qdesn_tt500_vb_mechanism_first_redesign.R")
  expect_true(file.exists(materializer))
  expect_true(file.exists(auditor))
  expect_true(file.exists(orchestrator))

  orch <- paste(readLines(orchestrator, warn = FALSE), collapse = "\n")
  expect_match(orch, "--full --launch-approved", fixed = TRUE)
  expect_match(orch, "--prepare-only", fixed = TRUE)
  expect_match(orch, "--spec-ids", fixed = TRUE)
  expect_match(orch, "Mechanism-first full launch requires", fixed = TRUE)
})

test_that("Q-DESN mechanism-first materialized bundles are VB-only and exact-spec scoped when present", {
  repo <- mechanism_first_repo_root()
  index_path <- file.path(
    repo,
    "config",
    "validation",
    "qdesn_dynamic_fitforecast_v2_tt500_vb_mechanism_first_bundle_index.csv"
  )
  skip_if_not(file.exists(index_path), "mechanism-first bundles have not been materialized")
  skip_if_not(requireNamespace("yaml", quietly = TRUE), "yaml is required for config audit")
  index <- utils::read.csv(index_path, check.names = FALSE, stringsAsFactors = FALSE)
  expect_equal(nrow(index), 6L)
  expect_true(all(c("bundle_id", "defaults_path", "grid_path", "target_spec_ids_path") %in% names(index)))
  expect_true(all(file.exists(index$defaults_path)))
  expect_true(all(file.exists(index$grid_path)))
  expect_true(all(file.exists(index$target_spec_ids_path)))

  for (i in seq_len(nrow(index))) {
    defaults <- yaml::read_yaml(index$defaults_path[[i]])
    target <- utils::read.csv(index$target_spec_ids_path[[i]], check.names = FALSE, stringsAsFactors = FALSE)
    expect_identical(tolower(as.character(defaults$execution$methods)), "vb")
    expect_false("mcmc" %in% tolower(unlist(defaults$execution$methods, use.names = FALSE)))
    expect_true(length(defaults$execution$allowed_fit_spec_ids) >= nrow(target))
    expect_true(all(target$spec_id %in% unlist(defaults$execution$allowed_fit_spec_ids, use.names = FALSE)))
    expect_true(all(tolower(target$likelihood_target) %in% c("al", "exal")))
    expect_false(isTRUE((defaults$pipeline$outputs %||% list())$save_forecast_objects))
    expect_false(isTRUE((defaults$pipeline$outputs %||% list())$keep_draws))
  }
})

test_that("Q-DESN mechanism-first decomposition bundles activate a different input mechanism", {
  repo <- mechanism_first_repo_root()
  index_path <- file.path(
    repo,
    "config",
    "validation",
    "qdesn_dynamic_fitforecast_v2_tt500_vb_mechanism_first_bundle_index.csv"
  )
  skip_if_not(file.exists(index_path), "mechanism-first bundles have not been materialized")
  skip_if_not(requireNamespace("yaml", quietly = TRUE), "yaml is required for config audit")
  index <- utils::read.csv(index_path, check.names = FALSE, stringsAsFactors = FALSE)
  for (i in seq_len(nrow(index))) {
    bundle_id <- index$bundle_id[[i]]
    defaults <- yaml::read_yaml(index$defaults_path[[i]])
    input_mode <- tolower(as.character(defaults$pipeline$readout$input_mode))
    decomp <- defaults$pipeline$decomposition %||% list()
    if (identical(bundle_id, "raw_period90_control")) {
      expect_identical(input_mode, "raw_y_lags")
      expect_false(isTRUE(decomp$enabled))
      expect_false(isTRUE(defaults$pipeline$validation_guardrails$allow_dlm_decomp_lags))
    } else {
      expect_identical(input_mode, "dlm_decomp_lags")
      expect_true(isTRUE(decomp$enabled))
      expect_true(isTRUE(defaults$pipeline$validation_guardrails$allow_dlm_decomp_lags))
      expect_true(tolower(as.character(decomp$input_builder)) %in% c("component_lags", "state_resid_y"))
      expect_equal(as.integer(decomp$seasonal$period), 90L)
      expect_true(all(c(1L, 2L) %in% as.integer(unlist(decomp$seasonal$harmonics, use.names = FALSE))))
    }
  }
})

test_that("Q-DESN mechanism-first opt-in passes the real validation pipeline builder", {
  repo <- mechanism_first_repo_root()
  index_path <- file.path(repo, "config", "validation", "qvbm1_bundle_index.csv")
  skip_if_not(file.exists(index_path), "short-path mechanism-first bundles have not been materialized")
  skip_if_not(requireNamespace("pkgload", quietly = TRUE), "pkgload is required for builder audit")
  pkgload::load_all(repo, quiet = TRUE)
  index <- utils::read.csv(index_path, check.names = FALSE, stringsAsFactors = FALSE)

  for (i in seq_len(nrow(index))) {
    defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(index$defaults_path[[i]])
    cfg <- mechanism_first_probe_pipeline_cfg(index[i, , drop = FALSE], defaults)
    expect_identical(tolower(as.character(cfg$readout$input_mode)), tolower(as.character(defaults$pipeline$readout$input_mode)))
    expect_identical(isTRUE(cfg$decomposition$enabled), isTRUE(defaults$pipeline$decomposition$enabled))
  }
})

test_that("Q-DESN mechanism-first DLM input remains an explicit opt-in", {
  repo <- mechanism_first_repo_root()
  index_path <- file.path(repo, "config", "validation", "qvbm1_bundle_index.csv")
  skip_if_not(file.exists(index_path), "short-path mechanism-first bundles have not been materialized")
  skip_if_not(requireNamespace("pkgload", quietly = TRUE), "pkgload is required for builder audit")
  pkgload::load_all(repo, quiet = TRUE)
  index <- utils::read.csv(index_path, check.names = FALSE, stringsAsFactors = FALSE)
  decomp_row <- index[index$bundle_id != "raw_period90_control", , drop = FALSE][1L, , drop = FALSE]
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(decomp_row$defaults_path[[1L]])

  defaults_no_opt_in <- defaults
  defaults_no_opt_in$pipeline$validation_guardrails$allow_dlm_decomp_lags <- FALSE
  expect_error(
    mechanism_first_probe_pipeline_cfg(decomp_row, defaults_no_opt_in),
    "raw_y_lags"
  )

  defaults_no_decomp <- defaults
  defaults_no_decomp$pipeline$decomposition$enabled <- FALSE
  expect_error(
    mechanism_first_probe_pipeline_cfg(decomp_row, defaults_no_decomp),
    "decomposition.enabled=TRUE"
  )
})

test_that("Q-DESN mechanism-first short-path bundles stay below robust path limits", {
  repo <- mechanism_first_repo_root()
  index_path <- file.path(repo, "config", "validation", "qvbm1_bundle_index.csv")
  skip_if_not(file.exists(index_path), "short-path mechanism-first bundles have not been materialized")
  skip_if_not(requireNamespace("yaml", quietly = TRUE), "yaml is required for config audit")
  index <- utils::read.csv(index_path, check.names = FALSE, stringsAsFactors = FALSE)
  expect_equal(nrow(index), 6L)
  expect_true(all(c("bundle_id", "bundle_code", "stage_stub", "defaults_path", "grid_path", "profiles_path") %in% names(index)))
  expect_true(all(startsWith(index$stage_stub, "qvbm1_")))
  expect_true(all(nchar(index$stage_stub) <= 12L))

  for (i in seq_len(nrow(index))) {
    defaults <- yaml::read_yaml(index$defaults_path[[i]])
    grid <- utils::read.csv(index$grid_path[[i]], check.names = FALSE, stringsAsFactors = FALSE)
    profiles <- utils::read.csv(index$profiles_path[[i]], check.names = FALSE, stringsAsFactors = FALSE)
    target <- utils::read.csv(index$target_spec_ids_path[[i]], check.names = FALSE, stringsAsFactors = FALSE)
    expect_lt(max(nchar(as.character(grid$root_id))), 240L)
    expect_lt(max(nchar(as.character(profiles$screening_profile_id))), 80L)
    expect_true(startsWith(as.character(defaults$campaign$results_root), "results/qvbm1/"))
    expect_true(startsWith(as.character(defaults$campaign$reports_root), "reports/qvbm1/"))
    expect_true(all(target$screening_profile_id %in% profiles$screening_profile_id))
    expect_true(all(target$spec_id %in% unlist(defaults$execution$allowed_fit_spec_ids, use.names = FALSE)))
  }
})

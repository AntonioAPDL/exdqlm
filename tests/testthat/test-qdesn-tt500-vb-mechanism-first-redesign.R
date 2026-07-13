mechanism_first_repo_root <- function() {
  normalizePath(
    system2("git", c("rev-parse", "--show-toplevel"), stdout = TRUE),
    winslash = "/",
    mustWork = TRUE
  )
}
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

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
    } else {
      expect_identical(input_mode, "dlm_decomp_lags")
      expect_true(isTRUE(decomp$enabled))
      expect_true(tolower(as.character(decomp$input_builder)) %in% c("component_lags", "state_resid_y"))
      expect_equal(as.integer(decomp$seasonal$period), 90L)
      expect_true(all(c(1L, 2L) %in% as.integer(unlist(decomp$seasonal$harmonics, use.names = FALSE))))
    }
  }
})

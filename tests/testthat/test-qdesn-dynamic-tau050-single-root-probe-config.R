`%||%` <- function(a, b) if (is.null(a)) b else a

build_single_root_probe_cfg <- function(defaults_path, grid_path, method = "mcmc", likelihood_family = "exal") {
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
  grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(grid_path)
  root_spec <- exdqlm:::qdesn_dynamic_crossstudy_enrich_root_spec(grid[1L, , drop = FALSE], defaults)
  cfg <- exdqlm:::qdesn_static_crossstudy_build_pipeline_cfg(
    root_spec = root_spec,
    defaults = defaults,
    method = method,
    likelihood_family = likelihood_family,
    x_cols = character(0),
    T_use = root_spec$fit_size
  )
  list(defaults = defaults, grid = grid, cfg = cfg)
}

test_that("single-root probe materializer writes reproducible grids and defaults", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  script_path <- file.path(
    repo_root,
    "scripts",
    "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_grids.R"
  )

  primary_exal_grid_path <- tempfile("primary_exal_rhsns_", fileext = ".csv")
  exal_ridge_grid_path <- tempfile("exal_ridge_", fileext = ".csv")
  al_rhsns_grid_path <- tempfile("al_rhsns_", fileext = ".csv")
  al_ridge_grid_path <- tempfile("al_ridge_", fileext = ".csv")
  triad_exal_grid_path <- tempfile("triad_exal_", fileext = ".csv")
  triad_al_grid_path <- tempfile("triad_al_", fileext = ".csv")
  completion_exal_grid_path <- tempfile("completion_exal_", fileext = ".csv")
  tau_only_defaults_path <- tempfile("tau_only_", fileext = ".yaml")
  theta_tau_defaults_path <- tempfile("theta_tau_", fileext = ".yaml")
  stau_defaults_path <- tempfile("stau_", fileext = ".yaml")
  theta_tau_rescue_defaults_path <- tempfile("theta_tau_rescue_", fileext = ".yaml")
  triad_tau_only_defaults_path <- tempfile("triad_tau_only_", fileext = ".yaml")
  triad_theta_tau_defaults_path <- tempfile("triad_theta_tau_", fileext = ".yaml")
  completion_tau_only_defaults_path <- tempfile("completion_tau_only_", fileext = ".yaml")
  completion_theta_tau_defaults_path <- tempfile("completion_theta_tau_", fileext = ".yaml")

  output <- system2(
    "Rscript",
    c(
      script_path,
      "--primary-exal-output", primary_exal_grid_path,
      "--exal-ridge-output", exal_ridge_grid_path,
      "--al-rhsns-output", al_rhsns_grid_path,
      "--al-ridge-output", al_ridge_grid_path,
      "--triad-exal-output", triad_exal_grid_path,
      "--triad-al-output", triad_al_grid_path,
      "--completion-exal-output", completion_exal_grid_path,
      "--tau-only-defaults-output", tau_only_defaults_path,
      "--theta-tau-defaults-output", theta_tau_defaults_path,
      "--stau-defaults-output", stau_defaults_path,
      "--theta-tau-rescue-defaults-output", theta_tau_rescue_defaults_path,
      "--triad-tau-only-defaults-output", triad_tau_only_defaults_path,
      "--triad-theta-tau-defaults-output", triad_theta_tau_defaults_path,
      "--completion-tau-only-defaults-output", completion_tau_only_defaults_path,
      "--completion-theta-tau-defaults-output", completion_theta_tau_defaults_path
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(output, "status", exact = TRUE) %||% 0L
  expect_identical(as.integer(status), 0L, info = paste(output, collapse = "\n"))

  primary_exal_grid <- utils::read.csv(primary_exal_grid_path, stringsAsFactors = FALSE)
  exal_ridge_grid <- utils::read.csv(exal_ridge_grid_path, stringsAsFactors = FALSE)
  al_rhsns_grid <- utils::read.csv(al_rhsns_grid_path, stringsAsFactors = FALSE)
  al_ridge_grid <- utils::read.csv(al_ridge_grid_path, stringsAsFactors = FALSE)
  triad_exal_grid <- utils::read.csv(triad_exal_grid_path, stringsAsFactors = FALSE)
  triad_al_grid <- utils::read.csv(triad_al_grid_path, stringsAsFactors = FALSE)
  completion_exal_grid <- utils::read.csv(completion_exal_grid_path, stringsAsFactors = FALSE)

  expect_identical(nrow(primary_exal_grid), 1L)
  expect_identical(nrow(exal_ridge_grid), 1L)
  expect_identical(nrow(al_rhsns_grid), 1L)
  expect_identical(nrow(al_ridge_grid), 1L)
  expect_identical(nrow(triad_exal_grid), 2L)
  expect_identical(nrow(triad_al_grid), 1L)
  expect_identical(nrow(completion_exal_grid), 1L)
  expect_identical(
    as.character(primary_exal_grid$root_id[[1L]]),
    "root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_rhs_ns"
  )

  tau_only <- build_single_root_probe_cfg(tau_only_defaults_path, primary_exal_grid_path)
  theta_tau <- build_single_root_probe_cfg(theta_tau_defaults_path, primary_exal_grid_path)
  stau <- build_single_root_probe_cfg(stau_defaults_path, primary_exal_grid_path)
  theta_tau_rescue <- build_single_root_probe_cfg(theta_tau_rescue_defaults_path, primary_exal_grid_path)
  triad_tau_only_exal <- build_single_root_probe_cfg(triad_tau_only_defaults_path, triad_exal_grid_path)
  triad_tau_only_al <- build_single_root_probe_cfg(triad_tau_only_defaults_path, triad_al_grid_path, likelihood_family = "al")
  triad_theta_tau_exal <- build_single_root_probe_cfg(triad_theta_tau_defaults_path, triad_exal_grid_path)
  triad_theta_tau_al <- build_single_root_probe_cfg(triad_theta_tau_defaults_path, triad_al_grid_path, likelihood_family = "al")
  completion_tau_only_exal <- build_single_root_probe_cfg(completion_tau_only_defaults_path, completion_exal_grid_path)
  completion_theta_tau_exal <- build_single_root_probe_cfg(completion_theta_tau_defaults_path, completion_exal_grid_path)

  expect_identical(as.integer(tau_only$defaults$pipeline$inference$vb$rhs$freeze_tau_iters), 50L)
  expect_identical(as.integer(tau_only$defaults$pipeline$inference$vb$rhs$freeze_tau_warmup_iters), 50L)
  expect_true(isTRUE(tau_only$defaults$pipeline$inference$vb$rhs$force_tau_after_warmup))
  expect_identical(as.integer(tau_only$cfg$inference$mcmc$vb_warm_start_control$rhs$freeze_tau_iters), 50L)
  expect_identical(as.integer(tau_only$cfg$inference$mcmc$rhs$freeze_tau_burnin_iters), 500L)
  expect_false(isTRUE(tau_only$cfg$inference$mcmc$theta$enabled))
  expect_false(isTRUE(tau_only$cfg$inference$mcmc$latent_v$enabled))
  expect_false(isTRUE(tau_only$cfg$inference$mcmc$latent_s$enabled))

  expect_true(isTRUE(theta_tau$cfg$inference$mcmc$theta$enabled))
  expect_identical(as.integer(theta_tau$cfg$inference$mcmc$theta$freeze_burnin_iters), 50L)
  expect_identical(as.integer(theta_tau$cfg$inference$mcmc$theta$sparse_update_every), 10L)
  expect_identical(as.integer(theta_tau$cfg$inference$mcmc$theta$sparse_update_until_iter), 500L)
  expect_true(isTRUE(theta_tau$cfg$inference$mcmc$theta$force_first_postwarmup_update))
  expect_false(isTRUE(theta_tau$cfg$inference$mcmc$latent_v$enabled))
  expect_false(isTRUE(theta_tau$cfg$inference$mcmc$latent_s$enabled))

  expect_false(isTRUE(stau$cfg$inference$mcmc$theta$enabled))
  expect_true(isTRUE(stau$cfg$inference$mcmc$latent_v$enabled))
  expect_true(isTRUE(stau$cfg$inference$mcmc$latent_s$enabled))
  expect_identical(as.integer(stau$cfg$inference$mcmc$sigmagam$freeze_burnin_iters), 0L)

  expect_true(isTRUE(theta_tau_rescue$cfg$inference$mcmc$theta$enabled))
  expect_true(isTRUE(theta_tau_rescue$cfg$inference$mcmc$latent_v$rescue_on_invalid))
  expect_identical(as.character(theta_tau_rescue$cfg$inference$mcmc$latent_v$rescue_strategy), "previous_state")
  expect_identical(as.integer(theta_tau_rescue$cfg$inference$mcmc$latent_v$rescue_max_consecutive), 1L)
  expect_false(isTRUE(theta_tau_rescue$cfg$inference$mcmc$latent_v$rescue_burn_only))

  expect_identical(as.integer(nrow(triad_tau_only_exal$grid)), 2L)
  expect_identical(as.integer(nrow(triad_tau_only_al$grid)), 1L)
  expect_identical(
    as.character(triad_tau_only_exal$defaults$campaign$name),
    "qdesn_dynamic_exdqlm_crossstudy_tau050_representative_triad_tau_only_validation"
  )
  expect_false(isTRUE(triad_tau_only_exal$cfg$inference$mcmc$theta$enabled))
  expect_identical(as.integer(triad_tau_only_exal$cfg$inference$mcmc$rhs$freeze_tau_burnin_iters), 500L)
  expect_false(isTRUE(triad_tau_only_al$cfg$inference$mcmc$theta$enabled))

  expect_identical(as.integer(nrow(triad_theta_tau_exal$grid)), 2L)
  expect_identical(as.integer(nrow(triad_theta_tau_al$grid)), 1L)
  expect_identical(
    as.character(triad_theta_tau_exal$defaults$campaign$name),
    "qdesn_dynamic_exdqlm_crossstudy_tau050_representative_triad_theta_tau_validation"
  )
  expect_true(isTRUE(triad_theta_tau_exal$cfg$inference$mcmc$theta$enabled))
  expect_identical(as.integer(triad_theta_tau_exal$cfg$inference$mcmc$theta$freeze_burnin_iters), 50L)
  expect_true(isTRUE(triad_theta_tau_al$cfg$inference$mcmc$theta$enabled))

  expect_identical(
    as.character(completion_tau_only_exal$defaults$campaign$name),
    "qdesn_dynamic_exdqlm_crossstudy_tau050_representative_completion_exal_tau_only_validation"
  )
  expect_false(isTRUE(completion_tau_only_exal$cfg$inference$mcmc$theta$enabled))
  expect_identical(
    as.character(completion_theta_tau_exal$defaults$campaign$name),
    "qdesn_dynamic_exdqlm_crossstudy_tau050_representative_completion_exal_theta_tau_validation"
  )
  expect_true(isTRUE(completion_theta_tau_exal$cfg$inference$mcmc$theta$enabled))
})

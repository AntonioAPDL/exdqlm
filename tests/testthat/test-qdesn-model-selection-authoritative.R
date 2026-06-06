test_that("qdesn_model_selection resolves authoritative engine from config shape", {
  expect_equal(
    exdqlm:::.qdesn_ms_resolve_engine(
      engine = "auto",
      cfg = list(model_selection = list(stages = list(list(name = "smoke"))))
    ),
    "v2"
  )
  expect_equal(
    exdqlm:::.qdesn_ms_resolve_engine(
      engine = "auto",
      ms_cfg = list(model_selection = list(esn_space = list(m = 5L)))
    ),
    "legacy"
  )
  expect_error(
    exdqlm:::.qdesn_ms_resolve_engine(
      engine = "auto",
      cfg = list(model_selection = list(objective = list(primary = "crps")))
    ),
    "could not infer engine"
  )
})

test_that("qdesn_model_selection routes modern staged configs to v2", {
  captured <- NULL
  testthat::local_mocked_bindings(
    run_model_selection_v2 = function(cfg, ds, run_dir) {
      captured <<- list(cfg = cfg, ds = ds, run_dir = run_dir)
      list(results = list(summary = data.frame(candidate_id = "ok")))
    },
    .package = "exdqlm"
  )

  cfg <- list(
    pipeline = list(mode = "sim"),
    forecast = list(mode = "origin"),
    model_selection = list(
      tune_name = "unit_v2",
      stages = list(list(name = "smoke"))
    )
  )
  ds <- list(slug = "toy", mode = "sim", input_path = "toy.csv")
  run_dir <- file.path(tempdir(), "qdesn-ms-v2")

  res <- exdqlm::qdesn_model_selection(
    cfg = cfg,
    ds = ds,
    run_dir = run_dir,
    engine = "auto",
    verbose = FALSE
  )

  expect_equal(res$engine, "v2")
  expect_equal(res$run_dir, run_dir)
  expect_equal(res$dataset_id, "toy")
  expect_equal(captured$ds$slug, "toy")
  expect_equal(captured$run_dir, run_dir)
})

test_that("qdesn_model_selection preserves legacy dispatch for esn_space configs", {
  captured <- NULL
  testthat::local_mocked_bindings(
    .qdesn_model_selection_legacy = function(...) {
      captured <<- list(...)
      list(tune_name = "legacy_unit", engine = "legacy")
    },
    .package = "exdqlm"
  )

  res <- exdqlm::qdesn_model_selection(
    dataset_id = "toy",
    file_long = "toy_long.csv",
    base_cfg = list(desn = list(m = 5L)),
    ms_cfg = list(model_selection = list(esn_space = list(m = 5L))),
    out_root = tempdir(),
    engine = "auto",
    verbose = FALSE
  )

  expect_equal(res$engine, "legacy")
  expect_equal(captured$dataset_id, "toy")
  expect_equal(captured$file_long, "toy_long.csv")
})

test_that("qdesn_model_selection v2 can merge base_cfg/ms_cfg shorthands", {
  captured <- NULL
  testthat::local_mocked_bindings(
    run_model_selection_v2 = function(cfg, ds, run_dir) {
      captured <<- list(cfg = cfg, ds = ds, run_dir = run_dir)
      list(results = list(summary = data.frame(candidate_id = "ok")))
    },
    .package = "exdqlm"
  )

  res <- exdqlm::qdesn_model_selection(
    dataset_id = "toy",
    file_long = "toy.csv",
    base_cfg = list(
      pipeline = list(mode = "sim"),
      forecast = list(mode = "origin"),
      desn = list(D = 1L, n = 10L)
    ),
    ms_cfg = list(
      model_selection = list(
        tune_name = "merged",
        stages = list(list(name = "smoke"))
      )
    ),
    out_root = tempdir(),
    engine = "auto",
    verbose = FALSE
  )

  expect_equal(res$engine, "v2")
  expect_equal(captured$ds$input_path, "toy.csv")
  expect_match(captured$run_dir, "merged$")
  expect_equal(captured$cfg$desn$n, 10L)
})

test_that("model selection v2 beta-prior builder supports current ridge and RHS variants", {
  ridge <- exdqlm:::ms_build_beta_prior_obj(list(
    vb = list(priors = list(beta = list(type = "ridge", ridge = list(tau2 = 25))))
  ))
  rhs <- exdqlm:::ms_build_beta_prior_obj(list(
    vb = list(priors = list(beta = list(type = "rhs", rhs = list(tau0 = 1e-3, s2 = 0.1))))
  ))
  rhs_ns <- exdqlm:::ms_build_beta_prior_obj(list(
    vb = list(priors = list(beta = list(type = "rhs_ns", rhs_ns = list(tau0 = 1e-4, s2 = 0.1))))
  ))

  expect_equal(ridge$type, "ridge")
  expect_equal(rhs$type, "rhs")
  expect_equal(rhs_ns$type, "rhs_ns")
})

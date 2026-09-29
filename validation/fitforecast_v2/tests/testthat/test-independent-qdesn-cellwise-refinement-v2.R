iqcr_v2_load_test_code <- function() {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  for (path in c(
    "independent_qdesn_full_redesign_v2.R",
    "independent_qdesn_full_redesign_v2_runtime.R",
    "independent_qdesn_representation_screen_v1.R",
    "independent_qdesn_representation_screen_v1_runtime.R",
    "independent_qdesn_cellwise_refinement_v2.R"
  )) source(file.path(repo_root, "validation", "fitforecast_v2", "R", path),
             local = globalenv())
  repo_root
}

test_that("cellwise-refinement protocol and frozen authorities pass", {
  repo_root <- iqcr_v2_load_test_code()
  protocol <- iqcr_v2_read_protocol(repo_root)
  checks <- iqcr_v2_protocol_checks(protocol)
  expect_true(all(checks$pass), info = paste(
    checks$check[!checks$pass], collapse = ", "
  ))
  authorities <- iqcr_v2_assert_authorities(repo_root, protocol)
  expect_true(all(authorities$hash_pass))
  cells <- iqcr_v2_target_cells(protocol)
  expect_equal(nrow(cells), 18L)
  expect_equal(sum(cells$protected), 1L)
  expect_equal(cells$target_cell_id[cells$protected], "laplace__al__0p05")
})

test_that("targeted bank is deterministic, unseen, broad, and identity-Q", {
  repo_root <- iqcr_v2_load_test_code()
  protocol <- iqcr_v2_read_protocol(repo_root)
  first <- iqcr_v2_generate_structures(repo_root, protocol)
  second <- iqcr_v2_generate_structures(repo_root, protocol)
  expect_identical(first$structure_signature, second$structure_signature)
  expect_identical(first$structure_id, second$structure_id)
  expect_equal(as.integer(table(first$family)[iqcr_v2_families]),
               c(80L, 60L, 80L))
  expect_equal(sum(first$generation == "stage1_import"), 140L)
  expect_equal(sum(first$generation == "family_targeted_v2_new"), 80L)
  expect_equal(max(first$m), 360L)
  expect_equal(max(first$D), 5L)
  expect_true(any(first$total_states >= 1800L))
  expect_true(any(first$alpha > 0.95))
  expect_true(any(first$rho > 0.99))
  identity <- vapply(seq_len(nrow(first)), function(i) {
    n <- iqfr_v2_unpack_integer(first$n[[i]])
    n_tilde <- iqfr_v2_unpack_integer(first$n_tilde[[i]])
    if (first$D[[i]] == 1L) !length(n_tilde) else
      identical(n_tilde, n[seq_len(first$D[[i]] - 1L)])
  }, logical(1L))
  expect_true(all(identity))
})

test_that("RHS refinement is local, clipped, and structure specific", {
  repo_root <- iqcr_v2_load_test_code()
  protocol <- iqcr_v2_read_protocol(repo_root)
  structures <- iqcr_v2_generate_structures(repo_root, protocol)
  structures <- structures[match(iqcr_v2_families, structures$family),
                            , drop = FALSE]
  coarse <- structures[c("family", "structure_id")]
  coarse$prior_scale <- c(0.0001, 0.1, 100)
  sources <- data.frame(
    family = iqcr_v2_families, tau = 0.50,
    frozen_path = tempfile("source-"), frozen_sha256 = "not-read",
    stringsAsFactors = FALSE
  )
  root <- tempfile("iqcr-v2-rhs-refinement-")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  dir.create(file.path(root, "configs", "rhs_refinement"), recursive = TRUE)
  dir.create(file.path(root, "results", "rhs_refinement"), recursive = TRUE)
  dir.create(file.path(root, "status", "rhs_refinement"), recursive = TRUE)
  dir.create(file.path(root, "plans"), recursive = TRUE)
  plan <- iqcr_v2_materialize_rhs_refinement_plan(
    repo_root, root, protocol, structures, sources, coarse
  )
  expect_equal(nrow(plan), 3L)
  grids <- lapply(plan$config_path, function(path) {
    as.numeric(iqfr_v2_read_json(path)$scale_grid)
  })
  expect_equal(grids[[1L]], c(0.0001, 0.0003), tolerance = 1e-9)
  expect_equal(grids[[2L]], c(0.1 / 3, 0.1, 0.3), tolerance = 1e-9)
  expect_equal(grids[[3L]], c(100 / 3, 100), tolerance = 1e-9)
})

test_that("adaptive refinement and direct MCMC selection stay cellwise", {
  repo_root <- iqcr_v2_load_test_code()
  protocol <- iqcr_v2_read_protocol(repo_root)
  structures <- iqcr_v2_generate_structures(repo_root, protocol)
  normal_rank <- structures
  normal_rank$prior_scale <- rep(c(0.001, 0.01, 0.1, 1),
                                 length.out = nrow(normal_rank))
  normal_rank$robust_score <- seq_len(nrow(normal_rank))
  normal_rank$median_forecast_mae <- 1 + seq_len(nrow(normal_rank)) / 1000
  normal_rank$worst_forecast_mae <- normal_rank$median_forecast_mae + 0.1
  normal_rank$median_fit_rmse <- 1 + seq_len(nrow(normal_rank)) / 2000
  candidates <- iqcr_v2_finalize_rhs_candidates(normal_rank, structures)

  bridge_counts <- c(normal = 36L, laplace = 24L, gausmix = 36L)
  bridge_ids <- unlist(lapply(names(bridge_counts), function(family) {
    utils::head(candidates$candidate_id[candidates$family == family],
                bridge_counts[[family]])
  }), use.names = FALSE)
  bridge_candidates <- candidates[
    match(bridge_ids, candidates$candidate_id), , drop = FALSE
  ]
  cells <- expand.grid(
    tau = iqcr_v2_quantiles, likelihood_family = iqcr_v2_likelihoods,
    stringsAsFactors = FALSE
  )
  bridge_ranked <- do.call(rbind, lapply(seq_len(nrow(bridge_candidates)),
                                        function(i) {
    out <- cbind(
      bridge_candidates[rep(i, nrow(cells)), c("family", "candidate_id")],
      cells
    )
    out$selection_rank <- i
    out$median_forecast_mae <- i + seq_len(nrow(cells)) / 100
    out
  }))
  refinement <- iqcr_v2_select_refinement(
    bridge_ranked, candidates, bridge_ids, protocol
  )
  expect_equal(nrow(refinement$candidates), 64L)
  expect_equal(nrow(refinement$assignments), 368L)
  expect_false(any(refinement$candidates$candidate_id %in% bridge_ids))

  screened <- iqrs_v1_bind_rows(list(
    bridge_candidates, refinement$candidates
  ))
  quantile_ranked <- do.call(rbind, lapply(seq_len(nrow(screened)),
                                          function(i) {
    out <- cbind(
      screened[rep(i, nrow(cells)), c("family", "candidate_id")], cells
    )
    out$selection_rank <- i
    out$median_forecast_mae <- i + seq_len(nrow(cells)) / 1000
    out$worst_forecast_mae <- out$median_forecast_mae + 0.1
    out$median_fit_rmse <- i / 10 + seq_len(nrow(cells)) / 1000
    out
  }))
  pilot <- iqcr_v2_select_mcmc_pilot(
    quantile_ranked, candidates, protocol
  )
  expect_equal(nrow(pilot), 170L)
  expect_true(all(table(pilot$target_cell_id) == 10L))
  expect_false("laplace__al__0p05" %in% pilot$target_cell_id)
  expect_true(all(c("stage1_import", "family_targeted_v2_new") %in%
                    pilot$generation))
})

test_that("stage-aware collector rejects only true duplicate rows", {
  iqcr_v2_load_test_code()
  expect_identical(
    iqcr_v2_key_columns("rhs_refinement"),
    c("job_id", "fold_id", "prior_scale")
  )
  expect_identical(
    iqcr_v2_key_columns("quantile_bridge"),
    c("job_id", "fold_id", "likelihood_family", "tau")
  )
  expect_identical(
    iqcr_v2_key_columns("confirmation"), c("job_id", "estimator")
  )
})

test_that("pipeline pins one worker to each allocated CPU", {
  repo_root <- iqcr_v2_load_test_code()
  path <- file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "run_independent_qdesn_cellwise_refinement_v2_pipeline.sh"
  )
  script <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(script, "--process-slot-var=IQCR_SLOT", fixed = TRUE)
  expect_match(script, "taskset -c \"$cpu\"", fixed = TRUE)
  expect_match(script, "run_stage rhs_refinement", fixed = TRUE)
  expect_match(script, "run_stage quantile_refinement", fixed = TRUE)
  expect_match(script, "--action verify --complete true", fixed = TRUE)
})

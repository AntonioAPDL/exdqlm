testthat::test_that("redesign v2 protocol and candidate design are frozen", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2_runtime.R"))
  protocol <- iqfr_v2_read_protocol(repo_root)
  checks <- iqfr_v2_protocol_checks(protocol)
  testthat::expect_true(all(checks$pass))
  testthat::expect_identical(
    as.character(read.dcf(file.path(repo_root, "DESCRIPTION"),
                          fields = "Version")[[1L]]),
    iqfr_v2_expected_package_version
  )
  testthat::expect_identical(
    as.character(utils::packageVersion("exdqlm")),
    iqfr_v2_expected_package_version
  )
  testthat::expect_identical(
    as.character(protocol$source$required_columns),
    c("t", "y", "mu", "q_target", "eps")
  )

  candidates <- iqfr_v2_generate_initial_candidates(
    protocol, "normal", n = 256L
  )
  testthat::expect_equal(nrow(candidates), 1536L)
  testthat::expect_equal(length(unique(candidates$structure_id)), 256L)
  testthat::expect_true(all(table(candidates$structure_id) == 6L))
  testthat::expect_equal(
    sort(unique(candidates$rhs_tau0)),
    c(0.03, 0.10, 0.30, 1, 3, 10)
  )
  testthat::expect_true(all(vapply(
    split(candidates$matrix_seed, candidates$structure_id),
    function(x) length(unique(x)) == 1L, logical(1L)
  )))
  testthat::expect_setequal(unique(candidates$D), 1:4)
  testthat::expect_gte(mean(candidates$alpha >= 0.4), 0.4)
  testthat::expect_identical(
    iqfr_v2_assert_paired_tau_contract(
      candidates, protocol$search$initial_tau0_arms, 256L
    )$contract_pass,
    TRUE
  )
  testthat::expect_identical(anyDuplicated(candidates$candidate_signature), 0L)
})

testthat::test_that("adaptive design pairs each new structure with local tau arms", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2_runtime.R"))
  protocol <- iqfr_v2_read_protocol(repo_root)
  initial <- iqfr_v2_generate_initial_candidates(
    protocol, "normal", n = 40L
  )
  results <- initial[c("family", "candidate_id", "structure_id")]
  results$forecast_oracle_location_mae <- seq_len(nrow(results))
  results$fit_oracle_location_rmse <- seq_len(nrow(results)) + 0.1
  results$forecast_oracle_location_rmse <- seq_len(nrow(results)) + 0.2
  results$state_saturation_fraction <- 0
  results$readout_dimension <- initial$readout_dimension
  ranked <- iqfr_v2_rank_normal(results)
  adaptive <- iqfr_v2_generate_adaptive_candidates(
    protocol, "normal", ranked, initial
  )
  testthat::expect_equal(nrow(adaptive), 288L)
  testthat::expect_equal(length(unique(adaptive$structure_id)), 96L)
  testthat::expect_true(all(table(adaptive$structure_id) == 3L))
  testthat::expect_true(all(adaptive$rhs_tau0 >= 0.01))
  testthat::expect_true(all(adaptive$rhs_tau0 <= 30))
  testthat::expect_false(any(
    adaptive$structure_signature %in% initial$structure_signature
  ))
})

testthat::test_that("initial and adaptive candidate ledgers bind fail-closed", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2_runtime.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2_resume.R"))
  initial <- data.frame(
    family = "normal", candidate_id = "initial",
    structure_id = "structure_initial", rhs_tau0 = 1
  )
  adaptive <- data.frame(
    family = "normal", candidate_id = "adaptive",
    structure_id = "structure_adaptive", rhs_tau0 = 3,
    adaptive_tau_center = 1
  )
  combined <- iqfr_v2_bind_candidate_ledgers(initial, adaptive)
  testthat::expect_equal(nrow(combined), 2L)
  testthat::expect_true(is.na(combined$adaptive_tau_center[[1L]]))
  testthat::expect_equal(combined$adaptive_tau_center[[2L]], 1)

  drifted <- adaptive
  drifted$unexpected <- TRUE
  testthat::expect_error(
    iqfr_v2_bind_candidate_ledgers(initial, drifted),
    "core schemas differ"
  )
  duplicated <- adaptive
  duplicated$candidate_id <- "initial"
  testthat::expect_error(
    iqfr_v2_bind_candidate_ledgers(initial, duplicated),
    "duplicate identities"
  )
})

testthat::test_that("worker HEAD changes require a valid resume authorization", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2_runtime.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2_resume.R"))
  root <- tempfile("iqfr21-resume-")
  dir.create(file.path(root, "manifests"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  materialization <- list(git = list(head = "base"))
  environment <- list(git_head = "base")

  frozen <- iqfr_v2_worker_head_contract(
    materialization, environment, "base", root
  )
  testthat::expect_true(frozen$pass)
  testthat::expect_identical(frozen$mode, "frozen_launch_head")
  missing <- iqfr_v2_worker_head_contract(
    materialization, environment, "repair", root
  )
  testthat::expect_false(missing$pass)

  artifact <- iqfr_v2_write_csv(
    data.frame(relative_path = "result.csv", bytes = 1, sha256 = "hash"),
    iqfr_v2_resume_artifact_path(root)
  )
  iqfr_v2_write_json(list(
    schema_version = iqfr_v2_resume_schema,
    authorization_pass = TRUE, base_head = "base", resume_head = "repair",
    completed_jobs = 5472L,
    completed_artifact_manifest_path = artifact,
    completed_artifact_manifest_sha256 = iqfr_v2_sha256(artifact)
  ), iqfr_v2_resume_manifest_path(root))
  resumed <- iqfr_v2_worker_head_contract(
    materialization, environment, "repair", root
  )
  testthat::expect_true(resumed$pass)
  testthat::expect_identical(resumed$mode, "authorized_checkpoint_resume")

  authorization_path <- iqfr_v2_resume_manifest_path(root)
  authorization <- iqfr_v2_read_json(authorization_path)
  authorization$completed_jobs <- 5622L
  iqfr_v2_write_json(authorization, authorization_path)
  continued <- iqfr_v2_worker_head_contract(
    materialization, environment, "repair", root
  )
  testthat::expect_true(continued$pass)

  authorization$completed_jobs <- 5471L
  iqfr_v2_write_json(authorization, authorization_path)
  too_early <- iqfr_v2_worker_head_contract(
    materialization, environment, "repair", root
  )
  testthat::expect_false(too_early$pass)

  authorization$completed_jobs <- 5953L
  iqfr_v2_write_json(authorization, authorization_path)
  too_late <- iqfr_v2_worker_head_contract(
    materialization, environment, "repair", root
  )
  testthat::expect_false(too_late$pass)
})

testthat::test_that("worker protocol paths resolve canonically for every stage", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2_runtime.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2_resume.R"))
  canonical <- normalizePath(
    file.path(repo_root, iqfr_v2_protocol_relpath), winslash = "/"
  )
  testthat::expect_identical(
    iqfr_v2_resolve_protocol_path(list(), repo_root), canonical
  )
  testthat::expect_identical(
    iqfr_v2_resolve_protocol_path(list(protocol_path = canonical), repo_root),
    canonical
  )
  testthat::expect_error(
    iqfr_v2_resolve_protocol_path(
      list(protocol_path = file.path(repo_root, "DESCRIPTION")), repo_root
    ),
    "noncanonical protocol path"
  )
})

testthat::test_that("multirow jobs collect with stage-specific keys", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2_runtime.R"))
  root <- tempfile("iqfr2-collect-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  result_path <- file.path(root, "result.csv")
  status_path <- file.path(root, "status.json")
  plan_path <- file.path(root, "plan.csv")
  result <- expand.grid(
    likelihood_family = c("al", "exal"),
    tau = c(0.05, 0.25, 0.50), stringsAsFactors = FALSE
  )
  result$stage <- "quantile_vb"
  result$job_id <- "one_job"
  iqfr_v2_write_csv(result, result_path)
  iqfr_v2_write_json(list(status = "SUCCESS"), status_path)
  iqfr_v2_write_csv(data.frame(
    stage = "quantile_vb", job_id = "one_job",
    result_path = result_path, status_path = status_path
  ), plan_path)
  collected <- iqfr_v2_collect_results(plan_path, require_complete = TRUE)
  testthat::expect_equal(nrow(collected), 6L)
})

testthat::test_that("cellwise MCMC plans cover all cells and exact chain counts", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2_runtime.R"))
  protocol <- iqfr_v2_read_protocol(repo_root)
  candidates <- do.call(rbind, lapply(iqfr_v2_families, function(family) {
    iqfr_v2_generate_initial_candidates(protocol, family, n = 5L)
  }))
  rows <- list()
  k <- 0L
  for (family in iqfr_v2_families) {
    ids <- candidates$candidate_id[candidates$family == family]
    for (tau in iqfr_v2_quantiles) {
      for (likelihood in c("al", "exal")) {
        for (i in seq_along(ids)) {
          k <- k + 1L
          rows[[k]] <- data.frame(
            family = family, tau = tau, likelihood_family = likelihood,
            candidate_id = ids[[i]], forecast_qtrue_mae = i,
            forecast_check_loss = i + 0.1,
            fit_qtrue_rmse = i + 0.2, stringsAsFactors = FALSE
          )
        }
      }
    }
  }
  selected <- iqfr_v2_select_cell_finalists(do.call(rbind, rows), 4L)
  testthat::expect_equal(nrow(selected), 72L)
  root <- tempfile("iqfr2-plans-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  sources <- do.call(rbind, lapply(iqfr_v2_families, function(family) {
    do.call(rbind, lapply(iqfr_v2_quantiles, function(tau) {
      path <- iqfr_v2_source_path(protocol, family, tau)
      data.frame(
        family = family, tau = tau, frozen_path = path,
        frozen_sha256 = iqfr_v2_sha256(path), stringsAsFactors = FALSE
      )
    }))
  }))
  pilot <- iqfr_v2_materialize_mcmc_jobs(
    repo_root, root, protocol, selected, candidates, sources, "mcmc_pilot"
  )
  testthat::expect_equal(nrow(pilot$plan), 72L)
  testthat::expect_equal(length(unique(interaction(
    pilot$plan$family, pilot$plan$tau, pilot$plan$likelihood_family
  ))), 18L)

  confirm_selected <- selected[selected$finalist_rank <= 2L, , drop = FALSE]
  confirmation <- iqfr_v2_materialize_mcmc_jobs(
    repo_root, root, protocol, confirm_selected, candidates, sources,
    "mcmc_confirmation"
  )
  testthat::expect_equal(nrow(confirmation$plan), 108L)
  testthat::expect_true(all(table(
    confirmation$plan$family, confirmation$plan$tau,
    confirmation$plan$likelihood_family
  ) == 6L))
  candidate_cells <- interaction(
    confirmation$plan$family, confirmation$plan$tau,
    confirmation$plan$likelihood_family,
    confirmation$plan$candidate_id, drop = TRUE
  )
  testthat::expect_true(all(table(candidate_cells) == 3L))
})

testthat::test_that("v2.1 launcher freezes clean 15-worker background execution", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  path <- file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "launch_independent_qdesn_full_redesign_v2_1.sh"
  )
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  testthat::expect_equal(
    system2("bash", c("-n", path), stdout = FALSE, stderr = FALSE), 0L
  )
  testthat::expect_match(text, "workers=15", fixed = TRUE)
  testthat::expect_match(text, "threads_per_worker=1", fixed = TRUE)
  testthat::expect_match(text, "tmux new-session -d", fixed = TRUE)
  testthat::expect_match(text, "status --porcelain", fixed = TRUE)
  testthat::expect_match(text, "@{upstream}", fixed = TRUE)

  resume_path <- file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "resume_independent_qdesn_full_redesign_v2_1.sh"
  )
  resume_text <- paste(readLines(resume_path, warn = FALSE), collapse = "\n")
  testthat::expect_equal(
    system2("bash", c("-n", resume_path), stdout = FALSE, stderr = FALSE), 0L
  )
  testthat::expect_match(resume_text, "authorize_resume", fixed = TRUE)
  testthat::expect_match(resume_text, "workers=15", fixed = TRUE)
  testthat::expect_match(resume_text, "threads_per_worker=1", fixed = TRUE)
})

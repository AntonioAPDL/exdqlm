stage_stub <- file.path(
  repo_root, "config", "validation",
  "qdesn_dynamic_fitforecast_v2_500obs_mcmc_sparse_topology_refine_v1"
)
read_strv1_csv <- function(suffix) {
  utils::read.csv(paste0(stage_stub, suffix), check.names = FALSE,
                  stringsAsFactors = FALSE)
}

test_that("sparse topology seeds are outcome-blind, exact, and interaction-stable", {
  interface <- file.path(
    repo_root, "validation", "fitforecast_v2", "promotions",
    "qdesn_dqlm_500obs_trainonly_article_v2_20260807",
    "qdesn_dqlm_500obs_trainonly_article_v2_20260807_interface.csv"
  )
  plan <- qdesn_strv1_build_plan(interface, repo_root)
  audit <- qdesn_strv1_topology_audit(plan$profiles)

  expect_equal(nrow(plan$topology$selected), 6L)
  expect_equal(nrow(plan$topology$search_audit), 39L)
  expect_equal(as.integer(table(plan$topology$selected$topology_class)), rep(2L, 3L))
  expect_equal(sort(unique(plan$topology$selected$recurrent_edges_target)), 1:3)
  expect_true(all(plan$topology$selected$dynamic_input_nnz >= 1L))
  expect_equal(nrow(audit), 168L)
  expect_true(all(audit$topology_valid))
  expect_true(all(audit$recurrent_nnz == audit$recurrent_edges_target))
})

test_that("sparse topology plan has exact candidate-parent and sampler contracts", {
  profiles <- read_strv1_csv("_profiles.csv")
  pairs <- read_strv1_csv("_pair_map.csv")
  grid <- read_strv1_csv("_grid.csv")
  seed_audit <- qdesn_strv1_seed_contract_audit(grid, profiles, TRUE)

  expect_equal(nrow(profiles), 168L)
  expect_equal(sum(profiles$comparison_role == "candidate"), 144L)
  expect_equal(sum(profiles$comparison_role == "matched_sparse_parent"), 24L)
  expect_identical(sort(unique(profiles$sampler_replicate)), 1:2)
  expect_equal(nrow(pairs), 144L)
  expect_equal(anyDuplicated(pairs$pair_id), 0L)
  expect_true(all(pairs$candidate_profile_id %in% profiles$screening_profile_id))
  expect_true(all(pairs$parent_profile_id %in% profiles$screening_profile_id))
  expect_equal(nrow(seed_audit), 168L)
  expect_true(all(seed_audit$status == "PASS"))
})

test_that("materialized campaign is full-budget, source-frozen, and storage-light", {
  defaults <- yaml::read_yaml(paste0(stage_stub, "_defaults.yaml"))
  grid <- read_strv1_csv("_grid.csv")
  specs <- read_strv1_csv("_target_spec_ids.csv")
  smoke <- yaml::read_yaml(paste0(stage_stub, "_smoke_defaults.yaml"))
  registry <- read_strv1_csv("_source_registry.csv")

  expect_equal(nrow(grid), 168L)
  expect_equal(nrow(specs), 168L)
  expect_equal(anyDuplicated(specs$spec_id), 0L)
  expect_true(all(specs$likelihood_family == specs$likelihood_target))
  expect_true(all(grid$train_start_source_index == 8501L))
  expect_true(all(grid$train_end_source_index == 9000L))
  expect_true(all(grid$forecast_start_source_index == 9001L))
  expect_true(all(grid$forecast_end_source_index == 10000L))
  expect_equal(registry$TT_warmup, 2000L)
  expect_equal(registry$TT_main, 10000L)
  expect_equal(registry$TT_total, 12000L)
  expect_equal(defaults$runtime$workers, 20L)
  expect_equal(defaults$runtime$threads, 1L)
  expect_equal(defaults$pipeline$inference$mcmc$n_burn, 5000L)
  expect_equal(defaults$pipeline$inference$mcmc$n_mcmc, 20000L)
  expect_equal(defaults$pipeline$inference$mcmc$progress_every, 50L)
  expect_true(defaults$pipeline$inference$mcmc$init_from_vb)
  expect_false(defaults$pipeline$outputs$keep_draws)
  expect_false(defaults$pipeline$outputs$keep_mcmc_vb_init)
  expect_false(defaults$pipeline$outputs$save_forecast_objects)
  expect_false(defaults$pipeline$outputs$retain_full_rds_on_failure)
  expect_equal(smoke$runtime$workers, 3L)
  expect_equal(smoke$pipeline$inference$mcmc$n_burn, 4L)
  expect_equal(smoke$pipeline$inference$mcmc$n_mcmc, 4L)
})

test_that("dynamic-alpha v2 promotion changes exactly three metrics", {
  id <- "qdesn_dqlm_500obs_trainonly_article_v2_20260807"
  root <- file.path(repo_root, "validation", "fitforecast_v2", "promotions", id)
  interface <- utils::read.csv(file.path(root, paste0(id, "_interface.csv")),
                               check.names = FALSE)
  winners <- utils::read.csv(file.path(root, "promoted_metric_winners.csv"),
                             check.names = FALSE)
  expect_equal(nrow(interface), 72L)
  expect_equal(nrow(winners), 3L)
  expect_true(all(winners$metric_improves_current))
  expect_true(all(winners$contract_eligible))
  expect_length(list.files(root, pattern = "[.](rds|rda|RData)$",
                           recursive = TRUE, ignore.case = TRUE), 0L)
})

test_that("trace compactor preserves endpoints, cadence, and status files", {
  root <- tempfile("strv1_trace_")
  fit <- file.path(root, "roots", "root1", "fits", "mcmc_al")
  dir.create(fit, recursive = TRUE)
  trace_path <- file.path(fit, "progress_trace.csv")
  status_path <- file.path(root, "roots", "root1", "fit_status.txt")
  trace <- data.frame(method = "mcmc", step = 1:123, gamma = seq_len(123))
  utils::write.csv(trace, trace_path, row.names = FALSE)
  writeLines("SUCCESS", status_path)
  status_hash <- unname(tools::sha256sum(status_path))
  output <- file.path(root, "audit")
  script <- file.path(repo_root, "validation", "fitforecast_v2", "scripts",
                      "compact_qdesn_progress_traces.R")
  result <- system2(file.path(R.home("bin"), "Rscript"),
                    c(script, "--run-root", root, "--output-dir", output,
                      "--stride", "50"), stdout = TRUE, stderr = TRUE)
  compact <- utils::read.csv(trace_path)
  audit <- utils::read.csv(file.path(output, "progress_trace_compaction_audit.csv"))
  expect_equal(attr(result, "status") %||% 0L, 0L)
  expect_equal(compact$step, c(1L, 50L, 100L, 123L))
  expect_equal(audit$rows_before, 123L)
  expect_equal(audit$rows_after, 4L)
  expect_identical(unname(tools::sha256sum(status_path)), status_hash)
})

test_that("launcher is guarded and runs one thread per parallel fit", {
  pipeline <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "run_qdesn_mcmc_sparse_topology_refine_v1_pipeline.sh"
  ), warn = FALSE), collapse = "\n")
  launcher <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "launch_qdesn_mcmc_sparse_topology_refine_v1.sh"
  ), warn = FALSE), collapse = "\n")
  health <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "healthcheck_qdesn_mcmc_sparse_topology_refine_v1.R"
  ), warn = FALSE), collapse = "\n")
  expect_match(pipeline, "WORKERS=20", fixed = TRUE)
  expect_match(pipeline, "OPENBLAS_NUM_THREADS=1", fixed = TRUE)
  expect_match(pipeline, "taskset -c", fixed = TRUE)
  expect_match(pipeline, "HEARTBEAT_SECONDS=\"${HEARTBEAT_SECONDS:-1800}\"", fixed = TRUE)
  expect_match(pipeline, "compact_qdesn_progress_traces.R", fixed = TRUE)
  expect_match(pipeline, "ARTICLE_UPDATE_AUTOMATIC=FALSE", fixed = TRUE)
  expect_match(launcher, "validation/qdesn-mcmc-sparse-topology-refine-v1-1.0.0",
               fixed = TRUE)
  expect_match(health, "expected <- 168L", fixed = TRUE)
  expect_match(health, "return(retained)", fixed = TRUE)
  expect_false(grepl("5000L + retained", health, fixed = TRUE))
})

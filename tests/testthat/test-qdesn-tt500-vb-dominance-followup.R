test_that("dominance campaign audit handles partial live campaigns and strict terminal campaigns", {
  tmp <- tempfile("qdesn_dom_audit_")
  results_root <- file.path(tmp, "results", "campaign", "tag", "stamp")
  report_root <- file.path(tmp, "reports", "campaign", "tag", "stamp")
  success_root <- file.path(results_root, "roots", "root_success")
  running_root <- file.path(results_root, "roots", "root_running")
  dir.create(file.path(success_root, "fits", "vb_exal", "tables"), recursive = TRUE)
  dir.create(file.path(success_root, "fits", "vb_exal", "manifest"), recursive = TRUE)
  dir.create(file.path(success_root, "manifest"), recursive = TRUE)
  dir.create(file.path(running_root, "fits", "vb_exal", "objects"), recursive = TRUE)
  dir.create(file.path(running_root, "manifest"), recursive = TRUE)
  writeLines("SUCCESS", file.path(success_root, "manifest", "root_status.txt"))
  writeLines("RUNNING", file.path(running_root, "manifest", "root_status.txt"))

  lead <- data.frame(
    forecast_lead = 1:30,
    origin_end_source_index = 9990L,
    qtrue_mae = seq_len(30),
    pinball_mean = seq_len(30),
    stringsAsFactors = FALSE
  )
  rolling <- data.frame(
    forecast_origin_source_index = c(rep(seq(9000, 9960, by = 30), each = 30), rep(9990, 10)),
    forecast_lead = c(rep(1:30, length(seq(9000, 9960, by = 30))), 1:10),
    target_source_index = 9001:10000,
    stringsAsFactors = FALSE
  )
  utils::write.csv(lead, file.path(success_root, "fits", "vb_exal", "tables", "forecast_lead_metrics.csv"), row.names = FALSE)
  utils::write.csv(rolling, file.path(success_root, "fits", "vb_exal", "tables", "forecast_rolling_origin_paths.csv"), row.names = FALSE)
  exdqlm:::.qdesn_validation_write_json(
    file.path(success_root, "fits", "vb_exal", "manifest", "output_retention.json"),
    list(forecast_objects_pruned = TRUE, forecast_objects_exists_after = FALSE)
  )
  writeLines("transient", file.path(running_root, "fits", "vb_exal", "objects", "forecast_objects.rds"))

  partial <- exdqlm:::qdesn_dynamic_fitforecast_audit_screen_campaign(
    results_root = results_root,
    report_root = report_root,
    expected_roots = 2L,
    strict = FALSE
  )
  expect_equal(partial$summary$n_success, 1L)
  expect_equal(partial$summary$n_running, 1L)
  expect_true(partial$summary$n_success_lead_pass == 1L)
  expect_true(partial$summary$n_success_rolling_pass == 1L)
  expect_false(partial$summary$strict_ready)
  expect_gt(partial$summary$forbidden_binary_count_total, 0L)

  strict <- exdqlm:::qdesn_dynamic_fitforecast_audit_screen_campaign(
    results_root = results_root,
    expected_roots = 1L,
    strict = TRUE
  )
  expect_false(strict$summary$strict_ready)

  unlink(running_root, recursive = TRUE)
  strict_done <- exdqlm:::qdesn_dynamic_fitforecast_audit_screen_campaign(
    results_root = results_root,
    expected_roots = 1L,
    strict = TRUE
  )
  expect_true(strict_done$summary$strict_ready)
})

test_that("dominance ranking materializes follow-up profiles and refuses empty dominance-pass filters", {
  tmp <- tempfile("qdesn_dom_followup_")
  dir.create(tmp)
  ranking_path <- file.path(tmp, "ranking.csv")
  profiles_path <- file.path(tmp, "profiles.csv")
  profiles <- data.frame(
    screening_profile_id = c("prof_a", "prof_b"),
    enabled = TRUE,
    D = c(1L, 2L),
    n_each = c(20L, 30L),
    m = 90L,
    seed = 123L,
    stringsAsFactors = FALSE
  )
  ranking <- data.frame(
    dominance_rank = c(1L, 2L),
    screening_profile_base = c("prof_b", "prof_a"),
    dominance_pass = c(TRUE, FALSE),
    dominance_score_low_is_better = c(0.8, 1.1),
    stringsAsFactors = FALSE
  )
  utils::write.csv(profiles, profiles_path, row.names = FALSE)
  utils::write.csv(ranking, ranking_path, row.names = FALSE)

  out <- exdqlm:::qdesn_dynamic_fitforecast_profiles_from_ranking(
    ranking_path = ranking_path,
    source_profiles_path = profiles_path,
    top_n = 1L,
    seed = 999L,
    require_dominance_pass = TRUE
  )
  expect_equal(out$screening_profile_id, "prof_b")
  expect_equal(out$seed, 999L)
  expect_equal(out$profile_role, "refinement_top")

  ranking$dominance_pass <- FALSE
  utils::write.csv(ranking, ranking_path, row.names = FALSE)
  expect_error(
    exdqlm:::qdesn_dynamic_fitforecast_profiles_from_ranking(
      ranking_path = ranking_path,
      source_profiles_path = profiles_path,
      require_dominance_pass = TRUE
    ),
    "No ranked profiles satisfy"
  )
})

test_that("profile freezer and follow-up materializer write reproducible config stubs", {
  tmp <- tempfile("qdesn_dom_freeze_")
  dir.create(tmp)
  ranking_path <- file.path(tmp, "ranking.csv")
  profiles_path <- file.path(tmp, "profiles.csv")
  base_defaults <- file.path(tmp, "base.yaml")
  profiles <- data.frame(
    screening_profile_id = c("prof_a", "prof_b"),
    enabled = TRUE,
    D = c(1L, 2L),
    n_each = c(20L, 30L),
    m = 90L,
    seed = 123L,
    stringsAsFactors = FALSE
  )
  ranking <- data.frame(
    dominance_rank = c(1L, 2L),
    screening_profile_base = c("prof_a", "prof_b"),
    dominance_pass = c(FALSE, TRUE),
    qdesn_p_over_n_mean_mean = c(0.2, 0.3),
    stringsAsFactors = FALSE
  )
  utils::write.csv(profiles, profiles_path, row.names = FALSE)
  utils::write.csv(ranking, ranking_path, row.names = FALSE)
  yaml::write_yaml(
    list(
      campaign = list(name = "base", results_root = "results/base", reports_root = "reports/base"),
      study_contract = list(id = "base", description = "base"),
      screening_profiles = list(enabled = TRUE, csv = profiles_path, priors = "rhs_ns"),
      reference_contract = list(families = c("normal"), taus = c(0.5)),
      source_materialization = list(taus = c(0.5)),
      runtime = list(workers = 1L)
    ),
    base_defaults
  )

  freeze <- exdqlm:::qdesn_dynamic_fitforecast_freeze_profile(
    ranking_path = ranking_path,
    source_profiles_path = profiles_path,
    out_profile_path = file.path(tmp, "frozen.csv"),
    out_manifest_path = file.path(tmp, "frozen.json"),
    allow_best_available = TRUE
  )
  expect_equal(freeze$manifest$selected_profile_id, "prof_b")
  expect_true(file.exists(file.path(tmp, "frozen.csv")))
  expect_true(file.exists(file.path(tmp, "frozen.json")))

  mat <- exdqlm:::qdesn_dynamic_fitforecast_materialize_followup_stage(
    stage = "replacement",
    profiles = freeze$profile,
    base_defaults_path = base_defaults,
    profiles_out = file.path(tmp, "replacement_profiles.csv"),
    defaults_out = file.path(tmp, "replacement_defaults.yaml"),
    grid_out = file.path(tmp, "replacement_grid.csv"),
    workers = 2L,
    refresh_grid = FALSE
  )
  expect_equal(mat$n_profiles, 1L)
  expect_equal(mat$n_grid_rows, 0L)
  defaults <- yaml::read_yaml(file.path(tmp, "replacement_defaults.yaml"))
  expect_equal(defaults$campaign$name, "qdesn_dynamic_fitforecast_v2_tt500_vb_replacement_frozen")
  expect_equal(defaults$runtime$workers, 2L)
  expect_equal(defaults$reference_contract$expected_qdesn_roots, 1L)
})

test_that("RHS trace cleanup is dry-run safe and requires compact summary", {
  tmp <- tempfile("qdesn_dom_cleanup_")
  results_root <- file.path(tmp, "results")
  root_dir <- file.path(results_root, "roots", "root_success")
  method_dir <- file.path(root_dir, "fits", "vb_exal")
  dir.create(file.path(method_dir, "models"), recursive = TRUE)
  dir.create(file.path(method_dir, "manifest"), recursive = TRUE)
  dir.create(file.path(root_dir, "manifest"), recursive = TRUE)
  writeLines("SUCCESS", file.path(root_dir, "manifest", "root_status.txt"))
  writeLines("SUCCESS", file.path(method_dir, "manifest", "status.txt"))
  saveRDS(list(trace = TRUE), file.path(method_dir, "models", "rhs_trace.rds"))

  missing_summary <- exdqlm:::qdesn_dynamic_fitforecast_prune_success_rhs_trace(results_root, dry_run = TRUE)
  expect_equal(missing_summary$summary$eligible, 0L)
  expect_true(file.exists(file.path(method_dir, "models", "rhs_trace.rds")))

  utils::write.csv(
    data.frame(rhs_trace_available = TRUE, stringsAsFactors = FALSE),
    file.path(method_dir, "models", "rhs_run_summary.csv"),
    row.names = FALSE
  )
  dry <- exdqlm:::qdesn_dynamic_fitforecast_prune_success_rhs_trace(results_root, dry_run = TRUE)
  expect_equal(dry$summary$eligible, 1L)
  expect_equal(dry$summary$pruned, 0L)
  expect_true(file.exists(file.path(method_dir, "models", "rhs_trace.rds")))

  live <- exdqlm:::qdesn_dynamic_fitforecast_prune_success_rhs_trace(results_root, dry_run = FALSE)
  expect_equal(live$summary$eligible, 1L)
  expect_equal(live$summary$pruned, 1L)
  expect_false(file.exists(file.path(method_dir, "models", "rhs_trace.rds")))
})

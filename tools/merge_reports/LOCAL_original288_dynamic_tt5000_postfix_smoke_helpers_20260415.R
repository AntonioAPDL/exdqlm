source("tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_helpers_20260414.R")

run_tag_original288_dynamic_tt5000_postfix_smoke <- function() {
  "original288_dynamic_tt5000_postfix_smoke_20260415"
}

paths_original288_dynamic_tt5000_postfix_smoke <- function() {
  tag <- run_tag_original288_dynamic_tt5000_postfix_smoke()
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", tag))
  list(
    source_manifest = paths_original288_dynamic_tt5000_exactspec_repair()$phase1_manifest,
    manifest = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_smoke_manifest_20260415.csv",
    stage_counts = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_smoke_stage_counts_20260415.csv",
    manifest_status = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_smoke_manifest_status_20260415.csv",
    phase_summary = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_smoke_phase_summary_20260415.csv",
    console_log = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_smoke_launcher_console_20260415.log",
    program_doc = "reports/static_exal_tuning_20260415/original288_dynamic_tt5000_postfix_smoke_program_20260415.md",
    execution_doc = "reports/static_exal_tuning_20260415/original288_dynamic_tt5000_postfix_smoke_execution_20260415.md",
    run_root = run_dir,
    config_dir = file.path(run_dir, "configs"),
    rows_dir = file.path(run_dir, "rows"),
    health_dir = file.path(run_dir, "health"),
    metrics_dir = file.path(run_dir, "metrics"),
    draws_dir = file.path(run_dir, "draws"),
    logs_dir = file.path(run_dir, "logs"),
    fits_dir = file.path(run_dir, "fits")
  )
}

representative_base_rows_original288_dynamic_tt5000_postfix_smoke <- function() {
  c(5L, 6L, 7L, 8L, 61L, 62L, 63L, 64L)
}

representative_seed_slots_original288_dynamic_tt5000_postfix_smoke <- function() {
  1L
}

smoke_phase_original288_dynamic_tt5000_postfix_smoke <- function() {
  "phase1_dynamic_tt5000_exact_replay"
}

smoke_mcmc_budget_original288_dynamic_tt5000_postfix_smoke <- function() {
  list(
    burn = 10L,
    n = 5L,
    trace_every = 5L,
    progress_every = 5L
  )
}

smoke_vb_budget_original288_dynamic_tt5000_postfix_smoke <- function() {
  list(
    max_iter = 40L,
    n_samp = 300L,
    min_iter = 10L,
    patience = 2L,
    allow_elbo_drop = 5e-5
  )
}

candidate_fit_path_original288_dynamic_tt5000_postfix_smoke <- function(run_root,
                                                                         inference,
                                                                         model,
                                                                         family,
                                                                         tau_label,
                                                                         base_row_id,
                                                                         seed_slot) {
  file.path(
    run_root,
    "fits",
    inference,
    sprintf(
      "%s_%s_%s_tau_%s_base%03d_seed%02d_postfix_smoke_20260415.rds",
      inference,
      model,
      family,
      tau_label,
      as.integer(base_row_id),
      as.integer(seed_slot)
    )
  )
}

config_path_original288_dynamic_tt5000_postfix_smoke <- function(row_id) {
  file.path(
    paths_original288_dynamic_tt5000_postfix_smoke()$config_dir,
    sprintf("row_%04d_run_config.rds", as.integer(row_id))
  )
}

row_status_path_original288_dynamic_tt5000_postfix_smoke <- function(row_id) {
  file.path(
    paths_original288_dynamic_tt5000_postfix_smoke()$rows_dir,
    sprintf("row_%04d.csv", as.integer(row_id))
  )
}

health_path_original288_dynamic_tt5000_postfix_smoke <- function(row_id) {
  file.path(
    paths_original288_dynamic_tt5000_postfix_smoke()$health_dir,
    sprintf("health_%04d.csv", as.integer(row_id))
  )
}

metrics_path_original288_dynamic_tt5000_postfix_smoke <- function(row_id) {
  file.path(
    paths_original288_dynamic_tt5000_postfix_smoke()$metrics_dir,
    sprintf("metrics_%04d.csv", as.integer(row_id))
  )
}

draws_path_original288_dynamic_tt5000_postfix_smoke <- function(row_id) {
  file.path(
    paths_original288_dynamic_tt5000_postfix_smoke()$draws_dir,
    sprintf("draws_%04d.rds", as.integer(row_id))
  )
}

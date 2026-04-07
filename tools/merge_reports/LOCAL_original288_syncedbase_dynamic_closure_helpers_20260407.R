source("tools/merge_reports/LOCAL_original288_syncedbase_faithful_replay_helpers_20260407.R")

predecessor_repo_root_original288_syncedbase_dynamic_closure <- function() {
  "/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs"
}

integration_repo_root_original288_syncedbase_dynamic_closure <- function() {
  "/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration"
}

run_tag_original288_syncedbase_dynamic_closure <- function() {
  "original288_syncedbase_dynamic_closure_20260407"
}

variant_tag_original288_syncedbase_dynamic_closure <- function() {
  "orig288_sync0p4p0_dynamic_closure_20260407"
}

phase_order_original288_syncedbase_dynamic_closure <- c(
  phase1_dynamic_tail_primary = 1L,
  phase2_dynamic_tail_alternate = 2L,
  phase3_dynamic_replay_repair = 3L
)

paths_original288_syncedbase_dynamic_closure <- function() {
  tag <- run_tag_original288_syncedbase_dynamic_closure()
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", tag))
  list(
    accepted_selection = "tools/merge_reports/LOCAL_original288_carryforward_selection_v7_20260407.csv",
    followup_status = "tools/merge_reports/LOCAL_original288_syncedbase_followup_manifest_status_20260407.csv",
    queue = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_queue_20260407.csv",
    deferred = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_deferred_inventory_20260407.csv",
    schedule = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_schedule_20260407.csv",
    manifest = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_manifest_20260407.csv",
    stage_counts = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_stage_counts_20260407.csv",
    manifest_status = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_manifest_status_20260407.csv",
    phase_summary = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_phase_summary_20260407.csv",
    block_summary = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_block_summary_20260407.csv",
    accepted_compare = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_accepted_compare_20260407.csv",
    config_dir = file.path(run_dir, "configs"),
    program_doc = "reports/static_exal_tuning_20260407/original_288_syncedbase_dynamic_closure_program_20260407.md",
    execution_doc = "reports/static_exal_tuning_20260407/original_288_syncedbase_dynamic_closure_execution_20260407.md"
  )
}

candidate_fit_path_original288_syncedbase_dynamic_closure <- function(run_root, inference, model, tau_label, candidate_label) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    inference,
    sprintf("%s_%s_tau_%s_fit_%s_%s.rds", inference, model, tau_label, variant_tag_original288_syncedbase_dynamic_closure(), candidate_label)
  ))
}

vb_candidate_fit_path_original288_syncedbase_dynamic_closure <- function(run_root, model, tau_label, candidate_label) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    "vb",
    sprintf("vb_%s_tau_%s_fit_%s_%s.rds", model, tau_label, variant_tag_original288_syncedbase_dynamic_closure(), candidate_label)
  ))
}

config_path_original288_syncedbase_dynamic_closure <- function(row_id) {
  file.path(
    paths_original288_syncedbase_dynamic_closure()$config_dir,
    sprintf("row_%04d_run_config.rds", as.integer(row_id))
  )
}

current_run_root_original288_syncedbase_dynamic_closure <- function(source_run_root) {
  normalize_path_original288(sub(
    predecessor_repo_root_original288_syncedbase_dynamic_closure(),
    integration_repo_root_original288_syncedbase_dynamic_closure(),
    source_run_root,
    fixed = TRUE
  ))
}

derive_dynamic_run_root_from_fit_original288_syncedbase_dynamic_closure <- function(fit_path) {
  normalize_path_original288(dirname(dirname(dirname(fit_path))))
}

vb_reference_fit_path_original288_syncedbase_dynamic_closure <- function(run_root, model, tau_label) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    "vb",
    sprintf("vb_%s_tau_%s_fit.rds", model, tau_label)
  ))
}

accepted_dynamic_tail_source_original288_syncedbase_dynamic_closure <- function() {
  carry <- read.csv(
    paths_original288_syncedbase_dynamic_closure()$accepted_selection,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  x <- subset(
    carry,
    block == "dynamic" &
      model == "exdqlm" &
      inference == "mcmc" &
      gate_overall == "FAIL"
  )
  if (!nrow(x)) return(x)

  x$row_id <- match(x$original_case_key, carry$original_case_key)
  x$tau_label <- x$tau
  x$accepted_gate <- x$gate_overall
  x$accepted_healthy <- x$healthy
  x$gate_current <- x$gate_overall
  x$accepted_compare <- "accepted_tail_fail"
  x$source_run_root <- vapply(
    x$selected_fit_path,
    derive_dynamic_run_root_from_fit_original288_syncedbase_dynamic_closure,
    character(1)
  )
  x$run_root <- vapply(
    x$source_run_root,
    current_run_root_original288_syncedbase_dynamic_closure,
    character(1)
  )
  x$source_run_config_path <- normalize_path_original288(file.path(x$source_run_root, "tables", "run_config.rds"))
  x$sim_output_path <- normalize_path_original288(file.path(dirname(x$source_run_root), "sim_output.rds"))
  x$source_baseline_fit_path <- x$baseline_fit_path
  x$source_selected_fit_path <- x$selected_fit_path
  x$source_reference_fit_path <- x$selected_fit_path
  x$vb_reference_fit_path <- mapply(
    vb_reference_fit_path_original288_syncedbase_dynamic_closure,
    x$source_run_root,
    x$model,
    x$tau_label,
    USE.NAMES = FALSE
  )
  x$queue_group <- "accepted_unresolved_tail"
  x$in_scope <- TRUE
  x
}

dynamic_replay_fail_source_original288_syncedbase_dynamic_closure <- function() {
  status <- read.csv(
    paths_original288_syncedbase_dynamic_closure()$followup_status,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  x <- subset(
    status,
    block == "dynamic" &
      model == "exdqlm" &
      inference == "mcmc" &
      accepted_compare == "worse_than_accepted" &
      gate_current == "FAIL"
  )
  if (!nrow(x)) return(x)
  x$queue_group <- "syncedbase_dynamic_replay_fail"
  x$in_scope <- TRUE
  x
}

read_source_status_original288_syncedbase_dynamic_closure <- function() {
  tail <- accepted_dynamic_tail_source_original288_syncedbase_dynamic_closure()
  replay <- dynamic_replay_fail_source_original288_syncedbase_dynamic_closure()

  keep_cols <- c(
    "row_id", "block", "root_kind", "family", "tau", "tau_label", "fit_size",
    "prior_semantics", "model", "inference", "method", "root_id",
    "original_scenario_key", "original_case_key", "baseline_signoff_path",
    "baseline_fit_path", "selected_source_type", "selected_source_subtype",
    "selected_candidate", "selected_variant_tag", "selected_fit_path",
    "selected_health_path", "selected_summary_path", "source_path",
    "gate_current", "accepted_gate", "accepted_healthy", "accepted_compare",
    "selection_mode", "selection_reason", "runtime_sec", "run_root",
    "source_run_root", "source_run_config_path", "sim_output_path",
    "source_baseline_fit_path", "source_selected_fit_path",
    "source_reference_fit_path", "vb_reference_fit_path", "queue_group",
    "in_scope"
  )

  for (nm in keep_cols) {
    if (!nm %in% names(tail)) tail[[nm]] <- NA
    if (!nm %in% names(replay)) replay[[nm]] <- NA
  }

  x <- rbind(
    tail[, keep_cols, drop = FALSE],
    replay[, keep_cols, drop = FALSE]
  )
  x <- x[order(
    factor(x$queue_group, levels = c("accepted_unresolved_tail", "syncedbase_dynamic_replay_fail")),
    x$family,
    x$tau_label,
    x$fit_size
  ), , drop = FALSE]
  rownames(x) <- NULL
  x
}

read_deferred_inventory_original288_syncedbase_dynamic_closure <- function() {
  status <- read.csv(
    paths_original288_syncedbase_dynamic_closure()$followup_status,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  deferred <- subset(
    status,
    (block %in% c("static_paper", "static_shrink") & model == "exal" & inference == "mcmc" & gate_current == "FAIL") |
      (accepted_compare == "worse_than_accepted" & gate_current == "WARN")
  )
  if (!nrow(deferred)) return(deferred)
  deferred$queue_group <- ifelse(
    deferred$gate_current == "FAIL",
    "deferred_static_replay_fail",
    "deferred_stability_review"
  )
  deferred$in_scope <- FALSE
  deferred
}

reference_fit_path_original288_syncedbase_dynamic_closure <- function(target_row, reference_basename = NA_character_) {
  if (is_missing_scalar_original288_syncedbase_rerun(reference_basename)) {
    return(normalize_path_original288(target_row$source_reference_fit_path))
  }
  path <- normalize_path_original288(file.path(dirname(target_row$source_reference_fit_path), reference_basename))
  if (!file.exists(path)) {
    stop(sprintf("Missing reference fit for %s: %s", target_row$original_case_key, path))
  }
  path
}

schedule_spec_original288_syncedbase_dynamic_closure <- function() {
  data.frame(
    phase = c(
      rep("phase1_dynamic_tail_primary", 6L),
      rep("phase2_dynamic_tail_alternate", 3L),
      rep("phase3_dynamic_replay_repair", 3L)
    ),
    target_case_key = c(
      "dynamic::gausmix::0p05::5000::default::exdqlm::mcmc",
      "dynamic::gausmix::0p25::500::default::exdqlm::mcmc",
      "dynamic::laplace::0p05::500::default::exdqlm::mcmc",
      "dynamic::laplace::0p05::5000::default::exdqlm::mcmc",
      "dynamic::normal::0p05::500::default::exdqlm::mcmc",
      "dynamic::normal::0p05::5000::default::exdqlm::mcmc",
      "dynamic::gausmix::0p05::5000::default::exdqlm::mcmc",
      "dynamic::laplace::0p05::500::default::exdqlm::mcmc",
      "dynamic::laplace::0p05::5000::default::exdqlm::mcmc",
      "dynamic::gausmix::0p05::500::default::exdqlm::mcmc",
      "dynamic::laplace::0p25::500::default::exdqlm::mcmc",
      "dynamic::normal::0p25::500::default::exdqlm::mcmc"
    ),
    candidate_label = c(
      "tail6_gmix005_tt5000_rw_refresh_ultra",
      "tail6_gmix025_tt500_slice_mid240",
      "tail6_lap005_tt500_rw_refresh_ultra",
      "tail6_lap005_tt5000_rw_refresh_ultra",
      "tail6_norm005_tt500_slice_mid240",
      "tail6_norm005_tt5000_slice_mid240",
      "tail6_gmix005_tt5000_slice_mid240",
      "tail6_lap005_tt500_slice_mid240",
      "tail6_lap005_tt5000_slice_mid240",
      "replay254_slice_mid240",
      "replay266_slice_mid240",
      "replay276_rw_refresh_ultra"
    ),
    reference_basename = c(
      "mcmc_exdqlm_tau_0p05_fit_rhsns_full_relaunch_20260327.rds",
      "mcmc_exdqlm_tau_0p25_fit_slice_pilot_20260318.rds",
      "mcmc_exdqlm_tau_0p05_fit_rhsns_full_relaunch_20260327.rds",
      "mcmc_exdqlm_tau_0p05_fit_rhsns_full_relaunch_20260327.rds",
      "mcmc_exdqlm_tau_0p05_fit_orig288_dyn_tail8_slice_sync_long_20260405.rds",
      "mcmc_exdqlm_tau_0p05_fit_orig288_dyn_tail8_slice_sync_long_20260405.rds",
      "mcmc_exdqlm_tau_0p05_fit_orig288_dyn_tail8_slice_sync_long_20260405.rds",
      "mcmc_exdqlm_tau_0p05_fit_orig288_dyn_tail8_slice_sync_long_20260405.rds",
      "mcmc_exdqlm_tau_0p05_fit_orig288_dyn_tail8_slice_sync_long_20260405.rds",
      "mcmc_exdqlm_tau_0p05_fit_orig288_dyn_tail8_slice_sync_long_20260405.rds",
      "mcmc_exdqlm_tau_0p25_fit_slice_wave1_20260319.rds",
      "mcmc_exdqlm_tau_0p25_fit_rhsns_full_relaunch_20260327.rds"
    ),
    reason = c(
      "Hard long-horizon low-tail gausmix row; RW retries improved diagnostics but remained unstable, so keep RW and strengthen refresh plus budget.",
      "Only non-low-tail accepted FAIL in the dynamic tail; best archived slice corridor stayed gamma-limited, so keep slice but widen stepping and extend budget.",
      "Short-horizon low-tail laplace row has both sigma and gamma instability; start with a stronger RW refresh corridor before switching families.",
      "Long-horizon low-tail laplace row is the hardest full-instability case; keep RW exactness but increase refresh strength and runtime substantially.",
      "Short-horizon low-tail normal row became sigma-stable under RW while gamma still failed, so pivot to a longer slice corridor aimed at gamma mixing.",
      "Long-horizon low-tail normal row improved a lot under larger RW budgets but still failed on gamma, so pivot to a longer slice corridor for gamma mixing.",
      "Hardest gausmix long-horizon row still needs an alternate exact kernel after repeated RW failures; test the strongest long slice corridor on the synced base.",
      "Short-horizon laplace low-tail row still needs an alternate exact kernel after RW instability; test a longer slice corridor directly on gamma.",
      "Long-horizon laplace low-tail row remains unstable after RW retries; use a long slice alternate rather than repeating the same RW family again.",
      "Accepted healthy replay row 254 still fails on gamma under RW exact-long; switch to the strongest archived slice corridor with a larger budget.",
      "Accepted healthy replay row 266 improved under slice exact-long but gamma still failed; keep slice and widen stepping rather than reopen RW immediately.",
      "Accepted healthy replay row 276 still fails on both sigma and gamma under slice; pivot to a stronger RW refresh corridor."
    ),
    override_burn = c(
      6000L, 2000L, 2500L, 6000L, 2500L, 5000L,
      6000L, 2500L, 6000L,
      2500L, 2000L, 2500L
    ),
    override_n = c(
      18000L, 8000L, 10000L, 18000L, 9000L, 16000L,
      18000L, 10000L, 18000L,
      9000L, 8000L, 10000L
    ),
    override_proposal = c(
      "laplace_rw", "slice", "laplace_rw", "laplace_rw", "slice", "slice",
      "slice", "slice", "slice",
      "slice", "slice", "laplace_rw"
    ),
    override_joint_sample = c(
      TRUE, FALSE, TRUE, TRUE, FALSE, FALSE,
      FALSE, FALSE, FALSE,
      FALSE, FALSE, TRUE
    ),
    override_slice_width = c(
      NA, 0.16, NA, NA, 0.16, 0.16,
      0.16, 0.16, 0.16,
      0.16, 0.16, NA
    ),
    override_slice_max_steps = c(
      NA, 240L, NA, NA, 240L, 240L,
      240L, 240L, 240L,
      240L, 240L, NA
    ),
    override_laplace_refresh_interval = c(
      10L, NA, 10L, 10L, NA, NA,
      NA, NA, NA,
      NA, NA, 10L
    ),
    override_laplace_refresh_start = c(
      50L, NA, 50L, 50L, NA, NA,
      NA, NA, NA,
      NA, NA, 50L
    ),
    override_laplace_refresh_weight = c(
      0.90, NA, 0.90, 0.90, NA, NA,
      NA, NA, NA,
      NA, NA, 0.90
    ),
    stringsAsFactors = FALSE
  )
}

apply_overrides_original288_syncedbase_dynamic_closure <- function(cfg, spec_row) {
  cfg$mcmc <- cfg$mcmc %||% list()
  cfg$mcmc$mh <- cfg$mcmc$mh %||% list()

  if (is.finite(safe_int_original288_syncedbase_rerun(spec_row$override_burn, NA_integer_))) {
    cfg$mcmc$burn <- safe_int_original288_syncedbase_rerun(spec_row$override_burn, NA_integer_)
  }
  if (is.finite(safe_int_original288_syncedbase_rerun(spec_row$override_n, NA_integer_))) {
    cfg$mcmc$n <- safe_int_original288_syncedbase_rerun(spec_row$override_n, NA_integer_)
  }
  if (!is_missing_scalar_original288_syncedbase_rerun(spec_row$override_proposal)) {
    cfg$mcmc$mh$proposal <- safe_chr_original288_syncedbase_rerun(spec_row$override_proposal, cfg$mcmc$mh$proposal %||% "laplace_rw")
    cfg$mcmc$mh$primary_proposal <- cfg$mcmc$mh$proposal
  }
  if (!all(is.na(spec_row$override_joint_sample))) {
    cfg$mcmc$mh$joint_sample <- as.logical(spec_row$override_joint_sample)[1]
    cfg$mcmc$mh$primary_joint_sample <- cfg$mcmc$mh$joint_sample
  }
  if (is.finite(safe_num_original288_syncedbase_rerun(spec_row$override_slice_width, NA_real_))) {
    cfg$mcmc$mh$slice_width <- safe_num_original288_syncedbase_rerun(spec_row$override_slice_width, NA_real_)
  }
  if (is.finite(safe_int_original288_syncedbase_rerun(spec_row$override_slice_max_steps, NA_integer_))) {
    cfg$mcmc$mh$slice_max_steps <- safe_int_original288_syncedbase_rerun(spec_row$override_slice_max_steps, NA_integer_)
  }
  if (is.finite(safe_int_original288_syncedbase_rerun(spec_row$override_laplace_refresh_interval, NA_integer_))) {
    cfg$mcmc$mh$laplace_refresh_interval <- safe_int_original288_syncedbase_rerun(spec_row$override_laplace_refresh_interval, NA_integer_)
  }
  if (is.finite(safe_int_original288_syncedbase_rerun(spec_row$override_laplace_refresh_start, NA_integer_))) {
    cfg$mcmc$mh$laplace_refresh_start <- safe_int_original288_syncedbase_rerun(spec_row$override_laplace_refresh_start, NA_integer_)
  }
  if (is.finite(safe_num_original288_syncedbase_rerun(spec_row$override_laplace_refresh_weight, NA_real_))) {
    cfg$mcmc$mh$laplace_refresh_weight <- safe_num_original288_syncedbase_rerun(spec_row$override_laplace_refresh_weight, NA_real_)
  }

  cfg
}

read_original288_syncedbase_dynamic_closure_status <- function(manifest_path = paths_original288_syncedbase_dynamic_closure()$manifest,
                                                               run_tag = run_tag_original288_syncedbase_dynamic_closure()) {
  manifest <- read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", run_tag))
  rows_dir <- file.path(run_dir, "rows")

  parts <- list()
  if (dir.exists(rows_dir)) {
    row_files <- list.files(rows_dir, pattern = "^row_[0-9]+\\.csv$", full.names = TRUE)
    if (length(row_files)) {
      parts <- lapply(row_files, function(p) tryCatch(read.csv(p, stringsAsFactors = FALSE), error = function(e) NULL))
      parts <- Filter(Negate(is.null), parts)
    }
  }

  rows <- rbind_fill_original288_syncedbase_rerun(parts)
  if (nrow(rows)) {
    merged <- merge(manifest, rows, by = "row_id", all.x = TRUE, suffixes = c("_manifest", "_row"))
  } else {
    merged <- manifest
  }

  if (!("status" %in% names(merged))) merged$status <- NA_character_
  if (!("gate_overall" %in% names(merged))) merged$gate_overall <- NA_character_
  if (!("healthy" %in% names(merged))) merged$healthy <- NA
  if (!("runtime_sec" %in% names(merged))) merged$runtime_sec <- NA_real_

  if ("status_row" %in% names(merged)) {
    merged$status <- ifelse(!is.na(merged$status_row) & nzchar(merged$status_row), merged$status_row, merged$status)
  }
  if ("gate_overall_row" %in% names(merged)) {
    merged$gate_overall <- ifelse(!is.na(merged$gate_overall_row) & nzchar(merged$gate_overall_row), merged$gate_overall_row, merged$gate_overall)
  }
  if ("healthy_row" %in% names(merged)) {
    merged$healthy <- ifelse(!is.na(merged$healthy_row), merged$healthy_row, merged$healthy)
  }
  if ("runtime_sec_row" %in% names(merged)) {
    merged$runtime_sec <- ifelse(!is.na(merged$runtime_sec_row), merged$runtime_sec_row, merged$runtime_sec)
  }

  for (nm in c("inference", "model", "root_kind", "family", "tau_label", "baseline_fit_path", "candidate_fit_path")) {
    manifest_nm <- paste0(nm, "_manifest")
    if (!(nm %in% names(merged)) && manifest_nm %in% names(merged)) {
      merged[[nm]] <- merged[[manifest_nm]]
    }
  }

  merged$state <- ifelse(is.na(merged$status) | !nzchar(merged$status), "pending", merged$status)
  merged$gate_current <- ifelse(
    merged$state %in% c("done", "skipped_existing", "failed_runtime", "input_missing"),
    ifelse(is.na(merged$gate_overall) | !nzchar(merged$gate_overall), "FAIL", merged$gate_overall),
    "MISSING"
  )
  merged$healthy_current <- ifelse(
    merged$state %in% c("done", "skipped_existing", "failed_runtime", "input_missing"),
    as.logical(ifelse(is.na(merged$healthy), FALSE, merged$healthy)),
    FALSE
  )
  merged$accepted_compare <- mapply(
    accepted_compare_status_original288_syncedbase_rerun,
    merged$gate_current,
    merged$accepted_gate,
    USE.NAMES = FALSE
  )
  merged
}

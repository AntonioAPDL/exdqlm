source("tools/merge_reports/LOCAL_original288_syncedbase_faithful_replay_helpers_20260407.R")

predecessor_repo_root_original288_syncedbase_dynamic_tail6_refine <- function() {
  "/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs"
}

integration_repo_root_original288_syncedbase_dynamic_tail6_refine <- function() {
  "/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration"
}

run_tag_original288_syncedbase_dynamic_tail6_refine <- function() {
  "original288_syncedbase_dynamic_tail6_refine_20260407"
}

variant_tag_original288_syncedbase_dynamic_tail6_refine <- function() {
  "orig288_sync0p4p0_dynamic_tail6_refine_20260407"
}

phase_order_original288_syncedbase_dynamic_tail6_refine <- c(
  phase1_dynamic_tail6_refine = 1L
)

paths_original288_syncedbase_dynamic_tail6_refine <- function() {
  tag <- run_tag_original288_syncedbase_dynamic_tail6_refine()
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", tag))
  list(
    accepted_selection = "tools/merge_reports/LOCAL_original288_carryforward_selection_v7_20260407.csv",
    closure_status = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_manifest_status_20260407.csv",
    queue = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_refine_queue_20260407.csv",
    deferred = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_refine_deferred_inventory_20260407.csv",
    schedule = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_refine_schedule_20260407.csv",
    manifest = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_refine_manifest_20260407.csv",
    stage_counts = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_refine_stage_counts_20260407.csv",
    manifest_status = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_refine_manifest_status_20260407.csv",
    phase_summary = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_refine_phase_summary_20260407.csv",
    block_summary = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_refine_block_summary_20260407.csv",
    accepted_compare = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_refine_accepted_compare_20260407.csv",
    config_dir = file.path(run_dir, "configs"),
    program_doc = "reports/static_exal_tuning_20260407/original_288_syncedbase_dynamic_tail6_refine_program_20260407.md",
    execution_doc = "reports/static_exal_tuning_20260407/original_288_syncedbase_dynamic_tail6_refine_execution_20260407.md"
  )
}

candidate_fit_path_original288_syncedbase_dynamic_tail6_refine <- function(run_root, inference, model, tau_label, candidate_label) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    inference,
    sprintf("%s_%s_tau_%s_fit_%s_%s.rds", inference, model, tau_label, variant_tag_original288_syncedbase_dynamic_tail6_refine(), candidate_label)
  ))
}

vb_candidate_fit_path_original288_syncedbase_dynamic_tail6_refine <- function(run_root, model, tau_label, candidate_label) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    "vb",
    sprintf("vb_%s_tau_%s_fit_%s_%s.rds", model, tau_label, variant_tag_original288_syncedbase_dynamic_tail6_refine(), candidate_label)
  ))
}

config_path_original288_syncedbase_dynamic_tail6_refine <- function(row_id) {
  file.path(
    paths_original288_syncedbase_dynamic_tail6_refine()$config_dir,
    sprintf("row_%04d_run_config.rds", as.integer(row_id))
  )
}

current_run_root_original288_syncedbase_dynamic_tail6_refine <- function(source_run_root) {
  normalize_path_original288(sub(
    predecessor_repo_root_original288_syncedbase_dynamic_tail6_refine(),
    integration_repo_root_original288_syncedbase_dynamic_tail6_refine(),
    source_run_root,
    fixed = TRUE
  ))
}

derive_dynamic_run_root_from_fit_original288_syncedbase_dynamic_tail6_refine <- function(fit_path) {
  normalize_path_original288(dirname(dirname(dirname(fit_path))))
}

vb_reference_fit_path_original288_syncedbase_dynamic_tail6_refine <- function(run_root, model, tau_label) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    "vb",
    sprintf("vb_%s_tau_%s_fit.rds", model, tau_label)
  ))
}

accepted_dynamic_tail_source_original288_syncedbase_dynamic_tail6_refine <- function() {
  carry <- read.csv(
    paths_original288_syncedbase_dynamic_tail6_refine()$accepted_selection,
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
    derive_dynamic_run_root_from_fit_original288_syncedbase_dynamic_tail6_refine,
    character(1)
  )
  x$run_root <- vapply(
    x$source_run_root,
    current_run_root_original288_syncedbase_dynamic_tail6_refine,
    character(1)
  )
  x$source_run_config_path <- normalize_path_original288(file.path(x$source_run_root, "tables", "run_config.rds"))
  x$sim_output_path <- normalize_path_original288(file.path(dirname(x$source_run_root), "sim_output.rds"))
  x$source_baseline_fit_path <- x$baseline_fit_path
  x$source_selected_fit_path <- x$selected_fit_path
  x$source_reference_fit_path <- x$selected_fit_path
  x$vb_reference_fit_path <- mapply(
    vb_reference_fit_path_original288_syncedbase_dynamic_tail6_refine,
    x$source_run_root,
    x$model,
    x$tau_label,
    USE.NAMES = FALSE
  )
  x$queue_group <- "accepted_unresolved_tail"
  x$in_scope <- TRUE
  x
}

read_dynamic_closure_status_original288_syncedbase_dynamic_tail6_refine <- function() {
  read.csv(
    paths_original288_syncedbase_dynamic_tail6_refine()$closure_status,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

read_source_status_original288_syncedbase_dynamic_tail6_refine <- function() {
  tail <- accepted_dynamic_tail_source_original288_syncedbase_dynamic_tail6_refine()

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
  }

  x <- tail[, keep_cols, drop = FALSE]
  x <- x[order(
    factor(x$queue_group, levels = c("accepted_unresolved_tail")),
    x$family,
    x$tau_label,
    x$fit_size
  ), , drop = FALSE]
  rownames(x) <- NULL
  x
}

read_deferred_inventory_original288_syncedbase_dynamic_tail6_refine <- function() {
  status <- read_dynamic_closure_status_original288_syncedbase_dynamic_tail6_refine()
  keep <- status$gate_current == "FAIL" & (
    status$accepted_compare == "worse_than_accepted" |
      status$planned_candidate_label %in% c(
        "tail6_gmix005_tt5000_rw_refresh_ultra",
        "tail6_lap005_tt500_slice_mid240",
        "tail6_lap005_tt5000_rw_refresh_ultra",
        "tail6_norm005_tt500_slice_mid240",
        "tail6_norm005_tt5000_slice_mid240"
      )
  )
  deferred <- status[keep, , drop = FALSE]
  if (!nrow(deferred)) return(deferred)
  deferred$queue_group <- ifelse(
    deferred$accepted_compare == "worse_than_accepted",
    "deferred_dynamic_replay_fail",
    "screened_dynamic_closure_weak"
  )
  deferred$in_scope <- FALSE
  deferred
}

reference_fit_path_original288_syncedbase_dynamic_tail6_refine <- function(target_row,
                                                                           reference_candidate_label = NA_character_,
                                                                           reference_path = NA_character_,
                                                                           reference_basename = NA_character_) {
  if (!is_missing_scalar_original288_syncedbase_rerun(reference_candidate_label)) {
    status <- read_dynamic_closure_status_original288_syncedbase_dynamic_tail6_refine()
    hit <- subset(
      status,
      planned_candidate_label == reference_candidate_label &
        original_case_key == target_row$original_case_key
    )
    if (nrow(hit) != 1L) {
      stop(sprintf(
        "Expected exactly one closure reference for %s / %s, found %d",
        target_row$original_case_key,
        reference_candidate_label,
        nrow(hit)
      ))
    }
    path <- normalize_path_original288(hit$candidate_fit_path[1])
    if (!file.exists(path)) {
      stop(sprintf("Missing closure reference fit for %s: %s", target_row$original_case_key, path))
    }
    return(path)
  }
  if (!is_missing_scalar_original288_syncedbase_rerun(reference_path)) {
    path <- normalize_path_original288(reference_path)
    if (!file.exists(path)) {
      stop(sprintf("Missing explicit reference fit for %s: %s", target_row$original_case_key, path))
    }
    return(path)
  }
  if (is_missing_scalar_original288_syncedbase_rerun(reference_basename)) {
    return(normalize_path_original288(target_row$source_reference_fit_path))
  }
  path <- normalize_path_original288(file.path(dirname(target_row$source_reference_fit_path), reference_basename))
  if (!file.exists(path)) {
    stop(sprintf("Missing reference fit for %s: %s", target_row$original_case_key, path))
  }
  path
}

schedule_spec_original288_syncedbase_dynamic_tail6_refine <- function() {
  data.frame(
    phase = rep("phase1_dynamic_tail6_refine", 6L),
    target_case_key = c(
      "dynamic::gausmix::0p05::5000::default::exdqlm::mcmc",
      "dynamic::gausmix::0p25::500::default::exdqlm::mcmc",
      "dynamic::laplace::0p05::500::default::exdqlm::mcmc",
      "dynamic::laplace::0p05::5000::default::exdqlm::mcmc",
      "dynamic::normal::0p05::500::default::exdqlm::mcmc",
      "dynamic::normal::0p05::5000::default::exdqlm::mcmc"
    ),
    candidate_label = c(
      "tail6_refine_gmix005_tt5000_slice_deep320",
      "tail6_refine_gmix025_tt500_slice_deep320",
      "tail6_refine_lap005_tt500_rw_joint_deep",
      "tail6_refine_lap005_tt5000_slice_deep320",
      "tail6_refine_norm005_tt500_rw_joint_deep",
      "tail6_refine_norm005_tt5000_rw_joint_long"
    ),
    reference_candidate_label = c(
      "tail6_gmix005_tt5000_slice_mid240",
      "tail6_gmix025_tt500_slice_mid240",
      "tail6_lap005_tt500_rw_refresh_ultra",
      "tail6_lap005_tt5000_slice_mid240",
      NA, NA
    ),
    reference_path = c(
      NA, NA, NA, NA, NA, NA
    ),
    reference_basename = c(
      NA,
      NA,
      NA,
      NA,
      "mcmc_exdqlm_tau_0p05_fit_rhsns_full_relaunch_20260327.rds",
      "mcmc_exdqlm_tau_0p05_fit_rhsns_full_relaunch_20260327.rds"
    ),
    reason = c(
      "Current synced-base slice alternate was the softest gausmix TT5000 failure; keep that corridor and materially deepen the exact slice budget.",
      "Current synced-base slice primary cleaned up drift for the only tau=0p25 accepted FAIL; keep slice and pay more compute for ESS.",
      "Current synced-base RW primary is the best near-miss in the whole tail; now run the intended joint RW refresh corridor with a real larger budget.",
      "Current synced-base slice alternate looked less bad than RW on the hardest laplace TT5000 row; continue slice rather than reopening weak RW.",
      "Historical RW relaunch already made sigma PASS on the short normal row while gamma remained the only hard blocker; keep RW and deepen it.",
      "Historical RW relaunch made sigma PASS and narrowed gamma drift on the long normal row; keep that RW corridor and pay for a real long run."
    ),
    override_burn = c(
      10000L,
      4000L,
      4000L,
      10000L,
      4000L,
      8000L
    ),
    override_n = c(
      32000L,
      16000L,
      16000L,
      32000L,
      16000L,
      24000L
    ),
    override_proposal = c(
      "slice",
      "slice",
      "laplace_rw",
      "slice",
      "laplace_rw",
      "laplace_rw"
    ),
    override_joint_sample = c(
      FALSE,
      FALSE,
      TRUE,
      FALSE,
      TRUE,
      TRUE
    ),
    override_slice_width = c(
      0.18,
      0.18,
      NA,
      0.18,
      NA,
      NA
    ),
    override_slice_max_steps = c(
      320L,
      320L,
      NA,
      320L,
      NA,
      NA
    ),
    override_laplace_refresh_interval = c(
      NA,
      NA,
      8L,
      NA,
      8L,
      8L
    ),
    override_laplace_refresh_start = c(
      NA,
      NA,
      25L,
      NA,
      25L,
      25L
    ),
    override_laplace_refresh_weight = c(
      NA,
      NA,
      0.92,
      NA,
      0.92,
      0.92
    ),
    stringsAsFactors = FALSE
  )
}

apply_overrides_original288_syncedbase_dynamic_tail6_refine <- function(cfg, spec_row) {
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

read_original288_syncedbase_dynamic_tail6_refine_status <- function(manifest_path = paths_original288_syncedbase_dynamic_tail6_refine()$manifest,
                                                               run_tag = run_tag_original288_syncedbase_dynamic_tail6_refine()) {
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

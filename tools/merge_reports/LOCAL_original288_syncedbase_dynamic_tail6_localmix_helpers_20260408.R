source("tools/merge_reports/LOCAL_original288_syncedbase_faithful_replay_helpers_20260407.R")

predecessor_repo_root_original288_syncedbase_dynamic_tail6_localmix <- function() {
  "/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs"
}

integration_repo_root_original288_syncedbase_dynamic_tail6_localmix <- function() {
  "/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration"
}

run_tag_original288_syncedbase_dynamic_tail6_localmix <- function() {
  "original288_syncedbase_dynamic_tail6_localmix_20260408"
}

variant_tag_original288_syncedbase_dynamic_tail6_localmix <- function() {
  "orig288_sync0p4p0_dynamic_tail6_localmix_20260408"
}

phase_order_original288_syncedbase_dynamic_tail6_localmix <- c(
  phase1_dynamic_tail6_localmix = 1L
)

paths_original288_syncedbase_dynamic_tail6_localmix <- function() {
  tag <- run_tag_original288_syncedbase_dynamic_tail6_localmix()
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", tag))
  list(
    accepted_selection = "tools/merge_reports/LOCAL_original288_carryforward_selection_v7_20260407.csv",
    closure_status = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_manifest_status_20260407.csv",
    tail6_refine_status = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_refine_manifest_status_20260407.csv",
    queue = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_queue_20260408.csv",
    deferred = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_deferred_inventory_20260408.csv",
    schedule = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_schedule_20260408.csv",
    manifest = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_manifest_20260408.csv",
    stage_counts = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_stage_counts_20260408.csv",
    manifest_status = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_manifest_status_20260408.csv",
    phase_summary = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_phase_summary_20260408.csv",
    block_summary = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_block_summary_20260408.csv",
    accepted_compare = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_accepted_compare_20260408.csv",
    config_dir = file.path(run_dir, "configs"),
    program_doc = "reports/static_exal_tuning_20260408/original_288_syncedbase_dynamic_tail6_localmix_program_20260408.md",
    execution_doc = "reports/static_exal_tuning_20260408/original_288_syncedbase_dynamic_tail6_localmix_execution_20260408.md"
  )
}

candidate_fit_path_original288_syncedbase_dynamic_tail6_localmix <- function(run_root, inference, model, tau_label, candidate_label) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    inference,
    sprintf("%s_%s_tau_%s_fit_%s_%s.rds", inference, model, tau_label, variant_tag_original288_syncedbase_dynamic_tail6_localmix(), candidate_label)
  ))
}

vb_candidate_fit_path_original288_syncedbase_dynamic_tail6_localmix <- function(run_root, model, tau_label, candidate_label) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    "vb",
    sprintf("vb_%s_tau_%s_fit_%s_%s.rds", model, tau_label, variant_tag_original288_syncedbase_dynamic_tail6_localmix(), candidate_label)
  ))
}

config_path_original288_syncedbase_dynamic_tail6_localmix <- function(row_id) {
  file.path(
    paths_original288_syncedbase_dynamic_tail6_localmix()$config_dir,
    sprintf("row_%04d_run_config.rds", as.integer(row_id))
  )
}

current_run_root_original288_syncedbase_dynamic_tail6_localmix <- function(source_run_root) {
  normalize_path_original288(sub(
    predecessor_repo_root_original288_syncedbase_dynamic_tail6_localmix(),
    integration_repo_root_original288_syncedbase_dynamic_tail6_localmix(),
    source_run_root,
    fixed = TRUE
  ))
}

derive_dynamic_run_root_from_fit_original288_syncedbase_dynamic_tail6_localmix <- function(fit_path) {
  normalize_path_original288(dirname(dirname(dirname(fit_path))))
}

vb_reference_fit_path_original288_syncedbase_dynamic_tail6_localmix <- function(run_root, model, tau_label) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    "vb",
    sprintf("vb_%s_tau_%s_fit.rds", model, tau_label)
  ))
}

accepted_dynamic_tail_source_original288_syncedbase_dynamic_tail6_localmix <- function() {
  carry <- read.csv(
    paths_original288_syncedbase_dynamic_tail6_localmix()$accepted_selection,
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
    derive_dynamic_run_root_from_fit_original288_syncedbase_dynamic_tail6_localmix,
    character(1)
  )
  x$run_root <- vapply(
    x$source_run_root,
    current_run_root_original288_syncedbase_dynamic_tail6_localmix,
    character(1)
  )
  x$source_run_config_path <- normalize_path_original288(file.path(x$source_run_root, "tables", "run_config.rds"))
  x$sim_output_path <- normalize_path_original288(file.path(dirname(x$source_run_root), "sim_output.rds"))
  x$source_baseline_fit_path <- x$baseline_fit_path
  x$source_selected_fit_path <- x$selected_fit_path
  x$source_reference_fit_path <- x$selected_fit_path
  x$vb_reference_fit_path <- mapply(
    vb_reference_fit_path_original288_syncedbase_dynamic_tail6_localmix,
    x$source_run_root,
    x$model,
    x$tau_label,
    USE.NAMES = FALSE
  )
  x$queue_group <- "accepted_unresolved_tail"
  x$in_scope <- TRUE
  x
}

read_dynamic_closure_status_original288_syncedbase_dynamic_tail6_localmix <- function() {
  read.csv(
    paths_original288_syncedbase_dynamic_tail6_localmix()$closure_status,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

read_source_status_original288_syncedbase_dynamic_tail6_localmix <- function() {
  tail <- accepted_dynamic_tail_source_original288_syncedbase_dynamic_tail6_localmix()

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

read_deferred_inventory_original288_syncedbase_dynamic_tail6_localmix <- function() {
  closure <- read_dynamic_closure_status_original288_syncedbase_dynamic_tail6_localmix()
  closure <- closure[closure$status_row == "done", , drop = FALSE]
  if (nrow(closure)) {
    closure$queue_group <- ifelse(
      closure$accepted_compare == "worse_than_accepted",
      "deferred_dynamic_replay_fail",
      "screened_dynamic_closure_attempt"
    )
    closure$in_scope <- FALSE
  }

  refine <- read.csv(
    paths_original288_syncedbase_dynamic_tail6_localmix()$tail6_refine_status,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  refine <- refine[refine$status_row == "done", , drop = FALSE]
  if (nrow(refine)) {
    refine$queue_group <- "screened_dynamic_tail6_refine_attempt"
    refine$in_scope <- FALSE
  }

  out <- rbind_fill_original288_syncedbase_rerun(list(closure, refine))
  if (!nrow(out)) return(out)
  out
}

reference_fit_path_original288_syncedbase_dynamic_tail6_localmix <- function(target_row,
                                                                           reference_candidate_label = NA_character_,
                                                                           reference_path = NA_character_,
                                                                           reference_basename = NA_character_) {
  if (!is_missing_scalar_original288_syncedbase_rerun(reference_candidate_label)) {
    status <- read_dynamic_closure_status_original288_syncedbase_dynamic_tail6_localmix()
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

schedule_spec_original288_syncedbase_dynamic_tail6_localmix <- function() {
  data.frame(
    phase = rep("phase1_dynamic_tail6_localmix", 6L),
    target_case_key = c(
      "dynamic::gausmix::0p05::5000::default::exdqlm::mcmc",
      "dynamic::gausmix::0p25::500::default::exdqlm::mcmc",
      "dynamic::laplace::0p05::500::default::exdqlm::mcmc",
      "dynamic::laplace::0p05::5000::default::exdqlm::mcmc",
      "dynamic::normal::0p05::500::default::exdqlm::mcmc",
      "dynamic::normal::0p05::5000::default::exdqlm::mcmc"
    ),
    candidate_label = c(
      "tail6_localmix_gmix005_tt5000_slice_true240",
      "tail6_localmix_gmix025_tt500_slice_true240",
      "tail6_localmix_lap005_tt500_rw_true_refresh",
      "tail6_localmix_lap005_tt5000_slice_true240",
      "tail6_localmix_norm005_tt500_rw_adapt_nj",
      "tail6_localmix_norm005_tt5000_rw_adapt_nj_long"
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
      "Dynamic closure never actually ran the intended 0.16/240 slice corridor at its planned 6000 + 18000 budget because manifest overrides were being shadowed. Re-open that exact corridor now that the runner bug is fixed.",
      "This is the clearest ESS-limited near-miss in the whole tail. The intended closure 0.16/240 slice corridor never actually ran at 2000 + 8000, so run that faithful corridor before widening the search again.",
      "The best laplace short-row signal still came from the closure RW-refresh corridor, but that launch only executed at reference-sized budget. Re-run the intended 2500 + 10000 joint refresh corridor faithfully.",
      "Refine deep-slice improved stability on the hardest laplace TT5000 row, but the original 0.16/240 alternate never actually ran at its intended budget. Use that truer efficiency-oriented slice corridor next.",
      "Historical non-joint RW improved sigma most on the short normal row, while the newer joint-deep continuation stayed sticky. Keep the historical RW family, turn adaptation on, and avoid joint deepening.",
      "The long normal row improved under RW but still mixed too slowly. Move back to the stronger historical non-joint RW geometry, keep the historical refresh settings, and enable adaptation for efficiency."
    ),
    override_burn = c(
      6000L,
      2000L,
      2500L,
      6000L,
      3000L,
      6000L
    ),
    override_n = c(
      18000L,
      8000L,
      10000L,
      18000L,
      12000L,
      18000L
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
      FALSE,
      FALSE
    ),
    override_slice_width = c(
      0.16,
      0.16,
      NA,
      0.16,
      NA,
      NA
    ),
    override_slice_max_steps = c(
      240L,
      240L,
      NA,
      240L,
      NA,
      NA
    ),
    override_laplace_refresh_interval = c(
      NA,
      NA,
      10L,
      NA,
      25L,
      25L
    ),
    override_laplace_refresh_start = c(
      NA,
      NA,
      50L,
      NA,
      25L,
      25L
    ),
    override_laplace_refresh_weight = c(
      NA,
      NA,
      0.9,
      NA,
      0.6,
      0.6
    ),
    override_mh_adapt = c(
      NA,
      NA,
      NA,
      NA,
      TRUE,
      TRUE
    ),
    stringsAsFactors = FALSE
  )
}

apply_overrides_original288_syncedbase_dynamic_tail6_localmix <- function(cfg, spec_row) {
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
  if (!all(is.na(spec_row$override_mh_adapt))) {
    cfg$mcmc$mh$adapt <- as.logical(spec_row$override_mh_adapt)[1]
  }

  cfg
}

read_original288_syncedbase_dynamic_tail6_localmix_status <- function(manifest_path = paths_original288_syncedbase_dynamic_tail6_localmix()$manifest,
                                                               run_tag = run_tag_original288_syncedbase_dynamic_tail6_localmix()) {
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

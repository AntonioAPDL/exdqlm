source("tools/merge_reports/LOCAL_original288_syncedbase_faithful_replay_helpers_20260407.R")

predecessor_repo_root_original288_syncedbase_dynamic_final_closure <- function() {
  "/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs"
}

integration_repo_root_original288_syncedbase_dynamic_final_closure <- function() {
  "/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration"
}

run_tag_original288_syncedbase_dynamic_final_closure <- function() {
  "original288_syncedbase_dynamic_final_closure_20260410"
}

variant_tag_original288_syncedbase_dynamic_final_closure <- function() {
  "orig288_sync0p4p0_dynamic_final_closure_20260410"
}

phase_order_original288_syncedbase_dynamic_final_closure <- c(
  phase1_dynamic_reinforcement = 1L,
  phase2_dynamic_broad_repair = 2L
)

paths_original288_syncedbase_dynamic_final_closure <- function() {
  tag <- run_tag_original288_syncedbase_dynamic_final_closure()
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", tag))
  list(
    accepted_selection = "tools/merge_reports/LOCAL_original288_carryforward_selection_v8_20260410.csv",
    closure_status = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_manifest_status_20260407.csv",
    tail6_refine_status = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_refine_manifest_status_20260407.csv",
    tail6_localmix_status = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_manifest_status_20260408.csv",
    queue = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_final_closure_queue_20260410.csv",
    deferred = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_final_closure_deferred_inventory_20260410.csv",
    schedule = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_final_closure_schedule_20260410.csv",
    manifest = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_final_closure_manifest_20260410.csv",
    stage_counts = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_final_closure_stage_counts_20260410.csv",
    manifest_status = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_final_closure_manifest_status_20260410.csv",
    phase_summary = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_final_closure_phase_summary_20260410.csv",
    block_summary = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_final_closure_block_summary_20260410.csv",
    accepted_compare = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_final_closure_accepted_compare_20260410.csv",
    config_dir = file.path(run_dir, "configs"),
    program_doc = "reports/static_exal_tuning_20260410/original_288_syncedbase_dynamic_final_closure_program_20260410.md",
    execution_doc = "reports/static_exal_tuning_20260410/original_288_syncedbase_dynamic_final_closure_execution_20260410.md"
  )
}

candidate_fit_path_original288_syncedbase_dynamic_final_closure <- function(run_root, inference, model, tau_label, candidate_label) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    inference,
    sprintf(
      "%s_%s_tau_%s_fit_%s_%s.rds",
      inference,
      model,
      tau_label,
      variant_tag_original288_syncedbase_dynamic_final_closure(),
      candidate_label
    )
  ))
}

vb_candidate_fit_path_original288_syncedbase_dynamic_final_closure <- function(run_root, model, tau_label, candidate_label) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    "vb",
    sprintf(
      "vb_%s_tau_%s_fit_%s_%s.rds",
      model,
      tau_label,
      variant_tag_original288_syncedbase_dynamic_final_closure(),
      candidate_label
    )
  ))
}

config_path_original288_syncedbase_dynamic_final_closure <- function(row_id) {
  file.path(
    paths_original288_syncedbase_dynamic_final_closure()$config_dir,
    sprintf("row_%04d_run_config.rds", as.integer(row_id))
  )
}

current_run_root_original288_syncedbase_dynamic_final_closure <- function(source_run_root) {
  normalize_path_original288(sub(
    predecessor_repo_root_original288_syncedbase_dynamic_final_closure(),
    integration_repo_root_original288_syncedbase_dynamic_final_closure(),
    source_run_root,
    fixed = TRUE
  ))
}

derive_dynamic_run_root_from_fit_original288_syncedbase_dynamic_final_closure <- function(fit_path) {
  normalize_path_original288(dirname(dirname(dirname(fit_path))))
}

vb_reference_fit_path_original288_syncedbase_dynamic_final_closure <- function(run_root, model, tau_label) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    "vb",
    sprintf("vb_%s_tau_%s_fit.rds", model, tau_label)
  ))
}

accepted_dynamic_tail_source_original288_syncedbase_dynamic_final_closure <- function() {
  carry <- read.csv(
    paths_original288_syncedbase_dynamic_final_closure()$accepted_selection,
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
    derive_dynamic_run_root_from_fit_original288_syncedbase_dynamic_final_closure,
    character(1)
  )
  x$run_root <- vapply(
    x$source_run_root,
    current_run_root_original288_syncedbase_dynamic_final_closure,
    character(1)
  )
  x$source_run_config_path <- normalize_path_original288(file.path(x$source_run_root, "tables", "run_config.rds"))
  x$sim_output_path <- normalize_path_original288(file.path(dirname(x$source_run_root), "sim_output.rds"))
  x$source_baseline_fit_path <- x$baseline_fit_path
  x$source_selected_fit_path <- x$selected_fit_path
  x$source_reference_fit_path <- x$selected_fit_path
  x$vb_reference_fit_path <- mapply(
    vb_reference_fit_path_original288_syncedbase_dynamic_final_closure,
    x$source_run_root,
    x$model,
    x$tau_label,
    USE.NAMES = FALSE
  )
  x$queue_group <- "accepted_unresolved_tail"
  x$in_scope <- TRUE
  x
}

read_status_file_original288_syncedbase_dynamic_final_closure <- function(path, queue_group) {
  if (!file.exists(path)) return(data.frame())
  x <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  x <- x[x$status_row == "done", , drop = FALSE]
  if (!nrow(x)) return(x)
  x$queue_group <- queue_group
  x$in_scope <- FALSE
  x
}

read_prior_dynamic_attempt_status_original288_syncedbase_dynamic_final_closure <- function() {
  paths <- paths_original288_syncedbase_dynamic_final_closure()
  out <- rbind_fill_original288_syncedbase_rerun(list(
    read_status_file_original288_syncedbase_dynamic_final_closure(
      paths$closure_status,
      "screened_dynamic_closure_attempt"
    ),
    read_status_file_original288_syncedbase_dynamic_final_closure(
      paths$tail6_refine_status,
      "screened_dynamic_tail6_refine_attempt"
    ),
    read_status_file_original288_syncedbase_dynamic_final_closure(
      paths$tail6_localmix_status,
      "screened_dynamic_tail6_localmix_attempt"
    )
  ))
  out
}

read_source_status_original288_syncedbase_dynamic_final_closure <- function() {
  tail <- accepted_dynamic_tail_source_original288_syncedbase_dynamic_final_closure()

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

read_deferred_inventory_original288_syncedbase_dynamic_final_closure <- function() {
  read_prior_dynamic_attempt_status_original288_syncedbase_dynamic_final_closure()
}

reference_fit_path_original288_syncedbase_dynamic_final_closure <- function(target_row,
                                                                            reference_candidate_label = NA_character_,
                                                                            reference_path = NA_character_,
                                                                            reference_basename = NA_character_) {
  fallback_path <- normalize_path_original288(target_row$source_reference_fit_path)
  if (!file.exists(fallback_path)) {
    stop(sprintf("Missing fallback reference fit for %s: %s", target_row$original_case_key, fallback_path))
  }
  if (!is_missing_scalar_original288_syncedbase_rerun(reference_candidate_label)) {
    status <- read_prior_dynamic_attempt_status_original288_syncedbase_dynamic_final_closure()
    hit <- subset(
      status,
      planned_candidate_label == reference_candidate_label &
        original_case_key == target_row$original_case_key
    )
    if (nrow(hit) != 1L) {
      stop(sprintf(
        "Expected exactly one prior reference for %s / %s, found %d",
        target_row$original_case_key,
        reference_candidate_label,
        nrow(hit)
      ))
    }
    path <- normalize_path_original288(hit$candidate_fit_path[1])
    if (file.exists(path)) {
      return(path)
    }
    return(fallback_path)
  }
  if (!is_missing_scalar_original288_syncedbase_rerun(reference_path)) {
    path <- normalize_path_original288(reference_path)
    if (file.exists(path)) {
      return(path)
    }
    return(fallback_path)
  }
  if (is_missing_scalar_original288_syncedbase_rerun(reference_basename)) {
    return(fallback_path)
  }
  path <- normalize_path_original288(file.path(dirname(target_row$source_reference_fit_path), reference_basename))
  if (file.exists(path)) {
    return(path)
  }
  fallback_path
}

schedule_spec_original288_syncedbase_dynamic_final_closure <- function() {
  data.frame(
    phase = c(
      rep("phase1_dynamic_reinforcement", 12L),
      rep("phase2_dynamic_broad_repair", 12L)
    ),
    target_case_key = c(
      "dynamic::gausmix::0p05::5000::default::exdqlm::mcmc",
      "dynamic::gausmix::0p05::5000::default::exdqlm::mcmc",
      "dynamic::gausmix::0p25::500::default::exdqlm::mcmc",
      "dynamic::gausmix::0p25::500::default::exdqlm::mcmc",
      "dynamic::laplace::0p05::500::default::exdqlm::mcmc",
      "dynamic::laplace::0p05::500::default::exdqlm::mcmc",
      "dynamic::laplace::0p05::5000::default::exdqlm::mcmc",
      "dynamic::laplace::0p05::5000::default::exdqlm::mcmc",
      "dynamic::normal::0p05::500::default::exdqlm::mcmc",
      "dynamic::normal::0p05::500::default::exdqlm::mcmc",
      "dynamic::normal::0p05::5000::default::exdqlm::mcmc",
      "dynamic::normal::0p05::5000::default::exdqlm::mcmc",
      "dynamic::gausmix::0p05::5000::default::exdqlm::mcmc",
      "dynamic::gausmix::0p05::5000::default::exdqlm::mcmc",
      "dynamic::gausmix::0p25::500::default::exdqlm::mcmc",
      "dynamic::gausmix::0p25::500::default::exdqlm::mcmc",
      "dynamic::laplace::0p05::500::default::exdqlm::mcmc",
      "dynamic::laplace::0p05::500::default::exdqlm::mcmc",
      "dynamic::laplace::0p05::5000::default::exdqlm::mcmc",
      "dynamic::laplace::0p05::5000::default::exdqlm::mcmc",
      "dynamic::normal::0p05::500::default::exdqlm::mcmc",
      "dynamic::normal::0p05::500::default::exdqlm::mcmc",
      "dynamic::normal::0p05::5000::default::exdqlm::mcmc",
      "dynamic::normal::0p05::5000::default::exdqlm::mcmc"
    ),
    candidate_label = c(
      "final_gmix005_tt5000_slice_deep320_long",
      "final_gmix005_tt5000_slice_wide360_xlong",
      "final_gmix025_tt500_slice_deep320_long",
      "final_gmix025_tt500_slice_deep400_xlong",
      "final_lap005_tt500_rw_refresh_refine_long",
      "final_lap005_tt500_rw_refresh_noadapt",
      "final_lap005_tt5000_slice_deep320_long",
      "final_lap005_tt5000_slice_wide360_xlong",
      "final_norm005_tt500_rw_joint_refine_long",
      "final_norm005_tt500_rw_nonjoint_adapt_long",
      "final_norm005_tt5000_rw_joint_xlong",
      "final_norm005_tt5000_rw_nonjoint_adapt_xlong",
      "final_gmix005_tt5000_slice_mid280_long",
      "final_gmix005_tt5000_rw_refresh_ultra_hedge",
      "final_gmix025_tt500_slice_mid280_balanced",
      "final_gmix025_tt500_slice_wide360_balanced",
      "final_lap005_tt500_slice_deep320_hedge",
      "final_lap005_tt500_rw_refresh_ultra_xlong",
      "final_lap005_tt5000_slice_mid280_long",
      "final_lap005_tt5000_rw_refresh_hedge",
      "final_norm005_tt500_slice_deep320_long",
      "final_norm005_tt500_slice_wide360_long",
      "final_norm005_tt5000_rw_joint_noadapt_xlong",
      "final_norm005_tt5000_slice_deep320_hedge"
    ),
    reference_candidate_label = c(
      "tail6_refine_gmix005_tt5000_slice_deep320",
      "tail6_refine_gmix005_tt5000_slice_deep320",
      "tail6_refine_gmix025_tt500_slice_deep320",
      "tail6_refine_gmix025_tt500_slice_deep320",
      "tail6_refine_lap005_tt500_rw_joint_deep",
      "tail6_refine_lap005_tt500_rw_joint_deep",
      "tail6_refine_lap005_tt5000_slice_deep320",
      "tail6_refine_lap005_tt5000_slice_deep320",
      "tail6_refine_norm005_tt500_rw_joint_deep",
      "tail6_localmix_norm005_tt500_rw_adapt_nj",
      "tail6_refine_norm005_tt5000_rw_joint_long",
      "tail6_localmix_norm005_tt5000_rw_adapt_nj_long",
      "tail6_refine_gmix005_tt5000_slice_deep320",
      "tail6_gmix005_tt5000_rw_refresh_ultra",
      "tail6_refine_gmix025_tt500_slice_deep320",
      "tail6_refine_gmix025_tt500_slice_deep320",
      "tail6_lap005_tt500_rw_refresh_ultra",
      "tail6_lap005_tt500_rw_refresh_ultra",
      "tail6_refine_lap005_tt5000_slice_deep320",
      "tail6_lap005_tt5000_rw_refresh_ultra",
      "tail6_norm005_tt500_slice_mid240",
      "tail6_norm005_tt500_slice_mid240",
      "tail6_refine_norm005_tt5000_rw_joint_long",
      "tail6_norm005_tt5000_slice_mid240"
    ),
    reference_path = NA_character_,
    reference_basename = NA_character_,
    reason = c(
      "Use the strongest prior gausmix TT5000 slice corridor and extend it materially; this row improved under deep slice and still looks like an ESS-limited exact-kernel problem.",
      "Push the hardest gausmix TT5000 row into a wider exact-kernel corridor rather than replaying the weak 0.16/240 alternate again.",
      "Reinforce the strongest tau=0.25 gausmix near-miss with more post-burn draw budget before abandoning slice on the only mid-tail dynamic failure.",
      "Keep gausmix tau=0.25 on slice, but push step depth further so the run explores one genuinely more aggressive corridor instead of repeating the refine default.",
      "The short laplace row still prefers RW over slice; keep the refine-style RW family and pay more budget for mixing rather than pivoting away from the best family.",
      "Check whether adaptation is the part still hurting the short laplace row by turning it off while keeping the strongest RW family otherwise intact.",
      "The hard laplace TT5000 row still looks best under slice; keep that family and widen compute rather than reopening the already screened faithful 0.16/240 corridor.",
      "Use one wider slice corridor on the hardest laplace long row so the overnight lane explores a real exact-kernel expansion rather than only incremental length.",
      "Normal TT500 remains difficult; reinforce the best joint-RW corridor once more at a longer budget before treating the row as purely slice-driven.",
      "Keep a non-joint adaptive RW hedge alive on the short normal row because joint RW and slice each solved different parts of the failure and this row still needs a hybrid search.",
      "The long normal row improved most under joint RW; extend that exact corridor substantially and make it the main reinforcement target.",
      "Retain a non-joint adaptive RW hedge for the long normal row because the localmix geometry softened some diagnostics even though it did not clear the gate.",
      "Give gausmix TT5000 a mid-width slice hedge that still stays inside the slice family, because 0.16/240 was too weak and 0.20/360 might overshoot.",
      "Reopen one RW hedge on gausmix TT5000 only because the original RW lane improved gamma a lot; this is the only non-slice hedge retained for that row.",
      "Use a balanced-width slice hedge on the tau=0.25 gausmix short row so the search is broad within the family that has been consistently least bad.",
      "Probe a second wider slice corridor on gausmix tau=0.25 to make the mid-tail search broader without spending on clearly weaker RW families.",
      "Add one real slice hedge on the short laplace row so the overnight lane still tests whether gamma instability is more slice-fixable than the current RW signal suggests.",
      "Stretch the best short laplace RW corridor much further; this is the one row where a simple longer RW reinforcement is still high-value.",
      "Use a mid-width slice hedge on the long laplace row so the search covers both 0.18/320-style and slightly softer exact-kernel corridors.",
      "Keep one RW hedge on the long laplace row only because the failure remains severe enough to justify a non-slice fallback if deeper slice still fails.",
      "Short normal still has no clear kernel winner; deepen the slice side seriously instead of leaving slice as only a token hedge.",
      "Add one wider slice hedge on short normal so the overnight lane gives slice a fair test against the renewed RW family.",
      "Turn adaptation off on the long normal joint-RW corridor to test whether adaptation is now the main thing holding back the best long normal geometry.",
      "Retain one exact-kernel hedge on the long normal row because gamma may still be the binding problem even if RW is the better general family."
    ),
    override_burn = c(
      12000L, 14000L, 5000L, 6000L, 4500L, 4000L, 12000L, 14000L, 5000L, 4500L, 10000L, 9000L,
      10000L, 10000L, 4500L, 5000L, 4000L, 5000L, 10000L, 10000L, 4500L, 5000L, 10000L, 12000L
    ),
    override_n = c(
      36000L, 42000L, 20000L, 24000L, 18000L, 16000L, 36000L, 42000L, 20000L, 18000L, 30000L, 28000L,
      32000L, 30000L, 18000L, 20000L, 16000L, 20000L, 32000L, 30000L, 18000L, 20000L, 30000L, 36000L
    ),
    override_proposal = c(
      "slice", "slice", "slice", "slice", "laplace_rw", "laplace_rw", "slice", "slice", "laplace_rw", "laplace_rw", "laplace_rw", "laplace_rw",
      "slice", "laplace_rw", "slice", "slice", "slice", "laplace_rw", "slice", "laplace_rw", "slice", "slice", "laplace_rw", "slice"
    ),
    override_joint_sample = c(
      FALSE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE, FALSE, TRUE, FALSE, TRUE, FALSE,
      FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, FALSE
    ),
    override_slice_width = c(
      0.18, 0.20, 0.18, 0.18, NA, NA, 0.18, 0.20, NA, NA, NA, NA,
      0.17, NA, 0.17, 0.20, 0.18, NA, 0.17, NA, 0.18, 0.20, NA, 0.18
    ),
    override_slice_max_steps = c(
      320L, 360L, 320L, 400L, NA, NA, 320L, 360L, NA, NA, NA, NA,
      280L, NA, 280L, 360L, 320L, NA, 280L, NA, 320L, 360L, NA, 320L
    ),
    override_laplace_refresh_interval = c(
      NA, NA, NA, NA, 8L, 8L, NA, NA, 8L, 25L, 8L, 25L,
      NA, 8L, NA, NA, NA, 10L, NA, 8L, NA, NA, 8L, NA
    ),
    override_laplace_refresh_start = c(
      NA, NA, NA, NA, 25L, 25L, NA, NA, 25L, 25L, 25L, 25L,
      NA, 25L, NA, NA, NA, 50L, NA, 25L, NA, NA, 25L, NA
    ),
    override_laplace_refresh_weight = c(
      NA, NA, NA, NA, 0.92, 0.92, NA, NA, 0.92, 0.60, 0.92, 0.60,
      NA, 0.92, NA, NA, NA, 0.90, NA, 0.92, NA, NA, 0.92, NA
    ),
    override_mh_adapt = c(
      FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, TRUE, TRUE,
      FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE
    ),
    stringsAsFactors = FALSE
  )
}

apply_overrides_original288_syncedbase_dynamic_final_closure <- function(cfg, spec_row) {
  cfg$mcmc <- cfg$mcmc %||% list()
  cfg$mcmc$mh <- cfg$mcmc$mh %||% list()

  if (is.finite(safe_int_original288_syncedbase_rerun(spec_row$override_burn, NA_integer_))) {
    cfg$mcmc$burn <- safe_int_original288_syncedbase_rerun(spec_row$override_burn, NA_integer_)
  }
  if (is.finite(safe_int_original288_syncedbase_rerun(spec_row$override_n, NA_integer_))) {
    cfg$mcmc$n <- safe_int_original288_syncedbase_rerun(spec_row$override_n, NA_integer_)
  }
  if (!is_missing_scalar_original288_syncedbase_rerun(spec_row$override_proposal)) {
    cfg$mcmc$mh$proposal <- safe_chr_original288_syncedbase_rerun(
      spec_row$override_proposal,
      cfg$mcmc$mh$proposal %||% "laplace_rw"
    )
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

read_original288_syncedbase_dynamic_final_closure_status <- function(
    manifest_path = paths_original288_syncedbase_dynamic_final_closure()$manifest,
    run_tag = run_tag_original288_syncedbase_dynamic_final_closure()) {
  read_original288_syncedbase_rerun_status(manifest_path = manifest_path, run_tag = run_tag)
}

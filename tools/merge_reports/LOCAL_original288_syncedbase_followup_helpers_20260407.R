source("tools/merge_reports/LOCAL_original288_syncedbase_faithful_replay_helpers_20260407.R")

run_tag_original288_syncedbase_followup <- function() {
  "original288_syncedbase_targeted_followup_20260407"
}

variant_tag_original288_syncedbase_followup <- function() {
  "orig288_sync0p4p0_followup_20260407"
}

phase_order_original288_syncedbase_followup <- c(
  phase1_static_exal_primary = 1L,
  phase2_static_exal_rowlocal = 2L,
  phase3_dynamic_exdqlm_exactlong = 3L,
  phase4_stability_review = 4L
)

paths_original288_syncedbase_followup <- function() {
  tag <- run_tag_original288_syncedbase_followup()
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", tag))
  list(
    accepted_selection = "tools/merge_reports/LOCAL_original288_carryforward_selection_v6_20260407.csv",
    source_status = "tools/merge_reports/LOCAL_original288_syncedbase_residual_manifest_status_20260407.csv",
    unresolved_dynamic = "tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v6_20260407.csv",
    queue = "tools/merge_reports/LOCAL_original288_syncedbase_followup_queue_20260407.csv",
    deferred = "tools/merge_reports/LOCAL_original288_syncedbase_followup_deferred_dynamic_tail_20260407.csv",
    schedule = "tools/merge_reports/LOCAL_original288_syncedbase_followup_schedule_20260407.csv",
    manifest = "tools/merge_reports/LOCAL_original288_syncedbase_followup_manifest_20260407.csv",
    stage_counts = "tools/merge_reports/LOCAL_original288_syncedbase_followup_stage_counts_20260407.csv",
    manifest_status = "tools/merge_reports/LOCAL_original288_syncedbase_followup_manifest_status_20260407.csv",
    phase_summary = "tools/merge_reports/LOCAL_original288_syncedbase_followup_phase_summary_20260407.csv",
    block_summary = "tools/merge_reports/LOCAL_original288_syncedbase_followup_block_summary_20260407.csv",
    accepted_compare = "tools/merge_reports/LOCAL_original288_syncedbase_followup_accepted_compare_20260407.csv",
    config_dir = file.path(run_dir, "configs"),
    program_doc = "reports/static_exal_tuning_20260407/original_288_syncedbase_targeted_followup_program_20260407.md",
    execution_doc = "reports/static_exal_tuning_20260407/original_288_syncedbase_targeted_followup_execution_20260407.md"
  )
}

candidate_fit_path_original288_syncedbase_followup <- function(run_root, inference, model, tau_label, candidate_label) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    inference,
    sprintf("%s_%s_tau_%s_fit_%s_%s.rds", inference, model, tau_label, variant_tag_original288_syncedbase_followup(), candidate_label)
  ))
}

vb_candidate_fit_path_original288_syncedbase_followup <- function(run_root, model, tau_label, candidate_label) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    "vb",
    sprintf("vb_%s_tau_%s_fit_%s_%s.rds", model, tau_label, variant_tag_original288_syncedbase_followup(), candidate_label)
  ))
}

config_path_original288_syncedbase_followup <- function(row_id) {
  file.path(
    paths_original288_syncedbase_followup()$config_dir,
    sprintf("row_%04d_run_config.rds", as.integer(row_id))
  )
}

read_source_status_original288_syncedbase_followup <- function() {
  x <- read.csv(
    paths_original288_syncedbase_followup()$source_status,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  x$queue_group <- ifelse(
    x$gate_current == "FAIL" &
      x$inference == "mcmc" &
      (
        (x$block %in% c("static_paper", "static_shrink") & x$model == "exal") |
          (x$block == "dynamic" & x$model == "exdqlm")
      ),
    "followup_fail",
    ifelse(
      x$accepted_gate == "PASS" & x$gate_current == "WARN" &
        x$inference == "mcmc" &
        x$block %in% c("static_paper", "static_shrink") &
        x$model %in% c("al", "exal"),
      "followup_warn_review",
      "out_of_scope"
    )
  )
  x$in_scope <- x$queue_group %in% c("followup_fail", "followup_warn_review")
  x
}

read_deferred_unresolved_dynamic_original288_syncedbase_followup <- function() {
  x <- read.csv(
    paths_original288_syncedbase_followup()$unresolved_dynamic,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  if (!nrow(x)) return(x)
  x$queue_group <- "deferred_accepted_unresolved_tail"
  x$in_scope <- FALSE
  x
}

reference_fit_path_original288_syncedbase_followup <- function(target_row, reference_basename = NA_character_) {
  if (is_missing_scalar_original288_syncedbase_rerun(reference_basename)) {
    return(normalize_path_original288(target_row$source_reference_fit_path))
  }
  path <- normalize_path_original288(file.path(dirname(target_row$source_reference_fit_path), reference_basename))
  if (!file.exists(path)) {
    stop(sprintf("Missing reference fit for %s: %s", target_row$original_case_key, path))
  }
  path
}

schedule_spec_original288_syncedbase_followup <- function() {
  data.frame(
    phase = c(
      rep("phase1_static_exal_primary", 16L),
      rep("phase2_static_exal_rowlocal", 6L),
      rep("phase3_dynamic_exdqlm_exactlong", 3L),
      rep("phase4_stability_review", 4L)
    ),
    target_case_key = c(
      "static_paper::gausmix::0p25::1000::paper::exal::mcmc",
      "static_paper::gausmix::0p95::1000::paper::exal::mcmc",
      "static_paper::laplace::0p95::1000::paper::exal::mcmc",
      "static_paper::normal::0p25::100::paper::exal::mcmc",
      "static_paper::normal::0p25::1000::paper::exal::mcmc",
      "static_paper::normal::0p95::1000::paper::exal::mcmc",
      "static_shrink::gausmix::0p05::100::ridge::exal::mcmc",
      "static_shrink::gausmix::0p05::1000::ridge::exal::mcmc",
      "static_shrink::gausmix::0p25::100::ridge::exal::mcmc",
      "static_shrink::gausmix::0p95::1000::ridge::exal::mcmc",
      "static_shrink::laplace::0p05::100::ridge::exal::mcmc",
      "static_shrink::laplace::0p95::1000::ridge::exal::mcmc",
      "static_shrink::normal::0p25::100::ridge::exal::mcmc",
      "static_shrink::gausmix::0p05::1000::rhs::exal::mcmc",
      "static_shrink::laplace::0p95::1000::rhs::exal::mcmc",
      "static_shrink::normal::0p05::100::rhs::exal::mcmc",
      "static_paper::gausmix::0p25::1000::paper::exal::mcmc",
      "static_paper::gausmix::0p25::1000::paper::exal::mcmc",
      "static_paper::normal::0p25::1000::paper::exal::mcmc",
      "static_shrink::gausmix::0p05::100::ridge::exal::mcmc",
      "static_shrink::gausmix::0p05::1000::ridge::exal::mcmc",
      "static_shrink::laplace::0p95::1000::rhs::exal::mcmc",
      "dynamic::gausmix::0p05::500::default::exdqlm::mcmc",
      "dynamic::laplace::0p25::500::default::exdqlm::mcmc",
      "dynamic::normal::0p25::500::default::exdqlm::mcmc",
      "static_paper::normal::0p05::100::paper::exal::mcmc",
      "static_shrink::gausmix::0p95::100::rhs::al::mcmc",
      "static_shrink::normal::0p05::100::rhs::al::mcmc",
      "static_shrink::normal::0p95::1000::rhs::exal::mcmc"
    ),
    candidate_label = c(
      "row152_row87_histshort",
      "row156_rhsns_current",
      "row168_rhsns_impl",
      "row174_rhsns_current",
      "row176_row135_histshort",
      "row180_rhsns_current",
      "row182_rhsns_impl",
      "row184_rhsns_current",
      "row186_rhsns_current",
      "row192_failband2_f085",
      "row194_rhsns_current",
      "row204_rhsns_current",
      "row210_rhsns_current",
      "row220_rhsns_current",
      "row240_rhsns_current",
      "row242_rhsns_current",
      "row152_row87_medium",
      "row152_row87_none",
      "row176_failband2_f085",
      "row182_tierbc_repairb",
      "row184_tierbc_repairb",
      "row240_failband2_f085",
      "row254_rw_exactlong",
      "row266_slice_exactlong",
      "row276_slice_exactlong",
      "row170_passconfirm_long",
      "row225_passconfirm_long",
      "row241_passconfirm_long",
      "row252_passconfirm_long"
    ),
    reference_basename = c(
      "mcmc_exal_tau_0p25_fit_row87fix11_R87_F085_sub2_s1025_histshort_seed2026079087.rds",
      "mcmc_exal_tau_0p95_fit_static_exal_f080_sub2_s105_rhsns_current_20260403.rds",
      "mcmc_exal_tau_0p95_fit_rhsns_impl_refresh_20260329.rds",
      "mcmc_exal_tau_0p25_fit_static_exal_f080_sub2_s105_rhsns_current_20260403.rds",
      "mcmc_exal_tau_0p25_fit_rowfix9_R135_F0825_sub2_s105_histshort_seed2026054135.rds",
      "mcmc_exal_tau_0p95_fit_static_exal_f080_sub2_s105_rhsns_current_20260403.rds",
      "mcmc_exal_tau_0p05_fit_rhsns_impl_refresh_20260329.rds",
      "mcmc_exal_tau_0p05_fit_static_exal_f080_sub2_s105_rhsns_current_20260403.rds",
      "mcmc_exal_tau_0p25_fit_static_exal_f080_sub2_s105_rhsns_current_20260403.rds",
      "mcmc_exal_tau_0p95_fit_failband2_F085_sub2_s100.rds",
      "mcmc_exal_tau_0p05_fit_static_exal_f080_sub2_s105_rhsns_current_20260403.rds",
      "mcmc_exal_tau_0p95_fit_static_exal_f080_sub2_s105_rhsns_current_20260403.rds",
      "mcmc_exal_tau_0p25_fit_static_exal_f080_sub2_s105_rhsns_current_20260403.rds",
      "mcmc_exal_tau_0p05_fit_static_exal_f080_sub2_s105_rhsns_current_20260403.rds",
      "mcmc_exal_tau_0p95_fit_static_exal_f080_sub2_s105_rhsns_current_20260403.rds",
      "mcmc_exal_tau_0p05_fit_static_exal_f080_sub2_s105_rhsns_current_20260403.rds",
      "mcmc_exal_tau_0p25_fit_row87fix11_R87_F0825_sub2_s100_medium_seed2026111087.rds",
      "mcmc_exal_tau_0p25_fit_row87fix11_R87_F0825_sub2_s1025_none_seed2026116087.rds",
      "mcmc_exal_tau_0p25_fit_failband2_F085_sub2_s100.rds",
      "mcmc_exal_tau_0p05_fit_tierBC_repairB_rollout8_20260323_Q14_exal_tau0p05_tt100_gausmix.rds",
      "mcmc_exal_tau_0p05_fit_tierBC_repairB_rollout8_20260323_Q16_exal_tau0p05_tt1000_gausmix.rds",
      "mcmc_exal_tau_0p95_fit_failband2_F085_sub2_s100.rds",
      NA_character_,
      NA_character_,
      NA_character_,
      NA_character_,
      NA_character_,
      NA_character_,
      NA_character_
    ),
    reason = c(
      "Row-87 best historical low-mid anchor; highest-value same-scenario rescue corridor.",
      "Small-candidate paper row; switch baseline failure to the strongest current rhsns refresh family.",
      "Current rhsns replay failed; fall back to earlier rhsns implementation refresh in the same scenario.",
      "Small-candidate paper row; use current rhsns refresh rather than plain baseline.",
      "Row-135 exact-none replay failed; pivot to the same row-local histshort corridor instead of repeating the same seed path.",
      "Small-candidate paper row; current rhsns refresh is the strongest reusable local family on disk.",
      "Accepted current rhsns replay failed; try the lighter rhsns implementation refresh before widening further.",
      "High-value ridge residual; current rhsns refresh remains the best broad local static profile on disk.",
      "Compact ridge row with only one strong reusable tuned family on disk; try current rhsns refresh.",
      "Large ridge residual bank; broad failband2 F085 remains the strongest documented static default.",
      "Compact ridge row; use current rhsns refresh instead of the plain baseline replay.",
      "Compact ridge row; use current rhsns refresh instead of the plain baseline replay.",
      "Compact ridge row; use current rhsns refresh instead of the plain baseline replay.",
      "rhs row must stay rhs_ns; current rhsns refresh is the strongest reusable local family on disk.",
      "Legacy rhs refresh failed exact replay; switch to the current rhsns refresh family.",
      "rhs row must stay rhs_ns; current rhsns refresh is the strongest reusable local family on disk.",
      "Second row-87 anchor to confirm whether the low-mid medium corridor is more stable than the promoted short replay.",
      "Third row-87 anchor to test whether the none-init lower-mid branch is more robust on the synced base.",
      "Fallback broad static default for the row-135 case after the row-local exact replay regressed.",
      "Escalate the same-scenario gausmix ridge case to its old tier-B/C repair candidate after rhsns_impl still looked fragile.",
      "Escalate the same-scenario gausmix ridge TT1000 case to its old tier-B/C repair candidate rather than repeating the same broad family.",
      "Fallback broad failband2 F085 on the legacy rhs row after the legacy refresh exact replay regressed.",
      "Same-kernel RW replay only failed on gamma mixing; keep the accepted refresh corridor and extend runtime budget.",
      "Same-kernel slice replay only failed on gamma mixing; keep the accepted slice corridor and extend runtime budget.",
      "Same-kernel slice replay failed on sigma/gamma mixing; keep the accepted slice corridor and extend runtime budget.",
      "Accepted PASS downgraded to WARN; confirm the same good failband2 corridor with a longer budget instead of opening a new family.",
      "Accepted PASS downgraded to WARN after the al bugfix lane; verify whether more draws recover PASS without changing the kernel family.",
      "Accepted PASS downgraded to WARN after the al bugfix lane; verify whether more draws recover PASS without changing the kernel family.",
      "Accepted PASS downgraded to WARN on current rhsns refresh; keep the same profile and extend runtime before broader changes."
    ),
    override_burn = c(
      rep(NA_integer_, 22L),
      3000L, 1200L, 1600L,
      4500L, 4500L, 4500L, 4500L
    ),
    override_n = c(
      rep(NA_integer_, 22L),
      9000L, 5000L, 6000L,
      12000L, 12000L, 12000L, 12000L
    ),
    override_proposal = c(
      rep(NA_character_, 22L),
      NA_character_, NA_character_, NA_character_,
      NA_character_, NA_character_, NA_character_, NA_character_
    ),
    override_joint_sample = c(
      rep(NA, 22L),
      NA, NA, NA,
      NA, NA, NA, NA
    ),
    override_slice_width = c(
      rep(NA_real_, 22L),
      NA_real_, NA_real_, NA_real_,
      NA_real_, NA_real_, NA_real_, NA_real_
    ),
    override_slice_max_steps = c(
      rep(NA_integer_, 22L),
      NA_integer_, NA_integer_, NA_integer_,
      NA_integer_, NA_integer_, NA_integer_, NA_integer_
    ),
    override_laplace_refresh_interval = c(
      rep(NA_integer_, 22L),
      NA_integer_, NA_integer_, NA_integer_,
      NA_integer_, NA_integer_, NA_integer_, NA_integer_
    ),
    override_laplace_refresh_start = c(
      rep(NA_integer_, 22L),
      NA_integer_, NA_integer_, NA_integer_,
      NA_integer_, NA_integer_, NA_integer_, NA_integer_
    ),
    override_laplace_refresh_weight = c(
      rep(NA_real_, 22L),
      NA_real_, NA_real_, NA_real_,
      NA_real_, NA_real_, NA_real_, NA_real_
    ),
    stringsAsFactors = FALSE
  )
}

apply_overrides_original288_syncedbase_followup <- function(cfg, spec_row) {
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

read_original288_syncedbase_followup_status <- function(manifest_path = paths_original288_syncedbase_followup()$manifest,
                                                        run_tag = run_tag_original288_syncedbase_followup()) {
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

source("tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_helpers_20260409.R")

run_tag_original288_static_shrink_rhsns_exal_mcmc_repair <- function() {
  "original288_static_shrink_rhsns_exal_mcmc_repair_20260410"
}

variant_tag_original288_static_shrink_rhsns_exal_mcmc_repair <- function() {
  "orig288_static_shrink_rhsns_exal_mcmc_repair_20260410"
}

phase_order_original288_static_shrink_rhsns_exal_mcmc_repair <- c(
  phase1_static_shrink_rhsns_exal_mcmc_crash_repair = 1L,
  phase2_static_shrink_rhsns_exal_mcmc_mixing_repair = 2L
)

paths_original288_static_shrink_rhsns_exal_mcmc_repair <- function() {
  tag <- run_tag_original288_static_shrink_rhsns_exal_mcmc_repair()
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", tag))
  list(
    accepted_selection = "tools/merge_reports/LOCAL_original288_carryforward_selection_v7_20260407.csv",
    rebuild_manifest_status = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_manifest_status_20260409.csv",
    schedule = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_schedule_20260410.csv",
    manifest = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_manifest_20260410.csv",
    stage_counts = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_stage_counts_20260410.csv",
    manifest_status = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_manifest_status_20260410.csv",
    phase_summary = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_phase_summary_20260410.csv",
    target_summary = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_target_summary_20260410.csv",
    compare_accepted = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_compare_accepted_20260410.csv",
    compare_rebuild = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_compare_rebuild_20260410.csv",
    config_dir = file.path(run_dir, "configs"),
    rows_dir = file.path(run_dir, "rows"),
    health_dir = file.path(run_dir, "health"),
    metrics_dir = file.path(run_dir, "metrics"),
    logs_dir = file.path(run_dir, "logs"),
    tracker_doc = "reports/static_exal_tuning_20260406/integration_branch_validation_status_20260406.md",
    static_tracker_doc = "tools/merge_reports/LOCAL_VALIDATION_RECOVERY_TRACKER_STATIC_EXAL_20260331.md",
    program_doc = "reports/static_exal_tuning_20260410/original_288_static_shrink_rhsns_exal_mcmc_repair_program_20260410.md",
    execution_doc = "reports/static_exal_tuning_20260410/original_288_static_shrink_rhsns_exal_mcmc_repair_execution_20260410.md"
  )
}

sanitize_profile_slug_original288_static_shrink_rhsns_exal_mcmc_repair <- function(x) {
  x <- tolower(safe_chr_original288_syncedbase_rerun(x, "profile"))
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  if (!nzchar(x)) "profile" else x
}

target_run_root_original288_static_shrink_rhsns_exal_mcmc_repair <- function(repo_root, family, tau_label, fit_size) {
  normalize_path_original288(file.path(
    repo_root,
    "results",
    "function_testing_20260309_static_shrinkage_family_qspec",
    family,
    sprintf("tau_%s", tau_label),
    sprintf("fit_input_subsample_tt%d_x01_sorted", as.integer(fit_size)),
    sprintf("validation_shrink_rhsns_repair_tt%d", as.integer(fit_size))
  ))
}

candidate_fit_path_original288_static_shrink_rhsns_exal_mcmc_repair <- function(
    run_root,
    inference,
    model,
    tau_label,
    profile_id) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    inference,
    sprintf(
      "%s_%s_tau_%s_fit_%s__%s.rds",
      inference,
      model,
      tau_label,
      variant_tag_original288_static_shrink_rhsns_exal_mcmc_repair(),
      sanitize_profile_slug_original288_static_shrink_rhsns_exal_mcmc_repair(profile_id)
    )
  ))
}

config_path_original288_static_shrink_rhsns_exal_mcmc_repair <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_exal_mcmc_repair()$config_dir,
    sprintf("row_%04d_run_config.rds", as.integer(row_id))
  )
}

row_status_path_original288_static_shrink_rhsns_exal_mcmc_repair <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_exal_mcmc_repair()$rows_dir,
    sprintf("row_%04d.csv", as.integer(row_id))
  )
}

health_path_original288_static_shrink_rhsns_exal_mcmc_repair <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_exal_mcmc_repair()$health_dir,
    sprintf("health_%04d.csv", as.integer(row_id))
  )
}

metrics_path_original288_static_shrink_rhsns_exal_mcmc_repair <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_exal_mcmc_repair()$metrics_dir,
    sprintf("metrics_%04d.csv", as.integer(row_id))
  )
}

gate_compare_original288_static_shrink_rhsns_exal_mcmc_repair <- function(current_gate, baseline_gate) {
  accepted_compare_status_original288_syncedbase_rerun(current_gate, baseline_gate)
}

coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair <- function(df, cols, default = NA_character_) {
  out <- rep(default, nrow(df))
  for (nm in cols) {
    if (!nm %in% names(df)) next
    val <- as.character(df[[nm]])
    idx <- is.na(out) | !nzchar(trimws(out))
    out[idx] <- val[idx]
  }
  out
}

read_failed_rows_original288_static_shrink_rhsns_exal_mcmc_repair <- function() {
  x <- utils::read.csv(
    paths_original288_static_shrink_rhsns_exal_mcmc_repair()$rebuild_manifest_status,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  x$base_row_id <- suppressWarnings(as.integer(x$row_id))
  x$family <- coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
    x,
    c("family", "family_row", "family_manifest")
  )
  x$tau_label <- coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
    x,
    c("tau_label", "tau_label_row", "tau_label_manifest")
  )
  x$fit_size <- suppressWarnings(as.integer(coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
    x,
    c("fit_size", "fit_size_row", "fit_size_manifest")
  )))
  x$model <- coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
    x,
    c("model", "model_row", "model_manifest")
  )
  x$inference <- coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
    x,
    c("inference", "inference_row", "inference_manifest")
  )
  x$profile_id <- coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
    x,
    c("profile_id_row", "profile_id", "profile_id_manifest")
  )
  x$selected_variant_tag <- coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
    x,
    c("selected_variant_tag_row", "selected_variant_tag", "selected_variant_tag_manifest")
  )
  x$target_original_case_key <- coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
    x,
    c("target_original_case_key", "original_case_key")
  )
  x$accepted_gate <- coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(x, c("accepted_gate"))
  x$accepted_healthy <- as.logical(ifelse(is.na(x$accepted_healthy), FALSE, x$accepted_healthy))
  x <- x[
    x$prior_semantics == "rhs_ns" &
      x$model == "exal" &
      x$inference == "mcmc" &
      x$gate_overall == "FAIL",
    c(
      "base_row_id",
      "family",
      "tau_label",
      "fit_size",
      "status",
      "error",
      "profile_id",
      "selected_variant_tag",
      "accepted_gate",
      "accepted_healthy",
      "target_original_case_key",
      "candidate_fit_path",
      "health_csv",
      "metrics_csv"
    ),
    drop = FALSE
  ]
  x <- x[order(x$base_row_id), , drop = FALSE]
  rownames(x) <- NULL
  stopifnot(nrow(x) == 12L)
  x
}

repair_schedule_spec_original288_static_shrink_rhsns_exal_mcmc_repair <- function() {
  data.frame(
    base_row_id = c(
      42, 42, 42,
      44, 44, 44, 44,
      54, 54, 54,
      56, 56, 56,
      66, 66, 66,
      68, 68, 68, 68,
      38, 38, 38,
      40, 40, 40,
      46, 46, 46,
      48, 48, 48,
      52, 52, 52,
      64, 64, 64
    ),
    phase = c(
      rep("phase1_static_shrink_rhsns_exal_mcmc_crash_repair", 20),
      rep("phase2_static_shrink_rhsns_exal_mcmc_mixing_repair", 18)
    ),
    repair_class = c(
      rep("invalid_state", 20),
      rep("chain_quality", 18)
    ),
    candidate_rank = c(
      1, 2, 3,
      1, 2, 3, 4,
      1, 2, 3,
      1, 2, 3,
      1, 2, 3,
      1, 2, 3, 4,
      1, 2, 3,
      1, 2, 3,
      1, 2, 3,
      1, 2, 3,
      1, 2, 3,
      1, 2, 3
    ),
    profile_id = c(
      "crash_rw_none_f0825_s100",
      "crash_slice_none_f085_s1025",
      "crash_rw_none_f085_s1025_long",
      "crash_rw_none_f085_s1025",
      "crash_rw_none_f0875_s105",
      "crash_slice_none_f085_s1025",
      "crash_rw_none_f0845_s100",
      "crash_rw_none_f0825_s100",
      "crash_rw_none_f0825_s1025_long",
      "crash_slice_none_f0825_s1025",
      "crash_rw_none_f0825_s1025",
      "crash_rw_none_f085_s1025_long",
      "crash_slice_none_f0825_s1025",
      "crash_rw_none_f0825_s100",
      "crash_rw_none_f0845_s100",
      "crash_slice_none_f0825_s100",
      "crash_rw_none_f0825_s105",
      "crash_rw_none_f0835_s1025",
      "crash_rw_none_f0845_s100",
      "crash_slice_none_f0825_s1025",
      "mix_rw_refresh_f080_s105",
      "mix_rw_none_f0825_s100",
      "mix_slice_none_f0825_s100",
      "mix_rw_hist_f0825_s1025_long",
      "mix_rw_none_f0825_s1025_long",
      "mix_slice_long_f0825_s1025",
      "mix_rw_hist_f0825_s100",
      "mix_rw_hist_f085_s100",
      "mix_slice_none_f0825_s100",
      "mix_rw_hist_f085_s1025",
      "mix_rw_hist_f0825_s1025_long",
      "mix_slice_long_f0825_s1025",
      "mix_rw_hist_f0835_s1025",
      "mix_rw_hist_f0825_s1025_long",
      "mix_rw_none_f0825_s1025_long",
      "mix_rw_none_f0825_s105",
      "mix_rw_hist_f0825_s1025_long",
      "mix_slice_long_f0825_s1025"
    ),
    init_from_vb = c(
      FALSE, FALSE, FALSE,
      FALSE, FALSE, FALSE, FALSE,
      FALSE, FALSE, FALSE,
      FALSE, FALSE, FALSE,
      FALSE, FALSE, FALSE,
      FALSE, FALSE, FALSE, FALSE,
      TRUE, FALSE, FALSE,
      TRUE, FALSE, FALSE,
      TRUE, TRUE, FALSE,
      TRUE, TRUE, FALSE,
      TRUE, TRUE, FALSE,
      FALSE, TRUE, FALSE
    ),
    mh_proposal = c(
      "laplace_rw", "slice", "laplace_rw",
      "laplace_rw", "laplace_rw", "slice", "laplace_rw",
      "laplace_rw", "laplace_rw", "slice",
      "laplace_rw", "laplace_rw", "slice",
      "laplace_rw", "laplace_rw", "slice",
      "laplace_rw", "laplace_rw", "laplace_rw", "slice",
      "laplace_rw", "laplace_rw", "slice",
      "laplace_rw", "laplace_rw", "slice",
      "laplace_rw", "laplace_rw", "slice",
      "laplace_rw", "laplace_rw", "slice",
      "laplace_rw", "laplace_rw", "laplace_rw",
      "laplace_rw", "laplace_rw", "slice"
    ),
    mh_adapt = c(
      TRUE, FALSE, TRUE,
      TRUE, TRUE, FALSE, TRUE,
      TRUE, TRUE, FALSE,
      TRUE, TRUE, FALSE,
      TRUE, TRUE, FALSE,
      TRUE, TRUE, TRUE, FALSE,
      TRUE, TRUE, FALSE,
      TRUE, TRUE, FALSE,
      TRUE, TRUE, FALSE,
      TRUE, TRUE, FALSE,
      TRUE, TRUE, TRUE,
      TRUE, TRUE, FALSE
    ),
    n_burn = c(
      2000L, 2200L, 3000L,
      2200L, 2200L, 2200L, 3000L,
      2000L, 3000L, 2200L,
      2200L, 3000L, 2200L,
      2000L, 2200L, 2200L,
      2200L, 2500L, 2200L, 2200L,
      2000L, 2500L, 2200L,
      3000L, 3000L, 2500L,
      2200L, 2200L, 2200L,
      2200L, 3000L, 2500L,
      2500L, 3000L, 3000L,
      2500L, 3000L, 2500L
    ),
    n_mcmc = c(
      1000L, 1200L, 1500L,
      1200L, 1200L, 1200L, 1500L,
      1000L, 1500L, 1200L,
      1200L, 1500L, 1200L,
      1000L, 1200L, 1200L,
      1200L, 1200L, 1200L, 1200L,
      1000L, 1200L, 1200L,
      1500L, 1500L, 1500L,
      1200L, 1200L, 1200L,
      1200L, 1500L, 1500L,
      1200L, 1500L, 1500L,
      1200L, 1500L, 1500L
    ),
    thin = 1L,
    gamma_substeps = 2L,
    p_global_eta_jump = c(
      0.0825, 0.0850, 0.0850,
      0.0850, 0.0875, 0.0850, 0.0845,
      0.0825, 0.0825, 0.0825,
      0.0825, 0.0850, 0.0825,
      0.0825, 0.0845, 0.0825,
      0.0825, 0.0835, 0.0845, 0.0825,
      0.0800, 0.0825, 0.0825,
      0.0825, 0.0825, 0.0825,
      0.0825, 0.0850, 0.0825,
      0.0850, 0.0825, 0.0825,
      0.0835, 0.0825, 0.0825,
      0.0825, 0.0825, 0.0825
    ),
    global_eta_jump_scale = c(
      1.000, 1.025, 1.025,
      1.025, 1.050, 1.025, 1.000,
      1.000, 1.025, 1.025,
      1.025, 1.025, 1.025,
      1.000, 1.000, 1.000,
      1.050, 1.025, 1.000, 1.025,
      1.050, 1.000, 1.000,
      1.025, 1.025, 1.025,
      1.000, 1.000, 1.000,
      1.025, 1.025, 1.025,
      1.025, 1.025, 1.025,
      1.050, 1.025, 1.025
    ),
    slice_width = c(
      NA, 0.12, NA,
      NA, NA, 0.12, NA,
      NA, NA, 0.12,
      NA, NA, 0.12,
      NA, NA, 0.12,
      NA, NA, NA, 0.12,
      NA, NA, 0.12,
      NA, NA, 0.12,
      NA, NA, 0.12,
      NA, NA, 0.12,
      NA, NA, NA,
      NA, NA, 0.12
    ),
    slice_max_steps = c(
      NA, 120L, NA,
      NA, NA, 120L, NA,
      NA, NA, 120L,
      NA, NA, 120L,
      NA, NA, 120L,
      NA, NA, NA, 120L,
      NA, NA, 120L,
      NA, NA, 120L,
      NA, NA, 120L,
      NA, NA, 120L,
      NA, NA, NA,
      NA, NA, 120L
    ),
    laplace_refresh_interval = 50L,
    laplace_refresh_start = 333L,
    laplace_refresh_weight = 0.60,
    historical_anchor_variant_tag = c(
      "failband2_F0825_sub2_s100",
      "failband2_F085_sub2_s1025",
      "failband2_F085_sub2_s1025",
      "failband2_F085_sub2_s1025",
      "failband2_F0875_sub2_s105",
      "failband2_F085_sub2_s1025",
      "failband2_F0845_sub2_s100",
      "failband2_F0825_sub2_s100",
      "failband2_F0825_sub2_s1025",
      "failband2_F0825_sub2_s1025",
      "failband2_F0825_sub2_s1025",
      "failband2_F085_sub2_s1025",
      "failband2_F0825_sub2_s1025",
      "failband2_F0825_sub2_s100",
      "failband2_F0845_sub2_s100",
      "failband2_F0825_sub2_s100",
      "failband2_F0825_sub2_s105_none",
      "failband2_F0835_sub2_s1025",
      "failband2_F0845_sub2_s100",
      "failband2_F0825_sub2_s1025",
      "static_exal_f080_sub2_s105_rhsns_current_20260403",
      "failband2_F0825_sub2_s100",
      "failband2_F0825_sub2_s100",
      "failband2_F0825_sub2_s1025",
      "failband2_F0825_sub2_s1025",
      "failband2_F0825_sub2_s1025",
      "failband2_F0825_sub2_s100",
      "failband2_F085_sub2_s100",
      "failband2_F0825_sub2_s100",
      "failband2_F085_sub2_s1025",
      "failband2_F0825_sub2_s1025",
      "failband2_F0825_sub2_s1025",
      "failband2_F0835_sub2_s1025",
      "failband2_F0825_sub2_s1025",
      "failband2_F0825_sub2_s1025",
      "failband2_F0825_sub2_s105_none",
      "failband2_F0825_sub2_s1025",
      "failband2_F0825_sub2_s1025"
    ),
    rationale = c(
      "drop VB warm start while keeping the stable mid-band rw settings that were least explosive in nearby rhs_ns rows",
      "test whether paper-style slice can remove the iter=2 invalid-state crash on the smallest gausmix 0p25 row",
      "give the no-VB gausmix crash row a longer rw corridor before rejecting the f085/s1025 band",
      "replay the best repeated gausmix tt1000/0p25 WARN anchor without VB warm start",
      "transfer the row-specific gausmix tt1000/0p25 WARN exception into the corrected rhs_ns branch with no-VB init",
      "probe whether slice can bypass the shared chi non-finite crash in the hardest gausmix crash row",
      "check a lower-mid rw fallback on the hardest gausmix crash row before escalating further",
      "remove the VB warm start but keep the simplest laplace 0p25 rw band as the first crash-rescue probe",
      "combine no-VB init with the better historical laplace 0p25 scale corridor and more chain budget",
      "check whether slice bypasses the shared chi crash on the small laplace 0p25 row",
      "replay the historical laplace tt1000/0p25 WARN corridor without the unstable VB initialization path",
      "stretch the laplace tt1000/0p25 rw chain to see if the remaining issue is only startup fragility plus chain length",
      "probe paper-style slice on the laplace tt1000/0p25 crash row as a kernel alternative, not a global replacement",
      "use a conservative no-VB rw anchor for the small normal 0p25 crash row before wider parameter moves",
      "test the best documented normal fallback scale on the small crash row while staying in rw",
      "check whether slice can remove the shared normal 0p25 crash without relying on VB hyper-state",
      "replay the strongest historical normal tt1000/0p25 PASS-style none-init corridor in the corrected rhs_ns branch",
      "keep the successful normal tt1000/0p25 family but move to the slightly higher jump band that also passed nearby",
      "retain the safest current normal tt1000/0p25 WARN fallback as a hedge if the higher bands over-shoot",
      "add one slice probe on the hardest normal crash row so the overnight program is broad but still focused",
      "rerun the stale gausmix tt100/0p05 profile on a fresh path before treating it as a real scientific failure",
      "remove VB warm start and shift to a slightly stronger rw band for the small gausmix 0p05 failure",
      "check whether slice stabilizes the small gausmix 0p05 tail better than the old rw path",
      "use the best historical gausmix 0p05 tt1000 rw anchor with more chain length to attack deep ESS and drift failures",
      "separate chain-quality from initialization by pairing the same gausmix 0p05 tt1000 corridor with no-VB init",
      "test a slice version of the best gausmix 0p05 tt1000 corridor because paper-aligned static exAL favored slice",
      "replay the stable small-row gausmix 0p95 anchor that passed nearby legacy/current rhs_ns work",
      "test the stronger small-row gausmix 0p95 PASS anchor that historically cleared the legacy branch",
      "check whether a no-VB slice probe resolves the residual gamma half-drift on the small gausmix 0p95 row",
      "replay the strongest gausmix tt1000/0p95 PASS anchor in the corrected rhs_ns branch",
      "keep the best closure anchor but give it a longer rw chain in case the remaining failure is only half-chain instability",
      "test whether slice fixes the remaining sigma half-drift on the large gausmix 0p95 row",
      "replay the documented laplace tt1000/0p05 PASS anchor that outperformed the baseline-like rebuild profile",
      "keep the weaker but reusable laplace tt1000/0p05 anchor and extend chain length to target gamma half-drift",
      "separate initialization from chain quality on laplace tt1000/0p05 by removing the VB warm start entirely",
      "use the strongest normal none-init pattern available from nearby rhs_ns success cases on the large 0p05 row",
      "pair the best historical normal mid-band with a longer rw chain to attack the low-ESS failure directly",
      "test whether slice can improve ESS and half-drift on the large normal 0p05 row without reopening the full profile grid"
    ),
    stringsAsFactors = FALSE
  )
}

materialize_schedule_original288_static_shrink_rhsns_exal_mcmc_repair <- function() {
  base_fail <- read_failed_rows_original288_static_shrink_rhsns_exal_mcmc_repair()
  names(base_fail)[names(base_fail) == "profile_id"] <- "base_profile_id"
  spec <- repair_schedule_spec_original288_static_shrink_rhsns_exal_mcmc_repair()
  spec$phase_order <- unname(phase_order_original288_static_shrink_rhsns_exal_mcmc_repair[spec$phase])

  stopifnot(!anyDuplicated(spec[, c("base_row_id", "profile_id")]))
  stopifnot(setequal(unique(spec$base_row_id), base_fail$base_row_id))

  merged <- merge(spec, base_fail, by = "base_row_id", all.x = TRUE, sort = FALSE)
  stopifnot(!any(is.na(merged$family)))

  hist_seed <- integer(nrow(merged))
  hist_seed[] <- NA_integer_
  hist_source <- character(nrow(merged))
  hist_source[] <- NA_character_
  for (i in seq_len(nrow(merged))) {
    hist <- lookup_historical_profile_original288_static_shrink_rhsns_rebuild(
      variant_tag = merged$historical_anchor_variant_tag[i],
      family = merged$family[i],
      tau_label = merged$tau_label[i],
      fit_size = merged$fit_size[i]
    )
    if (!is.null(hist)) {
      hist_seed[i] <- safe_int_original288_syncedbase_rerun(hist$seed, NA_integer_)
      hist_source[i] <- safe_chr_original288_syncedbase_rerun(hist$source_name, NA_character_)
    }
  }

  merged$fit_seed <- ifelse(
    is.finite(hist_seed),
    hist_seed,
    2026041000L + as.integer(merged$base_row_id) * 10L + as.integer(merged$candidate_rank)
  )
  merged$historical_source <- hist_source
  merged <- merged[order(
    merged$phase_order,
    merged$base_row_id,
    merged$candidate_rank,
    merged$profile_id
  ), , drop = FALSE]
  rownames(merged) <- NULL
  merged$row_id <- seq_len(nrow(merged))
  merged
}

build_row_config_original288_static_shrink_rhsns_exal_mcmc_repair <- function(row, repo_root) {
  data_dir <- source_input_dir_original288_static_shrink_rhsns_rebuild(row$family, row$tau_label, row$fit_size)
  run_root <- target_run_root_original288_static_shrink_rhsns_exal_mcmc_repair(repo_root, row$family, row$tau_label, row$fit_size)
  fit_path <- candidate_fit_path_original288_static_shrink_rhsns_exal_mcmc_repair(
    run_root = run_root,
    inference = "mcmc",
    model = "exal",
    tau_label = row$tau_label,
    profile_id = row$profile_id
  )

  list(
    row_id = as.integer(row$row_id),
    base_row_id = as.integer(row$base_row_id),
    tag = run_tag_original288_static_shrink_rhsns_exal_mcmc_repair(),
    phase = row$phase,
    phase_order = row$phase_order,
    lane_label = "static_shrink_rhsns_exal_mcmc_repair",
    repair_class = row$repair_class,
    block = "static_shrink",
    root_kind = "static_shrink",
    family = row$family,
    tau = tau_num_from_label_original288_syncedbase_rerun(row$tau_label),
    tau_label = row$tau_label,
    fit_size = as.integer(row$fit_size),
    model = "exal",
    inference = "mcmc",
    profile_id = row$profile_id,
    source_variant_tag = row$historical_anchor_variant_tag,
    historical_source = row$historical_source,
    target_prior_semantics = "rhs_ns",
    beta_prior = "rhs_ns",
    dqlm_ind = FALSE,
    fit_seed = as.integer(row$fit_seed),
    run_root = run_root,
    data_dir = data_dir,
    series_wide_path = normalize_path_original288(file.path(data_dir, "series_wide.csv")),
    coef_truth_path = normalize_path_original288(file.path(data_dir, "coef_truth.csv")),
    true_quantile_grid_path = normalize_path_original288(file.path(data_dir, "true_quantile_grid.csv")),
    selection_indices_path = normalize_path_original288(file.path(data_dir, "selection_indices.csv")),
    fit_path = fit_path,
    config_path = config_path_original288_static_shrink_rhsns_exal_mcmc_repair(row$row_id),
    row_status_path = row_status_path_original288_static_shrink_rhsns_exal_mcmc_repair(row$row_id),
    health_path = health_path_original288_static_shrink_rhsns_exal_mcmc_repair(row$row_id),
    metrics_path = metrics_path_original288_static_shrink_rhsns_exal_mcmc_repair(row$row_id),
    accepted_gate = row$accepted_gate,
    accepted_healthy = isTRUE(row$accepted_healthy),
    rebuild_gate = "FAIL",
    rebuild_status = row$status,
    base_profile_id = row$base_profile_id,
    base_selected_variant_tag = row$selected_variant_tag,
    base_error = row$error,
    target_original_case_key = row$target_original_case_key,
    base_candidate_fit_path = row$candidate_fit_path,
    base_health_csv = row$health_csv,
    base_metrics_csv = row$metrics_csv,
    n_burn = as.integer(row$n_burn),
    n_mcmc = as.integer(row$n_mcmc),
    thin = as.integer(row$thin),
    init_from_vb = isTRUE(row$init_from_vb),
    vb_init_controls = list(max_iter = 1000L, tol = 1e-4, n_samp_xi = 200L, verbose = FALSE),
    mh_proposal = row$mh_proposal,
    mh_adapt = isTRUE(row$mh_adapt),
    slice_width = as.numeric(row$slice_width),
    slice_max_steps = as.integer(row$slice_max_steps),
    gamma_substeps = as.integer(row$gamma_substeps),
    p_global_eta_jump = as.numeric(row$p_global_eta_jump),
    global_eta_jump_scale = as.numeric(row$global_eta_jump_scale),
    laplace_refresh_interval = as.integer(row$laplace_refresh_interval),
    laplace_refresh_start = as.integer(row$laplace_refresh_start),
    laplace_refresh_weight = as.numeric(row$laplace_refresh_weight),
    trace_every = 50L,
    progress_every = 50L,
    requested_init_mode = if (isTRUE(row$init_from_vb)) "vb" else "none",
    resolved_init_mode = if (isTRUE(row$init_from_vb)) "vb" else "none",
    rationale = row$rationale
  )
}

read_original288_static_shrink_rhsns_exal_mcmc_repair_status <- function(
    manifest_path = paths_original288_static_shrink_rhsns_exal_mcmc_repair()$manifest,
    run_tag = run_tag_original288_static_shrink_rhsns_exal_mcmc_repair()) {
  read_original288_syncedbase_rerun_status(manifest_path = manifest_path, run_tag = run_tag)
}

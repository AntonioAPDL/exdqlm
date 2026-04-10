source("tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_helpers_20260410.R")

run_tag_original288_static_shrink_rhsns_exal_mcmc_final_closure <- function() {
  "original288_static_shrink_rhsns_exal_mcmc_final_closure_20260410"
}

variant_tag_original288_static_shrink_rhsns_exal_mcmc_final_closure <- function() {
  "orig288_static_shrink_rhsns_exal_mcmc_final_closure_20260410"
}

phase_order_original288_static_shrink_rhsns_exal_mcmc_final_closure <- c(
  phase1_static_shrink_rhsns_exal_mcmc_final_closure = 1L
)

paths_original288_static_shrink_rhsns_exal_mcmc_final_closure <- function() {
  tag <- run_tag_original288_static_shrink_rhsns_exal_mcmc_final_closure()
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", tag))
  list(
    accepted_selection = "tools/merge_reports/LOCAL_original288_carryforward_selection_v8_20260410.csv",
    working_baseline = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_working_baseline_20260410.csv",
    schedule = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_schedule_20260410.csv",
    manifest = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_manifest_20260410.csv",
    stage_counts = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_stage_counts_20260410.csv",
    manifest_status = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_manifest_status_20260410.csv",
    phase_summary = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_phase_summary_20260410.csv",
    target_summary = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_target_summary_20260410.csv",
    compare_accepted = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_compare_accepted_20260410.csv",
    compare_working = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_compare_working_20260410.csv",
    config_dir = file.path(run_dir, "configs"),
    rows_dir = file.path(run_dir, "rows"),
    health_dir = file.path(run_dir, "health"),
    metrics_dir = file.path(run_dir, "metrics"),
    logs_dir = file.path(run_dir, "logs"),
    tracker_doc = "reports/static_exal_tuning_20260406/integration_branch_validation_status_20260406.md",
    static_tracker_doc = "tools/merge_reports/LOCAL_VALIDATION_RECOVERY_TRACKER_STATIC_EXAL_20260331.md",
    program_doc = "reports/static_exal_tuning_20260410/original_288_static_shrink_rhsns_exal_mcmc_final_closure_program_20260410.md",
    execution_doc = "reports/static_exal_tuning_20260410/original_288_static_shrink_rhsns_exal_mcmc_final_closure_execution_20260410.md"
  )
}

target_run_root_original288_static_shrink_rhsns_exal_mcmc_final_closure <- function(repo_root, family, tau_label, fit_size) {
  normalize_path_original288(file.path(
    repo_root,
    "results",
    "function_testing_20260309_static_shrinkage_family_qspec",
    family,
    sprintf("tau_%s", tau_label),
    sprintf("fit_input_subsample_tt%d_x01_sorted", as.integer(fit_size)),
    sprintf("validation_shrink_rhsns_final_tt%d", as.integer(fit_size))
  ))
}

candidate_fit_path_original288_static_shrink_rhsns_exal_mcmc_final_closure <- function(
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
      variant_tag_original288_static_shrink_rhsns_exal_mcmc_final_closure(),
      sanitize_profile_slug_original288_static_shrink_rhsns_exal_mcmc_repair(profile_id)
    )
  ))
}

config_path_original288_static_shrink_rhsns_exal_mcmc_final_closure <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_exal_mcmc_final_closure()$config_dir,
    sprintf("row_%04d_run_config.rds", as.integer(row_id))
  )
}

row_status_path_original288_static_shrink_rhsns_exal_mcmc_final_closure <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_exal_mcmc_final_closure()$rows_dir,
    sprintf("row_%04d.csv", as.integer(row_id))
  )
}

health_path_original288_static_shrink_rhsns_exal_mcmc_final_closure <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_exal_mcmc_final_closure()$health_dir,
    sprintf("health_%04d.csv", as.integer(row_id))
  )
}

metrics_path_original288_static_shrink_rhsns_exal_mcmc_final_closure <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_exal_mcmc_final_closure()$metrics_dir,
    sprintf("metrics_%04d.csv", as.integer(row_id))
  )
}

read_failed_rows_original288_static_shrink_rhsns_exal_mcmc_final_closure <- function() {
  x <- utils::read.csv(
    paths_original288_static_shrink_rhsns_exal_mcmc_final_closure()$working_baseline,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  x$base_row_id <- suppressWarnings(as.integer(x$row_id))
  x$family <- coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
    x, c("family", "family_row", "family_manifest")
  )
  x$tau_label <- coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
    x, c("tau_label", "tau_label_row", "tau_label_manifest")
  )
  x$fit_size <- suppressWarnings(as.integer(coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
    x, c("fit_size", "fit_size_row", "fit_size_manifest")
  )))
  x$model <- coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
    x, c("model", "model_row", "model_manifest")
  )
  x$inference <- coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
    x, c("inference", "inference_row", "inference_manifest")
  )
  x$profile_id <- coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
    x, c("profile_id_row", "profile_id", "profile_id_manifest")
  )
  x$selected_variant_tag <- coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
    x, c("selected_variant_tag_row", "selected_variant_tag", "selected_variant_tag_manifest")
  )
  x$target_original_case_key <- mapply(
    make_original_case_key_original288,
    root_kind = "static_shrink",
    family = x$family,
    tau_label = x$tau_label,
    fit_size = x$fit_size,
    prior_semantics = "rhs_ns",
    model = "exal",
    inference = "mcmc",
    USE.NAMES = FALSE
  )
  x <- subset(
    x,
    prior_semantics == "rhs_ns" &
      model == "exal" &
      inference == "mcmc" &
      gate_overall == "FAIL"
  )
  x <- x[, c(
    "base_row_id", "family", "tau_label", "fit_size", "status", "error",
    "profile_id", "selected_variant_tag", "accepted_gate", "accepted_healthy",
    "target_original_case_key", "candidate_fit_path", "health_csv", "metrics_csv"
  ), drop = FALSE]
  x <- x[order(x$base_row_id), , drop = FALSE]
  rownames(x) <- NULL
  stopifnot(identical(x$base_row_id, c(44L, 68L)))
  x
}

schedule_spec_original288_static_shrink_rhsns_exal_mcmc_final_closure <- function() {
  data.frame(
    base_row_id = c(rep(44, 9L), rep(68, 9L)),
    phase = "phase1_static_shrink_rhsns_exal_mcmc_final_closure",
    repair_class = "final_closure",
    candidate_rank = c(seq_len(9L), seq_len(9L)),
    profile_id = c(
      "final_rw_none_f085_s100_long",
      "final_rw_none_f085_s100_xlong",
      "final_rw_none_f0825_s1025_long",
      "final_rw_none_f0845_s100_histshort",
      "final_slice_none_w16_s240",
      "final_slice_none_w18_s320",
      "final_slice_none_w20_s360",
      "final_rw_none_f0875_s105_xlong",
      "final_rw_none_f085_s100_noadapt",
      "final_rw_none_f0845_s100_histshort",
      "final_rw_none_f0845_s100_histshort_xlong",
      "final_rw_none_f0825_s105_none_xlong",
      "final_rw_none_f0835_s1025_xlong",
      "final_rw_none_f0845_s100_noadapt",
      "final_slice_none_w16_s240",
      "final_slice_none_w18_s320",
      "final_slice_none_w20_s360",
      "final_rw_none_f080_s105_long"
    ),
    init_from_vb = FALSE,
    mh_proposal = c(
      rep("laplace_rw", 4L), rep("slice", 3L), rep("laplace_rw", 2L),
      rep("laplace_rw", 5L), rep("slice", 3L), "laplace_rw"
    ),
    mh_adapt = c(
      TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE,
      TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE
    ),
    n_burn = c(
      3000L, 4000L, 3500L, 3200L, 2600L, 3000L, 3500L, 4000L, 3000L,
      3000L, 4000L, 4000L, 4000L, 3200L, 2600L, 3200L, 3800L, 3500L
    ),
    n_mcmc = c(
      1800L, 2200L, 2000L, 1800L, 1400L, 1600L, 1800L, 2200L, 1800L,
      1500L, 2200L, 2200L, 2200L, 1800L, 1400L, 1800L, 2200L, 2000L
    ),
    thin = 1L,
    gamma_substeps = 2L,
    p_global_eta_jump = c(
      0.0850, 0.0850, 0.0825, 0.0845, 0.0850, 0.0850, 0.0850, 0.0875, 0.0850,
      0.0845, 0.0845, 0.0825, 0.0835, 0.0845, 0.0825, 0.0825, 0.0825, 0.0800
    ),
    global_eta_jump_scale = c(
      1.000, 1.000, 1.025, 1.000, 1.025, 1.025, 1.025, 1.050, 1.000,
      1.000, 1.000, 1.050, 1.025, 1.000, 1.025, 1.025, 1.025, 1.050
    ),
    slice_width = c(
      NA, NA, NA, NA, 0.16, 0.18, 0.20, NA, NA,
      NA, NA, NA, NA, NA, 0.16, 0.18, 0.20, NA
    ),
    slice_max_steps = c(
      NA, NA, NA, NA, 240L, 320L, 360L, NA, NA,
      NA, NA, NA, NA, NA, 240L, 320L, 360L, NA
    ),
    laplace_refresh_interval = 50L,
    laplace_refresh_start = 333L,
    laplace_refresh_weight = 0.60,
    historical_anchor_variant_tag = c(
      "failband2_F085_sub2_s100",
      "failband2_F085_sub2_s100",
      "failband2_F0825_sub2_s1025",
      "failband2_F0845_sub2_s100",
      "failband2_F085_sub2_s1025",
      "failband2_F085_sub2_s1025",
      "failband2_F085_sub2_s1025",
      "failband2_F0875_sub2_s105",
      "failband2_F085_sub2_s100",
      "repairmap9_R269_F0845_sub2_s100_histshort_seed2026076269",
      "repairmap9_R269_F0845_sub2_s100_histshort_seed2026076269",
      "failband2_F0825_sub2_s105_none",
      "failband2_F0835_sub2_s1025",
      "repairmap9_R269_F0845_sub2_s100_histshort_seed2026076269",
      "failband2_F0825_sub2_s1025",
      "failband2_F0825_sub2_s1025",
      "failband2_F0825_sub2_s1025",
      "static_exal_f080_sub2_s105_rhsns_current_20260403"
    ),
    rationale = c(
      "Re-open the gausmix tt1000/0p25 row around the exact legacy F085/s100 WARN corridor, but force no-VB init and give it a materially longer chain.",
      "Keep the same corrected gausmix tt1000/0p25 corridor and extend it further before discarding the cleanest legacy anchor.",
      "Probe the slightly softer F0825/s1025 band on the hard gausmix row with no-VB init and more length than the crash-repair wave used.",
      "Use the lower-mid F0845/s100 hedge on the hard gausmix row in case the stronger F085/F0875 bands are over-shooting the corrected rhs_ns geometry.",
      "Retry gausmix tt1000/0p25 with a much wider slice corridor than the crash wave; the earlier 0.12/120 slice was too conservative to be conclusive.",
      "Use a deeper 0.18/320 slice corridor on the hardest gausmix row to test whether the corrected rhs_ns branch simply needs a broader exact kernel.",
      "Stretch the slice corridor further on gausmix tt1000/0p25 so the overnight lane explores one genuinely aggressive exact-kernel option.",
      "Revisit the strongest historical F0875/s105 gausmix band with substantially more chain length and no-VB init.",
      "Repeat the cleanest gausmix F085/s100 corridor with adaptation off in case the corrected rhs_ns failure is an adaptation artifact rather than a geometry failure.",
      "Replay the exact legacy normal tt1000/0p25 histshort WARN anchor inside the corrected rhs_ns branch before declaring the row fundamentally broken.",
      "Give the histshort normal tt1000/0p25 anchor a substantially longer chain to test whether the corrected rhs_ns issue is now mostly ESS debt.",
      "Use the documented none-init normal tt1000/0p25 PASS-style corridor, but with more budget than the earlier crash wave.",
      "Keep the best higher-band normal tt1000/0p25 corridor and stretch it so the row gets one serious rw-only closure attempt.",
      "Turn adaptation off on the exact normal histshort anchor in case the corrected rhs_ns crash is being reintroduced by the adaptive phase.",
      "Retry the hard normal tt1000/0p25 row with a wider slice corridor than the earlier 0.12/120 probe.",
      "Use a deeper slice corridor on the hardest normal corrected row so the final closure wave explores a real exact-kernel alternative, not just a token probe.",
      "Push the slice corridor further on normal tt1000/0p25 to make the overnight exploration genuinely broad but still targeted.",
      "Carry the best current rhs_ns refresh-style normal band into the final closure lane as a lower-band hedge against the more aggressive historical anchors."
    ),
    stringsAsFactors = FALSE
  )
}

materialize_schedule_original288_static_shrink_rhsns_exal_mcmc_final_closure <- function() {
  base_fail <- read_failed_rows_original288_static_shrink_rhsns_exal_mcmc_final_closure()
  names(base_fail)[names(base_fail) == "profile_id"] <- "base_profile_id"
  spec <- schedule_spec_original288_static_shrink_rhsns_exal_mcmc_final_closure()
  spec$phase_order <- unname(phase_order_original288_static_shrink_rhsns_exal_mcmc_final_closure[spec$phase])

  stopifnot(!anyDuplicated(spec[, c("base_row_id", "profile_id")]))
  stopifnot(setequal(unique(spec$base_row_id), base_fail$base_row_id))

  merged <- merge(spec, base_fail, by = "base_row_id", all.x = TRUE, sort = FALSE)
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
    2026041010L + as.integer(merged$base_row_id) * 10L + as.integer(merged$candidate_rank)
  )
  merged$historical_source <- hist_source
  merged <- merged[order(merged$phase_order, merged$base_row_id, merged$candidate_rank, merged$profile_id), , drop = FALSE]
  rownames(merged) <- NULL
  merged$row_id <- seq_len(nrow(merged))
  merged
}

build_row_config_original288_static_shrink_rhsns_exal_mcmc_final_closure <- function(row, repo_root) {
  data_dir <- source_input_dir_original288_static_shrink_rhsns_rebuild(row$family, row$tau_label, row$fit_size)
  run_root <- target_run_root_original288_static_shrink_rhsns_exal_mcmc_final_closure(repo_root, row$family, row$tau_label, row$fit_size)
  fit_path <- candidate_fit_path_original288_static_shrink_rhsns_exal_mcmc_final_closure(
    run_root = run_root,
    inference = "mcmc",
    model = "exal",
    tau_label = row$tau_label,
    profile_id = row$profile_id
  )

  list(
    row_id = as.integer(row$row_id),
    base_row_id = as.integer(row$base_row_id),
    tag = run_tag_original288_static_shrink_rhsns_exal_mcmc_final_closure(),
    phase = row$phase,
    phase_order = row$phase_order,
    lane_label = "static_shrink_rhsns_exal_mcmc_final_closure",
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
    config_path = config_path_original288_static_shrink_rhsns_exal_mcmc_final_closure(row$row_id),
    row_status_path = row_status_path_original288_static_shrink_rhsns_exal_mcmc_final_closure(row$row_id),
    health_path = health_path_original288_static_shrink_rhsns_exal_mcmc_final_closure(row$row_id),
    metrics_path = metrics_path_original288_static_shrink_rhsns_exal_mcmc_final_closure(row$row_id),
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
    requested_init_mode = "none",
    resolved_init_mode = "none",
    rationale = row$rationale
  )
}

read_original288_static_shrink_rhsns_exal_mcmc_final_closure_status <- function(
    manifest_path = paths_original288_static_shrink_rhsns_exal_mcmc_final_closure()$manifest,
    run_tag = run_tag_original288_static_shrink_rhsns_exal_mcmc_final_closure()) {
  read_original288_syncedbase_rerun_status(manifest_path = manifest_path, run_tag = run_tag)
}

source("tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_helpers_20260410.R")

run_tag_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile <- function() {
  "original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_20260410"
}

variant_tag_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile <- function() {
  "orig288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_20260410"
}

phase_order_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile <- c(
  phase1_static_shrink_rhsns_exal_mcmc_gausmix_rw_length = 1L,
  phase2_static_shrink_rhsns_exal_mcmc_gausmix_rw_refresh = 2L,
  phase3_static_shrink_rhsns_exal_mcmc_gausmix_rw_scale = 3L,
  phase4_static_shrink_rhsns_exal_mcmc_gausmix_slice = 4L
)

paths_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile <- function() {
  tag <- run_tag_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile()
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", tag))
  list(
    accepted_selection = "tools/merge_reports/LOCAL_original288_carryforward_selection_v8_20260410.csv",
    working_baseline = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_working_baseline_v2_20260410.csv",
    schedule = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_schedule_20260410.csv",
    manifest = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_manifest_20260410.csv",
    stage_counts = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_stage_counts_20260410.csv",
    manifest_status = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_manifest_status_20260410.csv",
    phase_summary = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_phase_summary_20260410.csv",
    target_summary = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_target_summary_20260410.csv",
    compare_accepted = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_compare_accepted_20260410.csv",
    compare_working = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_compare_working_20260410.csv",
    config_dir = file.path(run_dir, "configs"),
    rows_dir = file.path(run_dir, "rows"),
    health_dir = file.path(run_dir, "health"),
    metrics_dir = file.path(run_dir, "metrics"),
    logs_dir = file.path(run_dir, "logs"),
    tracker_doc = "reports/static_exal_tuning_20260406/integration_branch_validation_status_20260406.md",
    static_tracker_doc = "tools/merge_reports/LOCAL_VALIDATION_RECOVERY_TRACKER_STATIC_EXAL_20260331.md",
    program_doc = "reports/static_exal_tuning_20260410/original_288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_program_20260410.md",
    execution_doc = "reports/static_exal_tuning_20260410/original_288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_execution_20260410.md"
  )
}

target_run_root_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile <- function(repo_root, family, tau_label, fit_size) {
  normalize_path_original288(file.path(
    repo_root,
    "results",
    "function_testing_20260309_static_shrinkage_family_qspec",
    family,
    sprintf("tau_%s", tau_label),
    sprintf("fit_input_subsample_tt%d_x01_sorted", as.integer(fit_size)),
    sprintf("validation_shrink_rhsns_gausmix_lastmile_tt%d", as.integer(fit_size))
  ))
}

candidate_fit_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile <- function(
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
      variant_tag_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile(),
      sanitize_profile_slug_original288_static_shrink_rhsns_exal_mcmc_repair(profile_id)
    )
  ))
}

config_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile()$config_dir,
    sprintf("row_%04d_run_config.rds", as.integer(row_id))
  )
}

row_status_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile()$rows_dir,
    sprintf("row_%04d.csv", as.integer(row_id))
  )
}

health_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile()$health_dir,
    sprintf("health_%04d.csv", as.integer(row_id))
  )
}

metrics_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile()$metrics_dir,
    sprintf("metrics_%04d.csv", as.integer(row_id))
  )
}

read_failed_rows_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile <- function() {
  x <- utils::read.csv(
    paths_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile()$working_baseline,
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
  stopifnot(identical(x$base_row_id, 44L))
  x
}

schedule_spec_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile <- function() {
  data.frame(
    base_row_id = rep(44L, 28L),
    phase = c(
      rep("phase1_static_shrink_rhsns_exal_mcmc_gausmix_rw_length", 8L),
      rep("phase2_static_shrink_rhsns_exal_mcmc_gausmix_rw_refresh", 8L),
      rep("phase3_static_shrink_rhsns_exal_mcmc_gausmix_rw_scale", 6L),
      rep("phase4_static_shrink_rhsns_exal_mcmc_gausmix_slice", 6L)
    ),
    repair_class = c(
      rep("rw_length", 8L),
      rep("rw_refresh", 8L),
      rep("rw_scale", 6L),
      rep("slice_lastmile", 6L)
    ),
    candidate_rank = c(seq_len(8L), seq_len(8L), seq_len(6L), seq_len(6L)),
    profile_id = c(
      "lastmile_rw_f085_s100_xxlong",
      "lastmile_rw_f085_s100_xxlong_sub3",
      "lastmile_rw_f085_s100_xxlong_sub4",
      "lastmile_rw_f0845_s100_xxlong",
      "lastmile_rw_f0845_s100_xxlong_sub3",
      "lastmile_rw_f0845_s100_xxlong_sub4",
      "lastmile_rw_f085_s100_noadapt_xxlong_sub3",
      "lastmile_rw_f0825_s1025_xxlong_sub3",
      "lastmile_rw_f085_s100_refresh25_s150_w075_sub3",
      "lastmile_rw_f085_s100_refresh10_s050_w085_sub3",
      "lastmile_rw_f085_s100_refresh10_s050_w090_sub4",
      "lastmile_rw_f0845_s100_refresh25_s150_w075_sub3",
      "lastmile_rw_f0845_s100_refresh10_s050_w085_sub4",
      "lastmile_rw_f0825_s1025_refresh25_s150_w075_sub3",
      "lastmile_rw_f0825_s1025_refresh10_s050_w085_sub4",
      "lastmile_rw_f0835_s1025_refresh25_s150_w075_sub3",
      "lastmile_rw_f085_s095_xxlong_sub3",
      "lastmile_rw_f085_s105_xxlong_sub3",
      "lastmile_rw_f0845_s095_xxlong_sub3",
      "lastmile_rw_f0845_s105_xxlong_sub3",
      "lastmile_rw_f080_s105_xxlong_sub4",
      "lastmile_rw_f0835_s1025_xxlong_sub4",
      "lastmile_slice_w16_s240_xxlong",
      "lastmile_slice_w16_s480_xxlong_sub3",
      "lastmile_slice_w18_s320_xxlong_sub3",
      "lastmile_slice_w20_s360_xxlong_sub3",
      "lastmile_slice_w22_s480_xxlong_sub4",
      "lastmile_slice_w24_s600_xxlong_sub4"
    ),
    init_from_vb = FALSE,
    mh_proposal = c(
      rep("laplace_rw", 22L),
      rep("slice", 6L)
    ),
    mh_adapt = c(
      TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE,
      TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE,
      TRUE, TRUE, TRUE, TRUE, TRUE, TRUE,
      FALSE, FALSE, FALSE, FALSE, FALSE, FALSE
    ),
    n_burn = c(
      5000L, 6500L, 8000L, 5000L, 6500L, 8000L, 6500L, 6500L,
      6500L, 7000L, 8500L, 6500L, 8500L, 6500L, 8500L, 6500L,
      6500L, 6500L, 6500L, 6500L, 8000L, 8000L,
      5000L, 7000L, 7000L, 7000L, 8500L, 9000L
    ),
    n_mcmc = c(
      4000L, 5000L, 6000L, 4000L, 5000L, 6000L, 5000L, 5000L,
      5000L, 5500L, 6500L, 5000L, 6500L, 5000L, 6500L, 5000L,
      5000L, 5000L, 5000L, 5000L, 6000L, 6000L,
      4000L, 5500L, 5500L, 5500L, 6500L, 7000L
    ),
    thin = 1L,
    gamma_substeps = c(
      2L, 3L, 4L, 2L, 3L, 4L, 3L, 3L,
      3L, 3L, 4L, 3L, 4L, 3L, 4L, 3L,
      3L, 3L, 3L, 3L, 4L, 4L,
      2L, 3L, 3L, 3L, 4L, 4L
    ),
    p_global_eta_jump = c(
      0.0850, 0.0850, 0.0850, 0.0845, 0.0845, 0.0845, 0.0850, 0.0825,
      0.0850, 0.0850, 0.0850, 0.0845, 0.0845, 0.0825, 0.0825, 0.0835,
      0.0850, 0.0850, 0.0845, 0.0845, 0.0800, 0.0835,
      0.0850, 0.0850, 0.0850, 0.0850, 0.0850, 0.0850
    ),
    global_eta_jump_scale = c(
      1.000, 1.000, 1.000, 1.000, 1.000, 1.000, 1.000, 1.025,
      1.000, 1.000, 1.000, 1.000, 1.000, 1.025, 1.025, 1.025,
      0.950, 1.050, 0.950, 1.050, 1.050, 1.025,
      1.025, 1.025, 1.025, 1.025, 1.025, 1.025
    ),
    slice_width = c(
      rep(NA_real_, 22L),
      0.16, 0.16, 0.18, 0.20, 0.22, 0.24
    ),
    slice_max_steps = c(
      rep(NA_integer_, 22L),
      240L, 480L, 320L, 360L, 480L, 600L
    ),
    laplace_refresh_interval = c(
      rep(50L, 8L),
      25L, 10L, 10L, 25L, 10L, 25L, 10L, 25L,
      rep(50L, 6L),
      rep(25L, 6L)
    ),
    laplace_refresh_start = c(
      rep(333L, 8L),
      150L, 50L, 50L, 150L, 50L, 150L, 50L, 150L,
      rep(333L, 6L),
      rep(150L, 6L)
    ),
    laplace_refresh_weight = c(
      rep(0.60, 8L),
      0.75, 0.85, 0.90, 0.75, 0.85, 0.75, 0.85, 0.75,
      rep(0.60, 6L),
      rep(0.75, 6L)
    ),
    historical_anchor_variant_tag = c(
      "failband2_F085_sub2_s100",
      "failband2_F085_sub2_s100",
      "failband2_F085_sub2_s100",
      "failband2_F0845_sub2_s100",
      "failband2_F0845_sub2_s100",
      "failband2_F0845_sub2_s100",
      "failband2_F085_sub2_s100",
      "failband2_F0825_sub2_s1025",
      "failband2_F085_sub2_s100",
      "failband2_F085_sub2_s100",
      "failband2_F085_sub2_s100",
      "failband2_F0845_sub2_s100",
      "failband2_F0845_sub2_s100",
      "failband2_F0825_sub2_s1025",
      "failband2_F0825_sub2_s1025",
      "failband2_F0835_sub2_s1025",
      "failband2_F085_sub2_s100",
      "failband2_F085_sub2_s100",
      "failband2_F0845_sub2_s100",
      "failband2_F0845_sub2_s100",
      "failband2_F080_sub2_s105",
      "failband2_F0835_sub2_s1025",
      "failband2_F085_sub2_s1025",
      "failband2_F085_sub2_s1025",
      "failband2_F085_sub2_s1025",
      "failband2_F085_sub2_s1025",
      "failband2_F085_sub2_s1025",
      "failband2_F085_sub2_s1025"
    ),
    rationale = c(
      "Carry the best long F085/s100 rw corridor much further to test whether row 44 is now blocked mainly by absolute gamma ESS rather than instability.",
      "Keep the same best F085/s100 rw corridor but add a third gamma substep so the overnight wave explicitly targets gamma ESS-per-draw.",
      "Push the strongest F085/s100 anchor to a fourth gamma substep and a materially longer chain as the most direct ESS-closure attempt.",
      "Re-open the lower-mid F0845/s100 corridor at much longer budget because it had the cleanest drift among the early gausmix repair attempts.",
      "Add a third gamma substep to the stable F0845/s100 corridor to see if it can out-mix the higher F085 band without reintroducing drift.",
      "Use the same lower-mid F0845/s100 corridor with four gamma substeps and a long chain to stress-test whether gamma ESS is now the only missing ingredient.",
      "Turn adaptation off on the strongest F085/s100 corridor while still extending the chain, in case the best ESS anchor can close once adaptation stops perturbing it.",
      "Keep one softer F0825/s1025 hedge alive at a long budget so the overnight program is broad without reopening clearly weak high-band corridors.",
      "Start laplace refresh earlier and more often on the strongest F085/s100 corridor to attack gamma ESS directly instead of only extending chain length.",
      "Use a very early, heavier refresh cadence on the F085/s100 corridor as a targeted hedge against persistent gamma stickiness.",
      "Push the early heavy-refresh F085 corridor to four gamma substeps so the search includes one truly aggressive rw mixing rescue.",
      "Apply the same earlier refresh plan to the F0845/s100 corridor to test whether that lower-mid geometry responds better than the F085 anchor.",
      "Combine the F0845/s100 corridor with very early heavy refresh and four gamma substeps as the strongest low-mid rw mixing attempt.",
      "Keep one refresh-heavy F0825/s1025 hedge because the softer band may still be preferable once gamma mixing is explicitly supported.",
      "Push the softer F0825/s1025 corridor to the same early heavy-refresh plus four-substep regime so it gets one serious all-night test.",
      "Carry one F0835/s1025 midpoint hedge with earlier refresh so the rw map stays broad but avoids reopening clearly weak extremes.",
      "Test whether lowering the jump scale on the best F085 corridor improves effective mixing without sacrificing the more stable drift behavior.",
      "Test the opposite F085 scale hedge in case row 44 still needs slightly larger global eta moves once the chain is much longer.",
      "Mirror the lower-scale hedge on the F0845 corridor so the search covers both best-performing rw anchors.",
      "Mirror the higher-scale hedge on the F0845 corridor to keep the overnight map broad but still anchored to informative rows.",
      "Carry a single lower-band F080/s105 hedge at very long budget to avoid overcommitting only to the F0845/F085 neighborhood.",
      "Give the promising F0835/s1025 mid-band one long four-substep run as a final rw-only hedge before abandoning that neighborhood.",
      "Re-open the best slice width seen so far but give it a much longer chain so absolute ESS can scale if the exact kernel is already close.",
      "Keep the same narrower slice width but double the slice path length and add a third gamma substep to test whether the earlier exact-kernel probe was simply too short.",
      "Carry the deeper 0.18/320 slice corridor forward with more budget and a third gamma substep so the exact-kernel family is explored seriously, not tokenly.",
      "Push the 0.20/360 exact-kernel corridor much further as the aggressive mid-width slice hedge.",
      "Try a genuinely broader 0.22/480 slice corridor with four gamma substeps to see if row 44 needs a much wider exact-kernel exploration band.",
      "Make one maximal exact-kernel attempt at 0.24/600 with four gamma substeps so the overnight lane has a true broad slice endpoint."
    ),
    stringsAsFactors = FALSE
  )
}

materialize_schedule_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile <- function() {
  base_fail <- read_failed_rows_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile()
  names(base_fail)[names(base_fail) == "profile_id"] <- "base_profile_id"
  spec <- schedule_spec_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile()
  spec$phase_order <- unname(phase_order_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile[spec$phase])

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
    2026041020L + as.integer(merged$base_row_id) * 100L + as.integer(merged$candidate_rank)
  )
  merged$historical_source <- hist_source
  merged <- merged[order(merged$phase_order, merged$base_row_id, merged$candidate_rank, merged$profile_id), , drop = FALSE]
  rownames(merged) <- NULL
  merged$row_id <- seq_len(nrow(merged))
  merged
}

build_row_config_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile <- function(row, repo_root) {
  data_dir <- source_input_dir_original288_static_shrink_rhsns_rebuild(row$family, row$tau_label, row$fit_size)
  run_root <- target_run_root_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile(repo_root, row$family, row$tau_label, row$fit_size)
  fit_path <- candidate_fit_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile(
    run_root = run_root,
    inference = "mcmc",
    model = "exal",
    tau_label = row$tau_label,
    profile_id = row$profile_id
  )

  list(
    row_id = as.integer(row$row_id),
    base_row_id = as.integer(row$base_row_id),
    tag = run_tag_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile(),
    phase = row$phase,
    phase_order = row$phase_order,
    lane_label = "static_shrink_rhsns_exal_mcmc_gausmix_lastmile",
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
    config_path = config_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile(row$row_id),
    row_status_path = row_status_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile(row$row_id),
    health_path = health_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile(row$row_id),
    metrics_path = metrics_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile(row$row_id),
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

read_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_status <- function(
    manifest_path = paths_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile()$manifest,
    run_tag = run_tag_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile()) {
  read_original288_syncedbase_rerun_status(manifest_path = manifest_path, run_tag = run_tag)
}

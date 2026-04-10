source("tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_helpers_20260410.R")

run_tag_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge <- function() {
  "original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_20260410"
}

variant_tag_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge <- function() {
  "orig288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_20260410"
}

phase_order_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge <- c(
  phase1_static_shrink_rhsns_exal_mcmc_gausmix_burn_bridge = 1L,
  phase2_static_shrink_rhsns_exal_mcmc_gausmix_vb_bridge = 2L,
  phase3_static_shrink_rhsns_exal_mcmc_gausmix_newkernels = 3L
)

paths_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge <- function() {
  tag <- run_tag_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge()
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", tag))
  list(
    accepted_selection = "tools/merge_reports/LOCAL_original288_carryforward_selection_v8_20260410.csv",
    working_baseline = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_working_baseline_v2_20260410.csv",
    schedule = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_schedule_20260410.csv",
    manifest = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_manifest_20260410.csv",
    stage_counts = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_stage_counts_20260410.csv",
    manifest_status = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_manifest_status_20260410.csv",
    phase_summary = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_phase_summary_20260410.csv",
    target_summary = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_target_summary_20260410.csv",
    compare_accepted = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_compare_accepted_20260410.csv",
    compare_working = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_compare_working_20260410.csv",
    config_dir = file.path(run_dir, "configs"),
    rows_dir = file.path(run_dir, "rows"),
    health_dir = file.path(run_dir, "health"),
    metrics_dir = file.path(run_dir, "metrics"),
    logs_dir = file.path(run_dir, "logs"),
    tracker_doc = "reports/static_exal_tuning_20260406/integration_branch_validation_status_20260406.md",
    static_tracker_doc = "tools/merge_reports/LOCAL_VALIDATION_RECOVERY_TRACKER_STATIC_EXAL_20260331.md",
    program_doc = "reports/static_exal_tuning_20260410/original_288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_program_20260410.md",
    execution_doc = "reports/static_exal_tuning_20260410/original_288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_execution_20260410.md"
  )
}

target_run_root_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge <- function(repo_root, family, tau_label, fit_size) {
  normalize_path_original288(file.path(
    repo_root,
    "results",
    "function_testing_20260309_static_shrinkage_family_qspec",
    family,
    sprintf("tau_%s", tau_label),
    sprintf("fit_input_subsample_tt%d_x01_sorted", as.integer(fit_size)),
    sprintf("validation_shrink_rhsns_gausmix_stationarity_bridge_tt%d", as.integer(fit_size))
  ))
}

candidate_fit_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge <- function(
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
      variant_tag_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge(),
      sanitize_profile_slug_original288_static_shrink_rhsns_exal_mcmc_repair(profile_id)
    )
  ))
}

config_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge()$config_dir,
    sprintf("row_%04d_run_config.rds", as.integer(row_id))
  )
}

row_status_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge()$rows_dir,
    sprintf("row_%04d.csv", as.integer(row_id))
  )
}

health_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge()$health_dir,
    sprintf("health_%04d.csv", as.integer(row_id))
  )
}

metrics_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge()$metrics_dir,
    sprintf("metrics_%04d.csv", as.integer(row_id))
  )
}

read_failed_rows_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge <- function() {
  x <- utils::read.csv(
    paths_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge()$working_baseline,
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

vb_init_controls_profile_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge <- function(profile) {
  profile <- safe_chr_original288_syncedbase_rerun(profile, "none")
  if (identical(profile, "none")) return(NULL)
  switch(
    profile,
    ldvb20 = list(max_iter = 20L, tol = 0.20, n_samp_xi = 60L, verbose = FALSE),
    ldvb40 = list(max_iter = 40L, tol = 0.10, n_samp_xi = 80L, verbose = FALSE),
    ldvb80 = list(max_iter = 80L, tol = 0.05, n_samp_xi = 120L, verbose = FALSE),
    stop(sprintf("unknown vb_init_profile: %s", profile))
  )
}

schedule_spec_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge <- function() {
  data.frame(
    base_row_id = rep(44L, 24L),
    phase = c(
      rep("phase1_static_shrink_rhsns_exal_mcmc_gausmix_burn_bridge", 8L),
      rep("phase2_static_shrink_rhsns_exal_mcmc_gausmix_vb_bridge", 8L),
      rep("phase3_static_shrink_rhsns_exal_mcmc_gausmix_newkernels", 8L)
    ),
    repair_class = c(
      rep("burn_bridge", 8L),
      rep("vb_bridge", 8L),
      rep("newkernel_bridge", 8L)
    ),
    candidate_rank = c(seq_len(8L), seq_len(8L), seq_len(8L)),
    profile_id = c(
      "bridge_rw_f085_s100_b12000_k2000_sub2",
      "bridge_rw_f085_s100_b14000_k2000_sub3_refresh85",
      "bridge_rw_f085_s100_b16000_k1500_sub4_refresh85",
      "bridge_rw_f085_s100_b14000_k2000_sub3_noadapt",
      "bridge_rw_f0845_s100_b12000_k2000_sub2",
      "bridge_rw_f0845_s100_b14000_k2000_sub3_refresh85",
      "bridge_rw_f0845_s100_b16000_k1500_sub4_refresh85",
      "bridge_rw_f0825_s1025_b14000_k2000_sub3_refresh75",
      "bridge_vb_rw_f085_s100_ld20_b8000_k2500",
      "bridge_vb_rw_f085_s100_ld40_b10000_k2500_refresh85",
      "bridge_vb_rw_f0845_s100_ld20_b8000_k2500",
      "bridge_vb_rw_f0845_s100_ld40_b10000_k2500_refresh85",
      "bridge_vb_rw_f0825_s1025_ld40_b10000_k2500_refresh75",
      "bridge_vb_sliceeta_f085_s100_ld20_b8000_k2500_w18_s320",
      "bridge_vb_sliceeta_f0845_s100_ld40_b9000_k2500_w18_s320",
      "bridge_vb_slice_f085_s100_ld40_b9000_k2500_w16_s240",
      "bridge_local_f085_s100_b9000_k3000",
      "bridge_local_f0845_s100_b9000_k3000",
      "bridge_local_f0825_s1025_b10000_k2500",
      "bridge_sliceeta_f085_s100_b9000_k3000_w18_s320",
      "bridge_sliceeta_f0845_s100_b9000_k3000_w18_s320",
      "bridge_sliceeta_f0825_s1025_b10000_k2500_w20_s360",
      "bridge_vb_local_f0845_s100_ld80_b9000_k2500",
      "bridge_vb_sliceeta_f085_s100_ld80_b10000_k2500_w20_s360_sub4"
    ),
    init_from_vb = c(
      rep(FALSE, 8L),
      rep(TRUE, 8L),
      FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, TRUE
    ),
    vb_init_profile = c(
      rep("none", 8L),
      "ldvb20", "ldvb40", "ldvb20", "ldvb40", "ldvb40", "ldvb20", "ldvb40", "ldvb40",
      "none", "none", "none", "none", "none", "none", "ldvb80", "ldvb80"
    ),
    mh_proposal = c(
      rep("laplace_rw", 13L),
      "slice_eta", "slice_eta", "slice",
      "laplace_local", "laplace_local", "laplace_local",
      "slice_eta", "slice_eta", "slice_eta",
      "laplace_local", "slice_eta"
    ),
    mh_adapt = c(
      TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE,
      TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE,
      FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE
    ),
    n_burn = c(
      12000L, 14000L, 16000L, 14000L, 12000L, 14000L, 16000L, 14000L,
      8000L, 10000L, 8000L, 10000L, 10000L, 8000L, 9000L, 9000L,
      9000L, 9000L, 10000L, 9000L, 9000L, 10000L, 9000L, 10000L
    ),
    n_mcmc = c(
      2000L, 2000L, 1500L, 2000L, 2000L, 2000L, 1500L, 2000L,
      2500L, 2500L, 2500L, 2500L, 2500L, 2500L, 2500L, 2500L,
      3000L, 3000L, 2500L, 3000L, 3000L, 2500L, 2500L, 2500L
    ),
    thin = 1L,
    gamma_substeps = c(
      2L, 3L, 4L, 3L, 2L, 3L, 4L, 3L,
      2L, 3L, 2L, 3L, 3L, 3L, 3L, 2L,
      2L, 2L, 3L, 3L, 3L, 3L, 2L, 4L
    ),
    p_global_eta_jump = c(
      0.0850, 0.0850, 0.0850, 0.0850, 0.0845, 0.0845, 0.0845, 0.0825,
      0.0850, 0.0850, 0.0845, 0.0845, 0.0825, 0.0850, 0.0845, 0.0850,
      0.0850, 0.0845, 0.0825, 0.0850, 0.0845, 0.0825, 0.0845, 0.0850
    ),
    global_eta_jump_scale = c(
      1.000, 1.000, 1.000, 1.000, 1.000, 1.000, 1.000, 1.025,
      1.000, 1.000, 1.000, 1.000, 1.025, 1.000, 1.000, 1.000,
      1.000, 1.000, 1.025, 1.000, 1.000, 1.025, 1.000, 1.000
    ),
    slice_width = c(
      rep(NA_real_, 13L),
      0.18, 0.18, 0.16,
      NA_real_, NA_real_, NA_real_,
      0.18, 0.18, 0.20,
      NA_real_, 0.20
    ),
    slice_max_steps = c(
      rep(NA_integer_, 13L),
      320L, 320L, 240L,
      NA_integer_, NA_integer_, NA_integer_,
      320L, 320L, 360L,
      NA_integer_, 360L
    ),
    laplace_refresh_interval = c(
      50L, 10L, 10L, 50L, 50L, 10L, 10L, 25L,
      50L, 10L, 50L, 10L, 25L, 25L, 25L, 25L,
      25L, 25L, 25L, 25L, 25L, 25L, 25L, 25L
    ),
    laplace_refresh_start = c(
      333L, 50L, 50L, 333L, 333L, 50L, 50L, 150L,
      333L, 50L, 333L, 50L, 150L, 150L, 150L, 150L,
      150L, 150L, 150L, 150L, 150L, 150L, 150L, 150L
    ),
    laplace_refresh_weight = c(
      0.60, 0.85, 0.85, 0.60, 0.60, 0.85, 0.85, 0.75,
      0.60, 0.85, 0.60, 0.85, 0.75, 0.75, 0.75, 0.75,
      0.75, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75
    ),
    historical_anchor_variant_tag = c(
      "failband2_F085_sub2_s100",
      "failband2_F085_sub2_s100",
      "failband2_F085_sub2_s100",
      "failband2_F085_sub2_s100",
      "failband2_F0845_sub2_s100",
      "failband2_F0845_sub2_s100",
      "failband2_F0845_sub2_s100",
      "failband2_F0825_sub2_s1025",
      "failband2_F085_sub2_s100",
      "failband2_F085_sub2_s100",
      "failband2_F0845_sub2_s100",
      "failband2_F0845_sub2_s100",
      "failband2_F0825_sub2_s1025",
      "failband2_F085_sub2_s100",
      "failband2_F0845_sub2_s100",
      "failband2_F085_sub2_s100",
      "failband2_F085_sub2_s100",
      "failband2_F0845_sub2_s100",
      "failband2_F0825_sub2_s1025",
      "failband2_F085_sub2_s100",
      "failband2_F0845_sub2_s100",
      "failband2_F0825_sub2_s1025",
      "failband2_F0845_sub2_s100",
      "failband2_F085_sub2_s100"
    ),
    rationale = c(
      "Discard much more burn on the strongest F085/s100 rw anchor and keep only a compact retained segment to test whether the remaining row-44 failure is mostly a late-stationarity problem.",
      "Combine the strongest F085/s100 anchor with a burn-heavy bridge, a third gamma substep, and early heavy refresh as the most direct stationarity-to-ESS bridge.",
      "Push the best F085/s100 anchor to an even heavier burn bridge and four gamma substeps so the search finally tests whether row 44 can close once nearly all transient behavior is discarded.",
      "Replay the burn-heavy F085/s100 bridge without MH adaptation to see whether late adaptation is still perturbing the retained chain after the longer burn window.",
      "Run the same heavy-burn bridge on the lower-mid F0845/s100 anchor because it showed cleaner retained-segment drift than the high-band anchor in the prior wave.",
      "Carry the best F0845/s100 geometry into the same third-substep early-refresh bridge so the stationarity search is not overcommitted to the F085 neighborhood.",
      "Give the F0845/s100 anchor the deepest burn-heavy bridge in the program as the cleanest low-mid attempt to recover both drift and gamma ESS together.",
      "Keep one softer F0825/s1025 bridge alive with a heavy burn and moderate early refresh because that band occasionally traded a little ESS for much cleaner drift.",
      "Use a conservative LDVB warm start on the strongest F085/s100 rw anchor to see whether a better initial sigma/gamma state can shorten the transient without abandoning the successful rw geometry.",
      "Push the same F085/s100 warm-start bridge deeper with heavier refresh so the row gets one serious VB-seeded attempt at the best high-band geometry.",
      "Mirror the conservative VB-seeded bridge on the cleaner F0845/s100 anchor rather than assuming the high-band seed is the only route to closure.",
      "Carry the deeper VB-seeded F0845/s100 bridge with early heavy refresh as the strongest low-mid warm-start attempt in the schedule.",
      "Keep one VB-seeded soft-band rw hedge alive so the bridge program still learns whether smoother initial states help the lower-jump geometry more than the higher band.",
      "Test the transformed exact-kernel route with a conservative warm start on the strongest F085/s100 anchor instead of repeating no-init slice probes that already screened out poorly.",
      "Mirror the warm-started slice_eta bridge on the cleaner F0845/s100 anchor so the exact-kernel test is not tied to only the highest rw band.",
      "Keep one gamma-space slice bridge with VB warm start as a narrow hedge in case eta-space movement is not the main missing ingredient on row 44.",
      "Test the approximate local-Gaussian kernel on the strongest F085/s100 anchor to see whether a less sticky local proposal family can raise gamma ESS without needing large global jumps.",
      "Run the same local-Gaussian kernel on the cleaner F0845/s100 anchor because that anchor previously offered the best retained-segment stability among the rw corridors.",
      "Carry one local-Gaussian soft-band hedge so the new-kernel phase still checks whether a smoother lower-jump band works better once the proposal family changes completely.",
      "Test slice_eta without VB on the strongest F085/s100 anchor so the new-kernel phase includes one pure exact-kernel bridge after the burn-heavy rw work is exhausted.",
      "Mirror the pure slice_eta bridge on the F0845/s100 anchor because that band repeatedly showed the cleanest drift in the rw-only waves.",
      "Keep one softer-band slice_eta hedge with a broader width and longer path length so the exact-kernel side of the search stays broad without reopening the clearly weak high-band edges.",
      "Combine the local-Gaussian kernel with the deepest conservative VB warm start on the cleaner F0845/s100 anchor as a last high-information approximation bridge.",
      "Make one maximal transformed exact-kernel bridge with the deepest conservative VB warm start on the strongest F085/s100 anchor so the lane has a real end-point beyond the earlier plain slice hedges."
    ),
    stringsAsFactors = FALSE
  )
}

materialize_schedule_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge <- function() {
  base_fail <- read_failed_rows_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge()
  names(base_fail)[names(base_fail) == "profile_id"] <- "base_profile_id"
  spec <- schedule_spec_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge()
  spec$phase_order <- unname(phase_order_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge[spec$phase])

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
    2026041030L + as.integer(merged$base_row_id) * 100L + as.integer(merged$candidate_rank)
  )
  merged$historical_source <- hist_source
  merged <- merged[order(merged$phase_order, merged$base_row_id, merged$candidate_rank, merged$profile_id), , drop = FALSE]
  rownames(merged) <- NULL
  merged$row_id <- seq_len(nrow(merged))
  merged
}

build_row_config_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge <- function(row, repo_root) {
  data_dir <- source_input_dir_original288_static_shrink_rhsns_rebuild(row$family, row$tau_label, row$fit_size)
  run_root <- target_run_root_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge(repo_root, row$family, row$tau_label, row$fit_size)
  fit_path <- candidate_fit_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge(
    run_root = run_root,
    inference = "mcmc",
    model = "exal",
    tau_label = row$tau_label,
    profile_id = row$profile_id
  )

  vb_profile <- safe_chr_original288_syncedbase_rerun(row$vb_init_profile, "none")
  vb_controls <- if (isTRUE(row$init_from_vb)) {
    vb_init_controls_profile_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge(vb_profile)
  } else {
    list(max_iter = 1000L, tol = 1e-4, n_samp_xi = 200L, verbose = FALSE)
  }
  init_mode <- if (isTRUE(row$init_from_vb)) sprintf("vb:%s", vb_profile) else "none"

  list(
    row_id = as.integer(row$row_id),
    base_row_id = as.integer(row$base_row_id),
    tag = run_tag_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge(),
    phase = row$phase,
    phase_order = row$phase_order,
    lane_label = "static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge",
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
    config_path = config_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge(row$row_id),
    row_status_path = row_status_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge(row$row_id),
    health_path = health_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge(row$row_id),
    metrics_path = metrics_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge(row$row_id),
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
    vb_init_profile = vb_profile,
    vb_init_controls = vb_controls,
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
    requested_init_mode = init_mode,
    resolved_init_mode = init_mode,
    rationale = row$rationale
  )
}

read_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_status <- function(
    manifest_path = paths_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge()$manifest,
    run_tag = run_tag_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge()) {
  read_original288_syncedbase_rerun_status(manifest_path = manifest_path, run_tag = run_tag)
}

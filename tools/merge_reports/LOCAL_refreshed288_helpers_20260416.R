source("tools/merge_reports/LOCAL_original288_normalized_multiseed_helpers_20260411.R")

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

default_run_tag_refreshed288 <- function() {
  "20260416"
}

sanitize_tag_refreshed288 <- function(x, default = default_run_tag_refreshed288()) {
  x <- safe_chr_original288_normalized_multiseed(x, default = default)
  x <- gsub("[^A-Za-z0-9_\\-]", "_", x)
  if (!nzchar(x)) default else x
}

run_tag_refreshed288 <- function() {
  tag_raw <- getOption(
    "refreshed288.run_tag",
    Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())
  )
  sprintf("refreshed288_paperaligned_%s", sanitize_tag_refreshed288(tag_raw))
}

variant_tag_refreshed288 <- function() {
  variant_raw <- getOption(
    "refreshed288.variant_tag",
    Sys.getenv("REFRESHED288_VARIANT_TAG", unset = sprintf("0p50_ldvb_slice_%s", sanitize_tag_refreshed288(getOption(
      "refreshed288.run_tag",
      Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())
    ))))
  )
  sprintf("refreshed288_%s", sanitize_tag_refreshed288(variant_raw, default = sprintf("0p50_ldvb_slice_%s", default_run_tag_refreshed288())))
}

report_stamp_refreshed288 <- function() {
  tag_raw <- sanitize_tag_refreshed288(getOption(
    "refreshed288.run_tag",
    Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())
  ))
  if (grepl("^[0-9]{8}([_-].*)?$", tag_raw)) {
    sub("^([0-9]{8}).*$", "\\1", tag_raw)
  } else {
    tag_raw
  }
}

phase_order_refreshed288 <- c(
  smoke_static_vb = 1L,
  smoke_dynamic_vb = 2L,
  smoke_static_mcmc = 3L,
  smoke_dynamic_mcmc = 4L,
  full_static_vb = 5L,
  full_dynamic_vb = 6L,
  full_static_mcmc = 7L,
  full_dynamic_mcmc = 8L
)

refreshed288_source_repo_root <- function() {
  "/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs"
}

refreshed288_tau_grid <- function() {
  data.frame(
    tau_label = c("0p05", "0p25", "0p50"),
    tau = c(0.05, 0.25, 0.50),
    stringsAsFactors = FALSE
  )
}

refreshed288_dynamic_sizes <- function() c(500L, 5000L)

refreshed288_static_sizes <- function() c(100L, 1000L)

paths_refreshed288 <- function() {
  tag <- run_tag_refreshed288()
  report_stamp <- report_stamp_refreshed288()
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", tag))
  list(
    dataset_registry = sprintf("tools/merge_reports/LOCAL_refreshed288_dataset_registry_%s.csv", sanitize_tag_refreshed288(getOption("refreshed288.run_tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())))),
    method_registry = sprintf("tools/merge_reports/LOCAL_refreshed288_method_registry_%s.csv", sanitize_tag_refreshed288(getOption("refreshed288.run_tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())))),
    smoke_manifest = sprintf("tools/merge_reports/LOCAL_refreshed288_smoke_manifest_%s.csv", sanitize_tag_refreshed288(getOption("refreshed288.run_tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())))),
    full_manifest = sprintf("tools/merge_reports/LOCAL_refreshed288_full_manifest_%s.csv", sanitize_tag_refreshed288(getOption("refreshed288.run_tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())))),
    smoke_stage_counts = sprintf("tools/merge_reports/LOCAL_refreshed288_smoke_stage_counts_%s.csv", sanitize_tag_refreshed288(getOption("refreshed288.run_tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())))),
    full_stage_counts = sprintf("tools/merge_reports/LOCAL_refreshed288_full_stage_counts_%s.csv", sanitize_tag_refreshed288(getOption("refreshed288.run_tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())))),
    smoke_manifest_status = sprintf("tools/merge_reports/LOCAL_refreshed288_smoke_manifest_status_%s.csv", sanitize_tag_refreshed288(getOption("refreshed288.run_tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())))),
    full_manifest_status = sprintf("tools/merge_reports/LOCAL_refreshed288_full_manifest_status_%s.csv", sanitize_tag_refreshed288(getOption("refreshed288.run_tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())))),
    smoke_phase_summary = sprintf("tools/merge_reports/LOCAL_refreshed288_smoke_phase_summary_%s.csv", sanitize_tag_refreshed288(getOption("refreshed288.run_tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())))),
    full_phase_summary = sprintf("tools/merge_reports/LOCAL_refreshed288_full_phase_summary_%s.csv", sanitize_tag_refreshed288(getOption("refreshed288.run_tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())))),
    smoke_method_summary = sprintf("tools/merge_reports/LOCAL_refreshed288_smoke_method_summary_%s.csv", sanitize_tag_refreshed288(getOption("refreshed288.run_tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())))),
    full_method_summary = sprintf("tools/merge_reports/LOCAL_refreshed288_full_method_summary_%s.csv", sanitize_tag_refreshed288(getOption("refreshed288.run_tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())))),
    smoke_report = sprintf("reports/static_exal_tuning_%s/refreshed288_smoke_status_%s.md", report_stamp, sanitize_tag_refreshed288(getOption("refreshed288.run_tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())))),
    full_report = sprintf("reports/static_exal_tuning_%s/refreshed288_full_status_%s.md", report_stamp, sanitize_tag_refreshed288(getOption("refreshed288.run_tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())))),
    spec_doc = sprintf("reports/static_exal_tuning_%s/refreshed288_relaunch_spec_%s.md", report_stamp, sanitize_tag_refreshed288(getOption("refreshed288.run_tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())))),
    run_contract = sprintf("tools/merge_reports/LOCAL_refreshed288_run_contract_%s.csv", sanitize_tag_refreshed288(getOption("refreshed288.run_tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())))),
    run_root = run_dir,
    config_dir = file.path(run_dir, "configs"),
    rows_dir = file.path(run_dir, "rows"),
    health_dir = file.path(run_dir, "health"),
    metrics_dir = file.path(run_dir, "metrics"),
    draws_dir = file.path(run_dir, "draws"),
    logs_dir = file.path(run_dir, "logs"),
    fits_dir = file.path(run_dir, "fits"),
    vb_init_dir = file.path(run_dir, "vb_init")
  )
}

current_git_sha_refreshed288 <- function(repo_root = ".") {
  out <- tryCatch(system2("git", c("-C", normalizePath(repo_root, winslash = "/", mustWork = TRUE), "rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE), error = function(...) character(0))
  if (!length(out)) NA_character_ else safe_chr_refreshed288(out[[1]], NA_character_)
}

current_git_branch_refreshed288 <- function(repo_root = ".") {
  out <- tryCatch(system2("git", c("-C", normalizePath(repo_root, winslash = "/", mustWork = TRUE), "rev-parse", "--abbrev-ref", "HEAD"), stdout = TRUE, stderr = FALSE), error = function(...) character(0))
  if (!length(out)) NA_character_ else safe_chr_refreshed288(out[[1]], NA_character_)
}

write_run_contract_refreshed288 <- function(paths, repo_root = ".") {
  contract <- data.frame(
    run_tag = run_tag_refreshed288(),
    variant_tag = variant_tag_refreshed288(),
    canonical_status = "planned_canonical_rerun",
    predecessor_run_tag = "refreshed288_paperaligned_20260416",
    predecessor_run_root = "tools/merge_reports/full288_refreshed288_paperaligned_20260416",
    predecessor_role = "interrupted_pilot_non_canonical",
    tau_grid = "0.05,0.25,0.50",
    static_shrink_priors = "ridge,rhs_ns",
    rhs_plain_forbidden = TRUE,
    rhsns_tau_warmup_vb = 50L,
    rhsns_tau_warmup_mcmc = 500L,
    rhsns_tau_warmup_vb_init = 50L,
    rhsns_vb_min_iter = 80L,
    sigmagam_vb_warmup_plan = "10_enabled",
    sigmagam_mcmc_warmup_plan = "50_enabled",
    sigmagam_status = "validation_repo_sigmagam_enabled",
    source_repo_root = refreshed288_source_repo_root(),
    validation_repo_branch = current_git_branch_refreshed288(repo_root),
    validation_repo_sha = current_git_sha_refreshed288(repo_root),
    run_root = paths$run_root,
    spec_doc = paths$spec_doc,
    full_manifest = paths$full_manifest,
    method_registry = paths$method_registry,
    stringsAsFactors = FALSE
  )
  utils::write.csv(contract, paths$run_contract, row.names = FALSE)
  invisible(contract)
}

ensure_dir_refreshed288 <- function(path) {
  ensure_dir_original288_normalized_multiseed(path)
}

safe_chr_refreshed288 <- function(x, default = NA_character_) {
  safe_chr_original288_normalized_multiseed(x, default = default)
}

safe_num_refreshed288 <- function(x, default = NA_real_) {
  safe_num_original288_normalized_multiseed(x, default = default)
}

safe_int_refreshed288 <- function(x, default = NA_integer_) {
  safe_int_original288_normalized_multiseed(x, default = default)
}

as_flag_refreshed288 <- function(x, default = FALSE) {
  as_flag_original288_normalized_multiseed(x, default = default)
}

hash_seed_refreshed288 <- function(key) {
  hash_seed_original288_normalized_multiseed(key)
}

select_draw_indices_refreshed288 <- function(n_available, n_target, seed) {
  select_draw_indices_original288_normalized_multiseed(n_available, n_target, seed)
}

safe_rmvnorm_refreshed288 <- function(n, mean, sigma) {
  safe_rmvnorm_original288_normalized_multiseed(n = n, mean = mean, sigma = sigma)
}

static_build_design_refreshed288 <- function(series_wide) {
  static_build_design_original288_normalized_multiseed(series_wide)
}

static_predictive_draws_refreshed288 <- function(fit_obj, row, series_wide, n_draws = 20000L, seed = 1L) {
  static_predictive_draws_original288_normalized_multiseed(
    fit_obj = fit_obj,
    row = row,
    series_wide = series_wide,
    n_draws = n_draws,
    seed = seed
  )
}

static_metrics_refreshed288 <- function(row, fit_obj, series_wide, coef_truth, draws_bundle) {
  static_metrics_original288_normalized_multiseed(
    row = row,
    fit_obj = fit_obj,
    series_wide = series_wide,
    coef_truth = coef_truth,
    draws_bundle = draws_bundle
  )
}

dynamic_standardize_draws_refreshed288 <- function(fit_obj, n_draws = 20000L, seed = 1L) {
  dynamic_standardize_draws_original288_normalized_multiseed(
    fit_obj = fit_obj,
    n_draws = n_draws,
    seed = seed
  )
}

dynamic_metrics_refreshed288 <- function(row, sim_obj, draw_mat) {
  dynamic_metrics_original288_normalized_multiseed(row = row, sim_obj = sim_obj, draw_mat = draw_mat)
}

canonical_dynamic_ld_controls_refreshed288 <- function(store_trace = TRUE) {
  list(
    optimizer_method = "lbfgsb",
    direct_commit = TRUE,
    auto_stabilize = TRUE,
    eig_floor = 1e-6,
    eta_lo = -12,
    eta_hi = 12,
    sigma_init_mode = "data_scale",
    reject_bad_mode_commit = TRUE,
    sts = canonical_sts_vb_controls_refreshed288(0L),
    sigmagam = canonical_sigmagam_vb_controls_refreshed288(),
    store_trace = isTRUE(store_trace)
  )
}

canonical_static_ld_controls_refreshed288 <- function(store_trace = TRUE) {
  list(
    optimizer_method = "lbfgsb",
    direct_commit = TRUE,
    auto_stabilize = TRUE,
    eig_floor = 1e-6,
    eta_lo = -12,
    eta_hi = 12,
    sigma_init_mode = "data_scale",
    gamma_init_mode = "midpoint",
    reject_bad_mode_commit = TRUE,
    sigmagam = canonical_sigmagam_vb_controls_refreshed288(),
    store_trace = isTRUE(store_trace)
  )
}

canonical_sigmagam_vb_controls_refreshed288 <- function(warmup_iters = 10L) {
  warmup_iters <- safe_int_refreshed288(warmup_iters, 10L)
  if (!is.finite(warmup_iters) || warmup_iters < 0L) warmup_iters <- 10L
  list(
    freeze_warmup_iters = as.integer(warmup_iters),
    force_after_warmup = TRUE,
    postwarmup_damping = 1.0,
    postwarmup_damping_iters = 0L,
    min_postwarmup_updates = 1L
  )
}

canonical_sigmagam_mcmc_controls_refreshed288 <- function(warmup_iters = 50L) {
  warmup_iters <- safe_int_refreshed288(warmup_iters, 50L)
  if (!is.finite(warmup_iters) || warmup_iters < 0L) warmup_iters <- 50L
  list(
    freeze_burnin_iters = as.integer(warmup_iters),
    freeze_only_during_burn = TRUE,
    force_after_warmup = TRUE,
    delay_adapt_until_after_warmup = TRUE,
    delay_laplace_refresh_until_after_warmup = TRUE
  )
}

canonical_sts_vb_controls_refreshed288 <- function(warmup_iters = 0L) {
  warmup_iters <- safe_int_refreshed288(warmup_iters, 0L)
  if (!is.finite(warmup_iters) || warmup_iters < 0L) warmup_iters <- 0L
  list(
    freeze_warmup_iters = as.integer(warmup_iters),
    force_after_warmup = TRUE,
    min_postwarmup_updates = if (warmup_iters > 0L) 1L else 0L
  )
}

runtime_sigmagam_vb_controls_refreshed288 <- function() {
  list(
    freeze_warmup_iters = 50L,
    force_after_warmup = TRUE,
    postwarmup_damping = 0.5,
    postwarmup_damping_iters = 5L,
    min_postwarmup_updates = 5L
  )
}

runtime_sts_vb_controls_refreshed288 <- function() {
  list(
    freeze_warmup_iters = 50L,
    force_after_warmup = TRUE,
    min_postwarmup_updates = 5L
  )
}

runtime_sigmagam_mcmc_controls_refreshed288 <- function() {
  canonical_sigmagam_mcmc_controls_refreshed288(500L)
}

runtime_latent_state_controls_refreshed288 <- function(model) {
  list(
    mode = if (identical(model, "dqlm")) "u_only" else "u_st_pair",
    freeze_burnin_iters = 100L,
    freeze_only_during_burn = TRUE,
    force_after_warmup = TRUE
  )
}

runtime_theta_state_controls_refreshed288 <- function() {
  list(
    freeze_burnin_iters = 100L,
    freeze_only_during_burn = TRUE,
    force_after_warmup = TRUE
  )
}

runtime_dqlm_sigma_controls_refreshed288 <- function() {
  list(
    freeze_burnin_iters = 500L,
    freeze_only_during_burn = TRUE,
    force_after_warmup = TRUE
  )
}

runtime_mcmc_backend_controls_refreshed288 <- function() {
  list(
    mcmc_use_cpp = TRUE,
    mcmc_cpp_mode = "strict"
  )
}

runtime_dynamic_ld_controls_refreshed288 <- function(store_trace = TRUE) {
  base <- canonical_dynamic_ld_controls_refreshed288(store_trace = store_trace)
  base$sts <- runtime_sts_vb_controls_refreshed288()
  base$sigmagam <- runtime_sigmagam_vb_controls_refreshed288()
  base
}

runtime_dynamic_vb_controls_refreshed288 <- function(store_trace = TRUE) {
  list(
    vb_method = "ldvb",
    vb_max_iter = 800L,
    vb_min_iter = 80L,
    vb_tol = 0.01,
    vb_n_samp_internal = 20000L,
    ld_controls = runtime_dynamic_ld_controls_refreshed288(store_trace = store_trace)
  )
}

runtime_dynamic_vb_init_controls_refreshed288 <- function() {
  list(
    method = "ldvb",
    tol = 0.01,
    n.IS = 200L,
    n.samp = 5000L,
    max_iter = 800L,
    min_iter = 80L,
    verbose = FALSE,
    ld_controls = runtime_dynamic_ld_controls_refreshed288(store_trace = FALSE)
  )
}

runtime_vb_init_validation_refreshed288 <- function(model) {
  list(
    require_theta_finite = TRUE,
    require_post_pred_finite = TRUE,
    require_sfe_finite = TRUE,
    require_sigma_finite = TRUE,
    require_gamma_finite = identical(model, "exdqlm")
  )
}

runtime_failure_method_profiles_refreshed288 <- function() {
  list(
    runtime_dynamic__exdqlm__vb__primary = list(
      method_profile_id = "runtime_dynamic__exdqlm__vb__primary",
      block = "dynamic",
      root_kind = "dynamic",
      prior_semantics = "default",
      model = "exdqlm",
      inference = "vb",
      fit_engine = "exdqlmLDVB",
      dqlm_ind = FALSE,
      df_value = 0.98,
      dim_df = c(2L, 4L),
      stored_posterior_draws = 20000L,
      notes = "runtime-failure direct VB rerun with stronger LDVB stabilization and exdqlm s_t warmup",
      vb_method = "ldvb",
      vb_max_iter = 800L,
      vb_min_iter = 80L,
      vb_tol = 0.01,
      vb_n_samp_internal = 20000L,
      ld_controls = runtime_dynamic_ld_controls_refreshed288(store_trace = TRUE)
    ),
    runtime_dynamic__dqlm__mcmc__primary = list(
      method_profile_id = "runtime_dynamic__dqlm__mcmc__primary",
      block = "dynamic",
      root_kind = "dynamic",
      prior_semantics = "default",
      model = "dqlm",
      inference = "mcmc",
      fit_engine = "exdqlmMCMC",
      dqlm_ind = TRUE,
      df_value = 0.98,
      dim_df = c(2L, 4L),
      stored_posterior_draws = 20000L,
      notes = "runtime-failure DQLM MCMC rerun with stronger init, theta warmup, Ut warmup, sigma warmup, and C++ strict MCMC backend",
      init_from_vb = TRUE,
      vb_init_method = "ldvb",
      vb_init_profile_id = "runtime_dynamic_ldvb_init",
      vb_init_controls = runtime_dynamic_vb_init_controls_refreshed288(),
      vb_init_ld_controls = runtime_dynamic_ld_controls_refreshed288(store_trace = FALSE),
      vb_init_validation = runtime_vb_init_validation_refreshed288("dqlm"),
      theta_state_controls = runtime_theta_state_controls_refreshed288(),
      latent_state_controls = runtime_latent_state_controls_refreshed288("dqlm"),
      dqlm_sigma_controls = runtime_dqlm_sigma_controls_refreshed288(),
      mcmc_use_cpp = TRUE,
      mcmc_cpp_mode = "strict",
      n_burn = 5000L,
      n_mcmc = 20000L,
      thin = 1L,
      mh_proposal = "slice",
      mh_adapt = TRUE,
      mh_adapt_interval = 50L,
      mh_target_accept_lo = 0.20,
      mh_target_accept_hi = 0.45,
      mh_scale_lo = 0.10,
      mh_scale_hi = 10.0,
      mh_max_scale_step = 0.35,
      mh_min_burn_adapt = 50L,
      trace_diagnostics = TRUE,
      trace_every = 50L,
      slice_width = 0.10,
      slice_max_steps = Inf
    ),
    runtime_dynamic__exdqlm__mcmc__primary = list(
      method_profile_id = "runtime_dynamic__exdqlm__mcmc__primary",
      block = "dynamic",
      root_kind = "dynamic",
      prior_semantics = "default",
      model = "exdqlm",
      inference = "mcmc",
      fit_engine = "exdqlmMCMC",
      dqlm_ind = FALSE,
      df_value = 0.98,
      dim_df = c(2L, 4L),
      stored_posterior_draws = 20000L,
      notes = "runtime-failure exDQLM MCMC rerun with stronger init, theta warmup, latent-pair warmup, exdqlm s_t VB-init warmup, larger sigmagam warmup, and C++ strict MCMC backend",
      init_from_vb = TRUE,
      vb_init_method = "ldvb",
      vb_init_profile_id = "runtime_dynamic_ldvb_init",
      vb_init_controls = runtime_dynamic_vb_init_controls_refreshed288(),
      vb_init_ld_controls = runtime_dynamic_ld_controls_refreshed288(store_trace = FALSE),
      vb_init_validation = runtime_vb_init_validation_refreshed288("exdqlm"),
      theta_state_controls = runtime_theta_state_controls_refreshed288(),
      latent_state_controls = runtime_latent_state_controls_refreshed288("exdqlm"),
      sigmagam_controls = runtime_sigmagam_mcmc_controls_refreshed288(),
      mcmc_use_cpp = TRUE,
      mcmc_cpp_mode = "strict",
      n_burn = 5000L,
      n_mcmc = 20000L,
      thin = 1L,
      mh_proposal = "slice",
      mh_adapt = TRUE,
      mh_adapt_interval = 50L,
      mh_target_accept_lo = 0.20,
      mh_target_accept_hi = 0.45,
      mh_scale_lo = 0.10,
      mh_scale_hi = 10.0,
      mh_max_scale_step = 0.35,
      mh_min_burn_adapt = 50L,
      trace_diagnostics = TRUE,
      trace_every = 50L,
      slice_width = 0.10,
      slice_max_steps = Inf
    )
  )
}

rhs_ns_tau_controls_refreshed288 <- function(warmup_iters) {
  warmup_iters <- safe_int_refreshed288(warmup_iters, 50L)
  if (!is.finite(warmup_iters) || warmup_iters < 0L) warmup_iters <- 50L
  list(
    freeze_tau_iters = as.integer(warmup_iters),
    freeze_tau_warmup_iters = as.integer(warmup_iters),
    update_every = 1L,
    update_every_warmup = 1L,
    update_every_warmup_iters = 0L,
    force_tau_after_warmup = TRUE
  )
}

assert_no_plain_rhs_refreshed288 <- function(x, context = "refreshed288") {
  rhs_fields <- intersect(
    c("prior_semantics", "beta_prior", "prior", "static_prior", "shrink_prior"),
    names(x)
  )
  if (!length(rhs_fields) || !nrow(x)) return(invisible(x))

  bad_rows <- rep(FALSE, nrow(x))
  for (field in rhs_fields) {
    vals <- trimws(tolower(as.character(x[[field]])))
    bad_rows <- bad_rows | (!is.na(vals) & vals == "rhs")
  }
  if (any(bad_rows)) {
    row_ids <- if ("row_id" %in% names(x)) x$row_id[bad_rows] else which(bad_rows)
    stop(
      sprintf(
        "[%s] plain rhs detected in rows: %s. The refreshed relaunch only allows ridge and rhs_ns.",
        context,
        paste(row_ids, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  invisible(x)
}

method_profile_id_refreshed288 <- function(root_kind, prior_semantics, model, inference) {
  if (identical(root_kind, "dynamic")) {
    return(sprintf("dynamic__%s__%s", model, inference))
  }
  sprintf("%s__%s__%s__%s", root_kind, prior_semantics, model, inference)
}

method_profiles_refreshed288 <- local({
  cache <- NULL

  build_dynamic_profile <- function(model, inference) {
    dqlm_ind <- identical(model, "dqlm")
    base <- list(
      method_profile_id = method_profile_id_refreshed288("dynamic", "default", model, inference),
      block = "dynamic",
      root_kind = "dynamic",
      prior_semantics = "default",
      model = model,
      inference = inference,
      fit_engine = if (identical(inference, "vb")) "exdqlmLDVB" else "exdqlmMCMC",
      dqlm_ind = dqlm_ind,
      df_value = 0.98,
      dim_df = c(2L, 4L),
      stored_posterior_draws = 20000L,
      notes = "dynamic paper-aligned refreshed study using direct CSV-backed inputs"
    )

    if (identical(inference, "vb")) {
      return(c(base, list(
        vb_method = "ldvb",
        vb_max_iter = 300L,
        vb_tol = 0.03,
        vb_n_samp_internal = 20000L,
        ld_controls = canonical_dynamic_ld_controls_refreshed288(store_trace = TRUE)
      )))
    }

    c(base, list(
      init_from_vb = TRUE,
      vb_init_method = "ldvb",
      vb_init_profile_id = "dynamic_ldvb_init",
      vb_init_controls = list(
        method = "ldvb",
        tol = 0.03,
        n.IS = 200L,
        n.samp = 1000L,
        max_iter = 300L,
        verbose = FALSE,
        ld_controls = canonical_dynamic_ld_controls_refreshed288(store_trace = FALSE)
      ),
      vb_init_ld_controls = canonical_dynamic_ld_controls_refreshed288(store_trace = FALSE),
      sigmagam_controls = canonical_sigmagam_mcmc_controls_refreshed288(50L),
      n_burn = 5000L,
      n_mcmc = 20000L,
      thin = 1L,
      mh_proposal = "slice",
      mh_adapt = TRUE,
      mh_adapt_interval = 50L,
      mh_target_accept_lo = 0.20,
      mh_target_accept_hi = 0.45,
      mh_scale_lo = 0.10,
      mh_scale_hi = 10.0,
      mh_max_scale_step = 0.35,
      mh_min_burn_adapt = 50L,
      trace_diagnostics = TRUE,
      trace_every = 50L,
      slice_width = 0.10,
      slice_max_steps = Inf
    ))
  }

  build_static_profile <- function(root_kind, prior_semantics, model, inference) {
    dqlm_ind <- identical(model, "al")
    if (identical(root_kind, "static_shrink") && !(prior_semantics %in% c("ridge", "rhs_ns"))) {
      stop(
        sprintf(
          "refreshed288 static_shrink only supports prior_semantics in {ridge, rhs_ns}; got '%s'",
          prior_semantics
        ),
        call. = FALSE
      )
    }
    beta_prior <- if (identical(prior_semantics, "rhs_ns")) "rhs_ns" else "ridge"
    beta_prior_controls <- if (identical(root_kind, "static_shrink") && identical(prior_semantics, "rhs_ns")) {
      rhs_ns_tau_controls_refreshed288(if (identical(inference, "vb")) 50L else 500L)
    } else {
      NULL
    }
    base <- list(
      method_profile_id = method_profile_id_refreshed288(root_kind, prior_semantics, model, inference),
      block = "static",
      root_kind = root_kind,
      prior_semantics = prior_semantics,
      model = model,
      inference = inference,
      fit_engine = if (identical(inference, "vb")) "exal_static_LDVB" else "exal_static_mcmc",
      dqlm_ind = dqlm_ind,
      beta_prior = beta_prior,
      beta_prior_controls = beta_prior_controls,
      stored_posterior_draws = 20000L,
      notes = if (identical(root_kind, "static_paper")) {
        "static paper-aligned refreshed study; paper-facing slice MCMC profile"
      } else {
        "static shrinkage refreshed study; standardized canonical slice MCMC profile"
      }
    )

    if (identical(inference, "vb")) {
      return(c(base, list(
        vb_method = "ldvb",
        max_iter = 300L,
        min_iter = if (identical(root_kind, "static_shrink") && identical(prior_semantics, "rhs_ns")) 80L else NA_integer_,
        tol = 0.03,
        n_samp_xi = 1000L,
        ld_controls = canonical_static_ld_controls_refreshed288(store_trace = TRUE)
      )))
    }

    slice_width <- if (identical(root_kind, "static_paper")) 0.01 else 0.10
    slice_max_steps <- if (identical(root_kind, "static_paper")) Inf else Inf

    c(base, list(
      init_from_vb = TRUE,
      vb_init_method = "ldvb",
      vb_init_profile_id = "static_ldvb_init",
      vb_init_beta_prior_controls = if (identical(root_kind, "static_shrink") && identical(prior_semantics, "rhs_ns")) {
        rhs_ns_tau_controls_refreshed288(50L)
      } else {
        NULL
      },
      vb_init_controls = list(
        max_iter = 300L,
        min_iter = if (identical(root_kind, "static_shrink") && identical(prior_semantics, "rhs_ns")) 80L else NA_integer_,
        tol = 0.03,
        n_samp_xi = 1000L,
        ld_controls = canonical_static_ld_controls_refreshed288(store_trace = FALSE),
        verbose = FALSE
      ),
      sigmagam_controls = canonical_sigmagam_mcmc_controls_refreshed288(50L),
      n_burn = 5000L,
      n_mcmc = 20000L,
      thin = 1L,
      mh_proposal = "slice",
      mh_adapt = TRUE,
      mh_adapt_interval = 50L,
      mh_target_accept_lo = 0.20,
      mh_target_accept_hi = 0.45,
      mh_scale_lo = 0.10,
      mh_scale_hi = 10.0,
      mh_max_scale_step = 0.35,
      mh_min_burn_adapt = 50L,
      gamma_substeps = 1L,
      p_global_eta_jump = 0,
      global_eta_jump_scale = 1,
      trace_diagnostics = TRUE,
      trace_every = 50L,
      slice_width = slice_width,
      slice_max_steps = slice_max_steps
    ))
  }

  function(force = FALSE) {
    if (!force && !is.null(cache)) return(cache)

    profiles <- list()
    for (model in c("dqlm", "exdqlm")) {
      for (inference in c("vb", "mcmc")) {
        prof <- build_dynamic_profile(model, inference)
        profiles[[prof$method_profile_id]] <- prof
      }
    }
    for (root_kind in c("static_paper", "static_shrink")) {
      prior_vec <- if (identical(root_kind, "static_paper")) "paper" else c("ridge", "rhs_ns")
      for (prior_semantics in prior_vec) {
        for (model in c("al", "exal")) {
          for (inference in c("vb", "mcmc")) {
            prof <- build_static_profile(root_kind, prior_semantics, model, inference)
            profiles[[prof$method_profile_id]] <- prof
          }
        }
      }
    }
    cache <<- profiles
    profiles
  }
})

flatten_method_profiles_refreshed288 <- function(profiles = method_profiles_refreshed288()) {
  rows <- lapply(profiles, function(x) {
    data.frame(
      method_profile_id = x$method_profile_id,
      block = x$block,
      root_kind = x$root_kind,
      prior_semantics = x$prior_semantics,
      model = x$model,
      inference = x$inference,
      fit_engine = x$fit_engine,
      dqlm_ind = isTRUE(x$dqlm_ind),
      beta_prior = safe_chr_refreshed288(x$beta_prior, NA_character_),
      stored_posterior_draws = safe_int_refreshed288(x$stored_posterior_draws, 20000L),
      df_value = safe_num_refreshed288(x$df_value, NA_real_),
      dim_df = if (!is.null(x$dim_df)) paste(as.integer(x$dim_df), collapse = ",") else NA_character_,
      vb_method = safe_chr_refreshed288(x$vb_method, safe_chr_refreshed288(x$vb_init_method, NA_character_)),
      vb_max_iter = safe_int_refreshed288(x$vb_max_iter %||% x$max_iter, NA_integer_),
      vb_min_iter = safe_int_refreshed288(x$vb_min_iter %||% x$min_iter, NA_integer_),
      vb_tol = safe_num_refreshed288(x$vb_tol %||% x$tol, NA_real_),
      vb_n_samp_internal = safe_int_refreshed288(x$vb_n_samp_internal, NA_integer_),
      n_samp_xi = safe_int_refreshed288(x$n_samp_xi, NA_integer_),
      rhs_tau_warmup_iters = safe_int_refreshed288(x$beta_prior_controls$freeze_tau_warmup_iters, NA_integer_),
      sts_vb_warmup_iters = safe_int_refreshed288(x$ld_controls$sts$freeze_warmup_iters, NA_integer_),
      sts_vb_min_postwarmup_updates = safe_int_refreshed288(x$ld_controls$sts$min_postwarmup_updates, NA_integer_),
      sigmagam_vb_warmup_iters = safe_int_refreshed288(x$ld_controls$sigmagam$freeze_warmup_iters, NA_integer_),
      sigmagam_vb_min_postwarmup_updates = safe_int_refreshed288(x$ld_controls$sigmagam$min_postwarmup_updates, NA_integer_),
      sigmagam_vb_postwarmup_damping = safe_num_refreshed288(x$ld_controls$sigmagam$postwarmup_damping, NA_real_),
      sigmagam_vb_postwarmup_damping_iters = safe_int_refreshed288(x$ld_controls$sigmagam$postwarmup_damping_iters, NA_integer_),
      init_from_vb = as_flag_refreshed288(x$init_from_vb, FALSE),
      vb_init_profile_id = safe_chr_refreshed288(x$vb_init_profile_id, NA_character_),
      vb_init_method = safe_chr_refreshed288(x$vb_init_method, NA_character_),
      vb_init_max_iter = safe_int_refreshed288(x$vb_init_controls$max_iter, NA_integer_),
      vb_init_min_iter = safe_int_refreshed288(x$vb_init_controls$min_iter, NA_integer_),
      vb_init_tol = safe_num_refreshed288(x$vb_init_controls$tol, NA_real_),
      vb_init_n_samp = safe_int_refreshed288(x$vb_init_controls$n.samp, NA_integer_),
      vb_init_n_samp_xi = safe_int_refreshed288(x$vb_init_controls$n_samp_xi, NA_integer_),
      vb_init_rhs_tau_warmup_iters = safe_int_refreshed288(x$vb_init_beta_prior_controls$freeze_tau_warmup_iters, NA_integer_),
      vb_init_sts_warmup_iters = safe_int_refreshed288((x$vb_init_ld_controls %||% x$vb_init_controls$ld_controls)$sts$freeze_warmup_iters, NA_integer_),
      vb_init_sts_min_postwarmup_updates = safe_int_refreshed288((x$vb_init_ld_controls %||% x$vb_init_controls$ld_controls)$sts$min_postwarmup_updates, NA_integer_),
      vb_init_sigmagam_warmup_iters = safe_int_refreshed288((x$vb_init_ld_controls %||% x$vb_init_controls$ld_controls)$sigmagam$freeze_warmup_iters, NA_integer_),
      vb_init_sigmagam_min_postwarmup_updates = safe_int_refreshed288((x$vb_init_ld_controls %||% x$vb_init_controls$ld_controls)$sigmagam$min_postwarmup_updates, NA_integer_),
      vb_init_sigmagam_postwarmup_damping = safe_num_refreshed288((x$vb_init_ld_controls %||% x$vb_init_controls$ld_controls)$sigmagam$postwarmup_damping, NA_real_),
      vb_init_sigmagam_postwarmup_damping_iters = safe_int_refreshed288((x$vb_init_ld_controls %||% x$vb_init_controls$ld_controls)$sigmagam$postwarmup_damping_iters, NA_integer_),
      vb_init_require_theta_finite = as_flag_refreshed288(x$vb_init_validation$require_theta_finite, FALSE),
      vb_init_require_post_pred_finite = as_flag_refreshed288(x$vb_init_validation$require_post_pred_finite, FALSE),
      vb_init_require_sfe_finite = as_flag_refreshed288(x$vb_init_validation$require_sfe_finite, FALSE),
      vb_init_require_sigma_finite = as_flag_refreshed288(x$vb_init_validation$require_sigma_finite, FALSE),
      vb_init_require_gamma_finite = as_flag_refreshed288(x$vb_init_validation$require_gamma_finite, FALSE),
      n_burn = safe_int_refreshed288(x$n_burn, NA_integer_),
      n_mcmc = safe_int_refreshed288(x$n_mcmc, NA_integer_),
      thin = safe_int_refreshed288(x$thin, NA_integer_),
      theta_state_warmup_iters = safe_int_refreshed288(x$theta_state_controls$freeze_burnin_iters, NA_integer_),
      theta_state_force_after_warmup = as_flag_refreshed288(x$theta_state_controls$force_after_warmup, FALSE),
      latent_state_mode = safe_chr_refreshed288(x$latent_state_controls$mode, NA_character_),
      latent_state_warmup_iters = safe_int_refreshed288(x$latent_state_controls$freeze_burnin_iters, NA_integer_),
      latent_state_force_after_warmup = as_flag_refreshed288(x$latent_state_controls$force_after_warmup, FALSE),
      dqlm_sigma_warmup_iters = safe_int_refreshed288(x$dqlm_sigma_controls$freeze_burnin_iters, NA_integer_),
      dqlm_sigma_force_after_warmup = as_flag_refreshed288(x$dqlm_sigma_controls$force_after_warmup, FALSE),
      sigmagam_mcmc_warmup_iters = safe_int_refreshed288(x$sigmagam_controls$freeze_burnin_iters, NA_integer_),
      sigmagam_mcmc_delay_adapt = as_flag_refreshed288(x$sigmagam_controls$delay_adapt_until_after_warmup, FALSE),
      sigmagam_mcmc_delay_laplace_refresh = as_flag_refreshed288(x$sigmagam_controls$delay_laplace_refresh_until_after_warmup, FALSE),
      mh_proposal = safe_chr_refreshed288(x$mh_proposal, NA_character_),
      slice_width = safe_num_refreshed288(x$slice_width, NA_real_),
      slice_max_steps = if (is.null(x$slice_max_steps)) NA_real_ else as.numeric(x$slice_max_steps),
      mcmc_use_cpp = as_flag_refreshed288(x$mcmc_use_cpp, NA),
      mcmc_cpp_mode = safe_chr_refreshed288(x$mcmc_cpp_mode, NA_character_),
      mh_adapt = as_flag_refreshed288(x$mh_adapt, FALSE),
      trace_diagnostics = as_flag_refreshed288(x$trace_diagnostics, FALSE),
      trace_every = safe_int_refreshed288(x$trace_every, NA_integer_),
      ld_control_profile = if (identical(x$block, "dynamic")) {
        if (identical(x$inference, "mcmc")) "dynamic_ldvb_init_and_slice" else "dynamic_ldvb_full"
      } else {
        if (identical(x$inference, "mcmc")) "static_ldvb_init_and_slice" else "static_ldvb_full"
      },
      notes = x$notes,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out <- out[order(out$root_kind, out$prior_semantics, out$model, out$inference), , drop = FALSE]
  assert_no_plain_rhs_refreshed288(out, context = "method_registry")
  out
}

build_dataset_registry_refreshed288 <- function() {
  tau_grid <- refreshed288_tau_grid()
  fams <- c("normal", "laplace", "gausmix")
  rows <- list()
  idx <- 0L

  add_row <- function(block, root_kind, family, tau_label, tau, fit_size, source_root, input_dir) {
    idx <<- idx + 1L
    coef_truth_path <- if (identical(block, "static")) file.path(input_dir, "coef_truth.csv") else NA_character_
    req_paths <- c(
      file.path(input_dir, "series_long.csv"),
      file.path(input_dir, "series_wide.csv"),
      file.path(input_dir, "selection_indices.csv"),
      file.path(input_dir, "true_quantile_grid.csv")
    )
    if (identical(block, "static")) req_paths <- c(req_paths, coef_truth_path)
    missing_paths <- req_paths[!file.exists(req_paths)]

    rows[[idx]] <<- data.frame(
      dataset_id = sprintf("%s::%s::%s::%s", root_kind, family, tau_label, as.integer(fit_size)),
      block = block,
      root_kind = root_kind,
      family = family,
      tau = tau,
      tau_label = tau_label,
      fit_size = as.integer(fit_size),
      source_root = normalizePath(source_root, winslash = "/", mustWork = TRUE),
      input_dir = normalizePath(input_dir, winslash = "/", mustWork = TRUE),
      series_long_path = normalizePath(file.path(input_dir, "series_long.csv"), winslash = "/", mustWork = FALSE),
      series_wide_path = normalizePath(file.path(input_dir, "series_wide.csv"), winslash = "/", mustWork = FALSE),
      selection_indices_path = normalizePath(file.path(input_dir, "selection_indices.csv"), winslash = "/", mustWork = FALSE),
      true_quantile_grid_path = normalizePath(file.path(input_dir, "true_quantile_grid.csv"), winslash = "/", mustWork = FALSE),
      coef_truth_path = if (identical(block, "static")) normalizePath(coef_truth_path, winslash = "/", mustWork = FALSE) else NA_character_,
      meta_path = normalizePath(file.path(source_root, "meta.txt"), winslash = "/", mustWork = FALSE),
      validation_path = normalizePath(file.path(source_root, "validation.csv"), winslash = "/", mustWork = FALSE),
      missing_inputs = length(missing_paths) > 0L,
      missing_paths = if (length(missing_paths)) paste(normalizePath(missing_paths, winslash = "/", mustWork = FALSE), collapse = ";") else NA_character_,
      stringsAsFactors = FALSE
    )
  }

  for (family in fams) {
    for (i in seq_len(nrow(tau_grid))) {
      tau_label <- tau_grid$tau_label[i]
      tau <- tau_grid$tau[i]

      dynamic_root <- file.path(
        refreshed288_source_repo_root(),
        "results",
        "function_testing_20260309_dynamic_dlm_family_qspec",
        "dlm_constV_smallW",
        family,
        sprintf("tau_%s", tau_label)
      )
      for (fit_size in refreshed288_dynamic_sizes()) {
        add_row(
          block = "dynamic",
          root_kind = "dynamic",
          family = family,
          tau_label = tau_label,
          tau = tau,
          fit_size = fit_size,
          source_root = dynamic_root,
          input_dir = file.path(dynamic_root, sprintf("fit_input_lastTT%d", fit_size))
        )
      }

      paper_root <- file.path(
        refreshed288_source_repo_root(),
        "results",
        "function_testing_20260309_static_paper_family_qspec",
        family,
        sprintf("tau_%s", tau_label)
      )
      for (fit_size in refreshed288_static_sizes()) {
        add_row(
          block = "static",
          root_kind = "static_paper",
          family = family,
          tau_label = tau_label,
          tau = tau,
          fit_size = fit_size,
          source_root = paper_root,
          input_dir = file.path(paper_root, sprintf("fit_input_subsample_tt%d_x01_sorted", fit_size))
        )
      }

      shrink_root <- file.path(
        refreshed288_source_repo_root(),
        "results",
        "function_testing_20260309_static_shrinkage_family_qspec",
        family,
        sprintf("tau_%s", tau_label)
      )
      for (fit_size in refreshed288_static_sizes()) {
        add_row(
          block = "static",
          root_kind = "static_shrink",
          family = family,
          tau_label = tau_label,
          tau = tau,
          fit_size = fit_size,
          source_root = shrink_root,
          input_dir = file.path(shrink_root, sprintf("fit_input_subsample_tt%d_x01_sorted", fit_size))
        )
      }
    }
  }

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$block, out$root_kind, out$family, out$tau, out$fit_size), , drop = FALSE]
}

case_key_refreshed288 <- function(root_kind, family, tau_label, fit_size, prior_semantics, model, inference) {
  sprintf(
    "%s::%s::%s::%s::%s::%s::%s",
    root_kind,
    family,
    tau_label,
    as.integer(fit_size),
    prior_semantics,
    model,
    inference
  )
}

case_pair_key_refreshed288 <- function(root_kind, family, tau_label, fit_size, prior_semantics, model) {
  sprintf(
    "%s::%s::%s::%s::%s::%s",
    root_kind,
    family,
    tau_label,
    as.integer(fit_size),
    prior_semantics,
    model
  )
}

case_slug_refreshed288 <- function(x) {
  y <- gsub("::", "__", as.character(x), fixed = TRUE)
  y <- gsub("[^A-Za-z0-9_]+", "_", y)
  y <- gsub("_+", "_", y)
  y
}

phase_for_row_refreshed288 <- function(block, inference, kind = c("full", "smoke")) {
  kind <- match.arg(kind)
  prefix <- sprintf("%s_", kind)
  if (identical(block, "dynamic") && identical(inference, "vb")) return(paste0(prefix, "dynamic_vb"))
  if (identical(block, "dynamic") && identical(inference, "mcmc")) return(paste0(prefix, "dynamic_mcmc"))
  if (identical(inference, "vb")) return(paste0(prefix, "static_vb"))
  paste0(prefix, "static_mcmc")
}

smoke_case_keys_refreshed288 <- function(manifest) {
  wanted <- c()
  for (fit_size in c(500L, 5000L)) {
    for (model in c("dqlm", "exdqlm")) {
      for (inference in c("vb", "mcmc")) {
        wanted <- c(wanted, case_key_refreshed288("dynamic", "normal", "0p50", fit_size, "default", model, inference))
      }
    }
  }
  for (fit_size in c(100L, 1000L)) {
    for (model in c("al", "exal")) {
      for (inference in c("vb", "mcmc")) {
        wanted <- c(wanted, case_key_refreshed288("static_paper", "normal", "0p50", fit_size, "paper", model, inference))
      }
    }
  }
  for (prior_semantics in c("ridge", "rhs_ns")) {
    for (model in c("al", "exal")) {
      for (inference in c("vb", "mcmc")) {
        wanted <- c(wanted, case_key_refreshed288("static_shrink", "normal", "0p50", 100L, prior_semantics, model, inference))
      }
    }
  }
  intersect(wanted, manifest$original_case_key)
}

build_dynamic_sim_object_refreshed288 <- function(series_wide_path, true_quantile_grid_path = NA_character_, tau = NA_real_, period = 50L) {
  series_wide <- utils::read.csv(series_wide_path, stringsAsFactors = FALSE, check.names = FALSE)
  q_truth <- if ("q_target" %in% names(series_wide)) {
    as.numeric(series_wide$q_target)
  } else if (!is.na(true_quantile_grid_path) && file.exists(true_quantile_grid_path) && "t" %in% names(series_wide)) {
    grid <- utils::read.csv(true_quantile_grid_path, stringsAsFactors = FALSE, check.names = FALSE)
    grid <- subset(grid, abs(tau - as.numeric(grid$tau)) < 1e-12)
    match_idx <- match(series_wide$t, grid$t)
    as.numeric(grid$q_true[match_idx])
  } else {
    rep(NA_real_, nrow(series_wide))
  }

  list(
    y = as.numeric(series_wide$y),
    q = matrix(q_truth, ncol = 1L),
    info = list(
      params = list(period = as.integer(period)[1]),
      source = "direct_csv_backed_rebuild"
    ),
    source_series_wide = series_wide
  )
}

parse_args_refreshed288 <- function(args) {
  out <- list()
  for (x in args) {
    if (grepl("^--[^=]+=.*$", x)) {
      key <- sub("^--([^=]+)=.*$", "\\1", x)
      val <- sub("^--[^=]+=(.*)$", "\\1", x)
      out[[key]] <- val
    } else if (grepl("^--", x)) {
      key <- sub("^--", "", x)
      out[[key]] <- "TRUE"
    }
  }
  out
}

safe_num_vec_refreshed288 <- function(x, default) {
  v <- suppressWarnings(as.numeric(x))
  if (!length(v) || any(!is.finite(v))) return(as.numeric(default))
  v
}

compact_fit_refreshed288 <- function(fit, inference) {
  out <- fit
  if (identical(inference, "mcmc")) {
    out$samp.v <- NULL
    out$samp.s <- NULL
    if (!is.null(out$mh.diagnostics$trace)) out$mh.diagnostics$trace <- NULL
  } else {
    if (!is.null(out$diagnostics$trace)) out$diagnostics$trace <- NULL
  }
  out
}

set_dynamic_ld_options_refreshed288 <- function(ld_list) {
  if (!is.list(ld_list) || !length(ld_list)) return(list())
  named <- ld_list
  names(named) <- paste0("exdqlm.dynamic.ldvb.", names(ld_list))
  options(named)
}

collect_vb_health_refreshed288 <- function(wrapped,
                                           case_id,
                                           variant,
                                           candidate_path,
                                           vhg_extract_rhs_collapse) {
  fit <- wrapped$fit %||% wrapped
  conv <- fit$diagnostics$convergence$converged %||% fit$converged %||% NA
  stop_reason <- as.character(fit$diagnostics$convergence$stop_reason %||% NA_character_)
  rhs <- vhg_extract_rhs_collapse(fit)

  finite_ok <- TRUE
  if (!is.null(fit$diagnostics$deltas)) {
    d <- unlist(fit$diagnostics$deltas, use.names = FALSE)
    d <- d[is.finite(d)]
    finite_ok <- length(d) > 0L
  }

  gate_overall <- if (isTRUE(rhs$collapse_flag)) {
    "FAIL"
  } else if (isTRUE(conv)) {
    "PASS"
  } else if (isTRUE(finite_ok)) {
    "WARN"
  } else {
    "FAIL"
  }

  data.frame(
    case_id = case_id,
    variant = variant,
    gate_overall = gate_overall,
    healthy = gate_overall %in% c("PASS", "WARN") && !isTRUE(rhs$collapse_flag),
    unhealthy_reason = if (isTRUE(rhs$collapse_flag)) "rhs_collapse" else if (gate_overall == "FAIL") "vb_fail" else NA_character_,
    rhs_collapse_flag = isTRUE(rhs$collapse_flag),
    rhs_collapse_sources = rhs$collapse_sources,
    vb_converged = isTRUE(conv),
    vb_stop_reason = stop_reason,
    run_time_sec = safe_num_refreshed288(wrapped$meta$runtime_sec %||% fit$run.time, NA_real_),
    candidate_path = candidate_path,
    stringsAsFactors = FALSE
  )
}

write_row_status_refreshed288 <- function(row, status, ts_start, ts_end = as.character(Sys.time()), error = NA_character_, gate_overall = NA_character_, healthy = FALSE, runtime_sec = NA_real_) {
  out <- data.frame(
    row_id = row$row_id,
    base_row_id = row$base_row_id,
    original_case_key = row$original_case_key,
    ts_start = ts_start,
    ts_end = ts_end,
    status = status,
    error = error,
    gate_overall = gate_overall,
    healthy = healthy,
    runtime_sec = runtime_sec,
    phase = row$phase,
    block = row$block,
    root_kind = row$root_kind,
    family = row$family,
    tau_label = row$tau_label,
    fit_size = row$fit_size,
    prior_semantics = row$prior_semantics,
    model = row$model,
    inference = row$inference,
    method_profile_id = row$method_profile_id,
    seed = row$seed,
    candidate_fit_path = row$candidate_fit_path,
    vb_init_fit_path = row$vb_init_fit_path,
    health_csv = row$health_path,
    metrics_csv = row$metrics_path,
    draws_rds = row$draws_path,
    retain_candidate_fit_binaries = as_flag_refreshed288(row$retain_candidate_fit_binaries, FALSE),
    retain_vb_init_binaries = as_flag_refreshed288(row$retain_vb_init_binaries, FALSE),
    retain_draw_binaries = as_flag_refreshed288(row$retain_draw_binaries, FALSE),
    stringsAsFactors = FALSE
  )
  utils::write.csv(out, row$row_status_path, row.names = FALSE)
}

write_row_failure_refreshed288 <- function(row, reason) {
  health_row <- data.frame(
    case_id = row$original_case_key,
    variant = run_tag_refreshed288(),
    gate_overall = "FAIL",
    healthy = FALSE,
    unhealthy_reason = "runtime_fail",
    rhs_collapse_flag = NA,
    run_time_sec = NA_real_,
    candidate_path = row$candidate_fit_path,
    stringsAsFactors = FALSE
  )
  metrics_row <- data.frame(
    row_id = row$row_id,
    base_row_id = row$base_row_id,
    original_case_key = row$original_case_key,
    phase = row$phase,
    block = row$block,
    root_kind = row$root_kind,
    family = row$family,
    tau_label = row$tau_label,
    fit_size = row$fit_size,
    prior_semantics = row$prior_semantics,
    model = row$model,
    inference = row$inference,
    method_profile_id = row$method_profile_id,
    seed = row$seed,
    gate_overall = "FAIL",
    healthy = FALSE,
    runtime_sec = NA_real_,
    crps_metric = NA_real_,
    primary_accuracy_metric = NA_real_,
    q_rmse_metric = NA_real_,
    coverage95_metric = NA_real_,
    coverage95_gap_metric = NA_real_,
    mean_ci_width_metric = NA_real_,
    cie_metric = NA_real_,
    beta_rmse_mean_metric = NA_real_,
    beta_coverage_gap_metric = NA_real_,
    metric_source = "runtime_fail",
    metric_error = reason,
    stringsAsFactors = FALSE
  )
  utils::write.csv(health_row, row$health_path, row.names = FALSE)
  utils::write.csv(metrics_row, row$metrics_path, row.names = FALSE)
  write_row_status_refreshed288(
    row = row,
    status = "failed_runtime",
    ts_start = as.character(Sys.time()),
    ts_end = as.character(Sys.time()),
    error = reason,
    gate_overall = "FAIL",
    healthy = FALSE,
    runtime_sec = NA_real_
  )
}

summarize_status_refreshed288 <- function(df, group_cols) {
  key <- interaction(df[, group_cols, drop = FALSE], drop = TRUE, lex.order = TRUE)
  spl <- split(df, key)
  out <- lapply(spl, function(d) {
    base <- d[1, group_cols, drop = FALSE]
    data.frame(
      base,
      total = nrow(d),
      completed = sum(d$status_current %in% c("done", "skipped_existing", "failed_runtime")),
      running = sum(d$status_current == "running"),
      not_started = sum(d$status_current == "not_started"),
      pass = sum(d$gate_current == "PASS"),
      warn = sum(d$gate_current == "WARN"),
      fail = sum(d$gate_current == "FAIL"),
      healthy = sum(d$healthy_current),
      pct_completed = round(100 * sum(d$status_current %in% c("done", "skipped_existing", "failed_runtime")) / nrow(d), 1),
      pct_active_or_done = round(100 * sum(d$status_current != "not_started") / nrow(d), 1),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out
}

build_manifest_refreshed288 <- function(dataset_registry, repo_root) {
  profiles <- method_profiles_refreshed288()
  paths <- paths_refreshed288()
  rows <- list()
  row_id <- 0L

  dir_candidates <- c(
    paths$run_root,
    paths$config_dir,
    paths$rows_dir,
    paths$health_dir,
    paths$metrics_dir,
    paths$draws_dir,
    paths$logs_dir,
    file.path(paths$fits_dir, "vb"),
    file.path(paths$fits_dir, "mcmc"),
    file.path(paths$vb_init_dir, "dynamic"),
    file.path(paths$vb_init_dir, "static"),
    dirname(paths$smoke_report),
    dirname(paths$full_report)
  )
  for (path in dir_candidates) ensure_dir_refreshed288(path)

  for (i in seq_len(nrow(dataset_registry))) {
    ds <- dataset_registry[i, , drop = FALSE]
    model_vec <- if (identical(ds$block, "dynamic")) c("dqlm", "exdqlm") else c("al", "exal")
    prior_vec <- if (identical(ds$root_kind, "static_shrink")) c("ridge", "rhs_ns") else if (identical(ds$root_kind, "static_paper")) "paper" else "default"
    for (prior_semantics in prior_vec) {
      for (model in model_vec) {
        for (inference in c("vb", "mcmc")) {
          row_id <- row_id + 1L
          original_case_key <- case_key_refreshed288(
            root_kind = ds$root_kind,
            family = ds$family,
            tau_label = ds$tau_label,
            fit_size = ds$fit_size,
            prior_semantics = prior_semantics,
            model = model,
            inference = inference
          )
          pair_id <- case_pair_key_refreshed288(
            root_kind = ds$root_kind,
            family = ds$family,
            tau_label = ds$tau_label,
            fit_size = ds$fit_size,
            prior_semantics = prior_semantics,
            model = model
          )
          profile_id <- method_profile_id_refreshed288(ds$root_kind, prior_semantics, model, inference)
          profile <- profiles[[profile_id]]
          slug <- case_slug_refreshed288(original_case_key)
          fit_path <- file.path(paths$fits_dir, inference, sprintf("row_%04d_%s_fit.rds", row_id, slug))
          vb_init_fit_path <- if (identical(inference, "mcmc")) {
            file.path(paths$vb_init_dir, ds$block, sprintf("row_%04d_%s_vb_init.rds", row_id, slug))
          } else {
            NA_character_
          }
          config_path <- file.path(paths$config_dir, sprintf("row_%04d_run_config.rds", row_id))
          row_status_path <- file.path(paths$rows_dir, sprintf("row_%04d_status.csv", row_id))
          health_path <- file.path(paths$health_dir, sprintf("row_%04d_health.csv", row_id))
          metrics_path <- file.path(paths$metrics_dir, sprintf("row_%04d_metrics.csv", row_id))
          draws_path <- file.path(paths$draws_dir, sprintf("row_%04d_draws.rds", row_id))
          fit_seed <- hash_seed_refreshed288(original_case_key)

          cfg <- c(
            list(
              repo_root = normalizePath(repo_root, winslash = "/", mustWork = TRUE),
              row_id = row_id,
              base_row_id = row_id,
              original_case_key = original_case_key,
              pair_id = pair_id,
              source_dataset_id = ds$dataset_id,
              method_profile_id = profile_id,
              fit_seed = fit_seed,
              tau = ds$tau,
              tau_label = ds$tau_label,
              period = 50L,
              candidate_fit_path = fit_path,
              row_status_path = row_status_path,
              health_path = health_path,
              metrics_path = metrics_path,
              draws_path = draws_path,
              vb_init_fit_path = vb_init_fit_path,
              series_long_path = ds$series_long_path,
              series_wide_path = ds$series_wide_path,
              selection_indices_path = ds$selection_indices_path,
              true_quantile_grid_path = ds$true_quantile_grid_path,
              coef_truth_path = ds$coef_truth_path,
              missing_inputs = isTRUE(ds$missing_inputs),
              missing_paths = ds$missing_paths
            ),
            profile
          )
          saveRDS(cfg, config_path)

          rows[[row_id]] <- data.frame(
            row_id = row_id,
            base_row_id = row_id,
            original_case_key = original_case_key,
            pair_id = pair_id,
            seed = fit_seed,
            status = "not_started",
            phase = phase_for_row_refreshed288(ds$block, inference, kind = "full"),
            phase_order = unname(phase_order_refreshed288[phase_for_row_refreshed288(ds$block, inference, kind = "full")]),
            missing_inputs = isTRUE(ds$missing_inputs),
            block = ds$block,
            root_kind = ds$root_kind,
            family = ds$family,
            tau = ds$tau,
            tau_label = ds$tau_label,
            fit_size = ds$fit_size,
            prior_semantics = prior_semantics,
            model = model,
            inference = inference,
            source_dataset_id = ds$dataset_id,
            method_profile_id = profile_id,
            config_path = config_path,
            run_root = paths$run_root,
            candidate_fit_path = fit_path,
            vb_init_fit_path = vb_init_fit_path,
            row_status_path = row_status_path,
            health_path = health_path,
            metrics_path = metrics_path,
            draws_path = draws_path,
            stored_posterior_draws = safe_int_refreshed288(profile$stored_posterior_draws, 20000L),
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }

  manifest <- do.call(rbind, rows)
  rownames(manifest) <- NULL
  manifest <- manifest[order(manifest$row_id), , drop = FALSE]
  assert_no_plain_rhs_refreshed288(manifest, context = "full_manifest")
  manifest
}

#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_refreshed288_helpers_20260416.R")

args <- parse_args_refreshed288(commandArgs(trailingOnly = TRUE))
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

run_tag_arg <- safe_chr_refreshed288(
  args$run_tag,
  Sys.getenv("REFRESHED288_RUN_TAG", unset = "20260419_row8_cppprobe_v1")
)
variant_tag_arg <- safe_chr_refreshed288(
  args$variant_tag,
  Sys.getenv("REFRESHED288_VARIANT_TAG", unset = "row8_cppprobe_v1")
)
source_run_tag <- safe_chr_refreshed288(args$source_run_tag, "20260417_canonical_v1")
target_row_id <- safe_int_refreshed288(args$target_row_id, 8L)

options(
  refreshed288.run_tag = run_tag_arg,
  refreshed288.variant_tag = variant_tag_arg
)

paths <- paths_refreshed288()
sanitized_run_tag <- sanitize_tag_refreshed288(run_tag_arg, default = run_tag_arg)
report_dir <- file.path("reports", sprintf("static_exal_tuning_%s", report_stamp_refreshed288()))
manifest_path <- file.path(
  "tools", "merge_reports",
  sprintf("LOCAL_refreshed288_row8_cpp_probe_manifest_%s.csv", sanitized_run_tag)
)
method_registry_path <- file.path(
  "tools", "merge_reports",
  sprintf("LOCAL_refreshed288_row8_cpp_probe_method_registry_%s.csv", sanitized_run_tag)
)
status_path <- file.path(
  "tools", "merge_reports",
  sprintf("LOCAL_refreshed288_row8_cpp_probe_manifest_status_%s.csv", sanitized_run_tag)
)
phase_path <- file.path(
  "tools", "merge_reports",
  sprintf("LOCAL_refreshed288_row8_cpp_probe_phase_summary_%s.csv", sanitized_run_tag)
)
method_path <- file.path(
  "tools", "merge_reports",
  sprintf("LOCAL_refreshed288_row8_cpp_probe_method_summary_%s.csv", sanitized_run_tag)
)
stage_counts_path <- file.path(
  "tools", "merge_reports",
  sprintf("LOCAL_refreshed288_row8_cpp_probe_stage_counts_%s.csv", sanitized_run_tag)
)
run_contract_path <- file.path(
  "tools", "merge_reports",
  sprintf("LOCAL_refreshed288_row8_cpp_probe_run_contract_%s.csv", sanitized_run_tag)
)
source_manifest_path <- file.path(
  "tools", "merge_reports",
  sprintf(
    "LOCAL_refreshed288_full_manifest_%s.csv",
    sanitize_tag_refreshed288(source_run_tag, default = source_run_tag)
  )
)
arm_matrix_path <- file.path(
  "reports",
  "static_exal_tuning_20260419",
  "refreshed288_numcrash_row8_cpp_arm_matrix_20260419.csv"
)
arm_matrix_copy_path <- file.path(
  "tools", "merge_reports",
  sprintf("LOCAL_refreshed288_row8_cpp_probe_arm_matrix_%s.csv", sanitized_run_tag)
)
plan_note_path <- file.path(
  report_dir,
  sprintf("refreshed288_row8_cpp_probe_plan_%s.md", sanitized_run_tag)
)
report_path <- file.path(
  report_dir,
  sprintf("refreshed288_row8_cpp_probe_status_%s.md", sanitized_run_tag)
)

ensure_dir_refreshed288(dirname(report_path))

if (!file.exists(source_manifest_path)) {
  stop(sprintf("source manifest not found: %s", source_manifest_path), call. = FALSE)
}
if (!file.exists(arm_matrix_path)) {
  stop(sprintf("arm matrix not found: %s", arm_matrix_path), call. = FALSE)
}

source_manifest <- utils::read.csv(source_manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
source_manifest$row_id <- as.integer(source_manifest$row_id)
source_row <- source_manifest[source_manifest$row_id == target_row_id, , drop = FALSE]
if (!nrow(source_row)) {
  stop(sprintf("target row %d not found in source manifest", target_row_id), call. = FALSE)
}
source_row <- source_row[1, , drop = FALSE]
source_cfg <- readRDS(source_row$config_path)
arm_matrix <- utils::read.csv(arm_matrix_path, stringsAsFactors = FALSE, check.names = FALSE)
arm_matrix <- arm_matrix[order(arm_matrix$arm_order), , drop = FALSE]

if (dir.exists(paths$run_root)) {
  unlink(paths$run_root, recursive = TRUE, force = TRUE)
}

for (path in c(
  paths$run_root,
  paths$config_dir,
  paths$rows_dir,
  paths$health_dir,
  paths$metrics_dir,
  paths$draws_dir,
  paths$logs_dir,
  file.path(paths$fits_dir, "mcmc"),
  file.path(paths$vb_init_dir, "dynamic"),
  dirname(report_path)
)) {
  ensure_dir_refreshed288(path)
}

base_profiles <- runtime_failure_method_profiles_refreshed288()
base_profile <- base_profiles[["runtime_dynamic__exdqlm__mcmc__primary"]]
if (is.null(base_profile)) {
  stop("missing runtime_dynamic__exdqlm__mcmc__primary profile", call. = FALSE)
}

theta_controls_for_arm <- function(warmup_iters) {
  warmup_iters <- safe_int_refreshed288(warmup_iters, 0L)
  list(
    freeze_burnin_iters = as.integer(max(0L, warmup_iters)),
    freeze_only_during_burn = TRUE,
    force_after_warmup = warmup_iters > 0L
  )
}

latent_controls_for_arm <- function(mode, warmup_iters) {
  warmup_iters <- safe_int_refreshed288(warmup_iters, 0L)
  list(
    mode = safe_chr_refreshed288(mode, "u_st_pair"),
    freeze_burnin_iters = as.integer(max(0L, warmup_iters)),
    freeze_only_during_burn = TRUE,
    force_after_warmup = warmup_iters > 0L
  )
}

sigmagam_controls_for_arm <- function(warmup_iters) {
  warmup_iters <- safe_int_refreshed288(warmup_iters, 0L)
  list(
    freeze_burnin_iters = as.integer(max(0L, warmup_iters)),
    freeze_only_during_burn = TRUE,
    force_after_warmup = warmup_iters > 0L,
    delay_adapt_until_after_warmup = warmup_iters > 0L,
    delay_laplace_refresh_until_after_warmup = warmup_iters > 0L
  )
}

md_table_runtime <- function(df) {
  if (!nrow(df)) return(c("| none |", "|---|"))
  hdr <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  body <- apply(df, 1L, function(x) paste0("| ", paste(as.character(x), collapse = " | "), " |"))
  c(hdr, sep, body)
}

rows <- vector("list", nrow(arm_matrix))
method_profiles <- list()
for (i in seq_len(nrow(arm_matrix))) {
  arm <- arm_matrix[i, , drop = FALSE]
  arm_id <- safe_chr_refreshed288(arm$arm_id[1], sprintf("arm%d", i))
  profile_id <- sprintf("row8_cppprobe__arm_%s", arm_id)
  probe_row_id <- 8000L + safe_int_refreshed288(arm$arm_order[1], i)
  slug <- sprintf("%s_arm%s", case_slug_refreshed288(source_row$original_case_key[1]), tolower(arm_id))

  arm_profile <- utils::modifyList(base_profile, list(
    method_profile_id = profile_id,
    notes = sprintf(
      "row-8 microscope arm %s: backend=%s theta=%s latent=%s sigmagam=%s",
      arm_id,
      safe_chr_refreshed288(arm$mcmc_cpp_mode[1], "strict"),
      safe_int_refreshed288(arm$theta_warmup_iters[1], 0L),
      safe_int_refreshed288(arm$latent_warmup_iters[1], 0L),
      safe_int_refreshed288(arm$sigmagam_mcmc_warmup_iters[1], 0L)
    ),
    mcmc_use_cpp = TRUE,
    mcmc_cpp_mode = safe_chr_refreshed288(arm$mcmc_cpp_mode[1], "strict"),
    theta_state_controls = theta_controls_for_arm(arm$theta_warmup_iters[1]),
    latent_state_controls = latent_controls_for_arm(
      safe_chr_refreshed288(arm$latent_mode[1], "u_st_pair"),
      arm$latent_warmup_iters[1]
    ),
    sigmagam_controls = sigmagam_controls_for_arm(arm$sigmagam_mcmc_warmup_iters[1]),
    n_burn = 600L,
    n_mcmc = 200L,
    thin = 1L,
    trace_diagnostics = TRUE,
    trace_every = 1L
  ))
  method_profiles[[profile_id]] <- arm_profile

  config_path <- file.path(paths$config_dir, sprintf("row_%04d_run_config.rds", probe_row_id))
  fit_path <- file.path(paths$fits_dir, "mcmc", sprintf("row_%04d_%s_fit.rds", probe_row_id, slug))
  vb_init_fit_path <- file.path(paths$vb_init_dir, "dynamic", sprintf("row_%04d_%s_vb_init.rds", probe_row_id, slug))
  row_status_path <- file.path(paths$rows_dir, sprintf("row_%04d_status.csv", probe_row_id))
  health_path <- file.path(paths$health_dir, sprintf("row_%04d_health.csv", probe_row_id))
  metrics_path <- file.path(paths$metrics_dir, sprintf("row_%04d_metrics.csv", probe_row_id))
  draws_path <- file.path(paths$draws_dir, sprintf("row_%04d_draws.rds", probe_row_id))

  cfg <- utils::modifyList(source_cfg, arm_profile)
  cfg$repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  cfg$row_id <- probe_row_id
  cfg$base_row_id <- target_row_id
  cfg$method_profile_id <- profile_id
  cfg$candidate_fit_path <- fit_path
  cfg$vb_init_fit_path <- vb_init_fit_path
  cfg$row_status_path <- row_status_path
  cfg$health_path <- health_path
  cfg$metrics_path <- metrics_path
  cfg$draws_path <- draws_path
  cfg$stored_posterior_draws <- 200L
  cfg$rerun_source_run_tag <- source_run_tag
  cfg$rerun_source_row_id <- target_row_id
  cfg$rerun_arm_id <- arm_id
  cfg$rerun_arm_order <- safe_int_refreshed288(arm$arm_order[1], i)
  cfg$rerun_intended_use <- safe_chr_refreshed288(arm$intended_use[1], NA_character_)
  cfg$retain_candidate_fit_binaries <- TRUE
  cfg$retain_vb_init_binaries <- TRUE
  cfg$retain_draw_binaries <- TRUE
  cfg$cleanup_policy <- "retain_all_binaries_until_manual_review"
  saveRDS(cfg, config_path)

  rows[[i]] <- data.frame(
    row_id = probe_row_id,
    base_row_id = target_row_id,
    original_case_key = source_row$original_case_key[1],
    pair_id = source_row$pair_id[1],
    seed = source_cfg$fit_seed,
    status = "not_started",
    phase = sprintf("arm_%s", arm_id),
    phase_order = safe_int_refreshed288(arm$arm_order[1], i),
    block = source_row$block[1],
    root_kind = source_row$root_kind[1],
    family = source_row$family[1],
    tau = source_row$tau[1],
    tau_label = source_row$tau_label[1],
    fit_size = source_row$fit_size[1],
    prior_semantics = source_row$prior_semantics[1],
    model = source_row$model[1],
    inference = source_row$inference[1],
    source_dataset_id = source_row$source_dataset_id[1],
    method_profile_id = profile_id,
    config_path = config_path,
    run_root = paths$run_root,
    candidate_fit_path = fit_path,
    vb_init_fit_path = vb_init_fit_path,
    row_status_path = row_status_path,
    health_path = health_path,
    metrics_path = metrics_path,
    draws_path = draws_path,
    stored_posterior_draws = 200L,
    source_failed_row_id = target_row_id,
    rerun_arm_id = arm_id,
    rerun_arm_order = safe_int_refreshed288(arm$arm_order[1], i),
    rerun_intended_use = safe_chr_refreshed288(arm$intended_use[1], NA_character_),
    backend_family = safe_chr_refreshed288(arm$backend_family[1], "cpp"),
    mcmc_cpp_mode = safe_chr_refreshed288(arm$mcmc_cpp_mode[1], "strict"),
    theta_warmup_iters = safe_int_refreshed288(arm$theta_warmup_iters[1], 0L),
    latent_mode = safe_chr_refreshed288(arm$latent_mode[1], "u_st_pair"),
    latent_warmup_iters = safe_int_refreshed288(arm$latent_warmup_iters[1], 0L),
    sigmagam_mcmc_warmup_iters = safe_int_refreshed288(arm$sigmagam_mcmc_warmup_iters[1], 0L),
    retain_candidate_fit_binaries = TRUE,
    retain_vb_init_binaries = TRUE,
    retain_draw_binaries = TRUE,
    stringsAsFactors = FALSE
  )
}

probe_manifest <- do.call(rbind, rows)
probe_manifest <- probe_manifest[order(probe_manifest$phase_order, probe_manifest$row_id), , drop = FALSE]
method_registry <- flatten_method_profiles_refreshed288(method_profiles)

stage_counts <- as.data.frame(with(probe_manifest, table(phase)), stringsAsFactors = FALSE)
names(stage_counts) <- c("phase", "rows")
stage_counts$phase_order <- match(stage_counts$phase, unique(probe_manifest$phase))
stage_counts <- stage_counts[order(stage_counts$phase_order), c("phase", "rows"), drop = FALSE]

run_contract <- data.frame(
  run_tag = run_tag_refreshed288(),
  variant_tag = variant_tag_refreshed288(),
  probe_scope = "row8_cpp_only_microscope",
  source_run_tag = source_run_tag,
  source_manifest = source_manifest_path,
  target_row_id = target_row_id,
  target_track = "track_exdqlm_mcmc_tt5000",
  arm_matrix_source = arm_matrix_path,
  arm_matrix_copy = arm_matrix_copy_path,
  arm_count = nrow(arm_matrix),
  backend_family = "cpp_only",
  n_burn = 600L,
  n_mcmc = 200L,
  thin = 1L,
  trace_every = 1L,
  preserve_candidate_fit_binaries = TRUE,
  preserve_vb_init_binaries = TRUE,
  preserve_draw_binaries = TRUE,
  cleanup_policy = "retain_all_binaries_until_manual_review",
  vb_init_max_iter = 800L,
  vb_init_min_iter = 80L,
  vb_init_tol = 0.01,
  vb_init_n_samp = 5000L,
  sts_vb_warmup_iters = 50L,
  sts_vb_min_postwarmup_updates = 5L,
  sigmagam_vb_warmup_iters = 50L,
  sigmagam_vb_min_postwarmup_updates = 5L,
  gig_b_vec_floor = "1e-10",
  confirmatory_row_id = 16L,
  validation_repo_branch = current_git_branch_refreshed288(repo_root),
  validation_repo_sha = current_git_sha_refreshed288(repo_root),
  run_root = paths$run_root,
  manifest_path = manifest_path,
  method_registry_path = method_registry_path,
  report_path = report_path,
  stringsAsFactors = FALSE
)

plan_lines <- c(
  "# Refreshed288 Row-8 C++ Microscope Probe",
  "",
  sprintf("- run tag: `%s`", run_tag_refreshed288()),
  sprintf("- variant tag: `%s`", variant_tag_refreshed288()),
  sprintf("- source canonical run: `%s`", source_run_tag),
  sprintf("- microscope row: `%d`", target_row_id),
  "- backend policy: `C++ only`",
  "- diagnostic horizon: `n.burn = 600`, `n.mcmc = 200`, `thin = 1`, `trace.every = 1`",
  "- promotion rule: choose the minimal winning arm before moving to row `16`",
  "",
  "## Arm Ladder",
  ""
)
plan_lines <- c(
  plan_lines,
  md_table_runtime(arm_matrix[, c(
    "arm_id", "arm_order", "mcmc_cpp_mode", "theta_warmup_iters",
    "latent_mode", "latent_warmup_iters", "sigmagam_mcmc_warmup_iters",
    "intended_use"
  ), drop = FALSE]),
  "",
  "## Fixed Baseline",
  ""
)
baseline_table <- data.frame(
  control = c(
    "VB/VB-init method",
    "VB-init max_iter",
    "VB-init min_iter",
    "VB-init tol",
    "VB-init n.samp",
    "exDQLM s_t VB warmup",
    "VB sigmagam warmup",
    "GIG b_vec floor",
    "binary retention"
  ),
  setting = c(
    "ldvb",
    "800",
    "80",
    "0.01",
    "5000",
    "50, min_postwarmup_updates 5",
    "50, damping 0.5 x 5",
    "1e-10",
    "candidate fit, vb_init, draws"
  ),
  stringsAsFactors = FALSE
)
plan_lines <- c(
  plan_lines,
  md_table_runtime(baseline_table),
  "",
  "## Manifest",
  "",
  md_table_runtime(probe_manifest[, c(
    "row_id", "phase", "rerun_arm_id", "mcmc_cpp_mode",
    "theta_warmup_iters", "latent_warmup_iters",
    "sigmagam_mcmc_warmup_iters", "rerun_intended_use"
  ), drop = FALSE]),
  ""
)

utils::write.csv(method_registry, method_registry_path, row.names = FALSE)
utils::write.csv(probe_manifest, manifest_path, row.names = FALSE)
utils::write.csv(stage_counts[, c("phase", "rows"), drop = FALSE], stage_counts_path, row.names = FALSE)
utils::write.csv(run_contract, run_contract_path, row.names = FALSE)
utils::write.csv(arm_matrix, arm_matrix_copy_path, row.names = FALSE)
writeLines(plan_lines, con = plan_note_path)

cat(sprintf("run_root=%s\n", paths$run_root))
cat(sprintf("manifest=%s\n", manifest_path))
cat(sprintf("method_registry=%s\n", method_registry_path))
cat(sprintf("run_contract=%s\n", run_contract_path))
cat(sprintf("status_out=%s\n", status_path))
cat(sprintf("phase_out=%s\n", phase_path))
cat(sprintf("method_out=%s\n", method_path))
cat(sprintf("report=%s\n", report_path))
cat(sprintf("stage_counts=%s\n", stage_counts_path))
cat(sprintf("plan_note=%s\n", plan_note_path))
cat(sprintf("arm_matrix_copy=%s\n", arm_matrix_copy_path))

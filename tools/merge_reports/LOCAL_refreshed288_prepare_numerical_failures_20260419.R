#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_refreshed288_helpers_20260416.R")

args <- parse_args_refreshed288(commandArgs(trailingOnly = TRUE))
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

run_tag_arg <- safe_chr_refreshed288(
  args$run_tag,
  Sys.getenv("REFRESHED288_RUN_TAG", unset = "20260419_numcrash_thetafreeze_v1")
)
variant_tag_arg <- safe_chr_refreshed288(
  args$variant_tag,
  Sys.getenv("REFRESHED288_VARIANT_TAG", unset = "0p50_ldvb_slice_numcrash_thetafreeze_v1")
)
source_run_tag <- safe_chr_refreshed288(args$source_run_tag, "20260417_canonical_v1")

options(
  refreshed288.run_tag = run_tag_arg,
  refreshed288.variant_tag = variant_tag_arg
)

paths <- paths_refreshed288()
sanitized_run_tag <- sanitize_tag_refreshed288(run_tag_arg, default = run_tag_arg)
report_dir <- file.path("reports", sprintf("static_exal_tuning_%s", report_stamp_refreshed288()))
status_path <- file.path("tools", "merge_reports", sprintf("LOCAL_refreshed288_numerical_runtime_failure_manifest_status_%s.csv", sanitized_run_tag))
phase_path <- file.path("tools", "merge_reports", sprintf("LOCAL_refreshed288_numerical_runtime_failure_phase_summary_%s.csv", sanitized_run_tag))
method_path <- file.path("tools", "merge_reports", sprintf("LOCAL_refreshed288_numerical_runtime_failure_method_summary_%s.csv", sanitized_run_tag))
stage_counts_path <- file.path("tools", "merge_reports", sprintf("LOCAL_refreshed288_numerical_runtime_failure_stage_counts_%s.csv", sanitized_run_tag))
plan_note_path <- file.path(report_dir, sprintf("refreshed288_numerical_runtime_failure_rerun_plan_%s.md", sanitized_run_tag))
report_path <- file.path(report_dir, sprintf("refreshed288_numerical_runtime_failure_status_%s.md", sanitized_run_tag))
source_manifest_path <- file.path(
  "tools",
  "merge_reports",
  sprintf("LOCAL_refreshed288_full_manifest_%s.csv", sanitize_tag_refreshed288(source_run_tag, default = source_run_tag))
)
source_runtime_manifest_path <- file.path(
  "tools",
  "merge_reports",
  "LOCAL_refreshed288_numerical_runtime_failure_manifest_20260419.csv"
)
source_runtime_manifest_copy <- file.path(
  "tools",
  "merge_reports",
  sprintf("LOCAL_refreshed288_numerical_runtime_failure_manifest_source_%s.csv", sanitized_run_tag)
)

ensure_dir_refreshed288(dirname(report_path))

if (!file.exists(source_manifest_path)) {
  stop(sprintf("source manifest not found: %s", source_manifest_path), call. = FALSE)
}
if (!file.exists(source_runtime_manifest_path)) {
  stop(sprintf("numerical runtime manifest not found: %s", source_runtime_manifest_path), call. = FALSE)
}

runtime_fail <- utils::read.csv(source_runtime_manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
source_manifest <- utils::read.csv(source_manifest_path, stringsAsFactors = FALSE, check.names = FALSE)

runtime_fail$row_id <- as.integer(runtime_fail$row_id)
source_manifest$row_id <- as.integer(source_manifest$row_id)

runtime_fail <- runtime_fail[
  runtime_fail$block == "dynamic" &
    runtime_fail$status == "failed_runtime",
  ,
  drop = FALSE
]
runtime_fail <- runtime_fail[order(runtime_fail$row_id), , drop = FALSE]

if (!nrow(runtime_fail)) {
  stop("no numerical runtime-failure rows found in the frozen manifest", call. = FALSE)
}

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
  file.path(paths$fits_dir, "vb"),
  file.path(paths$fits_dir, "mcmc"),
  file.path(paths$vb_init_dir, "dynamic"),
  dirname(report_path)
) ) {
  ensure_dir_refreshed288(path)
}

runtime_profiles <- runtime_failure_method_profiles_refreshed288()
runtime_method_registry <- flatten_method_profiles_refreshed288(runtime_profiles)

classify_runtime_mode_refreshed288 <- function(error_text) {
  error_text <- safe_chr_refreshed288(error_text, "")
  if (grepl("vb_init_validation_fail", error_text, fixed = TRUE)) return("vb_init_validation_fail")
  if (grepl("ldvb_q_t1 is NA", error_text, fixed = TRUE)) return("ldvb_q_t1_na")
  if (grepl("invalid state before chi update", error_text, fixed = TRUE)) return("invalid_pre_chi")
  if (grepl("non-finite values", error_text, fixed = TRUE)) return("nonfinite_chi")
  "other"
}

phase_for_runtime_row <- function(inference, model) {
  if (identical(inference, "vb")) {
    "numerical_vb_primary"
  } else if (identical(model, "exdqlm")) {
    "numerical_exdqlm_mcmc"
  } else {
    "numerical_dqlm_mcmc"
  }
}

phase_order_map <- c(
  numerical_vb_primary = 1L,
  numerical_exdqlm_mcmc = 2L,
  numerical_dqlm_mcmc = 3L
)

rows <- vector("list", nrow(runtime_fail))
for (i in seq_len(nrow(runtime_fail))) {
  fail_row <- runtime_fail[i, , drop = FALSE]
  source_row <- source_manifest[source_manifest$row_id == fail_row$row_id, , drop = FALSE]
  if (!nrow(source_row)) {
    stop(sprintf("source row %s not found in canonical manifest", fail_row$row_id), call. = FALSE)
  }
  source_row <- source_row[1, , drop = FALSE]
  source_cfg <- readRDS(source_row$config_path)

  profile_id <- if (identical(fail_row$inference[1], "vb")) {
    "runtime_dynamic__exdqlm__vb__primary"
  } else if (identical(fail_row$model[1], "dqlm")) {
    "runtime_dynamic__dqlm__mcmc__primary"
  } else {
    "runtime_dynamic__exdqlm__mcmc__primary"
  }
  profile <- runtime_profiles[[profile_id]]
  if (is.null(profile)) {
    stop(sprintf("missing runtime profile for row %s", fail_row$row_id), call. = FALSE)
  }

  slug <- case_slug_refreshed288(source_row$original_case_key[1])
  fit_path <- file.path(paths$fits_dir, fail_row$inference[1], sprintf("row_%04d_%s_fit.rds", fail_row$row_id[1], slug))
  vb_init_fit_path <- if (identical(fail_row$inference[1], "mcmc")) {
    file.path(paths$vb_init_dir, "dynamic", sprintf("row_%04d_%s_vb_init.rds", fail_row$row_id[1], slug))
  } else {
    NA_character_
  }
  config_path <- file.path(paths$config_dir, sprintf("row_%04d_run_config.rds", fail_row$row_id[1]))
  row_status_path <- file.path(paths$rows_dir, sprintf("row_%04d_status.csv", fail_row$row_id[1]))
  health_path <- file.path(paths$health_dir, sprintf("row_%04d_health.csv", fail_row$row_id[1]))
  metrics_path <- file.path(paths$metrics_dir, sprintf("row_%04d_metrics.csv", fail_row$row_id[1]))
  draws_path <- file.path(paths$draws_dir, sprintf("row_%04d_draws.rds", fail_row$row_id[1]))

  cfg <- utils::modifyList(source_cfg, profile)
  cfg$repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  cfg$row_id <- fail_row$row_id[1]
  cfg$base_row_id <- fail_row$row_id[1]
  cfg$method_profile_id <- profile_id
  cfg$candidate_fit_path <- fit_path
  cfg$vb_init_fit_path <- vb_init_fit_path
  cfg$row_status_path <- row_status_path
  cfg$health_path <- health_path
  cfg$metrics_path <- metrics_path
  cfg$draws_path <- draws_path
  cfg$stored_posterior_draws <- safe_int_refreshed288(profile$stored_posterior_draws, source_cfg$stored_posterior_draws %||% 20000L)
  cfg$rerun_source_run_tag <- source_run_tag
  cfg$rerun_source_row_id <- fail_row$row_id[1]
  cfg$rerun_source_runtime_mode <- classify_runtime_mode_refreshed288(fail_row$error[1])
  cfg$rerun_source_error <- fail_row$error[1]
  cfg$runtime_failure_rerun_arm <- "thetafreeze_primary"
  cfg$retain_candidate_fit_binaries <- TRUE
  cfg$retain_vb_init_binaries <- TRUE
  cfg$retain_draw_binaries <- TRUE
  cfg$cleanup_policy <- "retain_all_binaries_until_manual_review"
  saveRDS(cfg, config_path)

  phase <- phase_for_runtime_row(fail_row$inference[1], fail_row$model[1])
  rows[[i]] <- data.frame(
    row_id = fail_row$row_id[1],
    base_row_id = fail_row$row_id[1],
    original_case_key = source_row$original_case_key[1],
    pair_id = source_row$pair_id[1],
    seed = source_cfg$fit_seed,
    status = "not_started",
    phase = phase,
    phase_order = unname(phase_order_map[phase]),
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
    stored_posterior_draws = safe_int_refreshed288(profile$stored_posterior_draws, 20000L),
    source_failed_row_id = fail_row$row_id[1],
    source_runtime_mode = classify_runtime_mode_refreshed288(fail_row$error[1]),
    source_error = fail_row$error[1],
    runtime_failure_rerun_arm = "thetafreeze_primary",
    retain_candidate_fit_binaries = TRUE,
    retain_vb_init_binaries = TRUE,
    retain_draw_binaries = TRUE,
    stringsAsFactors = FALSE
  )
}

runtime_manifest <- do.call(rbind, rows)
runtime_manifest <- runtime_manifest[order(runtime_manifest$phase_order, runtime_manifest$row_id), , drop = FALSE]
stage_counts <- as.data.frame(with(runtime_manifest, table(phase)), stringsAsFactors = FALSE)
names(stage_counts) <- c("phase", "rows")
stage_counts$phase_order <- unname(phase_order_map[stage_counts$phase])
stage_counts <- stage_counts[order(stage_counts$phase_order), c("phase", "rows"), drop = FALSE]

run_contract <- data.frame(
  run_tag = run_tag_refreshed288(),
  variant_tag = variant_tag_refreshed288(),
  rerun_scope = "numerical_runtime_failures_only",
  source_run_tag = source_run_tag,
  source_manifest = source_manifest_path,
  source_runtime_manifest = source_runtime_manifest_path,
  source_runtime_manifest_copy = source_runtime_manifest_copy,
  total_runtime_rows = nrow(runtime_manifest),
  direct_vb_rows = sum(runtime_manifest$phase == "numerical_vb_primary"),
  exdqlm_mcmc_rows = sum(runtime_manifest$phase == "numerical_exdqlm_mcmc"),
  dqlm_mcmc_rows = sum(runtime_manifest$phase == "numerical_dqlm_mcmc"),
  numerical_runtime_fail_rows_canonical = nrow(runtime_fail),
  static_gate_fail_rows_excluded = 27L,
  preserve_candidate_fit_binaries = TRUE,
  preserve_vb_init_binaries = TRUE,
  preserve_draw_binaries = TRUE,
  cleanup_policy = "retain_all_binaries_until_manual_review",
  sts_vb_warmup_iters = 50L,
  sts_vb_min_postwarmup_updates = 5L,
  sigmagam_vb_warmup_iters = 50L,
  sigmagam_mcmc_warmup_iters = 500L,
  theta_state_warmup_iters = 100L,
  latent_state_warmup_iters = 100L,
  dqlm_sigma_warmup_iters = 500L,
  mcmc_use_cpp = FALSE,
  mcmc_cpp_mode = "strict",
  validation_repo_branch = current_git_branch_refreshed288(repo_root),
  validation_repo_sha = current_git_sha_refreshed288(repo_root),
  run_root = paths$run_root,
  manifest_path = paths$full_manifest,
  method_registry_path = paths$method_registry,
  report_path = report_path,
  stringsAsFactors = FALSE
)

md_table_runtime <- function(df) {
  if (!nrow(df)) return(c("| none |", "|---|"))
  hdr <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  body <- apply(df, 1L, function(x) paste0("| ", paste(as.character(x), collapse = " | "), " |"))
  c(hdr, sep, body)
}

plan_lines <- c(
  "# Refreshed288 Numerical Runtime-Failure Relaunch",
  "",
  sprintf("- run tag: `%s`", run_tag_refreshed288()),
  sprintf("- variant tag: `%s`", variant_tag_refreshed288()),
  sprintf("- source canonical run: `%s`", source_run_tag),
  sprintf("- rerun scope: `%d` frozen numerical/runtime crash rows only", nrow(runtime_manifest)),
  "- excluded rows: `27` static MCMC gate/mixing failures",
  "- exdqlm init change: explicit `s_t` warmup/freeze in LDVB init path",
  "- binary retention policy: keep candidate fit, vb-init, and draws `.rds` for manual review",
  "",
  "## Phase Plan",
  ""
)
plan_lines <- c(plan_lines, md_table_runtime(stage_counts[, c("phase", "rows"), drop = FALSE]), "", "## Method Highlights", "")
method_highlights <- data.frame(
  lever = c(
    "exdqlm VB / VB-init",
    "exdqlm MCMC",
    "dqlm MCMC",
    "retention"
  ),
  setting = c(
    "s_t warmup 50, min_postwarmup_updates 5, sigmagam warmup 50",
    "VB init max_iter 800 / min_iter 80 / n.samp 5000; latent pair warmup 100; sigmagam warmup 500",
    "VB init max_iter 800 / min_iter 80 / n.samp 5000; U_t warmup 100; sigma warmup 500",
    "preserve all fit / vb_init / draws binaries until manual cleanup"
  ),
  stringsAsFactors = FALSE
)
plan_lines <- c(plan_lines, md_table_runtime(method_highlights), "", "## Row Allocation", "")
plan_lines <- c(
  plan_lines,
  md_table_runtime(runtime_manifest[, c("row_id", "phase", "family", "tau_label", "fit_size", "model", "inference", "source_runtime_mode"), drop = FALSE]),
  ""
)

utils::write.csv(runtime_method_registry, paths$method_registry, row.names = FALSE)
utils::write.csv(runtime_manifest, paths$full_manifest, row.names = FALSE)
utils::write.csv(stage_counts[, c("phase", "rows"), drop = FALSE], stage_counts_path, row.names = FALSE)
utils::write.csv(run_contract, paths$run_contract, row.names = FALSE)
utils::write.csv(runtime_fail, source_runtime_manifest_copy, row.names = FALSE)
writeLines(plan_lines, con = plan_note_path)

cat(sprintf("run_root=%s\n", paths$run_root))
cat(sprintf("manifest=%s\n", paths$full_manifest))
cat(sprintf("method_registry=%s\n", paths$method_registry))
cat(sprintf("run_contract=%s\n", paths$run_contract))
cat(sprintf("status_out=%s\n", status_path))
cat(sprintf("phase_out=%s\n", phase_path))
cat(sprintf("method_out=%s\n", method_path))
cat(sprintf("report=%s\n", report_path))
cat(sprintf("stage_counts=%s\n", stage_counts_path))
cat(sprintf("plan_note=%s\n", plan_note_path))
cat(sprintf("source_runtime_manifest_copy=%s\n", source_runtime_manifest_copy))

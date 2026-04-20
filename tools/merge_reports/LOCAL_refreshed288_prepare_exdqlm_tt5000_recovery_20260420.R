#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_refreshed288_helpers_20260416.R")

args <- parse_args_refreshed288(commandArgs(trailingOnly = TRUE))
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

run_tag_arg <- safe_chr_refreshed288(
  args$run_tag,
  Sys.getenv("REFRESHED288_RUN_TAG", unset = "20260420_exdqlm_tt5000_recovery_v1")
)
variant_tag_arg <- safe_chr_refreshed288(
  args$variant_tag,
  Sys.getenv("REFRESHED288_VARIANT_TAG", unset = "exdqlm_tt5000_recovery_v1")
)
source_run_tag <- safe_chr_refreshed288(args$source_run_tag, "20260417_canonical_v1")

options(
  refreshed288.run_tag = run_tag_arg,
  refreshed288.variant_tag = variant_tag_arg
)

paths <- paths_refreshed288()
sanitized_run_tag <- sanitize_tag_refreshed288(run_tag_arg, default = run_tag_arg)
report_dir <- file.path("reports", sprintf("static_exal_tuning_%s", report_stamp_refreshed288()))
manifest_path <- file.path(
  "tools", "merge_reports",
  sprintf("LOCAL_refreshed288_exdqlm_tt5000_recovery_manifest_%s.csv", sanitized_run_tag)
)
method_registry_path <- file.path(
  "tools", "merge_reports",
  sprintf("LOCAL_refreshed288_exdqlm_tt5000_recovery_method_registry_%s.csv", sanitized_run_tag)
)
status_path <- file.path(
  "tools", "merge_reports",
  sprintf("LOCAL_refreshed288_exdqlm_tt5000_recovery_manifest_status_%s.csv", sanitized_run_tag)
)
phase_path <- file.path(
  "tools", "merge_reports",
  sprintf("LOCAL_refreshed288_exdqlm_tt5000_recovery_phase_summary_%s.csv", sanitized_run_tag)
)
method_path <- file.path(
  "tools", "merge_reports",
  sprintf("LOCAL_refreshed288_exdqlm_tt5000_recovery_method_summary_%s.csv", sanitized_run_tag)
)
stage_counts_path <- file.path(
  "tools", "merge_reports",
  sprintf("LOCAL_refreshed288_exdqlm_tt5000_recovery_stage_counts_%s.csv", sanitized_run_tag)
)
run_contract_path <- file.path(
  "tools", "merge_reports",
  sprintf("LOCAL_refreshed288_exdqlm_tt5000_recovery_run_contract_%s.csv", sanitized_run_tag)
)
report_path <- file.path(
  report_dir,
  sprintf("refreshed288_exdqlm_tt5000_recovery_status_%s.md", sanitized_run_tag)
)
plan_note_path <- file.path(
  report_dir,
  sprintf("refreshed288_exdqlm_tt5000_recovery_plan_%s.md", sanitized_run_tag)
)
source_manifest_path <- file.path(
  "tools", "merge_reports",
  sprintf("LOCAL_refreshed288_full_manifest_%s.csv", sanitize_tag_refreshed288(source_run_tag, default = source_run_tag))
)
source_runtime_manifest_path <- file.path(
  "tools", "merge_reports",
  "LOCAL_refreshed288_numerical_runtime_failure_manifest_20260419.csv"
)
source_runtime_manifest_copy <- file.path(
  "tools", "merge_reports",
  sprintf("LOCAL_refreshed288_exdqlm_tt5000_recovery_source_runtime_manifest_%s.csv", sanitized_run_tag)
)
probe_manifest_path <- file.path(
  "tools", "merge_reports",
  "LOCAL_refreshed288_row8_cpp_probe_manifest_20260419_row8_cppprobe_v1.csv"
)

ensure_dir_refreshed288(dirname(report_path))

if (!file.exists(source_manifest_path)) stop(sprintf("source manifest not found: %s", source_manifest_path), call. = FALSE)
if (!file.exists(source_runtime_manifest_path)) stop(sprintf("runtime manifest not found: %s", source_runtime_manifest_path), call. = FALSE)
if (!file.exists(probe_manifest_path)) stop(sprintf("probe manifest not found: %s", probe_manifest_path), call. = FALSE)

source_manifest <- utils::read.csv(source_manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
runtime_manifest <- utils::read.csv(source_runtime_manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
probe_manifest <- utils::read.csv(probe_manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
source_manifest$row_id <- as.integer(source_manifest$row_id)
runtime_manifest$row_id <- as.integer(runtime_manifest$row_id)
probe_manifest$row_id <- as.integer(probe_manifest$row_id)

runtime_exdqlm_tt5000 <- runtime_manifest[
  runtime_manifest$model == "exdqlm" &
    runtime_manifest$inference == "mcmc" &
    runtime_manifest$fit_size == 5000 &
    runtime_manifest$status == "failed_runtime",
  ,
  drop = FALSE
]
runtime_exdqlm_tt5000 <- runtime_exdqlm_tt5000[order(runtime_exdqlm_tt5000$row_id), , drop = FALSE]

expected_rows <- c(8L, 16L, 24L, 32L, 40L, 48L, 56L, 64L, 72L)
if (!identical(runtime_exdqlm_tt5000$row_id, expected_rows)) {
  stop("unexpected exdqlm TT5000 runtime cohort; expected rows 8,16,24,32,40,48,56,64,72", call. = FALSE)
}

if (dir.exists(paths$run_root)) unlink(paths$run_root, recursive = TRUE, force = TRUE)
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

theta_controls_prod <- function(iters) {
  list(
    freeze_burnin_iters = as.integer(iters),
    freeze_only_during_burn = TRUE,
    force_after_warmup = as.integer(iters) > 0L
  )
}

latent_controls_prod <- function(iters) {
  list(
    mode = "u_st_pair",
    freeze_burnin_iters = as.integer(iters),
    freeze_only_during_burn = TRUE,
    force_after_warmup = as.integer(iters) > 0L
  )
}

sigmagam_controls_prod <- function(iters) {
  list(
    freeze_burnin_iters = as.integer(iters),
    freeze_only_during_burn = TRUE,
    force_after_warmup = as.integer(iters) > 0L,
    delay_adapt_until_after_warmup = as.integer(iters) > 0L,
    delay_laplace_refresh_until_after_warmup = as.integer(iters) > 0L
  )
}

base_profiles <- runtime_failure_method_profiles_refreshed288()
base_profile <- base_profiles[["runtime_dynamic__exdqlm__mcmc__primary"]]
if (is.null(base_profile)) stop("missing runtime_dynamic__exdqlm__mcmc__primary profile", call. = FALSE)

profile_arm_B <- utils::modifyList(base_profile, list(
  method_profile_id = "exdqlm_tt5000_recovery__arm_B_prod",
  notes = "Production-budget confirmatory strict-only arm promoted from the row-8 microscope result",
  theta_state_controls = theta_controls_prod(0L),
  latent_state_controls = latent_controls_prod(0L),
  sigmagam_controls = sigmagam_controls_prod(0L),
  mcmc_use_cpp = TRUE,
  mcmc_cpp_mode = "strict",
  n_burn = 5000L,
  n_mcmc = 20000L,
  thin = 1L,
  trace_diagnostics = TRUE,
  trace_every = 50L
))

profile_arm_D <- utils::modifyList(base_profile, list(
  method_profile_id = "exdqlm_tt5000_recovery__arm_D_prod",
  notes = "Production-budget strict + theta100 + latent100 arm promoted from the winning row-8 microscope result",
  theta_state_controls = theta_controls_prod(100L),
  latent_state_controls = latent_controls_prod(100L),
  sigmagam_controls = sigmagam_controls_prod(0L),
  mcmc_use_cpp = TRUE,
  mcmc_cpp_mode = "strict",
  n_burn = 5000L,
  n_mcmc = 20000L,
  thin = 1L,
  trace_diagnostics = TRUE,
  trace_every = 50L
))

profiles <- list(
  exdqlm_tt5000_recovery__arm_B_prod = profile_arm_B,
  exdqlm_tt5000_recovery__arm_D_prod = profile_arm_D
)

plan_rows <- data.frame(
  row_id = c(8L, 16L, 16L, 24L, 32L, 40L, 48L, 56L, 64L, 72L),
  phase = c(
    "confirm_row8_arm_D",
    "confirm_row16_arm_B",
    "confirm_row16_arm_D",
    rep("spread_remaining_arm_D", 7L)
  ),
  phase_order = c(1L, 2L, 3L, rep(4L, 7L)),
  method_profile_id = c(
    "exdqlm_tt5000_recovery__arm_D_prod",
    "exdqlm_tt5000_recovery__arm_B_prod",
    "exdqlm_tt5000_recovery__arm_D_prod",
    rep("exdqlm_tt5000_recovery__arm_D_prod", 7L)
  ),
  plan_role = c(
    "fullconfirm_row8_d",
    "confirmatory_row16_b",
    "confirmatory_row16_d",
    rep("spread_remaining_d", 7L)
  ),
  stringsAsFactors = FALSE
)

md_table_runtime <- function(df) {
  if (!nrow(df)) return(c("| none |", "|---|"))
  hdr <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  body <- apply(df, 1L, function(x) paste0("| ", paste(as.character(x), collapse = " | "), " |"))
  c(hdr, sep, body)
}

rows <- vector("list", nrow(plan_rows))
for (i in seq_len(nrow(plan_rows))) {
  plan_row <- plan_rows[i, , drop = FALSE]
  source_row <- source_manifest[source_manifest$row_id == plan_row$row_id, , drop = FALSE]
  if (!nrow(source_row)) stop(sprintf("source row %s not found", plan_row$row_id), call. = FALSE)
  source_row <- source_row[1, , drop = FALSE]
  source_cfg <- readRDS(source_row$config_path)
  profile <- profiles[[plan_row$method_profile_id[1]]]
  if (is.null(profile)) stop(sprintf("missing profile %s", plan_row$method_profile_id[1]), call. = FALSE)

  relaunch_row_id <- 9200L + i
  suffix <- switch(
    plan_row$plan_role[1],
    fullconfirm_row8_d = "row8_armd",
    confirmatory_row16_b = "row16_armb",
    confirmatory_row16_d = "row16_armd",
    sprintf("row%s_armd", plan_row$row_id[1])
  )
  slug <- sprintf("%s_%s", case_slug_refreshed288(source_row$original_case_key[1]), suffix)

  config_path <- file.path(paths$config_dir, sprintf("row_%04d_run_config.rds", relaunch_row_id))
  fit_path <- file.path(paths$fits_dir, "mcmc", sprintf("row_%04d_%s_fit.rds", relaunch_row_id, slug))
  vb_init_fit_path <- file.path(paths$vb_init_dir, "dynamic", sprintf("row_%04d_%s_vb_init.rds", relaunch_row_id, slug))
  row_status_path <- file.path(paths$rows_dir, sprintf("row_%04d_status.csv", relaunch_row_id))
  health_path <- file.path(paths$health_dir, sprintf("row_%04d_health.csv", relaunch_row_id))
  metrics_path <- file.path(paths$metrics_dir, sprintf("row_%04d_metrics.csv", relaunch_row_id))
  draws_path <- file.path(paths$draws_dir, sprintf("row_%04d_draws.rds", relaunch_row_id))

  cfg <- utils::modifyList(source_cfg, profile)
  cfg$repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  cfg$row_id <- relaunch_row_id
  cfg$base_row_id <- as.integer(plan_row$row_id[1])
  cfg$method_profile_id <- plan_row$method_profile_id[1]
  cfg$candidate_fit_path <- fit_path
  cfg$vb_init_fit_path <- vb_init_fit_path
  cfg$row_status_path <- row_status_path
  cfg$health_path <- health_path
  cfg$metrics_path <- metrics_path
  cfg$draws_path <- draws_path
  cfg$rerun_source_run_tag <- source_run_tag
  cfg$rerun_source_row_id <- as.integer(plan_row$row_id[1])
  cfg$rerun_plan_role <- plan_row$plan_role[1]
  cfg$retain_candidate_fit_binaries <- TRUE
  cfg$retain_vb_init_binaries <- TRUE
  cfg$retain_draw_binaries <- TRUE
  cfg$cleanup_policy <- "retain_all_binaries_until_manual_review"
  saveRDS(cfg, config_path)

  source_fail <- runtime_exdqlm_tt5000[runtime_exdqlm_tt5000$row_id == plan_row$row_id[1], , drop = FALSE]
  rows[[i]] <- data.frame(
    row_id = relaunch_row_id,
    base_row_id = as.integer(plan_row$row_id[1]),
    original_case_key = source_row$original_case_key[1],
    pair_id = source_row$pair_id[1],
    seed = source_cfg$fit_seed,
    status = "not_started",
    phase = plan_row$phase[1],
    phase_order = as.integer(plan_row$phase_order[1]),
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
    method_profile_id = plan_row$method_profile_id[1],
    config_path = config_path,
    run_root = paths$run_root,
    candidate_fit_path = fit_path,
    vb_init_fit_path = vb_init_fit_path,
    row_status_path = row_status_path,
    health_path = health_path,
    metrics_path = metrics_path,
    draws_path = draws_path,
    stored_posterior_draws = safe_int_refreshed288(profile$stored_posterior_draws, 20000L),
    source_failed_row_id = as.integer(plan_row$row_id[1]),
    source_runtime_mode = safe_chr_refreshed288(source_fail$error[1], NA_character_),
    plan_role = plan_row$plan_role[1],
    retain_candidate_fit_binaries = TRUE,
    retain_vb_init_binaries = TRUE,
    retain_draw_binaries = TRUE,
    stringsAsFactors = FALSE
  )
}

recovery_manifest <- do.call(rbind, rows)
recovery_manifest <- recovery_manifest[order(recovery_manifest$phase_order, recovery_manifest$row_id), , drop = FALSE]
method_registry <- flatten_method_profiles_refreshed288(profiles)
stage_counts <- as.data.frame(with(recovery_manifest, table(phase)), stringsAsFactors = FALSE)
names(stage_counts) <- c("phase", "rows")
stage_counts$phase_order <- match(stage_counts$phase, unique(recovery_manifest$phase))
stage_counts <- stage_counts[order(stage_counts$phase_order), c("phase", "rows"), drop = FALSE]

run_contract <- data.frame(
  run_tag = run_tag_refreshed288(),
  variant_tag = variant_tag_refreshed288(),
  relaunch_scope = "exdqlm_tt5000_staged_recovery_only",
  source_run_tag = source_run_tag,
  source_manifest = source_manifest_path,
  source_runtime_manifest = source_runtime_manifest_path,
  source_runtime_manifest_copy = source_runtime_manifest_copy,
  track = "track_exdqlm_mcmc_tt5000",
  total_rows = nrow(recovery_manifest),
  confirmatory_rows = 3L,
  spread_rows = 7L,
  excluded_dqlm_tt5000_rows = 9L,
  excluded_init_blocked_rows = 2L,
  mcmc_use_cpp = TRUE,
  mcmc_cpp_mode = "strict",
  promoted_primary_arm = "D",
  fallback_arm = "B",
  promoted_theta_warmup_iters = 100L,
  promoted_latent_warmup_iters = 100L,
  promoted_sigmagam_warmup_iters = 0L,
  n_burn = 5000L,
  n_mcmc = 20000L,
  thin = 1L,
  trace_every = 50L,
  preserve_candidate_fit_binaries = TRUE,
  preserve_vb_init_binaries = TRUE,
  preserve_draw_binaries = TRUE,
  cleanup_policy = "retain_all_binaries_until_manual_review",
  validation_repo_branch = current_git_branch_refreshed288(repo_root),
  validation_repo_sha = current_git_sha_refreshed288(repo_root),
  run_root = paths$run_root,
  manifest_path = manifest_path,
  method_registry_path = method_registry_path,
  report_path = report_path,
  stringsAsFactors = FALSE
)

plan_lines <- c(
  "# Refreshed288 exDQLM TT5000 Recovery Program",
  "",
  sprintf("- run tag: `%s`", run_tag_refreshed288()),
  sprintf("- variant tag: `%s`", variant_tag_refreshed288()),
  sprintf("- source canonical run: `%s`", source_run_tag),
  "- scope: `exdqlm` dynamic MCMC TT5000 failures only",
  "- promoted arm from microscope: `D = strict + theta100 + latent100 + sigmagam0`",
  "- fallback arm retained for confirmation: `B = strict only`",
  "- excluded for now: all `dqlm` TT5000 crash rows and init-blocked exdqlm rows `11,12`",
  "- important correction: the row-8 PASS was at diagnostic horizon only, so production-budget confirmation is still required before broad rollout is trusted",
  "",
  "## Pattern Diagnosis",
  "",
  "- the promoted track is coherent because all nine target rows came from the same `exdqlm / dynamic / mcmc / TT5000` crash family",
  "- their original canonical failure surface was the same early `chi / pre_latent` numerical crash class",
  "- the microscope showed that backend mode matters materially: `C++ strict` was necessary while `C++ fast` remained unacceptable",
  "- the microscope also showed that `theta` warmup alone was not enough, but `theta + latent` together was sufficient to promote a production candidate",
  "- heavier `sigmagam` warmup regressed on the microscope row and is therefore intentionally excluded from the promoted recipe",
  "",
  "## Phase Plan",
  ""
)
plan_lines <- c(plan_lines, md_table_runtime(stage_counts[, c("phase", "rows"), drop = FALSE]), "", "## Row Allocation", "")
plan_lines <- c(plan_lines, md_table_runtime(recovery_manifest[, c("row_id", "base_row_id", "phase", "plan_role", "family", "tau_label", "method_profile_id"), drop = FALSE]), "")
plan_lines <- c(
  plan_lines,
  "## Promotion Rules",
  "",
  "1. `row 8 / arm D` must remain acceptable at production budget before the spread phase is trusted.",
  "2. `row 16 / arm D` must be at least as good as `row 16 / arm B`; otherwise the fallback debate remains open.",
  "3. The remaining seven exdqlm TT5000 rows only inherit `arm D` after both confirmatory checks stay acceptable.",
  "4. This relaunch does not reopen the `dqlm` TT5000 or init-blocked `11,12` tracks.",
  ""
)

utils::write.csv(method_registry, method_registry_path, row.names = FALSE)
utils::write.csv(recovery_manifest, manifest_path, row.names = FALSE)
utils::write.csv(stage_counts[, c("phase", "rows"), drop = FALSE], stage_counts_path, row.names = FALSE)
utils::write.csv(run_contract, run_contract_path, row.names = FALSE)
utils::write.csv(runtime_exdqlm_tt5000, source_runtime_manifest_copy, row.names = FALSE)
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
cat(sprintf("source_runtime_manifest_copy=%s\n", source_runtime_manifest_copy))

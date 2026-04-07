source("tools/merge_reports/LOCAL_original288_syncedbase_faithful_replay_helpers_20260407.R")

run_tag_original288_syncedbase_residual_repair <- function() {
  "original288_syncedbase_residual_repair_20260407"
}

variant_tag_original288_syncedbase_residual_repair <- function() {
  "orig288_sync0p4p0_residual_20260407"
}

phase_order_original288_syncedbase_residual_repair <- c(
  phase1_static_al_mcmc_bugfix = 1L,
  phase2_static_exal_mcmc_exact = 2L,
  phase3_dynamic_exdqlm_mcmc_exact = 3L
)

paths_original288_syncedbase_residual_repair <- function() {
  tag <- run_tag_original288_syncedbase_residual_repair()
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", tag))
  list(
    accepted_selection = "tools/merge_reports/LOCAL_original288_carryforward_selection_v5_20260407.csv",
    source_status = "tools/merge_reports/LOCAL_original288_syncedbase_faithful_replay_manifest_status_20260407.csv",
    fail_inventory = "tools/merge_reports/LOCAL_original288_syncedbase_residual_fail_inventory_20260407.csv",
    manifest = "tools/merge_reports/LOCAL_original288_syncedbase_residual_manifest_20260407.csv",
    stage_counts = "tools/merge_reports/LOCAL_original288_syncedbase_residual_stage_counts_20260407.csv",
    manifest_status = "tools/merge_reports/LOCAL_original288_syncedbase_residual_manifest_status_20260407.csv",
    phase_summary = "tools/merge_reports/LOCAL_original288_syncedbase_residual_phase_summary_20260407.csv",
    block_summary = "tools/merge_reports/LOCAL_original288_syncedbase_residual_block_summary_20260407.csv",
    accepted_compare = "tools/merge_reports/LOCAL_original288_syncedbase_residual_accepted_compare_20260407.csv",
    config_dir = file.path(run_dir, "configs"),
    program_doc = "reports/static_exal_tuning_20260407/original_288_syncedbase_residual_repair_program_20260407.md",
    execution_doc = "reports/static_exal_tuning_20260407/original_288_syncedbase_residual_repair_execution_20260407.md"
  )
}

expected_phase_original288_syncedbase_residual_repair <- function(block, model, inference) {
  stopifnot(identical(inference, "mcmc"))
  if (block %in% c("static_paper", "static_shrink") && identical(model, "al")) {
    return("phase1_static_al_mcmc_bugfix")
  }
  if (block %in% c("static_paper", "static_shrink") && identical(model, "exal")) {
    return("phase2_static_exal_mcmc_exact")
  }
  if (identical(block, "dynamic") && identical(model, "exdqlm")) {
    return("phase3_dynamic_exdqlm_mcmc_exact")
  }
  stop(sprintf("Unexpected residual lane for block=%s model=%s inference=%s", block, model, inference))
}

candidate_fit_path_original288_syncedbase_residual_repair <- function(run_root, inference, model, tau_label) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    inference,
    sprintf("%s_%s_tau_%s_fit_%s.rds", inference, model, tau_label, variant_tag_original288_syncedbase_residual_repair())
  ))
}

vb_candidate_fit_path_original288_syncedbase_residual_repair <- function(run_root, model, tau_label) {
  candidate_fit_path_original288_syncedbase_residual_repair(run_root, "vb", model, tau_label)
}

config_path_original288_syncedbase_residual_repair <- function(row_id) {
  file.path(
    paths_original288_syncedbase_residual_repair()$config_dir,
    sprintf("row_%04d_run_config.rds", as.integer(row_id))
  )
}

read_failed_source_status_original288_syncedbase_residual_repair <- function() {
  x <- read.csv(
    paths_original288_syncedbase_residual_repair()$source_status,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  x <- subset(
    x,
    state %in% c("done", "failed_runtime", "skipped_existing", "input_missing") &
      gate_current == "FAIL" &
      inference == "mcmc" &
      (
        (block %in% c("static_paper", "static_shrink") & model %in% c("al", "exal")) |
          (block == "dynamic" & model == "exdqlm")
      )
  )
  x$phase <- mapply(
    expected_phase_original288_syncedbase_residual_repair,
    x$block,
    x$model,
    x$inference,
    USE.NAMES = FALSE
  )
  x$phase_order <- unname(phase_order_original288_syncedbase_residual_repair[x$phase])
  x <- x[order(
    x$phase_order,
    x$block,
    x$family,
    x$tau_label,
    x$fit_size,
    x$prior_override,
    x$model
  ), , drop = FALSE]
  rownames(x) <- NULL
  x
}

read_original288_syncedbase_residual_repair_status <- function(manifest_path = paths_original288_syncedbase_residual_repair()$manifest,
                                                               run_tag = run_tag_original288_syncedbase_residual_repair()) {
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

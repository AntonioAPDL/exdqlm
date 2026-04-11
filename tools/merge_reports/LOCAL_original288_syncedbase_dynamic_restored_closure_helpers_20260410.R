source("tools/merge_reports/LOCAL_original288_syncedbase_faithful_replay_helpers_20260407.R")
source("tools/merge_reports/LOCAL_original288_syncedbase_dynamic_final_closure_helpers_20260410.R")

predecessor_repo_root_original288_syncedbase_dynamic_restored_closure <- function() {
  "/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs"
}

integration_repo_root_original288_syncedbase_dynamic_restored_closure <- function() {
  "/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration"
}

qdesn_repo_root_original288_syncedbase_dynamic_restored_closure <- function() {
  "/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration"
}

qdesn_materialized_root_original288_syncedbase_dynamic_restored_closure <- function() {
  file.path(
    qdesn_repo_root_original288_syncedbase_dynamic_restored_closure(),
    "results",
    "qdesn_mcmc_validation",
    "dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_sources",
    "dlm_constV_smallW"
  )
}

run_tag_original288_syncedbase_dynamic_restored_closure <- function() {
  "original288_syncedbase_dynamic_restored_closure_20260410"
}

variant_tag_original288_syncedbase_dynamic_restored_closure <- function() {
  "orig288_sync0p4p0_dynamic_restored_closure_20260410"
}

phase_order_original288_syncedbase_dynamic_restored_closure <- c(
  phase1_dynamic_reinforcement = 1L,
  phase2_dynamic_broad_repair = 2L
)

paths_original288_syncedbase_dynamic_restored_closure <- function() {
  tag <- run_tag_original288_syncedbase_dynamic_restored_closure()
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", tag))
  list(
    accepted_selection = "tools/merge_reports/LOCAL_original288_carryforward_selection_v8_20260410.csv",
    closure_status = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_manifest_status_20260407.csv",
    tail6_refine_status = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_refine_manifest_status_20260407.csv",
    tail6_localmix_status = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_manifest_status_20260408.csv",
    queue = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_queue_20260410.csv",
    deferred = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_deferred_inventory_20260410.csv",
    schedule = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_schedule_20260410.csv",
    manifest = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_manifest_20260410.csv",
    stage_counts = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_stage_counts_20260410.csv",
    manifest_status = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_manifest_status_20260410.csv",
    phase_summary = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_phase_summary_20260410.csv",
    block_summary = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_block_summary_20260410.csv",
    accepted_compare = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_accepted_compare_20260410.csv",
    source_audit = "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_source_audit_20260410.csv",
    config_dir = file.path(run_dir, "configs"),
    baseline_dir = file.path(run_dir, "synthetic_baselines"),
    restored_source_dir = file.path(run_dir, "restored_sources"),
    program_doc = "reports/static_exal_tuning_20260410/original_288_syncedbase_dynamic_restored_closure_program_20260410.md",
    execution_doc = "reports/static_exal_tuning_20260410/original_288_syncedbase_dynamic_restored_closure_execution_20260410.md"
  )
}

candidate_fit_path_original288_syncedbase_dynamic_restored_closure <- function(run_root, inference, model, tau_label, candidate_label) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    inference,
    sprintf(
      "%s_%s_tau_%s_fit_%s_%s.rds",
      inference,
      model,
      tau_label,
      variant_tag_original288_syncedbase_dynamic_restored_closure(),
      candidate_label
    )
  ))
}

vb_candidate_fit_path_original288_syncedbase_dynamic_restored_closure <- function(run_root, model, tau_label, candidate_label) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    "vb",
    sprintf(
      "vb_%s_tau_%s_fit_%s_%s.rds",
      model,
      tau_label,
      variant_tag_original288_syncedbase_dynamic_restored_closure(),
      candidate_label
    )
  ))
}

config_path_original288_syncedbase_dynamic_restored_closure <- function(row_id) {
  file.path(
    paths_original288_syncedbase_dynamic_restored_closure()$config_dir,
    sprintf("row_%04d_run_config.rds", as.integer(row_id))
  )
}

synthetic_baseline_path_original288_syncedbase_dynamic_restored_closure <- function(target_row_id) {
  file.path(
    paths_original288_syncedbase_dynamic_restored_closure()$baseline_dir,
    sprintf("row_%04d_synthetic_baseline.rds", as.integer(target_row_id))
  )
}

restored_sim_output_path_original288_syncedbase_dynamic_restored_closure <- function(target_row_id) {
  file.path(
    paths_original288_syncedbase_dynamic_restored_closure()$restored_source_dir,
    sprintf("row_%04d_sim_output_restored.rds", as.integer(target_row_id))
  )
}

current_run_root_original288_syncedbase_dynamic_restored_closure <- function(source_run_root) {
  normalize_path_original288(sub(
    predecessor_repo_root_original288_syncedbase_dynamic_restored_closure(),
    integration_repo_root_original288_syncedbase_dynamic_restored_closure(),
    source_run_root,
    fixed = TRUE
  ))
}

materialized_window_spec_original288_syncedbase_dynamic_restored_closure <- function(fit_size) {
  fit_size <- as.integer(fit_size)[1]
  if (identical(fit_size, 500L)) {
    return(list(source_total_size = 813L, dir_name = "fit_input_effTT500_totalTT813"))
  }
  if (identical(fit_size, 5000L)) {
    return(list(source_total_size = 5313L, dir_name = "fit_input_effTT5000_totalTT5313"))
  }
  stop(sprintf("Unsupported dynamic fit_size for restored closure: %s", fit_size))
}

materialized_source_dir_original288_syncedbase_dynamic_restored_closure <- function(family, tau_label, fit_size) {
  spec <- materialized_window_spec_original288_syncedbase_dynamic_restored_closure(fit_size)
  normalize_path_original288(file.path(
    qdesn_materialized_root_original288_syncedbase_dynamic_restored_closure(),
    family,
    sprintf("tau_%s", tau_label),
    spec$dir_name
  ))
}

dynamic_source_run_root_original288_syncedbase_dynamic_restored_closure <- function(source_path) {
  normalize_path_original288(dirname(dirname(source_path)))
}

dynamic_source_fit_input_dir_original288_syncedbase_dynamic_restored_closure <- function(source_run_root) {
  normalize_path_original288(dirname(source_run_root))
}

accepted_dynamic_tail_source_original288_syncedbase_dynamic_restored_closure <- function() {
  carry <- read.csv(
    paths_original288_syncedbase_dynamic_restored_closure()$accepted_selection,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  x <- subset(
    carry,
    block == "dynamic" &
      model == "exdqlm" &
      inference == "mcmc" &
      gate_overall == "FAIL"
  )
  if (!nrow(x)) return(x)

  x$row_id <- match(x$original_case_key, carry$original_case_key)
  x$tau_label <- x$tau
  x$accepted_gate <- x$gate_overall
  x$accepted_healthy <- x$healthy
  x$gate_current <- x$gate_overall
  x$accepted_compare <- "accepted_tail_fail"
  x$source_run_root <- vapply(
    x$source_path,
    dynamic_source_run_root_original288_syncedbase_dynamic_restored_closure,
    character(1)
  )
  x$run_root <- vapply(
    x$source_run_root,
    current_run_root_original288_syncedbase_dynamic_restored_closure,
    character(1)
  )
  x$source_fit_input_dir <- vapply(
    x$source_run_root,
    dynamic_source_fit_input_dir_original288_syncedbase_dynamic_restored_closure,
    character(1)
  )
  x$source_series_wide_path <- normalize_path_original288(file.path(x$source_fit_input_dir, "series_wide.csv"))
  x$source_selection_indices_path <- normalize_path_original288(file.path(x$source_fit_input_dir, "selection_indices.csv"))
  x$source_true_quantile_grid_path <- normalize_path_original288(file.path(x$source_fit_input_dir, "true_quantile_grid.csv"))
  x$materialized_source_dir <- mapply(
    materialized_source_dir_original288_syncedbase_dynamic_restored_closure,
    x$family,
    x$tau_label,
    x$fit_size,
    USE.NAMES = FALSE
  )
  x$materialized_sim_output_path <- normalize_path_original288(file.path(x$materialized_source_dir, "sim_output.rds"))
  x$materialized_series_wide_path <- normalize_path_original288(file.path(x$materialized_source_dir, "series_wide.csv"))
  x$materialized_selection_indices_path <- normalize_path_original288(file.path(x$materialized_source_dir, "selection_indices.csv"))
  x$queue_group <- "accepted_unresolved_tail"
  x$in_scope <- TRUE
  x
}

read_status_file_original288_syncedbase_dynamic_restored_closure <- function(path, queue_group) {
  if (!file.exists(path)) return(data.frame())
  x <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  x <- x[x$status_row == "done", , drop = FALSE]
  if (!nrow(x)) return(x)
  x$queue_group <- queue_group
  x$in_scope <- FALSE
  x
}

read_prior_dynamic_attempt_status_original288_syncedbase_dynamic_restored_closure <- function() {
  paths <- paths_original288_syncedbase_dynamic_restored_closure()
  rbind_fill_original288_syncedbase_rerun(list(
    read_status_file_original288_syncedbase_dynamic_restored_closure(
      paths$closure_status,
      "screened_dynamic_closure_attempt"
    ),
    read_status_file_original288_syncedbase_dynamic_restored_closure(
      paths$tail6_refine_status,
      "screened_dynamic_tail6_refine_attempt"
    ),
    read_status_file_original288_syncedbase_dynamic_restored_closure(
      paths$tail6_localmix_status,
      "screened_dynamic_tail6_localmix_attempt"
    )
  ))
}

read_source_status_original288_syncedbase_dynamic_restored_closure <- function() {
  tail <- accepted_dynamic_tail_source_original288_syncedbase_dynamic_restored_closure()
  keep_cols <- c(
    "row_id", "block", "root_kind", "family", "tau", "tau_label", "fit_size",
    "prior_semantics", "model", "inference", "method", "root_id",
    "original_scenario_key", "original_case_key", "baseline_signoff_path",
    "baseline_fit_path", "selected_source_type", "selected_source_subtype",
    "selected_candidate", "selected_variant_tag", "selected_fit_path",
    "selected_health_path", "selected_summary_path", "source_path",
    "gate_current", "accepted_gate", "accepted_healthy", "accepted_compare",
    "selection_mode", "selection_reason", "runtime_sec", "run_root",
    "source_run_root", "source_fit_input_dir", "source_series_wide_path",
    "source_selection_indices_path", "source_true_quantile_grid_path",
    "materialized_source_dir", "materialized_sim_output_path",
    "materialized_series_wide_path", "materialized_selection_indices_path",
    "queue_group", "in_scope"
  )
  for (nm in keep_cols) {
    if (!nm %in% names(tail)) tail[[nm]] <- NA
  }
  x <- tail[, keep_cols, drop = FALSE]
  x <- x[order(
    factor(x$queue_group, levels = c("accepted_unresolved_tail")),
    x$family,
    x$tau_label,
    x$fit_size
  ), , drop = FALSE]
  rownames(x) <- NULL
  x
}

read_deferred_inventory_original288_syncedbase_dynamic_restored_closure <- function() {
  read_prior_dynamic_attempt_status_original288_syncedbase_dynamic_restored_closure()
}

build_dlm_constV_smallW_model_original288_syncedbase_dynamic_restored_closure <- function(period = 50L, no_trend = TRUE) {
  period <- as.numeric(period)[1]
  stopifnot(is.finite(period), period > 2)
  lam1 <- 2 * pi / period
  lam2 <- 2 * lam1

  G_trend <- if (isTRUE(no_trend)) diag(2) else matrix(c(1, 1, 0, 1), 2, 2, byrow = TRUE)
  R1 <- matrix(c(cos(lam1), sin(lam1), -sin(lam1), cos(lam1)), 2, 2, byrow = TRUE)
  R2 <- matrix(c(cos(lam2), sin(lam2), -sin(lam2), cos(lam2)), 2, 2, byrow = TRUE)
  GG <- matrix(0, 6, 6)
  GG[1:2, 1:2] <- G_trend
  GG[3:4, 3:4] <- R1
  GG[5:6, 5:6] <- R2
  structure(
    list(
      m0 = matrix(0, nrow = 6, ncol = 1),
      C0 = diag(25, 6),
      GG = GG,
      FF = matrix(c(1, 0, 1, 0, 1, 0), nrow = 6, ncol = 1)
    ),
    class = "exdqlm"
  )
}

extract_dynamic_seed_original288_syncedbase_dynamic_restored_closure <- function(status_path, default = 202604060L) {
  if (!file.exists(status_path)) return(as.integer(default))
  lines <- readLines(status_path, warn = FALSE)
  seed_line <- grep("seed=", lines, value = TRUE)
  if (!length(seed_line)) return(as.integer(default))
  seed <- suppressWarnings(as.integer(sub(".*seed=([0-9]+).*", "\\1", seed_line[1])))
  if (is.finite(seed)) seed else as.integer(default)
}

extract_dynamic_df_original288_syncedbase_dynamic_restored_closure <- function(status_path, default = 0.98) {
  if (!file.exists(status_path)) return(as.numeric(default))
  lines <- readLines(status_path, warn = FALSE)
  hit <- grep("df=", lines, value = TRUE)
  if (!length(hit)) return(as.numeric(default))
  df <- suppressWarnings(as.numeric(sub(".*df=([0-9.]+).*", "\\1", hit[1])))
  if (is.finite(df)) df else as.numeric(default)
}

dynamic_baseline_context_original288_syncedbase_dynamic_restored_closure <- function(target_row) {
  fit_size <- as.integer(target_row$fit_size)[1]
  tau_chr <- safe_chr_original288_syncedbase_rerun(target_row$tau, NA_character_)
  tau_label <- safe_chr_original288_syncedbase_rerun(target_row$tau_label, NA_character_)
  tau_num <- suppressWarnings(as.numeric(gsub("p", ".", ifelse(is.na(tau_chr), tau_label, tau_chr), fixed = TRUE)))
  if (!is.finite(tau_num)) {
    tau_num <- suppressWarnings(as.numeric(gsub("p", ".", tau_label, fixed = TRUE)))
  }
  if (!is.finite(tau_num)) {
    stop(sprintf("Unable to parse tau for %s", target_row$original_case_key))
  }
  source_run_root <- safe_chr_original288_syncedbase_rerun(target_row$source_run_root, NA_character_)
  status_path <- normalize_path_original288(file.path(source_run_root, "logs", sprintf("exdqlm_tau_%s.status.tsv", tau_label)))
  diag_path <- normalize_path_original288(file.path(source_run_root, "tables", "mcmc_diagnostics_summary.csv"))
  diag_df <- read.csv(diag_path, stringsAsFactors = FALSE, check.names = FALSE)
  diag_row <- subset(diag_df, model == "exdqlm" & abs(as.numeric(tau) - tau_num) < 1e-12)
  if (nrow(diag_row) != 1L) {
    stop(sprintf("Expected one exdqlm diagnostics row for %s", target_row$original_case_key))
  }
  materialized_sim <- readRDS(target_row$materialized_sim_output_path)
  period <- materialized_sim$info$params$period %||% 50L
  list(
    period = as.integer(period)[1],
    fit_size = fit_size,
    tau = tau_num,
    seed = extract_dynamic_seed_original288_syncedbase_dynamic_restored_closure(status_path),
    df = extract_dynamic_df_original288_syncedbase_dynamic_restored_closure(status_path),
    diag_row = diag_row[1, , drop = FALSE]
  )
}

restore_dynamic_sim_output_original288_syncedbase_dynamic_restored_closure <- function(target_row, out_path) {
  mat_sim <- readRDS(target_row$materialized_sim_output_path)
  orig_series <- read.csv(target_row$source_series_wide_path, stringsAsFactors = FALSE, check.names = FALSE)
  orig_sel <- read.csv(target_row$source_selection_indices_path, stringsAsFactors = FALSE, check.names = FALSE)
  n_target <- as.integer(target_row$fit_size)[1]
  idx <- seq.int(length(mat_sim$y) - n_target + 1L, length(mat_sim$y))

  restored <- list(
    y = as.numeric(mat_sim$y[idx]),
    q = as.matrix(mat_sim$q[idx, , drop = FALSE]),
    p = mat_sim$p,
    info = mat_sim$info,
    extras = mat_sim$extras %||% list()
  )

  params <- restored$info$params %||% list()
  params$TT <- n_target
  params$TT_effective <- n_target
  params$washout <- 0L
  if ("t" %in% names(orig_series)) {
    params$TT_warmup <- as.integer(orig_series$t[1]) - 1L
  }
  restored$info$params <- params
  restored$info$subsample <- list(
    source_root = dirname(target_row$source_fit_input_dir),
    source_n = if ("source_index" %in% names(orig_sel)) max(as.integer(orig_sel$source_index)) else NA_integer_,
    target_n = n_target,
    effective_target_n = n_target,
    washout = 0L,
    selection_method = "last_T",
    sorted_by = "time"
  )

  source_index <- if ("source_index" %in% names(orig_sel) && nrow(orig_sel) == n_target) {
    as.integer(orig_sel$source_index)
  } else if ("t" %in% names(orig_series)) {
    as.integer(orig_series$t)
  } else {
    idx
  }
  restored$extras$source_index <- source_index
  restored$extras$materialized_for <- "original288_dynamic_restored_closure"

  if (length(restored$y) != nrow(orig_series)) {
    stop(sprintf("Restored dynamic y length mismatch for %s", target_row$original_case_key))
  }
  same_y <- isTRUE(all.equal(as.numeric(orig_series$y), restored$y, tolerance = 1e-8))
  if (!same_y) {
    stop(sprintf("Restored dynamic y mismatch for %s", target_row$original_case_key))
  }
  if ("q_target" %in% names(orig_series)) {
    same_q <- isTRUE(all.equal(as.numeric(orig_series$q_target), as.numeric(restored$q[, 1]), tolerance = 1e-8))
    if (!same_q) {
      stop(sprintf("Restored dynamic q_target mismatch for %s", target_row$original_case_key))
    }
  }

  ensure_dir_original288_syncedbase_rerun(dirname(out_path))
  saveRDS(restored, out_path)
  out_path
}

write_dynamic_synthetic_baseline_original288_syncedbase_dynamic_restored_closure <- function(target_row, out_path) {
  ctx <- dynamic_baseline_context_original288_syncedbase_dynamic_restored_closure(target_row)
  d <- ctx$diag_row
  baseline <- list(
    seed = ctx$seed,
    p0 = ctx$tau,
    model = build_dlm_constV_smallW_model_original288_syncedbase_dynamic_restored_closure(period = ctx$period, no_trend = TRUE),
    df = c(ctx$df, ctx$df),
    dim.df = c(2L, 4L),
    n.burn = 2000L,
    n.mcmc = 1000L,
    init.from.vb = TRUE,
    vb.init.method = "ldvb",
    mh.diagnostics = list(
      proposal = as.character(d$mh_proposal[1]),
      joint_sample = as.logical(d$mh_joint_sample[1]),
      adapt = as.logical(d$mh_adapt[1]),
      trace_every = 50L,
      scale_final = suppressWarnings(as.numeric(d$mh_scale_final[1])),
      accept = list(keep = suppressWarnings(as.numeric(d$accept_rate_keep[1])))
    )
  )
  ensure_dir_original288_syncedbase_rerun(dirname(out_path))
  saveRDS(baseline, out_path)
  out_path
}

base_dynamic_config_original288_syncedbase_dynamic_restored_closure <- function(target_row) {
  ctx <- dynamic_baseline_context_original288_syncedbase_dynamic_restored_closure(target_row)
  d <- ctx$diag_row
  list(
    vb = list(
      method = "ldvb",
      tol = 0.1,
      n_samp = 1000L,
      max_iter = 300L
    ),
    mcmc = list(
      burn = 2000L,
      n = 1000L,
      init_from_vb = TRUE,
      init_from_isvb = FALSE,
      mh = list(
        proposal = as.character(d$mh_proposal[1]),
        primary_proposal = as.character(d$mh_proposal[1]),
        joint_sample = as.logical(d$mh_joint_sample[1]),
        primary_joint_sample = as.logical(d$mh_joint_sample[1]),
        adapt = as.logical(d$mh_adapt[1]),
        adapt_interval = 50L,
        target_accept = c(0.20, 0.45),
        scale_bounds = c(0.1, 10),
        max_scale_step = 0.35,
        min_burn_adapt = 50L,
        trace_every = 50L
      )
    )
  )
}

schedule_spec_original288_syncedbase_dynamic_restored_closure <- function() {
  schedule_spec_original288_syncedbase_dynamic_final_closure()
}

apply_overrides_original288_syncedbase_dynamic_restored_closure <- function(cfg, spec_row) {
  apply_overrides_original288_syncedbase_dynamic_final_closure(cfg, spec_row)
}

read_original288_syncedbase_dynamic_restored_closure_status <- function(
    manifest_path = paths_original288_syncedbase_dynamic_restored_closure()$manifest,
    run_tag = run_tag_original288_syncedbase_dynamic_restored_closure()) {
  read_original288_syncedbase_rerun_status(manifest_path = manifest_path, run_tag = run_tag)
}

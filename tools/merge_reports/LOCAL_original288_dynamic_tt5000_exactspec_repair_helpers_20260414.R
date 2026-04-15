source("tools/merge_reports/LOCAL_original288_exactspec_multiseed_helpers_20260412.R")

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

run_tag_original288_dynamic_tt5000_exactspec_repair <- function() {
  "original288_dynamic_tt5000_exactspec_repair_20260414"
}

variant_tag_original288_dynamic_tt5000_exactspec_repair <- function() {
  "orig288_dynamic_tt5000_exactspec_repair_20260414"
}

phase_order_original288_dynamic_tt5000_exactspec_repair <- c(
  phase1_dynamic_tt5000_exact_replay = 1L,
  phase2_dynamic_tt5000_historical_repair = 2L
)

ensure_dir_original288_dynamic_tt5000_exactspec_repair <- function(path) {
  ensure_dir_original288_exactspec_multiseed(path)
}

safe_chr_original288_dynamic_tt5000_exactspec_repair <- function(x, default = NA_character_) {
  safe_chr_original288_exactspec_multiseed(x, default = default)
}

safe_num_original288_dynamic_tt5000_exactspec_repair <- function(x, default = NA_real_) {
  safe_num_original288_exactspec_multiseed(x, default = default)
}

safe_int_original288_dynamic_tt5000_exactspec_repair <- function(x, default = NA_integer_) {
  safe_int_original288_exactspec_multiseed(x, default = default)
}

as_flag_original288_dynamic_tt5000_exactspec_repair <- function(x, default = FALSE) {
  as_flag_original288_exactspec_multiseed(x, default = default)
}

gate_rank_original288_dynamic_tt5000_exactspec_repair <- function(x) {
  gate_rank_original288_exactspec_multiseed(x)
}

resolve_existing_path_original288_dynamic_tt5000_exactspec_repair <- function(path) {
  resolve_existing_path_original288_exactspec_multiseed(path)
}

map_to_current_repo_root_original288_dynamic_tt5000_exactspec_repair <- function(path) {
  map_to_current_repo_root_original288_exactspec_multiseed(path)
}

path_key_original288_dynamic_tt5000_exactspec_repair <- function(path) {
  raw <- safe_chr_original288_dynamic_tt5000_exactspec_repair(path, NA_character_)
  if (is.na(raw)) return(NA_character_)
  normalizePath(raw, winslash = "/", mustWork = FALSE)
}

hash_seed_original288_dynamic_tt5000_exactspec_repair <- function(key) {
  hash_seed_original288_exactspec_multiseed(key)
}

seed_vector_original288_dynamic_tt5000_exactspec_repair <- function(base_seed) {
  seed_vector_original288_exactspec_multiseed(base_seed)
}

select_draw_indices_original288_dynamic_tt5000_exactspec_repair <- function(n_available,
                                                                             n_target,
                                                                             seed) {
  select_draw_indices_original288_exactspec_multiseed(
    n_available = n_available,
    n_target = n_target,
    seed = seed
  )
}

dynamic_metrics_original288_dynamic_tt5000_exactspec_repair <- function(row, sim_obj, draw_mat) {
  dynamic_metrics_original288_exactspec_multiseed(row = row, sim_obj = sim_obj, draw_mat = draw_mat)
}

paths_original288_dynamic_tt5000_exactspec_repair <- function() {
  tag <- run_tag_original288_dynamic_tt5000_exactspec_repair()
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", tag))
  list(
    current_selection = "tools/merge_reports/LOCAL_original288_comparison_selection_exactspec_multiseed_v1_20260412.csv",
    baseline_selection = "tools/merge_reports/LOCAL_original288_comparison_selection_rhsns_v1_20260411.csv",
    candidate_pool = "tools/merge_reports/LOCAL_original288_candidate_pool_v1_20260405.csv",
    phase1_source_audit = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_phase1_source_audit_20260414.csv",
    phase2_candidate_inventory = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_phase2_candidate_inventory_20260414.csv",
    phase1_manifest = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_phase1_manifest_20260414.csv",
    phase2_manifest = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_phase2_manifest_20260414.csv",
    full_manifest = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_full_manifest_20260414.csv",
    phase1_stage_counts = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_phase1_stage_counts_20260414.csv",
    phase2_stage_counts = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_phase2_stage_counts_20260414.csv",
    phase1_manifest_status = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_phase1_manifest_status_20260414.csv",
    phase2_manifest_status = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_phase2_manifest_status_20260414.csv",
    full_manifest_status = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_full_manifest_status_20260414.csv",
    phase1_phase_summary = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_phase1_phase_summary_20260414.csv",
    phase2_phase_summary = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_phase2_phase_summary_20260414.csv",
    full_phase_summary = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_full_phase_summary_20260414.csv",
    full_seed_ranking = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_full_seed_ranking_20260414.csv",
    full_selected = "tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_full_selected_20260414.csv",
    repaired_selection = "tools/merge_reports/LOCAL_original288_comparison_selection_exactspec_multiseed_dynamic_tt5000_repair_v1_20260414.csv",
    repaired_selection_summary = "tools/merge_reports/LOCAL_original288_comparison_selection_exactspec_multiseed_dynamic_tt5000_repair_summary_v1_20260414.csv",
    comparison_output_dir = "tools/merge_reports/original288_tablebacked_comparison_exactspec_dynamic_tt5000_repair_20260414",
    comparison_report = "reports/static_exal_tuning_20260414/original288_tablebacked_cluster_comparison_exactspec_dynamic_tt5000_repair_20260414.md",
    plan_doc = "reports/static_exal_tuning_20260414/original288_dynamic_tt5000_exactspec_repair_plan_20260414.md",
    program_doc = "reports/static_exal_tuning_20260414/original288_dynamic_tt5000_exactspec_repair_program_20260414.md",
    execution_doc = "reports/static_exal_tuning_20260414/original288_dynamic_tt5000_exactspec_repair_execution_20260414.md",
    run_root = run_dir,
    config_dir = file.path(run_dir, "configs"),
    rows_dir = file.path(run_dir, "rows"),
    health_dir = file.path(run_dir, "health"),
    metrics_dir = file.path(run_dir, "metrics"),
    draws_dir = file.path(run_dir, "draws"),
    logs_dir = file.path(run_dir, "logs")
  )
}

row_status_path_original288_dynamic_tt5000_exactspec_repair <- function(row_id) {
  file.path(
    paths_original288_dynamic_tt5000_exactspec_repair()$rows_dir,
    sprintf("row_%04d.csv", as.integer(row_id))
  )
}

health_path_original288_dynamic_tt5000_exactspec_repair <- function(row_id) {
  file.path(
    paths_original288_dynamic_tt5000_exactspec_repair()$health_dir,
    sprintf("health_%04d.csv", as.integer(row_id))
  )
}

metrics_path_original288_dynamic_tt5000_exactspec_repair <- function(row_id) {
  file.path(
    paths_original288_dynamic_tt5000_exactspec_repair()$metrics_dir,
    sprintf("metrics_%04d.csv", as.integer(row_id))
  )
}

draws_path_original288_dynamic_tt5000_exactspec_repair <- function(row_id) {
  file.path(
    paths_original288_dynamic_tt5000_exactspec_repair()$draws_dir,
    sprintf("draws_%04d.rds", as.integer(row_id))
  )
}

config_path_original288_dynamic_tt5000_exactspec_repair <- function(row_id) {
  file.path(
    paths_original288_dynamic_tt5000_exactspec_repair()$config_dir,
    sprintf("row_%04d_run_config.rds", as.integer(row_id))
  )
}

candidate_fit_path_original288_dynamic_tt5000_exactspec_repair <- function(run_root,
                                                                            inference,
                                                                            model,
                                                                            tau_label,
                                                                            candidate_label,
                                                                            seed_slot) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    inference,
    sprintf(
      "%s_%s_tau_%s_fit_%s_%s_seed%02d.rds",
      inference,
      model,
      tau_label,
      variant_tag_original288_dynamic_tt5000_exactspec_repair(),
      candidate_label,
      as.integer(seed_slot)
    )
  ))
}

sanitize_candidate_label_original288_dynamic_tt5000_exactspec_repair <- function(x) {
  gsub("[^A-Za-z0-9]+", "_", safe_chr_original288_dynamic_tt5000_exactspec_repair(x, "candidate"), perl = TRUE)
}

read_current_selection_targets_original288_dynamic_tt5000_exactspec_repair <- function() {
  x <- read.csv(
    paths_original288_dynamic_tt5000_exactspec_repair()$current_selection,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  x$base_row_id <- seq_len(nrow(x))
  x <- subset(
    x,
    block == "dynamic" &
      fit_size == 5000 &
      gate_overall == "FAIL"
  )
  x <- x[order(x$family, x$tau, x$model, x$inference), , drop = FALSE]
  rownames(x) <- NULL
  x
}

read_baseline_selection_original288_dynamic_tt5000_exactspec_repair <- function() {
  read.csv(
    paths_original288_dynamic_tt5000_exactspec_repair()$baseline_selection,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

baseline_dynamic_vb_lookup_original288_dynamic_tt5000_exactspec_repair <- function(baseline_selection) {
  vb <- subset(baseline_selection, block == "dynamic" & inference == "vb")
  vb[, c("original_scenario_key", "model", "selected_fit_path"), drop = FALSE]
}

phase1_source_registry_original288_dynamic_tt5000_exactspec_repair <- function() {
  faithful <- read.csv(
    "tools/merge_reports/LOCAL_original288_syncedbase_faithful_replay_manifest_status_20260407.csv",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  faithful$source_registry_source <- "faithful_replay_20260407"

  rerun <- read.csv(
    "tools/merge_reports/LOCAL_original288_syncedbase_rerun_manifest_status_20260406.csv",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  rerun$source_registry_source <- "syncedbase_rerun_20260406"

  keep_cols <- c(
    "original_case_key",
    "source_selected_fit_path",
    "candidate_fit_path",
    "run_config_path",
    "sim_output_path",
    "run_root",
    "source_run_root",
    "source_run_config_path",
    "vb_reference_fit_path",
    "seed",
    "source_registry_source"
  )

  for (nm in keep_cols) {
    if (!nm %in% names(faithful)) faithful[[nm]] <- NA
    if (!nm %in% names(rerun)) rerun[[nm]] <- NA
  }

  faithful <- faithful[, keep_cols, drop = FALSE]
  rerun <- rerun[, keep_cols, drop = FALSE]
  out <- rbind(faithful, rerun)
  out$source_selected_fit_path_key <- vapply(
    out$source_selected_fit_path,
    path_key_original288_dynamic_tt5000_exactspec_repair,
    character(1)
  )
  out$candidate_fit_path_resolved <- vapply(
    out$candidate_fit_path,
    resolve_existing_path_original288_dynamic_tt5000_exactspec_repair,
    character(1)
  )
  out$candidate_fit_path_key <- vapply(
    out$candidate_fit_path,
    path_key_original288_dynamic_tt5000_exactspec_repair,
    character(1)
  )
  out$run_config_path <- vapply(
    out$run_config_path,
    resolve_existing_path_original288_dynamic_tt5000_exactspec_repair,
    character(1)
  )
  out$sim_output_path <- vapply(
    out$sim_output_path,
    resolve_existing_path_original288_dynamic_tt5000_exactspec_repair,
    character(1)
  )
  out$run_root <- vapply(
    out$run_root,
    map_to_current_repo_root_original288_dynamic_tt5000_exactspec_repair,
    character(1)
  )
  out$source_run_root <- vapply(
    out$source_run_root,
    resolve_existing_path_original288_dynamic_tt5000_exactspec_repair,
    character(1)
  )
  out$source_run_config_path <- vapply(
    out$source_run_config_path,
    resolve_existing_path_original288_dynamic_tt5000_exactspec_repair,
    character(1)
  )
  out$vb_reference_fit_path <- vapply(
    out$vb_reference_fit_path,
    resolve_existing_path_original288_dynamic_tt5000_exactspec_repair,
    character(1)
  )
  out
}

resolve_phase1_source_row_original288_dynamic_tt5000_exactspec_repair <- function(target_row,
                                                                                   baseline_row,
                                                                                   registry = phase1_source_registry_original288_dynamic_tt5000_exactspec_repair()) {
  fit_path <- path_key_original288_dynamic_tt5000_exactspec_repair(baseline_row$selected_fit_path)
  hit <- registry[
    registry$candidate_fit_path_key == fit_path |
      registry$source_selected_fit_path_key == fit_path,
    ,
    drop = FALSE
  ]
  if (!nrow(hit)) {
    stop(sprintf(
      "No exact phase1 source match for %s",
      baseline_row$original_case_key
    ))
  }
  hit$order_rank <- match(hit$source_registry_source, c("faithful_replay_20260407", "syncedbase_rerun_20260406"))
  hit <- hit[order(hit$order_rank, hit$run_config_path), , drop = FALSE]
  chosen <- hit[1, , drop = FALSE]
  chosen$base_row_id <- target_row$base_row_id
  chosen$current_gate <- target_row$gate_overall
  chosen$current_selected_fit_path <- target_row$selected_fit_path
  chosen$current_selected_variant_tag <- target_row$selected_variant_tag
  chosen$baseline_selected_fit_path <- baseline_row$selected_fit_path
  chosen$baseline_selected_variant_tag <- baseline_row$selected_variant_tag
  chosen$reference_fit_path <- if (!is.na(chosen$candidate_fit_path_resolved[1]) && nzchar(chosen$candidate_fit_path_resolved[1])) {
    chosen$candidate_fit_path_resolved[1]
  } else {
    resolve_existing_path_original288_dynamic_tt5000_exactspec_repair(baseline_row$selected_fit_path)
  }
  if ((is.na(chosen$sim_output_path[1]) || !nzchar(chosen$sim_output_path[1])) && file.exists(chosen$run_config_path[1])) {
    cfg <- readRDS(chosen$run_config_path[1])
    chosen$sim_output_path[1] <- resolve_existing_path_original288_dynamic_tt5000_exactspec_repair(cfg$sim_path)
  }
  chosen
}

derive_dynamic_case_key_original288_dynamic_tt5000_exactspec_repair <- function(model,
                                                                                 family,
                                                                                 tau,
                                                                                 fit_size,
                                                                                 prior_semantics = "default",
                                                                                 inference = "mcmc") {
  tau_label <- safe_chr_original288_dynamic_tt5000_exactspec_repair(tau, "0p50")
  tau_label <- gsub("\\.", "p", tau_label, fixed = TRUE)
  if (!grepl("p", tau_label, fixed = TRUE)) {
    tau_label <- gsub("^0\\.", "0p", tau_label)
  }
  sprintf(
    "dynamic::%s::%s::%s::%s::%s::%s",
    safe_chr_original288_dynamic_tt5000_exactspec_repair(family, "unknown"),
    tau_label,
    as.integer(safe_int_original288_dynamic_tt5000_exactspec_repair(fit_size, NA_integer_)),
    safe_chr_original288_dynamic_tt5000_exactspec_repair(prior_semantics, "default"),
    safe_chr_original288_dynamic_tt5000_exactspec_repair(model, "unknown"),
    safe_chr_original288_dynamic_tt5000_exactspec_repair(inference, "mcmc")
  )
}

extract_historical_control_part_original288_dynamic_tt5000_exactspec_repair <- function(path) {
  df <- tryCatch(read.csv(path, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) NULL)
  if (is.null(df) || !nrow(df)) return(NULL)

  bn <- basename(path)
  out <- NULL

  if (grepl("^LOCAL_dynamic_matrix_manifest_.*\\.csv$", bn) || identical(bn, "LOCAL_dynamic_row15_wave8_matrix_20260405.csv")) {
    out <- data.frame(
      csv_path = path,
      source_kind = "matrix_manifest",
      variant_tag = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$variant_tag, NA_character_),
      model = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$model, NA_character_),
      family = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$family, NA_character_),
      fit_size = safe_int_original288_dynamic_tt5000_exactspec_repair(df$tt %||% df$fit_size, NA_integer_),
      tau_label = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$tau, NA_character_),
      prior_semantics = "default",
      inference = "mcmc",
      candidate_path = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$candidate_path, NA_character_),
      health_path = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$case_health_csv %||% df$health_csv, NA_character_),
      source_seed = safe_int_original288_dynamic_tt5000_exactspec_repair(df$seed, NA_integer_),
      mh_proposal = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$mh_proposal, NA_character_),
      mh_adapt = if ("mh_adapt" %in% names(df)) as.logical(df$mh_adapt) else NA,
      laplace_refresh_interval = safe_int_original288_dynamic_tt5000_exactspec_repair(df$laplace_refresh_interval, NA_integer_),
      laplace_refresh_start = safe_int_original288_dynamic_tt5000_exactspec_repair(df$laplace_refresh_start, NA_integer_),
      laplace_refresh_weight = safe_num_original288_dynamic_tt5000_exactspec_repair(df$laplace_refresh_weight, NA_real_),
      slice_width = safe_num_original288_dynamic_tt5000_exactspec_repair(df$slice_width, NA_real_),
      slice_max_steps = safe_int_original288_dynamic_tt5000_exactspec_repair(df$slice_max_steps, NA_integer_),
      n_burn = safe_int_original288_dynamic_tt5000_exactspec_repair(df$n_burn, NA_integer_),
      n_mcmc = safe_int_original288_dynamic_tt5000_exactspec_repair(df$n_mcmc, NA_integer_),
      trace_every = safe_int_original288_dynamic_tt5000_exactspec_repair(df$trace_every, NA_integer_),
      progress_every = safe_int_original288_dynamic_tt5000_exactspec_repair(df$progress_every, NA_integer_),
      init_from_vb_requested = NA,
      init_from_vb = NA,
      vb_path = NA_character_,
      baseline_fit_path = NA_character_,
      run_config_path = NA_character_,
      stringsAsFactors = FALSE
    )
  } else if (grepl("^LOCAL_targeted_manifest_dynamic_tail.*\\.csv$", bn)) {
    out <- data.frame(
      csv_path = path,
      source_kind = "targeted_manifest",
      variant_tag = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$prepared_tag %||% df$variant_tag, NA_character_),
      model = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$model, NA_character_),
      family = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$family, NA_character_),
      fit_size = safe_int_original288_dynamic_tt5000_exactspec_repair(df$fit_size %||% df$tt, NA_integer_),
      tau_label = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$tau_label %||% df$tau, NA_character_),
      prior_semantics = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$prior_override %||% df$prior, "default"),
      inference = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$inference, "mcmc"),
      candidate_path = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$candidate_fit_path %||% df$candidate_path, NA_character_),
      health_path = NA_character_,
      source_seed = safe_int_original288_dynamic_tt5000_exactspec_repair(df$seed, NA_integer_),
      mh_proposal = NA_character_,
      mh_adapt = NA,
      laplace_refresh_interval = NA_integer_,
      laplace_refresh_start = NA_integer_,
      laplace_refresh_weight = NA_real_,
      slice_width = NA_real_,
      slice_max_steps = NA_integer_,
      n_burn = NA_integer_,
      n_mcmc = NA_integer_,
      trace_every = NA_integer_,
      progress_every = NA_integer_,
      init_from_vb_requested = NA,
      init_from_vb = NA,
      vb_path = NA_character_,
      baseline_fit_path = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$baseline_fit_path, NA_character_),
      run_config_path = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$run_config_path, NA_character_),
      stringsAsFactors = FALSE
    )
  } else if (grepl("^LOCAL_dynamic_case_checkpoint_.*\\.csv$", bn)) {
    keep <- tolower(safe_chr_original288_dynamic_tt5000_exactspec_repair(df$stage, "")) == "start" &
      !is.na(safe_chr_original288_dynamic_tt5000_exactspec_repair(df$candidate_path, NA_character_))
    df <- df[keep, , drop = FALSE]
    if (!nrow(df)) return(NULL)
    out <- data.frame(
      csv_path = path,
      source_kind = "checkpoint",
      variant_tag = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$variant_tag, NA_character_),
      model = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$model, NA_character_),
      family = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$family, NA_character_),
      fit_size = safe_int_original288_dynamic_tt5000_exactspec_repair(df$tt %||% df$fit_size, NA_integer_),
      tau_label = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$tau, NA_character_),
      prior_semantics = "default",
      inference = "mcmc",
      candidate_path = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$candidate_path, NA_character_),
      health_path = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$health_csv, NA_character_),
      source_seed = safe_int_original288_dynamic_tt5000_exactspec_repair(df$seed, NA_integer_),
      mh_proposal = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$mh_proposal, NA_character_),
      mh_adapt = if ("mh_adapt" %in% names(df)) as.logical(df$mh_adapt) else NA,
      laplace_refresh_interval = NA_integer_,
      laplace_refresh_start = NA_integer_,
      laplace_refresh_weight = NA_real_,
      slice_width = safe_num_original288_dynamic_tt5000_exactspec_repair(df$slice_width, NA_real_),
      slice_max_steps = safe_int_original288_dynamic_tt5000_exactspec_repair(df$slice_max_steps, NA_integer_),
      n_burn = safe_int_original288_dynamic_tt5000_exactspec_repair(df$n_burn, NA_integer_),
      n_mcmc = safe_int_original288_dynamic_tt5000_exactspec_repair(df$n_mcmc, NA_integer_),
      trace_every = safe_int_original288_dynamic_tt5000_exactspec_repair(df$trace_every, NA_integer_),
      progress_every = safe_int_original288_dynamic_tt5000_exactspec_repair(df$progress_every, NA_integer_),
      init_from_vb_requested = if ("init_from_vb_requested" %in% names(df)) as.logical(df$init_from_vb_requested) else NA,
      init_from_vb = if ("init_from_vb" %in% names(df)) as.logical(df$init_from_vb) else NA,
      vb_path = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$vb_path, NA_character_),
      baseline_fit_path = safe_chr_original288_dynamic_tt5000_exactspec_repair(df$mcmc_base_path %||% df$baseline_fit_path, NA_character_),
      run_config_path = NA_character_,
      stringsAsFactors = FALSE
    )
  }

  if (is.null(out) || !nrow(out)) return(NULL)

  out$original_case_key <- vapply(seq_len(nrow(out)), function(i) {
    if (!is.na(out$candidate_path[i]) && nzchar(out$candidate_path[i])) {
      mapped <- tryCatch(parse_original_key_from_fit_path_original288(out$candidate_path[i]), error = function(e) data.frame())
      if (nrow(mapped)) return(mapped$original_case_key[1])
    }
    derive_dynamic_case_key_original288_dynamic_tt5000_exactspec_repair(
      model = out$model[i],
      family = out$family[i],
      tau = out$tau_label[i],
      fit_size = out$fit_size[i],
      prior_semantics = out$prior_semantics[i],
      inference = out$inference[i]
    )
  }, character(1))

  out
}

historical_control_registry_original288_dynamic_tt5000_exactspec_repair <- local({
  cache <- NULL

  function(force = FALSE) {
    if (!force && !is.null(cache)) return(cache)

    root <- file.path(predecessor_repo_root_original288_normalized_multiseed(), "tools", "merge_reports")
    files <- unique(c(
      file.path(root, "LOCAL_dynamic_row15_wave8_matrix_20260405.csv"),
      list.files(root, pattern = "^LOCAL_dynamic_matrix_manifest_.*\\.csv$", full.names = TRUE),
      list.files(root, pattern = "^LOCAL_targeted_manifest_dynamic_tail.*\\.csv$", full.names = TRUE),
      list.files(root, pattern = "^LOCAL_dynamic_case_checkpoint_.*\\.csv$", full.names = TRUE)
    ))
    files <- files[file.exists(files)]

    parts <- Filter(Negate(is.null), lapply(files, extract_historical_control_part_original288_dynamic_tt5000_exactspec_repair))
    idx <- if (length(parts)) do.call(rbind, parts) else data.frame()
    if (!nrow(idx)) {
      cache <<- data.frame(stringsAsFactors = FALSE)
      return(cache)
    }

    idx$candidate_path_resolved <- vapply(idx$candidate_path, function(x) {
      resolved <- resolve_existing_path_original288_dynamic_tt5000_exactspec_repair(x)
      if (!is.na(resolved) && nzchar(resolved)) resolved else safe_chr_original288_dynamic_tt5000_exactspec_repair(x, NA_character_)
    }, character(1))
    idx$candidate_path_key <- vapply(idx$candidate_path_resolved, path_key_original288_dynamic_tt5000_exactspec_repair, character(1))
    idx$health_path <- vapply(idx$health_path, resolve_existing_path_original288_dynamic_tt5000_exactspec_repair, character(1))
    idx$vb_path <- vapply(idx$vb_path, resolve_existing_path_original288_dynamic_tt5000_exactspec_repair, character(1))
    idx$baseline_fit_path <- vapply(idx$baseline_fit_path, function(x) {
      resolved <- resolve_existing_path_original288_dynamic_tt5000_exactspec_repair(x)
      if (!is.na(resolved) && nzchar(resolved)) resolved else safe_chr_original288_dynamic_tt5000_exactspec_repair(x, NA_character_)
    }, character(1))
    idx$run_config_path <- vapply(idx$run_config_path, resolve_existing_path_original288_dynamic_tt5000_exactspec_repair, character(1))
    idx <- idx[order(idx$source_kind, idx$original_case_key, idx$variant_tag), , drop = FALSE]
    rownames(idx) <- NULL
    cache <<- idx
    idx
  }
})

resolve_phase2_historical_control_original288_dynamic_tt5000_exactspec_repair <- function(candidate_row,
                                                                                           control_index = historical_control_registry_original288_dynamic_tt5000_exactspec_repair()) {
  if (!nrow(control_index)) return(NULL)

  fit_key <- path_key_original288_dynamic_tt5000_exactspec_repair(candidate_row$selected_fit_path[1])
  health_path <- resolve_existing_path_original288_dynamic_tt5000_exactspec_repair(candidate_row$selected_health_path[1])
  score <- integer(nrow(control_index))
  score <- score + ifelse(!is.na(control_index$candidate_path_key) & !is.na(fit_key) & control_index$candidate_path_key == fit_key, 100L, 0L)
  score <- score + ifelse(!is.na(control_index$variant_tag) & control_index$variant_tag == candidate_row$selected_variant_tag[1], 60L, 0L)
  score <- score + ifelse(!is.na(control_index$original_case_key) & control_index$original_case_key == candidate_row$original_case_key[1], 30L, 0L)
  score <- score + ifelse(!is.na(control_index$health_path) & !is.na(health_path) & control_index$health_path == health_path, 40L, 0L)

  best <- which.max(score)
  best_score <- suppressWarnings(max(score))
  if (!length(best) || !is.finite(best_score) || best_score < 60L) return(NULL)

  out <- control_index[best, , drop = FALSE]
  out$resolution_score <- best_score
  out
}

resolve_phase2_source_row_original288_dynamic_tt5000_exactspec_repair <- function(candidate_row,
                                                                                   config_index = source_config_index_original288_exactspec_multiseed()) {
  config_index <- config_index[
    !grepl("dynamic_tt5000_exactspec_repair_", config_index$csv_path, fixed = TRUE),
    ,
    drop = FALSE
  ]
  resolved <- tryCatch(
    resolve_source_row_original288_exactspec_multiseed(candidate_row, config_index = config_index),
    error = function(e) NULL
  )
  if (is.null(resolved) || !nrow(resolved)) return(NULL)

  data.frame(
    config_csv_path = safe_chr_original288_dynamic_tt5000_exactspec_repair(resolved$csv_path[1], NA_character_),
    run_config_path = safe_chr_original288_dynamic_tt5000_exactspec_repair(resolved$run_config_path[1], NA_character_),
    candidate_path_match = safe_chr_original288_dynamic_tt5000_exactspec_repair(resolved$candidate_path[1], NA_character_),
    health_path_match = safe_chr_original288_dynamic_tt5000_exactspec_repair(resolved$health_path[1], NA_character_),
    source_seed = safe_int_original288_dynamic_tt5000_exactspec_repair(resolved$source_seed[1], NA_integer_),
    resolution_score = safe_int_original288_dynamic_tt5000_exactspec_repair(resolved$resolution_score[1], NA_integer_),
    reference_fit_path = {
      candidate_path <- safe_chr_original288_dynamic_tt5000_exactspec_repair(resolved$candidate_path[1], NA_character_)
      if (!is.na(candidate_path) && nzchar(candidate_path)) {
        candidate_path
      } else {
        safe_chr_original288_dynamic_tt5000_exactspec_repair(candidate_row$selected_fit_path[1], NA_character_)
      }
    },
    stringsAsFactors = FALSE
  )
}

base_seed_from_source_original288_dynamic_tt5000_exactspec_repair <- function(source_row,
                                                                               fallback_fit_path,
                                                                               original_case_key) {
  seed_from_source <- safe_int_original288_dynamic_tt5000_exactspec_repair(source_row$seed, NA_integer_)
  if (is.finite(seed_from_source)) return(seed_from_source)

  fit_seed <- extract_seed_from_fit_original288_normalized_multiseed(fallback_fit_path)
  if (is.finite(fit_seed)) return(fit_seed)

  hash_seed_original288_dynamic_tt5000_exactspec_repair(original_case_key)
}

seedbank_for_base_row_original288_dynamic_tt5000_exactspec_repair <- function(base_seed,
                                                                               base_row_id,
                                                                               original_case_key) {
  seeds <- seed_vector_original288_dynamic_tt5000_exactspec_repair(base_seed)
  data.frame(
    base_row_id = as.integer(base_row_id),
    original_case_key = original_case_key,
    seed_slot = seq_along(seeds),
    seed = as.integer(seeds),
    stringsAsFactors = FALSE
  )
}

build_nested_config_original288_dynamic_tt5000_exactspec_repair <- function(source_cfg,
                                                                             manifest_row,
                                                                             row_id,
                                                                             candidate_label,
                                                                             seed_slot,
                                                                             seed) {
  cfg <- source_cfg
  cfg$source_config_style <- "nested_dynamic_exact_repair"
  cfg$source_run_config_path <- manifest_row$source_run_config_path
  cfg$base_row_id <- as.integer(manifest_row$base_row_id)
  cfg$original_case_key <- manifest_row$original_case_key
  cfg$phase <- manifest_row$phase
  cfg$phase_order <- unname(phase_order_original288_dynamic_tt5000_exactspec_repair[manifest_row$phase])
  cfg$fit_seed <- as.integer(seed)
  cfg$seed_slot <- as.integer(seed_slot)
  cfg$candidate_label <- candidate_label
  cfg$sim_path <- resolve_existing_path_original288_dynamic_tt5000_exactspec_repair(manifest_row$sim_output_path)
  cfg$out_root <- map_to_current_repo_root_original288_dynamic_tt5000_exactspec_repair(source_cfg$out_root)
  cfg$fit_path <- candidate_fit_path_original288_dynamic_tt5000_exactspec_repair(
    run_root = manifest_row$run_root,
    inference = manifest_row$inference,
    model = manifest_row$model,
    tau_label = manifest_row$tau_label,
    candidate_label = candidate_label,
    seed_slot = seed_slot
  )
  cfg$config_path <- config_path_original288_dynamic_tt5000_exactspec_repair(row_id)
  cfg$row_status_path <- row_status_path_original288_dynamic_tt5000_exactspec_repair(row_id)
  cfg$health_path <- health_path_original288_dynamic_tt5000_exactspec_repair(row_id)
  cfg$metrics_path <- metrics_path_original288_dynamic_tt5000_exactspec_repair(row_id)
  cfg$draws_path <- draws_path_original288_dynamic_tt5000_exactspec_repair(row_id)
  cfg$stored_posterior_draws <- 20000L

  if (manifest_row$inference == "mcmc") {
    cfg$mcmc <- cfg$mcmc %||% list()
    cfg$mcmc$burn <- 5000L
    cfg$mcmc$n <- 20000L
    cfg$mcmc$mh <- cfg$mcmc$mh %||% list()
    if (is.null(cfg$mcmc$mh$proposal) && !is.null(cfg$mcmc$mh$primary_proposal)) {
      cfg$mcmc$mh$proposal <- cfg$mcmc$mh$primary_proposal
    }
    if (is.null(cfg$mcmc$mh$joint_sample) && !is.null(cfg$mcmc$mh$primary_joint_sample)) {
      cfg$mcmc$mh$joint_sample <- cfg$mcmc$mh$primary_joint_sample
    }

    hist_proposal <- safe_chr_original288_dynamic_tt5000_exactspec_repair(manifest_row$hist_mh_proposal, NA_character_)
    if (!is.na(hist_proposal) && nzchar(hist_proposal)) {
      cfg$mcmc$mh$proposal <- hist_proposal
      cfg$mcmc$mh$primary_proposal <- hist_proposal
    }

    hist_adapt <- manifest_row$hist_mh_adapt[1]
    if (!is.na(hist_adapt)) {
      cfg$mcmc$mh$adapt <- isTRUE(hist_adapt)
    }

    hist_refresh_interval <- safe_int_original288_dynamic_tt5000_exactspec_repair(manifest_row$hist_laplace_refresh_interval, NA_integer_)
    hist_refresh_start <- safe_int_original288_dynamic_tt5000_exactspec_repair(manifest_row$hist_laplace_refresh_start, NA_integer_)
    hist_refresh_weight <- safe_num_original288_dynamic_tt5000_exactspec_repair(manifest_row$hist_laplace_refresh_weight, NA_real_)
    hist_slice_width <- safe_num_original288_dynamic_tt5000_exactspec_repair(manifest_row$hist_slice_width, NA_real_)
    hist_slice_max_steps <- safe_int_original288_dynamic_tt5000_exactspec_repair(manifest_row$hist_slice_max_steps, NA_integer_)
    hist_trace_every <- safe_int_original288_dynamic_tt5000_exactspec_repair(manifest_row$hist_trace_every, NA_integer_)

    if (is.finite(hist_refresh_interval)) cfg$mcmc$mh$laplace_refresh_interval <- hist_refresh_interval
    if (is.finite(hist_refresh_start)) cfg$mcmc$mh$laplace_refresh_start <- hist_refresh_start
    if (is.finite(hist_refresh_weight)) cfg$mcmc$mh$laplace_refresh_weight <- hist_refresh_weight
    if (is.finite(hist_slice_width)) cfg$mcmc$mh$slice_width <- hist_slice_width
    if (is.finite(hist_slice_max_steps)) cfg$mcmc$mh$slice_max_steps <- hist_slice_max_steps
    if (is.finite(hist_trace_every)) cfg$mcmc$trace_every <- hist_trace_every

    hist_init_from_vb_requested <- manifest_row$hist_init_from_vb_requested[1]
    hist_init_from_vb <- manifest_row$hist_init_from_vb[1]
    if (!is.na(hist_init_from_vb_requested)) {
      cfg$mcmc$init_from_vb <- isTRUE(hist_init_from_vb_requested)
    }
    if (!is.na(hist_init_from_vb)) {
      cfg$mcmc$init_from_vb <- isTRUE(hist_init_from_vb)
    }
  }

  cfg
}

read_phase2_candidate_pool_original288_dynamic_tt5000_exactspec_repair <- function(target_rows,
                                                                                    baseline_rows,
                                                                                    registry = phase1_source_registry_original288_dynamic_tt5000_exactspec_repair(),
                                                                                    control_index = historical_control_registry_original288_dynamic_tt5000_exactspec_repair()) {
  pool <- read.csv(
    paths_original288_dynamic_tt5000_exactspec_repair()$candidate_pool,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  pool <- subset(
    pool,
    block == "dynamic" &
      fit_size == 5000 &
      gate_overall %in% c("PASS", "WARN") &
      original_case_key %in% target_rows$original_case_key
  )
  if (!nrow(pool)) return(pool)

  baseline_map <- baseline_rows[, c("original_case_key", "selected_fit_path"), drop = FALSE]
  names(baseline_map)[2] <- "baseline_selected_fit_path"
  pool <- merge(pool, baseline_map, by = "original_case_key", all.x = TRUE, sort = FALSE)
  pool$selected_fit_path_resolved <- vapply(
    pool$selected_fit_path,
    resolve_existing_path_original288_dynamic_tt5000_exactspec_repair,
    character(1)
  )
  pool$baseline_selected_fit_path_resolved <- vapply(
    pool$baseline_selected_fit_path,
    resolve_existing_path_original288_dynamic_tt5000_exactspec_repair,
    character(1)
  )
  keep <- is.na(pool$selected_fit_path_resolved) |
    is.na(pool$baseline_selected_fit_path_resolved) |
    pool$selected_fit_path_resolved != pool$baseline_selected_fit_path_resolved
  pool <- pool[keep, , drop = FALSE]
  if (!nrow(pool)) return(pool)

  pool$resolved_fit_path <- pool$selected_fit_path_resolved
  case_map_rows <- vector("list", nrow(target_rows))
  for (i in seq_len(nrow(target_rows))) {
    resolved <- resolve_phase1_source_row_original288_dynamic_tt5000_exactspec_repair(
      target_row = target_rows[i, , drop = FALSE],
      baseline_row = baseline_rows[i, , drop = FALSE],
      registry = registry
    )
    case_map_rows[[i]] <- data.frame(
      original_case_key = target_rows$original_case_key[i],
      phase1_run_root = resolved$run_root[1],
      phase1_run_config_path = resolved$run_config_path[1],
      phase1_sim_output_path = resolved$sim_output_path[1],
      phase1_source_run_root = resolved$source_run_root[1],
      phase1_registry_source = resolved$source_registry_source[1],
      stringsAsFactors = FALSE
    )
  }
  case_map <- do.call(rbind, case_map_rows)

  resolved_rows <- vector("list", nrow(pool))
  for (i in seq_len(nrow(pool))) {
    hist <- resolve_phase2_historical_control_original288_dynamic_tt5000_exactspec_repair(pool[i, , drop = FALSE], control_index = control_index)
    case_src <- case_map[case_map$original_case_key == pool$original_case_key[i], , drop = FALSE]
    resolved_rows[[i]] <- if (is.null(hist) || !nrow(case_src)) {
      data.frame(
        config_csv_path = NA_character_,
        run_config_path = NA_character_,
        candidate_path_match = NA_character_,
        health_path_match = NA_character_,
        source_seed = NA_integer_,
        resolution_score = NA_integer_,
        reference_fit_path = NA_character_,
        source_run_root = NA_character_,
        phase1_registry_source = NA_character_,
        historical_source_kind = NA_character_,
        hist_mh_proposal = NA_character_,
        hist_mh_adapt = NA,
        hist_laplace_refresh_interval = NA_integer_,
        hist_laplace_refresh_start = NA_integer_,
        hist_laplace_refresh_weight = NA_real_,
        hist_slice_width = NA_real_,
        hist_slice_max_steps = NA_integer_,
        hist_n_burn = NA_integer_,
        hist_n_mcmc = NA_integer_,
        hist_trace_every = NA_integer_,
        hist_progress_every = NA_integer_,
        hist_init_from_vb_requested = NA,
        hist_init_from_vb = NA,
        hist_vb_path = NA_character_,
        hist_baseline_fit_path = NA_character_,
        stringsAsFactors = FALSE
      )
    } else {
      data.frame(
        config_csv_path = safe_chr_original288_dynamic_tt5000_exactspec_repair(hist$csv_path[1], NA_character_),
        run_config_path = safe_chr_original288_dynamic_tt5000_exactspec_repair(case_src$phase1_run_config_path[1], NA_character_),
        candidate_path_match = safe_chr_original288_dynamic_tt5000_exactspec_repair(hist$candidate_path[1], NA_character_),
        health_path_match = safe_chr_original288_dynamic_tt5000_exactspec_repair(hist$health_path[1], NA_character_),
        source_seed = safe_int_original288_dynamic_tt5000_exactspec_repair(hist$source_seed[1], NA_integer_),
        resolution_score = safe_int_original288_dynamic_tt5000_exactspec_repair(hist$resolution_score[1], NA_integer_),
        reference_fit_path = safe_chr_original288_dynamic_tt5000_exactspec_repair(
          hist$baseline_fit_path[1],
          safe_chr_original288_dynamic_tt5000_exactspec_repair(hist$candidate_path[1], safe_chr_original288_dynamic_tt5000_exactspec_repair(pool$selected_fit_path[i], NA_character_))
        ),
        source_run_root = safe_chr_original288_dynamic_tt5000_exactspec_repair(case_src$phase1_source_run_root[1], NA_character_),
        phase1_registry_source = safe_chr_original288_dynamic_tt5000_exactspec_repair(case_src$phase1_registry_source[1], NA_character_),
        historical_source_kind = safe_chr_original288_dynamic_tt5000_exactspec_repair(hist$source_kind[1], NA_character_),
        hist_mh_proposal = safe_chr_original288_dynamic_tt5000_exactspec_repair(hist$mh_proposal[1], NA_character_),
        hist_mh_adapt = if ("mh_adapt" %in% names(hist)) hist$mh_adapt[1] else NA,
        hist_laplace_refresh_interval = safe_int_original288_dynamic_tt5000_exactspec_repair(hist$laplace_refresh_interval[1], NA_integer_),
        hist_laplace_refresh_start = safe_int_original288_dynamic_tt5000_exactspec_repair(hist$laplace_refresh_start[1], NA_integer_),
        hist_laplace_refresh_weight = safe_num_original288_dynamic_tt5000_exactspec_repair(hist$laplace_refresh_weight[1], NA_real_),
        hist_slice_width = safe_num_original288_dynamic_tt5000_exactspec_repair(hist$slice_width[1], NA_real_),
        hist_slice_max_steps = safe_int_original288_dynamic_tt5000_exactspec_repair(hist$slice_max_steps[1], NA_integer_),
        hist_n_burn = safe_int_original288_dynamic_tt5000_exactspec_repair(hist$n_burn[1], NA_integer_),
        hist_n_mcmc = safe_int_original288_dynamic_tt5000_exactspec_repair(hist$n_mcmc[1], NA_integer_),
        hist_trace_every = safe_int_original288_dynamic_tt5000_exactspec_repair(hist$trace_every[1], NA_integer_),
        hist_progress_every = safe_int_original288_dynamic_tt5000_exactspec_repair(hist$progress_every[1], NA_integer_),
        hist_init_from_vb_requested = if ("init_from_vb_requested" %in% names(hist)) hist$init_from_vb_requested[1] else NA,
        hist_init_from_vb = if ("init_from_vb" %in% names(hist)) hist$init_from_vb[1] else NA,
        hist_vb_path = safe_chr_original288_dynamic_tt5000_exactspec_repair(hist$vb_path[1], NA_character_),
        hist_baseline_fit_path = safe_chr_original288_dynamic_tt5000_exactspec_repair(hist$baseline_fit_path[1], NA_character_),
        stringsAsFactors = FALSE
      )
    }
  }
  resolved_df <- do.call(rbind, resolved_rows)
  if ("reference_fit_path" %in% names(pool)) {
    pool$reference_fit_path <- NULL
  }
  pool <- cbind(pool, resolved_df)
  pool$source_resolved <- !is.na(pool$run_config_path) & nzchar(pool$run_config_path) &
    !is.na(pool$historical_source_kind) & nzchar(pool$historical_source_kind)
  pool$gate_rank <- gate_rank_original288_dynamic_tt5000_exactspec_repair(pool$gate_overall)
  pool <- pool[order(
    pool$original_case_key,
    pool$gate_rank,
    pool$source_rank,
    ifelse(is.na(pool$runtime_sec), Inf, pool$runtime_sec),
    pool$selected_fit_path
  ), , drop = FALSE]
  rownames(pool) <- NULL
  pool
}

build_manifest_rows_original288_dynamic_tt5000_exactspec_repair <- function(seedbank,
                                                                             source_rows,
                                                                             candidate_label,
                                                                             phase,
                                                                             candidate_source_type,
                                                                             candidate_source_subtype,
                                                                             reference_gate,
                                                                             accepted_baseline_gate,
                                                                             vb_reference_fit_path,
                                                                             source_reference_fit_path,
                                                                             source_selected_variant_tag,
                                                                             source_rank = NA_integer_) {
  rows <- vector("list", nrow(seedbank))
  for (i in seq_len(nrow(seedbank))) {
    seed_row <- seedbank[i, , drop = FALSE]
    row_id <- as.integer(seed_row$row_id)
    src <- source_rows[1, , drop = FALSE]
    cfg <- readRDS(src$run_config_path)

    manifest_row <- data.frame(
      row_id = row_id,
      base_row_id = as.integer(seed_row$base_row_id),
      original_case_key = src$original_case_key,
      phase = phase,
      phase_order = unname(phase_order_original288_dynamic_tt5000_exactspec_repair[phase]),
      block = src$block,
      root_kind = src$root_kind,
      family = src$family,
      tau = src$tau,
      tau_label = src$tau_label,
      fit_size = as.integer(src$fit_size),
      prior_semantics = src$prior_semantics,
      model = src$model,
      inference = src$inference,
      seed_slot = as.integer(seed_row$seed_slot),
      seed = as.integer(seed_row$seed),
      candidate_label = candidate_label,
      candidate_source_type = candidate_source_type,
      candidate_source_subtype = candidate_source_subtype,
      source_rank = source_rank,
      reference_gate = reference_gate,
      accepted_baseline_gate = accepted_baseline_gate,
      run_root = src$run_root,
      run_config_path = config_path_original288_dynamic_tt5000_exactspec_repair(row_id),
      sim_output_path = src$sim_output_path,
      baseline_fit_path = source_reference_fit_path,
      source_reference_fit_path = source_reference_fit_path,
      vb_reference_fit_path = vb_reference_fit_path,
      source_run_root = src$source_run_root,
      source_run_config_path = src$run_config_path,
      selected_variant_tag_source = source_selected_variant_tag,
      candidate_fit_path = candidate_fit_path_original288_dynamic_tt5000_exactspec_repair(
        run_root = src$run_root,
        inference = src$inference,
        model = src$model,
        tau_label = src$tau_label,
        candidate_label = candidate_label,
        seed_slot = seed_row$seed_slot
      ),
      row_status_path = row_status_path_original288_dynamic_tt5000_exactspec_repair(row_id),
      health_path = health_path_original288_dynamic_tt5000_exactspec_repair(row_id),
      metrics_path = metrics_path_original288_dynamic_tt5000_exactspec_repair(row_id),
      draws_path = draws_path_original288_dynamic_tt5000_exactspec_repair(row_id),
      missing_inputs = FALSE,
      stringsAsFactors = FALSE
    )
    for (nm in c(
      "historical_source_kind",
      "phase1_registry_source",
      "hist_mh_proposal",
      "hist_mh_adapt",
      "hist_laplace_refresh_interval",
      "hist_laplace_refresh_start",
      "hist_laplace_refresh_weight",
      "hist_slice_width",
      "hist_slice_max_steps",
      "hist_n_burn",
      "hist_n_mcmc",
      "hist_trace_every",
      "hist_progress_every",
      "hist_init_from_vb_requested",
      "hist_init_from_vb",
      "hist_vb_path",
      "hist_baseline_fit_path"
    )) {
      manifest_row[[nm]] <- if (nm %in% names(src)) src[[nm]][1] else NA
    }

    built_cfg <- build_nested_config_original288_dynamic_tt5000_exactspec_repair(
      source_cfg = cfg,
      manifest_row = manifest_row,
      row_id = row_id,
      candidate_label = candidate_label,
      seed_slot = seed_row$seed_slot,
      seed = seed_row$seed
    )
    saveRDS(built_cfg, manifest_row$run_config_path)

    manifest_row$missing_inputs <- !file.exists(manifest_row$sim_output_path) ||
      !file.exists(manifest_row$run_config_path)

    rows[[i]] <- manifest_row
  }
  do.call(rbind, rows)
}

write_stage_counts_original288_dynamic_tt5000_exactspec_repair <- function(manifest, path) {
  if (!nrow(manifest)) {
    utils::write.csv(data.frame(phase = character(), rows = integer(), stringsAsFactors = FALSE), path, row.names = FALSE)
    return(invisible(NULL))
  }
  counts <- as.data.frame(with(manifest, table(phase)), stringsAsFactors = FALSE)
  names(counts) <- c("phase", "rows")
  counts$phase_order <- unname(phase_order_original288_dynamic_tt5000_exactspec_repair[counts$phase])
  counts <- counts[order(counts$phase_order), c("phase", "rows"), drop = FALSE]
  utils::write.csv(counts, path, row.names = FALSE)
  invisible(counts)
}

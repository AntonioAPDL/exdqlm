source("tools/merge_reports/LOCAL_original288_recovery_helpers_20260405.R")
source("tools/merge_reports/LOCAL_original288_normalized_multiseed_helpers_20260411.R")

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

run_tag_original288_exactspec_multiseed <- function() {
  "original288_exactspec_multiseed_relaunch_20260412"
}

variant_tag_original288_exactspec_multiseed <- function() {
  "orig288_exactspec_multiseed_20260412"
}

phase_order_original288_exactspec_multiseed <- c(
  full_static_mcmc = 1L,
  full_static_vb = 2L,
  full_dynamic_vb = 3L,
  full_dynamic_mcmc = 4L
)

ensure_dir_original288_exactspec_multiseed <- function(path) {
  ensure_dir_original288_normalized_multiseed(path)
}

safe_chr_original288_exactspec_multiseed <- function(x, default = NA_character_) {
  safe_chr_original288_normalized_multiseed(x, default = default)
}

safe_num_original288_exactspec_multiseed <- function(x, default = NA_real_) {
  safe_num_original288_normalized_multiseed(x, default = default)
}

safe_int_original288_exactspec_multiseed <- function(x, default = NA_integer_) {
  safe_int_original288_normalized_multiseed(x, default = default)
}

as_flag_original288_exactspec_multiseed <- function(x, default = FALSE) {
  as_flag_original288_normalized_multiseed(x, default = default)
}

resolve_existing_path_original288_exactspec_multiseed <- function(path) {
  resolve_existing_path_original288_normalized_multiseed(path)
}

map_to_current_repo_root_original288_exactspec_multiseed <- function(path) {
  map_to_current_repo_root_original288_normalized_multiseed(path)
}

hash_seed_original288_exactspec_multiseed <- function(key) {
  hash_seed_original288_normalized_multiseed(key)
}

seed_vector_original288_exactspec_multiseed <- function(base_seed) {
  seed_vector_original288_normalized_multiseed(base_seed)
}

select_draw_indices_original288_exactspec_multiseed <- function(n_available, n_target, seed) {
  select_draw_indices_original288_normalized_multiseed(n_available, n_target, seed)
}

static_predictive_draws_original288_exactspec_multiseed <- function(fit_obj,
                                                                    row,
                                                                    series_wide,
                                                                    n_draws = 20000L,
                                                                    seed = 1L) {
  static_predictive_draws_original288_normalized_multiseed(
    fit_obj = fit_obj,
    row = row,
    series_wide = series_wide,
    n_draws = n_draws,
    seed = seed
  )
}

static_metrics_original288_exactspec_multiseed <- function(row,
                                                            fit_obj,
                                                            series_wide,
                                                            coef_truth,
                                                            draws_bundle) {
  static_metrics_original288_normalized_multiseed(
    row = row,
    fit_obj = fit_obj,
    series_wide = series_wide,
    coef_truth = coef_truth,
    draws_bundle = draws_bundle
  )
}

dynamic_standardize_draws_original288_exactspec_multiseed <- function(fit_obj,
                                                                      n_draws = 20000L,
                                                                      seed = 1L) {
  dynamic_standardize_draws_original288_normalized_multiseed(
    fit_obj = fit_obj,
    n_draws = n_draws,
    seed = seed
  )
}

dynamic_metrics_original288_exactspec_multiseed <- function(row, sim_obj, draw_mat) {
  dynamic_metrics_original288_normalized_multiseed(row = row, sim_obj = sim_obj, draw_mat = draw_mat)
}

gate_rank_original288_exactspec_multiseed <- function(x) {
  gate_rank_original288_normalized_multiseed(x)
}

paths_original288_exactspec_multiseed <- function() {
  tag <- run_tag_original288_exactspec_multiseed()
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", tag))
  list(
    selection = "tools/merge_reports/LOCAL_original288_comparison_selection_rhsns_v1_20260411.csv",
    config_index = "tools/merge_reports/LOCAL_original288_exactspec_multiseed_config_index_20260412.csv",
    resolution_audit = "tools/merge_reports/LOCAL_original288_exactspec_multiseed_resolution_audit_20260412.csv",
    control_audit = "tools/merge_reports/LOCAL_original288_exactspec_multiseed_control_audit_20260412.csv",
    seedbank = "tools/merge_reports/LOCAL_original288_exactspec_multiseed_seedbank_20260412.csv",
    smoke_manifest = "tools/merge_reports/LOCAL_original288_exactspec_multiseed_smoke_manifest_20260412.csv",
    full_manifest = "tools/merge_reports/LOCAL_original288_exactspec_multiseed_full_manifest_20260412.csv",
    smoke_stage_counts = "tools/merge_reports/LOCAL_original288_exactspec_multiseed_smoke_stage_counts_20260412.csv",
    full_stage_counts = "tools/merge_reports/LOCAL_original288_exactspec_multiseed_full_stage_counts_20260412.csv",
    smoke_manifest_status = "tools/merge_reports/LOCAL_original288_exactspec_multiseed_smoke_manifest_status_20260412.csv",
    full_manifest_status = "tools/merge_reports/LOCAL_original288_exactspec_multiseed_full_manifest_status_20260412.csv",
    smoke_phase_summary = "tools/merge_reports/LOCAL_original288_exactspec_multiseed_smoke_phase_summary_20260412.csv",
    full_phase_summary = "tools/merge_reports/LOCAL_original288_exactspec_multiseed_full_phase_summary_20260412.csv",
    smoke_seed_ranking = "tools/merge_reports/LOCAL_original288_exactspec_multiseed_smoke_seed_ranking_20260412.csv",
    full_seed_ranking = "tools/merge_reports/LOCAL_original288_exactspec_multiseed_full_seed_ranking_20260412.csv",
    smoke_selected = "tools/merge_reports/LOCAL_original288_exactspec_multiseed_smoke_selected_20260412.csv",
    full_selected = "tools/merge_reports/LOCAL_original288_exactspec_multiseed_full_selected_20260412.csv",
    exactspec_selection = "tools/merge_reports/LOCAL_original288_comparison_selection_exactspec_multiseed_v1_20260412.csv",
    exactspec_selection_summary = "tools/merge_reports/LOCAL_original288_comparison_selection_exactspec_multiseed_summary_v1_20260412.csv",
    comparison_output_dir = "tools/merge_reports/original288_tablebacked_comparison_exactspec_multiseed_20260412",
    comparison_report = "reports/static_exal_tuning_20260412/original288_tablebacked_cluster_comparison_exactspec_multiseed_20260412.md",
    plan_doc = "reports/static_exal_tuning_20260412/original288_exactspec_multiseed_relaunch_plan_20260412.md",
    program_doc = "reports/static_exal_tuning_20260412/original288_exactspec_multiseed_relaunch_program_20260412.md",
    execution_doc = "reports/static_exal_tuning_20260412/original288_exactspec_multiseed_relaunch_execution_20260412.md",
    run_root = run_dir,
    config_dir = file.path(run_dir, "configs"),
    rows_dir = file.path(run_dir, "rows"),
    health_dir = file.path(run_dir, "health"),
    metrics_dir = file.path(run_dir, "metrics"),
    draws_dir = file.path(run_dir, "draws"),
    logs_dir = file.path(run_dir, "logs")
  )
}

source_config_index_original288_exactspec_multiseed <- local({
  cache <- NULL

  parse_case_key_from_case_id <- function(case_id) {
    if (is.na(case_id) || !nzchar(case_id)) return(NA_character_)
    mapped <- tryCatch(parse_original_key_from_fit_path_original288(case_id), error = function(e) data.frame())
    if (!nrow(mapped)) return(NA_character_)
    mapped$original_case_key[1]
  }

  extract_index_part <- function(path) {
    hdr <- tryCatch(
      names(read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, nrows = 1)),
      error = function(e) NULL
    )
    if (is.null(hdr)) return(NULL)

    cfg_col <- intersect(c("run_config_path", "config_path"), hdr)[1]
    if (length(cfg_col) == 0L || is.na(cfg_col) || !nzchar(cfg_col)) return(NULL)

    df <- tryCatch(read.csv(path, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) NULL)
    if (is.null(df) || !nrow(df)) return(NULL)

    out <- data.frame(
      csv_path = rep(path, nrow(df)),
      run_config_path = unname(vapply(df[[cfg_col]], resolve_existing_path_original288_exactspec_multiseed, character(1))),
      candidate_path = rep(NA_character_, nrow(df)),
      health_path = rep(NA_character_, nrow(df)),
      variant_tag = rep(NA_character_, nrow(df)),
      original_case_key = rep(NA_character_, nrow(df)),
      source_seed = rep(NA_integer_, nrow(df)),
      stringsAsFactors = FALSE
    )

    for (nm in intersect(c("candidate_path", "candidate_fit_path", "candidate_fit_path_row", "selected_fit_path"), names(df))) {
      vals <- unname(vapply(df[[nm]], resolve_existing_path_original288_exactspec_multiseed, character(1)))
      take <- is.na(out$candidate_path) | !nzchar(out$candidate_path)
      out$candidate_path[take] <- vals[take]
    }
    for (nm in intersect(c("health_csv", "health_path", "selected_health_path"), names(df))) {
      vals <- unname(vapply(df[[nm]], resolve_existing_path_original288_exactspec_multiseed, character(1)))
      take <- is.na(out$health_path) | !nzchar(out$health_path)
      out$health_path[take] <- vals[take]
    }
    for (nm in intersect(c("variant_tag", "selected_variant_tag", "candidate_variant_tag", "profile_id", "selected_candidate"), names(df))) {
      vals <- unname(as.character(df[[nm]]))
      take <- is.na(out$variant_tag) | !nzchar(out$variant_tag)
      out$variant_tag[take] <- vals[take]
    }
    for (nm in intersect(c("original_case_key", "target_original_case_key", "case_key"), names(df))) {
      vals <- unname(as.character(df[[nm]]))
      take <- is.na(out$original_case_key) | !nzchar(out$original_case_key)
      out$original_case_key[take] <- vals[take]
    }
    for (nm in intersect(c("seed", "fit_seed"), names(df))) {
      vals <- unname(suppressWarnings(as.integer(df[[nm]])))
      take <- !is.finite(out$source_seed)
      out$source_seed[take] <- vals[take]
    }
    if ("case_id" %in% names(df)) {
      vals <- unname(as.character(df$case_id))
      for (i in seq_along(vals)) {
        if ((is.na(out$original_case_key[i]) || !nzchar(out$original_case_key[i])) &&
            !is.na(vals[i]) && nzchar(vals[i])) {
          out$original_case_key[i] <- parse_case_key_from_case_id(vals[i])
        }
      }
    }
    for (i in seq_len(nrow(out))) {
      if ((is.na(out$original_case_key[i]) || !nzchar(out$original_case_key[i])) &&
          !is.na(out$candidate_path[i]) && nzchar(out$candidate_path[i])) {
        mapped <- tryCatch(parse_original_key_from_fit_path_original288(out$candidate_path[i]), error = function(e) data.frame())
        if (nrow(mapped)) out$original_case_key[i] <- mapped$original_case_key[1]
      }
    }

    out <- out[!is.na(out$run_config_path), , drop = FALSE]
    if (!nrow(out)) return(NULL)
    rownames(out) <- NULL
    out
  }

  function(force = FALSE) {
    if (!force && !is.null(cache)) return(cache)

    roots <- c(
      file.path(current_repo_root_original288_normalized_multiseed(), "tools", "merge_reports"),
      file.path(predecessor_repo_root_original288_normalized_multiseed(), "tools", "merge_reports")
    )
    files <- unique(unlist(lapply(roots, function(root) {
      list.files(root, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)
    })))

    parts <- Filter(Negate(is.null), lapply(files, extract_index_part))
    idx <- do.call(rbind, parts)
    rownames(idx) <- NULL
    idx <- idx[order(idx$csv_path, idx$run_config_path), , drop = FALSE]
    cache <<- idx
    idx
  }
})

resolve_source_row_original288_exactspec_multiseed <- function(selection_row,
                                                               config_index = source_config_index_original288_exactspec_multiseed()) {
  row <- selection_row
  row$selected_fit_path_resolved <- resolve_existing_path_original288_exactspec_multiseed(row$selected_fit_path)
  row$selected_health_path_resolved <- resolve_existing_path_original288_exactspec_multiseed(row$selected_health_path)
  row$selected_summary_path_resolved <- resolve_existing_path_original288_exactspec_multiseed(row$selected_summary_path)
  row$source_path_resolved <- resolve_existing_path_original288_exactspec_multiseed(row$source_path)

  score <- integer(nrow(config_index))
  score <- score + ifelse(
    !is.na(config_index$candidate_path) &
      !is.na(row$selected_fit_path_resolved) &
      config_index$candidate_path == row$selected_fit_path_resolved,
    100L,
    0L
  )
  score <- score + ifelse(
    !is.na(config_index$health_path) &
      !is.na(row$selected_health_path_resolved) &
      config_index$health_path == row$selected_health_path_resolved,
    80L,
    0L
  )
  score <- score + ifelse(
    !is.na(config_index$variant_tag) &
      !is.na(row$selected_variant_tag) &
      config_index$variant_tag == row$selected_variant_tag,
    40L,
    0L
  )
  score <- score + ifelse(
    !is.na(config_index$original_case_key) &
      !is.na(row$original_case_key) &
      config_index$original_case_key == row$original_case_key,
    20L,
    0L
  )
  score <- score + ifelse(
    !is.na(config_index$csv_path) &
      config_index$csv_path %in% c(
        row$source_path_resolved,
        row$selected_summary_path_resolved,
        row$selected_health_path_resolved
      ),
    10L,
    0L
  )

  best <- which.max(score)
  best_score <- suppressWarnings(max(score))
  if (!length(best) || !is.finite(best_score) || best_score < 40L) {
    stop(sprintf(
      "Could not resolve an exact source config for %s (best_score=%s).",
      row$original_case_key,
      as.character(best_score)
    ))
  }

  out <- cbind(row, config_index[best, , drop = FALSE], resolution_score = best_score)
  rownames(out) <- NULL
  out
}

source_config_style_original288_exactspec_multiseed <- function(cfg) {
  nm <- names(cfg)
  if (all(c("row_id", "fit_path", "run_root", "model", "inference") %in% nm)) return("flat")
  if (all(c("vb", "mcmc", "sim_path", "out_root") %in% nm)) return("nested")
  "unknown"
}

candidate_fit_path_original288_exactspec_multiseed <- function(run_root,
                                                               inference,
                                                               model,
                                                               tau_label,
                                                               seed_slot) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    inference,
    sprintf(
      "%s_%s_tau_%s_fit_%s_seed%02d.rds",
      inference,
      model,
      tau_label,
      variant_tag_original288_exactspec_multiseed(),
      as.integer(seed_slot)
    )
  ))
}

row_status_path_original288_exactspec_multiseed <- function(kind, row_id) {
  file.path(paths_original288_exactspec_multiseed()$rows_dir, sprintf("%s_row_%04d.csv", kind, as.integer(row_id)))
}

health_path_original288_exactspec_multiseed <- function(kind, row_id) {
  file.path(paths_original288_exactspec_multiseed()$health_dir, sprintf("%s_health_%04d.csv", kind, as.integer(row_id)))
}

metrics_path_original288_exactspec_multiseed <- function(kind, row_id) {
  file.path(paths_original288_exactspec_multiseed()$metrics_dir, sprintf("%s_metrics_%04d.csv", kind, as.integer(row_id)))
}

draws_path_original288_exactspec_multiseed <- function(kind, row_id) {
  file.path(paths_original288_exactspec_multiseed()$draws_dir, sprintf("%s_draws_%04d.rds", kind, as.integer(row_id)))
}

config_path_original288_exactspec_multiseed <- function(kind, row_id) {
  file.path(paths_original288_exactspec_multiseed()$config_dir, sprintf("%s_row_%04d_run_config.rds", kind, as.integer(row_id)))
}

phase_for_row_original288_exactspec_multiseed <- function(block, inference) {
  if (identical(block, "dynamic") && identical(inference, "mcmc")) return("full_dynamic_mcmc")
  if (identical(block, "dynamic") && identical(inference, "vb")) return("full_dynamic_vb")
  if (identical(inference, "mcmc")) return("full_static_mcmc")
  "full_static_vb"
}

data_dir_from_sim_path_original288_exactspec_multiseed <- function(sim_path) {
  sim_path_raw <- safe_chr_original288_exactspec_multiseed(sim_path, NA_character_)
  if (is.na(sim_path_raw)) return(NA_character_)

  sim_path_resolved <- resolve_existing_path_original288_exactspec_multiseed(sim_path_raw)
  if (!is.na(sim_path_resolved)) return(normalize_path_original288(dirname(sim_path_resolved)))

  dir_raw <- dirname(sim_path_raw)
  dir_resolved <- resolve_existing_path_original288_exactspec_multiseed(dir_raw)
  if (!is.na(dir_resolved)) return(normalize_path_original288(dir_resolved))

  mapped_file <- map_to_current_repo_root_original288_exactspec_multiseed(sim_path_raw)
  mapped_dir <- dirname(mapped_file)
  if (dir.exists(mapped_dir)) return(normalize_path_original288(mapped_dir))

  if (dir.exists(dir_raw)) return(normalize_path_original288(dir_raw))
  NA_character_
}

period_from_sim_output_original288_exactspec_multiseed <- function(sim_output_path, default = 50L) {
  sim_output_path <- resolve_existing_path_original288_exactspec_multiseed(sim_output_path)
  if (is.na(sim_output_path) || !file.exists(sim_output_path)) return(as.integer(default))
  obj <- readRDS(sim_output_path)
  as.integer(obj$info$params$period %||% default)[1]
}

dynamic_status_path_original288_exactspec_multiseed <- function(run_root, model, tau_label) {
  file.path(run_root, "logs", sprintf("%s_tau_%s.status.tsv", model, tau_label))
}

dynamic_df_from_source_original288_exactspec_multiseed <- function(source_cfg, source_row) {
  if (is.finite(safe_num_original288_exactspec_multiseed(source_cfg$df_value, NA_real_))) {
    return(safe_num_original288_exactspec_multiseed(source_cfg$df_value, 0.98))
  }

  run_root <- resolve_existing_path_original288_exactspec_multiseed(source_cfg$out_root %||% source_row$source_run_root %||% NA_character_)
  if (is.na(run_root)) return(0.98)

  status_path <- dynamic_status_path_original288_exactspec_multiseed(
    run_root = run_root,
    model = source_row$model,
    tau_label = source_row$tau
  )
  extract_dynamic_df_original288_normalized_multiseed(status_path, default = 0.98)
}

source_seed_from_config_original288_exactspec_multiseed <- function(source_cfg, source_row) {
  source_seed <- safe_int_original288_exactspec_multiseed(source_cfg$fit_seed %||% source_row$source_seed, NA_integer_)
  if (is.finite(source_seed)) return(source_seed)

  selected_seed <- extract_seed_from_fit_original288_normalized_multiseed(source_row$selected_fit_path)
  if (is.finite(selected_seed)) return(selected_seed)

  hash_seed_original288_exactspec_multiseed(source_row$original_case_key)
}

unified_flat_config_original288_exactspec_multiseed <- function(source_cfg,
                                                                source_row,
                                                                kind,
                                                                row_id,
                                                                seed_slot,
                                                                seed) {
  style <- source_config_style_original288_exactspec_multiseed(source_cfg)
  if (identical(style, "unknown")) {
    stop(sprintf("Unsupported source config style for %s", source_row$original_case_key))
  }

  if (identical(style, "flat")) {
    cfg <- source_cfg
    cfg$source_config_style <- "flat"
    cfg$source_run_config_path <- source_row$run_config_path
    cfg$source_config_csv <- source_row$csv_path
    cfg$base_row_id <- as.integer(source_row$base_row_id)
    cfg$original_case_key <- source_row$original_case_key
    cfg$selected_source_type <- source_row$selected_source_type
    cfg$selected_source_subtype <- source_row$selected_source_subtype
    cfg$selected_variant_tag_source <- source_row$selected_variant_tag
    cfg$row_id <- as.integer(row_id)
    cfg$fit_seed <- as.integer(seed)
    cfg$seed_slot <- as.integer(seed_slot)
    cfg$phase <- phase_for_row_original288_exactspec_multiseed(source_row$block, source_row$inference)
    cfg$phase_order <- unname(phase_order_original288_exactspec_multiseed[cfg$phase])
    cfg$lane_label <- "exactspec_multiseed_relaunch"
    cfg$run_root <- map_to_current_repo_root_original288_exactspec_multiseed(cfg$run_root)
    cfg$data_dir <- resolve_existing_path_original288_exactspec_multiseed(cfg$data_dir)
    cfg$series_wide_path <- resolve_existing_path_original288_exactspec_multiseed(cfg$series_wide_path)
    cfg$coef_truth_path <- resolve_existing_path_original288_exactspec_multiseed(cfg$coef_truth_path)
    cfg$true_quantile_grid_path <- resolve_existing_path_original288_exactspec_multiseed(cfg$true_quantile_grid_path)
    cfg$selection_indices_path <- resolve_existing_path_original288_exactspec_multiseed(cfg$selection_indices_path)
    cfg$fit_path <- candidate_fit_path_original288_exactspec_multiseed(cfg$run_root, cfg$inference, cfg$model, cfg$tau_label, seed_slot)
    cfg$config_path <- config_path_original288_exactspec_multiseed(kind, row_id)
    cfg$row_status_path <- row_status_path_original288_exactspec_multiseed(kind, row_id)
    cfg$health_path <- health_path_original288_exactspec_multiseed(kind, row_id)
    cfg$metrics_path <- metrics_path_original288_exactspec_multiseed(kind, row_id)
    cfg$draws_path <- draws_path_original288_exactspec_multiseed(kind, row_id)
    cfg$stored_posterior_draws <- 20000L
    if (identical(cfg$inference, "mcmc")) {
      cfg$n_burn <- 5000L
      cfg$n_mcmc <- 20000L
    }
    return(cfg)
  }

  run_root <- map_to_current_repo_root_original288_exactspec_multiseed(source_cfg$out_root)
  tau_label <- safe_chr_original288_exactspec_multiseed(source_row$tau, safe_chr_original288_exactspec_multiseed(source_row$tau_label, NA_character_))
  tau_num <- suppressWarnings(as.numeric(gsub("p", ".", tau_label, fixed = TRUE)))

  cfg <- list(
    row_id = as.integer(row_id),
    base_row_id = as.integer(source_row$base_row_id),
    original_case_key = source_row$original_case_key,
    source_config_style = "nested",
    source_run_config_path = source_row$run_config_path,
    source_config_csv = source_row$csv_path,
    selected_source_type = source_row$selected_source_type,
    selected_source_subtype = source_row$selected_source_subtype,
    selected_variant_tag_source = source_row$selected_variant_tag,
    tag = run_tag_original288_exactspec_multiseed(),
    phase = phase_for_row_original288_exactspec_multiseed(source_row$block, source_row$inference),
    phase_order = unname(phase_order_original288_exactspec_multiseed[phase_for_row_original288_exactspec_multiseed(source_row$block, source_row$inference)]),
    lane_label = "exactspec_multiseed_relaunch",
    block = source_row$block,
    root_kind = source_row$root_kind,
    family = source_row$family,
    tau = tau_num,
    tau_label = tau_label,
    fit_size = as.integer(source_row$fit_size),
    prior_semantics = source_row$prior_semantics,
    model = source_row$model,
    inference = source_row$inference,
    dqlm_ind = source_row$model %in% c("al", "dqlm"),
    fit_seed = as.integer(seed),
    seed_slot = as.integer(seed_slot),
    run_root = run_root,
    fit_path = candidate_fit_path_original288_exactspec_multiseed(run_root, source_row$inference, source_row$model, tau_label, seed_slot),
    config_path = config_path_original288_exactspec_multiseed(kind, row_id),
    row_status_path = row_status_path_original288_exactspec_multiseed(kind, row_id),
    health_path = health_path_original288_exactspec_multiseed(kind, row_id),
    metrics_path = metrics_path_original288_exactspec_multiseed(kind, row_id),
    draws_path = draws_path_original288_exactspec_multiseed(kind, row_id),
    stored_posterior_draws = 20000L
  )

  if (identical(source_row$block, "dynamic")) {
    dctx <- dynamic_source_context_original288_normalized_multiseed(source_row)
    cfg$sim_output_path <- resolve_existing_path_original288_exactspec_multiseed(dctx$materialized_sim_output_path)
    if (is.na(cfg$sim_output_path)) {
      cfg$sim_output_path <- resolve_existing_path_original288_exactspec_multiseed(source_cfg$sim_path)
    }
    cfg$period <- period_from_sim_output_original288_exactspec_multiseed(cfg$sim_output_path, default = 50L)
    cfg$df_value <- dynamic_df_from_source_original288_exactspec_multiseed(source_cfg, source_row)
    cfg$dim_df <- c(2L, 4L)
    cfg$vb <- source_cfg$vb %||% list()
    cfg$vb_method <- safe_chr_original288_exactspec_multiseed(cfg$vb$method, "ldvb")
    cfg$vb_tol <- safe_num_original288_exactspec_multiseed(cfg$vb$tol, 0.03)
    cfg$vb_n_samp_internal <- safe_int_original288_exactspec_multiseed(cfg$vb$n_samp, 1000L)
    cfg$vb_max_iter <- safe_int_original288_exactspec_multiseed(cfg$vb$max_iter, 1200L)
    cfg$vb_tol_sigma <- safe_num_original288_exactspec_multiseed(cfg$vb$tol_sigma %||% cfg$vb$conv$tol_sigma, cfg$vb_tol)
    cfg$vb_tol_gamma <- safe_num_original288_exactspec_multiseed(cfg$vb$tol_gamma %||% cfg$vb$conv$tol_gamma, cfg$vb_tol)
    cfg$vb_tol_elbo <- safe_num_original288_exactspec_multiseed(cfg$vb$tol_elbo %||% cfg$vb$conv$tol_elbo, 1e-6)
    cfg$vb_min_iter <- safe_int_original288_exactspec_multiseed(cfg$vb$min_iter %||% cfg$vb$conv$min_iter, 10L)
    cfg$vb_patience <- safe_int_original288_exactspec_multiseed(cfg$vb$patience %||% cfg$vb$conv$patience, 3L)
    cfg$vb_allow_elbo_drop <- safe_num_original288_exactspec_multiseed(cfg$vb$allow_elbo_drop %||% cfg$vb$conv$allow_elbo_drop, 1e-5)
    cfg$ld_controls <- cfg$vb$ld %||% list()

    mc <- source_cfg$mcmc %||% list()
    mh <- mc$mh %||% list()
    cfg$n_burn <- 5000L
    cfg$n_mcmc <- 20000L
    cfg$source_has_init_from_vb <- "init_from_vb" %in% names(mc)
    cfg$source_has_init_from_isvb <- "init_from_isvb" %in% names(mc)
    cfg$legacy_mcmc_init_default <- !cfg$source_has_init_from_vb && !cfg$source_has_init_from_isvb
    cfg$init_from_vb <- if (cfg$source_has_init_from_vb) {
      as_flag_original288_exactspec_multiseed(mc[["init_from_vb"]], TRUE)
    } else {
      NA
    }
    cfg$init_from_isvb <- if (cfg$source_has_init_from_isvb) {
      as_flag_original288_exactspec_multiseed(mc[["init_from_isvb"]], FALSE)
    } else {
      cfg$legacy_mcmc_init_default
    }
    cfg$trace_every <- safe_int_original288_exactspec_multiseed(mc$trace_every %||% mh$trace_every, 50L)
    cfg$mh_proposal <- safe_chr_original288_exactspec_multiseed(mh$proposal %||% mh$primary_proposal, "laplace_rw")
    cfg$mh_joint_sample <- as_flag_original288_exactspec_multiseed(mh$joint_sample %||% mh$primary_joint_sample, FALSE)
    cfg$source_has_mh_adapt <- "adapt" %in% names(mh)
    cfg$mh_adapt <- if (cfg$source_has_mh_adapt) {
      as_flag_original288_exactspec_multiseed(mh[["adapt"]], TRUE)
    } else {
      NA
    }
    cfg$mh_adapt_interval <- safe_int_original288_exactspec_multiseed(mh$adapt_interval, 50L)
    cfg$mh_target_accept <- as.numeric(mh$target_accept %||% c(0.20, 0.45))
    cfg$mh_scale_bounds <- as.numeric(mh$scale_bounds %||% c(0.1, 10))
    cfg$mh_max_scale_step <- safe_num_original288_exactspec_multiseed(mh$max_scale_step, 0.35)
    cfg$mh_min_burn_adapt <- safe_int_original288_exactspec_multiseed(mh$min_burn_adapt, 50L)
    cfg$slice_width <- safe_num_original288_exactspec_multiseed(mh$slice_width, NA_real_)
    cfg$slice_max_steps <- safe_int_original288_exactspec_multiseed(mh$slice_max_steps, NA_integer_)
    cfg$laplace_refresh_interval <- safe_int_original288_exactspec_multiseed(mh$laplace_refresh_interval, NA_integer_)
    cfg$laplace_refresh_start <- safe_int_original288_exactspec_multiseed(mh$laplace_refresh_start, NA_integer_)
    cfg$laplace_refresh_weight <- safe_num_original288_exactspec_multiseed(mh$laplace_refresh_weight, NA_real_)
  } else {
    cfg$data_dir <- data_dir_from_sim_path_original288_exactspec_multiseed(source_cfg$sim_path)
    cfg$series_wide_path <- normalize_path_original288(file.path(cfg$data_dir, "series_wide.csv"))
    cfg$coef_truth_path <- normalize_path_original288(file.path(cfg$data_dir, "coef_truth.csv"))
    cfg$true_quantile_grid_path <- normalize_path_original288(file.path(cfg$data_dir, "true_quantile_grid.csv"))
    cfg$selection_indices_path <- normalize_path_original288(file.path(cfg$data_dir, "selection_indices.csv"))

    vb <- source_cfg$vb %||% list()
    mc <- source_cfg$mcmc %||% list()
    mh <- mc$mh %||% list()

    cfg$beta_prior <- safe_chr_original288_exactspec_multiseed(
      if (identical(source_row$inference, "vb")) vb$beta_prior else mc$beta_prior,
      safe_chr_original288_exactspec_multiseed(
        if (identical(source_row$prior_semantics, "paper")) "ridge" else source_row$prior_semantics,
        "ridge"
      )
    )
    cfg$beta_prior_controls <- if (identical(source_row$inference, "vb")) {
      vb$beta_prior_controls %||% NULL
    } else {
      mc$beta_prior_controls %||% vb$beta_prior_controls %||% NULL
    }

    cfg$max_iter <- safe_int_original288_exactspec_multiseed(vb$max_iter, 300L)
    cfg$tol <- safe_num_original288_exactspec_multiseed(vb$tol, 0.03)
    cfg$n_samp_xi <- safe_int_original288_exactspec_multiseed(vb$n_samp_xi %||% vb$n_samp, 1000L)
    cfg$ld_controls <- vb$ld %||% list()
    cfg$n_burn <- 5000L
    cfg$n_mcmc <- 20000L
    cfg$thin <- safe_int_original288_exactspec_multiseed(mc$thin, 1L)
    cfg$source_has_init_from_vb <- "init_from_vb" %in% names(mc)
    cfg$source_has_init_from_isvb <- "init_from_isvb" %in% names(mc)
    cfg$legacy_mcmc_init_default <- !cfg$source_has_init_from_vb && !cfg$source_has_init_from_isvb
    cfg$init_from_vb <- if (cfg$source_has_init_from_vb) {
      as_flag_original288_exactspec_multiseed(mc[["init_from_vb"]], TRUE)
    } else {
      NA
    }
    cfg$init_from_isvb <- if (cfg$source_has_init_from_isvb) {
      as_flag_original288_exactspec_multiseed(mc[["init_from_isvb"]], FALSE)
    } else {
      cfg$legacy_mcmc_init_default
    }
    cfg$vb_init_controls <- mc$vb_init_controls %||% list(
      max_iter = safe_int_original288_exactspec_multiseed(vb$max_iter, 300L),
      tol = safe_num_original288_exactspec_multiseed(vb$tol, 0.03),
      n_samp_xi = safe_int_original288_exactspec_multiseed(vb$n_samp_xi %||% vb$n_samp, 1000L),
      ld_controls = vb$ld %||% NULL,
      verbose = FALSE
    )
    cfg$mh_proposal <- safe_chr_original288_exactspec_multiseed(mh$proposal %||% mh$primary_proposal, "laplace_rw")
    cfg$source_has_mh_adapt <- "adapt" %in% names(mh)
    cfg$mh_adapt <- if (cfg$source_has_mh_adapt) {
      as_flag_original288_exactspec_multiseed(mh[["adapt"]], TRUE)
    } else {
      NA
    }
    cfg$mh_adapt_interval <- safe_int_original288_exactspec_multiseed(mh$adapt_interval, 50L)
    cfg$mh_target_accept <- as.numeric(mh$target_accept %||% c(0.20, 0.45))
    cfg$mh_scale_bounds <- as.numeric(mh$scale_bounds %||% c(0.1, 10))
    cfg$mh_max_scale_step <- safe_num_original288_exactspec_multiseed(mh$max_scale_step, 0.35)
    cfg$mh_min_burn_adapt <- safe_int_original288_exactspec_multiseed(mh$min_burn_adapt, 50L)
    cfg$trace_diagnostics <- as_flag_original288_exactspec_multiseed(mh$trace_diagnostics, TRUE)
    cfg$slice_width <- safe_num_original288_exactspec_multiseed(mh$slice_width, NA_real_)
    cfg$slice_max_steps <- safe_int_original288_exactspec_multiseed(mh$slice_max_steps, NA_integer_)
    cfg$gamma_substeps <- safe_int_original288_exactspec_multiseed(mh$gamma_substeps, NA_integer_)
    cfg$p_global_eta_jump <- safe_num_original288_exactspec_multiseed(mh$p_global_eta_jump, NA_real_)
    cfg$global_eta_jump_scale <- safe_num_original288_exactspec_multiseed(mh$global_eta_jump_scale, NA_real_)
    cfg$laplace_refresh_interval <- safe_int_original288_exactspec_multiseed(mh$laplace_refresh_interval, NA_integer_)
    cfg$laplace_refresh_start <- safe_int_original288_exactspec_multiseed(mh$laplace_refresh_start, NA_integer_)
    cfg$laplace_refresh_weight <- safe_num_original288_exactspec_multiseed(mh$laplace_refresh_weight, NA_real_)
    cfg$trace_every <- safe_int_original288_exactspec_multiseed(mc$trace_every %||% mh$trace_every, 50L)
    cfg$progress_every <- 50L
  }

  cfg
}

smoke_case_keys_original288_exactspec_multiseed <- function(selection) {
  want <- list(
    c("static_paper", "mcmc", "al"),
    c("static_paper", "mcmc", "exal"),
    c("static_paper", "vb", "al"),
    c("static_paper", "vb", "exal"),
    c("static_shrink", "mcmc", "al"),
    c("static_shrink", "mcmc", "exal"),
    c("static_shrink", "vb", "al"),
    c("static_shrink", "vb", "exal"),
    c("dynamic", "mcmc", "dqlm"),
    c("dynamic", "mcmc", "exdqlm"),
    c("dynamic", "vb", "dqlm"),
    c("dynamic", "vb", "exdqlm")
  )
  keys <- character(0)
  for (triple in want) {
    hit <- selection[
      selection$block == triple[1] &
        selection$inference == triple[2] &
        selection$model == triple[3],
      ,
      drop = FALSE
    ]
    if (nrow(hit)) keys <- c(keys, hit$original_case_key[1])
  }
  unique(keys)
}

build_manifest_original288_exactspec_multiseed <- function(selection,
                                                            kind = c("smoke", "full"),
                                                            repo_root) {
  kind <- match.arg(kind)
  config_index <- source_config_index_original288_exactspec_multiseed()

  if (!"base_row_id" %in% names(selection)) selection$base_row_id <- seq_len(nrow(selection))
  selection$tau_label <- selection$tau
  selection$tau_num <- suppressWarnings(as.numeric(gsub("p", ".", selection$tau_label, fixed = TRUE)))

  resolved <- lapply(seq_len(nrow(selection)), function(i) {
    resolve_source_row_original288_exactspec_multiseed(selection[i, , drop = FALSE], config_index = config_index)
  })
  resolved_df <- do.call(rbind, resolved)
  rownames(resolved_df) <- NULL

  manifest_rows <- list()
  seedbank_rows <- list()
  audit_rows <- list()
  j <- 1L

  for (i in seq_len(nrow(resolved_df))) {
    row <- resolved_df[i, , drop = FALSE]
    source_cfg <- readRDS(row$run_config_path)
    source_seed <- source_seed_from_config_original288_exactspec_multiseed(source_cfg, row)
    seeds <- seed_vector_original288_exactspec_multiseed(source_seed)

    audit_rows[[i]] <- data.frame(
      base_row_id = row$base_row_id,
      original_case_key = row$original_case_key,
      selected_source_type = row$selected_source_type,
      selected_source_subtype = row$selected_source_subtype,
      selected_variant_tag = row$selected_variant_tag,
      source_config_csv = row$csv_path,
      source_run_config_path = row$run_config_path,
      source_config_style = source_config_style_original288_exactspec_multiseed(source_cfg),
      resolution_score = row$resolution_score,
      source_seed = source_seed,
      seed_1 = seeds[1],
      seed_2 = seeds[2],
      seed_3 = seeds[3],
      seed_4 = seeds[4],
      stringsAsFactors = FALSE
    )

    for (slot in seq_along(seeds)) {
      cfg <- unified_flat_config_original288_exactspec_multiseed(
        source_cfg = source_cfg,
        source_row = row,
        kind = kind,
        row_id = j,
        seed_slot = slot,
        seed = seeds[slot]
      )
      saveRDS(cfg, cfg$config_path)

      missing_inputs <- if (identical(cfg$block, "dynamic")) {
        !file.exists(cfg$sim_output_path)
      } else {
        any(!file.exists(c(
          cfg$series_wide_path,
          cfg$coef_truth_path,
          cfg$selection_indices_path,
          cfg$true_quantile_grid_path
        )))
      }

      manifest_rows[[j]] <- data.frame(
        row_id = j,
        base_row_id = row$base_row_id,
        original_case_key = row$original_case_key,
        pair_id = paste(row$original_case_key, sprintf("seed%02d", slot), sep = "::"),
        seed_slot = slot,
        seed = as.integer(seeds[slot]),
        status = "pending",
        phase = cfg$phase,
        phase_order = cfg$phase_order,
        missing_inputs = missing_inputs,
        block = cfg$block,
        root_kind = cfg$root_kind,
        family = cfg$family,
        tau = cfg$tau,
        tau_label = cfg$tau_label,
        fit_size = cfg$fit_size,
        prior_semantics = row$prior_semantics,
        model = cfg$model,
        inference = cfg$inference,
        source_config_style = cfg$source_config_style,
        selected_source_type = row$selected_source_type,
        selected_source_subtype = row$selected_source_subtype,
        selected_variant_tag = row$selected_variant_tag,
        source_config_csv = row$csv_path,
        source_run_config_path = row$run_config_path,
        accepted_gate = row$gate_overall,
        accepted_healthy = isTRUE(row$healthy),
        gate_rank_baseline = gate_rank_original288_exactspec_multiseed(row$gate_overall),
        config_path = cfg$config_path,
        run_root = cfg$run_root,
        candidate_fit_path = cfg$fit_path,
        row_status_path = cfg$row_status_path,
        health_path = cfg$health_path,
        metrics_path = cfg$metrics_path,
        draws_path = cfg$draws_path,
        stored_posterior_draws = 20000L,
        stringsAsFactors = FALSE
      )

      seedbank_rows[[j]] <- data.frame(
        base_row_id = row$base_row_id,
        original_case_key = row$original_case_key,
        seed_slot = slot,
        seed = as.integer(seeds[slot]),
        phase = cfg$phase,
        stringsAsFactors = FALSE
      )
      j <- j + 1L
    }
  }

  manifest <- do.call(rbind, manifest_rows)
  rownames(manifest) <- NULL
  manifest <- manifest[order(
    manifest$phase_order,
    manifest$block,
    manifest$family,
    manifest$tau_label,
    manifest$fit_size,
    manifest$model,
    manifest$inference,
    manifest$seed_slot
  ), , drop = FALSE]
  manifest$row_id <- seq_len(nrow(manifest))

  old_cfg_paths <- manifest$config_path
  cfg_cache <- lapply(old_cfg_paths, readRDS)
  unlink(unique(old_cfg_paths), force = TRUE)

  for (i in seq_len(nrow(manifest))) {
    cfg <- cfg_cache[[i]]
    cfg$row_id <- manifest$row_id[i]
    cfg$config_path <- config_path_original288_exactspec_multiseed(kind, manifest$row_id[i])
    cfg$row_status_path <- row_status_path_original288_exactspec_multiseed(kind, manifest$row_id[i])
    cfg$health_path <- health_path_original288_exactspec_multiseed(kind, manifest$row_id[i])
    cfg$metrics_path <- metrics_path_original288_exactspec_multiseed(kind, manifest$row_id[i])
    cfg$draws_path <- draws_path_original288_exactspec_multiseed(kind, manifest$row_id[i])
    saveRDS(cfg, cfg$config_path)
    manifest$config_path[i] <- cfg$config_path
    manifest$row_status_path[i] <- cfg$row_status_path
    manifest$health_path[i] <- cfg$health_path
    manifest$metrics_path[i] <- cfg$metrics_path
    manifest$draws_path[i] <- cfg$draws_path
  }

  list(
    manifest = manifest,
    seedbank = do.call(rbind, seedbank_rows),
    audit = do.call(rbind, audit_rows),
    config_index = config_index
  )
}

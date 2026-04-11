#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_normalized_multiseed_helpers_20260411.R")

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)
paths <- paths_original288_normalized_multiseed()

ensure_dir_original288_normalized_multiseed(paths$run_root)
ensure_dir_original288_normalized_multiseed(paths$config_dir)
ensure_dir_original288_normalized_multiseed(paths$rows_dir)
ensure_dir_original288_normalized_multiseed(paths$health_dir)
ensure_dir_original288_normalized_multiseed(paths$metrics_dir)
ensure_dir_original288_normalized_multiseed(paths$draws_dir)
ensure_dir_original288_normalized_multiseed(paths$logs_dir)
ensure_dir_original288_normalized_multiseed(paths$dynamic_restored_dir)
ensure_dir_original288_normalized_multiseed(paths$dynamic_baseline_dir)
ensure_dir_original288_normalized_multiseed(dirname(paths$comparison_report))

selection <- read.csv(paths$selection, stringsAsFactors = FALSE, check.names = FALSE)
selection$base_row_id <- seq_len(nrow(selection))
selection$tau_label <- selection$tau
selection$tau_num <- suppressWarnings(as.numeric(gsub("p", ".", selection$tau_label, fixed = TRUE)))

derive_universe_row <- function(sel_row) {
  fit_path_raw <- safe_chr_original288_normalized_multiseed(sel_row$selected_fit_path, NA_character_)
  raw_run_root <- sub("/fits/.*$", "", fit_path_raw)
  source_run_root <- raw_run_root
  current_run_root <- map_to_current_repo_root_original288_normalized_multiseed(raw_run_root)
  resolved_source_run_root <- resolve_existing_path_original288_normalized_multiseed(source_run_root)

  baseline_seed <- extract_seed_from_fit_original288_normalized_multiseed(sel_row$selected_fit_path)
  if (!is.finite(baseline_seed)) baseline_seed <- hash_seed_original288_normalized_multiseed(sel_row$original_case_key)

  if (identical(sel_row$block, "dynamic")) {
    dctx <- dynamic_source_context_original288_normalized_multiseed(sel_row)
    sim_output_current <- file.path(current_run_root, "sim_output.rds")
    restored_sim_output <- file.path(paths$dynamic_restored_dir, sprintf("row_%04d_sim_output_restored.rds", sel_row$base_row_id))
    synthetic_baseline <- file.path(paths$dynamic_baseline_dir, sprintf("row_%04d_synthetic_baseline.rds", sel_row$base_row_id))
    data.frame(
      base_row_id = sel_row$base_row_id,
      original_case_key = sel_row$original_case_key,
      block = sel_row$block,
      root_kind = sel_row$root_kind,
      family = sel_row$family,
      tau = sel_row$tau_label,
      tau_label = sel_row$tau_label,
      tau_num = sel_row$tau_num,
      fit_size = as.integer(sel_row$fit_size),
      prior_semantics = sel_row$prior_semantics,
      model = sel_row$model,
      inference = sel_row$inference,
      method = sel_row$method,
      source_run_root = source_run_root,
      resolved_source_run_root = resolved_source_run_root,
      current_run_root = current_run_root,
      data_dir = dctx$source_fit_input_dir,
      series_wide_path = dctx$source_series_wide_path,
      selection_indices_path = dctx$source_selection_indices_path,
      true_quantile_grid_path = dctx$source_true_quantile_grid_path,
      coef_truth_path = NA_character_,
      sim_output_path = if (file.exists(sim_output_current)) sim_output_current else restored_sim_output,
      sim_output_existing_path = resolve_existing_path_original288_normalized_multiseed(file.path(source_run_root, "../sim_output.rds")),
      restored_sim_output_path = restored_sim_output,
      materialized_source_dir = dctx$materialized_source_dir,
      materialized_sim_output_path = dctx$materialized_sim_output_path,
      synthetic_baseline_path = synthetic_baseline,
      baseline_seed = baseline_seed,
      selected_fit_path = sel_row$selected_fit_path,
      selected_summary_path = sel_row$selected_summary_path,
      gate_overall = sel_row$gate_overall,
      healthy = isTRUE(sel_row$healthy),
      data_ready = file.exists(dctx$source_series_wide_path) &&
        file.exists(dctx$source_selection_indices_path) &&
        file.exists(dctx$source_true_quantile_grid_path) &&
        file.exists(dctx$materialized_sim_output_path),
      stringsAsFactors = FALSE
    )
  } else {
    data_dir_raw <- dirname(raw_run_root)
    data_dir <- resolve_existing_path_original288_normalized_multiseed(data_dir_raw)
    if (is.na(data_dir)) data_dir <- data_dir_raw
    series_wide_path <- resolve_existing_path_original288_normalized_multiseed(file.path(data_dir, "series_wide.csv"))
    selection_indices_path <- resolve_existing_path_original288_normalized_multiseed(file.path(data_dir, "selection_indices.csv"))
    true_quantile_grid_path <- resolve_existing_path_original288_normalized_multiseed(file.path(data_dir, "true_quantile_grid.csv"))
    coef_truth_path <- resolve_existing_path_original288_normalized_multiseed(file.path(data_dir, "coef_truth.csv"))
    data.frame(
      base_row_id = sel_row$base_row_id,
      original_case_key = sel_row$original_case_key,
      block = sel_row$block,
      root_kind = sel_row$root_kind,
      family = sel_row$family,
      tau = sel_row$tau_label,
      tau_label = sel_row$tau_label,
      tau_num = sel_row$tau_num,
      fit_size = as.integer(sel_row$fit_size),
      prior_semantics = sel_row$prior_semantics,
      model = sel_row$model,
      inference = sel_row$inference,
      method = sel_row$method,
      source_run_root = source_run_root,
      resolved_source_run_root = resolved_source_run_root,
      current_run_root = current_run_root,
      data_dir = data_dir,
      series_wide_path = series_wide_path,
      selection_indices_path = selection_indices_path,
      true_quantile_grid_path = true_quantile_grid_path,
      coef_truth_path = coef_truth_path,
      sim_output_path = NA_character_,
      sim_output_existing_path = NA_character_,
      restored_sim_output_path = NA_character_,
      materialized_source_dir = NA_character_,
      materialized_sim_output_path = NA_character_,
      synthetic_baseline_path = NA_character_,
      baseline_seed = baseline_seed,
      selected_fit_path = sel_row$selected_fit_path,
      selected_summary_path = sel_row$selected_summary_path,
      gate_overall = sel_row$gate_overall,
      healthy = isTRUE(sel_row$healthy),
      data_ready = !is.na(series_wide_path) &&
        !is.na(selection_indices_path) &&
        !is.na(true_quantile_grid_path) &&
        !is.na(coef_truth_path),
      stringsAsFactors = FALSE
    )
  }
}

universe <- do.call(rbind, lapply(seq_len(nrow(selection)), function(i) derive_universe_row(selection[i, , drop = FALSE])))
universe$seed_1 <- seed_vector_original288_normalized_multiseed(universe$baseline_seed)[1]
universe$seed_2 <- seed_vector_original288_normalized_multiseed(universe$baseline_seed)[2]
universe$seed_3 <- seed_vector_original288_normalized_multiseed(universe$baseline_seed)[3]
universe$seed_4 <- seed_vector_original288_normalized_multiseed(universe$baseline_seed)[4]
utils::write.csv(universe, paths$universe, row.names = FALSE)

control_audit <- data.frame(
  base_row_id = universe$base_row_id,
  original_case_key = universe$original_case_key,
  block = universe$block,
  family = universe$family,
  tau_label = universe$tau_label,
  fit_size = universe$fit_size,
  prior_semantics = universe$prior_semantics,
  model = universe$model,
  inference = universe$inference,
  selected_fit_exists = !is.na(vapply(universe$selected_fit_path, resolve_existing_path_original288_normalized_multiseed, character(1))),
  source_run_root_exists = !is.na(vapply(universe$source_run_root, resolve_existing_path_original288_normalized_multiseed, character(1))),
  series_wide_exists = file.exists(universe$series_wide_path),
  selection_indices_exists = file.exists(universe$selection_indices_path),
  true_quantile_grid_exists = file.exists(universe$true_quantile_grid_path),
  coef_truth_exists = ifelse(universe$block == "dynamic", NA, file.exists(universe$coef_truth_path)),
  materialized_sim_exists = ifelse(universe$block == "dynamic", file.exists(universe$materialized_sim_output_path), NA),
  data_ready = universe$data_ready,
  baseline_seed = universe$baseline_seed,
  stringsAsFactors = FALSE
)
utils::write.csv(control_audit, paths$control_audit, row.names = FALSE)

seed_rows <- vector("list", nrow(universe) * 4L)
k <- 1L
for (i in seq_len(nrow(universe))) {
  row <- universe[i, , drop = FALSE]
  seeds <- seed_vector_original288_normalized_multiseed(row$baseline_seed)
  for (slot in seq_along(seeds)) {
    phase_full <- phase_for_row_original288_normalized_multiseed(row$block, row$inference, pilot = FALSE)
    phase_pilot <- phase_for_row_original288_normalized_multiseed(row$block, row$inference, pilot = TRUE)
    seed_rows[[k]] <- data.frame(
      base_row_id = row$base_row_id,
      original_case_key = row$original_case_key,
      seed_slot = slot,
      seed = as.integer(seeds[slot]),
      pilot_phase = phase_pilot,
      full_phase = phase_full,
      stringsAsFactors = FALSE
    )
    k <- k + 1L
  }
}
seedbank <- do.call(rbind, seed_rows)
seedbank <- merge(seedbank, universe, by = c("base_row_id", "original_case_key"), sort = FALSE)
seedbank <- seedbank[order(seedbank$base_row_id, seedbank$seed_slot), , drop = FALSE]
utils::write.csv(seedbank, paths$seedbank, row.names = FALSE)

pilot_keys <- pilot_case_keys_original288_normalized_multiseed(selection)

build_manifest <- function(seedbank_df, pilot = FALSE) {
  x <- if (pilot) {
    seedbank_df[seedbank_df$original_case_key %in% pilot_keys, , drop = FALSE]
  } else {
    seedbank_df
  }
  if (!nrow(x)) return(data.frame())
  x$phase <- if (pilot) x$pilot_phase else x$full_phase
  x$phase_order <- unname(phase_order_original288_normalized_multiseed[x$phase])
  x$runner_kind <- ifelse(x$block == "dynamic", "dynamic_generic", "static_native")
  x$tag <- run_tag_original288_normalized_multiseed()
  x$selection_mode <- "normalized_multiseed_relaunch"
  x$study_row_key <- x$original_case_key
  x$pair_id <- sprintf("%s::seed%02d", x$original_case_key, x$seed_slot)
  x$row_id <- seq_len(nrow(x))
  x$candidate_label <- sprintf("%s_seed%02d", variant_tag_original288_normalized_multiseed(), x$seed_slot)
  x$run_root <- x$current_run_root
  x$candidate_fit_path <- vapply(seq_len(nrow(x)), function(i) {
    inf <- x$inference[i]
    mdl <- x$model[i]
    tau_label <- x$tau_label[i]
    run_root <- x$run_root[i]
    file.path(run_root, "fits", inf, sprintf("%s_%s_tau_%s_fit_%s_seed%02d.rds", inf, mdl, tau_label, variant_tag_original288_normalized_multiseed(), x$seed_slot[i]))
  }, character(1))
  x$config_path <- file.path(paths$config_dir, sprintf("%s_row_%04d_config.rds", if (pilot) "pilot" else "full", x$row_id))
  x$row_status_path <- file.path(paths$rows_dir, sprintf("%s_row_%04d.csv", if (pilot) "pilot" else "full", x$row_id))
  x$health_path <- file.path(paths$health_dir, sprintf("%s_health_%04d.csv", if (pilot) "pilot" else "full", x$row_id))
  x$metrics_path <- file.path(paths$metrics_dir, sprintf("%s_metrics_%04d.csv", if (pilot) "pilot" else "full", x$row_id))
  x$draws_path <- file.path(paths$draws_dir, sprintf("%s_draws_%04d.rds", if (pilot) "pilot" else "full", x$row_id))
  x$missing_inputs <- !x$data_ready
  x$n_posterior_draws <- 20000L
  x$stored_posterior_draws <- 20000L
  x$n_burn <- ifelse(x$inference == "mcmc", 5000L, NA_integer_)
  x$n_mcmc <- ifelse(x$inference == "mcmc", 20000L, NA_integer_)
  x$thin <- ifelse(x$inference == "mcmc", 1L, NA_integer_)
  x$vb_n_samp <- ifelse(x$inference == "vb" & x$block == "dynamic", 20000L, NA_integer_)
  x$seed_rank_gate <- gate_rank_original288_normalized_multiseed(x$gate_overall)
  x
}

pilot_manifest <- build_manifest(seedbank, pilot = TRUE)
full_manifest <- build_manifest(seedbank, pilot = FALSE)

write_configs <- function(manifest_df) {
  if (!nrow(manifest_df)) return(invisible(NULL))
  for (i in seq_len(nrow(manifest_df))) {
    row <- manifest_df[i, , drop = FALSE]
    if (identical(row$runner_kind, "dynamic_generic")) {
      if (!file.exists(row$restored_sim_output_path)) {
        restore_dynamic_sim_output_original288_normalized_multiseed(row, row$restored_sim_output_path)
      }
      build_dynamic_synthetic_baseline_original288_normalized_multiseed(row, row$synthetic_baseline_path)
      cfg <- list(
        vb = list(method = "ldvb", tol = 0.1, n_samp = 20000L, max_iter = 300L),
        mcmc = list(
          burn = 5000L,
          n = 20000L,
          init_from_vb = TRUE,
          init_from_isvb = FALSE,
          mh = list(
            proposal = if (identical(row$inference, "vb")) NA_character_ else "laplace_rw",
            primary_proposal = if (identical(row$inference, "vb")) NA_character_ else "laplace_rw",
            joint_sample = FALSE,
            primary_joint_sample = FALSE,
            adapt = TRUE,
            adapt_interval = 50L,
            target_accept = c(0.20, 0.45),
            scale_bounds = c(0.1, 10),
            max_scale_step = 0.35,
            min_burn_adapt = 50L,
            trace_every = 50L
          )
        )
      )
      saveRDS(cfg, row$config_path)
    } else {
      fit_summary_row <- static_fit_summary_row_original288_normalized_multiseed(row)
      mcmc_diag_row <- static_mcmc_diag_row_original288_normalized_multiseed(row)
      beta_prior <- safe_chr_original288_normalized_multiseed(
        fit_summary_row$beta_prior %||% row$prior_semantics,
        if (identical(row$prior_semantics, "paper")) "ridge" else row$prior_semantics
      )
      mh_proposal <- safe_chr_original288_normalized_multiseed(mcmc_diag_row$mh_proposal, "laplace_rw")
      mh_adapt <- as_flag_original288_normalized_multiseed(mcmc_diag_row$mh_adapt, TRUE)
      mh_scale_final <- safe_num_original288_normalized_multiseed(mcmc_diag_row$mh_scale_final, 0.1)
      cfg <- list(
        row_id = as.integer(row$row_id),
        base_row_id = as.integer(row$base_row_id),
        tag = run_tag_original288_normalized_multiseed(),
        phase = row$phase,
        phase_order = row$phase_order,
        lane_label = if (startsWith(row$phase, "pilot")) "normalized_multiseed_pilot" else "normalized_multiseed_full",
        block = row$block,
        root_kind = row$root_kind,
        family = row$family,
        tau = as.numeric(row$tau_num),
        tau_label = row$tau_label,
        fit_size = as.integer(row$fit_size),
        model = row$model,
        inference = row$inference,
        beta_prior = beta_prior,
        dqlm_ind = identical(row$model, "al"),
        fit_seed = as.integer(row$seed),
        run_root = row$run_root,
        data_dir = row$data_dir,
        series_wide_path = row$series_wide_path,
        coef_truth_path = row$coef_truth_path,
        true_quantile_grid_path = row$true_quantile_grid_path,
        selection_indices_path = row$selection_indices_path,
        fit_path = row$candidate_fit_path,
        config_path = row$config_path,
        row_status_path = row$row_status_path,
        health_path = row$health_path,
        metrics_path = row$metrics_path,
        draws_path = row$draws_path,
        n_posterior_draws = 20000L,
        max_iter = 1000L,
        tol = 1e-4,
        n_samp_xi = 200L,
        ld_controls = list(store_trace = FALSE),
        n_burn = 5000L,
        n_mcmc = 20000L,
        thin = 1L,
        init_from_vb = TRUE,
        vb_init_controls = list(max_iter = 1000L, tol = 1e-4, n_samp_xi = 200L, verbose = FALSE),
        mh_proposal = mh_proposal,
        mh_adapt = mh_adapt,
        mh_scale_initial = mh_scale_final,
        slice_width = 0.10,
        slice_max_steps = 80L,
        gamma_substeps = 3L,
        p_global_eta_jump = 0.05,
        global_eta_jump_scale = 1,
        laplace_refresh_interval = 50L,
        laplace_refresh_start = 250L,
        laplace_refresh_weight = 0.60,
        trace_every = 50L,
        progress_every = 50L,
        requested_init_mode = "vb",
        resolved_init_mode = "vb"
      )
      saveRDS(cfg, row$config_path)
    }
  }
  invisible(NULL)
}

write_configs(pilot_manifest)
write_configs(full_manifest)

pilot_cols <- c(
  "row_id", "base_row_id", "original_case_key", "study_row_key", "pair_id", "phase", "phase_order", "runner_kind",
  "seed_slot", "seed", "missing_inputs", "block", "root_kind", "family", "tau", "tau_label",
  "fit_size", "prior_semantics", "model", "inference", "method", "gate_overall", "healthy",
  "run_root", "data_dir", "series_wide_path", "selection_indices_path", "true_quantile_grid_path",
  "coef_truth_path", "sim_output_path", "restored_sim_output_path", "synthetic_baseline_path",
  "config_path", "run_config_path", "baseline_fit_path", "candidate_fit_path", "row_status_path",
  "health_path", "metrics_path", "draws_path", "n_posterior_draws", "stored_posterior_draws",
  "n_burn", "n_mcmc", "thin", "vb_n_samp"
)

finalize_manifest <- function(df) {
  if (!nrow(df)) return(df)
  df$original_case_key <- df$study_row_key
  df$run_config_path <- df$config_path
  df$baseline_fit_path <- ifelse(df$runner_kind == "dynamic_generic", df$synthetic_baseline_path, NA_character_)
  df[, pilot_cols, drop = FALSE]
}

pilot_manifest_out <- finalize_manifest(pilot_manifest)
full_manifest_out <- finalize_manifest(full_manifest)

utils::write.csv(pilot_manifest_out, paths$pilot_manifest, row.names = FALSE)
utils::write.csv(full_manifest_out, paths$full_manifest, row.names = FALSE)

count_phase <- function(df) {
  out <- as.data.frame(table(df$phase), stringsAsFactors = FALSE)
  names(out) <- c("phase", "rows")
  out$phase_order <- unname(phase_order_original288_normalized_multiseed[out$phase])
  out[order(out$phase_order), c("phase", "rows"), drop = FALSE]
}

utils::write.csv(count_phase(pilot_manifest_out), paths$pilot_stage_counts, row.names = FALSE)
utils::write.csv(count_phase(full_manifest_out), paths$full_stage_counts, row.names = FALSE)

cat(sprintf("universe=%s\n", paths$universe))
cat(sprintf("seedbank=%s\n", paths$seedbank))
cat(sprintf("pilot_manifest=%s rows=%d\n", paths$pilot_manifest, nrow(pilot_manifest_out)))
cat(sprintf("full_manifest=%s rows=%d\n", paths$full_manifest, nrow(full_manifest_out)))
cat(sprintf("pilot_missing_inputs=%d\n", sum(pilot_manifest_out$missing_inputs)))
cat(sprintf("full_missing_inputs=%d\n", sum(full_manifest_out$missing_inputs)))

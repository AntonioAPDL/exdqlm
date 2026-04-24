source("tools/merge_reports/LOCAL_refreshed288_helpers_20260416.R")
source("tools/merge_reports/20260305_dynamic_dgp_model_helpers.R")

refreshed288_p90_tracker_path <- function() {
  "config/validation/refreshed288_p90_full288_relaunch_tracker_20260422.yaml"
}

refreshed288_p90_method_profile_path <- function() {
  "config/validation/refreshed288_p90_full288_method_profiles_20260422.csv"
}

refreshed288_p90_dynamic_registry_source_path <- function() {
  "tools/merge_reports/LOCAL_refreshed288_dataset_registry_20260422_dynamic_p90_steepertrend_v1.csv"
}

default_run_tag_refreshed288 <- function() {
  "20260422_p90_full288_baseline_v1"
}

run_tag_refreshed288 <- function() {
  tag_raw <- getOption(
    "refreshed288.run_tag",
    Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())
  )
  sprintf("refreshed288_%s", sanitize_tag_refreshed288(tag_raw))
}

variant_tag_refreshed288 <- function() {
  variant_raw <- getOption(
    "refreshed288.variant_tag",
    Sys.getenv(
      "REFRESHED288_VARIANT_TAG",
      unset = sprintf(
        "p90_ldvb_slice_%s",
        sanitize_tag_refreshed288(
          getOption(
            "refreshed288.run_tag",
            Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())
          )
        )
      )
    )
  )
  sprintf("refreshed288_%s", sanitize_tag_refreshed288(variant_raw))
}

report_stamp_refreshed288 <- function() {
  tag_raw <- sanitize_tag_refreshed288(
    getOption(
      "refreshed288.run_tag",
      Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())
    )
  )
  if (grepl("^[0-9]{8}([_-].*)?$", tag_raw)) {
    sub("^([0-9]{8}).*$", "\\1", tag_raw)
  } else {
    tag_raw
  }
}

paths_refreshed288 <- function() {
  raw_tag <- sanitize_tag_refreshed288(
    getOption(
      "refreshed288.run_tag",
      Sys.getenv("REFRESHED288_RUN_TAG", unset = default_run_tag_refreshed288())
    )
  )
  report_stamp <- report_stamp_refreshed288()
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_refreshed288_%s", raw_tag))
  list(
    dataset_registry = sprintf("tools/merge_reports/LOCAL_refreshed288_dataset_registry_%s.csv", raw_tag),
    method_registry = sprintf("tools/merge_reports/LOCAL_refreshed288_method_registry_%s.csv", raw_tag),
    smoke_manifest = sprintf("tools/merge_reports/LOCAL_refreshed288_smoke_manifest_%s.csv", raw_tag),
    full_manifest = sprintf("tools/merge_reports/LOCAL_refreshed288_full_manifest_%s.csv", raw_tag),
    smoke_stage_counts = sprintf("tools/merge_reports/LOCAL_refreshed288_smoke_stage_counts_%s.csv", raw_tag),
    full_stage_counts = sprintf("tools/merge_reports/LOCAL_refreshed288_full_stage_counts_%s.csv", raw_tag),
    smoke_manifest_status = sprintf("tools/merge_reports/LOCAL_refreshed288_smoke_manifest_status_%s.csv", raw_tag),
    full_manifest_status = sprintf("tools/merge_reports/LOCAL_refreshed288_full_manifest_status_%s.csv", raw_tag),
    smoke_phase_summary = sprintf("tools/merge_reports/LOCAL_refreshed288_smoke_phase_summary_%s.csv", raw_tag),
    full_phase_summary = sprintf("tools/merge_reports/LOCAL_refreshed288_full_phase_summary_%s.csv", raw_tag),
    smoke_method_summary = sprintf("tools/merge_reports/LOCAL_refreshed288_smoke_method_summary_%s.csv", raw_tag),
    full_method_summary = sprintf("tools/merge_reports/LOCAL_refreshed288_full_method_summary_%s.csv", raw_tag),
    smoke_report = sprintf("reports/static_exal_tuning_%s/refreshed288_p90_smoke_status_%s.md", report_stamp, raw_tag),
    full_report = sprintf("reports/static_exal_tuning_%s/refreshed288_p90_full_status_%s.md", report_stamp, raw_tag),
    spec_doc = sprintf("reports/static_exal_tuning_%s/refreshed288_p90_relaunch_spec_%s.md", report_stamp, raw_tag),
    run_contract = sprintf("tools/merge_reports/LOCAL_refreshed288_run_contract_%s.csv", raw_tag),
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

parse_csv_tokens_refreshed288 <- function(x) {
  if (is.null(x) || !length(x)) return(character(0))
  raw <- unlist(strsplit(paste(x, collapse = ","), ",", fixed = TRUE), use.names = FALSE)
  vals <- trimws(raw)
  vals[nzchar(vals)]
}

manifest_kind_from_path_refreshed288 <- function(manifest_path) {
  if (grepl("smoke_manifest", basename(manifest_path), fixed = TRUE)) "smoke" else "full"
}

status_path_for_manifest_refreshed288 <- function(manifest_path) {
  paths <- paths_refreshed288()
  if (identical(manifest_kind_from_path_refreshed288(manifest_path), "smoke")) {
    paths$smoke_manifest_status
  } else {
    paths$full_manifest_status
  }
}

select_row_ids_for_launch_refreshed288 <- function(manifest_path,
                                                   phase_filter = NULL,
                                                   status_filter = NULL,
                                                   outcome_filter = NULL,
                                                   filter_mode = c("all", "any"),
                                                   status_path = NULL) {
  filter_mode <- match.arg(filter_mode)
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  phase_vals <- parse_csv_tokens_refreshed288(phase_filter)
  if (length(phase_vals)) {
    manifest <- manifest[manifest$phase %in% phase_vals, , drop = FALSE]
  }
  if (!nrow(manifest)) return(integer(0))

  status_vals <- parse_csv_tokens_refreshed288(status_filter)
  outcome_vals <- parse_csv_tokens_refreshed288(outcome_filter)
  if (!length(status_vals) && !length(outcome_vals)) {
    return(as.integer(manifest$row_id))
  }

  status_path <- safe_chr_refreshed288(status_path, status_path_for_manifest_refreshed288(manifest_path))
  status_df <- safe_read_csv_refreshed288(status_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (is.null(status_df) || !nrow(status_df)) {
    status_lookup <- data.frame(
      row_id = manifest$row_id,
      status_current = rep("not_started", nrow(manifest)),
      gate_current = rep("", nrow(manifest)),
      stringsAsFactors = FALSE
    )
  } else {
    gate_col <- intersect(c("gate_current", "gate_overall_current", "gate_overall"), names(status_df))
    if (!length(gate_col)) {
      status_df$gate_current <- ""
      gate_col <- "gate_current"
    }
    status_lookup <- status_df[, c("row_id", "status_current", gate_col[1]), drop = FALSE]
    names(status_lookup) <- c("row_id", "status_current", "gate_current")
  }

  merged <- merge(
    manifest[, c("row_id", "phase", "phase_order"), drop = FALSE],
    status_lookup,
    by = "row_id",
    all.x = TRUE,
    sort = FALSE
  )
  merged$status_current[!nzchar(merged$status_current) | is.na(merged$status_current)] <- "not_started"
  merged$gate_current[!nzchar(merged$gate_current) | is.na(merged$gate_current)] <- ""

  status_match <- if (length(status_vals)) merged$status_current %in% status_vals else rep(FALSE, nrow(merged))
  outcome_match <- if (length(outcome_vals)) merged$gate_current %in% outcome_vals else rep(FALSE, nrow(merged))
  keep <- if (identical(filter_mode, "any")) {
    status_match | outcome_match
  } else {
    if (length(status_vals) && length(outcome_vals)) {
      status_match & outcome_match
    } else if (length(status_vals)) {
      status_match
    } else {
      outcome_match
    }
  }
  merged <- merged[keep, , drop = FALSE]
  if (!nrow(merged)) return(integer(0))
  merged <- merged[order(merged$phase_order, merged$row_id), , drop = FALSE]
  as.integer(merged$row_id)
}

tracker_refreshed288_p90 <- local({
  cache <- NULL
  function(force = FALSE) {
    if (!force && !is.null(cache)) return(cache)
    if (!requireNamespace("yaml", quietly = TRUE)) {
      stop("yaml package is required for refreshed288 p90 tracker loading", call. = FALSE)
    }
    cache <<- yaml::read_yaml(refreshed288_p90_tracker_path())
    cache
  }
})

method_profile_matrix_refreshed288_p90 <- local({
  cache <- NULL
  function(force = FALSE) {
    if (!force && !is.null(cache)) return(cache)
    out <- utils::read.csv(
      refreshed288_p90_method_profile_path(),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    rownames(out) <- NULL
    cache <<- out
    out
  }
})

parse_inf_num_refreshed288_p90 <- function(x, default = NA_real_) {
  if (is.null(x) || !length(x)) return(default)
  chr <- trimws(as.character(x)[1L])
  if (!nzchar(chr) || is.na(chr)) return(default)
  if (identical(chr, "Inf")) return(Inf)
  if (identical(chr, "-Inf")) return(-Inf)
  val <- suppressWarnings(as.numeric(chr))
  if (!is.finite(val) && !is.infinite(val)) default else val
}

parse_chr_na_refreshed288_p90 <- function(x, default = NA_character_) {
  chr <- safe_chr_refreshed288(x, default)
  if (is.na(chr) || !nzchar(chr) || identical(tolower(chr), "na")) default else chr
}

parse_bool_refreshed288_p90 <- function(x, default = FALSE) {
  if (is.null(x) || !length(x)) return(default)
  as_flag_refreshed288(x, default)
}

dynamic_meta_map_refreshed288_p90 <- local({
  cache <- NULL

  meta_value <- function(lines, key) {
    hit <- grep(sprintf("^%s:", key), lines, value = TRUE)
    if (!length(hit)) return(NA_character_)
    trimws(sub(sprintf("^%s:\\s*", key), "", hit[[1L]]))
  }

  parse_harmonic <- function(lines, idx) {
    raw <- meta_value(lines, sprintf("harmonic%d_amp_phase", idx))
    if (is.na(raw)) return(c(NA_real_, NA_real_))
    m <- regexec("^([-0-9.eE]+)\\s*@\\s*([-0-9.eE]+)$", raw)
    vals <- regmatches(raw, m)[[1L]]
    if (length(vals) != 3L) return(c(NA_real_, NA_real_))
    c(suppressWarnings(as.numeric(vals[2L])), suppressWarnings(as.numeric(vals[3L])))
  }

  parse_num_vec <- function(x) {
    if (is.na(x) || !nzchar(x)) return(NA_real_)
    vals <- suppressWarnings(as.numeric(trimws(strsplit(x, ",", fixed = TRUE)[[1L]])))
    vals
  }

  function(dynamic_registry, force = FALSE) {
    if (!force && !is.null(cache)) return(cache)
    uniq_roots <- unique(dynamic_registry$source_root)
    rows <- lapply(uniq_roots, function(root_dir) {
      meta_path <- file.path(root_dir, "meta.txt")
      sim_output_path <- file.path(root_dir, "sim_output.rds")
      lines <- if (file.exists(meta_path)) readLines(meta_path, warn = FALSE) else character(0)
      sim_obj <- if (file.exists(sim_output_path)) readRDS(sim_output_path) else NULL
      h1 <- parse_harmonic(lines, 1L)
      h2 <- parse_harmonic(lines, 2L)
      params <- sim_obj$info$params %||% list()
      data.frame(
        source_root = normalizePath(root_dir, winslash = "/", mustWork = TRUE),
        scenario_id = parse_chr_na_refreshed288_p90(meta_value(lines, "scenario_id"), sim_obj$info$scenario %||% NA_character_),
        sim_output_path = normalizePath(sim_output_path, winslash = "/", mustWork = FALSE),
        period = safe_int_refreshed288(params$period, safe_int_refreshed288(meta_value(lines, "period"), NA_integer_)),
        harmonics = {
          harms <- suppressWarnings(as.integer(parse_num_vec(meta_value(lines, "harmonics"))))
          harms <- harms[is.finite(harms)]
          if (!length(harms)) NA_character_ else paste(harms, collapse = ",")
        },
        dynamic_C0_scale = safe_num_refreshed288(params$C0_scale, safe_num_refreshed288(meta_value(lines, "C0_scale"), NA_real_)),
        dynamic_initial_state_mode = parse_chr_na_refreshed288_p90(meta_value(lines, "initial_state_mode"), params$initial_state_mode %||% NA_character_),
        dynamic_level0 = safe_num_refreshed288(meta_value(lines, "level0"), NA_real_),
        dynamic_slope0 = safe_num_refreshed288(meta_value(lines, "slope0"), NA_real_),
        dynamic_harmonic1_amplitude = safe_num_refreshed288(h1[1L], NA_real_),
        dynamic_harmonic1_phase = safe_num_refreshed288(h1[2L], NA_real_),
        dynamic_harmonic2_amplitude = safe_num_refreshed288(h2[1L], NA_real_),
        dynamic_harmonic2_phase = safe_num_refreshed288(h2[2L], NA_real_),
        dynamic_state_noise_sd = meta_value(lines, "state_noise_sd"),
        dynamic_normal_sigma = safe_num_refreshed288(meta_value(lines, "normal_sigma"), NA_real_),
        dynamic_laplace_scale = safe_num_refreshed288(meta_value(lines, "laplace_scale"), NA_real_),
        dynamic_gausmix_sigma = meta_value(lines, "gausmix_sigma"),
        dynamic_gausmix_weights = meta_value(lines, "gausmix_weights"),
        dynamic_gausmix_offset = safe_num_refreshed288(meta_value(lines, "gausmix_offset"), NA_real_),
        latent_seed = safe_int_refreshed288(sim_obj$extras$latent_seed, NA_integer_),
        noise_seed = safe_int_refreshed288(sim_obj$extras$noise_seed, NA_integer_),
        stringsAsFactors = FALSE
      )
    })
    cache <<- do.call(rbind, rows)
    rownames(cache) <- NULL
    cache
  }
})

build_dataset_registry_refreshed288 <- function() {
  out <- utils::read.csv(
    refreshed288_p90_dynamic_registry_source_path(),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  dynamic <- out[out$block == "dynamic", , drop = FALSE]
  static <- out[out$block == "static", , drop = FALSE]
  meta_map <- dynamic_meta_map_refreshed288_p90(dynamic)
  dynamic <- merge(dynamic, meta_map, by = "source_root", all.x = TRUE, sort = FALSE)

  extra_cols <- setdiff(names(dynamic), names(static))
  for (col in extra_cols) static[[col]] <- NA
  for (col in setdiff(names(static), names(dynamic))) dynamic[[col]] <- NA

  out <- rbind(dynamic[, names(dynamic), drop = FALSE], static[, names(dynamic), drop = FALSE])
  rownames(out) <- NULL
  out[order(out$block, out$root_kind, out$family, out$tau, out$fit_size), , drop = FALSE]
}

build_method_profile_refreshed288_p90 <- function(row) {
  tracker <- tracker_refreshed288_p90()
  common <- list(
    method_profile_id = row$method_profile_id,
    block = row$block,
    root_kind = row$root_kind,
    prior_semantics = row$prior_semantics,
    model = row$model,
    inference = row$inference,
    fit_engine = row$fit_engine,
    dqlm_ind = identical(row$model, "dqlm") || identical(row$model, "al"),
    stored_posterior_draws = safe_int_refreshed288(row$posterior_metric_draws, tracker$runtime_contract$posterior_metric_draws),
    notes = row$notes,
    first_retry_overlay = parse_chr_na_refreshed288_p90(row$first_retry_overlay, "none")
  )

  if (identical(row$block, "dynamic")) {
    common$df_value <- 0.98
    common$dim_df <- c(2L, 4L)
  }

  if (identical(row$root_kind, "static_shrink")) {
    common$beta_prior <- if (identical(row$prior_semantics, "rhs_ns")) "rhs_ns" else "ridge"
  } else if (identical(row$root_kind, "static_paper")) {
    common$beta_prior <- "ridge"
  }

  if (identical(row$inference, "vb")) {
    common$vb_method <- row$vb_method
    common$vb_max_iter <- safe_int_refreshed288(row$vb_max_iter, tracker$runtime_contract$vb$max_iter)
    common$vb_min_iter <- safe_int_refreshed288(row$vb_min_iter_elbo, tracker$runtime_contract$vb$min_iter_elbo)
    common$vb_tol <- safe_num_refreshed288(row$vb_tol, tracker$runtime_contract$vb$tol)
    if (identical(row$block, "dynamic")) {
      common$vb_n_samp_internal <- safe_int_refreshed288(row$dynamic_vb_n_samp, tracker$runtime_contract$vb$dynamic_n_samp)
    } else {
      common$n_samp_xi <- safe_int_refreshed288(row$static_vb_n_samp_xi, tracker$runtime_contract$vb$static_n_samp_xi)
    }
    return(common)
  }

  vb_init <- tracker$runtime_contract$vb_init
  common$init_from_vb <- parse_bool_refreshed288_p90(row$init_from_vb, TRUE)
  common$vb_init_method <- row$vb_init_method
  common$vb_init_profile_id <- sprintf("%s_ldvb_init", row$block)
  if (identical(row$block, "dynamic")) {
    common$vb_init_controls <- list(
      method = "ldvb",
      tol = safe_num_refreshed288(row$vb_init_tol, vb_init$tol),
      n.IS = 200L,
      n.samp = safe_int_refreshed288(row$vb_init_dynamic_n_samp, vb_init$dynamic_n_samp),
      max_iter = safe_int_refreshed288(row$vb_init_max_iter, vb_init$max_iter),
      verbose = FALSE,
      ld_controls = NULL
    )
    common$vb_init_validation <- runtime_vb_init_validation_refreshed288(row$model)
  } else {
    common$vb_init_controls <- list(
      max_iter = safe_int_refreshed288(row$vb_init_max_iter, vb_init$max_iter),
      min_iter = safe_int_refreshed288(row$vb_init_min_iter_elbo, vb_init$min_iter_elbo),
      tol = safe_num_refreshed288(row$vb_init_tol, vb_init$tol),
      n_samp_xi = safe_int_refreshed288(row$vb_init_static_n_samp_xi, vb_init$static_n_samp_xi),
      ld_controls = NULL,
      verbose = FALSE
    )
  }

  common$n_burn <- safe_int_refreshed288(row$mcmc_n_burn, tracker$runtime_contract$mcmc$n_burn)
  common$n_mcmc <- safe_int_refreshed288(row$mcmc_n_mcmc, tracker$runtime_contract$mcmc$n_mcmc)
  common$thin <- safe_int_refreshed288(row$thin, tracker$runtime_contract$mcmc$thin)
  common$mh_proposal <- parse_chr_na_refreshed288_p90(row$mh_proposal, tracker$runtime_contract$mcmc$proposal)
  common$mh_adapt <- TRUE
  common$mh_adapt_interval <- 50L
  common$mh_target_accept_lo <- 0.20
  common$mh_target_accept_hi <- 0.45
  common$mh_scale_lo <- 0.10
  common$mh_scale_hi <- 10.0
  common$mh_max_scale_step <- 0.35
  common$mh_min_burn_adapt <- 50L
  common$trace_diagnostics <- TRUE
  common$trace_every <- 50L
  common$slice_width <- parse_inf_num_refreshed288_p90(row$slice_width, 0.1)
  common$slice_max_steps <- parse_inf_num_refreshed288_p90(row$slice_max_steps, Inf)
  if (!identical(row$block, "dynamic")) {
    common$gamma_substeps <- 1L
    common$p_global_eta_jump <- 0
    common$global_eta_jump_scale <- 1
  }
  common
}

method_profiles_refreshed288 <- local({
  cache <- NULL
  function(force = FALSE) {
    if (!force && !is.null(cache)) return(cache)
    mat <- method_profile_matrix_refreshed288_p90(force = force)
    profiles <- lapply(seq_len(nrow(mat)), function(i) {
      prof <- build_method_profile_refreshed288_p90(mat[i, , drop = FALSE])
      prof
    })
    names(profiles) <- vapply(profiles, `[[`, character(1), "method_profile_id")
    cache <<- profiles
    profiles
  }
})

flatten_method_profiles_refreshed288 <- function(profiles = method_profiles_refreshed288()) {
  out <- method_profile_matrix_refreshed288_p90()
  rownames(out) <- NULL
  out[order(out$block, out$root_kind, out$prior_semantics, out$model, out$inference), , drop = FALSE]
}

smoke_case_keys_refreshed288 <- function(manifest) {
  wanted <- character(0)
  for (family in c("gausmix", "laplace", "normal")) {
    for (fit_size in c(500L, 5000L)) {
      for (model in c("dqlm", "exdqlm")) {
        for (inference in c("vb", "mcmc")) {
          wanted <- c(
            wanted,
            case_key_refreshed288("dynamic", family, "0p50", fit_size, "default", model, inference)
          )
        }
      }
    }
  }
  for (fit_size in c(100L, 1000L)) {
    for (model in c("al", "exal")) {
      for (inference in c("vb", "mcmc")) {
        wanted <- c(
          wanted,
          case_key_refreshed288("static_paper", "normal", "0p50", fit_size, "paper", model, inference),
          case_key_refreshed288("static_shrink", "normal", "0p50", fit_size, "ridge", model, inference),
          case_key_refreshed288("static_shrink", "normal", "0p50", fit_size, "rhs_ns", model, inference)
        )
      }
    }
  }
  intersect(wanted, manifest$original_case_key)
}

build_manifest_refreshed288 <- function(dataset_registry, repo_root) {
  profiles <- method_profiles_refreshed288()
  paths <- paths_refreshed288()
  rows <- list()
  row_id <- 0L

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
    file.path(paths$vb_init_dir, "static"),
    dirname(paths$smoke_report),
    dirname(paths$full_report)
  )) ensure_dir_refreshed288(path)

  for (i in seq_len(nrow(dataset_registry))) {
    ds <- dataset_registry[i, , drop = FALSE]
    model_vec <- if (identical(ds$block, "dynamic")) c("dqlm", "exdqlm") else c("al", "exal")
    prior_vec <- if (identical(ds$root_kind, "static_shrink")) c("ridge", "rhs_ns") else if (identical(ds$root_kind, "static_paper")) "paper" else "default"

    for (prior_semantics in prior_vec) {
      for (model in model_vec) {
        for (inference in c("vb", "mcmc")) {
          row_id <- row_id + 1L
          original_case_key <- case_key_refreshed288(ds$root_kind, ds$family, ds$tau_label, ds$fit_size, prior_semantics, model, inference)
          pair_id <- case_pair_key_refreshed288(ds$root_kind, ds$family, ds$tau_label, ds$fit_size, prior_semantics, model)
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
              period = safe_int_refreshed288(ds$period, 50L),
              harmonics = parse_chr_na_refreshed288_p90(ds$harmonics, "1,2"),
              scenario_id = parse_chr_na_refreshed288_p90(ds$scenario_id, NA_character_),
              sim_output_path = parse_chr_na_refreshed288_p90(ds$sim_output_path, NA_character_),
              dynamic_model_params = if (identical(ds$block, "dynamic")) list(
                period = safe_int_refreshed288(ds$period, 90L),
                harmonics = {
                  vals <- suppressWarnings(as.integer(trimws(strsplit(parse_chr_na_refreshed288_p90(ds$harmonics, "1,2"), ",", fixed = TRUE)[[1L]])))
                  vals <- vals[is.finite(vals)]
                  if (!length(vals)) c(1L, 2L) else vals
                },
                C0_scale = safe_num_refreshed288(ds$dynamic_C0_scale, 0.01),
                initial_state_mode = parse_chr_na_refreshed288_p90(ds$dynamic_initial_state_mode, "deterministic_m0"),
                level0 = safe_num_refreshed288(ds$dynamic_level0, 0),
                slope0 = safe_num_refreshed288(ds$dynamic_slope0, 0),
                seasonal_amplitudes = c(
                  safe_num_refreshed288(ds$dynamic_harmonic1_amplitude, 0),
                  safe_num_refreshed288(ds$dynamic_harmonic2_amplitude, 0)
                ),
                seasonal_phases = c(
                  safe_num_refreshed288(ds$dynamic_harmonic1_phase, 0),
                  safe_num_refreshed288(ds$dynamic_harmonic2_phase, 0)
                )
              ) else NULL,
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

write_run_contract_refreshed288 <- function(paths, repo_root = ".") {
  tracker <- tracker_refreshed288_p90()
  contract <- data.frame(
    run_tag = run_tag_refreshed288(),
    variant_tag = variant_tag_refreshed288(),
    canonical_status = "planned_p90_full288_relaunch",
    predecessor_run_tag = "refreshed288_paperaligned_20260417_canonical_v1",
    predecessor_run_root = "tools/merge_reports/full288_refreshed288_paperaligned_20260417_canonical_v1",
    active_dynamic_scenario = tracker$study_contract$dynamic_geometry$active_scenario_id,
    dynamic_fit_sizes = paste(tracker$study_contract$dynamic_geometry$fit_sizes, collapse = ","),
    static_paper_fit_sizes = paste(tracker$study_contract$static_geometry$static_paper_fit_sizes, collapse = ","),
    static_shrink_fit_sizes = paste(tracker$study_contract$static_geometry$static_shrink_fit_sizes, collapse = ","),
    posterior_metric_draws = tracker$runtime_contract$posterior_metric_draws,
    vb_sampling_nd_draws = tracker$runtime_contract$vb_sampling_nd_draws,
    vb_synthesis_n_samp = tracker$runtime_contract$vb_synthesis_n_samp,
    vb_method = tracker$runtime_contract$vb$method,
    vb_max_iter = tracker$runtime_contract$vb$max_iter,
    vb_min_iter_elbo = tracker$runtime_contract$vb$min_iter_elbo,
    vb_tol = tracker$runtime_contract$vb$tol,
    dynamic_vb_n_samp = tracker$runtime_contract$vb$dynamic_n_samp,
    static_vb_n_samp_xi = tracker$runtime_contract$vb$static_n_samp_xi,
    mcmc_proposal = tracker$runtime_contract$mcmc$proposal,
    mcmc_init_from_vb = isTRUE(tracker$runtime_contract$mcmc$init_from_vb),
    mcmc_n_burn = tracker$runtime_contract$mcmc$n_burn,
    mcmc_n_mcmc = tracker$runtime_contract$mcmc$n_mcmc,
    mcmc_thin = tracker$runtime_contract$mcmc$thin,
    rhs_plain_forbidden = isTRUE(tracker$baseline_policy$plain_rhs_allowed == FALSE),
    use_shared_0p4p0_models_only = isTRUE(tracker$baseline_policy$use_shared_0p4p0_models_only),
    use_qdesn_only_functions = isTRUE(tracker$baseline_policy$use_qdesn_only_functions),
    source_repo_root = refreshed288_source_repo_root(),
    validation_repo_branch = current_git_branch_refreshed288(repo_root),
    validation_repo_sha = current_git_sha_refreshed288(repo_root),
    plan_doc = tracker$sources$plan_doc,
    tracker_yaml = refreshed288_p90_tracker_path(),
    method_profile_matrix = tracker$sources$method_profile_matrix,
    run_root = paths$run_root,
    full_manifest = paths$full_manifest,
    smoke_manifest = paths$smoke_manifest,
    method_registry = paths$method_registry,
    stringsAsFactors = FALSE
  )
  utils::write.csv(contract, paths$run_contract, row.names = FALSE)
  invisible(contract)
}

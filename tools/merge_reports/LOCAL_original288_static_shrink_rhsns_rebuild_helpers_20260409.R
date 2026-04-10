source("tools/merge_reports/LOCAL_original288_syncedbase_faithful_replay_helpers_20260407.R")

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

run_tag_original288_static_shrink_rhsns_rebuild <- function() {
  "original288_static_shrink_rhsns_rebuild_20260409"
}

variant_tag_original288_static_shrink_rhsns_rebuild <- function() {
  "orig288_static_shrink_rhsns_rebuild_20260409"
}

source_repo_original288_static_shrink_rhsns_rebuild <- function() {
  "/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs"
}

phase_order_original288_static_shrink_rhsns_rebuild <- c(
  phase1_static_shrink_rhsns_vb = 1L,
  phase2_static_shrink_rhsns_mcmc = 2L
)

paths_original288_static_shrink_rhsns_rebuild <- function() {
  tag <- run_tag_original288_static_shrink_rhsns_rebuild()
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", tag))
  list(
    accepted_selection = "tools/merge_reports/LOCAL_original288_carryforward_selection_v7_20260407.csv",
    rebuild_inventory = file.path(
      "tools",
      "merge_reports",
      "original288_static_shrink_rhs_prior_audit_20260409",
      "original288_static_shrink_rhsns_rebuild_inventory_20260409.csv"
    ),
    manifest = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_manifest_20260409.csv",
    stage_counts = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_stage_counts_20260409.csv",
    manifest_status = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_manifest_status_20260409.csv",
    phase_summary = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_phase_summary_20260409.csv",
    block_summary = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_block_summary_20260409.csv",
    accepted_compare = "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_accepted_compare_20260409.csv",
    config_dir = file.path(run_dir, "configs"),
    rows_dir = file.path(run_dir, "rows"),
    health_dir = file.path(run_dir, "health"),
    metrics_dir = file.path(run_dir, "metrics"),
    logs_dir = file.path(run_dir, "logs"),
    tracker_doc = "reports/static_exal_tuning_20260406/integration_branch_validation_status_20260406.md",
    program_doc = "reports/static_exal_tuning_20260409/original_288_static_shrink_rhsns_rebuild_program_20260409.md",
    execution_doc = "reports/static_exal_tuning_20260409/original_288_static_shrink_rhsns_rebuild_execution_20260409.md",
    source_refresh_schedule = file.path(
      source_repo_original288_static_shrink_rhsns_rebuild(),
      "tools",
      "merge_reports",
      "LOCAL_static_exal_f080s105_refresh_schedule_20260403.csv"
    ),
    source_wave6_manifest = file.path(
      source_repo_original288_static_shrink_rhsns_rebuild(),
      "tools",
      "merge_reports",
      "LOCAL_static_exal_failband_wave6_manifest_20260404_193842_6521_3757286.csv"
    ),
    source_wave9_manifest = file.path(
      source_repo_original288_static_shrink_rhsns_rebuild(),
      "tools",
      "merge_reports",
      "LOCAL_static_exal_failband_wave9_manifest_20260405_022329_3948_3478750.csv"
    )
  )
}

expected_phase_original288_static_shrink_rhsns_rebuild <- function(inference) {
  if (identical(inference, "vb")) return("phase1_static_shrink_rhsns_vb")
  if (identical(inference, "mcmc")) return("phase2_static_shrink_rhsns_mcmc")
  "phase_unknown"
}

source_input_dir_original288_static_shrink_rhsns_rebuild <- function(family, tau_label, fit_size) {
  normalize_path_original288(file.path(
    source_repo_original288_static_shrink_rhsns_rebuild(),
    "results",
    "function_testing_20260309_static_shrinkage_family_qspec",
    family,
    sprintf("tau_%s", tau_label),
    sprintf("fit_input_subsample_tt%d_x01_sorted", as.integer(fit_size))
  ))
}

target_run_root_original288_static_shrink_rhsns_rebuild <- function(repo_root, family, tau_label, fit_size) {
  normalize_path_original288(file.path(
    repo_root,
    "results",
    "function_testing_20260309_static_shrinkage_family_qspec",
    family,
    sprintf("tau_%s", tau_label),
    sprintf("fit_input_subsample_tt%d_x01_sorted", as.integer(fit_size)),
    sprintf("validation_shrink_rhsns_tt%d", as.integer(fit_size))
  ))
}

candidate_fit_path_original288_static_shrink_rhsns_rebuild <- function(run_root, inference, model, tau_label) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    inference,
    sprintf(
      "%s_%s_tau_%s_fit_%s.rds",
      inference,
      model,
      tau_label,
      variant_tag_original288_static_shrink_rhsns_rebuild()
    )
  ))
}

config_path_original288_static_shrink_rhsns_rebuild <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_rebuild()$config_dir,
    sprintf("row_%04d_run_config.rds", as.integer(row_id))
  )
}

row_status_path_original288_static_shrink_rhsns_rebuild <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_rebuild()$rows_dir,
    sprintf("row_%04d.csv", as.integer(row_id))
  )
}

health_path_original288_static_shrink_rhsns_rebuild <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_rebuild()$health_dir,
    sprintf("health_%04d.csv", as.integer(row_id))
  )
}

metrics_path_original288_static_shrink_rhsns_rebuild <- function(row_id) {
  file.path(
    paths_original288_static_shrink_rhsns_rebuild()$metrics_dir,
    sprintf("metrics_%04d.csv", as.integer(row_id))
  )
}

read_rebuild_inventory_original288_static_shrink_rhsns_rebuild <- function() {
  x <- utils::read.csv(
    paths_original288_static_shrink_rhsns_rebuild()$rebuild_inventory,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  x$phase <- vapply(x$inference, expected_phase_original288_static_shrink_rhsns_rebuild, character(1))
  x$phase_order <- unname(phase_order_original288_static_shrink_rhsns_rebuild[x$phase])
  x
}

read_accepted_selection_original288_static_shrink_rhsns_rebuild <- function() {
  accepted <- utils::read.csv(
    paths_original288_static_shrink_rhsns_rebuild()$accepted_selection,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  accepted <- accepted[
    accepted$block == "static_shrink" & accepted$prior_semantics == "rhs",
    c(
      "block",
      "family",
      "tau",
      "fit_size",
      "model",
      "inference",
      "gate_overall",
      "healthy",
      "selection_mode",
      "selected_source_type",
      "selected_source_subtype",
      "selected_candidate",
      "selected_variant_tag",
      "selected_fit_path"
    ),
    drop = FALSE
  ]

  inv <- read_rebuild_inventory_original288_static_shrink_rhsns_rebuild()
  merged <- merge(
    inv,
    accepted,
    by = c("block", "family", "tau", "fit_size", "model", "inference", "selected_variant_tag"),
    suffixes = c(".inventory", ".accepted"),
    all.x = TRUE,
    sort = FALSE
  )
  choose_col <- function(primary, secondary, default = NA_character_) {
    out <- merged[[primary]]
    if (!secondary %in% names(merged)) {
      out[is.na(out) | !nzchar(trimws(as.character(out)))] <- default
      return(out)
    }
    fill <- merged[[secondary]]
    idx <- is.na(out) | !nzchar(trimws(as.character(out)))
    out[idx] <- fill[idx]
    out[is.na(out) | !nzchar(trimws(as.character(out)))] <- default
    out
  }
  merged$selected_source_subtype <- choose_col(
    "selected_source_subtype.inventory",
    "selected_source_subtype.accepted"
  )
  merged$selected_candidate <- choose_col(
    "selected_candidate.inventory",
    "selected_candidate.accepted"
  )
  merged$tau_label <- merged$tau
  merged$tau_num <- vapply(merged$tau_label, tau_num_from_label_original288_syncedbase_rerun, numeric(1))
  merged <- merged[order(
    merged$phase_order,
    merged$family,
    merged$tau_label,
    merged$fit_size,
    merged$model,
    merged$inference
  ), , drop = FALSE]
  rownames(merged) <- NULL
  merged
}

reference_status_original288_static_shrink_rhsns_rebuild <- function() {
  accepted <- read_accepted_selection_original288_static_shrink_rhsns_rebuild()
  list(
    total = nrow(accepted),
    pass = sum(accepted$gate_overall == "PASS"),
    warn = sum(accepted$gate_overall == "WARN"),
    fail = sum(accepted$gate_overall == "FAIL"),
    healthy = sum(accepted$healthy)
  )
}

validate_reference_status_original288_static_shrink_rhsns_rebuild <- function(accepted) {
  ref <- reference_status_original288_static_shrink_rhsns_rebuild()
  stopifnot(nrow(accepted) == 72L)
  stopifnot(nrow(accepted) == ref$total)
  stopifnot(sum(accepted$gate_overall == "PASS") == ref$pass)
  stopifnot(sum(accepted$gate_overall == "WARN") == ref$warn)
  stopifnot(sum(accepted$gate_overall == "FAIL") == ref$fail)
  stopifnot(sum(accepted$healthy) == ref$healthy)
  invisible(TRUE)
}

parse_seed_from_variant_original288_static_shrink_rhsns_rebuild <- function(tag) {
  tag <- safe_chr_original288_syncedbase_rerun(tag, NA_character_)
  if (is.na(tag)) return(NA_integer_)
  hit <- regmatches(tag, regexec("seed([0-9]+)", tag, perl = TRUE))[[1]]
  if (length(hit) >= 2L) suppressWarnings(as.integer(hit[2])) else NA_integer_
}

seed_fallback_original288_static_shrink_rhsns_rebuild <- function(row_id, inference, model) {
  base <- 2026049000L + as.integer(row_id) * 10L
  base + if (identical(inference, "mcmc")) 1L else 0L + if (identical(model, "exal")) 2L else 0L
}

apply_non_missing_original288_static_shrink_rhsns_rebuild <- function(base, override) {
  if (!length(override)) return(base)
  out <- base
  for (nm in names(override)) {
    val <- override[[nm]]
    if (length(val) == 0L || all(is.na(val))) next
    out[[nm]] <- val
  }
  out
}

dedupe_historical_profiles_original288_static_shrink_rhsns_rebuild <- function(x) {
  if (!nrow(x)) return(x)
  x$rhs_rank <- ifelse(toupper(x$beta_prior_override %||% "") == "RHS_NS", 1L, 0L)
  x$info_rank <- rowSums(!is.na(x[, intersect(
    c(
      "seed", "n_burn", "n_mcmc", "thin", "mh_proposal", "gamma_substeps",
      "p_global_eta_jump", "global_eta_jump_scale", "slice_width", "slice_max_steps"
    ),
    names(x)
  ), drop = FALSE]))
  x <- x[order(-x$rhs_rank, -x$info_rank), , drop = FALSE]
  key <- paste(x$variant_tag, x$family, x$tt, x$tau_label, sep = "::")
  x[!duplicated(key), , drop = FALSE]
}

historical_profile_lookup_original288_static_shrink_rhsns_rebuild <- local({
  cache <- NULL

  function(force = FALSE) {
    if (!force && !is.null(cache)) return(cache)

    paths <- paths_original288_static_shrink_rhsns_rebuild()
    parts <- list()

    if (file.exists(paths$source_refresh_schedule)) {
      x <- utils::read.csv(paths$source_refresh_schedule, stringsAsFactors = FALSE)
      x <- x[
        x$variant_tag == "static_exal_f080_sub2_s105_rhsns_current_20260403",
        c(
          "family", "tt", "tau_label", "variant_tag", "gamma_substeps",
          "p_global_eta_jump", "global_eta_jump_scale", "seed_refresh"
        ),
        drop = FALSE
      ]
      if (nrow(x)) {
        x$seed <- suppressWarnings(as.integer(x$seed_refresh))
        x$n_burn <- 2000L
        x$n_mcmc <- 1000L
        x$thin <- 1L
        x$mh_proposal <- "laplace_rw"
        x$mh_adapt <- TRUE
        x$slice_width <- 0.12
        x$slice_max_steps <- 80L
        x$laplace_refresh_interval <- 50L
        x$laplace_refresh_start <- 333L
        x$laplace_refresh_weight <- 0.60
        x$init_mode <- "baseline_last"
        x$beta_prior_override <- "rhs_ns"
        x$source_name <- "refresh_schedule"
        parts[[length(parts) + 1L]] <- x
      }
    }

    checkpoint_files <- list.files(
      file.path(source_repo_original288_static_shrink_rhsns_rebuild(), "tools", "merge_reports"),
      pattern = "^LOCAL_static_case_checkpoint_failband2_.*_exal_.*\\.csv$",
      full.names = TRUE
    )
    if (length(checkpoint_files)) {
      chk_parts <- lapply(checkpoint_files, function(path) {
        x <- tryCatch(utils::read.csv(path, stringsAsFactors = FALSE), error = function(e) NULL)
        if (is.null(x) || !nrow(x)) return(NULL)
        keep <- c(
          "family", "tt", "tau", "variant_tag", "seed", "n_burn", "n_mcmc", "thin",
          "mh_proposal", "mh_adapt", "slice_width", "slice_max_steps",
          "gamma_substeps", "p_global_eta_jump", "global_eta_jump_scale",
          "laplace_refresh_interval", "laplace_refresh_start", "laplace_refresh_weight",
          "beta_prior_override", "init_mode"
        )
        x <- x[, intersect(keep, names(x)), drop = FALSE]
        names(x)[names(x) == "tau"] <- "tau_label"
        x$source_name <- basename(path)
        x
      })
      chk <- rbind_fill_original288_syncedbase_rerun(Filter(Negate(is.null), chk_parts))
      if (nrow(chk)) {
        chk <- chk[
          !is.na(chk$seed) &
            !is.na(chk$mh_proposal) &
            toupper(chk$beta_prior_override %||% "") == "RHS_NS",
          ,
          drop = FALSE
        ]
        if (nrow(chk)) parts[[length(parts) + 1L]] <- chk
      }
    }

    if (file.exists(paths$source_wave6_manifest)) {
      x <- utils::read.csv(paths$source_wave6_manifest, stringsAsFactors = FALSE)
      x <- x[
        toupper(x$beta_prior_override %||% "") == "RHS_NS",
        c(
          "family", "tt", "tau_label", "variant_tag", "gamma_substeps",
          "p_global_eta_jump", "global_eta_jump_scale", "seed", "beta_prior_override"
        ),
        drop = FALSE
      ]
      if (nrow(x)) {
        x$n_burn <- 2000L
        x$n_mcmc <- 1000L
        x$thin <- 1L
        x$mh_proposal <- "laplace_rw"
        x$mh_adapt <- TRUE
        x$slice_width <- 0.12
        x$slice_max_steps <- 80L
        x$laplace_refresh_interval <- 50L
        x$laplace_refresh_start <- 333L
        x$laplace_refresh_weight <- 0.60
        x$init_mode <- "baseline_last"
        x$source_name <- "wave6_manifest"
        parts[[length(parts) + 1L]] <- x
      }
    }

    if (file.exists(paths$source_wave9_manifest)) {
      x <- utils::read.csv(paths$source_wave9_manifest, stringsAsFactors = FALSE)
      x <- x[
        ,
        c(
          "family", "tt", "tau_label", "variant_tag", "gamma_substeps",
          "p_global_eta_jump", "global_eta_jump_scale", "seed", "n_burn", "n_mcmc",
          "thin", "mh_proposal", "mh_adapt", "slice_width", "slice_max_steps",
          "init_mode", "beta_prior_override"
        ),
        drop = FALSE
      ]
      if (nrow(x)) {
        x$laplace_refresh_interval <- 50L
        x$laplace_refresh_start <- 333L
        x$laplace_refresh_weight <- 0.60
        x$source_name <- "wave9_manifest"
        parts[[length(parts) + 1L]] <- x
      }
    }

    out <- rbind_fill_original288_syncedbase_rerun(parts)
    if (nrow(out)) {
      out$tt <- suppressWarnings(as.integer(out$tt))
      out <- dedupe_historical_profiles_original288_static_shrink_rhsns_rebuild(out)
    }
    cache <<- out
    out
  }
})

lookup_historical_profile_original288_static_shrink_rhsns_rebuild <- function(
    variant_tag,
    family,
    tau_label,
    fit_size,
    variant_alias = NULL) {
  hist <- historical_profile_lookup_original288_static_shrink_rhsns_rebuild()
  if (!nrow(hist)) return(NULL)
  candidates <- unique(stats::na.omit(c(variant_tag, variant_alias)))
  for (cand in candidates) {
    hit <- hist[
      hist$variant_tag == cand &
        hist$family == family &
        hist$tau_label == tau_label &
        hist$tt == as.integer(fit_size),
      ,
      drop = FALSE
    ]
    if (nrow(hit)) return(as.list(hit[1, , drop = FALSE]))
  }
  NULL
}

default_vb_profile_original288_static_shrink_rhsns_rebuild <- function(model) {
  list(
    profile_id = sprintf("vb_%s_rhsns_default", model),
    beta_prior = "rhs_ns",
    dqlm_ind = identical(model, "al"),
    max_iter = 1000L,
    tol = 1e-4,
    n_samp_xi = 200L,
    ld_controls = list(
      store_trace = FALSE,
      profile_timing = FALSE,
      profile_iter_trace = FALSE
    )
  )
}

default_mcmc_al_profile_original288_static_shrink_rhsns_rebuild <- function() {
  list(
    profile_id = "mcmc_al_rhsns_default",
    beta_prior = "rhs_ns",
    dqlm_ind = TRUE,
    n_burn = 2000L,
    n_mcmc = 1000L,
    thin = 1L,
    init_from_vb = TRUE,
    vb_init_controls = list(max_iter = 1000L, tol = 1e-4, n_samp_xi = 200L, verbose = FALSE),
    trace_every = 50L,
    progress_every = 50L
  )
}

default_mcmc_exal_profile_original288_static_shrink_rhsns_rebuild <- function() {
  list(
    profile_id = "mcmc_exal_rhsns_baseline_like",
    beta_prior = "rhs_ns",
    dqlm_ind = FALSE,
    n_burn = 2000L,
    n_mcmc = 1000L,
    thin = 1L,
    init_from_vb = TRUE,
    vb_init_controls = list(max_iter = 1000L, tol = 1e-4, n_samp_xi = 200L, verbose = FALSE),
    mh_proposal = "laplace_rw",
    mh_adapt = TRUE,
    slice_width = 0.12,
    slice_max_steps = 80L,
    gamma_substeps = 1L,
    p_global_eta_jump = 0,
    global_eta_jump_scale = 1,
    laplace_refresh_interval = 50L,
    laplace_refresh_start = 333L,
    laplace_refresh_weight = 0.60,
    trace_every = 50L,
    progress_every = 50L,
    requested_init_mode = "baseline_last",
    resolved_init_mode = "vb"
  )
}

resolve_profile_original288_static_shrink_rhsns_rebuild <- function(row) {
  variant_tag <- safe_chr_original288_syncedbase_rerun(row$selected_variant_tag, "baseline")
  variant_alias <- switch(
    variant_tag,
    static_exal_f080_sub2_s105_rhs_legacy_20260403 = "static_exal_f080_sub2_s105_rhsns_current_20260403",
    variant_tag
  )

  if (identical(row$inference, "vb")) {
    base <- default_vb_profile_original288_static_shrink_rhsns_rebuild(row$model)
    seed_hist <- lookup_historical_profile_original288_static_shrink_rhsns_rebuild(
      variant_tag = variant_tag,
      variant_alias = variant_alias,
      family = row$family,
      tau_label = row$tau_label,
      fit_size = row$fit_size
    )
    seed <- safe_int_original288_syncedbase_rerun(seed_hist$seed %||% parse_seed_from_variant_original288_static_shrink_rhsns_rebuild(variant_tag), NA_integer_)
    base$fit_seed <- if (is.finite(seed)) seed else seed_fallback_original288_static_shrink_rhsns_rebuild(row$row_id, row$inference, row$model)
    base$source_variant_tag <- variant_tag
    base$historical_source <- safe_chr_original288_syncedbase_rerun(seed_hist$source_name %||% NA_character_, NA_character_)
    return(base)
  }

  if (identical(row$model, "al")) {
    base <- default_mcmc_al_profile_original288_static_shrink_rhsns_rebuild()
    seed_hist <- lookup_historical_profile_original288_static_shrink_rhsns_rebuild(
      variant_tag = "rhsns_impl_refresh_20260329",
      family = row$family,
      tau_label = row$tau_label,
      fit_size = row$fit_size
    )
    seed <- safe_int_original288_syncedbase_rerun(seed_hist$seed %||% parse_seed_from_variant_original288_static_shrink_rhsns_rebuild(variant_tag), NA_integer_)
    base$fit_seed <- if (is.finite(seed)) seed else seed_fallback_original288_static_shrink_rhsns_rebuild(row$row_id, row$inference, row$model)
    base$source_variant_tag <- variant_tag
    base$historical_source <- safe_chr_original288_syncedbase_rerun(seed_hist$source_name %||% NA_character_, NA_character_)
    if (identical(variant_tag, "rhsns_impl_refresh_20260329")) {
      base$profile_id <- "mcmc_al_rhsns_refresh"
    }
    return(base)
  }

  base <- default_mcmc_exal_profile_original288_static_shrink_rhsns_rebuild()
  hist <- lookup_historical_profile_original288_static_shrink_rhsns_rebuild(
    variant_tag = variant_tag,
    variant_alias = variant_alias,
    family = row$family,
    tau_label = row$tau_label,
    fit_size = row$fit_size
  )

  if (identical(variant_tag, "static_exal_f080_sub2_s105_rhsns_current_20260403") ||
      identical(variant_tag, "static_exal_f080_sub2_s105_rhs_legacy_20260403")) {
    base$profile_id <- "mcmc_exal_rhsns_f080_sub2_s105"
    base$gamma_substeps <- 2L
    base$p_global_eta_jump <- 0.08
    base$global_eta_jump_scale <- 1.05
  } else if (identical(variant_tag, "failband2_F085_sub2_s100")) {
    base$profile_id <- "mcmc_exal_rhsns_failband2_f085_sub2_s100"
    base$gamma_substeps <- 2L
    base$p_global_eta_jump <- 0.085
    base$global_eta_jump_scale <- 1
  } else if (identical(variant_tag, "repairmap6_F0825_sub2_s100")) {
    base$profile_id <- "mcmc_exal_rhsns_repairmap6_f0825_sub2_s100"
    base$gamma_substeps <- 2L
    base$p_global_eta_jump <- 0.0825
    base$global_eta_jump_scale <- 1
  } else if (identical(variant_tag, "repairmap9_R269_F0845_sub2_s100_histshort_seed2026076269")) {
    base$profile_id <- "mcmc_exal_rhsns_repairmap9_f0845_sub2_s100"
    base$gamma_substeps <- 2L
    base$p_global_eta_jump <- 0.0845
    base$global_eta_jump_scale <- 1
  } else if (identical(variant_tag, "rhs_legacy_refresh_20260329")) {
    base$profile_id <- "mcmc_exal_rhsns_corrected_legacy_refresh"
    base$gamma_substeps <- 2L
    base$p_global_eta_jump <- 0.08
    base$global_eta_jump_scale <- 1.05
  } else if (variant_tag %in% c("orig288_sync0p4p0_faithful_20260407", "orig288_sync0p4p0_residual_20260407")) {
    base$profile_id <- "mcmc_exal_rhsns_faithful_like"
  }

  if (!is.null(hist)) {
    hist_override <- list(
      n_burn = safe_int_original288_syncedbase_rerun(hist$n_burn, base$n_burn),
      n_mcmc = safe_int_original288_syncedbase_rerun(hist$n_mcmc, base$n_mcmc),
      thin = safe_int_original288_syncedbase_rerun(hist$thin, base$thin),
      mh_proposal = safe_chr_original288_syncedbase_rerun(hist$mh_proposal, base$mh_proposal),
      mh_adapt = safe_flag_original288_syncedbase_rerun(hist$mh_adapt, base$mh_adapt),
      slice_width = safe_num_original288_syncedbase_rerun(hist$slice_width, base$slice_width),
      slice_max_steps = safe_int_original288_syncedbase_rerun(hist$slice_max_steps, base$slice_max_steps),
      gamma_substeps = safe_int_original288_syncedbase_rerun(hist$gamma_substeps, base$gamma_substeps),
      p_global_eta_jump = safe_num_original288_syncedbase_rerun(hist$p_global_eta_jump, base$p_global_eta_jump),
      global_eta_jump_scale = safe_num_original288_syncedbase_rerun(hist$global_eta_jump_scale, base$global_eta_jump_scale),
      laplace_refresh_interval = safe_int_original288_syncedbase_rerun(hist$laplace_refresh_interval, base$laplace_refresh_interval),
      laplace_refresh_start = safe_int_original288_syncedbase_rerun(hist$laplace_refresh_start, base$laplace_refresh_start),
      laplace_refresh_weight = safe_num_original288_syncedbase_rerun(hist$laplace_refresh_weight, base$laplace_refresh_weight),
      requested_init_mode = safe_chr_original288_syncedbase_rerun(hist$init_mode, base$requested_init_mode)
    )
    base <- apply_non_missing_original288_static_shrink_rhsns_rebuild(base, hist_override)
  }

  hist_seed <- safe_int_original288_syncedbase_rerun(hist$seed %||% parse_seed_from_variant_original288_static_shrink_rhsns_rebuild(variant_tag), NA_integer_)
  base$fit_seed <- if (is.finite(hist_seed)) hist_seed else seed_fallback_original288_static_shrink_rhsns_rebuild(row$row_id, row$inference, row$model)
  base$source_variant_tag <- variant_tag
  base$historical_source <- safe_chr_original288_syncedbase_rerun(hist$source_name %||% NA_character_, NA_character_)
  base$variant_alias <- if (!identical(variant_alias, variant_tag)) variant_alias else NA_character_
  base
}

build_row_config_original288_static_shrink_rhsns_rebuild <- function(row, repo_root) {
  data_dir <- source_input_dir_original288_static_shrink_rhsns_rebuild(row$family, row$tau_label, row$fit_size)
  run_root <- target_run_root_original288_static_shrink_rhsns_rebuild(repo_root, row$family, row$tau_label, row$fit_size)
  profile <- resolve_profile_original288_static_shrink_rhsns_rebuild(row)
  fit_path <- candidate_fit_path_original288_static_shrink_rhsns_rebuild(run_root, row$inference, row$model, row$tau_label)

  list(
    row_id = as.integer(row$row_id),
    tag = run_tag_original288_static_shrink_rhsns_rebuild(),
    phase = row$phase,
    phase_order = row$phase_order,
    lane_label = "static_shrink_rhsns_rebuild",
    block = row$block,
    root_kind = row$block,
    family = row$family,
    tau = row$tau_num,
    tau_label = row$tau_label,
    fit_size = as.integer(row$fit_size),
    model = row$model,
    inference = row$inference,
    profile_id = profile$profile_id,
    source_variant_tag = safe_chr_original288_syncedbase_rerun(profile$source_variant_tag, row$selected_variant_tag),
    historical_source = profile$historical_source %||% NA_character_,
    target_prior_semantics = "rhs_ns",
    beta_prior = "rhs_ns",
    dqlm_ind = isTRUE(profile$dqlm_ind),
    fit_seed = as.integer(profile$fit_seed),
    run_root = run_root,
    data_dir = data_dir,
    series_wide_path = normalize_path_original288(file.path(data_dir, "series_wide.csv")),
    coef_truth_path = normalize_path_original288(file.path(data_dir, "coef_truth.csv")),
    true_quantile_grid_path = normalize_path_original288(file.path(data_dir, "true_quantile_grid.csv")),
    selection_indices_path = normalize_path_original288(file.path(data_dir, "selection_indices.csv")),
    fit_path = fit_path,
    config_path = config_path_original288_static_shrink_rhsns_rebuild(row$row_id),
    row_status_path = row_status_path_original288_static_shrink_rhsns_rebuild(row$row_id),
    health_path = health_path_original288_static_shrink_rhsns_rebuild(row$row_id),
    metrics_path = metrics_path_original288_static_shrink_rhsns_rebuild(row$row_id),
    accepted_gate = row$gate_overall,
    accepted_healthy = isTRUE(row$healthy),
    evidence_bucket = row$evidence_bucket,
    rebuild_scope = row$rebuild_scope,
    selected_candidate = row$selected_candidate,
    selected_variant_tag = row$selected_variant_tag,
    selection_mode = row$selection_mode,
    source_selected_fit_path = row$selected_fit_path,
    max_iter = profile$max_iter %||% NA_integer_,
    tol = profile$tol %||% NA_real_,
    n_samp_xi = profile$n_samp_xi %||% NA_integer_,
    ld_controls = profile$ld_controls %||% list(),
    n_burn = profile$n_burn %||% NA_integer_,
    n_mcmc = profile$n_mcmc %||% NA_integer_,
    thin = profile$thin %||% NA_integer_,
    init_from_vb = isTRUE(profile$init_from_vb),
    vb_init_controls = profile$vb_init_controls %||% list(),
    mh_proposal = profile$mh_proposal %||% NA_character_,
    mh_adapt = profile$mh_adapt %||% NA,
    slice_width = profile$slice_width %||% NA_real_,
    slice_max_steps = profile$slice_max_steps %||% NA_integer_,
    gamma_substeps = profile$gamma_substeps %||% NA_integer_,
    p_global_eta_jump = profile$p_global_eta_jump %||% NA_real_,
    global_eta_jump_scale = profile$global_eta_jump_scale %||% NA_real_,
    laplace_refresh_interval = profile$laplace_refresh_interval %||% NA_integer_,
    laplace_refresh_start = profile$laplace_refresh_start %||% NA_integer_,
    laplace_refresh_weight = profile$laplace_refresh_weight %||% NA_real_,
    trace_every = profile$trace_every %||% 50L,
    progress_every = profile$progress_every %||% 50L,
    requested_init_mode = profile$requested_init_mode %||% NA_character_,
    resolved_init_mode = profile$resolved_init_mode %||% NA_character_
  )
}

read_original288_static_shrink_rhsns_rebuild_status <- function(
    manifest_path = paths_original288_static_shrink_rhsns_rebuild()$manifest,
    run_tag = run_tag_original288_static_shrink_rhsns_rebuild()) {
  read_original288_syncedbase_rerun_status(manifest_path = manifest_path, run_tag = run_tag)
}

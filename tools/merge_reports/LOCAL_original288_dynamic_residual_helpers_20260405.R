source("tools/merge_reports/LOCAL_original288_recovery_helpers_20260405.R")

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

dynamic_residual_phase_order_original288 <- c(
  archive_rescore_existing = 1L,
  vb_relaxed = 2L,
  mcmc_targeted = 3L
)

dynamic_residual_force_original288 <- c(
  archive_rescore_existing = 0L,
  vb_relaxed = 1L,
  mcmc_targeted = 1L
)

gate_rank_dynamic_residual_original288 <- function(x) {
  ranks <- c(PASS = 3L, WARN = 2L, FAIL = 1L, MISSING = 0L)
  out <- unname(ranks[as.character(x)])
  out[is.na(out)] <- 0L
  as.integer(out)
}

candidate_preference_rank_dynamic_residual_original288 <- function(phase) {
  ranks <- c(
    mcmc_targeted = 3L,
    vb_relaxed = 2L,
    archive_rescore_existing = 1L
  )
  out <- unname(ranks[as.character(phase)])
  out[is.na(out)] <- 0L
  as.integer(out)
}

rbind_fill_dynamic_residual_original288 <- function(parts) {
  if (!length(parts)) return(data.frame())
  cols <- unique(unlist(lapply(parts, names), use.names = FALSE))
  norm <- lapply(parts, function(d) {
    miss <- setdiff(cols, names(d))
    if (length(miss)) {
      for (m in miss) d[[m]] <- NA
    }
    d[, cols, drop = FALSE]
  })
  do.call(rbind, norm)
}

paths_dynamic_residual_original288 <- function() {
  list(
    manifest = "tools/merge_reports/LOCAL_original288_dynamic_residual_manifest_20260405.csv",
    stage_counts = "tools/merge_reports/LOCAL_original288_dynamic_residual_stage_counts_20260405.csv",
    archive_catalog = "tools/merge_reports/LOCAL_original288_dynamic_residual_archive_catalog_20260405.csv",
    manifest_status = "tools/merge_reports/LOCAL_original288_dynamic_residual_manifest_status_20260405.csv",
    phase_summary = "tools/merge_reports/LOCAL_original288_dynamic_residual_phase_summary_20260405.csv",
    config_summary = "tools/merge_reports/LOCAL_original288_dynamic_residual_config_summary_20260405.csv",
    case_best = "tools/merge_reports/LOCAL_original288_dynamic_residual_case_best_20260405.csv",
    unresolved_after_run = "tools/merge_reports/LOCAL_original288_dynamic_residual_unresolved_after_run_20260405.csv",
    selection_update = "tools/merge_reports/LOCAL_original288_dynamic_residual_selection_update_20260405.csv",
    selection_delta = "tools/merge_reports/LOCAL_original288_dynamic_residual_selection_delta_20260405.csv",
    carryforward_preview = "tools/merge_reports/LOCAL_original288_carryforward_selection_dynamic_residual_preview_20260405.csv",
    health_summary_preview = "tools/merge_reports/LOCAL_original288_health_summary_dynamic_residual_preview_20260405.csv",
    tracker = "tools/merge_reports/LOCAL_ORIGINAL288_DYNAMIC_RECOVERY_TRACKER_20260405.md",
    plan_doc = "reports/static_exal_tuning_20260405/original_288_dynamic_residual_program_20260405.md",
    execution_doc = "reports/static_exal_tuning_20260405/original_288_dynamic_residual_execution_20260405.md"
  )
}

run_tag_dynamic_residual_original288 <- function() {
  "original288_dynamic_residual_20260405"
}

candidate_tag_from_fit_path_dynamic_residual_original288 <- function(path) {
  path <- normalize_path_original288(path)
  if (is.na(path)) return(NA_character_)
  base <- basename(path)
  if (!grepl("_fit_", base, fixed = TRUE)) return(NA_character_)
  sub("^.*_fit_(.*)\\.rds$", "\\1", base)
}

archive_priority_dynamic_residual_original288 <- function(tag) {
  tag <- as.character(tag %||% NA_character_)
  if (is.na(tag) || !nzchar(tag)) return(99L)
  if (grepl("row15_slice_exact|tierA_sync|slice_wave1|slice_wave2|slice_pilot|joint_recovery|adaptive_(pilot|prod)|cppgig", tag)) {
    return(1L)
  }
  if (grepl("rhsns_full_relaunch", tag)) {
    return(5L)
  }
  3L
}

full288_seed_map_dynamic_residual_original288 <- function() {
  manifest_path <- "tools/merge_reports/LOCAL_full288_manifest_rhsns_full_relaunch_20260327.csv"
  if (!file.exists(manifest_path)) {
    return(data.frame(original_case_key = character(0), seed_full288 = integer(0), stringsAsFactors = FALSE))
  }
  x <- read.csv(manifest_path, stringsAsFactors = FALSE)
  rows <- lapply(seq_len(nrow(x)), function(i) {
    mapped <- parse_original_key_from_fit_path_original288(
      x$baseline_fit_path[i],
      model_fallback = x$model[i],
      inference_fallback = x$inference[i]
    )
    if (!nrow(mapped)) return(NULL)
    data.frame(
      original_case_key = mapped$original_case_key,
      seed_full288 = as.integer(x$seed[i]),
      stringsAsFactors = FALSE
    )
  })
  out <- rbind_fill_dynamic_residual_original288(Filter(Negate(is.null), rows))
  if (!nrow(out)) return(out)
  out <- out[!duplicated(out$original_case_key), , drop = FALSE]
  rownames(out) <- NULL
  out
}

read_unresolved_dynamic_original288_dynamic_residual <- function() {
  path <- "tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v1_20260405.csv"
  x <- read.csv(path, stringsAsFactors = FALSE)
  x <- subset(x, root_kind == "dynamic" & selection_mode == "unresolved_baseline_fail")
  rownames(x) <- NULL
  x
}

build_archive_catalog_dynamic_residual_original288 <- function(unresolved = NULL,
                                                               harvested = NULL) {
  unresolved <- unresolved %||% read_unresolved_dynamic_original288_dynamic_residual()
  harvested <- harvested %||% read_dynamic_harvest_candidates_original288()
  harvested <- subset(harvested, block == "dynamic")

  if (!nrow(unresolved)) {
    return(data.frame())
  }

  harvested$key_candidate <- paste(
    harvested$original_case_key,
    normalize_path_original288(harvested$selected_fit_path),
    sep = "::"
  )
  harvested$gate_rank <- gate_rank_original288(harvested$gate_overall)
  harvested$runtime_rank <- ifelse(is.na(harvested$runtime_sec), Inf, harvested$runtime_sec)
  harvested <- harvested[order(
    harvested$key_candidate,
    harvested$gate_rank,
    harvested$source_rank,
    harvested$runtime_rank,
    harvested$source_path
  ), ]
  harvested <- harvested[!duplicated(harvested$key_candidate), , drop = FALSE]

  rows <- list()
  out_idx <- 0L
  for (i in seq_len(nrow(unresolved))) {
    row <- unresolved[i, , drop = FALSE]
    baseline_fit_path <- normalize_path_original288(row$selected_fit_path[1])
    fit_dir <- dirname(baseline_fit_path)
    fit_prefix <- sprintf("%s_%s_tau_%s_fit_", row$inference[1], row$model[1], row$tau[1])
    candidates <- Sys.glob(file.path(fit_dir, paste0(fit_prefix, "*.rds")))
    candidates <- sort(unique(normalize_path_original288(candidates)))
    if (!length(candidates)) next

    for (cand in candidates) {
      key_candidate <- paste(row$original_case_key[1], cand, sep = "::")
      ev <- harvested[harvested$key_candidate == key_candidate, , drop = FALSE]
      out_idx <- out_idx + 1L
      rows[[out_idx]] <- data.frame(
        original_case_key = row$original_case_key[1],
        block = row$block[1],
        root_kind = row$root_kind[1],
        family = row$family[1],
        tau = row$tau[1],
        fit_size = as.integer(row$fit_size[1]),
        prior_semantics = row$prior_semantics[1],
        model = row$model[1],
        inference = row$inference[1],
        baseline_fit_path = baseline_fit_path,
        run_root = normalize_path_original288(dirname(dirname(dirname(baseline_fit_path)))),
        tables_dir = normalize_path_original288(dirname(row$source_path[1])),
        run_config_path = normalize_path_original288(file.path(dirname(row$source_path[1]), "run_config.rds")),
        sim_output_path = normalize_path_original288(file.path(dirname(dirname(dirname(dirname(baseline_fit_path)))), "sim_output.rds")),
        source_signoff_path = normalize_path_original288(row$source_path[1]),
        candidate_fit_path = cand,
        candidate_variant_tag = candidate_tag_from_fit_path_dynamic_residual_original288(cand),
        archive_priority = archive_priority_dynamic_residual_original288(candidate_tag_from_fit_path_dynamic_residual_original288(cand)),
        has_harvest_evidence = nrow(ev) > 0L,
        evidence_gate = if (nrow(ev)) ev$gate_overall[1] else NA_character_,
        evidence_healthy = if (nrow(ev)) normalize_bool_original288(ev$healthy[1]) else NA,
        evidence_source_type = if (nrow(ev)) ev$candidate_source_type[1] else NA_character_,
        evidence_source_path = if (nrow(ev)) ev$source_path[1] else NA_character_,
        include_archive_stage = nrow(ev) == 0L,
        stringsAsFactors = FALSE
      )
    }
  }

  out <- rbind_fill_dynamic_residual_original288(rows)
  if (!nrow(out)) return(out)
  out <- out[order(
    out$original_case_key,
    out$include_archive_stage,
    out$archive_priority,
    out$candidate_variant_tag,
    out$candidate_fit_path
  ), , drop = FALSE]
  rownames(out) <- NULL
  out
}

config_id_dynamic_residual_original288 <- function(row) {
  if (identical(as.character(row$inference), "vb")) {
    return("vb_relaxed")
  }
  if (identical(as.character(row$model), "dqlm")) {
    return("mcmc_dqlm_cppgig_refresh")
  }
  if (as.integer(row$fit_size) == 500L) {
    return("mcmc_exdqlm_slice_short")
  }
  "mcmc_exdqlm_joint_long"
}

config_note_dynamic_residual_original288 <- function(config_id) {
  switch(
    config_id,
    vb_relaxed = "Relaxed dynamic VB controls for the two remaining exdqlm low-tail TT5000 cells.",
    mcmc_dqlm_cppgig_refresh = "Reuse the successful dqlm dynamic-tail refresh idea with current code and baseline geometry.",
    mcmc_exdqlm_slice_short = "Short-horizon exdqlm rescue using the surviving slice-style corridor from the March 18/19 repair pilots.",
    mcmc_exdqlm_joint_long = "Long-horizon exdqlm rescue using the stronger joint-recovery style geometry and refresh schedule.",
    "Unspecified dynamic residual config."
  )
}

apply_dynamic_residual_config_original288 <- function(cfg, config_id) {
  cfg <- cfg %||% list()
  cfg$vb <- cfg$vb %||% list()
  cfg$mcmc <- cfg$mcmc %||% list()
  cfg$mcmc$mh <- cfg$mcmc$mh %||% list()

  if (identical(config_id, "vb_relaxed")) {
    cfg$vb$tol <- 0.03
    cfg$vb$n_samp <- 1000L
    cfg$vb$max_iter <- 1200L
    cfg$vb$tol_sigma <- 0.02
    cfg$vb$tol_gamma <- 0.01
    cfg$vb$tol_elbo <- 3
    cfg$vb$min_iter <- 50L
    cfg$vb$patience <- 12L
    cfg$vb$allow_elbo_drop <- 3
    return(cfg)
  }

  if (identical(config_id, "mcmc_dqlm_cppgig_refresh")) {
    cfg$mcmc$trace_every <- cfg$mcmc$trace_every %||% 50L
    cfg$mcmc$mh$proposal <- cfg$mcmc$mh$proposal %||% cfg$mcmc$mh$primary_proposal %||% "laplace_rw"
    cfg$mcmc$mh$adapt <- if (!is.null(cfg$mcmc$mh$adapt)) cfg$mcmc$mh$adapt else TRUE
    return(cfg)
  }

  if (identical(config_id, "mcmc_exdqlm_slice_short")) {
    cfg$mcmc$burn <- 600L
    cfg$mcmc$n <- 1600L
    cfg$mcmc$trace_every <- 25L
    cfg$mcmc$mh$proposal <- "slice"
    cfg$mcmc$mh$adapt <- FALSE
    cfg$mcmc$mh$slice_width <- 0.12
    cfg$mcmc$mh$slice_max_steps <- 80L
    return(cfg)
  }

  if (identical(config_id, "mcmc_exdqlm_joint_long")) {
    cfg$mcmc$burn <- 2500L
    cfg$mcmc$n <- 5000L
    cfg$mcmc$trace_every <- 25L
    cfg$mcmc$mh$proposal <- "laplace_rw"
    cfg$mcmc$mh$adapt <- TRUE
    cfg$mcmc$mh$adapt_interval <- 25L
    cfg$mcmc$mh$target_accept <- c(0.20, 0.45)
    cfg$mcmc$mh$scale_bounds <- c(0.1, 10)
    cfg$mcmc$mh$max_scale_step <- 0.35
    cfg$mcmc$mh$min_burn_adapt <- 50L
    cfg$mcmc$mh$laplace_refresh_interval <- 25L
    cfg$mcmc$mh$laplace_refresh_start <- 300L
    cfg$mcmc$mh$laplace_refresh_weight <- 0.70
    return(cfg)
  }

  cfg
}

read_dynamic_residual_status_original288 <- function(manifest_path = paths_dynamic_residual_original288()$manifest,
                                                     run_tag = run_tag_dynamic_residual_original288()) {
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
  rows <- rbind_fill_dynamic_residual_original288(parts)
  if (nrow(rows)) {
    merged <- merge(manifest, rows, by = "row_id", all.x = TRUE, suffixes = c("_manifest", "_row"))
  } else {
    merged <- manifest
  }

  if (!("status" %in% names(merged))) merged$status <- NA_character_
  if (!("gate_overall" %in% names(merged))) merged$gate_overall <- NA_character_
  if (!("healthy" %in% names(merged))) merged$healthy <- NA
  if (!("runtime_sec" %in% names(merged))) merged$runtime_sec <- NA_real_
  if ("status_row" %in% names(merged)) merged$status <- ifelse(!is.na(merged$status_row) & nzchar(merged$status_row), merged$status_row, merged$status)
  if ("gate_overall_row" %in% names(merged)) merged$gate_overall <- ifelse(!is.na(merged$gate_overall_row) & nzchar(merged$gate_overall_row), merged$gate_overall_row, merged$gate_overall)
  if ("healthy_row" %in% names(merged)) merged$healthy <- ifelse(!is.na(merged$healthy_row), merged$healthy_row, merged$healthy)
  if ("runtime_sec_row" %in% names(merged)) merged$runtime_sec <- ifelse(!is.na(merged$runtime_sec_row), merged$runtime_sec_row, merged$runtime_sec)

  normalize_pref_col <- function(base) {
    if (!(base %in% names(merged))) merged[[base]] <<- NA
    row_nm <- paste0(base, "_row")
    manifest_nm <- paste0(base, "_manifest")
    if (row_nm %in% names(merged)) {
      row_val <- merged[[row_nm]]
      merged[[base]] <<- ifelse(!is.na(row_val) & (!is.character(row_val) | nzchar(row_val)), row_val, merged[[base]])
    }
    if (manifest_nm %in% names(merged)) {
      man_val <- merged[[manifest_nm]]
      merged[[base]] <<- ifelse((is.na(merged[[base]]) | (is.character(merged[[base]]) & !nzchar(merged[[base]]))) &
                                  (!is.na(man_val) & (!is.character(man_val) | nzchar(man_val))),
                                man_val,
                                merged[[base]])
    }
  }

  for (nm in c(
    "root_kind", "family", "tau_label", "model", "inference",
    "baseline_fit_path", "candidate_fit_path"
  )) {
    normalize_pref_col(nm)
  }

  merged$state <- ifelse(is.na(merged$status) | !nzchar(merged$status), "pending", merged$status)
  merged$gate_overall[is.na(merged$gate_overall) | !nzchar(merged$gate_overall)] <- "MISSING"
  merged
}

gate_rank_original288 <- function(x) {
  ranks <- c(PASS = 1L, WARN = 2L, FAIL = 3L)
  out <- unname(ranks[as.character(x)])
  out[is.na(out)] <- 9L
  as.integer(out)
}

normalize_bool_original288 <- function(x) {
  if (is.logical(x)) {
    return(ifelse(is.na(x), FALSE, x))
  }
  x_chr <- toupper(trimws(as.character(x)))
  x_chr %in% c("TRUE", "T", "1", "YES", "Y")
}

normalize_path_original288 <- function(path) {
  ifelse(
    is.na(path) | !nzchar(path),
    NA_character_,
    normalizePath(path, winslash = "/", mustWork = FALSE)
  )
}

tau_to_label_original288 <- function(x) {
  x_num <- suppressWarnings(as.numeric(x))
  out <- ifelse(
    is.na(x_num),
    as.character(x),
    format(x_num, scientific = FALSE, trim = TRUE)
  )
  out <- sub("\\.?0+$", "", out)
  out <- sub("^([0-9]+)$", "\\1p0", out)
  gsub("\\.", "p", out)
}

make_original_case_key_original288 <- function(root_kind,
                                               family,
                                               tau_label,
                                               fit_size,
                                               prior_semantics,
                                               model,
                                               inference) {
  paste(
    root_kind,
    family,
    tau_label,
    as.integer(fit_size),
    prior_semantics,
    model,
    inference,
    sep = "::"
  )
}

make_original_scenario_key_original288 <- function(root_kind,
                                                   family,
                                                   tau_label,
                                                   fit_size,
                                                   prior_semantics) {
  paste(
    root_kind,
    family,
    tau_label,
    as.integer(fit_size),
    prior_semantics,
    sep = "::"
  )
}

infer_model_from_fit_path_original288 <- function(path) {
  base <- basename(path)
  if (grepl("^(vb|mcmc)_[^_]+_tau_.*\\.rds$", base)) {
    return(sub("^(vb|mcmc)_([^_]+)_tau_.*$", "\\2", base))
  }
  NA_character_
}

infer_inference_from_fit_path_original288 <- function(path) {
  base <- basename(path)
  if (grepl("^vb_", base)) {
    return("vb")
  }
  if (grepl("^mcmc_", base)) {
    return("mcmc")
  }
  NA_character_
}

parse_original_key_from_fit_path_original288 <- function(path,
                                                         model_fallback = NA_character_,
                                                         inference_fallback = NA_character_) {
  path <- normalize_path_original288(path)
  if (is.na(path)) {
    return(data.frame())
  }

  extract_match <- function(pattern) {
    m <- regexec(pattern, path, perl = TRUE)
    regmatches(path, m)[[1]]
  }

  model <- infer_model_from_fit_path_original288(path)
  if (is.na(model) || !nzchar(model)) {
    model <- model_fallback
  }

  inference <- infer_inference_from_fit_path_original288(path)
  if (is.na(inference) || !nzchar(inference)) {
    inference <- inference_fallback
  }

  static_paper_match <- extract_match(
    ".*/results/function_testing_20260309_static_paper_family_qspec/([^/]+)/tau_([^/]+)/fit_input_subsample_tt([0-9]+)_x01_sorted/validation_paper_tt([0-9]+)/fits/(vb|mcmc)/[^/]+$"
  )
  if (length(static_paper_match)) {
    fit_size <- suppressWarnings(as.integer(static_paper_match[4]))
    return(data.frame(
      root_kind = "static_paper",
      family = static_paper_match[2],
      tau_label = static_paper_match[3],
      fit_size = fit_size,
      prior_semantics = "paper",
      inference = ifelse(is.na(inference), static_paper_match[6], inference),
      model = model,
      original_scenario_key = make_original_scenario_key_original288(
        "static_paper", static_paper_match[2], static_paper_match[3], fit_size, "paper"
      ),
      original_case_key = make_original_case_key_original288(
        "static_paper", static_paper_match[2], static_paper_match[3], fit_size, "paper", model,
        ifelse(is.na(inference), static_paper_match[6], inference)
      ),
      stringsAsFactors = FALSE
    ))
  }

  static_shrink_match <- extract_match(
    ".*/results/function_testing_20260309_static_shrinkage_family_qspec/([^/]+)/tau_([^/]+)/fit_input_subsample_tt([0-9]+)_x01_sorted/validation_shrink_(rhs|ridge)_tt([0-9]+)/fits/(vb|mcmc)/[^/]+$"
  )
  if (length(static_shrink_match)) {
    fit_size <- suppressWarnings(as.integer(static_shrink_match[4]))
    prior_semantics <- static_shrink_match[5]
    return(data.frame(
      root_kind = "static_shrink",
      family = static_shrink_match[2],
      tau_label = static_shrink_match[3],
      fit_size = fit_size,
      prior_semantics = prior_semantics,
      inference = ifelse(is.na(inference), static_shrink_match[7], inference),
      model = model,
      original_scenario_key = make_original_scenario_key_original288(
        "static_shrink", static_shrink_match[2], static_shrink_match[3], fit_size, prior_semantics
      ),
      original_case_key = make_original_case_key_original288(
        "static_shrink", static_shrink_match[2], static_shrink_match[3], fit_size, prior_semantics, model,
        ifelse(is.na(inference), static_shrink_match[7], inference)
      ),
      stringsAsFactors = FALSE
    ))
  }

  dynamic_match <- extract_match(
    ".*/results/function_testing_20260309_dynamic_dlm_family_qspec/dlm_constV_smallW/([^/]+)/tau_([^/]+)/fit_input_lastTT([0-9]+)/validation_dynamic_tt([0-9]+)/fits/(vb|mcmc)/[^/]+$"
  )
  if (length(dynamic_match)) {
    fit_size <- suppressWarnings(as.integer(dynamic_match[4]))
    return(data.frame(
      root_kind = "dynamic",
      family = dynamic_match[2],
      tau_label = dynamic_match[3],
      fit_size = fit_size,
      prior_semantics = "default",
      inference = ifelse(is.na(inference), dynamic_match[6], inference),
      model = model,
      original_scenario_key = make_original_scenario_key_original288(
        "dynamic", dynamic_match[2], dynamic_match[3], fit_size, "default"
      ),
      original_case_key = make_original_case_key_original288(
        "dynamic", dynamic_match[2], dynamic_match[3], fit_size, "default", model,
        ifelse(is.na(inference), dynamic_match[6], inference)
      ),
      stringsAsFactors = FALSE
    ))
  }

  data.frame()
}

infer_baseline_fit_path_original288 <- function(signoff_path,
                                                inference,
                                                model,
                                                tau_label) {
  scenario_dir <- dirname(dirname(signoff_path))
  normalize_path_original288(file.path(
    scenario_dir,
    "fits",
    inference,
    sprintf("%s_%s_tau_%s_fit.rds", inference, model, tau_label)
  ))
}

read_original288_registry_original288 <- function() {
  roots <- c(
    "results/function_testing_20260309_static_paper_family_qspec",
    "results/function_testing_20260309_static_shrinkage_family_qspec",
    "results/function_testing_20260309_dynamic_dlm_family_qspec"
  )
  files <- sort(unlist(lapply(roots, function(root) {
    list.files(root, pattern = "method_signoff_long\\.csv$", recursive = TRUE, full.names = TRUE)
  })))

  rows <- lapply(files, function(path) {
    x <- read.csv(path, stringsAsFactors = FALSE)
    tau_label <- tau_to_label_original288(x$tau)
    signoff_path <- normalize_path_original288(path)
    fit_paths <- vapply(
      seq_len(nrow(x)),
      function(i) infer_baseline_fit_path_original288(signoff_path, x$inference[i], x$model[i], tau_label[i]),
      character(1)
    )

    data.frame(
      block = x$root_kind,
      root_kind = x$root_kind,
      family = x$family,
      tau = tau_label,
      fit_size = as.integer(x$fit_size),
      prior_semantics = x$prior,
      model = x$model,
      inference = x$inference,
      method = x$method,
      root_id = x$root_id,
      original_scenario_key = mapply(
        make_original_scenario_key_original288,
        x$root_kind, x$family, tau_label, as.integer(x$fit_size), x$prior,
        SIMPLIFY = TRUE,
        USE.NAMES = FALSE
      ),
      original_case_key = mapply(
        make_original_case_key_original288,
        x$root_kind, x$family, tau_label, as.integer(x$fit_size), x$prior, x$model, x$inference,
        SIMPLIFY = TRUE,
        USE.NAMES = FALSE
      ),
      baseline_signoff_path = signoff_path,
      baseline_fit_path = fit_paths,
      baseline_fit_path_exists = file.exists(fit_paths),
      baseline_gate_overall = x$signoff_grade,
      baseline_healthy = x$signoff_grade %in% c("PASS", "WARN") &
        normalize_bool_original288(x$comparison_eligible) &
        normalize_bool_original288(x$execution_healthy),
      baseline_status = x$status,
      baseline_signoff_reason = x$signoff_reason,
      comparison_eligible = normalize_bool_original288(x$comparison_eligible),
      convergence_certified = normalize_bool_original288(x$convergence_certified),
      execution_healthy = normalize_bool_original288(x$execution_healthy),
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  out <- out[order(out$root_kind, out$family, out$tau, out$fit_size, out$prior_semantics, out$model, out$inference), ]
  rownames(out) <- NULL
  out
}

read_hybrid291_candidates_original288 <- function() {
  path <- "tools/merge_reports/LOCAL_validation_campaign_selection_table_v1_20260405.csv"
  x <- read.csv(path, stringsAsFactors = FALSE)
  x <- subset(x, !(selected_variant_tag %in% c("historical_base_fit")))

  rows <- lapply(seq_len(nrow(x)), function(i) {
    mapped <- parse_original_key_from_fit_path_original288(
      x$selected_fit_path[i],
      model_fallback = x$model[i],
      inference_fallback = x$inference[i]
    )
    if (!nrow(mapped)) {
      return(NULL)
    }
    data.frame(
      original_case_key = mapped$original_case_key,
      original_scenario_key = mapped$original_scenario_key,
      block = mapped$root_kind,
      family = mapped$family,
      tau = mapped$tau_label,
      fit_size = mapped$fit_size,
      prior_semantics = mapped$prior_semantics,
      model = mapped$model,
      inference = mapped$inference,
      candidate_source_type = "hybrid_291_selection",
      candidate_source_subtype = x$selected_pool[i],
      source_rank = if (x$selected_pool[i] %in% c("static_local_override", "dynamic_local_override")) {
        1L
      } else if (x$selected_pool[i] == "static_refresh_nonfail") {
        2L
      } else if (x$selected_pool[i] == "static_residual_broad_default") {
        3L
      } else if (x$selected_pool[i] == "dynamic_historical_reusable") {
        4L
      } else {
        5L
      },
      selected_candidate = x$selected_candidate[i],
      selected_variant_tag = x$selected_variant_tag[i],
      selected_fit_path = normalize_path_original288(x$selected_fit_path[i]),
      selected_health_path = normalize_path_original288(x$selected_health_path[i]),
      selected_summary_path = normalize_path_original288(x$selected_summary_path[i]),
      source_path = normalize_path_original288(x$provenance_source[i]),
      gate_overall = x$gate_overall[i],
      healthy = normalize_bool_original288(x$healthy[i]),
      runtime_sec = suppressWarnings(as.numeric(x$runtime_sec[i])),
      evidence_note = x$selection_reason[i],
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  if (is.null(out)) {
    return(data.frame())
  }
  rownames(out) <- NULL
  out
}

read_static_refresh_candidates_original288 <- function() {
  current_manifest_path <- "tools/merge_reports/LOCAL_targeted_manifest_current_static_rhsns_20260329.csv"
  legacy_manifest_path <- "tools/merge_reports/LOCAL_targeted_manifest_legacy_rhs_refresh_20260329.csv"
  current_compact_path <- "tools/merge_reports/full288_rhsns_impl_refresh_20260329/health_compact_20260329_114727.csv"
  legacy_compact_path <- "tools/merge_reports/full288_rhs_legacy_refresh_20260329/health_compact_20260329_123208.csv"

  current_manifest <- read.csv(current_manifest_path, stringsAsFactors = FALSE)
  legacy_manifest <- read.csv(legacy_manifest_path, stringsAsFactors = FALSE)
  current_compact <- read.csv(current_compact_path, stringsAsFactors = FALSE)
  legacy_compact <- read.csv(legacy_compact_path, stringsAsFactors = FALSE)

  current_manifest$refresh_summary_path <- normalize_path_original288(current_compact_path)
  legacy_manifest$refresh_summary_path <- normalize_path_original288(legacy_compact_path)
  current_manifest$refresh_subtype <- "current_rhsns_impl_refresh"
  legacy_manifest$refresh_subtype <- "legacy_rhs_refresh"

  current <- merge(
    current_manifest,
    current_compact[, c("row_id", "inference", "model", "gate_overall", "healthy", "runtime_sec")],
    by = c("row_id", "inference", "model"),
    all.x = TRUE,
    sort = FALSE
  )
  legacy <- merge(
    legacy_manifest,
    legacy_compact[, c("row_id", "inference", "model", "gate_overall", "healthy", "runtime_sec")],
    by = c("row_id", "inference", "model"),
    all.x = TRUE,
    sort = FALSE
  )

  merged <- rbind(current, legacy)
  merged <- subset(merged, gate_overall %in% c("PASS", "WARN"))

  rows <- lapply(seq_len(nrow(merged)), function(i) {
    mapped <- parse_original_key_from_fit_path_original288(
      merged$candidate_fit_path[i],
      model_fallback = merged$model[i],
      inference_fallback = merged$inference[i]
    )
    if (!nrow(mapped)) {
      return(NULL)
    }
    data.frame(
      original_case_key = mapped$original_case_key,
      original_scenario_key = mapped$original_scenario_key,
      block = mapped$root_kind,
      family = mapped$family,
      tau = mapped$tau_label,
      fit_size = mapped$fit_size,
      prior_semantics = mapped$prior_semantics,
      model = mapped$model,
      inference = mapped$inference,
      candidate_source_type = "static_refresh_compact",
      candidate_source_subtype = merged$refresh_subtype[i],
      source_rank = if (merged$refresh_subtype[i] == "current_rhsns_impl_refresh") 2L else 3L,
      selected_candidate = merged$prepared_tag[i],
      selected_variant_tag = merged$prepared_tag[i],
      selected_fit_path = normalize_path_original288(merged$candidate_fit_path[i]),
      selected_health_path = normalize_path_original288(merged$refresh_summary_path[i]),
      selected_summary_path = normalize_path_original288(merged$refresh_summary_path[i]),
      source_path = normalize_path_original288(merged$refresh_summary_path[i]),
      gate_overall = merged$gate_overall[i],
      healthy = normalize_bool_original288(merged$healthy[i]),
      runtime_sec = suppressWarnings(as.numeric(merged$runtime_sec[i])),
      evidence_note = sprintf(
        "Promotable static refresh candidate harvested from %s compact.",
        merged$refresh_subtype[i]
      ),
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  if (is.null(out)) {
    return(data.frame())
  }

  out$key_candidate <- paste(out$original_case_key, out$selected_fit_path, sep = "::")
  out$gate_rank <- gate_rank_original288(out$gate_overall)
  out$runtime_rank <- ifelse(is.na(out$runtime_sec), Inf, out$runtime_sec)
  out <- out[order(out$key_candidate, out$gate_rank, out$source_rank, out$runtime_rank, out$source_path), ]
  out <- out[!duplicated(out$key_candidate), ]
  out$key_candidate <- NULL
  out$gate_rank <- NULL
  out$runtime_rank <- NULL
  rownames(out) <- NULL
  out
}

read_dynamic_harvest_candidates_original288 <- function() {
  files <- sort(list.files(
    "tools/merge_reports",
    pattern = "^LOCAL_dynamic_case_health(_summary)?_.*\\.csv$",
    full.names = TRUE
  ))

  rows <- list()
  out_idx <- 0L

  for (path in files) {
    x <- tryCatch(read.csv(path, stringsAsFactors = FALSE), error = function(e) NULL)
    if (is.null(x) || !nrow(x)) {
      next
    }

    if (grepl("_summary_", basename(path), fixed = TRUE)) {
      keep <- !is.na(x$candidate_path) & nzchar(x$candidate_path)
      y <- x[keep, , drop = FALSE]
      if (!nrow(y)) {
        next
      }
      for (i in seq_len(nrow(y))) {
        mapped <- parse_original_key_from_fit_path_original288(y$candidate_path[i])
        if (!nrow(mapped)) {
          next
        }
        out_idx <- out_idx + 1L
        rows[[out_idx]] <- data.frame(
          original_case_key = mapped$original_case_key,
          original_scenario_key = mapped$original_scenario_key,
          block = mapped$root_kind,
          family = mapped$family,
          tau = mapped$tau_label,
          fit_size = mapped$fit_size,
          prior_semantics = mapped$prior_semantics,
          model = mapped$model,
          inference = mapped$inference,
          candidate_source_type = "dynamic_summary_csv",
          candidate_source_subtype = "dynamic_archive_summary",
          source_rank = 5L,
          selected_candidate = y$variant_tag[i],
          selected_variant_tag = y$variant_tag[i],
          selected_fit_path = normalize_path_original288(y$candidate_path[i]),
          selected_health_path = normalize_path_original288(
            if ("health_csv" %in% names(y)) y$health_csv[i] else NA_character_
          ),
          selected_summary_path = normalize_path_original288(path),
          source_path = normalize_path_original288(path),
          gate_overall = y$gate_overall[i],
          healthy = normalize_bool_original288(y$healthy[i]),
          runtime_sec = suppressWarnings(as.numeric(
            if ("runtime_sec_cand" %in% names(y)) y$runtime_sec_cand[i] else NA_real_
          )),
          evidence_note = "Archived dynamic summary candidate harvested into original-288 recovery pool.",
          stringsAsFactors = FALSE
        )
      }
    } else {
      keep <- !is.na(x$candidate_path) & nzchar(x$candidate_path) &
        !(tolower(trimws(as.character(x$variant))) %in% c("", "baseline"))
      y <- x[keep, , drop = FALSE]
      if (!nrow(y)) {
        next
      }
      for (i in seq_len(nrow(y))) {
        mapped <- parse_original_key_from_fit_path_original288(y$candidate_path[i])
        if (!nrow(mapped)) {
          next
        }
        out_idx <- out_idx + 1L
        rows[[out_idx]] <- data.frame(
          original_case_key = mapped$original_case_key,
          original_scenario_key = mapped$original_scenario_key,
          block = mapped$root_kind,
          family = mapped$family,
          tau = mapped$tau_label,
          fit_size = mapped$fit_size,
          prior_semantics = mapped$prior_semantics,
          model = mapped$model,
          inference = mapped$inference,
          candidate_source_type = "dynamic_health_csv",
          candidate_source_subtype = "dynamic_archive_health",
          source_rank = 6L,
          selected_candidate = y$variant[i],
          selected_variant_tag = y$variant[i],
          selected_fit_path = normalize_path_original288(y$candidate_path[i]),
          selected_health_path = normalize_path_original288(path),
          selected_summary_path = NA_character_,
          source_path = normalize_path_original288(path),
          gate_overall = y$gate_overall[i],
          healthy = normalize_bool_original288(y$healthy[i]),
          runtime_sec = suppressWarnings(as.numeric(
            if ("run_time_sec" %in% names(y)) y$run_time_sec[i] else NA_real_
          )),
          evidence_note = "Archived dynamic candidate health row harvested into original-288 recovery pool.",
          stringsAsFactors = FALSE
        )
      }
    }
  }

  out <- do.call(rbind, rows)
  if (is.null(out)) {
    return(data.frame())
  }

  out$key_candidate <- paste(out$original_case_key, out$selected_fit_path, sep = "::")
  out$gate_rank <- gate_rank_original288(out$gate_overall)
  out$runtime_rank <- ifelse(is.na(out$runtime_sec), Inf, out$runtime_sec)
  out <- out[order(out$key_candidate, out$gate_rank, out$source_rank, out$runtime_rank, out$source_path), ]
  out <- out[!duplicated(out$key_candidate), ]
  out$key_candidate <- NULL
  out$gate_rank <- NULL
  out$runtime_rank <- NULL
  rownames(out) <- NULL
  out
}

choose_original288_candidate <- function(reg_row, candidate_pool) {
  reg_row <- reg_row[1, , drop = FALSE]
  baseline_gate <- reg_row$baseline_gate_overall[1]
  baseline_rank <- gate_rank_original288(baseline_gate)
  baseline_healthy <- isTRUE(reg_row$baseline_healthy[1])

  if (!nrow(candidate_pool)) {
    return(data.frame(
      original_case_key = reg_row$original_case_key[1],
      original_scenario_key = reg_row$original_scenario_key[1],
      selected_source_type = "baseline_original",
      selected_source_subtype = "baseline_original",
      selected_candidate = "baseline",
      selected_variant_tag = "baseline",
      selected_fit_path = reg_row$baseline_fit_path[1],
      selected_health_path = reg_row$baseline_signoff_path[1],
      selected_summary_path = NA_character_,
      source_path = reg_row$baseline_signoff_path[1],
      gate_overall = baseline_gate,
      healthy = baseline_healthy,
      runtime_sec = NA_real_,
      improved_over_baseline = FALSE,
      selection_mode = if (baseline_healthy) "baseline_kept" else "unresolved_baseline_fail",
      selection_reason = if (baseline_healthy) {
        "Baseline original fit already healthy and no promoted candidate was required."
      } else {
        "Baseline original fit remains FAIL and no promoted candidate with explicit non-FAIL evidence was available."
      },
      stringsAsFactors = FALSE
    ))
  }

  candidate_pool$gate_rank <- gate_rank_original288(candidate_pool$gate_overall)
  candidate_pool$runtime_rank <- ifelse(is.na(candidate_pool$runtime_sec), Inf, candidate_pool$runtime_sec)
  candidate_pool <- candidate_pool[order(
    candidate_pool$gate_rank,
    candidate_pool$source_rank,
    candidate_pool$runtime_rank,
    candidate_pool$selected_fit_path
  ), ]

  improved <- subset(candidate_pool, gate_rank < baseline_rank)

  if (baseline_healthy && !nrow(improved)) {
    return(data.frame(
      original_case_key = reg_row$original_case_key[1],
      original_scenario_key = reg_row$original_scenario_key[1],
      selected_source_type = "baseline_original",
      selected_source_subtype = "baseline_original",
      selected_candidate = "baseline",
      selected_variant_tag = "baseline",
      selected_fit_path = reg_row$baseline_fit_path[1],
      selected_health_path = reg_row$baseline_signoff_path[1],
      selected_summary_path = NA_character_,
      source_path = reg_row$baseline_signoff_path[1],
      gate_overall = baseline_gate,
      healthy = baseline_healthy,
      runtime_sec = NA_real_,
      improved_over_baseline = FALSE,
      selection_mode = "baseline_kept",
      selection_reason = "Baseline original fit already healthy; repaired candidates did not strictly improve the gate.",
      stringsAsFactors = FALSE
    ))
  }

  promoted <- if (nrow(improved)) {
    improved[1, , drop = FALSE]
  } else {
    healthy_candidates <- subset(candidate_pool, healthy == TRUE & gate_rank < 3L)
    if (nrow(healthy_candidates)) healthy_candidates[1, , drop = FALSE] else NULL
  }

  if (is.null(promoted) || !nrow(promoted)) {
    return(data.frame(
      original_case_key = reg_row$original_case_key[1],
      original_scenario_key = reg_row$original_scenario_key[1],
      selected_source_type = "baseline_original",
      selected_source_subtype = "baseline_original",
      selected_candidate = "baseline",
      selected_variant_tag = "baseline",
      selected_fit_path = reg_row$baseline_fit_path[1],
      selected_health_path = reg_row$baseline_signoff_path[1],
      selected_summary_path = NA_character_,
      source_path = reg_row$baseline_signoff_path[1],
      gate_overall = baseline_gate,
      healthy = baseline_healthy,
      runtime_sec = NA_real_,
      improved_over_baseline = FALSE,
      selection_mode = if (baseline_healthy) "baseline_kept" else "unresolved_baseline_fail",
      selection_reason = if (baseline_healthy) {
        "Baseline original fit already healthy; no promoted candidate outranked it."
      } else {
        "Baseline original fit remains FAIL; candidate artifacts existed but none had explicit non-FAIL health evidence."
      },
      stringsAsFactors = FALSE
    ))
  }

  data.frame(
    original_case_key = reg_row$original_case_key[1],
    original_scenario_key = reg_row$original_scenario_key[1],
    selected_source_type = promoted$candidate_source_type[1],
    selected_source_subtype = promoted$candidate_source_subtype[1],
    selected_candidate = promoted$selected_candidate[1],
    selected_variant_tag = promoted$selected_variant_tag[1],
    selected_fit_path = promoted$selected_fit_path[1],
    selected_health_path = promoted$selected_health_path[1],
    selected_summary_path = promoted$selected_summary_path[1],
    source_path = promoted$source_path[1],
    gate_overall = promoted$gate_overall[1],
    healthy = promoted$healthy[1],
    runtime_sec = promoted$runtime_sec[1],
    improved_over_baseline = gate_rank_original288(promoted$gate_overall[1]) < baseline_rank,
    selection_mode = if (baseline_healthy) "promoted_over_healthy_baseline" else "promoted_over_fail_baseline",
    selection_reason = if (baseline_healthy) {
      sprintf(
        "Promoted `%s` because it improved the original baseline gate from `%s` to `%s`.",
        promoted$selected_variant_tag[1], baseline_gate, promoted$gate_overall[1]
      )
    } else {
      sprintf(
        "Promoted `%s` because it upgraded the original FAIL baseline to `%s` with explicit health evidence.",
        promoted$selected_variant_tag[1], promoted$gate_overall[1]
      )
    },
    stringsAsFactors = FALSE
  )
}

ensure_files_exist_original288 <- function(paths) {
  missing <- paths[!is.na(paths) & nzchar(paths) & !file.exists(paths)]
  unique(missing)
}

imic_v1_schema <- "independent_metric_interval_coupling_audit_v1"
imic_v1_promotion_id <- "qdesn_dqlm_500obs_metric_intervals_v10_20260824"
imic_v1_production_run_id <- "independent_metric_intervals_v1_production_20260823_225856"
imic_v1_pilot_stage <- "qdesn_dqlm_500obs_metric_interval_coupling_pilot_v1"
imic_v1_estimator_id <- "posterior_mean_draw_metric_equal_tailed_95cri_v1"
imic_v1_numeric_tolerance <- 1e-11
imic_v1_primary_replay_tolerance <- 1e-10

imic_v1_promotion_dir <- function(repo_root = ffv2_repo_root()) {
  file.path(repo_root, "validation", "fitforecast_v2", "promotions", imic_v1_promotion_id)
}

imic_v1_audit_dir <- function(repo_root = ffv2_repo_root()) {
  file.path(repo_root, "validation", "fitforecast_v2", "audits",
            "independent_metric_interval_coupling_audit_v1_20260824")
}

imic_v1_selection_path <- function(repo_root = ffv2_repo_root()) {
  file.path(repo_root, "config", "validation",
            "independent_metric_interval_coupling_audit_v1", "pilot_sources.csv")
}

imic_v1_read_selection <- function(repo_root = ffv2_repo_root()) {
  x <- ffv2_read_csv(imic_v1_selection_path(repo_root))
  required <- c("replay_id", "engine", "model_variant", "family", "tau",
                "article_roles", "pilot_role", "rationale")
  missing <- setdiff(required, names(x))
  if (length(missing)) {
    stop(sprintf("Pilot selection is missing: %s", paste(missing, collapse = ", ")),
         call. = FALSE)
  }
  if (nrow(x) != 11L || anyDuplicated(x$replay_id)) {
    stop("Pilot selection must contain exactly 11 unique replay ids.", call. = FALSE)
  }
  x
}

imic_v1_recursive_replace <- function(x, replacements) {
  if (is.list(x)) {
    return(lapply(x, imic_v1_recursive_replace, replacements = replacements))
  }
  if (!is.character(x)) return(x)
  out <- x
  for (from in names(replacements)) {
    out <- gsub(from, replacements[[from]], out, fixed = TRUE)
  }
  out
}

imic_v1_copy_verified <- function(source, destination, expected_sha256 = NULL) {
  source <- normalizePath(source, winslash = "/", mustWork = TRUE)
  if (!is.null(expected_sha256) && nzchar(as.character(expected_sha256)[1L])) {
    observed <- ffv2_file_sha256(source)
    if (!identical(observed, as.character(expected_sha256)[1L])) {
      stop(sprintf("Source hash mismatch before copy: %s", source), call. = FALSE)
    }
  }
  ffv2_ensure_dir(dirname(destination))
  if (!file.copy(source, destination, overwrite = TRUE, copy.mode = TRUE)) {
    stop(sprintf("Could not copy %s", source), call. = FALSE)
  }
  destination <- normalizePath(destination, winslash = "/", mustWork = TRUE)
  copied_sha <- ffv2_file_sha256(destination)
  if (!is.null(expected_sha256) && nzchar(as.character(expected_sha256)[1L]) &&
      !identical(copied_sha, as.character(expected_sha256)[1L])) {
    stop(sprintf("Copied hash mismatch: %s", destination), call. = FALSE)
  }
  destination
}

imic_v1_relative_numeric_error <- function(observed, expected) {
  abs(as.numeric(observed) - as.numeric(expected)) /
    pmax(1, abs(as.numeric(expected)))
}

imic_v1_hash_vectors_equal <- function(observed, expected) {
  observed <- unname(as.character(observed))
  expected <- unname(as.character(expected))
  length(observed) == length(expected) && length(observed) > 0L &&
    all(!is.na(observed) & !is.na(expected) & nzchar(observed) &
          nzchar(expected) & observed == expected)
}

imic_v1_recompute_source_summaries <- function(draw_index,
                                                promotion_dir = imic_v1_promotion_dir()) {
  required <- c("job_id", "replay_id", "engine", "inference", "model_variant",
                "family", "tau", "chain_id", "draw_path")
  missing <- setdiff(required, names(draw_index))
  if (length(missing)) {
    stop(sprintf("Draw index is missing: %s", paste(missing, collapse = ", ")),
         call. = FALSE)
  }
  if (nrow(draw_index) != 198L || anyDuplicated(draw_index$job_id)) {
    stop("Raw evidence replay requires exactly 198 unique job draw files.", call. = FALSE)
  }
  blocks <- split(draw_index, as.character(draw_index$replay_id))
  rows <- lapply(blocks, function(index_block) {
    index_block <- index_block[order(as.integer(index_block$chain_id)), , drop = FALSE]
    pieces <- lapply(seq_len(nrow(index_block)), function(i) {
      x <- ffv2_read_csv(index_block$draw_path[[i]])
      x$chain_id <- as.integer(index_block$chain_id[[i]])
      x
    })
    draws <- do.call(rbind, pieces)
    meta <- index_block[1L, , drop = FALSE]
    summary <- ffv2_metric_interval_summary(
      draws, inference = meta$inference[[1L]], estimator_id = imic_v1_estimator_id
    )
    data.frame(
      replay_id = meta$replay_id[[1L]],
      engine = meta$engine[[1L]],
      inference = meta$inference[[1L]],
      model_variant = meta$model_variant[[1L]],
      family = meta$family[[1L]],
      tau = as.numeric(meta$tau[[1L]]),
      summary,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$replay_id, out$metric), , drop = FALSE]
}

imic_v1_compare_replay_to_promotion <- function(recomputed,
                                                 promotion_dir = imic_v1_promotion_dir(),
                                                 tolerance = imic_v1_numeric_tolerance) {
  promoted <- ffv2_read_csv(file.path(promotion_dir, "source_interval_summary.csv"))
  key <- c("replay_id", "engine", "inference", "model_variant", "family", "tau", "metric")
  out <- merge(recomputed, promoted, by = key, all = TRUE,
               suffixes = c("_recomputed", "_promoted"), sort = TRUE)
  numeric_fields <- c("posterior_mean", "posterior_sd", "cri_lower",
                      "posterior_median", "cri_upper")
  for (field in numeric_fields) {
    out[[paste0(field, "_relative_error")]] <- imic_v1_relative_numeric_error(
      out[[paste0(field, "_recomputed")]], out[[paste0(field, "_promoted")]]
    )
  }
  numeric_error_cols <- paste0(numeric_fields, "_relative_error")
  out$numeric_match <- apply(out[numeric_error_cols], 1L, function(x) {
    all(is.finite(x) & x <= tolerance)
  })
  out$count_match <- as.integer(out$n_draws_recomputed) == as.integer(out$n_draws_promoted) &
    as.integer(out$n_chains_recomputed) == as.integer(out$n_chains_promoted)
  out$label_match <- as.character(out$interval_label_recomputed) ==
    as.character(out$interval_label_promoted) &
    as.character(out$estimator_id_recomputed) == as.character(out$estimator_id_promoted)
  out$all_match <- out$numeric_match & out$count_match & out$label_match
  out
}

imic_v1_coupling_modes <- function(engine) {
  if (identical(as.character(engine), "qdesn")) {
    c(primary = "native_aligned", alternative = "origin_independent_permutation")
  } else {
    c(primary = "origin_independent", alternative = "common_marginal_rank")
  }
}

imic_v1_pool_coupling_draws <- function(index) {
  required <- c("replay_id", "engine", "model_variant", "family", "tau",
                "chain_id", "coupling_draws_path")
  missing <- setdiff(required, names(index))
  if (length(missing)) {
    stop(sprintf("Coupling index is missing: %s", paste(missing, collapse = ", ")),
         call. = FALSE)
  }
  blocks <- split(index, as.character(index$replay_id))
  rows <- lapply(blocks, function(block) {
    pieces <- lapply(seq_len(nrow(block)), function(i) {
      x <- ffv2_read_csv(block$coupling_draws_path[[i]])
      x$chain_id <- as.integer(block$chain_id[[i]])
      x
    })
    draws <- do.call(rbind, pieces)
    summary <- ffv2_metric_coupling_summary(draws)
    meta <- block[1L, , drop = FALSE]
    data.frame(
      replay_id = meta$replay_id[[1L]],
      engine = meta$engine[[1L]],
      model_variant = meta$model_variant[[1L]],
      family = meta$family[[1L]],
      tau = as.numeric(meta$tau[[1L]]),
      summary,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

imic_v1_compare_coupling_modes <- function(summary) {
  keys <- unique(summary[c("replay_id", "engine", "model_variant", "family", "tau")])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    key <- keys[i, , drop = FALSE]
    block <- summary[summary$replay_id == key$replay_id[[1L]], , drop = FALSE]
    modes <- imic_v1_coupling_modes(key$engine[[1L]])
    do.call(rbind, lapply(c("forecast_mae", "forecast_check_loss"), function(metric) {
      primary <- block[block$metric == metric & block$coupling_mode == modes[["primary"]],
                       , drop = FALSE]
      alternative <- block[block$metric == metric &
                             block$coupling_mode == modes[["alternative"]], , drop = FALSE]
      if (nrow(primary) != 1L || nrow(alternative) != 1L) {
        stop(sprintf("Missing paired coupling summary for %s %s.",
                     key$replay_id[[1L]], metric), call. = FALSE)
      }
      native_width <- primary$cri_upper - primary$cri_lower
      alt_width <- alternative$cri_upper - alternative$cri_lower
      endpoint_shift <- max(abs(c(alternative$cri_lower - primary$cri_lower,
                                  alternative$cri_upper - primary$cri_upper)))
      rel_mean <- imic_v1_relative_numeric_error(alternative$posterior_mean,
                                                 primary$posterior_mean)
      width_ratio <- alt_width / native_width
      endpoint_fraction <- endpoint_shift / native_width
      severity <- if (rel_mean > 5e-10 || endpoint_fraction > 0.25 ||
                      width_ratio < 0.80 || width_ratio > 1.25) {
        "MATERIAL"
      } else if (endpoint_fraction > 0.10 || width_ratio < 0.90 || width_ratio > 1.10) {
        "REVIEW"
      } else "PASS"
      data.frame(
        key,
        metric = metric,
        primary_mode = modes[["primary"]],
        alternative_mode = modes[["alternative"]],
        primary_mean = primary$posterior_mean,
        alternative_mean = alternative$posterior_mean,
        relative_mean_shift = rel_mean,
        primary_cri_lower = primary$cri_lower,
        primary_cri_upper = primary$cri_upper,
        alternative_cri_lower = alternative$cri_lower,
        alternative_cri_upper = alternative$cri_upper,
        primary_width = native_width,
        alternative_width = alt_width,
        width_ratio = width_ratio,
        endpoint_shift_primary_width = endpoint_fraction,
        severity = severity,
        stringsAsFactors = FALSE
      )
    }))
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

imic_v1_primary_replay_comparison <- function(coupling_summary,
                                               promotion_dir = imic_v1_promotion_dir()) {
  promoted <- ffv2_read_csv(file.path(promotion_dir, "source_interval_summary.csv"))
  primary <- coupling_summary[vapply(coupling_summary$engine, function(engine) {
    TRUE
  }, logical(1L)), , drop = FALSE]
  primary$expected_mode <- vapply(primary$engine, function(engine) {
    imic_v1_coupling_modes(engine)[["primary"]]
  }, character(1L))
  primary <- primary[primary$coupling_mode == primary$expected_mode, , drop = FALSE]
  promoted <- promoted[promoted$metric %in% c("forecast_mae", "forecast_check_loss"),
                       , drop = FALSE]
  out <- merge(
    primary[c("replay_id", "metric", "posterior_mean", "posterior_sd", "cri_lower",
              "posterior_median", "cri_upper", "n_draws", "n_chains")],
    promoted[c("replay_id", "metric", "posterior_mean", "posterior_sd", "cri_lower",
               "posterior_median", "cri_upper", "n_draws", "n_chains")],
    by = c("replay_id", "metric"), suffixes = c("_pilot", "_v10"), all.x = TRUE
  )
  fields <- c("posterior_mean", "posterior_sd", "cri_lower", "posterior_median", "cri_upper")
  for (field in fields) {
    out[[paste0(field, "_relative_error")]] <- imic_v1_relative_numeric_error(
      out[[paste0(field, "_pilot")]], out[[paste0(field, "_v10")]]
    )
  }
  error_cols <- paste0(fields, "_relative_error")
  out$primary_replay_match <- apply(out[error_cols], 1L, function(x) {
    all(is.finite(x) & x <= imic_v1_primary_replay_tolerance)
  }) & out$n_draws_pilot == out$n_draws_v10 & out$n_chains_pilot == out$n_chains_v10
  out
}

imic_v1_article_overlap_sensitivity <- function(coupling_summary,
                                                 promotion_dir = imic_v1_promotion_dir()) {
  roles <- ffv2_read_csv(file.path(promotion_dir, "article_metric_role_intervals.csv"))
  roles <- roles[roles$inference == "mcmc" &
                   ((roles$family == "normal" & roles$tau == 0.25) |
                      (roles$family == "gausmix" & roles$tau == 0.05)) &
                   roles$metric_role %in% c("forecast_mae", "forecast_check"), , drop = FALSE]
  roles$metric <- ifelse(roles$metric_role == "forecast_mae", "forecast_mae",
                         "forecast_check_loss")
  contracts <- c("current", "matched_product", "dependence_bound")
  rows <- list()
  k <- 0L
  for (contract in contracts) {
    block <- roles
    block$coupling_mode <- mapply(function(engine, model_variant) {
      modes <- imic_v1_coupling_modes(engine)
      if (contract == "current") return(modes[["primary"]])
      if (contract == "matched_product") {
        if (engine == "qdesn") return(modes[["alternative"]])
        return(modes[["primary"]])
      }
      if (engine == "dqlm") modes[["alternative"]] else modes[["primary"]]
    }, ifelse(grepl("^qdesn_", block$model_variant), "qdesn", "dqlm"),
    block$model_variant, USE.NAMES = FALSE)
    block$engine <- ifelse(grepl("^qdesn_", block$model_variant), "qdesn", "dqlm")
    matched <- merge(
      block[c("family", "tau", "model_variant", "model_label", "metric", "replay_id",
              "engine", "coupling_mode")],
      coupling_summary[c("replay_id", "engine", "metric", "coupling_mode",
                         "posterior_mean", "cri_lower", "cri_upper")],
      by = c("replay_id", "engine", "metric", "coupling_mode"), all.x = TRUE
    )
    cells <- split(matched, paste(matched$family, matched$tau, matched$metric, sep = "|"))
    for (cell in cells) {
      cell <- cell[order(cell$posterior_mean, cell$model_variant), , drop = FALSE]
      if (nrow(cell) != 4L || any(!is.finite(cell$posterior_mean))) {
        stop("Article coupling sensitivity did not resolve four models per cell.", call. = FALSE)
      }
      overlap <- max(cell$cri_lower[1:2]) <= min(cell$cri_upper[1:2])
      k <- k + 1L
      rows[[k]] <- data.frame(
        contract = contract,
        family = cell$family[[1L]],
        tau = cell$tau[[1L]],
        metric = cell$metric[[1L]],
        winner = cell$model_variant[[1L]],
        winner_mean = cell$posterior_mean[[1L]],
        runner_up = cell$model_variant[[2L]],
        runner_up_mean = cell$posterior_mean[[2L]],
        winner_runner_intervals_overlap = overlap,
        stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, rows)
  current <- out[out$contract == "current",
                 c("family", "tau", "metric", "winner_runner_intervals_overlap")]
  names(current)[[4L]] <- "current_overlap"
  out <- merge(out, current, by = c("family", "tau", "metric"), all.x = TRUE)
  out$overlap_conclusion_changed <- out$winner_runner_intervals_overlap != out$current_overlap
  out[order(out$family, out$tau, out$metric, out$contract), , drop = FALSE]
}

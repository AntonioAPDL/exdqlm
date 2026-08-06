`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

qdesn_tpmv1_band_lead <- function(x) {
  cut(as.integer(x), breaks = c(0, 5, 15, 30),
      labels = c("lead_01_05", "lead_06_15", "lead_16_30"),
      include.lowest = TRUE)
}

qdesn_tpmv1_band_origin <- function(x) {
  x <- as.integer(x)
  ranks <- rank(x, ties.method = "min")
  n <- max(ranks, na.rm = TRUE)
  cut(ranks / n, breaks = c(0, 1 / 3, 2 / 3, 1),
      labels = c("origin_early", "origin_middle", "origin_late"),
      include.lowest = TRUE)
}

qdesn_tpmv1_summarise_source <- function(q, train_end = 9000L) {
  required <- c("source_index", "q_true", "y")
  if (!all(required %in% names(q))) stop("Source data lack required columns.", call. = FALSE)
  q <- q[order(q$source_index), , drop = FALSE]
  split <- ifelse(q$source_index <= train_end, "pre_forecast", "forecast")
  summarise <- function(x, role) {
    idx <- which(split == role)
    z <- x[idx, , drop = FALSE]
    slope <- if (nrow(z) > 1L) unname(coef(lm(q_true ~ source_index, data = z))[[2L]]) else NA_real_
    data.frame(
      window = role, n = nrow(z), source_start = min(z$source_index), source_end = max(z$source_index),
      q_mean = mean(z$q_true), q_sd = stats::sd(z$q_true), q_slope_per_100 = 100 * slope,
      innovation_mean = mean(z$y - z$q_true), innovation_sd = stats::sd(z$y - z$q_true),
      stringsAsFactors = FALSE
    )
  }
  out <- rbind(summarise(q, "pre_forecast"), summarise(q, "forecast"))
  pre <- out[out$window == "pre_forecast", , drop = FALSE]
  fore <- out[out$window == "forecast", , drop = FALSE]
  out$q_mean_shift_from_pre <- out$q_mean - pre$q_mean
  out$q_sd_ratio_to_pre <- out$q_sd / pre$q_sd
  out$slope_change_from_pre <- out$q_slope_per_100 - pre$q_slope_per_100
  out
}

qdesn_tpmv1_pair_paths <- function(candidate, parent) {
  keys <- c("forecast_origin_source_index", "forecast_lead", "target_source_index")
  keep <- c(keys, "qhat", "q_error", "abs_q_error", "pinball_tau")
  if (!all(keep %in% names(candidate)) || !all(keep %in% names(parent))) {
    stop("Forecast path data lack required columns.", call. = FALSE)
  }
  names(candidate)[match(setdiff(keep, keys), names(candidate))] <- paste0("candidate_", setdiff(keep, keys))
  names(parent)[match(setdiff(keep, keys), names(parent))] <- paste0("parent_", setdiff(keep, keys))
  out <- merge(candidate[, c(keys, paste0("candidate_", setdiff(keep, keys)))],
               parent[, c(keys, paste0("parent_", setdiff(keep, keys)))], by = keys, all = FALSE)
  out$delta_abs_error <- out$candidate_abs_q_error - out$parent_abs_q_error
  out$delta_pinball <- out$candidate_pinball_tau - out$parent_pinball_tau
  out$lead_band <- qdesn_tpmv1_band_lead(out$forecast_lead)
  out$origin_band <- qdesn_tpmv1_band_origin(out$forecast_origin_source_index)
  out
}

qdesn_tpmv1_group_summary <- function(x, group) {
  groups <- split(seq_len(nrow(x)), x[[group]], drop = TRUE)
  do.call(rbind, lapply(names(groups), function(label) {
    z <- x[groups[[label]], , drop = FALSE]
    data.frame(
      band_type = group, band = label, n = nrow(z),
      candidate_mae = mean(z$candidate_abs_q_error), parent_mae = mean(z$parent_abs_q_error),
      mae_ratio = mean(z$candidate_abs_q_error) / mean(z$parent_abs_q_error),
      candidate_bias = mean(z$candidate_q_error), parent_bias = mean(z$parent_q_error),
      qhat_shift = mean(z$candidate_qhat - z$parent_qhat),
      candidate_check = mean(z$candidate_pinball_tau), parent_check = mean(z$parent_pinball_tau),
      check_ratio = mean(z$candidate_pinball_tau) / mean(z$parent_pinball_tau),
      win_fraction_mae = mean(z$delta_abs_error < 0),
      stringsAsFactors = FALSE
    )
  }))
}

qdesn_tpmv1_decide <- function(source_summary, paired_summary, exal_summary) {
  article <- paired_summary[paired_summary$source_role == "frozen_article" &
                              paired_summary$band_type == "overall", , drop = FALSE]
  confirm <- paired_summary[paired_summary$source_role == "untouched_confirmation" &
                              paired_summary$band_type == "overall", , drop = FALSE]
  eligible_article <- article$arm_code[article$mae_ratio <= 0.95 & article$check_ratio <= 1.05]
  eligible_confirm <- confirm$arm_code[confirm$mae_ratio <= 0.95 & confirm$check_ratio <= 1.05]
  al_robust <- length(intersect(eligible_article, eligible_confirm)) > 0L
  exal_resolved <- nrow(exal_summary) &&
    any(exal_summary$median_max_core_acf1 <= 0.90 & exal_summary$median_min_core_ess_per_sec >= 0.25)
  if (al_robust) return("PREPARE_AL_MULTI_SOURCE_CONFIRMATION")
  if (exal_resolved) return("PREPARE_EXAL_FULL_BUDGET_CONFIRMATION")
  "STOP_REASSESS_MODEL_OR_SAMPLER"
}

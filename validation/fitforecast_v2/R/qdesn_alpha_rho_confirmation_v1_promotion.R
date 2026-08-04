qdesn_arfc1_promotion_review <- function(metrics, current_envelope) {
  metric_columns <- c(
    fit = "fit_qtrue_rmse",
    forecast_mae = "forecast_qtrue_mae_H1000",
    forecast_check = "forecast_check_loss_H1000"
  )
  required_metrics <- c(
    "target_cell_id", "family", "tau", "comparison_role",
    "reservoir_replicate", "screening_profile_id", "spec_id", "status",
    "signoff_grade", "stop_reason", "metric_complete",
    "seed_contract_match", "source_registry_hash_match",
    unname(metric_columns)
  )
  required_current <- c(
    "model_variant", "family", "tau", unname(metric_columns),
    "source_registry_hash_value"
  )
  missing_metrics <- setdiff(required_metrics, names(metrics))
  missing_current <- setdiff(required_current, names(current_envelope))
  if (length(missing_metrics) || length(missing_current)) {
    stop(sprintf(
      "Promotion review inputs are incomplete: metrics=[%s], current=[%s].",
      paste(missing_metrics, collapse = ", "),
      paste(missing_current, collapse = ", ")
    ), call. = FALSE)
  }
  if (nrow(metrics) != 8L || anyDuplicated(metrics$screening_profile_id)) {
    stop("Expected eight unique confirmation roots.", call. = FALSE)
  }
  if (any(metrics$status != "SUCCESS") ||
      any(!as.logical(metrics$metric_complete)) ||
      any(!as.logical(metrics$seed_contract_match)) ||
      any(!as.logical(metrics$source_registry_hash_match))) {
    stop("All confirmation roots must pass execution, metric, seed, and source gates.", call. = FALSE)
  }
  current <- current_envelope[
    current_envelope$model_variant == "qdesn_exal_rhs_ns",
    ,
    drop = FALSE
  ]
  if (nrow(current) != 9L) {
    stop("Current exAL-RHS authority is not the complete 3 x 3 grid.", call. = FALSE)
  }

  key <- paste(metrics$family, sprintf("%.8f", as.numeric(metrics$tau)))
  current_key <- paste(current$family, sprintf("%.8f", as.numeric(current$tau)))
  match_index <- match(key, current_key)
  if (anyNA(match_index)) {
    stop("A confirmation root has no current article-envelope cell.", call. = FALSE)
  }

  review <- metrics
  for (name in names(metric_columns)) {
    column <- metric_columns[[name]]
    current_column <- paste0("current_", column)
    ratio_column <- paste0(name, "_ratio_to_current")
    review[[current_column]] <- as.numeric(current[[column]][match_index])
    review[[ratio_column]] <-
      as.numeric(review[[column]]) / review[[current_column]]
  }
  review$companion_max_ratio <- pmax(
    review$fit_ratio_to_current,
    review$forecast_mae_ratio_to_current,
    review$forecast_check_ratio_to_current
  )
  review$all_metrics_improve_current <-
    review$fit_ratio_to_current < 1 &
    review$forecast_mae_ratio_to_current < 1 &
    review$forecast_check_ratio_to_current < 1
  review$manual_disposition <- "RETAIN_DIAGNOSTIC_EVIDENCE_NO_PROMOTION"
  review$manual_reason <- paste(
    "Does not satisfy the coherent all-metric promotion rule against the",
    "frozen article envelope."
  )

  approved <-
    review$target_cell_id == "exal_gausmix_t0p25" &
    review$comparison_role == "parent_exact" &
    as.integer(review$reservoir_replicate) == 1L &
    review$screening_profile_id == "arfc1_parent_exal_gausmix_t0p25_r01" &
    review$all_metrics_improve_current
  if (sum(approved) != 1L) {
    stop("The predeclared coherent Gaussian-mixture promotion root was not recovered.", call. = FALSE)
  }
  review$manual_disposition[approved] <-
    "PROMOTE_COHERENT_STATUS_AGNOSTIC_METRIC_ENVELOPE"
  review$manual_reason[approved] <- paste(
    "One completed root improves fit RMSE, forecast MAE, and forecast check",
    "loss simultaneously; diagnostic FAIL remains explicit and does not",
    "support a convergence or global-specification claim."
  )
  review$promotion_approved <- approved
  review
}

qdesn_arfc1_approved_promotion <- function(review) {
  required <- c(
    "promotion_approved", "screening_profile_id", "target_cell_id",
    "comparison_role", "reservoir_replicate", "all_metrics_improve_current",
    "companion_max_ratio"
  )
  missing <- setdiff(required, names(review))
  if (length(missing)) {
    stop(sprintf(
      "Promotion review is missing: %s.", paste(missing, collapse = ", ")
    ), call. = FALSE)
  }
  approved <- review[as.logical(review$promotion_approved), , drop = FALSE]
  if (nrow(approved) != 1L ||
      approved$screening_profile_id[[1L]] !=
        "arfc1_parent_exal_gausmix_t0p25_r01" ||
      approved$target_cell_id[[1L]] != "exal_gausmix_t0p25" ||
      approved$comparison_role[[1L]] != "parent_exact" ||
      as.integer(approved$reservoir_replicate[[1L]]) != 1L ||
      !isTRUE(approved$all_metrics_improve_current[[1L]]) ||
      as.numeric(approved$companion_max_ratio[[1L]]) >= 1) {
    stop("Manual promotion does not resolve to one coherent all-metric root.", call. = FALSE)
  }
  approved
}


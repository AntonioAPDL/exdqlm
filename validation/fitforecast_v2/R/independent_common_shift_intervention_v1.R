icsi_v1_schema <- "independent_qdesn_common_shift_intervention_v1"
icsi_v1_stage <- "qdesn_500obs_common_shift_intervention_v1"
icsi_v1_sources <- c("imi_v1_source_073", "imi_v1_source_075")
icsi_v1_workers <- 6L

icsi_v1_pool_effects <- function(state_root) {
  plan <- ffv2_read_csv(file.path(state_root, "manifests", "job_plan.csv"))
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    path <- file.path(plan$job_root[[i]], "tables",
                      "common_shift_intervention_effects.csv")
    x <- ffv2_read_csv(path)
    x$replay_id <- plan$replay_id[[i]]
    x$model_variant <- plan$model_variant[[i]]
    x$chain_id <- plan$chain_id[[i]]
    x
  })
  do.call(rbind, rows)
}

icsi_v1_decide <- function(effects) {
  keys <- unique(effects[c("replay_id", "model_variant", "intervention", "metric")])
  pooled <- do.call(rbind, lapply(seq_len(nrow(keys)), function(i) {
    keep <- Reduce(`&`, Map(function(name) {
      as.character(effects[[name]]) == as.character(keys[[name]][[i]])
    }, names(keys)))
    block <- effects[keep, , drop = FALSE]
    data.frame(
      keys[i, , drop = FALSE],
      mean_ratio = mean(block$mean_ratio),
      variance_ratio = mean(block$variance_ratio),
      width_ratio = mean(block$width_ratio),
      maximum_chain_variance_ratio = max(block$variance_ratio),
      n_chains = nrow(block), stringsAsFactors = FALSE
    )
  }))
  common <- pooled[pooled$intervention == "common_shift_removed" &
                     pooled$metric == "forecast_mae", , drop = FALSE]
  oracle <- pooled[pooled$intervention == "oracle_location_corrected" &
                     pooled$metric == "forecast_mae", , drop = FALSE]
  common$common_mode_gate <- common$variance_ratio <= 0.75 &
    common$maximum_chain_variance_ratio <= 0.85
  oracle$location_bias_gate <- oracle$mean_ratio <= 0.90
  decision <- merge(
    common[c("replay_id", "model_variant", "variance_ratio", "width_ratio",
             "common_mode_gate")],
    oracle[c("replay_id", "mean_ratio", "location_bias_gate")],
    by = "replay_id", suffixes = c("_common", "_oracle"), sort = FALSE
  )
  decision$recommended_next_action <- ifelse(
    decision$location_bias_gate,
    "authorize_matched_location_design_intervention",
    ifelse(decision$common_mode_gate,
           "audit_common_mode_parameterization_before_refit",
           "retain_authoritative_model_no_causal_refit")
  )
  list(pooled = pooled, decision = decision)
}

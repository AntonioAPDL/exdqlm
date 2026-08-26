#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/closeout_independent_origin_horizon_attribution_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/", mustWork = TRUE)
plan <- ffv2_read_csv(file.path(state_root, "manifests", "job_plan.csv"))
materialization <- ffv2_read_json(
  file.path(state_root, "manifests", "materialization_manifest.json")
)
phase <- as.character(materialization$phase)
expected_sources <- if (phase == "pilot") 2L else 7L
expected_jobs <- expected_sources * 3L
reused_pilot_jobs <- as.integer(materialization$reused_pilot_jobs %||% 0L)
newly_materialized_jobs <- as.integer(
  materialization$newly_materialized_jobs %||% expected_jobs
)
closeout_root <- ffv2_ensure_dir(file.path(state_root, "closeout"))
figure_root <- ffv2_ensure_dir(file.path(closeout_root, "figures"))

status_rows <- lapply(seq_len(nrow(plan)), function(i) {
  row <- plan[i, , drop = FALSE]
  status_path <- file.path(state_root, "status", paste0(row$job_id[[1L]], ".json"))
  status <- ffv2_read_json(status_path)
  job_root <- row$job_root[[1L]]
  data.frame(
    job_id = row$job_id[[1L]], replay_id = row$replay_id[[1L]],
    model_variant = row$model_variant[[1L]], family = row$family[[1L]],
    tau = row$tau[[1L]], chain_id = row$chain_id[[1L]],
    sentinel_role = row$sentinel_role[[1L]], status = as.character(status$status),
    config_sha256_match = identical(as.character(status$config_sha256),
                                    as.character(row$config_sha256[[1L]])),
    attribution_manifest_path = as.character(
      status$origin_horizon_attribution_manifest_path %||% ""
    ),
    attribution_manifest_sha256 = as.character(
      status$origin_horizon_attribution_manifest_sha256 %||% ""
    ),
    attribution_group_draws_path = as.character(
      status$attribution_group_draws_path %||% ""
    ),
    attribution_group_draws_sha256 = as.character(
      status$attribution_group_draws_sha256 %||% ""
    ),
    attribution_reconstruction_path = as.character(
      status$attribution_reconstruction_path %||% ""
    ),
    attribution_reconstruction_sha256 = as.character(
      status$attribution_reconstruction_sha256 %||% ""
    ),
    target_summary_path = file.path(job_root, "tables", "origin_horizon_target_summary.csv.gz"),
    path_structure_path = file.path(job_root, "tables", "origin_horizon_path_structure.csv"),
    parameter_associations_path = file.path(
      job_root, "tables", "origin_horizon_parameter_associations.csv.gz"
    ),
    job_root = job_root, heavy_binary_count = as.integer(status$heavy_binary_count %||% NA),
    stringsAsFactors = FALSE
  )
})
status_index <- do.call(rbind, status_rows)

hash_pairs <- list(
  attribution_manifest = c("attribution_manifest_path", "attribution_manifest_sha256"),
  attribution_group_draws = c("attribution_group_draws_path",
                              "attribution_group_draws_sha256"),
  attribution_reconstruction = c("attribution_reconstruction_path",
                                 "attribution_reconstruction_sha256")
)
for (name in names(hash_pairs)) {
  pair <- hash_pairs[[name]]
  status_index[[paste0(name, "_hash_match")]] <- vapply(seq_len(nrow(status_index)),
    function(i) {
      path <- status_index[[pair[[1L]]]][[i]]
      nzchar(path) && file.exists(path) && identical(
        ffv2_file_sha256(path), status_index[[pair[[2L]]]][[i]]
      )
    }, logical(1L))
}
hash_columns <- grep("_hash_match$", names(status_index), value = TRUE)

group_draws <- imoh_v1_pool_group_draws(status_index)
group_summary <- imoh_v1_pool_group_summary(group_draws)
variance <- imoh_v1_pool_variance(group_draws)
target_chain <- imoh_v1_read_chain_artifact(status_index, "target_summary_path")
path_structure <- imoh_v1_read_chain_artifact(status_index, "path_structure_path")
parameter_associations <- imoh_v1_read_chain_artifact(
  status_index, "parameter_associations_path"
)
parameter_signal <- imoh_v1_parameter_signal(parameter_associations)

target_keys <- c("replay_id", "model_variant", "family", "tau_level", "sentinel_role",
                 "origin_sequence_id", "forecast_origin_source_index", "forecast_lead",
                 "target_source_index")
target_measures <- c("q_true", "y", "posterior_mean_q", "posterior_sd_q",
                     "q_cri_width", "oracle_covered", "point_path_abs_error",
                     "posterior_mean_abs_error", "mae_jensen_gap",
                     "point_path_check_loss", "posterior_mean_check_loss",
                     "check_jensen_gap")
target_pooled <- stats::aggregate(
  target_chain[target_measures], target_chain[target_keys], mean, na.rm = TRUE
)
diagnosis <- imoh_v1_cell_diagnosis(
  group_summary, variance, target_pooled, path_structure, parameter_signal
)

reconstruction <- do.call(rbind, lapply(seq_len(nrow(status_index)), function(i) {
  x <- ffv2_read_csv(status_index$attribution_reconstruction_path[[i]])
  x$job_id <- status_index$job_id[[i]]
  x$replay_id <- status_index$replay_id[[i]]
  x$chain_id <- status_index$chain_id[[i]]
  x
}))
heavy <- unique(unlist(lapply(unique(plan$job_root), function(root) {
  if (!dir.exists(root)) return(character(0))
  list.files(root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
             full.names = TRUE, ignore.case = TRUE)
}), use.names = FALSE))
job_bytes <- vapply(unique(plan$job_root), function(root) {
  files <- list.files(root, recursive = TRUE, full.names = TRUE)
  sum(as.numeric(file.info(files)$size), na.rm = TRUE)
}, numeric(1L))
storage <- data.frame(
  jobs = length(job_bytes), total_compact_bytes = sum(job_bytes),
  maximum_job_bytes = max(job_bytes), heavy_binary_count = length(heavy),
  heavy_binary_bytes = if (length(heavy)) sum(as.numeric(file.info(heavy)$size)) else 0,
  stringsAsFactors = FALSE
)

origin_groups <- group_summary[
  group_summary$scope == "all_targets" & group_summary$group_type == "origin" &
    group_summary$metric == "forecast_mae", , drop = FALSE
]
lead_groups <- group_summary[
  group_summary$scope == "all_targets" & group_summary$group_type == "lead" &
    group_summary$metric == "forecast_mae", , drop = FALSE
]
checks <- data.frame(
  check = c("expected_jobs_success", "three_chains_per_source", "config_hashes_match",
            "terminal_hashes_match", "reconstruction_within_1e6", "all1000_present",
            "balanced990_present", "thirty_leads_present", "origins34_present",
            "finite_covariance_decomposition", "scientifically_informative_variation",
            "compact_job_under_100mib", "no_heavy_binaries"),
  pass = c(
    nrow(status_index) == expected_jobs && all(status_index$status == "SUCCESS"),
    all(table(status_index$replay_id) == 3L),
    all(status_index$config_sha256_match),
    all(as.matrix(status_index[hash_columns])),
    all(reconstruction$pass) &&
      max(reconstruction$forecast_mae_max_abs_error,
          reconstruction$forecast_check_max_abs_error) <= imoh_v1_reconstruction_tolerance,
    all(vapply(split(group_draws, group_draws$replay_id), function(x) {
      all(unique(x$n_targets[x$scope == "all_targets" & x$group_type == "all"]) == 1000L)
    }, logical(1L))),
    all(vapply(split(group_draws, group_draws$replay_id), function(x) {
      all(unique(x$n_targets[x$scope == "balanced_complete_origins" &
                               x$group_type == "all"]) == 990L)
    }, logical(1L))),
    all(table(lead_groups$replay_id) == 30L),
    all(table(origin_groups$replay_id) == 34L),
    all(is.finite(variance$total_variance)) && all(is.finite(variance$covariance_fraction)),
    all(vapply(split(lead_groups, lead_groups$replay_id), function(x) {
      stats::sd(x$posterior_mean) > 0 && stats::sd(x$cri_width) > 0
    }, logical(1L))) && all(vapply(split(origin_groups, origin_groups$replay_id), function(x) {
      stats::sd(x$posterior_mean) > 0 && stats::sd(x$cri_width) > 0
    }, logical(1L))),
    max(job_bytes) <= 100 * 1024^2,
    length(heavy) == 0L
  ), stringsAsFactors = FALSE
)

paths <- list(
  status = ffv2_write_csv(status_index, file.path(closeout_root, "job_artifact_audit.csv")),
  group_summary = ffv2_write_csv(group_summary,
                                 file.path(closeout_root, "pooled_group_summary.csv")),
  variance = ffv2_write_csv(variance,
                            file.path(closeout_root, "pooled_variance_decomposition.csv")),
  target = ffv2_write_csv(target_pooled,
                          file.path(closeout_root, "pooled_target_summary.csv")),
  path_structure = ffv2_write_csv(path_structure,
                                  file.path(closeout_root, "chain_path_structure.csv")),
  parameter_signal = ffv2_write_csv(parameter_signal,
                                    file.path(closeout_root, "rhs_parameter_signal.csv")),
  diagnosis = ffv2_write_csv(diagnosis,
                             file.path(closeout_root, "cell_mechanism_diagnosis.csv")),
  reconstruction = ffv2_write_csv(reconstruction,
                                  file.path(closeout_root, "reconstruction_audit.csv")),
  storage = ffv2_write_csv(storage, file.path(closeout_root, "storage_audit.csv")),
  checks = ffv2_write_csv(checks, file.path(closeout_root, "closeout_checks.csv"))
)

if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop("ggplot2 is required for origin-horizon diagnostic figures.", call. = FALSE)
}
lead_plot <- lead_groups
lead_plot$lead <- as.integer(lead_plot$group_value)
p <- ggplot2::ggplot(lead_plot, ggplot2::aes(
  x = lead, y = posterior_mean, ymin = cri_lower, ymax = cri_upper,
  colour = model_variant, fill = model_variant
)) +
  ggplot2::geom_ribbon(alpha = 0.12, colour = NA) +
  ggplot2::geom_line(linewidth = 0.45) + ggplot2::geom_point(size = 0.8) +
  ggplot2::facet_wrap(~ replay_id, scales = "free_y", ncol = 2) +
  ggplot2::labs(x = "Forecast lead", y = "Posterior draw-specific forecast MAE",
                title = "Forecast-risk heterogeneity across leads") +
  ggplot2::theme_bw(base_size = 9) + ggplot2::theme(legend.position = "bottom")
paths$lead_figure <- file.path(figure_root, "lead_risk_profiles.pdf")
ggplot2::ggsave(paths$lead_figure, p, width = 10, height = 9, device = grDevices::cairo_pdf)

origin_plot <- origin_groups
origin_plot$origin <- as.integer(origin_plot$group_value)
p <- ggplot2::ggplot(origin_plot, ggplot2::aes(
  x = origin, y = posterior_mean, ymin = cri_lower, ymax = cri_upper,
  colour = model_variant
)) + ggplot2::geom_linerange(linewidth = 0.3) + ggplot2::geom_point(size = 0.8) +
  ggplot2::facet_wrap(~ replay_id, scales = "free_y", ncol = 2) +
  ggplot2::labs(x = "Forecast origin", y = "Posterior draw-specific forecast MAE",
                title = "Forecast-risk heterogeneity across temporal blocks") +
  ggplot2::theme_bw(base_size = 9) + ggplot2::theme(legend.position = "bottom")
paths$origin_figure <- file.path(figure_root, "origin_risk_profiles.pdf")
ggplot2::ggsave(paths$origin_figure, p, width = 10, height = 9,
                device = grDevices::cairo_pdf)

p <- ggplot2::ggplot(target_pooled, ggplot2::aes(
  x = forecast_lead, y = origin_sequence_id, fill = posterior_sd_q
)) + ggplot2::geom_tile() +
  ggplot2::facet_wrap(~ replay_id, ncol = 2) +
  ggplot2::scale_fill_viridis_c(option = "C") +
  ggplot2::labs(x = "Forecast lead", y = "Origin sequence",
                fill = "Posterior SD", title = "Posterior quantile-path dispersion") +
  ggplot2::theme_bw(base_size = 9)
paths$dispersion_heatmap <- file.path(figure_root, "origin_lead_dispersion_heatmap.pdf")
ggplot2::ggsave(paths$dispersion_heatmap, p, width = 10, height = 9,
                device = grDevices::cairo_pdf)

p <- ggplot2::ggplot(target_pooled, ggplot2::aes(
  x = forecast_lead, y = origin_sequence_id, fill = point_path_abs_error
)) + ggplot2::geom_tile() +
  ggplot2::facet_wrap(~ replay_id, ncol = 2) +
  ggplot2::scale_fill_viridis_c(option = "B") +
  ggplot2::labs(x = "Forecast lead", y = "Origin sequence", fill = "Absolute error",
                title = "Posterior-mean quantile-path error") +
  ggplot2::theme_bw(base_size = 9)
paths$error_heatmap <- file.path(figure_root, "origin_lead_error_heatmap.pdf")
ggplot2::ggsave(paths$error_heatmap, p, width = 10, height = 9,
                device = grDevices::cairo_pdf)

paths <- lapply(paths, normalizePath, winslash = "/", mustWork = TRUE)
decision <- if (!all(checks$pass)) {
  "ORIGIN_HORIZON_ATTRIBUTION_CLOSEOUT_FAILED"
} else if (phase == "pilot") {
  "PILOT_PASS_AUTHORIZE_FULL_SEVEN_CELL_ATTRIBUTION"
} else if (any(diagnosis$tau0_causal_pilot_eligible)) {
  "ATTRIBUTION_COMPLETE_CASE_SPECIFIC_TAU0_CAUSAL_PILOT_ELIGIBLE"
} else {
  "ATTRIBUTION_COMPLETE_NO_TAU0_CAUSAL_PILOT_AUTHORIZED"
}

report_path <- file.path(closeout_root, "scientific_closeout.md")
lines <- c(
  "# Independent Q-DESN origin-horizon attribution closeout", "",
  sprintf("Decision: `%s`", decision), "",
  sprintf("Phase: `%s`; jobs: %d/%d; sources: %d.", phase,
          sum(status_index$status == "SUCCESS"), expected_jobs, expected_sources),
  sprintf("Verified pilot jobs reused: %d; newly executed full-phase jobs: %d.",
          reused_pilot_jobs, newly_materialized_jobs),
  "The authoritative 1,000-target metric and posterior-predictive recursion are unchanged.",
  "The balanced 990-target rectangle is diagnostic sensitivity evidence only.",
  "No article promotion or automatic tau0 launch is authorized by this script.", "",
  "## Cell diagnoses", "",
  paste0("- `", diagnosis$replay_id, "`: ", diagnosis$primary_pattern,
         "; late/early MAE ratio = ",
         format(round(diagnosis$late_to_early_mae_ratio, 3), nsmall = 3),
         "; origin covariance fraction = ",
         format(round(diagnosis$origin_covariance_fraction, 3), nsmall = 3),
         "; tau0 causal pilot eligible = ", diagnosis$tau0_causal_pilot_eligible, ".")
)
writeLines(lines, report_path)
paths$report <- normalizePath(report_path, winslash = "/", mustWork = TRUE)
manifest_out <- list(
  schema_version = imoh_v1_schema,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  phase = phase, decision = decision,
  jobs_completed = sum(status_index$status == "SUCCESS"), jobs_planned = expected_jobs,
  sources = expected_sources, article_update_authorized = FALSE,
  reused_pilot_jobs = reused_pilot_jobs,
  newly_materialized_jobs = newly_materialized_jobs,
  automatic_tau0_launch_authorized = FALSE,
  full_forecast_draw_matrix_retained = FALSE,
  heavy_binary_count = length(heavy),
  output_hashes = lapply(paths, ffv2_file_sha256)
)
ffv2_write_json(manifest_out, file.path(closeout_root, "decision_manifest.json"))
cat(sprintf("phase=%s decision=%s jobs=%d/%d sources=%d heavy=%d\n", phase, decision,
            manifest_out$jobs_completed, expected_jobs, expected_sources, length(heavy)))
if (!all(checks$pass)) quit(save = "no", status = 1L)

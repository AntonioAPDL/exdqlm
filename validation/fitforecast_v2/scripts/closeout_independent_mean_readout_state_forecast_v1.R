#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/closeout_independent_mean_readout_state_forecast_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/",
                            mustWork = TRUE)
setwd(repo_root)

defaults <- yaml::read_yaml(file.path(
  repo_root, "config", "validation",
  "independent_mean_readout_state_forecast_v1", "campaign_defaults.yaml"
))
fit_plan <- ffv2_read_csv(file.path(state_root, "manifests", "fit_plan.csv"))
forecast_plan <- ffv2_read_csv(
  file.path(state_root, "manifests", "forecast_plan.csv")
)
role_map <- ffv2_read_csv(file.path(state_root, "manifests", "role_map.csv"))
if (nrow(fit_plan) != 96L || nrow(forecast_plan) != 46L || nrow(role_map) != 72L) {
  stop("Closeout requires the complete 96/46/72 campaign surface.", call. = FALSE)
}
fit_complete <- vapply(seq_len(nrow(fit_plan)), function(i) {
  imrs_v1_status_success(
    state_root, "fit", fit_plan$job_id[[i]], fit_plan$config_sha256[[i]]
  )
}, logical(1L))
forecast_complete <- vapply(seq_len(nrow(forecast_plan)), function(i) {
  imrs_v1_status_success(
    state_root, "forecast", forecast_plan$forecast_id[[i]],
    forecast_plan$config_sha256[[i]]
  )
}, logical(1L))
if (!all(fit_complete) || !all(forecast_complete)) {
  stop("Partial results cannot enter scientific closeout.", call. = FALSE)
}

fit_statuses <- lapply(fit_plan$job_id, function(id) {
  imrs_v1_read_json(imrs_v1_status_path(state_root, "fit", id))
})
native_authority_ledger <- do.call(rbind, Map(function(status, id) {
  path <- normalizePath(
    status$native_authority_parity_path, winslash = "/", mustWork = TRUE
  )
  if (!identical(ffv2_file_sha256(path),
                 as.character(status$native_authority_parity_sha256))) {
    stop("Historical native-authority parity hash mismatch: ", id,
         call. = FALSE)
  }
  out <- ffv2_read_csv(path)
  out$fit_job_id <- id
  out
}, fit_statuses, fit_plan$job_id))
if (nrow(native_authority_ledger) != 2L * nrow(fit_plan) ||
    !all(native_authority_ledger$pass)) {
  stop("At least one fit failed historical native-authority reproduction.",
       call. = FALSE)
}

read_forecast_output <- function(i) {
  row <- forecast_plan[i, , drop = FALSE]
  status <- imrs_v1_read_json(imrs_v1_status_path(
    state_root, "forecast", row$forecast_id[[1L]]
  ))
  manifest_path <- normalizePath(
    status$artifact_manifest_path, winslash = "/", mustWork = TRUE
  )
  if (!identical(ffv2_file_sha256(manifest_path),
                 as.character(status$artifact_manifest_sha256))) {
    stop("Forecast artifact-manifest hash mismatch: ", row$forecast_id[[1L]])
  }
  manifest <- ffv2_read_csv(manifest_path)
  observed <- vapply(manifest$path, ffv2_file_sha256, character(1L))
  if (any(observed != manifest$sha256)) {
    stop("Forecast artifact hash mismatch: ", row$forecast_id[[1L]])
  }
  read_artifact <- function(name) {
    path <- manifest$path[match(name, manifest$artifact)]
    if (length(path) != 1L || is.na(path)) stop("Missing artifact: ", name)
    ffv2_read_csv(path)
  }
  list(
    plan = row, status = status,
    native_draws = read_artifact("native_draws"),
    candidate_draws = read_artifact("candidate_draws"),
    native_intervals = read_artifact("native_intervals"),
    candidate_intervals = read_artifact("candidate_intervals"),
    native_point = read_artifact("native_point"),
    candidate_point = read_artifact("candidate_point"),
    profiles = read_artifact("profiles"),
    dispersion = read_artifact("dispersion"),
    stability = read_artifact("stability"),
    parity = read_artifact("parity"),
    innovation_pairing = read_artifact("innovation_pairing")
  )
}
forecast_outputs <- lapply(seq_len(nrow(forecast_plan)), read_forecast_output)
if (any(vapply(forecast_outputs, function(x) !all(x$parity$pass), logical(1L)))) {
  stop("At least one forecast failed native-artifact consistency.", call. = FALSE)
}

write_csv_gz_atomic <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(path, ".tmp.", Sys.getpid())
  con <- gzfile(tmp, open = "wt")
  on.exit({
    try(close(con), silent = TRUE)
    unlink(tmp, force = TRUE)
  }, add = TRUE)
  utils::write.csv(x, con, row.names = FALSE, na = "")
  close(con)
  if (!file.rename(tmp, path)) stop("Could not publish compressed CSV: ", path)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

metric_names <- c("forecast_mae", "forecast_check_loss")
source_ids <- unique(role_map$source_id)
source_intervals <- list()
source_points <- list()
source_draws <- list()
si <- sp <- sd_i <- 0L
for (source_id in source_ids) {
  blocks <- forecast_outputs[vapply(forecast_outputs, function(x) {
    identical(as.character(x$plan$source_id[[1L]]), as.character(source_id))
  }, logical(1L))]
  if (!length(blocks)) stop("No forecast output for source: ", source_id)
  for (estimator in c("native", "candidate")) {
    draw_blocks <- lapply(blocks, `[[`, paste0(estimator, "_draws"))
    point_blocks <- lapply(blocks, `[[`, paste0(estimator, "_point"))
    if (length(blocks) > 1L) {
      n_keep <- min(vapply(draw_blocks, nrow, integer(1L)))
      draw_blocks <- lapply(draw_blocks, function(x) {
        idx <- unique(as.integer(round(seq(1, nrow(x), length.out = n_keep))))
        x[idx, , drop = FALSE]
      })
    }
    draws <- do.call(rbind, draw_blocks)
    estimator_id <- if (identical(estimator, "native")) {
      "native_posterior_predictive"
    } else imrs_v1_estimator
    intervals <- imrs_v1_interval_summary(draws, estimator_id)
    metadata <- blocks[[1L]]$plan
    intervals$source_id <- source_id
    intervals$inference <- metadata$inference[[1L]]
    intervals$likelihood_family <- metadata$likelihood_family[[1L]]
    intervals$family <- metadata$family[[1L]]
    intervals$tau <- metadata$tau[[1L]]
    intervals$pooling_policy <- metadata$pooling_policy[[1L]]
    intervals$basis_evaluations <- length(blocks)
    si <- si + 1L
    source_intervals[[si]] <- intervals

    point_values <- vapply(metric_names, function(metric) {
      mean(vapply(point_blocks, function(x) as.numeric(x[[metric]][[1L]]),
                  numeric(1L)))
    }, numeric(1L))
    points <- data.frame(
      metric = metric_names, point_score = as.numeric(point_values),
      estimator_id = estimator_id, source_id = source_id,
      inference = metadata$inference[[1L]],
      likelihood_family = metadata$likelihood_family[[1L]],
      family = metadata$family[[1L]], tau = metadata$tau[[1L]],
      pooling_policy = metadata$pooling_policy[[1L]],
      basis_evaluations = length(blocks), stringsAsFactors = FALSE
    )
    sp <- sp + 1L
    source_points[[sp]] <- points

    draws$source_id <- source_id
    draws$source_estimator_id <- estimator_id
    draws$basis_evaluations <- length(blocks)
    sd_i <- sd_i + 1L
    source_draws[[sd_i]] <- draws
  }
}
source_interval_ledger <- do.call(rbind, source_intervals)
source_point_ledger <- do.call(rbind, source_points)
source_draw_ledger <- do.call(rbind, source_draws)
rownames(source_interval_ledger) <- rownames(source_point_ledger) <- NULL

lookup_one <- function(ledger, source_id, estimator_id, metric) {
  x <- ledger[
    ledger$source_id == source_id & ledger$estimator_id == estimator_id &
      ledger$metric == metric,
    , drop = FALSE
  ]
  if (nrow(x) != 1L) {
    stop("Expected one source/estimator/metric record: ",
         paste(source_id, estimator_id, metric, sep = "|"))
  }
  x
}

role_rows <- lapply(seq_len(nrow(role_map)), function(i) {
  role <- role_map[i, , drop = FALSE]
  metric <- as.character(role$metric_role[[1L]])
  native_i <- lookup_one(
    source_interval_ledger, role$source_id[[1L]],
    "native_posterior_predictive", metric
  )
  candidate_i <- lookup_one(
    source_interval_ledger, role$source_id[[1L]], imrs_v1_estimator, metric
  )
  native_p <- lookup_one(
    source_point_ledger, role$source_id[[1L]],
    "native_posterior_predictive", metric
  )
  candidate_p <- lookup_one(
    source_point_ledger, role$source_id[[1L]], imrs_v1_estimator, metric
  )
  data.frame(
    inference = role$inference[[1L]],
    likelihood_family = role$likelihood_family[[1L]],
    family = role$family[[1L]], tau = role$tau[[1L]],
    metric = metric, source_id = role$source_id[[1L]],
    pooling_policy = role$pooling_policy[[1L]],
    native_point_score = native_p$point_score[[1L]],
    candidate_point_score = candidate_p$point_score[[1L]],
    point_score_ratio = candidate_p$point_score[[1L]] /
      native_p$point_score[[1L]],
    native_posterior_mean = native_i$posterior_mean[[1L]],
    candidate_posterior_mean = candidate_i$posterior_mean[[1L]],
    native_cri_lower = native_i$cri_lower[[1L]],
    candidate_cri_lower = candidate_i$cri_lower[[1L]],
    native_cri_upper = native_i$cri_upper[[1L]],
    candidate_cri_upper = candidate_i$cri_upper[[1L]],
    native_interval_width = native_i$interval_width[[1L]],
    candidate_interval_width = candidate_i$interval_width[[1L]],
    interval_width_ratio = candidate_i$interval_width[[1L]] /
      native_i$interval_width[[1L]],
    stringsAsFactors = FALSE
  )
})
role_comparison <- do.call(rbind, role_rows)

parity_ledger <- do.call(rbind, lapply(forecast_outputs, function(x) {
  out <- x$parity
  out$forecast_id <- x$plan$forecast_id[[1L]]
  out$source_id <- x$plan$source_id[[1L]]
  out
}))
innovation_pairing_ledger <- do.call(rbind, lapply(
  forecast_outputs, function(x) x$innovation_pairing
))
primary_pairing <- innovation_pairing_ledger[
  innovation_pairing_ledger$stream == "primary", , drop = FALSE
]
pairing_gate <- nrow(primary_pairing) == nrow(fit_plan) &&
  !anyDuplicated(primary_pairing$fit_job_id) &&
  setequal(primary_pairing$fit_job_id, fit_plan$job_id) &&
  all(primary_pairing$tail_seed_offset == 31L) &&
  all(primary_pairing$tail_seed - primary_pairing$full_seed == 31L) &&
  all(primary_pairing$complete_origin_count == 33L) &&
  all(primary_pairing$tail_origin_count == 1L) &&
  all(primary_pairing$source_draw_count >= primary_pairing$selected_draw_count) &&
  all(grepl("^[0-9a-f]{64}$", primary_pairing$selected_draw_indices_sha256))
stability_ledger <- do.call(rbind, lapply(forecast_outputs, function(x) {
  out <- x$stability
  if (!nrow(out)) return(NULL)
  out$forecast_id <- x$plan$forecast_id[[1L]]
  out$source_id <- x$plan$source_id[[1L]]
  out$inference <- x$plan$inference[[1L]]
  out$likelihood_family <- x$plan$likelihood_family[[1L]]
  out$family <- x$plan$family[[1L]]
  out$tau <- x$plan$tau[[1L]]
  out
}))
profile_ledger <- do.call(rbind, lapply(forecast_outputs, function(x) x$profiles))
dispersion_ledger <- do.call(rbind, lapply(forecast_outputs, function(x) {
  out <- x$dispersion
  if (nrow(out)) out$forecast_id <- x$plan$forecast_id[[1L]]
  out
}))

rules <- defaults$decision_rules
finite_gate <- all(vapply(
  role_comparison[vapply(role_comparison, is.numeric, logical(1L))],
  function(x) all(is.finite(x)), logical(1L)
))
median_width_ratio <- stats::median(role_comparison$interval_width_ratio)
improved_width_fraction <- mean(role_comparison$interval_width_ratio < 1)
median_point_ratio <- stats::median(role_comparison$point_score_ratio)
maximum_point_ratio <- max(role_comparison$point_score_ratio)
decision_checks <- c(
  full_surface = nrow(role_comparison) == 72L,
  finite_scores = finite_gate,
  native_artifact_consistency = all(parity_ledger$pass) &&
    max(parity_ledger$max_abs_difference) <= imrs_v1_tolerance,
  historical_native_authority = all(native_authority_ledger$pass) &&
    max(native_authority_ledger$max_abs_difference) <= imrs_v1_tolerance,
  innovation_pairing = isTRUE(pairing_gate),
  median_width = median_width_ratio <=
    as.numeric(rules$median_interval_width_ratio_max),
  width_roles = improved_width_fraction >=
    as.numeric(rules$improved_interval_role_fraction_min),
  median_point = median_point_ratio <=
    as.numeric(rules$median_point_score_ratio_max),
  maximum_point = maximum_point_ratio <=
    as.numeric(rules$maximum_point_score_ratio_max),
  stability_evidence = nrow(stability_ledger) > 0L &&
    all(is.finite(stability_ledger$max_abs_difference))
)
decision <- if (!all(decision_checks[c(
  "full_surface", "finite_scores", "native_artifact_consistency",
  "historical_native_authority", "innovation_pairing", "stability_evidence"
)])) {
  "BLOCKED_PROVENANCE_OR_IMPLEMENTATION_FAILURE"
} else if (all(decision_checks)) {
  "ACCEPT_MEAN_READOUT_STATE_FOR_FULL_QDESN_SURFACE"
} else {
  "RETAIN_NATIVE_QDESN_FORECAST_RECURSION"
}

closeout_root <- file.path(state_root, "closeout")
dir.create(closeout_root, recursive = TRUE, showWarnings = FALSE)
paths <- list(
  source_intervals = imrs_v1_atomic_write_csv(
    source_interval_ledger, file.path(closeout_root, "source_interval_ledger.csv")
  ),
  source_points = imrs_v1_atomic_write_csv(
    source_point_ledger, file.path(closeout_root, "source_point_ledger.csv")
  ),
  source_draws = write_csv_gz_atomic(
    source_draw_ledger, file.path(closeout_root, "source_draw_metrics.csv.gz")
  ),
  role_comparison = imrs_v1_atomic_write_csv(
    role_comparison, file.path(closeout_root, "role_level_comparison.csv")
  ),
  parity = imrs_v1_atomic_write_csv(
    parity_ledger, file.path(closeout_root, "native_artifact_consistency.csv")
  ),
  innovation_pairing = imrs_v1_atomic_write_csv(
    innovation_pairing_ledger,
    file.path(closeout_root, "innovation_pairing_ledger.csv")
  ),
  historical_native_authority = imrs_v1_atomic_write_csv(
    native_authority_ledger,
    file.path(closeout_root, "historical_native_authority_parity.csv")
  ),
  stability = imrs_v1_atomic_write_csv(
    stability_ledger, file.path(closeout_root, "integration_stability.csv")
  ),
  profiles = write_csv_gz_atomic(
    profile_ledger, file.path(closeout_root, "forecast_profiles.csv.gz")
  ),
  dispersion = write_csv_gz_atomic(
    dispersion_ledger, file.path(closeout_root, "state_readout_dispersion.csv.gz")
  )
)

if (!requireNamespace("ggplot2", quietly = TRUE)) stop("ggplot2 is required.")
interval_plot_data <- rbind(
  data.frame(
    role_comparison[c(
      "inference", "likelihood_family", "family", "tau", "metric", "source_id"
    )],
    posterior_mean = role_comparison$native_posterior_mean,
    cri_lower = role_comparison$native_cri_lower,
    cri_upper = role_comparison$native_cri_upper,
    estimator = "Native", stringsAsFactors = FALSE
  ),
  data.frame(
    role_comparison[c(
      "inference", "likelihood_family", "family", "tau", "metric", "source_id"
    )],
    posterior_mean = role_comparison$candidate_posterior_mean,
    cri_lower = role_comparison$candidate_cri_lower,
    cri_upper = role_comparison$candidate_cri_upper,
    estimator = "Mean readout state", stringsAsFactors = FALSE
  )
)
pdf_path <- file.path(closeout_root, "mean_readout_state_diagnostic_packet.pdf")
grDevices::pdf(pdf_path, width = 11, height = 8.5, onefile = TRUE)
for (inference_value in c("vb", "mcmc")) {
  for (metric_value in c("forecast_mae", "forecast_check_loss")) {
    d <- interval_plot_data[
      interval_plot_data$inference == inference_value &
        interval_plot_data$metric == metric_value, , drop = FALSE
    ]
    d$tau_label <- paste0("p = ", format(d$tau, nsmall = 2L))
    p <- ggplot2::ggplot(
      d, ggplot2::aes(x = posterior_mean, y = tau_label, colour = estimator)
    ) +
      ggplot2::geom_errorbarh(
        ggplot2::aes(xmin = cri_lower, xmax = cri_upper),
        position = ggplot2::position_dodge(width = 0.45), height = 0
      ) +
      ggplot2::geom_point(
        shape = 4, size = 2.4, stroke = 0.8,
        position = ggplot2::position_dodge(width = 0.45)
      ) +
      ggplot2::facet_grid(likelihood_family ~ family, scales = "free_x") +
      ggplot2::scale_colour_manual(values = c(
        Native = "#4D4D4D", `Mean readout state` = "#0072B2"
      )) +
      ggplot2::labs(
        title = paste(toupper(inference_value), metric_value),
        x = "Posterior score mean and equal-tailed 95% interval", y = NULL,
        colour = "Forecast recursion"
      ) +
      ggplot2::theme_bw(base_size = 10) +
      ggplot2::theme(legend.position = "bottom")
    print(p)
  }
}
ratio_plot <- ggplot2::ggplot(
  role_comparison,
  ggplot2::aes(
    x = interval_width_ratio,
    y = interaction(family, tau, likelihood_family, sep = " | "),
    colour = inference, shape = metric
  )
) +
  ggplot2::geom_vline(xintercept = 1, linetype = 2, colour = "black") +
  ggplot2::geom_point(size = 2, alpha = 0.8) +
  ggplot2::facet_wrap(~inference, scales = "free_y") +
  ggplot2::scale_colour_manual(values = c(vb = "#009E73", mcmc = "#D55E00")) +
  ggplot2::labs(
    title = "Interval-width ratio: mean-readout-state / native recursion",
    x = "Width ratio (values below 1 are narrower)", y = NULL
  ) + ggplot2::theme_bw(base_size = 10) +
  ggplot2::theme(legend.position = "bottom")
print(ratio_plot)
scatter <- ggplot2::ggplot(
  role_comparison,
  ggplot2::aes(
    x = native_point_score, y = candidate_point_score,
    colour = likelihood_family, shape = metric
  )
) +
  ggplot2::geom_abline(slope = 1, intercept = 0, linetype = 2) +
  ggplot2::geom_point(size = 2, alpha = 0.8) +
  ggplot2::facet_grid(inference ~ family, scales = "free") +
  ggplot2::scale_colour_manual(values = c(al = "#0072B2", exal = "#CC79A7")) +
  ggplot2::labs(
    title = "Point-score comparison", x = "Native recursion",
    y = "Mean-readout-state recursion"
  ) + ggplot2::theme_bw(base_size = 10) +
  ggplot2::theme(legend.position = "bottom")
print(scatter)
if (nrow(stability_ledger)) {
  stability_ledger$plot_difference <- pmax(
    stability_ledger$max_abs_difference, 1e-16
  )
  p_stability <- ggplot2::ggplot(
    stability_ledger,
    ggplot2::aes(x = comparison, y = plot_difference, colour = quantity)
  ) +
    ggplot2::geom_point(position = ggplot2::position_jitter(width = 0.12),
                        alpha = 0.75) +
    ggplot2::scale_y_log10() +
    ggplot2::facet_wrap(~metric, scales = "free_y") +
    ggplot2::labs(
      title = "Canary Monte Carlo integration sensitivity",
      x = NULL, y = "Maximum absolute difference (log scale)"
    ) + ggplot2::theme_bw(base_size = 10) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 20, hjust = 1))
  print(p_stability)
}
grDevices::dev.off()
paths$diagnostic_pdf <- normalizePath(pdf_path, winslash = "/", mustWork = TRUE)

decision_payload <- list(
  schema_version = imrs_v1_schema,
  decision = decision, checks = as.list(decision_checks),
  summary = list(
    role_rows = nrow(role_comparison), source_identities = length(source_ids),
    median_interval_width_ratio = median_width_ratio,
    improved_interval_role_fraction = improved_width_fraction,
    median_point_score_ratio = median_point_ratio,
    maximum_point_score_ratio = maximum_point_ratio,
    primary_innovation_pairing_records = nrow(primary_pairing),
    expected_primary_innovation_pairing_records = nrow(fit_plan),
    innovation_pairing_gate = isTRUE(pairing_gate),
    native_artifact_consistency_max_abs_difference =
      max(parity_ledger$max_abs_difference),
    historical_native_authority_max_abs_difference =
      max(native_authority_ledger$max_abs_difference)
  ),
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  git_commit = system("git rev-parse HEAD", intern = TRUE)
)
decision_path <- imrs_v1_atomic_write_json(
  decision_payload, file.path(closeout_root, "scientific_decision.json")
)
paths$decision <- decision_path

closeout_md <- c(
  "# Independent Q-DESN mean-readout-state forecast closeout",
  "",
  paste0("Decision: `", decision, "`"),
  "",
  "The campaign held every fitted Q-DESN winner fixed and changed only the",
  "recursive forecast estimator. Each fit produced the native authority once;",
  "its hash-verified draw and path artifacts passed an internal-summary",
  "consistency check at the predeclared absolute tolerance of `1e-6`.",
  "",
  "| Quantity | Result |",
  "|---|---:|",
  sprintf("| Fit reconstructions | %d/%d |", sum(fit_complete), nrow(fit_plan)),
  sprintf("| Basis forecast evaluations | %d/%d |", sum(forecast_complete),
          nrow(forecast_plan)),
  sprintf("| Article metric roles | %d |", nrow(role_comparison)),
  sprintf("| Median interval-width ratio | %.6f |", median_width_ratio),
  sprintf("| Roles with narrower intervals | %.1f%% |",
          100 * improved_width_fraction),
  sprintf("| Median point-score ratio | %.6f |", median_point_ratio),
  sprintf("| Maximum point-score ratio | %.6f |", maximum_point_ratio),
  sprintf("| Primary innovation-pairing records | %d/%d |",
          nrow(primary_pairing), nrow(fit_plan)),
  sprintf("| Innovation-pairing gate | %s |",
          if (isTRUE(pairing_gate)) "PASS" else "FAIL"),
  sprintf("| Native-artifact maximum consistency difference | %.3e |",
          max(parity_ledger$max_abs_difference)),
  sprintf("| Historical native-authority maximum difference | %.3e |",
          max(native_authority_ledger$max_abs_difference)),
  "",
  "A decision of `ACCEPT_MEAN_READOUT_STATE_FOR_FULL_QDESN_SURFACE` creates a",
  "candidate article replacement packet. A retain decision leaves the current",
  "native article authority unchanged. Integration and publication remain the",
  "responsibility of the coordinator lane."
)
closeout_md_path <- file.path(closeout_root, "scientific_closeout.md")
writeLines(closeout_md, closeout_md_path, useBytes = TRUE)
paths$scientific_closeout <- normalizePath(
  closeout_md_path, winslash = "/", mustWork = TRUE
)

handoff_lines <- c(
  "# Integration handoff: independent mean-readout-state forecast v1",
  "",
  paste0("Scientific decision: `", decision, "`"),
  paste0("Worktree: `", repo_root, "`"),
  paste0("Branch: `", system("git branch --show-current", intern = TRUE), "`"),
  paste0("Execution commit: `", system("git rev-parse HEAD", intern = TRUE), "`"),
  paste0("Run root: `", state_root, "`"),
  "",
  "The coordinator must independently verify the run before any article edit.",
  "No Article-v2, shared-validation, or Overleaf branch was modified here.",
  "DQLM/exDQLM rows and all fit-window metrics remain unchanged."
)
handoff_path <- file.path(closeout_root, "integration_handoff.md")
writeLines(handoff_lines, handoff_path, useBytes = TRUE)
paths$handoff <- normalizePath(handoff_path, winslash = "/", mustWork = TRUE)

prune_files <- list.files(
  file.path(state_root, "capsules"), pattern = "[.]rds$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
prune_manifest <- if (length(prune_files)) data.frame(
  path = normalizePath(prune_files, winslash = "/", mustWork = TRUE),
  bytes = as.numeric(file.info(prune_files)$size),
  sha256 = vapply(prune_files, ffv2_file_sha256, character(1L)),
  action = "deleted_after_complete_verified_scientific_closeout",
  stringsAsFactors = FALSE
) else data.frame(
  path = character(), bytes = numeric(), sha256 = character(),
  action = character(), stringsAsFactors = FALSE
)
prune_path <- imrs_v1_atomic_write_csv(
  prune_manifest, file.path(closeout_root, "capsule_prune_manifest.csv")
)
paths$capsule_prune_manifest <- prune_path
if (length(prune_files)) unlink(prune_files, force = TRUE)
if (length(list.files(
  file.path(state_root, "capsules"), pattern = "[.]rds$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
))) stop("Capsule pruning was incomplete.", call. = FALSE)

path_vector <- unlist(paths, use.names = FALSE)
artifact_manifest <- data.frame(
  artifact = names(paths), path = path_vector,
  bytes = as.numeric(file.info(path_vector)$size),
  sha256 = vapply(path_vector, ffv2_file_sha256, character(1L)),
  stringsAsFactors = FALSE
)
artifact_manifest_path <- imrs_v1_atomic_write_csv(
  artifact_manifest, file.path(closeout_root, "closeout_artifact_manifest.csv")
)
imrs_v1_atomic_write_json(list(
  schema_version = imrs_v1_schema, status = "SUCCESS", decision = decision,
  fit_jobs = nrow(fit_plan), forecast_jobs = nrow(forecast_plan),
  role_rows = nrow(role_comparison), source_identities = length(source_ids),
  artifact_manifest_path = artifact_manifest_path,
  artifact_manifest_sha256 = ffv2_file_sha256(artifact_manifest_path),
  capsule_files_pruned = nrow(prune_manifest),
  capsule_bytes_pruned = sum(prune_manifest$bytes),
  completed_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
), file.path(closeout_root, "closeout_manifest.json"))
cat(sprintf(
  "CLOSEOUT_COMPLETE decision=%s fits=%d forecasts=%d roles=%d pruned=%.3f_GiB\n",
  decision, nrow(fit_plan), nrow(forecast_plan), nrow(role_comparison),
  sum(prune_manifest$bytes) / 1024^3
))

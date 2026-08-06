#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(jsonlite))
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
repo <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/")
setwd(repo)
source("validation/fitforecast_v2/R/qdesn_trainonly_postmortem_v1.R")
state <- normalizePath(get_arg("--state-root", "reports/shared_fitforecast_v2_orchestration/qdesn_trainonly_followup_v1_20260805_205744"), winslash = "/")
closeout <- file.path(state, "closeout")
out <- normalizePath(get_arg("--output-root", file.path(closeout, "mechanistic_postmortem_v1")), winslash = "/", mustWork = FALSE)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
read_csv <- function(p) utils::read.csv(p, check.names = FALSE, stringsAsFactors = FALSE)
write_csv <- function(x, name) utils::write.csv(x, file.path(out, name), row.names = FALSE, na = "")

inventory <- read_csv(file.path(closeout, "run_inventory.csv"))
metrics <- read_csv(file.path(closeout, "qdesn_metrics.csv"))
exal <- read_csv(file.path(closeout, "exal_sampler_summary.csv"))
al <- metrics[metrics$experiment == "al_confirmation", , drop = FALSE]

source_rows <- list(); paired_rows <- list(); band_rows <- list()
for (scenario in unique(al$source_scenario)) {
  rows <- al[al$source_scenario == scenario, , drop = FALSE]
  source_role <- if (grepl("m0amp_highnoise", scenario)) "frozen_article" else "untouched_confirmation"
  sample_fit <- rows$fit_summary_path[[1L]]
  root <- dirname(dirname(dirname(sample_fit)))
  q_path <- file.path(root, "data", "q_true.csv")
  q <- read_csv(q_path)
  ss <- qdesn_tpmv1_summarise_source(q)
  ss$source_scenario <- scenario; ss$source_role <- source_role
  ss$q_true_path <- normalizePath(q_path, winslash = "/")
  ss$q_true_sha256 <- unname(tools::sha256sum(q_path))
  source_rows[[scenario]] <- ss

  for (seed in unique(rows$paired_reservoir_seed)) {
    z <- rows[rows$paired_reservoir_seed == seed, , drop = FALSE]
    parent <- z[z$arm_code == "parent_exact", , drop = FALSE]
    candidates <- z[z$arm_code != "parent_exact", , drop = FALSE]
    if (nrow(parent) != 1L) next
    pp <- file.path(dirname(parent$fit_summary_path), "tables", "forecast_rolling_origin_paths.csv")
    parent_path <- read_csv(pp)
    for (i in seq_len(nrow(candidates))) {
      cp <- file.path(dirname(candidates$fit_summary_path[[i]]), "tables", "forecast_rolling_origin_paths.csv")
      pair <- qdesn_tpmv1_pair_paths(read_csv(cp), parent_path)
      pair$source_scenario <- scenario; pair$source_role <- source_role
      pair$reservoir_seed <- seed; pair$arm_code <- candidates$arm_code[[i]]
      paired_rows[[length(paired_rows) + 1L]] <- pair
      overall <- data.frame(
        band_type = "overall", band = "all", n = nrow(pair),
        candidate_mae = mean(pair$candidate_abs_q_error), parent_mae = mean(pair$parent_abs_q_error),
        mae_ratio = mean(pair$candidate_abs_q_error) / mean(pair$parent_abs_q_error),
        candidate_bias = mean(pair$candidate_q_error), parent_bias = mean(pair$parent_q_error),
        qhat_shift = mean(pair$candidate_qhat - pair$parent_qhat),
        candidate_check = mean(pair$candidate_pinball_tau), parent_check = mean(pair$parent_pinball_tau),
        check_ratio = mean(pair$candidate_pinball_tau) / mean(pair$parent_pinball_tau),
        win_fraction_mae = mean(pair$delta_abs_error < 0)
      )
      bands <- rbind(overall, qdesn_tpmv1_group_summary(pair, "lead_band"),
                     qdesn_tpmv1_group_summary(pair, "origin_band"))
      bands$source_scenario <- scenario; bands$source_role <- source_role
      bands$reservoir_seed <- seed; bands$arm_code <- candidates$arm_code[[i]]
      band_rows[[length(band_rows) + 1L]] <- bands
    }
  }
}

sources <- do.call(rbind, source_rows)
paired <- do.call(rbind, paired_rows)
bands <- do.call(rbind, band_rows)
aggregate_metric <- function(x) median(x[is.finite(x)])
summary <- aggregate(cbind(mae_ratio, candidate_bias, parent_bias, qhat_shift, check_ratio, win_fraction_mae) ~ source_scenario + source_role + arm_code + band_type + band,
                     data = bands, FUN = aggregate_metric)
decision <- qdesn_tpmv1_decide(sources, summary, exal)

write_csv(sources, "source_shift_summary.csv")
write_csv(paired, "paired_origin_lead_deltas.csv")
write_csv(bands, "paired_seed_band_summary.csv")
write_csv(summary, "source_arm_band_summary.csv")
candidate <- data.frame(
  decision = character(), candidate_type = character(), target_cell = character(),
  reason = character(), stringsAsFactors = FALSE
)
write_csv(candidate, "next_candidate_manifest.csv")

gate <- list(
  generated_at = as.character(Sys.time()),
  input_followup_gate_sha256 = unname(tools::sha256sum(file.path(closeout, "followup_gate.json"))),
  decision = decision,
  compute_launched = FALSE,
  article_update_allowed = FALSE,
  candidate_count = nrow(candidate),
  al_multi_source_gate = "same arm must have median MAE ratio <=0.95 and check ratio <=1.05 on frozen article and untouched confirmation sources",
  exal_geometry_gate = "median max core ACF1 <=0.90 and median minimum core ESS/sec >=0.25",
  evidence = list(
    source_shift = file.path(out, "source_shift_summary.csv"),
    paired_origin_lead = file.path(out, "paired_origin_lead_deltas.csv"),
    paired_seed_bands = file.path(out, "paired_seed_band_summary.csv"),
    source_arm_bands = file.path(out, "source_arm_band_summary.csv"),
    candidates = file.path(out, "next_candidate_manifest.csv")
  )
)
write_json(gate, file.path(out, "postmortem_gate.json"), pretty = TRUE, auto_unbox = TRUE, null = "null")
article_overall <- summary[summary$source_role == "frozen_article" & summary$band_type == "overall", ]
confirm_overall <- summary[summary$source_role == "untouched_confirmation" & summary$band_type == "overall", ]
writeLines(c(
  "# Q-DESN Train-Only Mechanistic Postmortem v1", "",
  sprintf("- Decision: `%s`", decision),
  "- Model compute launched: `FALSE`", "- Article update allowed: `FALSE`",
  sprintf("- Candidate rows: `%d`", nrow(candidate)), "",
  "## Central finding", "",
  "The compact AL mechanisms do not transfer across sources. The frozen article source",
  "degrades in every lead and origin band, whereas the untouched confirmation source",
  "contains a development-only improvement, strongest for the state-residual arm.",
  "The discrepancy is therefore not a long-horizon-only failure and does not authorize",
  "another scalar hyperparameter screen.", "",
  "## Overall median ratios", "",
  paste(capture.output(print(article_overall[, c("arm_code", "mae_ratio", "check_ratio", "win_fraction_mae")], row.names = FALSE)), collapse = "\n"),
  "", paste(capture.output(print(confirm_overall[, c("arm_code", "mae_ratio", "check_ratio", "win_fraction_mae")], row.names = FALSE)), collapse = "\n"),
  "", "The exAL geometry gate also remains closed because all tested arms retain excessive",
  "lag-one autocorrelation. Reparameterization or a different package-supported update",
  "must be justified before further exAL MCMC compute."
), file.path(out, "README.md"))
evidence_files <- setdiff(list.files(out, full.names = TRUE), file.path(out, "file_manifest.csv"))
manifest <- data.frame(
  path = normalizePath(evidence_files, winslash = "/"),
  bytes = file.info(evidence_files)$size,
  sha256 = unname(tools::sha256sum(evidence_files)),
  stringsAsFactors = FALSE
)
write_csv(manifest, "file_manifest.csv")
cat(sprintf("Decision: %s\nCandidates: %d\nOutput: %s\n", decision, nrow(candidate), out))

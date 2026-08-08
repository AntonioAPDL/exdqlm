#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, digits = 17)

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required.", call. = FALSE)
  }
})

script_path <- normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]),
  winslash = "/", mustWork = TRUE
)
repo_root <- normalizePath(file.path(dirname(script_path), "..", "..", ".."),
                           winslash = "/", mustWork = TRUE)
id <- "qdesn_500obs_mcmc_chain_aggregate_sensitivity_v1_20260808"
root <- file.path(repo_root, "validation", "fitforecast_v2", "promotions", id)
manifest_path <- file.path(root, paste0(id, "_manifest.json"))
required <- c(
  manifest_path,
  file.path(root, "review_decision.json"),
  file.path(root, "output_file_manifest.csv"),
  file.path(root, "frozen_evidence_ledger.csv"),
  file.path(root, "design_review.csv"),
  file.path(root, "coherent_design_recommendations.csv"),
  file.path(root, "metric_improvement_review.csv"),
  file.path(root, "README.md")
)
if (any(!file.exists(required))) stop("Sensitivity bundle is incomplete.", call. = FALSE)

manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
decision <- jsonlite::read_json(file.path(root, "review_decision.json"),
                                simplifyVector = TRUE)
outputs <- read.csv(file.path(root, "output_file_manifest.csv"),
                    check.names = FALSE)
ledger <- read.csv(file.path(root, "frozen_evidence_ledger.csv"),
                   check.names = FALSE)
designs <- read.csv(file.path(root, "design_review.csv"), check.names = FALSE)
coherent <- read.csv(file.path(root, "coherent_design_recommendations.csv"),
                     check.names = FALSE)
metrics <- read.csv(file.path(root, "metric_improvement_review.csv"),
                    check.names = FALSE)

checks <- c(
  identical(manifest$status, "AUTHORITATIVE_ROBUSTNESS_SENSITIVITY"),
  identical(decision$decision,
            "ROBUST_SENSITIVITY_CONFIRMED_ARTICLE_TABLE_UNCHANGED"),
  isTRUE(decision$validation_evidence_complete),
  !isTRUE(decision$article_table_replacement_recommended),
  !isTRUE(decision$article_update_performed),
  identical(manifest$estimator_id,
            "median_of_chain_posterior_point_paths_v1"),
  !isTRUE(manifest$posterior_pooling_claim),
  manifest$complete_five_chain_designs == 11L,
  manifest$metric_improvements == 5L,
  nrow(designs) == 11L,
  all(designs$chain_count == 5L),
  all(designs$estimator_id == manifest$estimator_id),
  !any(designs$posterior_pooling_claim),
  nrow(coherent) == 2L,
  setequal(coherent$model_variant,
           c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns")),
  nrow(metrics) == 5L,
  all(metrics$improves_authority),
  !any(metrics$article_drop_in_eligible),
  all(file.exists(outputs$path)),
  identical(unname(tools::sha256sum(outputs$path)), unname(outputs$sha256)),
  all(file.exists(ledger$frozen_path)),
  identical(unname(tools::sha256sum(ledger$frozen_path)),
            unname(ledger$frozen_sha256)),
  identical(ledger$source_sha256, ledger$frozen_sha256),
  length(list.files(root, pattern = "\\.(rds|rda|RData)$", recursive = TRUE,
                    full.names = TRUE, ignore.case = TRUE)) == 0L
)
if (!all(checks)) {
  stop(sprintf("Sensitivity verification failed at checks: %s",
               paste(which(!checks), collapse = ", ")), call. = FALSE)
}

cat(sprintf("VERIFIED=%d/%d\n", sum(checks), length(checks)))
cat(sprintf("DECISION=%s\n", decision$decision))
cat(sprintf("METRIC_IMPROVEMENTS=%d\n", nrow(metrics)))
cat("ARTICLE_UPDATED=FALSE\n")

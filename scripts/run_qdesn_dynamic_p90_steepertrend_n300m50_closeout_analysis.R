#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default = NULL) {
  idx <- match(flag, args)
  if (is.na(idx) || idx >= length(args)) default else args[[idx + 1L]]
}

repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
manifest <- get_arg(
  "--manifest",
  file.path("config", "validation", "qdesn_dynamic_p90_steepertrend_n300m50_closeout_analysis_manifest.yaml")
)

if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("pkgload is required to run the n300/m50 p90 closeout analysis.", call. = FALSE)
}

pkgload::load_all(repo_root, quiet = TRUE)

out <- qdesn_dynamic_p90_steepertrend_closeout_analysis(
  manifest_path = manifest,
  repo_root = repo_root
)

cat(sprintf("Wrote n300/m50 p90 closeout analysis: %s\n", out$output_root))
cat(sprintf("Combined fit rows: %d\n", nrow(out$fit_summary)))
cat(sprintf("Figures: %d\n", nrow(out$figure_index)))

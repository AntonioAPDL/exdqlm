#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3L) {
  stop("Usage: <repo> <run> <output> [interim|final]")
}
repo <- normalizePath(args[1L], mustWork = TRUE)
run <- normalizePath(args[2L], mustWork = TRUE)
output <- args[3L]
mode <- if (length(args) >= 4L) args[4L] else "interim"

source(file.path(repo, "validation/fitforecast_v2/R",
  "independent_qdesn_training1000_runtime_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R",
  "independent_qdesn_training_size_mechanism_v6_review.R"))

result <- itm6r_audit(repo, run, output, mode = mode)
print(result$health, row.names = FALSE)
cat("review=", normalizePath(output), "\n", sep = "")
cat("manifest=", result$manifest, "\n", sep = "")

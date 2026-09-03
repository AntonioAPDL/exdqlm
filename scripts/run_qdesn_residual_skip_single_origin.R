#!/usr/bin/env Rscript

`%||%` <- function(x, alt) if (!is.null(x)) x else alt

parse_args <- function(args) {
  out <- list()
  for (arg in args) {
    if (!startsWith(arg, "--") || !grepl("=", arg, fixed = TRUE)) next
    pair <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1L]]
    out[[pair[1L]]] <- paste(pair[-1L], collapse = "=")
  }
  out
}

as_flag <- function(x, default = FALSE) {
  if (is.null(x)) return(default)
  tolower(as.character(x)[1L]) %in% c("1", "true", "yes", "y")
}

read_series <- function(path, column = "y") {
  if (!file.exists(path)) stop("Input file does not exist: ", path, call. = FALSE)
  ext <- tolower(tools::file_ext(path))
  object <- switch(
    ext,
    rds = readRDS(path),
    csv = utils::read.csv(path, check.names = FALSE),
    txt = utils::read.table(path, header = TRUE, check.names = FALSE),
    stop("Supported input extensions are .rds, .csv, and .txt.", call. = FALSE)
  )
  if (is.numeric(object) && is.null(dim(object))) return(as.numeric(object))
  if (is.matrix(object)) object <- as.data.frame(object)
  if (!is.data.frame(object)) stop("Input must contain a numeric vector or data frame.", call. = FALSE)
  if (!column %in% names(object)) {
    stop("Response column not found: ", column, call. = FALSE)
  }
  as.numeric(object[[column]])
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
input_path <- args$input
output_dir <- args$output
response_column <- args$column %||% "y"
quick <- as_flag(args$quick, FALSE)
config_path <- args$config %||%
  "config/validation/qdesn_residual_skip_single_origin_v1/defaults.yaml"

if (is.null(input_path) || is.null(output_dir)) {
  stop(
    "Usage: Rscript scripts/run_qdesn_residual_skip_single_origin.R ",
    "--input=/path/series.csv --column=y --output=/path/results ",
    "[--workers=4] [--quick=true]",
    call. = FALSE
  )
}

if (!requireNamespace("yaml", quietly = TRUE)) {
  stop("The runner requires the yaml package.", call. = FALSE)
}
cfg <- yaml::read_yaml(config_path)
workers <- as.integer(args$workers %||% (cfg$execution %||% list())$workers %||% 1L)
if (!is.finite(workers) || workers < 1L) {
  stop("--workers must be a positive integer.", call. = FALSE)
}

# Candidate-seed jobs are process-parallel.  Keep numerical libraries
# single-threaded inside each worker unless the caller has explicitly supplied
# a thread count, preventing severe oversubscription on Linux servers.
if (workers > 1L) {
  thread_vars <- c(
    "OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
    "VECLIB_MAXIMUM_THREADS", "NUMEXPR_NUM_THREADS"
  )
  current <- Sys.getenv(thread_vars, unset = "")
  to_set <- thread_vars[!nzchar(current)]
  if (length(to_set)) {
    values <- rep("1", length(to_set))
    names(values) <- to_set
    do.call(Sys.setenv, as.list(values))
  }
}

if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
  pkgload::load_all(".", quiet = TRUE)
} else {
  suppressPackageStartupMessages(library(exdqlm))
}

candidate_path <- cfg$selection$candidate_file
seed_path <- cfg$selection$seed_file
candidates <- utils::read.csv(candidate_path, stringsAsFactors = FALSE)
seed_ledger <- utils::read.csv(seed_path, stringsAsFactors = FALSE)
seeds_for <- function(stage) as.integer(seed_ledger$seed[seed_ledger$stage == stage])

y <- read_series(input_path, response_column)
if (length(y) < 1100L) {
  stop("The input series must contain at least 1100 observations.", call. = FALSE)
}

result <- qdesn_run_residual_ablation(
  y = y,
  output_dir = output_dir,
  candidates = candidates,
  tau0 = as.numeric(cfg$model$rhs_tau0),
  p_vec = as.numeric(unlist(cfg$quantiles, use.names = FALSE)),
  screening_seeds = seeds_for("screening"),
  confirmation_seeds = seeds_for("confirmation"),
  final_seeds = seeds_for("final"),
  nd_screen = as.integer(cfg$selection$screening_paths),
  nd_confirm = as.integer(cfg$selection$confirmation_paths),
  nd_final = as.integer(cfg$selection$final_paths),
  skip_scale = as.numeric(cfg$model$skip_scale),
  confirmation_top_per_architecture = as.integer(
    cfg$selection$confirmation_top_per_architecture
  ),
  near_tie_fraction = as.numeric(cfg$selection$near_tie_fraction),
  residual_retuned_min_validation_gain = as.numeric(
    cfg$selection$residual_retuned_min_validation_gain
  ),
  minimum_median_improvement_percent = as.numeric(
    cfg$final_decision$minimum_median_improvement_percent
  ),
  minimum_seed_wins = as.integer(cfg$final_decision$minimum_seed_wins),
  maximum_quantile_degradation_percent = as.numeric(
    cfg$final_decision$maximum_per_quantile_median_degradation_percent
  ),
  forgetting_tolerance = as.numeric(cfg$final_decision$forgetting_tolerance),
  workers = workers,
  resume = as_flag(args$resume, (cfg$execution %||% list())$resume %||% TRUE),
  quick = quick
)

cat("Residual retained:", isTRUE(result$decision$retain_residual), "\n")
cat("Median paired improvement (%):",
    format(result$decision$median_aggregate_improvement_percent, digits = 4), "\n")

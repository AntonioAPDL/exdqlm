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
    "--input=/path/series.csv --column=y --output=/path/results [--quick=true]",
    call. = FALSE
  )
}

if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
  pkgload::load_all(".", quiet = TRUE)
} else {
  suppressPackageStartupMessages(library(exdqlm))
}

if (!requireNamespace("yaml", quietly = TRUE)) {
  stop("The runner requires the yaml package.", call. = FALSE)
}
cfg <- yaml::read_yaml(config_path)

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
  resume = TRUE,
  quick = quick
)

cat("Residual retained:", isTRUE(result$decision$retain_residual), "\n")
cat("Median paired improvement (%):",
    format(result$decision$median_aggregate_improvement_percent, digits = 4), "\n")

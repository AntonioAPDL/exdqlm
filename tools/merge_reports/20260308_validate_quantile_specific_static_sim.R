#!/usr/bin/env Rscript

safe_chr <- function(x, default) {
  v <- as.character(x)[1]
  if (!nzchar(v) || is.na(v)) default else v
}

sim_path <- safe_chr(Sys.getenv('EXDQLM_STATIC_SIM_PATH', ''), '')
out_csv <- safe_chr(Sys.getenv('EXDQLM_STATIC_SIM_VALIDATION_OUT', ''), '')
if (!nzchar(sim_path) || !file.exists(sim_path)) stop('Simulation file not found: ', sim_path)
sim <- readRDS(sim_path)
if (is.null(sim$p) || length(sim$p) != 1L) stop('Static quantile-specific sim must have exactly one target tau in sim$p')
if (is.null(sim$q)) stop('Static quantile-specific sim must contain q truth')
q_true <- as.matrix(sim$q)
if (ncol(q_true) != 1L) stop('Static quantile-specific sim must have a single truth column')
TT <- length(sim$y)
if (nrow(q_true) != TT) stop('Truth length does not match y length')
tau <- as.numeric(sim$p)[1]
coverage <- mean(as.numeric(sim$y) <= q_true[, 1])
delta <- coverage - tau
res <- data.frame(
  sim_path = sim_path,
  TT = TT,
  tau = tau,
  empirical_coverage = coverage,
  coverage_delta = delta,
  truth_method = if (!is.null(sim$info$quantile_truth_method)) sim$info$quantile_truth_method else NA_character_,
  scenario = if (!is.null(sim$info$scenario)) sim$info$scenario else NA_character_,
  stringsAsFactors = FALSE
)
print(res)
if (nzchar(out_csv)) utils::write.csv(res, out_csv, row.names = FALSE)

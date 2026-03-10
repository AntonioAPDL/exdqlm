#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) stop('Usage: Rscript .../20260308_validate_quantile_specific_dynamic_sim.R <sim_output.rds>')
sim <- readRDS(args[1])
if (is.null(sim$p) || length(sim$p) != 1L) stop('Expected single target tau in sim$p')
if (is.null(sim$q)) stop('sim$q missing')
q_mat <- as.matrix(sim$q)
if (ncol(q_mat) != 1L) stop('Expected single truth column in sim$q')
tau <- as.numeric(sim$p)[1]
y <- as.numeric(sim$y)
q_true <- as.numeric(q_mat[, 1])
emp_cov <- mean(y <= q_true)
out <- data.frame(sim_path = args[1], TT = length(y), tau = tau, empirical_coverage = emp_cov, coverage_delta = emp_cov - tau, truth_method = if (!is.null(sim$info$quantile_truth_method)) sim$info$quantile_truth_method else NA_character_, scenario = if (!is.null(sim$info$scenario)) sim$info$scenario else NA_character_)
print(out)

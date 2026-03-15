#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) {
  stop("Usage: 20260314_family_qspec_root_signoff.R <run_root> [repo_root]", call. = FALSE)
}
run_root <- normalizePath(args[[1]], mustWork = TRUE)
repo_root <- if (length(args) >= 2L) normalizePath(args[[2]], mustWork = TRUE) else normalizePath(file.path(run_root, "..", "..", "..", "..", ".."), mustWork = TRUE)

source(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_v2_common.R"))
source(file.path(repo_root, "R", "static_fit_normalization.R"))
source(file.path(repo_root, "tools", "merge_reports", "20260314_family_qspec_signoff_common.R"))

cfg <- fqsg_signoff_cfg()
root_row <- fqsg_resolve_root_row(run_root, repo_root)
out_tables <- file.path(run_root, "tables")
dir.create(out_tables, recursive = TRUE, showWarnings = FALSE)

fit_summary <- fq_read_csv_safe(file.path(out_tables, "fit_summary.csv"))
vb_conv <- fq_read_csv_safe(file.path(out_tables, "vb_convergence_summary.csv"))
ld_diag <- fq_read_csv_safe(file.path(out_tables, "vb_ld_diagnostics_summary.csv"))
mc_diag <- fq_read_csv_safe(file.path(out_tables, "mcmc_diagnostics_summary.csv"))
rhs_diag <- fq_read_csv_safe(file.path(out_tables, "rhs_diagnostics_summary.csv"))

if (is.null(fit_summary) || !nrow(fit_summary)) {
  stop("Missing or empty fit_summary.csv under run root: ", run_root, call. = FALSE)
}
if (is.null(vb_conv)) vb_conv <- data.frame(stringsAsFactors = FALSE)
if (is.null(ld_diag)) ld_diag <- data.frame(stringsAsFactors = FALSE)
if (is.null(mc_diag)) mc_diag <- data.frame(stringsAsFactors = FALSE)
if (is.null(rhs_diag)) rhs_diag <- data.frame(stringsAsFactors = FALSE)

fit_summary$inference <- tolower(as.character(fit_summary$inference))
fit_summary$model <- tolower(as.character(fit_summary$model))
fit_summary$tau <- suppressWarnings(as.numeric(fit_summary$tau))
if (!"fit_file" %in% names(fit_summary)) fit_summary$fit_file <- NA_character_
if (!"beta_prior" %in% names(fit_summary)) fit_summary$beta_prior <- NA_character_

method_rows <- lapply(seq_len(nrow(fit_summary)), function(i) {
  fit_row <- fit_summary[i, , drop = FALSE]
  fit_path <- as.character(fit_row$fit_file[[1]] %||% "")
  if (!nzchar(fit_path) || !file.exists(fit_path)) {
    tau_lab <- fq_tau_tag(fit_row$tau[[1]])
    fit_path <- file.path(
      run_root,
      "fits",
      fit_row$inference[[1]],
      sprintf("%s_%s_tau_%s_fit.rds", fit_row$inference[[1]], fit_row$model[[1]], tau_lab)
    )
  }
  fit_obj <- fqsg_safe_read_fit_object(fit_path)
  fqsg_method_signoff_from_root(root_row, fit_row, fit_obj, vb_conv, ld_diag, mc_diag, rhs_diag, cfg)
})
method_signoff <- fqsg_bind_rows(method_rows)

if (!nrow(method_signoff)) {
  stop("No method signoff rows produced for run root: ", run_root, call. = FALSE)
}

runtime_lookup <- fit_summary[, c("inference", "model", "tau", "runtime_sec"), drop = FALSE]
runtime_lookup$inference <- tolower(as.character(runtime_lookup$inference))
runtime_lookup$model <- tolower(as.character(runtime_lookup$model))
runtime_lookup$tau <- suppressWarnings(as.numeric(runtime_lookup$tau))
runtime_lookup$runtime_sec <- suppressWarnings(as.numeric(runtime_lookup$runtime_sec))

algorithm_pairs <- fqsg_algorithm_pair_signoff(root_row, method_signoff)
if (nrow(algorithm_pairs)) {
  algorithm_pairs$vb_runtime_sec <- NA_real_
  algorithm_pairs$mcmc_runtime_sec <- NA_real_
  algorithm_pairs$runtime_ratio_mcmc_vs_vb <- NA_real_
  for (i in seq_len(nrow(algorithm_pairs))) {
    mdl <- algorithm_pairs$model[[i]]
    tau <- algorithm_pairs$tau[[i]]
    vb_rt <- runtime_lookup$runtime_sec[runtime_lookup$inference == "vb" & runtime_lookup$model == mdl & abs(runtime_lookup$tau - tau) < 1e-8]
    mc_rt <- runtime_lookup$runtime_sec[runtime_lookup$inference == "mcmc" & runtime_lookup$model == mdl & abs(runtime_lookup$tau - tau) < 1e-8]
    vb_rt <- if (length(vb_rt)) vb_rt[[1L]] else NA_real_
    mc_rt <- if (length(mc_rt)) mc_rt[[1L]] else NA_real_
    algorithm_pairs$vb_runtime_sec[[i]] <- vb_rt
    algorithm_pairs$mcmc_runtime_sec[[i]] <- mc_rt
    algorithm_pairs$runtime_ratio_mcmc_vs_vb[[i]] <- if (is.finite(vb_rt) && vb_rt > 0 && is.finite(mc_rt)) mc_rt / vb_rt else NA_real_
  }
}
model_pairs <- fqsg_model_pair_signoff(root_row, method_signoff)
root_summary <- fqsg_root_signoff_summary(root_row, method_signoff, algorithm_pairs, model_pairs)
repair_targets <- fqsg_repair_targets(root_row, method_signoff)

utils::write.csv(method_signoff, file.path(out_tables, "method_signoff_long.csv"), row.names = FALSE)
utils::write.csv(algorithm_pairs, file.path(out_tables, "algorithm_pair_signoff.csv"), row.names = FALSE)
utils::write.csv(model_pairs, file.path(out_tables, "model_pair_signoff.csv"), row.names = FALSE)
utils::write.csv(root_summary, file.path(out_tables, "root_signoff_summary.csv"), row.names = FALSE)
utils::write.csv(repair_targets, file.path(out_tables, "repair_targets.csv"), row.names = FALSE)

cat(sprintf("Wrote signoff bundle under: %s\n", out_tables))
cat(sprintf("method_rows=%d algorithm_pairs=%d model_pairs=%d repair_targets=%d\n", nrow(method_signoff), nrow(algorithm_pairs), nrow(model_pairs), nrow(repair_targets)))

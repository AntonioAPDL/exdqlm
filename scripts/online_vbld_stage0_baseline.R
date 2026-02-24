#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

`%||%` <- function(x, y) if (!is.null(x)) x else y

args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (length(i) && i < length(args)) args[i + 1L] else default
}

as_flag <- function(x, default = FALSE) {
  if (is.null(x)) return(isTRUE(default))
  x <- tolower(as.character(x)[1L])
  if (x %in% c("1", "true", "t", "yes", "y")) return(TRUE)
  if (x %in% c("0", "false", "f", "no", "n")) return(FALSE)
  isTRUE(default)
}

print_usage <- function() {
  cat(
    "Usage:\n",
    "  Rscript scripts/online_vbld_stage0_baseline.R [options]\n\n",
    "Options:\n",
    "  --cfg <path>                Optional YAML config (reads vb.online + vb.online.baseline)\n",
    "  --out_dir <path>            Output directory (default: results/online_vbld/stage0_baseline)\n",
    "  --seed <int>                Fixture seed (default: 20260223)\n",
    "  --n <int>                   Sample size (default: 72)\n",
    "  --k <int>                   Design dimension incl. intercept (default: 5)\n",
    "  --t0 <int>                  Warm-start prefix size (default: 48)\n",
    "  --p0 <num>                  Quantile level in (0,1) (default: 0.5)\n",
    "  --ridge_tau2 <num>          Ridge prior variance (default: 5)\n",
    "  --max_iter <int>            Batch VB max_iter (default: 35)\n",
    "  --tol <num>                 Batch VB ELBO tolerance (default: 1e-4)\n",
    "  --tol_par <num>             Batch VB parameter tolerance (default: 1e-4)\n",
    "  --M <int>                   RHS refresh period (default: 2)\n",
    "  --K <int>                   Sigma/gamma refresh period (default: 4)\n",
    "  --W <int>                   Window size (default: 24)\n",
    "  --L_loc <int>               Local alternations per step (default: 2)\n",
    "  --window_passes <int>       Window backfit passes (default: 1)\n",
    "  --jitter <num>              SPD solver jitter (default: 1e-10)\n",
    "  --check_repro <bool>        Run twice and compare hash (default: true)\n",
    "  --write_trace <bool>        Write per-step trace CSV(s) (default: true)\n",
    "  --help                      Show this message\n",
    sep = ""
  )
}

if ("--help" %in% args || "-h" %in% args) {
  print_usage()
  quit(save = "no", status = 0L)
}

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg)) {
  script_path <- normalizePath(sub("^--file=", "", script_arg[1L]), mustWork = TRUE)
  repo <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)
} else {
  repo <- normalizePath(getwd(), mustWork = TRUE)
}
setwd(repo)

if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("Package 'pkgload' is required to load local package code.", call. = FALSE)
}
pkgload::load_all(repo, quiet = TRUE, export_all = FALSE)

cfg_path <- as.character(get_arg("--cfg", ""))[1L]
cfg_yaml <- list()
if (nzchar(cfg_path)) {
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("Package 'yaml' is required when --cfg is provided.", call. = FALSE)
  }
  if (!file.exists(cfg_path)) stop("Config file not found: ", cfg_path, call. = FALSE)
  cfg_yaml <- yaml::read_yaml(cfg_path)
}
online_yaml <- cfg_yaml$vb$online %||% list()
baseline_yaml <- online_yaml$baseline %||% list()

cfg <- list(
  out_dir = as.character(get_arg(
    "--out_dir",
    baseline_yaml$out_dir %||% file.path("results", "online_vbld", "stage0_baseline")
  ))[1L],
  seed = as.integer(get_arg("--seed", as.character(baseline_yaml$seed %||% 20260223L)))[1L],
  n = as.integer(get_arg("--n", as.character(baseline_yaml$n %||% 72L)))[1L],
  k = as.integer(get_arg("--k", as.character(baseline_yaml$k %||% 5L)))[1L],
  t0 = as.integer(get_arg("--t0", as.character(baseline_yaml$t0 %||% 48L)))[1L],
  p0 = as.numeric(get_arg("--p0", as.character(baseline_yaml$p0 %||% 0.5)))[1L],
  ridge_tau2 = as.numeric(get_arg("--ridge_tau2", as.character(baseline_yaml$ridge_tau2 %||% 5)))[1L],
  max_iter = as.integer(get_arg("--max_iter", as.character(baseline_yaml$max_iter %||% 35L)))[1L],
  tol = as.numeric(get_arg("--tol", as.character(baseline_yaml$tol %||% 1e-4)))[1L],
  tol_par = as.numeric(get_arg("--tol_par", as.character(baseline_yaml$tol_par %||% 1e-4)))[1L],
  M = as.integer(get_arg("--M", as.character(online_yaml$M %||% 2L)))[1L],
  K = as.integer(get_arg("--K", as.character(online_yaml$K %||% 4L)))[1L],
  W = as.integer(get_arg("--W", as.character(online_yaml$W %||% 24L)))[1L],
  L_loc = as.integer(get_arg("--L_loc", as.character(online_yaml$L_loc %||% 2L)))[1L],
  window_passes = as.integer(get_arg("--window_passes", as.character(online_yaml$window_passes %||% 1L)))[1L],
  jitter = as.numeric(get_arg("--jitter", as.character(online_yaml$jitter %||% 1e-10)))[1L],
  check_repro = as_flag(get_arg("--check_repro", as.character(baseline_yaml$check_repro %||% TRUE)), default = TRUE),
  write_trace = as_flag(get_arg("--write_trace", as.character(baseline_yaml$write_trace %||% TRUE)), default = TRUE)
)

batch_vb_control <- list(
  max_iter = cfg$max_iter,
  tol = cfg$tol,
  tol_par = cfg$tol_par,
  verbose = FALSE
)
online_control <- list(
  M = cfg$M,
  K = cfg$K,
  W = cfg$W,
  L_loc = cfg$L_loc,
  window_passes = cfg$window_passes,
  jitter = cfg$jitter
)

cat("Running Stage-0 online VB-LD baseline benchmark...\n")
cat(sprintf("Repo: %s\n", repo))
cat(sprintf(
  "Config: seed=%d n=%d k=%d t0=%d p0=%.4f M=%d K=%d W=%d L_loc=%d check_repro=%s\n",
  cfg$seed, cfg$n, cfg$k, cfg$t0, cfg$p0, cfg$M, cfg$K, cfg$W, cfg$L_loc, as.character(cfg$check_repro)
))

res <- exal_online_stage0_benchmark(
  seed = cfg$seed,
  n = cfg$n,
  k = cfg$k,
  t0 = cfg$t0,
  p0 = cfg$p0,
  ridge_tau2 = cfg$ridge_tau2,
  batch_vb_control = batch_vb_control,
  online_control = online_control,
  check_repro = cfg$check_repro,
  return_trace = cfg$write_trace
)

paths <- exal_online_stage0_write_artifacts(
  benchmark_result = res,
  out_dir = cfg$out_dir,
  write_trace = cfg$write_trace
)

cat("\nSummary:\n")
cat(sprintf("  hash(run1): %s\n", res$reproducibility$hash_run1))
if (isTRUE(cfg$check_repro)) {
  cat(sprintf("  hash(run2): %s\n", res$reproducibility$hash_run2))
  cat(sprintf("  hashes_equal: %s\n", as.character(res$reproducibility$hashes_equal)))
}
cat(sprintf("  l2_beta_mu: %.6f\n", res$run1$metrics$l2_beta_mu))
cat(sprintf("  l_inf_beta_mu: %.6f\n", res$run1$metrics$linf_beta_mu))
cat(sprintf("  rmse_pred_mean: %.6f\n", res$run1$metrics$rmse_pred_mean))
cat(sprintf("  delta_check_loss: %.6f\n", res$run1$metrics$delta_check_loss))
cat(sprintf("  P_spd: %s | min_eig_P=%.6g\n", as.character(res$run1$health$P_spd), res$run1$health$min_eig_P))
cat(sprintf("  batch_full_converged: %s\n", as.character(res$run1$convergence$batch_full)))
cat(sprintf("  batch_init_converged: %s\n", as.character(res$run1$convergence$batch_init)))
cat(sprintf(
  "  timing_sec: batch_full=%.3f batch_init=%.3f online=%.3f\n",
  res$run1$timing_sec$batch_full, res$run1$timing_sec$batch_init, res$run1$timing_sec$online
))
cat(sprintf("  rhs_refreshes=%d sigmagam_refreshes=%d window_backfits=%d\n",
            as.integer(res$run1$refresh_counts$rhs %||% 0L),
            as.integer(res$run1$refresh_counts$sigmagam %||% 0L),
            as.integer(res$run1$refresh_counts$window_backfit %||% 0L)))

cat("\nArtifacts:\n")
cat(sprintf("  rds: %s\n", paths$rds))
if (is.character(paths$json) && nzchar(paths$json) && !is.na(paths$json)) {
  cat(sprintf("  json: %s\n", paths$json))
}
if (is.character(paths$trace_run1_csv) && nzchar(paths$trace_run1_csv) && !is.na(paths$trace_run1_csv)) {
  cat(sprintf("  trace_run1_csv: %s\n", paths$trace_run1_csv))
}
if (is.character(paths$trace_run2_csv) && nzchar(paths$trace_run2_csv) && !is.na(paths$trace_run2_csv)) {
  cat(sprintf("  trace_run2_csv: %s\n", paths$trace_run2_csv))
}

if (isTRUE(cfg$check_repro) && !isTRUE(res$reproducibility$hashes_equal)) {
  stop("Stage-0 reproducibility check failed: run hashes are different.", call. = FALSE)
}
if (!isTRUE(res$run1$health$P_spd) || !isTRUE(res$run1$health$is_finite_beta) || !isTRUE(res$run1$health$is_finite_sigmagam)) {
  stop("Stage-0 health checks failed (non-SPD/finite state).", call. = FALSE)
}

cat("\nStage-0 baseline completed successfully.\n")

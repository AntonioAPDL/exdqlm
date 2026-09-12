#!/usr/bin/env Rscript

options(width = 120, digits = 17)

thread_vars <- c(
  "OMP_NUM_THREADS", "OMP_THREAD_LIMIT", "OPENBLAS_NUM_THREADS",
  "MKL_NUM_THREADS", "BLIS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"
)
for (v in thread_vars) do.call(Sys.setenv, stats::setNames(as.list("1"), v))

RNGversion("4.6.0")
RNGkind("Mersenne-Twister", "Inversion", "Rejection")

library(exdqlm)
library(dlm)

hash_object <- function(x, file) {
  saveRDS(x, file = file, version = 3)
  unname(tools::md5sum(file))
}

cat("EXDQLM_FFBS_DIAGNOSTIC_BEGIN\n")
cat("R_VERSION=", R.version.string, "\n", sep = "")
cat("PLATFORM=", R.version$platform, "\n", sep = "")
cat("OS=", paste(Sys.info()[c("sysname", "release", "machine")], collapse = " "), "\n", sep = "")
cat("EXDQLM_VERSION=", as.character(packageVersion("exdqlm")), "\n", sep = "")
cat("RNGKIND=", paste(RNGkind(), collapse = ","), "\n", sep = "")
cat("THREADS=", paste(names(Sys.getenv(thread_vars)), Sys.getenv(thread_vars), sep = "=", collapse = ";"), "\n", sep = "")
soft_versions <- extSoftVersion()
cat("BLAS=", if ("BLAS" %in% names(soft_versions)) soft_versions[["BLAS"]] else NA_character_, "\n", sep = "")
cat("LAPACK=", if ("LAPACK" %in% names(soft_versions)) soft_versions[["LAPACK"]] else NA_character_, "\n", sep = "")

options(
  exdqlm.use_cpp_kf = TRUE,
  exdqlm.use_cpp_builders = FALSE,
  exdqlm.use_cpp_samplers = FALSE,
  exdqlm.use_cpp_postpred = FALSE,
  exdqlm.use_cpp_mcmc = TRUE,
  exdqlm.cpp_mcmc_mode = "fast",
  exdqlm.cpp_threads = 1L
)

cat("BACKEND_OPTIONS=", paste(capture.output(print(options()[c(
  "exdqlm.use_cpp_kf", "exdqlm.use_cpp_builders",
  "exdqlm.use_cpp_samplers", "exdqlm.use_cpp_postpred",
  "exdqlm.use_cpp_mcmc", "exdqlm.cpp_mcmc_mode",
  "exdqlm.cpp_threads"
)])), collapse = " | "), "\n", sep = "")

dlm_trend_comp <- dlm::dlmModPoly(1, m0 = 50, C0 = 2500)
trend_comp <- as.exdqlm(dlm_trend_comp)
seas_comp <- seasMod(p = 11, h = 1:4, C0 = 10 * diag(8))
model <- trend_comp + seas_comp

p <- length(model$m0)
TT <- length(sunspot.year)
FF <- matrix(model$FF, p, TT)
GG <- model$GG
if (length(dim(GG)) == 2L) {
  GG <- array(GG, dim = c(p, p, TT))
}
df_mat <- exdqlm:::make_df_mat(c(0.9, 0.85), c(1, 8), p)
ex_f <- rep(0, TT)
ex_q <- rep(1, TT)

set.seed(2026091101)
ffbs_1 <- exdqlm:::mcmc_ffbs_sample_cpp(
  GG = GG,
  m0 = as.numeric(model$m0),
  C0 = model$C0,
  FF = FF,
  y = as.numeric(sunspot.year),
  ex_f = ex_f,
  ex_q = ex_q,
  df_mat = df_mat
)
set.seed(2026091101)
ffbs_2 <- exdqlm:::mcmc_ffbs_sample_cpp(
  GG = GG,
  m0 = as.numeric(model$m0),
  C0 = model$C0,
  FF = FF,
  y = as.numeric(sunspot.year),
  ex_f = ex_f,
  ex_q = ex_q,
  df_mat = df_mat
)

cat("FFBS_DIRECT_HASH=", hash_object(ffbs_1, "ffbs-direct.rds"), "\n", sep = "")
cat("FFBS_DIRECT_REPEAT_IDENTICAL=", identical(ffbs_1, ffbs_2), "\n", sep = "")
cat("FFBS_DIRECT_THETA_HEAD=", paste(formatC(as.numeric(ffbs_1$sam.theta[1, 1:8]), digits = 17), collapse = ","), "\n", sep = "")
cat("FFBS_DIRECT_SFE_HEAD=", paste(formatC(as.numeric(ffbs_1$standard.forecast.errors[1:8]), digits = 17), collapse = ","), "\n", sep = "")

run_mcmc_probe <- function(label, dqlm_ind, seed) {
  set.seed(seed)
  fit <- exdqlmMCMC(
    y = sunspot.year, p0 = 0.85, model = model, df = c(0.9, 0.85),
    dim.df = c(1, 8), n.burn = 75, n.mcmc = 125, verbose = FALSE,
    dqlm.ind = dqlm_ind, fix.sigma = FALSE
  )
  theta_raw <- unclass(fit$samp.theta)
  postpred_raw <- unclass(fit$samp.post.pred)
  sigma_raw <- unclass(fit$samp.sigma)
  gamma_raw <- if (!is.null(fit$samp.gamma)) unclass(fit$samp.gamma) else NA_real_
  theta_num <- as.numeric(theta_raw)
  postpred_num <- as.numeric(postpred_raw)
  sigma_num <- as.numeric(sigma_raw)
  gamma_num <- as.numeric(gamma_raw)
  out <- list(
    label = label,
    backend = fit$backend,
    metrics = c(
      theta_mean = mean(theta_num),
      theta_sd = stats::sd(theta_num),
      postpred_mean = mean(postpred_num),
      postpred_sd = stats::sd(postpred_num),
      sigma_mean = mean(sigma_num),
      gamma_mean = mean(gamma_num)
    ),
    theta_head = theta_num[seq_len(min(8L, length(theta_num)))],
    pp_head = postpred_num[seq_len(min(8L, length(postpred_num)))]
  )
  cat(label, "_HASH=", hash_object(out, paste0(label, ".rds")), "\n", sep = "")
  cat(label, "_BACKEND=", paste(unlist(fit$backend), collapse = ","), "\n", sep = "")
  cat(label, "_METRICS=", paste(names(out$metrics), formatC(out$metrics, digits = 17), sep = "=", collapse = ","), "\n", sep = "")
  cat(label, "_THETA_HEAD=", paste(formatC(out$theta_head, digits = 17), collapse = ","), "\n", sep = "")
  cat(label, "_PP_HEAD=", paste(formatC(out$pp_head, digits = 17), collapse = ","), "\n", sep = "")
  invisible(out)
}

mcmc_dqlm <- run_mcmc_probe("MCMC_DQLM_FAST_PROBE", TRUE, 20262801)
mcmc_exdqlm <- run_mcmc_probe("MCMC_EXDQLM_FAST_PROBE", FALSE, 20262802)

cat("EXDQLM_FFBS_DIAGNOSTIC_END\n")

#!/usr/bin/env Rscript

options(width = 120, digits = 17)

thread_vars <- c(
  "OMP_NUM_THREADS", "OMP_THREAD_LIMIT", "OPENBLAS_NUM_THREADS",
  "MKL_NUM_THREADS", "BLIS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"
)
for (v in thread_vars) {
  do.call(Sys.setenv, stats::setNames(as.list("1"), v))
}

RNGkind("Mersenne-Twister", "Inversion", "Rejection")

make_ffbs_inputs <- function() {
  TT <- 6L
  GG_base <- matrix(c(1.00, 0.00, 0.20, 0.95), nrow = 2L, byrow = TRUE)
  list(
    GG = array(rep(GG_base, TT), dim = c(2L, 2L, TT)),
    m0 = c(0.2, -0.1),
    C0 = matrix(c(1.2, 0.15, 0.15, 0.8), nrow = 2L),
    FF = rbind(rep(1, TT), seq(-0.4, 0.6, length.out = TT)),
    y = c(0.12, -0.06, 0.19, 0.03, 0.21, 0.08),
    ex_f = rep(0.04, TT),
    ex_q = rep(0.85, TT),
    df_mat = exdqlm:::make_df_mat(c(0.96, 0.91), c(1L, 1L), 2L)
  )
}

soft_version_value <- function(name) {
  versions <- extSoftVersion()
  if (name %in% names(versions)) {
    unname(versions[[name]])
  } else {
    NA_character_
  }
}

run_probe <- function(out_file) {
  library(exdqlm)

  options(
    exdqlm.use_cpp_kf = TRUE,
    exdqlm.use_cpp_builders = FALSE,
    exdqlm.use_cpp_samplers = FALSE,
    exdqlm.use_cpp_postpred = FALSE,
    exdqlm.use_cpp_mcmc = TRUE,
    exdqlm.cpp_mcmc_mode = "fast",
    exdqlm.cpp_threads = 1L
  )

  x <- make_ffbs_inputs()

  set.seed(2026091201)
  ffbs_1 <- exdqlm:::mcmc_ffbs_sample_cpp(
    GG = x$GG, m0 = x$m0, C0 = x$C0, FF = x$FF,
    y = x$y, ex_f = x$ex_f, ex_q = x$ex_q, df_mat = x$df_mat
  )
  set.seed(2026091201)
  ffbs_2 <- exdqlm:::mcmc_ffbs_sample_cpp(
    GG = x$GG, m0 = x$m0, C0 = x$C0, FF = x$FF,
    y = x$y, ex_f = x$ex_f, ex_q = x$ex_q, df_mat = x$df_mat
  )

  if (!identical(ffbs_1, ffbs_2)) {
    stop("Direct C++ FFBS probe is not repeatable within this process.")
  }

  model <- as.exdqlm(list(
    m0 = c(0.0, 0.0),
    C0 = diag(c(1.0, 0.5)),
    FF = matrix(c(1, 0.25), nrow = 2L),
    GG = matrix(c(1.0, 0.0, 0.15, 0.9), nrow = 2L, byrow = TRUE)
  ))

  set.seed(2026091202)
  fit <- exdqlmMCMC(
    y = c(0.10, -0.04, 0.09, -0.02, 0.05, 0.03),
    p0 = 0.5, model = model, df = c(0.96, 0.91), dim.df = c(1, 1),
    dqlm.ind = TRUE, fix.gamma = TRUE, fix.sigma = TRUE,
    sig.init = 1, gam.init = 0, n.burn = 3, n.mcmc = 6,
    init.from.isvb = FALSE, verbose = FALSE
  )

  probe <- list(
    meta = list(
      r_version = R.version.string,
      platform = R.version$platform,
      os = paste(Sys.info()[c("sysname", "release", "machine")], collapse = " "),
      exdqlm_version = as.character(packageVersion("exdqlm")),
      rng = RNGkind(),
      threads = Sys.getenv(thread_vars),
      blas = soft_version_value("BLAS"),
      lapack = soft_version_value("LAPACK")
    ),
    ffbs = list(
      theta = ffbs_1$sam.theta,
      sfe = ffbs_1$standard.forecast.errors,
      theta_head = as.numeric(ffbs_1$sam.theta[, seq_len(3L), drop = FALSE]),
      sfe_head = as.numeric(ffbs_1$standard.forecast.errors[seq_len(6L)])
    ),
    mcmc = list(
      backend = fit$backend,
      theta = unclass(fit$samp.theta),
      sigma = unclass(fit$samp.sigma),
      post_pred = unclass(fit$samp.post.pred),
      theta_head = as.numeric(unclass(fit$samp.theta)[seq_len(8L)]),
      post_pred_head = as.numeric(unclass(fit$samp.post.pred)[seq_len(6L)])
    )
  )

  cat("EXDQLM_FFBS_CROSS_OS_PROBE\n")
  cat("R_VERSION=", probe$meta$r_version, "\n", sep = "")
  cat("PLATFORM=", probe$meta$platform, "\n", sep = "")
  cat("OS=", probe$meta$os, "\n", sep = "")
  cat("EXDQLM_VERSION=", probe$meta$exdqlm_version, "\n", sep = "")
  cat("FFBS_THETA_HEAD=", paste(formatC(probe$ffbs$theta_head, digits = 17), collapse = ","), "\n", sep = "")
  cat("FFBS_SFE_HEAD=", paste(formatC(probe$ffbs$sfe_head, digits = 17), collapse = ","), "\n", sep = "")
  cat("MCMC_THETA_HEAD=", paste(formatC(probe$mcmc$theta_head, digits = 17), collapse = ","), "\n", sep = "")
  cat("MCMC_POSTPRED_HEAD=", paste(formatC(probe$mcmc$post_pred_head, digits = 17), collapse = ","), "\n", sep = "")

  saveRDS(probe, out_file, version = 3)
}

max_abs_diff <- function(x, y) {
  x <- as.numeric(x)
  y <- as.numeric(y)
  max(abs(x - y), na.rm = TRUE)
}

compare_probes <- function(input_dir, tolerance = 1e-10) {
  files <- list.files(input_dir, pattern = "[.]rds$", recursive = TRUE, full.names = TRUE)
  if (length(files) < 3L) {
    stop("Expected at least three diagnostic RDS files; found ", length(files), ".")
  }
  probes <- stats::setNames(lapply(files, readRDS), basename(files))
  ref_name <- names(probes)[1L]
  ref <- probes[[1L]]

  cat("EXDQLM_FFBS_CROSS_OS_COMPARE\n")
  cat("REFERENCE=", ref_name, "\n", sep = "")

  for (nm in names(probes)[-1L]) {
    pr <- probes[[nm]]
    diffs <- c(
      ffbs_theta = max_abs_diff(ref$ffbs$theta, pr$ffbs$theta),
      ffbs_sfe = max_abs_diff(ref$ffbs$sfe, pr$ffbs$sfe),
      mcmc_theta = max_abs_diff(ref$mcmc$theta, pr$mcmc$theta),
      mcmc_sigma = max_abs_diff(ref$mcmc$sigma, pr$mcmc$sigma),
      mcmc_post_pred = max_abs_diff(ref$mcmc$post_pred, pr$mcmc$post_pred)
    )
    cat(nm, "=", paste(names(diffs), formatC(diffs, digits = 17), sep = ":", collapse = ","), "\n", sep = "")
    if (any(!is.finite(diffs)) || any(diffs > tolerance)) {
      stop(
        "Cross-OS FFBS diagnostic exceeded tolerance for ", nm,
        ". Maximum difference: ", format(max(diffs), digits = 17)
      )
    }
  }
}

args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args)) args[[1L]] else "run"

if (identical(mode, "run")) {
  out_file <- if (length(args) >= 2L) args[[2L]] else "ffbs-cross-os-probe.rds"
  run_probe(out_file)
} else if (identical(mode, "compare")) {
  input_dir <- if (length(args) >= 2L) args[[2L]] else "."
  compare_probes(input_dir)
} else {
  stop("Unknown mode: ", mode)
}

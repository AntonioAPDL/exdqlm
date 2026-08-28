test_that("compiled stochastic helpers obey the R seed", {
  old_env <- Sys.getenv(c("OMP_NUM_THREADS", "OMP_THREAD_LIMIT"), unset = NA_character_)
  on.exit({
    for (nm in names(old_env)) {
      if (is.na(old_env[[nm]])) {
        Sys.unsetenv(nm)
      } else {
        do.call(Sys.setenv, stats::setNames(as.list(old_env[[nm]]), nm))
      }
    }
  }, add = TRUE)

  Sys.setenv(OMP_NUM_THREADS = "4", OMP_THREAD_LIMIT = "4")

  set.seed(2026082401)
  gig_1 <- exdqlm:::sample_gig_devroye_vector(
    n_samples = 8L, p = 0.5, a = 1.7,
    b_vec = seq(0.3, 2.1, length.out = 12L)
  )
  set.seed(2026082401)
  gig_2 <- exdqlm:::sample_gig_devroye_vector(
    n_samples = 8L, p = 0.5, a = 1.7,
    b_vec = seq(0.3, 2.1, length.out = 12L)
  )
  expect_identical(gig_1, gig_2)

  set.seed(2026082402)
  trunc_1 <- exdqlm:::sample_truncnorm(
    n_samp = 6L, TT = 4L,
    sts_mu = c(-0.2, 0.0, 0.5, 1.0),
    sts_sig2 = c(0.5, 1.0, 1.5, 2.0)
  )
  set.seed(2026082402)
  trunc_2 <- exdqlm:::sample_truncnorm(
    n_samp = 6L, TT = 4L,
    sts_mu = c(-0.2, 0.0, 0.5, 1.0),
    sts_sig2 = c(0.5, 1.0, 1.5, 2.0)
  )
  expect_identical(trunc_1, trunc_2)

  sC <- array(0, dim = c(2L, 2L, 3L))
  for (tt in seq_len(dim(sC)[3L])) {
    sC[, , tt] <- diag(c(1, 1.5))
  }
  sm <- matrix(seq(-0.2, 0.2, length.out = 6L), nrow = 2L)

  set.seed(2026082403)
  mvn_1 <- exdqlm:::sample_multivariate_normal(
    n_samp = 5L, TT = 3L, sC = sC, sm = sm, p = 1L, J = 1L
  )
  set.seed(2026082403)
  mvn_2 <- exdqlm:::sample_multivariate_normal(
    n_samp = 5L, TT = 3L, sC = sC, sm = sm, p = 1L, J = 1L
  )
  expect_identical(mvn_1, mvn_2)

  set.seed(2026082404)
  mvn_3 <- exdqlm:::sample_multivariate_normal(
    n_samp = 5L, TT = 3L, sC = sC, sm = sm, p = 1L, J = 1L
  )
  expect_false(identical(mvn_1, mvn_3))
})

test_that("dynamic MCMC fast path is repeatable under a fixed seed", {
  old_opts <- options(
    exdqlm.use_cpp_mcmc = TRUE,
    exdqlm.cpp_mcmc_mode = "fast",
    exdqlm.use_cpp_kf = TRUE,
    exdqlm.use_cpp_samplers = FALSE,
    exdqlm.use_cpp_postpred = FALSE,
    exdqlm.cpp_threads = 1L
  )
  on.exit(options(old_opts), add = TRUE)

  model <- as.exdqlm(list(m0 = 0, C0 = matrix(1, 1, 1), FF = 1, GG = 1))
  y <- c(0.12, -0.08, 0.15, -0.03, 0.11, -0.06, 0.05, 0.02)

  fit_once <- function() {
    set.seed(2026082405)
    exdqlmMCMC(
      y = y, p0 = 0.5, model = model,
      df = 0.95, dim.df = 1,
      dqlm.ind = FALSE,
      fix.gamma = FALSE,
      fix.sigma = TRUE,
      sig.init = 1,
      gam.init = 0,
      Sig.mh = diag(c(0.005, 0.005)),
      n.burn = 5,
      n.mcmc = 12,
      init.from.isvb = FALSE,
      verbose = FALSE
    )
  }

  fit_1 <- fit_once()
  fit_2 <- fit_once()
  for (nm in c("samp.theta", "samp.vts", "samp.gamma", "samp.sts", "samp.post.pred")) {
    expect_identical(fit_1[[nm]], fit_2[[nm]], info = nm)
  }
})

test_that("static MCMC path is repeatable under a fixed seed", {
  set.seed(2026082406)
  x <- cbind(1, matrix(stats::rnorm(40), 20, 2))
  beta <- c(0.2, 0.8, 0)
  y <- drop(x %*% beta + stats::rnorm(20, sd = 0.5))

  fit_once <- function() {
    set.seed(2026082407)
    exalStaticMCMC(
      y = y, X = x, p0 = 0.5,
      n.burn = 5,
      n.mcmc = 12,
      init = list(gamma = 0, sigma = 1),
      dqlm.ind = FALSE,
      trace.diagnostics = FALSE,
      verbose = FALSE
    )
  }

  fit_1 <- fit_once()
  fit_2 <- fit_once()
  for (nm in c("samp.beta", "samp.sigma", "samp.gamma", "samp.v", "samp.s")) {
    expect_identical(fit_1[[nm]], fit_2[[nm]], info = nm)
  }
})

test_that("stochastic helpers are repeatable across fresh R processes and thread settings", {
  skip_on_cran()

  child_script <- tempfile("exdqlm-rng-child-", fileext = ".R")
  on.exit(unlink(child_script), add = TRUE)

  writeLines(
    c(
      "library(exdqlm)",
      "out_file <- commandArgs(trailingOnly = TRUE)[[1L]]",
      "set.seed(2026082411)",
      "gig <- exdqlm:::sample_gig_devroye_vector(",
      "  n_samples = 6L, p = 0.5, a = 1.3,",
      "  b_vec = seq(0.4, 1.6, length.out = 5L)",
      ")",
      "set.seed(2026082412)",
      "trn <- exdqlm:::sample_truncnorm(",
      "  n_samp = 5L, TT = 4L,",
      "  sts_mu = c(-0.3, 0.0, 0.2, 0.6),",
      "  sts_sig2 = c(0.6, 0.9, 1.2, 1.5)",
      ")",
      "model <- as.exdqlm(list(m0 = 0, C0 = matrix(1, 1, 1), FF = 1, GG = 1))",
      "set.seed(2026082413)",
      "fit <- exdqlmMCMC(",
      "  y = c(0.10, -0.04, 0.09, -0.02, 0.05),",
      "  p0 = 0.5, model = model, df = 0.95, dim.df = 1,",
      "  dqlm.ind = FALSE, fix.gamma = FALSE, fix.sigma = TRUE,",
      "  sig.init = 1, gam.init = 0, n.burn = 3, n.mcmc = 6,",
      "  init.from.isvb = FALSE, verbose = FALSE",
      ")",
      "saveRDS(",
      "  list(",
      "    gig = gig, trn = trn,",
      "    gamma = fit$samp.gamma, theta = fit$samp.theta,",
      "    post_pred = fit$samp.post.pred",
      "  ),",
      "  out_file",
      ")"
    ),
    child_script
  )

  run_child <- function(threads) {
    out_file <- tempfile("exdqlm-rng-child-", fileext = ".rds")
    on.exit(unlink(out_file), add = TRUE)
    env_names <- c(
      "OMP_NUM_THREADS", "OMP_THREAD_LIMIT", "OPENBLAS_NUM_THREADS",
      "MKL_NUM_THREADS", "BLIS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"
    )
    old_env <- Sys.getenv(env_names, unset = NA_character_)
    on.exit({
      for (nm in env_names) {
        if (is.na(old_env[[nm]])) {
          Sys.unsetenv(nm)
        } else {
          do.call(Sys.setenv, stats::setNames(as.list(old_env[[nm]]), nm))
        }
      }
    }, add = TRUE)
    Sys.setenv(
      OMP_NUM_THREADS = as.character(threads),
      OMP_THREAD_LIMIT = as.character(threads),
      OPENBLAS_NUM_THREADS = "1",
      MKL_NUM_THREADS = "1",
      BLIS_NUM_THREADS = "1",
      VECLIB_MAXIMUM_THREADS = "1"
    )
    status <- system2(
      file.path(R.home("bin"), "Rscript"),
      args = c("--vanilla", shQuote(child_script), shQuote(out_file)),
      stdout = TRUE,
      stderr = TRUE
    )
    expect_false(inherits(status, "try-error"))
    expect_true(file.exists(out_file), info = paste(status, collapse = "\n"))
    readRDS(out_file)
  }

  omp1_a <- run_child(1L)
  omp1_b <- run_child(1L)
  omp4 <- run_child(4L)

  expect_identical(omp1_a, omp1_b)
  expect_identical(omp1_a, omp4)
})

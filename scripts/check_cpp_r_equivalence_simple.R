#!/usr/bin/env Rscript
lib <- file.path(getwd(), ".Rlib")
.libPaths(c(lib, .libPaths()))

suppressPackageStartupMessages(library(exdqlm))

set.seed(123)
T <- 60L
y <- numeric(T)
for (t in 2:T) {
  y[t] <- 0.6 * y[t - 1L] + rnorm(1, sd = 0.5)
}

fit <- qdesn_fit_vb(
  y = y,
  p0 = 0.5,
  D = 1L,
  n = 10L,
  m = 3L,
  washout = 5L,
  add_bias = TRUE,
  alpha = 0.4,
  standardize_inputs = TRUE,
  seed = 42L,
  vb_args = list(max_iter = 50L, tol = 1e-3, verbose = FALSE)
)

H <- 4L
nd <- 50L

compare_paths <- function(precompute = FALSE) {
  options(
    exdqlm.use_cpp_postpred = FALSE,
    exdqlm.use_cpp_postpred_precompute = precompute,
    exdqlm.use_cpp_postpred_omp = FALSE
  )
  set.seed(999)
  out_r <- forecast_paths.qdesn_fit(fit, H = H, nd = nd)

  options(
    exdqlm.use_cpp_postpred = TRUE,
    exdqlm.use_cpp_postpred_precompute = precompute,
    exdqlm.use_cpp_postpred_omp = FALSE
  )
  set.seed(999)
  out_cpp <- forecast_paths.qdesn_fit(fit, H = H, nd = nd)

  list(
    max_y = max(abs(out_r$yrep - out_cpp$yrep)),
    max_mu = max(abs(out_r$mu_draws - out_cpp$mu_draws))
  )
}

cat("== forecast_paths.qdesn_fit ==\n")
res_np <- compare_paths(precompute = FALSE)
cat(sprintf("precompute=FALSE: max|yrep diff|=%g, max|mu diff|=%g\n", res_np$max_y, res_np$max_mu))

res_pc <- compare_paths(precompute = TRUE)
cat(sprintf("precompute=TRUE : max|yrep diff|=%g, max|mu diff|=%g\n", res_pc$max_y, res_pc$max_mu))

y_force <- rep(0, H)
options(
  exdqlm.use_cpp_postpred = FALSE,
  exdqlm.use_cpp_postpred_precompute = FALSE,
  exdqlm.use_cpp_postpred_omp = FALSE
)
set.seed(111)
out_r_tf <- forecast_paths.qdesn_fit(fit, H = H, nd = nd, y_future_obs = y_force)
options(
  exdqlm.use_cpp_postpred = TRUE,
  exdqlm.use_cpp_postpred_precompute = FALSE,
  exdqlm.use_cpp_postpred_omp = FALSE
)
set.seed(111)
out_cpp_tf <- forecast_paths.qdesn_fit(fit, H = H, nd = nd, y_future_obs = y_force)
cat(sprintf("teacher-forced: max|yrep diff|=%g, max|mu diff|=%g\n",
            max(abs(out_r_tf$yrep - out_cpp_tf$yrep)),
            max(abs(out_r_tf$mu_draws - out_cpp_tf$mu_draws))))

stats_by_h <- function(mat) {
  rbind(
    mean = rowMeans(mat),
    sd = apply(mat, 1L, stats::sd),
    q10 = apply(mat, 1L, stats::quantile, probs = 0.1),
    q50 = apply(mat, 1L, stats::quantile, probs = 0.5),
    q90 = apply(mat, 1L, stats::quantile, probs = 0.9)
  )
}

summ_diff <- function(a, b) {
  d <- abs(a - b)
  apply(d, 1L, max)
}

summ_mean_diff <- function(a, b) {
  d <- abs(a - b)
  apply(d, 1L, mean)
}

nd_mc <- 2000L
options(
  exdqlm.use_cpp_postpred = FALSE,
  exdqlm.use_cpp_postpred_precompute = FALSE,
  exdqlm.use_cpp_postpred_omp = FALSE
)
set.seed(777)
out_r_mc <- forecast_paths.qdesn_fit(fit, H = H, nd = nd_mc)
options(
  exdqlm.use_cpp_postpred = TRUE,
  exdqlm.use_cpp_postpred_precompute = FALSE,
  exdqlm.use_cpp_postpred_omp = FALSE
)
set.seed(777)
out_cpp_mc <- forecast_paths.qdesn_fit(fit, H = H, nd = nd_mc)

diff_y_stats <- summ_diff(stats_by_h(out_r_mc$yrep), stats_by_h(out_cpp_mc$yrep))
diff_mu_stats <- summ_diff(stats_by_h(out_r_mc$mu_draws), stats_by_h(out_cpp_mc$mu_draws))
cat(sprintf(
  "precompute=FALSE MC stats (nd=%d): yrep max|diff| mean=%g sd=%g q10=%g q50=%g q90=%g\n",
  nd_mc, diff_y_stats["mean"], diff_y_stats["sd"], diff_y_stats["q10"],
  diff_y_stats["q50"], diff_y_stats["q90"]
))
cat(sprintf(
  "precompute=FALSE MC stats (nd=%d): mu   max|diff| mean=%g sd=%g q10=%g q50=%g q90=%g\n",
  nd_mc, diff_mu_stats["mean"], diff_mu_stats["sd"], diff_mu_stats["q10"],
  diff_mu_stats["q50"], diff_mu_stats["q90"]
))

cat(sprintf(
  "precompute=FALSE pathwise (nd=%d): mean|yrep diff|=%g, mean|mu diff|=%g\n",
  nd_mc, mean(abs(out_r_mc$yrep - out_cpp_mc$yrep)),
  mean(abs(out_r_mc$mu_draws - out_cpp_mc$mu_draws))
))

compare_summary <- function(nd_use, seed_use) {
  options(
    exdqlm.use_cpp_postpred = FALSE,
    exdqlm.use_cpp_postpred_precompute = FALSE,
    exdqlm.use_cpp_postpred_omp = FALSE
  )
  set.seed(seed_use)
  r_out <- forecast_paths.qdesn_fit(fit, H = H, nd = nd_use)
  options(
    exdqlm.use_cpp_postpred = TRUE,
    exdqlm.use_cpp_postpred_precompute = FALSE,
    exdqlm.use_cpp_postpred_omp = FALSE
  )
  set.seed(seed_use)
  c_out <- forecast_paths.qdesn_fit(fit, H = H, nd = nd_use)

  sr <- stats_by_h(r_out$yrep)
  sc <- stats_by_h(c_out$yrep)
  dr_mean <- abs(sr["mean", ] - sc["mean", ])
  dr_q50  <- abs(sr["q50", ] - sc["q50", ])

  srm <- stats_by_h(r_out$mu_draws)
  scm <- stats_by_h(c_out$mu_draws)
  dm_mean <- abs(srm["mean", ] - scm["mean", ])
  dm_q50  <- abs(srm["q50", ] - scm["q50", ])

  list(
    y_mean_mean = mean(dr_mean),
    y_mean_max = max(dr_mean),
    y_q50_mean = mean(dr_q50),
    y_q50_max = max(dr_q50),
    mu_mean_mean = mean(dm_mean),
    mu_mean_max = max(dm_mean),
    mu_q50_mean = mean(dm_q50),
    mu_q50_max = max(dm_q50)
  )
}

nd_grid <- c(200L, 1000L, 5000L)
seed_grid <- c(101L, 202L, 303L)
cat("\nprecompute=FALSE convergence check (avg over 3 seeds):\n")
for (nd_use in nd_grid) {
  res <- lapply(seed_grid, function(s) compare_summary(nd_use, s))
  avg <- function(name) mean(vapply(res, function(r) r[[name]], numeric(1)))
  cat(sprintf(
    "nd=%d: y mean diff mean/max=%g/%g; y median diff mean/max=%g/%g; mu mean diff mean/max=%g/%g; mu median diff mean/max=%g/%g\n",
    nd_use,
    avg("y_mean_mean"), avg("y_mean_max"),
    avg("y_q50_mean"), avg("y_q50_max"),
    avg("mu_mean_mean"), avg("mu_mean_max"),
    avg("mu_q50_mean"), avg("mu_q50_max")
  ))
}

cat("\n== identity reducers (D=3) ==\n")
fit_id <- qdesn_fit_vb(
  y = y,
  p0 = 0.5,
  D = 3L,
  n = c(8L, 6L, 5L),
  n_tilde = c(8L, 3L),
  m = 2L,
  washout = 5L,
  add_bias = TRUE,
  alpha = 0.4,
  standardize_inputs = TRUE,
  seed = 7L,
  vb_args = list(max_iter = 40L, tol = 1e-3, verbose = FALSE)
)
cat(sprintf("Q_is_identity=%s\n", paste(fit_id$reservoir$Q_is_identity, collapse = ",")))

H_id <- 3L
nd_id <- 30L
compare_paths_id <- function(precompute = FALSE) {
  options(
    exdqlm.use_cpp_postpred = FALSE,
    exdqlm.use_cpp_postpred_precompute = precompute,
    exdqlm.use_cpp_postpred_omp = FALSE
  )
  set.seed(444)
  out_r <- forecast_paths.qdesn_fit(fit_id, H = H_id, nd = nd_id)

  options(
    exdqlm.use_cpp_postpred = TRUE,
    exdqlm.use_cpp_postpred_precompute = precompute,
    exdqlm.use_cpp_postpred_omp = FALSE
  )
  set.seed(444)
  out_cpp <- forecast_paths.qdesn_fit(fit_id, H = H_id, nd = nd_id)

  list(
    max_y = max(abs(out_r$yrep - out_cpp$yrep)),
    max_mu = max(abs(out_r$mu_draws - out_cpp$mu_draws))
  )
}
res_id_np <- compare_paths_id(precompute = FALSE)
cat(sprintf("precompute=FALSE: max|yrep diff|=%g, max|mu diff|=%g\n", res_id_np$max_y, res_id_np$max_mu))
res_id_pc <- compare_paths_id(precompute = TRUE)
cat(sprintf("precompute=TRUE : max|yrep diff|=%g, max|mu diff|=%g\n", res_id_pc$max_y, res_id_pc$max_mu))

origins <- c(30L, 40L, 50L)
set.seed(202)
options(
  exdqlm.use_cpp_postpred = FALSE,
  exdqlm.use_cpp_postpred_precompute = TRUE,
  exdqlm.use_cpp_postpred_omp = FALSE
)
lat_r <- exdqlm:::forecast_lattice.qdesn_fit(
  object = fit,
  y_all = y,
  origins = origins,
  H = H,
  nd = nd,
  mix_nd = 40L,
  keep_origin_draws = TRUE
)

set.seed(202)
options(
  exdqlm.use_cpp_postpred = TRUE,
  exdqlm.use_cpp_postpred_precompute = TRUE,
  exdqlm.use_cpp_postpred_omp = FALSE
)
lat_cpp <- exdqlm:::forecast_lattice.qdesn_fit(
  object = fit,
  y_all = y,
  origins = origins,
  H = H,
  nd = nd,
  mix_nd = 40L,
  keep_origin_draws = TRUE
)

max_abs <- function(x) {
  v <- as.numeric(x)
  v <- v[is.finite(v)]
  if (!length(v)) return(NA_real_)
  max(abs(v))
}

mix_y_diff <- max_abs(lat_r$mix$y - lat_cpp$mix$y)
mix_mu_diff <- max_abs(lat_r$mix$mu - lat_cpp$mix$mu)
orig_diff <- max(vapply(seq_along(origins), function(i) {
  max(abs(lat_r$yrep_by_origin[[i]] - lat_cpp$yrep_by_origin[[i]]))
}, numeric(1)))

cat("\n== forecast_lattice.qdesn_fit ==\n")
cat(sprintf("mix max|y diff|=%g, mix max|mu diff|=%g\n", mix_y_diff, mix_mu_diff))
cat(sprintf("per-origin max|yrep diff|=%g\n", orig_diff))

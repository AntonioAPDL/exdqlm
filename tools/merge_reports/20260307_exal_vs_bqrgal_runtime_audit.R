#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(pkgload)
  library(readr)
  library(dplyr)
  library(tibble)
  library(purrr)
})

repo_root <- "/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp"
bqr_root <- "/data/muscat_data/jaguir26/bqrgal-examples/bqrgal"
scenario_root <- file.path(repo_root, "results/function_testing_20260306_static_simple_linear_exal_positive_gamma")
input_root <- file.path(scenario_root, "fit_input_subsample_tt5000_xmain_sorted")
run_root <- file.path(scenario_root, "mcmc_triplet_compare_full5000_burn2000_n1000_20260306_234917")
audit_root <- file.path(repo_root, "results/sim_suite_static/audits/exal_vs_bqrgal_runtime_20260307")
dir.create(audit_root, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(audit_root, "tables"), showWarnings = FALSE)

our_pkg <- pkgload::load_all(repo_root, quiet = TRUE, helpers = FALSE, attach_testthat = FALSE, export_all = FALSE)
bqr_pkg <- pkgload::load_all(bqr_root, quiet = TRUE, helpers = FALSE, attach_testthat = FALSE, export_all = FALSE)
our_ns <- asNamespace("exdqlm")
bqr_ns <- asNamespace("bqrgal")

sim <- readRDS(file.path(input_root, "sim_output.rds"))
X <- as.matrix(sim$extras$X)
y <- as.numeric(sim$y)
fit_our <- readRDS(file.path(run_root, "fits", "our_exal_slice_tau_0.50.rds"))
fit_bqr <- readRDS(file.path(run_root, "fits", "bqrgal_slice_tau_0.50.rds"))
path_tbl <- read_csv(file.path(run_root, "tables", "fit_path_summary_long.csv"), show_col_types = FALSE)
metrics_tbl <- read_csv(file.path(run_root, "tables", "metrics_summary.csv"), show_col_types = FALSE)

# Representative state from the saved chain (matched target tau = 0.50)
keep_idx <- nrow(fit_our$samp.beta) %/% 2
beta <- as.numeric(fit_our$samp.beta[keep_idx, ])
sigma <- as.numeric(fit_our$samp.sigma[keep_idx])
gamma <- as.numeric(fit_our$samp.gamma[keep_idx])
v <- as.numeric(fit_our$samp.v[keep_idx, ])
s <- as.numeric(fit_our$samp.s[keep_idx, ])
p0 <- 0.5
n <- length(y)
L <- get("L.fn", our_ns)(p0)
U <- get("U.fn", our_ns)(p0)
A_of <- function(g) get("A.fn", our_ns)(p0, g)
B_of <- function(g) get("B.fn", our_ns)(p0, g)
C_of <- function(g) get("C.fn", our_ns)(p0, g)
lam_of <- function(g) C_of(g) * abs(g)
V0_inv <- diag(1 / 1e6, ncol(X))
b0 <- rep(0, ncol(X))
xb <- drop(X %*% beta)

our_logpost_gamma <- function(g) {
  if (!is.finite(g) || g <= L || g >= U || sigma <= 0 || any(v <= 0)) return(-Inf)
  A <- as.numeric(A_of(g))[1L]
  B <- as.numeric(B_of(g))[1L]
  lam <- as.numeric(lam_of(g))[1L]
  if (!is.finite(B) || B <= 0) return(-Inf)
  mu <- xb + lam * sigma * s + A * v
  res <- y - mu
  quad <- sum((res * res) / (B * sigma * v))
  if (!is.finite(quad)) return(-Inf)
  -(n / 2) * log(B) - 0.5 * quad
}
our_logpost_gamma_nocache <- function(g) {
  if (!is.finite(g) || g <= L || g >= U || sigma <= 0 || any(v <= 0)) return(-Inf)
  A <- as.numeric(A_of(g))[1L]
  B <- as.numeric(B_of(g))[1L]
  lam <- as.numeric(lam_of(g))[1L]
  if (!is.finite(B) || B <= 0) return(-Inf)
  mu <- drop(X %*% beta) + lam * sigma * s + A * v
  res <- y - mu
  quad <- sum((res * res) / (B * sigma * v))
  if (!is.finite(quad)) return(-Inf)
  -(n / 2) * log(B) - 0.5 * quad
}
bqr_logcondpga <- function(g) {
  get("logcondpga", bqr_ns)(g, yy = y, p0 = p0, mu = xb, sigma = sigma, ss = s, vv = v)
}

# Numerical equivalence on gamma grid
bounds_bqr <- c(get("find_ga_lb", bqr_ns)(p0, interval = c(-50, -1e-8), extendInt = "yes"),
                get("find_ga_ub", bqr_ns)(p0, interval = c(1e-8, 50), extendInt = "yes"))
grid <- seq(max(L, bounds_bqr[1]) + 1e-5, min(U, bounds_bqr[2]) - 1e-5, length.out = 401)
ours_grid <- vapply(grid, our_logpost_gamma, numeric(1))
bqr_grid <- vapply(grid, bqr_logcondpga, numeric(1))
centered_diff <- (ours_grid - max(ours_grid)) - (bqr_grid - max(bqr_grid))
num_eq_tbl <- tibble(
  p0 = p0,
  lower = max(L, bounds_bqr[1]),
  upper = min(U, bounds_bqr[2]),
  max_abs_centered_diff = max(abs(centered_diff)),
  mean_abs_centered_diff = mean(abs(centered_diff)),
  cor_centered = suppressWarnings(cor(ours_grid - max(ours_grid), bqr_grid - max(bqr_grid)))
)
write_csv(num_eq_tbl, file.path(audit_root, "tables", "gamma_logkernel_equivalence.csv"))

# Component benchmarks
bench_once <- function(expr, n_rep = 1L) {
  gc(verbose = FALSE)
  t0 <- proc.time()[[3]]
  force(n_rep)
  for (ii in seq_len(n_rep)) eval.parent(substitute(expr))
  (proc.time()[[3]] - t0) / n_rep
}

# pull bqr functions
bqr_updateBeta <- get("updateBeta", bqr_ns)
bqr_updateVV <- get("updateVV", bqr_ns)
bqr_updateSS <- get("updateSS", bqr_ns)
bqr_updateSigma <- get("updateSigma", bqr_ns)
bqr_uniSlice <- get("uniSlice", bqr_ns)

pp <- get("p_func", bqr_ns)(gamma, p0)
AA <- get("A_func", bqr_ns)(pp)
BB <- get("B_func", bqr_ns)(pp)
CC <- get("C_func", bqr_ns)(gamma, pp)
mu <- xb

our_beta_step <- function() {
  W_diag <- 1 / (BB * sigma * v)
  Xw <- X * sqrt(W_diag)
  V_inv <- crossprod(Xw) + V0_inv
  y_star <- y - (CC * abs(gamma)) * sigma * s - AA * v
  rhs <- crossprod(X, W_diag * y_star) + V0_inv %*% b0
  Uc <- chol(V_inv + 1e-10 * diag(ncol(X)))
  m_beta <- backsolve(Uc, forwardsolve(t(Uc), rhs))
  as.numeric(m_beta + backsolve(Uc, rnorm(ncol(X))))
}
our_v_step <- function() {
  z <- y - xb - (CC * abs(gamma)) * sigma * s
  chi_i <- (z * z) / (BB * sigma)
  psi_i <- (AA * AA) / (BB * sigma) + (2 / sigma)
  as.numeric(get("sample_gig_devroye_vector", our_ns)(1L, p = 0.5, a = psi_i, b_vec = chi_i)[1, ])
}
our_s_step <- function() {
  lambda <- CC * abs(gamma)
  r <- y - xb - AA * v
  tau2 <- pmax(1 / (1 + (lambda * lambda) * sigma / (BB * v)), 1e-12)
  mu_s <- tau2 * (lambda * r) / (BB * v)
  as.numeric(get("sample_truncnorm", our_ns)(1L, n, sts_mu = mu_s, sts_sig2 = tau2)[1, ])
}
our_sigma_step <- function() {
  lambda <- CC * abs(gamma)
  r <- y - xb - AA * v
  chi_sigma <- sum((r * r) / (BB * v)) + 2 * sum(v) + 2
  psi_sigma <- (lambda * lambda / BB) * sum((s * s) / v)
  as.numeric(get("sample_gig_devroye_vector", our_ns)(1L, p = -(1 + 1.5 * n), a = psi_sigma, b_vec = chi_sigma)[1, 1])
}
our_slice_step <- function() {
  get(".exdqlm_uni_slice_bounded", our_ns)(gamma, our_logpost_gamma_nocache, w = 0.1, m = Inf, lower = L + 1e-10, upper = U - 1e-10)$value
}
bqr_slice_step <- function() {
  bqr_uniSlice(x0 = gamma, g = get("logcondpga", bqr_ns), w = 0.1, m = Inf, lower = bounds_bqr[1], upper = bounds_bqr[2], yy = y, p0 = p0, mu = mu, sigma = sigma, ss = s, vv = v)
}

bench_tbl <- tibble(
  component = c(
    "our_logpost_gamma_eval",
    "our_logpost_gamma_eval_cached_xb",
    "bqrgal_logcondpga_eval",
    "our_trace_summary_s",
    "our_trace_summary_tau2",
    "our_beta_step",
    "bqrgal_beta_step",
    "our_v_step",
    "bqrgal_v_step",
    "our_s_step",
    "bqrgal_s_step",
    "our_sigma_step",
    "bqrgal_sigma_step",
    "our_slice_step",
    "bqrgal_slice_step"
  ),
  sec_per_call = c(
    bench_once(our_logpost_gamma_nocache(gamma), n_rep = 50L),
    bench_once(our_logpost_gamma(gamma), n_rep = 50L),
    bench_once(bqr_logcondpga(gamma), n_rep = 50L),
    bench_once(get(".exdqlm_trace_summary", our_ns)(s), n_rep = 100L),
    bench_once({lambda <- CC * abs(gamma); tau2 <- pmax(1 / (1 + (lambda * lambda) * sigma / (BB * v)), 1e-12); get(".exdqlm_trace_summary", our_ns)(tau2)}, n_rep = 100L),
    bench_once(our_beta_step(), n_rep = 20L),
    bench_once(bqr_updateBeta(be_mu0 = rep(0, ncol(X)), be_Sigma0 = diag(1e6, ncol(X)), yy = y, XX = X, sigma = sigma, ga = gamma, ss = s, vv = v, AA = AA, BB = BB, CC = CC), n_rep = 20L),
    bench_once(our_v_step(), n_rep = 10L),
    bench_once(bqr_updateVV(yy = y, mu = mu, sigma = sigma, ga = gamma, ss = s, AA = AA, BB = BB, CC = CC, nn = n), n_rep = 10L),
    bench_once(our_s_step(), n_rep = 20L),
    bench_once(bqr_updateSS(yy = y, mu = mu, sigma = sigma, ga = gamma, vv = v, AA = AA, BB = BB, CC = CC, nn = n), n_rep = 20L),
    bench_once(our_sigma_step(), n_rep = 20L),
    bench_once(bqr_updateSigma(u_sigma = 1, v_sigma = 1, yy = y, mu = mu, ga = gamma, ss = s, vv = v, AA = AA, BB = BB, CC = CC, nn = n), n_rep = 20L),
    bench_once(our_slice_step(), n_rep = 10L),
    bench_once(bqr_slice_step(), n_rep = 10L)
  )
) %>% arrange(desc(sec_per_call))
write_csv(bench_tbl, file.path(audit_root, "tables", "component_benchmarks.csv"))

# Short-run profiling
run_short_our <- function() {
  get("exal_static_mcmc", our_ns)(y = y, X = X, p0 = 0.5, dqlm.ind = FALSE, n.burn = 60, n.mcmc = 30, thin = 1, mh.proposal = "slice", slice.width = 0.1, slice.max.steps = Inf, log_prior_gamma = function(g) 0, verbose = FALSE)
}
run_short_bqr <- function() {
  get("bgal", bqr_ns)(
    resp = y,
    covars = X,
    prob = 0.5,
    beta_prior = "gaussian",
    priors = list(beta_gaus = list(mean_vec = rep(0, ncol(X)), var_mat = diag(1e6, ncol(X))), sigma_invgamma = c(1, 1), ga_uniform = bounds_bqr),
    starting = list(ga = 0, sigma = 1, vv = rep(1, length(y)), ss = abs(stats::rnorm(length(y))), omega = NULL),
    tuning = list(step_size = 0.1),
    mcmc_settings = list(n_iter = 90, n_burn = 60, n_thin = 1, n_report = 1000),
    ga_sampler = "slice",
    verbose = FALSE
  )
}
profile_run <- function(fun, out_file) {
  tmp <- tempfile(fileext = ".out")
  Rprof(tmp, interval = 0.01)
  t0 <- proc.time()[[3]]
  invisible(fun())
  elapsed <- proc.time()[[3]] - t0
  Rprof(NULL)
  prof <- summaryRprof(tmp)
  by_total <- as.data.frame(prof$by.total)
  by_self <- as.data.frame(prof$by.self)
  by_total$fun <- rownames(by_total)
  by_self$fun <- rownames(by_self)
  by_total <- tibble::as_tibble(by_total) %>% arrange(desc(total.time)) %>% slice_head(n = 15) %>% mutate(run = out_file, view = "by_total", elapsed_sec = elapsed)
  by_self <- tibble::as_tibble(by_self) %>% arrange(desc(self.time)) %>% slice_head(n = 15) %>% mutate(run = out_file, view = "by_self", elapsed_sec = elapsed)
  bind_rows(by_total, by_self)
}
prof_tbl <- bind_rows(
  profile_run(run_short_our, "our_exal_slice_short"),
  profile_run(run_short_bqr, "bqrgal_slice_short")
)
write_csv(prof_tbl, file.path(audit_root, "tables", "short_run_profile_summary.csv"))

# Path closeness in completed full run
path_compare_tbl <- path_tbl %>%
  filter(abs(tau - 0.5) < 1e-12, method %in% c("our_exal_slice", "bqrgal_slice", "our_al")) %>%
  select(idx, method, fit_mean) %>%
  tidyr::pivot_wider(names_from = method, values_from = fit_mean) %>%
  summarise(
    cor_our_vs_bqr = cor(our_exal_slice, bqrgal_slice),
    rmse_our_vs_bqr = sqrt(mean((our_exal_slice - bqrgal_slice)^2)),
    rmse_our_vs_al = sqrt(mean((our_exal_slice - our_al)^2)),
    rmse_bqr_vs_al = sqrt(mean((bqrgal_slice - our_al)^2))
  )
write_csv(path_compare_tbl, file.path(audit_root, "tables", "path_closeness_tau_0.50.csv"))

winner_tbl <- read_csv(file.path(run_root, "tables", "winner_summary.csv"), show_col_types = FALSE)
metrics_focus_tbl <- metrics_tbl %>% filter(tau == 0.5) %>% select(method_label, runtime_sec, rmse, gamma_mean, ess_sigma, ess_gamma)
write_csv(metrics_focus_tbl, file.path(audit_root, "tables", "full_run_tau_0.50_metrics.csv"))

note <- c(
  "# exAL vs bqrgal Runtime and Accuracy Audit",
  "",
  sprintf("Scenario root: `%s`", normalizePath(scenario_root)),
  sprintf("Comparison root: `%s`", normalizePath(run_root)),
  "",
  "## Executive summary",
  "",
  "1. On the matched target tau = 0.50, our exAL and bqrgal target essentially the same gamma conditional kernel numerically.",
  "2. The fit difference is small; bqrgal is slightly better, but our exAL is very close and much closer to bqrgal than to AL.",
  "3. The large runtime gap is mainly implementation overhead, not a different target: our code recomputes X %*% beta inside every gamma log-density evaluation and also computes/stores rich per-iteration diagnostics and s/tau2 summaries inside the main loop.",
  "4. bqrgal is leaner: cached mu is passed into gamma log density, and there is almost no per-iteration trace bookkeeping.",
  "",
  "## Matched tau = 0.50 metrics",
  ""
)
note <- c(note, capture.output(print(metrics_focus_tbl, n = nrow(metrics_focus_tbl))))
note <- c(note, "", "## Gamma kernel equivalence", "")
note <- c(note, capture.output(print(num_eq_tbl, n = nrow(num_eq_tbl))))
note <- c(note, "", "## Path closeness", "")
note <- c(note, capture.output(print(path_compare_tbl, n = nrow(path_compare_tbl))))
note <- c(note, "", "## Slowest components", "")
note <- c(note, capture.output(print(bench_tbl, n = nrow(bench_tbl))))
note <- c(note, "", "## Short run profile summary", "")
note <- c(note, capture.output(print(prof_tbl, n = nrow(prof_tbl))))
writeLines(note, file.path(audit_root, "bqrgal_runtime_audit_note.md"))
cat(sprintf("Audit written to %s\n", audit_root))

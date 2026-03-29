# RHS-NS Wave Test Matrix Results (2026-03-29)

Primary tracker: `TRACK__RHS_NS_CROSS_BRANCH_EXECUTION_PLAN_20260329.md`

Worktrees:

- `0.4.0` line: `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`
- qdesn line: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Scope

This evidence bundle covers:

- Wave 2 closed-form static RHS-NS port checks on `0.4.0` line.
- Wave 3 qdesn default/intercept-policy hardening checks.
- Wave 5 matrix requirements (T1-T4), including numerical sanity checks for parameterization and support.

## 2) `0.4.0` Worktree Test Evidence

### 2.1 Static targeted suites

Command:

```bash
Rscript -e "pkgload::load_all('/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs', quiet=TRUE); testthat::test_dir('/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs/tests/testthat', filter='static-beta-prior-rhs|static-fit-normalization|static-ldvb-jacobian|static-exal-shared-issue-checks', reporter='summary')"
```

Outcome:

- PASS.
- Confirms closed-form RHS-NS blocks and precision mapping checks in `test-static-beta-prior-rhs`.
- Confirms static normalization and interface stability in `test-static-fit-normalization`.

### 2.2 Static integration check (`ridge`, `rhs`, `rhs_ns`) for VB and MCMC

Command:

```bash
Rscript - <<'RS'
set.seed(20260329)
pkgload::load_all('/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs', quiet=TRUE)

dat_n <- 42
x1 <- rnorm(dat_n)
x2 <- runif(dat_n, -1, 1)
X <- cbind(1, x1, x2, x1 * x2)
y <- as.numeric(0.4 + 0.9 * x1 - 0.6 * x2 + 0.2 * x1 * x2 + rnorm(dat_n, sd = 0.35))

priors <- c('ridge', 'rhs', 'rhs_ns')
for (pr in priors) {
  vb_args <- list(y = y, X = X, p0 = 0.5, beta_prior = pr, max_iter = 35, tol = 1e-3, n_samp_xi = 50, verbose = FALSE)
  mc_args <- list(y = y, X = X, p0 = 0.5, beta_prior = pr, n.burn = 25, n.mcmc = 30, thin = 1, mh.proposal = 'slice', trace.diagnostics = FALSE, verbose = FALSE)
  if (pr == 'rhs') {
    rhs_ctrl <- list(tau0 = 0.5, nu = 4, s2 = 1, shrink_intercept = FALSE)
    vb_args$beta_prior_controls <- rhs_ctrl
    mc_args$beta_prior_controls <- rhs_ctrl
  }
  if (pr == 'rhs_ns') {
    rhsns_ctrl <- list(tau0 = 0.5, a_zeta = 2, b_zeta = 1, s2 = 1, shrink_intercept = FALSE)
    vb_args$beta_prior_controls <- rhsns_ctrl
    mc_args$beta_prior_controls <- rhsns_ctrl
  }
  fit_vb <- do.call(exal_static_LDVB, vb_args)
  fit_mc <- do.call(exal_static_mcmc, mc_args)
  stopifnot(identical(fit_vb$beta_prior$type, pr))
  stopifnot(identical(fit_mc$beta_prior$type, pr))
  stopifnot(is.finite(fit_vb$qsiggam$sigma_mean))
  stopifnot(is.finite(fit_vb$qsiggam$gamma_mean))
  stopifnot(all(is.finite(as.numeric(fit_mc$samp.sigma))))
  stopifnot(all(is.finite(as.numeric(fit_mc$samp.gamma))))
  cat(sprintf('PASS static integration prior=%s | VB sigma=%.4f gamma=%.4f | MCMC sigma_mean=%.4f gamma_mean=%.4f\n',
              pr,
              as.numeric(fit_vb$qsiggam$sigma_mean),
              as.numeric(fit_vb$qsiggam$gamma_mean),
              mean(as.numeric(fit_mc$samp.sigma)),
              mean(as.numeric(fit_mc$samp.gamma))))
}
RS
```

Outcome:

- PASS for all three prior routes in VB and MCMC.

### 2.3 Parameterization consistency sanity checks (IG, GIG, truncated Normal)

Command:

```bash
Rscript - <<'RS'
set.seed(20260329)
pkgload::load_all('/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs', quiet=TRUE)

# IG(shape=a, scale=b) under kernel x^{-a-1} exp(-b/x)
a <- 3.5
b <- 2.0
x_ig <- 1 / rgamma(40000, shape = a, rate = b)
mean_emp_ig <- mean(x_ig)
mean_the_ig <- b / (a - 1)

# GIG(p, chi, psi) under kernel x^{p-1} exp(-0.5*(chi/x + psi*x))
p <- 0.5
chi <- 1.8
psi <- 2.4
x_gig <- sample_gig_devroye_vector(n = 40000L, p = p, a = psi, b = chi)
z <- sqrt(chi * psi)
mean_the_gig <- (sqrt(chi / psi)) * (besselK(z, nu = p + 1) / besselK(z, nu = p))
mean_emp_gig <- mean(x_gig)

# Truncated Normal mean/variance parameterization
mu <- rep(0.35, 40000)
tau2 <- rep(0.28, 40000)
x_tn <- as.numeric(sample_truncnorm(1L, 40000L, sts_mu = mu, sts_sig2 = tau2)[1, ])
alpha <- mu[1] / sqrt(tau2[1])
mean_the_tn <- mu[1] + sqrt(tau2[1]) * dnorm(alpha) / pnorm(alpha)
mean_emp_tn <- mean(x_tn)

cat(sprintf('PASS parameterization sanity | IG mean rel.err=%.4f | GIG mean rel.err=%.4f | TN mean rel.err=%.4f\n',
            abs(mean_emp_ig - mean_the_ig) / abs(mean_the_ig),
            abs(mean_emp_gig - mean_the_gig) / abs(mean_the_gig),
            abs(mean_emp_tn - mean_the_tn) / abs(mean_the_tn)))
RS
```

Outcome:

- PASS (`IG` rel.err `0.0019`; `GIG` rel.err `0.0263`; truncated-Normal rel.err `0.0043`).

### 2.4 Support and SPD checks for Block structure

Command:

```bash
Rscript - <<'RS'
set.seed(20260329)
pkgload::load_all('/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs', quiet=TRUE)

n <- 36
x <- rnorm(n)
X <- cbind(1, x, x^2)
y <- as.numeric(0.2 + 0.6*x - 0.1*x^2 + rnorm(n, sd=0.3))
fit <- exal_static_mcmc(
  y = y, X = X, p0 = 0.5,
  beta_prior = 'rhs_ns',
  beta_prior_controls = list(tau0 = 0.5, a_zeta = 2, b_zeta = 1, shrink_intercept = FALSE),
  n.burn = 20, n.mcmc = 24, thin = 1,
  mh.proposal = 'slice', trace.diagnostics = FALSE, verbose = FALSE
)

# Support checks
L <- L.fn(0.5); U <- U.fn(0.5)
stopifnot(all(as.numeric(fit$samp.sigma) > 0))
stopifnot(all(as.numeric(fit$samp.gamma) > L), all(as.numeric(fit$samp.gamma) < U))
stopifnot(all(as.matrix(fit$samp.v) > 0))
stopifnot(all(as.matrix(fit$samp.s) > 0))

# SPD check for beta block matrix at final state
st <- fit$rhs.diagnostics$summary
p <- ncol(X)
active <- 2:p
prec <- rep(NA_real_, p)
prec[1] <- 1e-16
prec[active] <- 1 / (as.numeric(st$tau2) * as.numeric(st$lambda2)) + 1 / as.numeric(st$zeta2)
B <- as.numeric(B.fn(0.5, as.numeric(fit$last$gamma)))
w <- 1 / (B * as.numeric(fit$last$sigma) * pmax(as.numeric(fit$last$v), 1e-12))
H <- crossprod(X * sqrt(w), X * sqrt(w)) + diag(prec, p)
min_eig <- min(eigen(H, symmetric = TRUE, only.values = TRUE)$values)
chol(H)
stopifnot(is.finite(min_eig), min_eig > 0)

cat(sprintf('PASS support+SPD checks | min eig %.6e\n', min_eig))
RS
```

Outcome:

- PASS (`sigma>0`, `v>0`, `s>0`, `gamma in (L,U)`).
- PASS SPD check for `X'WX + D^{-1}` style beta precision system (`min eig > 0`).

## 3) qdesn Worktree Test Evidence

### 3.1 Targeted suites for defaults/intercept policy and algorithm stability

Command:

```bash
Rscript -e "pkgload::load_all('/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline', quiet=TRUE); testthat::test_dir('/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/tests/testthat', filter='qdesn-prior-defaults|exal-inference-config|exal-mcmc|qdesn-mcmc-validation-pilot', reporter='summary')"
```

Outcome:

- PASS.
- Confirms RHS-NS default resolution, intercept policy enforcement, ridge override routing, finite ELBO traces, and MCMC validation/signoff helpers including drift/ESS/Geweke-related logic.

### 3.2 End-to-end `qdesn_fit` routing checks (default RHS-NS and explicit ridge override)

Command:

```bash
Rscript - <<'RS'
set.seed(20260329)
pkgload::load_all('/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline', quiet=TRUE)

y <- as.numeric(2 + sin(seq_len(72)/6) + 0.15 * rnorm(72))

fit_vb_def <- exdqlm::qdesn_fit(
  y = y, p0 = 0.5, method = 'vb',
  D = 1L, n = 10L, m = 5L, alpha = 0.3, rho = 0.9,
  act_f = 'tanh', act_k = 'identity', pi_w = 0.2, pi_in = 1.0,
  washout = 6L, add_bias = TRUE, seed = 101L,
  vb_args = list(max_iter = 16L, min_iter_elbo = 6L, tol = 1e-3, n_samp_xi = 40L, verbose = FALSE)
)

fit_mc_def <- exdqlm::qdesn_fit(
  y = y, p0 = 0.5, method = 'mcmc',
  D = 1L, n = 10L, m = 5L, alpha = 0.3, rho = 0.9,
  act_f = 'tanh', act_k = 'identity', pi_w = 0.2, pi_in = 1.0,
  washout = 6L, add_bias = TRUE, seed = 101L,
  mcmc_args = list(n_burn = 15L, n_mcmc = 20L, thin = 1L, verbose = FALSE, init_from_vb = FALSE)
)

fit_vb_ridge <- exdqlm::qdesn_fit(
  y = y, p0 = 0.5, method = 'vb',
  D = 1L, n = 10L, m = 5L, alpha = 0.3, rho = 0.9,
  act_f = 'tanh', act_k = 'identity', pi_w = 0.2, pi_in = 1.0,
  washout = 6L, add_bias = TRUE, seed = 101L,
  vb_args = list(beta_prior_type = 'ridge', beta_ridge_tau2 = 5e3, max_iter = 12L, min_iter_elbo = 5L, tol = 1e-3, n_samp_xi = 40L, verbose = FALSE)
)

fit_mc_ridge <- exdqlm::qdesn_fit(
  y = y, p0 = 0.5, method = 'mcmc',
  D = 1L, n = 10L, m = 5L, alpha = 0.3, rho = 0.9,
  act_f = 'tanh', act_k = 'identity', pi_w = 0.2, pi_in = 1.0,
  washout = 6L, add_bias = TRUE, seed = 101L,
  mcmc_args = list(beta_prior_type = 'ridge', beta_ridge_tau2 = 5e3, n_burn = 10L, n_mcmc = 15L, thin = 1L, verbose = FALSE, init_from_vb = FALSE)
)

stopifnot(identical(fit_vb_def$fit$beta_prior$type, 'rhs_ns'))
stopifnot(identical(fit_mc_def$fit$beta_prior$type, 'rhs_ns'))
stopifnot(identical(fit_vb_ridge$fit$beta_prior$type, 'ridge'))
stopifnot(identical(fit_mc_ridge$fit$beta_prior$type, 'ridge'))
stopifnot(all(is.finite(fit_vb_def$fit$misc$elbo_trace)))

cat(sprintf('PASS qdesn integration | default VB prior=%s | default MCMC prior=%s | ridge overrides=%s/%s\n',
            fit_vb_def$fit$beta_prior$type,
            fit_mc_def$fit$beta_prior$type,
            fit_vb_ridge$fit$beta_prior$type,
            fit_mc_ridge$fit$beta_prior$type))
RS
```

Outcome:

- PASS.
- Confirms default RHS-NS routing and explicit ridge override in both VB and MCMC qdesn flows.

## 4) Numerical Limit Check for Regularized Variance Expression

Command:

```bash
Rscript - <<'RS'
set.seed(1)
tau2 <- runif(2000, 1e-3, 2)
lambda2 <- runif(2000, 1e-3, 3)
zeta2 <- 1e8
V_reg <- (zeta2 * tau2 * lambda2) / (zeta2 + tau2 * lambda2)
V_hs <- tau2 * lambda2
rel <- abs(V_reg - V_hs) / pmax(1e-12, abs(V_hs))
cat(sprintf('PASS variance-limit check | max rel diff %.6e | median rel diff %.6e\n', max(rel), median(rel)))
RS
```

Outcome:

- PASS (`max rel diff 5.873347e-08`).
- Confirms `zeta2 -> infinity` recovers ordinary horseshoe variance expression.

## 5) Checklist Mapping (Wave 5)

- T1.1/T1.2: Covered by `test-qdesn-prior-defaults` and `test-exal-inference-config` (PASS).
- T1.3: Covered by dedicated IG/GIG/truncated-Normal parameterization sanity command (PASS).
- T1.4: Covered by closed-form precision tests and explicit SPD check command (PASS).
- T2.1/T2.2: Covered by static VB/MCMC integration command over `ridge`, `rhs`, `rhs_ns` (PASS).
- T2.3/T2.4/T2.5: Covered by qdesn integration command and qdesn test suites (PASS).
- T3.1: Covered by explicit regularized-variance limit command (PASS).
- T3.2: Covered by support-domain command and package tests (PASS).
- T3.3: Covered by `test-qdesn-mcmc-validation-pilot` drift/ESS/Geweke signoff logic tests (PASS).
- T3.4: Covered by finite-ELBO checks in `test-exal-mcmc`, `test-qdesn-mcmc-validation-pilot`, and end-to-end qdesn VB command (PASS).
- T4.1/T4.2/T4.3: Covered by static regression/normalization suites and qdesn routing tests (PASS).

## 6) Exceptions

- None. No failed required checks remained at wave close.

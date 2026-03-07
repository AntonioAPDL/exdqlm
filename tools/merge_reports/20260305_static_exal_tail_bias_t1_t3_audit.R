#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(devtools)
  library(numDeriv)
})

devtools::load_all(".", quiet = TRUE)

tau_lab <- function(tau) gsub("\\.", "p", format(as.numeric(tau), nsmall = 2))

run_root <- Sys.getenv(
  "EXDQLM_STATIC_AUDIT_RUN_ROOT",
  "results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_160734"
)
sim_path <- Sys.getenv(
  "EXDQLM_STATIC_AUDIT_SIM_PATH",
  "results/sim_suite_static/series/static_exal_rich1d_mcq/sim_output.rds"
)
out_dir <- Sys.getenv(
  "EXDQLM_STATIC_AUDIT_OUT_DIR",
  "results/sim_suite_static/audits/static_exal_tail_bias_t1_t3_20260305"
)

if (!dir.exists(run_root)) stop("Audit run root not found: ", run_root)
if (!file.exists(sim_path)) stop("Audit sim file not found: ", sim_path)

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- readRDS(file.path(run_root, "tables", "run_config.rds"))
sim <- readRDS(sim_path)
TT <- min(as.integer(cfg$TT)[1], length(sim$y))
y <- as.numeric(sim$y[seq_len(TT)])
X <- as.matrix(sim$extras$X[seq_len(TT), , drop = FALSE])

focus_taus <- c(0.05, 0.95)
a_sigma <- 1
b_sigma <- 1
log_prior_gamma <- function(g) 0

central_grad <- function(fn, x, h) {
  out <- numeric(length(x))
  for (j in seq_along(x)) {
    e <- rep(0, length(x))
    e[j] <- h
    out[j] <- (fn(x + e) - fn(x - e)) / (2 * h)
  }
  out
}

central_hessian <- function(fn, x, h) {
  p <- length(x)
  H <- matrix(NA_real_, p, p)
  fx <- fn(x)
  for (i in seq_len(p)) {
    ei <- rep(0, p)
    ei[i] <- h
    H[i, i] <- (fn(x + ei) - 2 * fx + fn(x - ei)) / (h * h)
  }
  if (p >= 2L) {
    for (i in seq_len(p - 1L)) {
      for (j in (i + 1L):p) {
        ei <- rep(0, p)
        ej <- rep(0, p)
        ei[i] <- h
        ej[j] <- h
        H[i, j] <- (fn(x + ei + ej) - fn(x + ei - ej) - fn(x - ei + ej) + fn(x - ei - ej)) / (4 * h * h)
        H[j, i] <- H[i, j]
      }
    }
  }
  H
}

build_ld_state <- function(fit, tau) {
  bounds <- fit$misc$bounds
  L <- as.numeric(bounds["L"])[1]
  U <- as.numeric(bounds["U"])[1]
  A_of <- function(g) A.fn(tau, g)
  B_of <- function(g) B.fn(tau, g)
  C_of <- function(g) C.fn(tau, g)
  lam_of <- function(g) C_of(g) * abs(g)
  g_from_eta <- function(eta) {
    s <- stats::plogis(eta)
    L + (U - L) * s
  }
  sig_from_ell <- function(ell) exp(ell)

  list(
    y = y,
    X = X,
    n = length(y),
    m_beta = fit$qbeta$m,
    V_beta = fit$qbeta$V,
    E_inv_v = fit$qv$E_inv_v,
    E_v = fit$qv$E_v,
    E_s = fit$qs$E_s,
    E_s2 = fit$qs$E_s2,
    a_sigma = a_sigma,
    b_sigma = b_sigma,
    L = L,
    U = U,
    A_of = A_of,
    B_of = B_of,
    lam_of = lam_of,
    g_from_eta = g_from_eta,
    sig_from_ell = sig_from_ell,
    log_prior_gamma = log_prior_gamma
  )
}

focus_metrics <- read.csv(file.path(run_root, "tables", "metrics_summary.csv"), stringsAsFactors = FALSE)
focus_pairwise <- read.csv(file.path(run_root, "tables", "pairwise_exal_vs_al.csv"), stringsAsFactors = FALSE)
focus_vb_conv <- read.csv(file.path(run_root, "tables", "vb_convergence_summary.csv"), stringsAsFactors = FALSE)
focus_ld_diag <- read.csv(file.path(run_root, "tables", "vb_ld_diagnostics_summary.csv"), stringsAsFactors = FALSE)
focus_mcmc_diag <- read.csv(file.path(run_root, "tables", "mcmc_diagnostics_summary.csv"), stringsAsFactors = FALSE)

focus_metrics <- focus_metrics[focus_metrics$tau %in% focus_taus, , drop = FALSE]
focus_pairwise <- focus_pairwise[focus_pairwise$tau %in% focus_taus, , drop = FALSE]
focus_vb_conv <- focus_vb_conv[focus_vb_conv$tau %in% focus_taus, , drop = FALSE]
focus_ld_diag <- focus_ld_diag[focus_ld_diag$tau %in% focus_taus & focus_ld_diag$model == "exal", , drop = FALSE]
focus_mcmc_diag <- focus_mcmc_diag[focus_mcmc_diag$tau %in% focus_taus, , drop = FALSE]

write.csv(focus_metrics, file.path(out_dir, "t1_focus_metrics_summary.csv"), row.names = FALSE)
write.csv(focus_pairwise, file.path(out_dir, "t1_focus_pairwise_exal_vs_al.csv"), row.names = FALSE)
write.csv(focus_vb_conv, file.path(out_dir, "t1_focus_vb_convergence_summary.csv"), row.names = FALSE)
write.csv(focus_ld_diag, file.path(out_dir, "t1_focus_vb_ld_diagnostics_summary.csv"), row.names = FALSE)
write.csv(focus_mcmc_diag, file.path(out_dir, "t1_focus_mcmc_diagnostics_summary.csv"), row.names = FALSE)

t2_discrepancy_log <- data.frame(
  issue_id = c("T2-01", "T2-02", "T2-03", "T2-04", "T2-05"),
  component = c(
    "Static exAL scope in theory doc",
    "Quantile-fixed GAL augmentation",
    "Gamma support and p(gamma,p0) map",
    "Gamma prior default",
    "Sigma prior parameterization"
  ),
  original_paper_status = c(
    "Explicit: quantile-fixed GAL / exAL hierarchy is given in Sections 2.2 and 3.1.",
    "Explicit: y | beta,gamma,sigma,v,s uses sigma*C*|gamma|*s + A*v and variance sigma*B*v after v=sigma*z reparameterization.",
    "Explicit: g(gamma), p(gamma,p0), C=[I(gamma>0)-p]^{-1}, and bounds (L,U) are defined.",
    "Explicit: rescaled Beta prior is suggested; uniform prior on bounded support is listed as the default choice.",
    "Explicit: inverse-gamma prior IG(a_sigma,b_sigma) is used for sigma."
  ),
  main_tex_status = c(
    "Missing: main.tex currently documents only AL / exAL with gamma=0.",
    "Missing for exAL: main.tex contains only the AL augmentation without s_i or gamma.",
    "Missing for exAL: no static exAL gamma support or p(gamma,p0) reparameterization appears in main.tex.",
    "Not documented for exAL because the static exAL section is absent.",
    "Consistent for AL special case: same IG kernel appears in main.tex."
  ),
  code_status = c(
    "Implemented in static exAL code, but undocumented in main.tex.",
    "Implemented via q(v), q(s), and LD q(sigma,gamma) blocks in exal_static_LDVB().",
    "Implemented in R/utils.R via log_g(), p.fn(), A.fn(), B.fn(), C.fn(), L.fn(), U.fn().",
    "Implemented as flat log_prior_gamma() by default, which is uniform over (L,U).",
    "Implemented as IG(a_sigma,b_sigma) with the same kernel."
  ),
  verdict = c("theory_doc_gap", "theory_doc_gap", "theory_doc_gap", "consistent", "consistent"),
  implication = c(
    "Static exAL VB cannot be fully audited against main.tex alone.",
    "The code currently has to be checked against the original paper rather than the repo theory note.",
    "Any future static exAL theory note must include these definitions before deeper debugging can be considered closed.",
    "No discrepancy found here.",
    "No discrepancy found here."
  ),
  stringsAsFactors = FALSE
)
write.csv(t2_discrepancy_log, file.path(out_dir, "t2_joint_discrepancy_log.csv"), row.names = FALSE)

t3_concordance <- data.frame(
  component = c(
    "A/B/C helper map",
    "q(beta) update",
    "q(v_i) update",
    "q(s_i) update",
    "LD log q(sigma,gamma)",
    "eta,ell transform Jacobian",
    "xi expectation updates",
    "LD optimizer derivatives"
  ),
  theory_reference = c(
    "Original paper eq. (2.5) and p(gamma,p0) reparameterization",
    "Expected quadratic completion under Gaussian likelihood and Normal prior",
    "Expected GIG update from augmented Gaussian + Exp(v|sigma)",
    "Expected truncated-Normal update from N+(0,1) prior and linear/quadratic s terms",
    "Expected log joint terms in sigma,gamma after taking expectations over beta,v,s",
    "Change of variables from (gamma,sigma) to (eta,ell)",
    "MC approximation to E[1/(B sigma)], E[lambda/B], E[lambda^2 sigma/B], etc.",
    "Numerical rather than analytic gradient/Hessian for the LD block"
  ),
  code_location = c(
    "R/utils.R: log_g(), p.fn(), A.fn(), B.fn(), C.fn(), L.fn(), U.fn()",
    "R/exal_static_LDVB.R: q(beta) block inside exal_static_LDVB()",
    "R/exal_static_LDVB.R: q(v_i) block inside exal_static_LDVB()",
    "R/exal_static_LDVB.R: q(s_i) block inside exal_static_LDVB()",
    "R/exal_static_LDVB.R: .exal_static_ld_log_qsiggam()",
    "R/exal_static_LDVB.R: .exal_static_ld_log_jacobian(), g_from_eta(), sig_from_ell()",
    "R/exal_static_LDVB.R: compute_xi() and xi damping",
    "R/exal_static_LDVB.R: optim(method=\"BFGS\") plus numDeriv::hessian() fallback"
  ),
  verdict = c(
    "consistent",
    "consistent",
    "consistent",
    "consistent",
    "consistent",
    "consistent",
    "intentional_approximation",
    "intentional_approximation"
  ),
  note = c(
    "Code formulas match the original paper's quantile-fixed GAL parameterization.",
    "No sign or scaling mismatch found in the beta linear/quadratic terms.",
    "The implemented chi/psi terms simplify to the expected augmented GIG form.",
    "The truncated-Normal mean/variance structure matches the augmented hierarchy.",
    "The LD objective matches the expected sigma/gamma-dependent joint terms up to constants.",
    "Jacobian includes both logit(gamma) and log(sigma) parts; no missing term found.",
    "This is the main approximation layer that can still bias tails even when convergence looks healthy.",
    "Absence of analytic derivatives is not a derivation bug, but it remains a numerical weak point."
  ),
  stringsAsFactors = FALSE
)
write.csv(t3_concordance, file.path(out_dir, "t3_vb_concordance.csv"), row.names = FALSE)

ld_log_qsiggam <- getFromNamespace(".exal_static_ld_log_qsiggam", "exdqlm")
derivative_rows <- vector("list", length(focus_taus))

for (i in seq_along(focus_taus)) {
  tau <- focus_taus[i]
  vb_path <- file.path(run_root, "fits", "vb", sprintf("vb_exal_tau_%s_fit.rds", tau_lab(tau)))
  vb_obj <- readRDS(vb_path)
  fit <- vb_obj$fit
  state <- build_ld_state(fit, tau)
  x0 <- c(as.numeric(fit$qsiggam$eta_hat), as.numeric(fit$qsiggam$ell_hat))
  fn <- function(z) ld_log_qsiggam(par = z, state = state, include_jacobian = TRUE)

  g_rich <- numDeriv::grad(func = fn, x = x0, method = "Richardson")
  H_rich <- numDeriv::hessian(func = fn, x = x0, method = "Richardson")
  g_h4 <- central_grad(fn, x0, h = 1e-4)
  g_h5 <- central_grad(fn, x0, h = 1e-5)
  H_h4 <- central_hessian(fn, x0, h = 1e-4)
  H_h5 <- central_hessian(fn, x0, h = 1e-5)

  neg_H_eig <- eigen(-H_rich, symmetric = TRUE, only.values = TRUE)$values
  derivative_rows[[i]] <- data.frame(
    tau = tau,
    objective = fn(x0),
    eta_hat = x0[1],
    ell_hat = x0[2],
    gamma_hat = fit$qsiggam$gamma_mean,
    sigma_hat = fit$qsiggam$sigma_mean,
    grad_eta_rich = g_rich[1],
    grad_ell_rich = g_rich[2],
    grad_inf_norm_rich = max(abs(g_rich)),
    grad_diff_rich_vs_h1e4 = max(abs(g_rich - g_h4)),
    grad_diff_h1e4_vs_h1e5 = max(abs(g_h4 - g_h5)),
    hess_diff_rich_vs_h1e4 = max(abs(H_rich - H_h4)),
    hess_diff_h1e4_vs_h1e5 = max(abs(H_h4 - H_h5)),
    neg_hess_eig_min = min(neg_H_eig),
    neg_hess_eig_max = max(neg_H_eig),
    neg_hess_condition = max(neg_H_eig) / min(neg_H_eig),
    local_mode_pass = all(is.finite(neg_H_eig)) && all(neg_H_eig > 0),
    stringsAsFactors = FALSE
  )
}

derivative_df <- do.call(rbind, derivative_rows)
write.csv(derivative_df, file.path(out_dir, "t3_ld_derivative_check.csv"), row.names = FALSE)

cat("Audit artifacts written to:", out_dir, "\n")

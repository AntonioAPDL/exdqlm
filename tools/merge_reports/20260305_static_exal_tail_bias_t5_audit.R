#!/usr/bin/env Rscript

out_dir <- Sys.getenv(
  "EXDQLM_STATIC_AUDIT_T5_OUT_DIR",
  "results/sim_suite_static/audits/static_exal_tail_bias_t5_20260305"
)

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

concordance <- data.frame(
  component_id = c(
    "C01", "C02", "C03", "C04", "C05", "C06",
    "C07", "C08", "C09", "C10", "C11", "C12", "C13"
  ),
  component = c(
    "Gamma support and quantile-fixed reparameterization",
    "VB eta/ell transform Jacobian",
    "VB LD log q(sigma,gamma)",
    "VB q(beta) update",
    "VB q(v) family update",
    "VB q(s) family update",
    "VB xi expectation approximation",
    "VB LD mode/covariance approximation",
    "MCMC exact Gibbs blocks",
    "MCMC gamma exact MH kernels",
    "MCMC gamma laplace_local kernel",
    "VB-to-MCMC warm-start transport",
    "Normalization and signoff diagnostics extraction"
  ),
  theory_reference = c(
    "Original paper eq. (2.4)-(2.5), gamma support paragraph in Section 2.2",
    "Change of variables implied by bounded gamma support and sigma>0",
    "Original paper Section 3.1 hierarchy integrated against mean-field expectations",
    "Original paper Section 3.1 Step 1 plus mean-field completion",
    "Original paper Section 3.1 Step 2 plus mean-field replacement of exact sufficient statistics",
    "Original paper Section 3.1 Step 3 plus mean-field replacement of exact sufficient statistics",
    "No closed-form paper equation; implementation-specific approximation layer",
    "No closed-form paper equation; implementation-specific Laplace-Delta approximation",
    "Original paper Section 3.1 Steps 1-4",
    "Original paper allows exact slice/MH updates for gamma",
    "Not part of the original exact posterior sampler",
    "Not a theory object; implementation bridge between audited VB and MCMC code",
    "Not a theory object; reporting/signoff helper layer"
  ),
  code_reference = c(
    "R/utils.R:2-8; R/utils.R:19-49",
    "R/exal_static_LDVB.R:2-5; R/exal_static_LDVB.R:321-322",
    "R/exal_static_LDVB.R:8-40; R/exal_static_LDVB.R:451-477",
    "R/exal_static_LDVB.R:570-586",
    "R/exal_static_LDVB.R:588-603",
    "R/exal_static_LDVB.R:605-608",
    "R/exal_static_LDVB.R:398-449; R/exal_static_LDVB.R:634-642",
    "R/exal_static_LDVB.R:480-536; R/exal_static_LDVB.R:610-632",
    "R/exal_static_mcmc.R:443-479",
    "R/exal_static_mcmc.R:332-351; R/exal_static_mcmc.R:423-535",
    "R/exal_static_mcmc.R:489-497",
    "R/static_fit_normalization.R:3-29; R/exal_static_mcmc.R:141-181",
    "R/static_fit_normalization.R:31-145; tools/merge_reports/20260305_static_vb_mcmc_report.R:238-293; tools/merge_reports/20260305_static_vb_then_mcmc_pipeline.R:229-243"
  ),
  constants_handling = c(
    "Exact mapping; no constants omitted",
    "Exact Jacobian term retained",
    "Target kernel in eta,ell is up to additive constants independent of sigma,gamma",
    "Normalizing constants absorbed into Gaussian update",
    "Uses exact GIG moment formulas once xi inputs are fixed",
    "Uses exact truncated-Normal moments once xi inputs are fixed",
    "Monte Carlo expectations replace exact integrals over q(sigma,gamma)",
    "Local Gaussian approximation replaces exact q(sigma,gamma)",
    "Exact full conditional kernels up to normalizing constants",
    "Exact conditional target with MH correction",
    "No MH correction; approximate local Gaussian draw only",
    "No constants issue; transport helper only",
    "No constants issue; helper layer only"
  ),
  implementation_class = c(
    "exact",
    "exact",
    "exact_up_to_constant",
    "exact_given_xi",
    "exact_given_xi",
    "exact_given_xi",
    "approximate",
    "approximate",
    "exact",
    "exact",
    "approximate",
    "exact_helper",
    "diagnostic_helper"
  ),
  audit_verdict = c(
    "consistent",
    "consistent",
    "consistent",
    "consistent",
    "consistent",
    "consistent",
    "intentional_approximation",
    "intentional_approximation",
    "consistent",
    "consistent_when_using_rw_or_laplace_rw",
    "not_exact_posterior_kernel",
    "consistent",
    "needs_signoff_flag"
  ),
  patch_item_id = c(
    "P1", "P1", NA, NA, NA, NA, "P3", "P4", NA, "P2", "P2", NA, "P2"
  ),
  note = c(
    "Theory source exists in exAL_Original.pdf but is missing from local main.tex.",
    "No missing Jacobian term found in audited VB code.",
    "No sign/scaling mismatch found in the LD target itself.",
    "No algebraic mismatch found in beta update.",
    "No algebraic mismatch found in q(v) family update.",
    "No algebraic mismatch found in q(s) family update.",
    "Main unresolved VB risk: xi MC layer can bias tails even under apparent convergence.",
    "Main unresolved VB risk: LD local Gaussian approximation may be too crude in tail regimes.",
    "Static MCMC exact Gibbs blocks agree with the original paper hierarchy.",
    "Frozen rich static run uses rw, so its gamma kernel is exact.",
    "This branch should not be used for signoff or posterior-valid comparisons.",
    "Warm starts move audited VB states into MCMC correctly.",
    "Current reporting does not expose whether a run used an exact or approximate gamma kernel."
  ),
  stringsAsFactors = FALSE
)

patch_list <- data.frame(
  patch_item_id = c("P1", "P2", "P3", "P4"),
  priority = c("high", "high", "high", "medium"),
  title = c(
    "Add static exAL derivation to theory repo main.tex",
    "Add exact-kernel signoff guard for static exAL MCMC gamma updates",
    "Add deterministic/replicated xi-evaluation mode for static LDVB",
    "Add LD mode-quality diagnostics to normalized outputs and reports"
  ),
  rationale = c(
    "T2 showed that main.tex currently lacks the static quantile-fixed exAL/GAL derivation, so local theory-to-code review cannot close cleanly without this bridge.",
    "T4 showed that rw/laplace_rw are exact but laplace_local is not. Current reporting and gates do not surface this distinction.",
    "T3 did not find an algebraic bug, leaving the xi Monte Carlo layer as the strongest unresolved VB approximation risk.",
    "T3 derivative checks were informative but external; the fit/report stack should record this information directly for future runs."
  ),
  expected_effect = c(
    "Align local theory documentation with implemented static exAL code and remove the current theory-doc gap.",
    "Prevent approximate gamma kernels from being treated as signoff-equivalent to exact MCMC runs.",
    "Make the VB tail-bias diagnosis falsifiable by separating xi-MC noise from true model/approximation bias.",
    "Expose whether a saved LDVB fit reached a numerically credible local mode or only a damped plateau."
  ),
  files_to_update = c(
    "/data/muscat_data/jaguir26/DQLM-and-BQR---Theory/main.tex",
    "R/exal_static_mcmc.R; R/static_fit_normalization.R; tools/merge_reports/20260305_static_vb_mcmc_report.R; tools/merge_reports/20260305_static_vb_then_mcmc_pipeline.R; tools/merge_reports/20260305_resume_static_mcmc_from_vb.R",
    "R/exal_static_LDVB.R; tools/merge_reports/20260305_static_vb_then_mcmc_pipeline.R; tools/merge_reports/20260305_static_postprocess_from_existing_fits.R",
    "R/exal_static_LDVB.R; R/static_fit_normalization.R; tools/merge_reports/20260305_static_postprocess_from_existing_fits.R; tools/merge_reports/20260305_static_vb_mcmc_report.R"
  ),
  test_requirements = c(
    "Build/check theory PDF in the theory repo; no code test in this repo.",
    "Add regression test that normalized/report outputs expose gamma-kernel exactness and gate approximate kernels as non-signoff-ready.",
    "Add deterministic repeatability test for xi mode and a smoke comparison on a benign static exAL case.",
    "Add regression test that LD derivative/curvature diagnostics are emitted and survive normalization/postprocess."
  ),
  status = c("open", "open", "open", "open"),
  stringsAsFactors = FALSE
)

write.csv(concordance, file.path(out_dir, "t5_theory_code_concordance.csv"), row.names = FALSE)
write.csv(patch_list, file.path(out_dir, "t5_patch_list.csv"), row.names = FALSE)

cat("T5 audit artifacts written to:", out_dir, "\n")

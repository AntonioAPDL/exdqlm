# Static exAL Tail-Bias Audit (`T1-T3`)

## Scope

This note records the first three steps of the static `exAL` tail-bias audit:

- `T1`: freeze the empirical symptom on a fixed run/artifact basis
- `T2`: compare the original `exAL` / GAL source material against the theory repo
- `T3`: cross-check the static `exAL` VB/CAVI implementation against the audited hierarchy and run a frozen LD objective derivative check

Audit basis:

- code repo:
  - `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp`
  - branch: `jaguir26/dqlm-conjugacy-cavi-gibbs`
  - commit at audit time: `b9e16b596a1212c064b1befb07268535d22aed61`
- theory repo:
  - `/data/muscat_data/jaguir26/DQLM-and-BQR---Theory`
  - commit at audit time: `f31ce5df757ad78647c1015a3ed6a875a0402bc5`
- frozen empirical review run:
  - `results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_160734`
- generated audit artifacts:
  - `results/sim_suite_static/audits/static_exal_tail_bias_t1_t3_20260305/`

## T1. Frozen Empirical Symptom

Primary evidence plots:

- `results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_160734/plots/fit_within_inference/vb_tau_0p05_al_vs_exal_full.png`
- `results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_160734/plots/fit_within_inference/vb_tau_0p95_al_vs_exal_full.png`
- `results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_160734/plots/fit_between_inference/exal_tau_0p05_vb_vs_mcmc_full.png`
- `results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_160734/plots/fit_between_inference/exal_tau_0p95_vb_vs_mcmc_full.png`
- `results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_160734/plots/traces/vb_tau_0p05_elbo_trace.png`
- `results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_160734/plots/traces/vb_tau_0p95_gamma_trace_exal.png`

Frozen symptom summary:

| Tau | Method | exAL RMSE | AL RMSE | exAL minus AL | exAL coverage | AL coverage |
|---|---:|---:|---:|---:|---:|---:|
| `0.05` | `VB` | `5.7776` | `1.0284` | `+4.7492` | `0.0000` | `0.3104` |
| `0.05` | `MCMC` | `4.8509` | `1.0755` | `+3.7754` | `0.0000` | `0.4462` |
| `0.95` | `VB` | `1.9728` | `0.3775` | `+1.5953` | `0.0000` | `0.1048` |
| `0.95` | `MCMC` | `1.1912` | `0.4224` | `+0.7688` | `0.0000` | `0.4336` |

Frozen VB convergence summary:

| Tau | VB iter | Stop reason | `delta_state_last` | `delta_sigma_last` | `delta_gamma_last` |
|---|---:|---|---:|---:|---:|
| `0.05` | `453` | `joint_converged` | `2.44e-09` | `8.41e-11` | `1.52e-11` |
| `0.95` | `498` | `joint_converged` | `1.34e-09` | `5.08e-10` | `1.47e-10` |

Frozen LD and MCMC diagnostics:

| Tau | `ld_cov_condition_last` | `ld_xi_rel_drift_last` | `accept_rate_keep` | `ESS_sigma` | `ESS_gamma` |
|---|---:|---:|---:|---:|---:|
| `0.05` | `2.8618` | `1.36e-10` | `0.028` | `15.36` | `2.05` |
| `0.95` | `1.7017` | `1.14e-09` | `0.041` | `54.22` | `3.69` |

Interpretation:

- the empirical problem is real and fixed on this run:
  - `exAL` is materially worse than `AL` at the two tail quantiles in both `VB` and `MCMC`
- the `VB` tail fits do **not** look like simple unconverged failures:
  - stop reason is `joint_converged`
  - final delta metrics are extremely small
  - LD covariance condition numbers are mild, not explosive
- `MCMC` still mixes poorly on `gamma`, but the fact that both `VB` and `MCMC` are shifted in the same direction means the issue is unlikely to be explained by `VB` convergence bookkeeping alone

Artifact files written for `T1`:

- `results/sim_suite_static/audits/static_exal_tail_bias_t1_t3_20260305/t1_focus_metrics_summary.csv`
- `results/sim_suite_static/audits/static_exal_tail_bias_t1_t3_20260305/t1_focus_pairwise_exal_vs_al.csv`
- `results/sim_suite_static/audits/static_exal_tail_bias_t1_t3_20260305/t1_focus_vb_convergence_summary.csv`
- `results/sim_suite_static/audits/static_exal_tail_bias_t1_t3_20260305/t1_focus_vb_ld_diagnostics_summary.csv`
- `results/sim_suite_static/audits/static_exal_tail_bias_t1_t3_20260305/t1_focus_mcmc_diagnostics_summary.csv`

## T2. Original Paper vs `main.tex`

Primary conclusion:

- `main.tex` does **not** currently provide a static `exAL` derivation to audit against.
- It only covers `AL` / `exAL with gamma = 0`.
- Therefore the correct source of record for the static extended model is currently `exAL_Original.pdf`, not `main.tex`.

Key discrepancy log:

| Issue | Original paper | `main.tex` | Code | Verdict |
|---|---|---|---|---|
| Static `exAL` scope | explicit | missing | implemented | `theory_doc_gap` |
| Quantile-fixed GAL augmentation | explicit | missing | implemented | `theory_doc_gap` |
| `g(gamma)`, `p(gamma,p0)`, `C(gamma)`, `(L,U)` | explicit | missing | implemented in `R/utils.R` | `theory_doc_gap` |
| Uniform default prior on `gamma` | explicit as allowable default | absent for exAL | implemented | `consistent` |
| IG prior on `sigma` | explicit | present for AL case | implemented | `consistent` |

Interpretation:

- the first theory problem is not yet a sign error in code; it is that the local theory repo does not yet contain the static `exAL` bridge needed to audit the implementation from repo-local derivations
- this means future static `exAL` corrections should update the theory repo in parallel with code

Artifact file written for `T2`:

- `results/sim_suite_static/audits/static_exal_tail_bias_t1_t3_20260305/t2_joint_discrepancy_log.csv`

## T3. Static `exAL` VB/CAVI Audit

Equation-to-code concordance summary:

| Component | Verdict | Comment |
|---|---|---|
| `A/B/C` helper map | `consistent` | `R/utils.R` matches the original paper's quantile-fixed GAL parameterization |
| `q(beta)` | `consistent` | no sign or scaling mismatch found in the linear/quadratic beta terms |
| `q(v_i)` | `consistent` | implemented `chi/psi` reduce to the expected GIG form |
| `q(s_i)` | `consistent` | implemented truncated-Normal update matches the augmented hierarchy |
| `LD log q(sigma,gamma)` | `consistent` | sigma/gamma-dependent joint terms match the expected expansion up to constants |
| `(eta, ell)` Jacobian | `consistent` | no missing logit/log-sigma term found |
| `xi` expectations | `intentional_approximation` | MC approximation + damping is a real approximation layer |
| LD optimizer derivatives | `intentional_approximation` | no analytic gradient/Hessian are coded; optimizer relies on numeric derivatives |

Frozen derivative check on the LD objective:

| Tau | `grad_inf_norm_rich` | `neg_hess_eig_min` | `neg_hess_condition` | `local_mode_pass` |
|---|---:|---:|---:|---|
| `0.05` | `2.62e-03` | `5401.91` | `2.8618` | `TRUE` |
| `0.95` | `9.63e-04` | `5799.55` | `1.7017` | `TRUE` |

Interpretation of the derivative check:

- the frozen tail LD objective is numerically close to stationary at the saved `VB` tail fits
- the local curvature check is consistent with a proper local mode in both tail cases
- this reduces the probability that the observed tail bias is caused by the LD optimizer simply failing to reach a stationary point
- however, two approximation layers remain important:
  - `q(sigma,gamma)` is still a Laplace-Delta approximation
  - the `xi` expectations are still Monte Carlo approximated and damped

Current `T3` bottom line:

- no obvious algebraic sign/scaling bug was found in the static `exAL` `VB` updates during `T1-T3`
- the strongest concrete issue uncovered so far is the missing static `exAL` theory bridge in `main.tex`
- the strongest unresolved implementation risk is not a blatant closed-form mismatch; it is the quality of the `LD + xi-MC` approximation layer

Artifact files written for `T3`:

- `results/sim_suite_static/audits/static_exal_tail_bias_t1_t3_20260305/t3_vb_concordance.csv`
- `results/sim_suite_static/audits/static_exal_tail_bias_t1_t3_20260305/t3_ld_derivative_check.csv`

## Decision After `T1-T3`

What `T1-T3` rules out:

- a simple `VB` tail failure caused by obviously non-converged ELBO/state traces
- an immediately visible sign error in the core `q(beta)`, `q(v)`, `q(s)`, or LD objective terms
- a missing Jacobian term in the `(eta, ell)` transform

What remains open:

- `T4`: verify that the static `MCMC` code targets the same audited posterior object as the `VB` code
- extend the theory repo so `main.tex` contains a proper static `exAL` derivation rather than only the `gamma=0` special case
- if `VB` and `MCMC` are confirmed to target the same posterior, then the remaining issue is likely one of:
  - a shared posterior-target implementation issue outside the `T1-T3` scope
  - approximation quality in the `VB` LD block
  - genuine model misfit for the current static simulated DGP

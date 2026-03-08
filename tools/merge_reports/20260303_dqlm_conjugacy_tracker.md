# DQLM/AL Implementation Tracker (Static + Dynamic, MCMC + VB-CAVI)

## Document Control

- Status: Reduced-model + convergence-hardening implementation completed; latest full dynamic and static TT=5000 reruns plus figure/postprocess stages are completed. Final signoff is still open because the extended models (`exDQLM`, `exAL`) remain the dominant source of residual VB and MCMC issues, especially at `tau=0.05` and `tau=0.95`.
- Active implementation branch: `jaguir26/dqlm-conjugacy-cavi-gibbs`
- Baseline source branch for parity: `cransub/0.4.0` at `e18710a`
- Date: 2026-03-05
- Package repo: `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp`

## Primary Goal

Extend current package algorithms to support non-extended AL quantile regression (DQLM/BQR) in both static and dynamic settings, with mathematically correct Gibbs and VB-CAVI updates and robust tests.

Critical model restriction for this tracker:

- AL model is exAL with `gamma = 0`.
- Reduced latent structure is `state or beta`, `sigma`, and `v_t` only.
- There is no gamma inference block and no `s_t` block.

## Project Constraints (As Requested)

1. Do not create a parallel new algorithm stack by default.
2. Prefer extending current package files and code paths.
3. Add helper utilities only where necessary (prefer existing `R/utils.R` patterns).
4. Add C++ only if existing R/C++ wiring cannot be reused cleanly.
5. No superficial solutions (for example, just setting `gamma=0` inside exDQLM formulas while still keeping full exDQLM latent blocks).

## Theory Source of Truth (New)

Cloned repository:

- `/data/muscat_data/jaguir26/DQLM-and-BQR---Theory`

Primary document:

- `/data/muscat_data/jaguir26/DQLM-and-BQR---Theory/main.tex`

Key covered theory blocks in that document:

- Static BQR (AL) full posterior, Gibbs, CAVI, ELBO.
- Dynamic DQLM (AL) full posterior, FFBS Gibbs, CAVI with variational Kalman smoother, ELBO.

Additional consistency references:

- `/data/muscat_data/jaguir26/univ-exDQLM---Ensemble/main.tex`
- `/data/muscat_data/jaguir26/Static-exAL-Regression---MCMC/main.tex`
- `/data/muscat_data/jaguir26/Static-exAL-Regression---VB/main.tex`

## Canonical Reduced-AL Formulas to Implement

Let

- `A = (1 - 2 p0) / (p0 (1 - p0))`
- `B = 2 / (p0 (1 - p0))`

### Static BQR Gibbs

Model:

- `y_t | beta, sigma, v_t ~ N(x_t^T beta + A v_t, sigma B v_t)`
- `v_t | sigma ~ Exp(rate = 1/sigma)`
- `sigma ~ IG(a0, b0)`

Full conditionals:

- `beta | sigma, v, y` is Normal.
- `sigma | beta, v, y ~ IG(a0 + 3n/2, b0 + sum(v_t) + sum((y_t - x_t^T beta - A v_t)^2 / (2 B v_t)))`.
- `v_t | beta, sigma, y_t ~ GIG(1/2, chi_t, psi)` where
  - `chi_t = (y_t - x_t^T beta)^2 / (sigma B)`
  - `psi = A^2/(sigma B) + 2/sigma`.

### Dynamic DQLM Gibbs

Model:

- `y_t | alpha_t, sigma, v_t ~ N(F_t^T alpha_t + A v_t, sigma B v_t)`
- state evolution `alpha_t | alpha_{t-1}` Gaussian.

Full conditionals:

- `alpha_{0:T} | sigma, v, y` by FFBS using pseudo-data
  - `y_t_tilde = y_t - A v_t`
  - `R_t = sigma B v_t`.
- `sigma | alpha_{0:T}, v, y` same IG form with `eta_t = F_t^T alpha_t`.
- `v_t | alpha_t, sigma, y_t` same GIG form with `r_t = y_t - F_t^T alpha_t`.

### Static VB-CAVI

Factorization:

- `q(beta) q(sigma) prod_t q(v_t)`.

Closed-form updates:

- `q(beta)` Normal with weighted least squares structure.
- `q(v_t) = GIG(1/2, chi_t, psi)` using
  - `chi_t = (kappa/B) E[(y_t - x_t^T beta)^2]`
  - `psi = kappa (2 + A^2/B)`
  - `kappa = E[1/sigma] = a_sigma / b_sigma`.
- `q(sigma) = IG(a_sigma, b_sigma)` with
  - `a_sigma = a0 + 3n/2`
  - `b_sigma = b0 + sum(nu_t) + (1/(2B)) sum( ell_t E[r_t^2] - 2A E[r_t] + A^2 nu_t )`.

### Dynamic VB-CAVI

Factorization:

- `q(alpha_{0:T}) q(sigma) prod_t q(v_t)`.

Closed-form updates:

- `q(alpha_{0:T})` via variational Kalman smoothing with
  - pseudo-observation `y_t_star = y_t - A / ell_t`
  - observation variance `R_t_star = B / (kappa ell_t)`.
- `q(v_t)` and `q(sigma)` have the same structural forms as static, replacing residual moments with dynamic smoothed moments.

## Equation-to-Code Map (Locked)

| Theory block | Implemented in code | Notes |
|---|---|---|
| Dynamic reduced CAVI core (`q(alpha) q(sigma) prod q(v)`) | `R/utils.R` in `.run_dynamic_dqlm_cavi()` | Shared by `exdqlmISVB()` and `exdqlmLDVB()` when `dqlm.ind=TRUE`. |
| Dynamic pseudo-observation update (`y_t^*`, `R_t^*`) | `R/utils.R` in `.run_dynamic_dqlm_cavi()` | Uses `ex.f = A / E[v^{-1}]` and `ex.q = B / (kappa E[v^{-1}])`. |
| Dynamic `q(v_t)` GIG (`lambda=1/2`) | `R/utils.R` in `.run_dynamic_dqlm_cavi()` | Closed-form moments with stable `E[log v_t]`. |
| Dynamic `q(sigma)` IG update | `R/utils.R` in `.run_dynamic_dqlm_cavi()` | Matches reduced AL derivation (`a0 + 3T/2`, expected-rate term). |
| Static reduced Gibbs (`beta`, `sigma`, `v`) | `R/exal_static_mcmc.R` in `if (dqlm.ind)` branch | No gamma or `s` latent block in reduced branch. |
| Static reduced CAVI (`q(beta) q(sigma) prod q(v)`) | `R/utils.R` in `.run_static_dqlm_cavi()` and `R/exal_static_LDVB.R` dispatch | No Laplace-Delta block in reduced branch. |
| `dqlm.int`/`dqlm.ind` propagation fix | `R/exdqlmISVB.R`, `R/exdqlmLDVB.R`, `R/exdqlmMCMC.R` | Coercion now flows into active branching logic. |
| Dynamic wrapper dispatch | `R/exdqlmISVB.R`, `R/exdqlmLDVB.R` | Both wrappers route reduced mode to shared conjugate core. |

## ELBO Requirements (High Priority)

This is the highest-risk part and must be validated term-by-term.

For both static and dynamic reduced-AL VB:

1. ELBO decomposition must match reduced factorization:
   - static: beta + sigma + v blocks.
   - dynamic: alpha + sigma + v blocks.
2. No gamma/Jacobian/Laplace terms.
3. No `s_t` prior/likelihood/entropy terms.
4. IG entropy and prior terms must match package parameterization
   - `p(sigma) propto sigma^{-(a+1)} exp(-b/sigma)`.
5. GIG entropy uses exact expression for `lambda=1/2` and stable handling of `E[log v_t]`.
6. Add ELBO component diagnostics (not only total ELBO) in tests.

## Current Package Baseline Audit (Before Implementation)

### What is already aligned

- Dynamic MCMC has a dedicated DQLM path in `R/exdqlmMCMC.R` with no `s_t` update and IG sigma update (conceptually aligned).
- FFBS infrastructure already exists and is reusable.

### Critical incongruencies found

1. `check_logics` coercion is not fully propagated in core functions.
   - In `R/exdqlmMCMC.R`, `R/exdqlmISVB.R`, `R/exdqlmLDVB.R`, code assigns `dqlm.int = rv$dqlm.ind` but later logic uses `dqlm.ind`.
   - This can bypass intended coercion behavior from `check_logics`.
2. Static algorithms currently remain exAL-oriented.
   - `R/exal_static_mcmc.R` and `R/exal_static_LDVB.R` do not currently expose a reduced-model DQLM branch in this clean baseline.
3. Dynamic VB implementations remain exDQLM-oriented.
   - `R/exdqlmISVB.R` and `R/exdqlmLDVB.R` still keep gamma/s_t-centered structures and ELBO terms.
4. Return-object semantics are mixed between exDQLM and DQLM modes and need formal reduced-model contract.

These are not implementation blockers; they are expected targets for phased fixes.

## Phase-by-Phase Implementation Plan

### Phase 0: Theory Lock + Equation Mapping

Deliverables:

- map each formula in `DQLM-and-BQR---Theory/main.tex` to concrete package code blocks.
- freeze parameterization conventions (`IG`, `GIG`, residual definitions).

Checklist:

- [x] equation map table added in this tracker.
- [x] all symbols mapped to current variable names (`a_tau`, `b_tau`, `Ut`, etc.).
- [x] ELBO term dictionary locked.

### Phase 1: Baseline Hygiene and Control Path Fixes

Target files:

- `R/exdqlmMCMC.R`
- `R/exdqlmISVB.R`
- `R/exdqlmLDVB.R`
- `R/utils.R`

Checklist:

- [x] fix `dqlm.int` vs `dqlm.ind` propagation.
- [x] enforce deterministic DQLM mode contract at entry points.
- [x] add unit tests for logic coercion.

### Phase 2: Static MCMC Reduced-AL Branch

Target file:

- `R/exal_static_mcmc.R`

Checklist:

- [x] add explicit DQLM branch (`no gamma`, `no s`).
- [x] implement static Gibbs updates exactly as theory.
- [x] preserve existing exAL path unchanged.

### Phase 3: Static VB-CAVI Reduced-AL Branch

Target file:

- `R/exal_static_LDVB.R` (or refactor naming while keeping file continuity)

Checklist:

- [x] add reduced factorization `q(beta) q(sigma) prod q(v)`.
- [x] implement static closed-form CAVI updates from theory.
- [x] implement static ELBO decomposition for reduced model.
- [x] keep exAL branch intact.

### Phase 4: Dynamic MCMC Validation + Consolidation

Target file:

- `R/exdqlmMCMC.R`

Checklist:

- [x] verify exact formula parity against new theory for DQLM path.
- [x] add targeted tests on sigma IG parameters and v GIG parameters.
- [x] verify FFBS interfaces remain unchanged for downstream callers.

### Phase 5: Dynamic VB-CAVI Reduced-AL Branch

Target files:

- `R/exdqlmISVB.R`
- `R/exdqlmLDVB.R`

Checklist:

- [x] implement reduced DQLM CAVI (no gamma, no s) aligned with theory.
- [x] decide whether to keep both ISVB/LDVB wrappers or centralize reduced CAVI core and reuse from both.
- [x] implement variational pseudo-observation Kalman smoother update (`y_star`, `R_star`).

### Phase 6: ELBO Hardening and Diagnostics

Target files:

- VB files above + tests

Checklist:

- [ ] ELBO term-by-term tests (static and dynamic).
- [x] numerical stability checks for GIG moments and `E[log v]`.
- [x] convergence checks based on ELBO + parameter deltas.

### Phase 7: Wiring, Documentation, and Final Gates

Target files:

- `man/*.Rd` for modified functions
- `tests/testthat/*`
- this tracker

Checklist:

- [x] update function docs for reduced DQLM behavior.
- [x] ensure outputs are consistent and backward-compatible.
- [x] full `devtools::test()` pass.

### Phase 8: exDQLM Convergence and Mixing Triage (New)

Problem observed in current validation outputs:

- exDQLM MCMC gamma traces show poor mixing / apparent non-convergence.
- exDQLM VB gamma and sigma can plateau with ELBO still acceptable but parameter traces not stabilized enough.
- Current stopping and tuning are not yet enforcing convergence quality needed for fair VB vs MCMC runtime comparison.

Target files:

- `R/exdqlmLDVB.R`
- `R/exdqlmISVB.R`
- `R/exdqlmMCMC.R`
- `R/utils.R`
- `tests/testthat/*`

Checklist:

- [x] create explicit convergence diagnostic summary object for dynamic and static exDQLM fits (ELBO, gamma, sigma, stop reason).
- [x] add quantitative MCMC diagnostics in outputs (acceptance for MH blocks, ESS, optional R-hat-ready chain summaries).
- [ ] define and lock acceptance criteria for "converged enough to compare speeds".

### Phase 9: VB Stop-Rule Upgrade (Dynamic + Static exDQLM)

Goal: stop only when ELBO and key parameters are jointly stable.

Checklist:

- [x] replace ELBO-only stopping with joint criteria:
  - ELBO increment tolerance met.
  - gamma delta tolerance met (exDQLM only).
  - sigma delta tolerance met.
- [x] add `min_iter` + consecutive-iterations guard (`patience`) to avoid premature stopping.
- [x] ensure DQLM branch automatically disables gamma criterion (no gamma parameter).
- [x] expose tolerances/options with backward-compatible defaults and document them.
- [x] add tests where ELBO converges but gamma does not, ensuring algorithm continues.

### Phase 10: MCMC exDQLM Mixing Hardening

Goal: improve gamma/sigma mixing while preserving target posterior and backward compatibility.

Checklist:

- [x] implement robust MH tuning controls for gamma/sigma block (burn-in adaptation window, target acceptance band, bounds on proposal scale).
- [x] store adaptation history and final tuned proposal covariance in fit output.
- [x] add multi-chain validation helper for diagnostics-only runs (no API break for single-chain production path).
- [x] add tests confirming proposal tuning behaves as expected and does not break existing interfaces.

### Phase 11: VB Warm-Start for MCMC + Optional Laplace Proposal

Goal: improve initial state for MCMC and evaluate whether Laplace proposal is needed.

Checklist:

- [x] add optional pre-initialization mode: run VB first and seed MCMC (`theta`, `sigma`, `gamma`) from converged VB moments/MAP.
- [x] add explicit user controls: `init.from.vb`, `vb_init_controls`, and clear fallback behavior if VB init fails.
- [ ] evaluate two MH proposal strategies on the same synthetic cases:
  - tuned random-walk MH (baseline).
  - Laplace-based independence proposal (optional experimental path).
- [x] keep default path conservative: Laplace proposal only promoted to default if diagnostics clearly improve without regressions.

### Phase 12: Refit Protocol and Final Comparison Gates

Refits to run after phases 8-11 implementation and tests:

- exDQLM VB: `tau in {0.05, 0.50, 0.95}`.
- exDQLM MCMC: `tau in {0.05, 0.50, 0.95}` with increased iterations and tuned/warm-started initialization.
- regenerate all comparison figures and metrics tables.

Readiness checklist (must pass before accepting refits):

- [x] VB convergence summary indicates joint ELBO/gamma/sigma stability for all taus.
- [ ] MCMC diagnostics show acceptable mixing for gamma and sigma (no persistent pathological traces).
- [x] updated figures clearly show uncertainty bands and overlap behavior.
- [x] tests pass (`devtools::test()`), including new convergence and tuning tests.
- [x] tracker updated with final settings used for reproducible refits.

## Branching and Clean-Base Protocol for This New Scope

Checklist:

- [ ] ensure `cransub/0.4.0` is clean and fully synced before starting this convergence-hardening scope.
- [ ] create dedicated feature branch from clean base (suggested: `jaguir26/exdqlm-convergence-hardening`).
- [ ] if any temporary/patchy commits must be dropped, record exact commit hash and revert command in this tracker before coding.
- [ ] implement phase-by-phase commits so each phase can be reviewed and bisected independently.

## File Strategy (No Unnecessary New Files)

Default strategy:

- extend current algorithm files in place.
- shared helper math can go into existing utility modules if repetition grows.

Optional only-if-needed strategy:

- add new C++ FFBS/VB kernels only if existing R/C++ cannot provide correct or maintainable behavior.
- no speculative C++ expansion before correctness is established in tests.

## Test Matrix (Planned)

1. Logic tests
- [x] `dqlm.ind` coercion works identically in MCMC/ISVB/LDVB.

2. Static Gibbs tests
- [x] conditional parameter checks for `sigma` IG and `v` GIG.
- [x] gamma/s blocks absent in DQLM branch.

3. Dynamic Gibbs tests
- [x] FFBS + IG + GIG updates produce finite stable chains.

4. Static CAVI tests
- [x] closed-form update identities hold.
- [x] ELBO terms finite and consistent.

5. Dynamic CAVI tests
- [x] `y_star` and `R_star` pseudo-model produces valid Kalman updates.
- [ ] ELBO component checks pass.

6. Regression tests
- [x] exDQLM legacy paths unaffected.

## Open Issues to Track Explicitly

- [x] Decide reduced-DQLM output schema naming across `ISVB` and `LDVB` wrappers.
- [x] Decide whether dynamic reduced CAVI should live in one shared internal core called by both public functions.
- [ ] Validate whether any existing C++ helper can be safely reused for reduced CAVI state-update path without weakening ELBO diagnostics.
- [ ] Define final default MH strategy for exDQLM gamma/sigma (`tuned RW` vs `Laplace proposal`) after benchmark diagnostics.
- [ ] Lock final VB joint-stop default tolerances that work in both static and dynamic exDQLM.
- [x] Finalize VB warm-start contract for MCMC without breaking backward compatibility.

## Incongruency Log (to update during implementation)

- I1: `dqlm.int` assignment typo not propagated to `dqlm.ind` logic branches. Resolved.
- I2: Static routines currently exAL-first; reduced DQLM static path missing in clean baseline. Resolved.
- I3: Dynamic VB paths still include exDQLM-specific latent structures in DQLM mode. Resolved.
- I4: ELBO structures still include non-reduced terms in current VB implementations. Resolved for reduced branches; component-by-component ELBO diagnostics test coverage still pending.
- I5: Reduced dynamic CAVI currently uses R Kalman smoother for full ELBO-state accounting; C++ state update reuse for this reduced branch is pending explicit diagnostic-safe validation.

## Algebra Congruence Notes (exAL/exDQLM vs AL/DQLM)

- Reduced model removes both gamma and `s_t` blocks entirely (not a superficial `gamma=0` patch inside exAL formulas).
- For both static and dynamic reduced branches, the implemented updates match the reduced-AL derivations used in `DQLM-and-BQR---Theory/main.tex`.
- In the package parameterization `p(sigma) propto sigma^{-(a+1)} exp(-b/sigma)`, the full conditional for `sigma` is inverse-gamma in both Gibbs and CAVI reduced branches.
  - A GIG form for scale-related updates can arise under alternative parameterizations/transforms, but for this package parameterization the implemented IG form is the correct conjugate target.
- ELBO reductions remove all gamma/Jacobian/Laplace terms and all `s_t` terms in reduced branches.

## Execution Status for This Step

Completed now:

- [x] cloned theory repo locally.
- [x] reviewed static and dynamic Gibbs/CAVI/ELBO derivations.
- [x] implemented reduced-model dynamic CAVI core and wired ISVB/LDVB DQLM paths.
- [x] implemented reduced-model static Gibbs and static CAVI DQLM paths.
- [x] fixed `dqlm.ind` propagation typo in dynamic entry points.
- [x] added reduced-path tests (`test-dqlm-reduced-paths.R`, `test-dqlm-vb-sim-smoke.R`).
- [x] regenerated documentation (`devtools::document()`).
- [x] full test suite pass (`devtools::test()`: PASS 1008, FAIL 0, WARN 0, SKIP 0).
- [x] added simulation smoke plotting script:
  - `tools/merge_reports/20260304_vb_quantile_smoke_plot.R`
  - outputs in `results/sim_suite_dlm/dqlm_vb_smoke_20260304/`.

Pending:

- [ ] add explicit ELBO component-by-component assertions (not only finite/trace/consistency checks).
- [ ] define hard acceptance gates for exDQLM MCMC ESS/acceptance before speed-comparison signoff.

## Smoke Validation Evidence (2026-03-04)

Automated (testthat):

- `tests/testthat/test-dqlm-reduced-paths.R`
- `tests/testthat/test-dqlm-vb-sim-smoke.R`
- Full suite status: PASS 1008, FAIL 0, WARN 0, SKIP 0.

Synthetic dynamic quantile fit comparison (LDVB):

- Script: `tools/merge_reports/20260304_vb_quantile_smoke_plot.R`
- Output directory: `results/sim_suite_dlm/dqlm_vb_smoke_20260304/`
- Produced figures:
  - `tau_0p05_fit_compare.png`
  - `tau_0p50_fit_compare.png`
  - `tau_0p95_fit_compare.png`
- Summary metrics file:
  - `results/sim_suite_dlm/dqlm_vb_smoke_20260304/metrics_summary.csv`

Manual real-data smoke run (not a testthat gate):

- Data: `scIVTmag[1:90]`
- Model: `polytrendMod(1, quantile(y, 0.5), 10)`
- Fitted `exdqlmLDVB` and reduced `dqlm.ind=TRUE` at `tau in {0.05, 0.5, 0.95}`.
- All fits completed with finite outputs and iterations:
  - `tau=0.05`: iter ex/dq = 12/25
  - `tau=0.50`: iter ex/dq = 15/8
  - `tau=0.95`: iter ex/dq = 19/11

## Full Refit + Figure Regeneration (2026-03-04)

Script:

- `tools/merge_reports/20260305_full_vb_mcmc_validation.R`

Locked rerun attempt (fit generation):

- run config file: `results/function_testing_20260304_vb_quantiles/run_config.txt`
- start: `2026-03-04 08:45:11`
- fit completion timestamps (from saved fit files):
  - VB all 6 done by `08:50:07`
  - MCMC DQLM done by `10:31:05`
  - MCMC exDQLM done by `11:14:31`
- note: `tools/merge_reports/20260305_full_vb_mcmc_validation.log` stops after DQLM completion; parent logging process ended early while worker fits finished.

Exact locked-rerun settings used (from `run_config.txt`):

- `EXDQLM_CORES_VB=6`
- `EXDQLM_CORES_MCMC=6`
- `TT=5000` (full series)
- VB: `tol=0.03`, `n_samp=300`, `max_iter=300`
- VB joint-stop options:
  - `exdqlm.tol_sigma=0.02`
  - `exdqlm.tol_gamma=0.01`
  - `exdqlm.tol_elbo=5`
  - `exdqlm.vb.min_iter=30`
  - `exdqlm.vb.patience=5`
  - `exdqlm.vb.allow_elbo_drop=5`
- MCMC: `n.burn=500`, `n.mcmc=1500`
- MH tuning options:
  - `mh.adapt.interval=25`
  - `mh.target.accept=[0.25, 0.55]`
  - `mh.scale.bounds=[0.02, 2.50]`
  - `mh.max_scale.step=0.50`
  - `mh.min_burn_adapt=25`

Recovery pass (post-processing from existing fits):

- script: `tools/merge_reports/20260305_postprocess_from_existing_fits.R`
- log: `tools/merge_reports/20260305_postprocess_from_existing_fits.log`
- start/end: `2026-03-04 14:55:22` to `2026-03-04 15:12:07`
- recovered artifacts under `results/function_testing_20260304_vb_quantiles/`:
  - `derived/`: 12 files
  - `tables/`: `fit_summary.csv`, `metrics_summary.csv`, `vb_convergence_summary.csv`, `mcmc_diagnostics_summary.csv`
  - `plots/`: 39 PNG files

Post-recovery diagnostic note (locked rerun fit objects):

- VB gate improved: all 6 VB fits have `stop_reason=joint_converged`.
- exDQLM MCMC gamma mixing remains weak:
  - `tau=0.05`: ESS gamma `2.08`
  - `tau=0.50`: ESS gamma `9.84`
  - `tau=0.95`: ESS gamma `1.79`
- MH adaptation is active for exDQLM (non-zero adaptation history in fit objects; prior “not recording” concern was a diagnostics-field mismatch).

exDQLM-only MCMC gate pass (focused rerun):

- script: `tools/merge_reports/20260305_exdqlm_mcmc_gate_pass.R`
- output root: `results/function_testing_20260304_vb_quantiles/gate_exdqlm_mcmc_20260305/`
- log: `results/function_testing_20260304_vb_quantiles/gate_exdqlm_mcmc_20260305/logs/gate_run.log`
- start/end: `2026-03-04 16:06:31` to `2026-03-04 16:52:01`
- settings: `TT=5000`, `burn=150`, `n=450`, `cores=3`, `mh.proposal=laplace_rw`, `joint_sample=TRUE`
- diagnostics table:
  - `results/function_testing_20260304_vb_quantiles/gate_exdqlm_mcmc_20260305/tables/mcmc_exdqlm_gate_summary.csv`

Focused gate-pass outcome:

- adaptation recorded for all taus (`mh_adapt_steps=5`, non-NA `mh_scale_final`)
- gamma ESS still below acceptance gate in all taus:
  - `tau=0.05`: ESS gamma `1.23`
  - `tau=0.50`: ESS gamma `6.35`
  - `tau=0.95`: ESS gamma `2.09`

## Completed Dynamic Long-Burn Rerun (VB->MCMC)

Long-budget rerun used to re-evaluate DQLM/exDQLM under a longer burn-in and VB-first initialization:

- script: `tools/merge_reports/20260305_vb_then_mcmc_pipeline.R`
- run root: `results/function_testing_20260304_vb_quantiles/rerun_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260304_183508/`
- fixed settings:
  - `TT=5000`
  - VB: `n.samp=1000` (run first for each model/tau)
  - MCMC: `n.burn=2000`, `n.mcmc=1000`
  - parallel layout: 6 cores (one pipeline per model/tau task)
  - MCMC initialization: `init.from.vb=TRUE` with per-task `vb_init_fit`

Completion summary:

- VB completed for all 6 tasks.
- DQLM MCMC completed by `2026-03-04 23:04:04 PST`.
- exDQLM MCMC completed by `2026-03-05 00:03:48 PST`.
- postprocess script: `tools/merge_reports/20260305_postprocess_from_existing_fits.R`
- postprocess log: `tools/merge_reports/20260305_postprocess_from_existing_fits.log`
- postprocess completed at `2026-03-05 00:50:05 PST`
- regenerated artifacts under rerun root:
  - `tables/`: `fit_summary.csv`, `metrics_summary.csv`, `vb_convergence_summary.csv`, `mcmc_diagnostics_summary.csv`
  - `plots/`: 39 PNG files (`fit_within_inference`, `fit_between_inference`, `traces`)

## Remaining Work (Dynamic Scope)

Checklist to close current DQLM/exDQLM dynamic signoff:

- [x] wait for background rerun completion (`MCMC_DONE` for all 6 tasks, no failures).
- [x] run post-processing on the new rerun outputs:
  - regenerate unified tables (`fit_summary`, `metrics_summary`, `vb_convergence_summary`, `mcmc_diagnostics_summary`).
  - regenerate figures (within/between inference + traces) from this rerun only.
- [ ] evaluate final exDQLM gamma/sigma mixing gate on this long-burn run (ESS + acceptance + trace quality).
- [ ] lock final dynamic defaults:
  - final MH strategy (`rw` vs `laplace_rw`) for exDQLM.
  - final VB stop defaults (joint ELBO/sigma/gamma tolerances).
- [ ] close remaining dynamic tracker gates and record exact final reproducible configuration.

## New Requested Scope: Static exAL vs AL Parity Campaign

User-requested extension:

- replicate the same analysis pattern used for dynamic DQLM/exDQLM, but in the static setting:
  - exAL and AL regression
  - VB and MCMC
  - taus `{0.05, 0.50, 0.95}`
  - VB-first initialization for MCMC
  - full VB-vs-MCMC and exAL-vs-AL comparisons (fit, uncertainty, diagnostics, runtime).
- normalize static algorithm outputs/diagnostics to match dynamic formatting/style where feasible.
- produce a static simulation dataset generator aligned with the dynamic simulation format currently used:
  - inspect and document how the current dynamic simulation data was produced.
  - create static analog with known/approximate true quantile functions.
  - preserve similar object layout so report tooling can be reused.
- dataset specification ambiguity was resolved in S1 with two documented options; conservative default selected and locked.

Proposed phase checklist for this new static campaign:

### Phase S1: Static Simulation Spec + Data Generator Plan

- [x] locate and document dynamic simulation generator source used for current `sim_output.rds`.
- [x] draft static simulation schema mirroring dynamic data object structure.
- [x] define target true quantile functions and noise configuration for AL/exAL stress testing.
- [x] lock spec with explicit seed, TT/grid, covariates, and saved artifacts.

S1 implementation artifacts (`2026-03-04`):

- spec: `tools/merge_reports/20260305_static_exal_al_sim_spec.md`
- generator: `tools/merge_reports/20260305_generate_static_exal_al_sim.R`
- generator log: `tools/merge_reports/20260305_generate_static_exal_al_sim.log`
- validator: `tools/merge_reports/20260305_validate_static_sim_schema.R`
- validator log: `tools/merge_reports/20260305_validate_static_sim_schema.log`
- generated dataset root:
  - `results/sim_suite_static/series/static_exal_mildskew/`
  - files: `sim_output.rds`, `series_wide.csv`, `series_long.csv`, `meta.txt`, `run_config.rds`
  - validation outputs: `validation/schema_validation.txt`, `validation/schema_validation_summary.csv`

Locked S1 defaults:

- scenario: `static_exal_mildskew`
- seed: `20260305`
- `TT=5000`
- `p_grid={0.01,0.05,0.10,...,0.95,0.99}` (21 levels)
- static design:
  - `X=[1, sin(2*pi*t/50), cos(2*pi*t/50), scaled_time]`
  - `beta=(0.0, 2.0, -1.4, 0.6)`
- DGP error: exAL with `p0_gen=0.50`, `sigma_true=3.0`, `gamma_true=0.35`
- true quantiles:
  - exAL truth in `sim_output$q`
  - AL counterfactual quantiles in `sim_output$extras$q_al`

S1 follow-on refinement (`2026-03-05`):

- second static scenario added for clearer figure-level diagnostics and richer tail stress:
  - scenario: `static_exal_rich1d_mcq`
  - root: `results/sim_suite_static/series/static_exal_rich1d_mcq/`
  - generator still uses dynamic-style object structure, but the primary covariate is a single interpretable `x_main` with expanded basis terms
  - true quantiles are approximated by Monte Carlo and stored in `sim_output$q`
  - this is now the primary static review dataset for tail-behavior triage

Dynamic-lineage trace used in S1 (not present in this repo checkout, but available locally):

- `/data/muscat_data/jaguir26/exdqlm/scripts/sim_suite_dlm.R`
- `/data/muscat_data/jaguir26/exdqlm/R/simulate_ts_mc_quantiles.R`

### Phase S2: Static VB/MCMC Interface Normalization

- [x] align static fit return objects with dynamic-style diagnostics fields where possible.
- [x] align status logging and run metadata for static pipelines.
- [x] ensure backward-compatible function interfaces.

S2 implementation decision (ambiguity resolved):

- Option A: modify existing `exal_static_*` public return objects directly.
- Option B (chosen, conservative): add non-breaking adapter/normalization helpers and keep existing static APIs untouched.

Chosen S2 implementation artifacts:

- adapter helpers: `R/static_fit_normalization.R`
  - `.static_vb_to_mcmc_init()`
  - `.static_normalize_vb_fit()`
  - `.static_normalize_mcmc_fit()`
  - `.static_quantile_path_from_fit()`
- tests: `tests/testthat/test-static-fit-normalization.R`

S2 test evidence:

- `devtools::test(filter='static-fit-normalization')` -> `PASS 33, FAIL 0, WARN 0, SKIP 0`
- `devtools::test(filter='static-regression-regmod|dqlm-reduced-paths|static-fit-normalization')` -> `PASS 83, FAIL 0, WARN 0, SKIP 0`

### Phase S3: Static exAL/AL VB->MCMC Pipeline (3 Quantiles)

- [x] implement/prepare orchestrated run script for 6 static tasks:
  - `{AL, exAL} x {0.05, 0.50, 0.95}`
  - VB first, then MCMC seeded from VB fit.
- [x] support parallel execution with one task per core.
- [x] persist per-task status files and unified summary table.

S3 implementation artifacts:

- pipeline script: `tools/merge_reports/20260305_static_vb_then_mcmc_pipeline.R`
- background launcher log: `tools/merge_reports/20260305_static_vb_then_mcmc_pipeline_background.log`

S3 smoke validation run (completed):

- run root: `results/sim_suite_static/static_vb_then_mcmc_tt200_vbns80_burn30_n40_20260304_194114/`
- completed outputs include:
  - per-task status files under `logs/*.status.tsv`
  - per-task logs under `logs/*.log`
  - fit artifacts under `fits/vb/` and `fits/mcmc/`
  - summary table: `tables/pipeline_task_summary.csv`

S3 full TT=5000 runs (completed):

- mild-skew baseline run root:
  - `results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260304_194203/`
  - settings:
    - `TT=5000`
    - VB: `max_iter=300`, `tol=0.03`, `n_samp_xi=1000`
    - MCMC: `n.burn=2000`, `n.mcmc=1000`, `thin=1`
    - `cores=6`
  - all 6 fits completed:
    - AL MCMC done by `2026-03-04 19:46:31 PST`
    - exAL MCMC done by `2026-03-04 20:57:59 PST`
- richer MC-truth run root:
  - `results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_012506/`
  - same TT/VB/MCMC/core settings as above
  - source simulation:
    - `results/sim_suite_static/series/static_exal_rich1d_mcq/sim_output.rds`
  - all 6 fits completed:
    - AL MCMC done by `2026-03-05 01:29:38 PST`
    - exAL MCMC done by `2026-03-05 02:15:15 PST`

### Phase S4: Static Comparison and Signoff Gates

- [x] generate static comparison tables/plots (VB vs MCMC, AL vs exAL).
- [x] add convergence/mixing diagnostics summary and explicit acceptance gates.
- [x] add/extend tests for static reduced/full parity paths and diagnostics integrity.
- [ ] update tracker with final static campaign settings and closure status.

S4 implementation artifacts:

- report script: `tools/merge_reports/20260305_static_vb_mcmc_report.R`
- integration smoke test: `tests/testthat/test-static-vb-mcmc-pipeline-report-smoke.R`

S4 smoke reporting run (completed on finished S3 smoke pipeline):

- source run: `results/sim_suite_static/static_vb_then_mcmc_tt200_vbns80_burn30_n40_20260304_194114/`
- generated tables:
  - `tables/fit_metrics_by_task.csv`
  - `tables/runtime_diagnostics_summary.csv`
  - `tables/pairwise_exal_vs_al.csv`
  - `tables/acceptance_gate_summary.csv`
  - `tables/report_summary.md`
- generated plots:
  - `plots/fit_compare_tau_0p05.png`
  - `plots/fit_compare_tau_0p50.png`
  - `plots/fit_compare_tau_0p95.png`
  - `plots/runtime_vb_mcmc_by_task.png`

Static acceptance gates used in S4 smoke:

- `VB converged` gate: `vb_converged == TRUE`
- `MCMC ESS sigma` gate: `ESS_sigma >= 30`
- `MCMC ESS gamma` gate (exAL only): `ESS_gamma >= 20`
- `accuracy` gate: `RMSE(MCMC) <= 1.25 * RMSE(VB)`

S4 smoke gate outcome:

- pass count: `1 / 6` tasks
- fail count: `5 / 6` tasks
- dominant failures: low ESS in short-chain smoke budget and exAL VB `max_iter` stops at this smoke setting.

S4-related test bundle (`2026-03-04`):

- `devtools::test(filter='dqlm-reduced-paths|static-regression-regmod|static-fit-normalization|static-vb-mcmc-pipeline-report-smoke')`
  - `PASS 83, FAIL 0, WARN 0, SKIP 1`
  - skip reason: pipeline/report script path unavailable in the test sandbox for one integration smoke test.

Current S4 closure status:

- [x] rerun S4 report and gate summary on the full mild-skew run
  (`results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260304_194203/`)
- [x] generate dynamic-style postprocess outputs on the rich MC-truth run via
  `tools/merge_reports/20260305_static_postprocess_from_existing_fits.R`
  (completed `2026-03-05 14:05:37 PST`, `42` PNG files)
- [x] complete the static recalibration follow-through on the rich MC-truth run:
  - tuning screen root:
    - `results/sim_suite_static/screen_exal_tuning_tt5000_20260305_153200/`
    - selected settings:
      - LDVB profile: `base`
      - static `exAL` VB `max_iter=500`
      - static `exAL` MCMC kernel: `rw`
  - calibrated full run root:
    - `results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_160734/`
    - completed `2026-03-05 16:56:35 PST`
    - postprocess completed `2026-03-05 16:58:37 PST`
    - report outputs present after rerun of `tools/merge_reports/20260305_static_vb_mcmc_report.R`
- [x] complete the dynamic exDQLM retune follow-through on the latest TT=5000 review run:
  - retune root:
    - `results/function_testing_20260304_vb_quantiles/retune_exdqlm_from_vb_tt5000_burn2000_n1000_20260305_152639/`
  - scope:
    - reused the already-completed `DQLM` control-arm MCMC fits from the prior dynamic rerun
    - reran only the `exDQLM` MCMC arm from the existing VB fits under the calibrated proposal setting
  - exact retune settings:
    - `mh_proposal = laplace_rw`
    - `mh_joint_sample = FALSE`
    - `n.burn = 2000`
    - `n.mcmc = 1000`
    - `mh.adapt.interval = 25`
    - `mh.target.accept = c(0.25, 0.55)`
  - completion:
    - dynamic resume completed `2026-03-05 19:33:14 PST`
    - postprocess completed `2026-03-05 19:56:59 PST`
    - regenerated outputs:
      - `tables/fit_summary.csv`
      - `tables/vb_convergence_summary.csv`
      - `tables/mcmc_diagnostics_summary.csv`
      - `tables/metrics_summary.csv`
      - `plots/` (`39` PNG files)
- [ ] resolve the remaining extended-model diagnostics issues identified in the latest figure review below

### Static Calibration Outcomes After C1-C4 (`2026-03-05`)

Calibrated static rerun basis:

- run root:
  - `results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_160734/`
- tuning root:
  - `results/sim_suite_static/screen_exal_tuning_tt5000_20260305_153200/`
- static figures/tables regenerated from the calibrated run:
  - `tables/vb_convergence_summary.csv`
  - `tables/vb_ld_diagnostics_summary.csv`
  - `tables/mcmc_diagnostics_summary.csv`
  - `tables/acceptance_gate_summary.csv`
  - `plots/` (`73` PNG files across postprocess + S4 report outputs)

Static calibration outcome summary:

- VB side:
  - `exAL` VB now converges jointly at all taus under `max_iter=500`
  - iteration counts:
    - `tau=0.05 -> 453`
    - `tau=0.50 -> 153`
    - `tau=0.95 -> 498`
  - final LD diagnostics are stable:
    - `ld_mode_fallback_rate = 0` for all `exAL` taus
    - `ld_xi_rel_drift_last` is near zero for all `exAL` taus
- MCMC side:
  - calibrated static `rw` kernel is now fully instrumented and acceptance is observable
  - acceptance/ESS remain weak for `exAL`, especially `gamma`:
    - `tau=0.05`: `accept_keep=0.028`, `ESS_sigma=15.36`, `ESS_gamma=2.05`
    - `tau=0.50`: `accept_keep=0.084`, `ESS_sigma=27.22`, `ESS_gamma=3.85`
    - `tau=0.95`: `accept_keep=0.041`, `ESS_sigma=54.22`, `ESS_gamma=3.69`
- static gate status:
  - `AL`: `3 / 3` tasks pass
  - `exAL`: `0 / 3` tasks pass
  - failure mode after the static recalibration is now isolated to MCMC mixing/ESS, not VB convergence

### Dynamic Calibration Outcomes After C5-C6 (`2026-03-05`)

Calibrated dynamic rerun basis:

- previous dynamic review root:
  - `results/function_testing_20260304_vb_quantiles/rerun_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260304_183508/`
- retuned dynamic root:
  - `results/function_testing_20260304_vb_quantiles/retune_exdqlm_from_vb_tt5000_burn2000_n1000_20260305_152639/`
- regenerated dynamic tables/plots from the retuned root:
  - `tables/fit_summary.csv`
  - `tables/vb_convergence_summary.csv`
  - `tables/mcmc_diagnostics_summary.csv`
  - `tables/metrics_summary.csv`
  - `plots/` (`39` PNG files)

Dynamic calibration outcome summary:

- VB side:
  - no dynamic VB change was required after the static diagnosis
  - `exDQLM` VB remains jointly converged at all taus on the retuned review root:
    - `tau=0.05 -> iter=97`
    - `tau=0.50 -> iter=34`
    - `tau=0.95 -> iter=99`
- MCMC side:
  - the retune kept `laplace_rw` but disabled joint sampling (`mh_joint_sample = FALSE`)
  - this materially improved kept-draw acceptance at all `exDQLM` taus:
    - `tau=0.05`: `0.044 -> 0.293`
    - `tau=0.50`: `0.174 -> 0.289`
    - `tau=0.95`: `0.056 -> 0.280`
  - ESS changes were mixed:
    - `tau=0.05`: `ESS_sigma 2.85 -> 4.03`, `ESS_gamma 1.87 -> 9.65`
    - `tau=0.50`: `ESS_sigma 34.35 -> 51.57`, `ESS_gamma 12.51 -> 12.23`
    - `tau=0.95`: `ESS_sigma 1.74 -> 2.23`, `ESS_gamma 7.51 -> 4.40`
  - fit accuracy moved slightly in the right direction, but only marginally:
    - `tau=0.05`: `RMSE 0.6191 -> 0.6150`
    - `tau=0.50`: `RMSE 0.2833 -> 0.2801`
    - `tau=0.95`: `RMSE 0.6324 -> 0.6270`
- dynamic gate interpretation:
  - the dynamic retune improved chain usability and tail kept-draw acceptance
  - the dynamic extended-model mixing gate is still open because tail `sigma/gamma` ESS remains weak, especially at `tau=0.05` and `tau=0.95`
  - this confirms the shared extended-model issue is not a reduced-model parity problem anymore; it is now a residual tail-geometry / proposal-efficiency problem in the extended path

## Latest Figure Review and Triage Checklist (2026-03-05)

Review basis for the notes below:

- dynamic review run:
  - run root: `results/function_testing_20260304_vb_quantiles/rerun_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260304_183508/`
  - figures reviewed from latest postprocess completed `2026-03-05 00:50:05 PST`
  - VB traces correspond to completed fit lengths:
    - `exDQLM` iters = `97`, `34`, `99` for `tau=0.05`, `0.50`, `0.95`
    - `DQLM` iters = `37`, `34`, `37`
  - MCMC traces correspond to `1000` kept draws after `2000` burn-in
- static review run:
  - run root: `results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_012506/`
  - figures reviewed from latest postprocess completed `2026-03-05 14:05:37 PST`
  - VB traces are plotted from iteration `20` through iteration `300`
  - MCMC traces correspond to `1000` kept draws after `2000` burn-in

Structured review summary:

| ID | Observation from latest plots/tables | Evidence from latest completed runs | Working interpretation | Planned response |
|---|---|---|---|---|
| R1 | Extended models remain the dominant source of residual problems in both static and dynamic campaigns. | Static rich run: `exAL` tail RMSE is much worse than `AL` (`VB/MCMC` at `tau=0.05`: `4.52/4.83` vs `1.03/1.05`; `tau=0.95`: `1.03/1.17` vs `0.38/0.42`). Dynamic rerun: `exDQLM` gamma ESS stays weak (`1.87`, `12.51`, `7.51`) while `DQLM` sigma ESS stays high (`449-538`). | Reduced-model paths are no longer the bottleneck. Remaining signoff risk is concentrated in the extended `gamma`/`sigma` geometry, especially in the tails. | Keep `AL/DQLM` as control arms. Focus all next diagnostic and tuning work on `exAL/exDQLM`, especially `tau=0.05` and `tau=0.95`. |
| R2 | Static `exAL` VB instability is concentrated in the LD block (`sigma`, `gamma`, ELBO), not in the coefficient block. | Static rich run `vb_convergence_summary.csv`: `exAL` stops at `max_iter=300` for all taus. Final deltas are large at the tails (`tau=0.05`: `delta_sigma=1.07`, `delta_gamma=3.16`; `tau=0.95`: `delta_sigma=0.784`, `delta_gamma=2.35`) but tiny at the median (`tau=0.50`: `delta_sigma=6.46e-4`, `delta_gamma=5.88e-4`). Plot review shows coefficient traces look stable while ELBO and `sigma/gamma` continue to oscillate. | The likely failure mode is inside the Laplace-Delta block rather than `q(beta)`. Current `exAL` VB uses a BFGS mode finder plus Monte Carlo `xi` refresh with no damping/trust-region control, so the iterates can hover or mode-hop without settling deeper into the LD basin. | Add a forensic LD-block diagnostic pass first, then stabilize the block conservatively with damping/regularization before changing stopping tolerances. |
| R3 | Static `exAL` MCMC appears to reach the right region but mixes slowly for `gamma` and, at some taus, `sigma`. | Static rich run `mcmc_diagnostics_summary.csv`: `ESS_gamma = 8.43`, `7.32`, `6.20`; `ESS_sigma = 24.48`, `12.33`, `37.14` for `tau=0.05`, `0.50`, `0.95`. Current static report shows no acceptance rates. Code inspection: `R/exal_static_mcmc.R` does not use adaptive RW-MH for `gamma`; it redraws transformed `eta` from a local Gaussian around the per-iteration Laplace mode. | This is a different issue from dynamic exDQLM MCMC. Static `exAL` currently has no explicit MH step-size control or acceptance diagnostic for `gamma`, so mixing can be poor even when trace location looks reasonable. | Expose and instrument the current LD proposal scale, then compare it against a corrected/adaptive RW-MH alternative if the LD-only kernel remains sticky. |
| R4 | Dynamic extended-model issues are similar in spirit, but not identical in mechanism. | Dynamic rerun `vb_convergence_summary.csv`: `exDQLM` does converge jointly, but tails need many more iterations (`97`, `99`) than the median (`34`). Dynamic rerun `mcmc_diagnostics_summary.csv`: `mh_proposal=laplace_rw`, `mh_adapt=TRUE`, burn acceptance near `0.40`, but keep acceptance is very low at the tails (`0.044`, `0.056`) and tail gamma ESS remains weak. No analogous sigma/gamma VB oscillation is visible in the latest dynamic plots. | The shared problem is hard extended-model tail geometry. The static VB oscillation seems specific to the static LDVB implementation, but static MCMC and dynamic MCMC may still benefit from a shared proposal-scale strategy. | Diagnose static VB and static MCMC first, then port only the mechanism-supported fixes to dynamic exDQLM rather than copying all static changes blindly. |

Checklist for the next implementation round:

- [x] C1. Static `exAL` LDVB forensic diagnostic pass.
  - Completed implementation:
    - added per-iteration LD diagnostics and normalized summaries for:
      - `xi` drift
      - covariance / Hessian condition numbers
      - fallback usage
      - transformed-block trace metadata
    - exposed these in:
      - `R/exal_static_LDVB.R`
      - `R/static_fit_normalization.R`
      - `tools/merge_reports/20260305_static_postprocess_from_existing_fits.R`
  - Outcome:
    - forensic diagnostics showed the static failure was localized to the LD block, not the coefficient block
- [x] C2. Static `exAL` LDVB stabilization.
  - Completed implementation:
    - added LD-block damping, covariance regularization, step caps, and common-random-number style `xi` stabilization controls
    - screened LD profiles on the rich TT=5000 static dataset
  - Outcome:
    - static `exAL` VB convergence issue is resolved with `max_iter=500`
    - calibrated rerun reached `joint_converged` at all `exAL` taus
- [x] C3. Static `exAL` MCMC kernel instrumentation and control.
  - Completed implementation:
    - instrumented static MCMC kernel metadata, acceptance, scale history, and per-iteration MH traces
    - added explicit kernel options: `laplace_local`, `laplace_rw`, `rw`
    - screened kernels on the rich TT=5000 static dataset
  - Outcome:
    - `rw` was the best of the screened static kernels, but calibrated full-run ESS is still below gate for `exAL`
- [x] C4. Shared extended-model comparison protocol.
  - Completed implementation:
    - ran the static screen on the rich MC-truth dataset and then reran the full `{AL, exAL} x {0.05,0.50,0.95}` campaign under the calibrated settings
    - regenerated dynamic-style postprocess outputs plus S4 comparison/gate tables
  - Outcome:
    - the static rerun closed the VB question and isolated the remaining issue to extended-model MCMC mixing
- [x] C5. Dynamic exDQLM follow-through after static diagnosis.
  - Completed implementation:
    - kept the dynamic VB controls unchanged because the latest evidence still supports the existing joint-stop settings
    - retuned the dynamic `exDQLM` MCMC retry ordering so the primary calibrated path is:
      - `mh_proposal = laplace_rw`
      - `mh_joint_sample = FALSE`
    - reran the `exDQLM` MCMC arm from the already-completed dynamic VB fits under the calibrated setting
  - Outcome:
    - dynamic kept-draw acceptance improved substantially at all taus
    - lower-tail `gamma` ESS improved materially
    - upper-tail `gamma` ESS remains weak and did not improve
- [x] C6. Final rerun once fixes land.
  - Completed execution:
    - reran the full static rich MC-truth campaign under the calibrated static settings
    - reran the dynamic extended-model arm on the latest dynamic TT=5000 review root under the calibrated dynamic proposal setting
    - regenerated all current tables and figures for both latest review roots
    - validated targeted tests after implementation changes:
      - `PASS 76, FAIL 0, WARN 0, SKIP 1`
  - Outcome:
    - implementation and rerun workflow are complete for `C1-C6`
    - final signoff remains open because `exAL` and `exDQLM` tail-MCMC mixing gates are still not satisfied

Open signoff gates after C1-C6:

- [ ] Static `exAL` MCMC tail mixing:
  - `ESS_gamma` remains below acceptable levels for all taus on the calibrated static rerun
- [ ] Dynamic `exDQLM` MCMC tail mixing:
  - `ESS_sigma` and `ESS_gamma` remain weak at `tau=0.05` and `tau=0.95` on the retuned dynamic rerun
- [ ] Final extended-model default lock:
  - current evidence supports:
    - static `exAL` VB: keep the calibrated LD controls and `max_iter=500`
    - dynamic `exDQLM` MCMC: prefer `laplace_rw` with `mh_joint_sample = FALSE` over the prior joint-sampling path
  - a final default lock should wait until the residual tail-mixing issue is improved or explicitly accepted as an unresolved limitation

## New Audit Track: Static exAL Theory-to-Code Review for Residual Tail Bias (2026-03-05)

Motivation for this audit:

- after the static convergence hardening work, the `exAL` VB traces and LD-block diagnostics look materially healthier than before
- however, on the richer static review run, the `exAL` fits at `tau=0.05` and `tau=0.95` can still look shifted / biased relative to:
  - the true quantile curves
  - the `AL` control-arm fits
- the concerning part is that this bias can persist even when the VB convergence diagnostics look healthy enough that the issue is no longer obviously a pure optimizer failure
- therefore the next debugging layer is not more tuning first; it is a derivation-to-implementation audit

Theory repo of record for this audit:

- repo:
  - `/data/muscat_data/jaguir26/DQLM-and-BQR---Theory`
- remote:
  - `https://github.com/AntonioAPDL/DQLM-and-BQR---Theory.git`
- pulled latest on `2026-03-05`
- current commit used for audit planning:
  - `f31ce5df757ad78647c1015a3ed6a875a0402bc5`
- primary theory artifacts to cross-check:
  - `main.tex`
  - `exAL_Original.pdf`

Scope boundary for this audit:

- primary target:
  - static `exAL` VB at `tau=0.05` and `tau=0.95`
- secondary cross-check:
  - static `exAL` Gibbs/MCMC expressions for the same model, to verify the joint density and augmentation are coded consistently across VB and MCMC
- control arms to preserve during audit:
  - static `AL` VB/MCMC
  - dynamic `DQLM/exDQLM` should not be changed until the static audit identifies a real shared issue

Audit operating rules for `T1-T6`:

- lock the empirical review basis before touching theory or code:
  - use the rich static review run `results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_160734/`
  - treat the later heteroskedastic run as a secondary validation dataset, not the primary debugging basis for the first pass
- do not change dynamic `exDQLM` during `T1-T4`
- do not retune VB damping, `max_iter`, or MCMC proposal settings during `T1-T5` unless the audit proves the target density and updates are already consistent
- every discrepancy found must be labeled immediately as one of:
  - theory-document issue
  - implementation issue
  - intentional approximation
  - unresolved
- each audit step must produce a concrete artifact:
  - markdown note, concordance table, or regression test

Revised checklist for the derivation-to-code audit:

- [x] T1. Freeze the exact empirical symptom and review basis.
  - Record the exact run root, commit hash, and figure/table paths that motivated the concern:
    - `results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_160734/`
    - focus on static `exAL` at `tau=0.05` and `tau=0.95`
  - Pin the specific evidence to review:
    - within-inference plots showing the apparent shift/bias relative to truth
    - between-inference plots showing `exAL` vs `AL`
    - VB ELBO and parameter traces that look numerically healthy despite the fit issue
    - summary rows from `fit_summary.csv`, `vb_convergence_summary.csv`, and `metrics_summary.csv`
  - Write a short symptom note that separates:
    - fit bias
    - convergence behavior
    - mixing behavior
  - Deliverable:
    - one frozen audit note that defines the empirical problem before any new derivation or code edits
  - Completed on `2026-03-05`.
  - Artifacts:
    - note: `tools/merge_reports/20260305_static_exal_tail_bias_t1_t3_audit.md`
    - metrics extract: `results/sim_suite_static/audits/static_exal_tail_bias_t1_t3_20260305/t1_focus_metrics_summary.csv`
    - pairwise extract: `results/sim_suite_static/audits/static_exal_tail_bias_t1_t3_20260305/t1_focus_pairwise_exal_vs_al.csv`
    - VB convergence extract: `results/sim_suite_static/audits/static_exal_tail_bias_t1_t3_20260305/t1_focus_vb_convergence_summary.csv`
    - LD diagnostics extract: `results/sim_suite_static/audits/static_exal_tail_bias_t1_t3_20260305/t1_focus_vb_ld_diagnostics_summary.csv`
    - MCMC diagnostics extract: `results/sim_suite_static/audits/static_exal_tail_bias_t1_t3_20260305/t1_focus_mcmc_diagnostics_summary.csv`
  - Outcome:
    - frozen evidence confirms the tail-bias symptom is real for `exAL` at `tau=0.05` and `tau=0.95`
    - both `VB` and `MCMC` are materially worse than `AL` in the tails on this run
    - `VB` convergence diagnostics look healthy enough that this is not obviously a simple non-convergence story

- [x] T2. Re-derive the static `exAL` joint density and augmentation from source material.
  - Use `exAL_Original.pdf` as the primary source of record for:
    - model parameterization
    - latent-variable augmentation
    - support restrictions and transforms
    - full joint up to proportionality
  - Compare this directly against `main.tex` and identify:
    - notation mismatches
    - dropped or altered terms
    - support-transform inconsistencies
    - any ambiguity in the static specialization
  - Require a written side-by-side comparison:
    - original paper symbol/expression
    - current `main.tex` symbol/expression
    - verdict
  - Deliverable:
    - a discrepancy log for the joint density and augmentation alone
  - Completed on `2026-03-05`.
  - Artifacts:
    - note: `tools/merge_reports/20260305_static_exal_tail_bias_t1_t3_audit.md`
    - discrepancy log: `results/sim_suite_static/audits/static_exal_tail_bias_t1_t3_20260305/t2_joint_discrepancy_log.csv`
  - Outcome:
    - `main.tex` currently documents only `AL / exAL with gamma = 0`
    - the static `exAL` hierarchy, gamma support map, and quantile-fixed GAL augmentation are present in `exAL_Original.pdf` and in code, but not yet in `main.tex`
    - primary `T2` finding is a theory-document gap, not an immediate code mismatch

- [x] T3. Re-derive the static `exAL` VB/CAVI updates line by line from the audited joint.
  - Re-derive the mean-field factorization and update targets for:
    - `q(beta)`
    - `q(v_t)`
    - `q(s_t)`
    - `q(sigma, gamma)` under the Laplace-Delta block
  - For the LD block, explicitly verify:
    - transform definition `eta -> gamma`
    - objective being optimized
    - gradient and Hessian terms
    - Jacobian contribution
    - expectations entering the objective from other factors
  - Perform a numeric sanity pass:
    - finite-difference check of the implemented gradient/Hessian at one frozen parameter point
    - sign and scale check for tail-sensitive terms at `tau=0.05` and `tau=0.95`
  - Deliverables:
    - equation-by-equation concordance table
    - one numeric derivative check artifact for the LD objective
  - Completed on `2026-03-05`.
  - Artifacts:
    - note: `tools/merge_reports/20260305_static_exal_tail_bias_t1_t3_audit.md`
    - concordance table: `results/sim_suite_static/audits/static_exal_tail_bias_t1_t3_20260305/t3_vb_concordance.csv`
    - derivative check: `results/sim_suite_static/audits/static_exal_tail_bias_t1_t3_20260305/t3_ld_derivative_check.csv`
  - Outcome:
    - no obvious algebraic sign/scaling bug was found in the audited `VB` update blocks
    - the frozen LD objective is numerically close to stationary at the saved tail fits and the local curvature check is consistent with a proper local mode
    - the remaining concrete implementation risks are the intentional approximation layers:
      - Laplace-Delta approximation for `q(sigma, gamma)`
      - Monte Carlo + damping approximation for the `xi` expectations

- [x] T4. Cross-check the static Gibbs/MCMC implementation against the same audited joint.
  - Verify that the static MCMC updates target the same joint used in `T2`:
    - `beta | rest`
    - latent block conditionals
    - `sigma | rest`
    - transformed/proposal treatment for `gamma`
  - Identify whether the MCMC kernel is:
    - an exact Gibbs step
    - a Metropolis-within-Gibbs step
    - a Laplace-based proposal approximation
  - Explicitly compare VB and MCMC on shared quantities:
    - likelihood terms
    - prior terms
    - latent augmentation definitions
    - transform/Jacobian handling
  - Deliverable:
    - one consistency table stating whether VB and MCMC are targeting the same posterior object
  - Completed on `2026-03-05`.
  - Artifacts:
    - note: `tools/merge_reports/20260305_static_exal_tail_bias_t4_audit.md`
    - consistency table: `results/sim_suite_static/audits/static_exal_tail_bias_t4_20260305/t4_mcmc_vb_consistency.csv`
    - numeric kernel checks: `results/sim_suite_static/audits/static_exal_tail_bias_t4_20260305/t4_kernel_equivalence_checks.csv`
  - Outcome:
    - for the frozen rich static run, static `MCMC` and static `VB` are targeting the same posterior object on the shared quantile-fixed GAL / `exAL` ingredients
    - the frozen run uses `mh.proposal = rw`, which is an exact Metropolis-within-Gibbs `gamma` kernel
    - no algebraic mismatch was found in the audited `MCMC` full conditional structure for `beta`, `v`, `s`, `sigma`, or `gamma | rest`
    - important caveat:
      - the `laplace_local` branch in `R/exal_static_mcmc.R` is an approximate local-Gaussian draw without MH correction and is therefore not an exact posterior kernel

- [x] T5. Build a theory-to-code concordance map and patch list.
  - Map the audited formulas to implementation points in:
    - `R/exal_static_LDVB.R`
    - `R/exal_static_mcmc.R`
    - `R/utils.R`
    - any helper used for normalization, transforms, or diagnostics
  - For each nontrivial expression, record:
    - theory equation reference
    - exact code location
    - whether constants are intentionally omitted
    - whether the implementation is exact, approximated, or potentially inconsistent
  - If a discrepancy is found, open a concrete patch item with:
    - expected effect on inference
    - files to update
    - required regression tests
  - Deliverable:
    - a patch-ready concordance checklist that can drive implementation without re-reading the whole derivation
  - Completed on `2026-03-05`.
  - Artifacts:
    - note: `tools/merge_reports/20260305_static_exal_tail_bias_t5_audit.md`
    - concordance map: `results/sim_suite_static/audits/static_exal_tail_bias_t5_20260305/t5_theory_code_concordance.csv`
    - patch list: `results/sim_suite_static/audits/static_exal_tail_bias_t5_20260305/t5_patch_list.csv`
  - Outcome:
    - the theory-to-code concordance now covers:
      - `R/utils.R`
      - `R/exal_static_LDVB.R`
      - `R/exal_static_mcmc.R`
      - `R/static_fit_normalization.R`
      - static reporting/pipeline helpers that consume normalized outputs
    - no new algebraic mismatch was found in the already-audited exact kernels
    - the patch-ready items that emerged are:
      - `P1`: add static `exAL` derivation to the theory repo `main.tex`
      - `P2`: add an exact-kernel signoff guard so `laplace_local` cannot be treated as signoff-ready
      - `P3`: add deterministic/replicated `xi` evaluation mode for static `LDVB`
      - `P4`: add LD mode-quality diagnostics to normalized outputs and reports

- [x] `P1-P4` implementation pass completed on `2026-03-05`.
  - `P1` theory-doc bridge:
    - updated `/data/muscat_data/jaguir26/DQLM-and-BQR---Theory/main.tex`
    - added a dedicated static quantile-fixed `exAL / GAL` section with:
      - `g(gamma)`, support bounds `(L,U)`,
      - `p(gamma, p0)`, `A_gamma`, `B_gamma`, `C_gamma`, `lambda_gamma`,
      - the static joint posterior,
      - exact Gibbs kernels for `beta`, `v`, `s`, `sigma`,
      - the transformed `eta`-scale exact gamma kernel,
      - the relation between that joint and the static `LDVB` approximation.
    - theory build check now succeeds and produces:
      - `/data/muscat_data/jaguir26/DQLM-and-BQR---Theory/main.pdf`
  - `P2` exact-kernel signoff guard:
    - `R/exal_static_mcmc.R` now records:
      - `mh.diagnostics$kernel_exact`
      - `mh.diagnostics$signoff_ready`
      - `mh.diagnostics$approximation_note`
    - `R/static_fit_normalization.R` propagates exact-vs-approximate gamma-kernel status.
    - static reporting/gates now include:
      - `gate_mcmc_kernel_exact`
      - `mh_kernel_exact`
      - `mh_signoff_ready`
    - refreshed rich static gate table:
      - `results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_160734/tables/acceptance_gate_summary.csv`
  - `P3` deterministic / replicated `xi` evaluation:
    - `R/exal_static_LDVB.R` now supports:
      - `ld_controls$xi_mode`
      - `ld_controls$xi_replicates`
      - `ld_controls$reuse_seed`
    - replicated-`xi` evaluations now record Monte Carlo dispersion (`xi_mcse_mean`, `xi_mcse_max`) in the LD trace.
    - static pipeline env controls now expose the same knobs for reproducible focused reruns.
  - `P4` LD mode-quality diagnostics:
    - `R/exal_static_LDVB.R` now stores final finite-difference mode checks:
      - `grad_inf_norm`
      - `neg_hess_min_eig`
      - `neg_hess_condition`
      - `local_mode_pass`
    - `tools/merge_reports/20260305_static_postprocess_from_existing_fits.R` now writes these through to:
      - `vb_ld_diagnostics_summary.csv`
    - `tools/merge_reports/20260305_static_vb_mcmc_report.R` now gates on:
      - `gate_vb_ld_local_mode`
      - `gate_mcmc_kernel_exact`
  - supporting regression coverage added:
    - deterministic replicated-`xi` regression test
    - exact-kernel / approximate-kernel normalization test
    - static report smoke test now asserts the new gate columns.
  - heteroskedastic static model-equivalence audit completed:
    - artifact root:
      - `results/function_testing_20260306_static_heteroskedastic_skewnormal/audits/heteroskedastic_model_equivalence_20260305`
    - outcome:
      - the supplied design matrix `X = [intercept, x_main, cos_term]` spans the targeted DGP mean exactly
      - `AL` and `exAL` use the same regression function and the same stored Monte Carlo truth on this dataset
      - the observed performance gap is therefore not a design-matrix mismatch.

- [x] T6. Run a focused verification and only then decide on broader reruns.
  - Use a minimal verification suite first:
    - static `exAL`
    - `tau in {0.05, 0.95}`
    - the frozen rich static dataset from `T1`
  - Compare four views:
    - truth vs `AL`
    - truth vs current `exAL`
    - current `exAL` vs corrected `exAL`
    - diagnostics before/after any derivation-consistency fix
  - Add regression tests whenever the audit produces a code correction:
    - numeric derivative test if the LD block changes
    - smoke/integration test if the posterior target changes
  - Only after the focused verification passes should we:
    - propagate the fix to dynamic `exDQLM`
    - rerun the heteroskedastic static dataset
    - retune proposals or convergence defaults
  - Deliverable:
    - a clear go/no-go decision for broader reruns based on a narrow corrected verification case
  - Completed on `2026-03-05`.
  - Artifacts:
    - script:
      - `tools/merge_reports/20260305_static_exal_tail_bias_t6_verify.R`
    - output root:
      - `results/sim_suite_static/audits/static_exal_tail_bias_t6_20260305`
    - key files:
      - `t6_metrics_comparison.csv`
      - `t6_diagnostics_before_after.csv`
      - `t6_delta_summary.csv`
      - `t6_verification_note.md`
      - `plots/t6_tail_compare_tau_0p05.png`
      - `plots/t6_tail_compare_tau_0p95.png`
  - Outcome:
    - corrected static `exAL` VB with deterministic replicated `xi` reached numerically credible local modes at both tails:
      - `tau=0.05`: `grad_inf_norm = 2.83e-03`, `local_mode_pass = TRUE`
      - `tau=0.95`: `grad_inf_norm = 8.14e-04`, `local_mode_pass = TRUE`
    - however, the tail bias did not materially improve:
      - `tau=0.05`: `RMSE 5.777553 -> 5.777139`
      - `tau=0.95`: `RMSE 1.972789 -> 1.972654`
    - decision:
      - `NO-GO` for broader reruns at this stage.
    - implication:
      - `P2-P4` improved auditability and ruled out a simple `xi` Monte Carlo instability explanation for the static tail bias,
      - but they did not resolve the core static `exAL` performance gap,
      - so the next round should stay focused on model/approximation quality rather than launching broader static or dynamic reruns.

Decision rule for this audit:

- do not assume the remaining bias is an optimizer issue just because prior LD stabilization improved convergence
- if the derivation audit finds an inconsistency:
  - patch `main.tex` first or in parallel with the code
  - patch the implementation to match the corrected derivation
  - rerun the minimal static verification before touching dynamic code
- if the derivation audit finds no inconsistency:
  - only then return to model-performance debugging via proposal/approximation quality, initialization, or richer diagnostics

Definition of done for this audit track:

- a written concordance exists between:
  - `exAL_Original.pdf`
  - `main.tex`
  - static `exAL` VB/MCMC code
- the frozen empirical symptom from `T1` is still reproducible from the recorded artifacts
- every suspected discrepancy is labeled as one of:
  - theory typo / omission
  - implementation bug
  - acceptable approximation
  - unresolved but documented
- any true discrepancy has:
  - a committed theory correction and/or code fix
  - a targeted regression test when feasible
  - a rerun on the focused static verification case
  - updated tracker notes on whether the observed tail bias improved
- no proposal retuning or dynamic propagation is done until the focused verification case is reviewed after the derivation/code audit

Follow-on shared-target audit after `T6`:

- [x] U1. Verify that the implemented static `exAL` family reduces cleanly to `AL` at `gamma = 0`.
  - Completed on `2026-03-06`.
  - Script:
    - `tools/merge_reports/20260306_static_exal_shared_issue_u1_u4_audit.R`
  - Output root:
    - `results/sim_suite_static/audits/static_exal_shared_issue_u1_u4_20260306`
  - Key artifacts:
    - `u1_reduction_identity_checks.csv`
    - `u1_quantile_fixed_checks.csv`
  - Result:
    - exact reduction identities passed on `tau in {0.05, 0.50, 0.95}`:
      - `p(gamma = 0) = p0`
      - `A(gamma = 0) = A_AL`
      - `B(gamma = 0) = B_AL`
      - `lambda(gamma = 0) = 0`
    - the implemented observational family is also quantile-fixed:
      - `Q_tau(Y | mu, sigma, gamma) = mu`
      - `P(Y <= mu | mu, sigma, gamma) = tau`
    - implication:
      - the static `exAL` observational layer itself does reduce correctly to `AL`;
      - the current tail gap is not explained by a broken `gamma = 0` reduction in the implemented density map.

- [x] U2. Verify that the static reporting layer is extracting the fitted quantile correctly for `exAL`.
  - Completed on `2026-03-06`.
  - Key artifact:
    - `u2_quantile_path_mapping_checks.csv`
  - Result:
    - the current static plotting / metric path in `R/static_fit_normalization.R` is correct for the implemented quantile-fixed `exAL` family;
    - on the frozen rich and heteroskedastic runs, the direct exAL quantile
      `qexal(tau, p0=tau, mu=X beta, sigma, gamma)` matched the reported path to numerical precision:
      - max absolute difference across all checked cases: `7.11e-15`
    - implication:
      - the observed exAL tail shift is not a plotting or summary-metric artifact caused by using the wrong fitted quantile map.

- [x] U3. Profile the shared exact `gamma` target on the frozen problematic runs.
  - Completed on `2026-03-06`.
  - Key artifacts:
    - `u3_gamma_geometry_profile_summary.csv`
    - `plots/u3_gamma_profile_rich_005_tau_0p05.png`
    - `plots/u3_gamma_profile_rich_095_tau_0p95.png`
    - `plots/u3_gamma_profile_het_005_tau_0p05.png`
    - `plots/u3_gamma_profile_het_095_tau_0p95.png`
  - Result:
    - on both frozen datasets, the exact static `exAL` conditional gamma target strongly prefers nonzero `gamma` over the `AL` submodel (`gamma = 0`):
      - rich static:
        - `tau=0.05`: conditional mode `gamma ~= 5.00`, log-kernel gap vs `gamma=0` `= 12674.58`
        - `tau=0.95`: conditional mode `gamma ~= -4.28`, log-kernel gap vs `gamma=0` `= 12058.14`
      - heteroskedastic static:
        - `tau=0.05`: conditional mode `gamma ~= 2.36`, log-kernel gap vs `gamma=0` `= 10056.82`
        - `tau=0.95`: conditional mode `gamma ~= -5.00`, log-kernel gap vs `gamma=0` `= 12462.74`
    - implication:
      - the problematic saved runs are not merely failing to find the `AL` submodel;
      - the exact exAL target itself is pulling hard toward a nonzero-skew solution on these datasets.

- [x] U4. Run a focused recovery experiment on data generated from the implemented static family.
  - Completed on `2026-03-06`.
  - Key artifacts:
    - `u4_recovery_experiment_summary.csv`
    - `u4_recovery_pairwise_exal_vs_al.csv`
    - `u1_u4_audit_note.md`
  - Settings:
    - `n = 160`
    - `X = [1, x, x^2]`
    - `sigma_true = 0.8`
    - tails:
      - `tau=0.05`, `gamma_true in {0, 0.6}`
      - `tau=0.95`, `gamma_true in {0, -0.6}`
    - focused audit budgets only:
      - `VB max_iter = 180`, `n_samp_xi = 100`
      - `MCMC burn = 120`, `n = 120`
  - Result:
    - `AL`-generated data (`gamma_true = 0`):
      - `exAL` did not collapse relative to `AL`
      - `VB`: essentially tied with `AL`
      - `MCMC`: `exAL` was slightly better than `AL`
    - `exAL`-generated data (`gamma_true != 0`):
      - exact `exAL` `MCMC` recovered better than `AL` at both tails
      - `VB` was mixed:
        - `tau=0.95`: `exAL` slightly better than `AL`
        - `tau=0.05`: `exAL` worse than `AL`
    - implication:
      - the shared static `exAL` implementation is capable of recovering when the DGP actually comes from the implemented family;
      - this substantially weakens the hypothesis of a gross shared implementation bug in the static `exAL` posterior target;
      - remaining concern is more plausibly:
        - mismatch between the current skew-normal / rich static DGPs and the exAL family, and/or
        - additional left-tail approximation / finite-sample fragility in static `exAL` VB.

Current interpretation after `U1-U4`:

- ruled out:
  - broken `gamma=0` reduction
  - wrong static fitted-quantile extraction in plots/tables
  - a gross shared exAL implementation failure that prevents recovery on exAL-generated data
- now most plausible:
  - the poor static exAL performance on the current rich / heteroskedastic datasets is primarily a model-target issue on those DGPs rather than a simple shared coding bug,
  - with a secondary VB-specific weakness still visible in the `tau=0.05` exAL-generated recovery case.
- operational consequence:
  - do not launch more broad static/dynamic reruns yet;
  - next work should focus on:
    - understanding why the exact exAL target prefers strongly nonzero `gamma` on the current non-exAL DGPs,
    - and whether that reflects genuine model mismatch, identifiability, or prior-induced tail geometry.

### Gamma=0 Reduction Audit on the Current Static Review Runs

- [x] G1. Re-check the current observed performance pattern using the latest completed static review runs.
  - Completed on `2026-03-06`.
  - Audit root:
    - `results/sim_suite_static/audits/static_exal_gamma0_reduction_20260306_020757`
  - Key artifacts:
    - `baseline_pattern_by_tau_method.csv`
    - `baseline_pairwise_exal_vs_al.csv`
    - `gamma0_reduction_note.md`
  - Latest scenario basis:
    - rich static:
      - `results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_160734`
    - paired heteroskedastic:
      - `results/function_testing_20260306_static_scale_pair_skewnormal/heteroskedastic/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260306_011944_heteroskedastic_sub5000`
    - paired homoskedastic:
      - `results/function_testing_20260306_static_scale_pair_skewnormal/homoskedastic/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260306_011944_homoskedastic_sub5000`
  - Pattern summary from the completed runs:
    - `tau=0.05`:
      - `VB`: `exAL` worse than `AL` in `1/3` scenarios
      - `MCMC`: `exAL` worse than `AL` in `2/3` scenarios
    - `tau=0.50`:
      - `VB`: `exAL` worse than `AL` in `2/3` scenarios
      - `MCMC`: `exAL` worse than `AL` in `3/3` scenarios
    - `tau=0.95`:
      - `VB`: `exAL` worse than `AL` in `3/3` scenarios
      - `MCMC`: `exAL` worse than `AL` in `3/3` scenarios
  - Interpretation:
    - the poor `exAL` pattern absolutely persists on the current review runs;
    - it is strongest and most stable at the upper tail, and clearly present at the median;
    - the lower tail is mixed, not uniformly worse.

- [x] G2. Constrain `exAL` back to the `gamma=0` submodel and compare against `AL`.
  - Completed on `2026-03-06`.
  - Key artifacts:
    - `gamma0_vb_vs_baseline_comparison.csv`
    - `gamma0_vb_metrics_summary.csv`
    - `gamma_band_reduction_constants.csv`
  - Settings:
    - constrained `VB` audit only
    - `gamma band = [-1e-6, 1e-6]`
    - same `TT`, same design matrix, same truth, same `VB` budgets as each source run
  - Result:
    - in all `9/9` scenario/tau cells, constrained `exAL(gamma≈0)` collapsed back onto the `AL` fit:
      - `gamma_g0` was effectively zero (`|gamma| ~ 1e-10`)
      - `gap_closure_fraction` was `0.998` to `1.000`
      - path gaps versus `AL` were numerically negligible
    - examples:
      - rich static, `tau=0.05`:
        - free `exAL RMSE = 5.7776`
        - `AL RMSE = 1.0284`
        - constrained `exAL(gamma≈0) RMSE = 1.0277`
      - heteroskedastic, `tau=0.95`:
        - free `exAL RMSE = 0.7968`
        - `AL RMSE = 0.3690`
        - constrained `exAL(gamma≈0) RMSE = 0.3690`
      - homoskedastic, `tau=0.95`:
        - free `exAL RMSE = 0.6194`
        - `AL RMSE = 0.0880`
        - constrained `exAL(gamma≈0) RMSE = 0.0880`
  - Interpretation:
    - once `gamma` is forced back to zero, the practical fit gap disappears;
    - this is strong evidence that the observed exAL underperformance is introduced by the nonzero-`gamma` part of the exAL target, not by the reduced `AL` submodel machinery.

- [x] G3. Verify exact shared-update reduction at `gamma=0` for both static `VB` and static `MCMC`.
  - Completed on `2026-03-06`.
  - Key artifacts:
    - `vb_exact_reduction_checks.csv`
    - `mcmc_exact_reduction_checks.csv`
  - Result:
    - `VB` shared-update max diffs:
      - `V_inv <= 1.49e-08`
      - `rhs <= 2.61e-08`
      - `chi <= 3.55e-15`
      - `psi <= 1.42e-14`
      - `q(s)` collapses exactly:
        - `mu = 0`
        - `tau2 = 1`
    - `MCMC` shared-update max diffs:
      - `v-chi = 0`
      - `v-psi <= 1.42e-14`
      - `beta-rhs = 0`
      - `beta-W = 0`
      - `sigma-rate = 0`
      - `q(s)` / `s | rest` collapses exactly:
        - `mu = 0`
        - `tau2 = 1`
  - Interpretation:
    - the shared static `exAL` update equations reduce cleanly to the static `AL` equations at `gamma=0`;
    - the extra `s_i` latent block becomes independent nuisance structure and does not alter the fitted quantile path.

Current interpretation after `G1-G3`:

- ruled out more strongly:
  - a broken `gamma=0` reduction in the shared static `exAL` implementation
  - the hypothesis that `AL`-like performance is lost because of the retained `s_i` latent block alone
- now most plausible:
  - the poor static `exAL` performance comes from how the free-`gamma` exAL posterior behaves on these DGPs,
  - not from a failure of the shared `AL` reduction path
  - practical implication:
  - if `exAL` is forced back to `gamma=0`, it behaves like `AL`;
  - therefore the next debugging stage should focus on:
    - why the exact exAL target prefers large nonzero `gamma` on these non-exAL DGPs,
    - whether the `gamma` prior/support geometry is too permissive,
    - and whether a shrinkage-to-zero `gamma` strategy or stronger model-selection logic is needed.

## 2026-03-06: Static exAL VB sigma/gamma parity update toward qdesn path

- [x] Implement qdesn-style static `VB` sigma/gamma controls in [R/exal_static_LDVB.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/R/exal_static_LDVB.R).
  - Added deterministic `xi_method = "delta"` path as the default local-moment engine for the static exAL `(\sigma,\gamma)` block.
  - Added bounded `optimizer_method = "lbfgsb"` support on transformed `(\eta,\ell)` with finite `eta` and `sigma` region control.
  - Added data-scale sigma initialization / finite sigma bounds / interior gamma initialization via the LD setup helper.
  - Added direct-commit mode for the bounded optimizer path rather than relying on post-hoc damping.
  - Tightened the default covariance cap for the `delta + lbfgsb + direct_commit` path (`eig_cap = 1`) so the Delta approximation remains local and `E[1/\sigma]` does not explode on flat toy geometries.

- [x] Wire the same sigma/gamma controls through the static stack.
  - [R/exal_static_mcmc.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/R/exal_static_mcmc.R):
    - static `VB` warm-start path now accepts `vb_init_controls$ld_controls`
    - returned fit now records `vb.init.controls` when warm start is used
  - [R/static_fit_normalization.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/R/static_fit_normalization.R):
    - normalized static `VB` diagnostics now preserve `ld_block$setup`
  - [tools/merge_reports/20260305_static_vb_then_mcmc_pipeline.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tools/merge_reports/20260305_static_vb_then_mcmc_pipeline.R):
    - pipeline now exposes env-driven LD controls for `xi_method`, optimizer, direct-commit mode, sigma bounds/initialization, eta bounds, covariance initialization, and local covariance cap
  - [tools/merge_reports/20260306_run_static_scale_scenario.sh](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tools/merge_reports/20260306_run_static_scale_scenario.sh):
    - paired static scale experiments now launch with the qdesn-style LDVB defaults

- [x] Regression coverage for the new LDVB sigma/gamma path.
  - Updated / extended:
    - [tests/testthat/test-static-regression-regmod.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tests/testthat/test-static-regression-regmod.R)
    - [tests/testthat/test-static-fit-normalization.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tests/testthat/test-static-fit-normalization.R)
    - [tests/testthat/test-vb-mcmc-convergence-controls.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tests/testthat/test-vb-mcmc-convergence-controls.R)
    - [tests/testthat/test-static-vb-mcmc-pipeline-report-smoke.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tests/testthat/test-static-vb-mcmc-pipeline-report-smoke.R)
  - New coverage now checks:
    - deterministic Delta `xi` behavior,
    - preserved legacy replicated-MC `xi` behavior,
    - bounded-optimizer setup metadata,
    - warm-start LD-control propagation into static `MCMC`,
    - and pipeline/report compatibility under the new sigma/gamma defaults.

- [x] Validation status for the parity implementation.
  - `devtools::document()` completed and regenerated:
    - `man/exal_static_LDVB.Rd`
    - `man/exal_static_mcmc.Rd`
  - Targeted tests:
    - `PASS 104, FAIL 0, WARN 0, SKIP 1`
    - skipped item: sandbox-unavailable pipeline script path in the smoke test harness

- [x] Relaunch paired heteroskedastic / homoskedastic static campaigns with the new LDVB sigma/gamma path.
  - Heteroskedastic run:
    - tmux session: `static_pair_het_qdesn_20260306_111006`
    - log: [20260306_static_pair_heteroskedastic_qdesn_20260306_111006.log](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tools/merge_reports/20260306_static_pair_heteroskedastic_qdesn_20260306_111006.log)
    - run root: [heteroskedastic qdesn-parity run](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/function_testing_20260306_static_scale_pair_skewnormal/heteroskedastic/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260306_111006_heteroskedastic_qdesnvb_sub5000)
  - Homoskedastic run:
    - tmux session: `static_pair_homo_qdesn_20260306_111006`
    - log: [20260306_static_pair_homoskedastic_qdesn_20260306_111006.log](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tools/merge_reports/20260306_static_pair_homoskedastic_qdesn_20260306_111006.log)
    - run root: [homoskedastic qdesn-parity run](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/function_testing_20260306_static_scale_pair_skewnormal/homoskedastic/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260306_111006_homoskedastic_qdesnvb_sub5000)
  - One-time launch health check:
    - both sessions are active
    - all `AL` tasks entered `VB` and immediately moved into `MCMC`
    - `exAL` tasks entered `VB`
    - no immediate startup failures were observed

## 2026-03-06: Dynamic/static sigma-gamma standardization + latent-s diagnostics

- [x] Move dynamic `exDQLM` LDVB sigma/gamma handling toward the stabilized static path.
  - Updated [R/exdqlmLDVB.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/R/exdqlmLDVB.R) to replace the older transformed gamma block with:
    - logistic `eta -> gamma` support handling aligned with static `exAL`,
    - bounded `(\eta,\ell)` mode search with `L-BFGS-B`,
    - data-scale sigma initialization / finite sigma-region setup,
    - robust Hessian-to-covariance regularization via the static LD helpers,
    - direct-commit support for the bounded optimizer,
    - dynamic `ld_block` diagnostics mirroring the static structure.
  - Dynamic LD expectations remain Delta-based, but the optimizer geometry and transformed support now follow the same stabilized design as the static implementation.

- [x] Add latent-`s` trace summaries across the static and dynamic paths.
  - [R/utils.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/R/utils.R):
    - added shared positive truncated-normal moment helper `.exdqlm_pos_truncnorm_moments(...)`
    - added shared trace-summary helper `.exdqlm_trace_summary(...)`
  - [R/exal_static_LDVB.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/R/exal_static_LDVB.R):
    - static `VB` now records `delta_s`
    - added `diagnostics$s_block$trace` with per-iteration summaries of `E[s_i]` and `tau2(s_i)`
  - [R/exal_static_mcmc.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/R/exal_static_mcmc.R):
    - static `MCMC` trace rows now include `s_mean/s_sd/s_q05/s_q50/s_q95` and `s_tau2_*`
  - [R/exdqlmLDVB.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/R/exdqlmLDVB.R):
    - dynamic `VB` now records `delta_s`
    - added `diagnostics$s_block$trace` and `diagnostics$ld_block`
  - [R/exdqlmMCMC.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/R/exdqlmMCMC.R):
    - added a small floor for `s_t` conditional variance
    - added per-iteration latent-`s_t` summary trace rows under `mh.diagnostics$trace`
    - surfaced `diagnostics$s_block` for the dynamic `MCMC` fit
  - [R/static_fit_normalization.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/R/static_fit_normalization.R):
    - normalized static fits now preserve `s_block` in both `VB` and `MCMC`

- [x] Update postprocess scripts so the new latent-`s` diagnostics are visible in outputs.
  - [tools/merge_reports/20260305_postprocess_from_existing_fits.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tools/merge_reports/20260305_postprocess_from_existing_fits.R):
    - dynamic `vb_convergence_summary.csv` now includes `delta_s_last`
    - dynamic `mcmc_diagnostics_summary.csv` now includes average `s_mean` / `s_sd`
    - added `VB` and `MCMC` latent-`s_t` trace plots for `exDQLM`
  - [tools/merge_reports/20260305_static_postprocess_from_existing_fits.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tools/merge_reports/20260305_static_postprocess_from_existing_fits.R):
    - static `vb_convergence_summary.csv` now includes `delta_s_last`
    - static `mcmc_diagnostics_summary.csv` now includes average `s_mean` / `s_sd`
    - added trimmed `VB` and `MCMC` latent-`s_i` trace plots for `exAL`

- [x] Update dynamic pipeline wiring to expose the new dynamic LD controls.
  - [tools/merge_reports/20260305_vb_then_mcmc_pipeline.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tools/merge_reports/20260305_vb_then_mcmc_pipeline.R):
    - added env-driven dynamic LD control parsing
    - added explicit dynamic output-root override support (`EXDQLM_DYNAMIC_OUT_ROOT`)
    - current reruns use the standardized dynamic LD settings by default

- [x] Regression coverage for the new standardized diagnostics path.
  - Updated:
    - [tests/testthat/test-vb-mcmc-convergence-controls.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tests/testthat/test-vb-mcmc-convergence-controls.R)
    - [tests/testthat/test-static-fit-normalization.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tests/testthat/test-static-fit-normalization.R)
  - Targeted validation:
    - `testthat` targeted slice status: `PASS 9, FAIL 0, WARN 0, SKIP 1`
    - skipped item: static pipeline/report smoke test path unavailable in sandbox harness
  - `devtools::document()` completed after the code changes.

- [x] Relaunch standardized background campaigns for current working datasets.
  - Dynamic standardized rerun:
    - tmux session: `dynamic_std_20260306_155302`
    - log: [20260306_dynamic_std_background_20260306_155302.log](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tools/merge_reports/20260306_dynamic_std_background_20260306_155302.log)
    - run root: [dynamic standardized rerun](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/function_testing_20260304_vb_quantiles/rerun_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260306_155302_stdsiggam_sdiag)
    - chained stages: dynamic pipeline -> dynamic postprocess
  - Static standardized heteroskedastic rerun:
    - tmux session: `static_het_std_20260306_155302`
    - log: [20260306_static_heteroskedastic_std_background_20260306_155302.log](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tools/merge_reports/20260306_static_heteroskedastic_std_background_20260306_155302.log)
    - run root: [static heteroskedastic standardized rerun](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/function_testing_20260306_static_heteroskedastic_skewnormal/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260306_155302_stdsiggam_sdiag)
    - chained stages: static pipeline -> static postprocess -> static report
  - One-time launch health check:
    - both `tmux` sessions are active
    - both logs show pipeline startup banners and no immediate crash

## 2026-03-08: Static AL/exAL RHS prior implementation planning contract

### Objective

Add a coefficient-prior option for static `AL` and static `exAL` regression so that both `VB` and `MCMC` support:

- `beta_prior = "ridge"`
- `beta_prior = "rhs"`

The intent is to preserve the current likelihood-side `AL` / `exAL` machinery and extend only the coefficient-prior side in a way that is:

- aligned with the recent qdesn `beta_prior` design,
- backward compatible,
- well documented,
- testable under the current static reporting / diagnostics stack.

### Theory / code sources of record

- Static `exAL` likelihood-side VB theory:
  - `/data/muscat_data/jaguir26/Static-exAL-Regression---VB/main.tex`
- Static `exAL` likelihood-side MCMC theory:
  - `/data/muscat_data/jaguir26/Static-exAL-Regression---MCMC/main.tex`
- Standalone static `exAL` theory:
  - `/data/muscat_data/jaguir26/exAL---Regression/main.tex`
- Static / dynamic `AL` theory:
  - `/data/muscat_data/jaguir26/DQLM-and-BQR---Theory/main.tex`
- VB regularized horseshoe theory:
  - `/data/muscat_data/jaguir26/VB-for-Horseshoe-Regression/main.tex`
- qdesn branch implementation reference for VB RHS:
  - `/data/muscat_data/jaguir26/exdqlm` on branch `feature/model-selection-v2-impl`
  - especially:
    - `R/priors_beta.R`
    - `R/qdesn_rhs_prior.R`
    - `R/exal_ldvb_fit.R`
    - `R/exal_ldvb_engine.R`

### Locked design decisions from user review

- [x] Public API should expose a unified coefficient-prior selector for both static `AL` and static `exAL`.
  - target shape: `beta_prior = c("ridge", "rhs")`

- [x] `RHS` should be implemented as a robust, integrated feature rather than a superficial reduced-path patch.
  - preferred implementation strategy:
    - keep current static public interfaces,
    - support `AL` through the existing reduced `gamma = 0` path,
    - but refactor the internal coefficient-prior handling so the reduced path is first-class and not a fragile special case.

- [x] `RHS` should be zero-centered, matching qdesn / standard shrinkage usage.
  - implication:
    - `b0` applies to `ridge`
    - `b0` does not apply to `rhs`

- [x] Intercept should be excluded from shrinkage by default.
  - default:
    - `shrink_intercept = FALSE`
  - when excluded from shrinkage:
    - use Gaussian prior handling consistent with qdesn-style implementation

- [x] Expose qdesn-style RHS hyperparameters publicly.
  - public controls to support:
    - `tau0`
    - `nu`
    - `s` / `s2`
    - `shrink_intercept`
  - defaults should match qdesn unless a current-package compatibility reason forces a documented deviation

- [x] VB implementation should port the qdesn `beta_prior` object pattern, adapted to current package style.

- [x] VB RHS block should be separate from the current sigma/gamma LD block.
  - do not merge RHS hyperparameters into the current `(sigma, gamma)` LD optimization

- [x] MCMC RHS hyperparameters should be handled with practical log-scale slice updates where appropriate.
  - this matches the current MCMC philosophy better than forcing an unavailable closed-form Gibbs route

- [x] Implementation order should be:
  - `VB` first
  - `MCMC` second

- [x] Validation target after implementation will include:
  - tests
  - smoke runs
  - full static simulation comparisons
  - same reporting / plot style as current static campaigns
  - plus new summaries for RHS latent variables and coefficient tree plots

- [x] Theory / tracker documentation should be updated as part of the implementation pass.

### What is already clear enough to implement

- [x] VB-side RHS theory source is sufficient.
  - `VB-for-Horseshoe-Regression/main.tex` gives the missing clean VB-RHS equations:
    - `D_j = E_q[1 / V_j]`
    - Gaussian `q(beta)` update under `diag(D_j)`
    - LD block on log-scales for RHS hyperparameters
    - practical ELBO structure

- [x] The clean VB architecture is established.
  - keep current static `AL` / `exAL` likelihood-side blocks:
    - `q(v)`
    - `q(s)`
    - sigma/gamma LD block
  - replace only the coefficient-prior side through a qdesn-style `beta_prior` abstraction

- [x] `slice` not appearing in theory docs is not a blocker.
  - it is a kernel choice for nonconjugate univariate conditionals, not a target mismatch

### Main unresolved item before coding

- [x] Finalize the MCMC theory input for RHS hyperparameters in static `AL` / `exAL`.
  - Updated remote theory source:
    - `AntonioAPDL/VB-for-Horseshoe-Regression`
    - local clone: `/data/muscat_data/jaguir26/VB-for-Horseshoe-Regression`
    - current commit reviewed: `2524920`
  - New material now present in [main.tex](/data/muscat_data/jaguir26/VB-for-Horseshoe-Regression/main.tex):
    - full exAL joint log-kernel under RHS
    - exact RHS conditional kernel under exAL
    - transformed log-target on log-scales for the RHS block
    - full AL joint log-kernel under RHS
    - explicit statement that the exact RHS conditional kernel is identical under `AL` and `exAL` once conditioned on `beta`
  - This closes the main missing theory dependency for the MCMC-side RHS implementation.

### Exact input still needed from user for MCMC RHS implementation

The cleanest input needed from the user is a derivation note that gives the RHS hyperparameter target up to proportionality under the static regression posterior.

Minimum acceptable input:

- [x] A clear statement of the static RHS parameterization to use:
  - prior variance form for `beta_j`
  - definitions of `lambda_j`, `tau`, `c^2`
  - any intercept exception rule

- [x] The full conditional / log-kernel up to proportionality for the RHS hyperparameter block given current `beta`.
  - now available in:
    - [main.tex](/data/muscat_data/jaguir26/VB-for-Horseshoe-Regression/main.tex)
  - includes:
    - original-scale conditional kernel
    - original-scale log-kernel
    - transformed log-target on log-scales with Jacobian included

- [x] Confirmation of whether the same RHS hyperparameter block is intended for both static `AL` and static `exAL`.
  - confirmed by the updated theory note:
    - the exact RHS conditional kernel is identical under `AL` and `exAL` once conditioned on `beta`

- [x] Clarification of whether the user wants one-at-a-time scalar slice updates or grouped updates for the RHS hyperparameters.
  - current locked direction:
    - scalar slice for each `log lambda_j`
    - scalar slice for `log tau`
    - scalar slice for `log c^2`

### Practical note on what the user can provide

If the user can provide the RHS latent-variable posterior kernel up to proportionality for the static regression case, that is sufficient to implement the slice sampler.

The most useful concrete deliverable would be:

- a short note with the log-targets for:
  - `\log p(\lambda_j \mid \beta_j, \tau, c^2, \cdots) + const`
  - `\log p(\tau \mid \beta, \lambda, c^2, \cdots) + const`
  - `\log p(c^2 \mid \beta, \lambda, \tau, \cdots) + const`
- or the same targets transformed to log-scales with Jacobians included

That is enough to build slice updates robustly.

### Additional user-side design clarifications now locked

- [x] If `b0` / `V0` are passed together with `beta_prior = "rhs"`, issue a warning that they are ignored for the shrunk coefficients.

- [x] Coefficient-tree plots are required for `rhs` runs only.
  - no need to generate them for ordinary `ridge` runs by default

### Implementation checklist and current status

- [x] `R1` API / object design for coefficient priors
  - added shared internal prior abstraction in:
    - [R/static_beta_prior.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/R/static_beta_prior.R)
  - supports:
    - `beta_prior = "ridge"`
    - `beta_prior = "rhs"`
  - preserves current ridge behavior
  - adds warning when `b0` / `V0` are passed with `beta_prior = "rhs"`

- [x] `R2` Static `VB` support for `rhs`
  - implemented for:
    - static `exAL` in [R/exal_static_LDVB.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/R/exal_static_LDVB.R)
    - reduced static `AL` path in [R/utils.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/R/utils.R)
  - design kept as planned:
    - separate RHS LD block
    - current sigma/gamma LD block unchanged

- [x] `R3` Static `VB` / reporting plumbing for RHS
  - normalized RHS metadata added in:
    - [R/static_fit_normalization.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/R/static_fit_normalization.R)
  - static postprocess / report now emit RHS-aware tables and plots in:
    - [tools/merge_reports/20260305_static_postprocess_from_existing_fits.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tools/merge_reports/20260305_static_postprocess_from_existing_fits.R)
    - [tools/merge_reports/20260305_static_vb_mcmc_report.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tools/merge_reports/20260305_static_vb_mcmc_report.R)
  - RHS-only coefficient tree plots added for report generation

- [x] `R4` Static `MCMC` support for `rhs`
  - implemented in [R/exal_static_mcmc.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/R/exal_static_mcmc.R)
  - shared RHS slice block now updates:
    - `log lambda_j`
    - `log tau`
    - `log c^2`
  - same prior-side sampler works for:
    - static `AL`
    - static `exAL`

- [x] `R5` Documentation / theory update
  - roxygen updated for public static VB/MCMC interfaces
  - `devtools::document()` regenerated:
    - [man/exal_static_LDVB.Rd](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/man/exal_static_LDVB.Rd)
    - [man/exal_static_mcmc.Rd](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/man/exal_static_mcmc.Rd)
  - tracker section updated to reflect implemented design

- [x] `R6` Validation ladder
  - unit / targeted tests passed
  - full package test suite passed
  - manual RHS pipeline -> postprocess -> report smoke passed on a tiny static run
  - remaining work after this feature pass is scientific validation, not feature wiring

### 2026-03-08 static exAL VB + RHS tail collapse audit

Frozen baseline roots:
- ridge arm:
  - [static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260308_141742_shrink_ridge](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/function_testing_20260308_static_homoskedastic_shrinkage_gaussian/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260308_141742_shrink_ridge)
- rhs arm:
  - [static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260308_141742_shrink_rhs](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/function_testing_20260308_static_homoskedastic_shrinkage_gaussian/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260308_141742_shrink_rhs)
- compare root:
  - [shrinkage_compare_20260308_141742](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/function_testing_20260308_static_homoskedastic_shrinkage_gaussian/shrinkage_compare_20260308_141742)
- targeted audit:
  - [static_exal_rhs_tail_collapse_20260308](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/sim_suite_static/audits/static_exal_rhs_tail_collapse_20260308)

Audit conclusion:
- The static `exAL` `VB + RHS` failure at `tau = 0.05` and `tau = 0.95` is a genuine collapse regime, not merely weak tail fit.
- The RHS global scale collapses to essentially zero while the slope coefficients are numerically shrunk to zero.
- The intercept remains active and absorbs the tail shift, producing a degenerate fitted surface.

Concrete evidence from the frozen baseline:
- `rhs_diagnostics_summary.csv` shows for static `exAL` `VB + RHS`:
  - `tau = 0.05`: `rhs_tau = 4.24864984155777e-18`
  - `tau = 0.95`: `rhs_tau = 4.24864984155777e-18`
- The targeted audit summary confirms:
  - `tau = 0.05`: `slope_max_abs < 1e-6`, collapse signature `TRUE`
  - `tau = 0.95`: `slope_max_abs < 1e-6`, collapse signature `TRUE`
- Coefficient recovery tables show that nearly all non-intercept coefficients are effectively zero under the failed tail `VB + RHS` fits.

Interpretation:
- This matches the qdesn-side collapse pattern where the RHS global shrinkage level can become too aggressive.
- The current `tau0 = 1` default is not automatically safe for tail `exAL` `VB` in this static setup.
- The failure is localized:
  - static `AL + RHS` is behaving reasonably,
  - static `exAL + RHS` `MCMC` is behaving reasonably,
  - the main blocker is static `exAL + RHS` `VB` in the tails.

Focused debugging outcome:
- [x] Added an explicit collapse diagnostic / warning to static `VB + RHS` outputs when:
  - `rhs_tau` is near zero, and
  - the slope vector norm / max absolute slope is effectively zero.
- [x] Implemented qdesn-style tau warmup/freeze scheduling in the shared static RHS VB prior block:
  - `freeze_tau_iters`
  - `freeze_tau_warmup_iters`
  - `update_every`
  - `update_every_warmup`
  - `update_every_warmup_iters`
  - `force_tau_after_warmup`
- [x] Kept the debug scope localized:
  - no changes to the static `AL + RHS` likelihood path
  - no changes to the static `exAL + RHS` `MCMC` likelihood path

### 2026-03-08 static exAL VB + RHS warmup/freeze recheck

Targeted recheck root:
- [static_exal_rhs_tail_warmfreeze_recheck_20260308](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/sim_suite_static/audits/static_exal_rhs_tail_warmfreeze_recheck_20260308)

Recheck conclusion:
- The qdesn-style tau warmup/freeze stage prevented the previously observed static `exAL` `VB + RHS` tail collapse on the frozen high-dimensional shrinkage dataset.
- The same tail cases (`tau = 0.05`, `0.95`) now retain nonzero signal coefficients, keep zero coefficients small, and converge with finite nonzero RHS global scale.

Concrete evidence from `warmfreeze_recheck_summary.csv`:
- `tau = 0.05`
  - baseline `rhs_tau = 4.24864984155777e-18`
  - warmup/freeze `rhs_tau = 0.0867720651786426`
  - baseline signal mean abs estimate `= 1.02790622132233e-33`
  - warmup/freeze signal mean abs estimate `= 0.721571978207561`
  - warmup/freeze zero mean abs estimate `= 0.00445551564104866`
- `tau = 0.95`
  - baseline `rhs_tau = 4.24864984155777e-18`
  - warmup/freeze `rhs_tau = 0.0838155997165169`
  - baseline signal mean abs estimate `= 1.03605591418165e-33`
  - warmup/freeze signal mean abs estimate `= 0.69675527902913`
  - warmup/freeze zero mean abs estimate `= 0.00250496334651129`

Interpretation:
- The failure mode was genuinely a tau-collapse regime.
- The warmup/freeze schedule addresses that mechanism directly.
- The next gate is broader RHS validation using the stabilized schedule, rather than more localized tail debugging.

### 2026-03-08 broader static RHS validation rerun after warmup/freeze

Updated RHS run root:
- [static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260308_154217_shrink_rhs_warmfreeze](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/function_testing_20260308_static_homoskedastic_shrinkage_gaussian/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260308_154217_shrink_rhs_warmfreeze)

Updated `ridge vs rhs` compare root:
- [shrinkage_compare_20260308_154217_warmfreeze](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/function_testing_20260308_static_homoskedastic_shrinkage_gaussian/shrinkage_compare_20260308_154217_warmfreeze)

Rerun conclusion:
- The stabilized warmup/freeze schedule removed the catastrophic `static exAL VB + RHS` tail-collapse failure in the broader high-dimensional shrinkage campaign.
- The remaining `exAL` failures are no longer coefficient-collapse failures; they revert to the expected signoff gates:
  - weak `gamma` mixing / ESS in `MCMC`
  - LD stability gate failures in `VB`

Concrete before/after improvement for `static exAL VB + RHS`:
- `tau = 0.05`
  - previous `beta_rmse_signal = 0.855131568824353`
  - rerun `beta_rmse_signal = 0.0142199704035757`
  - previous `mean_abs_est_zero = 5.44074821497885e-35`
  - rerun `mean_abs_est_zero = 0.00445551565574937`
  - previous `support_tpr_signal = 0`
  - rerun `support_tpr_signal = 1`
- `tau = 0.95`
  - previous `beta_rmse_signal = 0.855131568824353`
  - rerun `beta_rmse_signal = 0.0181885978846463`
  - previous `mean_abs_est_zero = 5.14879301533093e-35`
  - rerun `mean_abs_est_zero = 0.00250496334842183`
  - previous `support_tpr_signal = 0`
  - rerun `support_tpr_signal = 1`

Broader interpretation:
- `AL + RHS` remains strong.
- `exAL + RHS` `MCMC` remains promising.
- `exAL + RHS` `VB` no longer collapses in the tails under the stabilized tau schedule.
- Remaining `exAL` signoff failures are now scientifically interpretable and comparable to the non-RHS extended-model issues, rather than being dominated by prior-collapse pathology.

Current gate status on the updated RHS run:
- `AL` rows: all pass.
- `exAL` rows:
  - `tau = 0.05`: fails on low `ESS_sigma`, low `ESS_gamma`, and LD stability gate
  - `tau = 0.50`: fails on low `ESS_gamma` and LD stability gate
  - `tau = 0.95`: fails on low `ESS_sigma`, low `ESS_gamma`, and LD stability gate
- `rhs_collapse_flag_count = 0`

Next validation gate:
- [x] Rerun the broader static RHS shrinkage validation arm with the stabilized warmup/freeze schedule recorded explicitly in the run configuration.
- [x] Rebuild the `ridge vs rhs` shrinkage comparison outputs against the frozen ridge baseline.
- [ ] Decide whether to relax or redesign the current LD stability gate for `RHS` tail `exAL VB`, now that collapse is gone but the tail traces remain highly variable.

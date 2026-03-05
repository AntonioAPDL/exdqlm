# DQLM/AL Implementation Tracker (Static + Dynamic, MCMC + VB-CAVI)

## Document Control

- Status: Reduced-model + convergence-hardening implementation completed; full refit/figure regeneration executed, with final exDQLM convergence-gate signoff still pending. A new long-budget dynamic rerun is currently in progress (VB->MCMC, 6 tasks), and a static exAL/AL parity workstream is now queued for planning.
- Active implementation branch: `jaguir26/dqlm-conjugacy-cavi-gibbs`
- Baseline source branch for parity: `cransub/0.4.0` at `e18710a`
- Date: 2026-03-04
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

## In-Flight Dynamic Rerun (Background, No Live Monitoring)

Rerun requested and launched to re-evaluate DQLM/exDQLM under a longer burn-in and VB-first initialization:

- script: `tools/merge_reports/20260305_vb_then_mcmc_pipeline.R`
- tmux session: `vb_mcmc_rerun_bg`
- run root: `results/function_testing_20260304_vb_quantiles/rerun_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260304_183508/`
- fixed settings:
  - `TT=5000`
  - VB: `n.samp=1000` (run first for each model/tau)
  - MCMC: `n.burn=2000`, `n.mcmc=1000`
  - parallel layout: 6 cores (one pipeline per model/tau task)
  - MCMC initialization: `init.from.vb=TRUE` with per-task `vb_init_fit`

Status snapshot (`2026-03-04 19:13:58 PST`):

| Model | Tau | Last stage | Stage timestamp | Notes |
|---|---:|---|---|---|
| DQLM | 0.05 | `MCMC_START` | `2026-03-04 18:40:42` | VB done (`runtime_sec=205.5`, `df=0.9950`) |
| DQLM | 0.50 | `MCMC_START` | `2026-03-04 18:40:27` | VB done (`runtime_sec=191.0`, `df=0.9950`) |
| DQLM | 0.95 | `MCMC_START` | `2026-03-04 18:40:36` | VB done (`runtime_sec=196.7`, `df=0.9950`) |
| exDQLM | 0.05 | `MCMC_START` | `2026-03-04 18:43:27` | VB done (`runtime_sec=354.8`, `df=0.9950`) |
| exDQLM | 0.50 | `MCMC_START` | `2026-03-04 18:41:29` | VB done (`runtime_sec=236.5`, `df=0.9950`) |
| exDQLM | 0.95 | `MCMC_START` | `2026-03-04 18:43:33` | VB done (`runtime_sec=361.6`, `df=0.9950`) |

Aggregate snapshot (`2026-03-04 19:13:58 PST`):

- VB done: `6/6`
- MCMC started: `6/6`
- MCMC done: `0/6`
- failed: `0/6`
- process health: parent + 6 worker R processes active

## Remaining Work (Dynamic Scope)

Checklist to close current DQLM/exDQLM dynamic signoff once the in-flight run finishes:

- [ ] wait for background rerun completion (`MCMC_DONE` for all 6 tasks, no failures).
- [ ] run post-processing on the new rerun outputs:
  - regenerate unified tables (`fit_summary`, `metrics_summary`, `vb_convergence_summary`, `mcmc_diagnostics_summary`).
  - regenerate figures (within/between inference + traces) from this rerun only.
- [ ] evaluate final exDQLM gamma/sigma mixing gate on this long-burn run (ESS + acceptance + trace quality).
- [ ] lock final dynamic defaults:
  - final MH strategy (`rw` vs `laplace_rw`) for exDQLM.
  - final VB stop defaults (joint ELBO/sigma/gamma tolerances).
- [ ] close remaining dynamic tracker gates and record exact final reproducible configuration.

## New Requested Scope (Planned): Static exAL vs AL Parity Campaign

User-requested extension (planning/documentation now; implementation deferred):

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
- dataset specification details are explicitly pending and must be discussed/locked before coding.

Proposed phase checklist for this new static campaign:

### Phase S1: Static Simulation Spec + Data Generator Plan

- [ ] locate and document dynamic simulation generator source used for current `sim_output.rds`.
- [ ] draft static simulation schema mirroring dynamic data object structure.
- [ ] define target true quantile functions and noise configuration for AL/exAL stress testing.
- [ ] lock spec with explicit seed, TT/grid, covariates, and saved artifacts.

### Phase S2: Static VB/MCMC Interface Normalization

- [ ] align static fit return objects with dynamic-style diagnostics fields where possible.
- [ ] align status logging and run metadata for static pipelines.
- [ ] ensure backward-compatible function interfaces.

### Phase S3: Static exAL/AL VB->MCMC Pipeline (3 Quantiles)

- [ ] implement/prepare orchestrated run script for 6 static tasks:
  - `{AL, exAL} x {0.05, 0.50, 0.95}`
  - VB first, then MCMC seeded from VB fit.
- [ ] support parallel execution with one task per core.
- [ ] persist per-task status files and unified summary table.

### Phase S4: Static Comparison and Signoff Gates

- [ ] generate static comparison tables/plots (VB vs MCMC, AL vs exAL).
- [ ] add convergence/mixing diagnostics summary and explicit acceptance gates.
- [ ] add/extend tests for static reduced/full parity paths and diagnostics integrity.
- [ ] update tracker with final static campaign settings and closure status.

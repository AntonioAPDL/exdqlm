# TRACK: Online VB-LD CAVI for Q-DESN (Single Quantile)

Date: 2026-02-23
Owner: Q-DESN single-quantile online extension
Status: Core online implementation + tests added (offline path preserved)

## 0) Scope and constraints

- Single quantile `p0` only.
- No parallel quantile grid, no synthesis, no multivariate extension.
- This tracker covers:
  - mathematical consistency audit between manuscript online section and existing batch code,
  - implementation plan, staging, tests, diagnostics, and health checks.
- Current repo now includes the first implementation increment of online VB-LD (single quantile).

## Update (implemented now)

- Added online module: `R/exal_online_vbld.R`
  - `exal_online_init()`
  - `exal_online_step()`
  - `exal_online_predict_quantile()`
  - `exal_online_run()`
  - `exal_online_health_check()`
  - `exal_online_trace_diagnostics()`
  - `exal_online_fit()` (returns `exal_vb`-compatible object with `misc$online` metadata)
- Added exports in `NAMESPACE`.
- Added tests: `tests/testthat/test-online-vbld.R`.
- Added shared internal helper modules:
  - `R/exal_online_step.R` (shared local `q(v_t), q(s_t)` updates)
  - `R/exal_online_state.R` (shared `barw/barm` and natural-stat accumulation helpers)
- Added Stage 1/2 equivalence tests:
  - `tests/testthat/test-online-vbld-batch-equivalence.R`
- Added Stage-0 benchmark module + runner:
  - `R/exal_online_stage0.R`
  - `scripts/online_vbld_stage0_baseline.R`
  - `tests/testthat/test-online-stage0.R`
- Verified:
  - online test file passes,
  - full `tests/testthat` suite passes,
  - strict streaming stability checks pass,
  - windowed online (`M=K=1`, large `W`) tracks batch very closely in deterministic test,
  - runner path is equivalent to manual stepping,
  - health-check utility returns finite/SPD diagnostics,
  - per-step trace includes pre-update check-loss/coverage,
  - solver diagnostics include jitter/fallback counters,
  - Stage-0 baseline can read defaults from `config/defaults.yaml` (`vb.online`).
  - pipeline gating implemented in `scripts/pipeline_sim_main.R` and `scripts/pipeline_real_main.R` via `vb.online.enabled` (default remains offline).
  - shared local and natural-stat helpers are now used by both batch and online paths,
  - Stage 1/2 equivalence tests pass.

## 1) Repo map (current batch VB-LD wiring)

### 1.1 Entrypoints and pipeline wiring

- `R/qdesn_vb.R`
  - `qdesn_fit_vb()` builds deterministic DESN features and calls exAL LDVB readout fit for a single `p0`.
- `R/exal_ldvb_fit.R`
  - `exal_ldvb_fit()` validates inputs, configures priors/control, calls `exal_ldvb_engine()`.
- `R/exal_ldvb_engine.R`
  - canonical batch CAVI + Laplace-Delta engine for the exAL readout (single quantile per call).

### 1.2 Core update blocks

- Local factors:
  - `q(v_t)`: `R/exal_ldvb_engine.R:801` onward.
  - `q(s_t)`: `R/exal_ldvb_engine.R:826` onward.
- Global beta update:
  - `update_qbeta()` in `R/exal_ldvb_engine.R:543`.
- Nonconjugate global block `(sigma,gamma)`:
  - transformed log-kernel `log_qsiggam()` in `R/exal_ldvb_engine.R:710`.
  - mode/Hessian update `find_mode_ld()` in `R/exal_ldvb_engine.R:737`.
  - moment map `compute_xi_fast()` in `R/exal_ldvb_engine.R:611`.
- Regularized horseshoe global block `(lambda, tau, c2)`:
  - prior object builder in `R/priors_beta.R`.
  - Laplace state and moments in `R/qdesn_rhs_prior.R`.
  - consumed by engine through `beta_prior_obj$expected_prec/update/elbo`.
- ELBO evaluation:
  - `compute_elbo_current()` in `R/exal_ldvb_engine.R:951`.

### 1.3 Moment cache / M-operator analog in code

- Theory uses Laplace-Delta operator `\mathcal{M}_i[\cdot]`.
- Code-level analog:
  - `(sigma,gamma)` moments packed in `xis` via `compute_xi_fast()` (`R/exal_ldvb_engine.R:611`).
  - RHS moments from `beta_prior_obj$expected_prec()` (`R/qdesn_rhs_prior.R:504`).
- Utility support:
  - exAL constants and special-function helpers in `R/00_utils.R`.

### 1.4 Manuscript section under audit

- `Q-DESN---Theory-for-implementation/main.tex`
  - section marker: `\section{Online / Streaming VB--LD CAVI Updates}`
  - label: `\label{sec:online_vbld}`

## 2) Math and consistency audit (manuscript online section vs existing code)

## 2.1 Formula map and verdict

| Online manuscript item | Code counterpart | Consistency verdict |
|---|---|---|
| `\bar w_t = E[1/(\sigma B(\gamma) v_t)]` | `W = xi1 * qv$m_inv`, `xi1 = E[1/(\sigma B)]` (`R/exal_ldvb_engine.R:544`, `R/exal_ldvb_engine.R:618`) | Consistent under mean-field factorization |
| `\bar m_t = E[(y_t-\sigma C|\gamma| s_t - A v_t)/(\sigma B v_t)]` and factored split | `rhs = X^T(Wy) - X^T(xi_lambda*qv_inv*qs_m) - xi_A*colSums(X)` (`R/exal_ldvb_engine.R:556`) | Consistent; algebra matches exact split under MF independence |
| Local `q(v_t)` with `\bar\psi_t,\bar\chi_t` | `psi = xi_A2 + 2*xi_siginv`; `chi = ...` (`R/exal_ldvb_engine.R:807`, `R/exal_ldvb_engine.R:810`) | Consistent with batch derivation using current moments |
| Local `q(s_t)` with `\bar a_t,\bar b_t` | `tau2 = 1/(1 + xi_lambda2*qv_inv)`, `mu_s = tau2*(xi_lambda*qv_inv*(y-xb) - zeta_lam)` (`R/exal_ldvb_engine.R:828`, `R/exal_ldvb_engine.R:831`) | Consistent with theory definitions (`eq:vb-abar`, `eq:vb-bbar`) |
| `P_t,h_t` natural recursion | Implied by batch `Prec = X'WX + diag(prec_diag)` and `rhs = X'\bar m` (`R/exal_ldvb_engine.R:553`, `R/exal_ldvb_engine.R:556`) | Consistent derivation; implemented in online state updates |
| Diagonal adjustment from `\bar D_t^{-1}-\bar D_{t-1}^{-1}` | `prec_diag <- beta_prior_obj$expected_prec(...)` (`R/exal_ldvb_engine.R:547`) | Consistent; implemented on scheduled RHS refresh in online updater |
| Window correction of `P,h` by replacing old/new per-datum messages | Equivalent to correcting sufficient stats `S=\sum \bar w x x^T`, `g=\sum \bar m x` | Mathematically consistent |

## 2.2 Key notational mismatches to keep explicit

- `lambda` overload in code:
  - exAL cross-term uses `lam = C(gamma)*|gamma|` in `R/exal_ldvb_engine.R:605` (named `xi_lambda` family).
  - horseshoe local scales use `lambda_j` in `R/qdesn_rhs_prior.R`.
- transformed `(sigma,gamma)` coordinates:
  - manuscript often uses `(rho,xi)`.
  - code uses `(ell,eta)` ordering in places: `ell=log sigma`, `eta=logit-like gamma coordinate`.
- manuscript `\bar D^{-1}` vs code `prec_diag` from `beta_prior_obj$expected_prec`.

Action for implementation docs/comments:
- always refer to exAL term as `lam_exal = C(gamma)*|gamma|` in new online code to avoid collision with horseshoe `lambda_j`.

## 2.3 Hidden assumptions (must be explicit in implementation)

- Mean-field independence is required for the factorized `\bar w_t` and `\bar m_t` expressions:
  - `q_{\sigma,\gamma}` independent of `q_{v_t}`, `q_{s_t}`.
  - `q_{v_t}` independent of `q_{s_t}`.
- `\bar\chi_t` update uses Gaussian `q_beta` moments (`E[(x_t^T beta)^2]` via mean + variance term), consistent with code term `q_i`.
- Strict streaming recursion is exact only for fixed historical messages:
  - when `(sigma,gamma)` refresh changes global moments, old per-datum messages are stale unless revisited/corrected.
- Windowed refresh introduces an intentional approximation when only a rolling window is re-optimized.

## 2.4 Mathematical issues found

Critical algebra errors found: none.

Important clarifications to keep in tracker/implementation:

- `\bar m_t` factorization in the manuscript is correct as written; no missing term.
- `P_t` diagonal RHS adjustment is correct and corresponds to updating prior precision contribution when `q_{lambda,tau,c^2}` is refreshed.
- Window correction formulas are correct for maintaining natural sufficient statistics (`S,g`) consistency.
- The phrase "additional approximation comes solely from not revisiting past locals" is slightly too narrow once scheduled global refreshes and finite windows are used; there is also approximation from stale/restricted historical contributions unless corrected.

## 2.5 RHS precision moment consistency

- Current code keeps `E_q[1/V_j]` on the same second-order delta-method
  approximation used by the offline engine:
  - `R/qdesn_rhs_prior.R:523` onward.
- This matches the current theory and repo policy: RHS precision moments are
  handled through Laplace-Delta approximations.
- Any online RHS refresh therefore inherits the same approximation policy as the
  offline fit.

## 3) Proposed online architecture (single quantile)

## 3.1 New state object (persistent, explicit)

Proposed object: `online_vbld_state` (R list + class) with fields:

- data/model dims:
  - `k` (readout dimension), `p0`, `gamma_bounds`, `t_current`.
- global factors:
  - `qbeta` with `mu`, `Sigma`, and natural params `P`, `h`.
  - `qsiggam` with transformed mode/cov and cached `xis` moments.
  - `beta_prior_state` (RHS/ridge latent state from `beta_prior_obj$init/update`).
- local current (and optional window cache):
  - current datum moments `E_v_t`, `E_inv_v_t`, `E_s_t`, `E_s2_t`.
  - optional ring buffer for last `W` entries: `x_i`, `barw_i`, `barm_i`, local moments.
- schedules + controls:
  - `M`, `K`, `W`, `L_loc` and tolerances/jitter.
- diagnostics:
  - running counters, failures, PD/jitter events, optional rolling metrics.

## 3.2 New function boundaries

- `online_state_init(...)`
  - builds initial state from batch warm-start output (single `p0`).
- `online_local_update(state, y_t, x_t, L_loc, ...)`
  - updates only new `q(v_t), q(s_t)` with small alternations.
- `online_messages_from_local(state, y_t, x_t)`
  - computes `barw_t`, `barm_t` using current global moments.
- `online_beta_rank1_update(state, x_t, barw_t, barm_t, dbar_delta = NULL)`
  - updates `P,h` and solves for `(mu,Sigma)`.
- `online_refresh_rhs(state)`
  - scheduled `q_{lambda,tau,c2}` refresh and diagonal `P` adjustment.
- `online_refresh_sigmagam(state, window_idx = NULL)`
  - scheduled `(sigma,gamma)` refresh; window mode optional.
- `step_online(state, y_t, x_t, ...)`
  - orchestration: local updates -> messages -> beta update -> refresh hooks.

## 3.3 Suggested file layout

- New core online modules:
  - `R/exal_online_state.R`
  - `R/exal_online_step.R`
  - `R/exal_online_refresh.R`
  - `R/exal_online_diagnostics.R`
- Reuse existing modules without duplication:
  - `R/exal_ldvb_engine.R` logic extraction targets
  - `R/qdesn_rhs_prior.R` and `R/priors_beta.R`
  - `R/00_utils.R` SPD/GIG helpers

## 4) Schedules and config wiring (M, K, W, L_loc)

Recommended defaults for first implementation:

- `L_loc = 2`
- `M = 5` (RHS refresh every 5 arrivals)
- `K = 20` (`K >= M`)
- `W = 0` strict mode default; `W = 100` windowed recommended mode

Config wiring target:

- add under `vb.online` in `config/defaults.yaml`:
  - `enabled`, `strict`, `M`, `K`, `W`, `L_loc`, `jitter`, `chol_rank1`.
- pass through in `scripts/pipeline_sim_main.R` and `scripts/pipeline_real_main.R`.

## 5) Testing plan (single quantile)

## 5.1 Deterministic fixtures

- Add deterministic small-data generator (single quantile) using fixed seed:
  - short simulated series + fixed design matrix `X` for direct engine testing.
- Add one persisted tiny fixture (`n <= 120`, moderate `k`) for reproducible CI-like checks.

Proposed test files:

- `tests/testthat/test-online-vbld-smoke.R`
- `tests/testthat/test-online-vbld-batch-equivalence.R`
- `tests/testthat/test-online-vbld-window-corrections.R`
- optional helper: `tests/testthat/helper-online-fixtures.R`

## 5.2 Required comparisons

- (i) Near-batch equivalence regime:
  - windowed mode with `W = T`, `M = 1`, `K = 1`, and full local backfit in window.
  - check online vs batch closeness for `mu_beta`, `diag(Sigma_beta)`, and key `xis` moments within tolerance.
- (ii) Strict streaming stability regime:
  - `W = 0`, scheduled refreshes.
  - assert no NaN/Inf, SPD preserved, bounded moments, no exploding drift.

## 5.3 Smoke and numerical-stability tests

- SPD checks for `P_t` at every step.
- Cholesky update success rate and fallback jitter count.
- positivity checks:
  - `barw_t > 0`, RHS `prec_diag > 0`, `E[v_t] > 0`, `E[1/v_t] > 0`, `E[s_t] > 0`, `E[s_t^2] > 0`.
- finite checks for all `xi_*` and `zeta_*` moments.

## 5.4 Predictive diagnostics for health checks

- rolling empirical coverage at target quantile `p0`.
- rolling check-loss trend.
- `||mu_beta_t - mu_beta_{t-1}||_2` drift monitor.
- optional ELBO-proxy trend (or objective surrogate) for scheduled refresh steps.

## 6) Incremental implementation stages (with stopping rules)

## Stage 0: Baseline snapshot

- Implemented:
  - deterministic baseline utility in `R/exal_online_stage0.R`:
    - `exal_online_stage0_benchmark()`
    - `exal_online_stage0_write_artifacts()`
  - CLI runner in `scripts/online_vbld_stage0_baseline.R`.
  - tests in `tests/testthat/test-online-stage0.R`.
- Test status:
  - reproducible hash check implemented and passing (`hashes_equal = TRUE`).
  - key metrics persisted to RDS/JSON + trace CSV artifacts.
- Files:
  - `R/exal_online_stage0.R`
  - `scripts/online_vbld_stage0_baseline.R`
  - `tests/testthat/test-online-stage0.R`
- Stop rule status:
  - satisfied (same-seed repeat run produces identical hash).

Reference command (validated):

```bash
Rscript scripts/online_vbld_stage0_baseline.R \
  --out_dir results/online_vbld/stage0_baseline \
  --seed 20260223 --n 72 --k 5 --t0 48 --p0 0.5 \
  --check_repro true --write_trace true
```

Latest reference outputs:
- `results/online_vbld/stage0_baseline/stage0_baseline_summary.rds`
- `results/online_vbld/stage0_baseline/stage0_baseline_summary.json`
- `results/online_vbld/stage0_baseline/stage0_run1_trace.csv`
- `results/online_vbld/stage0_baseline/stage0_run2_trace.csv`

## Stage 1: Factorize per-time local updates

- Implement:
  - extract local update routines (`q(v_t), q(s_t)`) from engine into reusable functions.
- Test:
  - extracted functions reproduce batch local moments on fixed snapshots.
- Files:
  - new `R/exal_online_step.R` + small refactor in `R/exal_ldvb_engine.R` (function reuse only).
- Stop rule:
  - no behavior change in batch path.

## Stage 2: Natural-parameter accumulation in batch mode first

- Implement:
  - compute `S = sum barw x x^T`, `g = sum barm x` and reconstruct `P,h` in batch code path.
- Test:
  - equivalence with current direct `X'WX` and `X'\bar m` formulation.
- Files:
  - `R/exal_ldvb_engine.R` (internal helper only), new utility in `R/exal_online_state.R`.
- Stop rule:
  - exact/near-exact equality under tolerance.

## Stage 3: `step_online` strict mode with frozen globals

- Implement:
  - online step with local updates + `P,h` rank-1 update only.
  - keep `(sigma,gamma)` and RHS fixed.
- Test:
  - stability smoke tests and deterministic replay.
- Files:
  - `R/exal_online_state.R`, `R/exal_online_step.R`, tests.
- Stop rule:
  - stable over long stream, no SPD failures.

## Stage 4: Add scheduled RHS refresh (`M`) + diagonal `P` adjustment

- Implement:
  - hook `beta_prior_obj$update/expected_prec` on schedule.
  - apply `diag(\bar D_t^{-1} - \bar D_{t-1}^{-1})` to `P`.
- Test:
  - consistency check against recomputed `P = S + Dbar` at refresh times.
- Files:
  - `R/exal_online_refresh.R`, `R/qdesn_rhs_prior.R` reuse only, tests.
- Stop rule:
  - residual `||P - (S + Dbar)||` below tolerance after every refresh.

## Stage 5: Add scheduled `(sigma,gamma)` refresh (`K`) without window

- Implement:
  - warm-started Laplace refresh of `qsiggam` and `xis` every `K` steps.
- Test:
  - finite moments and stable behavior; drift diagnostics tracked.
- Files:
  - `R/exal_online_refresh.R`, diagnostics tests.
- Stop rule:
  - no pathological divergence across benchmark streams.

## Stage 6: Add window buffer and window correction of `P,h`

- Implement:
  - ring buffer of last `W` messages/locals.
  - optional 1-2 local backfit passes on window and correction formulas for `P,h`.
- Test:
  - online-window variant approaches batch trajectory when `W=T`, `M=K=1`.
- Files:
  - `R/exal_online_state.R`, `R/exal_online_step.R`, `R/exal_online_refresh.R`, tests.
- Stop rule:
  - quantified closeness to batch achieved on fixture within predefined tolerance.

## 7) Coding standards for implementation

- deterministic seeds in all tests and baseline scripts.
- no hidden global state; explicit inputs/outputs for every online step.
- avoid expensive recomputation:
  - maintain `P,h` and optional Cholesky factor.
- numerical stability:
  - rank-1 Cholesky updates when possible,
  - jitter fallback + explicit diagnostics counter.
- preserve single-quantile path minimalism first.
- no new heavy dependencies unless strictly necessary.

## 8) Risks and open questions

- Approximation risk:
  - strict streaming with infrequent refresh can accumulate stale-message error.
- Large-`k` complexity:
  - full `Sigma` maintenance may be expensive; prefer storing Cholesky of `P` and solving linear systems.
- Schedule sensitivity:
  - `M,K,W,L_loc` tuning may be data-dependent; include health checks and default-safe profiles.
- Compatibility risk:
  - avoid breaking current batch APIs and model-selection pipelines.

## 9) Health-check checklist (runtime)

- [x] `P_t` SPD at every step.
- [x] no NaN/Inf in `mu_beta`, `Sigma_beta`, `xis`, local moments.
- [x] bounded jitter usage frequency.
- [x] rolling check-loss and coverage within reasonable range.
- [x] periodic snapshot compare: online state vs batch recompute on same prefix.

## 10) Execution order for the next implementation pass

- [x] Complete Stage 0 and commit baseline artifacts.
- [x] Complete Stage 1 and Stage 2 with no batch-regression.
- [x] Implement Stage 3 strict mode and stabilize.
- [x] Add Stage 4 and Stage 5 scheduled refreshes.
- [x] Add Stage 6 windowed mode and finalize tests/diagnostics.

## 11) Next practical steps (recommended)

1. Config and pipeline wiring:
   - [x] add `vb.online` keys in `config/defaults.yaml`.
   - [x] wire online mode in `scripts/pipeline_sim_main.R` and `scripts/pipeline_real_main.R` behind explicit `enabled` flag (default off).
2. Diagnostics expansion:
   - [x] add rolling check-loss and empirical coverage utilities.
   - [x] track jitter/fallback counts from `.solve_sympd` usage in online updates.
3. Refactor quality pass:
   - optionally extract shared local/global update pieces from `R/exal_ldvb_engine.R` to reduce duplication and keep offline/online formulas synchronized.

## 12) Iteration Plan (2026-02-23) and execution status

Goal for this iteration:
- harden case-study evaluation outputs and recommendation policy before broader rollout.

Planned actions (from latest planning round):
1. Rebaseline with fixed smoke/jitter/gate logic on a short sanity run.
2. Re-run full official case study with fixed logic.
3. Validate recommendation integrity and acceptance-gate behavior.
4. Keep a clean policy: online remains optional unless it clears acceptance criteria.

Implemented code changes for this iteration:
- Smoke pass criteria fixed for single-quantile runs in `scripts/online_vbld_case_study_smoke_tuning.R`:
  - no longer requires `scores_summary.csv` when synthesis is intentionally disabled,
  - accepts expected smoke artifacts (`models/forecast_objects.rds`, `models/rhs_run_summary.csv`).
- Jitter diagnostics hardened:
  - `R/exal_online_vbld.R`: sanitized jitter tracking (`n_jitter`, `jitter_out_of_range`, bounded/capped jitter summaries),
  - `scripts/online_vbld_case_study_smoke_tuning.R`: sanitized and capped jitter fields in run tables.
- Acceptance gate added in recommendation logic:
  - if best online candidate is worse than offline on both check-loss and coverage-error thresholds, set recommendation to `offline`.

Configuration updates:
- `config/online_vbld/case_study_dlm_constV_smallW.yaml` now includes:
  - `selection.jitter_eps_cap`,
  - `selection.max_jitter_eps_for_stability`,
  - `selection.acceptance.enabled`,
  - `selection.acceptance.max_check_loss_increase`,
  - `selection.acceptance.max_coverage_error_increase`.

Execution checklist:
- [x] Code hardening for smoke criteria.
- [x] Code hardening for jitter diagnostics.
- [x] Acceptance gate implementation.
- [x] Online test suite passes after changes.
- [x] Short sanity rerun complete with updated outputs.
- [x] Full official rerun complete with updated outputs.
- [x] Final recommendation decision recorded from refreshed run.

Runtime execution (detached, no active monitoring):
- Session: `online_vbld_iter_20260223-065909`
- Session meta: `logs/online_vbld_jobs/online_vbld_iter_20260223-065909.meta`
- Session log: `logs/online_vbld_jobs/online_vbld_iter_20260223-065909.log`
- Execution order:
  1) sanity config `config/online_vbld/case_study_dlm_constV_smallW_sanity.yaml`
  2) full config `config/online_vbld/case_study_dlm_constV_smallW.yaml`
- Output root: `results/online_vbld/case_study`

Completed outputs and decisions:
- Sanity run directory:
  - `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260223-065916`
  - Recommendation outcome: online default candidate accepted (`C4`), gate not triggered.
- Full run directory:
  - `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260223-071038`
  - Recommendation table: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260223-071038/tables/recommendation.csv`
  - Final policy outcome: `recommended_default=offline`, `safer_fallback=C2`, `recommended_online_candidate=C5`, `gate_triggered=TRUE`.
  - Gate reason (full run): online candidate worsened both check-loss and coverage-error versus offline beyond thresholds.

Operational policy lock (current):
- Keep `vb.online.enabled=false` by default in general workflows.
- If online mode is explicitly enabled, use `C5_W100` as first fallback schedule:
  - `M=10`, `K=40`, `W=100`, `L_loc=2`.
- Maintain acceptance gate in case-study selection and promote online defaults only after it clears offline baseline.

## 13) Next iteration plan (post-closeout)

Immediate goals:
1. Diagnose why online candidates collapse to nearly identical predictive metrics on this dataset.
2. Verify whether the bottleneck is schedule sensitivity, refresh cadence, or local-update depth.
3. Keep offline baseline frozen while testing narrow online variants.

Execution plan:
- [x] Add targeted config for a compact follow-up sweep around `C2`/`C5` with controlled `L_loc` and `W`.
- [x] Run one short sanity diagnostic sweep and one medium-budget sweep with deterministic seeds.
- [x] Record per-step diagnostics (`check_loss_pre`, coverage, jitter) and compare trajectory vs offline.
- [x] Decide whether to keep `C2` as fallback or adjust fallback defaults from empirical evidence.
- [x] Update `docs/ONLINE_VBLD_CASE_STUDY_SMOKE_TUNING.md` with the follow-up decision note.

Detached run launched:
- Session: `online_vbld_iter2_20260223-234101`
- Meta: `logs/online_vbld_jobs/online_vbld_iter2_20260223-234101.meta`
- Log: `logs/online_vbld_jobs/online_vbld_iter2_20260223-234101.log`
- Sequence:
  1) `config/online_vbld/case_study_dlm_constV_smallW_iteration2_sanity.yaml`
  2) `config/online_vbld/case_study_dlm_constV_smallW_iteration2.yaml`

Completion update (2026-02-24):
- Detached run status: completed (`[ITER2] COMPLETED 2026-02-24T00:42:11-08:00` in session log).
- Sanity run directory:
  - `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260223-234108`
  - Outcome: offline and tested online schedules were numerically identical on selected metrics.
  - Recommendation: `recommended_default=C2_L2`, gate not triggered.
- Medium run directory:
  - `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260223-235500`
  - Outcome: all online variants underperformed offline on check-loss and coverage error.
  - Recommendation table:
    - `recommended_default=offline`
    - `recommended_online_candidate=C5_W100`
    - `safer_fallback=C5_L3`
    - `gate_triggered=TRUE`
- Cross-run decision:
  - Keep offline default (`vb.online.enabled=false`).
  - Update online fallback defaults from `C2` to `C5_W100` based on medium-run evidence.
  - Keep acceptance gate as hard promotion criterion.

## 14) Next execution block

1. Run one diagnostic-only pass with `keep_trace=true` for:
   - offline baseline,
   - `C5_W100`,
   - `C5_L3`.
2. Export a compact drift table with:
   - rolling check-loss deltas,
   - rolling coverage gap,
   - jitter statistics by phase (`start`, `mid`, `end`).
3. If online still fails gate on the medium regime:
   - freeze operational defaults as-is (offline + `C5_W100` fallback),
   - stop schedule tuning and switch effort to algorithmic diagnostics (local update depth vs refresh cadence interaction).

Execution result (2026-02-24 diagnostic-only pass):
- Config used:
  - `config/online_vbld/case_study_dlm_constV_smallW_trace_diag.yaml`
- Run directory:
  - `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-124600`
- Schedules evaluated:
  - `offline`, `C5_W100`, `C5_L3`
- Gate outcome:
  - `recommended_default=offline`
  - `recommended_online_candidate=C5_W100`
  - `safer_fallback=C5_L3`
  - `gate_triggered=TRUE`
- Drift diagnostics:
  - table: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-124600/tables/diagnostic_drift_summary.csv`
  - trace tables: `trace_C5_W100.csv`, `trace_C5_L3.csv`
  - notable pattern: online jitter magnitude rises substantially across phases while coverage remains above target, and check-loss remains materially above offline.

Decision lock after step 14:
- Freeze operational policy as:
  - default: `vb.online.enabled=false`
  - optional fallback profile: `C5_W100` (`M=10`, `K=40`, `W=100`, `L_loc=2`)
- Stop schedule tuning for now and move to algorithmic diagnostics for root-cause analysis.

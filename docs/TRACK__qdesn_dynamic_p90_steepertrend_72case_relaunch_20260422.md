# TRACK: QDESN Dynamic P90 Steepertrend 72-Case Relaunch

Date: 2026-04-22
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Mission

Run the next high-quality Q-DESN dynamic relaunch on the promoted period-90
steeper-trend dataset surface using:

- the normalized shared `0.4.0` package warmup defaults;
- the updated Q-DESN dynamic launch stack; and
- a disciplined baseline-first relaunch structure.

Primary baseline target:

- `72` fits on one prior surface

Recommended order:

1. `ridge` first
2. `rhs_ns` second if the baseline is healthy

## 2) Active Dataset

Promoted scenario:

- `dlm_constV_p90_m0amp_highnoise_steepertrend_v1`

Canonical source root:

- [source roots](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v1)

Q-DESN materialized root:

- [qdesn windows](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_qdesn_sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v1)

Supporting docs:

- [active dataset manifest](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_active_dataset_selection.yaml)
- [selection report](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_dynamic_p90_steepertrend_main_dataset_selection_20260422.md)
- [relaunch prep plan](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/PLAN__qdesn_dynamic_p90_steepertrend_72case_relaunch_prep_20260422.md)

## 3) Core Baseline Policy

Shared long-budget contract to preserve:

- `vb.max_iter = 300`
- `vb.min_iter_elbo = 80`
- `vb.n_samp_xi = 1000`
- `mcmc.n_burn = 5000`
- `mcmc.n_mcmc = 20000`
- `mcmc.thin = 1`
- `posterior_metric_draws = 20000`
- `vb_sampling_nd_draws = 20000`
- `vb_synthesis_n_samp = 20000`
- `washout = 300`

Warmup policy to preserve:

- automatic tau warmup for `rhs` / `rhs_ns` with `50L`
- light exAL VB `(sigma, gamma)` warmup
- light exAL MCMC `(sigma, gamma)` warmup
- explicit `init_from_vb = TRUE` for MCMC

What stays out of the baseline:

- theta freeze rescue
- latent-state rescue
- latent `v` / latent `s` rescue
- precision rescue
- row-local replay overrides

## 4) Exact Dataset Semantics

Study geometry:

- `9` full roots
- `18` effective source windows
- one prior surface -> `72` fits
- two prior surfaces -> `144` fits

Exact effective-size semantics:

- effective sizes:
  - `500`
  - `5000`
- Q-DESN staged totals:
  - `813`
  - `5313`

These totals are required because:

- `holdout_n = 1`
- `lag_max = 12`
- `washout = 300`

## 5) Checklist

### A. Dataset freeze

- [x] promoted dataset selected
- [x] audit packs generated and reviewed
- [x] active dataset manifest written
- [x] `0.4.0` validation sync prompt written

### B. Relaunch design freeze

- [x] baseline-first relaunch policy documented
- [x] first-prior versus second-prior expansion policy documented
- [x] long-budget contract documented
- [x] baseline warmup matrix documented
- [x] final first-prior choice confirmed at implementation time

### C. Implementation prep

- [x] new relaunch defaults manifest created
- [x] new canonical full grid created from promoted dataset
- [x] audited subset grids created
- [x] launch wrapper created
- [x] healthcheck created
- [x] focused config test added

### D. Preflight gates

- [x] smoke `prepare-only` passed
- [x] full `prepare-only` passed
- [x] source totals verified as `813 / 5313`
- [x] effective-fit semantics verified as `500 / 5000`
- [x] warmup/default resolution verified

### E. Execution gates

- [x] smoke execution passed
- [x] committed-state launch tag frozen
- [x] full baseline launch started from committed state
- [x] live healthcheck captured

### F. Post-run decision

- [x] baseline result summarized
- [x] decision made on second-prior expansion
- [x] decision made on whether any rescue overlays are needed

## 6) Recommended Launch Order

1. implement the new relaunch assets on top of the promoted dataset
2. run committed-state smoke/full preflights
3. run smoke execution
4. run the first `72`-fit baseline on `ridge`
5. review results
6. only then launch the second `72`-fit `rhs_ns` expansion if justified

## 7) Historical Reference We Are Intentionally Reusing

We are reusing the parts of the previous refreshed-main relaunch that worked
well:

- explicit study contract
- deterministic per-root seeds
- phase-aware launch subsets
- committed-state preflights
- smoke-before-full discipline
- run-tag and session freeze after launch

We are intentionally **not** reusing the historical rescue-heavy defaults as
the new baseline.

## 8) Current Read

Committed-state launch tags used:

- smoke:
  - `qdesn-dynamic-p90-steepertrend-smoke-20260422-044129__git-6438b52`
- ridge baseline:
  - `qdesn-dynamic-p90-steepertrend-ridge-full-20260422-044241__git-6438b52`

Ridge baseline final operational outcome:

- `18 / 18` roots completed successfully
- `72 / 72` fits completed with `status = SUCCESS`
- hard numerical/runtime failures:
  - `0`
- root-level runtime failures:
  - `0`

Ridge baseline final fit-quality mix:

- `PASS: 42` (`58.3%`)
- `WARN: 15` (`20.8%`)
- `FAIL: 15` (`20.8%`)
- comparison-eligible:
  - `57 / 72` (`79.2%`)

Dominant diagnostic issues:

- `high_autocorrelation`
- `high_autocorrelation; half_chain_drift`
- `low_ess; high_autocorrelation; half_chain_drift`
- `vb_converged_false`
- `chain_marginal_but_usable`

Interpretation:

- the promoted dataset surface and the updated Q-DESN launch stack passed the
  first operational baseline gate
- the baseline did **not** show hard numerical breakdown
- the main remaining weakness is mixing/diagnostic quality, especially on
  `exal + mcmc`

Decision:

- proceed to the second prior surface, but **not** as a blind full launch
- next step should be a committed-state `rhs_ns` smoke gate using the same
  normalized baseline defaults
- only if that smoke gate remains free of hard numerical/runtime failures
  should the full `72`-fit `rhs_ns` expansion be launched

Rescue-overlay policy:

- do **not** change the baseline defaults yet
- do **not** promote theta/latent/precision rescue overlays into the default
  `rhs_ns` pass before seeing the `rhs_ns` smoke behavior
- if `rhs_ns` shows hard numerical problems, re-enter with a targeted rescue
  overlay plan afterward

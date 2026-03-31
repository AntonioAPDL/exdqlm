# QDESN exAL MCMC Kernel Redesign Proposal

- date: `2026-03-29`
- branch checkpoint: `412b3792ad53eb2cfebddd7aecb6d67272887f99`
- baseline closeout run: `rhsfixrelaunch-20260329b__git-6ac4727`
- scope: post-RHS-fix redesign proposal only; no package-code changes in this document

## Goal

Define a small, high-signal redesign plan for the QDESN MCMC kernel that:

1. uses the fresh post-fix evidence rather than the stale pre-fix closeout;
2. targets the actual active failure modes rather than inactive tuning knobs;
3. reuses the existing 6-root micro-pilot harness before any new broad rerun.

## Current Failure Picture

Primary evidence:

- `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/summary/phase01_summary.md`
- `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/tables/phase01_mcmc_fail_forensics.csv`
- `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/tables/phase01_mcmc_fail_cluster_rank.csv`
- `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/tables/phase01_micro_pilot_roots_selected.csv`
- `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/tables/phase35_transitions_P1_longer_chain.csv`

Fresh branch-level picture:

- Gate A passed with `19` MCMC FAIL rows and `4` failure clusters.
- `16/19` FAIL rows are `exal`; only `3/19` are `al`.
- `exal` fails are split evenly across priors: `8 rhs_ns`, `8 ridge`.
- dominant clusters are `half_chain_drift`, `geweke_drift`, and `low_ess`.
- the first micro-pilot profile (`P1_longer_chain`) reduced FAIL roots from `6 -> 3`, but median runtime inflation was about `+99.7%`, so it failed Gate B on efficiency.

Interpretation:

- The current blocker is not numerical collapse.
- The current blocker is chain quality under `exal`, especially on `tiny_d1_n8`.
- A `rhs_ns`-only fix is not enough, because `exal + ridge` fails almost identically on the hardest cells.

## Selected 6-Root Redesign Harness

Reuse these exact roots from `phase01_micro_pilot_roots_selected.csv`.

| role | scenario | tau | likelihood | prior | cluster | severity | read |
|---|---|---:|---|---|---|---:|---|
| severe-1 | `dlm_ar1V` | `0.95` | `exal` | `rhs_ns` | `all_four` | `3.464` | hardest rhs_ns tail stress |
| severe-2 | `dlm_constV_smallW` | `0.95` | `exal` | `ridge` | `all_four` | `3.394` | hardest ridge tail stress |
| severe-3 | `dlm_constV_bigW` | `0.05` | `exal` | `ridge` | `all_four` | `3.069` | opposite-tail ridge stress |
| severe-4 | `dlm_constV_smallW` | `0.95` | `exal` | `rhs_ns` | `all_four` | `2.278` | second rhs_ns severe stress |
| sentinel-1 | `dlm_constV_smallW` | `0.50` | `exal` | `rhs_ns` | `drift_geweke` | `1.141` | near-threshold exal rhs_ns sentinel |
| sentinel-2 | `dlm_constV_bigW` | `0.95` | `al` | `rhs_ns` | `drift_geweke` | `0.350` | lighter rhs_ns sentinel |

Why this set is enough:

- it covers both priors inside `exal`;
- it covers both tail directions (`0.05`, `0.95`) plus one central-ish case (`0.50`);
- it includes one `al` sentinel to catch rhs_ns regressions outside `exal`;
- it is already wired into the closeout machinery and gives direct comparison against the fresh baseline.

## Important Kernel Fact

The prior closeout micro-pilot tuned many `rhs` slice/block controls that do not act on `rhs_ns`.

Current code path:

- `rhs` uses `.exal_mcmc_rhs_slice_update()`
- `rhs_ns` uses `.exal_mcmc_rhs_ns_gibbs_update()`
- width adaptation is only active for `rhs`, not `rhs_ns`

Relevant files:

- `R/exal_mcmc_fit.R`
- `R/exal_inference_config.R`
- `scripts/run_qdesn_validation_closeout_phase01.R`

Consequence:

- old `P1/P2/P3` mostly tested longer chains for `rhs_ns`, not a true `rhs_ns` geometry redesign;
- the next redesign round should tune active `exal` core knobs and, if needed, active `rhs_ns` Gibbs knobs.

## Candidate 1: exAL Core Refresh v1

### Summary

Make a low-to-medium lift change that only touches active `exal` core controls and leaves the current RHS-family update logic intact.

### Proposed kernel changes

Files:

- `R/exal_inference_config.R`
- `R/exal_mcmc_fit.R`

Changes:

1. make `use_log_sigma = TRUE` the default for `exal` MCMC, not just a validation override;
2. add an `exal`-specific default of `core_extra_passes = 1` or `2` so each iteration gets additional `sigma/gamma` refreshes without doubling the full chain length;
3. split `sigma` tuning from generic slice tuning and expose `max_steps_out_sigma` / `max_shrink_sigma` separately;
4. tune the core widths conservatively for `exal`, starting near:
   - `width_gamma = 0.45`
   - `width_sigma = 0.25` to `0.30`
   - `max_steps_out_sigma = 60`
   - `max_shrink_sigma = 200`

### Why this matches the failures

- the dominant failures are `half_chain_drift` and `geweke_drift`;
- they occur across both `ridge` and `rhs_ns`;
- that points first to the shared `exal` core update, not to the prior-specific block.

### Expected upside

- best low-risk chance to convert the mild-to-moderate `FAIL` rows into `WARN` without a large runtime jump;
- directly targets the heavy `all_four` quartet and the lighter `drift_geweke` sentinels.

### Main risk

- if the true issue is strong `gamma`/`sigma` posterior coupling, coordinate refreshes may improve diagnostics only modestly.

## Candidate 2: Blocked exAL Core Kernel v1

### Summary

Introduce a real structural change to the `exal` core sampler by updating `gamma` and `sigma` in a coupled transformed block rather than only through repeated coordinate-wise updates.

### Proposed kernel changes

Files:

- `R/exal_mcmc_fit.R`
- `R/exal_inference_config.R`

Changes:

1. add a new core update mode, for example `core_update_mode = "blocked_sigma_gamma"`;
2. sample in transformed space using `(eta_gamma, eta_sigma)` or equivalent unconstrained coordinates;
3. perform one blocked proposal plus one cleanup coordinate pass per iteration;
4. expose block width separately from the existing scalar widths, for example:
   - `width_core_gamma_sigma_block = 0.15` to `0.25`
5. keep `use_log_sigma = TRUE` as part of this mode.

### Why this matches the failures

- the hardest residuals after `P1_longer_chain` are still all `exal`;
- the fail pattern is cross-prior, suggesting the shared core geometry is the real bottleneck;
- the existing long-chain rescue helped but was too expensive, which is exactly when a better kernel geometry is preferable.

### Expected upside

- strongest chance to break the `all_four` cluster without relying on much longer chains;
- the best candidate for a real branch-unblocking improvement if Candidate 1 is too weak.

### Main risk

- highest implementation and debugging cost;
- the blocked move needs careful diagnostics so we do not trade drift failures for finite/domain regressions.

## Candidate 3: rhs_ns Gibbs Hardening v1

### Summary

Improve the actual `rhs_ns` Gibbs path instead of continuing to tune `rhs` slice/block settings that do not apply.

### Proposed kernel changes

Files:

- `R/exal_mcmc_fit.R`
- `R/exal_inference_config.R`

Changes:

1. add repeated local-global refresh inside `.exal_mcmc_rhs_ns_gibbs_update()`, for example:
   - `rhs_ns_local_sweeps = 2`
   - `rhs_ns_global_passes = 2`
2. add a staged tau release policy after warmup instead of a simple frozen/unfrozen switch, for example:
   - keep `freeze_tau_burnin_iters`
   - then release `tau` gradually over the next `50` to `100` iterations
3. keep warm-start inheritance from VB and previous `beta_prior_state`, but record the chosen state more explicitly for diagnostics.

### Why this matches the failures

- it targets the true `rhs_ns` path;
- it is most relevant for the three `rhs_ns + exal` roots plus the `al + rhs_ns` sentinel;
- it addresses the fact that the old micro-pilot mostly changed inactive knobs for `rhs_ns`.

### Expected upside

- best candidate for cleaning up the rhs_ns-specific residual drift and half-drift behavior once the exAL core is healthier.

### Main risk

- it does not explain the `exal + ridge` fails, so it should not be the first redesign attempted in isolation.

## Recommended Order

### Recommended path

1. **Candidate 1 first**
   - lowest lift
   - hits the shared `exal` failure mode
   - likely best cost-benefit for the current severity profile
2. **Candidate 2 second if Candidate 1 only partially helps**
   - escalate to structural core redesign if the severe quartet remains mostly FAIL
3. **Candidate 3 third or in parallel design review**
   - only after we know how much of the problem remains on the true `rhs_ns` path

### Why this order is preferred

- severe failures are dominated by `exal` across both priors;
- `rhs_ns`-only work cannot clear the ridge half of the severe quartet;
- the current failure severities are mostly moderate enough to justify one lower-risk core pass before a bigger structural redesign.

## Matching 6-Root Validation Plan

### Reuse strategy

Do not rebuild branch validation. Reuse the current closeout micro-pilot harness and compare only against the fresh post-fix baseline.

Reuse:

- `phase01_manifest.json`
- `phase01_micro_pilot_roots_selected.csv`
- `phase35` comparison logic and Gate B metrics

Do not rerun:

- `T0`
- `T1`
- `T2`
- `T3`
- full branch closeout

until a candidate clears the 6-root redesign gate.

### Validation stages per candidate

#### Stage R0: safety replay

- run the candidate on the same 6 roots, single worker, `--no-plots`;
- objective: verify `6/6` roots reach `SUCCESS` with no finite/domain/collapse regressions.

#### Stage R1: redesign efficacy

Evaluate against the fresh baseline with the same transition logic used in `phase35`.

Required pass conditions:

1. `0` new finite/domain failures
2. `0` new collapse flags
3. runtime inflation median `<= 0.50`
4. severe quartet (`all_four` roots) reduced from `4 FAIL` to at most `2 FAIL`
5. no sentinel regression:
   - `dlm_constV_smallW | 0.50 | exal | rhs_ns` must stay `WARN` or improve
   - `dlm_constV_bigW | 0.95 | al | rhs_ns` must stay `WARN` or improve

Preferred pass conditions:

1. severe quartet reduced to `<= 1 FAIL`
2. median delta half-drift `< 0`
3. median delta Geweke `< 0`
4. runtime inflation median `<= 0.30`

#### Stage R2: decision

- if a candidate passes Required conditions, promote it to full failing-cell replay;
- if it misses only on runtime, move to a geometry-improving candidate rather than longer chains;
- if it misses on both severe quartet efficacy and sentinels, stop and redesign before more reruns.

## Candidate-to-Root Mapping

| candidate | primary target roots | secondary target roots | expected strongest signal |
|---|---|---|---|
| Candidate 1: exAL Core Refresh | severe-1, severe-2, severe-3, severe-4 | sentinel-1 | lower half-drift and Geweke with moderate runtime cost |
| Candidate 2: Blocked exAL Core Kernel | severe-1, severe-2, severe-3, severe-4 | sentinel-1, sentinel-2 | collapse `all_four` failures without long-chain inflation |
| Candidate 3: rhs_ns Gibbs Hardening | severe-1, severe-4, sentinel-1 | sentinel-2 | rhs_ns-specific drift cleanup after exAL core work |

## Concrete Next Action

If only one redesign is funded next, choose:

- **Candidate 1: exAL Core Refresh v1**

Rationale:

- it attacks the observed cross-prior `exal` failure mode;
- it is materially more targeted than the old longer-chain micro-pilot;
- it keeps runtime pressure much lower than repeating `P1/P2/P3` style rescues.

If Candidate 1 converts the mild drift roots but leaves the severe quartet mostly intact, move directly to Candidate 2 instead of spending another cycle on chain length.

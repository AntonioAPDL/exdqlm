# PLAN: QDESN Static exdqlm Cross-Study Wave 2 Debt Resolution

Date: 2026-04-04  
Branch: `feature/qdesn-mcmc-alternative`

## 1) Goal

Resolve only the remaining scientific debt from the broad static QDESN cross-study launch.

This is explicitly **not** another full-surface relaunch.

The source baseline is the Wave-1 broad shared-setup launch:

- `qdesn-static-exdqlm-crossstudy-20260404b__git-06ac1c0`

## 2) Current Baseline And Debt

Current baseline:

- broad shared static defaults from
  `config/validation/qdesn_static_exdqlm_crossstudy_defaults.yaml`
- authoritative Wave-1 root-state baseline:
  - `72` roots materialized
  - `66` `SUCCESS`
  - `6` `FAIL`

Remaining debt classes:

1. Hard root failures:
   - exactly `6`
   - all in `static_shrink x laplace x tt=1000`
2. rhs comparison debt:
   - `30` additional successful `rhs_ns` roots with
     `root_comparison_eligible_any = FALSE`

Current highest-value directions:

- anchor replay under the patched PSOCK runner
- stronger ridge MCMC schedule for the hard ridge slice
- softgamma/geometry ridge rescue
- rhs soft/freeze hedge
- one narrow crossover profile
- one static-specific rhs diagnostics probe

Explicit exclusions:

- no relaunch of the full `72`-root surface
- no row-by-row local custom tuning
- no reopening of the finished dynamic DLM tuning program
- no broad family reopening for `rhs_ns`

## 3) Design Principles

Hard rules carried over from the completed dynamic QDESN program:

1. Exact runner parity matters more than local pilot intuition.
2. Replays and confirmations matter more than one-off wins.
3. Freeze the shared baseline and compare against it explicitly.
4. Use narrow debt reruns instead of broad relaunches.
5. Track operational health separately from scientific quality.
6. Keep manifests deterministic and outputs auditable.
7. Treat comparison tables as first-class outputs.

## 4) Wave 2 Structure

Checked-in manifest:

- `config/validation/qdesn_static_exdqlm_crossstudy_debt_wave_manifest.yaml`

### Stage 1: `S1_failband_and_rhs_probe`

Purpose:

- distinguish execution-path recovery from true scientific improvement;
- screen a small set of targeted rescue profiles before spending full-debt compute.

Stage-1 root set:

- the `6` hard-fail roots
- plus `3` representative rhs debt probes

Total Stage-1 roots:

- `9`

Representative rhs probe roots:

1. `root__static_paper__gausmix__tau_0p25__tt_100__qdesn_rhs_ns`
2. `root__static_shrink__gausmix__tau_0p95__tt_1000__qdesn_rhs_ns`
3. `root__static_paper__normal__tau_0p95__tt_1000__qdesn_rhs_ns`

Profiles screened:

1. `D400_anchor_replay`
2. `D410_ridge_rescue_reference`
3. `D420_softgamma_geometry`
4. `D430_rhssoft_freeze90`
5. `D440_crossover_softgamma_rhssoft`
6. `D450_rhs_diagnostics_probe`

Stage-1 selection rule:

- always carry the anchor replay to Stage 2;
- also carry the top `1` experimental survivor by debt ranking.

### Stage 2: `S2_full_debt_confirmation`

Purpose:

- confirm the best experimental survivor on the full remaining debt set, not the whole study surface.

Stage-2 debt set:

- `36` roots total
  - `6` hard-fail roots
  - `30` successful rhs debt roots with `root_comparison_eligible_any = FALSE`

Stage-2 profiles:

- `D400_anchor_replay`
- anchor + top `1` experimental survivor from Stage 1

## 5) Why Each Profile Is Included

| profile | why included |
|---|---|
| `D400_anchor_replay` | tests whether the broad launch’s hard-root FAIL labels were largely campaign-path debt |
| `D410_ridge_rescue_reference` | highest-value rescue for the hard ridge slice and exal-MCMC drift |
| `D420_softgamma_geometry` | tests whether the static hard band shares the dynamic geometry clue |
| `D430_rhssoft_freeze90` | narrow rhs-local hedge for comparison debt without reopening the family |
| `D440_crossover_softgamma_rhssoft` | best disciplined crossover candidate from the dynamic lessons |
| `D450_rhs_diagnostics_probe` | static-specific rhs diagnostics probe to test whether some rhs debt can be reduced without code-path redesign |

## 6) Compute Plan

Server policy:

- logical CPUs: `64`
- nested parallelism: `disabled`
- per-fit threads: `1`
- `postpred_threads`: `1`
- plots during campaign: `disabled`

Worker policy:

- default if no competing QDESN jobs: `6`
- fallback if other QDESN jobs are active: `4`
- hard cap: `6`

Expected launch behavior for the current server state:

- because the broad Wave-1 launcher still appears live in process state, the debt wave should use
  the conservative fallback worker count.

Expected compute footprint:

- Stage 1:
  - `9 roots x 6 profiles = 54 root campaigns`
- Stage 2:
  - `36 roots x 2 profiles = 72 root campaigns`
- total:
  - `126` root campaigns

This is intentionally broader than a micro-pilot but much narrower than another `72`-root
surface-wide relaunch.

## 7) Outputs That Define “Done”

Required outputs:

1. preflight manifest + markdown
2. source debt inventory tables
3. stage grids and per-profile config materializations
4. Stage-1 profile metrics + ranking + selection summary
5. Stage-2 profile metrics + ranking + selection summary
6. runner state JSON
7. stage execution status table
8. integrated debt-wave result summary
9. completed manifest with recommendation

New implementation assets:

- `config/validation/qdesn_static_exdqlm_crossstudy_debt_wave_manifest.yaml`
- `R/qdesn_static_exdqlm_crossstudy_debt_wave.R`
- `scripts/run_qdesn_static_exdqlm_crossstudy_debt_wave.R`
- `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_debt_wave.R`

## 8) Acceptance Criteria

Wave 2 is considered successful if all of the following are true:

1. prepare-only passes cleanly;
2. Stage 1 completes and ranks profiles on the intended `9`-root debt pilot;
3. Stage 2 completes on the intended `36`-root debt set;
4. the source baseline, anchor replay, and experimental survivor are directly comparable in the
   emitted tables;
5. the result summary clearly states one of:
   - `PROMOTE_<profile>_AS_DEBT_WAVE_LEAD`
   - `KEEP_SHARED_STATIC_BASELINE_WITH_DOCUMENTED_DEBT`

Scientific success is narrower:

- any profile that rescues more hard-fail roots than the anchor or meaningfully improves rhs
  comparison coverage on the debt set becomes the debt-wave lead;
- otherwise the shared baseline remains the lead and the debt is documented honestly.

## 9) Operational Note

The Wave-1 source launch should not be reused as a live runner.

It remains valuable as a source baseline because its root-level artifacts are complete enough to
define the debt set precisely, but its campaign closeout path is not reliable enough to use as the
continuing execution surface.

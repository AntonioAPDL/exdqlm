# Q-DESN TT500 VB Screening Revised Plan

Date: 2026-06-25

Worktree:
`/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`

Branch:
`validation/shared-fitforecast-v2-1.0.0`

HEAD at audit:
`f7003224caa76eca8196caf5cd88b44f36f4a2fb`

## Purpose

This document revises the Q-DESN TT500 tuning path after the completed median
scout, all-quantile confirmation, and compact broad VB screens. The goal is to
select a faster and more accurate Q-DESN specification for the TT500
fit+forecast validation replacement without overfitting to one quantile,
family, reservoir seed, or ranking metric.

This is tuning evidence only. These runs must not be promoted directly to
Article-Q-DESN final comparison tables.

## Completed Evidence

| stage | run tag | scope | status | ranking |
|---|---|---:|---:|---:|
| median scout | `qdesn-tt500-vb-screen-median-scout-200draw-20260625-045828__git-437dc73-dirty` | 63 profiles x 3 families x tau 0.50 = 189 fits | 189/189 success | yes |
| all-quantile confirmation | `qdesn-tt500-vb-confirm-top10-20260625-174340__git-437dc73` | 10 profiles x 3 families x 3 taus = 90 fits | 90/90 success | yes |
| compact broad | `qdesn-tt500-vb-broad-20260625-181834__git-437dc73-dirty` | 55 profiles x 3 families x taus 0.05 and 0.50 = 330 fits | 330/330 success | yes |

Important evidence paths:

- Median scout ranking:
  `reports/qdesn_mcmc_validation/dynamic_fitforecast_v2_tt500_vb_screen/qdesn-tt500-vb-screen-median-scout-200draw-20260625-045828__git-437dc73-dirty/20260625-045959__git-437dc73/tables/qdesn_tt500_vb_screen_profile_ranking.csv`
- Confirmation ranking:
  `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_confirm/qdesn-tt500-vb-confirm-top10-20260625-174340__git-437dc73/20260625-174352__git-437dc73/tables/qdesn_tt500_vb_screen_profile_ranking.csv`
- Broad ranking:
  `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_broad/qdesn-tt500-vb-broad-20260625-181834__git-437dc73-dirty/20260625-181857__git-437dc73/tables/qdesn_tt500_vb_screen_profile_ranking.csv`
- Broad cell summary:
  `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_broad/qdesn-tt500-vb-broad-20260625-181834__git-437dc73-dirty/20260625-181857__git-437dc73/tables/qdesn_tt500_vb_screen_profile_cell_summary.csv`

## Diagnosis

1. The tuning machinery is operational.

   All three stages completed with no failed roots and complete rolling-origin
   lead metrics. The profile ranking is built from per-fit
   `forecast_lead_metrics.csv` files, not from the campaign-level `forecast_*`
   placeholders.

2. The useful region is compact.

   The broad screen shows the strongest global profiles around
   `alpha = 0.20`, `rho = 0.80`, with `D = 1` or `D = 2` and `n_each = 30--50`.
   These profiles have much lower readout dimension than the old deep profile
   and materially better runtime.

3. The old confirmation set is no longer sufficient.

   The all-quantile confirmation was launched before the compact broad screen.
   It confirms that `D2-n30-alpha0.30-rho0.85`,
   `D1-n50-alpha0.30-rho0.85`, and `D1-n30-alpha0.10-rho0.70` are robust,
   but it did not include the new broad leaders at `alpha = 0.20`,
   `rho = 0.80`.

4. The compact broad screen has a tau gap.

   Broad was intentionally restricted to `tau = 0.05` and `tau = 0.50`.
   Therefore the best broad profiles cannot be promoted until `tau = 0.25`
   is evaluated under the same all-family rolling-origin contract.

5. The `tau0` axis should stay out of the main screen.

   The median scout found no informative movement across the old
   `tau0 = 1e-5, 1e-4, 1e-3` triplicates. Unless a separate canary proves that
   a revised prior-scale parameterization changes fitted diagnostics, repeating
   `tau0` in the main search wastes compute and complicates interpretation.

6. The broad screen suggests some family/tau specialists.

   Examples include lower-alpha compact profiles for `laplace, tau = 0.05`,
   `D2/D3 n=20` profiles for `gausmix, tau = 0.50`, and small high-rho
   profiles for `normal, tau = 0.50`. These should be retained as guards, but
   the main goal should remain a single global compact profile unless a
   specialist has a large, stable gain.

## Revised Strategy

Use a staged successive-halving design:

1. Do not run another full broad sweep now.
2. Fill the missing all-quantile evidence for the best compact profiles.
3. Check reservoir seed stability only for the finalists.
4. Freeze either one global profile or a small documented override map.
5. Relaunch the TT500 replacement only after the frozen profile decision passes
   reproducibility and storage-light checks.

This is more efficient than a wider blind screen because the completed broad
screen already located a coherent neighborhood. It is safer than immediately
launching the replacement because the best broad profiles have not been tested
at `tau = 0.25` or alternate reservoir seeds.

## Stage A: All-Quantile Refinement

Create a new refinement stage that evaluates the best broad profiles plus
cross-stage guards across all families and all validation quantiles.

Recommended profile set:

| role | profile | reason |
|---|---|---|
| broad winner | `D2_n30_alpha0.20_rho0.80` | best broad rank, strong short-lead metrics |
| fast broad winner | `D1_n30_alpha0.20_rho0.80` | best broad forecast MAE, much cheaper |
| robust prior winner | `D2_n30_alpha0.30_rho0.85` | top 10 in median, confirmation, and broad |
| robust compact guard | `D1_n30_alpha0.10_rho0.70` | top 10 in all three stages |
| broad mid-width | `D1_n50_alpha0.20_rho0.80` | broad top 5 |
| broad wider shallow | `D1_n70_alpha0.20_rho0.80` | broad top 6 |
| very compact guard | `D1_n20_alpha0.10_rho0.70` | broad top 7 and low dimension |
| compact low-alpha guard | `D1_n40_alpha0.10_rho0.70` | broad top 8 |
| confirmed alpha0.30 guard | `D1_n50_alpha0.30_rho0.85` | top 10 in median, confirmation, and broad |
| confirmed forecast guard | `D1_n70_alpha0.30_rho0.85` | median and confirmation top 3 |
| cheap confirmed guard | `D1_n30_alpha0.30_rho0.85` | median and confirmation top 5 |
| broad mid-width alpha0.20 | `D1_n40_alpha0.20_rho0.80` | broad top 9 |

Scope:

- profiles: 12
- families: `gausmix`, `laplace`, `normal`
- taus: `0.05`, `0.25`, `0.50`
- fit size: TT500
- inference: VB
- likelihood: exAL
- prior: RHS-NS
- reservoir seed: 123
- total fits: 108

Estimated cost from observed screening runtimes:

- observed per-fit model runtime in `campaign_fit_summary.csv`: median about
  6.3 seconds and 95th percentile about 15.7 seconds
- observed broad-campaign wall throughput: about 330 fits in 144 minutes,
  including orchestration, source staging, metric aggregation, and I/O
- using the observed campaign throughput, the 108-fit refinement stage should
  be planned as roughly 45--60 minutes with 20 workers, not as a multi-day run

Required artifacts:

- refinement profile CSV
- refinement defaults YAML
- refinement grid CSV
- prepare-only manifest
- one-root smoke manifest
- campaign summary
- lead-aware profile ranking
- ranking manifest

## Stage B: Seed Stability

After Stage A, select the top 5 finalists using the lead-aware ranking and
cell-level diagnostics.

Run one alternate-seed stability pass first:

- profiles: top 5 from Stage A
- families: 3
- taus: 3
- seed: 456
- total fits: 45

Run a second alternate-seed pass only if the top two profiles are close or swap
substantially:

- profiles: top 5
- families: 3
- taus: 3
- seed: 789
- total fits: 45

Selection should be based on aggregated rank plus stability:

- all requested cells must have complete lead metrics
- no root failures
- no non-finite/domain warnings
- no severe family/tau collapse
- top profile should remain top 3 under alternate seed
- if a faster profile is within a small tolerance of the best score, prefer the
  faster/lower-dimension profile

## Stage C: Profile Freeze Decision

Freeze one of the following:

1. A single global Q-DESN profile for all TT500 Q-DESN rows.
2. A small override map by `family, tau` only if a specialist profile shows a
   stable and practically meaningful improvement.

Default preference:

- one global profile
- `p/n <= 0.25` unless the gain from a larger profile is clearly material
- no `tau0` axis
- no per-run manual edits outside the versioned profile registry

Recommended freeze criteria:

- all-family/all-tau Stage A complete
- seed stability complete for finalists
- selected profile has complete train, holdout, and rolling-origin forecast
  metrics
- selected profile improves the old TT500 Q-DESN behavior on fit and forecast
  recovery
- selected profile is not dominated by a substantially faster profile
- selected profile registry, defaults, grid, and ranking paths are recorded in
  the tracker

## Stage D: TT500 Replacement Relaunch Gate

Only after the freeze decision should a TT500 replacement validation be
launched.

The replacement launch must:

- use the frozen Q-DESN profile registry
- use the shared source registry and source hashes
- keep the rolling-origin protocol fixed:
  `Hmax = 30`, `origin_stride = 30`, no refit per origin, observed-lag state
  update
- keep TT500 train window `8501:9000`
- keep forecast block `9001:10000`
- keep storage-light artifact policy
- write article-facing summaries only after all rows are terminal

Do not launch TT5000 from this tuning path.

## Stage E: Article Interface Policy

The refinement and stability screens are not final article tables.

Article-Q-DESN may use them only as documented tuning evidence. Final article
tables should consume the later frozen TT500 replacement interface, not these
screening reports.

Article-facing comparison rows must include:

- source registry identity and hash
- model family and model variant
- inference method
- family, tau, fit size
- fit-window source start/end indices
- forecast origin and forecast block metadata
- rolling-origin `Hmax` and origin stride
- lead-band forecast metrics
- fit recovery metrics
- runtime
- status/failure fields
- branch, commit, package version, run tag
- artifact paths and hashes

## Required Implementation Work

Implemented support now includes:

1. A shared follow-up materializer:
   `qdesn_dynamic_fitforecast_materialize_followup_stage()`.
2. A live/strict campaign auditor:
   `qdesn_dynamic_fitforecast_audit_screen_campaign()`.
3. A freeze helper:
   `qdesn_dynamic_fitforecast_freeze_profile()`.
4. A successful-root RHS trace cleanup helper:
   `qdesn_dynamic_fitforecast_prune_success_rhs_trace()`.
5. Command wrappers:
   - `scripts/audit_qdesn_tt500_vb_dominance_screening.R`
   - `scripts/materialize_qdesn_tt500_vb_dominance_followup.R`
   - `scripts/freeze_qdesn_tt500_vb_profile.R`
   - `scripts/orchestrate_qdesn_tt500_vb_dominance_followup.R`
6. Tests covering partial/live audit semantics, strict terminal audit,
   dominance-pass filtering, profile freezing, and config stub materialization:
   `tests/testthat/test-qdesn-tt500-vb-dominance-followup.R`.

The materialized filenames are intentionally stage-specific:

- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement_profiles.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement_defaults.yaml`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement_grid.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_seed_stability_profiles.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_seed_stability_defaults.yaml`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_seed_stability_grid.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_replacement_frozen_profiles.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_replacement_frozen_defaults.yaml`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_replacement_frozen_grid.csv`

The follow-up orchestrator is guarded: it always materializes and runs
prepare-only first, runs smoke only with `--smoke`, and launches the full stage
only with `--full`.

## Stop/Go Rules

Stop before replacement launch if:

- any refinement or stability root fails
- any lead metric file is missing
- `tau = 0.25` disagrees sharply with the broad-screen winner
- the selected profile is seed-unstable
- a final profile cannot be represented in a versioned profile registry
- storage-light checks fail

Go to replacement planning if:

- refinement is complete
- seed stability is complete or the top profile is decisively separated
- one global profile or a minimal override map is frozen
- tests, prepare-only, smoke, and storage audits pass
- the user explicitly approves the TT500 replacement launch

## Current Recommendation

The optimal next action is Stage A: implement and launch the 108-fit
all-quantile refinement screen with 20 workers. This is the smallest screen
that closes the current evidence gap without discarding the useful broad-search
signal.

Do not launch another huge blind broad screen yet. Do not launch the TT500
replacement yet. Do not update article final tables from screening outputs.

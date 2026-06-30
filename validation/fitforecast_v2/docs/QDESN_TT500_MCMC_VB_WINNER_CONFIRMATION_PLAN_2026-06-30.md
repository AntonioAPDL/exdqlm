# Q-DESN TT500 MCMC VB-Winner Confirmation Plan

Status: planned, not launched.

This document freezes the plan for the next Q-DESN TT500 validation step after the
VB replacement work made every Article-facing Q-DESN exAL RHS VB cell competitive
against the best DQLM/exDQLM VB baseline. The purpose of this lane is not another
broad screen. It is a storage-light, reproducible MCMC confirmation of the frozen
VB winner set under the same shared rolling-origin fit+forecast protocol.

## Audit Snapshot

- validation worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- branch: `validation/shared-fitforecast-v2-1.0.0`
- upstream: `origin/validation/shared-fitforecast-v2-1.0.0`
- HEAD: `4d77027184df369a0607f3ac78eb7eae2687a5ed`
- HEAD subject: `Document Q-DESN TT500 VB stage4 candidates`
- package version: `1.0.0` from `DESCRIPTION`
- remote: `git@github.com:AntonioAPDL/exdqlm.git`
- status at audit time: clean relative to upstream

Evidence checked:

- Stage 4 VB candidate ledger:
  `validation/fitforecast_v2/docs/qdesn_tt500_vb_stage4_best_candidate_ledger_2026-06-29.csv`
- Stage 3 VB cell summary:
  `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue/qdesn-tt500-vb-stage3-forecast-bias-rescue-full-20260628/20260628-114648__git-203f47a/tables/qdesn_tt500_vb_dominance_cell_summary.csv`
- Article-facing TT500 summary:
  `/data/jaguir26/local/src/Article-Q-DESN/tables/qdesn_validation_tt500_final_summary.csv`
- Article-facing VB competitiveness audit:
  `/data/jaguir26/local/src/Article-Q-DESN/tables/qdesn_validation_tt500_vb_competitiveness_audit.csv`
- Main reusable runner:
  `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`
- Dynamic campaign engine:
  `R/qdesn_dynamic_exdqlm_crossstudy.R`
- MCMC warm-start implementation:
  `R/exal_mcmc_fit.R`

## Decision

Use the frozen Article-facing per-cell VB winner set as the MCMC confirmation
scope.

This is slightly different from saying "one universal spec for all cells." The
audit found one compact profile that is promoted for 7 of 9 cells, but two
gausmix cells require cell-specific winners. For scientific reproducibility and
Article consistency, the MCMC lane should confirm the promoted cell winners, not
silently re-optimize or swap profiles.

The promoted winner set is:

| family | tau | profile | source |
|---|---:|---|---|
| gausmix | 0.05 | `tt500vb_f3_d2_n20_a0p05_r0p6_m15_lag15_rl0_pw0p03_pin0p3` | Stage 4B |
| gausmix | 0.25 | `tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3` | Stage 3 Article-promoted |
| gausmix | 0.50 | `tt500vb_f3_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3` | Stage 4A |
| laplace | 0.05 | `tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3` | Stage 4A |
| laplace | 0.25 | `tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3` | Stage 4A |
| laplace | 0.50 | `tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3` | Stage 4A |
| normal | 0.05 | `tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3` | Stage 4A |
| normal | 0.25 | `tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3` | Stage 3 Article-promoted |
| normal | 0.50 | `tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3` | Stage 3 Article-promoted |

Note: the Stage 3 screen contains a `gausmix tau=0.25` profile with a slightly
better worst-ratio ordering under one selection rule
(`tt500vb_f3_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3`). That profile is
not the Article-promoted cell for `gausmix tau=0.25`. Do not substitute it into
the main MCMC confirmation unless we explicitly open a new VB freeze decision.

## Frozen MCMC Root IDs

The MCMC confirmation lane should contain exactly these nine roots:

```text
root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__gausmix__tau_0p05__lasttt_500__qdesn_rhs_ns__profile_tt500vb_f3_d2_n20_a0p05_r0p6_m15_lag15_rl0_pw0p03_pin0p3
root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__gausmix__tau_0p25__lasttt_500__qdesn_rhs_ns__profile_tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3
root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__gausmix__tau_0p50__lasttt_500__qdesn_rhs_ns__profile_tt500vb_f3_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3
root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__laplace__tau_0p05__lasttt_500__qdesn_rhs_ns__profile_tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3
root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__laplace__tau_0p25__lasttt_500__qdesn_rhs_ns__profile_tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3
root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__laplace__tau_0p50__lasttt_500__qdesn_rhs_ns__profile_tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3
root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__normal__tau_0p05__lasttt_500__qdesn_rhs_ns__profile_tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3
root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__normal__tau_0p25__lasttt_500__qdesn_rhs_ns__profile_tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3
root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__normal__tau_0p50__lasttt_500__qdesn_rhs_ns__profile_tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3
```

## Protocol To Preserve

The new MCMC lane must preserve the shared fit+forecast protocol already used by
the VB replacement work:

- source registry: shared dynamic fit+forecast v2 registry
- package baseline: exdqlm `1.0.0`
- fit size: TT500 only
- training target/source window: `8501:9000`
- forecast block: `9001:10000`
- rolling-origin forecast protocol: `rolling_origin_no_refit_state_update`
- maximum lead: `Hmax = 30`
- origin stride: `30`
- no quantile synthesis step
- metrics: fit recovery plus lead-level and aggregate rolling forecast metrics
- storage policy: scalar metrics, compact summaries, manifests, configs, logs,
  statuses, progress traces, and hashes; no routine successful `.rds`, `.rda`,
  or `.RData` payload retention

## Reuse Audit

The existing runner is the right base:

- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R` supports
  `--prepare-only`, `--methods`, `--likelihoods`, `--fit-sizes`, `--priors`,
  `--root-ids`, `--spec-ids`, `--workers`, `--scheduler load_balanced`, and
  run-tagged manifests.
- `qdesn_dynamic_crossstudy_run_campaign()` runs roots through a PSOCK cluster
  and switches to `parLapplyLB` when `root_scheduler = load_balanced`.
- `qdesn_dynamic_crossstudy_run_root()` records root status as `RUNNING`,
  `SUCCESS`, or `FAIL`, and writes root manifests, fit summaries, signoff
  summaries, progress traces, runtime summaries, and campaign summaries.
- `.qdesn_dynamic_crossstudy_run_selected_mcmc_fit()` supports optional
  multiseed MCMC, but the confirmation lane should start with one seed per root.
- `exal_mcmc_fit()` already implements `init_from_vb = TRUE` through an
  internal LDVB warm start. This does not require modifying the exdqlm 1.0.0
  package branch. Since the storage-light VB runs do not retain full reusable VB
  state, recomputing the compact warm start inside MCMC is acceptable and should
  be logged explicitly.

One gap to close before launch:

- the current healthcheck reports statuses, materialized roots, launcher state,
  storage footprint, and retained heavy artifacts, but the MCMC lane should add
  a 30-minute stale classification from progress/log/status mtimes so long MCMC
  fits can be audited without guessing.

## Implementation Plan

Create a new selective MCMC confirmation lane rather than editing the VB lanes in
place.

Planned files:

- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation_winners.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation_profiles.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation_cell_assignments.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation_defaults.yaml`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation_grid.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation_materialization_manifest.json`
- `scripts/materialize_qdesn_tt500_mcmc_vb_winner_confirmation.R`
- `scripts/orchestrate_qdesn_tt500_mcmc_vb_winner_confirmation.R`
- `scripts/audit_qdesn_tt500_mcmc_vb_winner_confirmation.R`
- `tests/testthat/test-qdesn-tt500-mcmc-vb-winner-confirmation.R`

Default lane settings:

- `execution.methods: mcmc`
- `execution.likelihood_families: exal`
- `fit_sizes: 500`
- `priors: rhs_ns`
- `expected_qdesn_roots: 27` for the canonical 3-profile x 9-cell grid
- `expected_unique_dataset_cells: 9`
- `expected_selected_qdesn_roots: 9` for the frozen confirmation subset
- `mcmc_n_burn: 5000`
- `mcmc_n_mcmc: 20000`
- `mcmc_thin: 1`
- `mcmc.progress_every: 50`
- `mcmc.init_from_vb: yes`
- `vb_warm_start_control.progress_every: 50`
- `runtime.threads: 1`
- `runtime.root_scheduler: load_balanced`
- `multiseed.enabled: no`
- `multiseed.mcmc_seed_reps: 1`
- `output_retention.keep_draws: no`
- `output_retention.save_forecast_objects: no`
- `output_retention.save_compact_fit_paths: yes`
- `output_retention.retain_full_rds_on_failure: no`

Resource policy:

- Use `workers = 9` for the full confirmation launch, one root per worker.
- Export thread caps in the launcher:
  `OMP_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`, `MKL_NUM_THREADS=1`,
  `VECLIB_MAXIMUM_THREADS=1`, `NUMEXPR_NUM_THREADS=1`.
- Do not use 64 workers for this lane because there are only nine roots and the
  selected MCMC implementation is root-parallel. Extra cores do not help unless
  we enable multiseed or nested parallelism, which would make diagnostics and
  storage less clean.
- Leave a small amount of headroom for the healthcheck, shells, and Article
  work. If the machine is otherwise idle, `workers = 9` is still the cleanest
  setting.

## Stages And Gates

1. Materialize the MCMC winner lane.
   - Write the winners CSV from the frozen table above.
   - Generate profiles, cell assignments, defaults, and a grid with exactly nine
     enabled roots.
   - Gate: materialization manifest reports exactly nine selected roots and the
     expected root IDs match this document.

2. Prepare-only dry run.
   - Command shape:
     ```bash
     Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
       --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation_defaults.yaml \
       --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation_grid.csv \
       --batch full \
       --methods mcmc \
       --likelihoods exal \
       --fit-sizes 500 \
       --priors rhs_ns \
       --allow-grid-subset \
       --prepare-only \
       --workers 9 \
       --scheduler load_balanced \
       --run-tag qdesn-tt500-mcmc-vb-winner-confirmation-prepare-YYYYMMDD__git-SHA
     ```
   - Gate: selected grid has nine rows, selected atomic specs has nine MCMC exAL
     RHS specs, and no active `/home/jaguir26/local/src` paths appear.

3. Smoke run.
   - Use the highest-risk root first:
     `gausmix tau=0.05`, profile
     `tt500vb_f3_d2_n20_a0p05_r0p6_m15_lag15_rl0_pw0p03_pin0p3`.
   - Smoke budget: `n_burn = 2`, `n_mcmc = 4`, `progress_every = 1`.
   - Gate: one root succeeds, rolling-origin output schema is valid, progress
     trace is nonempty, and storage-light checks pass.

4. Micro-pilot.
   - Run two roots:
     - `gausmix tau=0.05` for the D=2 exception and weakest VB margin.
     - `laplace tau=0.05` for a representative Stage 4A primary profile cell.
   - Suggested budget: `n_burn = 200`, `n_mcmc = 500`, `progress_every = 50`.
   - Gate: no failures, finite metrics, signoff rows present, progress rows show
     active iteration movement, and no forbidden binary payloads are retained.

5. Full TT500 MCMC confirmation.
   - Run exactly the nine roots above with `workers = 9`.
   - Suggested run tag:
     `qdesn-tt500-mcmc-vb-winner-confirmation-full-YYYYMMDD__git-SHA`.
   - Gate: all nine roots finish with explicit `SUCCESS` or documented `FAIL`;
     failures are not hidden or silently retried into the final table.

6. Audit and Article promotion.
   - Build an Article-facing MCMC replacement interface only after the full lane
     passes strict audit.
   - Compare against:
     - prior Q-DESN MCMC TT500 rows,
     - Q-DESN VB promoted rows,
     - DQLM/exDQLM MCMC rows,
     - DQLM/exDQLM VB rows.
   - Promote only if provenance, source hash, rolling-origin metadata, status
     fields, metric columns, runtime, and storage-light checks are complete.

## Tests Required Before Full Launch

- materializer writes exactly nine winners and nine roots
- all winner root IDs are present in the generated grid
- defaults set `methods = mcmc`, `likelihood_families = exal`, and TT500 only
- MCMC budget is nonzero only in the MCMC lane
- `progress_every = 50` in the full MCMC lane and `1` in smoke
- `init_from_vb = TRUE` and `require_init_from_vb = TRUE`
- `multiseed.enabled = FALSE` and `mcmc_seed_reps = 1`
- `root_scheduler = load_balanced`
- storage-light retention forbids routine successful `.rds`, `.rda`, `.RData`
- stale-path scan rejects active `/home/jaguir26/local/src`
- prepare-only produces no forbidden binary payloads
- smoke produces progress traces and compact status rows
- healthcheck reports percent complete, root status mix, fit status mix, latest
  progress age, retained heavy artifacts, and stale classification

## Risks

- MCMC may not preserve VB dominance. VB dominance is evidence for promising
  structure, not a guarantee that long MCMC sampling will have the same forecast
  ranking.
- The `gausmix tau=0.05` margin is very tight on forecast pinball
  (`0.99653` ratio to the best VB baseline), so this cell should be the first
  smoke and the first audited full-run cell.
- Reusing old full MCMC rows would be misleading because they use older Q-DESN
  specs and older Article interface IDs. The new MCMC confirmation must be
  clearly separated.
- Enabling multiseed MCMC now would increase compute and storage complexity. It
  should be reserved for a targeted repair if a specific root fails or mixes
  badly.

## Recommendation

Proceed with this selective MCMC confirmation lane after implementation and
dry-run/smoke gates pass. This is the optimal next step because it tests the
actual promoted VB winners under the MCMC estimator without reopening a broad
screen, without launching TT5000, and without consuming unnecessary cores.

Do not launch the full MCMC run directly from this document. First implement the
lane files, run tests, run prepare-only, run the one-root smoke, and inspect the
audit output.

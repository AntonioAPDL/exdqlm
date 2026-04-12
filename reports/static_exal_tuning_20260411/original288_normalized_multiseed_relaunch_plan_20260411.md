# Original288 Normalized Multi-Seed Relaunch Plan (0.4.0)

Date: `2026-04-11`

## Status

As of `2026-04-12`, this plan is superseded for the main relaunch objective.

It documents the normalized/generic relaunch design that was implemented and
then intentionally invalidated. The reason is simple: the user requirement is a
true exact-spec replay per row, not a generic normalized policy test.

The correct target is:

- keep each row's previously accepted/best spec exactly
- preserve row-local kernels, proposals, adaptation, slice controls, refresh
  cadence, initialization, and other local tuning choices
- change only:
  - `n.burn = 5000`
  - `n.mcmc = 20000`
  - stored posterior draws `= 20000`
  - deterministic `4`-seed expansion and seed reduction

## Purpose

This note defines the next major relaunch after the corrected `rhs_ns`
comparison refresh.

The goal is to normalize the active `0.4.0` validation machinery so that:

1. all current `mcmc` study rows use the same retained-chain budget
2. all current `vb` study rows export the same posterior-draw count
3. every rerun is reproducible under an explicit multi-seed policy
4. seed selection is deterministic, documented, and metric-backed
5. the full relaunch can be staged safely instead of launched ad hoc

This is a living plan. As of the current `2026-04-11` implementation refresh:

- Deliverable `1` is implemented
- Deliverable `2` is implemented
- Deliverable `3` is implemented
- Deliverable `4` is implemented at the launcher-validation level
- Deliverable `5` is implemented in the staged supervisor
- Deliverable `6` is implemented as an automatic post-run refresh path

The full relaunch is therefore no longer blocked on missing infrastructure.
The remaining gating question is only execution progress once the staged
supervisor is launched.

## Current Progress

Implemented artifacts now include:

- normalized universe and control audit
- frozen seed bank
- pilot and full manifests
- unified run-row wrapper
- evaluator
- seed reducer
- normalized selection refresh
- patched table-backed comparison that accepts explicit normalized outputs
- staged launcher with pilot-first sequencing

Validation already completed:

- syntax parse checks for all new R scripts
- `bash -n` for the launcher
- successful prepare with `48` pilot rows and `1152` full rows
- `0` missing inputs after path hardening
- launcher `--prepare-only`
- launcher `--dry-run`
- one completed real static native pilot row with normalized metrics + draw export

## Requested Normalization Target

The requested normalization policy is:

| component | target |
|---|---|
| `mcmc` burn-in | `5000` for every rerun |
| `mcmc` retained post-burn draws | `20000` for every rerun |
| stored posterior draws for accepted/selected `mcmc` outputs | `20000` |
| stored posterior draws for rerun `vb` outputs | `20000` |
| seed policy | `4` deterministic seeds per study row when feasible |
| seed winner rule | best gate first, then best metric |

The intended winner rule is:

1. prefer `PASS` over `WARN` over `FAIL`
2. if multiple seeds tie on gate, choose the lower `crps`
3. if all seeds `FAIL`, choose the lower `crps` among the failed seeds
4. if `crps` also ties, use deterministic secondary tie-breakers

## Current Investigated State

The current branch already supports reproducible row-wise reruns, but it is
not yet normalized to the target policy above.

### What the current dynamic repaired fits show

The currently readable promoted dynamic `exdqlm / mcmc` fits are not yet
uniform:

| scenario | `n.burn` | kept draws | stored posterior draws |
|---|---:|---:|---:|
| `gausmix / 0p25 / TT500` | `5000` | `20000` | `20000` |
| `laplace / 0p05 / TT500` | `4000` | `16000` | `16000` |
| `normal / 0p05 / TT500` | `4500` | `18000` | `18000` |

So the current repaired dynamic state is improved, but not normalized.

### Current runner defaults are smaller than the target policy

The generic runner currently falls back to smaller defaults:

- dynamic `mcmc` defaults are effectively around `2000 / 1500`
- static `mcmc` defaults are effectively around `3000 / 8000`
- dynamic `vb` currently uses `n.samp` on the order of `200`
- static `vb` currently exposes `n_samp_xi`, which is not the same thing as a
  standardized stored posterior-draw count

Relevant surfaces:

- `tools/merge_reports/LOCAL_full288_case_runner_20260327.R`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_helpers_20260410.R`

### Current rerun lanes are mostly single-seed

The current restored dynamic prepare step resolves one baseline seed per case
and writes that single seed into the manifest. The execution stack does not yet
implement best-of-`4` seed expansion or seed reduction.

### Current comparison logic is already durable

The current table-backed comparison is stable and should remain the comparison
backbone after the normalized relaunch:

- `reports/static_exal_tuning_20260411/original288_tablebacked_cluster_comparison_20260411.md`
- `tools/merge_reports/LOCAL_original288_tablebacked_cluster_comparison_20260411.R`

That comparison now provides the durable branch-level benchmark for:

- static `mcmc`
- static `vb`
- dynamic `mcmc`
- dynamic `vb`

## Key Design Constraint: CRPS Is Not Yet Universal

The requested winner rule uses `crps` as the main metric. That is clean for the
dynamic study, but the current corrected static comparison is not yet built on
a universal static `crps` export.

Current state:

- dynamic comparison already works with draw-based predictive metrics and can
  support a `crps` tie-break cleanly
- static comparison currently uses native validation-table metrics such as
  `rmse`, `coverage`, `mean_ci_width`, `cie`, and `beta` diagnostics
- static `vb` does not currently expose a standardized stored posterior-draw
  object in the same way that dynamic `vb` exposes `n.samp`

Therefore, if we want the winner rule to truly use `crps` across **all**
rerun rows, we need a new common posterior-predictive export layer.

## Planning Decision

To honor the requested seed-selection policy cleanly, the normalized relaunch
should add a **common posterior-predictive draw standard** across both static
and dynamic fits.

The target is:

- every rerun fit writes or can deterministically regenerate
  `20000` posterior predictive draws
- every rerun fit writes a lightweight metrics record that includes `crps`
- the seed reducer ranks seeds using the same gate-plus-`crps` rule everywhere

This avoids using one winner rule for dynamic and a different hidden rule for
static.

## Normalization Policy

### MCMC

All normalized `mcmc` reruns should use:

| field | value |
|---|---:|
| `n.burn` | `5000` |
| `n.mcmc` | `20000` |
| stored posterior draws | `20000` |
| effective default thin | `1` unless a documented lane overrides it |

Important rule:

- any exception to `5000 / 20000 / 1` must be written into the manifest as an
  explicit per-row override, not hidden inside a helper default

### VB

The VB relaunch should target:

| field | value |
|---|---:|
| stored posterior predictive draws | `20000` |
| seed handling | same deterministic multi-seed framework |

Important nuance:

- dynamic `vb` already has an explicit `n.samp` control
- static `vb` does **not** currently expose the same stored-draw contract
- static `vb` therefore needs a post-fit draw-export adapter rather than just a
  larger `n_samp_xi`

### Seed policy

Every rerun row should expand to `4` deterministic seeds:

- one `study row`
- four `seed rows`
- one selected winner row after reduction

The seed set must be fixed and versioned, not generated implicitly at runtime.

## Reproducibility Rules

### Seed bank

We should create a machine-readable seed bank such as:

- `tools/merge_reports/LOCAL_original288_normalized_multiseed_seedbank_20260411.csv`

Required columns:

- `original_case_key`
- `block`
- `family`
- `tau`
- `fit_size`
- `prior_semantics`
- `model`
- `inference`
- `seed_slot`
- `seed`

Seed-bank rules:

1. generated once from a deterministic recipe
2. committed to the branch
3. reused by every later normalized relaunch
4. never silently regenerated

### Artifact retention

Because `288 × 4` reruns with `20000` stored draws can become large, the
artifact policy should be tiered:

| artifact type | keep for all 4 seeds | keep only for selected seed |
|---|---|---|
| run config | yes | yes |
| seed info | yes | yes |
| health CSV | yes | yes |
| metrics CSV | yes | yes |
| selection rank CSV | yes | yes |
| full heavy fit object | temporary or optional | yes |
| standardized `20000` posterior draws | temporary or optional | yes |

This keeps the selection reproducible without forcing long-term storage of all
heavy loser artifacts.

### Seed selection reducer

The reducer should produce a ranked per-seed table and a single selected seed
per original study row.

Required ranking keys:

1. `gate_rank` where `PASS < WARN < FAIL`
2. lower `crps`
3. lower current primary-accuracy metric if available
4. lower runtime
5. smaller seed value

That last step removes ambiguity if two seeds are otherwise numerically tied.

## Implementation Map

The relaunch should be built around the current generic runner instead of
introducing another ad hoc runner family.

### Core implementation surfaces

| area | file(s) | expected change |
|---|---|---|
| generic execution | `tools/merge_reports/LOCAL_full288_case_runner_20260327.R` | normalize `mcmc` defaults, add seed-row metadata, add draw-export hooks |
| dynamic relaunch prior art | `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_*.R` | reuse manifest/evaluate patterns, but replace single-seed logic |
| comparison layer | `tools/merge_reports/LOCAL_original288_tablebacked_cluster_comparison_20260411.R` | point to normalized selected-seed outputs |
| dynamic `vb` draws | `R/exdqlmLDVB.R` and runner wrapper | standardize `n.samp = 20000` and exported predictive draws |
| static `vb` draws | `R/exal_static_LDVB.R` plus runner wrapper | add reproducible post-fit predictive-draw export |
| dynamic `mcmc` | `R/exdqlmMCMC.R` via runner configs | normalize `n.burn`, `n.mcmc`, and stored-draw persistence |
| static `mcmc` | `R/exal_static_mcmc.R` via runner configs | normalize `n.burn`, `n.mcmc`, stored draws, and selection telemetry |
| common `crps` | `R/utils.R` and reporting wrappers | reuse `.exdqlm_crps_vec` for the unified seed reducer |

### New planned artifacts

| artifact | role |
|---|---|
| normalized seed bank CSV | frozen four-seed registry |
| normalized manifest CSV | one row per seed-run candidate |
| seed-level manifest-status CSV | operational progress |
| seed-ranking CSV | deterministic winner reduction |
| selected-seed carry-forward CSV | one chosen fit per study row |
| normalized metric-long CSV | one row per chosen study cell |
| normalized comparison report | refreshed cluster comparison after relaunch |

## Staged Deliverables

### Deliverable 1: Control-state audit and seed-bank freeze

Output:

- full inventory of current control settings for all `288` rows
- frozen `4`-seed bank
- clear classification of which rows currently lack standardized draw export

Purpose:

- turn the normalization target into explicit machine-readable inputs
- remove hidden configuration drift before implementation

### Deliverable 2: Normalized runner layer

Output:

- generic runner patch for normalized `mcmc`
- dynamic `vb` set to `n.samp = 20000`
- static `vb` draw-export adapter
- seed-aware manifest expansion

Purpose:

- make the requested policy executable on the current `0.4.0` branch

### Deliverable 3: Seed reducer and winner-selection tables

Output:

- seed-level metrics table
- ranked seed-selection table
- selected-seed output table

Purpose:

- ensure every relaunch row has one durable, documented chosen winner

### Deliverable 4: Cross-path pilot

Output:

- a small pilot manifest covering all critical execution paths
- smoke-tested draw counts
- smoke-tested seed reduction

Recommended pilot coverage:

- static `paper / exal / mcmc`
- static `paper / exal / vb`
- static `shrink / rhs_ns / exal / mcmc`
- static `shrink / ridge / exal / vb`
- dynamic `exdqlm / mcmc / TT500`
- dynamic `exdqlm / mcmc / TT5000`
- dynamic `exdqlm / vb / TT500`
- dynamic `exdqlm / vb / TT5000`
- at least one `al` or `dqlm` control row in each block

Purpose:

- verify that all code paths can produce `20000` stored draws and seed-ranked
  outputs before the full relaunch

### Deliverable 5: Full staged relaunch

Recommended order:

1. static `mcmc`
2. static `vb`
3. dynamic `vb`
4. dynamic `mcmc`

Why this order:

- static paths are already scientifically stable and should be the first
  normalization anchor
- dynamic `vb` is operationally easier than dynamic `mcmc`
- dynamic `mcmc` remains the hardest tail and should launch only after the
  normalized infrastructure has been proven elsewhere

### Deliverable 6: Post-relaunch selection and comparison refresh

Output:

- new normalized carry-forward selection
- new health summary
- refreshed table-backed cluster comparison
- updated branch status note and trackers

Purpose:

- turn the normalized reruns into the new branch-level source of truth

## Testing And Validation Gates

No full relaunch should start until the following pass:

### Configuration tests

- seed-bank determinism test
- manifest expansion test
- per-row config serialization test
- prepare-only test
- dry-run launch test

### Output-contract tests

- `mcmc` retained draw count equals `20000`
- dynamic `vb` stored predictive draws equal `20000`
- static `vb` exported predictive draws equal `20000`
- metrics CSV contains `crps`
- seed-ranking reducer returns exactly one selected winner per study row

### Comparison integrity tests

- normalized metric extraction has `0` missing rows on the pilot
- refreshed comparison tables build without manual patching
- selected-seed comparison is stable under rerun with the same seed bank

## Efficiency And Resource Policy

The full normalized relaunch is large:

- `288` study rows
- `4` seeds each
- potentially `1152` seed-level executions if both `mcmc` and `vb` fully use
  the multi-seed policy

To keep this efficient:

1. pilot first
2. keep BLAS/OpenMP threads at `1` per worker
3. parallelize across rows, not within-row math threads
4. use lane-specific worker caps based on pilot memory telemetry
5. keep full heavy loser artifacts only temporarily

Initial recommended worker envelope to validate during the pilot:

| lane | initial cap |
|---|---:|
| static `vb` | `8` |
| static `mcmc` | `4` |
| dynamic `vb` | `6` |
| dynamic `mcmc` | `3` |

These are starting points only. The pilot should confirm or revise them.

## Risks And Mitigations

| risk | why it matters | mitigation |
|---|---|---|
| storage explosion | `4` seeds × `20000` draws can get large quickly | keep lightweight artifacts for all seeds, heavy draws for selected winners |
| static `vb` draw ambiguity | `n_samp_xi` is not a direct stored-posterior contract | implement a dedicated post-fit draw-export adapter |
| seed cherry-picking confusion | selecting the best seed can look opaque | commit seed bank, per-seed metrics, and reducer tables |
| silent config drift | helper defaults differ today | move normalized policy into explicit manifest/config tables |
| dynamic `mcmc` instability | still the hardest path scientifically | launch it last after pilot and easier lanes pass |

## Current Recommendation

The right next move is **not** to launch immediately.

The right next move is to implement Deliverables `1` through `4` first:

1. freeze the seed bank
2. normalize the runner/output contracts
3. build the seed reducer
4. pass a cross-path pilot

Only after that should we do the full normalized relaunch.

## Intended Living-Document Role

This file should stay live and be updated as the work progresses.

Recommended update points:

- after the seed-bank freeze
- after the runner/output normalization patch
- after the pilot
- before the full relaunch
- after the post-relaunch comparison refresh

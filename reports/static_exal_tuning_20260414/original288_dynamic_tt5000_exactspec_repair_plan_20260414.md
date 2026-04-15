# Original288 Dynamic TT5000 Exact-Spec Repair Plan (0.4.0)

Date: `2026-04-14`

## Purpose

This plan closes the remaining comparison gap left by the completed
exact-spec multiseed replay.

The replay-based comparison refresh at:

- `reports/static_exal_tuning_20260412/original288_tablebacked_cluster_comparison_exactspec_multiseed_20260412.md`

left `36 / 288` rows without usable fit metrics because the replay-selected
winners were all `runtime_fail` on the dynamic `TT5000` block.

That unresolved pocket is:

- `3` families: `gausmix`, `laplace`, `normal`
- `3` taus: `0p05`, `0p25`, `0p95`
- `2` models: `dqlm`, `exdqlm`
- `2` inference methods: `vb`, `mcmc`
- total unresolved rows: `36`

## Why This Is The Safe Next Step

This is the narrowest relaunch that can make the comparison scientifically
complete again.

It is safer than another full-study replay because it:

- preserves the already completed static replay and its selected winners
- touches only the unresolved dynamic `TT5000` rows
- keeps exact-source provenance in phase 1
- uses historical row-local repair candidates only after exact replay still
  fails
- refreshes the table-backed comparison automatically after reduction

## Baselines And Source Of Truth

Current failing replay selection:

- `tools/merge_reports/LOCAL_original288_comparison_selection_exactspec_multiseed_v1_20260412.csv`

Current accepted comparison baseline:

- `tools/merge_reports/LOCAL_original288_comparison_selection_rhsns_v1_20260411.csv`

Historical reusable repair pool:

- `tools/merge_reports/LOCAL_original288_candidate_pool_v1_20260405.csv`

## Correctness Rules

### Phase 1 exact replay

For every unresolved dynamic `TT5000` row:

- preserve the exact accepted or selected source run config
- preserve the row-local model / inference / prior semantics
- preserve row-local kernel / proposal / joint / adapt / slice / refresh /
  init settings embedded in the exact source config
- change only:
  - `n.burn = 5000`
  - `n.mcmc = 20000`
  - stored posterior draws `= 20000`
  - deterministic `4`-seed expansion

### Phase 2 historical repair

Only for rows that still select to `FAIL` after phase 1:

- pull row-local historical `PASS` / `WARN` `TT5000` candidates from prior
  dynamic repair waves
- preserve their candidate-specific local controls when recoverable:
  - proposal family
  - adapt setting
  - slice width / slice max steps
  - Laplace refresh interval / start / weight
  - VB-init usage
  - trace cadence
  - historical source seed
- again change only:
  - `n.burn = 5000`
  - `n.mcmc = 20000`
  - stored posterior draws `= 20000`
  - deterministic `4`-seed expansion

## Execution Design

### Phase layout

1. prepare exact phase-1 manifests and audits
2. run phase-1 exact replay on the `36` unresolved rows
3. evaluate and reduce phase 1
4. build phase-2 manifest only for still-failing cases
5. run the recovered historical repair candidates
6. evaluate and reduce the combined manifest
7. refresh repaired comparison-selection tables
8. regenerate the table-backed cluster comparison

### Expected row counts

- target rows: `36`
- phase-1 rows: `144` (`36 x 4` seeds)
- phase-2 candidate inventory currently resolved: `13`
- phase-2 rows if every currently supported historical candidate is needed:
  `52`

Phase 2 is intentionally sparse rather than brute-force. It is a repair lane,
not a new generic tuning search.

## Success Criteria

Primary success:

- repair enough dynamic `TT5000` rows to eliminate the `36 / 288` comparison
  hole
- regenerate a table-backed comparison with full dynamic coverage

Secondary success:

- preserve exact-source provenance for phase 1
- preserve historical candidate-specific controls for phase 2
- keep the run machine-auditable and reproducible

## Validation Requirements Before Launch

Must pass before launch:

- parser/syntax checks for the full repair stack
- `bash -n` for the launcher
- prepare pass with `0` missing phase-1 inputs
- launcher `--prepare-only=1`
- launcher `--dry-run=1 --skip-prepare=1`
- focused smoke runs covering:
  - phase-1 dynamic `mcmc`
  - phase-1 dynamic `vb`
  - phase-2 historical slice / tierA / targeted-manifest paths

Important interpretation rule:

- negative smoke outcomes on these rows are not by themselves a launch blocker
  because these are precisely the currently unresolved failing cases
- the actual launch blocker is provenance drift or broken execution plumbing,
  not the absence of an immediate rescue in one smoke seed

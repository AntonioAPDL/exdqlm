# Original288 Dynamic TT5000 Exact-Spec Repair Execution (0.4.0)

Date: `2026-04-14`

## Status

This note records the implementation validation and launch state for the
targeted dynamic `TT5000` exact-spec repair wave.

## Why This Relaunch Is The Right One

This is the most conservative repair path that still addresses the real gap in
the replay-based comparison:

- it does **not** relaunch the full `288` rows
- it does **not** replace row-local configs with generic tuning
- it first retries the exact current row-level source configs
- it only then falls back to historically successful row-local repair
  candidates

## Validation Checklist

Implementation checks completed:

- parser/syntax checks passed for:
  - `LOCAL_original288_dynamic_tt5000_exactspec_repair_helpers_20260414.R`
  - `LOCAL_original288_dynamic_tt5000_exactspec_repair_prepare_20260414.R`
  - `LOCAL_original288_dynamic_tt5000_exactspec_repair_build_phase2_20260414.R`
  - `LOCAL_original288_dynamic_tt5000_exactspec_repair_run_row_20260414.R`
  - `LOCAL_original288_dynamic_tt5000_exactspec_repair_evaluate_20260414.R`
  - `LOCAL_original288_dynamic_tt5000_exactspec_repair_reduce_20260414.R`
  - `LOCAL_original288_dynamic_tt5000_exactspec_repair_refresh_comparison_20260414.R`
- `bash -n` passed for:
  - `LOCAL_original288_dynamic_tt5000_exactspec_repair_launch_20260414.sh`

Prepare validation completed:

- target rows: `36`
- phase-1 rows: `144`
- phase-2 historical candidates: `13`
- missing phase-1 inputs: `0`

Launcher validation completed:

- `bash tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_launch_20260414.sh --prepare-only=1`
  passed
- `bash tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_launch_20260414.sh --dry-run=1 --skip-prepare=1`
  passed

## Historical-Control Validation

The earlier weak point in phase 2 was candidate drift: the repair inventory
could resolve a case-level source config without preserving the local tuning
that made the old repair candidate viable.

This has now been hardened:

- all `13 / 13` phase-2 historical candidates resolve to a source artifact
- phase-2 inventory now carries candidate-local controls when available:
  - `hist_mh_proposal`
  - `hist_mh_adapt`
  - `hist_slice_width`
  - `hist_slice_max_steps`
  - `hist_laplace_refresh_interval`
  - `hist_laplace_refresh_start`
  - `hist_laplace_refresh_weight`
  - `hist_init_from_vb`
  - `hist_vb_path`
  - historical source seed and baseline fit path
- generated phase-2 configs were inspected directly and confirmed to preserve
  recovered historical controls while standardizing to:
  - `n.burn = 5000`
  - `n.mcmc = 20000`
  - stored posterior draws `= 20000`

Representative verified configs:

- `hist_01_row15_slice_exact_20260405`
  - `proposal = slice`
  - `adapt = FALSE`
  - `slice_width = 0.12`
  - `slice_max_steps = 80`
  - `laplace_refresh_interval = 50`
  - `laplace_refresh_start = 200`
  - `laplace_refresh_weight = 0.6`
- `hist_01_tierA_sync_20260322_Q01_dqlm_tau0p05_tt5000_normal`
  - `proposal = slice`
  - `adapt = FALSE`
  - `slice_width = 0.12`
  - `slice_max_steps = 80`
  - `init_from_vb = TRUE`

## Focused Smoke Runs

Focused smoke rows were run after the hardened phase-2 rebuild:

| row | phase | case | result |
|---|---|---|---|
| `1` | phase 1 | `dynamic::gausmix::0p05::5000::default::dqlm::mcmc` | `FAIL` |
| `5` | phase 1 | `dynamic::gausmix::0p05::5000::default::dqlm::vb` | `FAIL` |
| `145` | phase 2 | `dynamic::gausmix::0p05::5000::default::dqlm::mcmc` | `FAIL` |
| `157` | phase 2 | `dynamic::gausmix::0p25::5000::default::exdqlm::mcmc` | `FAIL` |
| `181` | phase 2 | `dynamic::normal::0p05::5000::default::dqlm::mcmc` | `FAIL` |

Representative smoke failure modes:

- `chi has non-finite values at iter=1`
- `system is computationally singular`

Interpretation:

- these smoke outcomes are scientifically negative, but they are not evidence
  of spec drift
- they are consistent with the current unresolved status of this block
- the smoke stage succeeded in the operational sense:
  - the right configs were built
  - the right manifests were read
  - the right row-local failure paths were exercised
  - row / health / metric artifacts were written cleanly

## Launch State

The repair wave is now live in tmux.

Supervisor session:

- `original288-dynamic-tt5000-exactspec-repair-20260414`

Monitor session:

- `original288-dynamic-tt5000-exactspec-repair-monitor-20260414`

Console log:

- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_launcher_console_20260414.log`

Startup snapshot captured immediately after launch:

- prepare reran successfully inside the supervisor
- prepare emitted:
  - `36` target rows
  - `144` phase-1 rows
  - `13` phase-2 historical candidates
  - `0` missing phase-1 inputs
- prelaunch evaluator at launch time:
  - `0 / 144` done
  - `144 / 144` pending
- first active phase:
  - `phase1_dynamic_tt5000_exact_replay`
- active worker cap at launch:
  - `3`

Live structure:

- phase 1 exact replay on all `36` unresolved `TT5000` rows with `4` seeds
- phase 2 historical repairs only for rows still selecting to `FAIL`
- automatic post-run selection refresh
- automatic comparison refresh

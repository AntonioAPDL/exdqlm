# Original 288 Dynamic Tail-7 Geometry Program

Date: 2026-04-06

This document defines the next residual dynamic repair phase after the
tail-8 closure pass promoted one additional original dynamic case and moved the
corrected original-`288` carry-forward table to `281 / 288` healthy.

## Starting State

- publication-target universe: original `288`
- healthy now: `281 / 288`
- unresolved now: `7 / 288`
- unresolved block: dynamic only
- unresolved method family: `mcmc :: exdqlm` only

Authoritative carry-forward references:

- `tools/merge_reports/LOCAL_original288_carryforward_selection_v3_20260406.csv`
- `tools/merge_reports/LOCAL_original288_health_summary_v3_20260406.csv`
- `tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v3_20260406.csv`
- `tools/merge_reports/LOCAL_original288_audit_v3_20260406.csv`

## What Improved

- tail-8 produced one clear new rescue:
  - `dynamic::gausmix::0p95::500::default::exdqlm::mcmc`
  - promoted from baseline `FAIL` to `PASS`
- corrected dynamic healthy coverage improved from `64 / 72` to `65 / 72`
- corrected overall healthy coverage improved from `280 / 288` to `281 / 288`
- the unresolved tail shrank from `8` to `7`
- the remaining debt is now even more concentrated in the low-tail
  `exdqlm :: mcmc` corridor

## What Still Fails

Only these `7` original dynamic case keys remain unresolved:

- `dynamic::gausmix::0p05::500::default::exdqlm::mcmc`
- `dynamic::gausmix::0p05::5000::default::exdqlm::mcmc`
- `dynamic::gausmix::0p25::500::default::exdqlm::mcmc`
- `dynamic::laplace::0p05::500::default::exdqlm::mcmc`
- `dynamic::laplace::0p05::5000::default::exdqlm::mcmc`
- `dynamic::normal::0p05::500::default::exdqlm::mcmc`
- `dynamic::normal::0p05::5000::default::exdqlm::mcmc`

Residual shape:

- `4` at `TT500`
- `3` at `TT5000`
- `6` at `tau = 0p05`
- `1` at `tau = 0p25`

## What Worked Best

- correcting the original-`288` carry-forward table before more tuning
- archive-first promotion
- explicit same-scenario healthy `exdqlm :: vb` warm starts
- slice-based `exdqlm :: mcmc` rescues with:
  - `mh.proposal = slice`
  - `mh.adapt = FALSE`
  - `init.from.vb = TRUE`
- the exact `0.12 / 80` slice geometry on moderate and upper-tail analogs
- using the corrected original case key as the only promotion unit

## What Did Not Help

- reopening any static work
- rerunning archive rescoring after the archive stage already completed
- keeping the broader mixed residual manifest after the tail isolated to the
  `exdqlm :: mcmc` tail
- the long low-tail rerun at the old exact geometry:
  - `slice.width = 0.12`
  - `slice.max.steps = 80`
  - `n.burn = 2000`
  - `n.mcmc = 8000`
- broad corridor changes outside slice-based local repair

## Highest-Value Direction

The remaining failures look like slice-corridor cases that are still
ESS-limited, not collapsed fits. The highest-value next step is therefore to:

1. keep the validated slice-with-VB-init rescue corridor
2. change the slice geometry rather than only extending chain length
3. test that geometry band on all `7` unresolved rows
4. reserve a longer follow-up only for the dominant `tau = 0p05` cluster
5. avoid rerunning already-screened exact `0.12 / 80` short and long configs

## Tail-7 Program Design

### Stage 1: `anchor7_slice_band18`

Scope:

- all `7` unresolved original dynamic cells

Configuration:

- `mcmc_exdqlm_slice_band18`
- `mh.proposal = slice`
- `mh.adapt = FALSE`
- `n.burn = 1200`
- `n.mcmc = 4000`
- `trace.every = 50`
- `slice.width = 0.18`
- `slice.max.steps = 120`
- `init.from.vb = TRUE`
- explicit healthy same-scenario `exdqlm :: vb` warm start

Reason:

- closest geometry expansion around the only modern corridor that is actually
  producing `PASS` or `WARN` rescues

### Stage 2: `anchor7_slice_band24`

Scope:

- all `7` unresolved original dynamic cells

Configuration:

- `mcmc_exdqlm_slice_band24`
- same runtime budget and same VB warm-start policy
- more aggressive geometry:
  - `slice.width = 0.24`
  - `slice.max.steps = 160`

Reason:

- the old exact slice geometry is now screened out on this tail
- the remaining low-tail cases may need a wider bracket and more stepping
  rather than just more iterations

### Stage 3: `tau05_long6_slice_band18`

Scope:

- only the `6` unresolved `tau = 0p05` cases

Configuration:

- `mcmc_exdqlm_slice_band18_long`
- same band-18 geometry and same VB warm starts
- longer runtime budget:
  - `n.burn = 2000`
  - `n.mcmc = 8000`

Reason:

- `tau = 0p05` remains the dominant unresolved cluster
- long reruns are still justified there, but only after the geometry shift

## Explicit Exclusions

These are intentionally excluded from this phase:

- static reruns of any kind
- `dqlm :: mcmc` work
- `exdqlm :: vb` work
- archive rescoring
- the old exact short `0.12 / 80` tail-8 anchor
- the old exact long `0.12 / 80` low-tail follow-up
- broader mixed residual manifests
- non-slice generic MCMC corridors

## Planned Schedule

| phase | rows | rationale |
|---|---:|---|
| `anchor7_slice_band18` | `7` | moderate geometry expansion on the full remaining tail |
| `anchor7_slice_band24` | `7` | wider geometry expansion on the full remaining tail |
| `tau05_long6_slice_band18` | `6` | longer follow-up only on the dominant low-tail cluster |
| `total` | `20` | dynamic-only geometry-band closure program |

## Promotion Rule

Promote only when a tail-7 candidate:

1. maps to the same `original_case_key`
2. yields `PASS` or `WARN`
3. strictly improves the baseline `FAIL`

Tie-breaking among non-`FAIL` candidates:

1. `PASS` over `WARN`
2. `anchor7_slice_band18` over `anchor7_slice_band24`
3. shorter anchor over long low-tail follow-up when the gate ties
4. faster runtime only after gate and phase preference tie

## Validation Requirements Before Launch

- prepare writes exactly `20` rows
- every row has an explicit healthy `vb_candidate_fit_path`
- no row is marked `missing_inputs = TRUE`
- evaluator works on the empty pre-launch state
- selection preview works against carry-forward `v3`
- launch/supervisor/monitor pass `bash -n`
- branch is committed and pushed cleanly before overnight launch

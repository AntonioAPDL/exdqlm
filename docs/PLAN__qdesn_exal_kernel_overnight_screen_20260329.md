# QDESN exAL Kernel Overnight Screen Plan

- date: `2026-03-29`
- purpose: efficiently map active-control response on the fresh 6-root closeout harness before package-level kernel redesign work
- runner: `scripts/run_qdesn_exal_kernel_screen.R`
- manifest: `config/validation/qdesn_exal_kernel_screen_manifest.yaml`

## Why This Plan Exists

The current fresh failure picture says the next redesign should target the shared `exal` core, but we can still extract more information tonight without changing package code.

This screen is designed to answer three questions quickly:

1. How much improvement is available from active `exal` core controls alone?
2. How much of the rhs_ns residue is start-state or tau-release sensitive?
3. Is a modest chain increase ever competitive with better active-control settings, or does it again fail on runtime efficiency?

## Experimental Design

The screen reuses the fresh 6-root micro-pilot selected by closeout:

- 4 severe `all_four` roots
- 2 lighter `drift_geweke` sentinels

The grid is staged by learning objective rather than brute-force factorial:

### Anchor

- `X0_anchor_baseline`

Purpose:

- verify the screen harness reproduces the current post-fix baseline under the same 6-root setup

### Core Screen

- `X1_core_pass1_soft`
- `X2_core_pass2_soft`
- `X3_core_pass1_sharp`
- `X4_core_pass2_sharp`

Purpose:

- test whether the severe `exal` failures are primarily responsive to active `gamma/sigma` core controls
- isolate the value of `core_extra_passes`
- isolate whether tighter `width_gamma/width_sigma` helps or over-constrains the chain

### rhs_ns Screen

- `X5_rhsns_freeze60_core1`
- `X6_rhsns_freeze80_core1`
- `X7_rhsns_multistart3_core1`
- `X8_rhsns_freeze60_multistart3`

Purpose:

- test whether rhs_ns residual failures respond to a longer tau freeze, better start-state selection, or both
- do this only after giving each rhs_ns profile the same moderate core refresh

### Confirmation

- `X9_moderate_chain_core1`

Purpose:

- answer the “is modest extra chain worth it after active tuning?” question without repeating the expensive near-2x runtime behavior of `P1_longer_chain`

## What Makes This Efficient

- no rerun of `T0` through `T4`
- no full failing-cell replay
- no broad dynamic matrix
- no inactive rhs slice/block retuning for `rhs_ns`
- single 6-root harness reused for every profile
- only `2` campaign workers to keep unattended execution stable

## What We Learn Tomorrow

From one screen we will be able to tell:

1. whether better active `exal` core controls can already reduce the severe quartet materially;
2. whether the rhs_ns residue is mainly tau-freeze sensitive, initialization sensitive, or neither;
3. whether any control-only profile is good enough to justify one package-level redesign path over another.

## Decision Rules

Primary readout:

- `tables/profile_rank_summary.csv`

Interpretation:

- if the best profile is a core-screen profile, start with the shared `exal` core redesign
- if rhs_ns screen profiles materially outperform the core-only profiles on the rhs_ns roots without helping ridge, then queue rhs_ns hardening as phase 2 rather than phase 1
- if the moderate-chain profile wins only narrowly at noticeably higher runtime, that is another signal to prefer geometry redesign over longer chains

## Tomorrow Morning Checklist

1. inspect `summary/screen_results.md`
2. inspect `tables/profile_rank_summary.csv`
3. inspect `tables/phase35_micro_pilot_summary.csv`
4. inspect the top 2 transition tables:
   - `tables/phase35_transitions_<profile>.csv`
5. decide which package-level redesign candidate to implement next:
   - core refresh
   - blocked core kernel
   - rhs_ns Gibbs hardening

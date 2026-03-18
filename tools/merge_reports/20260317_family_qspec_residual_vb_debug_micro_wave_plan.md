# Family-QSpec Residual VB-Debug Micro-Wave Plan

## Objective

Resolve the final residual `vb::exdqlm` failures for dynamic `tt5000` at
`tau=0.05` with a gated two-case wave:

1. canary: `root__dynamic__laplace__tau_0p05__lasttt_5000`
2. second: `root__dynamic__gausmix__tau_0p05__lasttt_5000`

If the canary remains `FAIL`, stop and do not launch the second case.

## Baseline At Start

Post-wave signoff summary after forced rebuild (`generated_at=2026-03-17 20:47:04`):

- method fits: `93 PASS`, `128 WARN`, `67 FAIL`
- method comparison-eligible: `221 / 288`
- algorithm-pair eligible: `88 / 144`
- model-pair eligible: `84 / 144`
- roots any-eligible: `72 / 72`
- roots fully eligible: `23 / 72`
- unhealthy targets: `67`

## Implemented Controls

- configurable vb-debug supervisor tuning source:
  - `tools/merge_reports/20260317_family_qspec_vb_debug_supervisor.sh --tuning-env ...`
- dynamic `tt5000` direct-commit tuning profile for hard residuals:
  - `tools/merge_reports/20260318_family_qspec_vb_debug_tuning_tt5000_direct_commit.env`
- orchestrator with no-regression rollback and strict VB quality gate:
  - `tools/merge_reports/20260317_run_family_qspec_vb_debug_residual_wave.sh`

## Orchestrator Behavior

The orchestrator:

1. snapshots baseline method/signoff summary
2. snapshots full run-root artifacts for canary and second targets
3. builds exact one-row canary and one-row second target TSVs from
   `20260314_family_qspec_unhealthy_targets.tsv`
4. launches canary with direct-commit VB tuning (`fresh_vb_then_mcmc`)
5. forces signoff/scientific refresh
6. checks no-regression against baseline (`vb` and `mcmc` rows for canary model)
7. checks VB quality gate:
   - canary `vb::exdqlm` must be `WARN` or better
   - and must improve tail diagnostics vs baseline
8. if either check fails, restores canary run-root snapshot and rebuilds signoff
9. launches second case only if canary passes all gates
10. repeats no-regression + VB quality checks for second case
11. if second fails a gate, restores second run-root snapshot and rebuilds signoff
12. computes targeted-effect delta against baseline via
   `20260317_analyze_family_qspec_targeted_effect.R`
13. writes run summary under state

## Launch

```bash
tools/merge_reports/20260317_run_family_qspec_vb_debug_residual_wave.sh --repo-root "$PWD"
```

Runtime outputs:

- state root:
  - `/home/jaguir26/local/state/exdqlm/family_qspec_vb_debug_residual_<timestamp>`
- run status:
  - `status.tsv`
- live orchestrator log:
  - `orchestrator.log`
- final summary:
  - `summary.md`

# Original-288 Static Shrink RHS_NS exAL MCMC Final Closure Program

Date: `2026-04-10`

## Purpose

This final-closure lane follows the accepted `v8` promotion and the completed
`rhs_ns` repair wave.

Current corrected shrinkage state before launch:

- accepted branch: `282 / 288` healthy
- accepted unresolved dynamic rows: `6`
- corrected `static_shrink / rhs_ns` working branch: `70 / 72` healthy
- remaining corrected static unresolved rows: `2`

Target rows:

1. `static_shrink::gausmix::0p25::1000::rhs_ns::exal::mcmc`
2. `static_shrink::normal::0p25::1000::rhs_ns::exal::mcmc`

Both rows currently fail immediately with the same corrected-branch runtime
invalid-state symptom:

- `Static MCMC state invalid (iter=2): static_exal chi has 1000 non-finite values`

## Design Rules

1. Keep the accepted `v8` branch as the default baseline.
2. Treat this as a targeted closure lane, not a new discovery sweep.
3. Do not reopen solved rows.
4. Reuse only historically informative anchors.
5. Explore both:
   - no-VB-init rw corridors near the strongest surviving historical anchors
   - materially wider/deeper slice corridors as the exact-kernel hedge
6. Avoid rerunning obviously weak rebuild defaults unchanged.

User-level tuning policy carried into this program:

- `slice` is the default exploratory exact-kernel option when it is broadly
  stronger than `laplace_rw`
- but the search remains row-local rather than forcing `slice` everywhere

## Search Space

Total candidates: `18`

- `9` candidates for row `44` (`gausmix / 0p25 / 1000`)
- `9` candidates for row `68` (`normal / 0p25 / 1000`)

Candidate families:

1. `rw_no_vb_long`
   - reopen the best historical rw corridors with `init_from_vb = FALSE`
   - use longer budgets than the earlier crash-repair wave
2. `rw_no_vb_noadapt`
   - test whether adaptation itself is reintroducing the corrected-branch crash
3. `slice_no_vb_wide`
   - widen the slice corridor far beyond the earlier token probes
4. `slice_no_vb_deep`
   - keep the exact kernel but give it a more serious path length

## Why These Candidates Were Included

For row `44`:

- `final_rw_none_f085_s100_long`
  - exact reopen of the cleanest documented legacy `WARN` corridor
- `final_rw_none_f085_s100_xlong`
  - same corridor, more budget
- `final_rw_none_f0825_s1025_long`
  - softer rw hedge against overshooting the corrected geometry
- `final_rw_none_f0845_s100_histshort`
  - lower-mid hedge suggested by the surviving historical crash-band evidence
- `final_rw_none_f0875_s105_xlong`
  - strongest higher-band rw hedge
- `final_rw_none_f085_s100_noadapt`
  - tests adaptation as the failure mechanism
- `final_slice_none_w16_s240`
  - first genuinely widened exact-kernel retry
- `final_slice_none_w18_s320`
  - deeper slice corridor
- `final_slice_none_w20_s360`
  - aggressive exact-kernel closure attempt

For row `68`:

- `final_rw_none_f0845_s100_histshort`
  - exact reopen of the only documented normal `WARN`-style anchor
- `final_rw_none_f0845_s100_histshort_xlong`
  - same anchor with more budget
- `final_rw_none_f0825_s105_none_xlong`
  - strongest none-init rw hedge from prior normal evidence
- `final_rw_none_f0835_s1025_xlong`
  - higher-band rw hedge
- `final_rw_none_f0845_s100_noadapt`
  - adaptation-off test on the best normal anchor
- `final_rw_none_f080_s105_long`
  - lower-band current-rhsns hedge
- `final_slice_none_w16_s240`
  - widened slice hedge
- `final_slice_none_w18_s320`
  - deeper slice hedge
- `final_slice_none_w20_s360`
  - aggressive exact-kernel closure attempt

## Validation State

Validated artifacts:

- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_helpers_20260410.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_prepare_20260410.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_run_row_20260410.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_evaluate_20260410.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_launch_20260410.sh`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_monitor_20260410.sh`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_supervisor_20260410.sh`

Validation summary:

- prepare: `18` rows
- missing inputs: `0`
- `bash -n`: passed
- launcher `--prepare-only=1`: passed
- launcher `--dry-run=1 --skip-prepare=1`: passed

Tracked artifacts:

- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_schedule_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_manifest_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_stage_counts_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_manifest_status_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_target_summary_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_compare_working_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_compare_accepted_20260410.csv`

## Decision

This lane is ready for overnight launch.

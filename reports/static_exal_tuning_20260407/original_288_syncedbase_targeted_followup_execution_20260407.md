# Original-288 Synced-Base Targeted Follow-Up Execution

Date: 2026-04-07

## Prelaunch Validation

Prepared follow-up queue:

- `tools/merge_reports/LOCAL_original288_syncedbase_followup_queue_20260407.csv`

Prepared deferred tail record:

- `tools/merge_reports/LOCAL_original288_syncedbase_followup_deferred_dynamic_tail_20260407.csv`

Prepared follow-up schedule:

- `tools/merge_reports/LOCAL_original288_syncedbase_followup_schedule_20260407.csv`

Prepared manifest:

- `tools/merge_reports/LOCAL_original288_syncedbase_followup_manifest_20260407.csv`

Prepared stage counts:

- `tools/merge_reports/LOCAL_original288_syncedbase_followup_stage_counts_20260407.csv`

Prelaunch evaluator outputs:

- `tools/merge_reports/LOCAL_original288_syncedbase_followup_manifest_status_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_followup_phase_summary_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_followup_block_summary_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_followup_accepted_compare_20260407.csv`

Validated prelaunch state:

- `29 / 29` rows prepared
- `0` missing inputs
- `0 / 29` complete before launch
- `29 / 29` pending before launch
- `bash -n` passed for launch / supervisor / monitor scripts
- launcher `--prepare-only=1` passed
- launcher `--dry-run=1 --skip-prepare=1` passed

Validated lane split:

- `16` static `exal :: mcmc` primary local-profile reruns
- `6` static `exal :: mcmc` row-local alternates
- `3` dynamic `exdqlm :: mcmc` exact-kernel longer-budget reruns
- `4` PASS-to-WARN stability-review reruns

## Launch Intent

This execution is intended to answer:

- how much of the remaining synced-base replay debt disappears once we stop
  repeating failed exact replays and instead use small, scenario-local
  follow-up profiles

It is not intended to reopen the accepted unresolved dynamic tail of `6` yet.

## Launch Sessions

- tmux supervisor:
  `original288-syncedbase-targeted-followup-20260407`
- tmux monitor:
  `original288-syncedbase-targeted-followup-monitor-20260407`

## Initial Expected State

- active phase:
  `phase1_static_exal_primary`
- initial done count:
  `0 / 29`

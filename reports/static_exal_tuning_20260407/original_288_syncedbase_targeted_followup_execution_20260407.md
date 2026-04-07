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

## Final Outcome

Completed state:

- `29 / 29` rows done
- `3 PASS`
- `10 WARN`
- `16 FAIL`
- `13 / 29` healthy

Accepted comparison:

- `3` better than accepted
- `6` matches accepted
- `20` worse than accepted

Phase outcomes:

| phase | total | PASS | WARN | FAIL | healthy |
|---|---:|---:|---:|---:|---:|
| `phase1_static_exal_primary` | `16` | `2` | `6` | `8` | `8` |
| `phase2_static_exal_rowlocal` | `6` | `1` | `0` | `5` | `1` |
| `phase3_dynamic_exdqlm_exactlong` | `3` | `0` | `0` | `3` | `0` |
| `phase4_stability_review` | `4` | `0` | `4` | `0` | `4` |

Strict improvements promoted into accepted `v7`:

- `static_paper::gausmix::0p25::1000::paper::exal::mcmc` — `WARN -> PASS`
- `static_shrink::laplace::0p05::100::ridge::exal::mcmc` — `WARN -> PASS`
- `static_shrink::laplace::0p95::1000::ridge::exal::mcmc` — `WARN -> PASS`

Accepted carry-forward after promotion:

- `282 / 288` healthy
- `230 PASS`
- `52 WARN`
- `6 FAIL`

## Interpretation

What improved:

- the follow-up produced `3` strict quality upgrades without increasing the
  fail count
- both promoted static-shrink improvements came from local ridge `exal :: mcmc`
  repairs
- the broad accepted baseline is now stronger at the same `282 / 288` healthy
  total

What still fails:

- the accepted publication-target unresolved queue remains the same `6`
  dynamic `exdqlm :: mcmc` rows
- the follow-up also left `3` synced-base dynamic replay rows as `FAIL`
- `13` static replay/stability rows remain deferred after the follow-up

What worked best:

- scenario-local static `exal :: mcmc` repairs on the laplace ridge rows
- keeping narrow follow-up lanes instead of reopening the full replay grid

What did not help:

- the `3` dynamic exact-long reruns all remained `FAIL`
- most row-local static `exal` alternates stayed negative
- PASS-to-WARN stability review rows did not recover to `PASS`

Highest-value next direction:

- move to a dynamic-only closure program focused on the `6` accepted tail
  failures plus the `3` synced-base replay failures
- defer the remaining static replay/stability debt until the publication-tail
  dynamic queue is smaller

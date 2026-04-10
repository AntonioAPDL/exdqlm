# Original-288 Static Shrink RHS_NS exAL MCMC Gausmix Last-Mile Execution

Date: `2026-04-10`

## Purpose

Execute the last remaining corrected static rhs_ns closure lane after the
working branch advanced to `71 / 72` healthy.

Prelaunch branch state:

- accepted `v8`: `282 / 288` healthy
- corrected `rhs_ns` working branch: `71 / 72` healthy
- remaining corrected unresolved row:
  - `static_shrink::gausmix::0p25::1000::rhs_ns::exal::mcmc`

## Validation Checklist

- corrected working promotion script: `passed`
- prepare row count: `28`
- missing inputs: `0`
- `bash -n`: `passed`
- `--prepare-only=1`: `passed`
- `--dry-run=1 --skip-prepare=1`: `passed`
- prelaunch evaluate:
  - `0 / 28` done
  - `28 / 28` pending

## Launch State

- branch: `validation/rerun-after-0.4.0-sync-0p4p0-integration`
- accepted baseline at launch: `v8`
- launch mode: full overnight run
- worker cap: `4` MCMC workers

Supervisor session:

- `original288-static-shrink-rhsns-exal-mcmc-gausmix-lastmile-20260410`

Monitor session:

- `original288-static-shrink-rhsns-exal-mcmc-gausmix-lastmile-monitor-20260410`

Tracked artifacts:

- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_working_baseline_v2_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_working_summary_v2_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_manifest_status_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_phase_summary_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_target_summary_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_compare_working_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_compare_accepted_20260410.csv`

## Outcome

This lane is now complete.

Final result:

- `28 / 28` candidates completed
- `0 PASS`
- `0 WARN`
- `28 FAIL`
- `0` better than the failed corrected rebuild baseline
- `0` better than the accepted baseline

Row-level read:

- target row:
  - `static_shrink::gausmix::0p25::1000::rhs_ns::exal::mcmc`
- outcome:
  - `0 / 28` healthy
  - still unresolved

## Main Technical Read

The lane was fully negative, but it still sharpened the diagnosis.

What improved:

- the old broad uncertainty on row `44` is gone; the search now identifies the
  remaining blocker much more clearly

What still fails:

- the row still fails entirely through `gamma = FAIL`

Which ideas worked best:

- among the failed candidates, the best signals remained on `laplace_rw`
- the most informative anchors were the long `F085 / s100`, `F0845 / s100`,
  and refresh-heavy `F085 / s100` corridors

Which ideas did not help:

- every plain last-mile `slice` hedge failed
- repeating the prior RW geometry with only more keep or only wider exact-kernel
  settings did not rescue the row

Highest-value new direction:

- move from a plain length/refresh map to a true stationarity bridge:
  - heavier burn with shorter retained windows
  - conservative VB warm-start bridges
  - a small number of untried kernels such as `slice_eta` and `laplace_local`

The clean conclusion is that the old last-mile tuning surface is now exhausted.
The next useful wave needs to attack the gap between the accepted legacy
`WARN` row and the corrected `rhs_ns` failures more directly, rather than
replaying more of the same RW/slice map.

# Original-288 Static Shrink RHS_NS exAL MCMC Final Closure Execution

Date: `2026-04-10`

## Purpose

Execute the final targeted closure wave for the last two unresolved corrected
`static_shrink / rhs_ns / exal / mcmc` rows after the `v8` promotion.

Prelaunch branch state:

- accepted `v8`: `282 / 288` healthy
- corrected `rhs_ns` working branch: `70 / 72` healthy
- remaining corrected unresolved rows: `2`

## Validation Checklist

- prepare row count: `18`
- missing inputs: `0`
- `bash -n`: `passed`
- `--prepare-only=1`: `passed`
- `--dry-run=1 --skip-prepare=1`: `passed`
- prelaunch evaluate:
  - `0 / 18` done
  - `18 / 18` pending

## Launch State

- branch: `validation/rerun-after-0.4.0-sync-0p4p0-integration`
- accepted baseline at launch: `v8`
- launch mode: full overnight run
- worker cap: `2` MCMC workers

Supervisor session:

- `original288-static-shrink-rhsns-exal-mcmc-final-closure-20260410`

Monitor session:

- `original288-static-shrink-rhsns-exal-mcmc-final-closure-monitor-20260410`

Tracked artifacts:

- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_manifest_status_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_phase_summary_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_target_summary_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_compare_working_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_compare_accepted_20260410.csv`

## Closeout

Completed result:

- total candidates: `18`
- healthy candidates: `3`
- `PASS`: `0`
- `WARN`: `3`
- `FAIL`: `15`

Accepted-branch effect:

- accepted baseline remains `v8`
- no new accepted promotion from this lane

Corrected-working-branch effect:

- `1` corrected working-baseline promotion was justified
- promoted row:
  - `static_shrink::normal::0p25::1000::rhs_ns::exal::mcmc`
- chosen candidate:
  - `row_0013`
  - profile `final_rw_none_f0835_s1025_xlong`
- corrected branch gate change:
  - `FAIL -> WARN`

Target-level read:

- `static_shrink::normal::0p25::1000::rhs_ns::exal::mcmc`
  - `3 / 9` healthy
  - rescue signal is real
- `static_shrink::gausmix::0p25::1000::rhs_ns::exal::mcmc`
  - `0 / 9` healthy
  - still unresolved

Main lesson:

- the last normal row was recoverable with a longer row-local rw band
- the hard gausmix row now looks like a gamma-ESS last-mile problem rather than
  a broad rhs_ns branch failure

# Family-QSpec Validation Status Tracker

Last updated: 2026-03-12 17:14 EDT

This file is the current authoritative human-readable tracker for the family-qspec
validation campaign on muscat. It supersedes the earlier mixed jerez-only and
pre-rehome notes.

## Scope

Current validation-run scope:

- families: `normal`, `laplace`, `gausmix`
- taus: `0.05`, `0.25`, `0.50`
- static fit sizes: `100`, `1000`
- dynamic fit sizes: `500`, `5000`
- static shrinkage priors: `ridge`, `rhs`
- `ISVB` excluded

Validation totals:

- static paper:
  - `18` roots
  - `72` fits
- static shrinkage:
  - `36` roots
  - `144` fits
- dynamic:
  - `18` roots
  - `72` fits
- total:
  - `72` roots
  - `288` fits

## References

Primary planning and launch references:

- full validation plan:
  - `tools/merge_reports/20260310_family_qspec_full_validation_plan.md`
- original exact muscat backlog manifest:
  - `tools/merge_reports/20260312_family_qspec_muscat_launch_manifest.tsv`
- current machine-readable unified status:
  - `tools/merge_reports/20260312_family_qspec_unified_root_status.tsv`
- original jerez exclusion snapshot:
  - `tools/merge_reports/20260312_family_qspec_jerez_excluded_roots.tsv`
- original muscat launch registries:
  - `tools/merge_reports/20260312_muscat_launch_registry_20260312_024859.tsv`
  - `tools/merge_reports/20260312_muscat_launch_registry_manual_20260312_025039.tsv`
- former jerez partial-root handoff manifest:
  - `tools/merge_reports/20260312_jerez_gausmix_partial_roots_to_muscat.tsv`
- later exact sync plan for jerez-complete roots:
  - `tools/merge_reports/20260312_jerez_to_muscat_exact_sync_plan.tsv`
  - `tools/merge_reports/20260312_jerez_to_muscat_exact_sync_plan.sh`

Important interpretation note:

- `tools/merge_reports/20260312_family_qspec_global_root_status.tsv` is still
  useful as the original pre-rehome reconciliation snapshot.
- it does not yet encode the later `16:50 EDT` muscat resume sessions for the
  former jerez partial roots.
- `tools/merge_reports/20260312_family_qspec_unified_root_status.tsv` is the
  current machine-readable unified status table.
- this markdown tracker is the readable narrative companion to that unified TSV.

## Current Unified Root Placement

| State | Roots | Notes |
| --- | ---: | --- |
| complete on jerez, pending exact sync to muscat | 9 | these are complete outputs, not active compute |
| complete on muscat from backlog wave | 13 | completed inside the original `mqsp_*` muscat batch lanes |
| active on muscat from backlog wave | 8 | current root in each batch lane listed below |
| active on muscat, rehomed from former jerez partial roots | 7 | standalone resume sessions started at `2026-03-12 16:50 EDT` |
| queued on muscat behind active backlog lanes | 35 | already assigned to muscat; waiting behind the current 8 batch roots |
| not launched anywhere | 0 | no campaign roots remain unassigned |

Sanity check:

- `9 + 13 + 8 + 7 + 35 = 72` total campaign roots
- these counts match `tools/merge_reports/20260312_family_qspec_unified_root_status.tsv`

## Current Muscat Live Execution

Interpretation caveat:

- the batch logs are sparse inside long MCMC phases
- log timestamps mostly move at root boundaries, not continuously during sampling
- live process checks therefore matter more than log recency for current-health interpretation

### Active Backlog-Wave Batch Roots

These 8 sessions belong to the original exact muscat backlog launch.

| Session | Root type | Current root | Current models/stage | Batch progress | Remaining queued after current |
| --- | --- | --- | --- | --- | --- |
| `mqsp_dynamic_tt5000_20260312_025039` | dynamic | `gausmix tau=0.25 lastTT=5000` | `DQLM + exDQLM` in `VB -> MCMC` pipeline | `0 / 8` done | `gausmix tau=0.50`, `laplace tau=0.05/0.25/0.50`, `normal tau=0.05/0.25/0.50` |
| `mqsp_dynamic_tt500_20260312_025039` | dynamic | `laplace tau=0.25 lastTT=500` | `DQLM + exDQLM` in `VB -> MCMC` pipeline | `1 / 6` done | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `mqsp_static_paper_tt1000_20260312_024859` | static paper | `laplace tau=0.25 TT=1000` | `AL + exAL` in `VB -> MCMC` pipeline | `2 / 7` done | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `mqsp_static_paper_tt100_20260312_024859` | static paper | `laplace tau=0.25 TT=100` | `AL + exAL` in `VB -> MCMC` pipeline | `2 / 7` done | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `mqsp_static_shrink_rhs_tt1000_20260312_025039` | static shrink `rhs` | `laplace tau=0.25 TT=1000` | `AL + exAL` in `VB -> MCMC` pipeline | `2 / 7` done | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `mqsp_static_shrink_rhs_tt100_20260312_024859` | static shrink `rhs` | `laplace tau=0.25 TT=100` | `AL + exAL` in `VB -> MCMC` pipeline | `2 / 7` done | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `mqsp_static_shrink_ridge_tt1000_20260312_025039` | static shrink `ridge` | `laplace tau=0.25 TT=1000` | `AL + exAL` in `VB -> MCMC` pipeline | `2 / 7` done | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `mqsp_static_shrink_ridge_tt100_20260312_024859` | static shrink `ridge` | `laplace tau=0.25 TT=100` | `AL + exAL` in `VB -> MCMC` pipeline | `2 / 7` done | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |

### Active Rehomed Former-Jerez Roots

These 7 sessions were relaunched on muscat at `2026-03-12 16:50 EDT` after the
former jerez partial roots were preserved and handed off.

| Session | Former jerez session | Root | Current muscat stage | Resume goal |
| --- | --- | --- | --- | --- |
| `mqsp_jr_rsp100_20260312_135054` | `qsp_rsp100_20260310_204439` | static paper `gausmix tau=0.25 TT=100` | `resume_static_mcmc_from_vb.R` active | finish `exAL` MCMC, then postprocess/report |
| `mqsp_jr_rsp1k_20260312_135054` | `qsp_rsp1k_20260310_204439` | static paper `gausmix tau=0.25 TT=1000` | `resume_static_mcmc_from_vb.R` active | finish `exAL` MCMC, then postprocess/report |
| `mqsp_jr_rss100r_20260312_135054` | `qsp_rss100r_20260310_204439` | static shrink `ridge`, `gausmix tau=0.25 TT=100` | `resume_static_mcmc_from_vb.R` active | finish `exAL` MCMC, then postprocess/report |
| `mqsp_jr_rss1kr_20260312_135054` | `qsp_rss1kr_20260310_204439` | static shrink `ridge`, `gausmix tau=0.25 TT=1000` | `resume_static_mcmc_from_vb.R` active | finish `exAL` MCMC, then postprocess/report |
| `mqsp_jr_rss100h_20260312_135054` | `qsp_rss100h_20260310_204439` | static shrink `rhs`, `gausmix tau=0.25 TT=100` | `resume_static_mcmc_from_vb.R` active | finish `exAL` MCMC, then postprocess/report |
| `mqsp_jr_rss1kh_20260312_135054` | `qsp_rss1kh_20260310_204439` | static shrink `rhs`, `gausmix tau=0.25 TT=1000` | `resume_static_mcmc_from_vb.R` active | finish `exAL` MCMC, then postprocess/report |
| `mqsp_jr_rdy5k_20260312_135054` | `qsp_rdy5k_fix_20260311_173314` | dynamic `gausmix tau=0.05 lastTT=5000` | `resume_dynamic_mcmc_from_vb.R` active | finish `DQLM` and `exDQLM` MCMC, then postprocess |

## Completed On Muscat So Far

These roots are already complete inside the original muscat backlog wave.

### Static Paper

| Family | Tau | TT | State |
| --- | --- | ---: | --- |
| `gausmix` | `0.50` | 100 | complete on muscat |
| `gausmix` | `0.50` | 1000 | complete on muscat |
| `laplace` | `0.05` | 100 | complete on muscat |
| `laplace` | `0.05` | 1000 | complete on muscat |

### Static Shrink Ridge

| Family | Tau | TT | State |
| --- | --- | ---: | --- |
| `gausmix` | `0.50` | 100 | complete on muscat |
| `gausmix` | `0.50` | 1000 | complete on muscat |
| `laplace` | `0.05` | 100 | complete on muscat |
| `laplace` | `0.05` | 1000 | complete on muscat |

### Static Shrink RHS

| Family | Tau | TT | State |
| --- | --- | ---: | --- |
| `gausmix` | `0.50` | 100 | complete on muscat |
| `gausmix` | `0.50` | 1000 | complete on muscat |
| `laplace` | `0.05` | 100 | complete on muscat |
| `laplace` | `0.05` | 1000 | complete on muscat |

### Dynamic

| Family | Tau | lastTT | State |
| --- | --- | ---: | --- |
| `laplace` | `0.05` | 500 | complete on muscat |

## Queued Muscat Backlog After The Current Active Batch Roots

These `35` roots are already assigned to muscat and are waiting in the queue
behind the current 8 batch-current roots.

| Lane | Exact queued roots |
| --- | --- |
| `dynamic_tt5000` | `gausmix tau=0.50`, `laplace tau=0.05/0.25/0.50`, `normal tau=0.05/0.25/0.50` |
| `dynamic_tt500` | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `static_paper_tt1000` | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `static_paper_tt100` | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `static_shrink_rhs_tt1000` | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `static_shrink_rhs_tt100` | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `static_shrink_ridge_tt1000` | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `static_shrink_ridge_tt100` | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |

## Jerez-Complete Roots Still Pending Exact Sync

These 9 roots are complete but their results still need to be copied into the
muscat workspace using the exact sync plan.

| Type | Family | Tau | Size | Prior |
| --- | --- | --- | --- | --- |
| static paper | `gausmix` | `0.05` | `TT=100` | `paper` |
| static paper | `gausmix` | `0.05` | `TT=1000` | `paper` |
| static shrink | `gausmix` | `0.05` | `TT=100` | `ridge` |
| static shrink | `gausmix` | `0.05` | `TT=1000` | `ridge` |
| static shrink | `gausmix` | `0.05` | `TT=100` | `rhs` |
| static shrink | `gausmix` | `0.05` | `TT=1000` | `rhs` |
| dynamic | `gausmix` | `0.05` | `lastTT=500` | `-` |
| dynamic | `gausmix` | `0.25` | `lastTT=500` | `-` |
| dynamic | `gausmix` | `0.50` | `lastTT=500` | `-` |

## Operational Notes

- no campaign roots remain unassigned
- do not relaunch the 7 rehomed former jerez partial roots again elsewhere
- the exact handoff for those 7 roots is documented in:
  - `tools/merge_reports/20260312_jerez_gausmix_partial_roots_to_muscat.tsv`
- the exact later sync for the 9 jerez-complete roots is documented in:
  - `tools/merge_reports/20260312_jerez_to_muscat_exact_sync_plan.tsv`
- `tools/merge_reports/20260312_family_qspec_unified_root_status.tsv` is the
  machine-readable current-state table for this tracker

# Family-QSpec Validation Status Tracker

Last updated: 2026-03-12 13:51 PDT

## Source docs

- Broad corrected-simulation tracker:
  - `tools/merge_reports/20260308_quantile_specific_sim_validation_reset_tracker.md`
- Current full validation grid:
  - `tools/merge_reports/20260310_family_qspec_full_validation_plan.md`
- Current launch manifest:
  - `tools/merge_reports/20260310_family_qspec_batch_launch_20260310_004857.tsv`

This note is the compact current-status tracker for the family-qspec validation campaign.

## Scope clarification

There are two layers that should not be conflated:

1. Dataset-generation scope
   - documented in `20260309_paper_family_qspec_study_plan.md`
   - includes extra prepared subsets such as static `tt5000` and dynamic `lastTT1000/2000/5000`
   - mentions `loggpd` at the study-plan stage

2. Current validation-run scope
   - documented in `20260310_family_qspec_full_validation_plan.md`
   - families: `normal`, `laplace`, `gausmix`
   - taus: `0.05`, `0.25`, `0.50`
   - static fit sizes: `100`, `1000`
   - dynamic fit sizes: `500`, `5000`
   - static shrinkage priors: `ridge`, `rhs`
   - `ISVB` excluded

Current validation-run totals:

- static paper:
  - `3 families x 3 taus x 2 sizes = 18` run roots
  - `18 x 4 = 72` fits
- static shrinkage:
  - `3 families x 3 taus x 2 sizes x 2 priors = 36` run roots
  - `36 x 4 = 144` fits
- dynamic:
  - `3 families x 3 taus x 2 sizes = 18` run roots
  - `18 x 4 = 72` fits
- total:
  - `72` run roots
  - `288` fits

## Current campaign summary
X
Run-root status:

| Group | Complete roots | Running roots | Not launched roots | Total roots |
| --- | ---: | ---: | ---: | ---: |
| static paper | 2 | 2 | 14 | 18 |
| static shrinkage | 4 | 4 | 28 | 36 |
| dynamic | 3 | 1 | 14 | 18 |
| total | 9 | 7 | 56 | 72 |

Fit-level status:

| Group | Complete fits | Running fits | Not launched fits | Total fits |
| --- | ---: | ---: | ---: | ---: |
| static paper | 14 | 2 | 56 | 72 |
| static shrinkage | 28 | 4 | 112 | 144 |
| dynamic | 14 | 2 | 56 | 72 |
| total | 56 | 8 | 224 | 288 |

## Unified coordination status after muscat launch

At `2026-03-12 00:51 PDT`, the previously unlaunched backlog had been
assigned to muscat using the exact exclusion manifest produced from the
jerez audit. This supersedes the older jerez-only "not launched anywhere"
view below.

Current unified root placement:

| State | Roots |
| --- | ---: |
| complete on jerez | 9 |
| running on jerez | 7 |
| launched on muscat | 56 |
| not launched anywhere | 0 |

Muscat coordination references:

- global reconciliation:
  - `tools/merge_reports/20260312_family_qspec_global_root_status.tsv`
- exact muscat launch set:
  - `tools/merge_reports/20260312_family_qspec_muscat_launch_manifest.tsv`
- exact jerez exclusions:
  - `tools/merge_reports/20260312_family_qspec_jerez_excluded_roots.tsv`
- exact later sync plan:
  - `tools/merge_reports/20260312_jerez_to_muscat_exact_sync_plan.tsv`
  - `tools/merge_reports/20260312_jerez_to_muscat_exact_sync_plan.sh`

Muscat active batch sessions:

| Session | Batch class | Current evidence-backed stage |
| --- | --- | --- |
| `mqsp_static_paper_tt100_20260312_024859` | static paper `TT=100` | `gausmix tau=0.50` done, `laplace tau=0.05` done, now in `laplace tau=0.25 exAL` MCMC |
| `mqsp_static_paper_tt1000_20260312_024859` | static paper `TT=1000` | `gausmix tau=0.50` done, `laplace tau=0.05` done, now in `laplace tau=0.25 exAL` MCMC |
| `mqsp_static_shrink_ridge_tt100_20260312_024859` | static shrink ridge `TT=100` | `laplace tau=0.05` done, now in `laplace tau=0.25 exAL` MCMC |
| `mqsp_static_shrink_rhs_tt100_20260312_024859` | static shrink rhs `TT=100` | `laplace tau=0.05` done, now in `laplace tau=0.25 exAL` MCMC |
| `mqsp_static_shrink_ridge_tt1000_20260312_025039` | static shrink ridge `TT=1000` | `laplace tau=0.05` done, now in `laplace tau=0.25 exAL` MCMC |
| `mqsp_static_shrink_rhs_tt1000_20260312_025039` | static shrink rhs `TT=1000` | `laplace tau=0.05` done, now in `laplace tau=0.25 exAL` MCMC |
| `mqsp_dynamic_tt500_20260312_025039` | dynamic `TT=500` | `laplace tau=0.05` done, now in `laplace tau=0.25` with `exDQLM` already `MCMC_DONE` and `DQLM` still in MCMC |
| `mqsp_dynamic_tt5000_20260312_025039` | dynamic `TT=5000` | resumed `gausmix tau=0.25`; both `DQLM` and `exDQLM` reached `MCMC_START` |

## Jerez shutdown and muscat relocation

At `2026-03-12 13:34 PDT`, the remaining `7` live jerez `gausmix` roots were
classified as safe to stop at the pipeline level but not checkpointable at the
in-flight MCMC level. The shutdown and migration were then executed at
`2026-03-12 13:51 PDT`.

- all `7` roots are past VB
- the `6` static roots also already have completed base-model `AL` MCMC fits
- none of the active resume scripts writes mid-chain MCMC checkpoints
- stopping the jobs frees jerez immediately but discards the current in-flight
  MCMC work since the last `RESUME_MCMC_START`

Operational decision:

- stop the `7` jerez validation sessions to free jerez for other work
- preserve their partial validation roots
- sync those exact partial roots to muscat
- resume the missing MCMC work on muscat from the saved VB artifacts and, for
  static roots, the already completed `mcmc_al_*` base fits

Exact partial-root handoff manifest:

- `tools/merge_reports/20260312_jerez_gausmix_partial_roots_to_muscat.tsv`

Executed result:

| State | Roots |
| --- | ---: |
| complete on jerez, pending exact sync | 9 |
| former jerez partial roots synced and relaunched on muscat | 7 |
| already launched on muscat backlog | 56 |
| not launched anywhere | 0 |

Current jerez state after shutdown:

- no remaining live `qsp_*` validation sessions
- no remaining `20260305_resume_static_mcmc_from_vb.R` workers
- no remaining `20260305_resume_dynamic_mcmc_from_vb.R` workers

Current muscat resume sessions for the former jerez roots:

- `mqsp_jr_rsp100_20260312_135054`
- `mqsp_jr_rsp1k_20260312_135054`
- `mqsp_jr_rss100r_20260312_135054`
- `mqsp_jr_rss1kr_20260312_135054`
- `mqsp_jr_rss100h_20260312_135054`
- `mqsp_jr_rss1kh_20260312_135054`
- `mqsp_jr_rdy5k_20260312_135054`

Those `7` roots should not be restarted on jerez again. They have been
re-homed to muscat with the existing resume scripts:

- static:
  - `tools/merge_reports/20260305_resume_static_mcmc_from_vb.R`
  - followed by `tools/merge_reports/20260305_static_postprocess_from_existing_fits.R`
  - followed by `tools/merge_reports/20260305_static_vb_mcmc_report.R`
- dynamic:
  - `tools/merge_reports/20260305_resume_dynamic_mcmc_from_vb.R`
  - followed by `tools/merge_reports/20260305_postprocess_from_existing_fits.R`

## What had been launched on jerez before muscat cutover

Only the `gausmix` family has been launched so far.

Launched static subset:

- static paper:
  - `TT=100`, `1000`
  - `tau=0.05`, `0.25`
- static shrinkage:
  - `TT=100`, `1000`
  - `tau=0.05`, `0.25`
  - both `ridge` and `rhs`

Launched dynamic subset:

- `TT=500`:
  - `tau=0.05`, `0.25`, `0.50`
- `TT=5000`:
  - `tau=0.05` only

Not yet launched on jerez before muscat cutover:

- all `normal` roots
- all `laplace` roots
- all static `gausmix tau=0.50` roots
- dynamic `gausmix tau=0.25, TT=5000`
- dynamic `gausmix tau=0.50, TT=5000`

Those roots are now covered by the muscat launch manifest above.

## Jerez live runs before shutdown

Static live sessions:

| Session | Root class | Current stage |
| --- | --- | --- |
| `qsp_rsp100_20260310_204439` | static paper `gausmix tau=0.25 TT=100` | `exAL` resumed MCMC |
| `qsp_rsp1k_20260310_204439` | static paper `gausmix tau=0.25 TT=1000` | `exAL` resumed MCMC |
| `qsp_rss100r_20260310_204439` | static shrink ridge `gausmix tau=0.25 TT=100` | `exAL` resumed MCMC |
| `qsp_rss1kr_20260310_204439` | static shrink ridge `gausmix tau=0.25 TT=1000` | `exAL` resumed MCMC |
| `qsp_rss100h_20260310_204439` | static shrink rhs `gausmix tau=0.25 TT=100` | `exAL` resumed MCMC |
| `qsp_rss1kh_20260310_204439` | static shrink rhs `gausmix tau=0.25 TT=1000` | `exAL` resumed MCMC |

Dynamic live sessions:

| Session | Root class | Current stage |
| --- | --- | --- |
| `qsp_rdy5k_fix_20260311_173314` | dynamic `gausmix tau=0.05 TT=5000` | `DQLM` and `exDQLM` resumed MCMC |

Recently completed since the previous check:

| Session | Root class | Completion evidence |
| --- | --- | --- |
| `qsp_rdy500_fix_20260311_173314` | dynamic `gausmix tau=0.50 TT=500` | outer log reached `Post-processing from existing fits completed` at `2026-03-11 20:44:17 PDT`; tmux session exited; summary tables now present under `tables/` |

### Live audit snapshot

This snapshot reflects the current tmux/process state on `jerez` at
`2026-03-12 00:51 PDT`.

| Session | Case | Status | Evidence |
| --- | --- | --- | --- |
| `qsp_rsp100_20260310_204439` | static paper `TT=100 tau=0.25` | running `exAL` MCMC | worker `1197252` at `1032%` CPU; `mcmc_al_tau_0p25_fit.rds` present; `mcmc_exal_tau_0p25_fit.rds` absent; `exal_tau_0p25.status.tsv` last line `RESUME_MCMC_START` |
| `qsp_rsp1k_20260310_204439` | static paper `TT=1000 tau=0.25` | running `exAL` MCMC | worker `1206708` at `1061%` CPU; `mcmc_al_tau_0p25_fit.rds` present; `mcmc_exal_tau_0p25_fit.rds` absent; `exal_tau_0p25.status.tsv` last line `RESUME_MCMC_START` |
| `qsp_rss100r_20260310_204439` | static shrink-ridge `TT=100 tau=0.25` | running `exAL` MCMC | worker `1197486` at `1038%` CPU; base `AL` MCMC fit present; extended `exAL` MCMC fit absent |
| `qsp_rss1kr_20260310_204439` | static shrink-ridge `TT=1000 tau=0.25` | running `exAL` MCMC | worker `1208408` at `1028%` CPU; base `AL` MCMC fit present; extended `exAL` MCMC fit absent |
| `qsp_rss100h_20260310_204439` | static shrink-rhs `TT=100 tau=0.25` | running `exAL` MCMC | worker `1199335` at `1023%` CPU; base `AL` MCMC fit present; extended `exAL` MCMC fit absent |
| `qsp_rss1kh_20260310_204439` | static shrink-rhs `TT=1000 tau=0.25` | running `exAL` MCMC | worker `1208948` at `1030%` CPU; base `AL` MCMC fit present; extended `exAL` MCMC fit absent |
| `qsp_rdy5k_fix_20260311_173314` | dynamic `TT=5000 tau=0.05` | running `DQLM` + `exDQLM` resumed MCMC | workers `3792556` and `3792558` at `16.2%` CPU each; both status TSVs still at `RESUME_MCMC_START`; no MCMC fit files yet |

Status-file caveat:

- static resume logs are sparse after `RESUME_MCMC_START`; health for those six
  roots is being inferred from live high-CPU workers plus the continued absence
  of the final `mcmc_exal_*` fit files.

## Current launched-subset status table

### Static paper, gausmix

| Tau | TT | Status | Remaining work |
| --- | ---: | --- | --- |
| `0.05` | 100 | complete | none |
| `0.05` | 1000 | complete | none |
| `0.25` | 100 | running | `exAL` MCMC, then postprocess/report |
| `0.25` | 1000 | running | `exAL` MCMC, then postprocess/report |
| `0.50` | 100 | not launched | full root |
| `0.50` | 1000 | not launched | full root |

### Static shrinkage, gausmix, ridge

| Tau | TT | Status | Remaining work |
| --- | ---: | --- | --- |
| `0.05` | 100 | complete | none |
| `0.05` | 1000 | complete | none |
| `0.25` | 100 | running | `exAL` MCMC, then postprocess/report |
| `0.25` | 1000 | running | `exAL` MCMC, then postprocess/report |
| `0.50` | 100 | not launched | full root |
| `0.50` | 1000 | not launched | full root |

### Static shrinkage, gausmix, rhs

| Tau | TT | Status | Remaining work |
| --- | ---: | --- | --- |
| `0.05` | 100 | complete | none |
| `0.05` | 1000 | complete | none |
| `0.25` | 100 | running | `exAL` MCMC, then postprocess/report |
| `0.25` | 1000 | running | `exAL` MCMC, then postprocess/report |
| `0.50` | 100 | not launched | full root |
| `0.50` | 1000 | not launched | full root |

### Dynamic, gausmix

| Tau | TT | Status | Remaining work |
| --- | ---: | --- | --- |
| `0.05` | 500 | complete | none |
| `0.25` | 500 | complete | none |
| `0.50` | 500 | complete | none |
| `0.05` | 5000 | running | `DQLM` and `exDQLM` MCMC, then postprocess |
| `0.25` | 5000 | not launched | full root |
| `0.50` | 5000 | not launched | full root |

## Important caveat

Prepared directories exist outside the current validation-run scope:

- static `fit_input_subsample_tt5000_x01_sorted`
- dynamic `fit_input_lastTT1000`
- dynamic `fit_input_lastTT2000`

These should not be counted as launched validation roots unless corresponding
`validation_*` run roots exist.

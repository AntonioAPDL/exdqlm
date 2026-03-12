# Family-QSpec Validation Status Tracker

Last updated: 2026-03-11

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

Run-root status:

| Group | Complete roots | Running roots | Not launched roots | Total roots |
| --- | ---: | ---: | ---: | ---: |
| static paper | 2 | 2 | 14 | 18 |
| static shrinkage | 4 | 4 | 28 | 36 |
| dynamic | 2 | 2 | 14 | 18 |
| total | 8 | 8 | 56 | 72 |

Fit-level status:

| Group | Complete fits | Running fits | Not launched fits | Total fits |
| --- | ---: | ---: | ---: | ---: |
| static paper | 14 | 2 | 56 | 72 |
| static shrinkage | 28 | 4 | 112 | 144 |
| dynamic | 13 | 3 | 56 | 72 |
| total | 55 | 9 | 224 | 288 |

## What has actually been launched

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

Not yet launched anywhere in the current validation campaign:

- all `normal` roots
- all `laplace` roots
- all static `gausmix tau=0.50` roots
- dynamic `gausmix tau=0.25, TT=5000`
- dynamic `gausmix tau=0.50, TT=5000`

## Current live runs

Static live sessions:

| Session | Root class | Remaining fit |
| --- | --- | --- |
| `qsp_rsp100_20260310_204439` | static paper `gausmix tau=0.25 TT=100` | `exAL` MCMC |
| `qsp_rsp1k_20260310_204439` | static paper `gausmix tau=0.25 TT=1000` | `exAL` MCMC |
| `qsp_rss100r_20260310_204439` | static shrink ridge `gausmix tau=0.25 TT=100` | `exAL` MCMC |
| `qsp_rss1kr_20260310_204439` | static shrink ridge `gausmix tau=0.25 TT=1000` | `exAL` MCMC |
| `qsp_rss100h_20260310_204439` | static shrink rhs `gausmix tau=0.25 TT=100` | `exAL` MCMC |
| `qsp_rss1kh_20260310_204439` | static shrink rhs `gausmix tau=0.25 TT=1000` | `exAL` MCMC |

Dynamic live sessions:

| Session | Root class | Remaining fit |
| --- | --- | --- |
| `qsp_rdy500_fix_20260311_173314` | dynamic `gausmix tau=0.50 TT=500` | `DQLM` MCMC |
| `qsp_rdy5k_fix_20260311_173314` | dynamic `gausmix tau=0.05 TT=5000` | `DQLM` MCMC and `exDQLM` MCMC |

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
| `0.50` | 500 | running | `DQLM` MCMC, then postprocess |
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

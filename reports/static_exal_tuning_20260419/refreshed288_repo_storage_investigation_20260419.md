# Refreshed288 Repo Storage Investigation

Date: 2026-04-19
Repo: `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration`

## Question

After the recent emergency cleanup, where is the remaining storage footprint in this specific worktree/repo, and which artifact classes still dominate disk usage?

## High-Level Result

This repo is still large because almost all of its remaining footprint lives under `results/`, and almost all of that is binary `.rds` output from older simulation/validation artifacts.

The main sink is:

- `results/function_testing_20260309_dynamic_dlm_family_qspec`

This is not primarily a code, docs, or git-metadata problem.

## Top-Level Repo Breakdown

Measured with `du -xh --max-depth=1 . | sort -h`.

| Path | Size | Interpretation |
|---|---:|---|
| `results/` | `91G` | dominant storage sink |
| `tools/` | `135M` | small after cleanup |
| `src/` | `85M` | package source / compiled artifacts, not the problem |
| `reports/` | `1.4M` | negligible |
| `R/` | `684K` | negligible |
| everything else | small | negligible |

Repo total at measurement time: `91G`

## Filesystem Context

Measured with `df -h .`.

| Mount | Size | Used | Avail | Use% |
|---|---:|---:|---:|---:|
| `/dev/md0` mounted at `/home` | `916G` | `781G` | `89G` | `90%` |

The repo is no longer causing an immediate disk-write outage, but it remains one of the large consumers on `/home`.

## Git Metadata Check

Measured with:

- `git rev-parse --git-dir`
- `git rev-parse --git-common-dir`
- `du -sh $(git rev-parse --git-common-dir)`

| Item | Size | Interpretation |
|---|---:|---|
| shared git dir `/home/jaguir26/local/src/exdqlm/.git` | `295M` | not the main problem |

This worktree is not large because of git object storage.

## Results Tree Breakdown

Measured with:

- `du -sh results/function_testing_20260309_dynamic_dlm_family_qspec ...`
- `du -xh --max-depth=2 results | sort -h | tail`

| Results subtree | Size | Share of repo |
|---|---:|---:|
| `results/function_testing_20260309_dynamic_dlm_family_qspec` | `89G` | about `97.8%` |
| `results/function_testing_20260309_static_shrinkage_family_qspec` | `1.4G` | about `1.5%` |
| `results/function_testing_20260309_static_paper_family_qspec` | `242M` | about `0.3%` |
| `results/static_bqrgal_aligned_20260408` | `180K` | negligible |

## File-Type Breakdown

Measured with a `python3` walk over `results/`.

| Extension | Count | Total size |
|---|---:|---:|
| `.rds` | `1247` | `90.18 GiB` |

Interpretation:

- the remaining repo size is overwhelmingly binary R artifacts
- the storage issue is not driven by CSVs, reports, or code

## Dynamic Study Breakdown

Measured with a `python3` aggregation over:

- `results/function_testing_20260309_dynamic_dlm_family_qspec/dlm_constV_smallW`

Grouped by fit-size, validation pocket, and method.

| Bucket | Size | Share of repo | Share of dynamic tree |
|---|---:|---:|---:|
| `fit_input_lastTT500 / validation_dynamic_tt500 / fits / mcmc` | `72.62 GiB` | about `79.8%` | about `81.6%` |
| `fit_input_lastTT5000 / validation_dynamic_tt5000 / fits / vb` | `12.39 GiB` | about `13.6%` | about `13.9%` |
| `fit_input_lastTT500 / validation_dynamic_tt500 / fits / vb` | `3.58 GiB` | about `3.9%` | about `4.0%` |

This means the remaining repo footprint is mostly:

1. old dynamic `TT500` MCMC fits
2. old dynamic `TT5000` VB fits
3. old dynamic `TT500` VB fits

## Largest Dynamic Subdirectories

These were the biggest method-level subtrees still present at measurement time.

| Path | Size | File count |
|---|---:|---:|
| `gausmix/tau_0p25/fit_input_lastTT500/validation_dynamic_tt500/fits/mcmc` | `8.52 GiB` | `9` |
| `normal/tau_0p05/fit_input_lastTT500/validation_dynamic_tt500/fits/mcmc` | `8.44 GiB` | `9` |
| `laplace/tau_0p05/fit_input_lastTT500/validation_dynamic_tt500/fits/mcmc` | `8.38 GiB` | `9` |
| `gausmix/tau_0p95/fit_input_lastTT500/validation_dynamic_tt500/fits/mcmc` | `7.89 GiB` | `8` |
| `laplace/tau_0p95/fit_input_lastTT500/validation_dynamic_tt500/fits/mcmc` | `7.89 GiB` | `8` |
| `normal/tau_0p95/fit_input_lastTT500/validation_dynamic_tt500/fits/mcmc` | `7.88 GiB` | `8` |
| `laplace/tau_0p25/fit_input_lastTT500/validation_dynamic_tt500/fits/mcmc` | `7.88 GiB` | `8` |
| `normal/tau_0p25/fit_input_lastTT500/validation_dynamic_tt500/fits/mcmc` | `7.87 GiB` | `8` |
| `gausmix/tau_0p05/fit_input_lastTT500/validation_dynamic_tt500/fits/mcmc` | `7.87 GiB` | `8` |

These old dynamic `TT500` MCMC trees dominate the entire repo.

## Largest Single Files

Measured with `find . -xdev -type f -size +100M`.

The largest files are old dynamic MCMC `.rds` fits, many around `0.99G` to `1.12G` each, for example:

- `results/function_testing_20260309_dynamic_dlm_family_qspec/dlm_constV_smallW/gausmix/tau_0p95/fit_input_lastTT500/validation_dynamic_tt500/fits/mcmc/mcmc_exdqlm_tau_0p95_fit_orig288_exactspec_multiseed_20260412_seed04.rds`
- `results/function_testing_20260309_dynamic_dlm_family_qspec/dlm_constV_smallW/laplace/tau_0p25/fit_input_lastTT500/validation_dynamic_tt500/fits/mcmc/mcmc_exdqlm_tau_0p25_fit_orig288_exactspec_multiseed_20260412_seed01.rds`
- `results/function_testing_20260309_dynamic_dlm_family_qspec/dlm_constV_smallW/normal/tau_0p05/fit_input_lastTT500/validation_dynamic_tt500/fits/mcmc/mcmc_dqlm_tau_0p05_fit_orig288_exactspec_multiseed_20260412_seed04.rds`

So the space is not spread evenly across many medium files. It is heavily concentrated in very large legacy fit binaries.

## Interpretation

### What is driving space right now

- legacy dynamic-study fit artifacts
- especially old `TT500` MCMC `.rds` files
- secondarily old `TT5000` VB `.rds` files

### What is not driving space

- current refreshed288 run roots after cleanup
- reports
- manifests / configs / health / metrics / logs
- git metadata
- code and tests

## Safe Cleanup Direction

If we need further space before the next relaunch, the most impactful and coherent next targets are:

1. legacy dynamic `TT500` MCMC fit trees under `results/function_testing_20260309_dynamic_dlm_family_qspec/.../validation_dynamic_tt500/fits/mcmc`
2. legacy dynamic `TT5000` VB fit trees under `.../validation_dynamic_tt5000/fits/vb`
3. legacy dynamic `TT500` VB fit trees under `.../validation_dynamic_tt500/fits/vb`

The current refreshed288 reproducibility surfaces should continue to preserve:

- configs
- row status
- health summaries
- metrics
- logs
- compact reports

and not the heavy fit/draw binaries unless they are explicitly needed for a follow-up debugging lane.

## Bottom Line

For this repo/worktree on this server, the remaining storage burden is overwhelmingly:

- inside `results/`
- specifically inside `function_testing_20260309_dynamic_dlm_family_qspec`
- specifically old `.rds` fit outputs
- and most of all the old dynamic `TT500` MCMC fit trees

That is the clearest place to focus the next cleanup pass before any fresh relaunch.

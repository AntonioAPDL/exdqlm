# QDESN Tau050 Dataset Audit Plots Outputs

## Outcome

The tau050 dataset audit pack was generated successfully from the canonical source
run into a single flat temp folder for one-by-one review.

The output root is:

- `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_dataset_audit_local/qdesn-dynamic-exdqlm-crossstudy-tau050-datasetaudit-20260421-180700__git-d77edc7`

Rendered counts:

- `36` datasets selected
- `36` PNGs rendered
- `0` render errors
- `42` flat files total in the folder

## What Is In The Folder

- `000__run_metadata.json`
- `000__preflight.md`
- `000__dataset_index.csv`
- `000__dataset_audit_manifest.json`
- `000__dataset_audit_summary.md`
- `000__completion_metadata.json`
- `001__...png` through `036__...png`

All dataset figures are flat in the top-level folder so they can be browsed in lexical
order without drilling into subfolders.

The folder lives under the repo-local validation-report tree, which is already
gitignored, so the full visual audit pack stays untracked while remaining easy to
inspect from the current workspace.

## Review Guidance

The recommended review order is simply the lexical file order of the PNGs.

Each figure shows:

- the full series
- the last 100 observations
- dataset metadata in the title/subtitle
- recovered readiness context where available

## Intended Use

This pack should be treated as the raw-data audit surface for tau050:

- confirm the synthetic datasets themselves look sensible
- spot any obvious generation pathologies
- use the dataset visuals to contextualize the later fit-quality comparisons

## Next Step

Use the audit pack together with the study-facing comparison outputs to separate:

- poor fits caused by bad models or diagnostics
- versus poor fits that are partly explained by difficult or pathological source series

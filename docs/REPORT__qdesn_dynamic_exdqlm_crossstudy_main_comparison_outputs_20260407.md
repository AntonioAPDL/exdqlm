# REPORT: QDESN Dynamic exdqlm Cross-Study Main Comparison Outputs

Date: 2026-04-07  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Executive Read

The authoritative main comparison-analysis pack is now generated from the reconciled branch-local
baseline:

- stage-level promoted local winners:
  - `R1 -> L640_gmix_long_split_diag`
  - `R2 -> L670_gmix_short_diag_mix`
  - `R3 -> L720_ridge_long_softgamma_plus`
  - `R4 -> L760_rhs_long_vbguard_deep`
  - `R5 -> L770_short_mixed_local_mcmc`
- exact-root final-wave promotions:
  - `normal tau=0.05 lastTT5000 rhs_ns -> M850_rhs_long_burnheavy1300`
  - `normal tau=0.95 lastTT500 rhs_ns -> M940_short_rhs_narrow1200_diag5`

This is now the authoritative comparison source because it closes the residual fail band while
staying faithful to the late-stage decision rule:

- keep the stable baseline as default
- promote only clear local improvements
- allow scenario-specific overrides where they are genuinely better

Authoritative analysis run:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-172014__git-3a56f9e`
- report root:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-172014__git-3a56f9e`

Current authoritative state:

| Metric | Value |
|---|---:|
| Fit rows | `144` |
| `PASS` | `76` |
| `WARN` | `68` |
| `FAIL` | `0` |
| Root-status `FAIL` | `0 / 36` |
| Comparison-eligible-any roots | `36 / 36` |
| Comparison-eligible-full roots | `36 / 36` |

## 2) Output Inventory

Primary outputs:

- summary markdown:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-172014__git-3a56f9e/summary/qdesn_dynamic_main_comparison_analysis.md`
- QDESN-vs-reference summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-172014__git-3a56f9e/comparison_vs_reference/comparison_summary.md`
- overview table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-172014__git-3a56f9e/tables/analysis_overview.csv`
- authoritative local baseline map:
  - `tables/authoritative_local_baseline_map.csv`
- authoritative root override map:
  - `tables/authoritative_root_override_map.csv`
- fit-signoff summaries:
  - `tables/authoritative_fit_prior_summary.csv`
  - `tables/authoritative_fit_method_model_summary.csv`
  - `tables/authoritative_fit_surface_summary.csv`
- root readiness summaries:
  - `tables/authoritative_root_inventory.csv`
  - `tables/authoritative_root_axis_summary.csv`
  - `tables/authoritative_root_surface_summary.csv`
- pairwise comparison summaries:
  - `tables/authoritative_pair_axis_summary.csv`
  - `tables/authoritative_pair_surface_summary.csv`
  - `tables/authoritative_model_axis_summary.csv`
- QDESN-vs-reference deltas:
  - `tables/authoritative_qdesn_vs_reference_fit_axis_delta.csv`
  - `tables/authoritative_qdesn_vs_reference_fit_surface_delta.csv`
- fail inventory:
  - `tables/authoritative_fail_inventory.csv`

## 3) Main Comparison Findings

### 3.1 Prior-Level Read

| Prior | PASS | WARN | FAIL | Eligible Rate | Mean Runtime (s) |
|---|---:|---:|---:|---:|---:|
| `rhs_ns` | `23` | `49` | `0` | `1.000` | `12.516` |
| `ridge` | `53` | `19` | `0` | `1.000` | `12.185` |

Interpretation:

- both priors are now fully comparison-eligible on the authoritative surface
- `ridge` remains the cleaner signoff prior overall
- `rhs_ns` remains more dependent on local tuning, but the residual fail band is now closed

### 3.2 Method / Likelihood Read

| Inference | Model | PASS | WARN | FAIL | Eligible Rate | Mean Runtime (s) |
|---|---:|---:|---:|---:|---:|---:|
| `mcmc` | `al` | `22` | `14` | `0` | `1.000` |
| `mcmc` | `exal` | `1` | `35` | `0` | `1.000` |
| `vb` | `al` | `29` | `7` | `0` | `1.000` |
| `vb` | `exal` | `24` | `12` | `0` | `1.000` |

Interpretation:

- the last remaining failures were entirely in `mcmc/exal`, and they are now gone
- `vb/al` remains the healthiest and fastest broad slice
- `mcmc/exal` remains the softest area scientifically, but it is now all `WARN/PASS` rather than
  carrying hard `FAIL`s

### 3.3 Runtime Read

From `tables/authoritative_pair_axis_summary.csv`:

- VB-to-MCMC runtime ratios still range from about `2.20x` to `14.14x`
- the slowest MCMC relative to VB remains:
  - `ridge / exal / fit_size=5000`
  - mean `runtime_ratio_mcmc_vs_vb = 14.143`
- the next slowest remains:
  - `rhs_ns / exal / fit_size=5000`
  - mean `runtime_ratio_mcmc_vs_vb = 10.179`

Interpretation:

- runtime conclusions are unchanged by the root-specific promotions
- future extra MCMC compute should still be justified very selectively

### 3.4 Root Readiness

All roots are now fully comparison-ready:

| Prior | Fit Size | Roots | Full-Ready | Usable-With-Gap | Noncomparable | Fail Fits Total |
|---|---:|---:|---:|---:|---:|---:|
| `rhs_ns` | `500` | `9` | `9` | `0` | `0` | `0` |
| `rhs_ns` | `5000` | `9` | `9` | `0` | `0` | `0` |
| `ridge` | `500` | `9` | `9` | `0` | `0` | `0` |
| `ridge` | `5000` | `9` | `9` | `0` | `0` | `0` |

## 4) QDESN vs exdqlm Reference Read

Direct QDESN-vs-reference signoff/readiness deltas continue to use the normalized model mapping:

- `al <-> dqlm`
- `exal <-> exdqlm`

Key pack-level findings:

- QDESN now has `0 / 144` fit FAIL rows on the mirrored dynamic surface
- direct fail-rate deltas versus the mirrored exdqlm reference remain non-worse on all reported
  slices
- direct readiness comparisons remain valid on the same normalized join keys

Important limitation remains unchanged:

- reference runtime is still missing in the mirrored exdqlm summary inventory on this surface
- so direct runtime deltas versus exdqlm remain unavailable
- QDESN runtime is still fully summarized internally and is sufficient for compute-planning
  comparisons

## 5) Residual Gap

There is no remaining fit-level FAIL inventory under the authoritative branch-local baseline.

`tables/authoritative_fail_inventory.csv` now contains only the header row.

## 6) Recommendation

Use this pack as the authoritative comparison-facing source on the integration branch.

Recommended stance:

- treat the validation/tuning phase as effectively complete on this branch
- use the zero-fail pack for downstream comparison interpretation and reporting
- do **not** launch another validation wave by default
- reopen tuning only if you later want explicit confirmation reruns rather than because of
  unresolved fail debt

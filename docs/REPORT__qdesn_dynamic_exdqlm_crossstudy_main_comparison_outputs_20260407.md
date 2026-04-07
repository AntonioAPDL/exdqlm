# REPORT: QDESN Dynamic exdqlm Cross-Study Main Comparison Outputs

Date: 2026-04-07  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Executive Read

The main comparison-analysis pack is now generated from the authoritative branch-local baseline:

- `R1 -> L640_gmix_long_split_diag`
- `R2 -> L670_gmix_short_diag_mix`
- `R3 -> L720_ridge_long_softgamma_plus`
- `R4 -> L760_rhs_long_vbguard_deep`
- `R5 -> L770_short_mixed_local_mcmc`

This is the correct comparison-analysis source because it reflects the promoted residual-wave
winners while **not** over-promoting the later final-wave rhs-only evidence (`M850`, `M940`).

Authoritative analysis run:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-162250__git-b46643d`
- report root:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-162250__git-b46643d`

Current authoritative state:

| Metric | Value |
|---|---:|
| Fit rows | `144` |
| `PASS` | `77` |
| `WARN` | `65` |
| `FAIL` | `2` |
| Root-status `FAIL` | `0 / 36` |
| Comparison-eligible-any roots | `36 / 36` |
| Comparison-eligible-full roots | `34 / 36` |

## 2) Output Inventory

Primary outputs:

- summary markdown:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-162250__git-b46643d/summary/qdesn_dynamic_main_comparison_analysis.md`
- QDESN-vs-reference summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-162250__git-b46643d/comparison_vs_reference/comparison_summary.md`
- overview table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-162250__git-b46643d/tables/analysis_overview.csv`
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
- residual fail inventory:
  - `tables/authoritative_fail_inventory.csv`

## 3) Main Comparison Findings

### 3.1 Prior-Level Read

| Prior | PASS | WARN | FAIL | Eligible Rate | Mean Runtime (s) |
|---|---:|---:|---:|---:|---:|
| `rhs_ns` | `24` | `46` | `2` | `0.972` | `12.329` |
| `ridge` | `53` | `19` | `0` | `1.000` | `12.185` |

Interpretation:

- `ridge` is the cleaner signoff prior under the authoritative branch-local baseline.
- `rhs_ns` remains more flexible on a number of local slices, but it carries the only remaining
  residual fail band.
- the pairwise prior head-to-head table still favors `rhs_ns` in `55 / 72` surface-level
  comparisons because the tie-breaker uses fail rate, eligibility, holdout error, and runtime in
  sequence; that should be read as a **local slice preference summary**, not as a contradiction of
  the cleaner global signoff profile seen above.

### 3.2 Method / Likelihood Read

| Inference | Model | PASS | WARN | FAIL | Eligible Rate | Mean Runtime (s) |
|---|---:|---:|---:|---:|---:|---:|
| `mcmc` | `al` | `23` | `13` | `0` | `1.000` | `11.789` |
| `mcmc` | `exal` | `1` | `33` | `2` | `0.944` | `30.502` |
| `vb` | `al` | `29` | `7` | `0` | `1.000` | `2.831` |
| `vb` | `exal` | `24` | `12` | `0` | `1.000` | `3.907` |

Interpretation:

- `vb/al` is the healthiest and fastest broad slice.
- `mcmc/exal` is the only remaining fail source and is also the slowest broad slice by a wide
  margin.
- the study is therefore comparison-ready operationally, but the remaining scientific caveat is
  concentrated in `rhs_ns + mcmc_exal`.

### 3.3 Runtime Read

From `tables/authoritative_pair_axis_summary.csv`:

- VB-to-MCMC runtime ratios range from about `2.18x` to `14.14x`.
- the slowest MCMC relative to VB is:
  - `ridge / exal / fit_size=5000`
  - mean `runtime_ratio_mcmc_vs_vb = 14.143`
- the next slowest is:
  - `rhs_ns / exal / fit_size=5000`
  - mean `runtime_ratio_mcmc_vs_vb = 10.169`

Interpretation:

- MCMC carries a substantial runtime tax everywhere.
- that tax is largest on the long-horizon `exal` slices, especially under `ridge`.
- any future extra validation compute should therefore be justified very selectively.

### 3.4 Root Readiness

| Prior | Fit Size | Roots | Full-Ready | Usable-With-Gap | Noncomparable | Fail Fits Total |
|---|---:|---:|---:|---:|---:|---:|
| `rhs_ns` | `500` | `9` | `8` | `1` | `0` | `1` |
| `rhs_ns` | `5000` | `9` | `8` | `1` | `0` | `1` |
| `ridge` | `500` | `9` | `9` | `0` | `0` | `0` |
| `ridge` | `5000` | `9` | `9` | `0` | `0` | `0` |

Interpretation:

- all `36 / 36` roots now have at least usable comparison output.
- the only non-full-ready roots are both `rhs_ns` normal tails, one at `500` and one at `5000`.
- there are no outright broken roots left.

## 4) QDESN vs exdqlm Reference Read

Direct QDESN-vs-reference signoff/readiness deltas are now computed with a normalized model
mapping:

- `al <-> dqlm`
- `exal <-> exdqlm`

This enables fair direct deltas for:

- `PASS / WARN / FAIL` rate
- comparison-eligibility rate

Key pack-level findings from `tables/authoritative_qdesn_vs_reference_fit_axis_delta.csv`:

- `8 / 16` axis slices have strictly lower QDESN fail rate than the mirrored exdqlm reference
- `8 / 16` are tied on fail rate
- `0 / 16` are worse on fail rate
- `12 / 16` have higher QDESN pass rate than the mirrored exdqlm reference
- `8 / 16` have higher QDESN comparison-eligibility rate than the mirrored exdqlm reference

Examples:

- `mcmc / exal / fit_size=5000 / rhs_ns`
  - QDESN fail rate: `0.111`
  - reference fail rate: `0.778`
  - delta: `-0.667`
- `mcmc / exal / fit_size=5000 / ridge`
  - QDESN fail rate: `0.000`
  - reference fail rate: `0.778`
  - delta: `-0.778`
- `vb / al / fit_size=5000 / ridge`
  - QDESN pass rate: `1.000`
  - reference pass rate: `0.333`
  - delta: `+0.667`

Important limitation:

- reference runtime is currently missing in the mirrored exdqlm summary inventory on this surface
  (`0 / 16` axis rows have non-missing reference runtime)
- so direct runtime deltas vs exdqlm remain unavailable in this pack
- QDESN runtime is still fully summarized internally and should be used for compute planning

## 5) Remaining Residual Gap

Only `2` fit rows remain at `FAIL`, both on `rhs_ns / mcmc_exal`:

| Root | Method Row | Reason |
|---|---|---|
| `root__dynamic__dlm_constV_smallW__normal__tau_0p05__lasttt_5000__qdesn_rhs_ns` | `mcmc_exal` | `geweke_drift; half_chain_drift` |
| `root__dynamic__dlm_constV_smallW__normal__tau_0p95__lasttt_500__qdesn_rhs_ns` | `mcmc_exal` | `geweke_drift` |

These are the only remaining gaps under the authoritative branch-local baseline.

## 6) Recommendation

Use this analysis pack as the authoritative source for main comparison interpretation and any
downstream comparison-facing reporting.

Recommended stance:

- move forward to main comparison analysis from this baseline now
- keep the `2 / 144` residual fit FAIL rows explicit rather than hiding them
- do not launch further tuning by default unless zero-fit-FAIL certification becomes a hard
  requirement

## QDESN Tau050 Recovered Study-Facing Analysis Pack Outputs

Date: `2026-04-21`  
Status: canonical clean-SHA study-facing analysis pack completed from implementation commit `2a9c078`

## Canonical Run

- implementation commit: `2a9c078`
- source recovered comparison root:
  - [recovered main comparison root](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_recovered_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-tau050-recovered-maincmp-20260421-024204__git-86be927)
- study-facing run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-tau050-studyfacing-20260421-030134__git-2a9c078`
- study-facing analysis root:
  - [study-facing analysis root](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_recovered_study_facing_analysis/qdesn-dynamic-exdqlm-crossstudy-tau050-studyfacing-20260421-030134__git-2a9c078)
- primary outputs:
  - [study-facing summary](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_recovered_study_facing_analysis/qdesn-dynamic-exdqlm-crossstudy-tau050-studyfacing-20260421-030134__git-2a9c078/summary/qdesn_tau050_recovered_study_facing_analysis.md)
  - [representative case table](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_recovered_study_facing_analysis/qdesn-dynamic-exdqlm-crossstudy-tau050-studyfacing-20260421-030134__git-2a9c078/summary/qdesn_tau050_representative_case_table.md)

## Headline Outcome

| Metric | Value |
|---|---:|
| recovered source fit rows | 144 |
| recovered source runtime `FAIL` | 0 |
| recovered source signoff `FAIL` | 40 |
| recovered source root-status `FAIL` | 0 |
| representative rows | 36 |
| representative `PASS` | 33 |
| representative `WARN` | 3 |
| representative `FAIL` | 0 |
| representative rows aligned to mirrored reference | 24 |
| representative rows with tau `0.50` reference gap | 12 |

## Main Read

The most important conclusion is:

- there are no remaining numerical runtime crashes in the tau050 source study
- the clean study-facing surface is the representative layer
- the remaining weaker surface is diagnostic, not operational

This is the final transition from recovery engineering into analysis.

## Representative Surface

### By prior and model

| Prior | Model | Rows | PASS | WARN | FAIL |
|---|---|---:|---:|---:|---:|
| `rhs_ns` | `al` | 12 | 9 | 3 | 0 |
| `rhs_ns` | `exal` | 6 | 6 | 0 | 0 |
| `ridge` | `al` | 12 | 12 | 0 | 0 |
| `ridge` | `exal` | 6 | 6 | 0 | 0 |

The representative surface is entirely `vb`, and `ridge` is the cleanest comparison prior.

### Root readiness

| Prior | Roots | Any compare-ready | Full compare-ready |
|---|---:|---:|---:|
| `rhs_ns` | 18 | 15 | 0 |
| `ridge` | 18 | 18 | 15 |

So the practical comparison policy is:

- `ridge` for clean study-facing comparison
- `rhs_ns` for stress testing and secondary discussion

## Reference Alignment

Representative-reference alignment is limited by the existing mirrored reference contract:

- aligned rows: `24`
- gap rows: `12`

All `12` gaps are tau `0.50` representatives. Those rows remain useful as QDESN study results, but
they are not strict like-for-like QDESN-vs-reference deltas unless the mirrored reference is rerun
under the tau050 contract.

## Remaining Diagnostic Weakness

The remaining signoff weakness is sharply localized:

| Slice | Fail rate |
|---|---:|
| `mcmc al rhs_ns` | 94.4% |
| `mcmc exal rhs_ns` | 94.4% |
| `mcmc exal ridge` | 5.6% |
| `vb exal rhs_ns` | 16.7% |
| `vb exal ridge` | 11.1% |

Dominant remaining reasons:

- `high_autocorrelation`
- `geweke_drift`
- `half_chain_drift`
- `core_parameter_tail_unstable`

That means the remaining weakness is a fit-quality issue concentrated in `mcmc rhs_ns`, not a
runtime stability issue.

## Recommended Forward Path

The best next move is:

1. use this study-facing pack as the canonical tau050 presentation layer
2. treat the representative layer as the primary study table source
3. keep the full recovered 144-fit surface as a secondary diagnostic appendix
4. only rerun the mirrored reference if strict tau `0.50` alignment becomes a real requirement

## Read

This pack is the recovered tau050 study in its presentation-ready form:

- runtime failures are gone
- representative comparisons are clean
- remaining softness is explicitly documented and bounded

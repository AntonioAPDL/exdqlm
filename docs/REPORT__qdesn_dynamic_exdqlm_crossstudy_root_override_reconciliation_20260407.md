# REPORT: QDESN Dynamic exdqlm Cross-Study Root-Override Reconciliation

Date: 2026-04-07  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Executive Read

The remaining `2 / 144` fit-level FAIL rows are now closed on this branch without another compute
wave.

The key change is that the final-wave rhs candidates are now promoted only where they are actually
better:

- `M850_rhs_long_burnheavy1300`
  - promoted for:
    - `root__dynamic__dlm_constV_smallW__normal__tau_0p05__lasttt_5000__qdesn_rhs_ns`
- `M940_short_rhs_narrow1200_diag5`
  - promoted for:
    - `root__dynamic__dlm_constV_smallW__normal__tau_0p95__lasttt_500__qdesn_rhs_ns`

These are **root-specific** promotions, not stage-wide replacements.

That distinction matters:

- the broader `F1/F2` stage swaps were not clear global promotions;
- but each selected candidate clearly improves the exact remaining failing scenario;
- local tuning per scenario is already the intended decision rule for this phase.

## 2) Why This Promotion Is Now Justified

Previous conclusion after the final wave:

- do **not** promote `M850` or `M940` as full 4-root stage-wide replacements
- because:
  - `M850` was globally neutral when applied to all `F1` guard roots
  - `M940` was globally worse when applied to all `F2` guard roots

What changed here:

- I compared the authoritative source baseline and the final-wave candidates on the **exact**
  remaining fail roots
- the guard-root regressions are localized to the other stage guard roots, not to the exact failing
  roots themselves
- therefore the stage-wide rejection does **not** imply that the target-root fits should be
  rejected

Exact target-root evidence:

| Root | Source State | Candidate | Candidate Result | Promotion Read |
|---|---|---|---|---|
| `normal tau=0.05 lastTT5000 rhs_ns` | `mcmc_exal = FAIL`, root not full-ready | `M850` | `mcmc_exal = WARN`, root full-ready | promote locally |
| `normal tau=0.95 lastTT500 rhs_ns` | `mcmc_exal = FAIL`, root not full-ready | `M940` | `mcmc_exal = WARN`, root full-ready | promote locally |

Why `M940` is preferred over `M950` for the short-horizon target root:

- both clear the exact target `mcmc_exal` fail row
- `M940` keeps the non-fail rows on the target root cleaner overall
- `M950` weakens the target-root `al/mcmc` row much more sharply

## 3) Authoritative Baseline After Reconciliation

Stage-level local baseline map:

- `R1 -> L640_gmix_long_split_diag`
- `R2 -> L670_gmix_short_diag_mix`
- `R3 -> L720_ridge_long_softgamma_plus`
- `R4 -> L760_rhs_long_vbguard_deep`
- `R5 -> L770_short_mixed_local_mcmc`

Additional exact-root overrides:

- `root__dynamic__dlm_constV_smallW__normal__tau_0p05__lasttt_5000__qdesn_rhs_ns`
  - `M850_rhs_long_burnheavy1300`
- `root__dynamic__dlm_constV_smallW__normal__tau_0p95__lasttt_500__qdesn_rhs_ns`
  - `M940_short_rhs_narrow1200_diag5`

This reconciled authoritative baseline now yields:

| Metric | Value |
|---|---:|
| Fit rows | `144` |
| `PASS` | `76` |
| `WARN` | `68` |
| `FAIL` | `0` |
| Root-status `FAIL` | `0 / 36` |
| Comparison-eligible-any roots | `36 / 36` |
| Comparison-eligible-full roots | `36 / 36` |

## 4) What Improved

- fit FAIL rows:
  - `2 -> 0`
- fail-carrying roots:
  - `2 -> 0`
- fully comparison-ready roots:
  - `34 / 36 -> 36 / 36`
- root-status FAILs:
  - stayed at `0 / 36`

This means the dynamic mirrored QDESN study on the synced `0.4.0` base is now fully comparison
ready under the authoritative branch-local baseline.

## 5) What Worked Best

Most effective ideas in the surviving residual space:

- long-horizon rhs burn-heavy warmup for the normal lower-tail pocket
  - `M850`
- short-horizon rhs narrow-plus-diag stabilization for the normal upper-tail pocket
  - `M940`
- broader residual-wave winners already promoted earlier:
  - `L640`, `L670`, `L720`, `L760`, `L770`

These results reinforce the actual lesson from the late-stage cleanup:

- the remaining debt was not asking for one universal new default
- it was asking for **small local adjustments** around a stable baseline

## 6) What Did Not Help Enough

Still dominated or lower-value directions in the final rhs cleanup:

- `M820`
  - deeper pure-chain increase without enough stability benefit
- `M830`
  - narrower long-horizon variant without solving the target row
- `M920`
  - introduced a root execution fail and is not acceptable
- `M950`
  - clears the target row, but is weaker than `M940` on the target-root non-fail rows

## 7) Highest-Value Move Forward

There is no remaining fit-level FAIL surface to target.

So the correct move forward is now:

1. treat the validation/tuning phase as effectively closed on this branch
2. use the reconciled zero-fail authoritative baseline for comparison-facing analysis
3. do **not** launch another overnight validation wave by default

The only reason to reopen tuning from here would be optional confirmatory or certification-style
reruns, not unresolved scientific failure debt.

## 8) Reproducible Artifacts

Authoritative zero-fail comparison pack:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-194527__git-14d63dd`
- summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-194527__git-14d63dd/summary/qdesn_dynamic_main_comparison_analysis.md`
- root override map:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-194527__git-14d63dd/tables/authoritative_root_override_map.csv`
- fail inventory:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-194527__git-14d63dd/tables/authoritative_fail_inventory.csv`
- explicit q-true fit summaries:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-194527__git-14d63dd/tables/authoritative_fit_inference_summary.csv`
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-194527__git-14d63dd/tables/authoritative_fit_model_summary.csv`

Manifest and tooling:

- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_main_comparison_analysis_manifest.yaml`
- main analysis helper:
  - `R/qdesn_dynamic_exdqlm_crossstudy_main_comparison_analysis.R`
- source-state overlay helper:
  - `R/qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`
- runner:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_main_comparison_analysis.R`

## 9) Recommendation

Promote the two exact-root overrides above as part of the authoritative branch-local baseline and
move forward with the main comparison narrative from the zero-fail pack.

No additional overnight validation launch is applicable right now.

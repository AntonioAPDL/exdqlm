# REPORT: QDESN Static exdqlm Cross-Study Wave 2 Stage-1 Closeout

Date: 2026-04-04  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Scope And Stop State

Wave 2 was originally launched as a two-stage debt-only follow-up to the broad static cross-study
baseline:

- source baseline:
  - `qdesn-static-exdqlm-crossstudy-20260404b__git-06ac1c0`
- debt-wave run:
  - `qdesn-static-exdqlm-crossstudy-debt-20260404a__git-e2677d0`

The debt wave completed Stage 1 and was then intentionally stopped before Stage 2 by user request.

Important interpretation:

- Stage-1 findings are real and should be carried forward.
- Stage-2 confirmation did **not** complete and should not be claimed.

## 2) What Improved

Stage-1 probe surface:

- `9` roots total
  - `6` hard root FAIL roots
  - `3` representative `rhs_ns` debt probes
- `6` profiles completed:
  - `D400_anchor_replay`
  - `D410_ridge_rescue_reference`
  - `D420_softgamma_geometry`
  - `D430_rhssoft_freeze90`
  - `D440_crossover_softgamma_rhssoft`
  - `D450_rhs_diagnostics_probe`

Main improvement:

- **all 6 completed Stage-1 profiles rescued the 6/6 hard root FAILs on the probe surface**

This is the key outcome from Stage 1. The original narrow hard-fail band no longer looks like the
main remaining blocker.

## 3) What Still Fails

The broader Wave-1 source baseline still contains more debt than the original Wave-2 framing
captured.

Source broad baseline facts:

- root-level status:
  - `72` roots materialized
  - `66` root `SUCCESS`
  - `6` root `FAIL`
- fit-level signoff:
  - `130` fit `FAIL` rows

The remaining source FAIL surface now splits into three concrete buckets:

1. `rhs_ns` VB diagnostics-path FAILs
   - `66` FAIL rows
   - `33` roots
   - all with `signoff_reason = rhs_diagnostics_missing`
2. ridge `exal/mcmc` stability FAILs
   - `24` FAIL rows
   - `24` roots
3. `rhs_ns` `mcmc` stability FAILs
   - `40` FAIL rows
   - `30` roots

Additional important nuance:

- only `3` roots would be fully cleared by fixing the `rhs_ns` diagnostics-path bug alone
- so the diagnostics fix is high-value, but it is **not** the whole remaining solution

## 4) Which Ideas Worked Best

Shared baseline / broad default:

- `D400_anchor_replay` remains the best balanced Stage-1 control
- it preserved the hard-fail rescue and had the lowest Stage-1 probe `fit_n_fail`

Local ridge rescue:

- `D410_ridge_rescue_reference` ranked `#1` in Stage 1
- it matched `D400` on hard-fail rescue and improved probe comparison coverage
- it should now be treated as the **local ridge rescue reference**, not as a global default

## 5) Which Ideas Did Not Help Enough

The following did not justify reuse as leading directions:

- `D420_softgamma_geometry`
- `D430_rhssoft_freeze90`
- `D440_crossover_softgamma_rhssoft`
- `D450_rhs_diagnostics_probe`

Why:

- they did not beat the combined `D400` / `D410` picture strongly enough on the probe surface
- the rhs-local probes in particular did **not** convert enough `rhs_ns` debt to justify another
  generic rhs sweep

## 6) New Main Takeaway

Wave 2 Stage 1 changed the problem definition.

The remaining work is no longer best framed as:

- “rescue the six hard root FAILs and improve compare-any coverage”

It is now better framed as:

- “eliminate the remaining fit-level FAIL buckets with the shared baseline as default and
  slice-specific local tuning where needed”

This matters because the user goal is now explicit:

- get every case to at least `PASS` or `WARN`
- eliminate `FAIL`
- do not waste time looking for one generic tuning solution if the remaining debt is slice-local

## 7) Baseline Decision

Current baseline decisions after Stage 1:

- shared default baseline:
  - keep the shared static defaults as the default
- local ridge reference:
  - promote `D410_ridge_rescue_reference` as the best completed local ridge rescue lead
- local rhs reference:
  - no new rhs local profile is promoted from Stage 1

This is the correct split because no completed result clearly beat the shared default broadly, but
`D410` is the strongest local ridge signal from completed evidence.

## 8) Highest-Value Directions From Here

1. Patch the `rhs_ns` diagnostics-path bug so successful rhs-family VB fits are no longer marked
   `FAIL` only because the helper ignored `rhs_ns`.
2. Recheck the full `33`-root `rhs_ns` VB diagnostics bucket under the shared default baseline.
3. Run a local ridge fail-closure stage on the `24` ridge `exal/mcmc` fail roots using:
   - shared baseline control
   - `D410`-style ridge rescue
   - one slightly heavier chain-extension ridge variant
4. Split the `rhs_ns` `mcmc` fail surface by `tt=100` and `tt=1000` and tune those slices
   separately instead of forcing one generic rhs profile.

## 9) Follow-On Validation Note

That first follow-on step has now been completed at the code-path level:

- the validation collector now recovers rhs-family diagnostics from `rhs_trace.rds` when
  `rhs_run_summary.csv` is missing;
- a representative `rhs_ns` smoke root confirms that the two VB rows are no longer falsely marked
  `rhs_diagnostics_missing`;
- under fresh-status semantics, those rows downgrade from false `FAIL` to usable `WARN`.

This means the next launch no longer needs to treat the `rhs_ns` VB bucket as an open bug hunt.
It should now be treated as a closure stage under the patched shared default baseline.

## 10) Read Next

1. `docs/PLAN__qdesn_static_exdqlm_crossstudy_wave3_fit_fail_closure_20260404.md`
2. `docs/TRACK__qdesn_static_exdqlm_crossstudy_validation.md`
3. `config/validation/qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave_manifest.yaml`
4. `scripts/run_qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave.R`
5. `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave.R`

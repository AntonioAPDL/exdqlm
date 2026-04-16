# REPORT: QDESN Dynamic Effective-W300 Postdraw Deep-DESN Row-Faithful Multiseed Replay Closeout And Failure Audit

Date: 2026-04-16
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Record the final outcome of the corrected row-faithful multiseed replay, distinguish operational
health from scientific outcome, and audit whether the remaining failures are caused by mixing
problems, numeric invalidity, or crashes.

This report supersedes the launch-time-only view in:

- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_setup_and_launch_20260412.md`

## 2) Completed Run

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-rowfaithseed-20260412-124648__git-7144048`
- detached session:
  - `qdesn_dynx_0412_124649`
- completion state:
  - campaign completed manifest present
  - launcher session closed normally
  - `0` `root_error.txt` files

## 3) Final Completion Summary

- planned roots:
  - `36 / 36`
- materialized roots:
  - `36 / 36`
- root outcomes:
  - `26 SUCCESS`
  - `10 FAIL`
  - `0 RUNNING`
- fit summary rows:
  - `144 / 144`
- pair summary rows:
  - `72 / 72`
- root summary rows:
  - `36 / 36`
- MCMC seed selection rows:
  - `288 / 288`
- MCMC seed winner rows:
  - `72 / 72`

Final fit signoff mix:

- `66 PASS`
- `44 WARN`
- `34 FAIL`

Final fit execution status mix:

- `129 SUCCESS`
- `15 FAIL`

## 4) Final Root Failure Surface

The final root-level `FAIL` pocket is fully concentrated in long-horizon `fit_size = 5000`
MCMC-sensitive rows:

- `gausmix tau=0.05 fit_size=5000 rhs_ns`
- `gausmix tau=0.25 fit_size=5000 rhs_ns`
- `gausmix tau=0.95 fit_size=5000 rhs_ns`
- `laplace tau=0.05 fit_size=5000 rhs_ns`
- `laplace tau=0.05 fit_size=5000 ridge`
- `laplace tau=0.25 fit_size=5000 rhs_ns`
- `laplace tau=0.95 fit_size=5000 rhs_ns`
- `normal tau=0.05 fit_size=5000 rhs_ns`
- `normal tau=0.25 fit_size=5000 ridge`
- `normal tau=0.95 fit_size=5000 rhs_ns`

## 5) Failure Taxonomy

The finished replay does **not** support the claim that all remaining failures are purely
mixing-only failures.

There are two distinct failure classes.

### 5.1 Hard Fit-Status Failures

- count:
  - `15`
- inference:
  - all `mcmc`
- fit-size split:
  - `13` at `fit_size = 5000`, `rhs_ns`
  - `2` at `fit_size = 5000`, `ridge`
- stop reason:
  - all `missing_chain_diagnostics`
- finite/domain flags:
  - `finite_ok = FALSE` for all `15`
  - `domain_ok = FALSE` for all `15`

Interpretation:

- these are **not root crashes**, because there are no `root_error.txt` files;
- but they are also **not merely poor-mixing warnings**;
- they are fit-level failures where the finished replay could not produce a valid chain-diagnostics
  outcome and the resulting fit row is marked numerically/diagnostically invalid.

### 5.2 Signoff-Only Failures With Successful Fit Execution

- count:
  - `19`
- inference:
  - all `mcmc`
- split:
  - `18` at `fit_size = 500`, `rhs_ns`
  - `1` at `fit_size = 5000`, `rhs_ns`
- finite/domain flags:
  - `finite_ok = TRUE` for all `19`
  - `domain_ok = TRUE` for all `19`
- stop-reason mix:
  - `high_autocorrelation`
  - `high_autocorrelation; geweke_drift`
  - `high_autocorrelation; geweke_drift; half_chain_drift`

Interpretation:

- these are the genuine **poor-mixing / drift** failures;
- the fit executed successfully, but the diagnostics remained too weak for acceptable signoff.

## 6) Key Implication

The replay path itself is still validated:

- the run used the corrected row-faithful contract;
- the run completed cleanly;
- there were no root-level execution crashes.

But the accepted deep-DESN source does **not** fully survive the replay as a clean branch-local
candidate. The remaining blocker is a mixed MCMC-quality problem:

- one part is true mixing/diagnostic weakness;
- one part is more severe diagnostic invalidity in long-horizon `fit_size = 5000` MCMC rows.

## 7) Valid Conclusion

What is justified:

- treat the row-faithful replay as valid evidence;
- use it to identify which accepted rows still hold up and which do not;
- treat the long-horizon `5000` MCMC pocket as the main unresolved blocker.

What is **not** justified:

- claiming that all remaining failures are only due to poor mixing;
- claiming that the remaining failures are execution crashes.

The accurate statement is:

- there were **no root-level crashes**;
- some failures are **poor-mixing signoff failures**;
- some failures are **numerically/diagnostically invalid MCMC rows** with
  `missing_chain_diagnostics`.

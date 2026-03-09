# Draft Message to Raquel

I finished the branch-hardening pass on `jaguir26/dqlm-conjugacy-cavi-gibbs` so it is ready for later integration into `cransub/0.4.0`, but I have not merged anything into your branch.

Main items prepared on this branch:

- dynamic/static exAL and AL branch work cleaned and documented
- static exAL/AL simulation, normalization, reporting, and audit tooling added
- dynamic/static VB and MCMC convergence diagnostics standardized
- slice support added for gamma in MCMC
- optional per-iteration diagnostics traces added for MCMC
- MCMC efficiency improvements added, especially in the static exAL slice path
- static `RHS` prior support added for `AL` / `exAL` in both `VB` and `MCMC`
- qdesn-style `RHS` tau warmup/freeze safeguards added to the static `VB` path
- reduced DQLM path support and tests added
- roxygen docs regenerated and test coverage expanded

Validation completed on this branch:

- targeted branch tests passed (`PASS 43, FAIL 0, WARN 0, SKIP 1`)
- full package test suite passed (`PASS 1363, FAIL 0, WARN 0, SKIP 1`)
- package-level tarball check completed with only the installed-size note

Important scientific note:

- on several simple and skew-normal validation datasets, `AL` often recovered
  the target quantile better than `exAL`
- that same qualitative behavior was also reproduced against the external
  Yan-Kottas `GAL` implementation (`bqrgal`), so it does not currently look
  like a purely repo-specific coding artifact
- on matched exAL/GAL-generated data, our `exAL` and the external package
  behaved similarly, which is consistent with the current implementation being
  scientifically interpretable rather than structurally broken

Important RHS note:

- the initial static `exAL + RHS` `VB` tail-collapse issue was fixed with the
  tau warmup/freeze schedule
- the remaining `RHS` signoff issue is localized tail mixing/tuning for
  `exAL`, not a structural failure of the feature

Important integration note:

- I did not merge or rebase onto `cransub/0.4.0`
- I want to wait for your confirmation before pulling your latest changes and doing any integration work

Once you confirm, the next step should be:

1. pull your latest `cransub/0.4.0` changes
2. integrate this branch on top of that work
3. rerun full tests and package check on the integrated result

Please let me know when your `cransub/0.4.0` work is in a good state for that integration step.

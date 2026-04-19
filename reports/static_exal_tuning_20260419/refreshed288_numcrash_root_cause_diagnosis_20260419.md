# Refreshed288 Numerical-Crash Root-Cause Diagnosis

Date: `2026-04-19`

## Scope

This note diagnoses the current numerical-crash relaunch:

- run tag: `20260419_numcrash_stsfreeze_v1`
- scope: the frozen `20` dynamic numerical/runtime crash rows only
- excluded: static MCMC gate/mixing failures

The question addressed here is:

> Are the remaining dynamic MCMC crashes mainly a GIG latent-sampler tuning issue, or is the true root cause somewhere earlier in the dynamic MCMC path?

## Executive Conclusion

The current evidence says the root cause is **not** the GIG sampler.

The failing dynamic MCMC rows are crashing at the **first theta FFBS draw on iteration 1**, before the latent `U_t` or `U_t / s_t` GIG updates are called.

The strongest new result is a backend comparison:

- representative failing exDQLM row `8`:
  - `C++` MCMC backend: fails immediately at `exdqlm_mcmc_pre_latent (iter=1 ...)`
  - `R` MCMC backend: gets past that first step and returns an `exdqlmMCMC` fit
- representative failing DQLM row `6`:
  - `C++` MCMC backend: fails immediately at `dqlm_mcmc_pre_uts (iter=1 ...)`
  - `R` MCMC backend: gets past that first step and returns an `exdqlmMCMC` fit
- control row `12`:
  - both backends run

So the clean diagnosis is:

1. the failure appears **before** the latent GIG step,
2. it appears **exactly at the first MCMC theta draw / immediate post-theta state check**,
3. the failure is **backend-sensitive**,
4. the most likely root cause is the **fast C++ FFBS theta-sampler path**, not the GIG latent sampler.

## Where The Failure Happens

### exDQLM

In [R/exdqlmMCMC.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmMCMC.R:992), the exDQLM MCMC loop does:

1. build `ex.f` and `ex.q`
2. sample `theta` via `ex_samp_theta(...)`
3. compute `reg1 = state_signal(FF, cursam.theta)`
4. validate the sampled state
5. only after that, sample latent `U_t / s_t`

The relevant stop is at [R/exdqlmMCMC.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmMCMC.R:1001):

- `exdqlm_mcmc_pre_latent (iter=1 ...) invalid state before Ut/st update`

That means the row is failing **before** `ex_samp_uts(...)` or `ex_samp_sts(...)` can rescue or destabilize anything.

### DQLM

In [R/exdqlmMCMC.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmMCMC.R:1620), the DQLM loop does:

1. build `ex.f` and `ex.q`
2. sample `theta` via `samp_theta(...)`
3. compute `reg1`
4. validate the sampled state
5. only after that, sample latent `U_t`

The relevant stop is at [R/exdqlmMCMC.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmMCMC.R:1627):

- `dqlm_mcmc_pre_uts (iter=1 ...) invalid state before chi update`

Again, this is **before** `samp_uts(...)`.

## Why This Is Not Primarily A GIG Tuning Problem

The GIG samplers are only called later:

- exDQLM latent `U_t`: [R/exdqlmMCMC.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmMCMC.R:779)
- DQLM latent `U_t`: [R/exdqlmMCMC.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmMCMC.R:1527)

But the current crashing rows never get that far.

So:

- tuning GIG step size or related latent-sampler behavior may matter later,
- but it does **not** explain the current iteration-1 failures,
- and it should **not** be treated as the primary fix for the present crash surface.

## New Backend Evidence

The package currently defaults to the fast C++ MCMC backend:

- [R/zzz.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/zzz.R:11)

The routing happens here:

- [R/exdqlmMCMC.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmMCMC.R:377)

The C++ backend is enabled when:

- `options(exdqlm.use_cpp_mcmc = TRUE)`
- `options(exdqlm.cpp_mcmc_mode = "fast")`

I ran direct one-step reproductions on representative rows with the same saved VB init and the same run config, changing only the backend.

### Representative result

| Row | Case | C++ backend | R backend |
|---|---|---|---|
| `8` | exDQLM `gausmix / 0.05 / TT5000` | fails at `pre_latent` on iter 1 | returns `exdqlmMCMC` |
| `6` | DQLM `gausmix / 0.05 / TT5000` | fails at `pre_uts` on iter 1 | returns `exdqlmMCMC` |
| `12` | exDQLM `gausmix / 0.25 / TT500` | returns `exdqlmMCMC` | returns `exdqlmMCMC` |

That is the clearest root-cause evidence gathered so far.

## Why The C++ Path Is The Likely Root Cause

The C++ FFBS implementation in [src/mcmc_ffbs.cpp](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/src/mcmc_ffbs.cpp:135):

- symmetrizes covariance matrices
- floors invalid/non-positive `q` to `1e-12`
- uses SVD-based inversion

But it does **not** apply the package’s dynamic regularization layer:

- no `.exdqlm_regularize_cov(...)`
- no eigenvalue cap/floor from [R/utils.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/utils.R:484)
- no `.exdqlm_regularize_var(...)` with the package `q_cap` policy from [R/utils.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/utils.R:515)

By contrast, the R FFBS path in [R/exdqlmMCMC.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmMCMC.R:702) and [R/exdqlmMCMC.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmMCMC.R:1452) repeatedly regularizes:

- `P`
- `R`
- `q`
- `C`
- backward `sC`

using the package numeric guards.

So the likely mechanism is:

1. some failing dynamic rows enter iter 1 with extreme but finite VB-init state scales,
2. the fast C++ FFBS theta sampler processes those scales without the same covariance regularization/capping used in the R path,
3. the sampled `theta` becomes non-finite on iter 1,
4. the run stops at the pre-latent validity check,
5. the latent GIG step is never reached.

## Why It Appears So Early

It appears at `iter = 1` because the first MCMC iteration immediately uses:

- the VB-init `sigma`
- the VB-init `gamma` for exDQLM
- the VB-init latent `U_t` and `s_t`

to build:

- exDQLM:
  - `tau = p.fn(p0, gamma)`
  - `a_tau`, `b_tau`, `c_tau`
  - `ex.f = sigma * c_tau * |gamma| * s_t + U_t * a_tau`
  - `ex.q = b_tau * U_t * sigma`
- DQLM:
  - `ex.f = U_t * a_tau`
  - `ex.q = b_tau * U_t * sigma`

Then the very first theta sample is drawn from those inputs.

There is no opportunity for:

- latent warmup,
- sigma/gamma warmup,
- or GIG tuning

to help **before** that first theta draw.

That is why the crashes are so early and so stubborn.

## Representative Scale Evidence

The failing rows are not entering MCMC with obviously non-finite VB init anymore. The new `s_t` freeze work succeeded in making representative exDQLM VB-init objects finite.

But the scale profile is still extreme for the failing rows.

Examples from the saved VB-init fits:

| Row | Case | `sigma` | `max|theta|` | `max|reg1|` | `max U_t` | `tau_trans` | `b_tau` |
|---|---:|---:|---:|---:|---:|---:|---:|
| `8` | exDQLM fail | `21.35` | `12343.7` | `12389.9` | `289.4` | `0.0521` | `40.46` |
| `16` | exDQLM fail | `72.50` | `12467.5` | `12510.2` | `1034.5` | `0.2226` | `11.56` |
| `6` | DQLM fail | `19.12` | `12342.3` | `12388.5` | `277.7` | fixed `0.05` | `42.11` |
| `14` | DQLM fail | `84.45` | `12463.1` | `12507.2` | `1124.0` | fixed `0.25` | `10.67` |
| `12` | exDQLM control / WARN | `2852.4` | `2330.4` | `2787.4` | `3308.3` | `0.2428` | `10.88` |

The most distinctive difference is not just `sigma`, but the overall state scale:

- failing rows have `|theta|` and `|reg1|` around `1.2e4`
- the control row is much smaller there

So the problem looks like a **state-draw stability problem under extreme first-iteration FFBS inputs**, not a latent-draw problem.

## Exact Root-Cause Statement

The current numerical-crash rerun is failing because the **fast C++ MCMC FFBS theta backend** is numerically unstable on a subset of dynamic rows with extreme first-iteration state scales.

More precisely:

- the failing rows enter MCMC with finite VB-init values,
- the first MCMC theta draw is performed by the fast C++ FFBS path,
- that C++ path does not apply the same covariance regularization/capping policy as the legacy R path,
- the sampled `theta` becomes non-finite on iter 1,
- the run fails at the pre-latent validity check,
- and therefore the latent GIG samplers are never actually involved in the observed crash.

## What This Means For The Next Fix

### We should not start with GIG tuning

GIG tuning is not the first lever because the current failures happen before GIG is called.

### The first fix should target the first theta FFBS draw

The next high-value fix path is:

1. make the dynamic MCMC crash-recovery lane use the **R MCMC backend** for the crash cohort, or
2. bring the C++ FFBS path into parity with the R path by adding the same covariance/variance regularization semantics.

For immediate scientific progress, the cheaper option is:

- rerun the numerical crash cohort with `options(exdqlm.use_cpp_mcmc = FALSE)`

For a durable package fix, the cleaner option is:

- patch [src/mcmc_ffbs.cpp](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/src/mcmc_ffbs.cpp:135)
- add parity tests against the R FFBS path
- only then re-enable the fast backend for this surface

## Recommended Next Step

The next relaunch should be:

- the same frozen `20`-row numerical crash cohort
- same exDQLM `s_t` freeze / warmup
- same DQLM latent/sigma warmup
- **but with the dynamic MCMC backend forced to the regularized R path**

That is the most direct way to test the root-cause hypothesis and separate:

- backend-driven theta-sampler instability
from
- any remaining genuine latent/GIG instability.

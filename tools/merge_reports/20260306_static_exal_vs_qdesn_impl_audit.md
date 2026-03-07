# Static exAL vs qdesn exAL Audit

Date: 2026-03-06

Repos compared:
- Current static regression repo: `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp`
- qdesn repo: `/data/muscat_data/jaguir26/exdqlm`
- qdesn branch audited: `feature/model-selection-v2-impl`

## Scope

Goal: compare the static exAL regression implemented in this repo against the exAL implementation actually used by the qdesn workflow on `feature/model-selection-v2-impl`, and isolate discrepancies that are large enough to plausibly explain why qdesn exAL appears to behave better in practice.

This audit focused on the engine-level code paths, not the README/API descriptions.

## Executive Summary

The exAL observational map is largely shared across the two repos:
- same `gamma` support logic via `L.fn/U.fn`
- same `A(p0,gamma), B(p0,gamma), C(p0,gamma)` construction
- same quantile-fixed interpretation `Q_tau(Y|X) = X beta`

But the actual fitting paths are not the same.

The most important conclusion is:

1. qdesn is not validating the exact same static exAL algorithm used here.
2. The qdesn/model-selection-v2 path uses a different LDVB engine with materially different numerical behavior.
3. The qdesn path is more regularized and more tightly bounded.
4. The qdesn path also sits on a very different design matrix geometry because it fits a DESN readout, not a plain low-dimensional static regression.
5. The qdesn branch does contain a static exAL MCMC file, but that MCMC path is actually less exact than the current repo's MCMC. So qdesn's apparent success is much more plausibly coming from the VB readout path plus design/prior structure than from a better exAL Gibbs implementation.

## Critical Path Clarification

There are multiple exAL implementations inside the qdesn branch, and this matters.

### What qdesn actually calls

- `qdesn_vb.R` in `feature/model-selection-v2-impl` currently calls `exal_ldvb_fit()`, not `exal_static_LDVB()`.
- `qdesn_model_selection_v2.R` also calls `exal_ldvb_fit()` through `ms_fit_one_tau()`.

Relevant references:
- qdesn branch `R/qdesn_vb.R`, around the readout fit block where `exal_ldvb_fit(...)` is called.
- qdesn branch `R/qdesn_model_selection_v2.R:59-95`
- qdesn branch `R/exal_ldvb_fit.R:14-112`
- qdesn branch `R/exal_ldvb_engine.R`

### Why this matters

The header comments in `qdesn_vb.R` still describe the older `exal_static_LDVB()` path, but the current code path uses `exal_ldvb_fit()` and `exal_ldvb_engine()`. So a superficial comparison against the old `exal_static_LDVB.R` file in that repo is not enough.

## High-Confidence Discrepancies

| Topic | Current repo static exAL | qdesn branch exAL path | Why it matters |
|---|---|---|---|
| Actual VB engine | `R/exal_static_LDVB.R` | `R/exal_ldvb_fit.R` -> `R/exal_ldvb_engine.R` | These are not the same engine. |
| `xi` approximation | Monte Carlo Gaussian sample in `(eta, ell)` with optional reused/antithetic/replicated draws | Deterministic second-order Delta approximation `compute_xi_fast()` | This is a major algorithmic difference. qdesn removes MC noise from the LDVB loop. |
| LD optimizer | Unconstrained `BFGS` on `(eta, ell)` with post-hoc damping and step caps | Box-constrained `L-BFGS-B` with finite `eta` and `sigma` bounds | qdesn keeps the LD block inside a narrow, data-scaled feasible region. |
| Sigma bounds | No explicit finite optimization bounds on `ell = log sigma` | `sigma_min`, `sigma_max`, `ell_lo`, `ell_hi` based on data scale | This can materially stabilize tail behavior. |
| Gamma bounds in optimizer | Only implicit through logit transform and initial clipping | Additional optimizer-space bounds `eta_lo = -12`, `eta_hi = 12` | Prevents the optimizer from living too close to the support boundary. |
| Beta prior | Fixed Normal prior `beta ~ N(b0, V0)` with diffuse default `V0 = 1e6 I` | Pluggable `beta_prior_obj`; supports ridge and RHS shrinkage | qdesn can regularize the readout much more strongly than the current static regression. |
| Gamma prior | Default flat `log_prior_gamma = function(g) 0` | Default Normal gamma prior support available through `prior_gamma = list(mu0, s20)` and often wired in through qdesn/model-selection config | qdesn has an easy path to shrink `gamma` toward zero; the current static regression usually does not. |
| Sigma prior interface | Fixed `a_sigma, b_sigma` arguments | Same IG prior family, but wrapped and standardized in `prior_sigma` | Similar family, but qdesn wraps it into a better controlled engine. |
| Tail tolerance policy | Usually one tolerance path per run | `ms_build_vb_control()` uses tau-specific defaults: tighter tail tolerances than the median | qdesn explicitly treats tail fits as needing stricter convergence control. |
| Design matrix | Plain static regression design `X` | DESN feature readout with lag preprocessing, washout, scaling, optional weights, optional feature noise | Even with the same likelihood, the posterior geometry is not comparable. |
| MCMC gamma kernel | Supports exact `rw` and `laplace_rw` kernels; tracks exactness/signoff readiness | qdesn branch static MCMC uses a Laplace-local Gaussian draw for `gamma` with no MH correction | The current repo's static MCMC is more rigorous than the qdesn branch's static MCMC. |

## Detailed Findings

### 1. The shared exAL observational map looks aligned

The audited shared pieces do not show a core formula mismatch at the likelihood level:

- current repo `R/utils.R:2-8`
- qdesn branch `R/00_utils.R:76-130` via `exal_get_ABC(...)`
- current repo `R/exal_static_LDVB.R:383-391`
- qdesn branch `R/exal_ldvb_engine.R:596-610`

Both paths use the same conceptual map:
- `gamma in (L, U)`
- `A(p0,gamma), B(p0,gamma), C(p0,gamma)`
- `lambda(gamma) = C(gamma) * |gamma|`

So the main discrepancy is not in the basic exAL constants.

### 2. The biggest VB discrepancy is the `xi` layer

Current repo:
- `R/exal_static_LDVB.R:468-558`
- `R/exal_static_LDVB.R:744-753`

This repo computes the `xi` quantities by Monte Carlo under the Gaussian LD approximation in `(eta, ell)`. It then damps those `xi` updates because they can move noisily.

qdesn branch:
- `R/exal_ldvb_engine.R:612-675`
- `R/exal_ldvb_engine.R:743-746`
- `R/exal_ldvb_engine.R:857-875`

That path uses a deterministic second-order Delta approximation. There is no per-iteration MC noise in the `xi` step.

Implication:
- qdesn is solving a quieter optimization problem.
- This repo's static VB needs damping, replicated draws, and trace auditing precisely because the `xi` layer is noisier.
- If qdesn exAL looks smoother or more stable, this discrepancy alone is enough to explain a large part of that behavior.

### 3. The qdesn LD optimizer is materially more constrained

Current repo:
- `R/exal_static_LDVB.R:589-646`
- `R/exal_static_LDVB.R:724-742`

This repo:
- searches a small candidate set
- runs unconstrained `BFGS`
- regularizes the recovered covariance
- damps the update afterwards
- caps the actual step in `eta` and `ell`

qdesn branch:
- `R/exal_ldvb_engine.R:65-77`
- `R/exal_ldvb_engine.R:705-731`

That engine:
- defines finite, data-scaled bounds for `sigma`
- defines fixed bounds for `eta`
- runs `L-BFGS-B` directly inside those bounds

Implication:
- qdesn is much less willing to explore extreme `sigma` or near-boundary `gamma`.
- The current repo lets the optimizer roam more freely and then tries to recover with damping/regularization.
- These are not equivalent stabilization strategies.

### 4. qdesn is more regularized on `beta` and often on `gamma`

Current repo:
- `R/exal_static_LDVB.R:356-357`
- `R/exal_static_LDVB.R:817-821`
- default `log_prior_gamma = function(g) 0` at `R/exal_static_LDVB.R:342`

This repo defaults to:
- a very diffuse Normal prior on `beta`
- a flat prior on `gamma`

qdesn branch:
- `R/exal_ldvb_fit.R:60-86`
- `R/priors_beta.R:21-132`
- `R/qdesn_model_selection_v2.R:45-55`
- `R/qdesn_model_selection_v2.R:61-90`
- `R/qdesn_vb.R:359-404`

That path can use:
- ridge shrinkage
- RHS shrinkage
- explicit Normal prior on `gamma`
- explicit sigma prior objects

Implication:
- qdesn has much stronger mechanisms to stop the readout from overusing `gamma`.
- If free `gamma` is the source of the bad static exAL behavior here, qdesn may be masking that by shrinkage.

### 5. qdesn uses a very different design geometry

Current repo:
- plain static regression on the supplied `X`

qdesn branch:
- `R/qdesn_vb.R:1-42`
- `R/qdesn_vb.R:330-405`

The qdesn readout is not a plain linear regression on raw covariates. It uses:
- deep reservoir features
- lag preprocessing
- washout
- optional input standardization
- optional observation weights
- optional state-noise immunization

Implication:
- even with the same exAL likelihood, the fitted posterior is not directly comparable
- qdesn may work well because the reservoir features linearize the target much better before the exAL readout is fit
- the current static exAL regression and qdesn readout are not apples-to-apples model comparisons

### 6. The qdesn branch static MCMC is not the stronger implementation

qdesn branch static MCMC:
- `R/exal_static_mcmc.R:241-245`

That branch updates `gamma` by:
- finding a local mode in `eta`
- drawing `eta ~ N(mode, info^{-1})`
- no MH correction

Current repo static MCMC:
- `R/exal_static_mcmc.R:94-100`
- `R/exal_static_mcmc.R:429-615`

This repo supports:
- `laplace_local` (approximate)
- `rw` (exact MH)
- `laplace_rw` (exact MH with Laplace-based scale)
- acceptance diagnostics
- adaptation history
- explicit `kernel_exact` / `signoff_ready`

Implication:
- if the user's confidence in qdesn exAL comes from the qdesn branch's VB behavior, that is coherent
- but it should not be interpreted as evidence that the qdesn branch has a superior static exAL MCMC implementation
- on the MCMC side, the current repo is actually the more rigorous implementation

### 7. qdesn diagnostics/reporting are less complete than this repo's current static audit framework

qdesn branch:
- `R/vb_diagnostics.R` is still a skeleton

Current repo:
- already has end-to-end plotting/postprocess/trace reporting around the static regression campaigns

Implication:
- qdesn may appear to "work well" partly because it is being judged on end predictions rather than on the same level of detailed convergence/diagnostic scrutiny used here

## Bottom-Line Interpretation

The most likely explanation is not:
- "qdesn proves this repo's static exAL regression should already behave the same"

The better explanation is:
- qdesn is using the same broad exAL family but under a different optimization problem
- a different regularization structure
- a different `xi` approximation
- and a very different feature design

So the current static exAL issue here cannot be dismissed by saying "qdesn exAL works."

Those are related models, but they are not the same fitted system.

## Highest-Value Discrepancies To Test Next

If the goal is to explain the gap empirically, the most informative experiments would be:

1. Port the qdesn-style deterministic Delta `xi` update into this repo's static exAL VB and compare against the current MC-based `xi` path.
2. Add qdesn-style bounded `L-BFGS-B` optimization for `(eta, ell)` in this repo and compare the LD traces directly.
3. Add a shrinkage prior on `gamma` here, matching the qdesn branch default interface, and test whether the exAL tail bias collapses back toward AL behavior.
4. Compare the same static dataset under:
   - current repo static exAL
   - current repo static exAL with qdesn-style `gamma` prior
   - current repo static exAL with deterministic `xi`
   - current repo static exAL with both changes

If those changes materially improve the static exAL fits here, then the discrepancy is mostly numerical/regularization-related rather than a difference in the core exAL likelihood.

## Audit Verdict

High-confidence verdict:

- The core exAL observational formulas do not appear to be the main discrepancy.
- The qdesn branch's successful exAL path is materially different from the static exAL regression path being stress-tested here.
- The most consequential differences are:
  - deterministic vs Monte Carlo `xi`
  - bounded vs effectively unbounded LD optimization geometry
  - stronger beta/gamma regularization
  - much richer feature design
- The qdesn branch's static MCMC is not the reason qdesn appears better; if anything, the current repo is stronger on MCMC rigor.

That means the next clean move is not another derivation audit. It is a controlled numerical-parity experiment against the qdesn LDVB engine choices.

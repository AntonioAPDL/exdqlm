# Paper vs QSpec DGP Audit

## Purpose

Compare the Yan-Kottas / `bqrgal-examples` simulation construction against the
current quantile-specific (`qspec`) simulation generators in this repo, and
determine whether the quantile-centering principle itself is wrong or whether
the important discrepancies are elsewhere in the benchmark design.

This note is intentionally limited to DGP construction. It does not launch or
analyze new model fits.

## Sources Reviewed

Paper-side code:
- `/data/muscat_data/jaguir26/bqrgal-examples/data-examples/simu_funcs.R`
- `/data/muscat_data/jaguir26/bqrgal-examples/data-examples/sim/simulate_data.R`
- `/data/muscat_data/jaguir26/bqrgal-examples/data-examples/sim/fit_gal_models.R`
- `/data/muscat_data/jaguir26/bqrgal-examples/data-examples/sim/evaluate_gal_out.R`

Current qspec-side code:
- `tools/merge_reports/20260308_quantile_specific_sim_helpers.R`
- `tools/merge_reports/20260306_generate_static_simple_linear_normal.R`
- `tools/merge_reports/20260308_generate_static_homoskedastic_shrinkage_gaussian.R`
- `tools/merge_reports/20260309_generate_static_paper_normal_dense_nonzero.R`
- `tools/merge_reports/20260308_generate_dynamic_dlm_quantile_specific.R`

## Main Finding

The quantile-centering principle in the current `qspec` generators is
conceptually correct and is consistent with the paper-side construction.

The main discrepancy is **not**:
- "we shifted the error incorrectly"

The main discrepancies are instead:
- benchmark geometry
- target-quantile regime
- error-family choice
- coefficient structure
- evaluation design

## Paper-Side Quantile Centering

The paper-side simulation code already uses quantile-specific data generation.

### Normal case

From `simGausQr()`:

- `mu0 <- -sigma * qnorm(p0)`
- `y = mu + N(mu0, sigma^2)`

This implies:

- `Q_p0(y | x) = mu + mu0 + sigma qnorm(p0) = mu`

So the paper is explicitly shifting the error so the target quantile is exactly
the regression signal.

### Laplace case

From `simLaplaceQr()`:

- the location shift `mu0` is chosen so the target quantile is zero before
  adding `mu`

So the same principle is used.

### Gaussian mixture case

From `simGausMixQr()`:

- the code solves for the mixture-location root that makes the target quantile
  zero

Again, same principle.

### Log-GPD case

From `simLogGPD()`:

- the scale is chosen so that after the log transform the target quantile is
  zero before adding `mu`

Again, same principle.

## Current QSpec Quantile Centering

The current `qspec` helpers and generators do the same thing in a different
form.

### Static normal qspec generators

Examples:
- `20260306_generate_static_simple_linear_normal.R`
- `20260308_generate_static_homoskedastic_shrinkage_gaussian.R`
- `20260309_generate_static_paper_normal_dense_nonzero.R`

Pattern:

- sample base noise `z_raw`
- compute `q_eps = qnorm(tau)`
- define shifted noise `z_shift = z_raw - q_eps`
- use `y = mu + sigma * z_shift`

This is equivalent to the paper-side normal construction because:

- `Q_tau(z_raw - qnorm(tau)) = 0`
- therefore `Q_tau(y | x) = mu`

So for the normal case, the qspec shift logic is not the source of the
scientific discrepancy.

### Dynamic normal qspec generator

Example:
- `20260308_generate_dynamic_dlm_quantile_specific.R`

Pattern:

- sample Gaussian innovations
- shift them by `qnorm(tau)`
- use `y_t = F_t' theta_t + eps_t*`

Again, this is the correct quantile-specific principle.

## What Is Actually Different

### 1. Target quantile regime

The paper emphasizes:
- `p0 = 0.05`
- `p0 = 0.25`
- `p0 = 0.50`

The strongest reported GAL advantages are in the lower tail, especially
`p0 = 0.05`.

Many of the earlier local validation runs here emphasized:
- `0.05`
- `0.50`
- `0.95`

The upper-tail `0.95` cases are not part of the paper's main simulation
benchmark, and they may stress very different behavior.

### 2. Covariate geometry

Paper normal benchmark:
- `p = 8`
- correlated Gaussian covariates
- covariance `Sigma_ij = 0.5^{|i-j|}`

Several earlier local benchmarks were much simpler:
- one-covariate designs
- custom high-dimensional shrinkage designs
- different signal geometry

That matters because the paper's exAL/GAL behavior is being demonstrated in a
specific multivariate lower-tail regression regime, not in an arbitrary simple
univariate benchmark.

### 3. Coefficient structure

Paper benchmark:
- sparse vector `(3, 1.5, 0, 0, 2, 0, 0, 0)`

Local benchmarks here included:
- single-covariate cases
- dense nonzero cases
- shrinkage benchmarks with strong/small/near-zero/zero groups

That changes both:
- what "better behavior" means
- how much asymmetry/flexibility is actually useful

### 4. Error families

The paper benchmark includes four families:
- normal
- Laplace
- Gaussian mixture
- log-GPD

Earlier local qspec runs here focused heavily on:
- Gaussian
- skew-normal
- heteroskedastic skew-normal
- exAL-generated benchmarks

So some of the local DGPs are simply different scientific questions.

### 5. Replication-based evaluation

Paper benchmark:
- many train/test replications
- aggregate metrics across replications

Earlier local work here often used:
- one large dataset per scenario
- detailed fit diagnostics and truth-vs-fit plots

Those are complementary, but not equivalent validation designs.

## Practical Conclusion

For the normal qspec generators, the current quantile-centering logic is not
the main problem.

The stronger explanation for why the paper often shows `exAL` behaving better is:

1. the paper focuses on lower-tail targets
2. it uses specific correlated multivariate designs
3. it evaluates on DGP families where GAL/exAL flexibility is more relevant
4. it aggregates over replicated train/test splits

This is consistent with the local result already obtained on the paper-style
dense lower-tail normal benchmark:

- once the static `exAL VB` LD-block bug was fixed, both `VB` and `MCMC`
  favored `exAL` over `AL`

That strongly suggests the earlier poor exAL behavior in some local runs was
not caused by the quantile-shift principle itself.

## What This Means For The Next Generator Fixes

The next generator work should focus on benchmark fidelity, not on replacing the
basic qspec centering principle.

Priority changes:

1. Add paper-faithful static qspec generators for:
   - normal
   - Laplace
   - Gaussian mixture
   - log-GPD
   with `p0 in {0.05, 0.25, 0.50}`

2. Keep the current qspec centering principle for these generators.

3. Treat the earlier skew-normal / heteroskedastic qspec families as separate
   custom validation regimes, not as direct reproductions of the Yan-Kottas
   simulation study.

4. For dynamic validation, define a separate dynamic benchmark family instead of
   trying to force a direct one-to-one paper reproduction where no paper-side
   dynamic analogue exists.

## Decision

Do not rerun the full validation grid yet.

First:
- revise the remaining static qspec generators so the benchmark families are
  aligned with the intended scientific questions
- then rerun the static and dynamic validation grid on that corrected design

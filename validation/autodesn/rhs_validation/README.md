# Independent AutoDESN RHS validation

These checks target the normalized Piironen–Vehtari regularized horseshoe
(`beta_prior = "rhs"`). They do not test or reinterpret the package's separate
`rhs_ns` family.

`oracle.R` contains independent numerical references. It constructs the dense
observation covariance

\[
C_m=\sigma^2 I+X_m\operatorname{diag}(v_0,v_{m1},\ldots,v_{md_m})X_m^T,
\qquad
v_{mj}^{-1}=c^{-2}+(\tau_{0m}u\lambda_j)^{-2},
\]

and evaluates its Gaussian density directly. It does not call the production
coefficient-space density, local rejection sampler, or scale log target.

## Run

For an installed checkout:

```bash
Rscript validation/autodesn/rhs_validation/run_validation.R \
  --output-dir=/data/autodesn_rhs_oracles --backend=cpp
```

For source-level validation, with the R package dependencies and a working
C++ toolchain available:

```bash
Rscript validation/autodesn/rhs_validation/run_validation.R \
  --source-repo=/path/to/exdqlm \
  --output-dir=/data/autodesn_rhs_oracles \
  --backend=cpp --burn=2000 --draws=20000
```

The source workflow explicitly sources the checkout and compiles
`src/autodesn_rhs.cpp`. Use `--backend=r` for the independent R implementation.
The script exits with nonzero status if a reference check fails.

To refine a numerical reference without regenerating retained MCMC draws,
add `--reuse-chains=/absolute/path/to/oracle_chains.rds`. Reuse is explicit;
the driver verifies each bank's data, feature matrices, model prior, RHS
controls, model kernel, starting model, seed, backend, burn-in, and draw
count before using a saved chain. A normal invocation always samples fresh
chains. The result records the reused file path.

## Reference experiments

1. **Frozen shrinkage scales:** a bank with zero, one, and two slope features
   and different per-model `tau0` values. Integrate the observation variance
   to obtain marginal model probabilities. Compare independent categorical
   and Metropolis architecture chains with those probabilities and with the
   posterior mean of the observation variance.
2. **Learned local scales:** a two-model bank with one slope per model, fixed
   global/slab scales, and a learned local scale. Integrate both the local
   scale and observation variance. Compare model probabilities, observation
   variance, and the posterior expectation of the local prior CDF. This
   distinguishes the normalized RHS target from an incorrect horseshoe
   update that omits the RHS Gaussian variance normalizer.
3. **Uninformative slope designs:** zero-valued features with different
   dimensions. Every architecture has the same likelihood, so its posterior
   mass equals its supplied prior mass. The local, global, and slab marginal
   posteriors must equal their proper priors. Their prior CDFs therefore have
   mean `1/2` and second moment `1/3`. These bounded statistics remain useful
   even when a scale prior has no finite ordinary mean or variance.

The quadrature uses Gauss–Legendre nodes on `(0, 1)` after normalized prior
quantile transformations:

\[
\sigma^2=b_\sigma/F_{\Gamma(a_\sigma,1)}^{-1}(U),
\qquad \lambda=\tan(\pi U/2).
\]

No finite scale cutoff is introduced. Increasing the integration order
independently checks quadrature accuracy: the frozen-scale experiment uses
orders 384 and 768, and the learned-local experiment uses tensor-product
orders 320 and 640. The maximum change in model probability must be below
`1e-5`; the change in posterior mean observation variance must be below
`1e-4`. These gates are checked separately from MCMC agreement.
Posterior comparisons use six
batch-means Monte Carlo standard errors, a small absolute numerical floor,
and the observed quadrature-order difference. A pass indicates agreement
within the stated numerical uncertainty; it is not a proof of convergence
for every data set or architecture bank.

## Outputs

- `posterior_reference_checks.csv`: estimate, reference, numerical error,
  batch-means MCSE, tolerance, and pass flag for each comparison.
- `quadrature_convergence.csv`: changes when the integration order increases.
- `*_parameter_diagnostics.csv` and `*_model_diagnostics.csv`: separate
  continuous-parameter and architecture diagnostics for the two kernels.
- `oracle_validation.rds`: references, checks, diagnostics, runtime, and
  session metadata.
- `oracle_chains.rds`: retained draws used to compute the checks.
- `session_info.txt`: the actual R/package environment.

The regular test suite additionally checks rank-deficient and wider-than-data
designs, Gaussian coefficient covariance orientation, transformed scale
Jacobians, the local rejection distribution, RNG preservation, R/C++ parity,
recursive forecast causality, and rejection of mismatched diagnostic targets.

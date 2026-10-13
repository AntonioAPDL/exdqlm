# Independent Gaussian-mixture Q-DESN conditioning campaign v7

## Decision basis

The completed v6 campaign established that additional training data resolves or
substantially improves the lower-tail Normal/exAL and Laplace/exAL controls, but
not Gaussian-mixture/AL at `p = 0.05`. Its matched MCMC forecast-MAE ratio was
1.468 relative to DQLM. The result repeated across folds and chains, while check
loss was nearly tied. Rolling readout updates improved VB MAE by only about one
percent. Large 900--2,400-state designs had excellent oracle representation in
some cases but unstable estimated readouts. These facts localize the remaining
problem to stable estimation of a sufficiently expressive readout rather than
MCMC mixing, stale coefficients, or a general failure of Q-DESN.

## Scientific target and invariants

This campaign targets only Gaussian-mixture/AL at `p = 0.05`, with a 2,000-row
training window and the four frozen internal folds from v6. Normal and Laplace
are not recomputed. Their resolved v6 results remain controls. The article
holdout at source indices 9,001--10,000 remains unopened.

The fixed contract retains:

- teacher forcing when the forecast origin advances;
- recursive 30-step forecasting within each origin;
- intercept plus all reservoir layers in the readout;
- exact identity layer projections, with no dimension reduction;
- tanh reservoir recurrence and identity lower-layer readout activation;
- matrix seed 920001 and one numerical thread per worker;
- RHS-NS shrinkage with an unshrunk intercept;
- CRAN exdqlm 1.1.2 and AL with gamma fixed;
- forecast MAE as the primary selection criterion and check loss as a tie-breaker.

## Intervention

The causal intervention is fold-local readout conditioning. In the conditioned
arm, every non-intercept reservoir column is centered and scaled using only the
training fold. The same frozen transformation is applied to all recursive
forecast states. The unconditioned arm reproduces the v6 coordinate system.
This intervention changes coefficient-prior comparability and numerical
conditioning without changing the reservoir state map or leaking validation
information.

The architecture panel has 48 structures: four stable v6 anchors and 44
deterministic Halton proposals. New designs cover depths 3--6, 250--600 total
states, 240--500 output lags, alpha 0.04--0.60, rho 0.97--0.9995, broad input
gain and fan-in values, and mean/SD or median/MAD lag preprocessing. Exact
historical repeats are excluded using a frozen ledger built from the v6 parent
bank and all tracked promotion tables carrying structure identities. The four
declared v6 anchors are the only intentional repeats. This fills the untested
middle-capacity region between stable 143--414-state designs and unstable
900-plus-state designs.

## Gated execution

1. **Smoke** runs matched raw and conditioned AL-VB jobs and enforces exact
   first-step recursive prediction identities.
2. **Representation** evaluates all 48 structures on folds S1 and S3 using
   oracle-quantile and Gaussian ridge readouts. Candidates with nonfinite or
   unstable recursive behavior are rejected before Bayesian fitting.
3. **Quantile screen** sends 12 structures to direct AL-VB, crossing raw versus
   conditioned readouts, tau multipliers 0.5, 1, 2, and 3, and folds S1/S3.
4. **Validation** evaluates four finalists on all four internal folds. Selection
   uses mean forecast MAE, worst-fold behavior, and check loss. A matched
   conditioning counterfactual is retained even if it is not among the top
   three configurations.
5. **MCMC** confirms two finalists with three chains on folds S2 and S4, using
   each fold's exact VB initializer. Frozen v6 DQLM chains are hash-verified and
   reused as the unchanged comparator.
6. **Closeout** recommends a full 18-cell confirmation only if the best matched
   MCMC Q-DESN/DQLM forecast-MAE ratio is at most 1.10. Otherwise the persistent
   Gaussian-mixture limitation is reported and open-ended screening stops.

## Reproducibility and storage

All code, configurations, sources, package files, parent evidence, plans, and
result packets are SHA-256 manifested. Runtime outputs contain compressed CSV
and JSON only; fitted model binaries are prohibited. The scheduler pins one R
process to each of at most 30 physical cores, forces all numerical libraries to
one thread, stops new scheduling below 128 GiB available memory, and supports a
clean drain through `STOP_NEW_SCHEDULING`. Structure-defining floating-point
parameters are frozen to 14 significant digits before hashing so candidate
identities survive an exact JSON write/read transition. This campaign cannot
update article files or Overleaf directly.

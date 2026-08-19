# Post-M0 forecast-first promotion protocol

## Decision scope

This closeout applies only to the independent single-quantile validation cell
`exal_gausmix_t0p25` under MCMC, regularized horseshoe shrinkage, and exact
exAL method `M0_v_collapsed_support_logit`. It does not alter package defaults,
other validation cells, joint-QDESN work, applications, or article sources.

The frozen comparator is the 72-row v6 article interface. Forecast MAE is the
primary selection and promotion metric. Forecast check loss is a secondary
forecast metric and is promoted independently when its arithmetic mean over
the same three canonical chains is strictly lower than v6. Fit RMSE remains
unchanged unless it independently improves; it is not traded against forecast
performance.

## Evidence contract

The canonical confirmation uses one fixed candidate, the canonical article
source and reservoir seed, and three independent chains. Each chain uses 5,000
burn-in iterations and 20,000 retained MCMC iterations, with one worker thread.
Execution success, finite metrics, exact source/configuration hashes, exact M0,
and storage-light retention are hard gates.

Mixing diagnostics are retained in full as descriptive evidence. PASS, WARN, or
FAIL grades do not veto a strict forecast improvement. This policy supports a
metric-envelope simulation comparison; it does not authorize posterior
uncertainty or convergence claims from a diagnostically weak chain.

## Promotion and integration

The immutable v7 package inherits all v6 rows and metric sources. It may change
only Gaussian-mixture, p=0.25, exQ-DESN RHS MCMC forecast MAE and forecast check
loss, each to the arithmetic mean of the three canonical chains. Fit RMSE and
all other 214 numeric roles remain byte-for-byte or numerically unchanged.

The promotion package freezes compact CSV/JSON evidence, hashes every source,
and contains no `.rds`, `.rda`, or `.RData` payload. This scientific lane does
not edit the article repository. The integration lane must verify the frozen
handoff, regenerate the independent-validation table from v7, compile the
article and supplement, and publish the article-only Overleaf snapshot.

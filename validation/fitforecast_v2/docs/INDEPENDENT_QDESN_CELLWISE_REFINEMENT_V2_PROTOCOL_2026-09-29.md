# Independent Q-DESN cellwise representation refinement v2

## Purpose

The campaign targets the remaining independent single-quantile Q-DESN
underperformance without repeating the earlier family-level funnel. The frozen
v1 ridge stage completed 960/960 jobs and showed that long memory and deeper,
larger identity-Q reservoirs are promising for Normal and Laplace, while the
Gaussian-mixture family requires both compact and long/deep candidate pools.

The successor is not a restart. It imports the hashed v1 evidence, adds only 80
new family-targeted structures, and evaluates all later decisions separately by
family, target quantile, and working likelihood. The DQLM and exDQLM comparator
fits remain frozen.

## Audit conclusion

The completed v1 ridge stage is valid evidence, not a failed experiment. Its
960 scheduler jobs produced 11,520 finite fold-by-scale fits without a worker
failure. It established three facts that materially change the next stage:

1. Normal and Laplace favor longer response memory and generally deeper,
   higher-capacity identity-Q reservoirs than the earlier authority explored.
2. Gaussian mixture does not support one monotone capacity rule: competitive
   candidates occur in both compact and long/deep regions.
3. Historical VB rank transfer to MCMC is weak enough that a forecast winner
   under VB cannot be the only route into MCMC.

Resuming the original v1 funnel would therefore discard useful evidence at the
first collector boundary and repeat a scientifically weak global narrowing
rule. Starting another independent broad random screen would repeat thousands
of signatures without using the completed folds. The adopted design is the
smallest defensible bridge between those alternatives: preserve all frozen v1
elites, add targeted boundary probes, tune RHS locally per structure, and carry
cell-specific diversity into direct MCMC.

## Why the stage graph changed

Historical Normal and quantile-VB rankings were weak and sometimes negative
proxies for final MCMC ranking. Consequently, VB narrows the field but cannot
be the sole MCMC gate. Each unresolved cell receives a deliberately diverse
direct-MCMC pilot containing forecast leaders, fit leaders, robust-fold
leaders, imported anchors, and novel structures.

The already competitive Laplace--AL cell at `p=0.05` is protected. It receives
incidental VB evidence when a family candidate is fitted jointly across the
nested quantile sequence, but no broad MCMC allocation.

## Fixed scientific contract

- Families: Normal, Laplace, and Gaussian mixture.
- Target levels: 0.05, 0.25, and 0.50.
- Teacher forcing between origins and recursive forecasting within each
  30-step horizon.
- Readout: intercept plus every current reservoir layer; no direct response,
  exogenous, or reservoir lags.
- Reservoir activation: `tanh`; lower-state readout transforms: identity.
- Every `Q_d` is exactly the identity; dimensionality reduction is forbidden.
- One fixed matrix seed isolates architecture and prior-scale effects.
- exAL MCMC uses the exdqlm 1.1.1 M0 collapsed-slice transition.
- Selection uses only two blocked folds inside 8501--9000. The article holdout
  9001--10000 is first accessed by the sealed confirmation stage.

## Candidate bank

The bank has 220 structures: 140 frozen v1 elites and 80 unseen targeted
structures. Normal emphasizes depths 3--4, 400--2,200 states, and lags
240--360. Laplace emphasizes depths 3--4, 600--2,400 states, and lags
240--360. Limited depth-2 and depth-5 probes test boundaries. Gaussian mixture
uses a bimodal bank: compact 20--200-state maps with lags 90--180 and long/deep
600--2,000-state maps with lags 180--360. Alpha and rho remain broad because v1
did not support a monotone narrow range.

The 390-observation frozen source prefix permits `m=360` while retaining a
30-observation safety margin. `m=390` is forbidden.

## Stage graph

1. **Targeted ridge:** evaluate only the 80 unseen structures over eight ridge
   scales and two blocked folds.
2. **RHS bridge:** evaluate all 220 structures over seven coarse `tau0` values,
   then evaluate the winning value and its clipped one-third/threefold
   neighbors for each structure.
3. **Quantile bridge:** advance 36 Normal, 24 Laplace, and 36 Gaussian-mixture
   candidates. Each job fits nested 0.50, 0.25, and 0.05 AL and exAL models on
   both folds.
4. **Adaptive quantile refinement:** use bridge cell winners to select 24
   additional Normal, 16 Laplace, and 24 Gaussian-mixture candidates from the
   remaining RHS bank. Full nested jobs share reservoir construction across
   cells and are more efficient than duplicated cell jobs.
5. **Direct MCMC pilot:** ten diverse candidates in each of the 17 unresolved
   cells receive one short chain.
6. **Replication:** the best three candidates per unresolved cell receive two
   additional chains.
7. **Sealed confirmation:** one candidate per unresolved cell receives three
   full chains on 971 origins, with path-recursive and mean-state-recursive
   estimators.

The complete maximum is 1,003 scheduler jobs. All workers are process-parallel
and single-threaded, with atomic status and hash-verified outputs.

Each of the 15 workers is pinned to one distinct audited CPU. The pipeline is
stage-resumable: a successful result with a matching status record is skipped,
while missing, failed, or hash-invalid work remains pending. Every expensive
stage first runs a production canary; MCMC stages require separate AL and exAL
canaries. Materialization is permitted only from a clean branch exactly
synchronized with its upstream, and each worker verifies the frozen Git HEAD,
protocol hash, source hashes, and exdqlm 1.1.1 source version before fitting.
The 102-row current-authority ledger is vendored with the protocol and
SHA-256-pinned, so closeout does not depend on an older ignored run directory.

The run remains storage-light. It retains score ledgers, posterior metric
draws, and confirmation origin-by-lead summaries, but no fitted-model binary.
Closeout is forbidden until all eight stage plans are complete and valid. The
closeout then emits an artifact hash manifest, storage audit, authority
comparison, and integration handoff inside the ignored run root.

## Decisions and stopping rule

Forecast oracle-quantile MAE is primary, forecast check loss is secondary, and
fit oracle-quantile RMSE diagnoses center recovery. Diagnostic grades are
reported but do not veto a finite strict gain. Nonfinite metrics, leakage,
contract violations, and corrupted artifacts remain hard failures.

Every strict fully confirmed per-cell forecast improvement is eligible for
integration review. Comparator ratios at or below 1.05 indicate parity/win;
1.05--1.15 indicates near parity; 1.15--1.50 is improved but unresolved. If a
cell remains above 1.50 with center miss after this campaign, broad
hyperparameter screening stops. The next action must be an explicitly separate
model/readout/recursive-dynamics study rather than another larger grid.

No partial stage may update Article-v2, shared validation, or Overleaf.

## Explicit non-goals

- Do not refit DQLM or exDQLM during this campaign.
- Do not seek one architecture or `tau0` that wins globally.
- Do not use the article holdout for ridge, RHS, VB, or pilot selection.
- Do not reject a finite forecast gain solely because a diagnostic grade is
  imperfect; disclose it instead.
- Do not continue broad screening after a fully confirmed cell remains more
  than 1.5 times its frozen comparator with a persistent center miss.
- Do not promote runtime output directly. A separate frozen promotion commit
  and coordinator review are required after scientific closeout.

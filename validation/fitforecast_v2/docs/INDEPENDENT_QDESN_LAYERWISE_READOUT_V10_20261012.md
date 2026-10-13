# Independent Q-DESN Layerwise Readout Rescue v10

## Decision Context

V9 completed 71 of 71 jobs without failure. Its strongest global RHS arm,
tau multiplier 2 with slab multiplier 0.5, improved mean forecast MAE to
3.1124 versus DQLM's 3.1365. It did not solve the uncertainty target: the
forecast-MAE score interval width was 2.1103 versus 0.4679 for DQLM and was
slightly wider than the independently run V8 width of 2.0857.

The retained-draw attribution localizes the remaining spread:

| Readout block | Mean first-step SD | Mean covariance share |
|---|---:|---:|
| Intercept | 0.333 | 0.019 |
| Layer 1 | 7.167 | 0.745 |
| Layer 2 | 6.836 | 0.205 |
| Layer 3 | 5.464 | 0.031 |

The nonintercept coefficient covariance is not sufficiently low-rank for an
ad hoc projection: approximately 24, 82, 125, and 162 directions are required
for 50%, 80%, 90%, and 95% of its variance. V8 also showed that shared
recursive states and zero process noise do not contract the score interval.
The next justified intervention is therefore relative Layer 1/Layer 2 readout
regularization, not another global tau screen, intercept shrinkage, state
averaging, or posterior projection.

## Mathematical Intervention

After training-fold-only z-scoring, let `X` be the readout and let `G` be a
diagonal matrix whose Layer 1 and Layer 2 entries are `g1` and `g2`; intercept
and Layer 3 entries are one. V10 fits

```text
y = X G theta + error
```

under the unchanged common RHS-NS prior for `theta`. In the original readout
coordinates `beta = G theta`, so `g < 1` imposes a proportionally smaller
prior scale on that layer's original coefficients. This is a transparent
study-local group regularization device. It does not modify exdqlm, the
reservoir, the identity Q transitions, the data, or the forecasting protocol.

The same `G` is applied to the training matrix, every stored teacher-forced
design row, and every recursively generated forecast readout. First-step
prediction equality is checked at every forecast origin. This prevents a
fit/forecast transformation mismatch.

## Frozen Contract

- Sentinel: Gaussian-mixture, AL, `p = 0.05`.
- Training: 2,000 observations after the 500-observation washout.
- Architecture: fixed V7 winner, `D = 3`, `n = (141,119,90)`, `m = 360`.
- Reservoir: fixed seeds, sparsity, weight distributions, input scaling,
  activation functions, leakage, spectral radius, and identity Q matrices.
- Readout: unshrunk intercept plus every reservoir layer; no raw inputs.
- Base prior: fixed V9 best, tau multiplier 2 and slab multiplier 0.5.
- Selection folds: S1 and S3.
- Confirmation folds: S2 and S4.
- Article holdout: source indices 9001--10000 remain unopened.
- Forecasting: teacher forcing between origins and recursive 30-step paths
  within each origin.
- Software: CRAN exdqlm 1.1.2 under R 4.6.0.
- Storage: evidence tables only; fitted-model binaries are forbidden.

## Candidate Design

The Layer 1 and Layer 2 scale universe is

```text
0.25, 0.40, 0.55, 0.70, 0.85, 1.00.
```

Twelve of the 36 combinations are selected deterministically by maximin
coverage on the log-scale plane. The unmodified `(1,1)` anchor and the
mechanism-relevant `(0.4,0.7)`, `(0.55,0.55)`, and `(0.7,0.85)` arms are
forced. Layer 3 and the intercept always remain at one. The lower bound 0.25
represents a fourfold prior-scale contraction, or a sixteenfold Gaussian
precision change before local RHS adaptation; still smaller values would be
an unjustified near-deletion of a layer.

This design is intentionally not crossed with tau or slab. V9 already
identified the best global prior, and a 12 by 32 factorial would obscure the
mechanism and repeat completed work.

## Stages

| Stage | Jobs | Purpose | Budget |
|---|---:|---|---|
| Smoke | 1 | Verify block mapping, warm path, recursion, hashes | 20 burn + 40 retained |
| Warm | 24 | VB initializers for 12 arms on S1/S3 | 800 iterations |
| Discovery | 24 | Direct MCMC screen on S1/S3 | 1,500 burn + 5,000 retained |
| Confirm warm | 6 | Initializers for anchor and two interventions on S2/S4 | 1,000 iterations |
| Confirmation | 18 | 3 arms x 2 folds x 3 chains | 3,000 burn + 10,000 retained |

At most 30 models run concurrently. Each model is pinned to one physical core,
and every numerical-library thread count is one.

## Selection and Confirmation

Discovery first requires mean MAE no more than 1.10 times DQLM and worst-fold
MAE no more than 1.20 times DQLM. Eligible interventions are ranked primarily
by forecast-MAE score interval width, then interval score and mean MAE. The
concurrent `(1,1)` anchor and the two best non-anchor interventions advance.

A strict confirmed gain requires all of:

1. mean MAE no more than 1.05 times DQLM;
2. worst-fold MAE no more than 1.20 times DQLM;
3. mean MAE no more than 2% above the V9 best;
4. interval width strictly below both V9 and the concurrent anchor;
5. check loss no more than 2% above V9;
6. interval score no more than 2% above V9.

A meaningful contraction additionally requires at least a 10% width reduction
from V9. Full closure requires at least half of the original V7-to-DQLM excess
width gap to be removed. Every strict gain remains recorded even when it does
not meet the practical 10% target.

## Stop Rules and Scientific Boundary

- Full closure supports a later cellwise propagation campaign.
- A meaningful but incomplete contraction is retained for fresh-DGP testing.
- A smaller strict gain is retained, but does not justify another local rescue
  iteration.
- No strict gain stops targeted readout rescue. The next step would be a
  separately frozen model redesign or fresh-DGP evaluation, not dynamic
  appendage to this campaign.

V10 cannot update Article-v2, shared validation, integration branches, or
Overleaf. Its holdout is unopened and its outputs are diagnostic until a later
scientific lane and integration decision authorize broader confirmation.

Every source, package file, parent artifact, configuration, plan, and retained
result is SHA-256 hashed. The scheduler fails closed, supports
`STOP_NEW_SCHEDULING`, pins one worker per physical core, and advances only
after every job in the preceding frozen stage succeeds.

If an orchestration-only defect is discovered after a stage has completed,
recovery must verify every completed evidence manifest, preserve the original
source and frozen manifests, record the original and recovery commits, update
the source-hash epoch, and rerun zero scientific jobs. The dedicated
`recover-screening-baseline` command implements that fail-closed transition
for the S1/S3 DQLM source-stage lookup corrected during this campaign.

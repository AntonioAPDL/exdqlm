# Independent Q-DESN Dynamic-Location Capacity by tau0 Campaign V1

## Purpose and scope

This protocol governs an independent, single-quantile Q-DESN validation
campaign. It tests whether case-specific DESN capacity and regularized
horseshoe scale interact to improve posterior point forecasts in the four
largest remaining Normal-family forecast gaps. It does not modify DQLM,
exDQLM, joint-QDESN, PriceFM, GloFAS, the article repository, or any active job
outside this lane.

The campaign is motivated by the frozen origin-horizon and common-shift audits.
Those audits show that posterior forecast-metric dispersion in the Normal
lower tail is driven primarily by coherent dynamic-location movement, not by
independent lead-level noise. Previous broad screens changed capacity,
dynamics, memory, and `tau0` together. This matched factorial experiment holds
each architecture fixed while crossing a cell-specific `tau0` ladder.

## Frozen authorities

The materializer verifies these files byte-for-byte before producing a job:

| Authority | Role |
|---|---|
| v9 point interface | Current metric-specific article-facing point estimates |
| v9 remaining-gap ledger | Current Q-DESN versus DQLM/exDQLM gaps |
| v10 metric intervals | Current posterior draw-metric interval authority |
| v9 canonical source registry | Source trajectories and canonical source hash |

Their expected SHA-256 values are embedded in
`independent_dynamic_location_capacity_tau0_v1.R`. Every exact parent request
also has a frozen hash in the target-cell configuration.

The historical canonical registry stores indices 8111--10000, which is not
enough prehistory for the frozen `washout=450` parent. The campaign therefore
uses the original 10,000-row master source registered in
`..._full_source_registry.csv`. Materialization verifies its full-file hash and
then proves that rows 8111--10000 reproduce every shared column of the frozen
canonical source to `1e-12`. This restores the full 500-row fit estimand without
changing observations 8501--10000 or regenerating the DGP.

## Evaluation contract

- Training indices: 8501 through 9000, 500 observations.
- Forecast indices: 9001 through 10000, 1,000 unique targets.
- Forecast origins: 9000, 9030, ..., 9990.
- Leads: 1 through 30; origin stride: 30.
- Primary selection estimand: point forecast oracle-path MAE.
- Independent secondary estimand: realized-observation forecast check loss.
- Supporting estimands: fit oracle-path RMSE, posterior draw-metric intervals,
  location/shape attribution, design conditioning, RHS traces, and sampler
  diagnostics.
- Reconstruction tolerance: absolute error at most `1e-6`.
- exAL transition: exact `m0_v_collapsed_support_logit`.
- AL transition: `sigma_then_gamma`.
- Preprocessing: training-origin scoped.
- Posterior recycling as a prior: prohibited.

Diagnostic grades are descriptive and do not exclude a finite metric. An
execution failure, nonfinite metric, source mismatch, incomplete diagnostic
surface, or estimator-contract violation does exclude a job.

## Tier-A design

The four cells are AL and exAL at Normal `p=0.05` and `p=0.50`. Each cell has
four architecture roles:

1. `P0_parent`: exact current metric source, crossed over the tau0 ladder.
2. `P1_compact_persistent`: compact memory with moderate persistence.
3. `P2_multiscale_moderate`: a two-layer design with moderate multiscale
   dynamics.
4. `P3_deep_selective`: a controlled three-layer high-persistence boundary.

Each architecture is crossed with four case-specific `tau0` values. This gives
16 candidates per cell and 64 discovery jobs. The exact values are tracked in:

- `..._target_cells.csv`
- `..._architecture_profiles.csv`
- `..._tau0_ladder.csv`

The hard effective-readout cap is 400, below 0.8 times the 500-observation
training size. Every recurrent and input topology probability must be positive.
At least one design in every cell has `alpha >= 0.70` and `rho >= 0.90`, while a
compact moderate-persistence alternative is retained.

## Execution stages

### Static materialization

The materializer rebuilds a typed history inventory from tracked candidate,
signature, resolved-configuration, and frozen JSON records. It writes:

- authority and parent hash audits;
- candidate and tau0 ledgers;
- history inventory and typed signatures;
- exact nonrepeat and nearest-history audits;
- source and source-window registries;
- static topology/capacity diagnostics;
- two smoke configs and 64 discovery configs.

Only declared P0 matched controls may repeat a historical design. Any
undeclared exact repeat fails materialization.

### Boundary smoke

One AL and one exact-M0 exAL `P3` job run at `tau0=1e-9`. These are execution
tests only. Both must produce finite metrics, complete compact diagnostic
artifacts, reconstruction error below `1e-6`, zero fitted-model binaries, and
successful resume semantics before discovery starts.

### Direct-MCMC discovery

The 64 candidates use 1,000 burn-in and 4,000 retained iterations, one
deterministic reservoir panel, one process per CPU, and no more than 20
concurrent workers. The launcher identifies currently low-use CPUs and creates
one persistent worker queue per selected CPU so two jobs cannot overlap on the
same assigned core. BLAS/OpenMP worker counts are fixed to one.

Every successful job retains compact CSV/JSON evidence only:

- point fit and forecast summaries;
- lead-level and rolling-origin summaries;
- posterior draw-specific metric summaries and equal-tailed 95% intervals;
- origin/lead attribution and exact reconstruction audit;
- common-shift and oracle-location diagnostic contrasts;
- design rank, conditioning, correlation, transport, and saturation summaries;
- RHS and sampler summaries;
- hashes, status, timing, and retention manifests.

The oracle-location correction is non-deployable diagnostic evidence and can
never be promoted as performance.

## Advancement and promotion

Discovery ranks forecast MAE and forecast check loss independently within each
cell. The closeout retains:

- all exact P0 controls;
- the two best candidates for each forecast metric;
- every additional strict point-metric improvement.

A common specification across cells or metrics is neither required nor
desired. Later matched replication uses a second reservoir panel and at least
two sampler chains. Only strict point improvements then receive three-chain,
5,000 plus 20,000 iteration canonical confirmation.

Promotion is metric-specific. Any finite confirmed reduction beyond the
`1e-6` numerical tolerance may be promoted, however small. Posterior interval
width alone is not a promotion estimand. Newly promoted metric sources must
regenerate their own posterior metric intervals and provenance packet.

If no Tier-A candidate improves a point forecast metric and common-shift
dominance remains, capacity-by-`tau0` tuning stops. The next experiment is an
orthogonalized deterministic-versus-reservoir readout, not another broad
capacity screen.

## Storage and integration

Full fits and posterior path arrays are transient. Successful terminal jobs
must contain no `.rds`, `.rda`, or `.RData` files. Compact evidence is hashed.
No article update is automatic. After full confirmation, this scientific lane
must freeze a clean integration handoff; the article integration coordinator
alone merges eligible results and publishes the article/Overleaf snapshot.

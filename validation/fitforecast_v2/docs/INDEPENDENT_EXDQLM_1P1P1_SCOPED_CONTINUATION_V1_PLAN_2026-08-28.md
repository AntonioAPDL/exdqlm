# Independent exDQLM 1.1.1 scoped continuation

## Decision and correction

The full four-model compatibility campaign is superseded for execution. It was
derived from the optional full-table rerun in the original handoff, but it is
not required to answer the scientific question: how the exdqlm 1.1.1
scale-skewness changes affect the independent exDQLM rows.

The interrupted parent campaign is retained as immutable evidence:

`independent_qdesn_exdqlm_1p1p1_rerun_v1_20260828_000419`

At interruption, 18 VB jobs had succeeded, 16 Q-DESN VB status files were
nonterminal, 164 jobs had not started, and no MCMC job had started. The
pipeline's `FAIL exit=2` marker records the deliberate interruption and is not
a scientific failure.

## Scientific diagnosis

exdqlm 1.1.1 directly changes unrestricted exAL inference:

1. exDQLM MCMC now uses the exact-target `collapsed_slice` update for gamma
   after integrating out sigma and then redraws sigma from its conditional GIG
   distribution.
2. exDQLM LDVB now uses structured `q(gamma) q(sigma | gamma)` with a 151-node
   bounded-logit grid.
3. compiled stochastic helpers use serial R-controlled RNG streams.

DQLM fixes gamma at zero and bypasses the scale-skewness block. The nine DQLM
VB controls completed before interruption and reproduced all 27 frozen point
metrics exactly. This verifies the source, clock, model, and scoring contracts
without justifying a DQLM production rerun.

Q-DESN AL and exAL use separate explicit inference paths. In particular,
Q-DESN exAL MCMC already uses `m0_v_collapsed_support_logit`, not the exDQLM
default transition. Shared RNG helpers can alter fixed-seed trajectories, but
that is a reproducibility sensitivity rather than a new Q-DESN posterior
target. The pinned Q-DESN authority therefore remains valid.

## Frozen scoped contract

| Dimension | Contract |
|---|---:|
| Model | exDQLM only |
| Families | Gaussian, Laplace, Gaussian mixture |
| Quantiles | 0.05, 0.25, 0.50 |
| VB jobs | 9 |
| MCMC jobs | 27: 9 cells x 3 chains |
| Total jobs | 36 |
| Source identities | 18 |
| Article metric roles | 54 |
| Training indices | 8501--9000 |
| Forecast indices | 9001--10000 |
| Forecast grid | origins every 30, leads 1--30 |
| MCMC budget | 5,000 burn-in + 20,000 retained iterations |
| Metric draws | VB 10,000; MCMC 4,000 per chain |
| Numerical threads | one per worker |
| Maximum concurrent workers | 16 |

The scope removes 135 unnecessary MCMC jobs relative to the 198-job parent
plan, an 83.3% reduction.

## Evidence reuse

The nine exDQLM VB jobs are reused rather than recomputed. Reuse is permitted
only because every imported status satisfies all of the following:

- terminal `SUCCESS` status;
- exact config hash match;
- exact metric-draw, interval-summary, interval-manifest, and inference-
  diagnostic hashes;
- 10,000 retained metric draws;
- structured scale-skewness factorization;
- no fitted-model binary payloads.

The continuation copies only the compact status evidence into its own state
root. It references the immutable parent configs and result artifacts. The
parent plan and materialization manifest hashes are recorded in the scoped
manifest.

## Execution guards

Before CPU launch, verification must establish:

1. exactly 36 jobs and 18 source identities;
2. every job has `engine=dqlm`, `model_variant=exdqlm`, and unrestricted gamma;
3. all nine family-quantile cells exist once for VB and three times for MCMC;
4. VB requests structured factorization and a 151-node grid;
5. MCMC requests `collapsed_slice`, 5,000 burn-in, 20,000 retained iterations,
   and one numerical thread;
6. all nine imported VB statuses and artifacts still hash correctly;
7. no DQLM or Q-DESN job enters the scoped plan;
8. all 15 package/default/RNG preflight checks pass.

The package runtime remains the exact task-local tarball used by the parent
campaign. Its SHA-256 is part of every frozen config. New commits may change
only validation orchestration files after that package build; the launcher
rejects changes to package source, compiled code, or metadata.

## Closeout and interpretation

Closeout pools the three MCMC chains within each family-quantile cell and
produces both:

- posterior draw-wise metric means and equal-tailed 95% intervals; and
- like-for-like point-path metrics averaged across chains.

This separation prevents a posterior-metric estimator change from being
mistaken for a package-inference effect. The closeout also records gamma/sigma
diagnostics, metric R-hat/ESS/MCSE summaries, source and config hashes, granular
fit and forecast paths, and a local diagnostic PDF packet.

The 18 exDQLM rows are one compatibility block. Integration must either retain
the existing block or replace it with the complete 1.1.1 block; it must not
cherry-pick only favorable cells. Diagnostic warnings are disclosed but do not
silently exclude finite metrics.

## Ownership and publication boundary

This lane may commit and push only its dedicated validation branch. It must not
modify or merge shared validation, Article-v2 main, the article snapshot, or
Overleaf. On completion it emits `READY_FOR_INTEGRATION` or
`READY_NO_ARTICLE_CHANGE` and hands the frozen evidence to the integration
coordinator.

Runtime state remains under ignored `reports/`, `results/`, and
`validation/fitforecast_v2/local_trackers/` paths. Successful fitted-model
`.rds`, `.rda`, and `.RData` payloads are forbidden.

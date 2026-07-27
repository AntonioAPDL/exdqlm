# Q-DESN 500-Observation MCMC External-Coherent Confirmation v1

## Scope

This stage belongs only to the independent Q-DESN/exQ-DESN versus DQLM/exDQLM
fit-and-forecast validation. It does not modify the exdqlm package API, the
article repository, joint-QDESN, GloFAS, or PriceFM work.

The stage uses the local exdqlm 1.0.0 worktree and the frozen shared source
registry. It selects one exact reduced-budget MCMC candidate for full-budget
confirmation and emits a separate, non-launched redesign handoff for the
remaining lower-quantile cells.

## Diagnosis

The completed metric-gap v3 screen and transport repair produced one scalar
metric row for each of 80 frozen candidate specs. The closeout found:

- 80/80 metric-complete candidate specs;
- 16 targeted family/quantile/likelihood cells;
- a mixed-source internal metric envelope in 12/16 cells;
- no single candidate satisfying the old all-metric internal-envelope gate;
- two Laplace/0.25/exAL candidates coherently better than the external
  DQLM/exDQLM benchmark on fit RMSE, H=1000 forecast MAE, and H=1000 forecast
  check loss.

The `tau0=3e-4` anchor among those two candidates already has a separate
20,000-iteration full-budget result. The `tau0=1e-4` local perturbation has the
better reduced-budget fit RMSE, so it is the only candidate that still requires
full-budget confirmation.

The internal envelope is not a coherent fitted model in most cells. Requiring a
new single model to beat three minima drawn from different historical fits is a
valid stress test, but it is not the scientific target. The scientific target
is a coherent per-cell model that is competitive with DQLM/exDQLM.

## Selected Candidate

- Model: exQ-DESN, exAL working likelihood, regularized horseshoe
- Family: Laplace
- Quantile: 0.25
- Profile: `mgv3_16_exal_local`
- Root seed: `52086`
- Profile-declared seed: `83016`
- Observed effective DESN seed: `123`
- RHS `tau0`: `1e-4`
- Atomic spec:
  `qdesn__laplace__0p25__tt500__rhs_ns__mcmc__exal__020293d289bcb0`

Reduced-budget metrics:

| Metric | Candidate | External best | Ratio |
|---|---:|---:|---:|
| Fit RMSE | 1.685392 | 1.710212 | 0.985487 |
| H=1000 forecast MAE | 1.639841 | 3.520126 | 0.465847 |
| H=1000 forecast check loss | 4.395488 | 4.547688 | 0.966532 |

The reduced screen used 2,000 burn-in iterations, 8,000 MCMC iterations, and
100 posterior metric draws. Its diagnostic grade was `WARN` with reason
`chain_marginal_but_usable`; that status remains visible and is not used to
silently suppress metric evidence.

## Full Confirmation Contract

The confirmation changes only:

- burn-in from 2,000 to 5,000;
- retained MCMC iterations from 8,000 to 20,000;
- posterior metric draws from 100 to 200.

It preserves:

- exdqlm version 1.0.0;
- source registry identity and source hashes;
- train window 8501:9000;
- forecast block 9001:10000;
- rolling-origin protocol with maximum lead 30 and stride 30;
- exact family, quantile, likelihood, prior, profile, root, and atomic spec;
- exact seed contract;
- VB initialization of MCMC;
- one worker and one thread;
- progress cadence every 50 MCMC iterations;
- storage-light output policy.

The confirmation passes only if:

1. one exact root and one exact atomic fit complete;
2. all three metrics are finite;
3. each metric is no worse than 1.05 times the external best;
4. each full-budget metric is no worse than 1.10 times its screening value;
5. the source-registry hash, series hash, selection-index hash, simulation
   payload hash, and source windows all match;
6. no `.rds`, `.rda`, or `.RData` payload is retained.

Chain diagnostics are reported separately from these metric gates. Article
promotion is never automatic.

## Lower-Quantile Redesign

The other 11 lower-quantile cells are emitted as a cell-specific handoff and
are not launched. Each cell retains its own best coherent starting point and
external-metric bottleneck. The next design must:

- avoid a global specification;
- prefer D=1 case-local neighborhoods;
- vary one mechanism at a time;
- use cell-specific `tau0` among `1e-4`, `2e-4`, and `3e-4`;
- avoid repeating the unproductive broad D=2 / `tau0=3e-5` direction;
- use the coherent external benchmark as the primary gate;
- retain the mixed internal envelope only as context.

## Staged Commands

Materialize and prepare:

```bash
Rscript scripts/orchestrate_qdesn_tt500_mcmc_external_coherent_confirmation_v1.R \
  --prepare-only
```

Run the tiny smoke:

```bash
Rscript scripts/orchestrate_qdesn_tt500_mcmc_external_coherent_confirmation_v1.R \
  --smoke --skip-materialize
```

Launch the one-root full confirmation after a clean commit:

```bash
Rscript scripts/orchestrate_qdesn_tt500_mcmc_external_coherent_confirmation_v1.R \
  --full --launch-approved --skip-materialize
```

Close out after completion:

```bash
Rscript scripts/closeout_qdesn_tt500_mcmc_external_coherent_confirmation_v1.R \
  --run-tag RUN_TAG
```

## Completed Confirmation

The full confirmation completed successfully from the clean, pushed commit
`5787212744f56c4dd40578ae717c8874526b48a9`.

- run tag:
  `qdesn-tt500-mcmc-external-coherent-confirmation-v1-full-20260727__git-5787212`
- campaign stamp: `20260727-021334__git-5787212`
- execution: 1/1 root and 1/1 fit `SUCCESS`
- strict artifact audit: `strict_ready=TRUE`
- diagnostic grade: `WARN`
- diagnostic reason: `chain_marginal_but_usable`
- retained binary payloads: 0
- source-registry, source-file-hash, and source-window gates: all `TRUE`
- closeout decision:
  `ELIGIBLE_FOR_SCIENTIFIC_PROMOTION_PENDING_ARTICLE_REVIEW`

| Metric | Full confirmation | Screening | External best | Full / external |
|---|---:|---:|---:|---:|
| Fit RMSE | 1.747288 | 1.685392 | 1.710212 | 1.021679 |
| H=1000 forecast MAE | 1.367163 | 1.639841 | 3.520126 | 0.388385 |
| H=1000 forecast check loss | 4.388165 | 4.395488 | 4.547688 | 0.964922 |

The exact closeout is:

```text
validation/fitforecast_v2/promotions/
  qdesn_tt500_mcmc_external_coherent_confirmation_v1_closeout_20260727/
```

The strict audit is:

```text
reports/qdesn_mcmc_validation/
  qdesn_dynamic_fitforecast_v2_tt500_mcmc_external_coherent_confirmation_v1/
  qdesn-tt500-mcmc-external-coherent-confirmation-v1-full-20260727__git-5787212/
  20260727-021334__git-5787212/strict_audit/
```

This result is scientifically promotable under the frozen contract, but no
article repository was changed. Article integration remains a separate manual
review. The 11-cell lower-quantile redesign remains unlaunched.

## Metric-Envelope Promotion Review

The manual article review was completed against the frozen 2026-07-26
metric-wise candidate ledger. The full confirmation was added as a distinct
coherent candidate in:

```text
validation/fitforecast_v2/promotions/
  qdesn_dqlm_500obs_mcmc_metric_envelope_20260727/
```

The refreshed promotion has:

- 129 audited candidate rows;
- 36/36 complete article-facing cells;
- one separately identified coherent full-budget confirmation;
- zero replacements of an existing metric-wise minimum;
- the unchanged shared source-registry SHA-256
  `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`;
- no `.rds`, `.rda`, or `.RData` payloads;
- no active `/home/jaguir26/local/src` paths.

The coherent confirmation is slightly above the existing case-specific
Laplace/0.25/exAL-RHS metric minima:

| Metric | Coherent confirmation | Displayed metric-wise minimum |
|---|---:|---:|
| Fit RMSE | 1.747288 | 1.727325 |
| H=1000 forecast MAE | 1.367163 | 1.355324 |
| H=1000 forecast check loss | 4.388165 | 4.378391 |

Consequently, the article-facing numeric entries must not change under the
declared metric-wise selection rule. The new promotion strengthens provenance
by retaining a single fitted model that passed every prespecified external,
stability, source, and storage gate. Its `WARN` diagnostic
(`chain_marginal_but_usable`) remains explicit in the confirmation ledger.
Article integration should update the immutable source promotion and disclose
the coherent confirmation without presenting it as a new metric minimum.

## Invalid Historical Tags

The following aborted metric-gap repair tags remain invalid and must never be
consumed:

- `qdesn-tt500-mcmc-metricgap-v3-tau0-repair-full-20260726__git-81aa2e2`
- `qdesn-tt500-mcmc-metricgap-v3-tau0-repair-full-r2-20260726__git-34994be`

The authoritative repair evidence is:

- run tag:
  `qdesn-tt500-mcmc-metricgap-v3-tau0-repair-full-20260726__git-3e050f9`
- campaign stamp: `20260726-220256__git-3e050f9`

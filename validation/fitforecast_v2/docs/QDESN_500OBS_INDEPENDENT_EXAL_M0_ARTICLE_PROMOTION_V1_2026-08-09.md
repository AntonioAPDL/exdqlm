# Independent exAL M0 article promotion v1

## Decision boundary

This stage closes the completed independent single-quantile exAL MCMC campaign
`ind-exal-m0-v1-20260809_161838__git-89d214e`. It updates the fixed
500-observation article interface without changing the source registry, DESN
specifications, DQLM/exDQLM baselines, VB evidence, AL-RHS evidence, rolling-origin
protocol, or diagnostic policy.

The campaign completed 45 of 45 chains: 15 case-specific anchors and three
independent chains per anchor. Each pooled anchor contains 60,000 retained draws.
Thirteen anchors have a PASS diagnostic grade and two have WARN grades. The WARN
grades are retained in the interface; diagnostic status is not a metric filter.

## Promotion rule

The source authority is the immutable 72-row v3 interface
`qdesn_dqlm_500obs_trainonly_article_v3_20260807`. For each of the 27 independent
exAL-RHS MCMC family-by-quantile-by-metric roles:

1. verify that the v3 value equals the frozen pre-M0 comparison value;
2. verify that the pooled M0 value equals its compact anchor evidence;
3. promote M0 only when its value is strictly lower;
4. otherwise retain the existing v3 value and provenance;
5. preserve the selected metric's status and diagnostic grade.

This rule promotes 22 roles and retains five. It increases the number of exAL-RHS
within-table metric wins from 10 to 16 of 27. Eleven roles remain above another
displayed comparator and are written to `remaining_gap_ledger.csv`; lower-quantile
roles are marked as the primary future calibration targets.

## Reproducibility and storage

The v4 promotion is self-contained. It freezes all 81 compact metric sources used
by v3, compact pooled M0 rows, cross-chain diagnostics, path-agreement summaries,
runtime audits, closeout gates, source manifests, and storage audits. No fitted
object payload is retained. The promotion bundle must contain zero `.rds`, `.rda`,
or `.RData` files.

The exact MCMC method is `M0_v_collapsed_support_logit`: the established
v-augmentation, sigma collapsed from the gamma target and redrawn exactly, and
gamma updated in the logit transform of its native bounded support. The article
should describe the method scientifically; the immutable method ID remains in the
reproducibility manifest.

## Commands

```bash
Rscript validation/fitforecast_v2/scripts/promote_independent_exal_m0_article_v1.R
Rscript -e 'testthat::test_file("validation/fitforecast_v2/tests/testthat/test-independent-exal-m0-article-promotion-v1.R")'
```

The article repository must consume the generated v4 interface and its exact
SHA-256 values through a clean worktree based on current `origin/main`. Article
tables, figure data, PDF, and manifests must be regenerated from the existing
article builder and pass its independent-validation checker before publication.

## Invalid evidence

The following tags are non-consumable:

- `ind-exal-m0-v1-20260809_160325__git-1ac48bd`: launcher aborted before workers;
- `ind-exal-m0-v1-20260809_160714__git-0541583`: diagnostic canary only.

Only `ind-exal-m0-v1-20260809_161838__git-89d214e` is authoritative for this
promotion.

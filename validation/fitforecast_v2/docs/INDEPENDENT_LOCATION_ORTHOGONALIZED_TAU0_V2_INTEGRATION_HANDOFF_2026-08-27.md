# Independent Location-Orthogonalized Tau0 V2 Integration Handoff

Date: 2026-08-27

Final lane status: `READY_FOR_INTEGRATION`.

## Lane identity

- Scientific lane: independent single-quantile Q-DESN/DQLM validation only.
- Transcript:
  `/home/jaguir26/.codex/sessions/2026/05/15/rollout-2026-05-15T18-06-50-019e2dad-9160-7421-a3ae-4c5b3b1410ca.jsonl`.
- Worktree:
  `/data/jaguir26/local/src/exdqlm__wt__independent_dynamic_location_capacity_tau0_v1_1p0p0`.
- Branch: `validation/independent-location-orthogonalized-tau0-v2-1.0.0`.
- Upstream:
  `origin/validation/independent-location-orthogonalized-tau0-v2-1.0.0`.
- Promotion implementation commit:
  `1ba4f2d74f438aa0f6db30967702fea1124eb483`.
- The final branch tip is the commit containing this handoff and must be read
  from the upstream branch after fetch.

This lane did not merge or push shared validation, exdqlm main, Article-v2
main, an article snapshot, or direct Overleaf.

## Base relationship

At final fetch, `origin/validation/shared-fitforecast-v2-1.0.0` was
`e18ed1160a6a576d2c9df452f0b77491459dba4b`. The task branch was 0 commits
behind and 16 commits ahead before this handoff was committed. The previously
integrated IND authority `f7d57b17997bea461faf6f5bfc6213c33fa2fd1e` is an
ancestor of both the shared branch and this task branch, so the earlier authority
discrepancy is resolved by ancestry.

The integration coordinator must merge the complete task branch through an
explicit merge commit. The branch includes dependent interval-dispersion,
origin-horizon, common-shift, dynamic-location, V2 campaign, replay, promotion,
and closeout commits; do not cherry-pick only the final promotion commit.

## Result summary

| Item | Result |
|---|---:|
| Original V2 jobs | 52/52 successful |
| Interval replay jobs | 3/3 successful |
| Failures | 0 |
| Runs remaining | 0 |
| Active lane jobs | 0 |
| Promoted point metrics | 2 |
| Updated interval roles | 2 |
| Retained interval draws | 3,000 |
| Fitted-model binaries | 0 |

Scientific decision:
`PROMOTE_TWO_CASE_SPECIFIC_FORECAST_METRICS`.

The promoted cell is MCMC Q-DESN AL-RHS, Gaussian, `p = 0.05`:

- forecast MAE: 6.91659380458911 -> 6.73382698952425;
- forecast check loss: 1.20016989478546 -> 1.19120186398605;
- fit RMSE: retain the v9 source and value;
- all other point metrics: retain exactly;
- diagnostic disclosure: WARN, retained and not used as a metric veto.

The corresponding interval roles use 3,000 chain-balanced draw-wise metric
values and passed all precision gates. Forecast MAE has posterior mean 7.173395
and equal-tailed 95% CrI [2.718086, 12.226008]. Forecast check loss has
posterior mean 1.234977 and equal-tailed 95% CrI [1.081647, 1.453692].

## Frozen evidence

Portable audit:

`validation/fitforecast_v2/audits/independent_location_orthogonalized_tau0_v2_20260827`

Point authority:

`validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_trainonly_article_v11_location_orthogonalized_20260827`

Interval authority:

`validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_metric_interval_reporting_v11_1_20260827`

Closeout:

`validation/fitforecast_v2/docs/INDEPENDENT_LOCATION_ORTHOGONALIZED_TAU0_V2_PROMOTION_CLOSEOUT_2026-08-27.md`

Key hashes:

| Artifact | SHA-256 |
|---|---|
| Audit artifact manifest | `96ef4185f314059c354524bc1901067457a4792fc89a3fdd24285ef888c661af` |
| Audit manifest | `c61d84780145409105d116bcce6e9ef7bf72caac8bc1fdf09bee81df3a6a01fb` |
| Point authority manifest | `828f81fb714149937e088294ae433897354c7faa0ed941474936873718fb9958` |
| Interval decision manifest | `a683fb81d187f1d21829664e96f2ff0ce5c0903e987f8944a2418bbd64925357` |
| Article asset manifest | `c93227e30a65f024b237a8ae581d0035cba05fdc230f7c6be79702ccf5a70cc5` |

## Article-safe publication packet

The coordinator should publish only the following scientific outputs from this
lane:

1. The 72-row v11 point interface and its delta/source/rollback manifests.
2. The v11.1 interval reporting interface, precision ledgers, and decision
   manifest.
3. The two vector MCMC forecast-interval figures under
   `article_assets/figures/independent_simulation/`.
4. Minimal article prose documenting the two strict forecast improvements and
   the point-path versus draw-wise interval estimators.

Exact article actions:

- update Gaussian `p = 0.05` Q-DESN AL-RHS MCMC forecast MAE to `6.734`;
- update its forecast check loss to `1.191`;
- do not change its fit RMSE;
- do not change any other point-table value;
- replace the MCMC forecast MAE and check-loss interval figures with the v11.1
  PDFs;
- retain the WARN marker and diagnostic disclosure;
- do not describe the interval as a repeated-simulation confidence interval.

The scientific lane did not edit Article-v2. Article compilation and direct
Overleaf publication remain coordinator-owned.

## Verification contract

The following checks passed in R 4.6.0:

- `test-independent-location-orthogonalized-tau0-v2.R`: 26 expectations;
- `test-independent-location-orthogonalized-tau0-v2-promotion.R`:
  43 expectations;
- standalone promotion verifier: 8/8 checks;
- point parent invariance: 72 rows, exactly two changed metric cells;
- interval parent invariance: 216 roles, exactly two updated roles;
- interval precision: all six leave-one-chain-out/bootstrap gates passed;
- visual inspection: both figure PNGs passed;
- PDF inspection: both vector PDFs are valid one-page files;
- binary storage audit: no `.rds`, `.rda`, or `.RData` payloads;
- `git diff --check`: required again after coordinator merge.

Coordinator verification command:

```bash
Rscript validation/fitforecast_v2/scripts/verify_independent_location_orthogonalized_tau0_v2_promotion.R --repo-root="$(git rev-parse --show-toplevel)"
```

The coordinator should also rerun both focused test files after the merge and
compile the main article and supplement after copying article-safe assets.

## Runtime and storage

Ignored runtime evidence remains under:

- `reports/shared_fitforecast_v2_orchestration/independent_location_orthogonalized_tau0_v2_20260827_005026`;
- `reports/shared_fitforecast_v2_orchestration/independent_location_orthogonalized_tau0_v2_interval_replay_20260827_162303`;
- `results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_500obs_location_orthogonalized_tau0_v2`.

The result tree is approximately 417 MiB: 356 MiB for the original V2 run,
56 MiB for interval replay, and 4.5 MiB for preflight. It contains no fitted
model binaries. Preserve it until integration and article verification are
complete. Afterward, this lane may perform a separate read-only dry-run audit
and compact nonwinner regenerable runtime outputs while retaining all tracked
authority packets, manifests, winner evidence, and reproducibility metadata.

## Known cautions

1. The original 600-draw interval approximation was not promoted; it narrowly
   failed one precision gate. The 3,000-draw replay is authoritative.
2. Point-table scores and posterior metric means are different estimators and
   must not be substituted for one another.
3. Absolute source strings in inherited v9/v10.1 rows are grandfathered frozen
   provenance. New forecast and replay sources are repository-relative.
4. WARN diagnostics remain visible. They do not invalidate the user's declared
   strict metric-improvement promotion rule.
5. No new scientific screen should begin until v11/v11.1 is integrated and the
   remaining-gap ledger is rebased to it.

## Coordinator procedure

1. Fetch the task and shared-validation branches using command-line Git.
2. Confirm the task branch is clean and exactly synchronized with its upstream.
3. Confirm shared authority `e18ed116...` is an ancestor of the task branch.
4. Merge the complete task branch into the latest shared-validation authority
   through an explicit merge commit; do not force-push or squash away evidence.
5. Run the standalone verifier and the two focused test files.
6. Review the v11 delta and v11.1 interval-update ledgers.
7. Apply only the declared article-safe changes in the authoritative Article-v2
   worktree.
8. Compile the main article and supplement, visually inspect the table and two
   figures, and publish the article-only snapshot through command-line Git.
9. Report the final shared-validation, Article-v2, snapshot, and direct
   Overleaf hashes.

Final status: `READY_FOR_INTEGRATION`.

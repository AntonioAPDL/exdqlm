# Independent Q-DESN Tier-B Cellwise MCMC v1 Closeout

Date: 2026-08-13

This note closes the independent Q-DESN Tier-B cellwise MCMC campaign. It is
scoped only to the independent Q-DESN/DQLM simulation-validation lane. No
Article-Q-DESN, joint-QDESN, PriceFM, or GloFAS files or jobs were changed.

## Immutable identity

- Worktree: `/data/jaguir26/local/src/exdqlm__wt__qdesn_tierb_cellwise_mcmc_v1_1p0p0`
- Branch: `validation/qdesn-tierb-cellwise-mcmc-v1-1.0.0`
- Upstream: `origin/validation/qdesn-tierb-cellwise-mcmc-v1-1.0.0`
- Execution commit: `52f23d079f9e5f91b2ee9d339f6b96f902e70a8b`
- Package version: `1.0.0`
- Run id: `qdesn_tierb_cellwise_mcmc_v1_20260813_prod1`
- Run tag: `qdesn-tierb-cellwise-v1-20260813__git-52f23d0`
- State root: `reports/shared_fitforecast_v2_orchestration/qdesn_tierb_cellwise_mcmc_v1_20260813_prod1`
- Result root: `results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_500obs_tierb_cellwise_mcmc_v1/qdesn-tierb-cellwise-v1-20260813__git-52f23d0/jobs`

The tracked protocol is
`validation/fitforecast_v2/docs/QDESN_TIERB_CELLWISE_MCMC_V1_PROTOCOL_2026-08-13.md`.

## Objective and scope

The campaign tested previously unrun, case-specific AL-RHS designs for the four
remaining fit-RMSE cells:

- Laplace at tau 0.05;
- Laplace at tau 0.25;
- Gaussian mixture at tau 0.05; and
- Gaussian mixture at tau 0.25.

The frozen v6 article-facing metric was the comparator for each cell. Candidate
selection was adaptive but predeclared: development discovery, independent
development replication, sealed holdout evaluation, and canonical full-budget
confirmation. No global Q-DESN specification was sought.

## Computational closeout

Every planned job completed successfully.

| Stage | Jobs | Successful | Failed | Disposition |
|---|---:|---:|---:|---|
| Smoke | 2 | 2 | 0 | Passed |
| Calibration | 4 | 4 | 0 | Passed runtime gate |
| Tier-B discovery | 108 | 108 | 0 | Advanced 16 roots |
| Development replication | 16 | 16 | 0 | Advanced 48 sealed roots |
| Sealed holdout | 48 | 48 | 0 | One metric eligible |
| Canonical confirmation | 3 | 3 | 0 | No confirmed gain |
| **Total** | **181** | **181** | **0** | **Closed** |

The three canonical chains each completed 5,000 burn-in plus 20,000 retained
MCMC iterations. The final health report records all three at 25,000/25,000,
100 percent, and `completed`.

## Sealed evidence

Lower ratios are better. Eligibility required a mean ratio below one, a median
ratio below one, and improvement on at least three of four sealed sources.

| Cell | Candidate suffix | Mean ratio | Median ratio | Improved sources | Eligible |
|---|---|---:|---:|---:|---|
| Laplace, 0.05 | `05_304ae1d53d` | 1.0349 | 1.0267 | 0/4 | No |
| Laplace, 0.05 | `01_d633613a13` | 0.9880 | 0.9873 | 2/4 | No |
| Laplace, 0.25 | `05_e66c9795d3` | 0.9587 | 0.9786 | 2/4 | No |
| Laplace, 0.25 | `04_60d94c2ccb` | 0.9661 | 0.9760 | 2/4 | No |
| Gaussian mixture, 0.05 | `01_96661ae172` | 0.9948 | 1.0072 | 1/4 | No |
| Gaussian mixture, 0.05 | `05_d145489968` | 0.9815 | 1.0086 | 2/4 | No |
| Gaussian mixture, 0.25 | `04_d705048e71` | 0.9831 | 0.9876 | 2/4 | No |
| Gaussian mixture, 0.25 | `05_11db2b714c` | 0.9699 | 0.9565 | 3/4 | Yes |

Only `tbcv1_al_gausmix_t0p25_05_11db2b714c` crossed the sealed gate.

## Canonical confirmation

The eligible Gaussian-mixture tau-0.25 candidate was run on the frozen
article source with three full-budget chains.

| Chain | Fit RMSE | Ratio to v6 | Forecast MAE | Forecast check loss | Signoff |
|---:|---:|---:|---:|---:|---|
| 1 | 2.1778 | 1.1738 | 2.5363 | 4.5562 | PASS |
| 2 | 2.0681 | 1.1147 | 2.5684 | 4.5620 | PASS |
| 3 | 2.1268 | 1.1464 | 2.3819 | 4.5431 | PASS |

The frozen v6 fit RMSE is 1.855306. The confirmation mean is 2.124230 and the
median is 2.126843; zero of three chains improved the frozen value. All chains
are finite, successful, and diagnostically eligible, so the negative result is
not explained by implementation failure or poor chain signoff.

Diagnostic ranges across the three chains were:

- core minimum ESS: 4,211.9 to 4,492.2;
- core maximum lag-one autocorrelation: 0.421 to 0.445;
- core maximum absolute Geweke statistic: 0.390 to 1.848;
- core maximum half-chain drift: 0.016 to 0.032;
- RHS minimum ESS: 1,500.4 to 1,560.0; and
- RHS maximum lag-one autocorrelation: 0.838 to 0.843.

## Decision

The final decision is:

```text
NO_CONFIRMED_GAIN_RETAIN_V6
```

No metric is promoted. The independent-validation article table remains on
the frozen v6 authority, and no article-safe file should change because of this
campaign. The development and sealed improvements were useful screening
signals, but they did not transport to the canonical source.

Do not repeat this same local tau/memory/recurrence neighborhood. A future
campaign requires a new, predeclared scientific hypothesis and direct paired
canonical pilots before another broad MCMC allocation.

## Source and evidence contract

- Canonical registry identity hash:
  `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- Development source-registry file SHA-256:
  `920b3f0caef920dc51c543a70c455fc19b8cef6f1a4b71f7b9e843cc4c69811e`
- Development source-window registry SHA-256:
  `63396b83074dd6489e699c8bdebc3ee0cc37e16a3815776bbc2a6655d4813483`
- Canonical `series_wide.csv` SHA-256:
  `268332589ff560e8e4295a72f4ab112ea0c3095ed9e2ede2dde5fe1db1dab484`
- Canonical `sim_output.rds` SHA-256:
  `5bcf8bec952befbd9ec19499eca606fd13f17cb294f1fa9bf04a51bea14e596d`
- Frozen parent request SHA-256:
  `fa11cdb6457986605149287f5ba5b7b44931d1b9f30fc516c5a19e7fddb798a6`

Primary evidence under the state root:

- `materialization/materialization_manifest.json`
- `adaptive/tier_b_discovery_paired_metric_summary.csv`
- `adaptive/tier_b_replication_paired_metric_summary.csv`
- `adaptive/tier_b_sealed_paired_metric_summary.csv`
- `adaptive/tier_b_sealed_eligible_metrics.csv`
- `confirmation/confirmation_chain_metrics.csv`
- `confirmation/confirmation_promotion_ledger.csv`
- `confirmation/confirmation_closeout.json`
- `confirmation_verification.json`
- `confirmation_health.csv`

Key evidence SHA-256 values:

| Evidence | SHA-256 |
|---|---|
| Discovery paired summary | `1bfffa529f548ceed318e0c7818fbb1699050a8fa2b35c3e3202a9cee838f335` |
| Replication paired summary | `19a65ca7e50bf8ea311ee2d22afe15c5e739fdceb42d564b64befe278bdef67f` |
| Sealed paired summary | `2118a8462f73d81d7e98e17725bf13a2b0ef25fcf5e3cac36c4a52fd31fc154a` |
| Sealed eligibility | `d3b53162fa9928dd87eab35c6e0c2e598a9b9968e66c45fc2ec36a407cc01f95` |
| Confirmation chain metrics | `eebb92226d70b85fc65f0a17670b740c23d6fc4abc3f22338fc01e2dbbb540de` |
| Promotion ledger | `609ec08ee8059182098ce0e47bc7c97f496e158d4192716830947db030a9541a` |
| Confirmation closeout | `f71a9418c367026f091b43a2ac91980c762c2319a0cd6eb41d9183b559305542` |
| Confirmation verification | `db94c3f7e045d971b0367e199e9c24a68b4fdbce298654d60362de882ea4520b` |

## Storage-light closeout

- Fitted-model `.rds`, `.rda`, or `.RData` files under all 181 job roots: 0.
- Binary files under the orchestration state root: 0.
- Frozen source-authority `sim_output.rds` files: 64 files, 14.04 MiB.
- Campaign result tree: 706 MiB, primarily source tables and compact path
  summaries needed to reproduce paired scoring.
- Orchestration evidence: 4.5 MiB.

The source-authority objects are inputs with registered hashes, not fitted-model
payloads, and are retained. No cleanup is required for campaign closeout.

## Verification

The following checks passed under R 4.6.0 and the campaign-local package library:

- package installation and load at version 1.0.0;
- static protocol verification;
- smoke verification;
- calibration verification and runtime gate;
- discovery, replication, sealed, and confirmation runtime verification;
- replication and sealed handoff verification;
- focused Tier-B testthat suite, including confirmation-shaped health plans;
- final confirmation health report: 3 completed, 0 running, 0 failed;
- 181 job-status files: 181 `SUCCESS`;
- job-root and state-root fitted binary checks: zero forbidden payloads; and
- `git diff --check` before closeout commit.

The post-run focused-test log is
`reports/shared_fitforecast_v2_orchestration/qdesn_tierb_cellwise_mcmc_v1_20260813_prod1/final_focused_tests.log`.

## Integration handoff

This validation lane is `READY_FOR_INTEGRATION` after its closeout commit is
pushed and the branch is clean at zero ahead and zero behind. Integration must
be limited to the validation reporter, its focused regression test, and this
closeout note. There are no article-safe result changes to publish and no
background jobs to preserve for this campaign.

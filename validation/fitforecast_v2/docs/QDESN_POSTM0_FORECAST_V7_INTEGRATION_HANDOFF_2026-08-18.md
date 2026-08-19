# Independent Q-DESN post-M0 forecast v7 integration handoff

## Scope and ownership

This handoff belongs only to the independent single-quantile Q-DESN/DQLM
validation lane. It does not authorize edits to joint-QDESN, PriceFM, GloFAS,
or application code. Article publication is delegated to the Article Q-DESN
integration lane.

| Field | Frozen value |
|---|---|
| Lane | Independent Q-DESN/DQLM validation |
| Primary transcript | `/home/jaguir26/.codex/sessions/2026/05/15/rollout-2026-05-15T18-06-50-019e2dad-9160-7421-a3ae-4c5b3b1410ca.jsonl` |
| Continuation transcript | `/home/jaguir26/.codex/sessions/2026/08/18/rollout-2026-08-18T17-50-35-01a016da-d7c8-73f0-897d-c02d4a847f7a.jsonl` |
| Worktree | `/data/jaguir26/local/src/exdqlm__wt__qdesn_postm0_legacy_recheck_v1_1p0p0` |
| Branch | `validation/qdesn-postm0-legacy-recheck-v1-1.0.0` |
| Upstream | `origin/validation/qdesn-postm0-legacy-recheck-v1-1.0.0` |
| Shared-validation base | `f7d57b17997bea461faf6f5bfc6213c33fa2fd1e` |
| Frozen scientific payload | `077e4a8bc1052c2d4a2ba7c98e69bc3cb4d83469` |
| Relationship to base | Eight task-owned commits; base is an ancestor |

The exact 100-file scientific diff through the frozen payload commit is in
`QDESN_POSTM0_FORECAST_V7_INTEGRATION_CHANGED_FILES_2026-08-18.csv`. The
handoff document and that CSV are the only files added after the scientific
payload freeze.

## Campaign completion

| Field | Result |
|---|---|
| Run ID | `qdesn_postm0_legacy_recheck_v1_20260814_prod1` |
| Run tag | `qdesn-postm0-legacy-recheck-v1-20260814-prod1__git-9db909c` |
| Candidate | `plrv1_exal_gausmix_t0p25_08_576957a0bd` |
| Cell | MCMC exQ-DESN RHS, Gaussian mixture, p=0.25 |
| Method | `M0_v_collapsed_support_logit` |
| Canonical chains | 3/3 successful |
| Iterations | 5,000 burn-in plus 20,000 retained per chain |
| Final progress | 25,000/25,000 for every chain |
| Failed or remaining jobs | 0 |
| Active lane processes or tmux sessions | 0 |
| Fitted-model binary payloads | 0 |

All three chains carry a diagnostic grade of `FAIL` because of retained
autocorrelation and drift diagnostics. Under the predeclared forecast-first
policy, these grades are descriptive and are not a metric-promotion veto. This
evidence supports metric-envelope simulation comparisons only; it must not be
used to claim well-mixed posterior uncertainty.

## Scientific decision

The v7 interface inherits the complete 72-row v6 authority and changes exactly
two numeric roles. Both promoted values are arithmetic means over the three
successful full-budget chains.

| Metric | Frozen v6 | Confirmed mean | Relative gain | Chains improved | Decision |
|---|---:|---:|---:|---:|---|
| Forecast oracle-quantile MAE, H=1000 | 3.396454525 | 1.819330730 | 46.43% | 3/3 | Promote |
| Forecast check loss, H=1000 | 4.586349412 | 4.488089789 | 2.14% | 3/3 | Promote |
| Fit oracle-quantile RMSE | 1.3802668 | 2.1945801 | -58.99% | 0/3 | Retain v6 |

The promoted forecast MAE and forecast check loss are both lower than the best
displayed DQLM/exDQLM comparator for this cell. The fit metric is intentionally
not replaced. No other family, quantile, model, inference mode, or metric may
change during integration.

## Immutable evidence

Promotion root:

`validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_trainonly_article_v7_postm0_forecast_20260818`

| Artifact | SHA-256 |
|---|---|
| Article interface | `362a27fbd91ee18ae07b0b238e20cf1488892238103ac8fc5e8eee7dc3e8d325` |
| Promotion decision ledger | `603302cbf1a08614305aacacd4e24560ac57724ef9d598ca5061aecf63bde202` |
| Remaining-gap ledger | `6bcf4ce5bbc524b0faf3405f84e49186646264e5966728f5080bd623d63c923e` |
| Source ledger | `a238bfac83d90f142ee7c62bf7d729d7e8baad17b9ff729e9a2822a410d8187f` |
| Output-file manifest | `95ce879eed49e70f75497dee6d3e7e5f2ebc0eef34af1c4b8b4334d5d5ab6161` |
| Promotion manifest | `9876be4496961321d6d4d703799d1073ed18b90e1a5826ae753cb936bb318c9d` |
| Scientific changed-file manifest | `57dbaf464167dd7dd6af47c2048c026b2f464e5ff879a0d7e427c86f49da621a` |

The package is approximately 800 KiB and contains compact CSV/JSON evidence
only. The campaign report root is approximately 5.1 MiB. Neither surface
contains `.rds`, `.rda`, or `.RData` files, and no file exceeds 10 MiB.

The ignored runtime result root is
`results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_500obs_postm0_legacy_recheck_v1/qdesn-postm0-legacy-recheck-v1-20260814-prod1__git-9db909c`.
It contains 5,220 files totaling 639,749,917 bytes (0.596 GiB), zero serialized
model binaries, and no file larger than 5,177,057 bytes. Keep it excluded from
Git and retain it through integration because it contains the full diagnostic
traces behind the recorded `FAIL` grades. Storage compaction may be considered
only after the tracked v7 package is integrated and independently verified.

## Verification record

The following checks were run in the dedicated task worktree:

| Check | Result |
|---|---|
| Source-loaded environment | R 4.6.0 and exdqlm 1.0.0; pass |
| Focused post-M0 campaign `testthat` file | Pass |
| Exact-M0 adjacent regression file | Pass; two expected fixture-dependent skips |
| Promotion verifier | Pass: 72/72 interface rows, 2 promoted roles, article-consumption PASS, storage-policy PASS |
| Confirmation verifier | Pass: 3/3 chains complete and 12/12 contract checks |
| Hash verification | Pass for every immutable package artifact |
| `git diff --check` | Pass |
| Active-process audit | No process or tmux session for this campaign |

An older lower-tail adjacent test surface still reports two missing-fixture
errors and two warnings because its historical materialization directory was
compacted before this campaign. Its static tests pass, and the missing fixture
is not used by the v7 promotion. This is a documented environmental limitation,
not a regression introduced here.

## Integration instructions

1. Fetch the task branch and verify that it is clean and synchronized with its
   upstream.
2. Merge the task branch into the current shared independent-validation
   authority using a normal Git merge. Do not merge it into `exdqlm/main`.
3. Re-run the focused tests, promotion verifier, hashes, and confirmation
   verifier after the merge.
4. Use the v7 interface as the independent-validation article source. Update
   only Gaussian-mixture p=0.25, MCMC exQ-DESN RHS forecast MAE and forecast
   check loss. Retain the v6 fit RMSE and all other table values.
5. Regenerate the article table through its existing reproducible builder,
   compile the main article and supplement, and publish the article-only
   snapshot through the integration lane.
6. Keep report directories and generated runtime paths out of Git. The only
   publication inputs are the tracked immutable v7 package and its ledgers.

Recommended order: shared-validation merge and verification first, article
regeneration second, article compilation third, and Overleaf publication last.
Do not launch another screening campaign until v7 is integrated and the
remaining forecast-gap ledger is recomputed from the published authority.

## Residual scientific risks

- Diagnostic failure remains visible and must accompany any interpretation of
  these MCMC rows.
- Metric-specific winners may come from different calibrated specifications;
  the article must describe the table as a case-specific metric envelope.
- The next search should target only positive forecast gaps, use exact exAL M0,
  exclude previously evaluated signatures, and confirm strict gains directly
  with MCMC because VB has not been a reliable MCMC proxy in this study.

**READY_FOR_INTEGRATION**

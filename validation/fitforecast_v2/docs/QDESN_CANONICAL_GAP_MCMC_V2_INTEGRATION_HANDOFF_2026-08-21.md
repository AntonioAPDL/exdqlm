# Q-DESN canonical-gap MCMC v2 integration handoff

Date: 2026-08-21

Status: **READY_FOR_INTEGRATION**

## Lane

- Scientific lane: independent single-quantile Q-DESN/DQLM validation only
- Codex transcript:
  `/home/jaguir26/.codex/sessions/2026/05/15/rollout-2026-05-15T18-06-50-019e2dad-9160-7421-a3ae-4c5b3b1410ca.jsonl`
- Validation worktree:
  `/data/jaguir26/local/src/exdqlm__wt__qdesn_canonical_gap_mcmc_v2_1p0p0`
- Task branch: `validation/qdesn-canonical-gap-mcmc-v2-1.0.0`
- Task upstream: `origin/validation/qdesn-canonical-gap-mcmc-v2-1.0.0`
- Integration target: `origin/validation/shared-fitforecast-v2-1.0.0`
- Shared-target base: `fba22d605039dcf5d48f59c7760fc01053685451`

The shared target has no commit outside this task branch, so it can be
fast-forwarded after normal verification. Before this handoff commit, the task
branch contains seven unique commits:

```text
79e5b02 Add canonical-gap independent Q-DESN MCMC campaign
78b919f Require free capacity before canonical-gap launch
261c794 Fix canonical-gap launch identifiers
ec9a921 Create canonical-gap launch report root
e5be7d0 Add canonical-gap v9 promotion closeout
d585cd5 Deduplicate canonical-gap promotion controls
941203d Promote canonical-gap v9 forecast gains
```

## Completed run

- Run id: `qdesn_canonical_gap_mcmc_v2_20260820_003025`
- Run tag: `qdesn-canonical-gap-v2-20260820_003025__git-ec9a921`
- Smoke: 2/2 successful
- Calibration: 4/4 successful
- Screen: 128/128 successful
- Refinement: 36/36 successful
- Canonical confirmation: 6/6 successful
- Total: 176/176 successful, 0 failed
- Active campaign processes or tmux sessions: none

Each promoted case uses the arithmetic mean of three full-budget chains, with
5,000 burn-in and 20,000 retained iterations per chain. exAL uses
`M0_v_collapsed_support_logit`; AL uses `sigma_then_gamma`.

## Scientific decision

Promotion id:
`qdesn_dqlm_500obs_trainonly_article_v9_canonical_gap_20260821`

Four strict, finite, case-specific forecast improvements replace v8:

| Model and case | Criterion | v8 | v9 | Gain |
|---|---|---:|---:|---:|
| Q-DESN AL-RHS, Gaussian, p=0.05 | Forecast MAE | 8.410107 | 6.916594 | 17.8% |
| Q-DESN AL-RHS, Gaussian, p=0.05 | Forecast check loss | 1.220900 | 1.200170 | 1.7% |
| Q-DESN exAL-RHS, Gaussian mixture, p=0.50 | Forecast MAE | 2.562274 | 1.419645 | 44.6% |
| Q-DESN exAL-RHS, Gaussian mixture, p=0.50 | Forecast check loss | 5.610103 | 5.486730 | 2.2% |

No fit criterion changes. Canonical-chain diagnostics are 5 WARN and 1 FAIL;
they remain disclosed but, under the user's predeclared metric-level policy,
do not veto a finite strict forecast improvement.

## Validation evidence

The compact promotion directory contains exactly 124 files:

```text
validation/fitforecast_v2/promotions/
  qdesn_dqlm_500obs_trainonly_article_v9_canonical_gap_20260821/
```

Its 119-row `source_ledger.csv` enumerates and hashes source evidence. Its
11-row `output_file_manifest.csv` enumerates and hashes all core promotion
artifacts. Key hashes are:

- Interface: `eb697b6f3e366581d158a41ecd2213761486be769b541439d2d862d840ea4b27`
- Promotion manifest: `b5a87a3b5a69ac36a1a16ee8a2638ca3d374ea1d6a80b6b72ba44901376a3993`
- Source ledger: `aefdd71842fc0ee56fdf34bed3dd739297be6f73c14b31999ee788263f5f52f2`
- Article delta: `37fa5a69d1047286201e444984f70d626da700b916b8e637b74fe1a8db5849b4`
- Chain evidence: `5341fa1df7a09609b5bb276ec9150637a3cd8185803947477b0d5df8f6228fb5`
- Promoted specifications: `bb614471227f04622ba55967c8633f265afdee5d942f913888463cefb4881a91`
- Rollback ledger: `bc094abef458831ed0d9b7e0d5850dd3493e6a121dd79ea3b3fb359399d4786d`

The exact campaign implementation files preceding the compact closeout are:

```text
config/validation/qdesn_dynamic_fitforecast_v2_500obs_canonical_gap_mcmc_v2_candidate_profiles.csv
config/validation/qdesn_dynamic_fitforecast_v2_500obs_canonical_gap_mcmc_v2_novelty_audit.csv
config/validation/qdesn_dynamic_fitforecast_v2_500obs_canonical_gap_mcmc_v2_target_cells.csv
validation/fitforecast_v2/R/qdesn_canonical_gap_mcmc_v2.R
validation/fitforecast_v2/docs/QDESN_CANONICAL_GAP_MCMC_V2_PROTOCOL_2026-08-20.md
validation/fitforecast_v2/scripts/advance_qdesn_canonical_gap_mcmc_v2.R
validation/fitforecast_v2/scripts/build_qdesn_canonical_gap_mcmc_v2_design.R
validation/fitforecast_v2/scripts/healthcheck_qdesn_canonical_gap_mcmc_v2.R
validation/fitforecast_v2/scripts/launch_qdesn_canonical_gap_mcmc_v2.sh
validation/fitforecast_v2/scripts/materialize_qdesn_canonical_gap_mcmc_v2.R
validation/fitforecast_v2/scripts/run_qdesn_canonical_gap_mcmc_v2_chain.R
validation/fitforecast_v2/scripts/run_qdesn_canonical_gap_mcmc_v2_pipeline.sh
validation/fitforecast_v2/scripts/verify_qdesn_canonical_gap_mcmc_v2.R
validation/fitforecast_v2/tests/testthat/test-qdesn-canonical-gap-mcmc-v2.R
```

Outside the promotion directory, the exact closeout-owned changed files are:

```text
validation/fitforecast_v2/docs/QDESN_CANONICAL_GAP_MCMC_V2_PROMOTION_PLAN_2026-08-21.md
validation/fitforecast_v2/docs/QDESN_CANONICAL_GAP_MCMC_V2_INTEGRATION_HANDOFF_2026-08-21.md
validation/fitforecast_v2/scripts/promote_qdesn_canonical_gap_mcmc_v2.R
validation/fitforecast_v2/scripts/verify_qdesn_canonical_gap_mcmc_v2_promotion.R
validation/fitforecast_v2/tests/testthat/test-qdesn-canonical-gap-mcmc-v2-promotion.R
```

Together, the 14 campaign implementation files, 124 promotion files, and five
closeout files form the complete 143-file task-branch delta from the shared
validation target.

## Article-safe publication branch

- Article worktree:
  `/data/jaguir26/local/src/Article-Q-DESN---Version-2__wt__independent_canonical_gap_v9_20260821`
- Branch: `work/independent-validation-canonical-gap-v9-20260821`
- Upstream: `origin/work/independent-validation-canonical-gap-v9-20260821`
- Base: `origin/main` at `90692f3f26f816b0d3bbf34026eb00205ac43790`
- Head: `032f7b00662078d4207a630a500dc258904c20d9`
- Relationship to base: 0 behind, 1 ahead

Exact article-safe changed files:

```text
application/config/independent_validation_trainonly_v1.yaml
docs/implementation_notes/independent_validation_canonical_gap_v9_article_promotion_20260821.md
figures/independent_simulation/qdesn_mcmc_metric_envelope_heatmap.pdf
main.tex
qdesn-supplement.tex
scripts/build_independent_validation_trainonly_article.R
scripts/check_independent_validation_trainonly_article.R
tables/qdesn_validation_500obs_trainonly_summary.csv
tables/qdesn_validation_mcmc_figure_data.csv
tables/qdesn_validation_mcmc_figure_manifest.txt
tables/qdesn_validation_tt500_final_combined.tex
tables/qdesn_validation_tt500_final_gausmix.tex
tables/qdesn_validation_tt500_final_manifest.txt
tables/qdesn_validation_tt500_final_mcmc_gausmix.tex
tables/qdesn_validation_tt500_final_mcmc_normal.tex
tables/qdesn_validation_tt500_final_normal.tex
tables/qdesn_validation_tt500_final_summary.csv
tables/qdesn_validation_tt500_mcmc_current_best_manifest.txt
```

No validation fitting code, application code, joint-validation asset, PriceFM
asset, or GloFAS asset changes on the article branch.

## Verification

- Frozen-design test: 11/11 expectations passed
- v9 promotion test: 10/10 expectations passed
- Standalone promotion verifier: PASS
- Article interface: 72 rows
- Promoted forecast roles: 4
- Article changes from rendered v6: 8 cumulative roles
- Source ledger: 119/119 rows verified
- Article consumption gate: PASS
- Storage gate: PASS
- Article build/check gate: PASS, 72 rows, 36 VB, 36 MCMC, 108 figure cells, 0 ridge rows
- Deterministic regeneration: all four generated manifest/figure hashes stable across two builds
- Main article: 42 pages; final log clean
- Supplement: 39 pages; no undefined references/citations; one pre-existing 0.66-point overfull heading outside this change
- Visual inspection: updated tables, heatmap, companion table, and prose passed
- `git diff --check`: PASS

## Storage and exclusions

- Compact tracked promotion packet: 2.1 MB
- `.rds`, `.rda`, or `.RData` files in packet: 0
- Fitted-model payloads: 0
- Runtime logs remain excluded under:
  `reports/shared_fitforecast_v2_orchestration/qdesn_canonical_gap_mcmc_v2_20260820_003025*`
- Ignored article compilation evidence remains excluded under:
  `local_trackers/independent_validation_v9_article_compile_20260821/`

Do not publish runtime reports, local trackers, fitted objects, or any files
from another scientific lane.

## Required integration order

1. Merge or fast-forward this validation branch into
   `validation/shared-fitforecast-v2-1.0.0` and verify the promotion packet.
2. Merge article branch
   `work/independent-validation-canonical-gap-v9-20260821` into the latest
   Article-v2 `origin/main`.
3. Run the article builder and checker without `--validation-root`; the default
   shared-validation root must now resolve v9.
4. Compile and inspect both manuscripts.
5. Publish the article-only snapshot to GitHub and direct Overleaf through the
   integration coordinator.

This lane must not merge or push Article-v2 `main`, the shared-validation
integration target, or either Overleaf branch itself.

**READY_FOR_INTEGRATION**

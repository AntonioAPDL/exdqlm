# Independent Q-DESN forecast-gap v8 integration handoff

## Scope and ownership

This handoff belongs only to the independent single-quantile Q-DESN/DQLM
validation lane. It does not authorize edits to joint-QDESN, PriceFM, GloFAS,
application code, article `main`, or Overleaf. Article publication remains the
responsibility of the Article Q-DESN integration lane.

| Field | Frozen value |
|---|---|
| Lane | Independent Q-DESN/DQLM validation |
| Transcript | `/home/jaguir26/.codex/sessions/2026/05/15/rollout-2026-05-15T18-06-50-019e2dad-9160-7421-a3ae-4c5b3b1410ca.jsonl` |
| Worktree | `/data/jaguir26/local/src/exdqlm__wt__qdesn_forecast_gap_adaptive_mcmc_v1_1p0p0` |
| Branch | `validation/qdesn-forecast-gap-adaptive-mcmc-v1-1.0.0` |
| Upstream | `origin/validation/qdesn-forecast-gap-adaptive-mcmc-v1-1.0.0` |
| Shared-validation base | `f7d57b17997bea461faf6f5bfc6213c33fa2fd1e` |
| Frozen scientific payload | `93157ace7305d87aa3a46e1b5361eb47dca2c229` |
| Relationship to base | Fourteen task-owned commits; base is an ancestor |
| Article authority at read-only audit | `9559e354e83f0edaf82e3add4c590dbdc378a64e`, clean |

The exact 530-file diff through the frozen scientific payload is recorded in
`QDESN_FORECAST_GAP_ADAPTIVE_MCMC_V8_INTEGRATION_CHANGED_FILES_2026-08-19.csv`.
The changed-file ledger and this handoff are the only files added after the
scientific payload freeze.

## Campaign completion

| Stage | Completed | Failed |
|---|---:|---:|
| Smoke | 2/2 | 0 |
| Calibration | 8/8 | 0 |
| Discovery | 184/184 | 0 |
| Replication | 64/64 | 0 |
| Sealed evaluation | 96/96 | 0 |
| Canonical confirmation | 24/24 | 0 |
| Total | 378/378 | 0 |

| Execution field | Frozen value |
|---|---|
| Run ID | `qdesn_forecast_gap_adaptive_mcmc_v1_20260818_214229` |
| Run tag | `qdesn-forecast-gap-adaptive-v1-20260818_214229__git-e842a64` |
| Scientific design commit | `e842a6438839a7f70345dc7df1c448f887e5eeed` |
| Confirmation recovery commit | `a17b16836efc21393b2000202206a3edf67617ae` |
| Closeout implementation commit | `19be51cace8afbac1a8345a3f6e9dccf109ce739` |
| Confirmed candidates | 8 case-specific candidates |
| Canonical chains | 24/24 successful |
| Iterations | 5,000 burn-in plus 20,000 retained per chain |
| Final progress | 25,000/25,000 for every chain |
| exAL sampler | Exact `M0_v_collapsed_support_logit` |
| AL transition | `sigma_then_gamma` |
| Threads | One per chain |
| Active lane processes or tmux sessions | 0 |
| Remaining or failed jobs | 0 |
| Fitted-model binary payloads | 0 |

The 24 unique canonical chains have 11 `PASS` and 13 `WARN` signoffs. The
metric-role chain ledger has 33 rows because some chains contribute two target
metrics; that denominator has 13 `PASS` and 20 `WARN` rows. Diagnostics are
retained as descriptive evidence and were not a promotion veto, as requested.

## Scientific decision

The v8 interface inherits all 72 rows of the v7 authority and changes exactly
three case-specific MCMC forecast metric roles. Each promoted value is the
arithmetic mean of three successful full-budget chains, and all three chains
strictly improve the corresponding frozen v7 value.

| Model and cell | Metric | Frozen v7 | Confirmed mean | Relative gain | Improved chains |
|---|---|---:|---:|---:|---:|
| Q-DESN AL-RHS, Gaussian mixture, p=0.50 | Forecast oracle-quantile MAE | 2.367920628 | 0.907368829 | 61.68% | 3/3 |
| Q-DESN AL-RHS, Gaussian mixture, p=0.50 | Forecast check loss | 5.585104931 | 5.441483448 | 2.57% | 3/3 |
| Q-DESN AL-RHS, Gaussian, p=0.05 | Forecast check loss | 1.263697821 | 1.220899633 | 3.39% | 3/3 |

All fit metrics and every nonwinning forecast role remain at v7. No exQ-DESN
exAL-RHS role improved in this campaign. This is a case-specific metric
envelope, not a claim that one DESN specification is globally optimal.

The currently rendered article still reflects v6. Therefore the complete v8
article interface has five numeric deltas relative to the rendered table:

1. The three v8 improvements above.
2. The inherited v7 exQ-DESN exAL-RHS Gaussian-mixture p=0.25 forecast MAE,
   from 3.396454525 to 1.819330730.
3. The inherited v7 exQ-DESN exAL-RHS Gaussian-mixture p=0.25 forecast check
   loss, from 4.586349412 to 4.488089789.

The integration lane must consume the complete v8 interface once. Applying
only the three new v8 rows would omit the two unrendered v7 gains.

## Immutable evidence

Promotion root:

`validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_trainonly_article_v8_forecast_gap_adaptive_20260819`

| Artifact | SHA-256 |
|---|---|
| Article interface | `56d930b97a66a69f2a2ddfc945eeaeea2518c479490acf04611a9a2941593acc` |
| Promotion decision ledger | `ad3351c0dd2e82877def4b5f0c6173b28409bf86ce294742cd7bd0ba547111ee` |
| Article delta ledger | `153534e74d81688beaec974ab5a7039cab8d3ee822964153d76db52346c76d7c` |
| Remaining-gap ledger | `bedb6388389b66f243cdc94286cbee802fe69e3013d85707d61ad4d5960e38b8` |
| Source ledger | `de65a25ba53b9372ea02a49fbf994d05e5996e32349ccbf20227f0b125f7a37c` |
| Promotion manifest | `49daad634ac060f6d845a248b8bc57e0ccb77971a7fd6b543b4c010fb63f4cd1` |
| Output-file manifest | `68938e37a61848e8baf7432d5490612d916a041510ef32d6682de94de3e11a3d` |
| Scientific changed-file ledger | `bb7fbad89dee6ee3eeb52af19b2e9e830373a5f520c4e38a15286bb867ee8a79` |

The tracked promotion packet contains 392 files totaling approximately 7.2
MiB. It contains no `.rds`, `.rda`, or `.RData` payload and no file larger than
204,352 bytes. Historical absolute paths retained inside frozen job metadata
are provenance fields; all package resolution and hash verification use the
portable relative source ledger.

The ignored campaign report root contains 562 files and 10.788 MiB, with no
serialized model payload. The ignored runtime result root contains 10,962
compact files totaling 1,661,289,275 bytes (1.547 GiB), with no serialized
model payload and a maximum file size of 5,213,609 bytes. Retain both ignored
roots through integration. They may be compacted only after the tracked v8
packet has been merged and independently verified.

## Verification record

| Check | Result |
|---|---|
| Source-loaded environment | R 4.6.0 and exdqlm 1.0.0; pass |
| Focused forecast-gap `testthat` suite | Pass with no skips, failures, or warnings |
| v7 inherited-authority verifier | Pass: 72 rows, 2 promoted roles, article-consumption and storage checks pass |
| v8 promotion verifier | Pass: 72 rows, 3 new roles, 5 rendered-v6 deltas, 389 provenance rows |
| Canonical confirmation verifier | Pass: 24/24 chains and 13/13 runtime checks |
| Tracked implementation manifest | 35/35 files exist; 35/35 sizes and hashes match |
| Promotion output/source hashes | Pass |
| Storage-light contract | Pass |
| `git diff --check` | Pass |
| Active-process audit | No process or tmux session for this campaign |

The shell's ambient R library contains an older development package. This
campaign does not use that library entry: its worker source-loads this worktree
with `pkgload::load_all()`, which was rechecked under R 4.6.0 and resolves
exdqlm 1.0.0. The distinction is documented here to prevent an integration
check from accidentally testing the wrong installation.

## Integration instructions

1. Fetch this task branch and verify that it is clean and exactly synchronized
   with its upstream.
2. Merge it with normal command-line Git into the latest shared independent
   validation authority. Do not merge it into `exdqlm/main`.
3. Re-run the focused test file, v7 and v8 promotion verifiers, canonical
   confirmation verifier, and manifest checks after the merge.
4. In the authoritative article repository, consume the complete 72-row v8
   interface through the existing independent-validation table builder. Apply
   exactly the five rows in `article_delta_from_rendered_v6.csv`.
5. Verify that no unrelated joint-QDESN, PriceFM, GloFAS, or application files
   changed. Compile the main article and supplement in the integration lane.
6. Commit and push article `main`, rebuild the article-only snapshot, and push
   direct Overleaf only from the integration lane.
7. After publication verification, recompute the remaining-gap ledger from v8.
   Do not launch more screening from a stale v6 or v7 table.

No article file was modified by this validation chat. The article-safe inputs
are the v8 interface, article-delta ledger, promotion-decision ledger,
remaining-gap ledger, source ledger, manifests, and this handoff.

## Residual scientific risks and next action

- The promoted rows support metric-envelope comparisons, not posterior
  uncertainty claims for every chain.
- Q-DESN/exQ-DESN still trail DQLM/exDQLM for several forecast roles. The
  remaining-gap ledger is the sole valid basis for any future search.
- Pre-M0 exAL screens must not be treated as definitive DESN-specification
  failures because poor gamma mixing confounded those runs.
- The current campaign is complete. The optimal immediate action is integration
  and article regeneration, not another launch. Any later campaign should be a
  new branch from the post-integration shared authority and should target only
  positive v8 forecast gaps with exact M0 for exAL.

**READY_FOR_INTEGRATION**

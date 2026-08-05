# Q-DESN 500-Observation VB Train-Only Rebaseline V1

## Decision

The article-facing Q-DESN variational-Bayes rows must be re-estimated before
they can be combined with the corrected MCMC evidence. The historical VB fits
used the shared pre-repair preprocessing path, which estimated scaling
parameters from the full analysis block. The corrected protocol estimates all
preprocessing quantities from rows available through the forecast origin only.

This is an exact-design replay, not a new hyperparameter screen. It preserves
the 18 case-specific RHS designs currently supplying the article table:

- 9 Q-DESN AL-RHS cells;
- 9 Q-DESN exAL-RHS cells;
- three simulation families and quantile levels 0.05, 0.25, and 0.50;
- one exact historical design per model-family-quantile cell.

## Frozen Protocol

- Package: `exdqlm` 1.0.0.
- Source registry identity:
  `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`.
- Main source length: 10,000 after a 2,000-observation warmup.
- Effective training target indices: 8501--9000.
- Forecast origin: 9000.
- Forecast block: 9001--10000.
- Rolling-origin maximum lead: 30.
- Origin stride: 30.
- No refit at each forecast origin.
- Preprocessing fit rows within the staged 1,890-row analysis block: 1--890.
- Held-out responses and covariates are excluded from preprocessing estimates.

## Exact-Design Handoff

Every selected historical fit request must remain present and hash-verifiable.
The materializer reads the effective configuration from those requests and
freezes:

- DESN depth, layer width, reduction width, lag order, alpha, rho, sparsity,
  input sparsity, washout, bias flag, and reservoir seed;
- RHS `tau0`;
- likelihood family;
- LDVB controls: `max_iter = 150`, `min_iter_elbo = 40`, and
  `n_samp_xi = 500`;
- frozen source identities and source-window metadata.

Fresh deterministic execution and synthesis seeds are assigned so the replay
is a new run while preserving the winning reservoir realization.

## Gates

The staged workflow is:

1. materialize and hash all contracts;
2. verify package, source, request, window, preprocessing, budget, and storage
   contracts;
3. prepare-only manifest generation;
4. two-root smoke containing one AL and one exAL fit;
5. smoke contract audit;
6. 18-root full VB replay;
7. closeout and legacy comparison;
8. manual article review.

No article row is updated automatically. A complete closeout requires all 18
specifications, finite fit and H=100/H=1000 forecast metrics, exact source and
preprocessing provenance, the frozen LDVB budget, seed agreement, and no
successful `.rds`, `.rda`, or `.RData` payloads.

## Ridge Policy

The historical ridge rows also predate the preprocessing repair. They must not
be mixed into a corrected primary table. The primary scientific comparison is
therefore narrowed to DQLM, exDQLM, Q-DESN AL-RHS, and Q-DESN exAL-RHS. Ridge
remains historical sensitivity evidence until an independently approved exact
train-only replay is completed.

## Article Policy

Article integration is allowed only after a complete closeout. It must be done
in a clean worktree based on the then-current authoritative
`Article-Q-DESN---Version-2` `origin/main`. The old article repository and dirty
application worktrees are read-only context. The article must record immutable
run tags, commits, source hashes, metric artifact hashes, and the train-only
preprocessing scope while keeping repository mechanics out of reader-facing
prose.

## Completion Record

The exact replay completed on 2026-08-05. The full run tag is
`qdesn-vb-trainonly-v1-full-20260805_025823__git-df1233a`. All 18 requested
Q-DESN/exQ-DESN VB cells completed successfully and satisfied the source,
window, seed, budget, and train-only preprocessing contracts. The diagnostic
summary is 17 PASS and 1 WARN, with no retained `.rds`, `.rda`, or `.RData`
payloads.

The corrected VB closeout is frozen inside:

`validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_trainonly_article_v1_20260805/vb_closeout`

The combined article handoff is:

`validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_trainonly_article_v1_20260805/qdesn_dqlm_500obs_trainonly_article_v1_20260805_interface.csv`

Its SHA-256 is
`dff814fab1e920c10760645ac9e8d37dfa7f33ae2afba34ee8ed2a5509f4952a`.
The handoff contains exactly 72 rows: four displayed models, three innovation
families, three target quantile levels, and two inference methods. It combines
the corrected 18-cell VB replay, the corrected 18-cell MCMC envelope, and the
validated DQLM/exDQLM baselines. Historical ridge rows are excluded until they
are independently replayed under the corrected preprocessing contract.

The orchestration attempts
`qdesn_vb_trainonly_rebaseline_v1_20260805_025413` and
`qdesn_vb_trainonly_rebaseline_v1_20260805_030205` are aborted and must not be
consumed. Only the full run tag above and the immutable handoff are eligible
for article generation.

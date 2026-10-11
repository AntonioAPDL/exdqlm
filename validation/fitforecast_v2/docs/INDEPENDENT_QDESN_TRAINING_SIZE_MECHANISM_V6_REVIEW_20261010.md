# Independent Q-DESN training-size mechanism v6 review

## Purpose

This review layer evaluates the frozen v6 mechanism campaign without changing
its plans, configurations, statuses, selection rules, or evidence. It lives in a
separate worktree because the active scheduler sources code from its campaign
worktree. Editing that worktree during execution would invalidate the frozen
source hashes.

## Scientific contract

- Interim results are diagnostic and cannot be promoted.
- The article holdout at source indices 9,001--10,000 remains unavailable to
  selection.
- The existing representation, quantile, validation, rolling-readout, and MCMC
  gates remain unchanged.
- Forecast MAE is the primary decision criterion. Diagnostic grades remain
  disclosed but are not metric vetoes.
- Every completed worker manifest is verified before a review is accepted.
- The review records both the frozen campaign commit and the analysis commit.

## Outputs

The reviewer creates a self-contained, hashed packet containing:

1. stage health and completion balance;
2. representation quality by training size;
3. completed two-fold quantile ranks and case-specific winners;
4. instability by architectural role;
5. matched four-fold Q-DESN-to-DQLM ratios;
6. rolling-readout summaries when that gate is activated;
7. all-metric and primary forecast-MAE MCMC comparisons;
8. a compact Markdown review and artifact manifest.

`interim` mode permits incomplete stages and recommends continued execution.
`final` mode requires a closeout, no active or pending jobs, no failures, and
complete plans. Neither mode edits the source campaign.

## Execution

```bash
Rscript validation/fitforecast_v2/scripts/review_independent_qdesn_training_size_mechanism_v6.R \
  <review-worktree> <campaign-run> <ignored-output-directory> interim
```

After the scheduler closes, rerun with `final`. Review packets belong under an
ignored `local_trackers` directory until the integration coordinator decides
whether a final scientific handoff is warranted.

For unattended completion, the companion watcher can wait for the frozen
campaign closeout and invoke strict final mode automatically:

```bash
bash validation/fitforecast_v2/scripts/watch_independent_qdesn_training_size_mechanism_v6_review.sh \
  <review-worktree> <campaign-run> <ignored-final-output-directory> 300
```

The watcher records both initial commits, requires a clean review worktree,
blocks if either commit changes or the scheduler pauses, and otherwise sleeps
between checks. It does not consume a model core or alter the campaign.

## Post-campaign decision

- If every matched MCMC forecast-MAE ratio is at most 1.10, prepare a separate
  full 18-cell confirmation campaign. Do not publish automatically.
- If any ratio remains above 1.10, retain v6 as diagnostic evidence. Use the
  oracle, static-readout, and rolling-readout decomposition to identify the
  next mechanism; do not return to undirected reservoir-size escalation.
- Oversized candidates that are unstable under matched quantile VB are evidence
  against brute-force capacity growth, not evidence against moderate-depth
  reservoirs with controlled readout dimension.

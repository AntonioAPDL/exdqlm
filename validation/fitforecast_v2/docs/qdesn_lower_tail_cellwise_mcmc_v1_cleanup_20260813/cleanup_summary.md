# Q-DESN lower-tail cellwise MCMC v1 storage cleanup

- Mode: `execute`
- Generated: `2026-08-13 03:53:48 UTC`
- Branch: `validation/qdesn-lower-tail-cellwise-mcmc-v1-1.0.0`
- HEAD: `54bd412d5673e63851ae701ca7a4d99dac2ceb4b`
- Campaign: `qdesn-lower-tail-cellwise-mcmc-v1-tiera-20260811_215538__git-c050ccf`
- Campaign roots verified: `218/218` SUCCESS
- Canonical confirmation roots protected: `6/6`
- Deletion candidates: `1272` files, `0.552 GiB`
- Progress traces: `218` files, expected recovery `0.101 GiB`
- Total expected recovery: `0.653 GiB`
- Actual recovery: `700730628` bytes (`0.653 GiB`)
- Result tree: `1015909631` bytes before, `315179003` bytes after
- Remaining eligible deletion files: `0`
- Forbidden fitted-model binary payloads under jobs: `0`
- Protected confirmation files currently present: `174`
- Frozen source archives retained: `126` files (`29039986` bytes)
- Compact metric equivalence: `204/204` rows, maximum absolute difference
  `4.7961634663806763e-14`
- Post-cleanup verification: `PASS` (`13/13` checks)

The cleanup preserves every source archive/window, canonical confirmation root,
configuration, manifest, status, log, scalar metric, lead-level summary, ranking,
verification record, and closeout file. It removes only hash-recorded raw traces
and dense path exports from the 212 closed non-confirmation roots. Progress traces
retain their first, final, and every 50th iteration; status files are untouched.

## Evidence

- `artifact_classification.csv`
- `cleanup_dry_run_delete_manifest.csv`
- `cleanup_dry_run_progress_manifest.csv`
- `cleanup_removed_files.csv`
- `progress_trace_compaction_audit.csv`
- `compact_metric_equivalence_audit.csv`
- `post_cleanup_verification.json`

# Q-DESN train-only mechanism v1 legacy-output cleanup

- Audit time (UTC): `2026-08-05T19:55:25Z`
- Mode: `execute`
- Scoped owner: independent single-quantile Q-DESN fit+forecast validation
- Candidate files: `7946`
- Candidate bytes: `5322171042` (`4.957 GiB`)
- Removed files: `7946`
- Removed bytes: `5322171042` (`4.957 GiB`)
- Remaining eligible files after this invocation: `0`
- Disk after invocation: `/dev/md0        916G  270G  600G  31% /data`

## Scope guard

Only seven whitelisted duplicate CSV basenames below the exact origin-7000/origin-8000 legacy roots were eligible. Source objects, final origin-9000 evidence, scalar metrics, lead summaries, chain diagnostics, statuses, failures, logs, manifests, promotion records, and current campaign files were retained.

## Evidence

- Classification: `legacy_cleanup_classification.csv`
- Candidate manifest: `legacy_cleanup_dry_run.csv`
- Removal ledger: `legacy_cleanup_removed.csv`

# Q-DESN Branch Sync Ledger

Date: 2026-06-02

This ledger defines the package-side synchronization policy for the Q-DESN
development line. It deliberately excludes the non-Q-DESN JSS/release branch.

## Scope

In scope:

- Q-DESN package code, validation code, and Q-DESN-specific helper scripts.
- Article-facing Q-DESN engine contracts and reproducibility pins.
- Older Q-DESN branches, but only as evidence or targeted patch sources.

Out of scope:

- `work/exdqlm-article-1.0.0`
- `origin/feature/1.0.0-jss`
- CRAN/JSS release metadata unless it is independently required by Q-DESN.

## Canonical Branch

The current package-side Q-DESN source of truth is:

```text
branch: validation/shared-fitforecast-v2-1.0.0
worktree: /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0
current audited commit: 17eb1a4ad25117fde5f336cdf921429f8515ef5b
```

Do not edit the live worktree above while long-running validation jobs are
active. Use a separate worktree for audits, cherry-picks, and tests.

## Branch Classification

| Branch | Status | Action |
|---|---|---|
| `validation/shared-fitforecast-v2-1.0.0` | Canonical | Keep as the Q-DESN package source of truth. |
| `article/app-engine-73c043f` | Already absorbed | No sync action; retain only for historical application reproducibility. |
| `work/0.4.0-article-main` | Narrow candidate | Audit commit `2bc524f` for the truncated-normal entropy sign fix. Import only if canonical behavior lacks it. |
| `feature/glofas-discrepancy-qdesn` | Optional candidate | Source for old package-side `qdesn_fit_discrepancy()` only. Do not import unless we intentionally promote origin-state discrepancy fitting back into the package. |
| `feature/qdesn-fitforecast-validation-0p5p0` | Historical validation | Use for provenance/schema comparison only. Do not merge. |
| `validation/fit-forecast-shared-dynamic-0.5.0` | Historical validation | Use for provenance/schema comparison only. Do not merge. |
| `feature/qdesn-mcmc-alternative*` | Historical/probe | Mine only if a specific missing feature is identified. Do not merge wholesale. |
| `validation/rerun-after-0.4.0-sync*` | Historical/probe | Mine only if a specific missing validation repair is identified. Do not merge wholesale. |
| `origin/esn-server` | Archive/source-history | Use only for lineage checks around old ESN/Q-DESN APIs. |
| `origin/feature/real-pipeline-split` | Archive/source-history | Use only for lineage checks around old pipeline split work. |

## Sync Rules

1. Never broad-merge an old Q-DESN branch into the canonical branch.
2. Audit one feature or fix at a time.
3. Prefer manual adaptation when branch context is old or contains unrelated
   validation artifacts.
4. Every imported patch must include a focused test or a documented reason why
   an existing test covers it.
5. Article configuration pins must be updated only after the package patch is
   committed, tested, and pushed.
6. Historical Article configs should preserve old pins for reproducibility, but
   they must not be described as active launch configs.

## Current High-Priority Checks

| Priority | Candidate | Why | Gate |
|---:|---|---|---|
| 1 | `2bc524f` from `work/0.4.0-article-main` | Single numerical fix: truncated-normal entropy sign. | Prove canonical already covers it or add equivalent focused test/fix. |
| 2 | Article active engine pins | Active GloFAS configs should point to canonical Q-DESN commit; historical configs may keep old pins. | Article-side pin audit must classify every config. |
| 3 | `feature/glofas-discrepancy-qdesn` package export | Old package-side discrepancy fitter may be useful later, but active latent-path GloFAS fitting is article-side. | Defer unless a package-level discrepancy API is explicitly required. |

## Live-Run Safety Gates

Before package-side implementation work:

- Check for active validation sessions with `tmux ls` and process search.
- If validation is active, work only in a separate worktree.
- Do not edit the live canonical worktree while it is launching or supervising
  validation jobs.

Before Article-side implementation work:

- Check for active GloFAS application runs.
- Check for dirty PriceFM files.
- Use a separate Article worktree for Q-DESN sync work when either is present.

## Reproducible Audit Command

From an isolated package worktree:

```bash
Rscript scripts/audit_qdesn_branch_sync.R \
  --output-dir validation/qdesn_sync/generated/manual_audit
```

The generated directory is ignored by git. Commit only the ledger, scripts, and
tests that define the sync policy.

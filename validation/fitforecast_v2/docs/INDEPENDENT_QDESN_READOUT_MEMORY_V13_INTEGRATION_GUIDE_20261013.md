# IND QDESN v13 Integration Guide

## Coordinator Scope

Integrate the frozen IND scientific lane into the latest **exdqlm shared
validation authority**, not directly into Article-v2 or the exdqlm release
main. This is a completed negative-average-result mechanism screen with
retained local improvements. Publish no article metric, table, figure or
prose replacement. Do not open its conditional compute stages.

The final, post-push frozen packet is under:
`validation/fitforecast_v2/local_trackers/independent_qdesn_readout_memory_v13_handoff_20261013`.
Its `HANDOFF.md` and `handoff.json` contain the full final HEAD, fresh remote
read-back, ancestry and precise inventories. Those files are generated after
the compact closeout commit to avoid self-referential commit hashes.

## Lane and Repository

- Lane: IND QDESN VAL, independent single-quantile simulation validation only.
- Transcript for this resumed closeout:
  `/home/jaguir26/.codex/sessions/2026/10/13/rollout-2026-10-13T15-53-00-01a136d3-4e13-7183-b86d-ec138faa04e1.jsonl`.
- Worktree:
  `/data/jaguir26/local/src/Article-Q-DESN/.worktrees/ind_qdesn_readout_memory_v13_20261013`.
- Repository common Git directory: `/data/jaguir26/local/src/exdqlm/.git`.
  The worktree's physical location does not make it an Article-Q-DESN Git branch.
- Branch: `validation/independent-qdesn-readout-memory-v13-20261013`.
- Upstream: `origin/validation/independent-qdesn-readout-memory-v13-20261013`.
- Frozen model/scoring source: `5abb3db6a5b8c0559daf5ab125a654143f398ffa`.
- Pre-v13 scientific parent: `5c37ab3669d67c1d698e0ea801cefa89f6a84198`.
- Observed shared-validation target before closeout:
  `5b85bb3a3894a88968e4987f330e3ec66711f9c7` on
  `origin/validation/shared-fitforecast-v2-1.0.0`.
- Observed exdqlm release main: `e51045a4324901cced27ca2aaa22569afbc8e0e6`.

Do not substitute release main as the merge target because the two authorities
have different ancestry and responsibilities. Re-fetch only in the coordinator's
integration workflow and reconcile any subsequently advanced shared target.

## Important Ancestry Warning

Before this closeout the task branch was a 66-commit descendant of the shared
target, with 255 changed files. That includes IND predecessor campaigns,
package helpers, tests and docs; it is **not** a five-file v13-only delta.
The new closeout adds tested tools and compact audit metadata without modifying
the frozen model/scoring files. The final packet enumerates the exact final
unique commits and changed files, rather than assuming old counts still apply.

Some predecessor scientific work may already have been integrated through
different commits. Review semantic overlap, especially `R/` package helpers,
`scripts/pipeline_real_main.R`, `man/` and shared validation adapters. Preserve
other lanes' newer changes. Do not overwrite them wholesale, reset another
worktree, squash away the evidence ancestry, or force-push.

Recommended order: reconcile the pending predecessor history first, preserving
its v11/v12 dependencies, then review v13 implementation and the two new
closeout commits. The coordinator may merge the full branch through an explicit
merge after combined testing, or explain a narrower integration choice.
Any dependency-conscious selective integration must preserve the required
source/evidence provenance; cherry-picking only the final data commit would
not bring the code needed to reproduce its audit.

## Scientific Handoff

- 42/42 newly launched logical jobs successful, zero implementation failures.
- No workers/scheduler remain; 72 conditional jobs are declined without launch.
- Eight matched controls reused, not eight extra refits.
- Gaussian-mixture, AL-RHS_NS, p=0.05; gamma fixed zero, not an exAL M0 test.
- Five contrasts: half tau0, quarter slab variance scale, both, and two
  alpha/rho memory contrasts. All retain the 141/119/90-state architecture,
  360 output lags, identity Q, no raw inputs at readout and case-specific priors.
- No new candidate improves average forecast MAE or observed check loss over
  static. tau_half is only the best new candidate, not an overall winner.
- All 20 local strict metric-cell gains, including nine forecast gains,
  remain in the compact ledger. No diagnostic flag or minimum effect cutoff
  erased a finite gain. Local seed/fold winners are not article replacements.
- Aggregate uncertainty widths differ in posterior coupling across Q-DESN and
  DQLM. Do not reinterpret narrower score intervals as proven model superiority.
- Decision: `NO_AVERAGE_PRIMARY_FORECAST_GAIN_RETAIN_EXISTING_ARTICLE_AUTHORITY`.
- Compact tracked evidence:
  `validation/fitforecast_v2/audits/independent_qdesn_readout_memory_v13_20261013`.
- Tracked scientific explanation:
  `validation/fitforecast_v2/docs/INDEPENDENT_QDESN_READOUT_MEMORY_V13_CLOSEOUT_20261013.md`.

## Verification and Merge Gates

The final packet records the actual passed checks, not a claim of a clean
full historical/package suite. It includes 55 focused v13 checks, 19 focused
closeout checks, campaign/control manifests, 28 independent score reconstructions
within 1e-6, and 192/192 primary first-step guards. The portable compact
artifact manifest resolves relative to its own directory; the runtime index
requires this server's retained absolute evidence paths.

In an isolated integration worktree:

1. Verify the pushed branch hash against the frozen packet and inspect its
   exact unique-commit/file inventories before attempting a merge.
2. Verify compact artifact hashes and the original runtime closeout manifest
   using the source worktree. Do not edit old manifests to make a test pass.
3. Review inherited package-helper changes and run the relevant package tests,
   shared validation adapter tests and v13/closeout checks against the combined
   tree. Existing tests with compacted archived fixtures may require separate
   documented evidence, not pretending they passed.
4. Preserve numerical inference/scoring hashes. Any necessary integration
   repair gets a new supplemental manifest and clear provenance rather than
   rewriting the frozen scientific source or relabeling its result.
5. Advance shared-validation authority only after the coordinator's merge
   checks. Record the resulting merge/target hash. Article authority and
   Overleaf remain untouched because no article replacements are authorized.

All Git operations use the command line, not GitHub/Overleaf extensions.
No token from chat is needed for this validation-only integration.

## Runtime Exclusions and Protection

Do not add to Git or Overleaf: any `local_trackers/` content, model/path draws,
source trajectories, review PDFs, logs, compiled cache, installed R library,
or new forecast/refit outputs. No fitted RDS/RDA/RData payload is present in
the completed run. Retain the original run, original completion audit,
imported v12 controls/parent and pinned library; the runtime closeout lists
their protected paths. This closeout deletes nothing.

The stop marker and closeout supersede the original conditional-stage hint.
Do not remove the marker, call `continue`, create C/fresh plans, change article
results, launch the proposed later-prefix pilot or begin another screening
without a new explicit user decision.

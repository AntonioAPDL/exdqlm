# Jerez -> Muscat Transition Plan

Last updated: 2026-03-11

## Purpose

Move the active `exdqlm` development and remaining validation backlog from `jerez`
to `muscat` with minimal disruption, while leaving the current long-running
validation jobs on `jerez` alone unless there is an explicit decision to stop and
restart them.

This is a temporary execution plan, not a long-term architecture note.

## Current machine roles

### Jerez

Keep on `jerez`:

- current `GEFS` download / forecasting work
- current unified multimodel workflow work
- `project1_ucsc_phd`
- the currently running `family-qspec` validation sessions until they finish

Why:

- `jerez` is currently CPU-saturated
- `project1_ucsc_phd` has local changes you do not want to migrate right now
- the current `qsp_*` jobs already have partial MCMC progress and should not be
  thrown away casually

### Muscat

Move to `muscat`:

- main `exdqlm` package development
- remaining not-yet-launched family-qspec validation backlog
- qdesn-related `exdqlm` branch/worktree work
- future validation runs and heavy compute for `exdqlm`

Why:

- `muscat` is nearly idle:
  - `64` CPUs
  - about `495 GiB` available memory
  - load near `0`

## Important current facts

### Jerez resource state

- `jerez` is heavily CPU-saturated
- no zombie-process problem was found
- no significant idle-core pool was found
- the six static `qsp_*` resume jobs are genuinely active and oversubscribed

Conclusion:

- do **not** start more heavy `exdqlm` validation work on `jerez`

### Current `exdqlm` validation sessions on jerez

Running now:

- `qsp_rsp100_20260310_204439`
- `qsp_rsp1k_20260310_204439`
- `qsp_rss100h_20260310_204439`
- `qsp_rss100r_20260310_204439`
- `qsp_rss1kh_20260310_204439`
- `qsp_rss1kr_20260310_204439`
- `qsp_rdy500_fix_20260311_173314`
- `qsp_rdy5k_fix_20260311_173314`

These should be treated as live in-flight jobs on `jerez`.

### Scheduler state

- the deferred `family-qspec` scheduler previously started on `jerez` has already
  been stopped
- no queued follow-on backlog will auto-launch on `jerez`

## exdqlm worktree layout to mirror on muscat

Current important local layout on `jerez`:

- base repo:
  - `/data/muscat_data/jaguir26/exdqlm`
  - branch: `feature/benchmark-data-pipeline`
- validation worktree:
  - `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp`
  - branch: `jaguir26/dqlm-conjugacy-cavi-gibbs`
- main worktree:
  - `/data/muscat_data/jaguir26/exdqlm__wt__main`
  - branch: `main`

Recommended muscat target layout:

- `/home/jaguir26/local/src/exdqlm`
- `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`
- `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## Repos in local workspace

Current local repos discovered near the shared workspace:

- `Article-Q-DESN`
- `Corrections---Project-1`
- `DQLM-and-BQR---Theory`
- `Environmetrics_paper_repo`
- `NDLM---Ensemble`
- `Q-DESN---Theory-for-implementation`
- `Static-exAL-Regression---MCMC`
- `Static-exAL-Regression---VB`
- `VB-for-Horseshoe-Regression`
- `antonio-aguirre.github.io`
- `bqrgal-examples`
- `exAL---Regression`
- `exDQLM---Ensemble`
- `exdqlm`
- `exdqlm---Article`
- `project1_ucsc_phd`
- `univ-exDQLM---Ensemble`

Practical migration priority:

1. `exdqlm`
2. `Q-DESN---Theory-for-implementation` if needed soon
3. `Article-Q-DESN` and `exdqlm---Article` if needed
4. other repos later, on demand
5. `project1_ucsc_phd` stays on `jerez`

## What should be pushed vs copied privately vs left alone

### Push to GitHub

Push code and tracker files that belong in the repo:

- committed `exdqlm` fixes already on branch `jaguir26/dqlm-conjugacy-cavi-gibbs`
- any additional scripts/trackers that should become part of the branch

Current relevant local-only `exdqlm` tracker/script files that likely should be
committed if you want them available everywhere:

- `tools/merge_reports/20260310_resume_family_qspec_dynamic_batch.sh`
- `tools/merge_reports/20260310_resume_family_qspec_static_batch.sh`
- `tools/merge_reports/20260311_family_qspec_validation_status_tracker.md`
- `tools/merge_reports/20260311_schedule_remaining_family_qspec_batches.sh`
- this transition note
- the muscat bootstrap prompt note

### Copy privately to muscat, do not push

These are local execution artifacts or result trees:

- `results/function_testing_20260309_static_paper_family_qspec`
- `results/function_testing_20260309_static_shrinkage_family_qspec`
- `results/function_testing_20260309_dynamic_dlm_family_qspec`
- selected `tools/merge_reports/*.log`
- selected `tools/merge_reports/*_20260310_*.tsv`
- `tools/merge_reports/untracked_refs`

Approximate sizes:

- static paper qspec results: about `101M`
- static shrink qspec results: about `156M`
- dynamic qspec results: about `939M`

These are reasonable to `rsync` privately to muscat.

### Leave on jerez

- `project1_ucsc_phd`
- current GEFS / unified workflow working trees
- in-flight `qsp_*` sessions until they finish

## Known branch / local-change caveats

### exdqlm qdesn-side worktree

The base `exdqlm` repo on `jerez` currently has an uncommitted tracked change:

- file: `config/defaults.yaml`
- branch: `feature/benchmark-data-pipeline`

This must be preserved either by:

- committing and pushing it, or
- privately syncing that worktree to muscat

Do not forget this during migration.

### project1_ucsc_phd

`project1_ucsc_phd` is large and locally modified. Current size is about `390G`.
It should remain on `jerez`.

## Muscat bootstrap requirements

### Git / GitHub

Current blocker:

- muscat can be reached by SSH from `jerez`
- muscat currently fails `git@github.com:` access with `Host key verification failed`

So muscat must first:

1. trust GitHub host keys
2. verify GitHub auth over SSH
3. if SSH auth still fails, use a temporary GitHub token only if explicitly desired
   and avoid persisting secrets unnecessarily

### System / tooling

Need to verify or install on muscat:

- `git`
- `tmux`
- `R`
- expected R packages for `exdqlm`
- compiler/toolchain if needed for package compilation
- `Codex` local environment and permissions

### Codex operational requirements

Codex on muscat should:

- have access to the muscat filesystem
- be able to run shell commands freely there
- be able to use SSH/GitHub auth needed for cloning and pushing
- keep local-only outputs out of GitHub
- use detached `tmux` sessions for long-running jobs

## Recommended transition sequence

### Phase 1. Freeze the plan

1. Confirm what stays on `jerez`:
   - `project1_ucsc_phd`
   - GEFS work
   - unified multimodel work
   - current `qsp_*` jobs
2. Confirm what moves to `muscat`:
   - remaining `exdqlm` validation backlog
   - `exdqlm` package work
   - qdesn branch/worktree

### Phase 2. Prepare muscat

1. Fix GitHub SSH trust on muscat
2. Verify GitHub auth on muscat
3. Create muscat source root:
   - `/home/jaguir26/local/src`
4. Clone `exdqlm` on muscat
5. Add the two important `exdqlm` worktrees on muscat
6. Verify `R`, `tmux`, and package/toolchain setup

### Phase 3. Sync code and local artifacts

1. Push all `exdqlm` code/tracker files that should be remote
2. Privately `rsync` result roots and local-only tracker/log artifacts to muscat
3. Preserve the local qdesn-side diff if not yet committed

### Phase 4. Switch future execution

1. Do **not** launch any additional heavy `exdqlm` validation on `jerez`
2. Use muscat for all remaining not-yet-launched family-qspec backlog
3. Keep jerez only for:
   - current in-flight `qsp_*`
   - GEFS
   - unified
   - `project1_ucsc_phd`

### Phase 5. Retirement of jerez exdqlm compute

After the current `qsp_*` jobs finish on `jerez`:

1. copy any final local-only outputs to muscat if needed
2. mark the jerez validation sessions closed
3. treat muscat as the main `exdqlm` compute home

## Do-not-do list

- do not kill the current `qsp_*` jobs casually
- do not launch the remaining backlog on `jerez`
- do not push local-only result trees to GitHub
- do not migrate `project1_ucsc_phd` right now
- do not forget the uncommitted qdesn-side `config/defaults.yaml` change

## Immediate next actions

1. create and review the muscat bootstrap prompt
2. run the muscat bootstrap/setup steps there
3. clone `exdqlm` and create the muscat worktrees
4. decide which local-only exdqlm artifacts to `rsync`
5. only then launch new validation work on muscat

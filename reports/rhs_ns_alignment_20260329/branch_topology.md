# Wave 0 Branch Topology and Baseline Snapshot

Generated: 2026-03-29 09:21:11 EDT

## Commands Executed

1. 
git fetch --all --prune --tags

2. 
git status --short --branch

git branch --show-current

git rev-parse HEAD

git rev-list --left-right --count HEAD...origin/<base>

git log --oneline -n 8

3. 
git rev-parse origin/cransub/0.4.0

git rev-parse origin/feature/qdesn-mcmc-alternative

git rev-parse origin/validation/rerun-after-0.4.0-sync

4. 
git worktree list --porcelain

## Remote Baselines

- origin/cransub/0.4.0: a95ee8cc885547a5a6e2edb931d6756a09fa8054
- origin/feature/qdesn-mcmc-alternative: d4d65f1dde05f6659c2e04403d42e7d16e7a72b1
- origin/validation/rerun-after-0.4.0-sync: 11dce99ee9ebb4c13cd0b0784cb639ecd543259c

## Existing Worktree A (0.4.0 Validation Line)

Path: 
/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs

Branch: validation/rerun-after-0.4.0-sync

Status:

## validation/rerun-after-0.4.0-sync...origin/validation/rerun-after-0.4.0-sync
 M TRACK__RHS_NS_CROSS_BRANCH_EXECUTION_PLAN_20260329.md
?? reports/

HEAD: 11dce99ee9ebb4c13cd0b0784cb639ecd543259c

Divergence vs base origin/cransub/0.4.0 (left=HEAD ahead, right=behind):

- 66	0

Last 8 commits:

11dce99 Add RHS_NS cross-branch tracker and median comparison script
13cb72c Add optional progress callback to exdqlmMCMC for run telemetry
fa0539c Merge cransub/0.4.0 into validation/rerun-after-0.4.0-sync (rhs_ns sync)
a95ee8c Add rhs_ns stage-9 submission handoff memo
293d1ca Finalize rhs_ns release docs and static API examples
9876844 Add rhs_ns support to static exAL VB/MCMC on 0.4.0
f5d01ee mcmc: default to joint laplace-rw and expose chain-health diagnostics
2ed0937 static exAL MCMC: joint sigma-gamma MH block for rw kernels

## Existing Worktree B (Q-DESN Line)

Path: 
/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline

Branch: feature/qdesn-mcmc-alternative

Status:

## feature/qdesn-mcmc-alternative...origin/feature/qdesn-mcmc-alternative

HEAD: d4d65f1dde05f6659c2e04403d42e7d16e7a72b1

Divergence vs base origin/feature/qdesn-mcmc-alternative (left=HEAD ahead, right=behind):

- 0	0

Last 8 commits:

d4d65f1 Document qdesn closeout gates and final recommendation
d67746e Add qdesn validation closeout forensic and micro-pilot runners
4536ccc Integrate qdesn family/prior matrix and launch dynamic validation wave
2641e6b Add rhs-vs-rhs_ns median validation campaign and tracker docs
43c9763 Add rhs_ns diagnostics and guardrail parity in static validation
2acd278 Track final stage-9 submission memo on cransub 0.4.0
e498af1 Close rhs_ns tracker stages with release-finalization evidence
3138a13 Update rhs_ns tracker with 0.4.0 native port completion

## Worktree Topology (No New Worktree Created During Wave 0)

worktree /home/jaguir26/local/src/exdqlm
HEAD 9c715b79e53f5e2ffeb1016dfe334de38b7b0f06
branch refs/heads/main

worktree /home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs
HEAD 11dce99ee9ebb4c13cd0b0784cb639ecd543259c
branch refs/heads/validation/rerun-after-0.4.0-sync

worktree /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline
HEAD d4d65f1dde05f6659c2e04403d42e7d16e7a72b1
branch refs/heads/feature/qdesn-mcmc-alternative

worktree /home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile
HEAD a95ee8cc885547a5a6e2edb931d6756a09fa8054
branch refs/heads/cransub/0.4.0

worktree /tmp/wt_2eb8111
HEAD 2eb8111ee88d77f89aa89bd068022a463aaecb0d
detached

worktree /tmp/wt_ed9d929
HEAD ed9d9298cc4cf4047fd9ba2de88847bb5ba1fd4a
detached

worktree /tmp/wt_head_ablate
HEAD 692c58e65404d8ba820d30c1f6d73ea2a900cac9
detached

## Wave 0 Interpretation

1. Both authorized existing worktrees are available and synchronized to fetched remotes.
2. Base-target checks are explicit:
   - Worktree A checked against origin/cransub/0.4.0.
   - Worktree B checked against origin/feature/qdesn-mcmc-alternative.
3. No new worktree creation command was executed during Wave 0.

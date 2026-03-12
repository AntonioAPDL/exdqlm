Work on server:
`muscat.be.ucsc.edu`

User:
`jaguir26`

Primary mission:
Prepare muscat as the new main compute home for `exdqlm`, while leaving the
current in-flight validation jobs on jerez alone. Your job is to make muscat
fully ready for cloning, worktree setup, private artifact sync, and future
long-running validation runs.

Important context:

1. Jerez is currently overloaded by active `exdqlm` validation jobs.
2. Muscat is almost idle and is the correct place for the remaining backlog.
3. Do not assume the migration is already complete.
4. Start with setup and verification, not with launching the whole backlog.

Current jerez `exdqlm` layout to mirror conceptually:

- base repo:
  - `/data/muscat_data/jaguir26/exdqlm`
  - branch: `feature/benchmark-data-pipeline`
- validation worktree:
  - `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp`
  - branch: `jaguir26/dqlm-conjugacy-cavi-gibbs`
- main worktree:
  - `/data/muscat_data/jaguir26/exdqlm__wt__main`
  - branch: `main`

Recommended muscat layout:

- `/home/jaguir26/local/src/exdqlm`
- `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`
- `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

Important constraints:

1. Do not touch or manage jerez jobs from muscat unless explicitly instructed.
2. Do not assume local-only outputs should be pushed to GitHub.
3. Do not migrate `project1_ucsc_phd`.
4. Do not launch the full remaining validation backlog immediately.
5. First make muscat fully ready and verify everything.

Known current blocker on muscat:

- `git@github.com:` currently fails with `Host key verification failed`

Therefore your first responsibilities include:

1. fix GitHub SSH host trust on muscat
2. verify GitHub auth
3. if SSH auth still fails, use the user’s GitHub token only if necessary and in
   the safest practical way
4. do not leave secrets written into random files

`exdqlm` validation context you need to know:

- current full family-qspec validation plan is:
  - families: `normal`, `laplace`, `gausmix`
  - taus: `0.05`, `0.25`, `0.50`
  - static sizes: `100`, `1000`
  - dynamic sizes: last `500`, last `5000`
  - static shrinkage priors: `ridge`, `rhs`
  - models:
    - static paper: `AL`, `exAL`
    - static shrinkage: `AL`, `exAL`
    - dynamic: `DQLM`, `exDQLM`
- only `gausmix` has been partially launched so far on jerez
- many remaining planned roots are not yet launched and should eventually run on muscat

Local-only artifacts that will likely be copied privately to muscat later:

- `results/function_testing_20260309_static_paper_family_qspec`
- `results/function_testing_20260309_static_shrinkage_family_qspec`
- `results/function_testing_20260309_dynamic_dlm_family_qspec`
- selected `tools/merge_reports/*.log`
- selected `tools/merge_reports/*.tsv`
- `tools/merge_reports/untracked_refs`

Your tasks in order:

Step 1. Health check muscat.
- confirm CPU count
- confirm available memory
- confirm current load
- check whether any heavy competing workloads already exist

Step 2. Fix Git / GitHub access.
- inspect `~/.ssh`
- add GitHub to `known_hosts` if needed
- verify `ssh -T git@github.com`
- verify access to `git@github.com:AntonioAPDL/exdqlm.git`
- if SSH auth still fails, prepare a safe token-based fallback and explain exactly what you need

Step 3. Verify core tooling.
- check `git`
- check `tmux`
- check `R`
- check compiler/toolchain relevant for building/installing `exdqlm`
- check whether common required R packages are already available
- install missing requirements if safe and appropriate

Step 4. Create muscat repo layout.
- create `/home/jaguir26/local/src` if missing
- clone `exdqlm` into `/home/jaguir26/local/src/exdqlm`
- create worktrees for:
  - `jaguir26/dqlm-conjugacy-cavi-gibbs`
  - `feature/benchmark-data-pipeline`
- verify the checked-out branches are correct

Step 5. Audit local branch state on muscat.
- verify branch tracking
- verify remotes
- confirm where future commits/pushes would go
- do not modify code yet unless setup requires a small fix

Step 6. Prepare for private sync from jerez.
- create a recommended target location on muscat for local-only result roots and tracker artifacts
- do not sync everything blindly yet
- instead produce a precise `rsync` plan:
  - what to copy
  - where to place it
  - what to exclude

Step 7. Validate readiness for future long runs.
- propose safe default thread/core caps for muscat long runs
- confirm detached `tmux` workflow is ready
- confirm log locations and status-tracker pattern

Definition of done for this bootstrap phase:

1. muscat can authenticate to GitHub correctly
2. `exdqlm` is cloned on muscat
3. the two key worktrees are created and verified
4. required software/tooling is installed or gaps are explicitly identified
5. a concrete private-sync plan exists for local-only jerez artifacts
6. muscat is ready to receive the remaining validation backlog

Final response format:

1. muscat health summary
2. GitHub/auth/setup status
3. installed/missing tooling
4. repo/worktree layout created
5. private-sync plan
6. exact next actions for the jerez -> muscat cutover

Important:

- be rigorous
- do not launch the backlog yet
- do not mix up tracked code with local-only outputs
- do not assume anything about secrets without checking
- keep the setup secure and reproducible

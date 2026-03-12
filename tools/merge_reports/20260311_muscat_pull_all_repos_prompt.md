Work on server:
`muscat.be.ucsc.edu`

User:
`jaguir26`

Mission:
Set up a clean local source workspace on muscat by cloning or updating all
relevant repos from `/data/muscat_data/jaguir26` on jerez, except
`project1_ucsc_phd`, which must remain jerez-only.

Important:

1. Do not touch `project1_ucsc_phd`.
2. Do not assume every dirty jerez working tree should be reproduced via git.
3. Prefer clean remote clones for repos that are already synced.
4. For repos with unpublished local-only artifacts on jerez, clone the remote
   baseline and note any follow-up private sync that may still be needed.
5. Do not launch heavy compute yet. This is a source/workspace bootstrap step.

Current audited repo state on jerez as of 2026-03-11:

Ready for direct clone or pull from origin:

- `Article-Q-DESN`
- `Corrections---Project-1`
- `Environmetrics_paper_repo`
- `GSoC-2025/GSoC-2025`
- `NDLM---Ensemble`
- `Q-DESN---Theory-for-implementation`
- `Static-exAL-Regression---MCMC`
- `Static-exAL-Regression---VB`
- `VB-for-Horseshoe-Regression`
- `exAL---Regression`
- `exDQLM---Ensemble`
- `exdqlm`
- `exdqlm---Article`
- `univ-exDQLM---Ensemble`

Special cases on jerez:

- `exdqlm__wt__0.3.0-cpp`
  - tracked code/docs are already pushed on branch
    `jaguir26/dqlm-conjugacy-cavi-gibbs`
  - local untracked TSV manifests, queue files, and `untracked_refs/` should not
    be pushed blindly; these can be privately synced later if needed
- `exdqlm__wt__main`
  - clean and equivalent to `origin/main`
  - do not clone as a separate repo; create as a worktree from the base
    `exdqlm` clone if needed
- `DQLM-and-BQR---Theory`
  - jerez has only local untracked LaTeX build artifacts (`main.aux`, `main.log`,
    `main.out`, `main.pdf`)
  - remote branch is clean and current; clone remote baseline only
- `bqrgal-examples`
  - jerez has dirty compiled binary/object artifacts in `bqrgal/src`
  - remote branch is clean and current; clone remote baseline only
- `antonio-aguirre.github.io`
  - jerez `main` has unpublished local changes and is behind origin by 84 commits
  - do not try to mirror the jerez working tree through git during this step
  - if you need the repo on muscat, clone the remote baseline only and report
    that it is not a full mirror of jerez local state

Repos and origins to clone or update:

- `git@github.com:AntonioAPDL/Article-Q-DESN.git`
- `https://github.com/AntonioAPDL/Corrections---Project-1`
- `https://github.com/AntonioAPDL/DQLM-and-BQR---Theory.git`
- `https://github.com/AntonioAPDL/Evironmetrics---BAYESIAN-QUANTILE-BASED-CORRECTION-AND-SYNTHESIS-OF-RIVER-FLOW-FORECASTS`
- `https://github.com/AntonioAPDL/GSoC-2025.git`
- `git@github.com:AntonioAPDL/NDLM---Ensemble.git`
- `https://github.com/AntonioAPDL/Q-DESN---Theory-for-implementation.git`
- `https://github.com/AntonioAPDL/Static-exAL-Regression---MCMC.git`
- `https://github.com/AntonioAPDL/Static-exAL-Regression---VB.git`
- `https://github.com/AntonioAPDL/VB-for-Horseshoe-Regression.git`
- `git@github.com:AntonioAPDL/antonio-aguirre.github.io.git`
- `https://github.com/xzheng42/bqrgal-examples.git`
- `https://github.com/AntonioAPDL/exAL---Regression.git`
- `https://github.com/AntonioAPDL/exDQLM---Ensemble.git`
- `git@github.com:AntonioAPDL/exdqlm.git`
- `git@github.com:AntonioAPDL/exdqlm---Article.git`
- `git@github.com:AntonioAPDL/univ-exDQLM---Ensemble.git`

Target layout on muscat:

- `/home/jaguir26/local/src/Article-Q-DESN`
- `/home/jaguir26/local/src/Corrections---Project-1`
- `/home/jaguir26/local/src/DQLM-and-BQR---Theory`
- `/home/jaguir26/local/src/Environmetrics_paper_repo`
- `/home/jaguir26/local/src/GSoC-2025`
- `/home/jaguir26/local/src/NDLM---Ensemble`
- `/home/jaguir26/local/src/Q-DESN---Theory-for-implementation`
- `/home/jaguir26/local/src/Static-exAL-Regression---MCMC`
- `/home/jaguir26/local/src/Static-exAL-Regression---VB`
- `/home/jaguir26/local/src/VB-for-Horseshoe-Regression`
- `/home/jaguir26/local/src/antonio-aguirre.github.io`
- `/home/jaguir26/local/src/bqrgal-examples`
- `/home/jaguir26/local/src/exAL---Regression`
- `/home/jaguir26/local/src/exDQLM---Ensemble`
- `/home/jaguir26/local/src/exdqlm`
- `/home/jaguir26/local/src/exdqlm---Article`
- `/home/jaguir26/local/src/univ-exDQLM---Ensemble`

For `exdqlm`, after cloning the base repo:

1. verify remotes and auth
2. create worktrees for:
   - `jaguir26/dqlm-conjugacy-cavi-gibbs`
   - `feature/benchmark-data-pipeline`
   - optionally `main`
3. verify that:
   - branch `jaguir26/dqlm-conjugacy-cavi-gibbs` includes the family-qspec
     transition docs and resume fixes
   - branch `feature/benchmark-data-pipeline` includes the DESN defaults update

Required workflow:

Step 1. Verify GitHub access on muscat.
- fix GitHub `known_hosts` if needed
- verify SSH auth for `git@github.com`
- if HTTPS repos require credentials, use the safest available non-interactive
  method and report any blocker explicitly

Step 2. Create `/home/jaguir26/local/src` if missing.

Step 3. For each repo above:
- if target dir is missing, clone it
- if target dir exists, fetch and fast-forward pull only if clean
- if target dir exists but is dirty, do not overwrite it; report it

Step 4. For `exdqlm`, create and verify the required worktrees.

Step 5. Produce a final audit table with:
- repo
- target path
- cloned or updated
- branch checked out
- clean or dirty
- any caveat

Definition of done:

1. every repo except `project1_ucsc_phd` exists on muscat in the target layout,
   or a specific blocker is reported
2. the clean repos are on their correct current remote branches
3. `exdqlm` base clone and worktrees are ready
4. special-case repos are clearly labeled as remote-baseline-only vs needing
   later private sync

Final response format:

1. cloned/updated repos
2. any auth/setup blockers
3. `exdqlm` worktree status
4. special-case repos needing later private sync or manual follow-up

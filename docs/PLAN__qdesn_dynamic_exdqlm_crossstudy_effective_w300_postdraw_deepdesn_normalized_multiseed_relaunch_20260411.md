# PLAN: QDESN Dynamic Effective-W300 Postdraw Deep-DESN Normalized Multiseed Relaunch

Date: 2026-04-11
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Goal

Design the next deep-DESN relaunch so that it is:

- normalized across all current MCMC fits;
- reproducible across multiple seeds;
- explicit about seed-selection logic;
- efficient enough to run on the available server resources;
- and documented well enough that the branch history stays smooth.

This plan intentionally stops **before** the big relaunch. The deliverable here is a tested,
staged implementation plan and state freeze, not a blind immediate launch.

## 1.1) Implementation Update (2026-04-11)

The implementation path is now more concrete than the original investigation draft.

Chosen architecture:

- rerun the **full deep-DESN dynamic effective-w300 matrix**, not just another residual-only wave;
- keep the current shared grid of `36` roots;
- rerun VB once per likelihood family under the normalized posterior-draw contract;
- rerun each MCMC model with `4` deterministic seed replicates;
- select the winning seed by:
  - `PASS > WARN > FAIL`
  - then lower `forecast_CRPS_mean`
  - then lower runtime
  - then lower seed replicate id;
- write seed-selection tables at the method, root, and campaign levels;
- prune heavy non-winning seed artifacts after selection.

The implementation also adds two smoothness fixes that became necessary during testing:

- reuse the already-materialized effective-w300 source inventory when it exists instead of
  requiring the original full-source `sim_output.rds` files on every preflight;
- allow reference inventory parsing to proceed when raw reference `sim_output.rds` files have been
  pruned, since the comparison-facing reference summaries do not require those raw files.

## 2) Current Starting Point

Working deep-DESN challenger source after the completed `F` wave and justified `F630` promotion:

- `71 PASS`
- `60 WARN`
- `13 FAIL`
- `36 / 36` root `SUCCESS`
- `0 / 36` root `FAIL`
- `36 / 36` comparison-eligible-any
- `27 / 36` comparison-eligible-full

Residual scope:

- every remaining FAIL row is:
  - `prior = rhs_ns`
  - `fit_size = 5000`
  - `method = mcmc`
- residual family/model split:
  - `gausmix al = 3`
  - `gausmix exal = 3`
  - `laplace exal = 3`
  - `normal al = 2`
  - `normal exal = 2`

This means the remaining debt is now a **pure long-horizon MCMC diagnostics problem**.

## 3) Why This Direction Is Plausible

The user-requested direction is:

- normalize all MCMC fits to `n_burn = 5000`;
- set stored posterior draws to `20000`;
- run `4` reproducible seeds per MCMC fit;
- choose the best seed by signoff first, then CRPS;
- rerun VB too with stored posterior draws `20000`.

This is a plausible next move because:

1. the residual is homogeneous
- a normalized MCMC contract is now more coherent than another custom geometry ladder.

2. recent local geometry search is largely exhausted
- `F1`, `F2`, and `F4` all validated the current source instead of improving it.

3. the repo already has strong precedent for replicated selection
- benchmark-side `seed_set` pooling exists;
- multichain follow-up already uses deterministic multi-seed generation and `PASS/WARN/FAIL`
  grading.

## 4) Why We Should Not Launch It Blindly

There are four important engineering gaps to close before launch.

### 4.1 Seed Plumbing Is Not Yet First-Class In Dynamic Validation

Current state:

- root/grid `seed` currently feeds DESN configuration;
- `scripts/pipeline_real_main.R` also sets a top-level `set.seed(12345)`;
- MCMC replicate randomness needs explicit control through:
  - `mcmc_control$rng_seed` or `mcmc_control$seed`
  - and likely `mcmc_control$vb_warm_start_seed`.

What this means:

- naively rerunning the same root four times is not enough;
- the dynamic wave path needs a real seed-replicate design.

### 4.2 The Current Dynamic Validation Surface Needed A New Root-Level Layer

The implemented solution does **not** extend the old stage/profile residual-wave harness.

Instead it adds the multiseed layer directly inside the root-level dynamic validation runner:

- VB still runs once per likelihood family;
- each MCMC fit now runs through a seed-selection helper;
- canonical `fits/mcmc_*` directories represent the selected winning seed;
- seed-level artifacts live underneath `fits/mcmc_*/seeds/seed_##`.

This matches the user-requested scope better than another residual-stage abstraction because the
request is about **every current MCMC model** and the full current VB surface, not just one more
repair wave.

### 4.3 `20000` Draws Needs A Clear Contract

For VB:

- `sampling.nd_draws = 20000`
- `synthesis.n_samp = 20000`
- `metrics.posterior_metric_draws = 20000`

are a coherent interpretation.

For MCMC, that is **not** enough by itself.

Current behavior:

- posterior draw extraction can resample from a smaller saved chain;
- therefore `sampling.nd_draws = 20000` alone does **not** imply `20000` true kept MCMC draws.

If the requirement is literal stored posteriors for MCMC, the normalized contract should be:

- `n_burn = 5000`
- `n_mcmc = 20000`
- `thin = 1`

This is the cleanest interpretation and should be treated as the default plan unless we decide the
wording should mean only posterior **evaluation** draws.

### 4.4 Storage Must Be Designed Up Front

This branch already encountered `/home` storage exhaustion from large raw artifacts, especially
`forecast_objects.rds`.

If we multiply:

- every MCMC fit by `4` seeds,
- and raise retained draw counts materially,

we need a storage policy before launch.

Working recommendation:

- keep compact summary tables and diagnostics for **all** seed replicates;
- keep heavy raw fit artifacts only for the selected winning seed where possible;
- or prune non-winning heavy artifacts immediately after seed selection while retaining manifest,
  signoff, chain summary, and selection tables.

## 5) Similar Recent Work To Reuse

This relaunch should explicitly reuse the smoothest recent branch patterns.

### 5.1 Stage-Local Plus Exact-Root Reconciliation

Recent deep-DESN continuation already follows this pattern:

- Wave 1 closeout:
  - promote stage-local winners and exact-root carry-forwards only when strictly cleaner
- Wave 2 closeout:
  - promote `E410`, `E520`, `E620`
  - carry forward exact-root `E530`
- Wave 3 closeout:
  - promote only `F630`
  - keep source elsewhere

That pattern should remain the scientific control surface after the multiseed layer lands.

### 5.2 Benchmark-Side `seed_set` Pooling

The benchmark runner already supports:

- fixed `seed_set` lists;
- repeated candidate evaluation across seeds;
- CRPS-based candidate comparison.

That is the closest branch-local precedent for the new design.

### 5.3 Multichain Follow-Up Seed Management

Existing multichain follow-up already has:

- deterministic multi-seed generation from root metadata;
- a clean `PASS > WARN > FAIL` grade ordering helper.

That grading logic is directly reusable for the user-requested seed winner rule.

## 6) Recommended Design

### 6.1 Recommended Architecture

Recommended architecture:

- run the shared deep-DESN grid directly through the dynamic cross-study runner;
- add an explicit **seed replicate** layer inside each MCMC method directory;
- write seed-selection tables per method, per root, and per campaign;
- keep the reconciliation and promotion logic as a post-run reporting step.

Why this is the best fit:

- it matches the user-requested full-surface rerun;
- it avoids inventing a new residual-wave wrapper when the real need is a normalized baseline
  rerun;
- it preserves comparability with the existing dynamic campaign summary structure.

### 6.2 Design Option Assessment

| Option | Summary | Verdict |
| --- | --- | --- |
| Expand each seed replicate as a separate profile ID | quickest hack, but seed ranking and scientific profile ranking get mixed together | reject |
| Add seed-replicate execution inside each MCMC method directory | cleanest and most faithful to the requested logic | **implemented** |
| Build another residual-wave harness just for multiseed replay | would preserve recent wave naming, but adds indirection without helping the full-matrix rerun | reject |
| Treat this as a multichain confirmation problem | useful precedent, but wrong abstraction because the user wants best-seed selection, not chain aggregation | use only as a helper precedent |

## 7) Normalized Contract

### 7.1 MCMC Normalization

For all current MCMC fits in the relaunch scope:

- `n_burn = 5000`
- `n_mcmc = 20000`
- `thin = 1`
- `store_latent_draws = false`
- `store_rhs_draws = false`

Default interpretation:

- `20000` means **kept** MCMC posterior draws, not just resampled posterior evaluation draws.

### 7.2 VB Normalization

For all rerun VB fits:

- `sampling.nd_draws = 20000`
- `synthesis.n_samp = 20000`
- `metrics.posterior_metric_draws = 20000`

The user only explicitly requested four-seed replication for the MCMC models. The base plan
therefore keeps VB as a single deterministic rerun unless we later decide that VB seed
replication is worth the added compute.

### 7.3 Posterior Draw Semantics

Before launch, the implementation must document and validate:

- where `sampling.nd_draws` is consumed;
- where `synthesis.n_samp` is consumed;
- and that the MCMC chain itself now retains `20000` post-burn draws.

## 8) Seed Design

### 8.1 Required Behavior

Each MCMC candidate profile should be run with exactly `4` deterministic seed replicates.

Each replicate must set:

- DESN seed
- MCMC RNG seed
- VB warm-start seed used inside MCMC initialization
- synthesis seed if relevant

### 8.2 Recommended Seed Scheme

Recommended design:

- keep a replicate id: `seed_rep = 1, 2, 3, 4`
- derive a full seed bundle deterministically from:
  - `root_id`
  - `profile_id`
  - `seed_rep`

This is preferred over manually hard-coding a few global integers because it:

- avoids collisions,
- keeps runs reproducible across relaunches,
- and makes it obvious which exact seed bundle generated a selected winner.

### 8.3 Minimal Deterministic Rule

If we want the simplest acceptable implementation:

- use the current root seed as the base;
- derive four fixed replicate seeds from a documented offset rule;
- then derive MCMC and VB-warm seeds from each replicate seed with fixed additive offsets.

The exact rule should be written into the plan manifest and preserved in reports.

## 9) Seed Winner Rule

The user-requested selection rule should be encoded exactly:

1. prefer `PASS` over `WARN` over `FAIL`
2. within the same signoff grade, choose lower `forecast_CRPS_mean`
3. if all seed replicates are `FAIL`, still choose lower `forecast_CRPS_mean`
4. if CRPS ties remain, use a deterministic final tiebreak:
   - lower runtime first
   - then lower replicate id

Recommended internal score encoding:

- `PASS = 2`
- `WARN = 1`
- `FAIL = 0`

This matches the existing multichain grade-scoring pattern and keeps the rule transparent.

## 10) Recommended Scope

The relaunch scope should be:

1. all current MCMC fits in the dynamic effective-w300 deep-DESN matrix
- run with normalized MCMC settings and 4 seed replicates.

2. all current VB fits in the same matrix
- rerun with normalized posterior draw settings;
- no multiseed requirement by default unless explicitly expanded later.

This preserves the current full-study comparability while only multiplying the stochastic
MCMC burden.

Operational launch contract implemented for this relaunch:

- outer dynamic campaign workers:
  - `1`
- inner MCMC seed workers:
  - `4`

This is the safest direct interpretation of “run 4 different random seeds in parallel if possible”
without oversubscribing the server through nested outer and inner parallelism.

## 11) Deliverables And Stages

### D0: State Freeze And Documentation

Deliverables:

- freeze the working post-`F630` challenger state in docs and trackers;
- record the residual inventory and the rationale for not launching another geometry-only wave.

### D1: Seed Plumbing Patch

Deliverables:

- introduce a seed-bundle helper for dynamic validation profiles;
- ensure MCMC seed, VB warm-start seed, and DESN seed all vary by replicate;
- ensure the selected seeds are written into manifest outputs and result tables.

Success criteria:

- two nominally identical seed replicates produce distinct stored seed metadata;
- seed bundles are deterministic across reruns.

Status:

- **implemented**

### D2: Seed-Selection Layer

Deliverables:

- add per-profile seed summary tables;
- add best-seed selection tables using the exact requested rule;
- ensure stage ranking compares **seed-selected** profiles, not raw seed replicates.

Success criteria:

- the winning seed for each profile is machine-readable;
- selection is deterministic and reproducible.

Status:

- **implemented**

### D3: Normalized Config Layer

Deliverables:

- global normalized MCMC overrides:
  - `n_burn = 5000`
  - `n_mcmc = 20000`
- normalized posterior draw settings:
  - `sampling.nd_draws = 20000`
  - `synthesis.n_samp = 20000`
  - `metrics.posterior_metric_draws = 20000`

Success criteria:

- prepare-only manifests show the normalized contract everywhere it should appear.

Status:

- **implemented**

### D4: Storage-Safe Output Contract

Deliverables:

- define how non-winning seed artifacts are handled;
- either add a light-output mode or postselection pruning;
- keep enough metadata to fully reproduce the winner decision.

Success criteria:

- expected storage footprint is measured before launch;
- non-winning seeds do not recreate the recent disk-exhaustion problem.

Status:

- **implemented**

### D5: Canary

Deliverables:

- small canary run on representative roots covering:
  - `gausmix`
  - `laplace`
  - `normal`
  - both `al` and `exal`
  - both priors if they remain in scope

Success criteria:

- seed winner tables write correctly;
- normalized chain lengths and posterior-draw counts are verified;
- artifact retention/pruning behaves as designed.

Status:

- **implemented at prepare-only level**

### D6: Full Manifest And Prepare-Only Validation

Deliverables:

- full relaunch manifest
- launch wrapper
- healthcheck wrapper
- committed-state prepare-only run

Success criteria:

- scope counts match expectation;
- no output collisions;
- git state is clean before launch.

Status:

- **implemented at prepare-only level**

### D7: Big Relaunch

Launch only after `D0` through `D6` are complete.

Current status:

- **not launched yet in this plan update**

## 12) Testing And Validation Gates

Before the big relaunch, we should explicitly test:

1. seed differentiation
- confirm that the four replicates produce distinct seed metadata and distinct MCMC control seeds.

2. literal chain length
- confirm `n_burn = 5000`, `n_mcmc = 20000`, `thin = 1` in saved control manifests.

3. posterior draw counts
- confirm VB and synthesis layers really use `20000` draws.

4. selection logic
- confirm the chosen seed follows:
  - grade first
  - CRPS second
  - deterministic tiebreak last

5. storage behavior
- confirm non-winning seed artifacts do not retain unnecessary heavyweight files.

6. output isolation
- confirm no path collisions across seed replicates, profiles, and stages.

## 13) Recommendation

This is a credible next direction, but only if we implement it as a **seed-aware normalized wave**
rather than a quick manifest hack.

Recommended immediate next moves:

1. keep the working challenger frozen at the post-`F630` state
2. implement `D1` through `D4`
3. run a canary before any big relaunch
4. launch only after committed-state prepare-only validation passes

That is the smoothest path to make the next relaunch both scientifically stronger and operationally
safer than the recent geometry-only residual waves.

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

### 4.2 The Current Wave Harness Selects Profiles, Not Seed Winners

Current dynamic fit-fail waves already support:

- stage-local winners,
- source stage overrides,
- exact-root overrides.

But they do **not** yet support:

- running four seed replicates inside each candidate profile;
- selecting the best seed first;
- then comparing seed-selected profiles at the stage level.

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

- keep the **current stage/profile** concept;
- add an explicit **seed replicate** layer under each profile;
- write a new seed-selection table per profile;
- then compare the **selected best seed** for each profile at the stage level.

Why this is the best fit:

- it preserves the current wave reporting structure;
- it avoids treating seed as if it were a different scientific profile;
- it cleanly separates:
  - profile selection,
  - seed selection,
  - and stage-local promotion.

### 6.2 Design Option Assessment

| Option | Summary | Verdict |
| --- | --- | --- |
| Expand each seed replicate as a separate profile ID | quickest hack, but profile ranking and seed ranking get mixed together | reject as the main design |
| Add seed-replicate execution inside each profile | cleanest and most faithful to the requested logic | **recommended** |
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

### D2: Seed-Selection Layer

Deliverables:

- add per-profile seed summary tables;
- add best-seed selection tables using the exact requested rule;
- ensure stage ranking compares **seed-selected** profiles, not raw seed replicates.

Success criteria:

- the winning seed for each profile is machine-readable;
- selection is deterministic and reproducible.

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

### D4: Storage-Safe Output Contract

Deliverables:

- define how non-winning seed artifacts are handled;
- either add a light-output mode or postselection pruning;
- keep enough metadata to fully reproduce the winner decision.

Success criteria:

- expected storage footprint is measured before launch;
- non-winning seeds do not recreate the recent disk-exhaustion problem.

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

### D7: Big Relaunch

Launch only after `D0` through `D6` are complete.

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

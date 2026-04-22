Use this prompt in the `0.4.0` validation-study worktree to reproduce the same
canonical dynamic datasets there.

```text
You are working in the `0.4.0` validation-study worktree.

Your task is to reproduce the exact same canonical dynamic dataset surface that
was just selected in the Q-DESN validation worktree, so both validation repos
use the same underlying simulated datasets.

Read this first before changing anything.

==================================================
1. SOURCE OF TRUTH
==================================================

Authoritative source repo/worktree:
- `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

Authoritative branch and commit:
- branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
- commit: `a4ecc815534679afde037569ae18d1e4b64025f0`

Main docs to read there first:
- `docs/REPORT__qdesn_dynamic_candidate_dataset_refresh_outputs_20260422.md`
- `docs/REPORT__qdesn_dynamic_p90_steepertrend_main_dataset_selection_20260422.md`
- `docs/PLAN__qdesn_dynamic_p90_steepertrend_72case_relaunch_prep_20260422.md`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_active_dataset_selection.yaml`

Main generator files to inspect:
- `tools/merge_reports/20260305_dynamic_dgp_model_helpers.R`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_manifest.yaml`
- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_refresh.R`

==================================================
2. IMPORTANT ARCHITECTURE RULE
==================================================

Do not mirror the Q-DESN washout materialization into the `0.4.0`
validation-study canonical source layer.

The layer split should be:

1. canonical full dynamic roots
2. canonical `lastTT500` / `lastTT5000` validation windows
3. Q-DESN-only downstream washout materialization

So in this `0.4.0` validation repo, reproduce only:
- the `9` canonical full roots
- the `18` canonical `lastTT500` / `lastTT5000` windows

Do not reproduce:
- `effTT500_totalTT813`
- `effTT5000_totalTT5313`

Those are Q-DESN-local.

==================================================
3. SELECTED SCENARIO
==================================================

Scenario id:
- `dlm_constV_p90_m0amp_highnoise_steepertrend_v1`

Design contract:
- families: `gausmix`, `laplace`, `normal`
- taus: `0.05`, `0.25`, `0.50`
- total simulated length: `9000`
- warmup discard: `2000`
- kept main root: `7000`
- state dimension: `6`
- components: level, slope, cos1, sin1, cos2, sin2
- period: `90`
- harmonics: `1`, `2`
- observation loading: `(1, 0, 1, 0, 1, 0)`
- initial covariance: `C0 = 0.01 * I`
- initial state mode: deterministic `m0`
- latent path shared across tau within family
- tau-specific observed series created by deterministic quantile-centering
  shifts on the same raw noise draw

Family-specific `m0` / observation settings:

normal:
- level0: `40`
- slope0: `0.012`
- harmonic1 amplitude: `24`
- harmonic1 phase: `0.35`
- harmonic2 amplitude: `8`
- harmonic2 phase: `-0.8`
- observation sigma: `10`
- seeds: latent `12011`, noise `12012`

laplace:
- level0: `35`
- slope0: `0.011`
- harmonic1 amplitude: `28`
- harmonic1 phase: `-0.15`
- harmonic2 amplitude: `10`
- harmonic2 phase: `0.75`
- observation scale: `10`
- seeds: latent `22011`, noise `22012`

gausmix:
- level0: `45`
- slope0: `0.014`
- harmonic1 amplitude: `32`
- harmonic1 phase: `0.85`
- harmonic2 amplitude: `12`
- harmonic2 phase: `-1.25`
- gaussian-mixture sigmas: `(0.5, 15)`
- gaussian-mixture weights: `(0.1, 0.9)`
- gaussian-mixture offset: `+1`
- seeds: latent `32011`, noise `32012`

Shared state noise sd:
- `(0.005, 0.00002, 0.004, 0.004, 0.003, 0.003)`

==================================================
4. YOUR JOB
==================================================

1. Audit the current dynamic dataset generation/setup in this `0.4.0`
   validation repo.
2. Reproduce the same canonical scenario here using the Q-DESN source files as
   the behavioral reference.
3. Write the canonical full roots and canonical `lastTT500` / `lastTT5000`
   windows in the `0.4.0` validation repo’s own structure.
4. Preserve the same seeds, same DGP parameters, same quantile-centering rule,
   and same family-by-tau latent-path sharing.
5. Do not copy the Q-DESN washout windows into the canonical source layer.
6. Document exactly what you changed and how you verified that the datasets
   match the Q-DESN source contract.

==================================================
5. MATCHING REQUIREMENT
==================================================

The end result should be behaviorally identical to the Q-DESN source roots.

At minimum, verify:
- same `9` root directories
- same `18` canonical tail-slice directories
- same metadata/seed contract
- same full-root lengths
- same `lastTT500` / `lastTT5000` slicing convention
- same `q_true = mu` quantile-centering logic

If convenient, add summary hashes or comparison summaries so we can confirm the
two worktrees are using the same canonical source data.

==================================================
6. WHAT TO READ LOCALLY AFTER ORIENTING
==================================================

Before implementing, inspect the current dynamic validation study registry and
source paths in this repo so you can update them coherently rather than
creating a disconnected sidecar.

==================================================
7. NON-GOALS
==================================================

Do not:
- start the Q-DESN relaunch from this repo
- introduce the Q-DESN-only washout windows here
- change the warmup validation code in this task unless needed for dataset
  path compatibility
- broaden scope beyond reproducing the canonical dataset source surface

==================================================
8. DELIVERABLES
==================================================

When done, provide:
- a short implementation report
- a short dataset-sync report
- exact output paths
- a verification summary
- clean git status
```

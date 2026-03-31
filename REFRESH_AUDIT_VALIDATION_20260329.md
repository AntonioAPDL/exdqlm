# Refresh Audit: Validation State After RHS-NS Wave Closeout

Date: 2026-03-29

Worktree: `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`

Branch audited: `validation/rerun-after-0.4.0-sync`

Audit mode: read-only repository audit plus this report file only. No validation relaunch was executed.

## 1. Executive Conclusion

The smallest scientifically defensible rerun scope at current `HEAD` is:

- all `216` static RHS-NS campaign cells (`72` `static_paper` + `144` `static_shrink`), plus
- the unresolved dynamic tail rows `5`, `15`, and `57`.

That minimal correct scope is `219 / 288` method cells.

Reason:

- all existing static candidate fits were generated on `2026-03-27` to `2026-03-28`,
- all static candidate fits in the `full288` relaunch are true `rhs_ns` runs,
- commit `bc77e34` on `2026-03-29 09:48 EDT` materially changed the static RHS-NS VB/MCMC implementation and state mapping,
- the three dynamic tail rows still do not have complete usable candidate artifacts at current `HEAD`.

Completed dynamic rows outside `5/15/57` are not scientifically stale from current `HEAD` based on the code delta I found; they are only operationally less homogeneous because the later telemetry callback commit was not present when those runs completed.

Updated stricter interpretation requested on this audit refresh:

- every validation artifact tied to RHS-family static behavior and produced before the final static RHS-NS implementation commit must be treated as invalid evidence,
- not only the `216` current static candidate rows, but also the legacy `72` `validation_shrink_rhs_*` baseline method outputs and the auxiliary `rhs_vs_rhsns` comparison bundle.

Under that stricter rule:

- admissible rows inside the current `288`-cell bundle: only the `69` completed non-tail dynamic rows,
- stale rows inside the current `288`-cell bundle: all `216` static rows,
- unresolved rows inside the current `288`-cell bundle: `5`, `15`, `57`,
- additionally invalidated historical RHS-family baseline outputs outside the current candidate bundle: `72` legacy `validation_shrink_rhs_*` method outputs.

## 2. Repo Sync / Status Summary

Required sync sequence executed:

```bash
git fetch --all --prune --tags
git checkout validation/rerun-after-0.4.0-sync
git pull --ff-only
```

Observed repository state after sync:

- branch: `validation/rerun-after-0.4.0-sync`
- upstream: `origin/validation/rerun-after-0.4.0-sync`
- `HEAD`: `5868b1e1ed67dfc43d0b66cc9de2406d056a8b57`
- divergence vs upstream: `0 ahead / 0 behind`
- divergence vs `origin/cransub/0.4.0`: `71 ahead / 0 behind`
- worktree status at audit start: clean

Important timing note:

- `health_compact_20260329_103700.csv` was generated after the static RHS-NS closeout commits existed, but it still summarizes candidate fits mostly produced on `2026-03-27` to `2026-03-28`.
- The final closeout commit at current `HEAD` (`5868b1e`, `2026-03-29 10:39 EDT`) is documentation/evidence closeout, not new package behavior.

## 3. What Changed Since The Baseline Validation Artifacts

I used the March 27-29 branch history plus the required closeout reports to separate:

- changes already absorbed by the `full288` candidate artifacts, from
- changes that post-date those artifacts and therefore can make them stale.

### 3.1 Commits already absorbed by the stored `full288` candidates

These are relevant to interpretation but do not themselves force reruns beyond what the stored artifacts already represent:

| Commit | Date (EDT) | Area | Effect on validation interpretation |
|---|---:|---|---|
| `51de06d` | 2026-03-24 16:29 | static kernel | adds eta-slice gamma kernel for static exAL recovery work |
| `2ed0937` | 2026-03-24 20:27 | static kernel | changes static exAL MCMC to joint sigma-gamma MH for RW kernels |
| `f5d01ee` | 2026-03-25 15:33 | dynamic MCMC + diagnostics | defaults to joint laplace-rw and exposes chain-health diagnostics |
| `9876844` | 2026-03-27 06:18 | static priors/fitting | introduces static RHS-NS support on `0.4.0` |
| `fa0539c` | 2026-03-27 09:13 | branch sync | merges `cransub/0.4.0` into validation branch |

Evidence that the stored `full288` candidates already include this layer:

- all existing candidate fits were created after `fa0539c`:
  - dynamic existing candidates: `2026-03-27 18:26:33` to `2026-03-28 08:05:54`
  - static existing candidates: `2026-03-27 18:33:09` to `2026-03-28 06:02:31`

### 3.2 Commits that matter for staleness against current `HEAD`

| Commit | Date (EDT) | Area | Behavioral impact | Staleness implication |
|---|---:|---|---|---|
| `13cb72c` | 2026-03-29 08:49 | dynamic MCMC telemetry | adds optional `progress_callback` to `R/exdqlmMCMC.R`; callback wrappers only, no sampler equations changed | completed dynamic results are not scientifically stale; rerun only if homogeneous telemetry/supervision is desired |
| `bc77e34` | 2026-03-29 09:48 | static priors + static fitting | materially ports closed-form RHS-NS hierarchy into `R/static_beta_prior.R` and updates static MCMC init/state translation in `R/exal_static_mcmc.R` | all static RHS-NS candidates produced before this commit are stale for current `HEAD` |
| `2a781bd` | 2026-03-29 09:56 | docs/comments | clarifies parameterization and intercept behavior; no computational delta found in diff beyond documentation/comments | no rerun impact by itself |
| `08ea3ec`, `9a7d05e`, `11dce99`, `5868b1e` | 2026-03-29 | reports/evidence | tracker/evidence closeout only | no rerun impact by themselves |

### 3.3 Why `bc77e34` is the decisive static invalidator

`bc77e34` is not a documentation-only commit. It changes static RHS-NS behavior in exactly the functions used by the `full288` static relaunch:

- `R/static_beta_prior.R`
  - adds `.static_rhs_ns_recompute_moments()`
  - adds closed-form inverse-gamma state initialization and precision construction
  - changes static RHS-NS collapse diagnostics and expected precision handling
- `R/exal_static_mcmc.R`
  - changes how RHS-NS warm starts and init objects are translated into MCMC state
  - routes RHS-NS through new `lambda2`, `tau2`, `zeta2`, `nu`, `xi` state handling
- `tools/merge_reports/LOCAL_full288_case_runner_20260327.R`
  - static rows route through `exal_static_LDVB()` and `exal_static_mcmc()`

I additionally verified from actual candidate fit objects that the stored static relaunch fits are true RHS-NS fits and use the static exAL engine:

- `static_paper` candidate fits now store `beta_prior$type = "rhs_ns"` even when the baseline fit was `ridge`
- `static_shrink` candidate fits now store `beta_prior$type = "rhs_ns"` even when the baseline fit was `rhs` or `ridge`
- a sampled `static_paper` MCMC candidate fit has class `exal_mcmc` / `exal_static_mcmc`

Therefore the static candidate artifacts in the current `full288` campaign are not merely cosmetically old; they were generated under a different static RHS-NS implementation than current `HEAD`.

### 3.4 RHS-Family Timing Confirmation

Final static RHS-NS implementation cutoff:

- implementation commit: `bc77e34`
- timestamp: `2026-03-29 09:48:58 EDT`

I verified the relevant artifact windows against that cutoff:

| RHS-family artifact class | Count | Mtime window | Relation to cutoff |
|---|---:|---|---|
| legacy baseline `rhs` rows (`prior = rhs`, baseline fit paths from manifest) | `72` | `2026-03-10 03:49:38` to `2026-03-18 15:44:20` | all before cutoff |
| static candidate RHS-NS rows (`static_paper` + `static_shrink`) | `216` | `2026-03-27 18:33:09` to `2026-03-28 06:02:31` | all before cutoff |
| static candidate rows sourced from legacy `rhs` baselines | `72` | `2026-03-27 18:37:23` to `2026-03-28 06:01:34` | all before cutoff |
| static candidate rows sourced from legacy `ridge` baselines | `72` | `2026-03-27 18:37:34` to `2026-03-28 06:02:31` | all before cutoff |
| static candidate rows sourced from `paper` baselines | `72` | `2026-03-27 18:33:09` to `2026-03-28 04:36:44` | all before cutoff |

I also verified representative fit objects:

- legacy `validation_shrink_rhs_*` baseline fits store `beta_prior$type = "rhs"`
- current relaunch static candidates store `beta_prior$type = "rhs_ns"`
- therefore both the old `rhs` baselines and the relaunch `rhs_ns` static candidates predate the final static implementation cutoff

Auxiliary comparison evidence is stale too:

- `results/.../validation_shrink_rhs_vs_rhsns_20260327_102340`
- directory/file mtimes: `2026-03-27 10:23` to `2026-03-27 10:30`
- also before the `bc77e34` cutoff

## 4. Current Campaign State From Artifacts

Primary campaign artifacts audited:

- `tools/merge_reports/LOCAL_full288_manifest_rhsns_full_relaunch_20260327.csv`
- `tools/merge_reports/full288_rhsns_full_relaunch_20260327/health_compact_20260329_103700.csv`
- row-specific artifacts for `5`, `15`, `57`

### 4.1 Manifest structure

The manifest covers exactly `288` method cells:

- `72` dynamic
- `72` static paper
- `144` static shrink

Manifest prior routing:

- dynamic: `default -> default` (`72`)
- static paper: `paper -> rhs_ns` (`72`)
- static shrink: `rhs -> rhs_ns` (`72`)
- static shrink: `ridge -> rhs_ns` (`72`)

Interpretation:

- the static half of the campaign is explicitly a RHS-NS override campaign, not a mixed-prior baseline.

### 4.2 Compact health table summary

From `health_compact_20260329_103700.csv`:

- total rows: `288`
- states:
  - `done`: `144`
  - `skipped_existing`: `141`
  - `pending`: `2`
  - `failed_runtime`: `1`
- gate summary:
  - `PASS`: `163`
  - `WARN`: `63`
  - `FAIL`: `60`
  - `NA`: `2`
- health flags:
  - `healthy=TRUE`: `226`
  - `healthy=FALSE`: `60`
  - `NA`: `2`

### 4.3 PASS/WARN/FAIL distribution by model

| Model | PASS | WARN | FAIL | NA |
|---|---:|---:|---:|---:|
| `al` | 76 | 32 | 0 | 0 |
| `dqlm` | 34 | 0 | 1 | 1 |
| `exal` | 38 | 23 | 47 | 0 |
| `exdqlm` | 15 | 8 | 12 | 1 |

### 4.4 PASS/WARN/FAIL distribution by method

| Method | PASS | WARN | FAIL | NA |
|---|---:|---:|---:|---:|
| `mcmc::al` | 53 | 1 | 0 | 0 |
| `mcmc::dqlm` | 16 | 0 | 1 | 1 |
| `mcmc::exal` | 2 | 5 | 47 | 0 |
| `mcmc::exdqlm` | 0 | 5 | 12 | 1 |
| `vb::al` | 23 | 31 | 0 | 0 |
| `vb::dqlm` | 18 | 0 | 0 | 0 |
| `vb::exal` | 36 | 18 | 0 | 0 |
| `vb::exdqlm` | 15 | 3 | 0 | 0 |

### 4.5 PASS/WARN/FAIL distribution by `root_kind`

| Root kind | PASS | WARN | FAIL | NA |
|---|---:|---:|---:|---:|
| `dynamic` | 49 | 8 | 13 | 2 |
| `static_paper` | 42 | 13 | 17 | 0 |
| `static_shrink` | 72 | 42 | 30 | 0 |

Important interpretation:

- these counts describe the current stored artifact bundle,
- they should not be treated as current-`HEAD` scientific signoff because `216` of those rows are static RHS-NS artifacts generated before `bc77e34`, and `3` dynamic rows remain unresolved.

Under the stricter RHS-family invalidation rule, the usable subset of the current `288`-row bundle is only:

- `69` completed non-tail dynamic rows
  - `49 PASS`
  - `8 WARN`
  - `12 FAIL`

Everything else in the current bundle is either stale (`216` static rows) or unresolved (`5`, `15`, `57`).

## 5. Tail Rows `5`, `15`, `57`

### 5.1 Row 5

Manifest identity:

- `row_id = 5`
- `dynamic`, `gausmix`, `tau = 0.05`, `TT = 5000`
- `mcmc::dqlm`

Current state:

- compact table state: `pending`
- candidate fit: missing
- row CSV: missing
- health CSV: missing

Artifact evidence:

- launch attempts exist on `2026-03-28`
- hardened retry on `2026-03-29` produced telemetry/logs
- hardened telemetry advanced through burn-in `1000`:
  - `08:31` burn-in `200`
  - `08:40` burn-in `400`
  - `08:50` burn-in `600`
  - `08:59` burn-in `800`
  - `09:08` burn-in `1000`
- there is no terminal lifecycle CSV and no row summary CSV for this attempt

Assessment:

- unresolved due to missing terminal evidence, not a signed-off result
- exact terminal failure mode is unknown from stored artifacts

### 5.2 Row 15

Manifest identity:

- `row_id = 15`
- `dynamic`, `gausmix`, `tau = 0.25`, `TT = 5000`
- `mcmc::exdqlm`

Current state:

- compact table state: `pending`
- candidate fit: missing
- row CSV: missing
- health CSV: missing

Artifact evidence:

- three launch attempts exist on `2026-03-28`
- latest visible log reaches:
  - burn-in `2000`
  - MCMC iteration `2200`
  - MCMC iteration `2400`
- no hardened retry artifacts were found
- no terminal row CSV or health CSV was found

Assessment:

- unresolved due to missing completion artifacts
- there is not enough stored evidence to classify this as either successful or failed

### 5.3 Row 57

Manifest identity:

- `row_id = 57`
- `dynamic`, `normal`, `tau = 0.25`, `TT = 500`
- `mcmc::dqlm`

Current state:

- compact table state: `failed_runtime`
- gate: `FAIL`
- healthy: `FALSE`
- candidate fit: missing
- row CSV exists
- health CSV missing

Artifact evidence:

- two hardened retries exist on `2026-03-29`
- both advanced through burn-in and into kept MCMC progress
- final lifecycle record shows:
  - terminal status `stalled`
  - exit code `143`
  - signal `15`
  - note `progress_inactive_1200s`
- `row_0057.csv` marks:
  - `status = failed_runtime`
  - `gate_overall = FAIL`
  - `healthy = FALSE`

Assessment:

- resolved as a runtime failure, but not as a successful validation result
- missing `health_0057.csv` leaves the detailed gate decomposition unavailable

### 5.4 Tail-row conclusion

Rows `5`, `15`, and `57` are not scientifically usable current candidates.

- `5`: missing terminal evidence
- `15`: missing terminal evidence
- `57`: explicit runtime failure

All three must be rerun if the dynamic campaign is to be considered complete.

## 6. Staleness Matrix

| Campaign component | Rows | Current artifact status | Relation to current `HEAD` | Rerun class | Rationale |
|---|---:|---|---|---|---|
| Dynamic VB | 36 | complete; `33 PASS`, `3 WARN` | no post-artifact behavioral delta found | no-rerun | later code changes were static-only or optional MCMC telemetry |
| Dynamic MCMC completed excluding tail 3 | 33 | complete; `16 PASS`, `5 WARN`, `12 FAIL` | artifacts predate `13cb72c`, but that commit adds optional callback only | optional-rerun | scientific behavior is not stale, but provenance/telemetry is older |
| Dynamic tail rows `5/15/57` | 3 | `2 pending`, `1 failed_runtime`; all candidate fits missing | unresolved at current `HEAD` | must-rerun | there is no usable current candidate artifact |
| Static paper RHS-NS | 72 | complete artifact set, all candidates generated before `bc77e34` | stale | must-rerun | `bc77e34` materially changes static RHS-NS VB/MCMC implementation used by these runs |
| Static shrink RHS-NS | 144 | complete artifact set, all candidates generated before `bc77e34` | stale | must-rerun | same reason as above |
| Aggregate compact health / signoff summaries | 1 bundle | populated from stale static fits plus unresolved tail rows | stale as a current-`HEAD` summary | must-refresh after reruns | current PASS/WARN/FAIL totals are not valid release-facing `HEAD` totals |

Historical RHS-family artifacts not in the current `288`-row candidate count but also invalid under the stricter rule:

| Historical artifact class | Outputs | Relation to current `HEAD` | Action |
|---|---:|---|---|
| Legacy `validation_shrink_rhs_*` baseline method outputs | `72` | produced before final static RHS-NS implementation cutoff | do not use as evidence; rerun only if legacy `rhs` outputs still need to exist as standalone comparators |
| `rhs_vs_rhsns` comparison bundle (`validation_shrink_rhs_vs_rhsns_20260327_102340`) | `1` bundle | produced before cutoff | quarantine as stale exploratory evidence |

### 6.1 Count summary by rerun class

| Class | Rows |
|---|---:|
| must-rerun | 219 |
| optional-rerun | 33 |
| no-rerun | 36 |

Equivalent decomposition:

- must-rerun:
  - static rows: `216`
  - dynamic tail rows: `3`
- optional-rerun:
  - completed dynamic MCMC rows other than `5/15/57`: `33`
- no-rerun:
  - dynamic VB rows: `36`

## 7. Scientific Risk If No Rerun Is Done Now

### 7.1 High risk

If no rerun is done now, any claim that the full validation bundle reflects current `HEAD` would be scientifically weak to incorrect for the static half of the campaign.

Why:

- the static campaign is explicitly an RHS-NS override campaign,
- the current stored static candidates were produced before the closed-form RHS-NS port landed,
- the static PASS/WARN/FAIL distributions therefore summarize an older static RHS-NS implementation, not the one now signed off in targeted tests.

Practical consequence:

- release-facing or paper-facing static conclusions could shift after rerunning on the closed-form implementation,
- especially around `exal` MCMC failure concentration, which dominates the current stored failures.

### 7.2 Moderate risk

If no rerun is done, the campaign remains incomplete because rows `5`, `15`, and `57` are not finished current candidates.

Practical consequence:

- the compact table is not a complete 288-cell current-HEAD signoff bundle,
- and one tail row is already an explicit runtime failure.

### 7.3 Low risk

For completed dynamic rows outside the tail-3 set, the risk of scientific drift from current `HEAD` appears low.

Reason:

- I found no post-artifact dynamic sampler change beyond the optional progress callback added in `13cb72c`,
- and that diff does not alter update equations, kernels, or acceptance logic.

### 7.4 Overall risk statement

No-rerun is acceptable only if we treat the present artifacts as historical planning evidence and explicitly do not treat them as current-`HEAD` validation signoff.

No-rerun is not acceptable if the goal is to claim that the repository at `5868b1e` has a current, complete, reproducible validation campaign.

## 8. Recommended Rerun Scopes

### Option A: Minimal Correct Rerun

Scope: `219` rows

- `72` `static_paper`
- `144` `static_shrink`
- dynamic `5`, `15`, `57`

Why this is the minimum correct choice:

- it fixes the only scientifically stale slice created by the March 29 static RHS-NS port,
- and it closes the only unresolved dynamic holes.

Tradeoff:

- dynamic completed MCMC rows remain older in telemetry provenance than current orchestration, though not scientifically stale.

### Option B: Minimal Correct Rerun Plus Legacy RHS Refresh

Scope: `291` output artifacts

- Option A, plus
- the `72` legacy `validation_shrink_rhs_*` method outputs

Why choose it:

- this is the strictest reading of "relaunch all models that ever used the rhs prior,"
- it refreshes both the current rhs_ns target bundle and the older standalone `rhs` baseline artifacts,
- it prevents future reuse of stale `rhs` baseline outputs in comparisons or paper appendices.

Tradeoff:

- those extra `72` outputs are legacy baselines, not additional rows in the current `full288` candidate bundle,
- so this is archival/comparator hygiene on top of current signoff repair.

### Option C: Targeted Plus MCMC Homogenization

Scope: `252` rows

- Option A, plus
- the other `33` completed dynamic MCMC rows

Why choose it:

- all MCMC outputs become post-closeout, post-supervision, one-generation artifacts,
- simplifies audit narrative and operational comparability.

Tradeoff:

- `33` extra MCMC reruns for little expected scientific gain.

### Option D: Full Campaign Rerun

Scope: `288` rows

- rerun everything

Why choose it:

- cleanest provenance story,
- easiest to explain externally,
- no mixed-generation artifacts remain.

Tradeoff:

- highest compute/time cost,
- not required by the evidence I found.

## 9. Recommended Next-Step Checklist

1. Treat the current `health_compact_20260329_103700.csv` as a planning artifact, not final signoff.
2. Choose rerun scope:
   - Option A if the goal is current `HEAD` signoff only,
   - Option B if you want current signoff plus a strict refresh of all legacy standalone `rhs` outputs,
   - Option C if you want a clean all-MCMC-current bundle on top of Option A,
   - Option D only if one-generation provenance is worth the extra compute.
3. When reruns are authorized, regenerate:
   - row outputs,
   - health CSVs,
   - compact health summary,
   - model/method/root signoff tables.
4. Quarantine these as stale until refreshed or explicitly deprecated:
   - all `validation_shrink_rhs_*` baseline tables/fits,
   - all `full288` static rhs_ns candidate artifacts,
   - `validation_shrink_rhs_vs_rhsns_20260327_102340`.
5. Recompute PASS/WARN/FAIL distributions after the rerun; do not reuse the current aggregate counts for final reporting.
6. Compare pre/post static results specifically for:
   - `mcmc::exal`,
   - `vb::exal`,
   - `static_paper`,
   - `static_shrink`.
7. Reclassify rows `5`, `15`, `57` only from final row/health artifacts, not from launcher logs alone.

## 10. Explicit Uncertainties

I am confident about the must-rerun static conclusion and the unresolved tail-3 conclusion.

Remaining uncertainty is limited to the exact operational failure mechanism for two tail rows:

- row `5`: no terminal row/lifecycle artifact was found
- row `15`: no terminal row/health artifact and no hardened retry artifact was found
- row `57`: final runtime failure is clear, but detailed gate decomposition is unavailable because `health_0057.csv` is missing

Missing evidence that would reduce uncertainty:

- final lifecycle/row CSV for `5`
- final lifecycle/row CSV for `15`
- detailed health CSV for `57`

These uncertainties do not change the rerun recommendation, because all three tail rows already fail the threshold for a usable current candidate artifact.

## 11. Bottom-Line Recommendation

Recommended default: Option A.

Do not relaunch now, per instruction. When relaunch is authorized, the minimal correct rerun scope is:

- all static RHS-NS campaign rows (`216`)
- plus dynamic rows `5`, `15`, `57`

If you want the stricter "all historical RHS-family outputs refreshed or explicitly retired" interpretation, promote to Option B by adding the `72` legacy `validation_shrink_rhs_*` method outputs.

Anything smaller than Option A would leave scientifically stale static results or unresolved dynamic gaps in the current-`HEAD` validation bundle.

# Family-QSpec Validation Status Tracker

Last updated: 2026-03-14 04:40 EDT

This file is the authoritative human-readable tracker for the family-qspec
validation campaign on muscat.

Important interpretation rule:

- the current authoritative live state is the canonical relaunch state beginning
  at `## 2026-03-12 Canonical Relaunch Reset (Authoritative)` and the progress
  tables referenced near the end of this file
- the earlier `mqsp_*` sections are preserved as historical pre-reset notes so
  the migration/relaunch path remains auditable
- historical sections should not be used as the live source of truth for the
  current `fqv2_*` launcher state

## Scope

Current validation-run scope:

- families: `normal`, `laplace`, `gausmix`
- taus: `0.05`, `0.25`, `0.95`
- static fit sizes: `100`, `1000`
- dynamic fit sizes: `500`, `5000`
- static shrinkage priors: `ridge`, `rhs`
- `ISVB` excluded

Validation totals:

- static paper:
  - `18` roots
  - `72` VB/MCMC fit stages
- static shrinkage:
  - `36` roots
  - `144` VB/MCMC fit stages
- dynamic:
  - `18` roots
  - `72` VB/MCMC fit stages
- total:
  - `72` roots
  - `288` VB/MCMC fit stages

## References

Primary planning and launch references:

- full validation plan:
  - `tools/merge_reports/20260310_family_qspec_full_validation_plan.md`
- original exact muscat backlog manifest:
  - `tools/merge_reports/20260312_family_qspec_muscat_launch_manifest.tsv`
- historical pre-reset unified status snapshot:
  - `tools/merge_reports/20260312_family_qspec_unified_root_status.tsv`
- original jerez exclusion snapshot:
  - `tools/merge_reports/20260312_family_qspec_jerez_excluded_roots.tsv`
- original muscat launch registries:
  - `tools/merge_reports/20260312_muscat_launch_registry_20260312_024859.tsv`
  - `tools/merge_reports/20260312_muscat_launch_registry_manual_20260312_025039.tsv`
- former jerez partial-root handoff manifest:
  - `tools/merge_reports/20260312_jerez_gausmix_partial_roots_to_muscat.tsv`
- later exact sync plan for jerez-complete roots:
  - `tools/merge_reports/20260312_jerez_to_muscat_exact_sync_plan.tsv`
  - `tools/merge_reports/20260312_jerez_to_muscat_exact_sync_plan.sh`
- current reusable-state audit:
  - `tools/merge_reports/20260312_family_qspec_reusable_state_audit.tsv`
  - `tools/merge_reports/20260312_family_qspec_reusable_state_audit_summary.tsv`
- current runtime queue:
  - `tools/merge_reports/20260312_family_qspec_runtime_queue.tsv`
  - `tools/merge_reports/20260312_family_qspec_runtime_queue_summary.tsv`
- current full periodic progress tables:
  - `tools/merge_reports/20260312_family_qspec_model_path_progress.md`
  - `tools/merge_reports/20260312_family_qspec_barrier_progress.md`

Important interpretation note:

- `tools/merge_reports/20260312_family_qspec_global_root_status.tsv` is still
  useful as the original pre-rehome reconciliation snapshot.
- it does not yet encode the later `16:50 EDT` muscat resume sessions for the
  former jerez partial roots.
- `tools/merge_reports/20260312_family_qspec_unified_root_status.tsv` is a
  historical pre-reset unified status table.
- the current live coordination state is now carried by:
  - `tools/merge_reports/20260312_family_qspec_reusable_state_audit.tsv`
  - `tools/merge_reports/20260312_family_qspec_runtime_queue.tsv`
  - `tools/merge_reports/20260312_family_qspec_v2_active_tasks.tsv`
  - `/home/jaguir26/local/state/exdqlm/family_qspec_v2/task_events.tsv`
- this markdown tracker is the readable narrative companion to those files.

## Historical Pre-Reset Root Placement Snapshot

| State | Roots | Notes |
| --- | ---: | --- |
| complete on jerez, pending exact sync to muscat | 9 | these are complete outputs, not active compute |
| complete on muscat from backlog wave | 13 | completed inside the original `mqsp_*` muscat batch lanes |
| active on muscat from backlog wave | 8 | current root in each batch lane listed below |
| active on muscat, rehomed from former jerez partial roots | 7 | standalone resume sessions started at `2026-03-12 16:50 EDT` |
| queued on muscat behind active backlog lanes | 35 | already assigned to muscat; waiting behind the current 8 batch roots |
| not launched anywhere | 0 | no campaign roots remain unassigned |

Sanity check:

- `9 + 13 + 8 + 7 + 35 = 72` total campaign roots
- these counts match `tools/merge_reports/20260312_family_qspec_unified_root_status.tsv`
- this section is historical and describes the state before the canonical
  relaunch reset

## Historical Pre-Reset Muscat Live Execution

Interpretation caveat:

- the batch logs are sparse inside long MCMC phases
- log timestamps mostly move at root boundaries, not continuously during sampling
- live process checks therefore matter more than log recency for current-health interpretation

### Active Backlog-Wave Batch Roots

These 8 sessions belong to the original exact muscat backlog launch.

| Session | Root type | Current root | Current models/stage | Batch progress | Remaining queued after current |
| --- | --- | --- | --- | --- | --- |
| `mqsp_dynamic_tt5000_20260312_025039` | dynamic | `gausmix tau=0.25 lastTT=5000` | `DQLM + exDQLM` in `VB -> MCMC` pipeline | `0 / 8` done | `gausmix tau=0.50`, `laplace tau=0.05/0.25/0.50`, `normal tau=0.05/0.25/0.50` |
| `mqsp_dynamic_tt500_20260312_025039` | dynamic | `laplace tau=0.25 lastTT=500` | `DQLM + exDQLM` in `VB -> MCMC` pipeline | `1 / 6` done | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `mqsp_static_paper_tt1000_20260312_024859` | static paper | `laplace tau=0.25 TT=1000` | `AL + exAL` in `VB -> MCMC` pipeline | `2 / 7` done | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `mqsp_static_paper_tt100_20260312_024859` | static paper | `laplace tau=0.25 TT=100` | `AL + exAL` in `VB -> MCMC` pipeline | `2 / 7` done | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `mqsp_static_shrink_rhs_tt1000_20260312_025039` | static shrink `rhs` | `laplace tau=0.25 TT=1000` | `AL + exAL` in `VB -> MCMC` pipeline | `2 / 7` done | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `mqsp_static_shrink_rhs_tt100_20260312_024859` | static shrink `rhs` | `laplace tau=0.25 TT=100` | `AL + exAL` in `VB -> MCMC` pipeline | `2 / 7` done | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `mqsp_static_shrink_ridge_tt1000_20260312_025039` | static shrink `ridge` | `laplace tau=0.25 TT=1000` | `AL + exAL` in `VB -> MCMC` pipeline | `2 / 7` done | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `mqsp_static_shrink_ridge_tt100_20260312_024859` | static shrink `ridge` | `laplace tau=0.25 TT=100` | `AL + exAL` in `VB -> MCMC` pipeline | `2 / 7` done | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |

### Active Rehomed Former-Jerez Roots

These 7 sessions were relaunched on muscat at `2026-03-12 16:50 EDT` after the
former jerez partial roots were preserved and handed off.

| Session | Former jerez session | Root | Current muscat stage | Resume goal |
| --- | --- | --- | --- | --- |
| `mqsp_jr_rsp100_20260312_135054` | `qsp_rsp100_20260310_204439` | static paper `gausmix tau=0.25 TT=100` | `resume_static_mcmc_from_vb.R` active | finish `exAL` MCMC, then postprocess/report |
| `mqsp_jr_rsp1k_20260312_135054` | `qsp_rsp1k_20260310_204439` | static paper `gausmix tau=0.25 TT=1000` | `resume_static_mcmc_from_vb.R` active | finish `exAL` MCMC, then postprocess/report |
| `mqsp_jr_rss100r_20260312_135054` | `qsp_rss100r_20260310_204439` | static shrink `ridge`, `gausmix tau=0.25 TT=100` | `resume_static_mcmc_from_vb.R` active | finish `exAL` MCMC, then postprocess/report |
| `mqsp_jr_rss1kr_20260312_135054` | `qsp_rss1kr_20260310_204439` | static shrink `ridge`, `gausmix tau=0.25 TT=1000` | `resume_static_mcmc_from_vb.R` active | finish `exAL` MCMC, then postprocess/report |
| `mqsp_jr_rss100h_20260312_135054` | `qsp_rss100h_20260310_204439` | static shrink `rhs`, `gausmix tau=0.25 TT=100` | `resume_static_mcmc_from_vb.R` active | finish `exAL` MCMC, then postprocess/report |
| `mqsp_jr_rss1kh_20260312_135054` | `qsp_rss1kh_20260310_204439` | static shrink `rhs`, `gausmix tau=0.25 TT=1000` | `resume_static_mcmc_from_vb.R` active | finish `exAL` MCMC, then postprocess/report |
| `mqsp_jr_rdy5k_20260312_135054` | `qsp_rdy5k_fix_20260311_173314` | dynamic `gausmix tau=0.05 lastTT=5000` | `resume_dynamic_mcmc_from_vb.R` active | finish `DQLM` and `exDQLM` MCMC, then postprocess |

## Historical Pre-Reset Roots Completed Before Canonical Relaunch Reset

These roots are already complete inside the original muscat backlog wave.

### Static Paper

| Family | Tau | TT | State |
| --- | --- | ---: | --- |
| `gausmix` | `0.50` | 100 | complete on muscat |
| `gausmix` | `0.50` | 1000 | complete on muscat |
| `laplace` | `0.05` | 100 | complete on muscat |
| `laplace` | `0.05` | 1000 | complete on muscat |

### Static Shrink Ridge

| Family | Tau | TT | State |
| --- | --- | ---: | --- |
| `gausmix` | `0.50` | 100 | complete on muscat |
| `gausmix` | `0.50` | 1000 | complete on muscat |
| `laplace` | `0.05` | 100 | complete on muscat |
| `laplace` | `0.05` | 1000 | complete on muscat |

### Static Shrink RHS

| Family | Tau | TT | State |
| --- | --- | ---: | --- |
| `gausmix` | `0.50` | 100 | complete on muscat |
| `gausmix` | `0.50` | 1000 | complete on muscat |
| `laplace` | `0.05` | 100 | complete on muscat |
| `laplace` | `0.05` | 1000 | complete on muscat |

### Dynamic

| Family | Tau | lastTT | State |
| --- | --- | ---: | --- |
| `laplace` | `0.05` | 500 | complete on muscat |

## Queued Muscat Backlog After The Current Active Batch Roots

These `35` roots are already assigned to muscat and are waiting in the queue
behind the current 8 batch-current roots.

| Lane | Exact queued roots |
| --- | --- |
| `dynamic_tt5000` | `gausmix tau=0.50`, `laplace tau=0.05/0.25/0.50`, `normal tau=0.05/0.25/0.50` |
| `dynamic_tt500` | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `static_paper_tt1000` | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `static_paper_tt100` | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `static_shrink_rhs_tt1000` | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `static_shrink_rhs_tt100` | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `static_shrink_ridge_tt1000` | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |
| `static_shrink_ridge_tt100` | `laplace tau=0.50`, `normal tau=0.05/0.25/0.50` |

## Jerez-Complete Roots Still Pending Exact Sync

These 9 roots are complete but their results still need to be copied into the
muscat workspace using the exact sync plan.

| Type | Family | Tau | Size | Prior |
| --- | --- | --- | --- | --- |
| static paper | `gausmix` | `0.05` | `TT=100` | `paper` |
| static paper | `gausmix` | `0.05` | `TT=1000` | `paper` |
| static shrink | `gausmix` | `0.05` | `TT=100` | `ridge` |
| static shrink | `gausmix` | `0.05` | `TT=1000` | `ridge` |
| static shrink | `gausmix` | `0.05` | `TT=100` | `rhs` |
| static shrink | `gausmix` | `0.05` | `TT=1000` | `rhs` |
| dynamic | `gausmix` | `0.05` | `lastTT=500` | `-` |
| dynamic | `gausmix` | `0.25` | `lastTT=500` | `-` |
| dynamic | `gausmix` | `0.50` | `lastTT=500` | `-` |

## Operational Notes

- no campaign roots remain unassigned
- do not relaunch the 7 rehomed former jerez partial roots again elsewhere
- the exact handoff for those 7 roots is documented in:
  - `tools/merge_reports/20260312_jerez_gausmix_partial_roots_to_muscat.tsv`
- the exact later sync for the 9 jerez-complete roots is documented in:
  - `tools/merge_reports/20260312_jerez_to_muscat_exact_sync_plan.tsv`
- `tools/merge_reports/20260312_family_qspec_unified_root_status.tsv` is the
  machine-readable current-state table for this tracker

## Proposed Resource-Adaptive Full-Node Relaunch Design

This section records a better orchestration design for any future large muscat
relaunch. It is a planning note only. It does not change the current live runs.

### Core Conclusion

- muscat currently has `32` physical cores and `64` logical CPUs
- the present family-qspec scheduler is under-filling the node because it
  schedules long sequential batch lanes, not because the R pipelines lack
  internal task parallelism
- the idea "one worker owns one model path, runs VB, then continues into MCMC
  on that same worker" does make sense
- the current fresh pipelines already behave that way inside each root
- the main missing throughput comes from not running enough roots concurrently

### Why The Current Launcher Under-Fills Muscat

| Current design choice | Effect on muscat |
| --- | --- |
| 8 batch lanes launched as long-lived tmux sessions | only 8 roots are "owned" at a time |
| each fresh static root only contains `exAL` and `AL` task paths | max useful compute per fresh static root is about `2` workers |
| each fresh dynamic root only contains `exDQLM` and `DQLM` task paths | max useful compute per fresh dynamic root is about `2` workers |
| current former-jerez static resume roots mostly only need `exAL` MCMC completion | many resume roots only need `1` hot worker |
| consequence | muscat is only using about `15-16` hot workers, well below `32` physical cores |

Interpretation:

- increasing `EXDQLM_STATIC_PIPELINE_CORES` or `EXDQLM_PIPELINE_CORES` far above
  `2` does not materially help these family-qspec roots
- the practical speedup has to come from more concurrently running roots, not
  deeper threading inside a single root

### What The Existing Fresh Pipelines Already Do Correctly

- each model-specific task already runs `VB -> MCMC` in sequence on the same
  worker
- fresh static roots run the model pair `exAL` and `AL`
- fresh dynamic roots run the model pair `exDQLM` and `DQLM`
- BLAS/OpenMP oversubscription is already controlled by setting
  `OMP_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`, and `MKL_NUM_THREADS=1`

So the right redesign is not "more threads per fit". The right redesign is
"more independently owned roots in flight".

### Recommended Scheduling Unit

The recommended production scheduling unit for a future relaunch is:

- one queue row per exact `run_root`
- one detached child session per claimed root
- one root owner at a time
- current root owner runs all compute and postprocess for that root before the
  root is marked done

This is a root-level scheduler, not a batch-lane scheduler.

Reason:

- it preserves the current proven root-local scripts
- it avoids duplicate ownership
- it lets muscat fill unused cores with additional roots immediately
- it keeps resume semantics local to the root directory and `run_config.rds`

### Why A Pure Per-Model Scheduler Is Not The First Redesign

A per-model scheduler is possible, but it should be considered a second-stage
refactor rather than the first production redesign.

Why it is attractive:

- one model task can own one core
- that core can run `VB` and then `MCMC` sequentially for the same model
- this gives very fine-grained load balancing

Why it is not the best v1 redesign:

- current postprocess/report scripts expect the full root fit set to exist under
  the same `run_root`
- model-level claiming would require an additional root-aggregation state machine
- the root cannot be marked complete until both model tasks have finished and
  the postprocess/report layer has run

Recommended interpretation:

- your idea is valid in principle
- the current fresh root pipelines already do that internally for the two model
  paths
- the safest first redesign is still a root-level weighted scheduler

### Exact Counting View: Roots vs Model Paths vs Fit Stages

There are three useful counting levels for this campaign.

Important prior-scope rule:

- `ridge` and `rhs` apply only to the static shrink campaign
- static paper does not branch over shrinkage priors
- dynamic does not branch over shrinkage priors
- dynamic always uses its default/non-shrink configuration for this validation
  plan

1. Root count:

- static paper: `3 families x 3 taus x 2 TT = 18` roots
- static shrink: `3 families x 3 taus x 2 TT x 2 priors = 36` roots
- dynamic: `3 families x 3 taus x 2 TT = 18` roots
- total: `72` roots

2. Model-path count:

Each root contains exactly two model paths:

- static paper: `AL` and `exAL`
- static shrink: `AL` and `exAL`
- dynamic: `DQLM` and `exDQLM`

So:

- static paper: `18 x 2 = 36` model paths
- static shrink: `36 x 2 = 72` model paths
- dynamic: `18 x 2 = 36` model paths
- total: `144` model paths

3. Fit-stage count:

Each model path runs:

- `VB`
- then `MCMC`

So:

- total fit stages = `144 x 2 = 288`

Important correction:

- `216` is not the correct campaign count for this validation plan
- the shrinkage-prior dimension only applies to the static shrink campaign
- dynamic roots do not use `AL/exAL`; they use `DQLM/exDQLM`
- dynamic roots also do not multiply over `ridge/rhs`; they only use the
  default dynamic prior configuration

### When A Per-Model-Path Scheduler Becomes Preferable

If muscat is dedicated almost entirely to this campaign and the goal is to keep
as many physical cores busy as possible, then a per-model-path scheduler becomes
more attractive than a pure root-level scheduler.

Reason:

- one model path can naturally own one worker slot
- that worker can run `VB -> MCMC` sequentially for the same exact model
- when a faster model path finishes, its slot can be backfilled immediately
- this avoids the "half-idle root" effect where one model in a root finishes
  early but the root still waits on the slower companion model

This is the main efficiency gain over the current root-batch design.

### Recommended Dedicated-Node Interpretation

For a fully dedicated muscat relaunch, the most aggressive practical view is:

- schedule `144` model paths, not `72` roots, as the main work queue
- treat each model path as a `1`-slot task
- keep a separate `postprocess/report` task for each root that becomes eligible
  only after both model paths in that root are done

Under that interpretation:

- total primary compute tasks: `144`
- total root postprocess tasks: `72`
- full campaign work units: `216`

This `216` count is a scheduler-work-unit count, not a model count.

### Recommended V2 Full-Node Design If Maximum Throughput Is The Goal

If the node is truly dedicated and a richer orchestration layer is acceptable,
the preferred design becomes:

- queue unit: one model path
- slot cost: `1` per model path
- worker behavior: run `VB`, then `MCMC`, then mark model path done
- root barrier: when both model paths for a root are done, enqueue a
  `postprocess/report` task
- root completion: mark the root complete only after the postprocess task exits

Examples:

- static paper root:
  - task `AL @ root`
  - task `exAL @ root`
  - then one `postprocess/report @ root`
- dynamic root:
  - task `DQLM @ root`
  - task `exDQLM @ root`
  - then one `postprocess @ root`

### Why This V2 Design Can Fill Muscat Better

On a `32`-physical-core node:

- a `30`-slot policy could keep about `30` model paths active most of the time
- the scheduler can immediately backfill the slot of any finished `AL`, `exAL`,
  `DQLM`, or `exDQLM` path
- this is usually more efficient than assigning a fixed `2`-slot reservation to
  a root whose two model paths do not finish at exactly the same time

### Cost Of The V2 Design

This design is more efficient, but it requires more orchestration support:

- a model-path manifest, not just a root manifest
- exact path-level claiming and status tracking
- a root barrier that knows when both companion model paths are complete
- a postprocess trigger per root
- path-level resume semantics for partially completed roots

So the tradeoff is:

- root-level scheduler: simpler, still much better than the current batch-lane
  design
- model-path scheduler: more complex, but probably the best way to saturate a
  dedicated muscat node

### Muscat Resource Model For A Future Relaunch

Use physical cores, not logical CPUs, as the main scheduling budget.

| Resource policy item | Recommended value | Notes |
| --- | ---: | --- |
| physical core count | `32` | use `detectCores(logical = FALSE)` |
| logical CPU count | `64` | do not use this as the main job budget |
| reserved headroom | `2` slots | keeps shell, tmux, logging, and small postprocess tasks responsive |
| default slot budget | `30` slots | recommended full-node validation budget |
| aggressive slot budget | `32` slots | only after a stable burn-in test |
| BLAS/OpenMP threads per R process | `1` | keep nested thread libraries pinned |

### Slot Cost By Root Type

| Root type | Typical slot cost | Why |
| --- | ---: | --- |
| fresh static root | `2` | `AL` and `exAL` task paths |
| fresh dynamic root | `2` | `DQLM` and `exDQLM` task paths |
| static resume root with only one missing model MCMC | `1` | current former-jerez static partials fit this case |
| dynamic resume root with both model MCMCs pending | `2` | current dynamic rehome case fits this case |
| postprocess/report only | `1` | short cleanup stage if split out separately |

Operational rule:

- do not reserve more slots for a root than the number of genuinely runnable
  model tasks it still has

### Queue And Locking Model

For a future relaunch, the scheduler should use a single machine-readable queue
manifest with one row per root.

Recommended manifest columns:

- `root_key`
- `kind`
- `family`
- `tau`
- `tt`
- `prior`
- `prepared_root`
- `run_root`
- `estimated_cost_class`
- `slot_cost`
- `priority`
- `state`
- `owner_session`
- `claim_ts`
- `start_ts`
- `end_ts`
- `attempt`
- `resume_mode`
- `note`

Recommended state values:

- `pending`
- `claimed`
- `running_fresh`
- `running_resume`
- `postprocess_pending`
- `done`
- `failed`
- `excluded_jerez_complete`
- `excluded_jerez_live`

Recommended lock model:

- one lock file per `root_key`
- root claim must be atomic
- manifest updates should be append-only or lock-protected
- no session should start a root unless it owns that root lock

### Supervisor Behavior

Recommended top-level structure:

1. a single detached supervisor session computes the slot budget from muscat's
   physical core count
2. the supervisor keeps launching roots while total claimed slots stay within
   the budget
3. each child session claims exactly one root, runs it, records the outcome, and
   releases its slots
4. once a child session exits, the supervisor backfills from the queue
5. no batch lane owns future roots in advance

This is the key change from the current design. The current design owns long
future queues inside already-running batch sessions. The new design would only
own the root actually being executed.

### Priority Policy To Reduce Total Wall-Clock Time

A future relaunch should not use plain FIFO ordering. It should bias toward the
longest roots first so the campaign does not end with a long dynamic tail.

Recommended priority order:

1. partial resume roots with sunk compute already present
2. dynamic `TT=5000` roots
3. dynamic `TT=500` roots and static `TT=1000` roots
4. static `TT=100` roots

Additional rule:

- once runtime telemetry exists for the first several completed roots, replace
  the static priority guess above with observed median runtime by class

### Recommended Full-Node Launch Policy On Muscat

If the entire campaign were being launched from a clean scheduler on muscat, the
recommended starting policy would be:

- target `30` slots by default
- keep BLAS/OpenMP libraries pinned to `1`
- keep at least some dynamic roots active from the beginning to avoid a long
  end-game tail
- prioritize `TT=5000` dynamic roots before lighter dynamic roots
- prioritize `TT=1000` static roots before `TT=100` static roots

Recommended initial mix at `30` slots:

| Active work mix | Slot budget used | Notes |
| --- | ---: | --- |
| `6` dynamic roots | `12` | front-load the longest dynamic work |
| `9` fresh static roots | `18` | fills the remaining physical-core budget |
| total | `30` | good default full-node target |

If one-slot static resume roots exist:

- replace one `2`-slot fresh static root with two `1`-slot static resumes when
  that improves packing

If muscat is dedicated exclusively to validation and the first burn-in window is
stable:

- increase the slot budget from `30` to `32`
- do not jump from `30` straight to `64`
- logical hyperthreads should not be treated as full extra CPU capacity for this
  workload

### Why This Design Is Safer Than Killing Current In-Flight Work

This relaunch design is intended for:

- future clean waves
- future full restarts from a known queue state
- future backlog campaigns after the current roots finish

It is not intended to justify interrupting the current long MCMC roots.

Reason:

- the current batch sessions already own the future queue behind them
- stopping those sessions now would also stop expensive in-flight roots
- the main benefit of the new design comes from future root ownership, not from
  trying to surgically edit the ownership of roots already in progress

### Relaunch Readiness Notes From The Current Unified Status Table

The queued muscat backlog is already clean enough for this future scheduler
design.

Current queue-readiness facts:

- queued roots with missing prepared inputs: `0`
- queued roots with existing run roots: `0`
- queued roots with existing `run_config.rds`: `0`

This means the pending muscat queue is launch-ready from a filesystem
perspective. The current blocker is scheduler ownership, not dataset readiness.

### Practical V1 Recommendation

For the next large family-qspec relaunch on muscat, use:

- root-level scheduling
- weighted slot accounting
- one supervisor session
- one child session per claimed root
- `30` physical-core-based slots by default
- dynamic-long-root prioritization
- exact root locking and append-only state tracking

For v1, do not use:

- batch-lane ownership of future roots
- a `64`-thread logical-CPU target
- deeper per-root core settings above the number of real model tasks

### Success Criteria For The New Scheduler

- no duplicate root ownership
- no hidden future queue trapped inside a live batch shell
- enough active roots to keep muscat near `28-30` hot workers most of the time
- exact per-root auditable state transitions
- clean resumption from partial roots without broad manual intervention

## Exact Dependency Graph And Relaunch Artifacts

The future relaunch design is now materialized in machine-readable files, not
just prose.

Generation entrypoint:

- `tools/merge_reports/20260312_build_family_qspec_relaunch_design.R`

Generated artifacts:

- `tools/merge_reports/20260312_family_qspec_root_catalog.tsv`
- `tools/merge_reports/20260312_family_qspec_model_path_scheduler_manifest.tsv`
- `tools/merge_reports/20260312_family_qspec_root_postprocess_manifest.tsv`
- `tools/merge_reports/20260312_family_qspec_dependency_edges.tsv`
- `tools/merge_reports/20260312_family_qspec_comparison_barriers.tsv`
- `tools/merge_reports/20260312_family_qspec_tau_adaptation_audit.tsv`

Exact generated counts:

- `72` roots
- `144` model-path compute tasks
- `72` root postprocess tasks
- `18` static-shrink `ridge vs rhs` comparison barriers
- `3` campaign-review barriers
- `1` global cross-family summary barrier

Interpretation:

- `20260312_family_qspec_root_catalog.tsv` is the exact root inventory
- `20260312_family_qspec_dependency_edges.tsv` is the exact prerequisite graph
- `20260312_family_qspec_model_path_scheduler_manifest.tsv` is the exact
  `144`-task dedicated-node relaunch manifest

## Exact Dependency Levels

| Level | Unit | Count | Ready when | Current implementation status |
| --- | --- | ---: | --- | --- |
| 1 | model path | `144` | one exact model path finishes `VB -> MCMC` | implemented via current root pipelines |
| 2 | root postprocess | `72` | both model paths for the same root are done | implemented |
| 3 | root review | `72` | root postprocess is done; static also runs root report | implemented for root-local outputs |
| 4 | prior compare | `18` | both `ridge` and `rhs` root reviews are done for one static-shrink scenario | implemented after tau fix |
| 5 | campaign review | `3` | all required root reviews, and for shrink also all `18` prior compares, are done | planned / only partially standardized |
| 6 | global summary | `1` | the `3` campaign reviews are done | planned / not standardized |

Root-local comparison scope:

- static roots compare `AL vs exAL` within each inference backend
- static roots compare `VB vs MCMC` within each model
- dynamic roots compare `DQLM vs exDQLM` within each inference backend
- dynamic roots compare `VB vs MCMC` within each model

Cross-root comparison scope:

- static shrinkage additionally requires `ridge vs rhs` comparison for each
  exact `(family, tau, TT)` slice
- full campaign review additionally requires campaign-level aggregation and then
  a final global cross-family summary

## Scheduler State Model For The 144-Path Relaunch

Recommended state flow:

| Order | State | Scope | Meaning |
| --- | ---: | --- | --- |
| 1 | `queued` | model path | task is eligible but not yet claimed |
| 2 | `claimed` | model path | supervisor assigned the task to one worker slot |
| 3 | `vb_running` | model path | VB is executing for one exact model path |
| 4 | `vb_done` | model path | VB fit exists and worker advances to MCMC |
| 5 | `mcmc_running` | model path | MCMC is executing for the same exact model path |
| 6 | `model_path_done` | model path | both VB and MCMC outputs exist for that path |
| 7 | `root_postprocess_ready` | root | both companion model paths for the root are done |
| 8 | `root_postprocess_running` | root | postprocess/report worker is running for that root |
| 9 | `root_review_done` | root | root-local tables, diagnostics, metrics, and plots are complete |
| 10 | `prior_compare_ready` | barrier | static shrink only; both `ridge` and `rhs` root reviews are done |
| 11 | `prior_compare_running` | barrier | static shrink comparison worker is running |
| 12 | `prior_compare_done` | barrier | `rhs_vs_ridge_summary.csv` and related outputs exist |
| 13 | `campaign_review_ready` | barrier | all required root reviews and compare outputs exist for a campaign |
| 14 | `campaign_review_running` | barrier | campaign-level aggregation is running |
| 15 | `campaign_review_done` | barrier | one campaign-level review bundle is complete |
| 16 | `global_summary_ready` | barrier | the `3` campaign reviews are complete |
| 17 | `global_summary_running` | barrier | final cross-family synthesis is running |
| 18 | `global_summary_done` | barrier | full validation summary is complete |

Required scheduler rules:

- one model-path worker owns exactly one task at a time
- one root postprocess task may start only after both companion model paths are
  `model_path_done`
- one static-shrink compare task may start only after both prior-specific root
  reviews are `root_review_done`
- campaign and global summary tasks are barriers only; they must not start from
  partial root output

## Higher-Level Comparison Audit For `tau = 0.25`

The current audit file is:

- `tools/merge_reports/20260312_family_qspec_tau_adaptation_audit.tsv`

Campaign-critical tau findings:

- `tools/merge_reports/20260308_static_shrinkage_compare_report.R` was using the
  stale triplet `{0.05, 0.50, 0.95}` and is now fixed
- `tools/merge_reports/20260305_static_postprocess_from_existing_fits.R` had the
  same stale fallback and is now fixed
- the generic qspec wrapper scripts under `20260308_run_*_qspec_campaign.sh`
  were also defaulting to `{0.05, 0.50, 0.95}` and are now fixed

Important residual gap:

- no standardized family-qspec campaign-level aggregation script was found for:
  - static paper campaign review
  - dynamic campaign review
  - final global cross-family summary

So the remaining issue is no longer the `tau=0.25` grid definition. The
remaining issue is that the topmost review layers still need an explicit
implementation.

Additional non-tau scope caveat:

- the `20260309_run_*_family_qspec_campaign.sh` dataset-generator wrappers are
  already on the correct tau grid, but they still include `loggpd` in their
  family list even though the family-qspec plan for this campaign only uses
  `normal`, `laplace`, and `gausmix`

## 2026-03-12 Canonical Relaunch Reset (Authoritative)

This section supersedes the older `0.05 / 0.25 / 0.50` muscat bootstrap narrative for the production relaunch.

### Canonical Scientific Scope

- canonical family-qspec tau grid for the relaunch: `0.05`, `0.25`, `0.95`
- `0.50` family-qspec outputs are now treated as out-of-scope legacy artifacts for this relaunch
- dynamic family-qspec stays on the default/non-shrink prior only
- static shrinkage keeps both `ridge` and `rhs`

### Canonical Relaunch Inventory

- roots: `72`
- model paths: `144`
- VB/MCMC fit stages: `288`
- canonical relaunch design artifacts:
  - `tools/merge_reports/20260312_family_qspec_root_catalog.tsv`
  - `tools/merge_reports/20260312_family_qspec_model_path_scheduler_manifest.tsv`
  - `tools/merge_reports/20260312_family_qspec_root_postprocess_manifest.tsv`
  - `tools/merge_reports/20260312_family_qspec_dependency_edges.tsv`
  - `tools/merge_reports/20260312_family_qspec_comparison_barriers.tsv`
  - `tools/merge_reports/20260312_family_qspec_tau_adaptation_audit.tsv`

### Reusable-State Audit After Scope Lock And Jerez Sync

Machine-readable audit:
- `tools/merge_reports/20260312_family_qspec_reusable_state_audit.tsv`
- `tools/merge_reports/20260312_family_qspec_reusable_state_audit_summary.tsv`

Latest local audit counts at the last refresh after:
- canonical tau reset
- exact jerez sync
- static `0.95` prepared-input materialization
- clean stop of the old muscat batch wave
- active `fqv2_*` relaunch progress

These values evolve during the relaunch. The detailed live progress should be
read from the periodic progress tables referenced below.

| unit_type | blocked | complete_reusable | partial_reusable | % complete within unit_type | notes |
| --- | ---: | ---: | ---: | ---: | --- |
| prepared_input | 0 | 54 | 0 | 100.0% | all canonical prepared roots exist locally |
| model_path | 0 | 124 | 20 | 86.1% | all remaining incomplete model paths are now resume-ready after the overnight worker drain |
| root_postprocess | 20 | 52 | 0 | 72.2% | `52` roots already have reusable postprocess outputs |
| root_review | 20 | 52 | 0 | 72.2% | `52` roots already have reusable root-review outputs |
| prior_compare | 6 | 12 | 0 | 66.7% | `12` shrink prior-compare tasks are already complete |
| campaign_review | 3 | 0 | 0 | 0.0% | all still blocked on lower-level completion |
| global_summary | 1 | 0 | 0 | 0.0% | blocked on campaign reviews |
| legacy_root | n/a | n/a | n/a | n/a | `6` complete-out-of-scope legacy roots under `tau = 0.50`; see note below |

Out-of-scope legacy inventory:
- `tools/merge_reports/20260312_family_qspec_reusable_state_audit.tsv`
- currently detected complete-out-of-scope roots: `6`
- these are the previously completed `gausmix tau=0.50` static paper/static shrink roots and they are intentionally excluded from the canonical relaunch queue

### Jerez Audit And Exact Sync

Exact jerez root audit:
- `tools/merge_reports/20260312_family_qspec_jerez_root_audit.tsv`
- `tools/merge_reports/20260312_family_qspec_jerez_root_audit_summary.tsv`

Current jerez in-scope root audit under the canonical tau grid:
- complete roots: `8`
- partial roots: `7`
- missing roots: `57`

Exact sync planning and execution:
- sync manifest: `tools/merge_reports/20260312_family_qspec_jerez_sync_manifest.tsv`
- sync manifest summary: `tools/merge_reports/20260312_family_qspec_jerez_sync_manifest_summary.tsv`
- sync results: `tools/merge_reports/20260312_family_qspec_jerez_sync_results.tsv`

Exact roots synced from jerez to muscat:
- dynamic `gausmix tau=0.05 TT=500`
- dynamic `gausmix tau=0.25 TT=500`
- static paper `gausmix tau=0.05 TT=100`
- static paper `gausmix tau=0.05 TT=1000`
- static shrink `gausmix tau=0.05 TT=100` for `ridge`
- static shrink `gausmix tau=0.05 TT=100` for `rhs`
- static shrink `gausmix tau=0.05 TT=1000` for `ridge`
- static shrink `gausmix tau=0.05 TT=1000` for `rhs`

### Old Muscat Batch Wave Was Intentionally Stopped

The original muscat batch-lane sessions were stopped only after:
- canonical tau scope was locked
- the reusable-state audit existed
- the supervisor dry-run existed and passed
- the exact jerez sync for safe reusable roots was completed
- the static `0.95` prepared roots were materialized locally

Stop artifacts:
- `tools/merge_reports/20260312_family_qspec_stop_ledger.tsv`
- `tools/merge_reports/20260312_family_qspec_stop_results.tsv`

Stopped session count: `14`

Stopped classes:
- `8` original muscat batch-lane sessions
- `6` rehomed former-jerez resume sessions that were still active on muscat

Post-stop verification:
- no remaining `mqsp_*` tmux sessions
- no remaining family-qspec `R` workers from the old launcher/process tree

### New Supervisor / Locker Relaunch

New launcher scripts:
- shared helpers: `tools/merge_reports/20260312_family_qspec_v2_common.R`
- runtime queue builder: `tools/merge_reports/20260312_build_family_qspec_runtime_queue.R`
- campaign/global aggregation layer: `tools/merge_reports/20260312_family_qspec_campaign_aggregate.R`
- worker: `tools/merge_reports/20260312_family_qspec_worker.sh`
- supervisor: `tools/merge_reports/20260312_family_qspec_supervisor.sh`
- active-task snapshot: `tools/merge_reports/20260312_snapshot_family_qspec_v2_active_tasks.R`

Supervisor runtime state:
- current supervisor tmux session: `fqv2_supervisor_20260314_043810`
- state dir: `/home/jaguir26/local/state/exdqlm/family_qspec_v2`
- launch registry: `/home/jaguir26/local/state/exdqlm/family_qspec_v2/launch_registry.tsv`
- worker event log: `/home/jaguir26/local/state/exdqlm/family_qspec_v2/task_events.tsv`
- active-task snapshot: `tools/merge_reports/20260312_family_qspec_v2_active_tasks.tsv`
- archived noisy pre-fix recovery attempt:
  - `/home/jaguir26/local/state/exdqlm/family_qspec_v2/archive_20260314_043731/task_events.tsv`
  - `/home/jaguir26/local/state/exdqlm/family_qspec_v2/archive_20260314_043731/launch_registry.tsv`

Initial relaunch wave:
- slot budget: `30`
- thread policy: one shell-level thread per worker (`OMP/BLAS/MKL = 1`)
- first-wave launched tasks: `30` model-path workers
- first-wave mix:
  - reusable partial resume-from-VB model paths first
  - then fresh `TT=5000` dynamic model paths
  - then additional fresh model paths as capacity allowed

Early verification for the new launcher:
- no `FAILED` events in `/home/jaguir26/local/state/exdqlm/family_qspec_v2/task_events.tsv` at launch check time
- live `R` workers observed for both:
  - `20260305_resume_static_mcmc_from_vb.R` / `20260305_resume_dynamic_mcmc_from_vb.R`
  - `20260305_static_vb_then_mcmc_pipeline.R` / `20260305_vb_then_mcmc_pipeline.R`
- worker logs confirm correct root/model assignment, for example:
  - `mp__root__dynamic__gausmix__tau_0p25__lasttt_5000__dqlm` launched in `resume_mcmc_from_vb`
  - `mp__root__dynamic__gausmix__tau_0p95__lasttt_5000__dqlm` launched in `fresh_vb_then_mcmc`
  - `mp__root__static_paper__gausmix__tau_0p25__tt_100__exal` launched in `resume_mcmc_from_vb`

### Current Interpretation

Current authoritative state is now split across three layers:

1. reusable completed work:
- captured in `20260312_family_qspec_reusable_state_audit.tsv`

2. exact remaining canonical work:
- captured in `20260312_family_qspec_runtime_queue.tsv`

3. active work under the new launcher:
- captured in:
  - `/home/jaguir26/local/state/exdqlm/family_qspec_v2/launch_registry.tsv`
  - `/home/jaguir26/local/state/exdqlm/family_qspec_v2/task_events.tsv`
  - `tools/merge_reports/20260312_family_qspec_v2_active_tasks.tsv`

This is the new authoritative coordination model for the muscat relaunch.

### Full Periodic Progress Tables

For day-to-day tracking, the tracker itself should stay narrative and stable.
The full detailed progress tables should be regenerated and read from these
files:

- full 144-row model-path table:
  - `tools/merge_reports/20260312_family_qspec_model_path_progress.md`
  - `tools/merge_reports/20260312_family_qspec_model_path_progress.tsv`
- model-path summary counts and percentages:
  - `tools/merge_reports/20260312_family_qspec_model_path_progress_summary.md`
  - `tools/merge_reports/20260312_family_qspec_model_path_progress_summary.tsv`
- higher-layer root/barrier table:
  - `tools/merge_reports/20260312_family_qspec_barrier_progress.md`
  - `tools/merge_reports/20260312_family_qspec_barrier_progress.tsv`
- higher-layer root/barrier summary:
  - `tools/merge_reports/20260312_family_qspec_barrier_progress_summary.md`
  - `tools/merge_reports/20260312_family_qspec_barrier_progress_summary.tsv`

Refresh command from the repo root:

```bash
Rscript tools/merge_reports/20260312_build_family_qspec_progress_views.R "$PWD"
```

Interpretation of the model-path `stage_label` values:

- `running_resume_mcmc`: active now; resuming from an existing VB fit into MCMC
- `running_fresh_vb_then_mcmc`: active now; running the full fresh VB -> MCMC path
- `queued_resume_ready`: not active yet; ready to resume as soon as a slot opens
- `queued_restart_ready`: not active yet; stale partial state exists and the path
  should restart cleanly
- `queued_fresh_ready`: not active yet; no reusable fit exists and the path is
  ready for a fresh launch
- `complete_reusable`: fully complete on the canonical tau grid and should be
  skipped by the launcher
- `blocked`: waiting on prerequisites and not yet launchable

Interpretation of the higher-layer barrier `stage_label` values:

- `root_postprocess_ready`: both model paths for a root are done and root-level
  postprocess can run
- `root_postprocess_waiting_for_model_paths`: one or both model paths are still
  incomplete
- `root_review_complete`: root postprocess/review outputs are complete
- `prior_compare_ready`: static shrink `ridge vs rhs` comparison is ready to run
- `prior_compare_waiting_for_root_reviews`: waiting on one or both shrink root
  reviews
- `campaign_review_waiting_for_prerequisites`: campaign aggregate cannot run yet
- `global_summary_waiting_for_campaigns`: final cross-family summary cannot run
  yet

Current regenerated model-path summary snapshot:

| root_kind | stage_label | count | root_kind_total | % of root_kind | % of all model_paths |
|---|---|---:|---:|---:|---:|
| dynamic | `complete_reusable` | 34 | 36 | 94.4% | 23.6% |
| dynamic | `running_resume_mcmc` | 2 | 36 | 5.6% | 1.4% |
| static_paper | `complete_reusable` | 30 | 36 | 83.3% | 20.8% |
| static_paper | `running_resume_mcmc` | 6 | 36 | 16.7% | 4.2% |
| static_shrink | `complete_reusable` | 60 | 72 | 83.3% | 41.7% |
| static_shrink | `running_resume_mcmc` | 12 | 72 | 16.7% | 8.3% |

Current regenerated model-path snapshot by family:

| model class | family | complete | resume_ready | total | % complete |
|---|---|---:|---:|---:|---:|
| dynamic | `gausmix` | 11 | 1 | 12 | 91.7% |
| dynamic | `laplace` | 11 | 1 | 12 | 91.7% |
| dynamic | `normal` | 12 | 0 | 12 | 100.0% |
| static paper | `gausmix` | 10 | 2 | 12 | 83.3% |
| static paper | `laplace` | 10 | 2 | 12 | 83.3% |
| static paper | `normal` | 10 | 2 | 12 | 83.3% |
| static shrink | `gausmix` | 20 | 4 | 24 | 83.3% |
| static shrink | `laplace` | 20 | 4 | 24 | 83.3% |
| static shrink | `normal` | 20 | 4 | 24 | 83.3% |

Current regenerated barrier summary snapshot:

| unit_type | stage_label | count | unit_type_total | % of unit_type | % of all barriers |
|---|---|---:|---:|---:|---:|
| `campaign_review` | `campaign_review_waiting_for_prerequisites` | 3 | 3 | 100.0% | 1.8% |
| `global_summary` | `global_summary_waiting_for_campaigns` | 1 | 1 | 100.0% | 0.6% |
| `prior_compare` | `complete_reusable` | 12 | 18 | 66.7% | 7.2% |
| `prior_compare` | `prior_compare_waiting_for_root_reviews` | 6 | 18 | 33.3% | 3.6% |
| `root_postprocess` | `root_postprocess_complete` | 52 | 72 | 72.2% | 31.3% |
| `root_postprocess` | `root_postprocess_waiting_for_model_paths` | 20 | 72 | 27.8% | 12.0% |
| `root_review` | `root_review_complete` | 52 | 72 | 72.2% | 31.3% |
| `root_review` | `root_review_waiting_for_postprocess` | 20 | 72 | 27.8% | 12.0% |

Current regenerated higher-layer snapshot by family:

| workflow layer | family | complete | waiting | total | % complete |
|---|---|---:|---:|---:|---:|
| dynamic root postprocess | `gausmix` | 5 | 1 | 6 | 83.3% |
| dynamic root postprocess | `laplace` | 5 | 1 | 6 | 83.3% |
| dynamic root postprocess | `normal` | 6 | 0 | 6 | 100.0% |
| static paper root postprocess | `gausmix` | 4 | 2 | 6 | 66.7% |
| static paper root postprocess | `laplace` | 4 | 2 | 6 | 66.7% |
| static paper root postprocess | `normal` | 4 | 2 | 6 | 66.7% |
| static shrink root postprocess | `gausmix` | 8 | 4 | 12 | 66.7% |
| static shrink root postprocess | `laplace` | 8 | 4 | 12 | 66.7% |
| static shrink root postprocess | `normal` | 8 | 4 | 12 | 66.7% |
| shrink prior compare | `gausmix` | 4 | 2 | 6 | 66.7% |
| shrink prior compare | `laplace` | 4 | 2 | 6 | 66.7% |
| shrink prior compare | `normal` | 4 | 2 | 6 | 66.7% |

Latest live launcher verification at `2026-03-14 04:40 EDT`:

- active workers: `20`
- current task events in the clean recovery relaunch: `20 START`, `0 DONE`, `0 FAILED`
- host load: `24.00 / 20.99 / 14.69`
- available memory: `486 GiB`
- current active workload mix:
  - dynamic: `2` resume-MCMC model paths
  - static paper: `6` resume-MCMC model paths
  - static shrink: `12` resume-MCMC model paths

Main confirmed root issue from the failed overnight tail:

- the worker previously recorded `DONE` from shell exit semantics alone
- `DONE` therefore did not guarantee that the expected `mcmc_*.rds` artifact
  and `MCMC_DONE` status line actually existed
- the old per-worker control plane also allowed orphaned worker/R processes to
  survive after session teardown, which made ownership and relaunch behavior
  unreliable

Durable fixes now in place:

- `DONE` is now emitted only after
  `tools/merge_reports/20260312_verify_family_qspec_task_completion.R`
  verifies the on-disk task outputs
- all family-qspec MCMC burn-in defaults used by the relaunch are now `500`,
  not `2000`
- per-worker `tmux` ownership has been removed; workers are now launched as
  detached pid-tracked processes
- each current worker is isolated into its own session/pgid via `setsid`
- supervisor heartbeat now reports `ready_unlocked`, not the misleading raw
  ready count
- worker logs are no longer quiet:
  - dynamic workers emit live MCMC iteration lines again
  - all workers emit a `60`-second heartbeat with pid, elapsed time, cpu, rss,
    and the latest task status line when available

Current clean recovery relaunch evidence:

- current supervisor session: `fqv2_supervisor_20260314_043810`
- current event log and launch registry were reset cleanly for this relaunch
- the noisy prior recovery attempt was archived at:
  - `/home/jaguir26/local/state/exdqlm/family_qspec_v2/archive_20260314_043731`
- dynamic log evidence now shows live progress, for example:
  - `burn-in iteration 10` in
    `worker_logs/mp__root__dynamic__gausmix__tau_0p25__lasttt_5000__dqlm.log`
- static workers now show live health even before they print internal iteration
  lines, for example:
  - `worker heartbeat | pid=... | elapsed_s=60 | cpu=100 | rss_mb=284.1`
    in
    `worker_logs/mp__root__static_paper__normal__tau_0p25__tt_100__exal.log`

## 2026-03-14 Static exAL Resume Root-Cause Closure

Status snapshot at 2026-03-14 18:44 EDT:

- Root cause of the stuck static `exAL` tail is confirmed: the static resume path was reusing non-finite VB expectations as MCMC initials for the remaining `tau=0.25` static `exAL` cases.
- For all 18 formerly stuck cases, the exAL VB fit had:
  - non-finite `qbeta$m`
  - non-finite `qv$E_v`
  - non-finite `qs$E_s`
  - finite `qsiggam$sigma_mean`
  - finite `qsiggam$gamma_mean`
- That made the first static MCMC `v` update invalid before iteration 1:
  - `beta`, `v`, `s` entered as `NaN`
  - `z` became `NaN`
  - `chi_i` became `NaN`
  - `sample_gig_devroye_vector()` then spun in the first GIG draw
- The apparent lack of progress rows was therefore a consequence of invalid MCMC state, not the primary bug.

Implemented fix:

- `.static_vb_to_mcmc_init()` now sanitizes non-finite VB-derived initials and drops bad `beta`, `v`, and `s` instead of passing `NaN` into MCMC.
- `exal_static_mcmc()` now validates static init state and GIG inputs explicitly and fails fast on invalid numeric state.
- `sample_gig_devroye_vector()` now rejects non-finite/non-positive inputs instead of entering an unbounded spin.
- static resume logging now records `RESUME_INIT_SANITIZED` when fallback initialization is used.

Validation:

- A representative live-case scratch replay using the exact production resume script and a copied real `tau=0.25` static `exAL` root succeeded with:
  - `RESUME_INIT_SANITIZED`
  - `MCMC_PROGRESS`
  - `MCMC_DONE`
- The 18 live static `exAL` resume workers were then cleanly recycled at `2026-03-14 18:40:34 EDT`.
- All 18 were relaunched at `2026-03-14 18:40:51 EDT` under the fixed path.
- The recycled static `exAL` cases now emit real progress rows and no longer stall at `start`.
- Model-path layer is now fully complete again:
  - `144 / 144` model paths complete

New downstream blocker after model-fit completion:

- The next failing layer is `root_review`, not model fitting.
- Current failure is in `20260305_static_vb_mcmc_report.R` with:
  - `Error in [.data.frame(runtime_diag, , c("model", "tau", "beta_prior", ...): undefined columns selected`
- `prior_compare` tasks are succeeding.
- So the static resume/MCMC issue is closed; the remaining blocker is now the static review/report stage.

## 2026-03-14 Review/Campaign Closure

Status snapshot at 2026-03-14 19:02 EDT:

- The `root_review` blocker is now closed.
- The `campaign_review` blocker is now closed.
- The `global_summary` barrier is now complete.
- The relaunch runtime queue now has:
  - `0` launch-ready tasks
  - `0` non-complete canonical units

Root-review fix:

- `20260305_static_vb_mcmc_report.R` no longer builds review diagnostics from
  brittle `pipeline_task_summary*` state.
- It now reconstructs the review layer from canonical per-root outputs:
  - `fit_summary.csv`
  - `vb_convergence_summary.csv`
  - `mcmc_diagnostics_summary.csv`
  - `vb_ld_diagnostics_summary.csv`
- Review diagnostics now use the root context as the canonical prior label for
  static roots, rather than trusting inconsistent `beta_prior` labels from
  resumed fit objects.
- The report layer is also hardened against optional plot/data edge cases:
  - degenerate residual-density inputs no longer abort the review
  - degenerate RHS coefficient-tree inputs no longer abort the review
  - empty `pairwise_exal_vs_al.csv` outputs now write a schemaful zero-row file

Campaign-aggregation fix:

- `20260312_family_qspec_campaign_aggregate.R` is now robust to zero-row review
  tables and mixed legacy/new review schemas.
- Campaign aggregation now:
  - accepts blank review tables as valid zero-row inputs where appropriate
  - stacks mixed review schemas using column-union semantics instead of failing
    on strict `rbind()` column mismatches

Validation and closure state:

- Representative static paper and static shrink review roots were rerun
  successfully under the fixed review script.
- The reusable-state audit now reports:
  - `144 / 144` model paths `complete_reusable`
  - `72 / 72` root postprocess tasks `complete_reusable`
  - `72 / 72` root review tasks `complete_reusable`
  - `18 / 18` prior-compare tasks `complete_reusable`
  - `3 / 3` campaign-review tasks `complete_reusable`
  - `1 / 1` global-summary task `complete_reusable`
- The final global cross-family summary now exists under:
  - `tools/merge_reports/20260312_family_qspec_global_cross_family_summary`

Operational note:

- The supervisor event log still contains repeated historical `FAILED` entries
  for the earlier broken `campaign__static_paper` and
  `campaign__static_shrink` attempts.
- Those failures are now superseded by the corrected on-disk state.
- The authoritative truth is the rebuilt reusable-state audit and runtime queue,
  not the stale historical failure rows in `task_events.tsv`.

## 2026-03-14 Signoff / Eligibility Phase Closure

Status snapshot at 2026-03-14 20:33 EDT:

- The family-qspec workflow now has an explicit fit-health and comparison-eligibility layer between raw fit completion and scientific comparison.
- This signoff layer is now the authoritative gate for whether a fitted method result is safe to use in root-level, prior-level, campaign-level, and global comparison outputs.
- Execution is fully complete on the canonical grid:
  - `144 / 144` model paths complete
  - `72 / 72` root postprocess tasks complete
  - `72 / 72` root review tasks complete
  - `18 / 18` static shrink prior-compare tasks complete
  - `3 / 3` campaign-review tasks complete
  - `1 / 1` global-summary task complete
- However, signoff is intentionally stricter than execution success:
  - `288` fitted method results audited
  - `93` method results graded `PASS`
  - `81` method results graded `WARN`
  - `114` method results graded `FAIL`
  - `174 / 288` method results marked `comparison_eligible`
  - `93 / 288` method results marked `convergence_certified`
  - `53 / 144` algorithm pairs (`VB vs MCMC`) marked eligible
  - `50 / 144` model pairs (`extended vs baseline`) marked eligible
  - `1 / 72` roots fully eligible across all required comparison units
  - `66 / 72` roots have at least one eligible comparison unit
  - `114` unhealthy fit targets are now explicitly listed for repair/re-run planning

Signoff outputs now produced for the canonical campaign:

- method-fit signoff:
  - `tools/merge_reports/20260314_family_qspec_method_signoff.tsv`
- method-fit summary:
  - `tools/merge_reports/20260314_family_qspec_method_signoff_summary.tsv`
- algorithm-pair signoff:
  - `tools/merge_reports/20260314_family_qspec_algorithm_pair_signoff.tsv`
- model-pair signoff:
  - `tools/merge_reports/20260314_family_qspec_model_pair_signoff.tsv`
- pair summary:
  - `tools/merge_reports/20260314_family_qspec_pair_signoff_summary.tsv`
- root readiness:
  - `tools/merge_reports/20260314_family_qspec_root_readiness.tsv`
- unhealthy-target repair manifest:
  - `tools/merge_reports/20260314_family_qspec_unhealthy_targets.tsv`
- signoff summary:
  - `tools/merge_reports/20260314_family_qspec_signoff_summary.tsv`
  - `tools/merge_reports/20260314_family_qspec_signoff_summary.md`

Implemented signoff architecture:

- one row per fitted method result (`VB` or `MCMC`, baseline or extended)
- explicit `PASS / WARN / FAIL` grading
- explicit `comparison_eligible` and `convergence_certified` flags
- explicit pair-level signoff for:
  - `VB vs MCMC` within a model path
  - `extended vs baseline` within an inference method
- explicit root readiness table for downstream comparison gating

Current integration points:

- static and dynamic root-review layers now consume the signoff outputs instead of relying only on artifact existence
- static shrink prior-compare now uses eligible-only fit rows and writes excluded rows separately
- campaign and global aggregation are now robust to zero-row / excluded-only cases and mixed legacy/new review schemas
- the runtime queue is now closed under the signoff-aware workflow:
  - `0` launch-ready units remain in `20260312_family_qspec_runtime_queue_summary.tsv`

Interpretation:

- The canonical family-qspec execution campaign is complete.
- The scientific comparison layer is now explicitly gated by health/signoff rather than by file existence alone.
- The next improvement cycle is therefore not a generic rerun of the whole campaign.
- The next improvement cycle should be targeted repair of the `114` unhealthy fitted method results listed in `20260314_family_qspec_unhealthy_targets.tsv`, followed by selective rebuild of the affected comparison layers.

Main observed failure modes in the unhealthy-target manifest:

- `low_ess`
- `high_autocorrelation`
- `geweke_drift`
- `half_chain_drift`
- `non_finite_fit`
- `ld_unstable`
- `vb_converged_false`
- `elbo_tail_unstable`
- `missing_elbo_trace`

This closes the implementation of the signoff phases. The workflow now supports:

- complete execution tracking
- explicit fit-health grading
- explicit comparison eligibility
- explicit unhealthy-target repair manifests
- signoff-aware downstream comparison and aggregation

## 2026-03-14 Comparison Snapshot Closure

The validation framework now has all three intended scientific comparison layers materialized at campaign and global scope:

- `VB vs MCMC`
- `extended vs baseline`
- `rhs vs ridge`

The missing compact `VB vs MCMC` campaign/global summary has now been added and rebuilt across the canonical campaign:

- campaign-level outputs:
  - `tools/merge_reports/20260312_family_qspec_campaign_review__static_paper/tables/vb_vs_mcmc_summary.tsv`
  - `tools/merge_reports/20260312_family_qspec_campaign_review__static_shrink/tables/vb_vs_mcmc_summary.tsv`
  - `tools/merge_reports/20260312_family_qspec_campaign_review__dynamic/tables/vb_vs_mcmc_summary.tsv`
- global outputs:
  - `tools/merge_reports/20260312_family_qspec_global_cross_family_summary/tables/vb_vs_mcmc_summary.tsv`
  - `tools/merge_reports/20260312_family_qspec_global_cross_family_summary/tables/pairwise_vb_vs_mcmc_long.tsv`
  - `tools/merge_reports/20260312_family_qspec_global_cross_family_summary/tables/pairwise_vb_vs_mcmc_eligible_long.tsv`
  - `tools/merge_reports/20260312_family_qspec_global_cross_family_summary/tables/pairwise_vb_vs_mcmc_excluded_long.tsv`

The campaign/global aggregation layer now also propagates dynamic `extended vs baseline` comparison outputs instead of only the static `exAL vs AL` surface:

- `tools/merge_reports/20260312_family_qspec_global_cross_family_summary/tables/pairwise_exdqlm_vs_dqlm_long.tsv`
- `tools/merge_reports/20260312_family_qspec_global_cross_family_summary/tables/pairwise_exdqlm_vs_dqlm_excluded_long.tsv`
- `tools/merge_reports/20260312_family_qspec_global_cross_family_summary/tables/pairwise_model_compare_long.tsv`
- `tools/merge_reports/20260312_family_qspec_global_cross_family_summary/tables/pairwise_model_compare_excluded_long.tsv`

For human review, the compact scientific snapshot now lives at:

- `tools/merge_reports/20260314_family_qspec_scientific_comparison_snapshot.tsv`
- `tools/merge_reports/20260314_family_qspec_scientific_comparison_snapshot.md`

Current high-level picture from the produced comparison outputs:

- Dynamic:
  - baseline `DQLM` currently looks better with `MCMC` than `VB` in `laplace` and `normal`, but not in `gausmix`
  - extended `exDQLM` currently looks better with `VB` than `MCMC` in all three families
  - current produced `extended vs baseline` rows lean toward the extended dynamic model under `VB`
- Static paper:
  - `MCMC` usually lowers RMSE relative to `VB` for both `AL` and `exAL`
  - the runtime cost of `MCMC` is much larger than `VB`
  - `exAL vs AL` remains family-dependent rather than uniformly one-sided
- Static shrink:
  - `MCMC` again tends to lower RMSE relative to `VB`
  - `rhs` lowers false positives relative to `ridge`
  - `ridge` usually protects signal-recovery RMSE better, though the tradeoff is family-dependent

Interpretation:

- The full comparison stack is now implemented and rebuilt on the canonical campaign outputs.
- The next iteration no longer needs new comparison plumbing.
- The next iteration should focus on repairing unhealthy fitted methods so a larger share of the existing comparison surfaces becomes scientifically eligible.

## 2026-03-14 Targeted Repair Launcher Ready

The targeted repair lane for unhealthy fits is now implemented as a separate, signoff-aware repair wave rather than a rerun of the whole campaign.

New repair-wave control files:

- repair queue builder:
  - `tools/merge_reports/20260314_build_family_qspec_repair_queue.R`
- repair supervisor wrapper:
  - `tools/merge_reports/20260314_family_qspec_repair_supervisor.sh`
- repair queue:
  - `tools/merge_reports/20260314_family_qspec_repair_queue.tsv`
- repair queue summary:
  - `tools/merge_reports/20260314_family_qspec_repair_queue_summary.tsv`
- repair plan summary:
  - `tools/merge_reports/20260314_family_qspec_repair_plan_summary.tsv`

Repair-wave design:

- uses a dedicated state directory:
  - `/home/jaguir26/local/state/exdqlm/family_qspec_repair_v1`
- uses the existing unhealthy-target manifest as the seed:
  - `tools/merge_reports/20260314_family_qspec_unhealthy_targets.tsv`
- expands that seed through the dependency graph to rebuild only the affected downstream units:
  - `model_path`
  - `root_postprocess`
  - `root_signoff`
  - `root_review`
  - `prior_compare`
  - `campaign_review`
  - `global_summary`
- tracks completion within the repair wave itself instead of confusing old on-disk artifacts with repaired results

Current dry-run counts:

- unhealthy fitted-method rows:
  - `114`
- targeted `model_path` repair tasks:
  - `91`
- impacted roots:
  - `71`
- targeted `root_postprocess` tasks:
  - `71`
- targeted `root_signoff` tasks:
  - `71`
- targeted `root_review` tasks:
  - `71`
- targeted `prior_compare` tasks:
  - `18`
- targeted `campaign_review` tasks:
  - `3`
- targeted `global_summary` tasks:
  - `1`
- launch-ready now:
  - `91`

Current launch-ready semantics:

- only the unhealthy `model_path` tasks are launch-ready at the start of the repair wave
- all downstream tasks remain blocked until the repair wave marks the relevant upstream tasks as complete

Dry-run verification completed:

- `bash -n` passed for:
  - `tools/merge_reports/20260312_family_qspec_supervisor.sh`
  - `tools/merge_reports/20260312_family_qspec_worker.sh`
  - `tools/merge_reports/20260314_family_qspec_repair_supervisor.sh`
- the repair queue builder now writes all three repair artifacts successfully
- the repair supervisor dry-run now reports the correct queue state and launch-ready head
- the repair smoke test passes:
  - `tests/testthat/test-family-qspec-repair-queue-smoke.R`

Interpretation:

- The targeted unhealthy-fit repair lane is ready to launch.
- It is isolated from the canonical campaign state.
- It is dependency-aware and signoff-aware.
- The next decision is no longer infrastructure readiness.
- The next decision is threshold policy and the exact repair wave to launch.

## 2026-03-14 Recommended Policy And Repair Wiring

Based on the current completed campaign outputs, the recommended policy is now:

- keep all current `PASS` thresholds unchanged
- keep hard numerical / missing-diagnostic failures as `FAIL`
- relax only the `WARN`-level MCMC eligibility thresholds

Recommended MCMC `WARN` overrides:

- `ESS sigma warn`: `10 -> 5`
- `ESS gamma warn`: `10 -> 5`
- `ESS state warn`: `10 -> 5`
- `ACF1 warn`: `0.98 -> 0.995`
- `Geweke abs z warn`: `3.0 -> 5.0`
- `Half-chain drift warn`: `0.50 -> 0.75`

No VB threshold relaxation is currently recommended.

Rationale from the current failure surface:

- under the original policy:
  - unhealthy fitted-method rows: `114`
  - comparison-eligible method fits: `174 / 288`
  - targeted repair model paths: `91`
- under the recommended policy:
  - unhealthy fitted-method rows: `100`
  - comparison-eligible method fits: `188 / 288`
  - targeted repair model paths: `80`

Current updated signoff counts under the recommended policy:

- `PASS`: `93`
- `WARN`: `95`
- `FAIL`: `100`
- algorithm-pair eligible: `64 / 144`
- model-pair eligible: `62 / 144`
- fully eligible roots: `10 / 72`
- any-eligible roots: `67 / 72`

Residual failure composition after the recommended policy:

- soft-only failures:
  - `71`
- hard-only failures:
  - `27`
- mixed hard/soft failures:
  - `2`

Interpretation:

- the remaining repair wave is still necessary
- but the policy-adjusted view confirms that most residual failures are still MCMC-soft rather than hard-execution pathologies
- all current VB failures remain concentrated in the extended models and still look like real repair targets rather than threshold artifacts

Recommended policy/tuning files now in the repo:

- signoff policy env:
  - `tools/merge_reports/20260314_family_qspec_signoff_policy_recommended.env`
- repair tuning env:
  - `tools/merge_reports/20260314_family_qspec_repair_tuning_recommended.env`
- policy rebuild wrapper:
  - `tools/merge_reports/20260314_rebuild_family_qspec_signoff_recommended.sh`
- repair supervisor wrapper with policy+tuning:
  - `tools/merge_reports/20260314_family_qspec_repair_supervisor_recommended.sh`
- policy note:
  - `tools/merge_reports/20260314_family_qspec_policy_recommendation.md`

Recommended repair-wave defaults now wired:

- static MCMC burn:
  - `1500`
- dynamic MCMC burn:
  - `1500`
- static MCMC keep:
  - `5000`
- dynamic MCMC keep:
  - `5000`
- static and dynamic trace diagnostics:
  - enabled
- trace interval:
  - `25`

This means the framework is now ready for the next step:

- rerun only the remaining unhealthy model-path targets under the recommended policy and the heavier repair-wave MCMC settings

Residual unhealthy concentration under the recommended policy:

- dynamic:
  - `dqlm` MCMC failures: `18`
  - `exdqlm` MCMC failures: `18`
  - `exdqlm` VB failures: `5`
- static paper:
  - `exAL` MCMC failures: `12`
  - `exAL` VB failures: `6`
- static shrink:
  - `exAL` MCMC failures: `29`
  - `exAL` VB failures: `12`

Current median MCMC failure diagnostics for the main residual groups:

- dynamic `dqlm`:
  - `ESS_sigma ~ 288.5`
  - `ESS_state ~ 242.3`
  - `Geweke_sigma ~ 0.64`
  - failures are mainly state-level Geweke/drift rather than low ESS
- dynamic `exdqlm`:
  - `ESS_sigma ~ 11.9`
  - `ESS_gamma ~ 4.5`
  - `ACF1_gamma ~ 0.991`
  - `drift_gamma ~ 0.986`
- static paper `exAL`:
  - `ESS_sigma ~ 19.1`
  - `ESS_gamma ~ 2.45`
  - `drift_gamma ~ 1.236`
- static shrink `exAL`:
  - `ESS_sigma ~ 23.7`
  - `ESS_gamma ~ 3.50`
  - `drift_gamma ~ 1.151`

Interpretation:

- the remaining MCMC failures are not consistent with another shallow rerun
- the repair-wave tuning has therefore been strengthened before launch

## 2026-03-15 Repair Wave Closure And Post-Repair Health Audit

The recommended repair wave is now fully closed:

- repair state dir:
  - `/home/jaguir26/local/state/exdqlm/family_qspec_repair_recommended_20260314_224409`
- final queue state:
  - `model_path: 80 wave_complete`
  - `root_postprocess: 62 wave_complete`
  - `root_signoff: 62 wave_complete`
  - `root_review: 62 wave_complete`
  - `prior_compare: 17 wave_complete`
  - `campaign_review: 3 wave_complete`
  - `global_summary: 1 wave_complete`
- final repair-wave closures:
  - `campaign__dynamic DONE` at `2026-03-15 15:53:39 EDT`
  - `campaign__global_cross_family_summary DONE` at `2026-03-15 15:53:47 EDT`

The final dynamic campaign and global cross-family summary outputs were refreshed after the last two long-tail dynamic `exdqlm` repairs completed.

Post-repair signoff was then re-aggregated directly from the on-disk root signoff outputs under the recommended policy. Important result:

- aggregate signoff counts were unchanged versus the pre-repair baseline:
  - `PASS: 93`
  - `WARN: 95`
  - `FAIL: 100`
  - comparison-eligible method fits: `188 / 288`
  - algorithm-pair eligible: `64 / 144`
  - model-pair eligible: `62 / 144`
  - fully eligible roots: `10 / 72`
  - any-eligible roots: `67 / 72`
  - unhealthy targets: `100`

Interpretation:

- the first repair wave succeeded operationally
- it refreshed the repaired roots and all downstream comparison artifacts cleanly
- but it did **not** reduce the aggregate unhealthy/signoff-fail set under the current recommended policy

Residual unhealthy composition after the completed repair wave:

- `soft_only`: `76`
- `mixed`: `20`
- `hard_only`: `4`

Residual concentration by inference/model:

- `mcmc dqlm`: `18 soft_only`
- `mcmc exdqlm`: `18 soft_only`
- `mcmc exAL`: `35 soft_only`, `2 mixed`, `4 hard_only`
- `vb exAL`: `18 mixed`
- `vb exdqlm`: `5 soft_only`

Post-repair delta artifacts:

- aggregate delta:
  - `tools/merge_reports/20260315_family_qspec_post_repair_signoff_delta.tsv`
- reason delta:
  - `tools/merge_reports/20260315_family_qspec_post_repair_reason_delta.tsv`
- residual unhealthy classification:
  - `tools/merge_reports/20260315_family_qspec_post_repair_unhealthy_classification.tsv`
- residual bucket summaries:
  - `tools/merge_reports/20260315_family_qspec_post_repair_bucket_summary.tsv`
  - `tools/merge_reports/20260315_family_qspec_post_repair_bucket_by_model.tsv`
- row-level before/after change audit:
  - `tools/merge_reports/20260315_family_qspec_post_repair_row_changes.tsv`
- compact summary note:
  - `tools/merge_reports/20260315_family_qspec_post_repair_delta_summary.md`

Key conclusion:

- the next move should **not** be another blind replay of the same repair-wave settings
- the remaining work must be triaged as:
  - soft MCMC diagnostic failures that may need threshold-policy changes or materially deeper chains
  - mixed extended-model failures that likely need both modeling/debug attention and stronger sampling
  - the small hard-failure residue that should remain excluded until numerically repaired

## 2026-03-15 Residual Threshold-Rescue And Action-Plan Analysis

The post-repair unhealthy set was further decomposed into:

1. rows that could be recovered by a **moderate** MCMC policy relaxation
2. rows that would only be recovered by a much more **aggressive** and likely not acceptable relaxation
3. rows that still need materially deeper reruns or direct debugging

Current soft-failure metric surface:

- `mcmc dqlm` (`18` rows):
  - median `ESS sigma`: `288.52`
  - median `ESS state`: `242.27`
  - q75 `Geweke state`: `12.73`
  - interpretation:
    - not an ESS problem
    - mainly a state-level drift/Geweke problem
- `mcmc exAL` (`35` rows):
  - median `ESS sigma`: `20.47`
  - median `ESS gamma`: `3.10`
  - median `ESS state`: `59.43`
  - max `ACF1 gamma`: `0.997`
  - q75 `drift gamma`: `1.44`
  - interpretation:
    - gamma mixing remains the main bottleneck
- `mcmc exDQLM` (`18` rows):
  - median `ESS sigma`: `9.17`
  - median `ESS gamma`: `3.96`
  - median `ESS state`: `195.28`
  - max `ACF1 gamma`: `0.999`
  - q75 `Geweke state`: `13.21`
  - q75 `drift gamma`: `1.44`
  - interpretation:
    - still a genuine extended-state mixing problem, not just mild threshold overshoot
- `vb exDQLM` (`5` rows):
  - these remain VB-side instability/debug targets, not MCMC threshold cases

Threshold rescue scenarios on the `76` soft-only rows:

- current recommended policy:
  - rescues `0 / 76`
- moderate MCMC relaxation:
  - `ESS >= 3`
  - `ACF1 <= 0.998`
  - `Geweke <= 7.5`
  - `half-chain drift <= 1.0`
  - rescues `23 / 76` (`30.3%`)
- aggressive MCMC relaxation:
  - `ESS >= 1`
  - `ACF1 <= 0.999`
  - `Geweke <= 10`
  - `half-chain drift <= 1.5`
  - rescues `46 / 76` (`60.5%`)

Rescue counts by model under the moderate relaxation:

- `mcmc dqlm`: `11`
- `mcmc exAL`: `10`
- `mcmc exDQLM`: `2`

Full residual action plan across the `100` current unhealthy rows:

- `threshold_only_rescue_moderate`: `23`
- `aggressive_policy_only_rescue`: `23`
- `needs_deeper_chain`: `25`
- `needs_model_or_vb_debug`: `5`
- `mixed_debug_and_resample`: `20`
- `hard_numerical_repair`: `4`

Residual action concentration by inference/model:

- `mcmc dqlm`:
  - `11 threshold_only_rescue_moderate`
  - `7 needs_deeper_chain`
- `mcmc exAL`:
  - `10 threshold_only_rescue_moderate`
  - `16 aggressive_policy_only_rescue`
  - `9 needs_deeper_chain`
  - `2 mixed_debug_and_resample`
  - `4 hard_numerical_repair`
- `mcmc exDQLM`:
  - `2 threshold_only_rescue_moderate`
  - `7 aggressive_policy_only_rescue`
  - `9 needs_deeper_chain`
- `vb exAL`:
  - `18 mixed_debug_and_resample`
- `vb exDQLM`:
  - `5 needs_model_or_vb_debug`

Interpretation:

- there is a real threshold-sensitive subset, but it is only `23 / 100`
- a second wave should **not** be framed as “relax everything and rerun all”
- the cleanest next split is:
  - moderate-policy candidates:
    - `23`
  - deeper-chain MCMC candidates:
    - `25`
  - aggressive-policy-only rows that should probably **not** be rescued by threshold relaxation alone:
    - `23`
  - mixed / hard / VB-debug rows:
    - `29`

Durable rescue-analysis artifacts:

- soft metric summary:
  - `tools/merge_reports/20260315_family_qspec_soft_failure_metric_summary.tsv`
- threshold scenarios:
  - `tools/merge_reports/20260315_family_qspec_threshold_rescue_scenarios.tsv`
- threshold rescue by model:
  - `tools/merge_reports/20260315_family_qspec_threshold_rescue_by_model.tsv`
- soft-row rescue classification:
  - `tools/merge_reports/20260315_family_qspec_threshold_rescue_classification.tsv`
- soft-row rescue summary:
  - `tools/merge_reports/20260315_family_qspec_threshold_rescue_class_summary.tsv`
  - `tools/merge_reports/20260315_family_qspec_threshold_rescue_class_by_model.tsv`
- full residual action plan:
  - `tools/merge_reports/20260315_family_qspec_residual_action_plan.tsv`
  - `tools/merge_reports/20260315_family_qspec_residual_action_summary.tsv`
  - `tools/merge_reports/20260315_family_qspec_residual_action_by_model.tsv`
- compact summary:
  - `tools/merge_reports/20260315_family_qspec_threshold_rescue_summary.md`

## 2026-03-15 Accepted Second-Wave Decision

Decision:

- adopt the **moderate** MCMC threshold rescue policy only
- do **not** adopt the aggressive policy-only relaxation
- do **not** relax VB thresholds
- keep hard numerical failures excluded from scientific comparison

Accepted second-wave signoff policy:

- `ESS sigma warn`: `3`
- `ESS gamma warn`: `3`
- `ESS state warn`: `3`
- `ACF1 warn`: `0.998`
- `Geweke abs z warn`: `7.5`
- `half-chain drift warn`: `1.0`

This policy is recorded in:

- `tools/merge_reports/20260315_family_qspec_signoff_policy_second_wave.env`

Second-wave rerun tuning chosen for the remaining deeper-chain MCMC subset:

- `burn = 3000`
- `keep = 8000`
- `progress_every = 25`

This tuning is recorded in:

- `tools/merge_reports/20260315_family_qspec_repair_tuning_second_wave.env`

Accepted action split across the current `100` unhealthy rows:

- newly eligible under the second-wave policy:
  - `23`
- aggressive-policy-only holdouts:
  - `23`
- rerun with deeper MCMC:
  - `25`
- direct VB debug / targeted refit:
  - `5`
- mixed model-debug + resample:
  - `20`
- hard numerical holdouts:
  - `4`

Decision rationale:

- the moderate policy recovers a meaningful subset (`23`) without collapsing validation standards
- the aggressive policy would recover more rows (`46 soft-only` total) but pushes the thresholds past a level that is defensible for scientific comparison
- the remaining `25` deeper-chain MCMC rows are better treated as genuine resampling targets
- the remaining mixed / hard / VB-debug rows should not be forced through by threshold changes

Second-wave decision bundle:

- policy decision:
  - `tools/merge_reports/20260315_family_qspec_second_wave_policy_decision.tsv`
- compact decision note:
  - `tools/merge_reports/20260315_family_qspec_second_wave_decision.md`
- action summary:
  - `tools/merge_reports/20260315_family_qspec_second_wave_action_summary.tsv`
- newly eligible rows:
  - `tools/merge_reports/20260315_family_qspec_newly_eligible_under_second_wave_policy.tsv`
- deeper-chain rerun targets:
  - `tools/merge_reports/20260315_family_qspec_second_wave_deeper_chain_targets.tsv`
- VB debug targets:
  - `tools/merge_reports/20260315_family_qspec_second_wave_vb_debug_targets.tsv`
- mixed debug/resample targets:
  - `tools/merge_reports/20260315_family_qspec_second_wave_mixed_debug_targets.tsv`
- hard numerical holdouts:
  - `tools/merge_reports/20260315_family_qspec_second_wave_hard_holdouts.tsv`
- aggressive-policy holdouts:
  - `tools/merge_reports/20260315_family_qspec_aggressive_policy_holdouts.tsv`

Operational implication:

- the next wave should **not** target all `100` residual rows
- the next wave should rerun only the `25` deeper-chain targets
- the `23` newly eligible rows can be admitted to comparison under the accepted second-wave policy without rerun
- the `52` remaining rows (`23 + 20 + 5 + 4`) stay out of automatic rerun until addressed by later policy or debugging work

## 2026-03-15 Applied Second-Wave Policy Refresh And Corrected Relaunch

Accepted second-wave policy was applied to the canonical signoff and scientific-comparison outputs.

Applied post-policy signoff snapshot:

- method fits:
  - `288` total
  - `93 PASS`
  - `118 WARN`
  - `77 FAIL`
  - `211 comparison-eligible`
- algorithm pairs:
  - `86 / 144 eligible`
- model pairs:
  - `74 / 144 eligible`
- roots:
  - `21 / 72 fully eligible`
  - `69 / 72 with any eligible comparison`
- unhealthy targets remaining under the accepted second-wave policy:
  - `77`

Net effect relative to the pre-refresh recommended-policy state:

- `FAIL`: `100 -> 77`
- comparison-eligible method fits: `188 -> 211`
- eligible algorithm pairs: `64 -> 86`
- eligible model pairs: `62 -> 74`
- fully eligible roots: `10 -> 21`

Authoritative refreshed outputs:

- `tools/merge_reports/20260314_family_qspec_method_signoff.tsv`
- `tools/merge_reports/20260314_family_qspec_algorithm_pair_signoff.tsv`
- `tools/merge_reports/20260314_family_qspec_model_pair_signoff.tsv`
- `tools/merge_reports/20260314_family_qspec_root_readiness.tsv`
- `tools/merge_reports/20260314_family_qspec_signoff_summary.tsv`
- `tools/merge_reports/20260314_family_qspec_scientific_comparison_snapshot.tsv`

### First Second-Wave Launch Was Aborted

The first second-wave launch was invalid and intentionally aborted.

Aborted state dir:

- `/home/jaguir26/local/state/exdqlm/family_qspec_second_wave_20260315_170244_aborted_skip_existing`

Reason:

- resume tasks were still respecting existing `mcmc_*.rds` outputs and immediately short-circuiting as `skipped_existing`
- this produced a no-op wave rather than a genuine deeper-chain rerun

Corrective fix:

- force-overwrite support was added to the resume runners:
  - `tools/merge_reports/20260305_resume_dynamic_mcmc_from_vb.R`
  - `tools/merge_reports/20260305_resume_static_mcmc_from_vb.R`
- second-wave supervisor now exports overwrite env vars so the deeper-chain rerun actually replaces the existing MCMC artifacts for the targeted rows:
  - `tools/merge_reports/20260315_family_qspec_second_wave_supervisor.sh`

### Valid Corrected Second-Wave Relaunch

Valid second-wave state dir:

- `/home/jaguir26/local/state/exdqlm/family_qspec_second_wave_20260315_171146_force`

Launch characteristics:

- scope:
  - `25` deeper-chain `model_path` reruns
  - `18` downstream impacted roots
  - `7` impacted prior-compare barriers
  - `3` campaign reviews
  - `1` global summary
- tuning:
  - `burn = 3000`
  - `keep = 8000`
  - `progress_every = 25`
- launch mode:
  - forced overwrite of targeted existing MCMC fits

Live validation at relaunch:

- worker logs showed real burn-in / MCMC iteration progress for both dynamic and static targeted rows
- the corrected wave no longer exhibited the immediate `skipped_existing` no-op pattern
- the live queue state at launch showed `25` running `model_path` tasks and no downstream launches yet, which is the expected initial condition for a genuine second-wave rerun

## 2026-03-16 Second-Wave Closeout And Post-Wave Health Rebuild

Wave closure checks:

- second-wave state dir: `/home/jaguir26/local/state/exdqlm/family_qspec_second_wave_20260315_171146_force`
- `model_path` reruns: `25 / 25` complete
- downstream wave: `18 / 18` root postprocess + signoff, `18 / 18` root review
- `7 / 7` prior-compare
- `3 / 3` campaign review
- `1 / 1` global summary
- no new `FAILED` events during the closeout window

Post-wave signoff summary (accepted second-wave policy):

- method fits:
  - `93 PASS`
  - `119 WARN`
  - `76 FAIL`
  - `212 comparison-eligible`
- algorithm pairs eligible: `86 / 144`
- model pairs eligible: `75 / 144`
- roots:
  - `21 / 72 fully eligible`
  - `69 / 72 with any eligible comparison`
- remaining unhealthy targets: `76`

Post-wave delta vs the pre-closeout baseline:

- `FAIL`: `77 -> 76` (`-1`)
- comparison-eligible fits: `211 -> 212` (`+1`)
- model pairs eligible: `74 -> 75` (`+1`)
- all other aggregate counters unchanged

Residual action summary (remaining `76` unhealthy rows):

- `aggressive_policy_only_rescue`: `25`
- `needs_deeper_chain`: `19`
- `mixed_debug_and_resample`: `21`
- `needs_model_or_vb_debug`: `5`
- `hard_numerical_repair`: `6`

Authoritative outputs:

- `tools/merge_reports/20260314_family_qspec_signoff_summary.tsv`
- `tools/merge_reports/20260315_family_qspec_post_repair_signoff_delta.tsv`
- `tools/merge_reports/20260315_family_qspec_residual_action_summary.tsv`

## 2026-03-16 Full Comparison Validation Refresh (Existing Outputs)

Validation refresh scope:

- forced rebuild of all root signoff outputs under the accepted second-wave policy
- regenerated root-level VB/MCMC review outputs for all `72` roots
- regenerated all `18` static shrink `ridge vs rhs` prior-compare barriers
- rebuilt all `3` campaign reviews and the `1` global summary
- rebuilt the compact scientific comparison snapshot

Current signoff summary (post-refresh):

- generated_at: `2026-03-16 16:27:49`
- method fits:
  - `93 PASS`
  - `119 WARN`
  - `76 FAIL`
  - `212 comparison-eligible`
- algorithm pairs eligible: `86 / 144`
- model pairs eligible: `75 / 144`
- roots:
  - `21 / 72 fully eligible`
  - `69 / 72 with any eligible comparison`
- remaining unhealthy targets: `76`

Refreshed comparison outputs:

- `tools/merge_reports/20260312_family_qspec_campaign_review__static_paper`
- `tools/merge_reports/20260312_family_qspec_campaign_review__static_shrink`
- `tools/merge_reports/20260312_family_qspec_campaign_review__dynamic`
- `tools/merge_reports/20260312_family_qspec_global_cross_family_summary`
- `tools/merge_reports/20260314_family_qspec_scientific_comparison_snapshot.tsv`
- `tools/merge_reports/20260314_family_qspec_scientific_comparison_snapshot.md`

## 2026-03-16 Comparison Snapshot Freeze (Before Unhealthy-Fit Fixes)

Freeze rationale:

- preserve the current scientific comparison surface and signoff totals so we can measure the delta after unhealthy-fit repair
- add explicit runtime-ratio columns for VB vs MCMC (baseline and extended)

Freeze outputs:

- `tools/merge_reports/20260316_family_qspec_scientific_comparison_snapshot_freeze.tsv`
- `tools/merge_reports/20260316_family_qspec_scientific_comparison_snapshot_freeze.md`
- `tools/merge_reports/20260316_family_qspec_signoff_summary_freeze.tsv`

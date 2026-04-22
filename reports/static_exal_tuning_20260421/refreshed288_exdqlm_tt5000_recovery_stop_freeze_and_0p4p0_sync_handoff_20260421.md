# Refreshed288 exDQLM TT5000 Recovery Stop Freeze And 0.4.0 Sync Handoff

Date: `2026-04-21`

## Why We Are Stopping

We are stopping the staged `exdqlm` `TT5000` recovery program before completion.

This is an operator stop, not a scientific closeout.

The reason is strategic:

1. the recovery lane is still blocked on the first production-budget confirmation row,
2. the next requested work is a branch-level `0.4.0` sync and package-function reconciliation,
3. the dynamic datasets are about to change, so more compute on the current dataset would have low marginal value.

## What Was Running At Stop Time

Stopped run:

- run tag: `refreshed288_exdqlm_tt5000_recovery_v1`
- branch: `validation/rerun-after-0.4.0-sync-0p4p0-integration`
- branch SHA at launched contract: `b7023d8`
- run root:
  - `tools/merge_reports/full288_refreshed288_paperaligned_20260420_exdqlm_tt5000_recovery_v1`

Live row at stop:

- recovery row: `9201`
- base row: `8`
- family: `gausmix`
- tau: `0p05`
- fit size: `5000`
- model: `exdqlm`
- inference: `mcmc`
- method profile: `exdqlm_tt5000_recovery__arm_D_prod`

Method profile summary:

- `C++ strict`
- theta warmup `100`
- latent warmup `100`
- sigmagam warmup `0`
- production budget `n_burn = 5000`
- production budget `n_mcmc = 20000`

Observed stop-time runner state:

- runner still alive and consuming CPU
- no terminal row outcome written yet
- row status file still at initial `running` write
- the staged program had not advanced to the row-16 confirmation pair

## What We Learned Before Stopping

The key completed scientific result remains the row-8 C++ microscope ladder.

Completed microscope result:

| Arm | Recipe | Outcome |
|---|---|---|
| `A` | `fast` | `FAIL` |
| `B` | `strict` | `WARN` |
| `C` | `strict + theta100` | `FAIL` |
| `D` | `strict + theta100 + latent100` | `PASS` |
| `E` | `D + sigmagam500` | `FAIL` |
| `F` | heavier warmups | `FAIL` |
| `G` | `fast` rechallenge | `FAIL` |

This established:

1. `C++ fast` is not promotable for this failure family.
2. `C++ strict` materially improves behavior.
3. theta warmup alone is not enough.
4. theta plus latent warmup together is the best current recipe for the `exdqlm` `TT5000` crash family.
5. heavier `sigmagam` warmup did not help on the microscope row.

## Remaining Failure Surfaces

The numerical crash set is still split into three different tracks:

| Track | Status at stop |
|---|---|
| `exdqlm` dynamic `TT5000` MCMC crash family | partially diagnosed, promoted recipe identified, production confirmation interrupted |
| `dqlm` dynamic `TT5000` MCMC crash family | unresolved and still separate |
| init-blocked rows `11,12` | unresolved and still separate |

Important correction:

- we should not treat the unresolved `dqlm` rows or init-blocked rows as if they are solved by the `exdqlm` microscope winner

## Why The Production Confirmation Looked Odd

The stopped row was much longer than the short microscope runs, but that does not imply the runner was hung.

The most important explanation is budget mismatch:

- microscope `arm D`: `n_burn = 600`, `n_mcmc = 200`
- production confirmation: `n_burn = 5000`, `n_mcmc = 20000`

So the stopped production row should be compared against the promoted production budget, not against the short diagnostic horizon.

## Frozen State We Intend To Preserve

Preserve:

- the staged recovery plan
- the microscope diagnosis note
- the recovery manifest and method registry
- the stopped run root and row-status file
- the run contract showing the pinned launched SHA

Do not interpret as complete:

- the staged recovery status markdown
- the stopped production row outcome

## Next Work After This Freeze

The next work is branch and package integration work, not more recovery compute on the current dataset.

The intended next program is:

1. clean and push this validation branch in a frozen state,
2. fetch current `origin/cransub/0.4.0`,
3. sync latest `0.4.0` into the validation branch,
4. create a fresh `0.4.0`-based branch for selected backports from this validation branch,
5. port package-level warmup and stability changes that are worth carrying forward,
6. only then restart work for the new dynamic dataset surface.

## Files Most Relevant For The Next Sync

Primary package files:

- `R/exdqlmMCMC.R`
- `R/exdqlmLDVB.R`
- `R/exdqlmISVB.R`
- `R/utils.R`
- `R/exal_static_mcmc.R`
- `R/exal_static_LDVB.R`
- `man/exdqlmMCMC.Rd`

Validation-specific orchestration that should stay out of the package backport unless explicitly needed:

- `tools/merge_reports/*`
- `reports/static_exal_tuning_*`

## Final Freeze Read

This stop means:

- the recovery program is frozen in a scientifically useful but incomplete state,
- the best current `exdqlm` `TT5000` recipe is still `strict + theta100 + latent100`,
- that recipe is not yet production-confirmed,
- and the branch is now being transitioned from recovery execution into `0.4.0` sync and reusable-function integration work.

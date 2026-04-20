# Refreshed288 Row-8 C++ Probe Diagnosis

Date: `2026-04-20`

## What Finished

The `row 8` microscope ladder finished all `7/7` arms.

The final outcome table is:

| Arm | Backend | Theta | Latent | Sigmagam | Outcome |
|---|---|---:|---:|---:|---|
| `A` | `fast` | `0` | `0` | `0` | `FAIL` |
| `B` | `strict` | `0` | `0` | `0` | `WARN` |
| `C` | `strict` | `100` | `0` | `0` | `FAIL` |
| `D` | `strict` | `100` | `100` | `0` | `PASS` |
| `E` | `strict` | `100` | `100` | `500` | `FAIL` |
| `F` | `strict` | `200` | `200` | `750` | `FAIL` |
| `G` | `fast` | `100` | `100` | `500` | `FAIL` |

## Main Lessons

1. `C++ strict` is necessary.
   Arm `A` failed immediately, while arm `B` got through to a usable `WARN`.

2. `theta` warmup alone is not enough.
   Arm `C` failed even though arm `B` survived.

3. `theta + latent` together is the winning recipe on the microscope row.
   Arm `D` was the only `PASS`.

4. Heavier `sigmagam` warmup was not helpful.
   Arms `E` and `F` both regressed relative to `D`.

5. The fast backend remains unacceptable for promotion.
   Arm `G` failed again, and this time the failure surfaced at the forced post-warmup release rather than at pure startup.

## Why `D` Beats `B`

`B` is cheaper and simpler, but it only landed `WARN`.

`D` improved both diagnostics and forecasting quality on the probe row:

| Arm | Gate | ESS sigma | ESS gamma | Geweke sigma | Geweke gamma | CRPS | qRMSE |
|---|---|---:|---:|---:|---:|---:|---:|
| `B` | `WARN` | `4.98` | `3.71` | `3.19` | `2.59` | `352.54` | `1177.41` |
| `D` | `PASS` | `13.23` | `8.03` | `1.67` | `1.95` | `341.95` | `1150.39` |

So the microscope result does not just say "`D` passes." It says:

- `D` is more stable,
- `D` mixes better,
- and `D` scores better on the main predictive metrics.

## What This Means

The winning exDQLM TT5000 production candidate is:

- backend: `C++ strict`
- theta warmup: `100`
- latent warmup: `100`
- sigmagam warmup: `0`

But one important correction is needed before broad promotion:

- the probe used the short diagnostic horizon `600/200`
- so this result is still a **diagnostic-horizon win**, not yet a full production-budget confirmation

That means the next correct step is:

1. production confirm `row 8` with arm `D`
2. production compare `row 16` with arms `B` and `D`
3. only then spread `D` to the remaining exDQLM TT5000 failures

## What Not To Do

- do not promote `C++ fast`
- do not promote `theta`-only
- do not promote the heavier `sigmagam` warmup arms
- do not yet apply this recipe to the `dqlm` TT5000 failures
- do not mix the init-blocked rows `11,12` into the same relaunch

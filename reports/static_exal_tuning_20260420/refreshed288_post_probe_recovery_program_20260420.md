# Refreshed288 Post-Probe Recovery Program

Date: `2026-04-20`

## Current Truth

The microscope ladder changed the decision surface.

The strongest current findings are:

1. `exdqlm` TT5000 failures are not all hopeless.
2. The best current exDQLM recovery recipe is arm `D`.
3. The `dqlm` TT5000 failures remain a separate problem.
4. The init-blocked rows `11,12` remain a separate problem.

So the next move is **not**:

- rerun all remaining failures together,
- or apply the same recipe to every failed row.

The next move is a staged program.

## Program Structure

### Pattern diagnosis

The current evidence says the remaining numerical-crash rows are split into three different surfaces:

- `exdqlm` `TT5000` dynamic MCMC rows: same family as the row-8 microscope winner, so this is the only track ready for promotion now
- `dqlm` `TT5000` dynamic MCMC rows: same study surface, but a different numerical failure class, so they still need their own microscope
- init-blocked `11,12`: upstream LDVB / init path, so they remain isolated

That means the next relaunch should be **selective**, not broad.

### Track 1: exDQLM TT5000 recovery

This is the only track that is ready for immediate promotion.

Promoted primary recipe:

- `C++ strict`
- theta warmup `100`
- latent warmup `100`
- sigmagam warmup `0`

Fallback comparator:

- `C++ strict` only

### Track 2: DQLM TT5000 recovery

Do **not** inherit the exDQLM recipe automatically.

Reason:

- the original DQLM failures are `pre_uts / invalid state before chi update`
- that is not the same surface as the exDQLM `chi / pre_latent` crash family

This track needs its own microscope once Track 1 is settled.

### Track 3: init-blocked rows `11,12`

Keep isolated.

Reason:

- row `11` is direct VB init failure
- row `12` is still coupled to the init path

These rows should not be mixed into the exDQLM TT5000 recovery relaunch.

## Prepared Next Relaunch

The next prepared relaunch surface is:

- scope: `exdqlm` TT5000 failures only
- total rows: `10`
- phases:
  1. `confirm_row8_arm_D`
  2. `confirm_row16_arm_B`
  3. `confirm_row16_arm_D`
  4. `spread_remaining_arm_D`

Important correction:

- row `8` already has a diagnostic-horizon `PASS`
- but it still needs a production-budget confirmation before we count it as fully recovered
- and row `16` must confirm that the same promoted recipe transfers beyond the microscope seed row

## Decision Rules

1. If `row 8 / arm D` fails at full budget:
   stop broad exDQLM rollout and revisit the promotion.

2. If `row 16 / arm D` is not at least as good as `row 16 / arm B`:
   stop broad exDQLM rollout and keep the fallback debate open.

3. If both `row 8 / arm D` and `row 16 / arm D` are acceptable:
   promote `D` to the remaining exDQLM TT5000 rows.

4. Do not start the DQLM or init-blocked tracks just because exDQLM improves.

## What The User Was Missing

The main missing piece was:

- a microscope `PASS` under a short diagnostic horizon is **not yet** the same thing as a production recovery

So the correct bridge step is:

- production confirmation first,
- then spread,
- not direct spread from the microscope row alone.

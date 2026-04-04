# REPORT: QDESN Validation Phase 14 R512 Residual Resolution (2026-04-03)

Date: 2026-04-03  
Branch: `feature/qdesn-mcmc-alternative`  
Run tag: `qdesn-phase14-r512-residual-resolution-20260403a__git-8ef64e1`

## 1) Purpose

Capture the outcome of the first post-promotion wave rooted directly in the new `R512` baseline.

Phase 14 was designed to answer a narrow exact question:

1. can a close local descendant of `R512` reduce the remaining mixed ridge/rhs residual set;
2. can that happen without losing the zero-sentinel behavior that made `R512` promotable;
3. if not, which local ingredients are still alive enough to justify one more exact crossover wave.

## 2) Operational Outcome

Phase 14 completed cleanly.

- `15/15` Stage-1 profiles completed
- `0` Stage-2 profiles launched
- `0` Stage-3 profiles launched
- `0` timeouts
- `0` runner errors
- all completed profiles had full root success
- no finite, domain, collapse, or unhealthy regressions were introduced

This is a scientific negative result, not an orchestration artifact.

## 3) Stage Outcome

### Stage 1: exact full-6 residual-resolution matrix

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | fail_reduction | runtime_inflation | read |
|---|---:|---:|---:|---:|---:|---|
| `R600_r512_promoted_anchor` | `1` | `1` | `2` | `0.667` | `1.115` | best raw result, but blocked by a sentinel FAIL |
| `R602_r402_balanced_control` | `2` | `1` | `3` | `0.500` | `0.890` | best runtime-balanced control |
| `R612_r512_burn550_chain1100` | `2` | `1` | `3` | `0.500` | `1.031` | strongest ridge-local descendant |
| `R622_r512_rhssoft_freeze90` | `2` | `1` | `3` | `0.500` | `1.086` | strongest rhs-local descendant |
| `R620_r512_rhsfreeze90` | `2` | `1` | `3` | `0.500` | `1.109` | similar rhs-local signal, slightly weaker cost |
| `R616_r512_softgamma_steps80` | `4` | `0` | `4` | `0.333` | `1.138` | only zero-sentinel clue, but too many FAILs |

Read:

- no candidate advanced because the wave split into two incomplete success modes:
  low-fail profiles with `1` sentinel FAIL and one zero-sentinel profile with too many total FAILs;
- the promoted `R512` anchor was still the best raw performer on this exact harness;
- the best descendants did not dominate the anchor, but they did reveal which local levers still
  matter.

## 4) Root-Level Transition Read

Phase 14 was useful because different descendants repaired different parts of the residual set.

| profile | roots repaired to `WARN` | roots still `FAIL` | main lesson |
|---|---|---|---|
| `R600_r512_promoted_anchor` | `ar1V rhs_ns`, `smallW 0.95 rhs_ns`, `smallW 0.95 ridge`, `bigW 0.95 al rhs_ns` | `bigW 0.05 ridge`, `smallW 0.50 rhs_ns` | best broad repair pattern, but still sentinel-dirty |
| `R612_r512_burn550_chain1100` | `bigW 0.05 ridge`, `smallW 0.95 ridge`, `bigW 0.95 al rhs_ns` | `ar1V rhs_ns`, `smallW 0.95 rhs_ns`, `smallW 0.50 rhs_ns` | best ridge-rescue signal |
| `R622_r512_rhssoft_freeze90` | `ar1V rhs_ns`, `smallW 0.95 ridge`, `bigW 0.95 al rhs_ns` | `bigW 0.05 ridge`, `smallW 0.95 rhs_ns`, `smallW 0.50 rhs_ns` | best rhs-local hedge |
| `R616_r512_softgamma_steps80` | `smallW 0.50 rhs_ns`, `bigW 0.95 al rhs_ns` | `ar1V rhs_ns`, `bigW 0.05 ridge`, `smallW 0.95 rhs_ns`, `smallW 0.95 ridge` | only sentinel-clean clue |

Interpretation:

- `R600` is still the best broad scientific baseline on this exact 6-root harness;
- `R612` suggests the hard `bigW ridge` root still wants more ridge-side mixing support;
- `R622` suggests the surviving rhs-side value is in softer local rhs movement, not in reopening
  the old `R421` family;
- `R616` suggests the remaining sentinel instability is geometry-sensitive, but the tested version
  was too aggressive to be promotable.

## 5) What Improved

1. Phase 14 reran the promoted `R512` baseline on the exact branch-facing 6-root harness and
   showed that it can still get down to `2 FAIL`, even though one of those is now a sentinel FAIL.
2. The wave cleanly separated the surviving local repair ingredients:
   - `R612` for ridge rescue,
   - `R622` for rhs-local softness,
   - `R616` for sentinel cleanup.
3. The residual problem is now even more specific than it looked after Phase 13:
   the next gain likely requires a crossover of surviving local ingredients, not another single-axis
   neighborhood sweep.

## 6) What Still Fails

No candidate in Phase 14 delivered the target combination:

- `low total FAIL`, and
- `zero sentinel FAIL`.

The best raw profile (`R600`) still failed one sentinel root.
The only zero-sentinel profile (`R616`) still failed too many severe roots.

## 7) What Worked Best

1. keeping the exact full-6 harness from Stage 1 onward;
2. retaining the promoted anchor and clean control inside the same wave;
3. mild local ridge/rhs exploration around the promoted baseline instead of reopening dead families;
4. transition-level analysis, which showed that different descendants are repairing different roots.

## 8) What Clearly Did Not Work

1. chain-only increases (`R610`, `R611`);
2. extra-pass-only ridge inflation (`R613`);
3. raw wider-step geometry without a more careful crossover (`R614`, `R615`);
4. the tested narrow coupled variants (`R630`, `R631`);
5. reopening retired families is still unjustified.

## 9) Main Takeaways

1. Phase 14 did not produce a new promotable baseline.
2. `R512_r412_pass2_chain1000` remains the active carry-forward baseline.
3. The best raw Phase-14 result is still the exact `R512` anchor rerun (`R600`), which means the
   baseline itself remains scientifically strong.
4. The next search should not be another family wave.
5. The next search should be a crossover matrix that combines only the surviving local ingredients:
   `R600` broad repair, `R612` ridge rescue, `R622` rhs softness, and `R616` sentinel-clean
   geometry.

## 10) Recommended Next Move

Run one more exact full-6 crossover wave around `R512`:

1. keep `R600` as the anchor control;
2. keep `R402` as the clean control;
3. keep `R612`, `R622`, and `R616` as reference signals;
4. test only untried crossovers of:
   - the `R612` ridge rescue,
   - the `R622` rhs-soft behavior,
   - the `R616` sentinel-clean geometry hint;
5. allow promising low-fail / one-sentinel candidates through Stage 1;
6. enforce zero-sentinel rerun confirmation in Stage 2;
7. require `2 FAIL / 0 sentinel FAIL` before any new promotion call.

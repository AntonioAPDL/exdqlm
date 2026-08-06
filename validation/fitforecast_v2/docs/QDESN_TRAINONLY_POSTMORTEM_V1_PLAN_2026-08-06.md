# Q-DESN Train-Only Mechanistic Postmortem v1

## Purpose

This postmortem converts the completed `qdesn_trainonly_followup_v1_20260805_205744`
campaign into a reproducible decision about further computation. It does not alter the
exdqlm 1.0.0 package, launch another screen, or update the article.

## Diagnosis being tested

The preceding discovery screen identified compact raw and state-residual AL candidates,
but full-budget confirmation improved the untouched development source while degrading
the frozen article source. The postmortem therefore tests whether the discrepancy is
localized by forecast lead, forecast origin, or source-window shift. Separately, it
checks whether any exAL sampler arm crossed a predeclared geometry threshold.

## Evidence contract

1. Use only completed full-budget roots from the frozen follow-up gate.
2. Pair AL candidates with their exact parent by source and reservoir seed.
3. Compare every common rolling-origin target, not only aggregate H=1000 metrics.
4. Report leads 1--5, 6--15, and 16--30 and early, middle, and late origin bands.
5. Summarize pre-forecast and forecast true-quantile level, slope, variability, and
   observation innovation scale for each source.
6. Preserve input hashes and emit compact CSV/JSON evidence only.

## Gates

- `PREPARE_AL_MULTI_SOURCE_CONFIRMATION` requires the same arm to achieve median
  forecast-MAE ratio at most 0.95 and check-loss ratio at most 1.05 on both the frozen
  article and untouched confirmation sources.
- `PREPARE_EXAL_FULL_BUDGET_CONFIRMATION` requires median maximum core ACF1 at most
  0.90 and median minimum core ESS per second at least 0.25.
- Otherwise the decision is `STOP_REASSESS_MODEL_OR_SAMPLER`, the candidate manifest is
  empty, and no compute or article update is authorized.

## Execution

```bash
Rscript validation/fitforecast_v2/scripts/audit_qdesn_trainonly_postmortem_v1.R
```

The default output is written beneath the completed campaign's `closeout/` directory.
The audit is deterministic modulo its generated timestamp and can be rerun without model
objects or posterior draws.

# QDESN Tau050 Failed-MCMC S-Freeze Postmortem

Date: 2026-04-19  
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## Scope

This note audits the completed latent-`s` crash-only rerun of the original
`23` hard numerical MCMC failures from the April 16, 2026 `tau050` source
campaign.

Live `sfreeze` rerun tags:

- `qdesn-dynamic-exdqlm-crossstudy-tau050-failed_mcmc_al_sfreeze-20260419-031755__git-e44a56a`
- `qdesn-dynamic-exdqlm-crossstudy-tau050-failed_mcmc_exal_sfreeze-20260419-031810__git-e44a56a`

Compared baseline failed-only rerun tags:

- `qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-al-launch-20260418-021532__git-c6f8955`
- `qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-exal-launch-20260418-021532__git-c6f8955`

## Final Outcome

| Surface | Total | SUCCESS | FAIL | PASS/WARN acceptable | SUCCESS but signoff FAIL |
|---|---:|---:|---:|---:|---:|
| AL | 9 | 2 | 7 | 2 | 0 |
| EXAL | 14 | 6 | 8 | 3 | 3 |
| Overall | 23 | 8 | 15 | 5 | 3 |

High-level read:

- the latent-`s` freeze improved the aggregate completion rate from `5 / 23`
  recovered in the earlier failed-only rerun to `8 / 23`
- acceptable recovered cases (`PASS` or `WARN`) improved from `2 / 23` to
  `5 / 23`
- the rerun is still net-negative for the hard crash surface because
  `15 / 23` cases still ended in terminal `FAIL`

## What Was Actually Fixed

The `sfreeze` rerun newly moved these cases into the acceptable `PASS/WARN`
bucket:

| Lane | Family | tau | Fit size | Prior | New result |
|---|---|---:|---:|---|---|
| EXAL | `gausmix` | `0.05` | `5000` | `ridge` | `WARN` |
| EXAL | `gausmix` | `0.50` | `5000` | `ridge` | `PASS` |
| EXAL | `laplace` | `0.25` | `5000` | `ridge` | `WARN` |
| AL | `normal` | `0.50` | `5000` | `ridge` | `PASS` |

One previously acceptable case regressed:

| Lane | Family | tau | Fit size | Prior | Old | New |
|---|---|---:|---:|---|---|---|
| EXAL | `laplace` | `0.50` | `5000` | `ridge` | `WARN` | `FAIL` |

There are also `3` cases that now complete but still land in signoff `FAIL`:

| Lane | Family | tau | Fit size | Prior | Signoff reason |
|---|---|---:|---:|---|---|
| EXAL | `gausmix` | `0.50` | `500` | `rhs_ns` | `high_autocorrelation` |
| EXAL | `gausmix` | `0.50` | `5000` | `rhs_ns` | `high_autocorrelation; geweke_drift` |
| EXAL | `normal` | `0.05` | `500` | `rhs_ns` | `FAIL` diagnostic bucket |

These are not hard numerical crashes anymore, but they are also not yet in the
user-acceptable `PASS/WARN` bucket.

## Dominant Patterns

### 1. The remaining hard failures are now entirely on `fit_size = 5000`

| Fit size | FAIL | SUCCESS |
|---|---:|---:|
| `500` | `0` | `2` |
| `5000` | `15` | `6` |

This is the clearest structural win from the `sfreeze` rerun:

- the short-window crash surface is effectively gone as a hard-failure problem
- the unresolved crash surface is now the long-window `5000` subset only

### 2. The hard-failure family did not change

Every inspected failed `pipeline_stdout.log` still shows:

- `QDESN_LATENT_V_FAILURE_JSON=...`
- `exal_mcmc_fit::latent_v returned 1 invalid draws after 12 retry batches`
- `Execution halted`

So the remaining crash surface is still the same numerical latent-`v` invalid
draw failure family. The latent-`s` freeze did not change the root failure
mechanism; it only reduced its incidence on some cases.

### 3. Most remaining failures happen after thaw, not during warmup

From the `15` hard-fail logs with persisted latent-`v` JSON:

| Phase | Count |
|---|---:|
| `burn` | 5 |
| `keep` | 10 |

Supporting details:

- only `1 / 15` failures still occurs while `latent_v_warmup_active = TRUE`
- only `1 / 15` failures still occurs on `latent_v_update_reason = sparse_update`
- `14 / 15` failures occur with `latent_v_update_reason = scheduled`
- `14 / 15` failures occur with `latent_s_update_reason = scheduled`

This is the strongest decision signal in the postmortem:

- the remaining hard surface is **not** mainly a warmup-window failure anymore
- simply making the warmup longer is unlikely to be the most effective next
  intervention

### 4. The remaining hard surface is concentrated in harder taus and families

Hard failures by tau:

| tau | FAIL | SUCCESS |
|---|---:|---:|
| `0.05` | 2 | 3 |
| `0.25` | 6 | 1 |
| `0.50` | 7 | 4 |

Hard failures by family:

| Family | FAIL | SUCCESS |
|---|---:|---:|
| `gausmix` | 6 | 4 |
| `laplace` | 5 | 1 |
| `normal` | 4 | 3 |

Read:

- `tau = 0.25` and `tau = 0.50` remain the primary hard-failure zones
- `gausmix` and `laplace` remain harder than `normal`
- the remaining hard-failure surface is no longer diffuse

### 5. `rhs_ns` remains materially weaker than `ridge`

By prior:

| Prior | FAIL | SUCCESS | PASS/WARN acceptable |
|---|---:|---:|---:|
| `rhs_ns` | 10 | 3 | 0 |
| `ridge` | 5 | 5 | 5 |

Interpretation:

- `ridge` benefits much more from the `sfreeze` relaunch
- no `rhs_ns` case reaches `PASS` or `WARN`
- the remaining hard-fail surface is still not exclusively an `rhs_ns`
  problem, but `rhs_ns` is clearly the weaker pocket now

### 6. EXAL now completes more often than AL on this surface

| Lane | FAIL | SUCCESS | PASS/WARN acceptable |
|---|---:|---:|---:|
| AL | 7 | 2 | 2 |
| EXAL | 8 | 6 | 3 |

This matters because earlier waves often looked worse for EXAL. On the current
remaining-crash surface:

- EXAL still has more total failures in absolute count because it owns more of
  the original 23-fit failure set
- but EXAL also produces more completions and more acceptable recoveries here

## Most Important Takeaways

1. The latent-`s` freeze direction was useful, but only partially.
   It materially improved completion and acceptable recovery, but it did not
   solve the long-window crash core.

2. The unresolved surface is now much cleaner.
   We should stop treating this as a broad `23`-case problem and instead treat
   it as a specific `15`-case long-window hard-fail problem.

3. The next intervention should not be “more warmup only.”
   The crash logs show that nearly all remaining failures happen after both
   latent warmup schedules have thawed.

4. The next best lever is likely bounded latent-`v` rescue, not broader freeze.
   The repo already supports `latent_v$rescue_on_invalid` with
   `rescue_strategy = previous_state`, and that directly targets the remaining
   crash event instead of only shifting the thaw boundary.

5. Failure persistence is still incomplete in the fit-level summaries.
   The failed `health_summary.csv` rows do not currently retain the
   `mcmc_failure_*` fields, even though the `pipeline_stdout.log` files do.
   That should be fixed before the next large rerun so the postmortem does not
   depend on log scraping.

## Reproducible Remaining Hard-Fail Surface

The exact remaining hard-fail relaunch surface is now frozen in:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_remaining_hard_fail_al_grid.csv`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_remaining_hard_fail_exal_grid.csv`

Counts:

- AL hard-fail roots: `7`
- EXAL hard-fail roots: `8`
- total hard-fail roots: `15`

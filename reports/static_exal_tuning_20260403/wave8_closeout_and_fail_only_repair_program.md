# Static exAL Tuning: Wave-8 Closeout and Fail-Only Repair Program

Date: 2026-04-03

Primary references:

- `reports/static_exal_tuning_20260403/wave7_closeout_and_wave8_program.md`
- `tools/merge_reports/LOCAL_static_exal_wave8_resume_supervisor_20260403.log`
- `tools/merge_reports/LOCAL_static_exal_wave8_live_monitor_20260403.log`
- `tools/merge_reports/LOCAL_static_exal_wave8_guard8_resume_manifest_20260403_194245_23169_3807732.csv`
- `tools/merge_reports/LOCAL_static_exal_wave8_mix12_transfer_resume_manifest_20260403_195011_4088_3808775.csv`

## Wave-8 Final State

Wave-8 completed successfully under the repaired resume pipeline.

| stage | candidates | total | done | missing | PASS | WARN | FAIL |
|---|---:|---:|---:|---:|---:|---:|---:|
| `transfer6` | 8 | 48 | 48 | 0 | 30 | 17 | 1 |
| `guard8` | 8 | 64 | 64 | 0 | 40 | 23 | 1 |
| `mix12_transfer` | 8 | 96 | 96 | 0 | 58 | 36 | 2 |
| `Overall` |  | 208 | 208 | 0 | 128 | 76 | 4 |

Operational conclusion:

- all scheduled rows completed
- the repaired resume selector, manifest logging, supervisor, and monitor held
  through full completion
- the remaining problem is now scientific / candidate-quality specific, not an
  orchestration failure

## Residual FAIL Map

The raw FAIL count is `4`, but it reduces to `2` underlying weak patterns.

| stage | candidate_id | row_id | root_kind | family | tau | reason |
|---|---|---:|---|---|---|---|
| `transfer6` | `F075_sub2_s095` | 119 | `static_paper` | `laplace` | `0p95` | `gate_fail` |
| `guard8` | `F075_sub2_s095` | 119 | `static_paper` | `laplace` | `0p95` | `gate_fail` |
| `mix12_transfer` | `F075_sub2_s095` | 119 | `static_paper` | `laplace` | `0p95` | `gate_fail` |
| `mix12_transfer` | `F080_sub2_s095` | 75 | `static_paper` | `gausmix` | `0p05` | `gate_fail` |

Metric snapshot of the failing rows:

- `F075_sub2_s095 / row119`:
  `ess_sigma_per1k_cand = 22.32424`,
  `ess_gamma_per1k_cand = 5.936544`,
  `acf1_sigma_cand = 0.9563179`,
  `acf1_gamma_cand = 0.9881946`,
  `geweke_sigma_cand = 0.1730041`,
  `geweke_gamma_cand = 1.745401`,
  `runtime_sec_cand = 115.442`
- `F080_sub2_s095 / row75`:
  `ess_sigma_per1k_cand = 24.56187`,
  `ess_gamma_per1k_cand = 8.299607`,
  `acf1_sigma_cand = 0.9520445`,
  `acf1_gamma_cand = 0.9821441`,
  `geweke_sigma_cand = 1.3816391`,
  `geweke_gamma_cand = 2.002213`,
  `runtime_sec_cand = 96.417`

Interpretation:

- `F075_sub2_s095` is the clearly dominated candidate; the same row fails
  repeatedly across all three stages
- `F080_sub2_s095` is much closer to viable but still has one mix-stage FAIL
- these are the only residual FAIL targets worth debugging

## Zero-FAIL Candidate Shortlist

| candidate_id | PASS | WARN | FAIL |
|---|---:|---:|---:|
| `F080_sub2_s105` | 22 | 4 | 0 |
| `F080_sub2_s100_ref` | 19 | 7 | 0 |
| `F0825_sub2_s100` | 17 | 9 | 0 |
| `F075_sub2_s105` | 16 | 10 | 0 |
| `F085_sub2_s095` | 12 | 14 | 0 |
| `F085_sub2_s105` | 12 | 14 | 0 |

Working recommendation:

1. treat `F080_sub2_s105` as the leading zero-FAIL promotion candidate
2. keep `F080_sub2_s100_ref` as the primary backup
3. do not reopen a broad wave; only target the residual FAIL patterns
4. drop `F075_sub2_s095` unless a targeted repair materially changes the row119
   failure mechanism

## Fail-Only Program

The next program should be intentionally narrow and should preserve the exact
discipline used in the repaired wave-8 run.

### Scope

Only investigate and relaunch:

1. `F075_sub2_s095 / row119 / static_paper / laplace / tau_0p95`
2. `F080_sub2_s095 / row75 / static_paper / gausmix / tau_0p05`

### Required strategy

1. reconstruct each FAIL against nearby successful neighbors
2. compare against the zero-FAIL leaders, especially `F080_sub2_s105` and
   `F080_sub2_s100_ref`
3. identify whether the failure is due to:
   - proposal scale mismatch
   - row-specific instability
   - warm-start mismatch
   - threshold / gate sensitivity rather than substantive collapse
4. preserve the repaired orchestration stack:
   - deterministic missing-row selection
   - per-row manifests
   - supervisor logging
   - monitor heartbeats
5. avoid any broad rerun until fail-only evidence says it is justified

### Decision rule

- if the fail-only repair clears the remaining FAILs without destabilizing the
  surrounding zero-FAIL neighborhood, it can be promoted
- if `F075_sub2_s095` still fails on row119 after targeted repair, drop it and
  move forward with the zero-FAIL shortlist
- if `F080_sub2_s095` clears its single mix-stage FAIL, it becomes a viable
  additional option, but it does not displace `F080_sub2_s105` automatically

## Operational Bottom Line

Wave-8 itself is a success:

- the branch-level orchestration issue is fixed
- the exact-runner transfer sweep fully completed
- we now have a clean zero-missing baseline and a narrow fail-only repair scope

So the next step is not "redo wave-8." The next step is:

- run a disciplined fail-only repair mini-program on the two residual weak
  patterns
- keep the zero-FAIL shortlist intact as the current best path forward

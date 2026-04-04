# Static exAL Tuning: Fail-Only Bridge Results

Date: 2026-04-03

Context:

- `reports/static_exal_tuning_20260403/wave8_closeout_and_fail_only_repair_program.md`
- `reports/static_exal_tuning_20260403/PROMPT__wave8_fail_only_repair_20260403.md`

## Objective

Run a narrow fail-only bridge program that targets the two residual weak
patterns from wave-8 without reopening the full candidate grid.

Residual FAIL patterns before this bridge run:

1. `F075_sub2_s095 / row119 / static_paper / laplace / tau_0p95`
2. `F080_sub2_s095 / row75 / static_paper / gausmix / tau_0p05`

## Diagnosis

### Pattern 1: `F075_sub2_s095 / row119`

Evidence from wave-8:

- the same row failed in `transfer6`, `guard8`, and `mix12_transfer`
- nearby `F075_sub2_s105` lifted the same row to `WARN`
- nearby `F080` candidates also held the same row at `WARN`

Interpretation:

- the failure is consistent with a gamma-side mixing / drift boundary at the
  tighter `s095` geometry
- this is not an RHS collapse problem
- the candidate is dominated; the main question is whether a minimal bridge to
  `s100` confirms that this is a local scale threshold and not a deeper model
  issue

### Pattern 2: `F080_sub2_s095 / row75`

Evidence from wave-8:

- `F080_sub2_s095 / row75` failed in `mix12_transfer`
- `F080_sub2_s100_ref / row75` passed
- `F080_sub2_s105 / row75` passed
- the same candidate `F080_sub2_s095` remained only `WARN` on the sensitive
  laplace row `119`

Interpretation:

- this is a local geometry threshold, not a family-wide failure
- the most valuable test is a bridge candidate between `s095` and the passing
  `s100 / s105` settings

## Implemented Bridge Program

Implemented tooling:

- `tools/merge_reports/LOCAL_static_exal_fail_only_prepare_20260403.R`
- `tools/merge_reports/LOCAL_static_exal_fail_only_evaluate_20260403.R`
- `tools/merge_reports/LOCAL_static_exal_fail_only_launch_20260403.sh`
- `tools/merge_reports/LOCAL_static_exal_fail_only_monitor_20260403.sh`

Bridge schedule:

| candidate_id | variant_tag | row_id | family | tau | p_global_eta_jump | global_eta_jump_scale | why |
|---|---|---:|---|---|---:|---:|---|
| `F075_sub2_s100` | `failonly_F075_sub2_s100` | 119 | `laplace` | `0p95` | 0.075 | 1.000 | bridge repeated `F075` row119 FAIL between `s095` FAIL and `s105` WARN |
| `F080_sub2_s0975` | `failonly_F080_sub2_s0975` | 75 | `gausmix` | `0p05` | 0.080 | 0.975 | bridge `F080` row75 FAIL between `s095` FAIL and `s100/s105` PASS |
| `F080_sub2_s0975` | `failonly_F080_sub2_s0975` | 119 | `laplace` | `0p95` | 0.080 | 0.975 | verify the `F080` bridge remains acceptable on the known sensitive row119 |

Execution artifacts:

- `tools/merge_reports/LOCAL_static_exal_fail_only_manifest_20260403_202516_24542_3816811.csv`
- `tools/merge_reports/LOCAL_static_exal_fail_only_monitor_20260403.log`

## Results

| candidate_id | row_id | gate_overall | healthy | ess_sigma_per1k_cand | ess_gamma_per1k_cand | acf1_sigma_cand | acf1_gamma_cand | geweke_sigma_cand | geweke_gamma_cand | runtime_sec_cand |
|---|---:|---|---|---:|---:|---:|---:|---:|---:|---:|
| `F075_sub2_s100` | 119 | `WARN` | `TRUE` | 22.82980 | 7.652263 | 0.9553508 | 0.9848087 | 0.6981105 | 0.7264511 | 118.379 |
| `F080_sub2_s0975` | 75 | `PASS` | `TRUE` | 32.02235 | 12.749686 | 0.9379305 | 0.9748167 | 0.8193327 | 1.0854889 | 99.026 |
| `F080_sub2_s0975` | 119 | `WARN` | `TRUE` | 23.48983 | 7.322057 | 0.9496161 | 0.9852203 | 0.2778495 | 0.9331665 | 116.482 |

Candidate summary:

| candidate_id | total | PASS | WARN | FAIL |
|---|---:|---:|---:|---:|
| `F080_sub2_s0975` | 2 | 1 | 1 | 0 |
| `F075_sub2_s100` | 1 | 0 | 1 | 0 |

## Interpretation

### `F075_sub2_s095`

The bridge to `F075_sub2_s100` moved the repeated row119 failure from `FAIL` to
`WARN`. This confirms that the original `F075_sub2_s095` failure is a local
geometry threshold, not a collapse bug. But it also confirms that this part of
the search space is dominated by already-better zero-FAIL candidates.

Decision:

- drop `F075_sub2_s095`
- do not reopen a broader `F075` repair wave
- if an `F075` representative is still needed, prefer the already zero-FAIL
  `F075_sub2_s105`

### `F080_sub2_s095`

The bridge to `F080_sub2_s0975` cleared the failing gausmix row75 to `PASS`
while keeping the sensitive laplace row119 at `WARN`. This is the strongest
evidence that the original `F080_sub2_s095` failure was a repairable local
scale-boundary issue.

Decision:

- `F080_sub2_s0975` is now a viable secondary candidate
- it does not displace `F080_sub2_s105` as the leading carry-forward option,
  because `F080_sub2_s105` already achieved full zero-FAIL status across the
  completed wave-8 grid

## Carry-Forward Recommendation

1. Primary carry-forward candidate: `F080_sub2_s105`
2. Primary backup: `F080_sub2_s100_ref`
3. New secondary bridge candidate: `F080_sub2_s0975`
4. Drop: `F075_sub2_s095`

Operational conclusion:

- the fail-only repair program succeeded
- the residual FAIL boundary is now understood
- no additional broad rerun is justified from this evidence alone

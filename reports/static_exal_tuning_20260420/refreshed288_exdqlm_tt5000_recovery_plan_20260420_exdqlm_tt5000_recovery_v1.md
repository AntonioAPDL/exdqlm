# Refreshed288 exDQLM TT5000 Recovery Program

- run tag: `refreshed288_paperaligned_20260420_exdqlm_tt5000_recovery_v1`
- variant tag: `refreshed288_exdqlm_tt5000_recovery_v1`
- source canonical run: `20260417_canonical_v1`
- scope: `exdqlm` dynamic MCMC TT5000 failures only
- promoted arm from microscope: `D = strict + theta100 + latent100 + sigmagam0`
- fallback arm retained for confirmation: `B = strict only`
- excluded for now: all `dqlm` TT5000 crash rows and init-blocked exdqlm rows `11,12`
- important correction: the row-8 PASS was at diagnostic horizon only, so production-budget confirmation is still required before broad rollout is trusted

## Pattern Diagnosis

- the promoted track is coherent because all nine target rows came from the same `exdqlm / dynamic / mcmc / TT5000` crash family
- their original canonical failure surface was the same early `chi / pre_latent` numerical crash class
- the microscope showed that backend mode matters materially: `C++ strict` was necessary while `C++ fast` remained unacceptable
- the microscope also showed that `theta` warmup alone was not enough, but `theta + latent` together was sufficient to promote a production candidate
- heavier `sigmagam` warmup regressed on the microscope row and is therefore intentionally excluded from the promoted recipe

## Phase Plan

| phase | rows |
|---|---|
| confirm_row8_arm_D | 1 |
| confirm_row16_arm_B | 1 |
| confirm_row16_arm_D | 1 |
| spread_remaining_arm_D | 7 |

## Row Allocation

| row_id | base_row_id | phase | plan_role | family | tau_label | method_profile_id |
|---|---|---|---|---|---|---|
| 9201 |  8 | confirm_row8_arm_D | fullconfirm_row8_d | gausmix | 0p05 | exdqlm_tt5000_recovery__arm_D_prod |
| 9202 | 16 | confirm_row16_arm_B | confirmatory_row16_b | gausmix | 0p25 | exdqlm_tt5000_recovery__arm_B_prod |
| 9203 | 16 | confirm_row16_arm_D | confirmatory_row16_d | gausmix | 0p25 | exdqlm_tt5000_recovery__arm_D_prod |
| 9204 | 24 | spread_remaining_arm_D | spread_remaining_d | gausmix | 0p50 | exdqlm_tt5000_recovery__arm_D_prod |
| 9205 | 32 | spread_remaining_arm_D | spread_remaining_d | laplace | 0p05 | exdqlm_tt5000_recovery__arm_D_prod |
| 9206 | 40 | spread_remaining_arm_D | spread_remaining_d | laplace | 0p25 | exdqlm_tt5000_recovery__arm_D_prod |
| 9207 | 48 | spread_remaining_arm_D | spread_remaining_d | laplace | 0p50 | exdqlm_tt5000_recovery__arm_D_prod |
| 9208 | 56 | spread_remaining_arm_D | spread_remaining_d | normal | 0p05 | exdqlm_tt5000_recovery__arm_D_prod |
| 9209 | 64 | spread_remaining_arm_D | spread_remaining_d | normal | 0p25 | exdqlm_tt5000_recovery__arm_D_prod |
| 9210 | 72 | spread_remaining_arm_D | spread_remaining_d | normal | 0p50 | exdqlm_tt5000_recovery__arm_D_prod |

## Promotion Rules

1. `row 8 / arm D` must remain acceptable at production budget before the spread phase is trusted.
2. `row 16 / arm D` must be at least as good as `row 16 / arm B`; otherwise the fallback debate remains open.
3. The remaining seven exdqlm TT5000 rows only inherit `arm D` after both confirmatory checks stay acceptable.
4. This relaunch does not reopen the `dqlm` TT5000 or init-blocked `11,12` tracks.


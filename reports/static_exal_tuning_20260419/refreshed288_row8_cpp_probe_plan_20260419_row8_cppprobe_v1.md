# Refreshed288 Row-8 C++ Microscope Probe

- run tag: `refreshed288_paperaligned_20260419_row8_cppprobe_v1`
- variant tag: `refreshed288_row8_cppprobe_v1`
- source canonical run: `20260417_canonical_v1`
- microscope row: `8`
- backend policy: `C++ only`
- diagnostic horizon: `n.burn = 600`, `n.mcmc = 200`, `thin = 1`, `trace.every = 1`
- promotion rule: choose the minimal winning arm before moving to row `16`

## Arm Ladder

| arm_id | arm_order | mcmc_cpp_mode | theta_warmup_iters | latent_mode | latent_warmup_iters | sigmagam_mcmc_warmup_iters | intended_use |
|---|---|---|---|---|---|---|---|
| A | 1 | fast |   0 | u_st_pair |   0 |   0 | reproduction_anchor |
| B | 2 | strict |   0 | u_st_pair |   0 |   0 | mode_only |
| C | 3 | strict | 100 | u_st_pair |   0 |   0 | theta_only |
| D | 4 | strict | 100 | u_st_pair | 100 |   0 | theta_plus_latent |
| E | 5 | strict | 100 | u_st_pair | 100 | 500 | current_best_integrated |
| F | 6 | strict | 200 | u_st_pair | 200 | 750 | escalation_if_E_fails |
| G | 7 | fast | 100 | u_st_pair | 100 | 500 | fast_recovery_challenge_if_strict_wins |

## Fixed Baseline

| control | setting |
|---|---|
| VB/VB-init method | ldvb |
| VB-init max_iter | 800 |
| VB-init min_iter | 80 |
| VB-init tol | 0.01 |
| VB-init n.samp | 5000 |
| exDQLM s_t VB warmup | 50, min_postwarmup_updates 5 |
| VB sigmagam warmup | 50, damping 0.5 x 5 |
| GIG b_vec floor | 1e-10 |
| binary retention | candidate fit, vb_init, draws |

## Manifest

| row_id | phase | rerun_arm_id | mcmc_cpp_mode | theta_warmup_iters | latent_warmup_iters | sigmagam_mcmc_warmup_iters | rerun_intended_use |
|---|---|---|---|---|---|---|---|
| 8001 | arm_A | A | fast |   0 |   0 |   0 | reproduction_anchor |
| 8002 | arm_B | B | strict |   0 |   0 |   0 | mode_only |
| 8003 | arm_C | C | strict | 100 |   0 |   0 | theta_only |
| 8004 | arm_D | D | strict | 100 | 100 |   0 | theta_plus_latent |
| 8005 | arm_E | E | strict | 100 | 100 | 500 | current_best_integrated |
| 8006 | arm_F | F | strict | 200 | 200 | 750 | escalation_if_E_fails |
| 8007 | arm_G | G | fast | 100 | 100 | 500 | fast_recovery_challenge_if_strict_wins |


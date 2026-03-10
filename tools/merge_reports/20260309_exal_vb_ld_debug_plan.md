# exAL VB LD Debug Plan for Static Paper-Normal Dense Case

## Scope

Reference failing case:
- static exAL VB
- paper-style dense normal DGP
- tau = 0.05
- n = 10000
- run root: `results/function_testing_20260309_static_paper_normal_dense_nonzero_qspec/tau_0p05/run_tt10000_vbns1000_burn2000_n1000`

Reference reduced audit:
- `results/sim_suite_static/audits/exal_vb_s_block_debug_20260309`

## Main factual conclusion

The instability is not isolated to `s_i`.

In the large failing run, the saved traces show an exact 2-cycle in:
- `gamma`
- `sigma`
- `s_mean`
- `tau2_mean`
- `delta_elbo`
- `ld_objective`

So `s_i` is oscillating, but it is oscillating together with the LD sigma/gamma block.

## Why the plots can be misleading

The trace plots for `gamma` and `sigma` can look visually "converged" because:
- they alternate between two fixed values, so they appear as a narrow band
- the values are large enough that the line plot compresses the alternation
- `s_mean` is on a smaller scale and makes the alternation easier to see

So the correct interpretation must come from the saved trace values, not the visual impression alone.

## Confirmed failure mechanism

1. The `VB` fit does not converge.
2. The LD block does not end at a valid local mode.
3. The LD block enters a stable 2-point oscillation.
4. `q(s_i)` and `q(v_i)` follow that oscillation.
5. The current direct-commit LD update appears to be the main engineering trigger.

## Evidence already established

### Large failing run
- `converged = FALSE`
- `stop_reason = max_iter`
- `ld_local_mode_pass = FALSE`
- `ld_mode_grad_inf_norm_final` extremely large
- `ld_mode_neg_hess_min_eig_final < 0`

Tail trace alternation:
- gamma: `1.4857 <-> 8.2216`
- sigma: `1713.9 <-> 6454.3`
- s_mean: `0.2531 <-> 0.5194`
- tau2_mean: `0.0712 <-> 0.5503`

### Reduced `n=100` audit
Base run:
- exact 2-cycle in gamma/sigma/s_mean/tau2
- lag-1 correlation near `-1`
- lag-2 correlation near `+1`

Damped run:
- 2-cycle disappears
- traces drift smoothly instead of alternating
- this strongly suggests `s_i` is not the origin, but a follower of the unstable LD state

### MCMC reference
- same data, short run
- no deterministic 2-cycle in `s_i`
- supports the conclusion that the issue is specific to the VB LD path

## Hypotheses to test

### H1. Direct-commit LD updates are too aggressive
Expected symptom:
- LD step jumps between two competing states
- damping removes or weakens the 2-cycle

### H2. The Delta xi approximation is too brittle in this lower-tail exAL regime
Expected symptom:
- `xi_method = "mc"` or partial xi damping reduces oscillation
- `xi_rel_drift` becomes less erratic

### H3. The LD objective surface has two nearby competing basins
Expected symptom:
- optimizer repeatedly lands in alternating local optima
- stronger regularization / smaller step caps / mode rejection reduces alternation

### H4. The q(s_i) block is highly sensitive to xi_lambda2 and E_inv_v
Expected symptom:
- even moderate LD movement induces large changes in `tau2_mean` and then `s_mean`
- but stabilizing LD also stabilizes `s_i`

## Ranked tweak list

### Tier 1: safest and most likely
1. Disable `direct_commit` by default for difficult exAL VB regimes.
2. Use `damping < 1` and `xi_damping < 1` when tail-cycle detection is triggered.
3. Add explicit 2-cycle detection on tail traces.
4. Refuse full LD commit when `ld_local_mode_pass = FALSE`.

### Tier 2: likely useful
5. Try `xi_method = "mc"` or hybrid xi damping on this exact benchmark.
6. Reduce `step_cap_eta` and `step_cap_ell` even when using bounded optimizer.
7. Tighten covariance cap (`eig_cap`) further in hard lower-tail exAL cases.

### Tier 3: more structural
8. Replace single-shot LD update with an inner stabilization loop for the LD/xi block.
9. Add trust-region style acceptance for LD moves based on objective improvement and mode validity.
10. Consider switching automatically to a more conservative fallback mode for exAL lower-tail VB.

## Concrete debugging program

### D1. Reproduce the failure at `n=100`
Use the existing reduced audit dataset and compare:
- base settings
- direct_commit = FALSE with damping
- stronger step caps
- xi_method = mc
- xi_method = delta with xi_damping < 1

Measure:
- convergence
- lag-1 / lag-2 correlations for gamma, sigma, s_mean, tau2_mean
- `ld_local_mode_pass`
- final gradient norm
- coefficient RMSE

### D2. Add automatic cycle diagnostics
For the LD block, compute on the last K iterations:
- lag-1 and lag-2 correlation for gamma and sigma
- same for s_mean / tau2_mean
- alternating-state amplitude

Trigger a cycle flag when:
- lag-1 < -0.8
- lag-2 > 0.95
- amplitude above a small threshold

### D3. Test mode-quality gating
On the same `n=100` case:
- if `ld_local_mode_pass = FALSE`, do not direct-commit
- instead revert to damped update

### D4. Test xi approximation sensitivity
At `n=100` on the same benchmark:
- compare `xi_method = delta` vs `mc`
- compare `xi_damping = 1` vs `0.25` or `0.5`

### D5. Promote the best fix to the large reference case
Only after a clear `n=100` winner:
- rerun the `n=10000`, tau `0.05` benchmark
- verify:
  - no 2-cycle
  - valid local mode
  - stable coefficients
  - credible exAL fit

## Success criteria

A candidate fix is acceptable only if all of these hold:
1. no 2-cycle in gamma/sigma/s_mean/tau2 traces
2. `ld_local_mode_pass = TRUE`
3. gradient norm is small
4. coefficients remain finite and plausible
5. exAL VB fit is in the same qualitative regime as exAL MCMC

## Immediate recommendation

Start with:
1. `direct_commit = FALSE`
2. `damping = 0.25`
3. `xi_damping = 0.25`
4. automatic cycle detection
5. mode-quality-based commit rejection

Reason:
- this is already strongly supported by the reduced audit
- it is the least invasive fix
- it directly targets the confirmed failure mode

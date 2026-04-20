# QDESN Tau050 Representative Completion Wave Postmortem

Date: 2026-04-20
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## Scope

This note audits the minimal EXAL ridge continuation wave that was launched to
finish the representative-triad decision gate:

- `representative_completion_exal_tau_only`
- `representative_completion_exal_theta_tau`

Reference launch note:

- [completion wave launch](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_tau050_representative_completion_wave_launch_20260420.md)

## Targeted Root

Both completion lanes targeted the same single root:

- lane: `mcmc_exal`
- family: `laplace`
- `tau = 0.50`
- `fit_size = 5000`
- prior: `ridge`
- root id:
  `root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_ridge`

## Final Outcome

| Arm | Status | Signoff | Runtime sec | Failure family |
|---|---|---|---:|---|
| `tau only` | `FAIL` | `FAIL` | `178.673` | precision / Cholesky |
| `theta + tau` | `FAIL` | `FAIL` | `114.078` | precision / Cholesky |

Both arms ended in the same fit-level terminal state:

- `status = FAIL`
- `signoff_grade = FAIL`
- `signoff_reason = missing_chain_diagnostics`

Root-level manifests also show terminal `FAIL` for both runs.

## What Failed

The direct failure is not the earlier latent-`v` invalid-draw family.

Instead, both logs terminate during burn with a positive-definiteness failure in
the EXAL beta precision draw:

```text
Error in chol.default(Prec + 1e-10 * diag(nrow(Prec))) :
  the leading minor of order ... is not positive
Calls: fit_exAL_on_X_train -> .exal_mcmc_sample_mvnorm_prec -> chol -> chol.default
Execution halted
```

Representative logs:

- [tau-only EXAL ridge failure log](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/qdesn_dynamic_exdqlm_crossstudy_tau050_representative_completion_exal_tau_only_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-representative_completion_exal_tau_only-20260420-013345__git-ef66349/20260420-013353__git-ef66349/roots/root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_ridge/fits/mcmc_exal/logs/pipeline_stdout.log)
- [theta+tau EXAL ridge failure log](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/qdesn_dynamic_exdqlm_crossstudy_tau050_representative_completion_exal_theta_tau_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-representative_completion_exal_theta_tau-20260420-013345__git-ef66349/20260420-013353__git-ef66349/roots/root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_ridge/fits/mcmc_exal/logs/pipeline_stdout.log)

## Timing Read

Failure occurs after startup and after warm-start setup, not at launch-time:

- `tau only`: burn failure around iteration `600`
- `theta + tau`: burn failure around iteration `500`

So this is neither:

- an infrastructure failure
- a collector failure
- nor a direct replay of the latent-`v` invalid-draw event

It is a second numerical mechanism in the remaining surface.

## Most Important Takeaways

1. The completion gate was still worth running.
   It ruled out blind promotion of `theta + tau` to the full remaining cohort.

2. The unresolved remaining-fail surface is now at least two-mechanism:
   - latent-`v` invalid-draw failures on the long-window hard-fail surface
   - EXAL ridge beta-precision / Cholesky failures

3. `theta + tau` remains a promising stabilization direction for the earlier
   latent-`v`-dominated surface, but it is not sufficient on the EXAL ridge
   precision pocket.

4. The next relaunch should be run-specific or cluster-specific, not a single
   global spec for all remaining failed roots.

## Practical Implication

The next program should split the remaining hard-fail roots into:

- a latent-`v`-dominated cluster
- an EXAL ridge precision-stabilization cluster

and launch different dedicated specs against those two groups.

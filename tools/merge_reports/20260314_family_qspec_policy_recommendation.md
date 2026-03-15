# Family-QSpec Recommended Signoff Policy

## Recommendation

Keep the current `PASS` thresholds unchanged.

Relax only the `WARN`-level MCMC thresholds for comparison eligibility:

- `ESS sigma warn`: `10 -> 5`
- `ESS gamma warn`: `10 -> 5`
- `ESS state warn`: `10 -> 5`
- `ACF1 warn`: `0.98 -> 0.995`
- `Geweke abs z warn`: `3.0 -> 5.0`
- `Half-chain drift warn`: `0.50 -> 0.75`

Do **not** relax the hard failure policy for:

- `non_finite_fit`
- `missing_elbo_trace`
- `domain_violation`
- `kernel_not_signoff_ready`
- `rhs_collapse`

Do **not** relax the current VB policy at this stage.

## Why

The current failure surface is dominated by MCMC soft-failure diagnostics rather than hard execution pathologies.

Under the original policy:

- unhealthy method fits: `114`
- comparison-eligible method fits: `174 / 288`
- targeted repair model paths: `91`

Under the recommended policy:

- unhealthy method fits: `100`
- comparison-eligible method fits: `188 / 288`
- targeted repair model paths: `80`

## Interpretation

This policy is intentionally conservative:

- it reduces over-exclusion from short-chain MCMC diagnostics
- it does not hide hard numerical or missing-diagnostic failures
- it preserves the distinction between:
  - `PASS`: convergence-certified
  - `WARN`: comparison-eligible but not fully certified
  - `FAIL`: excluded and targeted for repair

## Repair-wave defaults wired for this policy

Recommended repair tuning is currently set to:

- static MCMC burn: `1500`
- dynamic MCMC burn: `1500`
- static MCMC keep: `5000`
- dynamic MCMC keep: `5000`
- static/dynamic trace diagnostics: enabled
- static/dynamic trace interval: `25`

Why the heavier rerun is justified:

- dynamic `dqlm` failures are mostly state-Geweke failures despite otherwise decent ESS
- dynamic `exdqlm` failures still show weak gamma ESS and large drift
- static `exAL` failures still have very weak gamma ESS and large half-chain drift

This is meant to address the remaining MCMC-heavy tail without changing the scientific interpretation of hard-failure VB cases.

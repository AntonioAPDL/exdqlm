# Refreshed288 RHS-NS Tau Policy

Date: `2026-04-17`

## Purpose

This note records the explicit `rhs_ns` global-shrinkage `tau` warmup policy for
the refreshed static shrinkage relaunch and clarifies how that differs from the
already-launched partial `2026-04-16` run.

## Canonical Policy Going Forward

The refreshed validation study must never use plain `rhs`. The static shrinkage
lane uses only `ridge` and `rhs_ns`.

For `rhs_ns`, the explicit warmup policy is:

| context | prior | `freeze_tau_warmup_iters` | `min_iter` |
|---|---|---:|---:|
| static shrink VB main fit | `rhs_ns` | `50` | `80` |
| static shrink MCMC main fit | `rhs_ns` | `500` | `NA` |
| static shrink MCMC VB init | `rhs_ns` | `50` | `80` |

Additional explicit controls kept aligned with package defaults:

- `freeze_tau_iters = freeze_tau_warmup_iters`
- `update_every = 1`
- `update_every_warmup = 1`
- `update_every_warmup_iters = 0`
- `force_tau_after_warmup = TRUE`

## Current Partial Run

The already-launched partial refreshed run under:

- `tools/merge_reports/full288_refreshed288_paperaligned_20260416`

was prepared before this policy was made explicit in the relaunch stack.

Representative evidence:

- config example: `tools/merge_reports/full288_refreshed288_paperaligned_20260416/configs/row_0277_run_config.rds`
- observed fields:
  - `beta_prior = "rhs_ns"`
  - `beta_prior_controls = NULL`

That means the current partial run is inheriting package defaults implicitly,
not the explicit refreshed policy above.

## Interpreting The Current Partial Run

Because `beta_prior_controls = NULL` in the current generated configs:

- static shrink VB rows are using package-default `rhs_ns` tau warmup
  - effective `freeze_tau_warmup_iters = 50`
- static shrink MCMC rows are also using package-default `rhs_ns` tau warmup
  - effective `freeze_tau_warmup_iters = 50`
- static VB `min_iter` was not encoded explicitly in the current generated row
  configs
  - in practice the static LDVB runner path fell back to the package default
    `exdqlm.vb.min_iter = 10`

So the current partial run should be interpreted as:

| context | effective behavior in current partial run |
|---|---|
| static shrink VB | `tau` warmup `50`, implicit |
| static shrink MCMC | `tau` warmup `50`, implicit |
| static shrink VB `min_iter` | `10`, implicit |

This differs from the intended refreshed policy:

| context | intended refreshed policy |
|---|---|
| static shrink VB | `tau` warmup `50`, explicit |
| static shrink MCMC | `tau` warmup `500`, explicit |
| static shrink VB `min_iter` | `80`, explicit |

## Operational Consequence

The new explicit `50 / 80 / 500` policy is now wired into the refreshed tool
stack for future refreshed manifest generation.

It does **not** retroactively change the already-generated configs inside the
current partial run root.

So:

- the current partial run remains historically valid as an implicit-default run
- any future refreshed re-prepare from scratch should use the new explicit
  policy
- the current partial run and the updated refreshed policy should not be treated
  as identical

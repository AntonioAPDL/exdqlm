# refreshed288 p90 full288 relaunch prepare implementation

Date: 2026-04-22
Branch: `validation/rerun-after-0.4.0-sync-0p4p0-integration`

## Scope

Implemented the full refreshed288 relaunch prepare stack for the active dynamic scenario
`dlm_constV_p90_m0amp_highnoise_steepertrend_v1`, covering:

- fresh dataset registry alias
- fresh method registry
- fresh full manifest
- fresh smoke manifest
- fresh run contract
- launch wrapper
- background launch wrapper
- healthcheck wrapper
- focused relaunch contract test

The prepare stack is wired to the current normalized `0.4.0` package layer and keeps the
full `288`-row study geometry:

- full dynamic: `72`
- full static paper: `72`
- full static shrink: `144`

## Frozen outputs

Key source and orchestration files:

- `tools/merge_reports/LOCAL_refreshed288_helpers_20260422_p90_full288.R`
- `tools/merge_reports/LOCAL_refreshed288_prepare_20260422_p90_full288.R`
- `tools/merge_reports/LOCAL_refreshed288_evaluate_20260422_p90_full288.R`
- `tools/merge_reports/LOCAL_refreshed288_report_20260422_p90_full288.R`
- `tools/merge_reports/LOCAL_refreshed288_run_row_20260422_p90_full288.R`
- `tools/merge_reports/LOCAL_refreshed288_launch_20260422_p90_full288.sh`
- `tools/merge_reports/LOCAL_refreshed288_launch_background_20260422_p90_full288.sh`
- `tools/merge_reports/LOCAL_refreshed288_healthcheck_20260422_p90_full288.sh`
- `tests/testthat/test-refreshed288-p90-relaunch-contract.R`

Prepared run-tag outputs:

- `tools/merge_reports/LOCAL_refreshed288_dataset_registry_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_method_registry_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_full_manifest_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_smoke_manifest_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_run_contract_20260422_p90_full288_baseline_v1.csv`

## Runtime contract

The prepared relaunch contract is pinned to:

- active dynamic scenario: `dlm_constV_p90_m0amp_highnoise_steepertrend_v1`
- dynamic effective sizes: `500`, `5000`
- VB method: `LDVB`
- VB max iterations: `300`
- VB minimum ELBO iterations: `80`
- static VB internal sampling: `1000`
- posterior metric draws: `20000`
- VB posterior draws: `20000`
- VB synthesis sample size: `20000`
- MCMC method: `slice`
- MCMC VB init: `TRUE`
- MCMC burn-in: `5000`
- MCMC kept draws: `20000`
- MCMC thinning: `1`

Shared baseline warmup policy:

- package-default exAL `(sigma, gamma)` warmup
- package-default `rhs` / `rhs_ns` tau warmup
- no retry overlays preloaded into the baseline manifests

## Verification

Prepare and orchestration checks completed:

- prepare script regenerated the expected `54`-entry dataset registry
- method registry regenerated the expected `16` method-profile rows
- full manifest regenerated the expected `288` rows
- smoke manifest regenerated the expected `48` rows
- full dry-run printed the expected four launch phases and worker counts
- full healthcheck regenerated the status, phase, and method summaries without error

Focused tests completed:

- `tests/testthat/test-refreshed288-p90-relaunch-contract.R`
- `tests/testthat/test-dynamic-p90-canonical-source-contract.R`

Reduced-budget preflight coverage:

- static VB path: completed successfully
- static MCMC path: completed successfully
- dynamic VB path: launched successfully and observed computing under sustained full CPU
- dynamic MCMC path: launched successfully, built VB init/output paths, and observed computing under sustained full CPU

The dynamic preflights were intentionally reduced-budget path validations, not scientific runs.
Their purpose here was to confirm that the dynamic runner starts cleanly against the new p90
dataset surface and the current `0.4.0` package APIs.

## Overnight launch entrypoint

Background launch command:

```bash
tools/merge_reports/LOCAL_refreshed288_launch_background_20260422_p90_full288.sh \
  --manifest-kind=full \
  --run-tag=20260422_p90_full288_baseline_v1
```

Healthcheck command:

```bash
tools/merge_reports/LOCAL_refreshed288_healthcheck_20260422_p90_full288.sh \
  --manifest-kind=full \
  --run-tag=20260422_p90_full288_baseline_v1
```

## Readiness call

The relaunch prepare stack is ready for overnight background execution.

The main residual scientific risk is not orchestration but model behavior on the new p90
dynamic datasets, especially for dynamic `exdqlm` and long-horizon dynamic MCMC rows. That risk
is already reflected in the method-profile and retry-overlay planning, so the baseline launch can
proceed cleanly and any follow-up rescue can be applied case-specifically rather than by changing
the global contract.

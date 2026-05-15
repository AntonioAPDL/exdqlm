# Runbook

## 1. Confirm Runtime

```sh
Rscript -e 'cat(R.version.string, "\n"); stopifnot(getRversion() >= "4.6.0")'
```

## 2. Confirm Shared Source Exists

The shared source root should contain one full source for each family/tau cell:

`/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources`

Do not proceed to model fitting until the source registry is frozen and verified.

## 3. Prepare

```sh
Rscript validation/fitforecast_v2/scripts/prepare_exdqlm_dynamic_fitforecast_v2_validation.R
```

This writes the run manifest and row configs. It does not fit models.

## 4. Verify

```sh
Rscript validation/fitforecast_v2/scripts/verify_exdqlm_dynamic_fitforecast_v2_source_windows.R
Rscript validation/fitforecast_v2/scripts/healthcheck_exdqlm_dynamic_fitforecast_v2_validation.R
```

## 5. Smoke Dry Run

```sh
Rscript validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R --phase smoke --dry-run
Rscript scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R --phase smoke --dry-run
Rscript scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R --phase smoke --prepare-only
```

## 6. Smoke Compute

```sh
EXDQLM_FFV2_LAUNCH_APPROVED=true \
Rscript validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R --phase smoke

QDESN_FFV2_LAUNCH_APPROVED=true \
Rscript scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R --phase smoke
```

## 7. Staged Full Compute

After smoke closeout:

```sh
EXDQLM_FFV2_LAUNCH_APPROVED=true \
Rscript validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R --phase vb_full
```

Then TT500 MCMC:

```sh
EXDQLM_FFV2_LAUNCH_APPROVED=true \
Rscript validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R --phase mcmc_tt500
```

Do not run TT5000 MCMC without a fresh approval.

TT5000 requires the ordinary launch approval plus the TT5000-specific approval:

```sh
QDESN_FFV2_LAUNCH_APPROVED=true QDESN_FFV2_TT5000_APPROVED=true \
Rscript scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R --phase mcmc_tt5000
```

## 8. Closeout After Each Stage

```sh
Rscript validation/fitforecast_v2/scripts/healthcheck_exdqlm_dynamic_fitforecast_v2_validation.R
Rscript validation/fitforecast_v2/scripts/export_exdqlm_dynamic_fitforecast_v2_shared_interface.R
Rscript scripts/healthcheck_qdesn_dynamic_fitforecast_v2_validation.R
Rscript scripts/export_qdesn_dynamic_fitforecast_v2_shared_interface.R --campaign-report-root <campaign-report-root>
```

Required closeout evidence:

- status counts;
- health gate counts;
- storage audit with zero forbidden successful run payloads;
- shared-interface row count and path;
- explicit decision to continue, retry, repair, or stop.

The invalid partial Q-DESN smoke tag
`qdesn-dynamic-fitforecast-v2-smoke-20260515-184752__git-5de7a28`
was aborted during launcher verification and is not article-consumable.

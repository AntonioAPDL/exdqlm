# RQR-DESN Broad Simulation Frozen Config

Date: 2026-07-16

Config:

```text
config/rqr_desn/rqr_desn_broad_simulation_frozen_20260716.R
```

Validator:

```text
scripts/audit_rqr_desn_broad_config.R
```

Status: frozen planning config only. It does not authorize launch and does not
authorize article updates.

## Bridge Authorization

The config is authorized by the package-side bridge result:

```text
bridge commit: bd17d8d61a595bf39f84db5f40476c0fa2aa21b7
readiness: reports/rqr_desn_pre_simulation_readiness/rqr_desn_readiness_20260716-141012_git_bd17d8d61a59
pilot: reports/rqr_desn_pilot/rqr_desn_pilot_20260716-140837_git_bd17d8d61a59
pilot decision: go_for_broad_spec=yes
```

The bridge passed package install, focused RQR tests, clean readiness archive,
and pilot gates. That permits freezing the broad-study design, not running it.

## Scientific Contract

The native estimand remains a central prediction interval. The simulation must
report interval coverage, width, interval score, endpoint accuracy when oracle
endpoints are available, midpoint accuracy, finite/order checks, failures, and
runtime diagnostics.

The simulation must not:

- call `coverage_level` a quantile level;
- pass `target_p` or `p0` as RQR target arguments;
- claim a response likelihood;
- sample future responses from the RQR pseudo-AL augmentation;
- treat VB uncertainty as calibrated;
- modify article or application repositories.

## Frozen Study Shape

The frozen config has two stages.

| Stage | Families | Replicates | Purpose |
|---|---:|---:|---|
| `fixed_design_calibration` | 4 | 24 | RQR interval calibration with fixed features and oracle endpoints |
| `teacher_forced_desn_dynamic` | 2 | 18 | RQR-DESN readout evaluation on explicit teacher-forced reservoir designs |

Primary MCMC uses coverage levels `0.80` and `0.90`, learning rates `0.50`,
`1.00`, and `1.50`, and ridge/RHS_NS priors. VB appears only as a sidecar.

The expected workload from the frozen config is:

```text
total rows:    3312
MCMC rows:     2880
VB sidecar:    168
baseline rows: 264
```

These are expected scenario rows, not completed fits.

## Validation Command

Run this audit before any launcher consumes the config:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  scripts/audit_rqr_desn_broad_config.R \
  --config config/rqr_desn/rqr_desn_broad_simulation_frozen_20260716.R
```

The audit writes local ignored artifacts under:

```text
reports/rqr_desn_broad_config_audit/
```

## Next Step

The next task should be a launcher-preflight implementation that reads this
frozen config and materializes a scenario manifest without fitting models. Only
after the manifest audit passes should a broad background run be considered.

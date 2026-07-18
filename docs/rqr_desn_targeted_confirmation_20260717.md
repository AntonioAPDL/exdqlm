# RQR-DESN Targeted Confirmation

Date: 2026-07-17

Status: package-side targeted confirmation implementation. This does not
authorize article updates.

## Purpose

The targeted confirmation pass follows the broad RQR-DESN results audit. The
broad run selected promising MCMC interval-readout configurations. The targeted
confirmation pass freezes those configurations and reruns them on fresh
independent seeds before any article text is considered.

## Evidence Chain

```text
broad run -> results audit -> targeted confirmation -> article decision
```

The completed broad audit recommended:

```text
promote_to_targeted_confirmation
```

It did not allow article updates.

## Main Files

```text
config/rqr_desn/rqr_desn_targeted_confirmation_20260717.R
scripts/materialize_rqr_desn_targeted_confirmation_manifest.R
scripts/run_rqr_desn_broad_simulation.R
scripts/audit_rqr_desn_broad_results_promotion.R
```

The confirmation manifest is built from:

```text
reports/rqr_desn_broad_simulation/results_audit_promotion_20260717/targeted_confirmation_candidate_grid.csv
```

## Confirmation Surface

The default confirmation denominator uses:

- 30 unique MCMC candidate specifications;
- 12 winner cells represented by winner, nearest-coverage, and score-runner-up
  roles;
- empirical train-interval baselines for paired deltas;
- the original broad-run replicate depths: 24 fixed-design replicates and 18
  dynamic replicates;
- fresh seed base `10170000`;
- no VB rows;
- no response likelihood;
- no response predictive draws;
- no recursive response sampling.

This yields 912 scenario rows:

- 648 MCMC rows;
- 264 empirical baseline rows;
- 0 VB rows.

## Materialization Command

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  scripts/materialize_rqr_desn_targeted_confirmation_manifest.R \
  --output-dir reports/rqr_desn_broad_simulation/rqr_desn_targeted_confirmation_20260717_git_<commit>
```

## Run Command

After the manifest is materialized:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  scripts/run_rqr_desn_broad_simulation.R \
  --config config/rqr_desn/rqr_desn_targeted_confirmation_20260717.R \
  --output-dir reports/rqr_desn_broad_simulation/rqr_desn_targeted_confirmation_20260717_git_<commit> \
  --install-package true \
  --workers 4
```

The broad runner is reused intentionally. The targeted manifest supplies the
scenario denominator, while the runner supplies already-tested fitting, scoring,
status, and aggregation behavior.

## Audit Command

After completion, run:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  scripts/audit_rqr_desn_broad_results_promotion.R \
  --run-dir reports/rqr_desn_broad_simulation/rqr_desn_targeted_confirmation_20260717_git_<commit> \
  --output-dir reports/rqr_desn_broad_simulation/results_audit_targeted_confirmation_20260717
```

## Article Guard

The article should still not be touched until the targeted confirmation audit
closes cleanly. The article decision should require:

- all confirmation rows complete;
- zero failure rows;
- MCMC winners improve over empirical baselines in paired deltas;
- calibration remains green/yellow for the promoted cells or is explicitly
  handled;
- no MCMC diagnostic flags;
- dynamic claims stay limited to teacher-forced held-out interval scoring;
- fixed-design claims are the only claims using oracle endpoint recovery;
- VB remains excluded unless a separate calibration study is run.

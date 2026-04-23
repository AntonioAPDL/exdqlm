# QDESN Pre-p90 Validation Output Cleanup Plan

Date: 2026-04-22

## Goal

Set up a safe and well-documented cleanup workflow for legacy qdesn validation-study
outputs created before the current `p90` steeper-trend relaunch, while preserving:

- the live `p90` relaunch result tree
- all source dataset surfaces under `results/qdesn_mcmc_validation/*_sources`
- tracked package data under `data/*.rda`
- reports, documentation, and lightweight audit artifacts

## Important Clarification

The repo currently does **not** contain generated validation-study `.rda` outputs that
need purging. The only `.rda` files found are tracked package datasets under `data/`.

The actual storage-heavy launch outputs are generated mainly as `.rds` binaries inside
older `*_validation` result trees, especially `forecast_objects.rds`.

So the cleanup target is:

- old validation result trees and their `.rds` payloads

not:

- package data `.rda` files

## Cleanup Policy

### Protected surfaces

These must remain untouched:

- `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_validation`
- all `results/qdesn_mcmc_validation/*_sources` directories
- `data/*.rda`
- `reports/` and `docs/` audit/report surfaces

### Targeted legacy surfaces

The cleanup should target top-level validation result trees under:

- `results/qdesn_mcmc_validation/*_validation`

except the protected current `p90` relaunch tree above.

This is intentionally a top-level cleanup policy so that:

- the live relaunch remains isolated
- source datasets remain reproducible
- old heavy result trees can be cleared cleanly in one pass

## Workflow

### Step 1. Dry-run inventory

Run:

```bash
scripts/cleanup_qdesn_pre_p90_validation_outputs.sh --run-label <label>
```

This writes manifests under:

`reports/qdesn_mcmc_validation/storage_cleanup/<label>/`

### Step 2. Review the manifests

Review:

- `cleanup_summary.md`
- `validation_dirs_to_delete.tsv`
- `protected_paths.tsv`
- `package_rda_inventory.tsv`
- `target_binary_inventory_top200.tsv`

### Step 3. Wait for live relaunch to settle

Do **not** run destructive cleanup while the live `qdesn_p90_*` tmux sessions are
still active, unless there is a deliberate reason to override the safety gate.

### Step 4. Execute after the relaunch is no longer live

Run:

```bash
scripts/cleanup_qdesn_pre_p90_validation_outputs.sh --execute --run-label <label>
```

By default, execute mode blocks itself if live `qdesn_*` tmux sessions still exist.

If a future controlled cleanup must run despite live sessions, the script supports:

```bash
scripts/cleanup_qdesn_pre_p90_validation_outputs.sh \
  --execute \
  --allow-live-sessions \
  --run-label <label>
```

That override should be treated as exceptional, not routine.

## Safety Guarantees

The new cleanup script:

- defaults to dry run
- inventories tracked package `.rda` files separately
- inventories targeted generated `.rda/.RData` files separately
- confirms there are no generated validation `.rda/.RData` outputs outside protected surfaces
- records the exact delete set before execution
- records the protected set explicitly
- captures filesystem, git, and tmux state before and after
- blocks execute mode when live `qdesn_*` tmux sessions are present
- blocks execute mode if any targeted `.rda/.RData` file is detected

## Deliverables

- script:
  - `scripts/cleanup_qdesn_pre_p90_validation_outputs.sh`
- dry-run manifest root:
  - `reports/qdesn_mcmc_validation/storage_cleanup/20260422_pre_p90_cleanup_dryrun`
- execute-block safety check root:
  - `reports/qdesn_mcmc_validation/storage_cleanup/20260422_pre_p90_cleanup_execute_block_check`

## Acceptance Checklist

- [x] Separate package `.rda` inventory from generated validation outputs
- [x] Protect the live `p90` relaunch tree
- [x] Protect all source dataset surfaces
- [x] Materialize dry-run manifests
- [x] Validate execute-mode blocking while live sessions exist
- [ ] Execute destructive cleanup after the live relaunch is finished and reviewed

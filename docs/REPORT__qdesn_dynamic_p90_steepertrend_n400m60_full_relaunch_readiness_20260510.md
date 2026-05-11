# QDESN Dynamic P90 Steeper-Trend n400/m60 Full Relaunch Readiness

Date: 2026-05-10

Worktree:
`/data/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

Branch:
`feature/qdesn-mcmc-alternative-0p4p0-integration`

Current HEAD during this readiness pass:
`ac7ff7e` (`docs: close qdesn n400 standard smoke`)

## Purpose

This note prepares the QDESN dynamic-only p90 steeper-trend n400/m60 validation
for the main 36-root / 144-fit relaunch. It confirms the scientific MCMC budget,
records the current-HEAD full preflight, and lists the final items that must be
accepted before launching the expensive campaign.

This note does not start the full validation run.

## Confirmed Full Budget

The full storage-light defaults already match the requested larger MCMC budget:

- `mcmc_n_burn: 5000`
- `mcmc_n_mcmc: 20000`
- `mcmc_thin: 1`
- `posterior_metric_draws: 20000`
- `vb_sampling_nd_draws: 20000`
- `vb_synthesis_n_samp: 20000`

The smoke-only defaults are separate and remain intentionally tiny for
infrastructure tests. They should not be used for the article-facing relaunch.

Full defaults:
`config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_storage_light_defaults.yaml`

Smoke defaults:
`config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_testing_smoke_defaults.yaml`

## Confirmed Full Contract

Current-HEAD full preflight:
`reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n400m60-rhs-tau1em5-full-preflight-20260510-currenthead__git-ac7ff7e/launch/qdesn_dynamic_exdqlm_crossstudy_preflight.md`

Selected full grid:
`reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n400m60-rhs-tau1em5-full-preflight-20260510-currenthead__git-ac7ff7e/launch/selected_grid_full.csv`

Preflight facts:

- Git SHA: `ac7ff7e`
- Defaults: storage-light full defaults
- Grid: fresh full grid
- Selected roots: `36`
- Requested fits: `144`
- Requested fits per root: `4`
- Unique dataset cells: `18`
- Scenario: `dlm_constV_p90_m0amp_highnoise_steepertrend_v1`
- Families: `gausmix`, `laplace`, `normal`
- Taus: `0.05`, `0.25`, `0.5`
- Effective fit sizes: `500`, `5000`
- Priors: `rhs_ns`, `ridge`
- Likelihood variants: `exal`, `al`
- Inference methods: `vb`, `mcmc`
- Reservoir profile: `deep_d3_n400x3_skip100_w300_m60`
- DESN seed: `123`
- Active QDESN processes at preflight: `0`
- Stale `/home/.../local/src` hits in the current preflight artifact tree: `0`

## Confirmed Active Model Settings

DESN profile:

- `D: 3`
- `n: [400, 400, 400]`
- `n_tilde: [400, 400]`
- `m: 60`
- `alpha: [0.3, 0.3, 0.3]`
- `rho: [0.95, 0.95, 0.95]`
- `act_f: [tanh, tanh, tanh]`
- `act_k: [identity, identity, identity]`
- `pi_w: [0.1, 0.1, 0.1]`
- `pi_in: [1.0, 1.0, 1.0]`
- `washout: 300`
- `add_bias: yes`
- `seed: 123`

RHS-NS prior:

- `tau0: 1.0e-5`
- `a_zeta: 2.0`
- `b_zeta: 1.0`
- `s2: 1.0`
- `shrink_intercept: no`
- `intercept_prec: 1.0e-10`
- `n_inner: 2`
- `var_floor: 1.0e-08`

Seed policy:

- The reservoir profile seed is `123`.
- The fresh grids carry explicit `desn_seed: 123`.
- The deterministic root `seed` column is root metadata and must not be
  interpreted as the reservoir seed.

## Verification Completed

Smoke gates already completed:

- Active 16-fit fast micro-smoke completed `4 / 4` roots and `16 / 16` fits.
- Active 48-fit standard smoke completed `12 / 12` roots and `48 / 48` fits.
- The standard smoke retained `0` broad `forecast_objects.rds` payloads and
  `0` `.rda` / `.RData` files.
- Standard-smoke result footprint was about `65M`; report footprint was about
  `1.1M`.
- Smoke MCMC signoff failures were expected under the tiny smoke-only budget and
  are not scientific evidence.

Current readiness checks completed:

```bash
R_LIBS=/home/jaguir26/R/x86_64-redhat-linux-gnu-library/4.5:/data/jaguir26/R/x86_64-redhat-linux-gnu-library/4.4 \
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_storage_light_defaults.yaml \
  --grid config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_grid.csv \
  --batch full \
  --prepare-only \
  --allow-grid-subset \
  --no-plots \
  --workers 1 \
  --run-tag qdesn-dynamic-p90-steepertrend-n400m60-rhs-tau1em5-full-preflight-20260510-currenthead__git-ac7ff7e
```

Result: full preflight completed successfully.

```bash
R_LIBS=/home/jaguir26/R/x86_64-redhat-linux-gnu-library/4.5:/data/jaguir26/R/x86_64-redhat-linux-gnu-library/4.4 \
Rscript -e "pkgload::load_all('.', quiet = TRUE); testthat::test_file('tests/testthat/test-qdesn-dynamic-p90-steepertrend-config.R')"
```

Result: `136` passes, `0` failures, `0` warnings, `0` skips.

## Required Decisions Before Launch

1. **Confirm launch topology.**
   The current launcher can run the full 36-root campaign as one campaign. This
   is the simplest for closeout and article handoff. Sharding by tau or family
   would reduce risk per launch, but it would require a deliberate merge/closeout
   plan before Article-Q-DESN can consume the result.

2. **Confirm worker count.**
   The full defaults set `campaign_workers: 16`. The standard smoke used
   `workers=4` and took about `3h 48m` with tiny MCMC. The full MCMC budget is
   much larger, so runtime should be expected to be long. A lower worker count
   may be gentler on the server; a higher count may finish sooner but increases
   concurrent memory and I/O pressure.

3. **Confirm storage pause threshold.**
   The current tracker suggests pausing and inspecting if the full output root
   exceeds `1G` or if broad full-fit payloads appear. The standard smoke pruned
   about `11.96G` of pre-prune forecast objects to zero retained broad payloads
   across `48` fits, so storage-light behavior looks sound.

4. **Confirm failure policy.**
   Execution failures should stop the campaign and trigger inspection. Scientific
   signoff failures should be recorded in closeout tables, not automatically
   rerun, unless the failed diagnostics indicate a wiring/runtime defect.

5. **Confirm no automatic Article-Q-DESN switch.**
   The article should not consume the fresh n400/m60 run until the full campaign
   completes, compact artifacts are audited, and the article-facing closeout is
   generated.

## Ready Full Launch Command

Use only after explicit approval:

```bash
cd /data/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration
export R_LIBS=/home/jaguir26/R/x86_64-redhat-linux-gnu-library/4.5:/data/jaguir26/R/x86_64-redhat-linux-gnu-library/4.4

Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_storage_light_defaults.yaml \
  --grid config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_grid.csv \
  --batch full \
  --allow-grid-subset \
  --no-plots \
  --workers 16 \
  --tmux-session qdesn_p90_n400m60_rhs_tau1em5_full_YYYYMMDD \
  --run-tag qdesn-dynamic-p90-steepertrend-n400m60-rhs-tau1em5-full-YYYYMMDD-HHMMSS__git-ac7ff7e
```

## First Safe Commands Before Launch

Run these immediately before starting the full campaign:

```bash
cd /data/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration
git status --short --branch
git rev-parse --short HEAD
pgrep -af '[p]ipeline_real_main|[r]un_qdesn_dynamic|[q]desn_dynamic_exdqlm' || true
tmux ls 2>/dev/null || true
rg -n '/home/jaguir26/local/src|/home/.*/local/src' \
  config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_storage_light_defaults.yaml \
  config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_grid.csv \
  reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n400m60-rhs-tau1em5-full-preflight-20260510-currenthead__git-ac7ff7e \
  || true
```

Expected before launch:

- branch is clean and at the intended HEAD;
- no active QDESN validation runner processes;
- no unexpected conflicting tmux sessions;
- no stale `/home/.../local/src` paths in the active full launch inputs.

## Healthcheck Command After Launch

```bash
R_LIBS=/home/jaguir26/R/x86_64-redhat-linux-gnu-library/4.5:/data/jaguir26/R/x86_64-redhat-linux-gnu-library/4.4 \
Rscript scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_storage_light_defaults.yaml \
  --run-tag qdesn-dynamic-p90-steepertrend-n400m60-rhs-tau1em5-full-YYYYMMDD-HHMMSS__git-ac7ff7e
```

## Recommendation

The validation worktree is ready for a full-launch approval decision. The
strongest default path is a single full campaign using the storage-light defaults
and `workers=16`, because that keeps the closeout and article handoff simple.
If server load or runtime risk is a concern, create explicit shard grids and a
merge/closeout plan before launching any shard.

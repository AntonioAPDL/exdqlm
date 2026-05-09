# QDESN Dynamic P90 Steeper-Trend Fresh Relaunch Wiring

Date: 2026-05-09

Worktree:
`/data/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

Branch:
`feature/qdesn-mcmc-alternative-0p4p0-integration`

Base commit during initial wiring:
`197ffdf999ed873cc490adeef22d3b3f3853cf37`

Active DESN wiring commit:
`validation: wire qdesn fresh n400m60 reservoir` (current local `HEAD` when this
note is committed).

## Purpose

This note records the reproducible wiring for the fresh dynamic-only QDESN
period-90 steeper-trend validation scaffold.

The inherited file and run-tag stem still contains `n300m50` because the scaffold
was derived from the previous n300/m50 campaign. The active DESN candidate for
new dry/smoke/full validation is now the user-proposed n400/m60 profile below.
The final 144-fit article-facing campaign remains blocked until the active DESN
and RHS prior are revalidated through the same gates.

## Active DESN Candidate

Profile id:
`deep_d3_n400x3_skip100_w300_m60`

Specification:

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

Effective seed handling:

- the reservoir profile keeps `seed: 123`;
- fresh grids now include `desn_seed: 123`, because the pipeline builder gives
  `desn_seed` precedence over the root-level grid `seed`;
- the existing deterministic root `seed` column is retained as root metadata and
  run identity, but it no longer overrides the DESN reservoir seed for these
  fresh grids.

## Active RHS-NS Prior

The active `rhs_ns` prior for both VB and MCMC is:

- `tau0: 1.0e-5`
- `a_zeta: 2.0`
- `b_zeta: 1.0`
- `s2: 1.0`
- `shrink_intercept: no`
- `intercept_prec: 1.0e-10`
- `n_inner: 2`
- `var_floor: 1.0e-08`

For VB, the existing initialization settings remain:

- `init_log_tau: ~`
- `init_log_lambda: 0.0`
- `init_log_c2: 0.0`

Wired into:

- fresh storage-light defaults;
- reduced-budget testing/smoke defaults;
- fresh full, smoke, and micro-smoke grids;
- the materializer script, so regenerated fresh grids keep the active n400/m60
  profile and active RHS prior rather than reverting to the historical n300/m50
  profile or old RHS prior.

## Tracked Files Added Or Updated

Code and launcher wiring:

- `R/qdesn_dynamic_exdqlm_crossstudy.R`
- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`
- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_validation.R`

Fresh path-correct grids and defaults:

- `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_grid.R`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_storage_light_defaults.yaml`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_testing_smoke_defaults.yaml`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_grid.csv`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_micro_smoke_grid.csv`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_smoke_grid.csv`

## Wiring Summary

Path hygiene:

- Added a narrow dynamic-cross-study path rewrite layer.
- Fresh defaults can set `paths.rewrite_home_local_src_to_repo_root: yes`.
- Historical `/home/jaguir26/local/src/...` inventory paths are rewritten to the
  active repo root under `/data/jaguir26/local/src/...` when materialized source
  inputs are loaded.

Launcher reproducibility:

- Runner preflight manifests now record R version, `.libPaths()`, `R_LIBS`,
  `R_LIBS_USER`, and `R_LIBS_SITE`.
- Detached launcher scripts now export the same R library environment into the
  tmux-launched child process.

Storage policy:

- Storage-light defaults keep `retention_profile: analysis`.
- Full `forecast_objects.rds` payloads are not retained after compact summaries
  are written.
- `retain_full_rds_on_failure: no` is used for the fresh storage-light lane.

Testing/smoke budget:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_testing_smoke_defaults.yaml`
  reduces compute for dry/smoke validation only.
- Reduced values:
  - `posterior_metric_draws: 2000`
  - `vb_sampling_nd_draws: 2000`
  - `vb_synthesis_n_samp: 2000`
  - `mcmc_n_burn: 1000`
  - `mcmc_n_mcmc: 2000`
  - `mcmc_thin: 1`
- The reduced MCMC settings are present in the study contract, base
  `pipeline.inference.mcmc`, and both `ridge` and `rhs_ns` prior overrides.

## Generated Local Evidence

The package `.gitignore` excludes validation `reports/` and `results/` outputs.
The following evidence paths are therefore local run evidence, not tracked git
artifacts:

- Micro-smoke closeout:
  `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n300m50-fresh-v1-micro-smoke-20260507-202648__git-197ffdf/20260507-202656__git-197ffdf/summary/qdesn_dynamic_p90_steepertrend_n300m50_fresh_micro_smoke_closeout.md`
- Reduced-budget smoke preflight manifest:
  `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n300m50-testing-smoke-preflight-20260509__git-197ffdf/launch/qdesn_dynamic_exdqlm_crossstudy_preflight_manifest.json`
- Reduced-budget smoke preflight markdown:
  `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n300m50-testing-smoke-preflight-20260509__git-197ffdf/launch/qdesn_dynamic_exdqlm_crossstudy_preflight.md`
- Active-DESN current-RHS micro prepare-only preflight manifest:
  `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n400m60-rhs-current-micro-preflight-20260509__git-f7e1c87-dirty/launch/qdesn_dynamic_exdqlm_crossstudy_preflight_manifest.json`
- Active-DESN current-RHS selected micro grid:
  `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n400m60-rhs-current-micro-preflight-20260509__git-f7e1c87-dirty/launch/selected_grid_full.csv`
- Active-DESN active-RHS micro prepare-only preflight manifest:
  `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n400m60-rhs-tau1em5-micro-preflight-20260509__git-8253ed3-dirty/launch/qdesn_dynamic_exdqlm_crossstudy_preflight_manifest.json`
- Active-DESN active-RHS selected micro grid:
  `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n400m60-rhs-tau1em5-micro-preflight-20260509__git-8253ed3-dirty/launch/selected_grid_full.csv`

The shared cross-chat tracker is outside this git repository:

- `/data/jaguir26/local/src/QDESN_EXDQLM_DYNAMIC_VALIDATION_RELAUNCH_COORDINATION_2026-05-07.md`

## Verification Performed

Micro-smoke closeout:

- Run tag:
  `qdesn-dynamic-p90-steepertrend-n300m50-fresh-v1-micro-smoke-20260507-202648__git-197ffdf`
- Completed `4 / 4` roots and `16 / 16` fits with runner status `SUCCESS`.
- Results footprint was about `53M`; reports footprint was about `18M`.
- Retained `forecast_objects.rds`: `0`.
- Retained `.rda` / `.RData`: `0`.
- Compact train path CSVs: `16`.
- Compact holdout path CSVs: `16`.
- Diagnostic signoff mix was `PASS=6`, `WARN=4`, `FAIL=6`; these grades were
  documented but not used as a blocker for the infrastructure/storage gate.

Reduced-budget effective config check:

```bash
R_LIBS=/home/jaguir26/R/x86_64-redhat-linux-gnu-library/4.5:/data/jaguir26/R/x86_64-redhat-linux-gnu-library/4.4 \
Rscript - <<'EOF'
pkgload::load_all(".", quiet = TRUE)
defaults <- qdesn_validation_load_defaults(
  "config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_testing_smoke_defaults.yaml"
)
grid <- read.csv(
  "config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_micro_smoke_grid.csv",
  stringsAsFactors = FALSE
)
for (prior in unique(grid$beta_prior_type)) {
  row <- as.list(grid[match(prior, grid$beta_prior_type), , drop = FALSE])
  cfg <- qdesn_static_crossstudy_build_pipeline_cfg(
    root_spec = row,
    defaults = defaults,
    method = "mcmc",
    likelihood_family = "exal",
    x_cols = c("x_dummy"),
    T_use = as.integer(row$source_total_size)
  )
  print(list(
    prior = prior,
    n_burn = cfg$inference$mcmc$n_burn,
    n_mcmc = cfg$inference$mcmc$n_mcmc,
    thin = cfg$inference$mcmc$thin,
    nd_draws = cfg$sampling$nd_draws,
    synthesis_n = cfg$synthesis$n_samp,
    posterior_metric_draws = cfg$metrics$posterior_metric_draws
  ))
}
EOF
```

Active-DESN wiring checks:

- Fresh full grid: `36` roots, `18` dataset cells, active reservoir
  `deep_d3_n400x3_skip100_w300_m60`, `desn_seed=123`, no
  `/home/.../local/src` hits.
- Fresh smoke grid: `12` roots, `6` dataset cells, active reservoir
  `deep_d3_n400x3_skip100_w300_m60`, `desn_seed=123`, no
  `/home/.../local/src` hits.
- Fresh micro grid: `4` roots, `2` dataset cells, active reservoir
  `deep_d3_n400x3_skip100_w300_m60`, `desn_seed=123`, no
  `/home/.../local/src` hits.
- Package-level config build verified that both `ridge` and `rhs_ns`, for both
  `vb` and `mcmc`, resolve to `D=3`, `n=400,400,400`, `n_tilde=400,400`,
  `m=60`, `alpha=0.3,0.3,0.3`, `washout=300`, and effective DESN seed `123`.
- YAML parsing verified that both fresh defaults resolve `rhs_ns` to
  `tau0=1.0e-5` and `s2=1.0` for both VB and MCMC.
- Package-level config build verified that active `rhs_ns` resolves to
  `tau0=1.0e-5`, `a_zeta=2.0`, `b_zeta=1.0`, `s2=1.0`,
  `shrink_intercept=FALSE`, `intercept_prec=1.0e-10`, `n_inner=2`, and
  `var_floor=1.0e-08` for both VB and MCMC.
- Prepare-only runner preflight on the active-DESN/active-RHS micro grid wrote a
  selected grid with `4` roots, `2` dataset cells, `4` requested fits per root,
  active reservoir `deep_d3_n400x3_skip100_w300_m60`, `desn_seed=123`, and no
  `/home/.../local/src` hits.

Observed result:

- `ridge`: `n_burn=1000`, `n_mcmc=2000`, `thin=1`, `nd_draws=2000`,
  `synthesis_n=2000`, `posterior_metric_draws=2000`.
- `rhs_ns`: `n_burn=1000`, `n_mcmc=2000`, `thin=1`, `nd_draws=2000`,
  `synthesis_n=2000`, `posterior_metric_draws=2000`.

Reduced-budget standard-smoke prepare-only preflight:

```bash
cd /data/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration
export R_LIBS=/home/jaguir26/R/x86_64-redhat-linux-gnu-library/4.5:/data/jaguir26/R/x86_64-redhat-linux-gnu-library/4.4

Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_testing_smoke_defaults.yaml \
  --grid config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_smoke_grid.csv \
  --batch full \
  --prepare-only \
  --allow-grid-subset \
  --no-plots \
  --workers 2 \
  --run-tag qdesn-dynamic-p90-steepertrend-n300m50-testing-smoke-preflight-20260509__git-197ffdf
```

Observed manifest:

- `prepare_only=TRUE`
- selected roots: `12`
- unique dataset cells: `6`
- requested fits per root: `4`
- families: `gausmix`, `laplace`, `normal`
- tau: `0.25`
- fit sizes: `500`, `5000`
- priors: `rhs_ns`, `ridge`
- posterior metric draws: `2000`
- VB draws: `2000`
- synthesis draws: `2000`
- MCMC burn: `1000`
- MCMC samples: `2000`
- MCMC thin: `1`

## Reproducible Command Checklist

Use this from the QDESN worktree:

```bash
cd /data/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration
export R_LIBS=/home/jaguir26/R/x86_64-redhat-linux-gnu-library/4.5:/data/jaguir26/R/x86_64-redhat-linux-gnu-library/4.4
```

Regenerate fresh grids and storage-light defaults:

```bash
Rscript scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_grid.R
```

Dry preflight the reduced-budget smoke scaffold:

```bash
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_testing_smoke_defaults.yaml \
  --grid config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_smoke_grid.csv \
  --batch full \
  --prepare-only \
  --allow-grid-subset \
  --no-plots \
  --workers 2 \
  --run-tag qdesn-dynamic-p90-steepertrend-n300m50-testing-smoke-preflight-YYYYMMDD__git-SHA
```

Launch a reduced-budget smoke only after explicit compute approval:

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --runner scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_testing_smoke_defaults.yaml \
  --grid config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_smoke_grid.csv \
  --batch full \
  --allow-grid-subset \
  --no-plots \
  --workers 2 \
  --tmux-session qdesn_p90_n300m50_testing_smoke \
  --run-tag qdesn-dynamic-p90-steepertrend-n300m50-testing-smoke-YYYYMMDD-HHMMSS__git-SHA
```

## Gate For The Final Article-Facing Launch

Before any final 144-fit article-facing campaign:

1. Re-run the path hygiene and source-window audits.
2. Re-run prepare-only manifests for micro, smoke, and full surfaces.
3. Run a micro-smoke using the active DESN/RHS-prior spec.
4. Close out the micro-smoke with storage audit and compact-output evidence.
5. Run the standard smoke only after the new-spec micro-smoke passes.
6. Launch the full 144-fit campaign only after explicit approval.

Do not switch Article-Q-DESN to any current scaffold output. The current
micro-smoke and reduced-budget smoke preflight are infrastructure evidence only;
they used the earlier n300/m50 reservoir and are superseded for final validation
planning by the n400/m60 candidate wiring.

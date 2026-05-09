# QDESN Dynamic P90 Steeper-Trend Fresh Relaunch Wiring

Date: 2026-05-09

Worktree:
`/data/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

Branch:
`feature/qdesn-mcmc-alternative-0p4p0-integration`

Base commit during initial wiring:
`197ffdf999ed873cc490adeef22d3b3f3853cf37`

Current local active-spec commit after seed and smoke-budget fixes:
`ca06a81` (`validation: tighten qdesn n400 smoke budget`).

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
- this behavior is guarded by a regression test in
  `tests/testthat/test-qdesn-dynamic-p90-steepertrend-config.R`.

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
  - `vb.max_iter: 80`
  - `vb.n_samp_xi: 300`
  - `mcmc_n_burn: 100`
  - `mcmc_n_mcmc: 200`
  - `mcmc_thin: 1`
- The reduced MCMC settings are present in the study contract, base
  `pipeline.inference.mcmc`, and both `ridge` and `rhs_ns` prior overrides.
- The smoke MCMC signoff thresholds are intentionally relaxed because this lane
  is an infrastructure/storage gate, not an MCMC-quality gate.

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
- Aborted active-DESN active-RHS micro-smoke that exposed the dynamic
  `desn_seed` propagation bug:
  `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n400m60-rhs-tau1em5-micro-smoke-20260509-173753__git-b46bdee`
- Stopped corrected active-DESN active-RHS micro-smoke that verified seed/storage
  but exposed an overly heavy smoke budget:
  `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n400m60-rhs-tau1em5-micro-smoke-20260509-fixseed__git-ccb7fd0`
- Completed active-DESN active-RHS fast micro-smoke:
  `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n400m60-rhs-tau1em5-fast-micro-smoke-20260509__git-ca06a81`
- Active-DESN active-RHS fast micro-smoke closeout:
  `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n400m60-rhs-tau1em5-fast-micro-smoke-20260509__git-ca06a81/20260509-182711__git-ca06a81/summary/qdesn_dynamic_p90_steepertrend_n400m60_rhs_tau1em5_fast_micro_smoke_closeout.md`
- Active-DESN active-RHS fast smoke prepare-only preflight:
  `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n400m60-rhs-tau1em5-fast-smoke-preflight-20260509__git-ca06a81/launch/qdesn_dynamic_exdqlm_crossstudy_preflight.md`
- Active-DESN active-RHS full prepare-only preflight:
  `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n400m60-rhs-tau1em5-full-preflight-20260509__git-ca06a81/launch/qdesn_dynamic_exdqlm_crossstudy_preflight.md`

The aborted micro-smoke is not valid active-spec evidence because its
`fit_request.json` files showed `config.desn.seed` equal to the root metadata
seed, for example `62010`, instead of the requested DESN seed `123`. It was
stopped immediately after this was detected and must not be used for article
tables or launch approval.

The stopped `fixseed` micro-smoke is valid evidence for corrected DESN seed
propagation and compact retention on completed fits, but it is not a completed
smoke. Its live `fit_request.json` files showed `cfg_desn_seed=123`; completed
VB fits pruned full `forecast_objects.rds` after compact path export. It was
stopped because the smoke-only VB/MCMC budget was still too expensive for the
n400/m60 profile.

The completed `fast-micro-smoke` is the current active-spec infrastructure and
storage gate. It used commit `ca06a81`, active DESN seed `123`, the active
RHS-NS prior, and a deliberately small smoke-only MCMC budget
(`n_burn=100`, `n_mcmc=200`, `thin=1`). It completed all `4` roots and all `16`
fits with runner status `SUCCESS`, produced compact train/holdout CSVs for all
fits, and retained zero full `forecast_objects.rds` payloads. Its MCMC signoff
failures are expected for this tiny budget and must not be treated as scientific
quality approval.

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

Active n400/m60 fast micro-smoke closeout:

- Run tag:
  `qdesn-dynamic-p90-steepertrend-n400m60-rhs-tau1em5-fast-micro-smoke-20260509__git-ca06a81`
- Inner run tag: `20260509-182711__git-ca06a81`
- Completed `4 / 4` roots and `16 / 16` fits with runner status `SUCCESS`.
- Results footprint was about `22M`; reports footprint was about `468K`.
- Retained broad `forecast_objects.rds`: `0`.
- Retained `.rda` / `.RData`: `0`.
- Retained small diagnostic `.rds` files: `8` `rhs_trace.rds` files
  (`80,624` bytes total) and `16` `timing_summary.rds` files
  (`10,132` bytes total).
- Compact train path CSVs: `16`.
- Compact holdout path CSVs: `16`.
- Recorded pre-prune `forecast_objects.rds` bytes across `16` fits:
  `3,975,511,479`; recorded post-prune bytes: `0`.
- Train compact source-index range: `2000:6999`; holdout source-index:
  `7000`.
- Recursive path hygiene search of the completed run found zero
  `/home/jaguir26/local/src` hits.
- Diagnostic signoff mix was MCMC `FAIL=7`, MCMC `WARN=1`, VB `PASS=4`,
  VB `WARN=3`, VB `FAIL=1`. These are expected under the fast smoke MCMC budget
  and are not an MCMC-quality approval.
- Campaign summary recommendation:
  `COMPARISON_READY_WITH_DOCUMENTED_DYNAMIC_FAIL_BAND`.

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
- The first active-DESN active-RHS micro-smoke launch was intentionally stopped
  after its live `fit_request.json` showed the dynamic root normalizer had
  dropped `desn_seed`. The fix is in `R/qdesn_dynamic_exdqlm_crossstudy.R`,
  where enriched dynamic root specs now retain `out$desn_seed` separately from
  `out$seed`.
- Targeted regression verification after the fix:
  `pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-qdesn-dynamic-p90-steepertrend-config.R", reporter = "summary")`
  completed successfully.
- The first corrected micro-smoke using `ccb7fd0` was stopped at `2026-05-09
  18:24 EDT` with `3` completed fits and `3` retention manifests. It confirmed
  DESN seed `123` in live fit logs, but it showed that the previous smoke
  budget (`vb.max_iter=300`, `mcmc_n_burn=1000`, `mcmc_n_mcmc=2000`) was too
  slow for infrastructure smoke on the n400/m60 profile.

Observed result:

- `ridge`: `n_burn=100`, `n_mcmc=200`, `thin=1`, `nd_draws=2000`,
  `synthesis_n=2000`, `posterior_metric_draws=2000`.
- `rhs_ns`: `n_burn=100`, `n_mcmc=200`, `thin=1`, `nd_draws=2000`,
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

Dry preflight the active fast smoke scaffold:

```bash
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_testing_smoke_defaults.yaml \
  --grid config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_smoke_grid.csv \
  --batch full \
  --prepare-only \
  --allow-grid-subset \
  --no-plots \
  --workers 1 \
  --run-tag qdesn-dynamic-p90-steepertrend-n400m60-rhs-tau1em5-fast-smoke-preflight-YYYYMMDD__git-SHA
```

Launch a standard smoke only after explicit compute approval:

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_testing_smoke_defaults.yaml \
  --grid config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_smoke_grid.csv \
  --batch full \
  --allow-grid-subset \
  --no-plots \
  --workers 4 \
  --tmux-session qdesn_p90_n400m60_rhs_tau1em5_smoke_YYYYMMDD \
  --run-tag qdesn-dynamic-p90-steepertrend-n400m60-rhs-tau1em5-smoke-YYYYMMDD-HHMMSS__git-SHA
```

## Gate For The Final Article-Facing Launch

Before any final 144-fit article-facing campaign:

1. Re-run the path hygiene and source-window audits.
2. Re-run prepare-only manifests for micro, smoke, and full surfaces.
3. Treat the completed active-spec fast micro-smoke as the current
   infrastructure/storage gate, not as MCMC-quality approval.
4. Decide whether standard smoke should use the fast MCMC budget, a staged
   VB-first / MCMC-subset design, or a larger MCMC budget.
5. Run the standard smoke only after that design is explicitly approved.
6. Launch the full 144-fit campaign only after explicit approval.

Do not switch Article-Q-DESN to any current scaffold output. The current
micro-smoke evidence is infrastructure/storage evidence only. Article-Q-DESN
should stay on the previous authoritative full closeout until a full 36-root /
144-fit n400/m60 run is completed and closed out.

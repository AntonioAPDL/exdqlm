# Q-DESN External-Coherent Full-Budget Confirmation v1

- generated_at: `2026-07-27 02:08:15.09097`
- package: `exdqlm 1.0.0`
- source closeout: `qdesn_tt500_mcmc_metricgap_v3_combined_closeout_20260727`
- selected atomic spec: `qdesn__laplace__0p25__tt500__rhs_ns__mcmc__exal__020293d289bcb0`
- selected root: `root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__laplace__tau_0p25__lasttt_500__qdesn_rhs_ns__profile_mgv3_16_exal_local`
- source registry SHA-256: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- launch status: `prepared_not_launched`

## Decision

Two reduced-budget candidates coherently beat the external DQLM/exDQLM
benchmark on fit RMSE, H=1000 forecast MAE, and H=1000 forecast check loss.
The tau0=3e-4 anchor already has 20,000-iteration full-budget evidence. The
tau0=1e-4 local candidate has the better screening fit RMSE and is therefore
the only remaining candidate promoted to confirmation. The mixed historical
Q-DESN metric envelope remains context rather than a blocking target.

## Confirmation Gates

- One exact root and one exact exAL atomic spec.
- External ratio at most 1.05 for each of the three metrics.
- Full-budget metric at most 1.10 times its reduced-budget screening value.
- Exact source-registry hash, all three source-file hashes, and source windows: train 8501:9000; forecast 9001:10000.
- Complete scalar/path/status artifacts and no retained `.rds`, `.rda`, or `.RData` payload.
- Chain diagnostics are retained and reported; they do not silently erase metric evidence.
- No article update is automatic.

## Remaining Lower-Quantile Work

The other 11 lower-quantile family/quantile/likelihood cells are frozen as a
cell-specific redesign handoff. No broad follow-up is launched by this stage.
The redesign excludes a global specification and the already unproductive
D=2 / tau0=3e-5 broad direction.

- selected candidate: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_external_coherent_confirmation_v1_prelaunch_20260727/selected_coherent_external_candidate.csv`
- all externally coherent screening candidates: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_external_coherent_confirmation_v1_prelaunch_20260727/eligible_coherent_external_candidates.csv`
- benchmark contract: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_external_coherent_confirmation_v1_prelaunch_20260727/external_confirmation_contract.csv`
- seed contract: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_external_coherent_confirmation_v1_prelaunch_20260727/seed_contract.csv`
- lower-quantile redesign: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_external_coherent_confirmation_v1_prelaunch_20260727/lower_quantile_cell_specific_redesign_handoff.csv`
- defaults: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_external_coherent_confirmation_v1_defaults.yaml`
- grid: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_external_coherent_confirmation_v1_grid.csv`
- target spec: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_external_coherent_confirmation_v1_target_spec_ids.csv`

# 20260314 Family-QSpec Scientific Comparison Snapshot

- generated_at: `2026-03-15 17:02:18 EDT`
- source_vb_vs_mcmc: `tools/merge_reports/20260312_family_qspec_global_cross_family_summary/tables/vb_vs_mcmc_summary.tsv`
- source_extended_vs_baseline: `tools/merge_reports/20260312_family_qspec_global_cross_family_summary/tables/pairwise_model_compare_long.tsv`

| Campaign | Family | VB vs MCMC baseline | VB vs MCMC extended | Extended vs baseline under VB | Extended vs baseline under MCMC | RHS vs ridge |
|---|---|---|---|---|---|---|
| dynamic | gausmix | VB lower RMSE (1/6 rows, mean ΔRMSE=4.603) | VB lower RMSE (6/6 rows, mean ΔRMSE=839.194) | extended lower RMSE (2/4 rows, mean ΔRMSE=-54.548) | extended lower RMSE (1/1 rows, mean ΔRMSE=-23.125) | N/A |
| dynamic | laplace | MCMC lower RMSE (6/6 rows, mean ΔRMSE=-33.734) | VB lower RMSE (6/6 rows, mean ΔRMSE=810.436) | extended lower RMSE (2/4 rows, mean ΔRMSE=-54.806) | not available | N/A |
| dynamic | normal | MCMC lower RMSE (6/6 rows, mean ΔRMSE=-19.953) | VB lower RMSE (5/6 rows, mean ΔRMSE=273.098) | extended lower RMSE (3/5 rows, mean ΔRMSE=-47.828) | extended lower RMSE (1/1 rows, mean ΔRMSE=-10.102) | N/A |
| static paper | gausmix | MCMC lower RMSE (5/6 rows, mean ΔRMSE=-0.046, runtime x455.5) | MCMC lower RMSE (4/6 rows, mean ΔRMSE=-0.190, runtime x20.0) | AL lower RMSE (3/4 rows, mean ΔRMSE=0.092) | exAL lower RMSE (1/1 rows, mean ΔRMSE=-0.480) | N/A |
| static paper | laplace | MCMC lower RMSE (5/6 rows, mean ΔRMSE=-0.087, runtime x36.6) | MCMC lower RMSE (4/6 rows, mean ΔRMSE=-0.496, runtime x15.4) | exAL lower RMSE (2/4 rows, mean ΔRMSE=-0.309) | exAL lower RMSE (3/3 rows, mean ΔRMSE=-0.856) | N/A |
| static paper | normal | MCMC lower RMSE (5/6 rows, mean ΔRMSE=-0.045, runtime x15.5) | MCMC lower RMSE (4/6 rows, mean ΔRMSE=-0.294, runtime x10.6) | AL lower RMSE (2/4 rows, mean ΔRMSE=0.049) | not available | N/A |
| static shrink | gausmix | MCMC lower RMSE (7/12 rows, mean ΔRMSE=-0.078, runtime x227.4) | MCMC lower RMSE (8/12 rows, mean ΔRMSE=-0.155, runtime x16.3) | AL lower RMSE (4/8 rows, mean ΔRMSE=0.073) | exAL lower RMSE (2/4 rows, mean ΔRMSE=-0.071) | ridge better signal RMSE; rhs lowers false positives (Δsignal=0.086, ΔFPR=-0.341) |
| static shrink | laplace | MCMC lower RMSE (6/12 rows, mean ΔRMSE=-0.005, runtime x23.2) | MCMC lower RMSE (8/12 rows, mean ΔRMSE=-0.216, runtime x10.6) | AL lower RMSE (4/8 rows, mean ΔRMSE=0.009) | exAL lower RMSE (3/3 rows, mean ΔRMSE=-0.422) | ridge better signal RMSE; rhs lowers false positives (Δsignal=0.003, ΔFPR=-0.235) |
| static shrink | normal | MCMC lower RMSE (8/12 rows, mean ΔRMSE=-0.029, runtime x16.0) | MCMC lower RMSE (8/12 rows, mean ΔRMSE=-0.085, runtime x10.1) | exAL lower RMSE (4/8 rows, mean ΔRMSE=-0.064) | exAL lower RMSE (3/3 rows, mean ΔRMSE=-0.230) | ridge better signal RMSE; rhs lowers false positives (Δsignal=0.022, ΔFPR=-0.271) |

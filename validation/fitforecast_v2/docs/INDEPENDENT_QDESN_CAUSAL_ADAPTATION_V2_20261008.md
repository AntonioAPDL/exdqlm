# Independent Q-DESN causal adaptation v2

## Scientific question

The completed sentinel campaign searched a broad static DESN/RHS surface but
did not beat exDQLM forecast MAE for the Normal, p=0.05, exAL cell. The deficit
was already present at leads 1--5 and did not increase with horizon. First-step
teacher-forcing guards passed at floating-point precision, M0 mixing was usable,
and the same Q-DESN machinery beat exDQLM for the Laplace positive control.
Another broad static topology search or a shorter forecast window is therefore
not the next experiment.

Five of six online-VB pilots improved their static counterparts. This campaign
tests whether the improvement comes from causally updating the readout
coefficients, refreshing RHS shrinkage, or refreshing the exAL gamma/sigma
block. It does not change the DESN topology, prior family, DGP, fold, forecast,
or scoring contract.

## Frozen scope

The experiment uses the three reservoir-only Normal exAL p=0.05 finalists
`3a7a6653cb244f49813c`, `23eb3c867723c85379f2`, and
`1b071df459e29d74d20f`. These are the parent's full-MCMC top three, and each
also has a completed online-VB pilot. Restricting the experiment to this
intersection preserves matched three-chain static-MCMC evidence for the exact
bridge without adding an avoidable static-MCMC campaign. It retains folds
S1--S4, 1,000-observation initial
training windows, 500-observation washout, 30-step recursive forecasts,
teacher forcing between origins, identity Q matrices, frozen fold-specific
preprocessing, and the original seeds and reservoirs. Every selection target
ends by source index 9000. Source indices 9001--10000 remain unopened.

The 24 new VB jobs cross three candidates, four folds, and two update modes:

1. `beta_only`: update beta natural parameters for every newly observed point;
   keep RHS and gamma/sigma factors fixed.
2. `beta_rhs`: update beta for every point and refresh RHS on its existing
   schedule; keep gamma/sigma fixed.

The completed parent campaign supplies hashed static and full-update
comparators. Full update changes beta, RHS, gamma, and sigma under the existing
online schedule. Thus all four modes, static, beta-only, beta-plus-RHS, and
full, can be compared without rerunning valid parent evidence.

## Gate and exact bridge

The online gate chooses the lowest median forecast MAE, then check loss and
worst-fold MAE. It passes only when the selected mode improves at least three
of four folds, improves median MAE, and keeps median check loss within two
percent of its matched static candidate.

If the gate passes, one selected candidate receives 12 exact M0 MCMC refits:
four folds crossed with offsets 50, 125, and 200 after the original training
end. Each refit appends only observations available at that origin while
retaining the original fold's preprocessing and reservoir. It uses 3,000 burn
iterations, 10,000 retained draws, and one chain because this is a bounded
mechanism bridge, not article confirmation. Forecasts cover the next 30 steps
from that origin. Results are compared with the parent static Q-DESN and
exDQLM MCMC chains at the same fold and origin.

MCMC adaptation is supported only if it improves the static Q-DESN at at least
8 of 12 origins and has a median adapted/static MAE ratio below one. Closing
the comparator gap additionally requires at least 7 of 12 origin wins and a
median adapted/exDQLM ratio below one.

## Reproducibility and closure

The campaign runs on a dedicated branch and worktree, uses CRAN exdqlm 1.1.2,
M0 for exAL MCMC, one numerical thread per model, and at most 15 idle physical
cores. Source, package, input, configuration, parent-evidence, and output
manifests are frozen. No fitted-model binaries are retained.

The parent run's original closeout manifest contained one directory row with a
blank hash. Its 16 file rows were valid. This campaign does not mutate that
completed run; it writes a supplemental recursive file-only manifest and
records the original manifest hash and defect.

No result is promoted to the article automatically. A successful bridge can
justify a separately designed fresh-DGP confirmation. A failed bridge closes
the static-screening path and retains the current article authority.

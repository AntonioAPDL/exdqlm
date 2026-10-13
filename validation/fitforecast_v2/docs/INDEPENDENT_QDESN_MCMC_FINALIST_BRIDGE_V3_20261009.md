# Independent Q-DESN exact-MCMC finalist bridge v3

## Question

The causal-adaptation v2 campaign established that updating the Normal,
exAL, p=0.05 Q-DESN readout improves forecast MAE, but its exact bridge was
run only for candidate `3a7a6653cb244f49813c`, selected by online VB. The
parent full-MCMC ordering instead favored `23eb3c867723c85379f2`, followed by
`3a7a6653cb244f49813c` and `1b071df459e29d74d20f`. Because VB rankings have
not been reliable MCMC proxies in this study, the remaining comparator gap
cannot be attributed to the model class until all three MCMC finalists receive
the same exact intervention.

## Frozen design

The completed v2 bridge for `3a7a6653cb244f49813c` is imported by hash. The
campaign adds 24 exact M0 refits: the two untested candidates crossed with
folds S1--S4 and offsets 50, 125, and 200 after the original fit endpoint.
Every job uses 3,000 burn iterations, 10,000 retained draws, one numerical
thread, the original reservoir and seeds, frozen fold preprocessing, and a
30-step recursive forecast. Observations between origins are available only
inside the internal training-selection block. Source indices 9001--10000 stay
unopened.

Each adapted candidate is compared with its own three-chain static Q-DESN
result and the same three-chain exDQLM result at the identical fold and origin.
Forecast MAE is primary and forecast check loss is secondary. Diagnostic
status is retained but does not veto finite metric improvements.

## Selection and confirmation

Candidates are ordered by paired median adapted/exDQLM MAE ratio, number of
origin wins, median check-loss ratio, worst MAE ratio, and stable candidate ID.
Closing the gap requires a median MAE ratio below one and at least 7 of 12
origin wins. Adaptation support relative to static Q-DESN requires a median
ratio below one and at least 8 of 12 wins.

If no candidate closes the gap, the campaign stops. The next scientific stage
must then examine local or rolling readout adaptation; it must not resume broad
static DESN screening automatically.

If a candidate closes the gap, chains 2 and 3 are run for all 12 cells. The
three-chain mean must satisfy the same rule. A confirmed result freezes the
protocol for a separately designed fresh-DGP confirmation; it does not alter
the article automatically.

## Operational contract

The scheduler uses at most 15 idle physical cores, one job and one numerical
thread per core. Source, package, parent evidence, configurations, status
records, evidence manifests, and decisions are hashed. No fitted-model binary
payload is retained. Article-v2, shared validation, and Overleaf are outside
this lane's write scope.

# Independent Q-DESN exact-MCMC finalist bridge v3 closeout

## Frozen result

The campaign ran from commit
`3604cb33cad4c535e78c770c4b9b28cb8b836750` under exdqlm 1.1.2. Its
ignored evidence root is:

```text
validation/fitforecast_v2/local_trackers/independent_qdesn_mcmc_finalist_bridge_v3_20261009_041939__git-3604cb33
```

All 24 newly required candidate-bridge jobs completed. The 12 exact-M0 jobs
for candidate `3a7a6653cb244f49813c` were imported from causal-adaptation v2
by hash. No implementation failure, unresolved worker, fitted-model binary,
sealed-block evaluation, confirmation job, or article change occurred.

## Scientific decision

The predeclared comparator-closing rule required a median paired forecast-MAE
ratio below one and at least 7 wins among the 12 fold-origin cells. None of the
three full-MCMC finalists passed:

| Candidate | Median adapted MAE | Adapted/static MAE ratio | Static wins | Adapted/exDQLM MAE ratio | exDQLM wins | Check-loss ratio | Decision |
|---|---:|---:|---:|---:|---:|---:|---|
| `3a7a6653cb244f49813c` | 2.3783 | 0.8325 | 8/12 | 1.0406 | 6/12 | 0.9879 | Adaptation supported; comparator gap remains |
| `23eb3c867723c85379f2` | 2.5155 | 0.9848 | 8/12 | 1.1246 | 4/12 | 0.9874 | Adaptation supported; comparator gap remains |
| `1b071df459e29d74d20f` | 2.6273 | 0.9984 | 6/12 | 1.2443 | 4/12 | 1.0270 | No stable adaptation or comparator gain |

The frozen decision is
`NO_EXACT_MCMC_FINALIST_CLOSES_GAP_DYNAMIC_READOUT_SCOPE_REQUIRED`.
Candidate `3a7a6653cb244f49813c` remains the best tested exact-MCMC adapted
candidate, but it does not qualify for confirmation or article replacement.

## Interpretation and next action

The direct MCMC experiment resolves the prior VB-to-MCMC uncertainty: the
other two full-MCMC finalists do not overtake the v2 candidate when given the
same intervention. Readout adaptation is beneficial relative to static
Q-DESN, particularly at later adaptation offsets, but its gains are not stable
across internal folds and it does not close the exDQLM MAE gap. This evidence
does not support another broad static reservoir screen or a shorter reported
forecast horizon.

The next campaign should test a narrowly scoped local or rolling readout
update inside the same internal-training protocol. It must preserve frozen
reservoir features, teacher forcing between origins, recursive 30-step paths
within origins, and the unopened source indices 9001--10000. It should first
compare a small set of causal forgetting/window controls with the static and
full-history adapted anchors, then use exact M0 only for a candidate that
passes the internal paired gate.

## Verification

- New campaign tests: 15 passed.
- Inherited causal-adaptation tests: 16 passed.
- Sentinel-mechanism regression tests: 72 passed.
- Full worker canary: passed through 3,000 burn and 10,000 retained draws.
- Production first-step recursion guards: 24/24 passed.
- Production method identifiers: 24/24 exact M0.
- New evidence manifests: 24/24 passed.
- Parent import hashes: 72/72 records passed for config, status, and evidence.
- Imported v2 bridge hashes: 12/12 records passed for config, status, and evidence.
- Closeout manifest: 89/89 hashes passed.
- Fitted-model binary payloads: 0.
- Active campaign jobs: 0.

The article and shared-validation authorities remain unchanged pending a
separately approved scientific stage and integration handoff.

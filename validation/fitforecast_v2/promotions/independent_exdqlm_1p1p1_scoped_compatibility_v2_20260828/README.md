# Independent exDQLM 1.1.1 compatibility refresh

This frozen packet is the integration handoff for the scoped exDQLM-only rerun.
It contains separate point-estimate and posterior-interval candidates. The
original pipeline failure is retained in runtime evidence and was caused only
by diagnostic postprocessing after all 36 scientific jobs had completed.

- Scientific decision: `EXDQLM_1P1P1_COMPATIBILITY_REFRESH_CONCLUSIONS_STABLE`
- Jobs: 36/36 complete; 0 rerun during recovery
- Point candidate: 18 exDQLM rows in a 72-row interface
- Interval candidate: 54 exDQLM roles in a 216-role interface
- Non-exDQLM interval roles: 162/162 invariant
- Diagnostic packet: local and ignored; hash recorded in the handoff
- Article/shared-validation/Overleaf writes: none
- Integration policy: use the complete exDQLM block; never cherry-pick gains.

## CRAN release mapping

The public software authority is CRAN `exdqlm` 1.1.1. This packet preserves
the exact locally built 1.1.1 tarball used by the campaign; it must not be
silently relabeled as the CRAN tarball. The additive compatibility packet at
`validation/fitforecast_v2/promotions/independent_exdqlm_1p1p1_cran_release_addendum_20260828/`
verifies the mapping and concludes that no scientific rerun is required solely
because the release is now available from CRAN.

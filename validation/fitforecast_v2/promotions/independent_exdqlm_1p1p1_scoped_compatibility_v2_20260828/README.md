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

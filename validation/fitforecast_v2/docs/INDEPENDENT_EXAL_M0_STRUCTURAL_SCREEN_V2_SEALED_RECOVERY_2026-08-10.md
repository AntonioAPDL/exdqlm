# Independent exAL M0 structural screen v2 sealed recovery

## Scope

This recovery closes the automated structural-screen campaign without rerunning
the 354 successful smoke, calibration, Wave 1, Wave 2, or Wave 3 jobs. It does
not launch the 21 full-budget confirmation chains and does not update the
article.

## Failure diagnosis

Wave 3 completed 72/72 jobs with finite objective metrics and no binary
payloads. Advancement failed because Wave 3 job profiles retained the selector
annotations `virtual_id` and `predicted_objective_ratio`, while Wave 2 profiles
used the canonical 37-column model-profile schema. Base `rbind()` therefore
rejected finalists drawn from both stages. No model fit or metric artifact was
invalidated.

## Repair contract

1. `qdesn_ssv2_profile_from_job()` projects every serialized profile onto the
   canonical model-profile fields. Selector annotations remain in selector
   ledgers and are not model parameters.
2. Advancement accepts ordered repeated `--prior-adaptive-root` arguments. Plan
   lookup checks the new output root, then prior roots in argument order, then
   the frozen materialization root.
3. The sealed-only recovery re-verifies all 354 completed jobs, materializes and
   verifies exactly 76 sealed jobs, runs only those jobs with 16 one-thread
   workers, and creates a 21-row confirmation manifest with
   `launch_approved = FALSE`.
4. Successful outputs remain storage-light. Routine `.rds`, `.rda`, and
   `.RData` files are forbidden.

## Frozen evidence

- Run ID: `independent_exal_m0_structural_screen_v2_capacity_repair_20260810_040208`
- Run tag: `ind-exal-m0-struct-v2-capacity-20260810_040208__git-8f1898a`
- Original Wave 2 root: `adaptive`
- Completed Wave 3 root: `adaptive_recovery_selector_v2`
- Sealed recovery root: `adaptive_recovery_selector_v3`

## Recovery command

```bash
WORKERS=16 \
  validation/fitforecast_v2/scripts/launch_resume_independent_exal_m0_structural_screen_v2_after_wave3.sh
```

The launcher requires the expected branch, a clean synchronized worktree, the
frozen run tag, and the existing Wave 2 and Wave 3 plans. Confirmation remains
blocked pending a separate scientific audit and explicit human approval.

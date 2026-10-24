# AutoDESN execution interruption — 24 October 2026

The compute environment became unavailable while work was in progress. The implementation and comparison are **not complete**. No new production posterior qualified, no new benchmark forecasts were issued, and no confirmation data were generated.

The last fully verified ordinary source/evidence checkpoint before this interruption is commit `dd9f220ee4de4a4d022cde757cc0b5235f215099`. Later local changes were not fully committed before access was lost. This recovery commit preserves uploaded binary objects and an explicit inventory; it does not claim the lost working tree was recovered.

## Last observed results

- Source and installed extension tests: 210 assertions each, zero failures/errors/warnings; installed tests also ran outside Git. The exact test and fixture hashes are in the recovery inventory. This is not a package-wide check, and the current ordinary source tree is the earlier committed version.
- Joint-proposal F1: four fresh chains at 128k retained draws completed. Maximum R-hat 1.00139, minimum ESS 3693, maximum probability MCSE .00719. Model/depth chain-frequency ranges .04068/.03612 failed the registered .03 threshold.
- Its 32k/128k comparison passed 69 fixed-design practical/Monte Carlo stability checks, but the overall certificate remains false because the individual architecture screens fail.
- The revised 16-coordinate proposal's 32k trial completed in 762.88 seconds. R-hat/ESS passed, while model/depth/lag frequency ranges .05941/.10434/.07406 failed. It is not a successful sampler repair.
- Recursive SV calibration: 89 completed cases were last seen in the log; only the first 62 verified atomic cases are preserved in archive005. No 200-case aggregate or calibration conclusion was observed.
- A full-training native AutoGP run (2000 rows, 16 particles, seed7366021, native moves only) was observed launching. No completion was observed.

The final states of the SV and AutoGP processes are **unknown**. The inaccessible environment prevented either inspecting or terminating them. No claim is made that they continue in the background.

## Recoverable uploads

Read [environment_loss_recovery_inventory.json](evidence/environment_loss_recovery_inventory.json) for exact Git blob identities and source/target observations.

Archive005 has all 61 parts, totalling 36,561,263 bytes. The complete six-archive chain had passed a local fresh restoration before uploading; however, the original archive005/006 SHA256/member manifests were not uploaded before loss. For archive005, concatenate its listed parts in order from Git objects, verify each Git blob identity and then the ZIP CRCs and safe member paths. Do not describe this as recovery of the unavailable original SHA256 manifest.

Archive006 has only parts001–320 of343 in this recovery inventory. Its complete local size was205,232,020 bytes. It is **incomplete** and is not a recoverable complete ZIP; the missing suffix includes the central directory. Unrecorded blobs possibly uploaded by the interrupted batch are excluded. The existing normal restore-chain tool only sees committed original manifests through archive004; it will not silently certify these recovery uploads.

Archive005 contains collected numerical/source checkpoints, including the small-target coordinate-kernel reference, canonical proposal-training sources and portable-test observations. Its archived member set is not the complete lost working tree.

## Remaining work

Restore access to the former environment if possible; check both process states, retrieve missing manifests/files and verify all identities before resuming. Otherwise recover the fully uploaded archives and rebuild inputs from their frozen sources, explicitly documenting anything unavailable.

Full-bank architecture exploration, two qualified successive budgets, chronological fold reconstruction/family selection, independent full-size AutoGP qualification, SV calibration/production/filter qualification, predictive Monte Carlo sensitivity, the complete rolling-origin comparison and independent confirmations/stress cases remain required.

The PDF in this branch is an earlier **execution checkpoint** report, not a final completed scientific comparison. A newer local nine-page checkpoint PDF was rendered and inspected but was not uploaded before loss; its hash is recorded in the inventory. No final updated PDF can be supplied from the unavailable environment.

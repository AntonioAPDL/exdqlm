# PLAN: QDESN Validation Phase 3 Family-B Screen (2026-03-31)

Date: 2026-03-31  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Purpose

Run the next repair wave as a broad but disciplined Family-B screen that:

1. explores genuinely new shared-core candidates;
2. avoids rerunning candidate families already rejected;
3. keeps the fixed closeout micro-pilot harness unchanged;
4. advances only the strongest candidates to more expensive stages;
5. leaves a clean log and artifact trail for review tomorrow.

This is the first broad search after:

- the bridge family was rejected;
- diagonal conditioning was shown to be effectively inert;
- QR whitening was shown to improve geometry but not close the canary by itself.

## 2) What We Are Not Retesting

These are explicitly out of scope for this screen:

- standalone `gamma_sigma_gamma` bridge reruns
- standalone diagonal conditioning
- standalone QR-whitening conditioning
- the old `X10` / `X3` / `X8` promotion set
- chain-length inflation as the main repair lever

Those ideas are already documented and should not consume more screening compute unless a later winner needs them as supporting ingredients.

## 3) Family-B Hypothesis

The next broad screen is built around the strongest remaining untested family:

- reparameterized shared-core updates with `use_log_sigma = TRUE`

Why this family:

- it is new relative to all completed repair waves;
- it targets the shared `gamma/sigma` core directly;
- it gives us a real sigma reparameterization without inventing a risky new joint target overnight;
- it can be combined with QR support as a secondary helper rather than treating conditioning as the main idea.

## 4) Candidate Design

The schedule uses two batches.

### Batch B0: unconditioned transformed-sigma candidates

Purpose:

- isolate whether transformed sigma alone changes the hard canary enough to matter

Profiles:

| profile | main idea | why included |
|---|---|---|
| `R7_logsigma_base` | transformed sigma only | clean family baseline |
| `R8_logsigma_gamma_focus` | transformed sigma + gamma-focused extra pass | targets the shared low-ESS / high-Geweke pain point |
| `R10_logsigma_bridge` | transformed sigma + bridge order | checks whether the old bridge needed sigma reparameterization to become viable |
| `R12_logsigma_sigma_focus` | transformed sigma + sigma-focused sharpening | directly targets the half-drift cluster |

### Batch B1: QR-supported transformed-sigma candidates

Purpose:

- test whether geometry cleanup becomes useful only after sigma is reparameterized

Profiles:

| profile | main idea | why included |
|---|---|---|
| `R9_logsigma_gamma_focus_qr` | gamma-focused transformed sigma + QR | best candidate for shared-core plus geometry support |
| `R11_logsigma_bridge_qr` | bridge + transformed sigma + QR | checks if the bridge needed both levers together |
| `R13_logsigma_sigma_focus_qr` | sigma-focused transformed sigma + QR | strongest half-drift-oriented geometry-assisted probe |
| `R14_logsigma_bridge_pass1_qr` | transformed sigma + bridge + extra pass + QR | high-ambition edge candidate, included once to test the upper envelope without turning it into a default guess |

## 5) Staging Strategy

The schedule is intentionally broad at the cheap stage and narrow at the expensive stages.

### Stage S1: hard-canary screen

Scope:

- anchor + all 8 Family-B candidates
- 1 root only:
  `dlm_constV_bigW @ tau=0.05 exal ridge`

Purpose:

- reject weak candidates cheaply
- compare transformed-sigma variants apples-to-apples

Advance rule:

- keep only the best `3` candidates that satisfy:
  - `ESS` not materially worse than anchor
  - `Geweke` improves meaningfully
  - `half_drift` does not blow up beyond the stage ceiling
  - runtime remains moderate

### Stage S2: severe quartet confirmation

Scope:

- anchor + top `3` canary survivors
- the 4 severe `all_four` roots

Purpose:

- test whether canary wins generalize across the real severe cluster

Advance rule:

- keep only the best `2` candidates that reduce the severe fail burden at acceptable runtime

### Stage S3: full fixed 6-root harness

Scope:

- anchor + top `2` quartet survivors
- the full fixed 6-root micro-pilot harness

Purpose:

- identify whether any Family-B candidate is strong enough to justify a broader closeout restart

## 6) Resource Plan

Server capacity:

- `64` CPU cores available

Execution strategy:

- keep profile execution sequential at the supervisor level for robustness
- use `campaign_workers = 4` inside each profile campaign
- keep `threads_per_worker = 1`
- keep plots off
- keep per-profile timeout protection on

Why this is the right balance:

- it uses parallelism where the harness is already proven stable:
  root-level campaign work
- it avoids reintroducing the earlier orchestration failure mode from uncontrolled profile-level parallelism
- it still lets the expensive quartet/full-six stages use multiple workers efficiently

## 7) Logging and Artifact Standards

Every stage will emit:

- a stage-specific screen manifest
- a stage log
- a stage candidate-selection table
- a stage MCMC-config summary table
- stage status JSON
- overall runner state JSON

The telemetry is expanded so that tomorrow’s review can answer, for every candidate:

- did it use transformed sigma?
- what `core_update_mode` ran?
- how many extra core passes were used?
- what were `width_gamma` and `width_sigma`?
- was QR conditioning active?
- how much did conditioning change the working condition number?

## 8) Success Conditions

This screen is successful if it gives us one of these outcomes:

1. a clear Family-B winner that reaches the full 6-root harness cleanly;
2. a narrowed subset of survivors with a clear best direction for the next patch;
3. a clean rejection of the transformed-sigma family, with enough evidence to justify moving to a deeper blocked/reparameterized redesign.

## 9) Main Files

Plan and tracker:

- `docs/TRACK__qdesn_validation_repair_20260331.md`
- `docs/PLAN__qdesn_validation_phase3_20260331.md`
- `docs/PLAN__qdesn_validation_phase3_family_b_screen_20260331.md`

Automation:

- `scripts/run_qdesn_validation_phase3_family_b_screen.R`
- `config/validation/qdesn_validation_phase3_family_b_screen_manifest.yaml`

## 10) Bottom-Line Recommendation

This is the right next run.

It is broad enough to cover the most plausible remaining transformed-sigma combinations, disciplined enough to avoid retesting rejected families, and efficient enough to stop weak ideas at the canary before they consume quartet/full-six compute.

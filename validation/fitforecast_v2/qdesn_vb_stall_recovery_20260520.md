# Q-DESN VB Stall Recovery Protocol

Date: 2026-05-20

## Situation

The shared fit+forecast validation workflow is implemented on
`validation/shared-fitforecast-v2-1.0.0` at commit `e4e6dc0`, but the full Q-DESN
VB compute stage did not complete.

The original broad Q-DESN VB run partially completed 24 `vb_exal` fits, then
entered a CPU-active/no-output state during the subsequent VB fits. A targeted
recovery launched on 2026-05-19 reproduced the same silent no-output pattern in:

- 4-worker `normal + vb_exal` recovery.
- 1-worker controlled `vb_al` recovery.

TT500 and TT5000 remained blocked, as intended by the launch gates.

## Do Not Consume

The following run tags are diagnostic or partial only and must not be consumed as
final article-facing validation output:

- `qdesn-dynamic-fitforecast-v2-vb-full-20260517-022453__git-e4e6dc0`
- `qdesn-dynamic-fitforecast-v2-vb-resume-exal-normal-20260519-182120__git-e4e6dc0`
- `qdesn-dynamic-fitforecast-v2-vb-resume-al-controlled-20260519-182120__git-e4e6dc0`

## Evidence

Primary diagnostic bundle:

`reports/shared_fitforecast_v2_orchestration/shared-fitforecast-v3-primary-vb-tt500-20260517-022304__git-e4e6dc0/diagnostics/qdesn_worker_audit_complete_20260519_180325`

Final pre-stop recovery diagnostic bundle:

`reports/shared_fitforecast_v2_orchestration/shared-fitforecast-v3-primary-vb-tt500-20260517-022304__git-e4e6dc0/diagnostics/qdesn_recovery_final_pre_stop_20260520_032724`

## Instrumentation Added

The validation wrapper now writes per-fit sentinel/debug files before invoking
the child ESN pipeline:

- `fits/<method>_<family>/manifest/fit_status.txt`
- `fits/<method>_<family>/logs/fit_debug_events.csv`
- `fits/<method>_<family>/logs/pipeline_child_live.log`

The child R process can now stream stdout/stderr directly to
`pipeline_child_live.log` through `cfg$validation$stream_child_stdout = TRUE`.
This prevents long validation fits from becoming invisible until process exit.

Optional per-fit timeout is supported through:

- `cfg$validation$timeout_seconds`
- `cfg$validation$timeout_kill_after_seconds`

The production defaults enable live child logging but do not impose a timeout.
Diagnostic relaunches may use a timeout to classify a suspected stall without
waiting indefinitely.

## Safe Next Step

Run one foreground or one-worker diagnostic Q-DESN VB spec with live child logs
and a bounded timeout. Only after that spec either completes or produces an
actionable live log should the missing Q-DESN VB grid be relaunched.

Full validation launch remains blocked until Q-DESN VB produces a clean completed
campaign manifest and a valid shared interface table.

## Diagnostic Proof Run

Two one-root bounded probes were launched on 2026-05-20 with live child logs and
an 1800 second per-fit timeout:

- `qdesn-vb-stallprobe-exal-normal-20260520-033314__git-e4e6dc0`
- `qdesn-vb-stallprobe-al-gausmix-20260520-033314__git-e4e6dc0`

Both probes reached the LDVB loop and emitted iteration-25 progress lines in
`pipeline_child_live.log`. This confirms that the earlier no-output interval was
not a confirmed deadlock; it was a CPU-active LDVB phase with insufficient live
telemetry.

The probes were then stopped manually after the progress evidence was captured so
the real orchestrator preflight would not be blocked by diagnostic sessions.

The probes are diagnostic only and must not be consumed as final validation
outputs. Their evidence roots are:

- `results/qdesn_mcmc_validation/dynamic_fitforecast_v2_validation/qdesn-vb-stallprobe-exal-normal-20260520-033314__git-e4e6dc0`
- `results/qdesn_mcmc_validation/dynamic_fitforecast_v2_validation/qdesn-vb-stallprobe-al-gausmix-20260520-033314__git-e4e6dc0`

Follow-up code changes make VB progress cadence explicit through
`progress_every`, set the current Q-DESN validation defaults to
`progress_every: 50`, and write child stdout/stderr live for every long-running
validation fit. Production defaults remain timeout-free; diagnostic launches can
opt into `--fit-timeout-seconds`.

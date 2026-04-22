# QDESN tau050 Stop Point and 0.4.0 Sync Pivot

Date: 2026-04-21

## Purpose

This report freezes the current QDESN validation-study branch at the point
where the tau050 failed-run recovery work is complete enough to stop, document,
and pivot into a controlled `0.4.0` package-sync phase before changing the
dynamic datasets.

## Why We Are Stopping Here

The tau050 validation program reached a stable stopping point:

- the failed-run recovery program closed out with the original hard numerical
  crash surface recovered
- the recovered 144-case tau050 comparison pack was rebuilt successfully
- the representative study-facing pack was generated and documented
- the next scientific step is a dynamic-dataset reset, not another tau050
  repair wave

That makes this the right time to freeze the current branch and align it with
the authoritative `0.4.0` package line before any dataset change introduces a
second moving target.

## Authoritative References For The Sync

| Role | Branch / SHA | Meaning |
|---|---|---|
| Upstream `0.4.0` | `origin/cransub/0.4.0` at `dc032e6` | authoritative package naming, public API shape, docs direction, and VB trace framework |
| Proven validation sync | `validation/rerun-after-0.4.0-sync-0p4p0-integration` at `5bdc943` | already-resolved sync decisions between validation work and `0.4.0` |
| Proven package backport | `integration/0.4.0-validation-warmup-backport` at `54fb296` | reusable validation-derived warmup and numerical-stability improvements already ported onto `0.4.0` |
| Current QDESN stop-point base | `feature/qdesn-mcmc-alternative-0p4p0-integration` at `231a683` | starting point for the controlled carry-forward in this repo |

## What Must Be Preserved From The Validation/QDESN Side

The `0.4.0` sync is not a blind rename exercise. The validation/QDESN branch
contains numerical-recovery work that must survive the sync:

- dynamic MCMC warmup and freeze controls
- dynamic VB and LDVB stabilization controls
- static warm-start and warmup plumbing
- shared numerical hardening already used during tau050 recovery
- newer QDESN-side precision-rescue logic and diagnostics
- auditability improvements that make the recovery controls visible in outputs

## Sync Principle

The branch should follow upstream `0.4.0` package naming and public API shape,
while preserving the stronger validation/QDESN numerical-recovery behavior
behind that interface.

In practice that means:

- upstream `0.4.0` naming wins
- reusable validation/backport fixes from `54fb296` are restored
- later QDESN-only recovery improvements stay where they are stronger
- dataset changes remain explicitly out of scope until after sync verification

## Immediate Next Step

Complete the controlled `0.4.0` carry-forward on this branch, verify it, and
leave a clean implementation record plus a carry-forward checklist that can be
used when the validation-study `0.4.0` repo is updated again.

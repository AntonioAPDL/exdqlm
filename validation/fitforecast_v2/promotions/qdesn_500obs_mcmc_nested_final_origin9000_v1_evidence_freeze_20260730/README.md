# Q-DESN Nested Final-Origin Evidence Freeze

## Scope

This bundle freezes the completed nested final-origin MCMC confirmation at
validation commit `a02b93bee8cb52c273d989f455f8e7e3fd962f69`. It adds policy
metadata only. It does not modify the authoritative closeout, launch models,
change the article, or authorize a new calibration campaign.

## Frozen Evidence

- Closeout:
  `qdesn_500obs_mcmc_nested_final_origin9000_v1_closeout_20260730`
- Consumable scientific run:
  `qdesn-500obs-mcmc-nested-final-o9000-v1-full-20260730__git-bd4da62`
- Scientific role: frozen negative confirmation evidence.
- Decision: `NO_CONFIRMED_COHERENT_ARTICLE_REFRESH`.
- Coherent promotion cells: 0/4.
- Article-refresh rows: 0.
- Source-registry SHA-256:
  `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`.

The valid run is consumable only as evidence that the four selected candidates
failed confirmation. It is not a source of replacement article metrics.

## Article Authority

The current article numbers remain those in the immutable promotion
`qdesn_dqlm_500obs_mcmc_metric_envelope_20260727`. Its 36-row article
envelope supplies 108 displayed values over four model variants, three
simulation families, three quantile levels, and three metrics. The associated
coherent exQ-DESN confirmation remains supporting evidence and does not replace
an envelope minimum.

This freeze is the current authority overlay for article consumption:

- numerical authority: the 2026-07-27 metric envelope;
- latest evaluated evidence: the valid 2026-07-30 final-origin run;
- latest scientific decision: no coherent article refresh;
- article action: keep all current numerical values unchanged.

The three article-authority inputs and their SHA-256 hashes are pinned in
`frozen_evidence_ledger.csv`. Article builders must verify both the numerical
authority and this no-change overlay. They must not infer a numerical refresh
from the existence of later run directories.

## Permanent Refusals

The full tag
`qdesn-500obs-mcmc-nested-final-o9000-v1-full-20260730__git-6582f87`
is permanently non-consumable because its effective posterior predictive draw
budget was 100 rather than the frozen requirement of 200.

Prepare-only and smoke tags are workflow evidence, not scientific evidence.
Their metrics must never enter calibration, comparison, or article tables.

## Origin Policy

Source origin 9000, with training indices 8501--9000 and forecast indices
9001--10000, is exposed. It can be inspected as frozen evidence or used in
explicitly declared development diagnostics, but it cannot be represented
again as an untouched confirmation origin.

## Integrity

`frozen_evidence_ledger.csv` pins the SHA-256 hashes of the authoritative
numerical promotion, coherent confirmation, final-origin closeout, and
invalid-run registry. `run_disposition.csv` and `origin_disposition.csv`
provide machine-readable consumption rules. The JSON manifest pins this
freeze bundle and its policy.

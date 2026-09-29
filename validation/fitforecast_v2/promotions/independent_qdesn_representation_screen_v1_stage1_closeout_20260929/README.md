# Independent Q-DESN representation screen v1: Stage 1 closeout

Status: `STAGE1_COMPLETE_SUPERSEDED_BY_CELLWISE_REFINEMENT_V2`.

The exact Normal-ridge stage completed 960/960 scheduler jobs and
11,520 internal fold-by-scale fits with no worker failures, nonfinite
metrics, projection violations, zero-variance readout columns, or fitted
model binaries. The pipeline stopped after Stage 1 because the inherited
collector keyed valid multirow results too coarsely. That orchestration
defect does not invalidate the ridge evidence.

The remaining 816 jobs from the original stage graph were deliberately
not resumed. Historical audits show weak and sometimes negative transfer
from family-level Normal/VB ranks to cell-specific MCMC performance.
The successor campaign therefore imports these frozen ridge results, adds
targeted family-specific structures, establishes fresh cellwise quantile
evidence, and preserves diverse candidates for direct MCMC.

No article, shared-validation, integration, or Overleaf write is authorized
by this closeout.

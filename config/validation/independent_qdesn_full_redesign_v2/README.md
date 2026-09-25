# Independent Q-DESN full redesign v2

This directory freezes the clean independent single-quantile validation
protocol. It tunes Q-DESN AL-RHS and exQ-DESN exAL-RHS by family, quantile,
and likelihood while retaining DQLM and exDQLM as fixed state-space
comparators. Runtime materializations and fitted objects are intentionally
excluded from Git.

The controller is resumable and stage gated. The held-out 9001:10000 block is
not accessible until Normal-RHS and quantile-VB selection have frozen the
cell-specific candidates. Article and Overleaf publication are outside this
lane.

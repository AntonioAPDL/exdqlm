#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  for (pkg in c("digest", "jsonlite")) {
    if (!requireNamespace(pkg, quietly = TRUE)) stop("Missing package: ", pkg)
  }
})
repo <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                      winslash = "/", mustWork = TRUE)
source(file.path(repo, "validation/fitforecast_v2/R/qdesn_canonical_gap_mcmc_v2.R"))
stub <- file.path(repo, "config/validation", qdesn_cgcv2_stage)
targets <- qdesn_ssv2_read_csv(paste0(stub, "_target_cells.csv"))
history_path <- file.path(repo, "config/validation",
  "qdesn_dynamic_fitforecast_v2_500obs_forecast_gap_adaptive_mcmc_v1_history_signature_ledger.csv")
history <- qdesn_ssv2_read_csv(history_path)

# Deliberately structured, broad arms. They vary memory, depth, capacity,
# nonlinearity, spectral persistence, sparsity, and RHS shrinkage jointly.
arms <- data.frame(
  D = c(1,1,2,2,2,3,3,3,3,4,4,4,2,3,4,1),
  base_n = c(40,90,45,80,120,35,60,90,110,35,55,75,160,100,110,200),
  m = c(12,45,20,60,110,25,55,90,140,30,65,120,150,150,150,150),
  alpha = c(.08,.25,.42,.58,.72,.38,.64,.82,.94,.48,.74,.90,.985,.995,.999,.88),
  rho = c(.35,.65,.78,.90,.96,.84,.93,.975,.992,.88,.965,.995,.998,.985,.999,.94),
  tau0 = c(1e-8,3e-8,1e-7,3e-7,1e-6,3e-6,1e-5,3e-5,1e-4,3e-4,1e-8,1e-6,1e-7,1e-5,3e-6,3e-5),
  readout_y_lags = c(1,2,2,3,4,2,4,6,8,3,6,10,12,10,8,12),
  reservoir_lags = c(0,0,1,1,0,1,1,0,1,1,0,1,0,1,0,0),
  stringsAsFactors = FALSE
)

make_profile <- function(target, arm, index) {
  D <- arm$D[[1L]]
  nvec <- pmin(300L, as.integer(round(arm$base_n[[1L]] * (1 + .18 * (0:(D-1L))))))
  nt <- if (D > 1L) nvec[-1L] else integer()
  alpha <- pmin(.9995, arm$alpha[[1L]] + (0:(D-1L)) * .002)
  rho <- pmin(.9995, arm$rho[[1L]] + (0:(D-1L)) * .001)
  piw <- pmax(.02, pmin(.35, 12 / nvec))
  pii <- pmax(.02, pmin(.20, 6 / nvec))
  row <- data.frame(
    D=D, n=paste(nvec, collapse=";"), n_tilde=paste(nt, collapse=";"),
    m=arm$m, alpha=paste(format(alpha, digits=12, scientific=FALSE), collapse=";"),
    rho=paste(format(rho, digits=12, scientific=FALSE), collapse=";"),
    pi_w=paste(format(piw, digits=12), collapse=";"),
    pi_in=paste(format(pii, digits=12), collapse=";"), rhs_tau0=arm$tau0,
    readout_y_lags=arm$readout_y_lags, reservoir_lags=arm$reservoir_lags,
    washout=max(300L, 3L * arm$m), layer_shape="expanding",
    alpha_pattern="weakly_increasing", rho_pattern="weakly_increasing",
    expected_degree=12, total_states=sum(nvec), max_alpha=max(alpha),
    min_alpha=min(alpha), mean_alpha=mean(alpha), max_rho=max(rho),
    min_rho=min(rho), mean_rho=mean(rho),
    design_role="canonical_direct_novel_screen", selection_arm=sprintf("arm_%02d", index),
    target_cell_id=target$target_cell_id, family=target$family, tau=target$tau,
    priority=target$tier, objective_metric=target$objective_metric,
    current_value=target$objective_current_value,
    comparator_value=target$objective_comparator_value,
    parent_anchor_id=sub("[.]json$", "", basename(target$parent_request_path)),
    likelihood_target=target$likelihood_target, target_metrics=target$target_metrics,
    stringsAsFactors=FALSE
  )
  row$effective_readout_dimension <- qdesn_ssv2_effective_readout_dimension(
    row$n, row$n_tilde, row$reservoir_lags, row$readout_y_lags)
  row$profile_signature <- qdesn_cgcv2_signature(row)
  # Deterministically move a colliding arm without changing its scientific regime.
  tries <- 0L
  while (row$profile_signature %in% history$profile_signature && tries < 50L) {
    tries <- tries + 1L
    row$rhs_tau0 <- row$rhs_tau0 * (1 + tries / 1000)
    row$profile_signature <- qdesn_cgcv2_signature(row)
  }
  if (row$profile_signature %in% history$profile_signature) stop("Unable to create novel profile")
  hash <- substr(digest::digest(paste(target$target_cell_id, row$profile_signature),
                                algo="sha256", serialize=FALSE), 1, 10)
  row$candidate_id <- sprintf("cgcv2_%s_%02d_%s", target$target_cell_id, index, hash)
  row$screening_profile_id <- row$candidate_id
  row
}

profiles <- do.call(rbind, lapply(seq_len(nrow(targets)), function(i) {
  do.call(rbind, lapply(seq_len(nrow(arms)), function(j) make_profile(targets[i,,drop=FALSE], arms[j,,drop=FALSE], j)))
}))
if (nrow(profiles) != 64L || any(table(profiles$target_cell_id) != 16L) ||
    any(profiles$effective_readout_dimension > 900L) ||
    any(profiles$profile_signature %in% history$profile_signature) ||
    anyDuplicated(paste(profiles$target_cell_id, profiles$profile_signature))) {
  stop("Canonical-gap candidate design contract failed.")
}
qdesn_ssv2_write_csv(profiles, paste0(stub, "_candidate_profiles.csv"))
audit <- data.frame(
  target_cell_id=targets$target_cell_id, candidates=16L,
  history_signatures=nrow(history), collisions=0L,
  min_alpha=vapply(split(profiles, profiles$target_cell_id), function(x) min(x$min_alpha), numeric(1)),
  max_alpha=vapply(split(profiles, profiles$target_cell_id), function(x) max(x$max_alpha), numeric(1)),
  max_dimension=vapply(split(profiles, profiles$target_cell_id), function(x) max(x$effective_readout_dimension), numeric(1)),
  stringsAsFactors=FALSE
)
qdesn_ssv2_write_csv(audit, paste0(stub, "_novelty_audit.csv"))
cat(sprintf("DESIGN_OK profiles=%d history=%d\n", nrow(profiles), nrow(history)))

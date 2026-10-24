# Optional, restartable Monte Carlo sensitivity on the same qualified posterior.
# This never changes an inference gate, model weight, posterior draw or prior.
source("validation/autodesn/nonlinear_heteroscedastic/helpers.R")
options <- rhs_options(); cfg <- rhs_configuration(options)
if (cfg$mode != "full") stop("Sensitivity is defined only for the frozen full NHS1 experiment")
directory <- file.path(options$out, options$method)
status <- jsonlite::fromJSON(file.path(directory, "status.json"))
if (!isTRUE(status$complete) || !isTRUE(status$qualified) || isTRUE(status$reused))
  stop("A fresh, complete, qualified posterior is required.")
cp <- readRDS(file.path(directory, "posterior_checkpoint.rds"))
stopifnot(isTRUE(cp$qualified), nrow(cp$draws) == 384L,
          identical(cp$comparison_contract_id, status$contract_id))
provenance <- jsonlite::fromJSON(file.path(directory, "provenance.json"))
for (i in seq_len(nrow(provenance$production_source))) {
  p <- provenance$production_source[i, ]
  if (!identical(digest::digest(file = p$path, algo = "sha256"), p$sha256))
    stop("Production source changed since fitting; use the fitting source revision for sensitivity")
}
out <- file.path(directory, "sensitivity"); dir.create(out, showWarnings = FALSE)
source_paths <- c("validation/autodesn/nonlinear_heteroscedastic/sensitivity.R","validation/autodesn/nonlinear_heteroscedastic/helpers.R","validation/autodesn/rhs_comparison/sensitivity.R",
                  "validation/autodesn/c1_comparison/helpers.R",
                  "validation/autodesn/heteroscedastic/rolling/helpers.R")
id <- rhs_guard(out, list(posterior_contract = cp$comparison_contract_id,
  script_sha256 = vapply(source_paths, function(p) digest::digest(file = p, algo = "sha256"), ""),
  origins = c(2500L, 2735L, 2970L), outer = c(192L, 384L), inner = c(4L, 8L, 16L, 32L)))
y <- c1_data()$y; origins <- c(2500L, 2735L, 2970L); started <- proc.time()[3]
states <- hr_origin_states(cp, y[seq_len(max(origins))], origins)
state_seconds <- unname(proc.time()[3] - started)
rows <- list(); seconds <- 0
for (origin in origins) for (N in c(192L, 384L)) for (K in c(4L, 8L, 16L, 32L)) {
  path <- file.path(out, sprintf("origin_%04d_N%d_K%d.rds", origin, N, K))
  if (file.exists(path)) {
    record <- readRDS(path); stopifnot(identical(record$contract_id, id))
  } else {
    primary <- cp; primary$draws <- cp$draws[seq_len(N), , drop = FALSE]
    primary$beta <- cp$beta[seq_len(N)]; primary$source_ids <- cp$source_ids[seq_len(N)]
    i <- match(origin, origins); begun <- proc.time()[3]
    fc <- hr_auto(primary, states$states[[i]], states$history_scaled[seq_len(origin)],
      cfg$H, K, c1_noise(cfg$innovation_seed, origin, K, N, cfg$H))
    elapsed <- unname(proc.time()[3] - begun)
    score <- c1_desn_score(fc, y[origin + seq_len(cfg$H)], origin)
    score$model <- paste("AutoDESN", if (options$method == "rhs") "RHS" else "ridge")
    score$outer_draws <- N; score$inner_paths <- K
    record <- list(contract_id = id, score = score, forecast_seconds = elapsed)
    rhs_save(record, path)
  }
  rows[[length(rows) + 1L]] <- record$score; seconds <- seconds + record$forecast_seconds
  cat(options$method, "sensitivity origin", origin, "N", N, "K", K, "complete\n"); flush.console()
}
write.csv(do.call(rbind, rows), file.path(directory, "mc_sensitivity.csv"), row.names = FALSE)
rhs_json(list(complete = TRUE, reused = FALSE, qualified_posterior = TRUE,
  settings = 24L, score_pairs = 720L, state_seconds_this_invocation = state_seconds,
  forecast_compute_seconds_sum = seconds, contract_id = id,
  interpretation = "Changes in Monte Carlo estimates with nested draw/path counts; these are not new fits or independent replications."),
  file.path(out, "status.json"))

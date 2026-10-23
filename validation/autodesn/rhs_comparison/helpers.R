# Sourced from the repository root. Existing C1 adapters remain unchanged.
source("validation/autodesn/c1_comparison/helpers.R")
rhs_compare_root <- "validation/autodesn/rhs_comparison"

rhs_options <- function(args = commandArgs(trailingOnly = TRUE)) {
  out <- list(stage = "all", method = "rhs", mode = "full", out = NULL,
              bank_dir = NULL, backend = "auto", n_burn = NULL, n_mcmc = NULL)
  i <- 1L
  while (i <= length(args)) {
    if (args[i] == "--smoke") { out$mode <- "smoke"; i <- i + 1L; next }
    key <- gsub("-", "_", sub("^--", "", args[i]))
    if (!startsWith(args[i], "--") || !key %in% names(out) || i == length(args))
      stop("Unknown or incomplete option: ", args[i])
    out[[key]] <- args[i + 1L]; i <- i + 2L
  }
  out$stage <- match.arg(out$stage, c("build", "fit", "forecast", "all"))
  out$method <- match.arg(out$method, c("ridge", "rhs"))
  out$mode <- match.arg(out$mode, c("full", "pilot", "smoke"))
  out$backend <- match.arg(out$backend, c("auto", "R", "cpp"))
  if (out$mode != "pilot" && (!is.null(out$n_burn) || !is.null(out$n_mcmc)))
    stop("Iteration overrides are permitted only in explicitly unqualified pilot mode")
  if (is.null(out$out)) out$out <- file.path(rhs_compare_root, "artifacts", out$mode)
  if (is.null(out$bank_dir)) out$bank_dir <- if (out$mode == "pilot")
    file.path(rhs_compare_root, "artifacts", "full", "bank") else file.path(out$out, "bank")
  out
}

rhs_configuration <- function(options) {
  cfg <- jsonlite::fromJSON(file.path(rhs_compare_root, "configuration.json"))
  for (name in names(cfg$input_sha256)) {
    path <- file.path(c1_root, "input", name)
    if (!identical(digest::digest(file = path, algo = "sha256"), cfg$input_sha256[[name]]))
      stop("Frozen C1 input hash mismatch: ", name)
  }
  cfg$mode <- options$mode
  if (options$mode == "smoke") {
    cfg$washout <- 30L; cfg$fit_start <- 31L; cfg$fit_end <- 110L; cfg$n_train <- 80L
    cfg$test_start <- 111L; cfg$test_end <- 120L; cfg$n_test <- 10L
    cfg$first_origin <- 110L; cfg$last_origin <- 115L; cfg$origins <- 6L; cfg$H <- 5L
    cfg$outer_draws <- 12L; cfg$inner_paths <- 2L; cfg$checkpoint_draws <- 24L
    cfg$feature_workers <- 1L; cfg$origin_workers <- 1L
    cfg$attempts <- as.data.frame(cfg$smoke[c("n_burn", "n_mcmc")])
    cfg$chains <- cfg$smoke$chains
  } else if (options$mode == "pilot") {
    cfg$attempts <- as.data.frame(cfg$pilot[c("n_burn", "n_mcmc")])
    cfg$chains <- cfg$pilot$chains
    for (key in c("n_burn", "n_mcmc")) if (!is.null(options[[key]])) {
      value <- as.integer(options[[key]])
      if (!is.finite(value) || value < if (key == "n_burn") 0L else 2L) stop("Invalid pilot iterations")
      cfg$attempts[[key]] <- value
    }
  }
  cfg
}

rhs_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(path, ".partial")
  jsonlite::write_json(x, tmp, auto_unbox = TRUE, pretty = TRUE, digits = 16, na = "null")
  if (!file.rename(tmp, path)) stop("Atomic JSON save failed: ", path)
}

rhs_save <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(path, ".partial")
  saveRDS(x, tmp, compress = FALSE)
  if (file.info(tmp)$size <= 0 || !file.rename(tmp, path)) stop("Atomic checkpoint save failed: ", path)
}

rhs_source_manifest <- function() {
  paths <- sort(c(list.files("R", pattern = "\\.R$", full.names = TRUE),
                  list.files("src", pattern = "\\.(cpp|h)$", full.names = TRUE)))
  data.frame(path = paths, sha256 = vapply(paths, function(p) digest::digest(file = p, algo = "sha256"), ""))
}

rhs_guard <- function(directory, contract) {
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  id <- digest::digest(contract, algo = "sha256")
  file <- file.path(directory, "contract.rds")
  if (file.exists(file)) {
    old <- readRDS(file)
    if (!identical(old$id, id)) stop("Checkpoint contract changed; use a new output directory: ", directory)
  } else rhs_save(list(id = id, contract = contract), file)
  id
}

rhs_specifications <- function(cfg) {
  if (cfg$mode != "smoke") {
    recovered <- readRDS(file.path(c1_root, "input/specifications.rds"))
    return(list(specs = recovered[["3_specifications"]], grid = recovered[["2_grid"]]))
  }
  specs <- autodesn_candidates(D = 1:2, n = 6, m = 2, alpha = .65, rho = .4,
    seed = 11, washout = cfg$washout, act_k = "identity")
  specs <- lapply(specs, function(s) { s$n_tilde <- s$n[seq_len(s$D - 1L)]; s })
  names(specs) <- paste0("smoke_", seq_along(specs))
  list(specs = specs, grid = data.frame(candidate = names(specs),
    D = vapply(specs, `[[`, 0L, "D"), widths = vapply(specs, function(s) paste(s$n, collapse = "/"), "")))
}

rhs_build_bank <- function(cfg, directory) {
  # The bank contract intentionally excludes the readout prior and its sampler.
  # A bank may therefore be shared by ridge, RHS and a training-only pilot.
  source_paths <- c("R/autodesn.R", "R/qdesn_vb.R", "R/qdesn_normal.R",
                    "R/qdesn_design_only.R", "R/readout_transform.R")
  sc <- rhs_specifications(cfg)
  contract <- list(input_sha256 = cfg$input_sha256, washout = cfg$washout,
    fit_start = cfg$fit_start, fit_end = cfg$fit_end, tolerance = cfg$washout_tolerance,
    specifications = sc$specs, builder_sha256 = vapply(source_paths,
      function(p) digest::digest(file = p, algo = "sha256"), ""))
  id <- rhs_guard(directory, contract)
  path <- file.path(directory, "bank.rds")
  started <- proc.time()[3]
  if (file.exists(path)) {
    bank <- readRDS(path)
    stopifnot(identical(attr(bank, "comparison_bank_id"), id))
    return(list(bank = bank, id = id, reused = TRUE,
                load_seconds = unname(proc.time()[3] - started)))
  }
  y <- c1_data()$y[seq_len(cfg$fit_end)]
  cache <- file.path(directory, "parts"); dir.create(cache, showWarnings = FALSE)
  make_one <- function(j) {
    file <- file.path(cache, sprintf("part_%04d.rds", j))
    if (file.exists(file)) return(NULL)
    begun <- proc.time()[3]
    one <- autodesn_build_bank(y, sc$specs[j], conditioning = cfg$washout, washout = cfg$washout)
    template <- one$templates[[1L]]; model <- one$models[[1L]]
    error <- c1_warmup(template, one$history_scaled, cfg$washout)
    h <- do.call(cbind, template$states$H_all)[one$keep_idx, , drop = FALSE]
    audit <- data.frame(candidate = sc$grid$candidate[j], warmup_error = error,
      admitted = is.finite(error) && error <= cfg$washout_tolerance,
      saturation_fraction = mean(abs(h) > .99), constant_features = sum(apply(h, 2L, sd) < 1e-8),
      feature_rank = qr(model$X)$rank, slopes = model$d, finite = all(is.finite(model$X)))
    base <- one[c("y", "n", "normalize_features", "keep_idx", "history", "history_scaled", "preprocessing", "meta")]
    part <- list(model = model, template = c1_lean_template(template), audit = audit,
      base = if (j == 1L) base else NULL, compute_seconds = unname(proc.time()[3] - begun), bank_id = id)
    rhs_save(part, file); NULL
  }
  for (start in seq(1L, length(sc$specs), by = 8L)) {
    ids <- seq.int(start, min(length(sc$specs), start + 7L))
    result <- parallel::mclapply(ids, make_one, mc.cores = cfg$feature_workers, mc.set.seed = FALSE)
    if (any(vapply(result, inherits, FALSE, "try-error"))) stop("Feature-bank construction failed; completed parts remain restartable")
    cat("Built/audited", max(ids), "/", length(sc$specs), "candidates\n"); flush.console()
  }
  parts <- lapply(seq_along(sc$specs), function(j) readRDS(file.path(cache, sprintf("part_%04d.rds", j))))
  stopifnot(all(vapply(parts, function(x) identical(x$bank_id, id), FALSE)))
  audit <- do.call(rbind, lapply(parts, `[[`, "audit")); keep <- which(audit$admitted)
  stopifnot(length(keep) > 0L, all(audit$finite))
  bank <- parts[[1L]]$base
  bank$models <- lapply(parts[keep], `[[`, "model"); bank$templates <- lapply(parts[keep], `[[`, "template")
  bank$specifications <- sc$specs[keep]; bank$model_info <- cbind(model = seq_along(keep), sc$grid[keep, , drop = FALSE])
  counts <- table(bank$model_info$D)
  bank$prior <- 1 / (length(counts) * as.numeric(counts[as.character(bank$model_info$D)]))
  class(bank) <- "autodesn_bank"; attr(bank, "comparison_bank_id") <- id
  stopifnot(identical(bank$keep_idx, seq.int(cfg$fit_start, cfg$fit_end)), bank$n == cfg$n_train)
  write.csv(cbind(sc$grid, audit[, -1L, drop = FALSE]), file.path(directory, "specification_audit.csv"), row.names = FALSE)
  rhs_save(bank, path)
  timing <- list(complete = TRUE, bank_id = id, candidates = length(sc$specs), admitted = length(keep),
    invocation_wall_seconds = unname(proc.time()[3] - started),
    candidate_compute_seconds_sum = sum(vapply(parts, `[[`, 0, "compute_seconds")),
    timing_note = "Invocation wall time can include reused parts; summed candidate compute covers all parts and is not parallel wall time.")
  rhs_json(timing, file.path(directory, "status.json"))
  list(bank = bank, id = id, reused = FALSE, load_seconds = 0, build = timing)
}

rhs_diagnostic_gate <- function(dg, cfg) {
  p <- dg$parameters; m <- dg$models; g <- cfg$diagnostic_gates
  if (is.data.frame(p) && "sampled" %in% names(p)) p <- p[p$sampled, , drop = FALSE]
  identical(as.integer(dg$chains), as.integer(cfg$chains)) &&
    is.data.frame(p) && nrow(p) > 0L && is.data.frame(m) && nrow(m) > 0L &&
    all(is.finite(p$rhat)) && all(is.finite(p$ess_spectral)) && all(is.finite(m$chain_range)) &&
    max(p$rhat) <= g$rhat_max && min(p$ess_spectral) >= g$ess_min &&
    max(m$chain_range) <= g$model_chain_range_max
}

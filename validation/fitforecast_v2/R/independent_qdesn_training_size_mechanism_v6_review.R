itm6r_schema <- "independent_qdesn_training_size_mechanism_v6_review_v1"

itm6r_plan_files <- function(run) {
  paths <- list.files(file.path(run, "plans"), pattern = "[.]csv$",
    full.names = TRUE)
  paths[!grepl("_hashes[.]csv$", paths)]
}

itm6r_statuses <- function(plan) {
  if (!nrow(plan)) return(character())
  vapply(plan$status_path, function(path) {
    if (!file.exists(path)) return("PENDING")
    iqt12_read(path)$status
  }, "")
}

itm6r_health <- function(run) {
  rows <- lapply(itm6r_plan_files(run), function(path) {
    plan <- read.csv(path, stringsAsFactors = FALSE)
    status <- itm6r_statuses(plan)
    data.frame(stage = sub("[.]csv$", "", basename(path)),
      planned = nrow(plan), complete = sum(status == "SUCCESS"),
      running = sum(status == "RUNNING"), pending = sum(status == "PENDING"),
      failed = sum(grepl("^FAILED", status)),
      other = sum(!status %in% c("SUCCESS", "RUNNING", "PENDING") &
        !grepl("^FAILED", status)), stringsAsFactors = FALSE)
  })
  if (!length(rows)) return(data.frame(stage = character(), planned = integer(),
    complete = integer(), running = integer(), pending = integer(),
    failed = integer(), other = integer()))
  out <- do.call(rbind, rows)
  out[order(match(out$stage, c("smoke", "representation", "quantile",
    "validation", "rolling", "mcmc")), out$stage), ]
}

itm6r_success_results <- function(run, stage) {
  plan_path <- file.path(run, "plans", paste0(stage, ".csv"))
  if (!file.exists(plan_path)) return(data.frame())
  plan <- read.csv(plan_path, stringsAsFactors = FALSE)
  status <- itm6r_statuses(plan)
  plan <- plan[status == "SUCCESS", , drop = FALSE]
  if (!nrow(plan)) return(data.frame())
  rows <- vector("list", nrow(plan))
  for (i in seq_len(nrow(plan))) {
    path <- file.path(run, "evidence", plan$id[i], "summary.csv")
    stopifnot(file.exists(path))
    z <- read.csv(path, stringsAsFactors = FALSE)
    z$plan_id <- plan$id[i]
    z$stage <- stage
    for (name in c("structure_id", "tau_multiplier", "rolling_window",
        "config_path", "status_path")) {
      if (name %in% names(plan)) z[[name]] <- plan[[name]][i]
    }
    rows[[i]] <- z
  }
  do.call(rbind, rows)
}

itm6r_verify_success <- function(run) {
  checked <- 0L
  failures <- character()
  for (plan_path in itm6r_plan_files(run)) {
    plan <- read.csv(plan_path, stringsAsFactors = FALSE)
    status <- itm6r_statuses(plan)
    for (i in which(status == "SUCCESS")) {
      packet <- iqt12_read(plan$status_path[i])
      ok <- tryCatch({
        iqt12_verify(packet$manifest)
        TRUE
      }, error = function(error) FALSE)
      checked <- checked + 1L
      if (!ok) failures <- c(failures, plan$status_path[i])
    }
  }
  list(checked = checked, failures = failures)
}

itm6r_verify_frozen <- function(run) {
  names <- c("source_hashes.csv", "input_hashes.csv", "package_hashes.csv",
    "frozen_hashes.csv")
  paths <- file.path(run, names)
  stopifnot(all(file.exists(paths)))
  failures <- paths[!vapply(paths, function(path) tryCatch({
    iqt12_verify(path)
    TRUE
  }, error = function(error) FALSE), logical(1L))]
  list(checked = length(paths), failures = failures)
}

itm6r_binary_payloads <- function(run) {
  paths <- list.files(run, recursive = TRUE, full.names = TRUE)
  paths[grepl("[.](rds|rda|rdata)$", paths, ignore.case = TRUE)]
}

itm6r_representation_summary <- function(run) {
  path <- file.path(run, "summaries", "representation_scores.csv")
  if (!file.exists(path)) return(data.frame())
  z <- read.csv(path, stringsAsFactors = FALSE)
  rows <- list()
  for (cell in unique(z$cell)) for (N in sort(unique(z$N))) {
    x <- z[z$cell == cell & z$N == N, , drop = FALSE]
    value <- function(name, fun = min) fun(x[[name]], na.rm = TRUE)
    rows[[length(rows) + 1L]] <- data.frame(cell = cell, N = N,
      oracle_teacher_min = value("oracle_teacher_mae"),
      oracle_recursive_min = value("oracle_recursive_mae"),
      gaussian_recursive_min = value("gaussian_recursive_mae"),
      normal_rhs_min = value("normal_rhs_observed_mae"),
      oracle_teacher_median = value("oracle_teacher_mae", median),
      gaussian_recursive_median = value("gaussian_recursive_mae", median),
      stringsAsFactors = FALSE)
  }
  do.call(rbind, rows)
}

itm6r_group_metric <- function(results, metric, expected_folds = NULL) {
  if (!nrow(results)) return(data.frame())
  z <- results[results$metric == metric, , drop = FALSE]
  if (!nrow(z)) return(data.frame())
  keys <- intersect(c("cell", "N", "structure_id", "tau_multiplier",
    "rolling_window", "model"), names(z))
  signature <- interaction(z[keys], drop = TRUE, lex.order = TRUE)
  rows <- lapply(split(z, signature), function(x) {
    key <- x[1L, keys, drop = FALSE]
    cbind(key, data.frame(metric = metric, mean = mean(x$mean),
      minimum = min(x$mean), maximum = max(x$mean),
      folds = length(unique(x$fold)), jobs = nrow(x),
      complete_folds = if (is.null(expected_folds)) NA else
        length(unique(x$fold)) == expected_folds,
      stringsAsFactors = FALSE))
  })
  do.call(rbind, rows)
}

itm6r_quantile_rank <- function(run) {
  x <- itm6r_success_results(run, "quantile")
  out <- itm6r_group_metric(x, "forecast_mae", expected_folds = 2L)
  if (!nrow(out)) return(out)
  out <- out[out$complete_folds, , drop = FALSE]
  out[order(out$cell, out$N, out$mean, out$maximum), ]
}

itm6r_quantile_best <- function(rank) {
  if (!nrow(rank)) return(data.frame())
  groups <- interaction(rank$cell, rank$N, drop = TRUE, lex.order = TRUE)
  out <- do.call(rbind, lapply(split(rank, groups), function(z)
    z[order(z$mean, z$maximum), , drop = FALSE][1L, ]))
  rownames(out) <- NULL
  out[order(out$cell, out$N), ]
}

itm6r_completion_balance <- function(run, stage) {
  path <- file.path(run, "plans", paste0(stage, ".csv"))
  if (!file.exists(path)) return(data.frame())
  plan <- read.csv(path, stringsAsFactors = FALSE)
  plan$status <- itm6r_statuses(plan)
  keys <- intersect(c("cell", "N", "status"), names(plan))
  out <- aggregate(plan$id, plan[keys], length)
  names(out)[ncol(out)] <- "jobs"
  out[order(out$cell, out$N, out$status), ]
}

itm6r_role_stability <- function(run) {
  x <- itm6r_success_results(run, "quantile")
  if (!nrow(x)) return(data.frame())
  x <- x[x$metric == "forecast_mae", , drop = FALSE]
  bank <- read.csv(file.path(run, "candidate_bank.csv"), stringsAsFactors = FALSE)
  columns <- intersect(c("structure_id", "role", "D", "total_states", "m"),
    names(bank))
  x <- merge(x, unique(bank[columns]), by = "structure_id", all.x = TRUE)
  rows <- lapply(split(x, x$role), function(z) data.frame(role = z$role[1L],
    D = z$D[1L], total_states = z$total_states[1L], m = z$m[1L],
    jobs = nrow(z), median_mae = median(z$mean), minimum_mae = min(z$mean),
    over_10 = sum(z$mean > 10), over_100 = sum(z$mean > 100),
    over_1000 = sum(z$mean > 1000), stringsAsFactors = FALSE))
  out <- do.call(rbind, rows)
  out[order(out$median_mae), ]
}

itm6r_validation_rank <- function(run) {
  x <- itm6r_success_results(run, "validation")
  if (!nrow(x)) return(data.frame())
  z <- x[x$metric == "forecast_mae", , drop = FALSE]
  q <- z[z$model == "qdesn", , drop = FALSE]
  b <- z[z$model == "baseline", c("cell", "N", "fold", "mean"), drop = FALSE]
  names(b)[4L] <- "baseline_mae"
  q <- merge(q, b, by = c("cell", "N", "fold"), all.x = TRUE)
  q$ratio <- q$mean / q$baseline_mae
  keys <- c("cell", "N", "structure_id", "tau_multiplier")
  signature <- interaction(q[keys], drop = TRUE, lex.order = TRUE)
  rows <- lapply(split(q, signature), function(y) cbind(y[1L, keys, drop = FALSE],
    data.frame(qdesn_mae = mean(y$mean), baseline_mae = mean(y$baseline_mae),
      ratio = mean(y$ratio), worst_fold_ratio = max(y$ratio),
      folds = length(unique(y$fold)), stringsAsFactors = FALSE)))
  out <- do.call(rbind, rows)
  out[order(out$cell, out$ratio, out$worst_fold_ratio), ]
}

itm6r_rolling_rank <- function(run) {
  x <- itm6r_success_results(run, "rolling")
  if (!nrow(x)) return(data.frame())
  itm6r_group_metric(x, "forecast_mae")
}

itm6r_mcmc_summary <- function(run) {
  x <- itm6r_success_results(run, "mcmc")
  if (!nrow(x)) return(list(metrics = data.frame(), primary = data.frame()))
  keys <- c("cell", "model", "metric")
  signature <- interaction(x[keys], drop = TRUE, lex.order = TRUE)
  metrics <- do.call(rbind, lapply(split(x, signature), function(z)
    cbind(z[1L, keys, drop = FALSE], data.frame(mean = mean(z$mean),
      minimum = min(z$mean), maximum = max(z$mean),
      chains = length(unique(z$chain)), folds = length(unique(z$fold)),
      jobs = length(unique(z$plan_id)), stringsAsFactors = FALSE))))
  mae <- metrics[metrics$metric == "forecast_mae", ]
  if (!nrow(mae)) return(list(metrics = metrics, primary = data.frame()))
  wide <- reshape(mae[c("cell", "model", "mean")], idvar = "cell",
    timevar = "model", direction = "wide")
  if (all(c("mean.qdesn", "mean.baseline") %in% names(wide))) {
    wide$ratio_qdesn_to_baseline <- wide$mean.qdesn / wide$mean.baseline
  }
  list(metrics = metrics, primary = wide)
}

itm6r_fmt <- function(value, digits = 4L) {
  if (!length(value) || is.na(value)) return("NA")
  formatC(value, digits = digits, format = "fg", flag = "#")
}

itm6r_markdown <- function(meta, health, representation, quantile_best,
                           role_stability, validation, mcmc) {
  lines <- c("# Independent Q-DESN training-size mechanism v6 review", "",
    paste0("- Review mode: `", meta$mode, "`"),
    paste0("- Campaign HEAD: `", meta$campaign_head, "`"),
    paste0("- Analysis HEAD: `", meta$analysis_head, "`"),
    paste0("- Article holdout used for selection: `",
      meta$selection_used_article_holdout, "`"),
    paste0("- Verified successful result packets: ", meta$verified_packets),
    paste0("- Binary fitted-model payloads: ", meta$binary_payloads), "",
    "## Health", "",
    "| Stage | Planned | Complete | Running | Pending | Failed |",
    "|---|---:|---:|---:|---:|---:|")
  for (i in seq_len(nrow(health))) lines <- c(lines,
    sprintf("| %s | %d | %d | %d | %d | %d |", health$stage[i],
      health$planned[i], health$complete[i], health$running[i],
      health$pending[i], health$failed[i]))
  lines <- c(lines, "", "## Evidence-led interpretation", "")
  if (nrow(quantile_best)) {
    lines <- c(lines, "Best completed two-fold internal forecast MAE by cell and training size:", "",
      "| Cell | N | Forecast MAE | Tau multiplier | Structure |",
      "|---|---:|---:|---:|---|")
    for (i in seq_len(nrow(quantile_best))) lines <- c(lines,
      sprintf("| %s | %d | %s | %s | `%s` |", quantile_best$cell[i],
        quantile_best$N[i], itm6r_fmt(quantile_best$mean[i]),
        itm6r_fmt(quantile_best$tau_multiplier[i], 3L),
        quantile_best$structure_id[i]))
  } else lines <- c(lines, "Quantile evidence is not yet available.")
  if (nrow(role_stability)) {
    unstable <- role_stability[role_stability$over_100 > 0, , drop = FALSE]
    lines <- c(lines, "", paste0("Architectural roles with forecast MAE above 100: ",
      if (nrow(unstable)) paste(unstable$role, collapse = ", ") else "none", "."))
  }
  if (nrow(validation)) {
    best <- do.call(rbind, lapply(split(validation, validation$cell),
      function(z) z[which.min(z$ratio), , drop = FALSE]))
    lines <- c(lines, "", "Best matched four-fold validation ratios:")
    for (i in seq_len(nrow(best))) lines <- c(lines,
      paste0("- ", best$cell[i], ": ", itm6r_fmt(best$ratio[i]),
        " (worst fold ", itm6r_fmt(best$worst_fold_ratio[i]), ")."))
  }
  if (nrow(mcmc$primary)) {
    lines <- c(lines, "", "Final matched MCMC forecast-MAE ratios:")
    for (i in seq_len(nrow(mcmc$primary))) lines <- c(lines,
      paste0("- ", mcmc$primary$cell[i], ": ",
        itm6r_fmt(mcmc$primary$ratio_qdesn_to_baseline[i]), "."))
  }
  lines <- c(lines, "", "## Decision", "", meta$recommendation, "")
  lines
}

itm6r_audit <- function(repo, run, output, mode = c("interim", "final"),
                        verify_hashes = TRUE) {
  mode <- match.arg(mode)
  stopifnot(dir.exists(repo), dir.exists(run))
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  campaign <- iqt12_read(file.path(run, "campaign.json"))
  health <- itm6r_health(run)
  if (any(health$failed > 0L)) stop("Campaign contains failed jobs")
  if (mode == "final") {
    required_stages <- c("smoke", "representation", "quantile", "validation",
      "rolling", "mcmc")
    stopifnot(file.exists(file.path(run, "closeout.json")),
      all(required_stages %in% health$stage),
      all(health$running == 0L), all(health$pending == 0L),
      all(health$complete == health$planned))
  }
  verification <- if (verify_hashes) itm6r_verify_success(run) else
    list(checked = sum(health$complete), failures = character())
  frozen_verification <- if (verify_hashes) itm6r_verify_frozen(run) else
    list(checked = 0L, failures = character())
  if (length(verification$failures)) stop("Artifact verification failed")
  if (length(frozen_verification$failures)) stop("Frozen-input verification failed")
  binaries <- itm6r_binary_payloads(run)
  representation <- itm6r_representation_summary(run)
  quantile_rank <- itm6r_quantile_rank(run)
  quantile_best <- itm6r_quantile_best(quantile_rank)
  role_stability <- itm6r_role_stability(run)
  completion <- itm6r_completion_balance(run, "quantile")
  validation <- itm6r_validation_rank(run)
  rolling <- itm6r_rolling_rank(run)
  mcmc <- itm6r_mcmc_summary(run)
  if (mode == "final") {
    stopifnot(length(binaries) == 0L, nrow(mcmc$primary) == 3L,
      all(c("mean.qdesn", "mean.baseline", "ratio_qdesn_to_baseline") %in%
        names(mcmc$primary)),
      all(is.finite(mcmc$primary$ratio_qdesn_to_baseline)))
  }
  complete <- nrow(health) && all(health$complete == health$planned) &&
    all(health$running == 0L) && all(health$pending == 0L)
  recommendation <- if (!complete) {
    "Continue the frozen campaign. Do not promote interim values or alter selection while jobs remain."
  } else if (nrow(mcmc$primary) &&
      all(is.finite(mcmc$primary$ratio_qdesn_to_baseline)) &&
      all(mcmc$primary$ratio_qdesn_to_baseline <= 1.1)) {
    "The sentinel mechanism criterion is met. Prepare, but do not automatically publish, the full 18-cell confirmation campaign."
  } else {
    "Retain this campaign as diagnostic-only. Localize the remaining gap using validation and rolling-readout evidence before any new screen."
  }
  analysis_head <- system2("git", c("-C", repo, "rev-parse", "HEAD"),
    stdout = TRUE)
  meta <- list(schema = itm6r_schema, mode = mode,
    run = normalizePath(run), campaign_head = campaign$head,
    analysis_head = analysis_head,
    selection_used_article_holdout = FALSE,
    verified_packets = verification$checked,
    verification_failures = length(verification$failures),
    frozen_manifests_verified = frozen_verification$checked,
    frozen_verification_failures = length(frozen_verification$failures),
    binary_payloads = length(binaries), recommendation = recommendation,
    generated_at = format(Sys.time(), tz = "UTC", usetz = TRUE))
  tables <- list(stage_health = health,
    representation_training_size = representation,
    quantile_completion_balance = completion,
    quantile_completed_rank = quantile_rank,
    quantile_best_by_cell_N = quantile_best,
    quantile_role_stability = role_stability,
    validation_rank = validation, rolling_rank = rolling,
    mcmc_metric_summary = mcmc$metrics,
    mcmc_primary_comparison = mcmc$primary)
  for (name in names(tables)) iqt12_csv(tables[[name]],
    file.path(output, paste0(name, ".csv")))
  iqt12_json(meta, file.path(output, "review_metadata.json"))
  writeLines(itm6r_markdown(meta, health, representation, quantile_best,
    role_stability, validation, mcmc), file.path(output, "campaign_review.md"))
  manifest_files <- list.files(output, full.names = TRUE)
  manifest_files <- manifest_files[basename(manifest_files) != "review_manifest.csv"]
  iqt12_hash(manifest_files, file.path(output, "review_manifest.csv"))
  invisible(list(metadata = meta, health = health, tables = tables,
    manifest = file.path(output, "review_manifest.csv")))
}

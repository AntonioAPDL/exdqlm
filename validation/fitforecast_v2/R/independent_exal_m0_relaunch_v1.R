qdesn_m0v1_stage <- "qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_relaunch_v1"
qdesn_m0v1_method_id <- "m0_v_collapsed_support_logit"
qdesn_m0v1_authority_sha256 <- "90744fae79f8af79c6e844e5862c90330ea14d9bbd2df69f630440887fed1393"
qdesn_m0v1_registry_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
qdesn_m0v1_base_commit <- "58ad24dee1204f23f7b0df5efc32b388dd8638b3"
qdesn_m0v1_reference_commit <- "e7073b6982caf2ed4abbcee04c78cfde9cb8a983"

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

qdesn_m0v1_repo_root <- function() {
  normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
}

qdesn_m0v1_path <- function(repo_root, ..., must_work = FALSE) {
  path <- file.path(repo_root, ...)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}

qdesn_m0v1_rel <- function(path, repo_root) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  prefix <- paste0(
    "^", gsub("([].[^$*+?{}|()\\\\])", "\\\\\\1", repo_root), "/?"
  )
  sub(prefix, "", path)
}

qdesn_m0v1_sha256 <- function(path) {
  if (!file.exists(path)) return(NA_character_)
  unname(tools::sha256sum(path))
}

qdesn_m0v1_read_csv <- function(path) {
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}

qdesn_m0v1_write_csv <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(value, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

qdesn_m0v1_read_json <- function(path) {
  jsonlite::read_json(path, simplifyVector = TRUE)
}

qdesn_m0v1_write_json <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(
    value, path, pretty = TRUE, auto_unbox = TRUE, null = "null", digits = NA
  )
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

qdesn_m0v1_authority_path <- function(repo_root) {
  qdesn_m0v1_path(
    repo_root, "validation", "fitforecast_v2", "promotions",
    "qdesn_dqlm_500obs_trainonly_article_v3_20260807",
    "qdesn_dqlm_500obs_trainonly_article_v3_20260807_interface.csv",
    must_work = TRUE
  )
}

qdesn_m0v1_config_stub <- function(repo_root) {
  qdesn_m0v1_path(
    repo_root, "config", "validation", qdesn_m0v1_stage,
    must_work = FALSE
  )
}

qdesn_m0v1_source_occurrences <- function(interface) {
  target <- interface[
    interface$inference == "mcmc" &
      interface$model_variant == "qdesn_exal_rhs_ns",
    , drop = FALSE
  ]
  if (nrow(target) != 9L) {
    stop("The authoritative interface must contain nine exQ-DESN RHS MCMC cells.",
         call. = FALSE)
  }
  family_order <- c(normal = 1L, laplace = 2L, gausmix = 3L)
  target <- target[order(family_order[target$family], target$tau), , drop = FALSE]
  definitions <- list(
    list(
      role = "fit_qtrue_rmse",
      id = "fit_source_candidate_id",
      path = "fit_source_path",
      value = "fit_qtrue_rmse"
    ),
    list(
      role = "forecast_qtrue_mae_H1000",
      id = "forecast_mae_source_candidate_id",
      path = "forecast_mae_source_path",
      value = "forecast_qtrue_mae_H1000"
    ),
    list(
      role = "forecast_check_loss_H1000",
      id = "forecast_check_source_candidate_id",
      path = "forecast_check_source_path",
      value = "forecast_check_loss_H1000"
    )
  )
  rows <- list()
  k <- 0L
  for (i in seq_len(nrow(target))) {
    for (j in seq_along(definitions)) {
      d <- definitions[[j]]
      k <- k + 1L
      rows[[k]] <- data.frame(
        family = target$family[[i]],
        tau = as.numeric(target$tau[[i]]),
        metric_role = d$role,
        candidate_id = as.character(target[[d$id]][[i]]),
        source_path = as.character(target[[d$path]][[i]]),
        current_value = as.numeric(target[[d$value]][[i]]),
        current_status = as.character(target$status[[i]]),
        current_signoff_grade = as.character(target$signoff_grade[[i]]),
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

qdesn_m0v1_request_path_from_metric <- function(source_path) {
  source_path <- normalizePath(source_path, winslash = "/", mustWork = TRUE)
  if (identical(basename(source_path), "fit_summary_row.csv")) {
    method_dir <- dirname(source_path)
  } else if (identical(basename(dirname(source_path)), "tables")) {
    method_dir <- dirname(dirname(source_path))
  } else {
    stop(sprintf("Cannot resolve a fit request from metric path: %s", source_path),
         call. = FALSE)
  }
  normalizePath(file.path(method_dir, "fit_request.json"),
                winslash = "/", mustWork = TRUE)
}

qdesn_m0v1_metric_value <- function(role, fit_path, forecast_path) {
  if (identical(role, "fit_qtrue_rmse")) {
    fit <- qdesn_m0v1_read_csv(fit_path)
    return(as.numeric(fit$train_qtrue_rmse[[1L]]))
  }
  horizon <- qdesn_m0v1_read_csv(forecast_path)
  idx <- which(
    suppressWarnings(as.integer(horizon$horizon)) == 1000L |
      as.character(horizon$window) == "forecast_H1000"
  )
  if (!length(idx)) return(NA_real_)
  if (identical(role, "forecast_qtrue_mae_H1000")) {
    return(as.numeric(horizon$qtrue_mae[[idx[[1L]]]]))
  }
  as.numeric(horizon$pinball_tau[[idx[[1L]]]])
}

qdesn_m0v1_job_root <- function(repo_root, run_tag, job_id) {
  qdesn_m0v1_path(
    repo_root, "results", "qdesn_mcmc_validation", qdesn_m0v1_stage,
    run_tag, "jobs", job_id, must_work = FALSE
  )
}

qdesn_m0v1_status_row <- function(path) {
  status <- tryCatch(qdesn_m0v1_read_json(path), error = function(e) NULL)
  if (is.null(status)) return(NULL)
  data.frame(
    job_id = as.character(status$job_id %||% NA_character_),
    budget = as.character(status$budget %||% NA_character_),
    anchor_id = as.character(status$anchor_id %||% NA_character_),
    chain_id = as.integer(status$chain_id %||% NA_integer_),
    status = as.character(status$status %||% NA_character_),
    started_at = as.character(status$started_at %||% NA_character_),
    finished_at = as.character(status$finished_at %||% NA_character_),
    elapsed_seconds = as.numeric(status$elapsed_seconds %||% NA_real_),
    error_message = as.character(status$error_message %||% NA_character_),
    stringsAsFactors = FALSE
  )
}

qdesn_m0v1_scan_jobs <- function(repo_root, run_tag, plan) {
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    job_root <- qdesn_m0v1_job_root(repo_root, run_tag, plan$job_id[[i]])
    status_path <- file.path(job_root, "job_status.json")
    row <- if (file.exists(status_path)) qdesn_m0v1_status_row(status_path) else NULL
    if (is.null(row)) {
      row <- data.frame(
        job_id = plan$job_id[[i]], budget = plan$budget[[i]],
        anchor_id = plan$anchor_id[[i]], chain_id = plan$chain_id[[i]],
        status = if (file.exists(file.path(job_root, "job_started.json"))) "RUNNING" else "PLANNED",
        started_at = NA_character_, finished_at = NA_character_,
        elapsed_seconds = NA_real_, error_message = NA_character_,
        stringsAsFactors = FALSE
      )
    }
    row$config_sha256 <- plan$config_sha256[[i]]
    row$fit_summary_exists <- file.exists(file.path(job_root, "fit_summary_row.csv"))
    row$forecast_summary_exists <- file.exists(
      file.path(job_root, "tables", "forecast_horizon_summary.csv")
    )
    row$progress_rows <- if (file.exists(file.path(job_root, "progress_trace.csv"))) {
      max(0L, length(readLines(file.path(job_root, "progress_trace.csv"), warn = FALSE)) - 1L)
    } else 0L
    row
  })
  do.call(rbind, rows)
}

qdesn_m0v1_classify_health <- function(status, process_alive,
                                       evidence_age_seconds,
                                       stale_threshold_seconds = 1800) {
  status <- toupper(as.character(status %||% "UNKNOWN")[1L])
  alive <- isTRUE(process_alive)
  age <- suppressWarnings(as.numeric(evidence_age_seconds)[1L])
  threshold <- suppressWarnings(as.numeric(stale_threshold_seconds)[1L])
  if (!is.finite(threshold) || threshold <= 0) threshold <- 1800
  if (identical(status, "SUCCESS")) return("completed")
  if (identical(status, "FAIL")) return("failed")
  if (identical(status, "PLANNED")) return("planned")
  if (!identical(status, "RUNNING")) return("unknown")
  if (!alive) return("interrupted")
  if (is.finite(age) && age > threshold) return("stalled")
  "progressing"
}

qdesn_m0v1_rank_split_rhat <- function(chains, folded = FALSE) {
  chains <- lapply(chains, function(x) as.numeric(x[is.finite(x)]))
  n <- min(vapply(chains, length, integer(1L)))
  n <- 2L * floor(n / 2L)
  if (length(chains) < 2L || n < 20L) return(NA_real_)
  chains <- lapply(chains, function(x) utils::tail(x, n))
  pooled <- unlist(chains, use.names = FALSE)
  if (isTRUE(folded)) pooled <- abs(pooled - stats::median(pooled))
  ranks <- rank(pooled, ties.method = "average")
  z <- stats::qnorm((ranks - 3 / 8) / (length(ranks) + 1 / 4))
  split <- list()
  offset <- 0L
  for (i in seq_along(chains)) {
    zi <- z[offset + seq_len(n)]
    offset <- offset + n
    split[[length(split) + 1L]] <- zi[seq_len(n / 2L)]
    split[[length(split) + 1L]] <- zi[(n / 2L + 1L):n]
  }
  mat <- do.call(cbind, split)
  chain_means <- colMeans(mat)
  W <- mean(apply(mat, 2L, stats::var))
  B <- nrow(mat) * stats::var(chain_means)
  var_plus <- (nrow(mat) - 1) / nrow(mat) * W + B / nrow(mat)
  if (!is.finite(W) || W <= 0) return(if (isTRUE(all.equal(B, 0))) 1 else NA_real_)
  sqrt(var_plus / W)
}

qdesn_m0v1_effective_size <- function(chains) {
  chains <- lapply(chains, function(x) as.numeric(x[is.finite(x)]))
  n <- min(vapply(chains, length, integer(1L)))
  if (length(chains) < 1L || n < 20L) return(NA_real_)
  obj <- coda::mcmc.list(lapply(chains, function(x) coda::mcmc(utils::tail(x, n))))
  as.numeric(coda::effectiveSize(obj)[[1L]])
}

qdesn_m0v1_tail_effective_size <- function(chains) {
  pooled <- unlist(chains, use.names = FALSE)
  pooled <- pooled[is.finite(pooled)]
  if (length(pooled) < 40L) return(NA_real_)
  cuts <- stats::quantile(pooled, c(0.05, 0.95), na.rm = TRUE, names = FALSE)
  lower <- lapply(chains, function(x) as.numeric(x <= cuts[[1L]]))
  upper <- lapply(chains, function(x) as.numeric(x >= cuts[[2L]]))
  values <- c(
    qdesn_m0v1_effective_size(lower),
    qdesn_m0v1_effective_size(upper)
  )
  values <- values[is.finite(values)]
  if (length(values)) min(values) else NA_real_
}

qdesn_m0v1_compact_progress <- function(path, stride = 50L) {
  if (!file.exists(path)) return(FALSE)
  x <- qdesn_m0v1_read_csv(path)
  if (nrow(x) <= 2L) return(TRUE)
  keep <- unique(c(1L, seq.int(1L, nrow(x), by = as.integer(stride)), nrow(x)))
  qdesn_m0v1_write_csv(x[keep, , drop = FALSE], path)
  TRUE
}

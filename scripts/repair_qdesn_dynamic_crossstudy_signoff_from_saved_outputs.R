#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(flag, default = NULL) {
  idx <- match(flag, args)
  if (is.na(idx) || idx >= length(args)) return(default)
  args[[idx + 1L]]
}

arg_flag <- function(flag) {
  flag %in% args
}

results_root_arg <- arg_value("--results-root")
report_root_arg <- arg_value("--report-root", default = NULL)
dry_run <- arg_flag("--dry-run")

if (is.null(results_root_arg)) {
  stop("Usage: repair_qdesn_dynamic_crossstudy_signoff_from_saved_outputs.R --results-root <campaign-results-root-or-outer-root> [--report-root <dir>] [--dry-run]", call. = FALSE)
}

repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
suppressPackageStartupMessages(pkgload::load_all(repo_root, quiet = TRUE))

resolve_campaign_results_root <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (dir.exists(file.path(path, "roots"))) return(path)
  children <- if (dir.exists(path)) list.dirs(path, recursive = FALSE, full.names = TRUE) else character(0)
  hits <- children[dir.exists(file.path(children, "roots"))]
  if (length(hits) == 1L) return(normalizePath(hits[[1L]], winslash = "/", mustWork = TRUE))
  if (length(hits) > 1L) {
    newest <- hits[order(file.info(hits)$mtime, decreasing = TRUE)][[1L]]
    return(normalizePath(newest, winslash = "/", mustWork = TRUE))
  }
  stop(sprintf("Could not resolve a campaign results root with a roots/ directory from: %s", path), call. = FALSE)
}

read_csv_or_empty <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

copy_if_exists <- function(path, backup_root, base_root) {
  if (!file.exists(path)) return(FALSE)
  rel <- sub(paste0("^", gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", normalizePath(base_root, winslash = "/", mustWork = FALSE)), "/?"), "", normalizePath(path, winslash = "/", mustWork = FALSE))
  dst <- file.path(backup_root, rel)
  dir.create(dirname(dst), recursive = TRUE, showWarnings = FALSE)
  isTRUE(file.copy(path, dst, overwrite = TRUE))
}

write_df <- function(x, path) {
  exdqlm:::.qdesn_validation_write_df(x, path)
}

write_json <- function(path, x) {
  exdqlm:::.qdesn_validation_write_json(path, x)
}

write_lines <- function(path, x) {
  exdqlm:::.qdesn_validation_write_lines(path, x)
}

repair_method_dir <- function(root_spec, q_true, method_dir, backup_root, campaign_results_root) {
  method_name <- basename(method_dir)
  parts <- strsplit(method_name, "_", fixed = TRUE)[[1L]]
  if (length(parts) != 2L || !(parts[[1L]] %in% c("vb", "mcmc")) || !(parts[[2L]] %in% c("al", "exal"))) {
    return(NULL)
  }

  method <- parts[[1L]]
  likelihood_family <- parts[[2L]]
  forecast_path <- file.path(method_dir, "models", "forecast_objects.rds")
  if (!file.exists(forecast_path)) return(NULL)

  before_health <- read_csv_or_empty(file.path(method_dir, "health_summary.csv"))
  before_signoff <- read_csv_or_empty(file.path(method_dir, "signoff_summary.csv"))
  before_fit <- read_csv_or_empty(file.path(method_dir, "fit_summary_row.csv"))

  backup_paths <- c(
    file.path(method_dir, "health_summary.csv"),
    file.path(method_dir, "signoff_summary.csv"),
    file.path(method_dir, "fit_summary_row.csv"),
    file.path(method_dir, "progress_trace.csv"),
    file.path(method_dir, "chain_summary.csv")
  )
  if (!dry_run) {
    invisible(vapply(backup_paths, copy_if_exists, logical(1), backup_root = backup_root, base_root = campaign_results_root))
  }

  root_spec_lik <- modifyList(root_spec, list(likelihood_family = likelihood_family))
  summary_obj <- exdqlm:::collect_pipeline_run_summary(method_dir)
  health_row <- exdqlm:::.qdesn_validation_method_health(method, root_spec_lik, summary_obj)
  progress_trace <- exdqlm:::.qdesn_validation_method_progress_trace(method, summary_obj)
  if (nrow(progress_trace)) {
    progress_trace$likelihood_family <- likelihood_family
  }
  signoff_cfg <- exdqlm:::.qdesn_validation_signoff_cfg(NULL)
  meta_row <- health_row[, c("root_id", "scenario", "tau", "likelihood_family", "beta_prior_type", "seed", "reservoir_profile"), drop = FALSE]
  signoff_row <- if (identical(method, "vb")) {
    exdqlm:::.qdesn_validation_vb_signoff_from_rows(meta_row, health_row, progress_trace, signoff_cfg$vb)
  } else {
    exdqlm:::.qdesn_validation_mcmc_signoff_from_rows(meta_row, health_row, progress_trace, signoff_cfg$mcmc)
  }
  metrics <- exdqlm:::.qdesn_static_crossstudy_collect_metrics_from_summary(summary_obj, q_true)
  fit_summary <- exdqlm:::.qdesn_static_crossstudy_fit_summary_row(
    root_spec = root_spec,
    likelihood_family = likelihood_family,
    method = method,
    health_row = health_row,
    metrics = metrics,
    signoff_row = signoff_row,
    method_dir = method_dir
  )
  compact_paths <- if (dry_run) {
    list(train = exdqlm:::.qdesn_validation_compact_fit_path_file(method_dir, "train"), holdout = exdqlm:::.qdesn_validation_compact_fit_path_file(method_dir, "holdout"), train_rows = NA_integer_, holdout_rows = NA_integer_)
  } else {
    exdqlm:::.qdesn_validation_write_compact_fit_paths(summary_obj, root_spec_lik, method_dir)
  }

  chain_summary <- data.frame(stringsAsFactors = FALSE)
  if (identical(method, "mcmc")) {
    chain_summary <- exdqlm:::.qdesn_validation_mcmc_chain_summary(summary_obj)
    if (nrow(chain_summary)) {
      chain_summary$likelihood_family <- likelihood_family
    }
  }

  if (!dry_run) {
    write_df(health_row, file.path(method_dir, "health_summary.csv"))
    write_df(signoff_row, file.path(method_dir, "signoff_summary.csv"))
    write_df(fit_summary, file.path(method_dir, "fit_summary_row.csv"))
    if (nrow(progress_trace)) {
      write_df(progress_trace, file.path(method_dir, "progress_trace.csv"))
    }
    if (nrow(chain_summary)) {
      write_df(chain_summary, file.path(method_dir, "chain_summary.csv"))
    }
  }

  data.frame(
    root_id = root_spec$root_id,
    method_dir = normalizePath(method_dir, winslash = "/", mustWork = FALSE),
    method = method,
    likelihood_family = likelihood_family,
    before_status = as.character(before_fit$status[1L] %||% before_health$status[1L] %||% NA_character_),
    before_finite_ok = as.logical(before_fit$finite_ok[1L] %||% before_health$finite_ok[1L] %||% NA),
    before_domain_ok = as.logical(before_fit$domain_ok[1L] %||% before_health$domain_ok[1L] %||% NA),
    before_signoff_grade = as.character(before_fit$signoff_grade[1L] %||% before_signoff$signoff_grade[1L] %||% NA_character_),
    before_signoff_reason = as.character(before_fit$signoff_reason[1L] %||% before_signoff$signoff_reason[1L] %||% NA_character_),
    after_status = as.character(fit_summary$status[1L] %||% NA_character_),
    after_finite_ok = as.logical(fit_summary$finite_ok[1L] %||% NA),
    after_domain_ok = as.logical(fit_summary$domain_ok[1L] %||% NA),
    after_signoff_grade = as.character(fit_summary$signoff_grade[1L] %||% NA_character_),
    after_signoff_reason = as.character(fit_summary$signoff_reason[1L] %||% NA_character_),
    after_progress_rows = as.integer(nrow(progress_trace)),
    after_chain_rows = as.integer(nrow(chain_summary)),
    compact_train_path = as.character(compact_paths$train %||% NA_character_),
    compact_train_rows = as.integer(compact_paths$train_rows %||% NA_integer_),
    compact_holdout_path = as.character(compact_paths$holdout %||% NA_character_),
    compact_holdout_rows = as.integer(compact_paths$holdout_rows %||% NA_integer_),
    stringsAsFactors = FALSE
  )
}

repair_root <- function(root_dir, backup_root, campaign_results_root) {
  status_path <- file.path(root_dir, "manifest", "root_status.txt")
  root_status <- if (file.exists(status_path)) trimws(readLines(status_path, warn = FALSE)[1L]) else NA_character_
  if (!identical(root_status, "SUCCESS")) return(NULL)

  manifest_path <- file.path(root_dir, "manifest", "root_manifest.json")
  q_true_path <- file.path(root_dir, "data", "q_true.csv")
  if (!file.exists(manifest_path) || !file.exists(q_true_path)) return(NULL)

  root_spec <- jsonlite::fromJSON(manifest_path, simplifyVector = FALSE)
  q_true_df <- utils::read.csv(q_true_path, stringsAsFactors = FALSE)
  q_true <- as.numeric(q_true_df$q_true %||% numeric(0))
  method_dirs <- sort(list.dirs(file.path(root_dir, "fits"), recursive = FALSE, full.names = TRUE))
  method_dirs <- method_dirs[grepl("^(vb|mcmc)_(al|exal)$", basename(method_dirs))]

  backup_paths <- c(
    file.path(root_dir, "tables", "fit_summary.csv"),
    file.path(root_dir, "tables", "pairwise_vb_vs_mcmc.csv"),
    file.path(root_dir, "tables", "model_pair_signoff.csv"),
    file.path(root_dir, "tables", "root_signoff_summary.csv"),
    file.path(root_dir, "tables", "progress_trace_long.csv")
  )
  if (!dry_run) {
    invisible(vapply(backup_paths, copy_if_exists, logical(1), backup_root = backup_root, base_root = campaign_results_root))
  }

  repair_rows <- lapply(method_dirs, repair_method_dir,
    root_spec = root_spec,
    q_true = q_true,
    backup_root = backup_root,
    campaign_results_root = campaign_results_root
  )
  repair_rows <- Filter(Negate(is.null), repair_rows)
  if (!length(repair_rows)) return(NULL)

  fit_paths <- file.path(method_dirs, "fit_summary_row.csv")
  fit_summary <- exdqlm:::.qdesn_validation_bind_rows(lapply(fit_paths[file.exists(fit_paths)], read_csv_or_empty))
  pairwise <- exdqlm:::.qdesn_static_crossstudy_algorithm_pair_summary(fit_summary, root_spec)
  model_pair <- exdqlm:::.qdesn_static_crossstudy_model_pair_summary(fit_summary, root_spec)
  status_vec <- as.character(fit_summary$status %||% character(0))
  status_vec[is.na(status_vec) | !nzchar(status_vec)] <- "FAIL"
  expected_fits <- 4L
  repaired_root_status <- if (nrow(fit_summary) >= expected_fits && length(status_vec) >= expected_fits && all(status_vec[seq_len(expected_fits)] == "SUCCESS")) {
    "SUCCESS"
  } else {
    "FAIL"
  }
  root_summary <- exdqlm:::.qdesn_dynamic_crossstudy_root_summary(
    root_spec = root_spec,
    fit_summary = fit_summary,
    pairwise_vb_vs_mcmc = pairwise,
    model_pair_summary = model_pair,
    root_status = repaired_root_status
  )

  progress_paths <- file.path(method_dirs, "progress_trace.csv")
  progress_long <- exdqlm:::.qdesn_validation_bind_rows(lapply(progress_paths[file.exists(progress_paths)], read_csv_or_empty))

  if (!dry_run) {
    write_df(fit_summary, file.path(root_dir, "tables", "fit_summary.csv"))
    write_df(pairwise, file.path(root_dir, "tables", "pairwise_vb_vs_mcmc.csv"))
    write_df(model_pair, file.path(root_dir, "tables", "model_pair_signoff.csv"))
    write_df(root_summary, file.path(root_dir, "tables", "root_signoff_summary.csv"))
    if (nrow(progress_long)) {
      write_df(progress_long, file.path(root_dir, "tables", "progress_trace_long.csv"))
    }
    write_lines(status_path, repaired_root_status)
  }

  exdqlm:::.qdesn_validation_bind_rows(repair_rows)
}

campaign_results_root <- resolve_campaign_results_root(results_root_arg)
if (is.null(report_root_arg)) {
  report_root_arg <- file.path(campaign_results_root, "repair", format(Sys.time(), "%Y%m%d-%H%M%S"))
}
repair_root_dir <- normalizePath(report_root_arg, winslash = "/", mustWork = FALSE)
backup_root <- file.path(repair_root_dir, "pre_repair_csv_backup")

if (!dry_run) {
  dir.create(repair_root_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(backup_root, recursive = TRUE, showWarnings = FALSE)
}

roots_dir <- file.path(campaign_results_root, "roots")
root_dirs <- sort(list.dirs(roots_dir, recursive = FALSE, full.names = TRUE))
repair_rows <- vector("list", length(root_dirs))
for (i in seq_along(root_dirs)) {
  cat(sprintf(
    "[%s] repair audit %d/%d: %s\n",
    format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    i,
    length(root_dirs),
    basename(root_dirs[[i]])
  ))
  flush.console()
  repair_rows[[i]] <- repair_root(
    root_dirs[[i]],
    backup_root = backup_root,
    campaign_results_root = campaign_results_root
  )
}
repair_rows <- Filter(Negate(is.null), repair_rows)
repair_df <- exdqlm:::.qdesn_validation_bind_rows(repair_rows)

if (!dry_run) {
  write_df(repair_df, file.path(repair_root_dir, "signoff_repair_method_audit.csv"))
  write_json(file.path(repair_root_dir, "signoff_repair_manifest.json"), list(
    generated_at = as.character(Sys.time()),
    dry_run = FALSE,
    campaign_results_root = campaign_results_root,
    repair_root = repair_root_dir,
    repaired_method_rows = nrow(repair_df),
    repaired_roots = length(unique(as.character(repair_df$root_id %||% character(0)))),
    backup_root = backup_root
  ))
}

cat(sprintf("campaign_results_root: %s\n", campaign_results_root))
cat(sprintf("dry_run: %s\n", if (dry_run) "TRUE" else "FALSE"))
cat(sprintf("repaired_method_rows: %d\n", nrow(repair_df)))
cat(sprintf("repaired_roots: %d\n", length(unique(as.character(repair_df$root_id %||% character(0))))))
if (nrow(repair_df)) {
  cat("\nafter_signoff_grade:\n")
  print(table(repair_df$after_signoff_grade, useNA = "ifany"))
  cat("\nafter_finite_domain:\n")
  print(with(repair_df, table(after_finite_ok, after_domain_ok, useNA = "ifany")))
}

#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default = NULL) {
  idx <- match(flag, args)
  if (is.na(idx) || idx >= length(args)) default else args[[idx + 1L]]
}

split_arg <- function(flag, default) {
  raw <- get_arg(flag, default)
  out <- trimws(unlist(strsplit(as.character(raw), ",", fixed = TRUE)))
  out[nzchar(out)]
}

repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
results_run_root <- get_arg(
  "--results-run-root",
  file.path(
    "results", "qdesn_mcmc_validation",
    "dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation",
    "qdesn-dynamic-p90-steepertrend-n300m50-full-20260424-172949__git-366ca13",
    "20260424-172958__git-366ca13"
  )
)
report_base <- get_arg(
  "--report-base",
  file.path(
    "reports", "qdesn_mcmc_validation",
    "dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fit_overlay_pack"
  )
)
docs_report <- get_arg(
  "--docs-report",
  file.path("docs", "REPORT__qdesn_dynamic_p90_steepertrend_n300m50_fit_overlay_pack_20260427.md")
)
run_tag <- get_arg("--run-tag", NULL)
short_taus <- as.numeric(split_arg("--short-taus", "0.05,0.25,0.50"))
short_fit_sizes <- as.integer(split_arg("--short-fit-sizes", "500"))
long_taus <- as.numeric(split_arg("--long-vb-taus", "0.25"))
long_fit_sizes <- as.integer(split_arg("--long-vb-fit-sizes", "5000"))
families <- split_arg("--families", "normal,laplace,gausmix")
priors <- split_arg("--priors", "ridge,rhs_ns")
last_n <- as.integer(get_arg("--last-n", "500"))
include_long_vb <- !tolower(get_arg("--include-long-vb", "true")) %in% c("false", "no", "0")

resolve_path <- function(path, must_work = FALSE) {
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = must_work)
}

results_run_root <- resolve_path(results_run_root, must_work = TRUE)
report_base <- resolve_path(report_base, must_work = FALSE)
docs_report <- resolve_path(docs_report, must_work = FALSE)

if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("pkgload is required for the QDESN fit overlay pack.", call. = FALSE)
}
pkgload::load_all(repo_root, quiet = TRUE)
.qdesn_validation_require_namespace("ggplot2")

git_sha <- .qdesn_p90_closeout_git_sha(repo_root)
if (is.null(run_tag) || !nzchar(run_tag)) {
  run_tag <- sprintf("qdesn-p90-n300m50-fit-overlay-%s__git-%s", format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
}
output_root <- file.path(report_base, run_tag)
table_dir <- file.path(output_root, "tables")
fig_dir <- file.path(output_root, "figures")
summary_dir <- file.path(output_root, "summary")
manifest_dir <- file.path(output_root, "manifest")
for (d in c(output_root, table_dir, fig_dir, summary_dir, manifest_dir)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

read_root_tables <- function(results_root) {
  files <- Sys.glob(file.path(results_root, "roots", "*", "tables", "fit_summary.csv"))
  if (!length(files)) {
    stop(sprintf("No root fit summaries found under: %s", results_root), call. = FALSE)
  }
  out <- .qdesn_validation_bind_rows(lapply(files, function(path) {
    x <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    x$source_fit_summary_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
    x
  }))
  out$canonical_model <- ifelse(tolower(as.character(out$model)) %in% c("exal", "exdqlm"), "exal", "al")
  out$method_key <- paste(as.character(out$inference), out$canonical_model, sep = "_")
  out$tau <- suppressWarnings(as.numeric(out$tau))
  out$fit_size <- suppressWarnings(as.integer(out$fit_size))
  out
}

fit_summary <- read_root_tables(results_run_root)

root_status_files <- Sys.glob(file.path(results_run_root, "roots", "*", "manifest", "root_status.txt"))
root_status <- .qdesn_validation_bind_rows(lapply(root_status_files, function(path) {
  data.frame(
    root_id = basename(dirname(dirname(path))),
    root_status = trimws(readLines(path, warn = FALSE)[1L]),
    stringsAsFactors = FALSE
  )
}))

plot_case <- function(root_id, layer, inferences, models, last_n_value) {
  sub <- fit_summary[as.character(fit_summary$root_id) == as.character(root_id), , drop = FALSE]
  if (!nrow(sub)) return(NULL)
  sub <- sub[
    as.character(sub$inference) %in% inferences &
      as.character(sub$canonical_model) %in% models,
    ,
    drop = FALSE
  ]
  expected_keys <- unlist(lapply(inferences, function(inference) {
    paste(inference, models, sep = "_")
  }), use.names = FALSE)
  present_keys <- unique(as.character(sub$method_key))
  missing_keys <- setdiff(expected_keys, present_keys)
  existing_files <- file.exists(as.character(sub$fit_file))
  compact_files <- vapply(seq_len(nrow(sub)), function(j) {
    compact_path <- .qdesn_p90_closeout_compact_train_path(sub[j, , drop = FALSE], as.character(sub$fit_file[j]))
    !is.na(compact_path) && nzchar(compact_path) && file.exists(compact_path)
  }, logical(1))
  artifact_ready <- existing_files | compact_files
  if (length(missing_keys) || !all(artifact_ready)) {
    return(data.frame(
      layer = layer,
      root_id = root_id,
      family = as.character(sub$family[1L] %||% NA_character_),
      tau = as.numeric(sub$tau[1L] %||% NA_real_),
      fit_size = as.integer(sub$fit_size[1L] %||% NA_integer_),
      prior = as.character(sub$prior[1L] %||% NA_character_),
      inferences = paste(inferences, collapse = ","),
      models = paste(models, collapse = ","),
      expected_panels = paste(expected_keys, collapse = ","),
      missing_panels = paste(c(missing_keys, sub$method_key[!artifact_ready]), collapse = ","),
      status = "SKIPPED_MISSING_PANEL_OR_FILE",
      path = NA_character_,
      stringsAsFactors = FALSE
    ))
  }

  row0 <- sub[1L, , drop = FALSE]
  filename <- sprintf(
    "%s__%s__tau_%s__tt%d__%s.png",
    layer,
    as.character(row0$family[1L]),
    gsub("\\.", "p", sprintf("%.2f", as.numeric(row0$tau[1L]))),
    as.integer(row0$fit_size[1L]),
    as.character(row0$prior[1L])
  )
  path <- file.path(fig_dir, layer, filename)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  status <- "SUCCESS"
  written <- tryCatch(
    .qdesn_p90_closeout_plot_uncertainty_case(
      fit_summary = fit_summary,
      root_id = root_id,
      output_path = path,
      last_n = last_n_value,
      inferences = inferences,
      models = models
    ),
    error = function(e) {
      status <<- paste("ERROR", conditionMessage(e), sep = ": ")
      NA_character_
    }
  )
  gc(verbose = FALSE)
  data.frame(
    layer = layer,
    root_id = root_id,
    family = as.character(row0$family[1L]),
    tau = as.numeric(row0$tau[1L]),
    fit_size = as.integer(row0$fit_size[1L]),
    prior = as.character(row0$prior[1L]),
    inferences = paste(inferences, collapse = ","),
    models = paste(models, collapse = ","),
    expected_panels = paste(expected_keys, collapse = ","),
    missing_panels = "",
    status = status,
    path = written %||% NA_character_,
    stringsAsFactors = FALSE
  )
}

case_grid_for <- function(layer, taus, fit_sizes) {
  cases <- unique(fit_summary[, c("root_id", "family", "tau", "fit_size", "prior"), drop = FALSE])
  cases <- cases[
    as.character(cases$family) %in% families &
      as.character(cases$prior) %in% priors &
      as.integer(cases$fit_size) %in% fit_sizes &
      vapply(cases$tau, function(x) any(abs(as.numeric(x) - taus) < 1e-8), logical(1)),
    ,
    drop = FALSE
  ]
  cases$layer <- layer
  cases <- cases[order(match(cases$fit_size, fit_sizes), cases$tau, match(cases$prior, priors), match(cases$family, families)), , drop = FALSE]
  rownames(cases) <- NULL
  cases
}

short_cases <- case_grid_for("tt500_all_methods_last500", short_taus, short_fit_sizes)
long_cases <- if (isTRUE(include_long_vb)) {
  case_grid_for("tt5000_vb_only_last500", long_taus, long_fit_sizes)
} else {
  data.frame(stringsAsFactors = FALSE)
}
selected_cases <- .qdesn_validation_bind_rows(list(short_cases, long_cases))

figure_rows <- list()
if (nrow(short_cases)) {
  for (i in seq_len(nrow(short_cases))) {
    row <- short_cases[i, , drop = FALSE]
    message(sprintf("[fit_overlay_pack] short %d/%d | %s", i, nrow(short_cases), row$root_id[1L]))
    figure_rows[[length(figure_rows) + 1L]] <- plot_case(
      root_id = row$root_id[1L],
      layer = row$layer[1L],
      inferences = c("vb", "mcmc"),
      models = c("al", "exal"),
      last_n_value = min(last_n, as.integer(row$fit_size[1L]))
    )
  }
}
if (nrow(long_cases)) {
  for (i in seq_len(nrow(long_cases))) {
    row <- long_cases[i, , drop = FALSE]
    message(sprintf("[fit_overlay_pack] long-vb %d/%d | %s", i, nrow(long_cases), row$root_id[1L]))
    figure_rows[[length(figure_rows) + 1L]] <- plot_case(
      root_id = row$root_id[1L],
      layer = row$layer[1L],
      inferences = c("vb"),
      models = c("al", "exal"),
      last_n_value = last_n
    )
  }
}
figure_index <- .qdesn_validation_bind_rows(figure_rows)

score_cols <- intersect(c(
  "root_id", "family", "tau", "fit_size", "prior", "inference", "canonical_model",
  "status", "signoff_grade", "signoff_reason", "comparison_eligible",
  "train_qtrue_rmse", "train_qtrue_mae", "train_pinball_tau",
  "train_coverage_error", "runtime_sec", "fit_file"
), names(fit_summary))
scorecard <- fit_summary[fit_summary$root_id %in% selected_cases$root_id, score_cols, drop = FALSE]
scorecard <- scorecard[order(scorecard$fit_size, scorecard$tau, scorecard$prior, scorecard$family, scorecard$inference, scorecard$canonical_model), , drop = FALSE]

.qdesn_p90_closeout_write_df(root_status, file.path(table_dir, "root_status.csv"))
.qdesn_p90_closeout_write_df(selected_cases, file.path(table_dir, "selected_cases.csv"))
.qdesn_p90_closeout_write_df(scorecard, file.path(table_dir, "selected_fit_scorecard.csv"))
.qdesn_p90_closeout_write_df(figure_index, file.path(table_dir, "figure_index.csv"))

rel_fig <- function(path) {
  if (is.na(path) || !nzchar(path)) return("_(missing)_")
  rel <- sub(paste0("^", gsub("([\\^\\$\\.\\|\\?\\*\\+\\(\\)\\[\\{\\\\])", "\\\\\\1", output_root), "/?"), "", path)
  sprintf("![](%s)", file.path("..", rel))
}

figure_lines <- unlist(lapply(seq_len(nrow(figure_index)), function(i) {
  row <- figure_index[i, , drop = FALSE]
  c(
    sprintf("### %s / %s / tau %.2f / TT%d / %s",
            row$layer[1L], row$family[1L], row$tau[1L], row$fit_size[1L], row$prior[1L]),
    "",
    sprintf("- root_id: `%s`", row$root_id[1L]),
    sprintf("- panels: `%s`", row$expected_panels[1L]),
    sprintf("- status: `%s`", row$status[1L]),
    "",
    rel_fig(row$path[1L]),
    ""
  )
}), use.names = FALSE)

summary_lines <- c(
  "# QDESN Dynamic P90 Steeper-Trend N300/M50 Fit Overlay Pack",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- git_sha: `%s`", git_sha),
  sprintf("- results_run_root: `%s`", results_run_root),
  sprintf("- output_root: `%s`", output_root),
  sprintf("- selected_cases: `%d`", nrow(selected_cases)),
  sprintf("- figures_success: `%d / %d`", sum(figure_index$status == "SUCCESS", na.rm = TRUE), nrow(figure_index)),
  sprintf("- campaign_roots_success_now: `%d / %d`", sum(root_status$root_status == "SUCCESS", na.rm = TRUE), nrow(root_status)),
  "",
  "## Scope",
  "",
  "- `tt500_all_methods_last500`: all available TT500 roots across selected families, taus, and priors with `VB/AL`, `VB/EXAL`, `MCMC/AL`, and `MCMC/EXAL` panels.",
  "- `tt5000_vb_only_last500`: selected TT5000 roots with VB panels only, to avoid reading the much heavier long-horizon MCMC payloads for a visual-only pass.",
  "- Each panel shows observations, fitted target quantile, known simulated `q_true`, and the posterior quantile uncertainty band.",
  "",
  "## Selected Cases",
  .qdesn_p90_closeout_md_table(selected_cases),
  "",
  "## Figure Index",
  .qdesn_p90_closeout_md_table(figure_index[, intersect(c("layer", "family", "tau", "fit_size", "prior", "status", "path"), names(figure_index)), drop = FALSE]),
  "",
  "## Figures",
  figure_lines
)

.qdesn_p90_closeout_write_lines(summary_lines, file.path(summary_dir, "qdesn_dynamic_p90_steepertrend_n300m50_fit_overlay_pack.md"))
.qdesn_p90_closeout_write_lines(c(
  "# QDESN Dynamic P90 Steeper-Trend N300/M50 Fit Overlay Pack",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- git_sha: `%s`", git_sha),
  sprintf("- output_root: `%s`", output_root),
  sprintf("- summary: `%s`", file.path(output_root, "summary", "qdesn_dynamic_p90_steepertrend_n300m50_fit_overlay_pack.md")),
  sprintf("- figure_index: `%s`", file.path(output_root, "tables", "figure_index.csv")),
  sprintf("- selected_cases: `%d`", nrow(selected_cases)),
  sprintf("- figures_success: `%d / %d`", sum(figure_index$status == "SUCCESS", na.rm = TRUE), nrow(figure_index)),
  "",
  "## Interpretation",
  "",
  "This pack is a visual overlay companion to the metric comparison. It is generated from saved fit objects and does not relaunch model fitting.",
  "The current run is still treated as partial if any campaign root remains `RUNNING` at generation time."
), docs_report)

.qdesn_validation_write_json(file.path(manifest_dir, "fit_overlay_pack_manifest.json"), list(
  generated_at = as.character(Sys.time()),
  git_sha = git_sha,
  repo_root = repo_root,
  results_run_root = results_run_root,
  output_root = output_root,
  docs_report = docs_report,
  short_taus = short_taus,
  short_fit_sizes = short_fit_sizes,
  long_taus = long_taus,
  long_fit_sizes = long_fit_sizes,
  families = families,
  priors = priors,
  last_n = last_n,
  include_long_vb = include_long_vb,
  selected_cases_n = nrow(selected_cases),
  figures_success_n = sum(figure_index$status == "SUCCESS", na.rm = TRUE),
  figures_n = nrow(figure_index)
))

cat(sprintf("Fit overlay pack output_root: %s\n", output_root))
cat(sprintf("Figures: %d / %d successful\n", sum(figure_index$status == "SUCCESS", na.rm = TRUE), nrow(figure_index)))
cat(sprintf("Summary: %s\n", file.path(output_root, "summary", "qdesn_dynamic_p90_steepertrend_n300m50_fit_overlay_pack.md")))

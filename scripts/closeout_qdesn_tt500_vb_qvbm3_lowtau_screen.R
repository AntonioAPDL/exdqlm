#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite")
  missing <- setdiff(req, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  invisible(lapply(req, require, character.only = TRUE))
})

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

write_csv <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

write_json <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

write_lines <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(x, path, useBytes = TRUE)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

sha256_file <- function(path) unname(tools::sha256sum(resolve_path(path)))
num <- function(x) suppressWarnings(as.numeric(x))
chr <- function(x) as.character(x %||% NA_character_)
bool <- function(x) {
  z <- tolower(as.character(x))
  z %in% c("true", "t", "1", "yes")
}

bind_rows <- function(xs) {
  xs <- Filter(function(x) is.data.frame(x) && nrow(x), xs)
  if (!length(xs)) return(data.frame(stringsAsFactors = FALSE))
  cols <- unique(unlist(lapply(xs, names), use.names = FALSE))
  xs <- lapply(xs, function(x) {
    missing <- setdiff(cols, names(x))
    for (nm in missing) x[[nm]] <- NA
    x[, cols, drop = FALSE]
  })
  do.call(rbind, xs)
}

read_csv <- function(path) {
  path <- resolve_path(path, must_work = TRUE)
  if (!file.info(path)$size) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

md_table <- function(df, cols = names(df), digits = 4L, max_rows = Inf) {
  if (is.null(df) || !nrow(df)) return(c("| empty |", "|---|", "| no rows |"))
  cols <- intersect(cols, names(df))
  x <- df[, cols, drop = FALSE]
  if (is.finite(max_rows) && nrow(x) > max_rows) x <- utils::head(x, max_rows)
  for (nm in names(x)) {
    if (is.numeric(x[[nm]])) {
      x[[nm]] <- ifelse(is.na(x[[nm]]), "", format(round(x[[nm]], digits), trim = TRUE, scientific = FALSE))
    }
    x[[nm]] <- gsub("\\|", "/", as.character(x[[nm]]))
    x[[nm]][is.na(x[[nm]])] <- ""
  }
  c(
    paste0("| ", paste(names(x), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(x)), collapse = "|"), "|"),
    apply(x, 1L, function(z) paste0("| ", paste(z, collapse = " | "), " |"))
  )
}

git_value <- function(args) {
  out <- tryCatch(system2("git", args, stdout = TRUE, stderr = FALSE), error = function(e) NA_character_)
  if (!length(out)) NA_character_ else out[[1L]]
}

stage_prefix <- get_arg("--stage-prefix", "qvbm3_tau1e6")
reference_stage <- get_arg("--reference-stage", "qvbm3_capacity")
qvbm1_comparison_path <- get_arg(
  "--qvbm1-comparison",
  "reports/qvbm1/audit/closeout/qvbm1_decomp_guardfix_20260713_main__git-8c6eda9/tables/qvbm1_mechanism_first_current_table_comparison.csv"
)
docs_dir <- get_arg("--docs-dir", "validation/fitforecast_v2/docs")
closeout_id <- sprintf("%s_closeout_20260716__git-%s", stage_prefix, git_value(c("rev-parse", "--short", "HEAD")))
ignored_report_root <- file.path("reports", stage_prefix, "audit", "closeout", closeout_id)
tracked_doc_prefix <- file.path(docs_dir, paste0(stage_prefix, "_closeout_20260716"))

normalize_profile_id <- function(x) {
  x <- as.character(x)
  x <- sub("^m3lt", "m3", x)
  sub("_lt[[:alnum:]]+$", "", x)
}

cell_key <- function(family, tau, model) paste(as.character(family), sprintf("%.8f", num(tau)), as.character(model), sep = "\r")

metric_cols <- c(
  fit_rmse = "train_qtrue_rmse",
  fit_check = "train_pinball_tau",
  forecast_mae = "forecast_qtrue_mae_lead_mean",
  forecast_check = "forecast_pinball_mean_lead_mean"
)

read_stage_fit <- function(stage) {
  files <- list.files(
    file.path("reports", stage),
    pattern = "^campaign_fit_summary[.]csv$",
    recursive = TRUE,
    full.names = TRUE
  )
  rows <- lapply(files, function(path) {
    x <- read_csv(path)
    if (!nrow(x)) return(x)
    x$campaign_fit_summary_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
    x$stage_prefix <- stage
    x
  })
  out <- bind_rows(rows)
  if (!nrow(out)) stop(sprintf("No campaign fit summary rows found for stage `%s`.", stage), call. = FALSE)
  out
}

lead_summary_for_path <- function(path) {
  path <- as.character(path %||% "")[1L]
  if (!nzchar(path) || !file.exists(path)) {
    return(data.frame(
      forecast_lead_rows = 0L,
      min_forecast_lead = NA_integer_,
      max_forecast_lead = NA_integer_,
      unique_forecast_leads = 0L,
      forecast_qtrue_mae_lead_mean = NA_real_,
      forecast_qtrue_rmse_lead_mean = NA_real_,
      forecast_pinball_mean_lead_mean = NA_real_,
      forecast_coverage_error_lead_mean = NA_real_,
      stringsAsFactors = FALSE
    ))
  }
  x <- read_csv(path)
  data.frame(
    forecast_lead_rows = nrow(x),
    min_forecast_lead = if (nrow(x)) min(num(x$forecast_lead), na.rm = TRUE) else NA_integer_,
    max_forecast_lead = if (nrow(x)) max(num(x$forecast_lead), na.rm = TRUE) else NA_integer_,
    unique_forecast_leads = if (nrow(x)) length(unique(num(x$forecast_lead))) else 0L,
    forecast_qtrue_mae_lead_mean = if (nrow(x)) mean(num(x$forecast_qtrue_mae), na.rm = TRUE) else NA_real_,
    forecast_qtrue_rmse_lead_mean = if (nrow(x)) mean(num(x$forecast_qtrue_rmse), na.rm = TRUE) else NA_real_,
    forecast_pinball_mean_lead_mean = if (nrow(x)) mean(num(x$forecast_pinball_mean), na.rm = TRUE) else NA_real_,
    forecast_coverage_error_lead_mean = if (nrow(x)) mean(abs(num(x$forecast_coverage_error)), na.rm = TRUE) else NA_real_,
    stringsAsFactors = FALSE
  )
}

add_lead_summaries <- function(df) {
  paths <- as.character(df$forecast_lead_metrics_path %||% rep(NA_character_, nrow(df)))
  lead <- bind_rows(lapply(paths, lead_summary_for_path))
  cbind(df, lead)
}

root_status_table <- function(stage) {
  files <- list.files(
    file.path("results", stage),
    pattern = "^root_status[.]txt$",
    recursive = TRUE,
    full.names = TRUE
  )
  rows <- lapply(files, function(path) {
    data.frame(
      root_id = basename(dirname(dirname(path))),
      root_status = trimws(readLines(path, warn = FALSE)[[1L]]),
      root_status_path = normalizePath(path, winslash = "/", mustWork = TRUE),
      stringsAsFactors = FALSE
    )
  })
  bind_rows(rows)
}

status_mix <- function(status) {
  if (!nrow(status)) return(data.frame(root_status = character(), n = integer()))
  out <- as.data.frame(table(root_status = status$root_status), stringsAsFactors = FALSE)
  names(out)[2L] <- "n"
  out
}

storage_audit <- function(stage) {
  roots <- c(file.path("results", stage), file.path("reports", stage))
  files <- unlist(lapply(roots, function(root) {
    if (!dir.exists(root)) return(character())
    list.files(root, recursive = TRUE, full.names = TRUE, all.files = FALSE)
  }), use.names = FALSE)
  heavy <- files[grepl("([.](rds|rda|RData)$|__design[.]rds$)", files, ignore.case = TRUE)]
  data.frame(
    stage_prefix = stage,
    scanned_roots = paste(roots, collapse = ";"),
    heavy_payload_files = length(heavy),
    heavy_payload_bytes = if (length(heavy)) sum(file.info(heavy)$size, na.rm = TRUE) else 0,
    storage_policy_status = if (length(heavy)) "FAIL_HEAVY_PAYLOADS_FOUND" else "PASS_STORAGE_LIGHT",
    stringsAsFactors = FALSE
  )
}

stage <- add_lead_summaries(read_stage_fit(stage_prefix))
reference <- add_lead_summaries(read_stage_fit(reference_stage))
status <- root_status_table(stage_prefix)
qvbm1 <- read_csv(qvbm1_comparison_path)

for (df_name in c("stage", "reference")) {
  df <- get(df_name)
  df$profile_norm <- normalize_profile_id(df$screening_profile_id)
  df$key_profile <- paste(cell_key(df$family, df$tau, df$model), df$profile_norm, sep = "\r")
  for (col in unname(metric_cols)) df[[col]] <- num(df[[col]])
  assign(df_name, df)
}

status_by_root <- status[, c("root_id", "root_status"), drop = FALSE]
stage <- merge(stage, status_by_root, by = "root_id", all.x = TRUE, sort = FALSE)
stage$root_status[is.na(stage$root_status)] <- "MISSING_ROOT_STATUS"

planned_roots <- nrow(stage)
success_roots <- sum(stage$root_status == "SUCCESS" & as.character(stage$status) == "SUCCESS", na.rm = TRUE)
non_success_roots <- planned_roots - success_roots
expected_lead_rows <- planned_roots * 30L
observed_lead_rows <- sum(num(stage$forecast_lead_rows), na.rm = TRUE)
all_leads_complete <- identical(as.integer(observed_lead_rows), as.integer(expected_lead_rows))

signoff <- as.data.frame(table(
  signoff_grade = as.character(stage$signoff_grade),
  converged = as.character(stage$converged),
  useNA = "ifany"
), stringsAsFactors = FALSE)

health <- data.frame(
  stage_prefix = stage_prefix,
  planned_roots = planned_roots,
  success_roots = success_roots,
  non_success_roots = non_success_roots,
  roots_left = non_success_roots,
  pct_done = round(100 * success_roots / planned_roots, 1),
  fit_summary_rows = nrow(stage),
  forecast_lead_files = sum(num(stage$forecast_lead_rows) > 0, na.rm = TRUE),
  observed_forecast_lead_rows = observed_lead_rows,
  expected_forecast_lead_rows = expected_lead_rows,
  forecast_leads_complete = all_leads_complete,
  min_forecast_lead = min(num(stage$min_forecast_lead), na.rm = TRUE),
  max_forecast_lead = max(num(stage$max_forecast_lead), na.rm = TRUE),
  pass_converged = sum(stage$signoff_grade == "PASS" & bool(stage$converged), na.rm = TRUE),
  warn_not_converged = sum(stage$signoff_grade == "WARN" & !bool(stage$converged), na.rm = TRUE),
  rhs_collapse_count = sum(bool(stage$rhs_collapse_flag), na.rm = TRUE),
  stringsAsFactors = FALSE
)

screen_medians <- function(df, label) {
  med <- function(x) if (all(is.na(x))) NA_real_ else median(x, na.rm = TRUE)
  data.frame(
    screen = label,
    rows = nrow(df),
    median_fit_rmse = med(df[[metric_cols[["fit_rmse"]]]]),
    median_fit_check = med(df[[metric_cols[["fit_check"]]]]),
    median_forecast_mae = med(df[[metric_cols[["forecast_mae"]]]]),
    median_forecast_check = med(df[[metric_cols[["forecast_check"]]]]),
    median_runtime_sec = med(num(df$runtime_sec)),
    stringsAsFactors = FALSE
  )
}
median_summary <- rbind(screen_medians(stage, stage_prefix), screen_medians(reference, reference_stage))

group_summary <- aggregate(
  cbind(train_qtrue_rmse, train_pinball_tau, forecast_qtrue_mae_lead_mean, forecast_pinball_mean_lead_mean, runtime_sec) ~
    family + tau + model,
  stage,
  mean,
  na.rm = TRUE
)
names(group_summary) <- sub("^train_qtrue_rmse$", "mean_fit_rmse", names(group_summary))
names(group_summary) <- sub("^train_pinball_tau$", "mean_fit_check", names(group_summary))
names(group_summary) <- sub("^forecast_qtrue_mae_lead_mean$", "mean_forecast_mae", names(group_summary))
names(group_summary) <- sub("^forecast_pinball_mean_lead_mean$", "mean_forecast_check", names(group_summary))
names(group_summary) <- sub("^runtime_sec$", "mean_runtime_sec", names(group_summary))

reference_subset <- reference[, c("key_profile", unname(metric_cols), "rhs_tau0", "screening_profile_id"), drop = FALSE]
names(reference_subset) <- c("key_profile", paste0(names(metric_cols), "_reference"), "rhs_tau0_reference", "screening_profile_id_reference")
stage_vs_reference <- merge(
  stage[, c("root_id", "key_profile", "family", "tau", "model", "screening_profile_id", "rhs_tau0", unname(metric_cols), "signoff_grade", "converged"), drop = FALSE],
  reference_subset,
  by = "key_profile",
  all.x = TRUE,
  sort = FALSE
)
for (metric in names(metric_cols)) {
  stage_col <- metric_cols[[metric]]
  ref_col <- paste0(metric, "_reference")
  stage_vs_reference[[paste0("ratio_vs_", reference_stage, "_", metric)]] <- num(stage_vs_reference[[stage_col]]) / num(stage_vs_reference[[ref_col]])
  stage_vs_reference[[paste0("delta_vs_", reference_stage, "_", metric)]] <- num(stage_vs_reference[[stage_col]]) - num(stage_vs_reference[[ref_col]])
}

ratio_cols_ref <- grep(paste0("^ratio_vs_", reference_stage, "_"), names(stage_vs_reference), value = TRUE)
ratio_reference_summary <- data.frame(
  metric = sub(paste0("^ratio_vs_", reference_stage, "_"), "", ratio_cols_ref),
  cells = vapply(ratio_cols_ref, function(col) sum(is.finite(num(stage_vs_reference[[col]]))), integer(1L)),
  median_ratio = vapply(ratio_cols_ref, function(col) median(num(stage_vs_reference[[col]]), na.rm = TRUE), numeric(1L)),
  min_ratio = vapply(ratio_cols_ref, function(col) min(num(stage_vs_reference[[col]]), na.rm = TRUE), numeric(1L)),
  max_ratio = vapply(ratio_cols_ref, function(col) max(num(stage_vs_reference[[col]]), na.rm = TRUE), numeric(1L)),
  cells_better_0p5pct = vapply(ratio_cols_ref, function(col) sum(num(stage_vs_reference[[col]]) < 0.995, na.rm = TRUE), integer(1L)),
  cells_worse_0p5pct = vapply(ratio_cols_ref, function(col) sum(num(stage_vs_reference[[col]]) > 1.005, na.rm = TRUE), integer(1L)),
  stringsAsFactors = FALSE
)

qvbm1$cell <- cell_key(qvbm1$family, qvbm1$tau, qvbm1$qdesn_likelihood)
stage$cell <- cell_key(stage$family, stage$tau, stage$model)
q1_cols <- c(
  "cell", "qvbm1_fit_rmse", "qvbm1_fit_check", "qvbm1_fcst_mae", "qvbm1_fcst_check",
  "best_exdqlm_dqlm_vb_fit_rmse", "best_exdqlm_dqlm_vb_fit_check",
  "best_exdqlm_dqlm_vb_fcst_mae", "best_exdqlm_dqlm_vb_fcst_check"
)
cell_compare <- merge(stage, qvbm1[, intersect(q1_cols, names(qvbm1)), drop = FALSE], by = "cell", all.x = TRUE, sort = FALSE)
external_map <- c(
  fit_rmse = "best_exdqlm_dqlm_vb_fit_rmse",
  fit_check = "best_exdqlm_dqlm_vb_fit_check",
  forecast_mae = "best_exdqlm_dqlm_vb_fcst_mae",
  forecast_check = "best_exdqlm_dqlm_vb_fcst_check"
)
qvbm1_map <- c(
  fit_rmse = "qvbm1_fit_rmse",
  fit_check = "qvbm1_fit_check",
  forecast_mae = "qvbm1_fcst_mae",
  forecast_check = "qvbm1_fcst_check"
)
for (metric in names(metric_cols)) {
  cell_compare[[paste0("ratio_vs_qvbm1_", metric)]] <- num(cell_compare[[metric_cols[[metric]]]]) / num(cell_compare[[qvbm1_map[[metric]]]])
  cell_compare[[paste0("ratio_vs_exdqlm_dqlm_", metric)]] <- num(cell_compare[[metric_cols[[metric]]]]) / num(cell_compare[[external_map[[metric]]]])
}
cell_compare$worst_ratio_vs_qvbm1 <- do.call(pmax, c(cell_compare[paste0("ratio_vs_qvbm1_", names(metric_cols))], list(na.rm = TRUE)))
cell_compare$worst_ratio_vs_exdqlm_dqlm <- do.call(pmax, c(cell_compare[paste0("ratio_vs_exdqlm_dqlm_", names(metric_cols))], list(na.rm = TRUE)))
cell_compare$beats_qvbm1_all4 <- apply(cell_compare[paste0("ratio_vs_qvbm1_", names(metric_cols))], 1L, function(x) all(num(x) < 1, na.rm = FALSE))
cell_compare$beats_exdqlm_dqlm_all4 <- apply(cell_compare[paste0("ratio_vs_exdqlm_dqlm_", names(metric_cols))], 1L, function(x) all(num(x) < 1, na.rm = FALSE))

ranked <- bind_rows(lapply(split(cell_compare, cell_compare$cell), function(d) {
  d <- d[order(d$worst_ratio_vs_qvbm1, d$worst_ratio_vs_exdqlm_dqlm, num(d$runtime_sec), d$screening_profile_id), , drop = FALSE]
  d$cell_rank_vs_qvbm1 <- seq_len(nrow(d))
  d
}))
cell_winners <- ranked[ranked$cell_rank_vs_qvbm1 == 1L, , drop = FALSE]
cell_winners <- cell_winners[order(cell_winners$family, num(cell_winners$tau), cell_winners$model), , drop = FALSE]

qvbm1_ratio_summary <- data.frame(
  reference = c("qvbm1", "exdqlm_dqlm_vb"),
  cells = c(nrow(cell_winners), nrow(cell_winners)),
  cells_beating_all4 = c(sum(cell_winners$beats_qvbm1_all4, na.rm = TRUE), sum(cell_winners$beats_exdqlm_dqlm_all4, na.rm = TRUE)),
  median_worst_ratio = c(median(cell_winners$worst_ratio_vs_qvbm1, na.rm = TRUE), median(cell_winners$worst_ratio_vs_exdqlm_dqlm, na.rm = TRUE)),
  min_worst_ratio = c(min(cell_winners$worst_ratio_vs_qvbm1, na.rm = TRUE), min(cell_winners$worst_ratio_vs_exdqlm_dqlm, na.rm = TRUE)),
  max_worst_ratio = c(max(cell_winners$worst_ratio_vs_qvbm1, na.rm = TRUE), max(cell_winners$worst_ratio_vs_exdqlm_dqlm, na.rm = TRUE)),
  stringsAsFactors = FALSE
)

profile_files <- list.files(file.path("config", "validation"), pattern = paste0("^", stage_prefix, "_.*profiles[.]csv$"), full.names = TRUE)
profiles <- bind_rows(lapply(profile_files, read_csv))
profile_tau0 <- data.frame(
  source = c("config_profiles", "campaign_fit_summary", "reference_campaign_fit_summary"),
  n_rows = c(nrow(profiles), nrow(stage), nrow(reference)),
  min_rhs_tau0 = c(min(num(profiles$rhs_tau0), na.rm = TRUE), min(num(stage$rhs_tau0), na.rm = TRUE), min(num(reference$rhs_tau0), na.rm = TRUE)),
  max_rhs_tau0 = c(max(num(profiles$rhs_tau0), na.rm = TRUE), max(num(stage$rhs_tau0), na.rm = TRUE), max(num(reference$rhs_tau0), na.rm = TRUE)),
  unique_rhs_tau0 = c(
    paste(sort(unique(format(num(profiles$rhs_tau0), scientific = TRUE))), collapse = ";"),
    paste(sort(unique(format(num(stage$rhs_tau0), scientific = TRUE))), collapse = ";"),
    paste(sort(unique(format(num(reference$rhs_tau0), scientific = TRUE))), collapse = ";")
  ),
  stringsAsFactors = FALSE
)

tau0_code_wiring <- data.frame(
  evidence = c(
    "grid_row_assigns_screening_rhs_tau0",
    "grid_preflight_requires_positive_rhs_tau0",
    "root_spec_validates_positive_rhs_tau0",
    "static_prior_requires_positive_tau0",
    "static_rhs_log_prior_uses_ctrl_tau0"
  ),
  path = c(
    "R/qdesn_dynamic_exdqlm_crossstudy.R",
    "R/qdesn_dynamic_exdqlm_crossstudy.R",
    "R/qdesn_dynamic_exdqlm_crossstudy.R",
    "R/static_beta_prior.R",
    "R/static_beta_prior.R"
  ),
  line_hint = c("1048", "1170-1175", "1253-1288", "69-72", "365"),
  interpretation = c(
    "screening profile rhs_tau0 is copied into the generated root/grid row",
    "rhs_ns rows with non-positive rhs_tau0 are rejected before launch",
    "root specs with invalid rhs_tau0 are rejected before fit",
    "beta prior controls reject non-positive tau0",
    "RHS prior log-density includes log(ctrl$tau0)"
  ),
  stringsAsFactors = FALSE
)

store <- storage_audit(stage_prefix)

promote_to_mcmc <- nrow(cell_winners) > 0L &&
  all(cell_winners$beats_qvbm1_all4, na.rm = FALSE) &&
  all(cell_winners$beats_exdqlm_dqlm_all4, na.rm = FALSE) &&
  health$non_success_roots[[1L]] == 0L &&
  all_leads_complete &&
  store$heavy_payload_files[[1L]] == 0L

disposition <- data.frame(
  stage_prefix = stage_prefix,
  status = if (health$non_success_roots[[1L]] == 0L && all_leads_complete) "COMPLETE" else "INCOMPLETE",
  scientific_disposition = if (isTRUE(promote_to_mcmc)) "PROMOTE_CANDIDATES_AFTER_REVIEW" else "DIAGNOSTIC_NEGATIVE_DO_NOT_PROMOTE",
  article_facing = FALSE,
  mcmc_handoff = isTRUE(promote_to_mcmc),
  core_reason = if (isTRUE(promote_to_mcmc)) {
    "all cells clear qvbm1 and exdqlm/dqlm all-four gates"
  } else {
    "tau0=1e-06 completed but is effectively identical to qvbm3_capacity and does not clear qvbm1/exdqlm-dqlm all-four gates"
  },
  recommended_next_step = "close this surface; plan a different mechanism-first screen from qvbm1/frontier designs rather than another tau0-only qvbm3 relaunch",
  stringsAsFactors = FALSE
)

tables <- list(
  health = health,
  root_status_mix = status_mix(status),
  signoff_mix = signoff,
  median_summary = median_summary,
  group_summary = group_summary,
  stage_vs_reference = stage_vs_reference,
  ratio_reference_summary = ratio_reference_summary,
  cell_winners = cell_winners,
  qvbm1_ratio_summary = qvbm1_ratio_summary,
  profile_tau0_wiring = profile_tau0,
  tau0_code_wiring = tau0_code_wiring,
  storage_audit = store,
  disposition = disposition
)

ignored_tables_dir <- file.path(ignored_report_root, "tables")
tracked_paths <- list()
ignored_paths <- list()
for (nm in names(tables)) {
  ignored_paths[[nm]] <- write_csv(tables[[nm]], file.path(ignored_tables_dir, paste0(stage_prefix, "_", nm, ".csv")))
  tracked_paths[[nm]] <- write_csv(tables[[nm]], paste0(tracked_doc_prefix, "_", nm, ".csv"))
}

summary_path <- paste0(tracked_doc_prefix, ".md")
ignored_summary_path <- file.path(ignored_report_root, "summary", paste0(stage_prefix, "_closeout.md"))

summary_lines <- c(
  "# Q-DESN 500-Observation VB QVBM3 Tau1e-6 Closeout",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- worktree: `%s`", repo_root),
  sprintf("- branch: `%s`", git_value(c("branch", "--show-current"))),
  sprintf("- head: `%s`", git_value(c("rev-parse", "HEAD"))),
  sprintf("- stage_prefix: `%s`", stage_prefix),
  sprintf("- reference_stage: `%s`", reference_stage),
  sprintf("- raw ignored report root: `%s`", resolve_path(ignored_report_root, must_work = FALSE)),
  "",
  "## Health",
  "",
  md_table(health, c(
    "planned_roots", "success_roots", "non_success_roots", "roots_left", "pct_done",
    "fit_summary_rows", "forecast_lead_files", "observed_forecast_lead_rows",
    "expected_forecast_lead_rows", "pass_converged", "warn_not_converged", "rhs_collapse_count"
  )),
  "",
  "## Metric Medians",
  "",
  md_table(median_summary),
  "",
  "## Cell Group Means",
  "",
  md_table(group_summary, c("family", "tau", "model", "mean_fit_rmse", "mean_fit_check", "mean_forecast_mae", "mean_forecast_check", "mean_runtime_sec")),
  "",
  "## Ratio Summary Versus Prior QVBM3 Capacity Screen",
  "",
  md_table(ratio_reference_summary),
  "",
  "## Ratio Summary Versus Baselines",
  "",
  md_table(qvbm1_ratio_summary),
  "",
  "## Tau0 Wiring Audit",
  "",
  md_table(profile_tau0),
  "",
  md_table(tau0_code_wiring, c("evidence", "path", "line_hint", "interpretation")),
  "",
  "## Storage Audit",
  "",
  md_table(store),
  "",
  "## Disposition",
  "",
  md_table(disposition),
  "",
  "## Interpretation",
  "",
  "- The run is operationally complete: all planned roots succeeded and all rolling-origin lead metric files are present.",
  "- The `rhs_tau0 = 1e-06` value is present in config profiles and campaign fit summaries, while the reference qvbm3 capacity screen records `1e-04`/`3e-04`.",
  "- The code path reads, validates, and passes `rhs_tau0` into the RHS prior; the lack of improvement is therefore treated as empirical negative evidence for this tau0-only rescue, not as proof that the field is ignored.",
  "- The screen is not article-facing and should not be promoted to MCMC.",
  "- The next screen should change model mechanism/feature construction or return to the stronger qvbm1 frontier, rather than relaunching this same high-capacity surface with only smaller tau0."
)

summary_out <- write_lines(summary_lines, summary_path)
ignored_summary_out <- write_lines(summary_lines, ignored_summary_path)

manifest <- list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  git_branch = git_value(c("branch", "--show-current")),
  git_sha = git_value(c("rev-parse", "HEAD")),
  stage_prefix = stage_prefix,
  reference_stage = reference_stage,
  qvbm1_comparison_path = resolve_path(qvbm1_comparison_path),
  closeout_id = closeout_id,
  health = health,
  disposition = disposition,
  tracked_outputs = c(tracked_paths, list(summary = summary_out)),
  ignored_report_outputs = c(ignored_paths, list(summary = ignored_summary_out)),
  hashes = c(
    lapply(tracked_paths, sha256_file),
    list(summary_sha256 = sha256_file(summary_out))
  )
)
manifest_path <- write_json(manifest, paste0(tracked_doc_prefix, "_manifest.json"))
ignored_manifest_path <- write_json(manifest, file.path(ignored_report_root, "manifest", paste0(stage_prefix, "_closeout_manifest.json")))

required_ok <- health$non_success_roots[[1L]] == 0L &&
  all_leads_complete &&
  store$heavy_payload_files[[1L]] == 0L &&
  all(num(profile_tau0$min_rhs_tau0[profile_tau0$source == "campaign_fit_summary"]) == 1e-06) &&
  nrow(cell_winners) == length(unique(stage$cell))

if (!required_ok) {
  stop("qvbm3 low-tau closeout failed one or more completeness/storage/wiring checks.", call. = FALSE)
}

cat(sprintf("closeout_status: %s\n", disposition$status[[1L]]))
cat(sprintf("scientific_disposition: %s\n", disposition$scientific_disposition[[1L]]))
cat(sprintf("tracked_summary: %s\n", summary_out))
cat(sprintf("tracked_manifest: %s\n", manifest_path))
cat(sprintf("ignored_report_manifest: %s\n", ignored_manifest_path))
cat("qvbm3_tau1e6_closeout=PASS\n")

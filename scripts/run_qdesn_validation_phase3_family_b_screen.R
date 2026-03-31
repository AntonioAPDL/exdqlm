#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("yaml", "jsonlite")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
has_flag <- function(flag) any(args == flag)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

usage <- function() {
  cat(
    "Usage: scripts/run_qdesn_validation_phase3_family_b_screen.R [options]\n\n",
    "Options:\n",
    "  --manifest <path>   Family-B screen manifest YAML.\n",
    "  --run-tag <tag>     Screen run tag.\n",
    "  --execute           Run the staged screen.\n",
    "  --prepare-only      Prepare artifacts only (default).\n",
    "  --help              Print this help.\n",
    sep = ""
  )
}

if (has_flag("--help")) {
  usage()
  quit(status = 0)
}

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

dir_create <- function(path) dir.create(path, recursive = TRUE, showWarnings = FALSE)

read_csv_safe <- function(path) {
  if (is.null(path) || !file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

write_json_safe <- function(x, path) {
  dir_create(dirname(path))
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
}

write_lines_safe <- function(lines, path) {
  dir_create(dirname(path))
  writeLines(lines, path)
}

deep_merge <- function(x, y) {
  if (!is.list(x) || !is.list(y)) return(y)
  out <- x
  for (nm in names(y)) {
    if (is.list(out[[nm]]) && is.list(y[[nm]])) {
      out[[nm]] <- deep_merge(out[[nm]], y[[nm]])
    } else {
      out[[nm]] <- y[[nm]]
    }
  }
  out
}

safe_num <- function(x, default = NA_real_) {
  x <- suppressWarnings(as.numeric(x))
  if (!length(x) || !is.finite(x[1L])) default else x[1L]
}

safe_int <- function(x, default = NA_integer_) {
  x <- suppressWarnings(as.integer(x))
  if (!length(x) || is.na(x[1L])) default else x[1L]
}

safe_chr <- function(x, default = NA_character_) {
  x <- as.character(x %||% default)
  if (!length(x)) default else x[1L]
}

safe_lgl <- function(x, default = FALSE) {
  x <- as.logical(x)
  if (!length(x) || is.na(x[1L])) default else isTRUE(x[1L])
}

grade_score <- function(x) {
  x <- toupper(trimws(as.character(x %||% NA_character_)))
  ifelse(
    x == "PASS", 2L,
    ifelse(x == "WARN", 1L, ifelse(x == "FAIL", 0L, NA_integer_))
  )
}

build_key <- function(df) {
  cols <- c("scenario", "tau", "likelihood_family", "beta_prior_type", "seed", "reservoir_profile")
  cols <- cols[cols %in% names(df)]
  if (!length(cols)) return(character(nrow(df)))
  do.call(paste, c(df[, cols, drop = FALSE], sep = "||"))
}

render_markdown_table <- function(df) {
  if (!is.data.frame(df) || !nrow(df) || !ncol(df)) return(c("| empty |", "|---|"))
  fmt <- function(x) {
    x <- as.character(x)
    x[is.na(x) | !nzchar(x)] <- "NA"
    x
  }
  hdr <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |")
  rows <- apply(df, 1L, function(row) paste0("| ", paste(fmt(row), collapse = " | "), " |"))
  c(hdr, sep, rows)
}

select_stage_roots <- function(selector, micro_roots) {
  mode <- tolower(trimws(as.character((selector %||% list())$mode %||% "all")))[1L]
  if (!nrow(micro_roots)) stop("Micro roots table is empty.", call. = FALSE)

  if (identical(mode, "all")) return(micro_roots)

  if (identical(mode, "failure_cluster")) {
    clusters <- as.character((selector %||% list())$failure_clusters %||% character(0))
    out <- micro_roots[as.character(micro_roots$failure_cluster) %in% clusters, , drop = FALSE]
    return(out)
  }

  if (identical(mode, "exact_root")) {
    out <- micro_roots
    fields <- c("scenario", "likelihood_family", "beta_prior_type", "seed", "reservoir_profile")
    for (nm in fields) {
      target <- (selector %||% list())[[nm]]
      if (!is.null(target) && nm %in% names(out)) {
        out <- out[as.character(out[[nm]]) == as.character(target)[1L], , drop = FALSE]
      }
    }
    if ("tau" %in% names(out) && !is.null(selector$tau)) {
      tau_target <- safe_num(selector$tau)
      out <- out[abs(suppressWarnings(as.numeric(out$tau)) - tau_target) < 1e-10, , drop = FALSE]
    }
    return(out)
  }

  stop(sprintf("Unsupported stage selector mode '%s'.", mode), call. = FALSE)
}

prepare_stage_phase01 <- function(stage_id, stage_dir, phase01, selected_roots, micro_grid) {
  selected_roots$root_join_key <- build_key(selected_roots)
  selected_grid <- micro_grid[micro_grid$root_join_key %in% selected_roots$root_join_key, , drop = FALSE]
  if (!nrow(selected_grid)) stop(sprintf("Stage %s selected no grid rows.", stage_id), call. = FALSE)

  configs_dir <- file.path(stage_dir, "configs")
  tables_dir <- file.path(stage_dir, "tables")
  summary_dir <- file.path(stage_dir, "summary")
  for (d in c(configs_dir, tables_dir, summary_dir)) dir_create(d)

  micro_grid_stage <- file.path(configs_dir, "micro_pilot_grid.csv")
  micro_roots_stage <- file.path(tables_dir, "phase01_micro_pilot_roots_selected.csv")
  utils::write.csv(selected_grid[, setdiff(names(selected_grid), "root_join_key"), drop = FALSE], micro_grid_stage, row.names = FALSE)
  utils::write.csv(selected_roots[, setdiff(names(selected_roots), "root_join_key"), drop = FALSE], micro_roots_stage, row.names = FALSE)

  phase01_stage <- phase01
  phase01_stage$files <- phase01_stage$files %||% list()
  phase01_stage$files$micro_grid <- micro_grid_stage
  phase01_stage$files$micro_roots <- micro_roots_stage

  phase01_stage_path <- file.path(summary_dir, "phase01_manifest.json")
  write_json_safe(phase01_stage, phase01_stage_path)

  list(
    phase01_stage_path = phase01_stage_path,
    micro_grid_stage = micro_grid_stage,
    micro_roots_stage = micro_roots_stage,
    selected_roots = selected_roots,
    selected_grid = selected_grid
  )
}

filter_profiles_for_stage <- function(all_profiles_cfg, anchor_profile_id, profile_source, prev_selected_ids = character(0)) {
  prof_ids <- vapply(all_profiles_cfg, function(p) safe_chr(p$id, ""), character(1))
  keep_ids <- character(0)
  if (identical(profile_source, "all_candidates")) {
    keep_ids <- setdiff(prof_ids, anchor_profile_id)
  } else if (identical(profile_source, "selected_from_previous")) {
    keep_ids <- intersect(prev_selected_ids, prof_ids)
  } else if (identical(profile_source, "explicit")) {
    stop("Explicit stage profile selection is not implemented.", call. = FALSE)
  } else {
    stop(sprintf("Unsupported stage profile_source '%s'.", profile_source), call. = FALSE)
  }

  keep_all <- c(anchor_profile_id, keep_ids)
  out <- all_profiles_cfg[prof_ids %in% keep_all]
  out
}

collect_stage_mcmc_config <- function(stage_report_root, selected_roots) {
  exec_tbl <- read_csv_safe(file.path(stage_report_root, "tables", "profile_execution_status.csv"))
  if (!nrow(exec_tbl) || !"report_root" %in% names(exec_tbl)) return(data.frame(stringsAsFactors = FALSE))

  selected_roots$root_join_key <- build_key(selected_roots)
  keep <- c(
    "root_join_key", "scenario", "tau", "likelihood_family", "beta_prior_type", "seed", "reservoir_profile",
    "mcmc_core_update_mode", "mcmc_core_extra_passes", "mcmc_use_log_sigma",
    "mcmc_width_gamma", "mcmc_width_sigma", "mcmc_max_steps_out", "mcmc_max_shrink",
    "mcmc_max_steps_out_sigma", "mcmc_max_shrink_sigma",
    "mcmc_conditioning_mode", "mcmc_conditioning_active", "mcmc_conditioning_raw_kappa",
    "mcmc_conditioning_work_kappa", "mcmc_conditioning_gain_ratio", "mcmc_conditioning_scaled_columns_n"
  )

  out <- list()
  for (ii in seq_len(nrow(exec_tbl))) {
    profile_id <- safe_chr(exec_tbl$profile_id[ii], sprintf("P%d", ii))
    report_root <- resolve_path(exec_tbl$report_root[ii], must_work = FALSE)
    method_tbl <- read_csv_safe(file.path(report_root, "tables", "campaign_method_summary.csv"))
    if (!nrow(method_tbl)) next
    method_tbl$root_join_key <- build_key(method_tbl)
    method_tbl <- method_tbl[
      method_tbl$root_join_key %in% selected_roots$root_join_key &
        as.character(method_tbl$method) == "mcmc",
    , drop = FALSE]
    if (!nrow(method_tbl)) next

    keep_i <- keep[keep %in% names(method_tbl)]
    out[[length(out) + 1L]] <- cbind(
      data.frame(profile_id = profile_id, stringsAsFactors = FALSE),
      method_tbl[, keep_i, drop = FALSE]
    )
  }

  if (!length(out)) return(data.frame(stringsAsFactors = FALSE))
  do.call(rbind, out)
}

evaluate_canary_candidates <- function(stage_report_root, candidate_profiles, gate_cfg) {
  exec_tbl <- read_csv_safe(file.path(stage_report_root, "tables", "profile_execution_status.csv"))
  rows <- lapply(candidate_profiles, function(profile_id) {
    exec_row <- exec_tbl[as.character(exec_tbl$profile_id) == profile_id, , drop = FALSE]
    trans_tbl <- read_csv_safe(file.path(stage_report_root, "tables", sprintf("phase35_transitions_%s.csv", profile_id)))
    trans_row <- if (nrow(trans_tbl)) trans_tbl[1L, , drop = FALSE] else data.frame(stringsAsFactors = FALSE)

    grade_base <- safe_chr(trans_row$signoff_grade_base, NA_character_)
    grade_prof <- safe_chr(trans_row$signoff_grade_prof, NA_character_)
    ess_base <- safe_num(trans_row$mcmc_min_ess_core_base)
    ess_prof <- safe_num(trans_row$mcmc_min_ess_core_prof)
    geweke_base <- safe_num(trans_row$mcmc_max_geweke_absz_core_base)
    geweke_prof <- safe_num(trans_row$mcmc_max_geweke_absz_core_prof)
    half_base <- safe_num(trans_row$mcmc_max_half_drift_core_base)
    half_prof <- safe_num(trans_row$mcmc_max_half_drift_core_prof)
    runtime_base <- safe_num(trans_row$fit_runtime_seconds_base)
    runtime_prof <- safe_num(trans_row$fit_runtime_seconds_prof)

    delta_ess <- ess_prof - ess_base
    ess_ratio <- if (is.finite(ess_base) && ess_base > 0) ess_prof / ess_base else NA_real_
    delta_geweke <- geweke_prof - geweke_base
    geweke_improvement_abs <- geweke_base - geweke_prof
    delta_half <- half_prof - half_base
    runtime_inflation <- if (is.finite(runtime_base) && runtime_base > 0) runtime_prof / runtime_base - 1 else NA_real_
    grade_prof_score <- grade_score(grade_prof)
    grade_base_score <- grade_score(grade_base)

    candidate_pass <- isTRUE(safe_lgl(exec_row$operational_pass, FALSE)) &&
      (is.na(safe_num(gate_cfg$min_prof_ess_core)) || ess_prof >= safe_num(gate_cfg$min_prof_ess_core)) &&
      (is.na(safe_num(gate_cfg$min_ess_ratio)) || ess_ratio >= safe_num(gate_cfg$min_ess_ratio)) &&
      (is.na(safe_num(gate_cfg$max_prof_geweke_absz)) || geweke_prof <= safe_num(gate_cfg$max_prof_geweke_absz)) &&
      (is.na(safe_num(gate_cfg$min_geweke_improvement_abs)) || geweke_improvement_abs >= safe_num(gate_cfg$min_geweke_improvement_abs)) &&
      (is.na(safe_num(gate_cfg$max_prof_half_drift)) || half_prof <= safe_num(gate_cfg$max_prof_half_drift)) &&
      (is.na(safe_num(gate_cfg$max_delta_half_drift_increase)) || delta_half <= safe_num(gate_cfg$max_delta_half_drift_increase)) &&
      (is.na(safe_num(gate_cfg$max_runtime_inflation)) || runtime_inflation <= safe_num(gate_cfg$max_runtime_inflation)) &&
      (is.na(grade_prof_score) || is.na(grade_base_score) || grade_prof_score >= grade_base_score)

    data.frame(
      profile_id = profile_id,
      execution_status = safe_chr(exec_row$execution_status, "MISSING"),
      operational_pass = safe_lgl(exec_row$operational_pass, FALSE),
      signoff_grade_base = grade_base,
      signoff_grade_prof = grade_prof,
      fit_runtime_seconds_base = runtime_base,
      fit_runtime_seconds_prof = runtime_prof,
      runtime_inflation = runtime_inflation,
      mcmc_min_ess_core_base = ess_base,
      mcmc_min_ess_core_prof = ess_prof,
      ess_ratio = ess_ratio,
      delta_ess_core = delta_ess,
      mcmc_max_geweke_absz_core_base = geweke_base,
      mcmc_max_geweke_absz_core_prof = geweke_prof,
      geweke_improvement_abs = geweke_improvement_abs,
      delta_geweke_absz = delta_geweke,
      mcmc_max_half_drift_core_base = half_base,
      mcmc_max_half_drift_core_prof = half_prof,
      delta_half_drift = delta_half,
      candidate_pass = candidate_pass,
      stringsAsFactors = FALSE
    )
  })

  df <- do.call(rbind, rows)
  df <- df[order(
    !as.logical(df$candidate_pass),
    -grade_score(df$signoff_grade_prof),
    as.numeric(df$mcmc_max_half_drift_core_prof),
    -as.numeric(df$mcmc_min_ess_core_prof),
    as.numeric(df$mcmc_max_geweke_absz_core_prof),
    as.numeric(df$runtime_inflation),
    as.character(df$profile_id)
  ), , drop = FALSE]
  rownames(df) <- NULL
  df$selection_rank <- seq_len(nrow(df))
  top_n <- max(1L, safe_int(gate_cfg$top_n, 1L))
  df$selected <- as.logical(df$candidate_pass) & df$selection_rank <= top_n
  list(
    table = df,
    selected_profiles = as.character(df$profile_id[df$selected])
  )
}

evaluate_rank_candidates <- function(stage_report_root, candidate_profiles, gate_cfg) {
  exec_tbl <- read_csv_safe(file.path(stage_report_root, "tables", "profile_execution_status.csv"))
  rank_tbl <- read_csv_safe(file.path(stage_report_root, "tables", "profile_rank_summary.csv"))

  rows <- lapply(candidate_profiles, function(profile_id) {
    exec_row <- exec_tbl[as.character(exec_tbl$profile_id) == profile_id, , drop = FALSE]
    rank_row <- rank_tbl[as.character(rank_tbl$profile_id) == profile_id, , drop = FALSE]

    severe_fail_n <- safe_num(rank_row$severe_fail_n, Inf)
    severe_improved_n <- safe_num(rank_row$severe_improved_n, 0)
    sentinel_fail_n <- safe_num(rank_row$sentinel_fail_n, Inf)
    total_fail_n <- safe_num(rank_row$total_fail_n, Inf)
    fail_reduction <- safe_num(rank_row$fail_reduction, -Inf)
    runtime_inflation <- safe_num(rank_row$median_runtime_inflation, Inf)

    candidate_pass <- isTRUE(safe_lgl(exec_row$operational_pass, FALSE)) &&
      (is.null(gate_cfg$max_severe_fail_n) || severe_fail_n <= safe_num(gate_cfg$max_severe_fail_n, Inf)) &&
      (is.null(gate_cfg$max_total_fail_n) || total_fail_n <= safe_num(gate_cfg$max_total_fail_n, Inf)) &&
      (is.null(gate_cfg$max_sentinel_fail_n) || sentinel_fail_n <= safe_num(gate_cfg$max_sentinel_fail_n, Inf)) &&
      (is.null(gate_cfg$max_runtime_inflation) || runtime_inflation <= safe_num(gate_cfg$max_runtime_inflation, Inf)) &&
      (is.null(gate_cfg$min_fail_reduction) || fail_reduction >= safe_num(gate_cfg$min_fail_reduction, -Inf)) &&
      (is.null(gate_cfg$min_severe_improved_n) || severe_improved_n >= safe_num(gate_cfg$min_severe_improved_n, -Inf))

    data.frame(
      profile_id = profile_id,
      execution_status = safe_chr(exec_row$execution_status, "MISSING"),
      operational_pass = safe_lgl(exec_row$operational_pass, FALSE),
      severe_fail_n = severe_fail_n,
      severe_improved_n = severe_improved_n,
      sentinel_fail_n = sentinel_fail_n,
      total_fail_n = total_fail_n,
      fail_reduction = fail_reduction,
      median_runtime_inflation = runtime_inflation,
      candidate_pass = candidate_pass,
      stringsAsFactors = FALSE
    )
  })

  df <- do.call(rbind, rows)
  df <- df[order(
    !as.logical(df$candidate_pass),
    as.numeric(df$severe_fail_n),
    as.numeric(df$total_fail_n),
    as.numeric(df$sentinel_fail_n),
    -as.numeric(df$severe_improved_n),
    -as.numeric(df$fail_reduction),
    as.numeric(df$median_runtime_inflation),
    as.character(df$profile_id)
  ), , drop = FALSE]
  rownames(df) <- NULL
  df$selection_rank <- seq_len(nrow(df))
  top_n <- max(1L, safe_int(gate_cfg$top_n, 1L))
  df$selected <- as.logical(df$candidate_pass) & df$selection_rank <= top_n
  list(
    table = df,
    selected_profiles = as.character(df$profile_id[df$selected])
  )
}

write_runner_state <- function(path, run_tag, current_stage_id, execution_tbl, stop_reason = NA_character_) {
  payload <- list(
    generated_at = as.character(Sys.time()),
    run_tag = run_tag,
    current_stage_id = current_stage_id,
    completed_stages = if (nrow(execution_tbl)) sum(as.character(execution_tbl$execution_status) %in% c("COMPLETED", "RESUMED_COMPLETED"), na.rm = TRUE) else 0L,
    total_stages = nrow(execution_tbl),
    stop_reason = stop_reason
  )
  write_json_safe(payload, path)
}

write_plan_summary <- function(path, run_tag, git_sha, manifest_path, stages_df, profiles_df, controls_tbl) {
  lines <- c(
    "# QDESN Phase 3 Family-B Screen",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- run_tag: `%s`", run_tag),
    sprintf("- git_sha: `%s`", git_sha),
    sprintf("- manifest_path: `%s`", manifest_path),
    "",
    "## Controls",
    "",
    render_markdown_table(controls_tbl),
    "",
    "## Stages",
    "",
    render_markdown_table(stages_df),
    "",
    "## Profiles",
    "",
    render_markdown_table(profiles_df),
    ""
  )
  write_lines_safe(lines, path)
}

write_result_summary <- function(path, run_tag, stop_reason, stage_results_df) {
  lines <- c(
    "# QDESN Phase 3 Family-B Screen Results",
    "",
    sprintf("- updated_at: `%s`", as.character(Sys.time())),
    sprintf("- run_tag: `%s`", run_tag),
    sprintf("- stop_reason: `%s`", stop_reason),
    "",
    "## Stage Results",
    "",
    render_markdown_table(stage_results_df),
    ""
  )
  write_lines_safe(lines, path)
}

write_stage_selection_summary <- function(path, stage_id, stage_desc, table_df, selected_profiles) {
  lines <- c(
    sprintf("# %s Selection Summary", stage_id),
    "",
    stage_desc,
    "",
    sprintf("- selected_profiles: `%s`", paste(selected_profiles, collapse = ", ")),
    "",
    render_markdown_table(table_df),
    ""
  )
  write_lines_safe(lines, path)
}

write_stage_mcmc_summary <- function(path, df) {
  lines <- c(
    "# Stage MCMC Config Summary",
    "",
    render_markdown_table(df),
    ""
  )
  write_lines_safe(lines, path)
}

manifest_path <- resolve_path(
  get_arg("--manifest", file.path("config", "validation", "qdesn_validation_phase3_family_b_screen_manifest.yaml")),
  must_work = TRUE
)
cfg <- yaml::read_yaml(manifest_path)

phase01_manifest_path <- resolve_path((cfg$inputs %||% list())$phase01_manifest, must_work = TRUE)
base_defaults_path <- resolve_path((cfg$inputs %||% list())$base_defaults, must_work = TRUE)
phase01 <- jsonlite::fromJSON(phase01_manifest_path, simplifyVector = TRUE)

git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("qdesn-phase3-familyb-screen-%s__git-%s", format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]
if (!nzchar(trimws(run_tag))) stop("--run-tag cannot be empty.", call. = FALSE)

controls <- cfg$controls %||% list()
anchor_profile_id <- safe_chr(controls$anchor_profile_id, "R0_legacy_anchor")
resume_completed_stages <- isTRUE(controls$resume_completed_stages %||% TRUE)
execute <- has_flag("--execute")

report_workspace <- resolve_path(
  file.path((cfg$outputs %||% list())$report_root %||% file.path("reports", "qdesn_mcmc_validation", "qdesn_validation_phase3_family_b_screen"), run_tag),
  must_work = FALSE
)
results_workspace <- resolve_path(
  file.path((cfg$outputs %||% list())$results_root %||% file.path("results", "qdesn_mcmc_validation", "qdesn_validation_phase3_family_b_screen"), run_tag),
  must_work = FALSE
)
summary_dir <- file.path(report_workspace, "summary")
tables_dir <- file.path(report_workspace, "tables")
configs_dir <- file.path(report_workspace, "configs")
manifest_dir <- file.path(report_workspace, "manifest")
logs_dir <- file.path(report_workspace, "logs")
status_dir <- file.path(report_workspace, "status")
stages_root <- file.path(report_workspace, "stages")
stage_results_root <- file.path(results_workspace, "stages")
for (d in c(report_workspace, results_workspace, summary_dir, tables_dir, configs_dir, manifest_dir, logs_dir, status_dir, stages_root, stage_results_root)) {
  dir_create(d)
}

phase01_files <- phase01$files %||% list()
micro_grid_path <- resolve_path(phase01_files$micro_grid, must_work = TRUE)
micro_roots_path <- resolve_path(phase01_files$micro_roots, must_work = TRUE)
micro_grid <- read_csv_safe(micro_grid_path)
micro_roots <- read_csv_safe(micro_roots_path)
if (!nrow(micro_grid) || !nrow(micro_roots)) stop("Phase01 micro-pilot inputs are empty.", call. = FALSE)
micro_grid$root_join_key <- build_key(micro_grid)
micro_roots$root_join_key <- build_key(micro_roots)

profiles_cfg <- cfg$profiles %||% list()
if (!length(profiles_cfg)) stop("No profiles defined in manifest.", call. = FALSE)

profile_tbl <- do.call(rbind, lapply(seq_along(profiles_cfg), function(i) {
  p <- profiles_cfg[[i]]
  patch <- (((p$patch %||% list())$pipeline %||% list())$inference %||% list())$mcmc %||% list()
  slice_cfg <- patch$slice %||% list()
  tr_cfg <- patch$transforms %||% list()
  cond_cfg <- patch$conditioning %||% list()
  data.frame(
    profile_id = safe_chr(p$id, sprintf("P%d", i)),
    batch_id = safe_chr(p$batch, "B0"),
    family = safe_chr(p$family, "repair"),
    use_log_sigma = safe_lgl(tr_cfg$use_log_sigma, FALSE),
    core_update_mode = safe_chr(slice_cfg$core_update_mode, "sigma_then_gamma"),
    core_extra_passes = safe_int(slice_cfg$core_extra_passes, 0L),
    width_gamma = safe_num(slice_cfg$width_gamma),
    width_sigma = safe_num(slice_cfg$width_sigma),
    conditioning_mode = safe_chr(cond_cfg$mode, "none"),
    description = safe_chr(p$description, ""),
    stringsAsFactors = FALSE
  )
}))

stages_cfg <- cfg$stages %||% list()
if (!length(stages_cfg)) stop("No stages defined in manifest.", call. = FALSE)

stage_plan_rows <- lapply(seq_along(stages_cfg), function(ii) {
  stage_cfg <- stages_cfg[[ii]]
  data.frame(
    stage_order = ii,
    stage_id = safe_chr(stage_cfg$id, sprintf("S%d", ii)),
    description = safe_chr(stage_cfg$description, ""),
    profile_source = safe_chr(stage_cfg$profile_source, "all_candidates"),
    top_n = safe_int((stage_cfg$advance %||% list())$top_n, NA_integer_),
    stringsAsFactors = FALSE
  )
})
stages_df <- do.call(rbind, stage_plan_rows)
utils::write.csv(stages_df, file.path(tables_dir, "stage_plan.csv"), row.names = FALSE)

controls_tbl <- data.frame(
  key = c("anchor_profile_id", "campaign_workers", "threads_per_worker", "profile_timeout_minutes", "max_timeout_profiles", "max_error_profiles"),
  value = c(
    anchor_profile_id,
    as.character(safe_int(controls$campaign_workers, 1L)),
    as.character(safe_int(controls$threads_per_worker, 1L)),
    as.character(safe_int(controls$profile_timeout_minutes, 45L)),
    as.character(safe_int(controls$max_timeout_profiles, 2L)),
    as.character(safe_int(controls$max_error_profiles, 3L))
  ),
  stringsAsFactors = FALSE
)

write_plan_summary(
  path = file.path(summary_dir, "family_b_screen_plan.md"),
  run_tag = run_tag,
  git_sha = git_sha,
  manifest_path = manifest_path,
  stages_df = stages_df,
  profiles_df = profile_tbl,
  controls_tbl = controls_tbl
)

write_json_safe(
  list(
    generated_at = as.character(Sys.time()),
    run_tag = run_tag,
    git_sha = git_sha,
    manifest_path = manifest_path,
    phase01_manifest_path = phase01_manifest_path,
    base_defaults_path = base_defaults_path,
    report_workspace = report_workspace,
    results_workspace = results_workspace
  ),
  file.path(manifest_dir, "family_b_screen_manifest.json")
)

if (!isTRUE(execute)) {
  cat(sprintf("Prepared Phase 3 Family-B screen workspace: %s\n", report_workspace))
  cat(sprintf("Plan summary: %s\n", file.path(summary_dir, "family_b_screen_plan.md")))
  quit(status = 0)
}

stage_result_rows <- list()
prev_selected_profiles <- character(0)
stop_reason <- "completed_requested_scope"

for (ii in seq_along(stages_cfg)) {
  stage_cfg <- stages_cfg[[ii]]
  stage_id <- safe_chr(stage_cfg$id, sprintf("S%d", ii))
  stage_dir <- file.path(stages_root, stage_id)
  stage_result_dir <- file.path(stage_results_root, stage_id)
  dir_create(stage_dir)
  dir_create(stage_result_dir)
  log_path <- file.path(logs_dir, sprintf("%s.log", stage_id))
  status_path <- file.path(status_dir, sprintf("%s_status.json", stage_id))

  if (isTRUE(resume_completed_stages) && file.exists(status_path)) {
    prior_status <- tryCatch(jsonlite::fromJSON(status_path), error = function(...) NULL)
    if (!is.null(prior_status) && isTRUE(prior_status$completed %||% FALSE)) {
      prev_selected_profiles <- as.character(prior_status$selected_profiles %||% character(0))
      stage_result_rows[[length(stage_result_rows) + 1L]] <- data.frame(
        stage_id = stage_id,
        execution_status = safe_chr(prior_status$execution_status, "RESUMED_COMPLETED"),
        operational_pass = safe_lgl(prior_status$operational_pass, FALSE),
        selected_n = length(prev_selected_profiles),
        gate_reason = safe_chr(prior_status$gate_reason, ""),
        stage_report_root = safe_chr(prior_status$stage_report_root, ""),
        stringsAsFactors = FALSE
      )
      if (!length(prev_selected_profiles) && !identical((stage_cfg$advance %||% list())$type %||% "report_only", "report_only")) {
        stop_reason <- sprintf("no_candidates_advanced_%s", stage_id)
        break
      }
      next
    }
  }

  selected_roots <- select_stage_roots(stage_cfg$selector %||% list(), micro_roots)
  if (!nrow(selected_roots)) stop(sprintf("Stage %s selected zero roots.", stage_id), call. = FALSE)
  prep <- prepare_stage_phase01(stage_id, stage_dir, phase01, selected_roots, micro_grid)

  stage_profiles_cfg <- filter_profiles_for_stage(
    all_profiles_cfg = profiles_cfg,
    anchor_profile_id = anchor_profile_id,
    profile_source = safe_chr(stage_cfg$profile_source, "all_candidates"),
    prev_selected_ids = prev_selected_profiles
  )
  stage_profile_ids <- vapply(stage_profiles_cfg, function(p) safe_chr(p$id, ""), character(1))
  candidate_profile_ids <- setdiff(stage_profile_ids, anchor_profile_id)
  if (!length(candidate_profile_ids)) {
    stop_reason <- sprintf("no_stage_candidates_%s", stage_id)
    stage_result_rows[[length(stage_result_rows) + 1L]] <- data.frame(
      stage_id = stage_id,
      execution_status = "SKIPPED_NO_CANDIDATES",
      operational_pass = FALSE,
      selected_n = 0L,
      gate_reason = stop_reason,
      stage_report_root = NA_character_,
      stringsAsFactors = FALSE
    )
    break
  }

  stage_run_tag <- sprintf("%s__%s", run_tag, stage_id)
  stage_screen_parent_report <- file.path(stage_dir, "screen_runs")
  stage_screen_parent_results <- file.path(stage_result_dir, "screen_runs")
  dir_create(stage_screen_parent_report)
  dir_create(stage_screen_parent_results)

  stage_screen_manifest <- list(
    meta = list(
      name = sprintf("%s__%s", safe_chr((cfg$meta %||% list())$name, "qdesn_phase3_family_b_screen"), stage_id),
      purpose = safe_chr(stage_cfg$description, "")
    ),
    inputs = list(
      phase01_manifest = prep$phase01_stage_path,
      base_defaults = base_defaults_path
    ),
    outputs = list(
      report_root = stage_screen_parent_report,
      results_root = stage_screen_parent_results
    ),
    controls = deep_merge(
      list(resume_completed_profiles = TRUE),
      list(
        campaign_workers = safe_int(controls$campaign_workers, 1L),
        threads_per_worker = safe_int(controls$threads_per_worker, 1L),
        create_plots = safe_lgl(controls$create_plots, FALSE),
        profile_verbose = if (is.null(controls$profile_verbose)) TRUE else isTRUE(controls$profile_verbose),
        profile_timeout_minutes = safe_int(controls$profile_timeout_minutes, 45L),
        timeout_kill_after_seconds = safe_int(controls$timeout_kill_after_seconds, 30L),
        continue_on_profile_error = if (is.null(controls$continue_on_profile_error)) TRUE else isTRUE(controls$continue_on_profile_error),
        max_timeout_profiles = safe_int(controls$max_timeout_profiles, 2L),
        max_error_profiles = safe_int(controls$max_error_profiles, 3L),
        stop_on_anchor_operational_failure = if (is.null(controls$stop_on_anchor_operational_failure)) TRUE else isTRUE(controls$stop_on_anchor_operational_failure)
      )
    ),
    batches = cfg$batches %||% list(),
    profiles = stage_profiles_cfg
  )
  stage_screen_manifest_path <- file.path(stage_dir, "configs", "stage_screen_manifest.yaml")
  yaml::write_yaml(stage_screen_manifest, stage_screen_manifest_path)

  cmd <- c(
    "scripts/run_qdesn_exal_kernel_screen.R",
    "--manifest", stage_screen_manifest_path,
    "--run-tag", stage_run_tag,
    "--execute"
  )
  exit_status <- suppressWarnings(system2("Rscript", cmd, stdout = log_path, stderr = log_path))
  exit_status <- as.integer(exit_status %||% 0L)
  stage_screen_report_root <- file.path(stage_screen_parent_report, stage_run_tag)

  advance_cfg <- stage_cfg$advance %||% list()
  advance_type <- tolower(trimws(as.character(advance_cfg$type %||% "report_only")))[1L]
  selection <- switch(
    advance_type,
    canary_filter_top_n = evaluate_canary_candidates(stage_screen_report_root, candidate_profile_ids, advance_cfg),
    rank_filter_top_n = evaluate_rank_candidates(stage_screen_report_root, candidate_profile_ids, advance_cfg),
    report_only = list(
      table = data.frame(profile_id = candidate_profile_ids, selected = FALSE, stringsAsFactors = FALSE),
      selected_profiles = character(0)
    ),
    stop(sprintf("Unsupported stage advance type '%s'.", advance_type), call. = FALSE)
  )

  selection_csv <- file.path(stage_dir, "tables", "stage_candidate_selection.csv")
  selection_md <- file.path(stage_dir, "summary", "stage_candidate_selection.md")
  utils::write.csv(selection$table, selection_csv, row.names = FALSE)
  write_stage_selection_summary(
    path = selection_md,
    stage_id = stage_id,
    stage_desc = safe_chr(stage_cfg$description, ""),
    table_df = selection$table,
    selected_profiles = selection$selected_profiles
  )

  mcmc_cfg_df <- collect_stage_mcmc_config(stage_screen_report_root, prep$selected_roots[, setdiff(names(prep$selected_roots), "root_join_key"), drop = FALSE])
  mcmc_cfg_csv <- file.path(stage_dir, "tables", "stage_mcmc_config_summary.csv")
  mcmc_cfg_md <- file.path(stage_dir, "summary", "stage_mcmc_config_summary.md")
  if (nrow(mcmc_cfg_df)) {
    utils::write.csv(mcmc_cfg_df, mcmc_cfg_csv, row.names = FALSE)
    write_stage_mcmc_summary(mcmc_cfg_md, mcmc_cfg_df)
  }

  operational_pass <- identical(exit_status, 0L)
  gate_reason <- if (length(selection$selected_profiles)) "candidates_advanced" else if (identical(advance_type, "report_only")) "report_only_final_stage" else "no_candidates_advanced"
  execution_status <- if (operational_pass) "COMPLETED" else sprintf("ERROR_%d", exit_status)
  prev_selected_profiles <- selection$selected_profiles

  write_json_safe(
    list(
      completed = TRUE,
      exit_status = exit_status,
      execution_status = execution_status,
      operational_pass = operational_pass,
      gate_reason = gate_reason,
      selected_profiles = prev_selected_profiles,
      stage_report_root = stage_screen_report_root,
      stage_results_root = file.path(stage_screen_parent_results, stage_run_tag),
      stage_manifest_path = stage_screen_manifest_path,
      log_path = log_path,
      selection_csv = selection_csv,
      selection_md = selection_md,
      mcmc_config_csv = if (nrow(mcmc_cfg_df)) mcmc_cfg_csv else NA_character_,
      mcmc_config_md = if (nrow(mcmc_cfg_df)) mcmc_cfg_md else NA_character_
    ),
    status_path
  )

  stage_result_rows[[length(stage_result_rows) + 1L]] <- data.frame(
    stage_id = stage_id,
    execution_status = execution_status,
    operational_pass = operational_pass,
    selected_n = length(prev_selected_profiles),
    gate_reason = gate_reason,
    stage_report_root = stage_screen_report_root,
    stringsAsFactors = FALSE
  )

  stage_results_df <- do.call(rbind, stage_result_rows)
  utils::write.csv(stage_results_df, file.path(tables_dir, "stage_execution_status.csv"), row.names = FALSE)
  write_result_summary(file.path(summary_dir, "family_b_screen_results.md"), run_tag, stop_reason, stage_results_df)
  write_runner_state(file.path(status_dir, "runner_state.json"), run_tag, stage_id, stage_results_df, stop_reason)

  if (!operational_pass) {
    stop_reason <- sprintf("stage_error_%s", stage_id)
    break
  }
  if (!length(prev_selected_profiles) && !identical(advance_type, "report_only")) {
    stop_reason <- sprintf("no_candidates_advanced_%s", stage_id)
    break
  }
}

stage_results_df <- if (length(stage_result_rows)) do.call(rbind, stage_result_rows) else data.frame(stringsAsFactors = FALSE)
utils::write.csv(stage_results_df, file.path(tables_dir, "stage_execution_status.csv"), row.names = FALSE)
write_result_summary(file.path(summary_dir, "family_b_screen_results.md"), run_tag, stop_reason, stage_results_df)
write_runner_state(file.path(status_dir, "runner_state.json"), run_tag, NA_character_, stage_results_df, stop_reason)
write_json_safe(
  list(
    completed_at = as.character(Sys.time()),
    run_tag = run_tag,
    stop_reason = stop_reason,
    report_workspace = report_workspace,
    results_workspace = results_workspace
  ),
  file.path(manifest_dir, "family_b_screen_completed.json")
)

cat(sprintf("Phase 3 Family-B screen workspace: %s\n", report_workspace))
cat(sprintf("Plan summary: %s\n", file.path(summary_dir, "family_b_screen_plan.md")))
cat(sprintf("Result summary: %s\n", file.path(summary_dir, "family_b_screen_results.md")))

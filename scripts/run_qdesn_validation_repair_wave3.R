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
    "Usage: scripts/run_qdesn_validation_repair_wave3.R [options]\n\n",
    "Options:\n",
    "  --manifest <path>   Repair-wave manifest YAML.\n",
    "  --run-tag <tag>     Repair-wave run tag.\n",
    "  --execute           Run the staged repair wave.\n",
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

safe_chr <- function(x, default = NA_character_) {
  x <- as.character(x %||% default)
  if (!length(x)) default else x[1L]
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

grade_score <- function(x) {
  x <- toupper(trimws(as.character(x %||% NA_character_)))
  ifelse(
    x == "PASS", 2L,
    ifelse(x == "WARN", 1L, ifelse(x == "FAIL", 0L, NA_integer_))
  )
}

select_stage_roots <- function(selector, micro_roots) {
  mode <- tolower(trimws(as.character((selector %||% list())$mode %||% "all")))[1L]
  if (!nrow(micro_roots)) stop("Micro roots table is empty.", call. = FALSE)

  if (identical(mode, "all")) {
    return(micro_roots)
  }

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
  selected_roots <- selected_roots
  selected_roots$root_join_key <- build_key(selected_roots)
  selected_grid <- micro_grid[micro_grid$root_join_key %in% selected_roots$root_join_key, , drop = FALSE]
  if (!nrow(selected_grid)) {
    stop(sprintf("Stage %s selected no grid rows.", stage_id), call. = FALSE)
  }

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

evaluate_stage <- function(stage_cfg, stage_report_root, candidate_profile) {
  exec_tbl <- read_csv_safe(file.path(stage_report_root, "tables", "profile_execution_status.csv"))
  rank_tbl <- read_csv_safe(file.path(stage_report_root, "tables", "profile_rank_summary.csv"))
  trans_tbl <- read_csv_safe(file.path(stage_report_root, "tables", sprintf("phase35_transitions_%s.csv", candidate_profile)))

  exec_row <- exec_tbl[as.character(exec_tbl$profile_id) == candidate_profile, , drop = FALSE]
  operational_pass <- nrow(exec_row) && isTRUE(as.logical(exec_row$operational_pass[1L]))
  execution_status <- safe_chr(exec_row$execution_status, NA_character_)

  gate_cfg <- stage_cfg$gate %||% list()
  gate_type <- tolower(trimws(as.character(gate_cfg$type %||% "")))[1L]

  gate_pass <- FALSE
  gate_reason <- "missing_evidence"
  metrics <- list()

  if (identical(gate_type, "canary_material_improvement")) {
    if (nrow(trans_tbl)) {
      trans_row <- trans_tbl[1L, , drop = FALSE]
      grade_base <- grade_score(trans_row$signoff_grade_base[1L])
      grade_prof <- grade_score(trans_row$signoff_grade_prof[1L])
      delta_ess <- if ("delta_ess_core" %in% names(trans_row)) {
        safe_num(trans_row$delta_ess_core[1L])
      } else {
        safe_num(trans_row$mcmc_min_ess_core_prof[1L]) - safe_num(trans_row$mcmc_min_ess_core_base[1L])
      }
      delta_geweke <- if ("delta_geweke_absz" %in% names(trans_row)) {
        safe_num(trans_row$delta_geweke_absz[1L])
      } else {
        safe_num(trans_row$mcmc_max_geweke_absz_core_prof[1L]) - safe_num(trans_row$mcmc_max_geweke_absz_core_base[1L])
      }
      delta_half <- if ("delta_half_drift" %in% names(trans_row)) {
        safe_num(trans_row$delta_half_drift[1L])
      } else {
        safe_num(trans_row$mcmc_max_half_drift_core_prof[1L]) - safe_num(trans_row$mcmc_max_half_drift_core_base[1L])
      }
      root_label <- if ("root_label" %in% names(trans_row)) {
        safe_chr(trans_row$root_label[1L])
      } else {
        sprintf(
          "%s @ tau=%s %s %s",
          safe_chr(trans_row$scenario[1L]),
          as.character(trans_row$tau[1L]),
          safe_chr(trans_row$likelihood_family[1L]),
          safe_chr(trans_row$beta_prior_type[1L])
        )
      }

      grade_improved <- is.finite(grade_prof) && is.finite(grade_base) && grade_prof > grade_base
      metric_improved <- isTRUE(
        delta_ess >= safe_num(gate_cfg$min_delta_ess_core, 0) &&
          delta_geweke <= safe_num(gate_cfg$max_delta_geweke_absz_increase, 0) &&
          delta_half <= safe_num(gate_cfg$max_delta_half_drift_increase, 0)
      )
      gate_pass <- isTRUE(operational_pass) && (grade_improved || metric_improved)
      gate_reason <- if (gate_pass) "canary_improved" else "canary_not_improved_enough"
      metrics <- list(
        root_label = root_label,
        signoff_grade_base = safe_chr(trans_row$signoff_grade_base[1L]),
        signoff_grade_prof = safe_chr(trans_row$signoff_grade_prof[1L]),
        delta_ess_core = delta_ess,
        delta_geweke_absz = delta_geweke,
        delta_half_drift = delta_half
      )
    }
  } else if (identical(gate_type, "rank_table_threshold")) {
    rank_row <- rank_tbl[as.character(rank_tbl$profile_id) == candidate_profile, , drop = FALSE]
    if (nrow(rank_row)) {
      severe_fail_n <- safe_num(rank_row$severe_fail_n[1L], 0)
      sentinel_fail_n <- safe_num(rank_row$sentinel_fail_n[1L], 0)
      total_fail_n <- safe_num(rank_row$total_fail_n[1L], 0)
      runtime_inflation <- safe_num(rank_row$median_runtime_inflation[1L], Inf)

      gate_pass <- isTRUE(operational_pass)
      if (!is.null(gate_cfg$max_severe_fail_n)) gate_pass <- gate_pass && severe_fail_n <= safe_num(gate_cfg$max_severe_fail_n, Inf)
      if (!is.null(gate_cfg$max_sentinel_fail_n)) gate_pass <- gate_pass && sentinel_fail_n <= safe_num(gate_cfg$max_sentinel_fail_n, Inf)
      if (!is.null(gate_cfg$max_total_fail_n)) gate_pass <- gate_pass && total_fail_n <= safe_num(gate_cfg$max_total_fail_n, Inf)
      if (!is.null(gate_cfg$max_runtime_inflation)) gate_pass <- gate_pass && runtime_inflation <= safe_num(gate_cfg$max_runtime_inflation, Inf)

      gate_reason <- if (gate_pass) "rank_gate_pass" else "rank_gate_threshold_failed"
      metrics <- list(
        severe_fail_n = severe_fail_n,
        sentinel_fail_n = sentinel_fail_n,
        total_fail_n = total_fail_n,
        median_runtime_inflation = runtime_inflation
      )
    }
  } else {
    stop(sprintf("Unsupported gate type '%s'.", gate_type), call. = FALSE)
  }

  list(
    execution_status = execution_status,
    operational_pass = isTRUE(operational_pass),
    gate_pass = isTRUE(gate_pass),
    gate_reason = gate_reason,
    metrics = metrics
  )
}

write_plan_summary <- function(path, run_tag, git_sha, manifest_path, profiles_df, stages_df) {
  lines <- c(
    "# QDESN Validation Repair Wave 3",
    "",
    sprintf("- run_tag: `%s`", run_tag),
    sprintf("- git_sha: `%s`", git_sha),
    sprintf("- manifest: `%s`", manifest_path),
    "",
    "## Profiles",
    ""
  )
  lines <- c(lines, render_markdown_table(profiles_df), "", "## Stages", "", render_markdown_table(stages_df), "")
  write_lines_safe(lines, path)
}

write_result_summary <- function(path, run_tag, stop_reason, stage_results_df) {
  lines <- c(
    "# QDESN Validation Repair Wave 3 Results",
    "",
    sprintf("- run_tag: `%s`", run_tag),
    sprintf("- stop_reason: `%s`", stop_reason),
    ""
  )
  lines <- c(lines, "## Stage Results", "", render_markdown_table(stage_results_df), "")
  write_lines_safe(lines, path)
}

write_conditioning_summary <- function(path, df) {
  lines <- c(
    "# QDESN Validation Repair Wave 3 Conditioning Summary",
    "",
    render_markdown_table(df),
    ""
  )
  write_lines_safe(lines, path)
}

collect_stage_conditioning <- function(stage_report_root, selected_roots) {
  exec_tbl <- read_csv_safe(file.path(stage_report_root, "tables", "profile_execution_status.csv"))
  if (!nrow(exec_tbl) || !"report_root" %in% names(exec_tbl)) {
    return(data.frame(stringsAsFactors = FALSE))
  }

  selected_roots <- selected_roots
  selected_roots$root_join_key <- build_key(selected_roots)
  out <- list()
  keep <- c(
    "root_join_key", "scenario", "tau", "likelihood_family", "beta_prior_type", "seed", "reservoir_profile",
    "mcmc_conditioning_mode", "mcmc_conditioning_active", "mcmc_conditioning_raw_kappa",
    "mcmc_conditioning_work_kappa", "mcmc_conditioning_gain_ratio", "mcmc_conditioning_scaled_columns_n"
  )

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

manifest_path <- resolve_path(
  get_arg("--manifest", file.path("config", "validation", "qdesn_validation_repair_wave3_manifest.yaml")),
  must_work = TRUE
)
cfg <- yaml::read_yaml(manifest_path)

phase01_manifest_path <- resolve_path((cfg$inputs %||% list())$phase01_manifest, must_work = TRUE)
base_defaults_path <- resolve_path((cfg$inputs %||% list())$base_defaults, must_work = TRUE)
phase01 <- jsonlite::fromJSON(phase01_manifest_path, simplifyVector = TRUE)

git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("qdesn-validation-repair-wave3-%s__git-%s", format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]
if (!nzchar(trimws(run_tag))) stop("--run-tag cannot be empty.", call. = FALSE)

controls <- cfg$controls %||% list()
resume_completed_stages <- isTRUE(controls$resume_completed_stages %||% TRUE)
execute <- has_flag("--execute")

report_workspace <- resolve_path(
  file.path((cfg$outputs %||% list())$report_root %||% file.path("reports", "qdesn_mcmc_validation", "qdesn_validation_repair_wave3"), run_tag),
  must_work = FALSE
)
results_workspace <- resolve_path(
  file.path((cfg$outputs %||% list())$results_root %||% file.path("results", "qdesn_mcmc_validation", "qdesn_validation_repair_wave3"), run_tag),
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
profiles_df <- do.call(rbind, lapply(seq_along(profiles_cfg), function(i) {
  p <- profiles_cfg[[i]]
  data.frame(
    profile_id = safe_chr(p$id, sprintf("R%d", i)),
    family = safe_chr(p$family, "repair"),
    description = safe_chr(p$description, ""),
    stringsAsFactors = FALSE
  )
}))

stages_cfg <- cfg$stages %||% list()
if (!length(stages_cfg)) stop("No stages defined in manifest.", call. = FALSE)

stage_rows <- vector("list", length(stages_cfg))
stage_context <- vector("list", length(stages_cfg))
for (ii in seq_along(stages_cfg)) {
  stage_cfg <- stages_cfg[[ii]]
  stage_id <- safe_chr(stage_cfg$id, sprintf("S%d", ii))
  stage_dir <- file.path(stages_root, stage_id)
  stage_result_dir <- file.path(stage_results_root, stage_id)
  dir_create(stage_dir)
  dir_create(stage_result_dir)

  selected_roots <- select_stage_roots(stage_cfg$selector %||% list(), micro_roots)
  if (!nrow(selected_roots)) {
    stop(sprintf("Stage %s selected zero roots.", stage_id), call. = FALSE)
  }

  prep <- prepare_stage_phase01(stage_id, stage_dir, phase01, selected_roots, micro_grid)
  stage_run_tag <- sprintf("%s__%s", run_tag, stage_id)
  stage_screen_parent_report <- file.path(stage_dir, "screen_runs")
  stage_screen_parent_results <- file.path(stage_result_dir, "screen_runs")
  dir_create(stage_screen_parent_report)
  dir_create(stage_screen_parent_results)

  stage_screen_manifest <- list(
    meta = list(
      name = sprintf("%s__%s", safe_chr((cfg$meta %||% list())$name, "qdesn_validation_repair_wave3"), stage_id),
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
        campaign_workers = as.integer(controls$campaign_workers %||% 1L),
        threads_per_worker = as.integer(controls$threads_per_worker %||% 1L),
        create_plots = isTRUE(controls$create_plots %||% FALSE),
        profile_verbose = if (is.null(controls$profile_verbose)) TRUE else isTRUE(controls$profile_verbose),
        profile_timeout_minutes = as.integer(controls$profile_timeout_minutes %||% 45L),
        timeout_kill_after_seconds = as.integer(controls$timeout_kill_after_seconds %||% 30L),
        continue_on_profile_error = if (is.null(controls$continue_on_profile_error)) TRUE else isTRUE(controls$continue_on_profile_error),
        max_timeout_profiles = as.integer(controls$max_timeout_profiles %||% 2L),
        max_error_profiles = as.integer(controls$max_error_profiles %||% 3L),
        stop_on_anchor_operational_failure = if (is.null(controls$stop_on_anchor_operational_failure)) TRUE else isTRUE(controls$stop_on_anchor_operational_failure)
      )
    ),
    batches = cfg$batches %||% list(),
    profiles = profiles_cfg
  )
  stage_screen_manifest_path <- file.path(stage_dir, "configs", "stage_screen_manifest.yaml")
  yaml::write_yaml(stage_screen_manifest, stage_screen_manifest_path)

  stage_rows[[ii]] <- data.frame(
    stage_order = ii,
    stage_id = stage_id,
    description = safe_chr(stage_cfg$description, ""),
    n_roots = nrow(prep$selected_roots),
    candidate_profile = safe_chr((stage_cfg$gate %||% list())$candidate_profile, NA_character_),
    screen_manifest = stage_screen_manifest_path,
    stringsAsFactors = FALSE
  )
  stage_context[[ii]] <- list(
    stage_cfg = stage_cfg,
    stage_id = stage_id,
    stage_dir = stage_dir,
    stage_result_dir = stage_result_dir,
    selected_roots = prep$selected_roots[, setdiff(names(prep$selected_roots), "root_join_key"), drop = FALSE],
    stage_run_tag = stage_run_tag,
    stage_screen_manifest_path = stage_screen_manifest_path,
    stage_screen_report_root = file.path(stage_screen_parent_report, stage_run_tag),
    stage_screen_results_root = file.path(stage_screen_parent_results, stage_run_tag)
  )
}

stages_df <- do.call(rbind, stage_rows)
utils::write.csv(stages_df, file.path(tables_dir, "stage_plan.csv"), row.names = FALSE)
write_plan_summary(
  path = file.path(summary_dir, "repair_wave3_plan.md"),
  run_tag = run_tag,
  git_sha = git_sha,
  manifest_path = manifest_path,
  profiles_df = profiles_df,
  stages_df = stages_df[, c("stage_id", "description", "n_roots", "candidate_profile"), drop = FALSE]
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
  file.path(manifest_dir, "repair_wave3_manifest.json")
)

if (!isTRUE(execute)) {
  cat(sprintf("Prepared repair wave 3 workspace: %s\n", report_workspace))
  cat(sprintf("Plan summary: %s\n", file.path(summary_dir, "repair_wave3_plan.md")))
  quit(status = 0)
}

stage_result_rows <- list()
stop_reason <- "completed_requested_scope"

for (ii in seq_along(stage_context)) {
  ctx <- stage_context[[ii]]
  stage_cfg <- ctx$stage_cfg
  stage_id <- ctx$stage_id
  candidate_profile <- safe_chr((stage_cfg$gate %||% list())$candidate_profile, NA_character_)
  log_path <- file.path(logs_dir, sprintf("%s.log", stage_id))
  status_path <- file.path(status_dir, sprintf("%s_status.json", stage_id))

  if (isTRUE(resume_completed_stages) && file.exists(status_path)) {
    prior_status <- tryCatch(jsonlite::fromJSON(status_path), error = function(...) NULL)
    if (!is.null(prior_status) && isTRUE(prior_status$completed %||% FALSE)) {
      stage_result_rows[[length(stage_result_rows) + 1L]] <- data.frame(
        stage_id = stage_id,
        execution_status = safe_chr(prior_status$execution_status, "RESUMED_COMPLETED"),
        operational_pass = isTRUE(prior_status$operational_pass %||% FALSE),
        gate_pass = isTRUE(prior_status$gate_pass %||% FALSE),
        gate_reason = safe_chr(prior_status$gate_reason, ""),
        stage_report_root = safe_chr(prior_status$stage_report_root, ctx$stage_screen_report_root),
        stringsAsFactors = FALSE
      )
      if (!isTRUE(prior_status$gate_pass %||% FALSE)) {
        stop_reason <- sprintf("gate_failed_%s", stage_id)
        break
      }
      next
    }
  }

  cmd <- c(
    "scripts/run_qdesn_exal_kernel_screen.R",
    "--manifest", ctx$stage_screen_manifest_path,
    "--run-tag", ctx$stage_run_tag,
    "--execute"
  )
  exit_status <- suppressWarnings(system2("Rscript", cmd, stdout = log_path, stderr = log_path))
  exit_status <- as.integer(exit_status %||% 0L)

  stage_eval <- evaluate_stage(stage_cfg, ctx$stage_screen_report_root, candidate_profile)
  execution_status <- if (identical(exit_status, 0L)) "COMPLETED" else sprintf("ERROR_%d", exit_status)
  conditioning_df <- collect_stage_conditioning(ctx$stage_screen_report_root, ctx$selected_roots)
  conditioning_csv <- file.path(ctx$stage_dir, "tables", "stage_conditioning_summary.csv")
  conditioning_md <- file.path(ctx$stage_dir, "summary", "stage_conditioning_summary.md")
  if (nrow(conditioning_df)) {
    utils::write.csv(conditioning_df, conditioning_csv, row.names = FALSE)
    write_conditioning_summary(conditioning_md, conditioning_df)
  }

  write_json_safe(
    list(
      completed = TRUE,
      exit_status = exit_status,
      execution_status = execution_status,
      operational_pass = isTRUE(stage_eval$operational_pass),
      gate_pass = isTRUE(stage_eval$gate_pass),
      gate_reason = stage_eval$gate_reason,
      metrics = stage_eval$metrics,
      stage_report_root = ctx$stage_screen_report_root,
      stage_results_root = ctx$stage_screen_results_root,
      log_path = log_path,
      conditioning_summary_csv = if (nrow(conditioning_df)) conditioning_csv else NA_character_,
      conditioning_summary_md = if (nrow(conditioning_df)) conditioning_md else NA_character_
    ),
    status_path
  )

  stage_result_rows[[length(stage_result_rows) + 1L]] <- data.frame(
    stage_id = stage_id,
    execution_status = execution_status,
    operational_pass = isTRUE(stage_eval$operational_pass),
    gate_pass = isTRUE(stage_eval$gate_pass),
    gate_reason = stage_eval$gate_reason,
    stage_report_root = ctx$stage_screen_report_root,
    stringsAsFactors = FALSE
  )

  stage_results_df <- do.call(rbind, stage_result_rows)
  utils::write.csv(stage_results_df, file.path(tables_dir, "stage_execution_status.csv"), row.names = FALSE)
  write_result_summary(
    path = file.path(summary_dir, "repair_wave3_results.md"),
    run_tag = run_tag,
    stop_reason = stop_reason,
    stage_results_df = stage_results_df
  )

  if (!isTRUE(stage_eval$gate_pass)) {
    stop_reason <- sprintf("gate_failed_%s", stage_id)
    break
  }
}

stage_results_df <- if (length(stage_result_rows)) do.call(rbind, stage_result_rows) else data.frame(stringsAsFactors = FALSE)
utils::write.csv(stage_results_df, file.path(tables_dir, "stage_execution_status.csv"), row.names = FALSE)
write_result_summary(
  path = file.path(summary_dir, "repair_wave3_results.md"),
  run_tag = run_tag,
  stop_reason = stop_reason,
  stage_results_df = stage_results_df
)
write_json_safe(
  list(
    completed_at = as.character(Sys.time()),
    run_tag = run_tag,
    stop_reason = stop_reason,
    completed_stages = nrow(stage_results_df),
    report_workspace = report_workspace,
    results_workspace = results_workspace
  ),
  file.path(manifest_dir, "repair_wave3_completed.json")
)

cat(sprintf("Repair wave 3 workspace: %s\n", report_workspace))
cat(sprintf("Plan summary: %s\n", file.path(summary_dir, "repair_wave3_plan.md")))
cat(sprintf("Result summary: %s\n", file.path(summary_dir, "repair_wave3_results.md")))

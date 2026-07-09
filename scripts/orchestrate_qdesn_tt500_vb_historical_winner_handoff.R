#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload", "yaml")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[[1L]]
  if (idx >= length(args)) return(default)
  args[[idx + 1L]]
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}
int_arg <- function(flag, default) {
  val <- suppressWarnings(as.integer(get_arg(flag, as.character(default)))[1L])
  if (is.finite(val)) val else as.integer(default)
}

workers <- min(int_arg("--workers", 20L), 64L)
top_per_cell <- int_arg("--top-per-cell", 5L)
stage_file <- as.character(get_arg(
  "--stage-file",
  "qdesn_dynamic_fitforecast_v2_tt500_vb_historical_winner_handoff"
))[1L]
stamp_id <- as.character(get_arg("--stamp", "20260709"))[1L]
likelihoods <- as.character(get_arg("--likelihoods", "exal"))[1L]
baseline_path <- resolve_path(get_arg(
  "--baseline",
  "validation/fitforecast_v2/docs/validation_local_exdqlm_dqlm_vb_baseline_20260708.csv"
), must_work = TRUE)
base_defaults_path <- resolve_path(get_arg(
  "--base-defaults",
  "config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_v2_defaults.yaml"
), must_work = TRUE)
out_dir <- resolve_path(get_arg("--out-dir", "validation/fitforecast_v2/docs"), must_work = FALSE)
selection_csv <- resolve_path(get_arg(
  "--selection-csv",
  file.path(out_dir, paste0("qdesn_tt500_vb_historical_winner_handoff_selected_designs_", stamp_id, ".csv"))
), must_work = FALSE)

git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("qdesn-vb-historical-winner-handoff-%s__git-%s", stamp, git_sha)
))[1L]
orchestrator_tag <- as.character(get_arg(
  "--orchestrator-tag",
  sprintf("qdesn-vb-historical-winner-handoff-orchestrator-%s__git-%s", stamp, git_sha)
))[1L]

dry_run <- has_flag("--dry-run")
mine_only <- has_flag("--mine-only")
materialize_only <- has_flag("--materialize-only")
prepare_only <- has_flag("--prepare-only")
do_smoke <- has_flag("--smoke")
do_full <- has_flag("--full") && !isTRUE(dry_run)
launch_approved <- has_flag("--launch-approved")
skip_mine <- has_flag("--skip-mine")
skip_materialize <- has_flag("--skip-materialize")
skip_prepare <- has_flag("--skip-prepare")
skip_rank <- has_flag("--skip-rank")
refresh_materialized <- has_flag("--refresh-materialized")

if (isTRUE(do_full) && !isTRUE(launch_approved)) {
  stop("Full historical-winner handoff launch requires both --full and --launch-approved.", call. = FALSE)
}

profiles_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_profiles.csv")), must_work = FALSE)
assignments_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_cell_assignments.csv")), must_work = FALSE)
defaults_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_defaults.yaml")), must_work = FALSE)
grid_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_grid.csv")), must_work = FALSE)
materialization_manifest <- resolve_path(file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json")), must_work = FALSE)

orchestrator_root <- file.path(
  repo_root,
  "reports",
  "qdesn_mcmc_validation",
  "qdesn_tt500_vb_historical_winner_handoff",
  orchestrator_tag
)
dir.create(file.path(orchestrator_root, "logs"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(orchestrator_root, "manifest"), recursive = TRUE, showWarnings = FALSE)

run_cmd <- function(label, cmd, args) {
  log_path <- file.path(orchestrator_root, "logs", paste0(label, ".log"))
  cmd_path <- file.path(orchestrator_root, "logs", paste0(label, "_command.txt"))
  line <- paste(shQuote(c(cmd, args)), collapse = " ")
  writeLines(line, cmd_path)
  if (isTRUE(dry_run)) {
    cat(sprintf("[dry-run] %s\n", line))
    return(0L)
  }
  cat(sprintf("[historical-winner-handoff] %s start: %s\n", label, Sys.time()))
  status <- system2(cmd, args = args, stdout = log_path, stderr = log_path)
  cat(sprintf("[historical-winner-handoff] %s status=%d end: %s\n", label, as.integer(status), Sys.time()))
  as.integer(status)
}

latest_campaign_report <- function(base_report_root, tag) {
  outer <- file.path(repo_root, base_report_root, tag)
  if (!dir.exists(outer)) return(NA_character_)
  direct <- file.path(outer, "tables", "campaign_fit_summary.csv")
  if (file.exists(direct)) return(normalizePath(outer, winslash = "/", mustWork = FALSE))
  kids <- sort(list.dirs(outer, recursive = FALSE, full.names = TRUE), decreasing = TRUE)
  for (kid in kids) {
    if (file.exists(file.path(kid, "tables", "campaign_fit_summary.csv"))) {
      return(normalizePath(kid, winslash = "/", mustWork = FALSE))
    }
  }
  NA_character_
}

mine_status <- if (isTRUE(skip_mine)) {
  if (!file.exists(selection_csv)) {
    stop("Cannot --skip-mine because selection CSV does not exist: ", selection_csv, call. = FALSE)
  }
  cat(sprintf("[historical-winner-handoff] mine skipped; using selection: %s\n", selection_csv))
  0L
} else {
  run_cmd(
    label = "mine_historical_winners",
    cmd = "Rscript",
    args = c(
      file.path("scripts", "mine_qdesn_tt500_vb_historical_winners.R"),
      "--out-dir", out_dir,
      "--top-per-cell", as.character(top_per_cell),
      "--stamp", stamp_id
    )
  )
}
if (!identical(mine_status, 0L)) stop("Historical-winner mining failed. Inspect orchestrator logs.", call. = FALSE)
if (isTRUE(mine_only)) {
  materialize_status <- prepare_status <- smoke_status <- run_status <- generic_rank_status <- dominance_rank_status <- strict_audit_status <- NA_integer_
  expected_roots <- NA_integer_
  campaign_report_root <- campaign_results_root <- NA_character_
} else {
  materialize_status <- if (isTRUE(skip_materialize)) {
    if (!file.exists(materialization_manifest)) {
      stop("Cannot --skip-materialize because materialization manifest does not exist: ", materialization_manifest, call. = FALSE)
    }
    cat(sprintf("[historical-winner-handoff] materialize skipped; using manifest: %s\n", materialization_manifest))
    0L
  } else {
    run_cmd(
      label = "materialize",
      cmd = "Rscript",
      args = c(
        file.path("scripts", "materialize_qdesn_tt500_vb_historical_winner_handoff.R"),
        "--selection-csv", selection_csv,
        "--base-defaults", base_defaults_path,
        "--stage-file", stage_file,
        "--workers", as.character(workers),
        "--likelihoods", likelihoods,
        "--stamp", stamp_id,
        if (isTRUE(refresh_materialized)) "--refresh-materialized" else character(0)
      )
    )
  }
  if (!identical(materialize_status, 0L)) stop("Historical-winner handoff materialization failed. Inspect orchestrator logs.", call. = FALSE)
  if (!file.exists(materialization_manifest)) stop("Materialization manifest is missing: ", materialization_manifest, call. = FALSE)
  mat <- jsonlite::read_json(materialization_manifest, simplifyVector = TRUE)
  expected_roots <- as.integer(mat$materialized$expected_qdesn_roots)

  prepare_status <- NA_integer_
  if (!isTRUE(materialize_only) && !isTRUE(skip_prepare) && (isTRUE(prepare_only) || isTRUE(do_smoke) || isTRUE(do_full))) {
    prepare_status <- run_cmd(
      label = "prepare_preflight",
      cmd = "Rscript",
      args = c(
        file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
        "--defaults", defaults_path,
        "--grid", grid_path,
        "--batch", "full",
        "--methods", "vb",
        "--likelihoods", likelihoods,
        "--fit-sizes", "500",
        "--priors", "rhs_ns",
        "--allow-grid-subset",
        "--prepare-only",
        "--workers", as.character(workers),
        "--scheduler", "load_balanced",
        "--run-tag", paste0(run_tag, "-prepare")
      )
    )
    if (!identical(prepare_status, 0L)) stop("Historical-winner handoff prepare preflight failed. Inspect orchestrator logs.", call. = FALSE)
  }

  smoke_status <- NA_integer_
  if (isTRUE(do_smoke) && !isTRUE(materialize_only)) {
    smoke_status <- run_cmd(
      label = "smoke_run",
      cmd = "Rscript",
      args = c(
        file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
        "--defaults", defaults_path,
        "--grid", grid_path,
        "--batch", "smoke",
        "--methods", "vb",
        "--likelihoods", likelihoods,
        "--fit-sizes", "500",
        "--priors", "rhs_ns",
        "--allow-grid-subset",
        "--workers", "1",
        "--scheduler", "sequential",
        "--run-tag", paste0(run_tag, "-smoke")
      )
    )
    if (!identical(smoke_status, 0L)) stop("Historical-winner handoff smoke failed. Inspect orchestrator logs.", call. = FALSE)
  }

  run_status <- generic_rank_status <- dominance_rank_status <- strict_audit_status <- NA_integer_
  campaign_report_root <- campaign_results_root <- NA_character_
  if (isTRUE(do_full) && !isTRUE(materialize_only) && !isTRUE(prepare_only)) {
    run_status <- run_cmd(
      label = "full_run",
      cmd = "Rscript",
      args = c(
        file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
        "--defaults", defaults_path,
        "--grid", grid_path,
        "--batch", "full",
        "--methods", "vb",
        "--likelihoods", likelihoods,
        "--fit-sizes", "500",
        "--priors", "rhs_ns",
        "--allow-grid-subset",
        "--workers", as.character(workers),
        "--scheduler", "load_balanced",
        "--run-tag", run_tag
      )
    )
    defaults <- yaml::read_yaml(defaults_path)
    campaign_report_root <- latest_campaign_report(defaults$campaign$reports_root, run_tag)
    if (!is.na(campaign_report_root)) {
      campaign_manifest_path <- file.path(campaign_report_root, "manifest", "campaign_manifest.json")
      if (file.exists(campaign_manifest_path)) {
        campaign_manifest <- jsonlite::read_json(campaign_manifest_path, simplifyVector = TRUE)
        campaign_results_root <- as.character(campaign_manifest$results_root %||% NA_character_)
      }
    }
    if (identical(run_status, 0L) && !is.na(campaign_report_root) && !isTRUE(skip_rank)) {
      generic_rank_status <- run_cmd(
        label = "generic_rank",
        cmd = "Rscript",
        args = c(
          file.path("scripts", "rank_qdesn_tt500_vb_screen.R"),
          "--report-root", campaign_report_root,
          "--top-n", "40"
        )
      )
      if (identical(generic_rank_status, 0L)) {
        dominance_rank_status <- run_cmd(
          label = "dominance_rank",
          cmd = "Rscript",
          args = c(
            file.path("scripts", "rank_qdesn_tt500_vb_dominance_screen.R"),
            "--report-root", campaign_report_root,
            "--baseline", baseline_path,
            "--top-n", "40"
          )
        )
      }
      strict_audit_status <- run_cmd(
        label = "strict_audit",
        cmd = "Rscript",
        args = c(
          file.path("scripts", "audit_qdesn_tt500_vb_dominance_screening.R"),
          "--report-root", campaign_report_root,
          "--results-root", campaign_results_root,
          "--expected-roots", as.character(expected_roots),
          "--strict",
          "--require-rankings"
        )
      )
    }
  }
}

manifest <- list(
  generated_at = as.character(Sys.time()),
  stage = "qdesn_vb_historical_winner_handoff",
  orchestrator_tag = orchestrator_tag,
  run_tag = run_tag,
  repo_root = repo_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  workers = as.integer(workers),
  top_per_cell = as.integer(top_per_cell),
  likelihoods = likelihoods,
  dry_run = isTRUE(dry_run),
  mine_only = isTRUE(mine_only),
  materialize_only = isTRUE(materialize_only),
  prepare_only = isTRUE(prepare_only),
  smoke_requested = isTRUE(do_smoke),
  full_requested = isTRUE(do_full),
  launch_approved = isTRUE(launch_approved),
  stage_file = stage_file,
  selection_csv = selection_csv,
  base_defaults_path = base_defaults_path,
  baseline_path = baseline_path,
  profiles_path = profiles_path,
  assignments_path = assignments_path,
  defaults_path = defaults_path,
  grid_path = grid_path,
  materialization_manifest = materialization_manifest,
  expected_roots = expected_roots,
  campaign_report_root = campaign_report_root,
  campaign_results_root = campaign_results_root,
  statuses = list(
    mine = mine_status,
    materialize = materialize_status,
    prepare = prepare_status,
    smoke = smoke_status,
    full = run_status,
    generic_rank = generic_rank_status,
    dominance_rank = dominance_rank_status,
    strict_audit = strict_audit_status
  )
)
manifest_path <- file.path(orchestrator_root, "manifest", "orchestrator_manifest.json")
exdqlm:::.qdesn_validation_write_json(manifest_path, manifest)

cat(sprintf("orchestrator_root: %s\n", orchestrator_root))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("run_tag: %s\n", run_tag))
cat(sprintf("expected_roots: %s\n", as.character(expected_roots)))
cat(sprintf("campaign_report_root: %s\n", campaign_report_root))
cat(sprintf("launch_approved: %s\n", isTRUE(launch_approved)))

statuses <- unlist(manifest$statuses, use.names = TRUE)
statuses <- statuses[!is.na(statuses)]
quit(status = if (any(as.integer(statuses) != 0L)) 1L else 0L, save = "no")

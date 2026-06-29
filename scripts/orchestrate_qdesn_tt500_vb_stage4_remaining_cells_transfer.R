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
`%||%` <- function(a, b) if (is.null(a)) b else a

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

article_summary_path <- resolve_path(get_arg(
  "--article-summary",
  "/data/jaguir26/local/src/Article-Q-DESN/tables/qdesn_validation_tt500_final_summary.csv"
), must_work = TRUE)
workers <- min(int_arg("--workers", 12L), 30L)
git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("qdesn-tt500-vb-stage4-transfer-%s__git-%s", stamp, git_sha)
))[1L]
orchestrator_tag <- as.character(get_arg(
  "--orchestrator-tag",
  sprintf("qdesn-tt500-vb-stage4-transfer-orchestrator-%s__git-%s", stamp, git_sha)
))[1L]
dry_run <- has_flag("--dry-run")
prepare_only <- has_flag("--prepare-only")
do_smoke <- has_flag("--smoke") || has_flag("--full")
do_full <- has_flag("--full") && !isTRUE(dry_run)
skip_rank <- has_flag("--skip-rank")
refresh_materialized <- has_flag("--refresh-materialized")
include_sentinels <- has_flag("--include-sentinels")
skip_materialize <- has_flag("--skip-materialize")

stage_file <- "qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer"
profiles_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_profiles.csv")), must_work = FALSE)
assignments_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_cell_assignments.csv")), must_work = FALSE)
defaults_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_defaults.yaml")), must_work = FALSE)
grid_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_grid.csv")), must_work = FALSE)
materialization_manifest <- resolve_path(file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json")), must_work = FALSE)

orchestrator_root <- file.path(
  repo_root,
  "reports",
  "qdesn_mcmc_validation",
  "qdesn_tt500_vb_stage4_remaining_cells_transfer",
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
  cat(sprintf("[stage4-transfer] %s start: %s\n", label, Sys.time()))
  status <- system2(cmd, args = args, stdout = log_path, stderr = log_path)
  cat(sprintf("[stage4-transfer] %s status=%d end: %s\n", label, as.integer(status), Sys.time()))
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

materialize_args <- c(
  file.path("scripts", "materialize_qdesn_tt500_vb_stage4_remaining_cells_transfer.R"),
  "--article-summary", article_summary_path,
  "--workers", as.character(workers),
  if (isTRUE(refresh_materialized)) "--refresh-materialized" else character(0),
  if (isTRUE(include_sentinels)) "--include-sentinels" else character(0)
)
materialize_status <- if (isTRUE(skip_materialize)) {
  if (!file.exists(materialization_manifest)) {
    stop("Cannot --skip-materialize because the Stage 4A materialization manifest does not exist.", call. = FALSE)
  }
  cat(sprintf("[stage4-transfer] materialize skipped; using committed manifest: %s\n", materialization_manifest))
  0L
} else {
  run_cmd(
    label = "materialize",
    cmd = "Rscript",
    args = materialize_args
  )
}
if (!identical(materialize_status, 0L)) {
  stop("Stage 4A transfer materialization failed. Inspect orchestrator logs.", call. = FALSE)
}
mat <- jsonlite::read_json(materialization_manifest, simplifyVector = TRUE)
expected_roots <- as.integer(mat$materialized$expected_qdesn_roots)

prepare_status <- run_cmd(
  label = "prepare_preflight",
  cmd = "Rscript",
  args = c(
    file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
    "--defaults", defaults_path,
    "--grid", grid_path,
    "--batch", "full",
    "--methods", "vb",
    "--likelihoods", "exal",
    "--fit-sizes", "500",
    "--priors", "rhs_ns",
    "--allow-grid-subset",
    "--prepare-only",
    "--workers", as.character(workers),
    "--scheduler", "load_balanced",
    "--run-tag", paste0(run_tag, "-prepare")
  )
)
if (!identical(prepare_status, 0L)) {
  stop("Stage 4A transfer prepare preflight failed. Inspect orchestrator logs.", call. = FALSE)
}

smoke_status <- NA_integer_
if (isTRUE(do_smoke)) {
  smoke_status <- run_cmd(
    label = "smoke_run",
    cmd = "Rscript",
    args = c(
      file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
      "--defaults", defaults_path,
      "--grid", grid_path,
      "--batch", "smoke",
      "--methods", "vb",
      "--likelihoods", "exal",
      "--fit-sizes", "500",
      "--priors", "rhs_ns",
      "--allow-grid-subset",
      "--workers", "1",
      "--scheduler", "sequential",
      "--run-tag", paste0(run_tag, "-smoke")
    )
  )
  if (!identical(smoke_status, 0L)) {
    stop("Stage 4A transfer smoke failed. Inspect orchestrator logs.", call. = FALSE)
  }
}

run_status <- NA_integer_
generic_rank_status <- NA_integer_
dominance_rank_status <- NA_integer_
audit_status <- NA_integer_
campaign_report_root <- NA_character_
campaign_results_root <- NA_character_
if (isTRUE(do_full) && !isTRUE(prepare_only)) {
  run_status <- run_cmd(
    label = "full_run",
    cmd = "Rscript",
    args = c(
      file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
      "--defaults", defaults_path,
      "--grid", grid_path,
      "--batch", "full",
      "--methods", "vb",
      "--likelihoods", "exal",
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
    manifest_path <- file.path(campaign_report_root, "manifest", "campaign_manifest.json")
    if (file.exists(manifest_path)) {
      campaign_manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
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
        "--top-n", "20"
      )
    )
    if (identical(generic_rank_status, 0L)) {
      dominance_rank_status <- run_cmd(
        label = "dominance_rank",
        cmd = "Rscript",
        args = c(
          file.path("scripts", "rank_qdesn_tt500_vb_dominance_screen.R"),
          "--report-root", campaign_report_root,
          "--baseline", article_summary_path,
          "--top-n", "20"
        )
      )
    }
    audit_status <- run_cmd(
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

manifest <- list(
  generated_at = as.character(Sys.time()),
  stage = "stage4_remaining_cells_transfer",
  orchestrator_tag = orchestrator_tag,
  run_tag = run_tag,
  repo_root = repo_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  workers = workers,
  dry_run = dry_run,
  prepare_only = prepare_only,
  skip_materialize = isTRUE(skip_materialize),
  smoke_requested = isTRUE(do_smoke),
  full_requested = isTRUE(do_full),
  include_sentinels = isTRUE(include_sentinels),
  article_summary_path = article_summary_path,
  profiles_path = profiles_path,
  assignments_path = assignments_path,
  defaults_path = defaults_path,
  grid_path = grid_path,
  materialization_manifest = materialization_manifest,
  expected_roots = expected_roots,
  statuses = list(
    materialize = materialize_status,
    prepare = prepare_status,
    smoke = smoke_status,
    full_run = run_status,
    generic_rank = generic_rank_status,
    dominance_rank = dominance_rank_status,
    strict_audit = audit_status
  ),
  campaign_report_root = campaign_report_root,
  campaign_results_root = campaign_results_root
)
manifest_path <- file.path(orchestrator_root, "manifest", "qdesn_tt500_vb_stage4_remaining_cells_transfer_orchestrator_manifest.json")
jsonlite::write_json(manifest, manifest_path, pretty = TRUE, auto_unbox = TRUE, null = "null")

cat(sprintf("orchestrator_root: %s\n", orchestrator_root))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("run_tag: %s\n", run_tag))
cat(sprintf("expected_roots: %d\n", expected_roots))
cat(sprintf("campaign_report_root: %s\n", campaign_report_root))

statuses <- unlist(manifest$statuses, use.names = TRUE)
statuses <- statuses[!is.na(statuses)]
quit(status = if (any(as.integer(statuses) != 0L)) 1L else 0L, save = "no")

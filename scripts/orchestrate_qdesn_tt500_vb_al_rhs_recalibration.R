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
  "/data/jaguir26/local/src/Article-Q-DESN__wt__main_validation_tables/tables/qdesn_validation_tt500_final_summary.csv"
), must_work = TRUE)
workers <- min(int_arg("--workers", 20L), 40L)
max_profiles <- int_arg("--max-profiles", 24L)
git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
run_tag <- as.character(get_arg("--run-tag", sprintf("qdesn-tt500-vb-al-rhs-recalibration-%s__git-%s", stamp, git_sha)))[1L]
orchestrator_tag <- as.character(get_arg("--orchestrator-tag", sprintf("qdesn-tt500-vb-al-rhs-recalibration-orchestrator-%s__git-%s", stamp, git_sha)))[1L]
dry_run <- has_flag("--dry-run")
prepare_only <- has_flag("--prepare-only")
do_smoke <- has_flag("--smoke") || has_flag("--full")
do_full <- has_flag("--full") && !isTRUE(dry_run)
skip_rank <- has_flag("--skip-rank")
refresh_materialized <- has_flag("--refresh-materialized")

stage_file <- "qdesn_dynamic_fitforecast_v2_tt500_vb_al_rhs_recalibration"
defaults_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_defaults.yaml")), must_work = FALSE)
grid_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_grid.csv")), must_work = FALSE)
materialization_manifest <- resolve_path(file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json")), must_work = FALSE)

orchestrator_root <- file.path(repo_root, "reports", "qdesn_mcmc_validation", "qdesn_tt500_vb_al_rhs_recalibration", orchestrator_tag)
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
  cat(sprintf("[al-rhs] %s start: %s\n", label, Sys.time()))
  status <- system2(cmd, args = args, stdout = log_path, stderr = log_path)
  cat(sprintf("[al-rhs] %s status=%d end: %s\n", label, as.integer(status), Sys.time()))
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

audit_status <- run_cmd(
  label = "audit_need",
  cmd = "Rscript",
  args = c(
    file.path("scripts", "audit_qdesn_tt500_al_rhs_recalibration_need.R"),
    "--article-summary", article_summary_path,
    "--out-dir", file.path(orchestrator_root, "audit")
  )
)
if (!identical(audit_status, 0L)) stop("AL RHS need audit failed.", call. = FALSE)

materialize_status <- run_cmd(
  label = "materialize",
  cmd = "Rscript",
  args = c(
    file.path("scripts", "materialize_qdesn_tt500_vb_al_rhs_recalibration.R"),
    "--article-summary", article_summary_path,
    "--workers", as.character(workers),
    "--max-profiles", as.character(max_profiles),
    if (isTRUE(refresh_materialized)) "--refresh-materialized" else character(0)
  )
)
if (!identical(materialize_status, 0L)) stop("AL RHS materialization failed.", call. = FALSE)
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
    "--likelihoods", "al",
    "--fit-sizes", "500",
    "--priors", "rhs_ns",
    "--allow-grid-subset",
    "--prepare-only",
    "--workers", as.character(workers),
    "--scheduler", "load_balanced",
    "--run-tag", paste0(run_tag, "-prepare")
  )
)
if (!identical(prepare_status, 0L)) stop("AL RHS prepare preflight failed.", call. = FALSE)

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
      "--likelihoods", "al",
      "--fit-sizes", "500",
      "--priors", "rhs_ns",
      "--allow-grid-subset",
      "--workers", "1",
      "--scheduler", "sequential",
      "--run-tag", paste0(run_tag, "-smoke")
    )
  )
  if (!identical(smoke_status, 0L)) stop("AL RHS smoke failed.", call. = FALSE)
}

run_status <- NA_integer_
generic_rank_status <- NA_integer_
dominance_rank_status <- NA_integer_
strict_audit_status <- NA_integer_
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
      "--likelihoods", "al",
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
      args = c(file.path("scripts", "rank_qdesn_tt500_vb_screen.R"), "--report-root", campaign_report_root, "--top-n", "20")
    )
    dominance_rank_status <- run_cmd(
      label = "dominance_rank",
      cmd = "Rscript",
      args = c(file.path("scripts", "rank_qdesn_tt500_vb_dominance_screen.R"), "--report-root", campaign_report_root, "--baseline", article_summary_path, "--top-n", "20")
    )
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

manifest <- list(
  generated_at = as.character(Sys.time()),
  stage = "al_rhs_recalibration",
  orchestrator_tag = orchestrator_tag,
  run_tag = run_tag,
  repo_root = repo_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  workers = workers,
  max_profiles = max_profiles,
  dry_run = dry_run,
  prepare_only = prepare_only,
  do_smoke = do_smoke,
  do_full = do_full,
  expected_roots = expected_roots,
  defaults_path = defaults_path,
  grid_path = grid_path,
  materialization_manifest = materialization_manifest,
  campaign_report_root = campaign_report_root,
  campaign_results_root = campaign_results_root,
  statuses = list(
    audit_need = audit_status,
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
cat(sprintf("expected_roots: %d\n", expected_roots))

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

stage <- match.arg(as.character(get_arg("--stage", "refinement"))[1L], c("refinement", "seed_stability", "replacement"))
stage_file <- switch(
  stage,
  refinement = "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement",
  seed_stability = "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_seed_stability",
  replacement = "qdesn_dynamic_fitforecast_v2_tt500_vb_replacement_frozen"
)
workers <- min(int_arg("--workers", 20L), 30L)
git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("qdesn-tt500-vb-%s-%s__git-%s", gsub("_", "-", stage), stamp, git_sha)
))[1L]
orchestrator_tag <- as.character(get_arg(
  "--orchestrator-tag",
  sprintf("qdesn-tt500-vb-%s-orchestrator-%s__git-%s", gsub("_", "-", stage), stamp, git_sha)
))[1L]
dry_run <- has_flag("--dry-run")
do_smoke <- has_flag("--smoke")
do_full <- has_flag("--full")
if (do_full && dry_run) do_full <- FALSE
ranking_path <- resolve_path(get_arg("--ranking", ""), must_work = TRUE)
source_profiles_path <- resolve_path(
  get_arg("--source-profiles", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_profiles.csv")),
  must_work = TRUE
)
base_defaults_path <- resolve_path(
  get_arg("--base-defaults", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_defaults.yaml")),
  must_work = TRUE
)
profiles_out <- resolve_path(
  get_arg("--profiles-out", file.path("config", "validation", paste0(stage_file, "_profiles.csv"))),
  must_work = FALSE
)
defaults_out <- resolve_path(
  get_arg("--defaults-out", file.path("config", "validation", paste0(stage_file, "_defaults.yaml"))),
  must_work = FALSE
)
grid_out <- resolve_path(
  get_arg("--grid-out", file.path("config", "validation", paste0(stage_file, "_grid.csv"))),
  must_work = FALSE
)
top_n <- int_arg("--top-n", if (identical(stage, "replacement")) 1L else 12L)
seed_value <- get_arg("--seed", NULL)
seed_value <- if (is.null(seed_value)) NULL else suppressWarnings(as.integer(seed_value)[1L])
baseline_path <- resolve_path(get_arg(
  "--baseline",
  "/data/jaguir26/local/src/Article-Q-DESN/tables/qdesn_validation_tt500_final_summary.csv"
), must_work = FALSE)
require_dominance_pass <- has_flag("--require-dominance-pass")
refresh_materialized <- has_flag("--refresh-materialized")
skip_rank <- has_flag("--skip-rank")

orchestrator_root <- file.path(
  repo_root,
  "reports",
  "qdesn_mcmc_validation",
  "qdesn_tt500_vb_dominance_followup",
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
  cat(sprintf("[followup] %s start: %s\n", label, Sys.time()))
  status <- system2(cmd, args = args, stdout = log_path, stderr = log_path)
  cat(sprintf("[followup] %s status=%d end: %s\n", label, as.integer(status), Sys.time()))
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

profiles <- exdqlm:::qdesn_dynamic_fitforecast_profiles_from_ranking(
  ranking_path = ranking_path,
  source_profiles_path = source_profiles_path,
  top_n = top_n,
  screening_stage = switch(
    stage,
    refinement = "dominance_refinement",
    seed_stability = "dominance_seed_stability",
    replacement = "tt500_vb_replacement_frozen"
  ),
  screening_wave = paste0(stage, "_", format(Sys.Date(), "%Y_%m_%d")),
  profile_role = switch(
    stage,
    refinement = "refinement_top",
    seed_stability = "seed_stability_top",
    replacement = "frozen_global"
  ),
  seed = seed_value,
  require_dominance_pass = require_dominance_pass
)
materialized <- exdqlm:::qdesn_dynamic_fitforecast_materialize_followup_stage(
  stage = stage,
  profiles = profiles,
  base_defaults_path = base_defaults_path,
  profiles_out = profiles_out,
  defaults_out = defaults_out,
  grid_out = grid_out,
  workers = workers,
  refresh_grid = !isTRUE(dry_run),
  refresh_materialized = refresh_materialized
)

stage_results <- list(materialize = materialized)
prepare_status <- run_cmd(
  label = "prepare_preflight",
  cmd = "Rscript",
  args = c(
    file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
    "--defaults", defaults_out,
    "--grid", grid_out,
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
stage_results$prepare <- list(status = prepare_status)
if (!identical(prepare_status, 0L)) {
  stop("Follow-up prepare preflight failed. Inspect orchestrator logs.", call. = FALSE)
}

smoke_status <- NA_integer_
if (isTRUE(do_smoke)) {
  smoke_status <- run_cmd(
    label = "smoke_run",
    cmd = "Rscript",
    args = c(
      file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
      "--defaults", defaults_out,
      "--grid", grid_out,
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
}
stage_results$smoke <- list(status = smoke_status)

run_status <- NA_integer_
report_root <- NA_character_
generic_rank_status <- NA_integer_
dominance_rank_status <- NA_integer_
audit_status <- NA_integer_
if (isTRUE(do_full)) {
  run_status <- run_cmd(
    label = "full_run",
    cmd = "Rscript",
    args = c(
      file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
      "--defaults", defaults_out,
      "--grid", grid_out,
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
  defaults <- yaml::read_yaml(defaults_out)
  report_root <- latest_campaign_report(defaults$campaign$reports_root, run_tag)
  if (identical(run_status, 0L) && !is.na(report_root) && !isTRUE(skip_rank)) {
    generic_rank_status <- run_cmd(
      label = "generic_rank",
      cmd = "Rscript",
      args = c(
        file.path("scripts", "rank_qdesn_tt500_vb_screen.R"),
        "--report-root", report_root,
        "--top-n", "20"
      )
    )
    if (identical(generic_rank_status, 0L) && file.exists(baseline_path)) {
      dominance_rank_status <- run_cmd(
        label = "dominance_rank",
        cmd = "Rscript",
        args = c(
          file.path("scripts", "rank_qdesn_tt500_vb_dominance_screen.R"),
          "--report-root", report_root,
          "--baseline", baseline_path,
          "--top-n", "20"
        )
      )
    }
    audit_status <- run_cmd(
      label = "strict_audit",
      cmd = "Rscript",
      args = c(
        file.path("scripts", "audit_qdesn_tt500_vb_dominance_screening.R"),
        "--report-root", report_root,
        "--expected-roots", as.character(materialized$expected_qdesn_roots),
        "--strict",
        "--require-rankings"
      )
    )
  }
}
stage_results$full <- list(
  run_tag = run_tag,
  run_status = run_status,
  report_root = report_root,
  generic_rank_status = generic_rank_status,
  dominance_rank_status = dominance_rank_status,
  audit_status = audit_status
)

manifest <- list(
  generated_at = as.character(Sys.time()),
  stage = stage,
  orchestrator_tag = orchestrator_tag,
  run_tag = run_tag,
  repo_root = repo_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  workers = workers,
  dry_run = dry_run,
  smoke_requested = isTRUE(do_smoke),
  full_requested = isTRUE(do_full),
  ranking_path = ranking_path,
  source_profiles_path = source_profiles_path,
  baseline_path = baseline_path,
  stages = stage_results
)
manifest_path <- file.path(orchestrator_root, "manifest", "qdesn_tt500_vb_dominance_followup_manifest.json")
jsonlite::write_json(manifest, manifest_path, pretty = TRUE, auto_unbox = TRUE, null = "null")

cat(sprintf("orchestrator_root: %s\n", orchestrator_root))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("profiles: %s\n", profiles_out))
cat(sprintf("defaults: %s\n", defaults_out))
cat(sprintf("grid: %s\n", grid_out))
cat(sprintf("expected_roots: %d\n", as.integer(materialized$expected_qdesn_roots)))
cat(sprintf("full_requested: %s\n", as.character(isTRUE(do_full))))

failed <- vapply(stage_results, function(x) {
  vals <- unlist(x[names(x) %in% c("status", "run_status", "generic_rank_status", "dominance_rank_status", "audit_status")], use.names = FALSE)
  vals <- vals[!is.na(vals)]
  any(as.integer(vals) != 0L)
}, logical(1L))
quit(status = if (any(failed)) 1L else 0L, save = "no")

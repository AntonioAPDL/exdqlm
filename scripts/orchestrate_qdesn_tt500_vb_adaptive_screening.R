#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload")
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

workers <- suppressWarnings(as.integer(get_arg("--workers", "20"))[1L])
if (!is.finite(workers) || workers < 1L) workers <- 20L
workers <- min(workers, 30L)
git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
orchestrator_tag <- as.character(get_arg(
  "--orchestrator-tag",
  sprintf("qdesn-tt500-vb-adaptive-screening-%s__git-%s", stamp, git_sha)
))[1L]
confirm_tag <- as.character(get_arg(
  "--confirm-tag",
  sprintf("qdesn-tt500-vb-confirm-top10-%s__git-%s", stamp, git_sha)
))[1L]
broad_tag <- as.character(get_arg(
  "--broad-tag",
  sprintf("qdesn-tt500-vb-broad-%s__git-%s", stamp, git_sha)
))[1L]
skip_broad <- has_flag("--skip-broad")
dry_run <- has_flag("--dry-run")

orchestrator_root <- file.path(
  repo_root,
  "reports",
  "qdesn_mcmc_validation",
  "qdesn_tt500_vb_adaptive_screening",
  orchestrator_tag
)
dir.create(file.path(orchestrator_root, "logs"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(orchestrator_root, "manifest"), recursive = TRUE, showWarnings = FALSE)

run_cmd <- function(label, cmd, args) {
  log_path <- file.path(orchestrator_root, "logs", paste0(label, ".log"))
  line <- paste(shQuote(c(cmd, args)), collapse = " ")
  writeLines(line, file.path(orchestrator_root, "logs", paste0(label, "_command.txt")))
  if (isTRUE(dry_run)) {
    cat(sprintf("[dry-run] %s\n", line))
    return(0L)
  }
  cat(sprintf("[orchestrator] %s start: %s\n", label, Sys.time()))
  status <- system2(cmd, args = args, stdout = log_path, stderr = log_path)
  cat(sprintf("[orchestrator] %s status=%d end: %s\n", label, as.integer(status), Sys.time()))
  as.integer(status)
}

latest_campaign_report <- function(base_report_root, run_tag) {
  outer <- file.path(repo_root, base_report_root, run_tag)
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

stage_specs <- list(
  confirmation = list(
    tag = confirm_tag,
    defaults = file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_confirm_defaults.yaml"),
    grid = file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_confirm_grid.csv"),
    report_base = file.path("reports", "qdesn_mcmc_validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_confirm")
  ),
  broad = list(
    tag = broad_tag,
    defaults = file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_broad_defaults.yaml"),
    grid = file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_broad_grid.csv"),
    report_base = file.path("reports", "qdesn_mcmc_validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_broad")
  )
)
if (isTRUE(skip_broad)) {
  stage_specs <- stage_specs["confirmation"]
}

stage_results <- list()
for (stage_name in names(stage_specs)) {
  spec <- stage_specs[[stage_name]]
  status <- run_cmd(
    label = paste0(stage_name, "_run"),
    cmd = "Rscript",
    args = c(
      file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
      "--defaults", spec$defaults,
      "--grid", spec$grid,
      "--batch", "full",
      "--methods", "vb",
      "--likelihoods", "exal",
      "--fit-sizes", "500",
      "--priors", "rhs_ns",
      "--allow-grid-subset",
      "--workers", as.character(workers),
      "--scheduler", "load_balanced",
      "--run-tag", spec$tag
    )
  )
  report_root <- latest_campaign_report(spec$report_base, spec$tag)
  rank_status <- NA_integer_
  if (identical(status, 0L) && !is.na(report_root)) {
    rank_status <- run_cmd(
      label = paste0(stage_name, "_rank"),
      cmd = "Rscript",
      args = c(
        file.path("scripts", "rank_qdesn_tt500_vb_screen.R"),
        "--report-root", report_root,
        "--top-n", "20"
      )
    )
  }
  stage_results[[stage_name]] <- list(
    run_tag = spec$tag,
    defaults = spec$defaults,
    grid = spec$grid,
    report_root = report_root,
    run_status = status,
    rank_status = rank_status
  )
  if (!identical(status, 0L) || (!is.na(rank_status) && !identical(rank_status, 0L))) {
    break
  }
}

manifest <- list(
  generated_at = as.character(Sys.time()),
  orchestrator_tag = orchestrator_tag,
  repo_root = repo_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  workers = workers,
  dry_run = dry_run,
  skip_broad = skip_broad,
  stages = stage_results
)
jsonlite::write_json(
  manifest,
  file.path(orchestrator_root, "manifest", "qdesn_tt500_vb_adaptive_screening_manifest.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)
cat(sprintf("orchestrator_root: %s\n", orchestrator_root))
cat(sprintf("manifest: %s\n", file.path(orchestrator_root, "manifest", "qdesn_tt500_vb_adaptive_screening_manifest.json")))
failed <- vapply(stage_results, function(x) !identical(x$run_status, 0L) || (!is.na(x$rank_status) && !identical(x$rank_status, 0L)), logical(1L))
quit(status = if (any(failed)) 1L else 0L, save = "no")

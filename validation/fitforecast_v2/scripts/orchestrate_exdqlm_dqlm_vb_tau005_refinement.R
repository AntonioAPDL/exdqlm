#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) {
  sub("^--file=", "", file_arg[[1L]])
} else {
  "validation/fitforecast_v2/scripts/orchestrate_exdqlm_dqlm_vb_tau005_refinement.R"
}
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- ffv2_repo_root()
setwd(repo_root)

int_arg <- function(name, default) {
  val <- suppressWarnings(as.integer(args[[name]] %||% default)[1L])
  if (is.finite(val)) val else as.integer(default)
}

flag <- function(name) ffv2_truthy(args[[name]] %||% FALSE)

git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
candidates_path <- args$candidates %||%
  file.path(harness_root, "config", "exdqlm_dqlm_vb_tau005_refinement_candidates_20260706.csv")
run_tag <- args$`run-tag` %||%
  sprintf("20260706_exdqlm_dqlm_vb_tau005_refinement__git-%s", git_sha)
orchestrator_tag <- args$`orchestrator-tag` %||%
  sprintf("exdqlm-dqlm-vb-tau005-refinement-orchestrator-%s__git-%s", stamp, git_sha)
workers <- max(1L, min(int_arg("workers", 12L), 40L))
families <- args$families %||% "gausmix,laplace,normal"
taus <- args$taus %||% "0.05"
smoke_family <- args$`smoke-family` %||% "normal"
smoke_tau <- suppressWarnings(as.numeric(args$`smoke-tau` %||% "0.05")[1L])
smoke_candidates <- ffv2_split_csv_arg(args$`smoke-candidates` %||%
  "t005_anchor_ni23,t005_trend25_season05_df099")
dry_run <- flag("dry-run")
prepare_only <- flag("prepare-only")
do_smoke <- flag("smoke") || flag("full")
full_requested <- flag("full")
do_full <- full_requested && !dry_run
skip_prepare <- flag("skip-prepare")
overwrite <- flag("overwrite")

run_root <- file.path(repo_root, "validation", "fitforecast_v2", "runs", run_tag)
orchestrator_root <- file.path(run_root, "orchestrator", orchestrator_tag)
dir.create(file.path(orchestrator_root, "logs"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(orchestrator_root, "manifest"), recursive = TRUE, showWarnings = FALSE)

run_cmd <- function(label, cmd, cmd_args, env = character(0)) {
  log_path <- file.path(orchestrator_root, "logs", paste0(label, ".log"))
  cmd_path <- file.path(orchestrator_root, "logs", paste0(label, "_command.txt"))
  line <- paste(c(env, shQuote(cmd), shQuote(cmd_args)), collapse = " ")
  writeLines(line, cmd_path)
  if (dry_run) {
    cat(sprintf("[dry-run] %s\n", line))
    return(0L)
  }
  cat(sprintf("[exdqlm-tau005] %s start: %s\n", label, Sys.time()))
  status <- system2(cmd, args = cmd_args, stdout = log_path, stderr = log_path, env = env)
  cat(sprintf("[exdqlm-tau005] %s status=%d end: %s\n", label, as.integer(status), Sys.time()))
  as.integer(status)
}

prepare_status <- NA_integer_
if (skip_prepare) {
  cat(sprintf("[exdqlm-tau005] prepare skipped; using run root: %s\n", run_root))
  if (!file.exists(file.path(run_root, "manifests", "row_manifest.csv"))) {
    stop("--skip-prepare requested, but row_manifest.csv does not exist for run tag ", run_tag,
         call. = FALSE)
  }
  prepare_status <- 0L
} else {
  prepare_status <- run_cmd(
    "prepare",
    "Rscript",
    c(
      file.path("validation", "fitforecast_v2", "scripts", "prepare_exdqlm_dqlm_vb_calibration_screen.R"),
      "--candidates", candidates_path,
      "--run-tag", run_tag,
      "--families", families,
      "--taus", taus,
      if (overwrite) "--overwrite" else character(0)
    )
  )
}
if (!identical(prepare_status, 0L)) {
  stop("exDQLM/DQLM tau=0.05 VB refinement prepare failed. Inspect orchestrator logs.",
       call. = FALSE)
}

manifest_path <- file.path(run_root, "manifests", "row_manifest.csv")

select_smoke_row_ids <- function(manifest_path) {
  manifest <- ffv2_read_csv(manifest_path)
  selected <- manifest[
    as.character(manifest$candidate_id) %in% smoke_candidates &
      as.character(manifest$family) == smoke_family &
      abs(as.numeric(manifest$tau) - smoke_tau) < 1e-8 &
      as.character(manifest$model_variant) %in% c("dqlm", "exdqlm"),
    ,
    drop = FALSE
  ]
  if (!nrow(selected)) {
    selected <- manifest[as.character(manifest$family) == smoke_family &
                           abs(as.numeric(manifest$tau) - smoke_tau) < 1e-8, , drop = FALSE]
  }
  selected <- selected[order(selected$candidate_id, selected$model_variant), , drop = FALSE]
  unique(as.integer(selected$row_id))[seq_len(min(4L, length(unique(as.integer(selected$row_id)))))]
}

smoke_row_ids <- integer(0)
smoke_status <- NA_integer_
if (do_smoke) {
  smoke_row_ids <- if (dry_run && !file.exists(manifest_path)) integer(0) else select_smoke_row_ids(manifest_path)
  if (!length(smoke_row_ids) && !dry_run) {
    stop("Could not select smoke rows from manifest: ", manifest_path, call. = FALSE)
  }
  if (length(smoke_row_ids)) {
    writeLines(as.character(smoke_row_ids), file.path(orchestrator_root, "manifest", "smoke_row_ids.txt"))
  }
  smoke_status <- run_cmd(
    "smoke",
    "Rscript",
    c(
      file.path("validation", "fitforecast_v2", "scripts", "launch_exdqlm_dynamic_fitforecast_v2_validation.R"),
      "--manifest", manifest_path,
      "--phase", "vb_full",
      "--validation-stage", "all",
      "--row-ids", if (length(smoke_row_ids)) paste(smoke_row_ids, collapse = ",") else "<selected-after-prepare>",
      "--workers", as.character(min(4L, workers))
    ),
    env = c("EXDQLM_FFV2_LAUNCH_APPROVED=true")
  )
  if (!identical(smoke_status, 0L)) {
    stop("exDQLM/DQLM tau=0.05 VB refinement smoke failed. Inspect orchestrator logs.",
         call. = FALSE)
  }
}

full_status <- NA_integer_
health_status <- NA_integer_
summary_status <- NA_integer_
if (do_full && !prepare_only) {
  full_status <- run_cmd(
    "full_run",
    "Rscript",
    c(
      file.path("validation", "fitforecast_v2", "scripts", "launch_exdqlm_dynamic_fitforecast_v2_validation.R"),
      "--manifest", manifest_path,
      "--phase", "vb_full",
      "--validation-stage", "all",
      "--workers", as.character(workers)
    ),
    env = c("EXDQLM_FFV2_LAUNCH_APPROVED=true")
  )
  if (identical(full_status, 0L)) {
    health_status <- run_cmd(
      "healthcheck",
      "Rscript",
      c(
        file.path("validation", "fitforecast_v2", "scripts", "healthcheck_exdqlm_dynamic_fitforecast_v2_validation.R"),
        "--manifest", manifest_path
      )
    )
    summary_status <- run_cmd(
      "summarize",
      "Rscript",
      c(
        file.path("validation", "fitforecast_v2", "scripts", "summarize_exdqlm_dqlm_vb_noninferiority_screen.R"),
        "--manifest", manifest_path
      )
    )
  }
}

manifest <- list(
  generated_at = as.character(Sys.time()),
  stage = "exdqlm_dqlm_vb_tau005_refinement",
  repo_root = repo_root,
  harness_root = harness_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  candidates_path = normalizePath(candidates_path, winslash = "/", mustWork = TRUE),
  run_tag = run_tag,
  run_root = normalizePath(run_root, winslash = "/", mustWork = FALSE),
  manifest_path = normalizePath(manifest_path, winslash = "/", mustWork = file.exists(manifest_path)),
  orchestrator_tag = orchestrator_tag,
  orchestrator_root = normalizePath(orchestrator_root, winslash = "/", mustWork = TRUE),
  workers = workers,
  families = families,
  taus = taus,
  smoke_family = smoke_family,
  smoke_tau = smoke_tau,
  smoke_candidates = smoke_candidates,
  smoke_row_ids = smoke_row_ids,
  dry_run = dry_run,
  prepare_only = prepare_only,
  smoke_requested = do_smoke,
  full_requested = full_requested,
  statuses = list(
    prepare = prepare_status,
    smoke = smoke_status,
    full = full_status,
    healthcheck = health_status,
    summarize = summary_status
  )
)
manifest_out <- file.path(orchestrator_root, "manifest", "orchestrator_manifest.json")
ffv2_write_json(manifest, manifest_out)

cat(sprintf("orchestrator_root: %s\n", orchestrator_root))
cat(sprintf("manifest: %s\n", manifest_out))
cat(sprintf("run_tag: %s\n", run_tag))
cat(sprintf("row_manifest: %s\n", manifest_path))
cat(sprintf("workers: %d\n", workers))

statuses <- unlist(manifest$statuses, use.names = TRUE)
statuses <- statuses[!is.na(statuses)]
quit(status = if (any(as.integer(statuses) != 0L)) 1L else 0L, save = "no")

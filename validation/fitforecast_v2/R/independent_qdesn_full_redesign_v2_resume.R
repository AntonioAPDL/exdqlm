iqfr_v2_resume_schema <- "independent_qdesn_full_redesign_v2_1_resume_v1"

iqfr_v2_resume_manifest_path <- function(run_root) {
  file.path(run_root, "manifests", "checkpoint_resume_authorization.json")
}

iqfr_v2_resume_artifact_path <- function(run_root) {
  file.path(run_root, "manifests", "checkpoint_resume_artifacts.csv")
}

iqfr_v2_resume_allowed_files <- c(
  "validation/fitforecast_v2/R/independent_qdesn_full_redesign_v2_resume.R",
  "validation/fitforecast_v2/scripts/manage_independent_qdesn_full_redesign_v2.R",
  "validation/fitforecast_v2/scripts/run_independent_qdesn_full_redesign_v2_job.R",
  "validation/fitforecast_v2/scripts/resume_independent_qdesn_full_redesign_v2_1.sh",
  "validation/fitforecast_v2/tests/testthat/test-independent-qdesn-full-redesign-v2.R",
  "validation/fitforecast_v2/docs/INDEPENDENT_QDESN_FULL_REDESIGN_V2_1_AUDIT_AND_RELAUNCH_2026-09-25.md"
)

iqfr_v2_bind_candidate_ledgers <- function(initial, adaptive) {
  if (!is.data.frame(initial) || !is.data.frame(adaptive) ||
      !nrow(initial) || !nrow(adaptive)) {
    stop("Candidate ledgers must be nonempty data frames.", call. = FALSE)
  }
  required <- c("family", "candidate_id", "structure_id", "rhs_tau0")
  optional <- "adaptive_tau_center"
  if (!all(required %in% names(initial)) ||
      !all(required %in% names(adaptive))) {
    stop("Candidate ledgers are missing identity columns.", call. = FALSE)
  }
  initial_core <- setdiff(names(initial), optional)
  adaptive_core <- setdiff(names(adaptive), optional)
  if (!setequal(initial_core, adaptive_core)) {
    stop("Candidate ledger core schemas differ.", call. = FALSE)
  }
  if (!optional %in% names(initial)) initial[[optional]] <- NA_real_
  if (!optional %in% names(adaptive)) adaptive[[optional]] <- NA_real_
  columns <- c(initial_core, optional)
  out <- rbind(
    initial[, columns, drop = FALSE],
    adaptive[, columns, drop = FALSE]
  )
  rownames(out) <- NULL
  if (anyNA(out$candidate_id) || anyDuplicated(out$candidate_id)) {
    stop("Combined candidate ledger has missing or duplicate identities.",
         call. = FALSE)
  }
  out
}

iqfr_v2_git_output <- function(repo_root, args) {
  out <- system2(
    "git", c("-C", repo_root, args), stdout = TRUE, stderr = TRUE
  )
  status <- attr(out, "status") %||% 0L
  if (!identical(as.integer(status), 0L)) {
    stop("Git command failed: git -C ", repo_root, " ",
         paste(args, collapse = " "), "\n", paste(out, collapse = "\n"),
         call. = FALSE)
  }
  out
}

iqfr_v2_checkpoint_artifacts <- function(run_root) {
  stage_dirs <- unlist(lapply(
    c("configs", "results", "status", "logs"),
    function(kind) file.path(
      run_root, kind, c("normal_initial", "normal_adaptive")
    )
  ), use.names = FALSE)
  paths <- unlist(lapply(stage_dirs, function(path) {
    if (!dir.exists(path)) return(character())
    list.files(path, recursive = TRUE, full.names = TRUE)
  }), use.names = FALSE)
  paths <- c(
    paths,
    list.files(file.path(run_root, "sources"), full.names = TRUE),
    file.path(run_root, "source_manifest.csv"),
    file.path(run_root, "plans", c(
      "normal_initial.csv", "normal_adaptive.csv"
    )),
    list.files(file.path(run_root, "summaries"), full.names = TRUE),
    list.files(file.path(run_root, "manifests"), full.names = TRUE)
  )
  paths <- paths[file.exists(paths) & !dir.exists(paths)]
  paths <- paths[!basename(paths) %in% c(
    basename(iqfr_v2_resume_manifest_path(run_root)),
    basename(iqfr_v2_resume_artifact_path(run_root))
  )]
  sort(unique(normalizePath(paths, winslash = "/", mustWork = TRUE)))
}

iqfr_v2_authorize_checkpoint_resume <- function(repo_root, run_root) {
  repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  run_root <- normalizePath(run_root, winslash = "/", mustWork = TRUE)
  if (dir.exists(file.path(run_root, ".pipeline_lock"))) {
    stop("Cannot authorize a resume while the pipeline lock exists.",
         call. = FALSE)
  }
  materialization <- iqfr_v2_read_json(file.path(
    run_root, "manifests", "materialization.json"
  ))
  environment <- iqfr_v2_read_json(file.path(
    run_root, "manifests", "environment.json"
  ))
  base_head <- as.character(materialization$git$head)
  if (!identical(base_head, as.character(environment$git_head))) {
    stop("Launch manifests disagree about the frozen Git HEAD.",
         call. = FALSE)
  }
  branch <- iqfr_v2_git_output(repo_root, c("branch", "--show-current"))
  current_head <- iqfr_v2_git_output(repo_root, c("rev-parse", "HEAD"))
  if (!identical(branch, iqfr_v2_expected_branch)) {
    stop("Checkpoint resume is on the wrong branch.", call. = FALSE)
  }
  if (identical(base_head, current_head)) {
    stop("Checkpoint resume requires a committed repair HEAD.",
         call. = FALSE)
  }
  status <- iqfr_v2_git_output(repo_root, c("status", "--porcelain"))
  if (length(status)) stop("Checkpoint resume requires a clean worktree.",
                           call. = FALSE)
  upstream <- iqfr_v2_git_output(
    repo_root,
    c("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}")
  )
  divergence <- iqfr_v2_git_output(
    repo_root, c("rev-list", "--left-right", "--count",
                 paste0("HEAD...", upstream))
  )
  divergence <- scan(text = divergence, quiet = TRUE)
  if (length(divergence) != 2L || any(divergence != 0)) {
    stop("Checkpoint repair branch is not synchronized with its upstream.",
         call. = FALSE)
  }
  ancestor_status <- system2(
    "git", c("-C", repo_root, "merge-base", "--is-ancestor",
             base_head, current_head), stdout = FALSE, stderr = FALSE
  )
  if (!identical(as.integer(ancestor_status), 0L)) {
    stop("The launch HEAD is not an ancestor of the repair HEAD.",
         call. = FALSE)
  }
  changed <- iqfr_v2_git_output(
    repo_root, c("diff", "--name-only", paste0(base_head, "..", current_head))
  )
  required_repairs <- c(
    "validation/fitforecast_v2/R/independent_qdesn_full_redesign_v2_resume.R",
    "validation/fitforecast_v2/scripts/manage_independent_qdesn_full_redesign_v2.R",
    "validation/fitforecast_v2/scripts/run_independent_qdesn_full_redesign_v2_job.R"
  )
  if (!length(changed) ||
      length(setdiff(changed, iqfr_v2_resume_allowed_files)) ||
      !all(required_repairs %in% changed)) {
    stop("Repair commit contains missing or unauthorized files: ",
         paste(setdiff(changed, iqfr_v2_resume_allowed_files), collapse = ", "),
         call. = FALSE)
  }
  plan_paths <- file.path(run_root, "plans", c(
    "normal_initial.csv", "normal_adaptive.csv"
  ))
  health <- do.call(rbind, lapply(plan_paths, iqfr_v2_stage_health))
  if (!all(health$complete) || any(health$failed > 0L) ||
      !identical(as.integer(sum(health$success)), 5472L) ||
      file.exists(file.path(run_root, "plans", "normal_full.csv"))) {
    stop("Run root is not at the approved 5,472-job checkpoint.",
         call. = FALSE)
  }
  binary_payloads <- list.files(
    run_root, pattern = "[.](rds|rda|rdata)$", recursive = TRUE,
    full.names = TRUE, ignore.case = TRUE
  )
  if (length(binary_payloads)) {
    stop("Unexpected fitted-model payloads exist at the checkpoint.",
         call. = FALSE)
  }
  artifacts <- iqfr_v2_checkpoint_artifacts(run_root)
  info <- file.info(artifacts)
  artifact_ledger <- data.frame(
    relative_path = substring(artifacts, nchar(run_root) + 2L),
    bytes = as.numeric(info$size),
    sha256 = unname(tools::sha256sum(artifacts)),
    stringsAsFactors = FALSE
  )
  artifact_path <- iqfr_v2_write_csv(
    artifact_ledger, iqfr_v2_resume_artifact_path(run_root)
  )
  diff_text <- iqfr_v2_git_output(
    repo_root, c("diff", "--binary", paste0(base_head, "..", current_head),
                 "--", changed)
  )
  authorization <- list(
    schema_version = iqfr_v2_resume_schema,
    status = "AUTHORIZED_ORCHESTRATION_ONLY_RESUME",
    authorization_pass = TRUE,
    created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    run_root = run_root,
    branch = branch,
    upstream = upstream,
    base_head = base_head,
    resume_head = current_head,
    changed_files = changed,
    allowed_changed_files = iqfr_v2_resume_allowed_files,
    git_diff_sha256 = digest::digest(
      paste(diff_text, collapse = "\n"), algo = "sha256", serialize = FALSE
    ),
    scientific_protocol_unchanged = TRUE,
    source_trajectories_unchanged = TRUE,
    completed_stage_health = health,
    completed_jobs = as.integer(sum(health$success)),
    completed_artifact_rows = nrow(artifact_ledger),
    completed_artifact_bytes = sum(artifact_ledger$bytes),
    completed_artifact_manifest_path = artifact_path,
    completed_artifact_manifest_sha256 = iqfr_v2_sha256(artifact_path),
    fitted_model_binaries = 0L,
    remaining_jobs = 480L
  )
  path <- iqfr_v2_write_json(
    authorization, iqfr_v2_resume_manifest_path(run_root)
  )
  list(path = path, authorization = authorization)
}

iqfr_v2_worker_head_contract <- function(materialization, environment,
                                         observed_head, run_root) {
  base_head <- as.character(materialization$git$head)
  environment_head <- as.character(environment$git_head)
  if (!identical(base_head, environment_head)) {
    return(list(pass = FALSE, mode = "launch_manifest_mismatch"))
  }
  if (identical(observed_head, base_head)) {
    return(list(
      pass = TRUE, mode = "frozen_launch_head",
      authorization_path = NA_character_, authorization_sha256 = NA_character_
    ))
  }
  path <- iqfr_v2_resume_manifest_path(run_root)
  if (!file.exists(path)) {
    return(list(pass = FALSE, mode = "missing_resume_authorization"))
  }
  authorization <- tryCatch(
    iqfr_v2_read_json(path), error = function(e) NULL
  )
  if (is.null(authorization)) {
    return(list(pass = FALSE, mode = "invalid_resume_authorization"))
  }
  artifact_path <- as.character(
    authorization$completed_artifact_manifest_path
  )
  pass <- identical(as.character(authorization$schema_version),
                    iqfr_v2_resume_schema) &&
    isTRUE(authorization$authorization_pass) &&
    identical(as.character(authorization$base_head), base_head) &&
    identical(as.character(authorization$resume_head), observed_head) &&
    identical(as.integer(authorization$completed_jobs), 5472L) &&
    file.exists(artifact_path) &&
    identical(iqfr_v2_sha256(artifact_path), as.character(
      authorization$completed_artifact_manifest_sha256
    ))
  list(
    pass = isTRUE(pass),
    mode = if (isTRUE(pass)) "authorized_checkpoint_resume" else
      "resume_authorization_failed",
    authorization_path = path,
    authorization_sha256 = iqfr_v2_sha256(path)
  )
}

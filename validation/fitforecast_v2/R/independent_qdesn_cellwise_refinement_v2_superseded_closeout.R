iqcr_v2_superseded_schema <-
  "independent_qdesn_cellwise_refinement_v2_superseded_closeout_v1"

iqcr_v2_superseded_read_status <- function(path) {
  if (!file.exists(path)) return(NULL)
  tryCatch(jsonlite::read_json(path, simplifyVector = TRUE),
           error = function(e) list(status = "UNREADABLE", error = conditionMessage(e)))
}

iqcr_v2_superseded_pid_alive <- function(pid) {
  pid <- suppressWarnings(as.integer(pid))
  if (!is.finite(pid) || pid < 1L) return(FALSE)
  identical(system2("kill", c("-0", pid), stdout = FALSE, stderr = FALSE), 0L)
}

iqcr_v2_superseded_inventory <- function(run_root) {
  run_root <- normalizePath(run_root, winslash = "/", mustWork = TRUE)
  configs <- list.files(file.path(run_root, "configs"), pattern = "[.]json$",
                        recursive = TRUE, full.names = TRUE)
  configs <- sort(configs)
  rows <- lapply(configs, function(config_path) {
    cfg <- jsonlite::read_json(config_path, simplifyVector = TRUE)
    stage <- as.character(cfg$stage)
    job_id <- as.character(cfg$job_id)
    status_path <- as.character(cfg$status_path)
    result_path <- as.character(cfg$result_path)
    status <- iqcr_v2_superseded_read_status(status_path)
    state <- if (is.null(status)) "PENDING" else
      toupper(as.character(status$status %||% "UNKNOWN"))
    pid <- suppressWarnings(as.integer(status$pid %||% NA_integer_))
    live <- identical(state, "RUNNING") && iqcr_v2_superseded_pid_alive(pid)
    expected_hash <- as.character(status$result_sha256 %||% NA_character_)
    observed_hash <- if (file.exists(result_path)) iqfr_v2_sha256(result_path) else
      NA_character_
    hash_pass <- if (!is.na(expected_hash) && nzchar(expected_hash)) {
      identical(expected_hash, observed_hash)
    } else NA
    data.frame(
      stage = stage, job_id = job_id, state = state,
      live_pid = live, pid = pid,
      config_path = normalizePath(config_path, winslash = "/", mustWork = TRUE),
      config_sha256 = iqfr_v2_sha256(config_path),
      status_path = status_path, status_exists = file.exists(status_path),
      result_path = result_path, result_exists = file.exists(result_path),
      expected_result_sha256 = expected_hash,
      observed_result_sha256 = observed_hash,
      result_hash_pass = hash_pass,
      stringsAsFactors = FALSE
    )
  })
  if (!length(rows)) stop("No predecessor configs were found.", call. = FALSE)
  do.call(rbind, rows)
}

iqcr_v2_superseded_stage_summary <- function(inventory) {
  stages <- unique(inventory$stage)
  rows <- lapply(stages, function(stage) {
    x <- inventory[inventory$stage == stage, , drop = FALSE]
    data.frame(
      stage = stage, planned = nrow(x),
      success = sum(x$state == "SUCCESS"),
      failed = sum(x$state == "FAILED"),
      running = sum(x$state == "RUNNING"),
      live = sum(x$live_pid),
      pending = sum(x$state == "PENDING"),
      result_files = sum(x$result_exists),
      verified_result_hashes = sum(x$result_hash_pass %in% TRUE),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

iqcr_v2_superseded_copy_file <- function(source, destination_root,
                                          relative_path) {
  if (!file.exists(source)) return(NULL)
  destination <- file.path(destination_root, relative_path)
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(source, destination, overwrite = TRUE, copy.mode = TRUE)) {
    stop("Could not copy closeout evidence: ", source, call. = FALSE)
  }
  data.frame(
    relative_path = relative_path,
    bytes = file.info(destination)$size,
    sha256 = iqfr_v2_sha256(destination),
    stringsAsFactors = FALSE
  )
}

iqcr_v2_superseded_closeout <- function(repo_root, run_root, output_dir) {
  repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  run_root <- normalizePath(run_root, winslash = "/", mustWork = TRUE)
  output_dir <- normalizePath(output_dir, winslash = "/", mustWork = FALSE)
  if (dir.exists(output_dir) && length(list.files(output_dir, all.files = TRUE,
                                                  no.. = TRUE))) {
    stop("Refusing to overwrite a nonempty closeout directory.", call. = FALSE)
  }
  inventory <- iqcr_v2_superseded_inventory(run_root)
  if (any(inventory$live_pid)) {
    stop("A predecessor model worker is still alive; closeout is not safe.",
         call. = FALSE)
  }
  success <- inventory$state == "SUCCESS"
  if (any(success & !inventory$result_exists) ||
      any(success & !(inventory$result_hash_pass %in% TRUE))) {
    stop("A successful predecessor job lacks a verified result.",
         call. = FALSE)
  }
  if (any(inventory$state == "FAILED")) {
    warning("The predecessor contains failed atomic jobs; preserving them in closeout.")
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  stage_summary <- iqcr_v2_superseded_stage_summary(inventory)
  iqfr_v2_write_csv(stage_summary, file.path(output_dir, "stage_summary.csv"))
  iqfr_v2_write_csv(inventory, file.path(output_dir, "job_integrity.csv"))

  whitelist <- c(
    "launch_environment.txt", "pipeline.stdout.log", "source_manifest.csv",
    file.path("manifests", c(
      "authority_manifest.csv", "candidate_pool.csv", "environment.json",
      "materialization.json", "mcmc_pilot_finalists.csv",
      "mcmc_pilot_materialization.json", "preflight_report.json",
      "quantile_bridge_candidates.csv", "quantile_bridge_materialization.json",
      "quantile_refinement_assignments.csv", "quantile_refinement_candidates.csv",
      "quantile_refinement_materialization.json",
      "rhs_coarse_best_per_structure.csv", "rhs_refinement_materialization.json",
      "rhs_screen_materialization.json", "session_info.txt",
      "structure_catalog.csv"
    )),
    file.path("plans", c(
      "ridge_screen.csv", "rhs_screen.csv", "rhs_refinement.csv",
      "quantile_bridge.csv", "quantile_refinement.csv", "mcmc_pilot.csv"
    )),
    file.path("summaries", c(
      "targeted_ridge_robust_ranking.csv", "rhs_coarse_robust_ranking.csv",
      "rhs_combined_robust_ranking.csv", "quantile_bridge_robust_ranking.csv",
      "quantile_combined_robust_ranking.csv"
    ))
  )
  copied <- lapply(whitelist, function(relative_path) {
    iqcr_v2_superseded_copy_file(
      file.path(run_root, relative_path), output_dir, relative_path
    )
  })
  copied <- copied[!vapply(copied, is.null, logical(1L))]

  canary <- inventory[inventory$stage == "mcmc_pilot" &
                        (inventory$status_exists | inventory$result_exists), ,
                      drop = FALSE]
  if (nrow(canary)) {
    for (i in seq_len(nrow(canary))) {
      relative_base <- file.path("mcmc_canary", canary$job_id[[i]])
      evidence <- c(
        config = canary$config_path[[i]], status = canary$status_path[[i]],
        result = canary$result_path[[i]]
      )
      for (kind in names(evidence)) {
        extension <- tools::file_ext(evidence[[kind]])
        relative_path <- paste0(relative_base, "__", kind,
                                if (nzchar(extension)) paste0(".", extension) else "")
        row <- iqcr_v2_superseded_copy_file(
          evidence[[kind]], output_dir, relative_path
        )
        if (!is.null(row)) copied[[length(copied) + 1L]] <- row
      }
    }
  }

  closeout <- list(
    schema_version = iqcr_v2_superseded_schema,
    decision = "SUPERSEDED_BY_CORRECTED_FORECAST_ESTIMAND_V3",
    article_promotion_authorized = FALSE,
    broad_mcmc_authorized = FALSE,
    run_root = run_root,
    predecessor_branch = "validation/independent-qdesn-cellwise-refinement-v2-20260929",
    predecessor_head = "b671dd59567343636e0eacc60af5b9938daa33a2",
    closeout_branch = iqcf_v3_expected_branch,
    closeout_head_at_generation = system2(
      "git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE
    ),
    counts = lapply(seq_len(nrow(stage_summary)), function(i) {
      as.list(stage_summary[i, , drop = FALSE])
    }),
    retained_fitted_model_binaries = 0L,
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
  iqfr_v2_write_json(closeout, file.path(output_dir, "closeout.json"))

  readme <- c(
    "# Cellwise Refinement v2 Superseded Closeout",
    "",
    "Decision: `SUPERSEDED_BY_CORRECTED_FORECAST_ESTIMAND_V3`.",
    "",
    "This packet freezes compact diagnostic evidence from the stopped v2",
    "campaign. It authorizes no article result and no continuation of the",
    "remaining v2 MCMC plan. Generated source copies and fitted-model binaries",
    "are deliberately excluded. See `stage_summary.csv`, `job_integrity.csv`,",
    "and `closeout.json` for the exact completion and hash state."
  )
  writeLines(readme, file.path(output_dir, "README.md"), useBytes = TRUE)

  generated <- c("README.md", "stage_summary.csv", "job_integrity.csv",
                 "closeout.json")
  copied_rows <- if (length(copied)) do.call(rbind, copied) else
    data.frame(relative_path = character(), bytes = numeric(),
               sha256 = character(), stringsAsFactors = FALSE)
  generated_rows <- data.frame(
    relative_path = generated,
    bytes = file.info(file.path(output_dir, generated))$size,
    sha256 = vapply(file.path(output_dir, generated), iqfr_v2_sha256,
                    character(1L)), stringsAsFactors = FALSE
  )
  manifest <- rbind(copied_rows, generated_rows)
  manifest <- manifest[order(manifest$relative_path), , drop = FALSE]
  iqfr_v2_write_csv(manifest, file.path(output_dir, "artifact_manifest.csv"))
  invisible(list(stage_summary = stage_summary, inventory = inventory,
                 manifest = manifest, closeout = closeout))
}

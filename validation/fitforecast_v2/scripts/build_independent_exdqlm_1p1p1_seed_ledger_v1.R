#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/build_independent_exdqlm_1p1p1_seed_ledger_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/", mustWork = TRUE)
legacy_plan_path <- normalizePath(args$`legacy-plan` %||% file.path(
  "/data/jaguir26/local/src/exdqlm__wt__independent_metric_intervals_v1_1p0p0",
  "reports/shared_fitforecast_v2_orchestration",
  "independent_metric_intervals_v1_production_20260823_225856",
  "manifests/job_plan.csv"
), winslash = "/", mustWork = TRUE)
output_path <- ffv2_resolve_path(args$output %||% i111_seed_ledger_path(repo_root),
                                 repo_root = repo_root, must_work = FALSE)

audit <- i111_static_audit(repo_root)
if (!all(audit$checks$pass)) stop("v11.1 authority audit failed.", call. = FALSE)
legacy_plan <- ffv2_read_csv(legacy_plan_path)
if (nrow(legacy_plan) != 198L || any(!file.exists(legacy_plan$config_path))) {
  stop("Legacy metric-interval plan is unavailable or incomplete.", call. = FALSE)
}

new_candidate <- "idol2_al_normal_t0p05_o1_orthogonalized_3e09_132580d19b"
new_requests <- list.files(
  file.path(repo_root, "validation", "fitforecast_v2", "audits",
            "independent_location_orthogonalized_tau0_v2_20260827", "requests"),
  pattern = "^point_confirmation_chain_[0-9]+[.]json$", full.names = TRUE
)
new_request_objects <- lapply(new_requests, ffv2_read_json)
new_request_candidates <- vapply(new_request_objects, function(x) {
  as.character(x$candidate_id %||% x$root_spec$screening_profile_id %||% "")
}, character(1L))
new_requests <- new_requests[new_request_candidates == new_candidate]
new_request_objects <- new_request_objects[new_request_candidates == new_candidate]
if (length(new_requests) != 3L) {
  stop("Expected three exact v11 location-orthogonalized confirmation requests.",
       call. = FALSE)
}

rows <- list()
row_i <- 0L
for (i in seq_len(nrow(audit$source_registry))) {
  source <- audit$source_registry[i, , drop = FALSE]
  for (chain_id in seq_len(as.integer(source$planned_chains[[1L]]))) {
    old <- legacy_plan[
      legacy_plan$source_identity == source$source_identity[[1L]] &
        as.integer(legacy_plan$chain_id) == chain_id,
      , drop = FALSE
    ]
    seed <- mcmc_seed <- mcmc_rng_seed <- vb_warm_start_seed <- synthesis_seed <-
      desn_seed <- NA_integer_
    request_override_path <- request_override_sha256 <- ""
    source_override_path <- source_override_sha256 <- ""
    seed_source <- ""
    if (nrow(old) == 1L) {
      old_cfg <- ffv2_read_json(old$config_path[[1L]])
      if (old$engine[[1L]] == "qdesn") {
        mcmc_seed <- as.integer(old_cfg$root_spec$mcmc_seed %||% NA_integer_)
        mcmc_rng_seed <- as.integer(old_cfg$root_spec$mcmc_rng_seed %||% NA_integer_)
        vb_warm_start_seed <- as.integer(old_cfg$root_spec$vb_warm_start_seed %||% NA_integer_)
        synthesis_seed <- as.integer(old_cfg$root_spec$synthesis_seed %||% NA_integer_)
        desn_seed <- as.integer(old_cfg$root_spec$desn_seed %||% old_cfg$config$desn$seed)
      } else {
        seed <- as.integer(old_cfg$seed)
      }
      seed_source <- "metric_intervals_v1_production_20260823_225856"
    } else if (identical(source$source_candidate_id[[1L]], new_candidate) &&
               chain_id <= length(new_request_objects)) {
      req_idx <- which(vapply(new_request_objects, function(x) {
        identical(as.integer(x$chain_id), chain_id)
      }, logical(1L)))
      if (length(req_idx) != 1L) stop("New candidate chain request join failed.", call. = FALSE)
      req <- new_request_objects[[req_idx]]
      path <- new_requests[[req_idx]]
      mcmc_seed <- as.integer(req$root_spec$mcmc_seed)
      mcmc_rng_seed <- as.integer(req$root_spec$mcmc_rng_seed)
      vb_warm_start_seed <- as.integer(req$root_spec$vb_warm_start_seed %||% NA_integer_)
      synthesis_seed <- as.integer(req$root_spec$synthesis_seed)
      desn_seed <- as.integer(req$root_spec$desn_seed %||% req$config$desn$seed)
      request_override_path <- imi_v1_relpath(path, repo_root)
      request_override_sha256 <- ffv2_file_sha256(path)
      source_override_path <- i111_v11_source_fixture_relpath
      source_override_sha256 <- i111_v11_source_fixture_sha256
      seed_source <- "v11_location_orthogonalized_point_confirmation"
    } else {
      stop(sprintf("No compatible seed source for %s chain %d.",
                   source$source_identity[[1L]], chain_id), call. = FALSE)
    }
    row_i <- row_i + 1L
    rows[[row_i]] <- data.frame(
      source_identity = source$source_identity[[1L]],
      model_variant = source$model_variant[[1L]],
      inference = source$inference[[1L]],
      chain_id = chain_id,
      seed = seed,
      mcmc_seed = mcmc_seed,
      mcmc_rng_seed = mcmc_rng_seed,
      vb_warm_start_seed = vb_warm_start_seed,
      synthesis_seed = synthesis_seed,
      desn_seed = desn_seed,
      seed_source = seed_source,
      request_override_path = request_override_path,
      request_override_sha256 = request_override_sha256,
      source_override_path = source_override_path,
      source_override_sha256 = source_override_sha256,
      legacy_plan_sha256 = ffv2_file_sha256(legacy_plan_path),
      stringsAsFactors = FALSE
    )
  }
}
ledger <- do.call(rbind, rows)
if (nrow(ledger) != i111_expected_jobs ||
    anyDuplicated(paste(ledger$source_identity, ledger$chain_id, sep = "|"))) {
  stop("Generated seed ledger violates the frozen 198-job contract.", call. = FALSE)
}
ffv2_write_csv(ledger, output_path)
cat(sprintf("seed ledger: rows=%d old=%d v11=%d path=%s sha256=%s\n",
            nrow(ledger), sum(grepl("metric_intervals_v1", ledger$seed_source)),
            sum(grepl("v11_", ledger$seed_source)), output_path,
            ffv2_file_sha256(output_path)))

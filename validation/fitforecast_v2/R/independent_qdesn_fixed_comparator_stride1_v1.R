iqfc_v1_schema <- "independent_qdesn_fixed_comparator_stride1_v1"
iqfc_v1_expected_branch <-
  "validation/independent-qdesn-full-redesign-v2-20260925"
iqfc_v1_package_version <- "1.1.1"
iqfc_v1_tarball_sha256 <-
  "3f3ed643ded7602fd62357d7f62024ca9071e0096214456650ed2de79722443e"
iqfc_v1_expected_jobs <- 54L
iqfc_v1_expected_cells <- 18L
iqfc_v1_expected_chains <- 3L
iqfc_v1_expected_origins <- 971L
iqfc_v1_expected_forecast_rows <- 29130L
iqfc_v1_metric_draws <- 300L

iqfc_v1_qdesn_run_relpath <- file.path(
  "validation", "fitforecast_v2", "local_trackers",
  "independent_qdesn_full_redesign_v2_1_20260925_162713__git-384496d94"
)

iqfc_v1_dqlm_source_plan_default <- paste0(
  "/data/jaguir26/local/src/",
  "exdqlm__wt__independent_qdesn_exdqlm_1p1p1_rerun_20260827/",
  "reports/shared_fitforecast_v2_orchestration/",
  "independent_qdesn_exdqlm_1p1p1_rerun_v1_20260828_000419/",
  "manifests/job_plan.csv"
)

iqfc_v1_exdqlm_source_manifest_relpath <- file.path(
  "validation", "fitforecast_v2", "promotions",
  "independent_exdqlm_mcmc_rolling_state_fix_v1_20260829",
  "manifests", "job_manifest.csv"
)

iqfc_v1_tarball_source_default <- paste0(
  "/data/jaguir26/local/src/",
  "exdqlm__wt__independent_exdqlm_mcmc_rolling_state_fix_v1_1p0p0/",
  "validation/fitforecast_v2/local_trackers/",
  "independent_exdqlm_mcmc_rolling_state_fix_v1/package/",
  "exdqlm_1.1.1.tar.gz"
)

iqfc_v1_sha256 <- function(path) {
  if (!file.exists(path)) return(NA_character_)
  unname(tools::sha256sum(path))
}

iqfc_v1_git <- function(repo_root, ...) {
  out <- system2("git", c("-C", repo_root, ...), stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) stop(paste(out, collapse = "\n"), call. = FALSE)
  out
}

iqfc_v1_assert_branch <- function(repo_root, require_clean = FALSE,
                                  require_synced = FALSE) {
  branch <- iqfc_v1_git(repo_root, "branch", "--show-current")[[1L]]
  if (!identical(branch, iqfc_v1_expected_branch)) {
    stop(sprintf("Refusing unexpected branch: %s", branch), call. = FALSE)
  }
  if (isTRUE(require_clean) && length(iqfc_v1_git(repo_root, "status", "--porcelain"))) {
    stop("The dedicated comparator worktree must be clean.", call. = FALSE)
  }
  upstream <- iqfc_v1_git(repo_root, "rev-parse", "--abbrev-ref", "@{upstream}")[[1L]]
  divergence <- scan(text = iqfc_v1_git(
    repo_root, "rev-list", "--left-right", "--count", "@{upstream}...HEAD"
  )[[1L]], quiet = TRUE)
  if (isTRUE(require_synced) && (length(divergence) != 2L || any(divergence != 0L))) {
    stop(sprintf("Comparator branch is not synchronized: %s",
                 paste(divergence, collapse = "/")), call. = FALSE)
  }
  list(
    branch = branch,
    upstream = upstream,
    head = iqfc_v1_git(repo_root, "rev-parse", "HEAD")[[1L]],
    behind = as.integer(divergence[[1L]]),
    ahead = as.integer(divergence[[2L]])
  )
}

iqfc_v1_read_csv <- function(path) {
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}

iqfc_v1_write_csv <- function(x, path) {
  ffv2_write_csv(x, path)
}

iqfc_v1_write_csv_gz <- function(x, path) {
  ffv2_write_csv_gz(x, path)
}

iqfc_v1_package_preflight <- function(tarball_path) {
  desc <- utils::packageDescription("exdqlm")
  mcmc_default <- eval(formals(exdqlm::exdqlmMCMC)$mh.proposal)[[1L]]
  checks <- c(
    version = identical(as.character(desc$Version), iqfc_v1_package_version),
    repository = identical(as.character(desc$Repository), "CRAN"),
    tarball_exists = file.exists(tarball_path),
    tarball_sha256 = identical(iqfc_v1_sha256(tarball_path),
                               iqfc_v1_tarball_sha256),
    collapsed_slice_default = identical(mcmc_default, "collapsed_slice")
  )
  if (!all(checks)) {
    stop(sprintf("Comparator package preflight failed: %s",
                 paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
  }
  list(
    checks = as.list(checks),
    version = as.character(desc$Version),
    repository = as.character(desc$Repository),
    tarball_path = normalizePath(tarball_path, winslash = "/", mustWork = TRUE),
    tarball_sha256 = iqfc_v1_sha256(tarball_path),
    library_path = normalizePath(find.package("exdqlm"), winslash = "/",
                                 mustWork = TRUE),
    mcmc_default = mcmc_default
  )
}

iqfc_v1_source_registry <- function(repo_root) {
  dqlm_plan <- Sys.getenv("IQFC_V1_DQLM_SOURCE_PLAN",
                          iqfc_v1_dqlm_source_plan_default)
  exdqlm_manifest <- file.path(repo_root, iqfc_v1_exdqlm_source_manifest_relpath)
  if (!file.exists(dqlm_plan) || !file.exists(exdqlm_manifest)) {
    stop("A frozen comparator source manifest is missing.", call. = FALSE)
  }
  d <- iqfc_v1_read_csv(dqlm_plan)
  d <- d[d$model_variant == "dqlm" & d$inference == "mcmc", , drop = FALSE]
  d <- data.frame(
    source_authority = "independent_exdqlm_1p1p1_rerun_v1_dqlm",
    source_job_id = d$job_id,
    model_variant = d$model_variant,
    family = d$family,
    tau = as.numeric(d$tau),
    chain_id = as.integer(d$chain_id),
    source_config_path = d$config_path,
    source_config_sha256 = d$config_sha256,
    stringsAsFactors = FALSE
  )
  e <- iqfc_v1_read_csv(exdqlm_manifest)
  e <- e[e$model_variant == "exdqlm" & e$inference == "mcmc", , drop = FALSE]
  e <- data.frame(
    source_authority = "independent_exdqlm_mcmc_rolling_state_fix_v1_20260829",
    source_job_id = e$source_job_id,
    model_variant = e$model_variant,
    family = e$family,
    tau = as.numeric(e$tau),
    chain_id = as.integer(e$chain_id),
    source_config_path = e$row_config_path,
    source_config_sha256 = e$row_config_sha256,
    stringsAsFactors = FALSE
  )
  out <- rbind(d, e)
  out <- out[order(out$model_variant, out$family, out$tau, out$chain_id), ]
  expected <- expand.grid(
    model_variant = c("dqlm", "exdqlm"),
    family = c("normal", "laplace", "gausmix"),
    tau = c(0.05, 0.25, 0.50), chain_id = 1:3,
    stringsAsFactors = FALSE
  )
  observed_key <- with(out, paste(model_variant, family, sprintf("%.2f", tau),
                                  chain_id, sep = "|"))
  expected_key <- with(expected, paste(model_variant, family, sprintf("%.2f", tau),
                                       chain_id, sep = "|"))
  if (nrow(out) != iqfc_v1_expected_jobs || anyDuplicated(observed_key) ||
      !setequal(observed_key, expected_key)) {
    stop("The frozen comparator source registry is not the exact 54-job surface.",
         call. = FALSE)
  }
  valid <- file.exists(out$source_config_path) & vapply(seq_len(nrow(out)), function(i) {
    identical(iqfc_v1_sha256(out$source_config_path[[i]]),
              out$source_config_sha256[[i]])
  }, logical(1L))
  if (!all(valid)) {
    stop(sprintf("Frozen source config verification failed for: %s",
                 paste(out$source_job_id[!valid], collapse = ", ")), call. = FALSE)
  }
  out
}

iqfc_v1_source_equality <- function(repo_root, registry) {
  qdesn_root <- file.path(repo_root, iqfc_v1_qdesn_run_relpath)
  qdesn_manifest_path <- file.path(qdesn_root, "source_manifest.csv")
  if (!file.exists(qdesn_manifest_path)) {
    stop("The completed Q-DESN source manifest is unavailable.", call. = FALSE)
  }
  qdesn_manifest <- iqfc_v1_read_csv(qdesn_manifest_path)
  cells <- unique(registry[c("family", "tau")])
  rows <- lapply(seq_len(nrow(cells)), function(i) {
    family <- cells$family[[i]]
    tau <- cells$tau[[i]]
    q <- qdesn_manifest[qdesn_manifest$family == family &
                          abs(qdesn_manifest$tau - tau) < 1e-12, , drop = FALSE]
    source_configs <- registry[registry$family == family &
                                 abs(registry$tau - tau) < 1e-12, ]
    configs <- lapply(source_configs$source_config_path, ffv2_read_json)
    series_paths <- unique(vapply(configs, function(x) x$series_wide_path,
                                  character(1L)))
    truth_paths <- unique(vapply(configs, function(x) x$true_quantile_grid_path,
                                 character(1L)))
    if (nrow(q) != 1L || length(series_paths) != 1L || length(truth_paths) != 1L) {
      stop(sprintf("Ambiguous source identity for %s tau %.2f.", family, tau),
           call. = FALSE)
    }
    frozen <- iqfc_v1_read_csv(q$frozen_path[[1L]])
    source <- iqfc_v1_read_csv(series_paths[[1L]])
    matched <- source[match(frozen$t, source$t), , drop = FALSE]
    exact <- nrow(matched) == nrow(frozen) && !anyNA(matched$t) &&
      isTRUE(all.equal(as.numeric(matched$y), as.numeric(frozen$y),
                       tolerance = 0, check.attributes = FALSE)) &&
      isTRUE(all.equal(as.numeric(matched$mu), as.numeric(frozen$mu),
                       tolerance = 0, check.attributes = FALSE))
    if (!exact) stop(sprintf("DGP mismatch for %s tau %.2f.", family, tau),
                     call. = FALSE)
    data.frame(
      family = family, tau = tau, frozen_rows = nrow(frozen),
      first_t = min(frozen$t), last_t = max(frozen$t), exact_equal = exact,
      frozen_source_path = normalizePath(q$frozen_path[[1L]], winslash = "/",
                                         mustWork = TRUE),
      frozen_source_sha256 = iqfc_v1_sha256(q$frozen_path[[1L]]),
      full_series_path = normalizePath(series_paths[[1L]], winslash = "/",
                                       mustWork = TRUE),
      full_series_sha256 = iqfc_v1_sha256(series_paths[[1L]]),
      truth_grid_path = normalizePath(truth_paths[[1L]], winslash = "/",
                                      mustWork = TRUE),
      truth_grid_sha256 = iqfc_v1_sha256(truth_paths[[1L]]),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out[order(out$family, out$tau), ]
}

iqfc_v1_qdesn_authority <- function(repo_root) {
  root <- file.path(repo_root, iqfc_v1_qdesn_run_relpath)
  closeout_path <- file.path(root, "manifests", "closeout.json")
  artifact_path <- file.path(root, "manifests", "artifact_manifest.csv")
  if (!file.exists(closeout_path) || !file.exists(artifact_path)) {
    stop("The completed Q-DESN closeout authority is missing.", call. = FALSE)
  }
  closeout <- ffv2_read_json(closeout_path)
  required <- c(
    closeout$outputs$chain_results,
    closeout$outputs$selected_winner_metrics,
    closeout$outputs$forecast_estimator_decision
  )
  manifest <- iqfc_v1_read_csv(artifact_path)
  match_index <- match(normalizePath(required, winslash = "/", mustWork = TRUE),
                       normalizePath(manifest$path, winslash = "/", mustWork = FALSE))
  checks <- c(
    status = identical(
      as.character(closeout$status),
      "READY_FOR_SCIENTIFIC_REVIEW_NO_AUTOMATIC_ARTICLE_PROMOTION"
    ),
    cells = identical(as.integer(closeout$selected_cells), 18L),
    origins = identical(as.integer(closeout$final_origins),
                        iqfc_v1_expected_origins),
    pairs = identical(as.integer(closeout$final_pairs_per_row),
                      iqfc_v1_expected_forecast_rows),
    no_binaries = identical(as.integer(closeout$fitted_model_binaries), 0L),
    required_listed = !anyNA(match_index),
    required_hashes = !anyNA(match_index) && all(vapply(seq_along(required), function(i) {
      identical(iqfc_v1_sha256(required[[i]]), manifest$sha256[[match_index[[i]]]])
    }, logical(1L)))
  )
  if (!all(checks)) {
    stop(sprintf("Q-DESN authority verification failed: %s",
                 paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
  }
  list(
    root = normalizePath(root, winslash = "/", mustWork = TRUE),
    checks = as.list(checks), closeout_path = closeout_path,
    closeout_sha256 = iqfc_v1_sha256(closeout_path),
    artifact_manifest_path = artifact_path,
    artifact_manifest_sha256 = iqfc_v1_sha256(artifact_path),
    required_paths = required,
    required_sha256 = vapply(required, iqfc_v1_sha256, character(1L))
  )
}

iqfc_v1_remap_path <- function(path, source_root, target_root) {
  path <- as.character(path %||% "")[[1L]]
  if (!nzchar(path) || !startsWith(path, paste0(source_root, "/"))) return(path)
  file.path(target_root, substring(path, nchar(source_root) + 2L))
}

iqfc_v1_remap_config <- function(source, repo_root, run_root, registry_row,
                                 frozen_source_config_path) {
  source_root <- as.character(source$run_root)[[1L]]
  tau_label <- ffv2_tau_label(source$tau)
  job_id <- sprintf("%s__%s__%s__c%02d", source$model_variant,
                    source$family, tau_label, as.integer(source$chain_id))
  target_root <- file.path(run_root, "jobs", job_id)
  config <- source
  input_fields <- c("series_wide_path", "true_quantile_grid_path",
                    "sim_output_path", "meta_path")
  path_fields <- names(config)[grepl("_path$", names(config))]
  for (field in setdiff(path_fields, input_fields)) {
    config[[field]] <- iqfc_v1_remap_path(config[[field]], source_root, target_root)
  }
  config$run_tag <- paste0(basename(run_root), "__", job_id)
  config$run_root <- target_root
  config$repo_root <- repo_root
  config$harness_root <- file.path(repo_root, "validation", "fitforecast_v2")
  config$defaults_path <- file.path(
    repo_root, "validation", "fitforecast_v2", "config",
    "exdqlm_dynamic_fitforecast_v2_defaults.yaml"
  )
  config$status <- "pending"
  config$validation_stage <- "all"
  config$phase <- "mcmc_tt500"
  config$origin_stride <- 1L
  config$require_full_horizon <- TRUE
  config$max_lead_configured <- 30L
  config$forecast_horizon_max <- 30L
  config$forecast_window_rows <-
    as.integer(config$forecast_end_source_index) -
    as.integer(config$forecast_start_source_index) + 1L
  config$forecast_protocol <- "rolling_origin_no_refit_state_update"
  config$state_update_method <-
    ffv2_exdqlm_mcmc_predictive_state_update_method()
  config$refit_per_origin <- FALSE
  config$package_runtime_mode <- "installed_namespace"
  config$screen_stage <- "fixed_comparator_stride1_replay_v1"
  config$candidate_notes <- paste(
    "Frozen authoritative comparator specification and MCMC seed replayed on",
    "the 971-origin stride-one lattice with 300 posterior metric draws."
  )
  config$source_config_path <- normalizePath(
    frozen_source_config_path, winslash = "/", mustWork = TRUE
  )
  config$source_config_sha256 <- iqfc_v1_sha256(frozen_source_config_path)
  config$source_authority <- registry_row$source_authority[[1L]]
  config$source_job_id <- registry_row$source_job_id[[1L]]
  config$package_contract <- list(
    version = iqfc_v1_package_version,
    authority = "CRAN",
    url = "https://CRAN.R-project.org/package=exdqlm",
    source_tarball_sha256 = iqfc_v1_tarball_sha256,
    gamma_update = if (identical(source$model_variant, "exdqlm")) {
      "collapsed_slice"
    } else "gamma_fixed_al"
  )
  config$budget$stored_draws <- iqfc_v1_metric_draws
  config$budget$forecast_draws <- iqfc_v1_metric_draws
  config$metric_intervals <- utils::modifyList(
    config$metric_intervals %||% list(),
    list(enabled = TRUE, required = TRUE, draws = iqfc_v1_metric_draws,
         fit_rows = 500L, forecast_rows = iqfc_v1_expected_forecast_rows,
         chain_id = as.integer(source$chain_id))
  )
  config$runtime <- utils::modifyList(
    config$runtime %||% list(), list(threads = 1L)
  )
  config$handoff <- utils::modifyList(
    config$handoff %||% list(), list(prune_fit_on_success = TRUE)
  )
  config$retention <- utils::modifyList(
    config$retention %||% list(),
    list(mode = "compact_success_only", allow_success_binary_payloads = FALSE)
  )
  config
}

iqfc_v1_config_audit <- function(source, target) {
  fields <- union(names(source), names(target))
  changed <- fields[vapply(fields, function(field) {
    !identical(source[[field]], target[[field]])
  }, logical(1L))]
  input_fields <- c("series_wide_path", "true_quantile_grid_path",
                    "sim_output_path", "meta_path")
  generated_paths <- setdiff(fields[grepl("_path$", fields)], input_fields)
  allowed <- unique(c(
    generated_paths, "run_tag", "run_root", "repo_root", "harness_root",
    "defaults_path", "status", "origin_stride", "require_full_horizon",
    "forecast_horizon_max", "forecast_window_rows", "state_update_method",
    "package_runtime_mode", "package_contract", "screen_stage",
    "candidate_notes", "source_config_sha256", "source_authority",
    "source_job_id", "budget", "metric_intervals", "runtime", "handoff",
    "retention"
  ))
  unexpected <- setdiff(changed, allowed)
  input_equal <- vapply(input_fields, function(field) {
    identical(source[[field]], target[[field]])
  }, logical(1L))
  invariant <- c(
    model_variant = identical(source$model_variant, target$model_variant),
    family = identical(source$family, target$family),
    tau = identical(source$tau, target$tau),
    chain_id = identical(source$chain_id, target$chain_id),
    seed = identical(source$seed, target$seed),
    models = identical(source$models, target$models),
    mcmc_budget = identical(source$budget$mcmc, target$budget$mcmc),
    input_paths = all(input_equal)
  )
  list(changed = sort(changed), unexpected = unexpected,
       invariant = invariant, pass = !length(unexpected) && all(invariant))
}

iqfc_v1_materialize <- function(repo_root, run_root, tarball_path) {
  git <- iqfc_v1_assert_branch(repo_root)
  package <- iqfc_v1_package_preflight(tarball_path)
  qdesn_authority <- iqfc_v1_qdesn_authority(repo_root)
  grid <- ffv2_rolling_grid(
    9000L, 9001L, 10000L, 30L, 1L,
    "rolling_origin_no_refit_state_update", require_full_horizon = TRUE
  )
  grid_checks <- c(
    origins = length(unique(grid$forecast_origin_source_index)) ==
      iqfc_v1_expected_origins,
    forecast_rows = nrow(grid) == iqfc_v1_expected_forecast_rows,
    max_lead = max(grid$forecast_lead) == 30L
  )
  if (!all(grid_checks)) stop("Stride-one rolling grid preflight failed.", call. = FALSE)
  manifest_path <- file.path(run_root, "manifests", "job_manifest.csv")
  if (file.exists(manifest_path)) stop("Refusing an existing materialization.",
                                       call. = FALSE)
  ffv2_ensure_dir(file.path(run_root, "manifests", "source_configs"))
  registry <- iqfc_v1_source_registry(repo_root)
  equality <- iqfc_v1_source_equality(repo_root, registry)
  registry_path <- iqfc_v1_write_csv(
    registry, file.path(run_root, "manifests", "source_registry.csv")
  )
  equality_path <- iqfc_v1_write_csv(
    equality, file.path(run_root, "manifests", "source_equality_ledger.csv")
  )
  manifest_rows <- vector("list", nrow(registry))
  audit_rows <- vector("list", nrow(registry))
  for (i in seq_len(nrow(registry))) {
    source_path <- registry$source_config_path[[i]]
    source <- ffv2_read_json(source_path)
    frozen_name <- sprintf(
      "%s__%s__%s__c%02d.json", source$model_variant, source$family,
      ffv2_tau_label(source$tau), as.integer(source$chain_id)
    )
    frozen_path <- file.path(run_root, "manifests", "source_configs", frozen_name)
    if (!file.copy(source_path, frozen_path, overwrite = FALSE, copy.mode = TRUE)) {
      stop(sprintf("Could not freeze source config: %s", source_path), call. = FALSE)
    }
    if (!identical(iqfc_v1_sha256(frozen_path),
                   registry$source_config_sha256[[i]])) {
      stop("Frozen source config hash changed during copy.", call. = FALSE)
    }
    target <- iqfc_v1_remap_config(
      source, repo_root, run_root, registry[i, , drop = FALSE], frozen_path
    )
    audit <- iqfc_v1_config_audit(source, target)
    if (!isTRUE(audit$pass)) {
      stop(sprintf("Config contract failed for %s: %s",
                   registry$source_job_id[[i]],
                   paste(c(audit$unexpected, names(audit$invariant)[!audit$invariant]),
                         collapse = ", ")), call. = FALSE)
    }
    ffv2_ensure_dir(dirname(target$row_config_path))
    ffv2_write_json(target, target$row_config_path)
    job_id <- sprintf("%s__%s__%s__c%02d", target$model_variant,
                      target$family, ffv2_tau_label(target$tau),
                      as.integer(target$chain_id))
    manifest_rows[[i]] <- data.frame(
      job_id = job_id, row_id = as.integer(target$row_id),
      row_key = as.character(target$row_key), spec_id = as.character(target$spec_id),
      family = as.character(target$family), tau = as.numeric(target$tau),
      fit_size = as.integer(target$fit_size),
      model_variant = as.character(target$model_variant), inference = "mcmc",
      phase = "mcmc_tt500", chain_id = as.integer(target$chain_id),
      source_authority = registry$source_authority[[i]],
      source_job_id = registry$source_job_id[[i]],
      source_config_path = normalizePath(frozen_path, winslash = "/", mustWork = TRUE),
      source_config_sha256 = iqfc_v1_sha256(frozen_path),
      row_config_path = normalizePath(target$row_config_path, winslash = "/",
                                      mustWork = TRUE),
      row_config_sha256 = iqfc_v1_sha256(target$row_config_path),
      row_status_path = target$row_status_path,
      status = "pending", stringsAsFactors = FALSE
    )
    audit_rows[[i]] <- data.frame(
      job_id = job_id,
      changed_top_level_fields = paste(audit$changed, collapse = ";"),
      unexpected_top_level_fields = paste(audit$unexpected, collapse = ";"),
      scientific_identity_preserved = all(audit$invariant),
      config_contract_pass = audit$pass, stringsAsFactors = FALSE
    )
  }
  manifest <- do.call(rbind, manifest_rows)
  audit <- do.call(rbind, audit_rows)
  manifest_path <- iqfc_v1_write_csv(manifest, manifest_path)
  audit_path <- iqfc_v1_write_csv(
    audit, file.path(run_root, "manifests", "config_change_audit.csv")
  )
  session_path <- file.path(run_root, "manifests", "session_info.txt")
  capture.output(sessionInfo(), file = session_path)
  preflight <- list(
    schema_version = iqfc_v1_schema,
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    git = git, package = package, qdesn_authority = qdesn_authority,
    grid_checks = as.list(grid_checks),
    jobs = nrow(manifest), cells = iqfc_v1_expected_cells,
    chains_per_cell = iqfc_v1_expected_chains,
    origins = iqfc_v1_expected_origins,
    horizon = 30L, forecast_rows = iqfc_v1_expected_forecast_rows,
    metric_draws_per_chain = iqfc_v1_metric_draws,
    source_registry_path = registry_path,
    source_registry_sha256 = iqfc_v1_sha256(registry_path),
    source_equality_path = equality_path,
    source_equality_sha256 = iqfc_v1_sha256(equality_path),
    config_audit_path = audit_path,
    config_audit_sha256 = iqfc_v1_sha256(audit_path),
    manifest_path = manifest_path, manifest_sha256 = iqfc_v1_sha256(manifest_path),
    session_info_path = normalizePath(session_path, winslash = "/", mustWork = TRUE),
    session_info_sha256 = iqfc_v1_sha256(session_path),
    article_write_performed = FALSE, shared_validation_write_performed = FALSE,
    overleaf_write_performed = FALSE
  )
  preflight_path <- ffv2_write_json(
    preflight, file.path(run_root, "manifests", "preflight_report.json")
  )
  list(manifest = manifest, preflight = preflight,
       preflight_path = preflight_path)
}

iqfc_v1_last_status <- function(path) {
  if (!file.exists(path)) return("pending")
  x <- tryCatch(iqfc_v1_read_csv(path), error = function(e) NULL)
  if (is.null(x) || !nrow(x) || !"status" %in% names(x)) return("unknown")
  as.character(tail(x$status, 1L))
}

iqfc_v1_health <- function(run_root) {
  manifest_path <- file.path(run_root, "manifests", "job_manifest.csv")
  manifest <- iqfc_v1_read_csv(manifest_path)
  manifest$current_status <- vapply(manifest$row_status_path,
                                    iqfc_v1_last_status, character(1L))
  summary <- stats::aggregate(
    rep(1L, nrow(manifest)),
    by = manifest[c("model_variant", "current_status")], FUN = sum
  )
  names(summary)[[3L]] <- "jobs"
  failed <- grepl("^failed", manifest$current_status)
  running <- manifest$current_status == "running"
  done <- manifest$current_status == "done"
  list(
    jobs = manifest,
    summary = summary,
    total = nrow(manifest),
    done = sum(done),
    failed = sum(failed),
    running = sum(running),
    remaining = sum(!(done | failed | running))
  )
}

iqfc_v1_num <- function(x) {
  value <- suppressWarnings(as.numeric(x %||% NA_real_)[1L])
  if (is.finite(value)) value else NA_real_
}

iqfc_v1_profile <- function(x, groups, metrics) {
  if (requireNamespace("data.table", quietly = TRUE)) {
    dt <- data.table::as.data.table(x)
    out <- dt[, c(
      lapply(.SD, function(value) mean(as.numeric(value), na.rm = TRUE)),
      list(n_chains = data.table::uniqueN(chain_id))
    ), by = groups, .SDcols = metrics]
    return(as.data.frame(out, stringsAsFactors = FALSE))
  }
  key <- do.call(paste, c(x[groups], sep = "\r"))
  pieces <- lapply(split(seq_len(nrow(x)), key), function(index) {
    z <- x[index, , drop = FALSE]
    out <- z[1L, groups, drop = FALSE]
    for (metric in metrics) out[[metric]] <- mean(as.numeric(z[[metric]]), na.rm = TRUE)
    out$n_chains <- length(unique(z$chain_id))
    out
  })
  ffv2_bind_rows(pieces)
}

iqfc_v1_long_qdesn_intervals <- function(winners) {
  metrics <- c("fit_qtrue_rmse", "fit_qtrue_mae", "fit_check_loss",
               "forecast_qtrue_mae", "forecast_qtrue_rmse",
               "forecast_check_loss")
  ffv2_bind_rows(lapply(metrics, function(metric) {
    data.frame(
      model_variant = ifelse(winners$likelihood_family == "al",
                             "qdesn_al_rhs", "qdesn_exal_rhs"),
      family = winners$family, tau = winners$tau,
      likelihood_family = winners$likelihood_family, metric = metric,
      posterior_mean = winners[[paste0(metric, "_mean")]],
      cri_lower = winners[[paste0(metric, "_lower")]],
      cri_upper = winners[[paste0(metric, "_upper")]],
      n_draws = winners$pooled_draws, n_chains = winners$chains,
      estimator = winners$estimator, candidate_id = winners$candidate_id,
      stringsAsFactors = FALSE
    )
  }))
}

iqfc_v1_qdesn_forecast_rows <- function(repo_root) {
  iqfc_v1_qdesn_authority(repo_root)
  qdesn_root <- file.path(repo_root, iqfc_v1_qdesn_run_relpath)
  winners <- iqfc_v1_read_csv(file.path(
    qdesn_root, "summaries", "mcmc_selected_winner_metrics.csv"
  ))
  chains <- iqfc_v1_read_csv(file.path(
    qdesn_root, "summaries", "mcmc_confirmation_chain_results.csv"
  ))
  winner_key <- with(winners, paste(family, sprintf("%.2f", tau),
                                    likelihood_family, candidate_id, sep = "|"))
  chain_key <- with(chains, paste(family, sprintf("%.2f", tau),
                                 likelihood_family, candidate_id, sep = "|"))
  chains <- chains[chain_key %in% winner_key &
                     chains$estimator == "mean_readout_state_recursive", , drop = FALSE]
  chains <- chains[!duplicated(chains[c("job_id", "chain_id")]), , drop = FALSE]
  path_hashes <- vapply(seq_len(nrow(chains)), function(i) {
    file.exists(chains$origin_lead_path[[i]]) &&
      identical(iqfc_v1_sha256(chains$origin_lead_path[[i]]),
                chains$origin_lead_sha256[[i]])
  }, logical(1L))
  if (nrow(chains) != 54L || !all(path_hashes)) {
    stop("The selected Q-DESN granular forecast surface is incomplete.", call. = FALSE)
  }
  rows <- lapply(seq_len(nrow(chains)), function(i) {
    x <- iqfc_v1_read_csv(chains$origin_lead_path[[i]])
    x <- x[x$estimator == "mean_readout_state_recursive", , drop = FALSE]
    if (nrow(x) != iqfc_v1_expected_forecast_rows) {
      stop(sprintf("Unexpected Q-DESN forecast shape: %s", chains$job_id[[i]]),
           call. = FALSE)
    }
    qhat <- as.numeric(x$posterior_mean_quantile)
    qtrue <- as.numeric(x$qtrue)
    observed <- as.numeric(x$observed)
    data.frame(
      model_variant = if (chains$likelihood_family[[i]] == "al") {
        "qdesn_al_rhs"
      } else "qdesn_exal_rhs",
      family = chains$family[[i]], tau = as.numeric(chains$tau[[i]]),
      likelihood_family = chains$likelihood_family[[i]],
      chain_id = as.integer(chains$chain_id[[i]]),
      forecast_origin_source_index = as.integer(x$source_origin),
      forecast_lead = as.integer(x$lead),
      target_source_index = as.integer(x$source_target),
      q_true = qtrue, y = observed, qhat = qhat,
      abs_q_error = abs(qhat - qtrue),
      squared_q_error = (qhat - qtrue)^2,
      pinball_tau = ffv2_check_loss(observed, qhat, as.numeric(chains$tau[[i]])),
      stringsAsFactors = FALSE
    )
  })
  ffv2_bind_rows(rows)
}

iqfc_v1_closeout <- function(repo_root, run_root) {
  health <- iqfc_v1_health(run_root)
  if (health$done != iqfc_v1_expected_jobs || health$failed != 0L) {
    stop(sprintf("Closeout requires 54 successful jobs; done=%d failed=%d.",
                 health$done, health$failed), call. = FALSE)
  }
  manifest <- health$jobs
  chain_rows <- vector("list", nrow(manifest))
  draw_rows <- vector("list", nrow(manifest))
  forecast_rows <- vector("list", nrow(manifest))
  diagnostic_rows <- vector("list", nrow(manifest))
  for (i in seq_len(nrow(manifest))) {
    config <- ffv2_read_json(manifest$row_config_path[[i]])
    if (!identical(iqfc_v1_sha256(manifest$row_config_path[[i]]),
                   manifest$row_config_sha256[[i]])) {
      stop(sprintf("Config changed after materialization: %s", manifest$job_id[[i]]),
           call. = FALSE)
    }
    metrics <- iqfc_v1_read_csv(config$row_metrics_path)
    fit <- iqfc_v1_read_csv(config$fit_path_summary_path)
    forecast <- iqfc_v1_read_csv(config$forecast_path_summary_path)
    draws <- iqfc_v1_read_csv(config$metric_draws_path)
    interval_manifest <- ffv2_read_json(config$metric_interval_manifest_path)
    health_row <- iqfc_v1_read_csv(config$row_health_path)
    diagnostics <- ffv2_read_json(config$inference_diagnostics_path)
    checks <- c(
      fit_rows = nrow(fit) == 500L,
      forecast_rows = nrow(forecast) == iqfc_v1_expected_forecast_rows,
      origins = length(unique(forecast$forecast_origin_source_index)) ==
        iqfc_v1_expected_origins,
      leads = max(forecast$forecast_lead) == 30L,
      metric_draws = nrow(draws) == iqfc_v1_metric_draws,
      interval_rows = as.integer(interval_manifest$forecast_rows) ==
        iqfc_v1_expected_forecast_rows,
      package = identical(as.character(config$package_contract$version),
                          iqfc_v1_package_version),
      runtime = identical(as.character(config$package_runtime_mode),
                          "installed_namespace")
    )
    if (!all(checks)) {
      stop(sprintf("Artifact contract failed for %s: %s", manifest$job_id[[i]],
                   paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
    }
    status <- iqfc_v1_read_csv(config$row_status_path)
    chain_rows[[i]] <- data.frame(
      job_id = manifest$job_id[[i]], model_variant = config$model_variant,
      family = config$family, tau = as.numeric(config$tau),
      likelihood_family = if (config$model_variant == "dqlm") "al" else "exal",
      chain_id = as.integer(config$chain_id), seed = as.integer(config$seed),
      status = tail(status$status, 1L), health_gate = health_row$gate[[1L]],
      fit_qtrue_rmse = metrics$fit_q_rmse[[1L]],
      fit_qtrue_mae = metrics$fit_q_mae[[1L]],
      fit_check_loss = metrics$fit_pinball_mean[[1L]],
      forecast_qtrue_mae = metrics$forecast_h1000_q_mae[[1L]],
      forecast_qtrue_rmse = metrics$forecast_h1000_q_rmse[[1L]],
      forecast_check_loss = metrics$forecast_h1000_pinball_mean[[1L]],
      forecast_origins = length(unique(forecast$forecast_origin_source_index)),
      forecast_pairs = nrow(forecast), metric_draws = nrow(draws),
      runtime_seconds = tail(status$runtime_sec, 1L),
      config_path = manifest$row_config_path[[i]],
      config_sha256 = manifest$row_config_sha256[[i]],
      stringsAsFactors = FALSE
    )
    draws$model_variant <- config$model_variant
    draws$family <- config$family
    draws$tau <- as.numeric(config$tau)
    draws$likelihood_family <- if (config$model_variant == "dqlm") "al" else "exal"
    draws$chain_id <- as.integer(config$chain_id)
    draw_rows[[i]] <- draws
    forecast$model_variant <- config$model_variant
    forecast$family <- config$family
    forecast$tau <- as.numeric(config$tau)
    forecast$likelihood_family <- if (config$model_variant == "dqlm") "al" else "exal"
    forecast$chain_id <- as.integer(config$chain_id)
    forecast_rows[[i]] <- forecast[c(
      "model_variant", "family", "tau", "likelihood_family", "chain_id",
      "forecast_origin_source_index", "forecast_lead", "target_source_index",
      "q_true", "y", "qhat", "abs_q_error", "squared_q_error", "pinball_tau"
    )]
    diagnostic_rows[[i]] <- data.frame(
      model_variant = config$model_variant, family = config$family,
      tau = as.numeric(config$tau), chain_id = as.integer(config$chain_id),
      requested_mh_proposal = as.character(
        diagnostics$requested_mh_proposal %||% NA_character_
      ),
      observed_mh_proposal = as.character(
        diagnostics$observed_mh_proposal %||% NA_character_
      ),
      gamma_ess = iqfc_v1_num((diagnostics$gamma %||% list())$ess),
      gamma_acf1 = iqfc_v1_num((diagnostics$gamma %||% list())$acf1),
      sigma_ess = iqfc_v1_num((diagnostics$sigma %||% list())$ess),
      sigma_acf1 = iqfc_v1_num((diagnostics$sigma %||% list())$acf1),
      stringsAsFactors = FALSE
    )
  }
  chain <- ffv2_bind_rows(chain_rows)
  draws <- ffv2_bind_rows(draw_rows)
  forecasts <- ffv2_bind_rows(forecast_rows)
  diagnostics <- ffv2_bind_rows(diagnostic_rows)
  cell_key <- with(draws, paste(model_variant, family, sprintf("%.2f", tau), sep = "|"))
  intervals <- ffv2_bind_rows(lapply(split(seq_len(nrow(draws)), cell_key), function(index) {
    z <- draws[index, , drop = FALSE]
    out <- ffv2_metric_interval_summary(z, inference = "mcmc")
    out$model_variant <- z$model_variant[[1L]]
    out$family <- z$family[[1L]]
    out$tau <- z$tau[[1L]]
    out$likelihood_family <- z$likelihood_family[[1L]]
    out
  }))
  metric_names <- c(
    fit_rmse = "fit_qtrue_rmse", fit_mae = "fit_qtrue_mae",
    fit_check_loss = "fit_check_loss",
    forecast_mae = "forecast_qtrue_mae",
    forecast_rmse = "forecast_qtrue_rmse",
    forecast_check_loss = "forecast_check_loss"
  )
  intervals$metric <- unname(metric_names[intervals$metric])
  metric_diagnostics <- ffv2_bind_rows(lapply(
    split(seq_len(nrow(draws)), cell_key), function(index) {
      z <- draws[index, , drop = FALSE]
      out <- ffv2_metric_chain_diagnostics(z)
      out$model_variant <- z$model_variant[[1L]]
      out$family <- z$family[[1L]]
      out$tau <- z$tau[[1L]]
      out$metric <- unname(metric_names[out$metric])
      out
    }
  ))
  qdesn_forecasts <- iqfc_v1_qdesn_forecast_rows(repo_root)
  profile_forecasts <- rbind(forecasts, qdesn_forecasts)
  leads <- iqfc_v1_profile(
    profile_forecasts, c("model_variant", "family", "tau", "likelihood_family",
                 "forecast_lead"), c("abs_q_error", "squared_q_error", "pinball_tau")
  )
  origins <- iqfc_v1_profile(
    profile_forecasts, c("model_variant", "family", "tau", "likelihood_family",
                 "forecast_origin_source_index"),
    c("abs_q_error", "squared_q_error", "pinball_tau")
  )
  origin_lead <- iqfc_v1_profile(
    profile_forecasts, c("model_variant", "family", "tau", "likelihood_family",
                 "forecast_origin_source_index", "forecast_lead"),
    c("abs_q_error", "squared_q_error", "pinball_tau")
  )
  qdesn_root <- file.path(repo_root, iqfc_v1_qdesn_run_relpath)
  qdesn_winners <- iqfc_v1_read_csv(file.path(
    qdesn_root, "summaries", "mcmc_selected_winner_metrics.csv"
  ))
  qdesn_intervals <- iqfc_v1_long_qdesn_intervals(qdesn_winners)
  comparator_intervals <- intervals[c(
    "model_variant", "family", "tau", "likelihood_family", "metric",
    "posterior_mean", "cri_lower", "cri_upper", "n_draws", "n_chains"
  )]
  comparator_intervals$estimator <- "state_space_recursive"
  comparator_intervals$candidate_id <- NA_character_
  unified_intervals <- rbind(comparator_intervals, qdesn_intervals)
  matched <- merge(
    comparator_intervals,
    qdesn_intervals,
    by = c("family", "tau", "likelihood_family", "metric"),
    suffixes = c("_comparator", "_qdesn"), all = FALSE
  )
  matched$qdesn_minus_comparator <-
    matched$posterior_mean_qdesn - matched$posterior_mean_comparator
  matched$qdesn_to_comparator_ratio <-
    matched$posterior_mean_qdesn / matched$posterior_mean_comparator
  matched$lower_posterior_mean <- ifelse(
    matched$qdesn_minus_comparator < 0,
    matched$model_variant_qdesn, matched$model_variant_comparator
  )
  output_root <- ffv2_ensure_dir(file.path(run_root, "closeout"))
  outputs <- c(
    chain_metrics = iqfc_v1_write_csv(
      chain, file.path(output_root, "chain_metrics.csv")
    ),
    pooled_metric_intervals = iqfc_v1_write_csv(
      intervals, file.path(output_root, "pooled_metric_intervals.csv")
    ),
    metric_diagnostics = iqfc_v1_write_csv(
      metric_diagnostics, file.path(output_root, "metric_chain_diagnostics.csv")
    ),
    inference_diagnostics = iqfc_v1_write_csv(
      diagnostics, file.path(output_root, "inference_diagnostics.csv")
    ),
    unified_four_model_intervals = iqfc_v1_write_csv(
      unified_intervals, file.path(output_root, "unified_four_model_intervals.csv")
    ),
    likelihood_matched_comparison = iqfc_v1_write_csv(
      matched, file.path(output_root, "likelihood_matched_comparison.csv")
    ),
    forecast_lead_profiles = iqfc_v1_write_csv(
      leads, file.path(output_root, "forecast_lead_profiles.csv")
    ),
    forecast_origin_profiles = iqfc_v1_write_csv(
      origins, file.path(output_root, "forecast_origin_profiles.csv")
    ),
    forecast_origin_lead_profiles = iqfc_v1_write_csv_gz(
      origin_lead, file.path(output_root, "forecast_origin_lead_profiles.csv.gz")
    )
  )
  heavy <- list.files(run_root, recursive = TRUE, full.names = TRUE,
                      pattern = "[.](rds|rda|RData)$", ignore.case = TRUE)
  decision <- list(
    schema_version = iqfc_v1_schema,
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    status = "READY_FOR_SCIENTIFIC_REVIEW_NO_AUTOMATIC_ARTICLE_PROMOTION",
    jobs = nrow(chain), successful_jobs = sum(chain$status == "done"),
    failed_jobs = sum(chain$status != "done"), cells = iqfc_v1_expected_cells,
    chains_per_cell = iqfc_v1_expected_chains,
    forecast_origins = iqfc_v1_expected_origins,
    forecast_pairs_per_chain = iqfc_v1_expected_forecast_rows,
    qdesn_estimator = "mean_readout_state_recursive",
    comparator_estimator = "state_space_recursive",
    package_version = iqfc_v1_package_version,
    article_write_performed = FALSE, shared_validation_write_performed = FALSE,
    overleaf_write_performed = FALSE, fitted_model_binaries = length(heavy),
    outputs = as.list(outputs),
    output_sha256 = as.list(setNames(vapply(outputs, iqfc_v1_sha256,
                                            character(1L)), names(outputs)))
  )
  decision_path <- ffv2_write_json(decision, file.path(output_root, "closeout.json"))
  artifact_manifest <- data.frame(
    role = c(names(outputs), "closeout"),
    path = c(unname(outputs), decision_path),
    sha256 = vapply(c(unname(outputs), decision_path), iqfc_v1_sha256,
                    character(1L)),
    bytes = as.numeric(file.info(c(unname(outputs), decision_path))$size),
    stringsAsFactors = FALSE
  )
  manifest_path <- iqfc_v1_write_csv(
    artifact_manifest, file.path(output_root, "artifact_manifest.csv")
  )
  list(decision = decision, decision_path = decision_path,
       artifact_manifest_path = manifest_path)
}

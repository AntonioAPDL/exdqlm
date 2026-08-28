imi_v1_schema <- "independent_metric_intervals_v1"
imi_v1_stage <- "qdesn_dqlm_500obs_independent_metric_intervals_v1"
imi_v1_branch <- "validation/independent-metric-intervals-v1-1.0.0"
imi_v1_workers <- 20L
imi_v1_mcmc_chains <- 3L
imi_v1_vb_draws <- 10000L
imi_v1_mcmc_metric_draws <- 4000L
imi_v1_authority_id <- "qdesn_dqlm_500obs_trainonly_article_v9_canonical_gap_20260821"

imi_v1_repo_root <- function() ffv2_repo_root()

imi_v1_relpath <- function(path, repo_root = imi_v1_repo_root()) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  root <- paste0(normalizePath(repo_root, winslash = "/", mustWork = TRUE), "/")
  ifelse(startsWith(path, root), substring(path, nchar(root) + 1L), path)
}

imi_v1_authority_dir <- function(repo_root = imi_v1_repo_root(),
                                 authority_id = imi_v1_authority_id) {
  file.path(repo_root, "validation", "fitforecast_v2", "promotions", authority_id)
}

imi_v1_authority_interface_path <- function(repo_root = imi_v1_repo_root(),
                                            authority_id = imi_v1_authority_id) {
  file.path(imi_v1_authority_dir(repo_root, authority_id), paste0(authority_id, "_interface.csv"))
}

imi_v1_authority_manifest_path <- function(repo_root = imi_v1_repo_root(),
                                           authority_id = imi_v1_authority_id) {
  file.path(imi_v1_authority_dir(repo_root, authority_id), paste0(authority_id, "_manifest.json"))
}

imi_v1_metric_roles <- c(
  fit = "fit_qtrue_rmse",
  forecast_mae = "forecast_qtrue_mae_H1000",
  forecast_check = "forecast_check_loss_H1000"
)

imi_v1_expand_metric_sources <- function(interface) {
  rows <- lapply(names(imi_v1_metric_roles), function(role) {
    prefix <- paste0(role, "_source_")
    data.frame(
      article_row = seq_len(nrow(interface)),
      inference = as.character(interface$inference),
      model_variant = as.character(interface$model_variant),
      model_label = as.character(interface$model_label),
      family = as.character(interface$family),
      tau = as.numeric(interface$tau),
      metric_role = role,
      metric_name = unname(imi_v1_metric_roles[[role]]),
      authoritative_value = as.numeric(interface[[unname(imi_v1_metric_roles[[role]])]]),
      source_candidate_id = as.character(interface[[paste0(prefix, "candidate_id")]]),
      source_run_tag = as.character(interface[[paste0(prefix, "run_tag")]]),
      source_status = as.character(interface[[paste0(prefix, "status")]]),
      source_signoff_grade = as.character(interface[[paste0(prefix, "signoff_grade")]]),
      source_path = as.character(interface[[paste0(prefix, "path")]]),
      source_sha256 = as.character(interface[[paste0(prefix, "sha256")]]),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out$source_identity <- do.call(paste, c(out[c(
    "inference", "model_variant", "family", "tau", "source_candidate_id",
    "source_run_tag"
  )], sep = "|"))
  out
}

imi_v1_source_registry <- function(metric_roles) {
  keys <- unique(metric_roles$source_identity)
  rows <- lapply(seq_along(keys), function(i) {
    block <- metric_roles[metric_roles$source_identity == keys[[i]], , drop = FALSE]
    data.frame(
      replay_id = sprintf("imi_v1_source_%03d", i),
      source_identity = keys[[i]],
      inference = block$inference[[1L]],
      model_variant = block$model_variant[[1L]],
      model_label = block$model_label[[1L]],
      family = block$family[[1L]],
      tau = block$tau[[1L]],
      source_candidate_id = block$source_candidate_id[[1L]],
      source_run_tag = block$source_run_tag[[1L]],
      metric_roles = paste(sort(unique(block$metric_role)), collapse = ";"),
      metric_names = paste(sort(unique(block$metric_name)), collapse = ";"),
      article_rows = paste(sort(unique(block$article_row)), collapse = ";"),
      planned_chains = if (identical(block$inference[[1L]], "mcmc")) {
        imi_v1_mcmc_chains
      } else 1L,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out[order(out$inference, out$model_variant, out$family, out$tau,
            out$source_candidate_id, out$source_run_tag), , drop = FALSE]
}

imi_v1_json_request_metadata <- function(path, repo_root = imi_v1_repo_root()) {
  obj <- tryCatch(ffv2_read_json(path), error = function(...) NULL)
  if (is.null(obj) || !is.list(obj) || is.null(obj$config) || is.null(obj$root_spec)) return(NULL)
  candidate <- as.character(
    obj$candidate_id %||% (obj$profile %||% list())$candidate_id %||%
      obj$spec_id %||% (obj$root_spec %||% list())$screening_profile_id %||% ""
  )[1L]
  inference <- as.character(obj$method %||% ((obj$config %||% list())$inference %||% list())$method %||% "")[1L]
  likelihood <- as.character(((obj$config %||% list())$inference %||% list())$likelihood_family %||%
                               (obj$root_spec %||% list())$likelihood_family %||% "")[1L]
  family <- as.character((obj$root_spec %||% list())$source_family %||% "")[1L]
  tau <- as.numeric((obj$root_spec %||% list())$tau %||% NA_real_)[1L]
  if (!nzchar(candidate) || !nzchar(inference) || !nzchar(family) || !is.finite(tau)) return(NULL)
  data.frame(
    request_path = imi_v1_relpath(normalizePath(path, winslash = "/", mustWork = TRUE), repo_root),
    request_sha256 = ffv2_file_sha256(path),
    candidate_id = candidate,
    inference = inference,
    likelihood_family = likelihood,
    family = family,
    tau = tau,
    root_id = as.character((obj$root_spec %||% list())$root_id %||% NA_character_),
    reservoir_seed = as.integer(((obj$config %||% list())$desn %||% list())$seed %||% NA_integer_),
    mcmc_seed = as.integer((((obj$config %||% list())$inference %||% list())$mcmc %||% list())$control$seed %||% NA_integer_),
    config_path_hint = as.character((obj$execution %||% list())$config_path %||% NA_character_),
    provenance_kind = "frozen_request_json",
    target_registry_path = NA_character_,
    target_registry_sha256 = NA_character_,
    target_registry_row = NA_integer_,
    grid_path = NA_character_,
    grid_sha256 = NA_character_,
    grid_row = NA_integer_,
    stringsAsFactors = FALSE
  )
}

imi_v1_target_registry_catalog <- function(repo_root = imi_v1_repo_root()) {
  registry_files <- c(
    file.path(repo_root, "config", "validation",
              "qdesn_dynamic_fitforecast_v2_500obs_trainonly_rebaseline_v1_target_spec_ids.csv"),
    file.path(repo_root, "config", "validation",
              "qdesn_dynamic_fitforecast_v2_500obs_vb_trainonly_rebaseline_v1_target_spec_ids.csv")
  )
  rows <- list()
  row_i <- 0L
  for (registry_path in registry_files) {
    if (!file.exists(registry_path)) next
    target <- ffv2_read_csv(registry_path)
    grid_path <- sub("_target_spec_ids[.]csv$", "_grid.csv", registry_path)
    if (!file.exists(grid_path)) {
      stop(sprintf("Target registry has no matched frozen grid: %s", registry_path),
           call. = FALSE)
    }
    grid <- ffv2_read_csv(grid_path)
    grid_index <- match(as.character(target$root_id), as.character(grid$root_id))
    if (anyNA(grid_index)) {
      stop(sprintf("Target registry/grid root join failed: %s", registry_path),
           call. = FALSE)
    }
    for (i in seq_len(nrow(target))) {
      request_path <- as.character(target$source_fit_request_path[[i]])
      expected_request_sha <- as.character(target$source_fit_request_sha256[[i]])
      if (!file.exists(request_path)) next
      observed_request_sha <- ffv2_file_sha256(request_path)
      if (!identical(observed_request_sha, expected_request_sha)) {
        stop(sprintf("Frozen source request hash mismatch: %s", request_path),
             call. = FALSE)
      }
      g <- grid_index[[i]]
      row_i <- row_i + 1L
      rows[[row_i]] <- data.frame(
        request_path = normalizePath(request_path, winslash = "/", mustWork = TRUE),
        request_sha256 = observed_request_sha,
        candidate_id = as.character(target$spec_id[[i]]),
        inference = as.character(target$inference[[i]]),
        likelihood_family = as.character(target$likelihood_family[[i]]),
        family = as.character(target$family[[i]]),
        tau = as.numeric(target$tau[[i]]),
        root_id = as.character(target$root_id[[i]]),
        reservoir_seed = as.integer(grid$desn_seed[[g]] %||% grid$seed[[g]]),
        mcmc_seed = if ("mcmc_seed" %in% names(grid)) {
          as.integer(grid$mcmc_seed[[g]])
        } else NA_integer_,
        config_path_hint = NA_character_,
        provenance_kind = "tracked_target_registry_and_grid",
        target_registry_path = imi_v1_relpath(registry_path, repo_root),
        target_registry_sha256 = ffv2_file_sha256(registry_path),
        target_registry_row = i,
        grid_path = imi_v1_relpath(grid_path, repo_root),
        grid_sha256 = ffv2_file_sha256(grid_path),
        grid_row = g,
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) return(data.frame())
  do.call(rbind, rows)
}

imi_v1_request_catalog <- function(repo_root = imi_v1_repo_root()) {
  roots <- c(
    file.path(repo_root, "config", "validation"),
    file.path(repo_root, "validation", "fitforecast_v2", "promotions"),
    file.path(repo_root, "validation", "fitforecast_v2", "audits")
  )
  files <- unlist(lapply(roots, function(root) {
    list.files(root, pattern = "[.]json$", recursive = TRUE, full.names = TRUE)
  }), use.names = FALSE)
  rows <- lapply(files, imi_v1_json_request_metadata, repo_root = repo_root)
  rows <- rows[!vapply(rows, is.null, logical(1L))]
  json_catalog <- if (length(rows)) do.call(rbind, rows) else data.frame()
  registry_catalog <- imi_v1_target_registry_catalog(repo_root)
  if (!nrow(json_catalog)) return(registry_catalog)
  if (!nrow(registry_catalog)) return(json_catalog)
  rbind(json_catalog, registry_catalog)
}

imi_v1_request_path_score <- function(path, run_tag) {
  path <- tolower(as.character(path))
  tag <- tolower(as.character(run_tag))
  score <- 0
  if (grepl("fit_request[.]json$|evidence/configs/.+[.]json$|frozen_parent_requests/.+[.]json$", path)) score <- score + 20
  patterns <- list(
    "canonical-gap" = "article_v9|canonical_gap",
    "forecast-gap" = "article_v8|forecast_gap",
    "postm0-legacy" = "article_v7|postm0",
    "paired-confirm" = "article_v6|paired_confirmation",
    "ind-exal-m0-v1" = "independent_exal_m0|m0_relaunch|article_v5",
    "qdesn-strv1" = "sparse_topology_refine|article_v5",
    "qdesn-trainonly-v1" = "trainonly_rebaseline|frozen_parent|article_v5",
    "qdesn-vb-trainonly-v1" = "vb_trainonly|train_only_rebaseline|article_v5"
  )
  for (key in names(patterns)) {
    if (grepl(key, tag, fixed = TRUE) && grepl(patterns[[key]], path)) score <- score + 100
  }
  if (grepl("promotions/", path)) score <- score + 5
  score
}

imi_v1_resolve_qdesn_requests <- function(registry, catalog) {
  q_idx <- grepl("^qdesn_", registry$model_variant)
  registry$request_path <- NA_character_
  registry$request_sha256 <- NA_character_
  registry$request_match_count <- NA_integer_
  registry$request_resolution <- ifelse(q_idx, "UNRESOLVED", "GENERATED_C13")
  for (field in c(
    "provenance_kind", "target_registry_path", "target_registry_sha256",
    "target_registry_row", "grid_path", "grid_sha256", "grid_row",
    "reservoir_seed", "source_request_root_id"
  )) registry[[field]] <- NA
  for (i in which(q_idx)) {
    row <- registry[i, , drop = FALSE]
    likelihood <- if (identical(row$model_variant[[1L]], "qdesn_al_rhs_ns")) "al" else "exal"
    keep <- as.character(catalog$candidate_id) == as.character(row$source_candidate_id[[1L]]) &
      as.character(catalog$inference) == as.character(row$inference[[1L]]) &
      as.character(catalog$family) == as.character(row$family[[1L]]) &
      abs(as.numeric(catalog$tau) - as.numeric(row$tau[[1L]])) < 1e-10 &
      as.character(catalog$likelihood_family) == likelihood
    candidates <- catalog[keep, , drop = FALSE]
    registry$request_match_count[[i]] <- nrow(candidates)
    if (!nrow(candidates)) next
    scores <- vapply(candidates$request_path, imi_v1_request_path_score, numeric(1L),
                     run_tag = row$source_run_tag[[1L]])
    candidates <- candidates[order(-scores, candidates$request_path), , drop = FALSE]
    selected <- candidates[1L, , drop = FALSE]
    registry$request_path[[i]] <- selected$request_path[[1L]]
    registry$request_sha256[[i]] <- selected$request_sha256[[1L]]
    registry$provenance_kind[[i]] <- selected$provenance_kind[[1L]]
    registry$target_registry_path[[i]] <- selected$target_registry_path[[1L]]
    registry$target_registry_sha256[[i]] <- selected$target_registry_sha256[[1L]]
    registry$target_registry_row[[i]] <- selected$target_registry_row[[1L]]
    registry$grid_path[[i]] <- selected$grid_path[[1L]]
    registry$grid_sha256[[i]] <- selected$grid_sha256[[1L]]
    registry$grid_row[[i]] <- selected$grid_row[[1L]]
    registry$reservoir_seed[[i]] <- selected$reservoir_seed[[1L]]
    registry$source_request_root_id[[i]] <- selected$root_id[[1L]]
    registry$request_resolution[[i]] <- if (nrow(candidates) == 1L) "EXACT_UNIQUE" else "FROZEN_DETERMINISTIC"
  }
  registry
}

imi_v1_static_audit <- function(repo_root = imi_v1_repo_root(),
                                authority_id = imi_v1_authority_id) {
  interface_path <- imi_v1_authority_interface_path(repo_root, authority_id)
  manifest_path <- imi_v1_authority_manifest_path(repo_root, authority_id)
  interface <- ffv2_read_csv(interface_path)
  roles <- imi_v1_expand_metric_sources(interface)
  registry <- imi_v1_source_registry(roles)
  catalog <- imi_v1_request_catalog(repo_root)
  registry <- imi_v1_resolve_qdesn_requests(registry, catalog)
  checks <- data.frame(
    check = c(
      "authority_interface_exists", "authority_manifest_exists", "article_rows_72",
      "metric_roles_216", "source_identities_90", "vb_sources_36",
      "mcmc_sources_54", "production_jobs_198", "qdesn_requests_resolved",
      "source_metric_values_finite"
    ),
    pass = c(
      file.exists(interface_path), file.exists(manifest_path), nrow(interface) == 72L,
      nrow(roles) == 216L, nrow(registry) == 90L,
      sum(registry$inference == "vb") == 36L,
      sum(registry$inference == "mcmc") == 54L,
      sum(registry$planned_chains) == 198L,
      all(registry$request_resolution[grepl("^qdesn_", registry$model_variant)] != "UNRESOLVED"),
      all(is.finite(roles$authoritative_value))
    ),
    stringsAsFactors = FALSE
  )
  list(interface = interface, metric_roles = roles, source_registry = registry,
       request_catalog = catalog, checks = checks)
}

imi_v1_seed <- function(...) {
  key <- paste(..., sep = "|")
  hex <- substr(digest::digest(key, algo = "sha256", serialize = FALSE), 1L, 7L)
  as.integer(strtoi(hex, base = 16L)) %% 900000000L + 10000000L
}

imi_v1_output_root <- function(repo_root, run_tag) {
  file.path(repo_root, "results", "qdesn_mcmc_validation", imi_v1_stage, run_tag)
}

imi_v1_state_root <- function(repo_root, run_id) {
  file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration", run_id)
}

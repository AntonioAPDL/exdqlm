ffv2_clean_token <- function(x, fallback = "na") {
  x <- as.character(x %||% fallback)[1L]
  if (is.na(x) || !nzchar(trimws(x))) x <- fallback
  x <- tolower(trimws(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  if (!nzchar(x)) fallback else x
}

ffv2_hash_string <- function(x, prefix = "", n = 16L) {
  tmp <- tempfile("ffv2_hash_")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(enc2utf8(as.character(x)), tmp, useBytes = TRUE)
  hash <- ffv2_file_sha256(tmp)
  paste0(prefix, substr(hash, 1L, as.integer(n)[1L]))
}

ffv2_row_value <- function(row, name, default = NA_character_) {
  if (is.null(row) || !length(row) || !name %in% names(row)) return(default)
  val <- row[[name]]
  if (!length(val)) return(default)
  val[[1L]]
}

ffv2_make_spec_id <- function(row, model_family = "exdqlm_dqlm") {
  fields <- c(
    model_family = model_family,
    model_variant = ffv2_row_value(row, "model_variant"),
    inference = ffv2_row_value(row, "inference"),
    likelihood_family = ffv2_row_value(row, "likelihood_family"),
    beta_prior_type = ffv2_row_value(row, "beta_prior_type"),
    scenario_id = ffv2_row_value(row, "scenario_id", ffv2_row_value(row, "source_scenario")),
    family = ffv2_row_value(row, "family", ffv2_row_value(row, "source_family")),
    tau = as.character(ffv2_row_value(row, "tau")),
    fit_size = as.character(ffv2_row_value(row, "fit_size", ffv2_row_value(row, "effective_fit_size"))),
    source_cell_id = ffv2_row_value(row, "source_cell_id", ffv2_row_value(row, "dataset_cell_id")),
    source_hash = ffv2_row_value(row, "series_wide_sha256", ffv2_row_value(row, "source_sim_sha256")),
    truth_hash = ffv2_row_value(row, "true_quantile_grid_sha256"),
    forecast_protocol = ffv2_row_value(row, "forecast_protocol"),
    max_lead_configured = as.character(ffv2_row_value(row, "max_lead_configured")),
    origin_stride = as.character(ffv2_row_value(row, "origin_stride")),
    calibration_id = ffv2_row_value(row, "calibration_id"),
    model_spec_hash = ffv2_row_value(row, "model_spec_hash"),
    latent_clock_mode = ffv2_row_value(row, "latent_clock_mode"),
    latent_clock_start_source_index = as.character(ffv2_row_value(row, "latent_clock_start_source_index")),
    latent_clock_offset = as.character(ffv2_row_value(row, "latent_clock_offset")),
    model_C0_scale = as.character(ffv2_row_value(row, "model_C0_scale")),
    trend_C0_scale = as.character(ffv2_row_value(row, "trend_C0_scale")),
    seasonal_C0_scale = as.character(ffv2_row_value(row, "seasonal_C0_scale")),
    df_value = as.character(ffv2_row_value(row, "df_value")),
    dim_df = as.character(ffv2_row_value(row, "dim_df")),
    dynamic_model_period = as.character(ffv2_row_value(row, "dynamic_model_period", ffv2_row_value(row, "period"))),
    dynamic_model_harmonics = as.character(ffv2_row_value(row, "dynamic_model_harmonics", ffv2_row_value(row, "harmonics")))
  )
  fields[is.na(fields)] <- ""
  digest <- ffv2_hash_string(paste(names(fields), fields, sep = "=", collapse = "\n"), n = 14L)
  tau_label <- ffv2_clean_token(ffv2_row_value(row, "tau_label", ffv2_row_value(row, "tau")), "tau")
  fit_label <- paste0("tt", ffv2_clean_token(ffv2_row_value(row, "fit_size"), "fit"))
  paste(
    ffv2_clean_token(model_family, "model"),
    ffv2_clean_token(ffv2_row_value(row, "family", ffv2_row_value(row, "source_family")), "family"),
    tau_label,
    fit_label,
    ffv2_clean_token(ffv2_row_value(row, "model_variant", ffv2_row_value(row, "beta_prior_type")), "variant"),
    ffv2_clean_token(ffv2_row_value(row, "inference", ffv2_row_value(row, "method")), "inference"),
    digest,
    sep = "__"
  )
}

ffv2_validation_stage <- function(stage = "all") {
  stage <- tolower(as.character(stage %||% "all")[1L])
  aliases <- c(
    fit = "fit-only",
    forecast = "forecast-only",
    metrics = "metrics-only",
    full = "all"
  )
  if (stage %in% names(aliases)) stage <- aliases[[stage]]
  allowed <- c("all", "fit-only", "forecast-only", "metrics-only")
  if (!stage %in% allowed) {
    stop(sprintf("--validation-stage must be one of: %s", paste(allowed, collapse = ", ")),
         call. = FALSE)
  }
  stage
}

ffv2_split_csv_arg <- function(x) {
  x <- as.character(x %||% "")[1L]
  if (!nzchar(trimws(x))) return(character(0))
  out <- trimws(strsplit(x, ",", fixed = TRUE)[[1L]])
  out[nzchar(out)]
}

ffv2_split_int_arg <- function(x) {
  vals <- suppressWarnings(as.integer(ffv2_split_csv_arg(x)))
  vals[is.finite(vals)]
}

ffv2_split_num_arg <- function(x) {
  vals <- suppressWarnings(as.numeric(ffv2_split_csv_arg(x)))
  vals[is.finite(vals)]
}

ffv2_filter_manifest <- function(manifest,
                                 spec_ids = character(0),
                                 row_ids = integer(0),
                                 row_keys = character(0),
                                 families = character(0),
                                 taus = numeric(0),
                                 fit_sizes = integer(0),
                                 model_variants = character(0),
                                 inferences = character(0),
                                 phases = character(0)) {
  out <- as.data.frame(manifest, stringsAsFactors = FALSE)
  if (!nrow(out)) return(out)
  spec_ids <- as.character(spec_ids %||% character(0))
  row_ids <- as.integer(row_ids %||% integer(0))
  row_keys <- as.character(row_keys %||% character(0))
  families <- as.character(families %||% character(0))
  taus <- as.numeric(taus %||% numeric(0))
  fit_sizes <- as.integer(fit_sizes %||% integer(0))
  model_variants <- as.character(model_variants %||% character(0))
  inferences <- as.character(inferences %||% character(0))
  phases <- as.character(phases %||% character(0))

  if (length(spec_ids) && "spec_id" %in% names(out)) out <- out[as.character(out$spec_id) %in% spec_ids, , drop = FALSE]
  if (length(row_ids) && "row_id" %in% names(out)) out <- out[as.integer(out$row_id) %in% row_ids, , drop = FALSE]
  if (length(row_keys) && "row_key" %in% names(out)) out <- out[as.character(out$row_key) %in% row_keys, , drop = FALSE]
  if (length(families) && "family" %in% names(out)) out <- out[as.character(out$family) %in% families, , drop = FALSE]
  if (length(taus) && "tau" %in% names(out)) out <- out[as.numeric(out$tau) %in% taus, , drop = FALSE]
  if (length(fit_sizes) && "fit_size" %in% names(out)) out <- out[as.integer(out$fit_size) %in% fit_sizes, , drop = FALSE]
  if (length(model_variants) && "model_variant" %in% names(out)) {
    out <- out[as.character(out$model_variant) %in% model_variants, , drop = FALSE]
  }
  if (length(inferences) && "inference" %in% names(out)) out <- out[as.character(out$inference) %in% inferences, , drop = FALSE]
  if (length(phases) && "phase" %in% names(out)) out <- out[as.character(out$phase) %in% phases, , drop = FALSE]
  rownames(out) <- NULL
  out
}

ffv2_select_manifest_rows <- function(manifest,
                                      phase = "smoke",
                                      include_completed = FALSE,
                                      selectors = list()) {
  selected <- ffv2_stage_rows(manifest, phase = phase, include_completed = include_completed)
  ffv2_filter_manifest(
    selected,
    spec_ids = selectors$spec_ids %||% character(0),
    row_ids = selectors$row_ids %||% integer(0),
    row_keys = selectors$row_keys %||% character(0),
    families = selectors$families %||% character(0),
    taus = selectors$taus %||% numeric(0),
    fit_sizes = selectors$fit_sizes %||% integer(0),
    model_variants = selectors$model_variants %||% character(0),
    inferences = selectors$inferences %||% character(0),
    phases = selectors$phases %||% character(0)
  )
}

ffv2_load_run_overrides <- function(path = NULL) {
  if (is.null(path) || !length(path) || is.na(path[[1L]]) || !nzchar(as.character(path)[1L])) {
    return(list())
  }
  path <- normalizePath(as.character(path)[1L], winslash = "/", mustWork = TRUE)
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("yaml", "yml")) return(ffv2_load_yaml(path))
  if (ext == "json") return(ffv2_read_json(path))
  stop("Run override registry must be YAML or JSON.", call. = FALSE)
}

ffv2_override_for_spec <- function(overrides, spec_id, row) {
  if (is.null(overrides) || !length(overrides)) return(list())
  spec_id <- as.character(spec_id %||% "")[1L]
  row_key <- as.character(ffv2_row_value(row, "row_key", ""))[1L]
  out <- list()
  if (length(spec_id) && nzchar(spec_id) && !is.null(overrides$specs[[spec_id]])) {
    out <- utils::modifyList(out, overrides$specs[[spec_id]], keep.null = TRUE)
  }
  if (length(row_key) && nzchar(row_key) && !is.null(overrides$row_keys[[row_key]])) {
    out <- utils::modifyList(out, overrides$row_keys[[row_key]], keep.null = TRUE)
  }
  rows <- overrides$rows %||% list()
  if (length(rows)) {
    for (item in rows) {
      if (!is.list(item)) next
      item_spec <- as.character(item$spec_id %||% "")[1L]
      item_key <- as.character(item$row_key %||% "")[1L]
      if ((nzchar(item_spec) && identical(item_spec, spec_id)) ||
          (nzchar(item_key) && identical(item_key, row_key))) {
        item$spec_id <- NULL
        item$row_key <- NULL
        out <- utils::modifyList(out, item, keep.null = TRUE)
      }
    }
  }
  out
}

ffv2_apply_row_override <- function(config, override) {
  if (is.null(override) || !length(override)) {
    config$run_override_applied <- FALSE
    return(config)
  }
  id <- as.character(override$id %||% override$override_id %||% config$spec_id %||% config$row_key %||% "")[1L]
  reason <- as.character(override$reason %||% override$notes %||% "")[1L]
  for (field in c("runtime", "budget", "models", "retention", "source", "forecast", "metadata")) {
    if (!is.null(override[[field]])) {
      config[[field]] <- utils::modifyList(config[[field]] %||% list(), override[[field]], keep.null = TRUE)
    }
  }
  scalar_names <- setdiff(names(override), c(
    "id", "override_id", "reason", "notes", "runtime", "budget", "models",
    "retention", "source", "forecast", "metadata"
  ))
  for (nm in scalar_names) config[[nm]] <- override[[nm]]
  config$run_override_applied <- TRUE
  config$run_override_id <- id
  config$run_override_reason <- reason
  config
}

ffv2_handoff_enabled <- function(config, role = c("fit", "vb_init")) {
  role <- match.arg(role)
  handoff <- config$handoff %||% list()
  if (role == "fit") return(!isFALSE(handoff$fit %||% TRUE))
  !isFALSE(handoff$vb_init %||% TRUE)
}

ffv2_save_handoff <- function(object, path, manifest_path, role, config, transient = TRUE) {
  if (is.null(path) || !nzchar(as.character(path)[1L])) return(invisible(NULL))
  ffv2_ensure_dir(dirname(path))
  saveRDS(object, path)
  info <- file.info(path)
  manifest <- list(
    role = role,
    spec_id = as.character(config$spec_id %||% NA_character_),
    row_id = as.integer(config$row_id %||% NA_integer_),
    row_key = as.character(config$row_key %||% NA_character_),
    run_tag = as.character(config$run_tag %||% NA_character_),
    path = normalizePath(path, winslash = "/", mustWork = TRUE),
    sha256 = ffv2_file_sha256(path),
    bytes = as.numeric(info$size),
    transient = isTRUE(transient),
    storage_class = "stage_handoff_not_article_facing",
    created_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    object_class = paste(class(object), collapse = "|")
  )
  if (!is.null(manifest_path) && nzchar(as.character(manifest_path)[1L])) {
    ffv2_write_json(manifest, manifest_path)
  }
  invisible(manifest)
}

ffv2_read_handoff <- function(path, manifest_path = NULL, expected_role = NULL) {
  if (is.null(path) || !file.exists(path)) {
    stop(sprintf("Required stage handoff does not exist: %s", as.character(path %||% NA_character_)[1L]),
         call. = FALSE)
  }
  if (!is.null(manifest_path) && file.exists(manifest_path)) {
    manifest <- ffv2_read_json(manifest_path)
    if (!is.null(expected_role) && !identical(as.character(manifest$role %||% ""), as.character(expected_role))) {
      stop(sprintf("Stage handoff role mismatch at %s", manifest_path), call. = FALSE)
    }
    hash <- ffv2_file_sha256(path)
    if (!identical(as.character(manifest$sha256 %||% ""), hash)) {
      stop(sprintf("Stage handoff hash mismatch at %s", path), call. = FALSE)
    }
  }
  readRDS(path)
}

ffv2_prune_handoff <- function(path, manifest_path = NULL) {
  if (!is.null(path) && file.exists(path)) unlink(path)
  if (!is.null(manifest_path) && file.exists(manifest_path)) {
    manifest <- tryCatch(ffv2_read_json(manifest_path), error = function(e) list())
    manifest$pruned_at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
    manifest$path_exists_after_prune <- FALSE
    ffv2_write_json(manifest, manifest_path)
  }
  invisible(TRUE)
}

ffv2_minimal_exdqlm_vb_init <- function(fit) {
  out <- list(
    dqlm.ind = isTRUE(fit$dqlm.ind),
    p0 = fit$p0,
    sig.out = fit$sig.out,
    gammasig.out = fit$gammasig.out,
    vts.out = fit$vts.out,
    theta.out = fit$theta.out,
    sts.out = fit$sts.out,
    samp.sigma = fit$samp.sigma,
    samp.gamma = fit$samp.gamma
  )
  class(out) <- unique(c(class(fit), "ffv2_minimal_vb_init"))
  out
}

ffv2_find_vb_init_handoff <- function(config) {
  explicit <- as.character(config$vb_init_source_path %||% "")[1L]
  if (nzchar(explicit) && file.exists(explicit)) {
    return(list(path = explicit, manifest_path = as.character(config$vb_init_source_manifest_path %||% "")[1L], source = "explicit"))
  }
  manifest_path <- as.character(config$row_manifest_path %||% "")[1L]
  if (!nzchar(manifest_path) || !file.exists(manifest_path)) return(NULL)
  manifest <- tryCatch(ffv2_read_csv(manifest_path), error = function(e) NULL)
  if (is.null(manifest) || !nrow(manifest)) return(NULL)
  required <- c("family", "tau", "fit_size", "model_variant", "inference", "vb_init_handoff_path")
  if (!all(required %in% names(manifest))) return(NULL)
  keep <- as.character(manifest$inference) == "vb" &
    as.character(manifest$family) == as.character(config$family) &
    abs(as.numeric(manifest$tau) - as.numeric(config$tau)) < 1e-8 &
    as.integer(manifest$fit_size) == as.integer(config$fit_size) &
    as.character(manifest$model_variant) == as.character(config$model_variant)
  candidates <- manifest[keep, , drop = FALSE]
  if (!nrow(candidates)) return(NULL)
  candidates <- candidates[file.exists(as.character(candidates$vb_init_handoff_path)), , drop = FALSE]
  if (!nrow(candidates)) return(NULL)
  list(
    path = as.character(candidates$vb_init_handoff_path[[1L]]),
    manifest_path = as.character(candidates$vb_init_handoff_manifest_path[[1L]] %||% ""),
    source = "matching_vb_manifest_row",
    source_spec_id = as.character(candidates$spec_id[[1L]] %||% NA_character_)
  )
}

ffv2_empty_path_summary <- function(split_role = "forecast") {
  cols <- unique(c(ffv2_required_path_columns(), "horizon", "forecast_protocol",
                   "state_update_method", "refit_per_origin",
                   "forecast_origin_source_index", "forecast_lead",
                   "target_source_index", "origin_sequence_id", "origin_stride",
                   "max_lead_configured", "n_origins_for_lead", "local_start_t",
                   "qhat_p0025", "qhat_p0250", "qhat_p0500", "qhat_p0750", "qhat_p0975"))
  out <- as.data.frame(stats::setNames(rep(list(logical(0)), length(cols)), cols),
                       stringsAsFactors = FALSE)
  out$split_role <- character(0)
  out
}

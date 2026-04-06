`%||%` <- function(a, b) if (is.null(a)) b else a

qdesn_dynamic_crossstudy_load_defaults <- function(path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_defaults.yaml"),
                                                   repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- yaml::read_yaml(yaml_path)
  if (!is.list(out)) {
    stop("Dynamic exdqlm cross-study defaults YAML must parse to a list.", call. = FALSE)
  }
  out
}

qdesn_dynamic_crossstudy_load_grid <- function(path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_grid.csv"),
                                               repo_root = NULL) {
  grid_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- utils::read.csv(grid_path, stringsAsFactors = FALSE)
  if (!nrow(out)) {
    stop("Dynamic exdqlm cross-study grid CSV is empty.", call. = FALSE)
  }
  out
}

.qdesn_dynamic_crossstudy_prob_label <- function(x) {
  gsub("\\.", "p", format(as.numeric(x)[1L], nsmall = 2, digits = 4, trim = TRUE))
}

.qdesn_dynamic_crossstudy_parse_tau_label <- function(x) {
  raw <- sub("^tau_", "", as.character(x)[1L])
  raw <- gsub("p", ".", raw, fixed = TRUE)
  as.numeric(raw)
}

.qdesn_dynamic_crossstudy_parse_fit_size <- function(x, prefix) {
  as.integer(sub(sprintf("^%s", prefix), "", as.character(x)[1L]))
}

.qdesn_dynamic_crossstudy_parse_reference_root <- function(root_dir, reference_root) {
  root_dir <- normalizePath(root_dir, winslash = "/", mustWork = TRUE)
  reference_root <- normalizePath(reference_root, winslash = "/", mustWork = TRUE)
  rel <- sub(paste0("^", reference_root, "/?"), "", root_dir)
  parts <- strsplit(rel, "/", fixed = TRUE)[[1L]]
  if (length(parts) < 5L) {
    stop(sprintf("Dynamic reference root has unexpected structure: %s", root_dir), call. = FALSE)
  }
  scenario <- as.character(parts[[1L]])
  family <- as.character(parts[[2L]])
  tau <- .qdesn_dynamic_crossstudy_parse_tau_label(parts[[3L]])
  fit_size <- .qdesn_dynamic_crossstudy_parse_fit_size(parts[[4L]], "fit_input_lastTT")
  validation_tt <- .qdesn_dynamic_crossstudy_parse_fit_size(parts[[5L]], "validation_dynamic_tt")
  if (!is.finite(tau) || !is.finite(fit_size) || !is.finite(validation_tt)) {
    stop(sprintf("Failed to parse dynamic reference root metadata from: %s", root_dir), call. = FALSE)
  }
  if (!identical(as.integer(fit_size), as.integer(validation_tt))) {
    stop(sprintf(
      "Dynamic reference root mismatch: fit_input_lastTT=%d but validation_dynamic_tt=%d for %s",
      as.integer(fit_size), as.integer(validation_tt), root_dir
    ), call. = FALSE)
  }
  fit_input_dir <- dirname(root_dir)
  data.frame(
    root_dir = root_dir,
    scenario = scenario,
    root_kind = "dynamic",
    family = family,
    tau = tau,
    fit_size = as.integer(fit_size),
    fit_input_dir = normalizePath(fit_input_dir, winslash = "/", mustWork = TRUE),
    series_wide_path = normalizePath(file.path(fit_input_dir, "series_wide.csv"), winslash = "/", mustWork = TRUE),
    selection_indices_path = normalizePath(file.path(fit_input_dir, "selection_indices.csv"), winslash = "/", mustWork = TRUE),
    sim_path = normalizePath(file.path(fit_input_dir, "sim_output.rds"), winslash = "/", mustWork = TRUE),
    report_summary_path = normalizePath(file.path(root_dir, "tables", "report_summary.md"), winslash = "/", mustWork = TRUE),
    stringsAsFactors = FALSE
  )
}

qdesn_dynamic_crossstudy_collect_reference_inventory <- function(reference_root) {
  reference_root <- .qdesn_validation_resolve_path(reference_root, must_work = TRUE)
  signoff_paths <- list.files(reference_root, pattern = "root_signoff_summary.csv", recursive = TRUE, full.names = TRUE)
  if (!length(signoff_paths)) {
    stop(sprintf("No dynamic reference root_signoff_summary.csv files found under %s", reference_root), call. = FALSE)
  }
  root_dirs <- sort(unique(dirname(dirname(signoff_paths))))
  cell_inventory <- .qdesn_validation_bind_rows(lapply(root_dirs, function(root_dir) {
    .qdesn_dynamic_crossstudy_parse_reference_root(root_dir, reference_root)
  }))

  build_fit_rows <- function(root_dir) {
    meta_path <- file.path(root_dir, "tables", "root_signoff_summary.csv")
    signoff_long_path <- file.path(root_dir, "tables", "method_signoff_long.csv")
    fit_summary_path <- file.path(root_dir, "tables", "fit_summary.csv")
    if (!file.exists(meta_path) || !file.exists(signoff_long_path)) return(NULL)
    meta <- utils::read.csv(meta_path, stringsAsFactors = FALSE)
    if (!nrow(meta)) return(NULL)
    signoff_long <- utils::read.csv(signoff_long_path, stringsAsFactors = FALSE)
    if (!nrow(signoff_long)) return(NULL)
    fit_summary <- if (file.exists(fit_summary_path)) utils::read.csv(fit_summary_path, stringsAsFactors = FALSE) else data.frame(stringsAsFactors = FALSE)
    out <- if (nrow(fit_summary)) {
      merge(
        signoff_long,
        fit_summary,
        by = intersect(c("inference", "model", "tau"), intersect(names(signoff_long), names(fit_summary))),
        all.x = TRUE,
        sort = FALSE,
        suffixes = c("", "_fit")
      )
    } else {
      signoff_long
    }
    parsed <- .qdesn_dynamic_crossstudy_parse_reference_root(root_dir, reference_root)
    for (nm in c("root_id", "root_kind", "family", "tau", "fit_size", "prior")) {
      if (nm %in% names(meta) && !nm %in% names(out)) out[[nm]] <- meta[[nm]][1L]
    }
    out$scenario <- as.character(parsed$scenario[1L])
    if (!("runtime_sec" %in% names(out)) && "runtime_sec_fit" %in% names(out)) {
      out$runtime_sec <- out$runtime_sec_fit
    }
    out
  }

  build_pair_rows <- function(root_dir) {
    path <- file.path(root_dir, "tables", "algorithm_pair_signoff.csv")
    if (!file.exists(path)) return(NULL)
    df <- utils::read.csv(path, stringsAsFactors = FALSE)
    if (!nrow(df)) return(NULL)
    parsed <- .qdesn_dynamic_crossstudy_parse_reference_root(root_dir, reference_root)
    df$scenario <- as.character(parsed$scenario[1L])
    if (!("algorithm_pair_signoff_grade" %in% names(df)) && "pair_signoff_grade" %in% names(df)) {
      df$algorithm_pair_signoff_grade <- df$pair_signoff_grade
    }
    if (!("algorithm_pair_comparison_eligible" %in% names(df)) && "pair_comparison_eligible" %in% names(df)) {
      df$algorithm_pair_comparison_eligible <- df$pair_comparison_eligible
    }
    df
  }

  build_model_rows <- function(root_dir) {
    path <- file.path(root_dir, "tables", "model_pair_signoff.csv")
    if (!file.exists(path)) return(NULL)
    df <- utils::read.csv(path, stringsAsFactors = FALSE)
    if (!nrow(df)) return(NULL)
    parsed <- .qdesn_dynamic_crossstudy_parse_reference_root(root_dir, reference_root)
    df$scenario <- as.character(parsed$scenario[1L])
    df
  }

  build_root_rows <- function(root_dir) {
    path <- file.path(root_dir, "tables", "root_signoff_summary.csv")
    if (!file.exists(path)) return(NULL)
    df <- utils::read.csv(path, stringsAsFactors = FALSE)
    if (!nrow(df)) return(NULL)
    parsed <- .qdesn_dynamic_crossstudy_parse_reference_root(root_dir, reference_root)
    df$scenario <- as.character(parsed$scenario[1L])
    df
  }

  list(
    reference_root = reference_root,
    root_dirs = root_dirs,
    cell_inventory = cell_inventory,
    fit_summary = .qdesn_validation_bind_rows(lapply(root_dirs, build_fit_rows)),
    pairwise_vb_vs_mcmc = .qdesn_validation_bind_rows(lapply(root_dirs, build_pair_rows)),
    model_pair_signoff = .qdesn_validation_bind_rows(lapply(root_dirs, build_model_rows)),
    root_signoff_summary = .qdesn_validation_bind_rows(lapply(root_dirs, build_root_rows))
  )
}

qdesn_dynamic_crossstudy_validate_reference_inventory <- function(reference_inventory, defaults) {
  contract <- defaults$reference_contract %||% list()
  root_summary <- reference_inventory$root_signoff_summary %||% data.frame(stringsAsFactors = FALSE)
  problems <- character(0)
  if (!nrow(root_summary)) {
    problems <- c(problems, "reference root_signoff_summary inventory is empty")
  } else {
    scenarios <- sort(unique(as.character(root_summary$scenario)))
    families <- sort(unique(as.character(root_summary$family)))
    taus <- sort(unique(as.numeric(root_summary$tau)))
    fit_sizes <- sort(unique(as.integer(root_summary$fit_size)))
    root_kinds <- sort(unique(as.character(root_summary$root_kind)))
    unique_cells <- unique(paste(root_summary$scenario, root_summary$family, root_summary$tau, root_summary$fit_size, sep = "||"))
    if (!identical(scenarios, sort(as.character(contract$scenarios %||% scenarios)))) {
      problems <- c(problems, sprintf("scenario set mismatch: %s", paste(scenarios, collapse = ", ")))
    }
    if (!identical(families, sort(as.character(contract$families %||% families)))) {
      problems <- c(problems, sprintf("family set mismatch: %s", paste(families, collapse = ", ")))
    }
    if (!identical(as.numeric(taus), sort(as.numeric(contract$taus %||% taus)))) {
      problems <- c(problems, sprintf("tau set mismatch: %s", paste(taus, collapse = ", ")))
    }
    if (!identical(as.integer(fit_sizes), sort(as.integer(contract$fit_sizes %||% fit_sizes)))) {
      problems <- c(problems, sprintf("fit_size set mismatch: %s", paste(fit_sizes, collapse = ", ")))
    }
    if (!identical(root_kinds, sort(as.character(contract$root_kind %||% root_kinds)))) {
      problems <- c(problems, sprintf("root_kind set mismatch: %s", paste(root_kinds, collapse = ", ")))
    }
    if (!is.null(contract$expected_reference_roots) &&
        !identical(nrow(root_summary), as.integer(contract$expected_reference_roots))) {
      problems <- c(problems, sprintf(
        "expected %d reference roots, found %d",
        as.integer(contract$expected_reference_roots), nrow(root_summary)
      ))
    }
    if (!is.null(contract$expected_unique_dataset_cells) &&
        !identical(length(unique_cells), as.integer(contract$expected_unique_dataset_cells))) {
      problems <- c(problems, sprintf(
        "expected %d unique dataset cells, found %d",
        as.integer(contract$expected_unique_dataset_cells), length(unique_cells)
      ))
    }
  }
  if (length(problems)) {
    stop(paste(c("Dynamic reference inventory validation failed:", paste0("- ", problems)), collapse = "\n"), call. = FALSE)
  }
  list(
    reference_root_dirs_n = length(reference_inventory$root_dirs),
    reference_root_rows_n = nrow(root_summary),
    reference_unique_dataset_cells = length(unique(paste(
      root_summary$scenario, root_summary$family, root_summary$tau, root_summary$fit_size, sep = "||"
    ))),
    scenarios = sort(unique(as.character(root_summary$scenario))),
    families = sort(unique(as.character(root_summary$family))),
    taus = sort(unique(as.numeric(root_summary$tau))),
    fit_sizes = sort(unique(as.integer(root_summary$fit_size)))
  )
}

qdesn_dynamic_crossstudy_build_root_id <- function(root_spec) {
  sprintf(
    "root__dynamic__%s__%s__tau_%s__lasttt_%s__qdesn_%s",
    as.character(root_spec$source_scenario)[1L],
    as.character(root_spec$source_family)[1L],
    .qdesn_dynamic_crossstudy_prob_label(root_spec$tau),
    as.integer(root_spec$fit_size)[1L],
    as.character(root_spec$beta_prior_type)[1L]
  )
}

qdesn_dynamic_crossstudy_build_grid_from_reference <- function(defaults) {
  reference_cfg <- defaults$reference %||% list()
  reference_root <- .qdesn_validation_resolve_path(reference_cfg$dynamic_root, must_work = TRUE)
  reference_inventory <- qdesn_dynamic_crossstudy_collect_reference_inventory(reference_root)
  qdesn_dynamic_crossstudy_validate_reference_inventory(reference_inventory, defaults)
  pilot_cfg <- defaults$pilot %||% list()

  cells <- unique(reference_inventory$cell_inventory[, c(
    "scenario", "root_kind", "family", "tau", "fit_size",
    "fit_input_dir", "root_dir", "series_wide_path", "selection_indices_path", "sim_path"
  ), drop = FALSE])
  cells <- cells[order(cells$scenario, cells$family, cells$tau, cells$fit_size), , drop = FALSE]

  rows <- list()
  for (i in seq_len(nrow(cells))) {
    cell <- cells[i, , drop = FALSE]
    dataset_cell_id <- sprintf(
      "dynamic__%s__%s__tau_%s__lasttt_%s",
      as.character(cell$scenario[1L]),
      as.character(cell$family[1L]),
      .qdesn_dynamic_crossstudy_prob_label(cell$tau[1L]),
      as.integer(cell$fit_size[1L])
    )
    for (beta_prior_type in c("ridge", "rhs_ns")) {
      row <- data.frame(
        enabled = TRUE,
        dataset_cell_id = dataset_cell_id,
        source_root_kind = "dynamic",
        source_scenario = as.character(cell$scenario[1L]),
        source_family = as.character(cell$family[1L]),
        tau = as.numeric(cell$tau[1L]),
        fit_size = as.integer(cell$fit_size[1L]),
        beta_prior_type = beta_prior_type,
        source_fit_input_dir = as.character(cell$fit_input_dir[1L]),
        source_report_root = as.character(cell$root_dir[1L]),
        source_series_wide_path = as.character(cell$series_wide_path[1L]),
        source_selection_indices_path = as.character(cell$selection_indices_path[1L]),
        source_sim_path = as.character(cell$sim_path[1L]),
        source_reference_root_count = 1L,
        source_reference_priors = "default",
        source_current_rhsns_member = FALSE,
        source_legacy_rhs_member = FALSE,
        reservoir_profile = as.character(pilot_cfg$reservoir_profile %||% "tiny_d1_n8"),
        seed = as.integer(pilot_cfg$seed %||% 123L),
        stringsAsFactors = FALSE
      )
      row$root_id <- qdesn_dynamic_crossstudy_build_root_id(row)
      rows[[length(rows) + 1L]] <- row
    }
  }
  .qdesn_validation_bind_rows(rows)
}

qdesn_dynamic_crossstudy_validate_grid <- function(grid_df, defaults) {
  contract <- defaults$reference_contract %||% list()
  problems <- character(0)
  enabled <- if ("enabled" %in% names(grid_df)) {
    tolower(as.character(grid_df$enabled)) %in% c("true", "1", "t", "yes", "y")
  } else {
    rep(TRUE, nrow(grid_df))
  }
  grid_df <- grid_df[enabled, , drop = FALSE]
  if (!nrow(grid_df)) {
    stop("Dynamic cross-study grid has no enabled rows.", call. = FALSE)
  }
  scenarios <- sort(unique(as.character(grid_df$source_scenario)))
  families <- sort(unique(as.character(grid_df$source_family)))
  taus <- sort(unique(as.numeric(grid_df$tau)))
  fit_sizes <- sort(unique(as.integer(grid_df$fit_size)))
  root_kinds <- sort(unique(as.character(grid_df$source_root_kind)))
  priors <- sort(unique(as.character(grid_df$beta_prior_type)))
  unique_cells <- unique(as.character(grid_df$dataset_cell_id))

  if (!identical(scenarios, sort(as.character(contract$scenarios %||% scenarios)))) {
    problems <- c(problems, sprintf("scenario set mismatch: %s", paste(scenarios, collapse = ", ")))
  }
  if (!identical(families, sort(as.character(contract$families %||% families)))) {
    problems <- c(problems, sprintf("family set mismatch: %s", paste(families, collapse = ", ")))
  }
  if (!identical(as.numeric(taus), sort(as.numeric(contract$taus %||% taus)))) {
    problems <- c(problems, sprintf("tau set mismatch: %s", paste(taus, collapse = ", ")))
  }
  if (!identical(as.integer(fit_sizes), sort(as.integer(contract$fit_sizes %||% fit_sizes)))) {
    problems <- c(problems, sprintf("fit_size set mismatch: %s", paste(fit_sizes, collapse = ", ")))
  }
  if (!identical(root_kinds, sort(as.character(contract$root_kind %||% root_kinds)))) {
    problems <- c(problems, sprintf("root_kind set mismatch: %s", paste(root_kinds, collapse = ", ")))
  }
  if (!identical(priors, sort(as.character(contract$expected_priors %||% priors)))) {
    problems <- c(problems, sprintf("beta_prior_type set mismatch: %s", paste(priors, collapse = ", ")))
  }
  if (!is.null(contract$expected_unique_dataset_cells) &&
      !identical(length(unique_cells), as.integer(contract$expected_unique_dataset_cells))) {
    problems <- c(problems, sprintf(
      "expected %d unique dataset cells, found %d",
      as.integer(contract$expected_unique_dataset_cells), length(unique_cells)
    ))
  }
  if (!is.null(contract$expected_qdesn_roots) &&
      !identical(nrow(grid_df), as.integer(contract$expected_qdesn_roots))) {
    problems <- c(problems, sprintf(
      "expected %d QDESN roots, found %d",
      as.integer(contract$expected_qdesn_roots), nrow(grid_df)
    ))
  }
  if (any(abs(as.numeric(grid_df$tau) - 0.50) < 1e-8, na.rm = TRUE)) {
    problems <- c(problems, "grid unexpectedly includes tau=0.50 rows")
  }
  if (length(problems)) {
    stop(paste(c("Dynamic cross-study grid validation failed:", paste0("- ", problems)), collapse = "\n"), call. = FALSE)
  }
  list(
    enabled_roots = nrow(grid_df),
    unique_dataset_cells = length(unique_cells),
    scenarios = scenarios,
    families = families,
    taus = taus,
    fit_sizes = fit_sizes,
    root_kinds = root_kinds,
    priors = priors
  )
}

qdesn_dynamic_crossstudy_enrich_root_spec <- function(root_spec, defaults) {
  pilot_cfg <- defaults$pilot %||% list()
  contract <- defaults$reference_contract %||% list()
  source_root_kind <- as.character(root_spec$source_root_kind %||% pilot_cfg$source_root_kind %||% "dynamic")[1L]
  source_scenario <- as.character(root_spec$source_scenario %||% pilot_cfg$source_scenario %||% NA_character_)[1L]
  source_family <- as.character(root_spec$source_family %||% pilot_cfg$source_family %||% NA_character_)[1L]
  tau <- as.numeric(root_spec$tau %||% pilot_cfg$tau %||% NA_real_)[1L]
  fit_size <- as.integer(root_spec$fit_size %||% pilot_cfg$fit_size %||% NA_integer_)[1L]
  beta_prior_type <- tolower(as.character(root_spec$beta_prior_type %||% pilot_cfg$beta_prior_type %||% "rhs_ns")[1L])
  source_fit_input_dir <- .qdesn_validation_resolve_path(root_spec$source_fit_input_dir %||% pilot_cfg$source_fit_input_dir, must_work = TRUE)
  source_report_root <- .qdesn_validation_resolve_path(root_spec$source_report_root %||% pilot_cfg$source_report_root, must_work = TRUE)
  source_series_wide_path <- .qdesn_validation_resolve_path(root_spec$source_series_wide_path %||% pilot_cfg$source_series_wide_path, must_work = TRUE)
  source_selection_indices_path <- .qdesn_validation_resolve_path(root_spec$source_selection_indices_path %||% pilot_cfg$source_selection_indices_path, must_work = TRUE)
  source_sim_path <- .qdesn_validation_resolve_path(root_spec$source_sim_path %||% pilot_cfg$source_sim_path, must_work = TRUE)
  reservoir_profile <- as.character(root_spec$reservoir_profile %||% pilot_cfg$reservoir_profile %||% "tiny_d1_n8")[1L]
  enabled <- .qdesn_validation_as_flag(root_spec$enabled %||% pilot_cfg$enabled, default = TRUE)
  reference_root_count <- as.integer(root_spec$source_reference_root_count %||% pilot_cfg$source_reference_root_count %||% 1L)[1L]
  reference_priors <- as.character(root_spec$source_reference_priors %||% pilot_cfg$source_reference_priors %||% "default")[1L]
  current_member <- .qdesn_validation_as_flag(root_spec$source_current_rhsns_member %||% FALSE, default = FALSE)
  legacy_member <- .qdesn_validation_as_flag(root_spec$source_legacy_rhs_member %||% FALSE, default = FALSE)

  problems <- character(0)
  if (!identical(source_root_kind, as.character(contract$root_kind %||% "dynamic")[1L])) {
    problems <- c(problems, sprintf("unsupported source_root_kind '%s'", source_root_kind))
  }
  if (!source_scenario %in% as.character(contract$scenarios %||% source_scenario)) {
    problems <- c(problems, sprintf("unsupported source_scenario '%s'", source_scenario))
  }
  if (!source_family %in% as.character(contract$families %||% source_family)) {
    problems <- c(problems, sprintf("unsupported source_family '%s'", source_family))
  }
  if (!is.finite(tau) || !tau %in% as.numeric(contract$taus %||% tau)) {
    problems <- c(problems, sprintf("unsupported tau '%s'", as.character(tau)))
  }
  if (!is.finite(fit_size) || !fit_size %in% as.integer(contract$fit_sizes %||% fit_size)) {
    problems <- c(problems, sprintf("unsupported fit_size '%s'", as.character(fit_size)))
  }
  if (!beta_prior_type %in% c("ridge", "rhs_ns")) {
    problems <- c(problems, sprintf("unsupported beta_prior_type '%s'", beta_prior_type))
  }
  if (!is.finite(reference_root_count) || reference_root_count < 1L) {
    problems <- c(problems, "source_reference_root_count must be >= 1")
  }
  if (length(problems)) {
    stop(paste(c("Dynamic cross-study root spec invalid:", paste0("- ", problems)), collapse = "\n"), call. = FALSE)
  }

  out <- list(
    source_root_kind = source_root_kind,
    source_scenario = source_scenario,
    source_family = source_family,
    tau = tau,
    fit_size = fit_size,
    beta_prior_type = beta_prior_type,
    source_fit_input_dir = source_fit_input_dir,
    source_report_root = source_report_root,
    source_series_wide_path = source_series_wide_path,
    source_selection_indices_path = source_selection_indices_path,
    source_sim_path = source_sim_path,
    source_reference_root_count = reference_root_count,
    source_reference_priors = reference_priors,
    source_current_rhsns_member = current_member,
    source_legacy_rhs_member = legacy_member,
    reservoir_profile = reservoir_profile,
    enabled = enabled
  )
  out$dataset_cell_id <- as.character(root_spec$dataset_cell_id %||%
    sprintf(
      "dynamic__%s__%s__tau_%s__lasttt_%s",
      source_scenario,
      source_family,
      .qdesn_dynamic_crossstudy_prob_label(tau),
      fit_size
    ))[1L]
  out$scenario <- source_scenario
  out$seed <- as.integer(root_spec$seed %||% ((defaults$reservoir_profiles %||% list())[[reservoir_profile]]$seed %||% 123L))[1L]
  out$root_id <- as.character(root_spec$root_id %||% qdesn_dynamic_crossstudy_build_root_id(out))[1L]
  out
}

qdesn_dynamic_crossstudy_stage_dataset <- function(root_spec, root_dir, defaults) {
  series_df <- utils::read.csv(root_spec$source_series_wide_path, stringsAsFactors = FALSE)
  if (!nrow(series_df)) {
    stop(sprintf("Dynamic source series_wide.csv is empty: %s", root_spec$source_series_wide_path), call. = FALSE)
  }
  y <- as.numeric(series_df$y %||% numeric(0))
  if (length(y) != as.integer(root_spec$fit_size)) {
    stop(sprintf(
      "Dynamic source dataset length mismatch for %s: expected fit_size=%d, got y=%d.",
      root_spec$root_id,
      as.integer(root_spec$fit_size),
      length(y)
    ), call. = FALSE)
  }
  q_true <- if ("q_target" %in% names(series_df)) {
    as.numeric(series_df$q_target)
  } else {
    sim_obj <- readRDS(root_spec$source_sim_path)
    q_mat <- as.matrix(sim_obj$q %||% matrix(numeric(0), 0L, 0L))
    if (!nrow(q_mat)) stop(sprintf("Dynamic source sim object missing q matrix: %s", root_spec$source_sim_path), call. = FALSE)
    as.numeric(q_mat[, 1L])
  }
  if (length(q_true) != length(y)) {
    stop(sprintf("q_true length mismatch for %s.", root_spec$root_id), call. = FALSE)
  }
  selection_df <- utils::read.csv(root_spec$source_selection_indices_path, stringsAsFactors = FALSE)
  source_index <- if (nrow(selection_df) == length(y) && "source_index" %in% names(selection_df)) {
    as.integer(selection_df$source_index)
  } else {
    rep(NA_integer_, length(y))
  }
  mu <- if ("mu" %in% names(series_df)) as.numeric(series_df$mu) else rep(NA_real_, length(y))

  data_dir <- file.path(root_dir, "data")
  .qdesn_validation_dir_create(data_dir)
  obs_path <- file.path(data_dir, "observed.csv")
  q_true_path <- file.path(data_dir, "q_true.csv")
  .qdesn_validation_write_df(data.frame(y = y, stringsAsFactors = FALSE), obs_path)
  .qdesn_validation_write_df(
    data.frame(
      t = seq_along(y),
      source_index = source_index,
      q_true = q_true,
      y = y,
      mu = mu,
      stringsAsFactors = FALSE
    ),
    q_true_path
  )
  .qdesn_validation_write_json(file.path(data_dir, "source_metadata.json"), list(
    root_id = root_spec$root_id,
    dataset_cell_id = root_spec$dataset_cell_id,
    source_root_kind = root_spec$source_root_kind,
    source_scenario = root_spec$source_scenario,
    source_family = root_spec$source_family,
    tau = as.numeric(root_spec$tau),
    fit_size = as.integer(root_spec$fit_size),
    source_fit_input_dir = root_spec$source_fit_input_dir,
    source_report_root = root_spec$source_report_root,
    source_series_wide_path = root_spec$source_series_wide_path,
    source_selection_indices_path = root_spec$source_selection_indices_path,
    source_sim_path = root_spec$source_sim_path,
    source_reference_root_count = as.integer(root_spec$source_reference_root_count),
    source_reference_priors = root_spec$source_reference_priors,
    generated_at = as.character(Sys.time())
  ))
  list(
    observed_path = obs_path,
    q_true_path = q_true_path,
    q_true = q_true,
    y = y,
    x_cols = character(0),
    n_obs = length(y)
  )
}

.qdesn_dynamic_crossstudy_root_summary <- function(root_spec,
                                                   fit_summary,
                                                   pairwise_vb_vs_mcmc,
                                                   model_pair_summary,
                                                   root_status) {
  out <- .qdesn_static_crossstudy_root_summary(
    root_spec = root_spec,
    fit_summary = fit_summary,
    pairwise_vb_vs_mcmc = pairwise_vb_vs_mcmc,
    model_pair_summary = model_pair_summary,
    root_status = root_status
  )
  out$scenario <- root_spec$scenario
  out[, c(
    "root_id", "dataset_cell_id", "scenario", "root_kind", "family", "tau", "fit_size", "prior",
    setdiff(names(out), c("root_id", "dataset_cell_id", "scenario", "root_kind", "family", "tau", "fit_size", "prior"))
  ), drop = FALSE]
}

qdesn_dynamic_crossstudy_run_root <- function(root_spec,
                                              defaults,
                                              output_root,
                                              create_plots = FALSE,
                                              verbose = TRUE) {
  root_dir <- file.path(output_root, root_spec$root_id)
  if (dir.exists(root_dir) && length(list.files(root_dir, all.files = TRUE, no.. = TRUE)) > 0L) {
    stop(sprintf("Dynamic cross-study root already exists and is not empty: %s", root_dir), call. = FALSE)
  }
  for (d in c("manifest", "config", "data", "fits", "tables", "plots")) {
    .qdesn_validation_dir_create(file.path(root_dir, d))
  }
  .qdesn_validation_write_lines(file.path(root_dir, "manifest", "root_status.txt"), "RUNNING")
  .qdesn_validation_write_json(file.path(root_dir, "manifest", "root_manifest.json"), list(
    root_id = root_spec$root_id,
    dataset_cell_id = root_spec$dataset_cell_id,
    source_root_kind = root_spec$source_root_kind,
    source_scenario = root_spec$source_scenario,
    source_family = root_spec$source_family,
    scenario = root_spec$scenario,
    tau = as.numeric(root_spec$tau),
    fit_size = as.integer(root_spec$fit_size),
    beta_prior_type = root_spec$beta_prior_type,
    source_fit_input_dir = root_spec$source_fit_input_dir,
    source_report_root = root_spec$source_report_root,
    source_series_wide_path = root_spec$source_series_wide_path,
    source_selection_indices_path = root_spec$source_selection_indices_path,
    source_sim_path = root_spec$source_sim_path,
    source_reference_root_count = as.integer(root_spec$source_reference_root_count),
    source_reference_priors = root_spec$source_reference_priors,
    reservoir_profile = root_spec$reservoir_profile,
    seed = as.integer(root_spec$seed),
    git_sha = .qdesn_validation_git_sha(),
    started_at = as.character(Sys.time())
  ))

  staged_data <- qdesn_dynamic_crossstudy_stage_dataset(root_spec, root_dir, defaults)
  fit_rows <- list()
  progress_rows <- list()
  for (likelihood_family in c("exal", "al")) {
    for (method in c("vb", "mcmc")) {
      if (isTRUE(verbose)) {
        message(sprintf(
          "[qdesn_dynamic_crossstudy_run_root] %s | %s | %s",
          root_spec$root_id,
          likelihood_family,
          method
        ))
      }
      res <- .qdesn_static_crossstudy_run_one_fit(
        root_spec = root_spec,
        defaults = defaults,
        staged_data = staged_data,
        root_dir = root_dir,
        method = method,
        likelihood_family = likelihood_family
      )
      fit_rows[[length(fit_rows) + 1L]] <- res$fit_summary
      if (nrow(res$progress_trace)) {
        progress_rows[[length(progress_rows) + 1L]] <- res$progress_trace
      }
    }
  }

  fit_summary <- .qdesn_validation_bind_rows(fit_rows)
  pairwise_vb_vs_mcmc <- .qdesn_static_crossstudy_algorithm_pair_summary(fit_summary, root_spec)
  model_pair_summary <- .qdesn_static_crossstudy_model_pair_summary(fit_summary, root_spec)
  status_vec <- if ("status" %in% names(fit_summary)) as.character(fit_summary$status) else character(0)
  status_vec[is.na(status_vec) | !nzchar(status_vec)] <- "FAIL"
  root_status <- if (nrow(fit_summary) >= 4L && length(status_vec) >= 4L && all(status_vec == "SUCCESS")) "SUCCESS" else "FAIL"
  root_summary <- .qdesn_dynamic_crossstudy_root_summary(
    root_spec = root_spec,
    fit_summary = fit_summary,
    pairwise_vb_vs_mcmc = pairwise_vb_vs_mcmc,
    model_pair_summary = model_pair_summary,
    root_status = root_status
  )

  .qdesn_validation_write_df(fit_summary, file.path(root_dir, "tables", "fit_summary.csv"))
  .qdesn_validation_write_df(pairwise_vb_vs_mcmc, file.path(root_dir, "tables", "pairwise_vb_vs_mcmc.csv"))
  .qdesn_validation_write_df(model_pair_summary, file.path(root_dir, "tables", "model_pair_signoff.csv"))
  .qdesn_validation_write_df(root_summary, file.path(root_dir, "tables", "root_signoff_summary.csv"))
  if (length(progress_rows)) {
    .qdesn_validation_write_df(.qdesn_validation_bind_rows(progress_rows), file.path(root_dir, "tables", "progress_trace_long.csv"))
  }
  .qdesn_validation_write_lines(file.path(root_dir, "manifest", "root_status.txt"), root_status)
  .qdesn_validation_write_json(file.path(root_dir, "manifest", "runtime_summary.json"), list(
    root_status = root_status,
    finished_at = as.character(Sys.time()),
    root_id = root_spec$root_id
  ))
  list(
    root_dir = root_dir,
    root_status = root_status,
    fit_summary = fit_summary,
    pairwise_vb_vs_mcmc = pairwise_vb_vs_mcmc,
    model_pair_summary = model_pair_summary,
    root_summary = root_summary
  )
}

.qdesn_dynamic_crossstudy_reference_root_group_summary <- function(df) {
  if (!nrow(df)) return(data.frame(stringsAsFactors = FALSE))
  split_idx <- split(
    seq_len(nrow(df)),
    interaction(df[, c("scenario", "root_kind", "family", "tau", "fit_size"), drop = FALSE], drop = TRUE, lex.order = TRUE)
  )
  rows <- lapply(split_idx, function(idx) {
    sub <- df[idx, , drop = FALSE]
    row <- sub[1L, c("scenario", "root_kind", "family", "tau", "fit_size"), drop = FALSE]
    row$n_roots <- nrow(sub)
    row$comparison_eligible_any_rate <- mean(as.logical(sub$root_comparison_eligible_any), na.rm = TRUE)
    row$comparison_eligible_full_rate <- mean(as.logical(sub$root_comparison_eligible_full), na.rm = TRUE)
    row
  })
  .qdesn_validation_bind_rows(rows)
}

.qdesn_dynamic_crossstudy_qdesn_root_group_summary <- function(df) {
  if (!nrow(df)) return(data.frame(stringsAsFactors = FALSE))
  split_idx <- split(
    seq_len(nrow(df)),
    interaction(df[, c("scenario", "root_kind", "family", "tau", "fit_size", "prior"), drop = FALSE], drop = TRUE, lex.order = TRUE)
  )
  rows <- lapply(split_idx, function(idx) {
    sub <- df[idx, , drop = FALSE]
    row <- sub[1L, c("scenario", "root_kind", "family", "tau", "fit_size", "prior"), drop = FALSE]
    row$n_roots <- nrow(sub)
    row$n_success <- sum(as.character(sub$root_status) == "SUCCESS", na.rm = TRUE)
    row$n_fail <- sum(as.character(sub$root_status) == "FAIL", na.rm = TRUE)
    row$root_success_rate <- if (nrow(sub)) row$n_success / nrow(sub) else NA_real_
    row$root_comparison_eligible_any_rate <- mean(as.logical(sub$root_comparison_eligible_any), na.rm = TRUE)
    row$root_comparison_eligible_full_rate <- mean(as.logical(sub$root_comparison_eligible_full), na.rm = TRUE)
    row$method_comparison_eligible_rate_mean <- mean(as.numeric(sub$method_comparison_eligible_rate), na.rm = TRUE)
    row$algorithm_pair_comparison_eligible_rate_mean <- mean(as.numeric(sub$algorithm_pair_comparison_eligible_rate), na.rm = TRUE)
    row$model_pair_comparison_eligible_rate_mean <- mean(as.numeric(sub$model_pair_comparison_eligible_rate), na.rm = TRUE)
    row
  })
  .qdesn_validation_bind_rows(rows)
}

qdesn_dynamic_crossstudy_write_reference_compare <- function(reference_inventory,
                                                             qdesn_tables,
                                                             output_root) {
  .qdesn_validation_dir_create(output_root)
  .qdesn_validation_dir_create(file.path(output_root, "tables"))
  .qdesn_validation_dir_create(file.path(output_root, "manifest"))

  ref_fit_group <- .qdesn_static_crossstudy_group_summary(
    reference_inventory$fit_summary,
    group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "inference", "model"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    extra_numeric = c("runtime_sec")
  )
  q_fit_group <- .qdesn_static_crossstudy_group_summary(
    qdesn_tables$fit_summary,
    group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "prior", "inference", "model"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    extra_numeric = c("runtime_sec", "train_mae", "train_rmse", "holdout_mae", "holdout_rmse")
  )
  ref_pair_group <- .qdesn_static_crossstudy_group_summary(
    reference_inventory$pairwise_vb_vs_mcmc,
    group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "model"),
    grade_col = "algorithm_pair_signoff_grade",
    eligible_col = "algorithm_pair_comparison_eligible",
    extra_numeric = c("runtime_ratio_mcmc_vs_vb")
  )
  q_pair_group <- .qdesn_static_crossstudy_group_summary(
    qdesn_tables$pairwise_vb_vs_mcmc,
    group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "prior", "model"),
    grade_col = "algorithm_pair_signoff_grade",
    eligible_col = "algorithm_pair_comparison_eligible",
    extra_numeric = c("runtime_ratio_mcmc_vs_vb", "mae_delta_mcmc_minus_vb")
  )
  ref_root_group <- .qdesn_dynamic_crossstudy_reference_root_group_summary(reference_inventory$root_signoff_summary)
  q_root_group <- .qdesn_dynamic_crossstudy_qdesn_root_group_summary(qdesn_tables$root_summary)
  surface_delta <- merge(
    q_root_group,
    ref_root_group,
    by = c("scenario", "root_kind", "family", "tau", "fit_size"),
    all.x = TRUE,
    suffixes = c("_qdesn", "_reference"),
    sort = TRUE
  )
  if (nrow(surface_delta)) {
    surface_delta$comparison_eligible_any_rate_delta <- as.numeric(
      surface_delta$root_comparison_eligible_any_rate - surface_delta$comparison_eligible_any_rate
    )
    surface_delta$comparison_eligible_full_rate_delta <- as.numeric(
      surface_delta$root_comparison_eligible_full_rate - surface_delta$comparison_eligible_full_rate
    )
  }

  .qdesn_validation_write_df(reference_inventory$fit_summary, file.path(output_root, "tables", "reference_fit_summary.csv"))
  .qdesn_validation_write_df(reference_inventory$pairwise_vb_vs_mcmc, file.path(output_root, "tables", "reference_pairwise_vb_vs_mcmc.csv"))
  .qdesn_validation_write_df(reference_inventory$model_pair_signoff, file.path(output_root, "tables", "reference_model_pair_signoff.csv"))
  .qdesn_validation_write_df(reference_inventory$root_signoff_summary, file.path(output_root, "tables", "reference_root_signoff_summary.csv"))
  .qdesn_validation_write_df(ref_fit_group, file.path(output_root, "tables", "reference_fit_group_summary.csv"))
  .qdesn_validation_write_df(ref_pair_group, file.path(output_root, "tables", "reference_pair_group_summary.csv"))
  .qdesn_validation_write_df(ref_root_group, file.path(output_root, "tables", "reference_root_group_summary.csv"))
  .qdesn_validation_write_df(q_fit_group, file.path(output_root, "tables", "qdesn_fit_group_summary.csv"))
  .qdesn_validation_write_df(q_pair_group, file.path(output_root, "tables", "qdesn_pair_group_summary.csv"))
  .qdesn_validation_write_df(q_root_group, file.path(output_root, "tables", "qdesn_root_group_summary.csv"))
  .qdesn_validation_write_df(surface_delta, file.path(output_root, "tables", "qdesn_vs_reference_surface_delta.csv"))

  compare_lines <- c(
    "# QDESN Dynamic Cross-Study vs exdqlm Reference",
    "",
    "## Reference Surface",
    sprintf("- reference_root_dirs: `%d`", length(reference_inventory$root_dirs)),
    sprintf("- reference_fit_rows: `%d`", nrow(reference_inventory$fit_summary)),
    sprintf("- reference_pair_rows: `%d`", nrow(reference_inventory$pairwise_vb_vs_mcmc)),
    "",
    "## QDESN Surface",
    sprintf("- qdesn_root_rows: `%d`", nrow(qdesn_tables$root_summary)),
    sprintf("- qdesn_fit_rows: `%d`", nrow(qdesn_tables$fit_summary)),
    sprintf("- qdesn_pair_rows: `%d`", nrow(qdesn_tables$pairwise_vb_vs_mcmc)),
    "",
    "## Important Interpretation Note",
    "",
    "- This comparison is valid on the shared mirrored dynamic dataset surface.",
    "- The exdqlm side remains the canonical dynamic reference.",
    "- The QDESN side preserves the additional prior axis (`ridge` / `rhs_ns`) explicitly.",
    "",
    "## Reference Root Group Summary",
    .qdesn_validation_df_to_markdown(ref_root_group),
    "",
    "## QDESN Root Group Summary",
    .qdesn_validation_df_to_markdown(q_root_group),
    "",
    "## Reference Pair Group Summary",
    .qdesn_validation_df_to_markdown(ref_pair_group),
    "",
    "## QDESN Pair Group Summary",
    .qdesn_validation_df_to_markdown(q_pair_group),
    "",
    "## QDESN vs Reference Surface Delta",
    .qdesn_validation_df_to_markdown(utils::head(surface_delta, 24L))
  )
  .qdesn_validation_write_lines(file.path(output_root, "comparison_summary.md"), compare_lines)
  .qdesn_validation_write_json(file.path(output_root, "manifest", "comparison_manifest.json"), list(
    generated_at = as.character(Sys.time()),
    output_root = normalizePath(output_root, winslash = "/", mustWork = FALSE),
    reference_root_n = length(reference_inventory$root_dirs),
    qdesn_root_n = nrow(qdesn_tables$root_summary)
  ))
  invisible(list(
    reference_fit_group = ref_fit_group,
    reference_pair_group = ref_pair_group,
    reference_root_group = ref_root_group,
    qdesn_fit_group = q_fit_group,
    qdesn_pair_group = q_pair_group,
    qdesn_root_group = q_root_group,
    surface_delta = surface_delta
  ))
}

qdesn_dynamic_crossstudy_collect_campaign <- function(results_root,
                                                      report_root,
                                                      defaults,
                                                      reference_inventory,
                                                      create_plots = FALSE) {
  roots_dir <- file.path(results_root, "roots")
  root_dirs <- if (dir.exists(roots_dir)) sort(list.dirs(roots_dir, recursive = FALSE, full.names = TRUE)) else character(0)
  fit_summary <- .qdesn_static_crossstudy_collect_root_tables(root_dirs, "fit_summary.csv")
  pairwise_vb_vs_mcmc <- .qdesn_static_crossstudy_collect_root_tables(root_dirs, "pairwise_vb_vs_mcmc.csv")
  model_pair_signoff <- .qdesn_static_crossstudy_collect_root_tables(root_dirs, "model_pair_signoff.csv")
  root_summary <- .qdesn_static_crossstudy_collect_root_tables(root_dirs, "root_signoff_summary.csv")
  progress_rows <- .qdesn_static_crossstudy_collect_root_tables(root_dirs, "progress_trace_long.csv")

  .qdesn_validation_dir_create(file.path(report_root, "tables"))
  .qdesn_validation_write_df(root_summary, file.path(report_root, "tables", "campaign_root_signoff_summary.csv"))
  .qdesn_validation_write_df(fit_summary, file.path(report_root, "tables", "campaign_fit_summary.csv"))
  .qdesn_validation_write_df(pairwise_vb_vs_mcmc, file.path(report_root, "tables", "campaign_pairwise_vb_vs_mcmc.csv"))
  .qdesn_validation_write_df(model_pair_signoff, file.path(report_root, "tables", "campaign_model_pair_signoff.csv"))
  if (nrow(progress_rows)) {
    .qdesn_validation_write_df(progress_rows, file.path(report_root, "tables", "campaign_progress_trace_long.csv"))
  }

  fit_group <- .qdesn_static_crossstudy_group_summary(
    fit_summary,
    group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "prior", "inference", "model"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    extra_numeric = c("runtime_sec", "train_mae", "train_rmse", "holdout_mae", "holdout_rmse")
  )
  pair_group <- .qdesn_static_crossstudy_group_summary(
    pairwise_vb_vs_mcmc,
    group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "prior", "model"),
    grade_col = "algorithm_pair_signoff_grade",
    eligible_col = "algorithm_pair_comparison_eligible",
    extra_numeric = c("runtime_ratio_mcmc_vs_vb", "mae_delta_mcmc_minus_vb")
  )
  model_group <- .qdesn_static_crossstudy_group_summary(
    model_pair_signoff,
    group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "prior", "inference"),
    grade_col = "pair_signoff_grade",
    eligible_col = "pair_comparison_eligible",
    extra_numeric = c("train_mae_delta_extended_minus_baseline")
  )
  root_status_mix <- if (nrow(root_summary)) {
    .qdesn_static_crossstudy_count_table_df(as.character(root_summary$root_status), "root_status")
  } else {
    data.frame(stringsAsFactors = FALSE)
  }
  fit_signoff_mix <- if (nrow(fit_summary)) {
    as.data.frame(table(
      inference = as.character(fit_summary$inference),
      model = as.character(fit_summary$model),
      signoff_grade = as.character(fit_summary$signoff_grade)
    ), stringsAsFactors = FALSE)
  } else {
    data.frame(stringsAsFactors = FALSE)
  }
  pair_signoff_mix <- if (nrow(pairwise_vb_vs_mcmc)) {
    as.data.frame(table(
      model = as.character(pairwise_vb_vs_mcmc$model),
      algorithm_pair_signoff_grade = as.character(pairwise_vb_vs_mcmc$algorithm_pair_signoff_grade)
    ), stringsAsFactors = FALSE)
  } else {
    data.frame(stringsAsFactors = FALSE)
  }

  .qdesn_validation_write_df(fit_group, file.path(report_root, "tables", "campaign_fit_group_summary.csv"))
  .qdesn_validation_write_df(pair_group, file.path(report_root, "tables", "campaign_pair_group_summary.csv"))
  .qdesn_validation_write_df(model_group, file.path(report_root, "tables", "campaign_model_group_summary.csv"))
  .qdesn_validation_write_df(root_status_mix, file.path(report_root, "tables", "campaign_root_status_mix.csv"))
  .qdesn_validation_write_df(fit_signoff_mix, file.path(report_root, "tables", "campaign_fit_signoff_mix.csv"))
  .qdesn_validation_write_df(pair_signoff_mix, file.path(report_root, "tables", "campaign_pair_signoff_mix.csv"))

  compare_root <- file.path(report_root, "comparison_vs_reference")
  compare_obj <- qdesn_dynamic_crossstudy_write_reference_compare(
    reference_inventory = reference_inventory,
    qdesn_tables = list(
      fit_summary = fit_summary,
      pairwise_vb_vs_mcmc = pairwise_vb_vs_mcmc,
      model_pair_signoff = model_pair_signoff,
      root_summary = root_summary
    ),
    output_root = compare_root
  )

  recommendation <- if (nrow(root_summary) && all(as.character(root_summary$root_status) == "SUCCESS") &&
      nrow(fit_summary) && !any(as.character(fit_summary$signoff_grade) == "FAIL")) {
    "COMPARISON_READY_QDESN_DYNAMIC_EXDQLM_COMPLETE"
  } else if (nrow(root_summary) && all(as.character(root_summary$root_status) == "SUCCESS")) {
    "COMPARISON_READY_WITH_DOCUMENTED_DYNAMIC_FAIL_BAND"
  } else {
    "HOLD_QDESN_DYNAMIC_EXDQLM_WITH_GAPS"
  }

  summary_lines <- c(
    "# QDESN Dynamic exdqlm Cross-Study Campaign Summary",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- results_root: `%s`", normalizePath(results_root, winslash = "/", mustWork = FALSE)),
    sprintf("- report_root: `%s`", normalizePath(report_root, winslash = "/", mustWork = FALSE)),
    sprintf("- recommendation: `%s`", recommendation),
    "",
    "## Root Status Mix",
    .qdesn_validation_df_to_markdown(root_status_mix),
    "",
    "## Fit Signoff Mix",
    .qdesn_validation_df_to_markdown(fit_signoff_mix),
    "",
    "## Algorithm Pair Signoff Mix",
    .qdesn_validation_df_to_markdown(pair_signoff_mix),
    "",
    "## Fit Group Summary",
    .qdesn_validation_df_to_markdown(utils::head(fit_group, 24L)),
    "",
    "## Pair Group Summary",
    .qdesn_validation_df_to_markdown(utils::head(pair_group, 24L)),
    "",
    "## Model Group Summary",
    .qdesn_validation_df_to_markdown(utils::head(model_group, 24L)),
    "",
    sprintf("- comparison_root: `%s`", compare_root)
  )
  .qdesn_validation_write_lines(file.path(report_root, "summary", "qdesn_dynamic_crossstudy_summary.md"), summary_lines)
  .qdesn_validation_write_json(file.path(report_root, "manifest", "campaign_summary_manifest.json"), list(
    generated_at = as.character(Sys.time()),
    results_root = normalizePath(results_root, winslash = "/", mustWork = FALSE),
    report_root = normalizePath(report_root, winslash = "/", mustWork = FALSE),
    recommendation = recommendation,
    n_roots = nrow(root_summary),
    n_fits = nrow(fit_summary)
  ))

  invisible(list(
    root_summary = root_summary,
    fit_summary = fit_summary,
    pairwise_vb_vs_mcmc = pairwise_vb_vs_mcmc,
    model_pair_signoff = model_pair_signoff,
    fit_group = fit_group,
    pair_group = pair_group,
    model_group = model_group,
    compare = compare_obj,
    recommendation = recommendation
  ))
}

qdesn_dynamic_crossstudy_run_campaign <- function(grid = NULL,
                                                  defaults = NULL,
                                                  grid_path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_grid.csv"),
                                                  defaults_path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_defaults.yaml"),
                                                  results_root = NULL,
                                                  report_root = NULL,
                                                  verbose = TRUE,
                                                  workers = NULL,
                                                  create_plots = FALSE,
                                                  reference_inventory = NULL) {
  defaults <- defaults %||% qdesn_dynamic_crossstudy_load_defaults(defaults_path)
  grid <- grid %||% qdesn_dynamic_crossstudy_load_grid(grid_path)
  campaign_cfg <- defaults$campaign %||% list()
  runtime_cfg <- defaults$runtime %||% list()
  workers <- as.integer(workers %||% runtime_cfg$campaign_workers %||% runtime_cfg$workers %||% 1L)[1L]
  if (!is.finite(workers) || workers < 1L) workers <- 1L

  results_root <- results_root %||% .qdesn_validation_resolve_path(
    campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_validation"),
    must_work = FALSE
  )
  report_root <- report_root %||% .qdesn_validation_resolve_path(
    campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_validation"),
    must_work = FALSE
  )
  timestamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  run_stub <- sprintf("%s__git-%s", timestamp, .qdesn_validation_git_sha() %||% "unknown")
  results_run_root <- file.path(results_root, run_stub)
  report_run_root <- file.path(report_root, run_stub)
  for (d in c(results_run_root, file.path(results_run_root, "roots"), report_run_root, file.path(report_run_root, "tables"), file.path(report_run_root, "summary"), file.path(report_run_root, "plots"), file.path(report_run_root, "manifest"))) {
    .qdesn_validation_dir_create(d)
  }
  .qdesn_validation_write_json(file.path(report_run_root, "manifest", "campaign_manifest.json"), list(
    campaign_name = campaign_cfg$name %||% "qdesn_dynamic_exdqlm_crossstudy_validation",
    started_at = as.character(Sys.time()),
    results_root = results_run_root,
    report_root = report_run_root,
    grid_path = grid_path,
    defaults_path = defaults_path,
    git_sha = .qdesn_validation_git_sha(),
    workers = workers
  ))

  if (is.null(reference_inventory)) {
    reference_cfg <- defaults$reference %||% list()
    reference_inventory <- qdesn_dynamic_crossstudy_collect_reference_inventory(
      reference_root = .qdesn_validation_resolve_path(reference_cfg$dynamic_root, must_work = TRUE)
    )
  }

  targets <- list()
  for (i in seq_len(nrow(grid))) {
    root_spec <- qdesn_dynamic_crossstudy_enrich_root_spec(as.list(grid[i, , drop = FALSE]), defaults)
    if (!isTRUE(root_spec$enabled)) next
    targets[[length(targets) + 1L]] <- root_spec
  }
  n_targets <- length(targets)
  run_one <- function(root_spec, seq_id, n_total) {
    if (isTRUE(verbose)) {
      message(sprintf("[qdesn_dynamic_crossstudy_run_campaign] root %d/%d | %s", seq_id, n_total, root_spec$root_id))
    }
    res <- tryCatch(
      qdesn_dynamic_crossstudy_run_root(
        root_spec = root_spec,
        defaults = defaults,
        output_root = file.path(results_run_root, "roots"),
        create_plots = create_plots,
        verbose = verbose
      ),
      error = function(e) {
        root_status_path <- file.path(results_run_root, "roots", root_spec$root_id, "manifest", "root_status.txt")
        root_error_path <- file.path(results_run_root, "roots", root_spec$root_id, "manifest", "root_error.txt")
        if (file.exists(root_status_path)) {
          .qdesn_validation_write_lines(root_status_path, "FAIL")
        }
        .qdesn_validation_write_lines(root_error_path, conditionMessage(e))
        data.frame(
          root_id = root_spec$root_id,
          dataset_cell_id = root_spec$dataset_cell_id,
          scenario = root_spec$scenario,
          root_kind = root_spec$source_root_kind,
          family = root_spec$source_family,
          tau = as.numeric(root_spec$tau),
          fit_size = as.integer(root_spec$fit_size),
          prior = root_spec$beta_prior_type,
          root_status = "FAIL",
          error_message = conditionMessage(e),
          stringsAsFactors = FALSE
        )
      }
    )
    if (is.data.frame(res)) return(res)
    out <- res$root_summary
    out$error_message <- ""
    out
  }

  status_rows <- list()
  if (workers > 1L && n_targets > 1L) {
    repo_root <- .qdesn_validation_repo_root()
    cl <- parallel::makePSOCKcluster(workers, outfile = "")
    on.exit(parallel::stopCluster(cl), add = TRUE)
    parallel::clusterExport(
      cl,
      varlist = c(
        "repo_root",
        "targets",
        "defaults",
        "results_run_root",
        "create_plots",
        "verbose",
        "n_targets"
      ),
      envir = environment()
    )
    parallel::clusterEvalQ(cl, {
      suppressPackageStartupMessages(library(pkgload))
      pkgload::load_all(repo_root, quiet = TRUE)
      NULL
    })
    status_rows <- parallel::parLapply(
      cl,
      X = seq_len(n_targets),
      fun = function(j) {
        root_spec <- targets[[j]]
        tryCatch(
          {
            res <- exdqlm:::qdesn_dynamic_crossstudy_run_root(
              root_spec = root_spec,
              defaults = defaults,
              output_root = file.path(results_run_root, "roots"),
              create_plots = create_plots,
              verbose = verbose
            )
            out <- res$root_summary
            out$error_message <- ""
            out
          },
          error = function(e) {
            root_status_path <- file.path(results_run_root, "roots", root_spec$root_id, "manifest", "root_status.txt")
            root_error_path <- file.path(results_run_root, "roots", root_spec$root_id, "manifest", "root_error.txt")
            if (file.exists(root_status_path)) {
              exdqlm:::.qdesn_validation_write_lines(root_status_path, "FAIL")
            }
            exdqlm:::.qdesn_validation_write_lines(root_error_path, conditionMessage(e))
            data.frame(
              root_id = root_spec$root_id,
              dataset_cell_id = root_spec$dataset_cell_id,
              scenario = root_spec$scenario,
              root_kind = root_spec$source_root_kind,
              family = root_spec$source_family,
              tau = as.numeric(root_spec$tau),
              fit_size = as.integer(root_spec$fit_size),
              prior = root_spec$beta_prior_type,
              root_status = "FAIL",
              error_message = conditionMessage(e),
              stringsAsFactors = FALSE
            )
          }
        )
      }
    )
    .qdesn_validation_write_df(.qdesn_validation_bind_rows(status_rows), file.path(report_run_root, "tables", "campaign_progress.csv"))
  } else {
    for (j in seq_len(n_targets)) {
      row <- run_one(targets[[j]], j, n_targets)
      status_rows[[length(status_rows) + 1L]] <- row
      .qdesn_validation_write_df(.qdesn_validation_bind_rows(status_rows), file.path(report_run_root, "tables", "campaign_progress.csv"))
      qdesn_dynamic_crossstudy_collect_campaign(
        results_root = results_run_root,
        report_root = report_run_root,
        defaults = defaults,
        reference_inventory = reference_inventory,
        create_plots = create_plots
      )
    }
  }

  final <- qdesn_dynamic_crossstudy_collect_campaign(
    results_root = results_run_root,
    report_root = report_run_root,
    defaults = defaults,
    reference_inventory = reference_inventory,
    create_plots = create_plots
  )
  .qdesn_validation_write_json(file.path(report_run_root, "manifest", "campaign_completed.json"), list(
    finished_at = as.character(Sys.time()),
    results_root = results_run_root,
    report_root = report_run_root,
    n_roots = nrow(final$root_summary),
    n_fits = nrow(final$fit_summary),
    recommendation = final$recommendation
  ))
  invisible(list(
    results_root = results_run_root,
    report_root = report_run_root,
    summary = final
  ))
}

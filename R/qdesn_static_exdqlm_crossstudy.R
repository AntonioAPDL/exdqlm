`%||%` <- function(a, b) if (is.null(a)) b else a

.qdesn_static_bool <- function(x, default = FALSE) {
  out <- as.logical(x)
  out[is.na(out)] <- default
  out
}

.qdesn_static_crossstudy_count_table_df <- function(x, name) {
  if (!length(x)) return(data.frame(stringsAsFactors = FALSE))
  out <- as.data.frame(table(value = as.character(x)), stringsAsFactors = FALSE)
  names(out) <- c(name, "n")
  out[order(out[[name]]), , drop = FALSE]
}

qdesn_static_crossstudy_load_defaults <- function(path = file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_defaults.yaml"),
                                                  repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- yaml::read_yaml(yaml_path)
  if (!is.list(out)) {
    stop("Static cross-study defaults YAML must parse to a list.", call. = FALSE)
  }
  out
}

qdesn_static_crossstudy_load_grid <- function(path = file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_grid.csv"),
                                              repo_root = NULL) {
  grid_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- utils::read.csv(grid_path, stringsAsFactors = FALSE)
  if (!nrow(out)) {
    stop("Static cross-study grid CSV is empty.", call. = FALSE)
  }
  out
}

.qdesn_static_crossstudy_prob_label <- function(x) {
  gsub("\\.", "p", format(as.numeric(x)[1L], nsmall = 2, digits = 4, trim = TRUE))
}

qdesn_static_crossstudy_build_grid_from_reference <- function(defaults) {
  reference_cfg <- defaults$reference %||% list()
  paper_root <- .qdesn_validation_resolve_path(reference_cfg$paper_root, must_work = TRUE)
  shrink_root <- .qdesn_validation_resolve_path(reference_cfg$shrink_root, must_work = TRUE)
  pilot_cfg <- defaults$pilot %||% list()

  collect_cells <- function(base_root) {
    signoff_paths <- list.files(base_root, pattern = "root_signoff_summary.csv", recursive = TRUE, full.names = TRUE)
    .qdesn_validation_bind_rows(lapply(signoff_paths, function(path) {
      root_dir <- dirname(dirname(path))
      fit_input_dir <- dirname(root_dir)
      meta <- utils::read.csv(path, stringsAsFactors = FALSE)
      if (!nrow(meta)) return(NULL)
      data.frame(
        root_id_ref = as.character(meta$root_id[1L]),
        root_kind = as.character(meta$root_kind[1L]),
        family = as.character(meta$family[1L]),
        tau = as.numeric(meta$tau[1L]),
        fit_size = as.integer(meta$fit_size[1L]),
        prior = as.character(meta$prior[1L]),
        source_fit_input_dir = normalizePath(fit_input_dir, winslash = "/", mustWork = TRUE),
        source_sim_path = normalizePath(file.path(fit_input_dir, "sim_output.rds"), winslash = "/", mustWork = TRUE),
        stringsAsFactors = FALSE
      )
    }))
  }

  ref_df <- .qdesn_validation_bind_rows(list(
    collect_cells(paper_root),
    collect_cells(shrink_root)
  ))
  if (!nrow(ref_df)) {
    stop("Reference signoff roots could not be recovered from the exdqlm worktree.", call. = FALSE)
  }
  ref_df <- ref_df[order(ref_df$root_kind, ref_df$family, ref_df$tau, ref_df$fit_size, ref_df$prior), , drop = FALSE]

  key <- paste(ref_df$root_kind, ref_df$family, ref_df$tau, ref_df$fit_size, sep = "||")
  split_rows <- split(seq_len(nrow(ref_df)), key)
  rows <- list()
  for (idx in split_rows) {
    sub <- ref_df[idx, , drop = FALSE]
    root_kind <- as.character(sub$root_kind[1L])
    family <- as.character(sub$family[1L])
    tau <- as.numeric(sub$tau[1L])
    fit_size <- as.integer(sub$fit_size[1L])
    source_reference_priors <- paste(sort(unique(as.character(sub$prior))), collapse = "|")
    source_reference_root_count <- nrow(sub)
    source_current_rhsns_member <- TRUE
    source_legacy_rhs_member <- identical(root_kind, "static_shrink")
    dataset_cell_id <- sprintf(
      "%s__%s__tau_%s__tt_%s",
      root_kind,
      family,
      .qdesn_static_crossstudy_prob_label(tau),
      fit_size
    )
    for (beta_prior_type in c("ridge", "rhs_ns")) {
      rows[[length(rows) + 1L]] <- data.frame(
        enabled = TRUE,
        dataset_cell_id = dataset_cell_id,
        source_root_kind = root_kind,
        source_family = family,
        tau = tau,
        fit_size = fit_size,
        beta_prior_type = beta_prior_type,
        source_fit_input_dir = as.character(sub$source_fit_input_dir[1L]),
        source_sim_path = as.character(sub$source_sim_path[1L]),
        source_reference_root_count = source_reference_root_count,
        source_reference_priors = source_reference_priors,
        source_current_rhsns_member = source_current_rhsns_member,
        source_legacy_rhs_member = source_legacy_rhs_member,
        reservoir_profile = as.character(pilot_cfg$reservoir_profile %||% "tiny_d1_n8"),
        seed = as.integer(pilot_cfg$seed %||% 123L),
        stringsAsFactors = FALSE
      )
    }
  }
  grid_df <- .qdesn_validation_bind_rows(rows)
  grid_df$root_id <- vapply(seq_len(nrow(grid_df)), function(i) {
    qdesn_static_crossstudy_build_root_id(as.list(grid_df[i, , drop = FALSE]))
  }, character(1))
  grid_df[, c(
    "enabled",
    "root_id",
    "dataset_cell_id",
    "source_root_kind",
    "source_family",
    "tau",
    "fit_size",
    "beta_prior_type",
    "source_fit_input_dir",
    "source_sim_path",
    "source_reference_root_count",
    "source_reference_priors",
    "source_current_rhsns_member",
    "source_legacy_rhs_member",
    "reservoir_profile",
    "seed"
  ), drop = FALSE]
}

qdesn_static_crossstudy_validate_reference_inventory <- function(reference_inventory, defaults) {
  contract <- defaults$reference_contract %||% list()
  root_summary <- reference_inventory$root_signoff_summary %||% data.frame(stringsAsFactors = FALSE)
  problems <- character(0)
  if (!nrow(root_summary)) {
    problems <- c(problems, "reference root_signoff_summary inventory is empty")
  } else {
    paper_n <- sum(as.character(root_summary$root_kind) == "static_paper", na.rm = TRUE)
    shrink_n <- sum(as.character(root_summary$root_kind) == "static_shrink", na.rm = TRUE)
    if (!is.null(contract$expected_paper_signoff_roots) &&
        !identical(as.integer(paper_n), as.integer(contract$expected_paper_signoff_roots))) {
      problems <- c(problems, sprintf(
        "expected %d paper signoff roots, found %d",
        as.integer(contract$expected_paper_signoff_roots), as.integer(paper_n)
      ))
    }
    if (!is.null(contract$expected_shrink_signoff_roots) &&
        !identical(as.integer(shrink_n), as.integer(contract$expected_shrink_signoff_roots))) {
      problems <- c(problems, sprintf(
        "expected %d shrink signoff roots, found %d",
        as.integer(contract$expected_shrink_signoff_roots), as.integer(shrink_n)
      ))
    }
    unique_cells <- unique(paste(
      as.character(root_summary$root_kind),
      as.character(root_summary$family),
      as.numeric(root_summary$tau),
      as.integer(root_summary$fit_size),
      sep = "||"
    ))
    if (!is.null(contract$expected_unique_dataset_cells) &&
        !identical(length(unique_cells), as.integer(contract$expected_unique_dataset_cells))) {
      problems <- c(problems, sprintf(
        "expected %d unique dataset cells, found %d",
        as.integer(contract$expected_unique_dataset_cells), length(unique_cells)
      ))
    }
  }
  if (length(problems)) {
    stop(paste(c("Reference inventory validation failed:", paste0("- ", problems)), collapse = "\n"), call. = FALSE)
  }
  list(
    reference_root_dirs_n = length(reference_inventory$root_dirs),
    reference_paper_signoff_roots = sum(as.character(root_summary$root_kind) == "static_paper", na.rm = TRUE),
    reference_shrink_signoff_roots = sum(as.character(root_summary$root_kind) == "static_shrink", na.rm = TRUE),
    reference_unique_dataset_cells = length(unique(paste(
      as.character(root_summary$root_kind),
      as.character(root_summary$family),
      as.numeric(root_summary$tau),
      as.integer(root_summary$fit_size),
      sep = "||"
    )))
  )
}

qdesn_static_crossstudy_validate_grid <- function(grid_df, defaults) {
  contract <- defaults$reference_contract %||% list()
  problems <- character(0)
  enabled <- if ("enabled" %in% names(grid_df)) {
    tolower(as.character(grid_df$enabled)) %in% c("true", "1", "t", "yes", "y")
  } else {
    rep(TRUE, nrow(grid_df))
  }
  grid_df <- grid_df[enabled, , drop = FALSE]
  if (!nrow(grid_df)) {
    stop("Cross-study grid has no enabled rows.", call. = FALSE)
  }
  families <- sort(unique(as.character(grid_df$source_family)))
  taus <- sort(unique(as.numeric(grid_df$tau)))
  fit_sizes <- sort(unique(as.integer(grid_df$fit_size)))
  root_kinds <- sort(unique(as.character(grid_df$source_root_kind)))
  priors <- sort(unique(as.character(grid_df$beta_prior_type)))
  unique_cells <- unique(as.character(grid_df$dataset_cell_id))

  if (!identical(families, sort(as.character(contract$families %||% families)))) {
    problems <- c(problems, sprintf("family set mismatch: %s", paste(families, collapse = ", ")))
  }
  if (!identical(as.numeric(taus), sort(as.numeric(contract$taus %||% taus)))) {
    problems <- c(problems, sprintf("tau set mismatch: %s", paste(taus, collapse = ", ")))
  }
  if (!identical(as.integer(fit_sizes), sort(as.integer(contract$fit_sizes %||% fit_sizes)))) {
    problems <- c(problems, sprintf("fit_size set mismatch: %s", paste(fit_sizes, collapse = ", ")))
  }
  if (!identical(root_kinds, sort(as.character(contract$root_kinds %||% root_kinds)))) {
    problems <- c(problems, sprintf("root_kind set mismatch: %s", paste(root_kinds, collapse = ", ")))
  }
  if (!identical(priors, c("rhs_ns", "ridge"))) {
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
    stop(paste(c("Cross-study grid validation failed:", paste0("- ", problems)), collapse = "\n"), call. = FALSE)
  }
  list(
    enabled_roots = nrow(grid_df),
    unique_dataset_cells = length(unique_cells),
    families = families,
    taus = taus,
    fit_sizes = fit_sizes,
    root_kinds = root_kinds,
    priors = priors
  )
}

qdesn_static_crossstudy_build_root_id <- function(root_spec) {
  sprintf(
    "root__%s__%s__tau_%s__tt_%s__qdesn_%s",
    as.character(root_spec$source_root_kind)[1L],
    as.character(root_spec$source_family)[1L],
    .qdesn_static_crossstudy_prob_label(root_spec$tau),
    as.integer(root_spec$fit_size)[1L],
    as.character(root_spec$beta_prior_type)[1L]
  )
}

qdesn_static_crossstudy_enrich_root_spec <- function(root_spec, defaults) {
  pilot_cfg <- defaults$pilot %||% list()
  source_root_kind <- as.character(root_spec$source_root_kind %||% pilot_cfg$source_root_kind %||% NA_character_)[1L]
  source_family <- as.character(root_spec$source_family %||% pilot_cfg$source_family %||% NA_character_)[1L]
  tau <- as.numeric(root_spec$tau %||% pilot_cfg$tau %||% NA_real_)[1L]
  fit_size <- as.integer(root_spec$fit_size %||% pilot_cfg$fit_size %||% NA_integer_)[1L]
  beta_prior_type <- tolower(as.character(root_spec$beta_prior_type %||% pilot_cfg$beta_prior_type %||% "rhs_ns")[1L])
  source_sim_path <- .qdesn_validation_resolve_path(root_spec$source_sim_path %||% pilot_cfg$source_sim_path, must_work = TRUE)
  source_fit_input_dir <- .qdesn_validation_resolve_path(root_spec$source_fit_input_dir %||% pilot_cfg$source_fit_input_dir, must_work = TRUE)
  reservoir_profile <- as.character(root_spec$reservoir_profile %||% pilot_cfg$reservoir_profile %||% "tiny_d1_n8")[1L]
  enabled <- .qdesn_validation_as_flag(root_spec$enabled %||% pilot_cfg$enabled, default = TRUE)
  reference_root_count <- as.integer(root_spec$source_reference_root_count %||% pilot_cfg$source_reference_root_count %||% NA_integer_)[1L]
  reference_priors <- as.character(root_spec$source_reference_priors %||% pilot_cfg$source_reference_priors %||% NA_character_)[1L]
  current_member <- .qdesn_validation_as_flag(
    root_spec$source_current_rhsns_member %||% pilot_cfg$source_current_rhsns_member,
    default = TRUE
  )
  legacy_member <- .qdesn_validation_as_flag(
    root_spec$source_legacy_rhs_member %||% pilot_cfg$source_legacy_rhs_member,
    default = FALSE
  )

  problems <- character(0)
  if (!source_root_kind %in% c("static_paper", "static_shrink")) {
    problems <- c(problems, sprintf("unsupported source_root_kind '%s'", source_root_kind))
  }
  if (!source_family %in% c("gausmix", "laplace", "normal")) {
    problems <- c(problems, sprintf("unsupported source_family '%s'", source_family))
  }
  if (!is.finite(tau) || !tau %in% c(0.05, 0.25, 0.95)) {
    problems <- c(problems, sprintf("unsupported tau '%s'", as.character(tau)))
  }
  if (!is.finite(fit_size) || !fit_size %in% c(100L, 1000L)) {
    problems <- c(problems, sprintf("unsupported fit_size '%s'", as.character(fit_size)))
  }
  if (!beta_prior_type %in% c("ridge", "rhs_ns")) {
    problems <- c(problems, sprintf("unsupported beta_prior_type '%s'", beta_prior_type))
  }
  if (!is.finite(reference_root_count) || reference_root_count < 1L) {
    problems <- c(problems, "source_reference_root_count must be >= 1")
  }
  if (length(problems)) {
    stop(paste(c("Static cross-study root spec invalid:", paste0("- ", problems)), collapse = "\n"), call. = FALSE)
  }

  out <- list(
    source_root_kind = source_root_kind,
    source_family = source_family,
    tau = tau,
    fit_size = fit_size,
    beta_prior_type = beta_prior_type,
    source_sim_path = source_sim_path,
    source_fit_input_dir = source_fit_input_dir,
    source_reference_root_count = reference_root_count,
    source_reference_priors = reference_priors,
    source_current_rhsns_member = current_member,
    source_legacy_rhs_member = legacy_member,
    reservoir_profile = reservoir_profile,
    enabled = enabled
  )
  out$dataset_cell_id <- as.character(
    root_spec$dataset_cell_id %||%
      sprintf(
        "%s__%s__tau_%s__tt_%s",
        source_root_kind,
        source_family,
        .qdesn_static_crossstudy_prob_label(tau),
        fit_size
      )
  )[1L]
  out$scenario <- as.character(root_spec$scenario %||% source_root_kind)[1L]
  out$seed <- as.integer(root_spec$seed %||% ((defaults$reservoir_profiles %||% list())[[reservoir_profile]]$seed %||% 123L))[1L]
  out$root_id <- as.character(root_spec$root_id %||% qdesn_static_crossstudy_build_root_id(out))[1L]
  out
}

.qdesn_static_crossstudy_reservoir_cfg <- function(defaults, profile) {
  cfg <- (defaults$reservoir_profiles %||% list())[[profile]]
  if (is.null(cfg)) {
    stop(sprintf("Reservoir profile '%s' not found in static cross-study defaults.", profile), call. = FALSE)
  }
  cfg$D <- as.integer(cfg[["D", exact = TRUE]] %||% 1L)[1L]
  cfg[["n"]] <- as.integer(unlist(cfg[["n", exact = TRUE]] %||% integer(0), use.names = FALSE))
  cfg$n_tilde <- as.integer(unlist(cfg[["n_tilde", exact = TRUE]] %||% integer(0), use.names = FALSE))
  cfg$m <- as.integer(cfg[["m", exact = TRUE]] %||% 4L)[1L]
  cfg$washout <- as.integer(cfg[["washout", exact = TRUE]] %||% 4L)[1L]
  cfg
}

qdesn_static_crossstudy_build_pipeline_cfg <- function(root_spec,
                                                       defaults,
                                                       method = c("vb", "mcmc"),
                                                       likelihood_family = c("exal", "al"),
                                                       x_cols = character(0),
                                                       T_use = NULL) {
  method <- match.arg(method)
  likelihood_family <- match.arg(likelihood_family)
  pipeline_cfg <- defaults$pipeline %||% list()
  .qdesn_validation_assert_non_dlm_input(pipeline_cfg)
  infer_cfg <- pipeline_cfg$inference %||% list()
  reservoir_cfg <- .qdesn_static_crossstudy_reservoir_cfg(defaults, root_spec$reservoir_profile)
  external_cfg <- defaults$external_data %||% list()
  preproc_cfg <- defaults$preproc %||% list()
  lags_cfg <- defaults$lags %||% list()
  normalize_column_name <- function(value, default, label) {
    if (is.null(value) || !length(value)) return(default)
    if (is.logical(value)) {
      if (length(value) == 1L && isTRUE(value) && identical(default, "y")) {
        warning(
          sprintf(
            "%s was parsed as logical TRUE; falling back to default column '%s'. Quote the YAML scalar to avoid YAML 1.1 boolean coercion.",
            label,
            default
          ),
          call. = FALSE
        )
        return(default)
      }
      stop(sprintf("%s must be a column name string, not logical.", label), call. = FALSE)
    }
    out <- as.character(value)[1L]
    out <- trimws(out)
    if (!nzchar(out)) return(default)
    out
  }

  T_eff <- as.integer(T_use %||% root_spec$fit_size)[1L]
  if (!is.finite(T_eff) || T_eff < 20L) {
    stop("Static cross-study requires T_use >= 20.", call. = FALSE)
  }
  holdout_n <- as.integer(external_cfg$holdout_n %||% 1L)[1L]
  if (!is.finite(holdout_n) || holdout_n < 1L) holdout_n <- 1L
  if (holdout_n >= T_eff) {
    stop(sprintf("holdout_n=%d is too large for T_use=%d.", holdout_n, T_eff), call. = FALSE)
  }
  n_train <- T_eff - holdout_n

  cfg <- list(
    pipeline = list(
      mode = "real",
      verbose = isTRUE(pipeline_cfg$verbose %||% TRUE)
    ),
    split = list(
      use_last = TRUE,
      T_use = T_eff,
      train_n = n_train
    ),
    p_vec = as.numeric(root_spec$tau),
    columns = list(
      y = normalize_column_name(external_cfg$y_column %||% "y", default = "y", label = "external_data.y_column"),
      x = as.character(x_cols)
    ),
    lags = list(
      m_y = as.integer(lags_cfg$m_y %||% 12L)[1L],
      m_x = as.integer(lags_cfg$m_x %||% 0L)[1L]
    ),
    preproc = list(
      scale_y = isTRUE(preproc_cfg$scale_y %||% TRUE),
      scale_x = isTRUE(preproc_cfg$scale_x %||% TRUE)
    ),
    desn = reservoir_cfg,
    readout = modifyList(list(
      include_input = TRUE,
      reservoir_lags = 1L,
      input_position = "after_reservoir",
      input_mode = "raw_y_lags"
    ), pipeline_cfg$readout %||% list()),
    decomposition = modifyList(list(
      enabled = FALSE
    ), pipeline_cfg$decomposition %||% list()),
    sampling = modifyList(list(nd_draws = 96L, chunk = 48L), pipeline_cfg$sampling %||% list()),
    forecast = modifyList(list(
      mode = "origin",
      horizon = 1L,
      train_last_window = 1L,
      fore_last_window = 1L
    ), pipeline_cfg$forecast %||% list()),
    synthesis = modifyList(list(
      isotonic = FALSE,
      rearrange = FALSE,
      grid_M = 151L,
      n_samp = 96L,
      seed = 321L
    ), pipeline_cfg$synthesis %||% list()),
    diagnostics = modifyList(list(
      calibration = FALSE,
      pit = FALSE,
      scores = TRUE,
      lead_eval = FALSE,
      fan_charts = FALSE,
      plots = FALSE
    ), pipeline_cfg$diagnostics %||% list()),
    cpp = modifyList(list(
      use_postpred = FALSE,
      postpred_omp = FALSE,
      postpred_precompute = FALSE,
      postpred_threads = 1L
    ), pipeline_cfg$cpp %||% list()),
    outputs = modifyList(list(
      save = TRUE,
      keep_draws = FALSE,
      thesis_subset = FALSE
    ), pipeline_cfg$outputs %||% list()),
    inference = list(
      method = method,
      likelihood_family = likelihood_family,
      readout_scale = isTRUE(infer_cfg$readout_scale %||% TRUE)
    )
  )

  if (identical(method, "vb")) {
    cfg$inference$vb <- modifyList(list(), infer_cfg$vb %||% list())
    cfg$inference$vb <- .qdesn_validation_apply_prior_override(cfg$inference$vb, root_spec$beta_prior_type)
    cfg$inference$vb$priors <- modifyList(list(), cfg$inference$vb$priors %||% list())
    cfg$inference$vb$priors$beta <- modifyList(list(type = root_spec$beta_prior_type), cfg$inference$vb$priors$beta %||% list())
    cfg$inference$vb$priors$beta$type <- root_spec$beta_prior_type
  } else {
    cfg$inference$mcmc <- modifyList(list(), infer_cfg$mcmc %||% list())
    cfg$inference$mcmc <- .qdesn_validation_apply_prior_override(cfg$inference$mcmc, root_spec$beta_prior_type)
    cfg$inference$mcmc$priors <- modifyList(list(), cfg$inference$mcmc$priors %||% list())
    cfg$inference$mcmc$priors$beta <- modifyList(list(type = root_spec$beta_prior_type), cfg$inference$mcmc$priors$beta %||% list())
    cfg$inference$mcmc$priors$beta$type <- root_spec$beta_prior_type
  }

  cfg
}

qdesn_static_crossstudy_stage_dataset <- function(root_spec, root_dir, defaults) {
  sim_obj <- readRDS(root_spec$source_sim_path)
  if (!all(c("y", "q", "p", "extras") %in% names(sim_obj))) {
    stop(sprintf("Static cross-study source sim object missing required entries: %s", root_spec$source_sim_path), call. = FALSE)
  }
  y <- as.numeric(sim_obj$y)
  q_mat <- as.matrix(sim_obj$q)
  q_true <- as.numeric(q_mat[, 1L])
  if (length(y) != root_spec$fit_size || length(q_true) != root_spec$fit_size) {
    stop(sprintf(
      "Source dataset length mismatch for %s: expected fit_size=%d, got y=%d q=%d.",
      root_spec$root_id,
      as.integer(root_spec$fit_size),
      length(y),
      length(q_true)
    ), call. = FALSE)
  }
  p_src <- as.numeric(sim_obj$p %||% NA_real_)[1L]
  if (is.finite(p_src) && abs(p_src - as.numeric(root_spec$tau)) > 1e-8) {
    stop(sprintf(
      "Tau mismatch for %s: grid tau=%s but sim_output.rds p=%s.",
      root_spec$root_id,
      as.character(root_spec$tau),
      as.character(p_src)
    ), call. = FALSE)
  }
  X <- sim_obj$extras$X %||% NULL
  if (is.null(X)) {
    stop(sprintf("Static cross-study source sim object is missing extras$X: %s", root_spec$source_sim_path), call. = FALSE)
  }
  X <- as.matrix(X)
  if (nrow(X) != length(y)) {
    stop(sprintf("X row count mismatch for %s: nrow(X)=%d, length(y)=%d.", root_spec$root_id, nrow(X), length(y)), call. = FALSE)
  }

  data_dir <- file.path(root_dir, "data")
  .qdesn_validation_dir_create(data_dir)
  x_names <- colnames(X)
  if (is.null(x_names) || length(x_names) != ncol(X) || any(!nzchar(x_names))) {
    x_names <- sprintf("x%02d", seq_len(ncol(X)))
  }
  df <- data.frame(y = y, X, stringsAsFactors = FALSE)
  names(df) <- c("y", x_names)
  obs_path <- file.path(data_dir, "observed.csv")
  q_true_path <- file.path(data_dir, "q_true.csv")
  .qdesn_validation_write_df(df, obs_path)
  .qdesn_validation_write_df(
    data.frame(t = seq_along(q_true), q_true = q_true, y = y, stringsAsFactors = FALSE),
    q_true_path
  )
  .qdesn_validation_write_json(file.path(data_dir, "source_metadata.json"), list(
    root_id = root_spec$root_id,
    dataset_cell_id = root_spec$dataset_cell_id,
    source_root_kind = root_spec$source_root_kind,
    source_family = root_spec$source_family,
    tau = as.numeric(root_spec$tau),
    fit_size = as.integer(root_spec$fit_size),
    source_sim_path = root_spec$source_sim_path,
    source_fit_input_dir = root_spec$source_fit_input_dir,
    source_reference_root_count = as.integer(root_spec$source_reference_root_count),
    source_reference_priors = root_spec$source_reference_priors,
    source_current_rhsns_member = isTRUE(root_spec$source_current_rhsns_member),
    source_legacy_rhs_member = isTRUE(root_spec$source_legacy_rhs_member),
    x_columns = x_names,
    q_source_probability = p_src,
    generated_at = as.character(Sys.time())
  ))

  list(
    observed_path = obs_path,
    q_true_path = q_true_path,
    q_true = q_true,
    y = y,
    x_cols = x_names,
    n_obs = length(y)
  )
}

.qdesn_static_crossstudy_safe_cor <- function(x, y) {
  keep <- is.finite(x) & is.finite(y)
  if (sum(keep) < 3L) return(NA_real_)
  out <- suppressWarnings(stats::cor(x[keep], y[keep]))
  if (!is.finite(out)) return(NA_real_)
  as.numeric(out)
}

.qdesn_static_crossstudy_eval_metrics <- function(q_pred, q_true) {
  q_pred <- as.numeric(q_pred)
  q_true <- as.numeric(q_true)
  keep <- is.finite(q_pred) & is.finite(q_true)
  if (!any(keep)) {
    return(list(
      n_eval = 0L,
      mae = NA_real_,
      rmse = NA_real_,
      bias = NA_real_,
      corr = NA_real_
    ))
  }
  err <- q_pred[keep] - q_true[keep]
  list(
    n_eval = sum(keep),
    mae = mean(abs(err)),
    rmse = sqrt(mean(err^2)),
    bias = mean(err),
    corr = .qdesn_static_crossstudy_safe_cor(q_pred, q_true)
  )
}

.qdesn_static_crossstudy_collect_metrics_from_summary <- function(summary_obj, q_true_full) {
  fits_fc <- summary_obj$forecast_objects$fits_fc %||% list()
  if (!length(fits_fc)) {
    return(list(
      train = .qdesn_static_crossstudy_eval_metrics(numeric(0), numeric(0)),
      holdout = .qdesn_static_crossstudy_eval_metrics(numeric(0), numeric(0))
    ))
  }
  fit_entry <- fits_fc[[1L]]
  df_pred_tr <- as.data.frame(fit_entry$df_pred_tr %||% data.frame(stringsAsFactors = FALSE), stringsAsFactors = FALSE)
  df_pred_fc <- as.data.frame(fit_entry$df_pred_fc %||% data.frame(stringsAsFactors = FALSE), stringsAsFactors = FALSE)
  keep_idx <- as.integer((fit_entry$fit_train$meta %||% list())$keep_idx %||% integer(0))
  split_n <- as.integer((summary_obj$summary$n_train %||% NA_integer_)[1L])

  if (nrow(df_pred_tr) && length(keep_idx) == nrow(df_pred_tr)) {
    q_true_tr <- q_true_full[keep_idx]
  } else {
    q_true_tr <- rep(NA_real_, nrow(df_pred_tr))
  }
  train_metrics <- .qdesn_static_crossstudy_eval_metrics(df_pred_tr$q_pred %||% numeric(0), q_true_tr)

  holdout_idx <- if (is.finite(split_n) && nrow(df_pred_fc)) {
    seq.int(split_n + 1L, split_n + nrow(df_pred_fc))
  } else {
    integer(0)
  }
  holdout_idx <- holdout_idx[holdout_idx >= 1L & holdout_idx <= length(q_true_full)]
  if (length(holdout_idx) == nrow(df_pred_fc)) {
    q_true_fc <- q_true_full[holdout_idx]
  } else {
    q_true_fc <- rep(NA_real_, nrow(df_pred_fc))
  }
  holdout_metrics <- .qdesn_static_crossstudy_eval_metrics(df_pred_fc$q_pred %||% numeric(0), q_true_fc)

  list(
    train = train_metrics,
    holdout = holdout_metrics
  )
}

.qdesn_static_crossstudy_fit_runtime_row <- function(method_dir) {
  path <- file.path(method_dir, "manifest", "runtime_summary.json")
  if (!file.exists(path)) return(list())
  .qdesn_validation_read_json_if_exists(path) %||% list()
}

.qdesn_static_crossstudy_fit_summary_row <- function(root_spec,
                                                     likelihood_family,
                                                     method,
                                                     health_row,
                                                     metrics,
                                                     signoff_row,
                                                     method_dir) {
  runtime_row <- .qdesn_static_crossstudy_fit_runtime_row(method_dir)
  fit_file <- file.path(method_dir, "models", "forecast_objects.rds")
  runtime_sec <- as.numeric(health_row$fit_runtime_seconds[1L] %||% runtime_row$elapsed_seconds %||% NA_real_)
  sigma_mean <- if (identical(method, "vb")) {
    as.numeric(health_row$vb_sigma_last[1L] %||% NA_real_)
  } else {
    as.numeric(health_row$mcmc_sigma_mean[1L] %||% NA_real_)
  }
  gamma_mean <- if (identical(method, "vb")) {
    as.numeric(health_row$vb_gamma_last[1L] %||% NA_real_)
  } else {
    as.numeric(health_row$mcmc_gamma_mean[1L] %||% NA_real_)
  }
  converged <- if (identical(method, "vb")) {
    as.logical(health_row$vb_converged[1L] %||% NA)
  } else {
    NA
  }
  iter_like <- if (identical(method, "vb")) {
    as.integer(health_row$vb_iter[1L] %||% NA_integer_)
  } else {
    as.integer(health_row$mcmc_n_keep[1L] %||% NA_integer_)
  }
  collapse_warning <- if (isTRUE(health_row$rhs_collapse_flag[1L] %||% FALSE)) {
    as.character(health_row$unhealthy_reason[1L] %||% "rhs_collapse")
  } else {
    NA_character_
  }
  data.frame(
    root_id = root_spec$root_id,
    dataset_cell_id = root_spec$dataset_cell_id,
    scenario = root_spec$scenario,
    root_kind = root_spec$source_root_kind,
    family = root_spec$source_family,
    tau = as.numeric(root_spec$tau),
    fit_size = as.integer(root_spec$fit_size),
    prior = root_spec$beta_prior_type,
    beta_prior_type = root_spec$beta_prior_type,
    source_reference_priors = root_spec$source_reference_priors,
    source_current_rhsns_member = isTRUE(root_spec$source_current_rhsns_member),
    source_legacy_rhs_member = isTRUE(root_spec$source_legacy_rhs_member),
    seed = as.integer(root_spec$seed),
    reservoir_profile = root_spec$reservoir_profile,
    method = method,
    inference = method,
    likelihood_family = likelihood_family,
    model = likelihood_family,
    runtime_sec = runtime_sec,
    fit_runtime_seconds = runtime_sec,
    wall_seconds = runtime_sec,
    total_stage_seconds = runtime_sec,
    iter_like = iter_like,
    converged = converged,
    stop_reason = as.character(signoff_row$signoff_reason[1L] %||% NA_character_),
    sigma_mean = sigma_mean,
    gamma_mean = if (identical(likelihood_family, "al")) NA_real_ else gamma_mean,
    rhs_collapse_flag = as.logical(health_row$rhs_collapse_flag[1L] %||% NA),
    rhs_collapse_warning = collapse_warning,
    fit_file = normalizePath(fit_file, winslash = "/", mustWork = FALSE),
    status = as.character(health_row$status[1L] %||% NA_character_),
    finite_ok = as.logical(health_row$finite_ok[1L] %||% NA),
    domain_ok = as.logical(health_row$domain_ok[1L] %||% NA),
    signoff_grade = as.character(signoff_row$signoff_grade[1L] %||% NA_character_),
    comparison_eligible = as.logical(signoff_row$comparison_eligible[1L] %||% FALSE),
    signoff_reason = as.character(signoff_row$signoff_reason[1L] %||% NA_character_),
    train_n_eval = as.integer(metrics$train$n_eval),
    train_mae = as.numeric(metrics$train$mae),
    train_rmse = as.numeric(metrics$train$rmse),
    train_bias = as.numeric(metrics$train$bias),
    train_corr = as.numeric(metrics$train$corr),
    holdout_n_eval = as.integer(metrics$holdout$n_eval),
    holdout_mae = as.numeric(metrics$holdout$mae),
    holdout_rmse = as.numeric(metrics$holdout$rmse),
    holdout_bias = as.numeric(metrics$holdout$bias),
    holdout_corr = as.numeric(metrics$holdout$corr),
    stringsAsFactors = FALSE
  )
}

.qdesn_static_crossstudy_algorithm_pair_summary <- function(fit_summary, root_spec) {
  if (!nrow(fit_summary)) return(data.frame(stringsAsFactors = FALSE))
  rows <- list()
  for (likelihood_family in sort(unique(as.character(fit_summary$likelihood_family %||% fit_summary$model)))) {
    sub <- fit_summary[(fit_summary$likelihood_family %||% fit_summary$model) == likelihood_family, , drop = FALSE]
    vb_row <- sub[sub$method == "vb", , drop = FALSE]
    mcmc_row <- sub[sub$method == "mcmc", , drop = FALSE]
    if (!nrow(vb_row) || !nrow(mcmc_row)) next
    pair_grade <- if (vb_row$signoff_grade[1L] == "PASS" && mcmc_row$signoff_grade[1L] == "PASS") {
      "PASS"
    } else if (vb_row$signoff_grade[1L] != "FAIL" && mcmc_row$signoff_grade[1L] != "FAIL") {
      "WARN"
    } else {
      "FAIL"
    }
    pair_eligible <- isTRUE(vb_row$comparison_eligible[1L]) && isTRUE(mcmc_row$comparison_eligible[1L])
    rows[[length(rows) + 1L]] <- data.frame(
      root_id = root_spec$root_id,
      dataset_cell_id = root_spec$dataset_cell_id,
      root_kind = root_spec$source_root_kind,
      family = root_spec$source_family,
      tau = as.numeric(root_spec$tau),
      fit_size = as.integer(root_spec$fit_size),
      prior = root_spec$beta_prior_type,
      beta_prior = root_spec$beta_prior_type,
      model = likelihood_family,
      vb_status = as.character(vb_row$status[1L]),
      mcmc_status = as.character(mcmc_row$status[1L]),
      both_success = isTRUE(vb_row$status[1L] == "SUCCESS" && mcmc_row$status[1L] == "SUCCESS"),
      both_finite_ok = isTRUE(vb_row$finite_ok[1L]) && isTRUE(mcmc_row$finite_ok[1L]),
      both_domain_ok = isTRUE(vb_row$domain_ok[1L]) && isTRUE(mcmc_row$domain_ok[1L]),
      vb_signoff_grade = as.character(vb_row$signoff_grade[1L]),
      mcmc_signoff_grade = as.character(mcmc_row$signoff_grade[1L]),
      vb_comparison_eligible = isTRUE(vb_row$comparison_eligible[1L]),
      mcmc_comparison_eligible = isTRUE(mcmc_row$comparison_eligible[1L]),
      pair_signoff_grade = pair_grade,
      algorithm_pair_signoff_grade = pair_grade,
      pair_comparison_eligible = pair_eligible,
      algorithm_pair_comparison_eligible = pair_eligible,
      vb_runtime_sec = as.numeric(vb_row$runtime_sec[1L]),
      mcmc_runtime_sec = as.numeric(mcmc_row$runtime_sec[1L]),
      runtime_ratio_mcmc_vs_vb = ifelse(
        is.finite(as.numeric(vb_row$runtime_sec[1L])) && as.numeric(vb_row$runtime_sec[1L]) > 0,
        as.numeric(mcmc_row$runtime_sec[1L]) / as.numeric(vb_row$runtime_sec[1L]),
        NA_real_
      ),
      mae_vb = as.numeric(vb_row$train_mae[1L]),
      mae_mcmc = as.numeric(mcmc_row$train_mae[1L]),
      mae_delta_mcmc_minus_vb = as.numeric(mcmc_row$train_mae[1L] - vb_row$train_mae[1L]),
      rmse_vb = as.numeric(vb_row$train_rmse[1L]),
      rmse_mcmc = as.numeric(mcmc_row$train_rmse[1L]),
      rmse_delta_mcmc_minus_vb = as.numeric(mcmc_row$train_rmse[1L] - vb_row$train_rmse[1L]),
      bias_vb = as.numeric(vb_row$train_bias[1L]),
      bias_mcmc = as.numeric(mcmc_row$train_bias[1L]),
      bias_delta_mcmc_minus_vb = as.numeric(mcmc_row$train_bias[1L] - vb_row$train_bias[1L]),
      corr_vb = as.numeric(vb_row$train_corr[1L]),
      corr_mcmc = as.numeric(mcmc_row$train_corr[1L]),
      corr_delta_mcmc_minus_vb = as.numeric(mcmc_row$train_corr[1L] - vb_row$train_corr[1L]),
      gate_accuracy = isTRUE(vb_row$finite_ok[1L]) && isTRUE(mcmc_row$finite_ok[1L]) &&
        isTRUE(vb_row$domain_ok[1L]) && isTRUE(mcmc_row$domain_ok[1L]),
      overall_pass = identical(pair_grade, "PASS"),
      stringsAsFactors = FALSE
    )
  }
  .qdesn_validation_bind_rows(rows)
}

.qdesn_static_crossstudy_run_one_fit <- function(root_spec,
                                                 defaults,
                                                 staged_data,
                                                 root_dir,
                                                 method = c("vb", "mcmc"),
                                                 likelihood_family = c("exal", "al")) {
  method <- match.arg(method)
  likelihood_family <- match.arg(likelihood_family)
  root_spec_lik <- modifyList(root_spec, list(likelihood_family = likelihood_family))
  method_dir <- file.path(root_dir, "fits", paste(method, likelihood_family, sep = "_"))
  .qdesn_validation_dir_create(method_dir)
  cfg <- qdesn_static_crossstudy_build_pipeline_cfg(
    root_spec = root_spec_lik,
    defaults = defaults,
    method = method,
    likelihood_family = likelihood_family,
    x_cols = staged_data$x_cols,
    T_use = staged_data$n_obs
  )
  .qdesn_validation_write_json(file.path(method_dir, "fit_request.json"), list(
    root_spec = root_spec_lik,
    config = cfg,
    observed_path = staged_data$observed_path
  ))

  status <- "SUCCESS"
  error_message <- NA_character_
  run_res <- tryCatch(
    run_esn_pipeline_from_cfg(
      cfg = cfg,
      file_long = staged_data$observed_path,
      file_obs = staged_data$observed_path,
      out_dir = method_dir,
      save_outputs = TRUE,
      verbose = FALSE
    ),
    error = function(e) {
      status <<- "FAIL"
      error_message <<- conditionMessage(e)
      NULL
    }
  )
  if (!is.null(run_res) && !identical(as.integer(run_res$status), 0L)) {
    status <- "FAIL"
    if (is.na(error_message)) {
      error_message <- sprintf("pipeline exited with status %s", as.integer(run_res$status))
    }
  }
  if (!is.null(run_res)) {
    .qdesn_validation_write_lines(file.path(method_dir, "logs", "pipeline_stdout.log"), run_res$stdout)
  }
  if (identical(status, "FAIL")) {
    health_row <- data.frame(
      root_id = root_spec$root_id,
      scenario = root_spec$scenario,
      tau = as.numeric(root_spec$tau),
      likelihood_family = likelihood_family,
      beta_prior_type = root_spec$beta_prior_type,
      seed = as.integer(root_spec$seed),
      reservoir_profile = root_spec$reservoir_profile,
      method = method,
      status = "FAIL",
      fit_class = NA_character_,
      fit_runtime_seconds = as.numeric(run_res$elapsed_seconds %||% NA_real_),
      finite_ok = FALSE,
      domain_ok = FALSE,
      rhs_collapse_flag = NA,
      unhealthy = FALSE,
      unhealthy_reason = "",
      stringsAsFactors = FALSE
    )
    progress_trace <- data.frame(stringsAsFactors = FALSE)
    signoff_cfg <- .qdesn_validation_signoff_cfg(defaults)
    meta_row <- health_row[, c("root_id", "scenario", "tau", "likelihood_family", "beta_prior_type", "seed", "reservoir_profile"), drop = FALSE]
    signoff_row <- if (identical(method, "vb")) {
      .qdesn_validation_vb_signoff_from_rows(meta_row, health_row, progress_trace, signoff_cfg$vb)
    } else {
      .qdesn_validation_mcmc_signoff_from_rows(meta_row, health_row, progress_trace, signoff_cfg$mcmc)
    }
    metrics <- list(
      train = .qdesn_static_crossstudy_eval_metrics(numeric(0), numeric(0)),
      holdout = .qdesn_static_crossstudy_eval_metrics(numeric(0), numeric(0))
    )
    fit_summary <- .qdesn_static_crossstudy_fit_summary_row(
      root_spec = root_spec,
      likelihood_family = likelihood_family,
      method = method,
      health_row = health_row,
      metrics = metrics,
      signoff_row = signoff_row,
      method_dir = method_dir
    )
    .qdesn_validation_write_df(health_row, file.path(method_dir, "health_summary.csv"))
    .qdesn_validation_write_df(signoff_row, file.path(method_dir, "signoff_summary.csv"))
    return(list(
      method = method,
      likelihood_family = likelihood_family,
      status = status,
      error_message = error_message,
      health = health_row,
      signoff = signoff_row,
      progress_trace = progress_trace,
      fit_summary = fit_summary
    ))
  }

  summary_obj <- collect_pipeline_run_summary(method_dir)
  health_row <- .qdesn_validation_method_health(method, root_spec_lik, summary_obj)
  if ("status" %in% names(health_row)) {
    status_chr <- as.character(health_row$status[1L] %||% NA_character_)
    if (is.na(status_chr) || !nzchar(status_chr)) {
      health_row$status[1L] <- status
    }
  }
  progress_trace <- .qdesn_validation_method_progress_trace(method, summary_obj)
  if (nrow(progress_trace)) {
    progress_trace$likelihood_family <- likelihood_family
  }
  signoff_cfg <- .qdesn_validation_signoff_cfg(defaults)
  meta_row <- health_row[, c("root_id", "scenario", "tau", "likelihood_family", "beta_prior_type", "seed", "reservoir_profile"), drop = FALSE]
  signoff_row <- if (identical(method, "vb")) {
    .qdesn_validation_vb_signoff_from_rows(meta_row, health_row, progress_trace, signoff_cfg$vb)
  } else {
    .qdesn_validation_mcmc_signoff_from_rows(meta_row, health_row, progress_trace, signoff_cfg$mcmc)
  }
  metrics <- .qdesn_static_crossstudy_collect_metrics_from_summary(summary_obj, staged_data$q_true)
  fit_summary <- .qdesn_static_crossstudy_fit_summary_row(
    root_spec = root_spec,
    likelihood_family = likelihood_family,
    method = method,
    health_row = health_row,
    metrics = metrics,
    signoff_row = signoff_row,
    method_dir = method_dir
  )
  .qdesn_validation_write_df(health_row, file.path(method_dir, "health_summary.csv"))
  .qdesn_validation_write_df(signoff_row, file.path(method_dir, "signoff_summary.csv"))
  if (nrow(progress_trace)) {
    .qdesn_validation_write_df(progress_trace, file.path(method_dir, "progress_trace.csv"))
  }
  if (identical(method, "mcmc")) {
    chain_summary <- .qdesn_validation_mcmc_chain_summary(summary_obj)
    if (nrow(chain_summary)) {
      chain_summary$likelihood_family <- likelihood_family
      .qdesn_validation_write_df(chain_summary, file.path(method_dir, "chain_summary.csv"))
    }
  }
  .qdesn_validation_write_df(fit_summary, file.path(method_dir, "fit_summary_row.csv"))
  list(
    method = method,
    likelihood_family = likelihood_family,
    status = as.character(health_row$status[1L] %||% status),
    error_message = error_message,
    health = health_row,
    signoff = signoff_row,
    progress_trace = progress_trace,
    fit_summary = fit_summary
  )
}

.qdesn_static_crossstudy_model_pair_summary <- function(fit_summary, root_spec) {
  if (!nrow(fit_summary)) return(data.frame(stringsAsFactors = FALSE))
  rows <- list()
  for (method in sort(unique(as.character(fit_summary$inference)))) {
    sub <- fit_summary[fit_summary$inference == method, , drop = FALSE]
    al_row <- sub[sub$model == "al", , drop = FALSE]
    exal_row <- sub[sub$model == "exal", , drop = FALSE]
    if (!nrow(al_row) || !nrow(exal_row)) next
    pair_grade <- if (al_row$signoff_grade[1L] == "PASS" && exal_row$signoff_grade[1L] == "PASS") {
      "PASS"
    } else if (al_row$signoff_grade[1L] != "FAIL" && exal_row$signoff_grade[1L] != "FAIL") {
      "WARN"
    } else {
      "FAIL"
    }
    rows[[length(rows) + 1L]] <- data.frame(
      root_id = root_spec$root_id,
      root_kind = root_spec$source_root_kind,
      family = root_spec$source_family,
      tau = as.numeric(root_spec$tau),
      fit_size = as.integer(root_spec$fit_size),
      prior = root_spec$beta_prior_type,
      inference = method,
      baseline_model = "al",
      extended_model = "exal",
      baseline_signoff_grade = as.character(al_row$signoff_grade[1L]),
      extended_signoff_grade = as.character(exal_row$signoff_grade[1L]),
      baseline_comparison_eligible = as.logical(al_row$comparison_eligible[1L]),
      extended_comparison_eligible = as.logical(exal_row$comparison_eligible[1L]),
      pair_signoff_grade = pair_grade,
      pair_comparison_eligible = as.logical(al_row$comparison_eligible[1L] & exal_row$comparison_eligible[1L]),
      train_mae_delta_extended_minus_baseline = as.numeric(exal_row$train_mae[1L] - al_row$train_mae[1L]),
      train_rmse_delta_extended_minus_baseline = as.numeric(exal_row$train_rmse[1L] - al_row$train_rmse[1L]),
      train_corr_delta_extended_minus_baseline = as.numeric(exal_row$train_corr[1L] - al_row$train_corr[1L]),
      stringsAsFactors = FALSE
    )
  }
  .qdesn_validation_bind_rows(rows)
}

.qdesn_static_crossstudy_root_summary <- function(root_spec,
                                                  fit_summary,
                                                  pairwise_vb_vs_mcmc,
                                                  model_pair_summary,
                                                  root_status) {
  data.frame(
    root_id = root_spec$root_id,
    dataset_cell_id = root_spec$dataset_cell_id,
    root_kind = root_spec$source_root_kind,
    family = root_spec$source_family,
    tau = as.numeric(root_spec$tau),
    fit_size = as.integer(root_spec$fit_size),
    prior = root_spec$beta_prior_type,
    source_reference_priors = root_spec$source_reference_priors,
    source_current_rhsns_member = isTRUE(root_spec$source_current_rhsns_member),
    source_legacy_rhs_member = isTRUE(root_spec$source_legacy_rhs_member),
    root_status = root_status,
    n_methods = nrow(fit_summary),
    n_signoff_pass = sum(as.character(fit_summary$signoff_grade) == "PASS", na.rm = TRUE),
    n_signoff_warn = sum(as.character(fit_summary$signoff_grade) == "WARN", na.rm = TRUE),
    n_signoff_fail = sum(as.character(fit_summary$signoff_grade) == "FAIL", na.rm = TRUE),
    method_comparison_eligible_rate = mean(as.logical(fit_summary$comparison_eligible), na.rm = TRUE),
    n_algorithm_pairs = nrow(pairwise_vb_vs_mcmc),
    n_algorithm_pair_pass = sum(as.character(pairwise_vb_vs_mcmc$algorithm_pair_signoff_grade) == "PASS", na.rm = TRUE),
    n_algorithm_pair_warn = sum(as.character(pairwise_vb_vs_mcmc$algorithm_pair_signoff_grade) == "WARN", na.rm = TRUE),
    n_algorithm_pair_fail = sum(as.character(pairwise_vb_vs_mcmc$algorithm_pair_signoff_grade) == "FAIL", na.rm = TRUE),
    algorithm_pair_comparison_eligible_rate = mean(as.logical(pairwise_vb_vs_mcmc$algorithm_pair_comparison_eligible), na.rm = TRUE),
    n_model_pairs = nrow(model_pair_summary),
    n_model_pair_pass = sum(as.character(model_pair_summary$pair_signoff_grade) == "PASS", na.rm = TRUE),
    n_model_pair_warn = sum(as.character(model_pair_summary$pair_signoff_grade) == "WARN", na.rm = TRUE),
    n_model_pair_fail = sum(as.character(model_pair_summary$pair_signoff_grade) == "FAIL", na.rm = TRUE),
    model_pair_comparison_eligible_rate = mean(as.logical(model_pair_summary$pair_comparison_eligible), na.rm = TRUE),
    root_comparison_eligible_any = {
      eligible_vec <- c(
        as.logical(pairwise_vb_vs_mcmc$algorithm_pair_comparison_eligible),
        as.logical(model_pair_summary$pair_comparison_eligible)
      )
      isTRUE(length(eligible_vec) > 0L && any(eligible_vec, na.rm = TRUE))
    },
    root_comparison_eligible_full = {
      eligible_vec <- c(
        as.logical(pairwise_vb_vs_mcmc$algorithm_pair_comparison_eligible),
        as.logical(model_pair_summary$pair_comparison_eligible)
      )
      isTRUE(length(eligible_vec) > 0L && all(eligible_vec, na.rm = TRUE))
    },
    stringsAsFactors = FALSE
  )
}

qdesn_static_crossstudy_run_root <- function(root_spec,
                                             defaults,
                                             output_root,
                                             create_plots = FALSE,
                                             verbose = TRUE) {
  root_dir <- file.path(output_root, root_spec$root_id)
  if (dir.exists(root_dir) && length(list.files(root_dir, all.files = TRUE, no.. = TRUE)) > 0L) {
    stop(sprintf("Static cross-study root already exists and is not empty: %s", root_dir), call. = FALSE)
  }
  for (d in c("manifest", "config", "data", "fits", "tables", "plots")) {
    .qdesn_validation_dir_create(file.path(root_dir, d))
  }
  .qdesn_validation_write_lines(file.path(root_dir, "manifest", "root_status.txt"), "RUNNING")
  .qdesn_validation_write_json(file.path(root_dir, "manifest", "root_manifest.json"), list(
    root_id = root_spec$root_id,
    dataset_cell_id = root_spec$dataset_cell_id,
    source_root_kind = root_spec$source_root_kind,
    source_family = root_spec$source_family,
    tau = as.numeric(root_spec$tau),
    fit_size = as.integer(root_spec$fit_size),
    beta_prior_type = root_spec$beta_prior_type,
    source_sim_path = root_spec$source_sim_path,
    source_fit_input_dir = root_spec$source_fit_input_dir,
    source_reference_root_count = as.integer(root_spec$source_reference_root_count),
    source_reference_priors = root_spec$source_reference_priors,
    source_current_rhsns_member = isTRUE(root_spec$source_current_rhsns_member),
    source_legacy_rhs_member = isTRUE(root_spec$source_legacy_rhs_member),
    reservoir_profile = root_spec$reservoir_profile,
    seed = as.integer(root_spec$seed),
    git_sha = .qdesn_validation_git_sha(),
    started_at = as.character(Sys.time())
  ))

  staged_data <- qdesn_static_crossstudy_stage_dataset(root_spec, root_dir, defaults)
  results <- list()
  fit_rows <- list()
  progress_rows <- list()
  for (likelihood_family in c("exal", "al")) {
    for (method in c("vb", "mcmc")) {
      if (isTRUE(verbose)) {
        message(sprintf(
          "[qdesn_static_crossstudy_run_root] %s | %s | %s",
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
      key <- paste(method, likelihood_family, sep = "__")
      results[[key]] <- res
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
  root_summary <- .qdesn_static_crossstudy_root_summary(
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

.qdesn_static_crossstudy_collect_root_tables <- function(root_dirs, file_name) {
  rows <- list()
  for (root_dir in root_dirs) {
    path <- file.path(root_dir, "tables", file_name)
    if (!file.exists(path)) next
    rows[[length(rows) + 1L]] <- utils::read.csv(path, stringsAsFactors = FALSE)
  }
  .qdesn_validation_bind_rows(rows)
}

.qdesn_static_crossstudy_group_summary <- function(df, group_cols, grade_col, eligible_col = NULL, extra_numeric = character(0)) {
  if (!nrow(df)) return(data.frame(stringsAsFactors = FALSE))
  group_cols <- group_cols[group_cols %in% names(df)]
  if (!length(group_cols)) return(data.frame(stringsAsFactors = FALSE))
  idx_list <- split(seq_len(nrow(df)), interaction(df[, group_cols, drop = FALSE], drop = TRUE, lex.order = TRUE))
  rows <- lapply(idx_list, function(idx) {
    sub <- df[idx, , drop = FALSE]
    row <- sub[1L, group_cols, drop = FALSE]
    row$n_rows <- nrow(sub)
    row$n_pass <- sum(as.character(sub[[grade_col]]) == "PASS", na.rm = TRUE)
    row$n_warn <- sum(as.character(sub[[grade_col]]) == "WARN", na.rm = TRUE)
    row$n_fail <- sum(as.character(sub[[grade_col]]) == "FAIL", na.rm = TRUE)
    row$pass_rate <- row$n_pass / row$n_rows
    row$warn_rate <- row$n_warn / row$n_rows
    row$fail_rate <- row$n_fail / row$n_rows
    if (!is.null(eligible_col) && eligible_col %in% names(sub)) {
      row$comparison_eligible_rate <- mean(as.logical(sub[[eligible_col]]), na.rm = TRUE)
    }
    for (nm in extra_numeric[extra_numeric %in% names(sub)]) {
      x <- as.numeric(sub[[nm]])
      row[[paste0(nm, "_mean")]] <- if (any(is.finite(x))) mean(x[is.finite(x)]) else NA_real_
    }
    row
  })
  .qdesn_validation_bind_rows(rows)
}

.qdesn_static_crossstudy_reference_root_group_summary <- function(df) {
  if (!nrow(df)) return(data.frame(stringsAsFactors = FALSE))
  split_idx <- split(
    seq_len(nrow(df)),
    interaction(df[, c("root_kind", "family", "tau", "fit_size"), drop = FALSE], drop = TRUE, lex.order = TRUE)
  )
  rows <- lapply(split_idx, function(idx) {
    sub <- df[idx, , drop = FALSE]
    row <- sub[1L, c("root_kind", "family", "tau", "fit_size"), drop = FALSE]
    row$n_roots <- nrow(sub)
    row$comparison_eligible_any_rate <- mean(as.logical(sub$root_comparison_eligible_any), na.rm = TRUE)
    row$comparison_eligible_full_rate <- mean(as.logical(sub$root_comparison_eligible_full), na.rm = TRUE)
    row
  })
  .qdesn_validation_bind_rows(rows)
}

.qdesn_static_crossstudy_qdesn_root_group_summary <- function(df) {
  if (!nrow(df)) return(data.frame(stringsAsFactors = FALSE))
  split_idx <- split(
    seq_len(nrow(df)),
    interaction(df[, c("root_kind", "family", "tau", "fit_size", "prior"), drop = FALSE], drop = TRUE, lex.order = TRUE)
  )
  rows <- lapply(split_idx, function(idx) {
    sub <- df[idx, , drop = FALSE]
    row <- sub[1L, c("root_kind", "family", "tau", "fit_size", "prior"), drop = FALSE]
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

qdesn_static_crossstudy_collect_reference_inventory <- function(paper_root,
                                                                shrink_root) {
  collect_root_dirs <- function(base_root) {
    signoff_paths <- list.files(base_root, pattern = "root_signoff_summary.csv", recursive = TRUE, full.names = TRUE)
    sort(unique(dirname(dirname(signoff_paths))))
  }
  root_dirs <- c(collect_root_dirs(paper_root), collect_root_dirs(shrink_root))
  fit_summary <- .qdesn_validation_bind_rows(lapply(root_dirs, function(root_dir) {
    path <- file.path(root_dir, "tables", "fit_summary.csv")
    if (!file.exists(path)) return(NULL)
    df <- utils::read.csv(path, stringsAsFactors = FALSE)
    meta <- utils::read.csv(file.path(root_dir, "tables", "root_signoff_summary.csv"), stringsAsFactors = FALSE)
    if (nrow(meta)) {
      for (nm in c("root_id", "root_kind", "family", "tau", "fit_size", "prior", "root_comparison_eligible_any", "root_comparison_eligible_full")) {
        if (nm %in% names(meta) && !nm %in% names(df)) df[[nm]] <- meta[[nm]][1L]
      }
    }
    df
  }))
  pairwise <- .qdesn_validation_bind_rows(lapply(root_dirs, function(root_dir) {
    path <- file.path(root_dir, "tables", "pairwise_vb_vs_mcmc.csv")
    if (!file.exists(path)) return(NULL)
    df <- utils::read.csv(path, stringsAsFactors = FALSE)
    meta <- utils::read.csv(file.path(root_dir, "tables", "root_signoff_summary.csv"), stringsAsFactors = FALSE)
    if (nrow(meta)) {
      for (nm in c("root_id", "root_kind", "family", "tau", "fit_size")) {
        if (nm %in% names(meta) && !nm %in% names(df)) df[[nm]] <- meta[[nm]][1L]
      }
    }
    df
  }))
  model_pair <- .qdesn_static_crossstudy_collect_root_tables(root_dirs, "model_pair_signoff.csv")
  root_summary <- .qdesn_static_crossstudy_collect_root_tables(root_dirs, "root_signoff_summary.csv")
  list(
    root_dirs = root_dirs,
    fit_summary = fit_summary,
    pairwise_vb_vs_mcmc = pairwise,
    model_pair_signoff = model_pair,
    root_signoff_summary = root_summary
  )
}

qdesn_static_crossstudy_write_reference_compare <- function(reference_inventory,
                                                            qdesn_tables,
                                                            output_root) {
  .qdesn_validation_dir_create(output_root)
  .qdesn_validation_dir_create(file.path(output_root, "tables"))
  .qdesn_validation_dir_create(file.path(output_root, "manifest"))

  ref_fit_group <- .qdesn_static_crossstudy_group_summary(
    reference_inventory$fit_summary,
    group_cols = c("root_kind", "family", "tau", "fit_size", "inference", "model"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    extra_numeric = c("runtime_sec")
  )
  q_fit_group <- .qdesn_static_crossstudy_group_summary(
    qdesn_tables$fit_summary,
    group_cols = c("root_kind", "family", "tau", "fit_size", "prior", "inference", "model"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    extra_numeric = c("runtime_sec", "train_mae", "train_rmse")
  )
  ref_pair_group <- .qdesn_static_crossstudy_group_summary(
    reference_inventory$pairwise_vb_vs_mcmc,
    group_cols = c("root_kind", "family", "tau", "fit_size", "model"),
    grade_col = "algorithm_pair_signoff_grade",
    eligible_col = "algorithm_pair_comparison_eligible",
    extra_numeric = c("runtime_ratio_mcmc_vs_vb")
  )
  q_pair_group <- .qdesn_static_crossstudy_group_summary(
    qdesn_tables$pairwise_vb_vs_mcmc,
    group_cols = c("root_kind", "family", "tau", "fit_size", "prior", "model"),
    grade_col = "algorithm_pair_signoff_grade",
    eligible_col = "algorithm_pair_comparison_eligible",
    extra_numeric = c("runtime_ratio_mcmc_vs_vb", "mae_delta_mcmc_minus_vb")
  )
  ref_root_group <- .qdesn_static_crossstudy_reference_root_group_summary(reference_inventory$root_signoff_summary)
  q_root_group <- .qdesn_static_crossstudy_qdesn_root_group_summary(qdesn_tables$root_summary)
  surface_delta <- merge(
    q_root_group,
    ref_root_group,
    by = c("root_kind", "family", "tau", "fit_size"),
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
    "# QDESN Static Cross-Study vs exdqlm Reference",
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
    "- Direct signoff/rate comparison is valid at the shared dataset-surface level.",
    "- Raw training error metrics are informative but not forced into a single tuned-minus-reference delta table because QDESN uses a one-step holdout to satisfy the real-mode pipeline contract while the exdqlm static study fits the full dataset directly.",
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

qdesn_static_crossstudy_collect_campaign <- function(results_root,
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
    group_cols = c("root_kind", "family", "tau", "fit_size", "prior", "inference", "model"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    extra_numeric = c("runtime_sec", "train_mae", "train_rmse")
  )
  pair_group <- .qdesn_static_crossstudy_group_summary(
    pairwise_vb_vs_mcmc,
    group_cols = c("root_kind", "family", "tau", "fit_size", "prior", "model"),
    grade_col = "algorithm_pair_signoff_grade",
    eligible_col = "algorithm_pair_comparison_eligible",
    extra_numeric = c("runtime_ratio_mcmc_vs_vb", "mae_delta_mcmc_minus_vb")
  )
  model_group <- .qdesn_static_crossstudy_group_summary(
    model_pair_signoff,
    group_cols = c("root_kind", "family", "tau", "fit_size", "prior", "inference"),
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
  compare_obj <- qdesn_static_crossstudy_write_reference_compare(
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
    "COMPARISON_READY_QDESN_STATIC_CROSSSTUDY_COMPLETE"
  } else if (nrow(root_summary) && all(as.character(root_summary$root_status) == "SUCCESS")) {
    "COMPARISON_READY_WITH_DOCUMENTED_FAIL_BAND"
  } else {
    "HOLD_QDESN_STATIC_CROSSSTUDY_WITH_GAPS"
  }

  summary_lines <- c(
    "# QDESN Static exdqlm Cross-Study Campaign Summary",
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
  .qdesn_validation_write_lines(file.path(report_root, "summary", "qdesn_static_crossstudy_summary.md"), summary_lines)
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

qdesn_static_crossstudy_run_campaign <- function(grid = NULL,
                                                 defaults = NULL,
                                                 grid_path = file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_grid.csv"),
                                                 defaults_path = file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_defaults.yaml"),
                                                 results_root = NULL,
                                                 report_root = NULL,
                                                 verbose = TRUE,
                                                 workers = NULL,
                                                 create_plots = FALSE,
                                                 reference_inventory = NULL) {
  defaults <- defaults %||% qdesn_static_crossstudy_load_defaults(defaults_path)
  grid <- grid %||% qdesn_static_crossstudy_load_grid(grid_path)
  campaign_cfg <- defaults$campaign %||% list()
  runtime_cfg <- defaults$runtime %||% list()
  workers <- as.integer(workers %||% runtime_cfg$campaign_workers %||% runtime_cfg$workers %||% 1L)[1L]
  if (!is.finite(workers) || workers < 1L) workers <- 1L

  results_root <- results_root %||% .qdesn_validation_resolve_path(
    campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "static_exdqlm_crossstudy"),
    must_work = FALSE
  )
  report_root <- report_root %||% .qdesn_validation_resolve_path(
    campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "static_exdqlm_crossstudy"),
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
    campaign_name = campaign_cfg$name %||% "qdesn_static_exdqlm_crossstudy",
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
    reference_inventory <- qdesn_static_crossstudy_collect_reference_inventory(
      paper_root = .qdesn_validation_resolve_path(reference_cfg$paper_root, must_work = TRUE),
      shrink_root = .qdesn_validation_resolve_path(reference_cfg$shrink_root, must_work = TRUE)
    )
  }

  targets <- list()
  for (i in seq_len(nrow(grid))) {
    root_spec <- qdesn_static_crossstudy_enrich_root_spec(as.list(grid[i, , drop = FALSE]), defaults)
    if (!isTRUE(root_spec$enabled)) next
    targets[[length(targets) + 1L]] <- root_spec
  }
  n_targets <- length(targets)
  run_one <- function(root_spec, seq_id, n_total) {
    if (isTRUE(verbose)) {
      message(sprintf("[qdesn_static_crossstudy_run_campaign] root %d/%d | %s", seq_id, n_total, root_spec$root_id))
    }
    res <- tryCatch(
      qdesn_static_crossstudy_run_root(
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
            res <- exdqlm:::qdesn_static_crossstudy_run_root(
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
      qdesn_static_crossstudy_collect_campaign(
        results_root = results_run_root,
        report_root = report_run_root,
        defaults = defaults,
        reference_inventory = reference_inventory,
        create_plots = create_plots
      )
    }
  }

  final <- qdesn_static_crossstudy_collect_campaign(
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

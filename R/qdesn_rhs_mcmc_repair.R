`%||%` <- function(a, b) if (is.null(a)) b else a

qdesn_rhs_mcmc_repair_load_matrix <- function(path = file.path("config", "validation", "qdesn_rhs_mcmc_repair_matrix.csv"),
                                              repo_root = NULL) {
  csv_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- utils::read.csv(csv_path, stringsAsFactors = FALSE)
  if (!nrow(out)) {
    stop("RHS MCMC repair matrix CSV is empty.", call. = FALSE)
  }
  out
}

qdesn_rhs_mcmc_repair_load_profiles <- function(path = file.path("config", "validation", "qdesn_rhs_mcmc_repair_profiles.yaml"),
                                                repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- yaml::read_yaml(yaml_path)
  if (!is.list(out)) {
    stop("RHS MCMC repair profiles YAML must parse to a list.", call. = FALSE)
  }
  out
}

.qdesn_rhs_mcmc_repair_field_is_placeholder <- function(x) {
  x <- trimws(as.character(x %||% ""))
  !nzchar(x) || identical(tolower(x), "na") || startsWith(tolower(x), "best_from_") || identical(tolower(x), "n/a")
}

.qdesn_rhs_mcmc_repair_parse_bool <- function(x) {
  x <- trimws(as.character(x %||% ""))
  if (!nzchar(x) || identical(tolower(x), "na")) return(NA)
  switch(tolower(x),
         "true" = TRUE,
         "false" = FALSE,
         stop(sprintf("Cannot parse boolean value '%s'.", x), call. = FALSE))
}

.qdesn_rhs_mcmc_repair_parse_int <- function(x) {
  if (.qdesn_rhs_mcmc_repair_field_is_placeholder(x)) return(NA_integer_)
  as.integer(x)[1L]
}

.qdesn_rhs_mcmc_repair_parse_num <- function(x) {
  if (.qdesn_rhs_mcmc_repair_field_is_placeholder(x)) return(NA_real_)
  as.numeric(x)[1L]
}

.qdesn_rhs_mcmc_repair_select_row <- function(matrix_df, experiment_id = NULL, run_order = NULL) {
  if (!is.null(experiment_id)) {
    idx <- which(as.character(matrix_df$experiment_id) == as.character(experiment_id)[1L])
  } else if (!is.null(run_order)) {
    idx <- which(as.integer(matrix_df$run_order) == as.integer(run_order)[1L])
  } else {
    stop("Provide experiment_id or run_order.", call. = FALSE)
  }
  if (!length(idx)) {
    stop("Requested RHS MCMC repair experiment was not found in the matrix.", call. = FALSE)
  }
  matrix_df[idx[[1L]], , drop = FALSE]
}

.qdesn_rhs_mcmc_repair_root_set_path <- function(root_set, profiles, repo_root = NULL) {
  root_sets <- profiles$root_sets %||% list()
  rel <- root_sets[[as.character(root_set)[1L]]] %||% NULL
  if (is.null(rel)) {
    stop(sprintf("Unknown RHS MCMC repair root_set '%s'.", as.character(root_set)[1L]), call. = FALSE)
  }
  .qdesn_validation_resolve_path(rel, repo_root = repo_root, must_work = TRUE)
}

.qdesn_rhs_mcmc_repair_vb_profile <- function(profile_name, profiles) {
  profs <- profiles$vb_warm_start_profiles %||% list()
  prof <- profs[[as.character(profile_name)[1L]]] %||% NULL
  if (is.null(prof)) {
    stop(sprintf("Unknown RHS MCMC repair VB warm-start profile '%s'.", as.character(profile_name)[1L]), call. = FALSE)
  }
  prof
}

qdesn_rhs_mcmc_repair_resolve_experiment <- function(experiment_id = NULL,
                                                     run_order = NULL,
                                                     matrix_path = file.path("config", "validation", "qdesn_rhs_mcmc_repair_matrix.csv"),
                                                     profiles_path = file.path("config", "validation", "qdesn_rhs_mcmc_repair_profiles.yaml"),
                                                     repo_root = NULL) {
  repo_root <- .qdesn_validation_repo_root(repo_root)
  matrix_df <- qdesn_rhs_mcmc_repair_load_matrix(matrix_path, repo_root = repo_root)
  profiles <- qdesn_rhs_mcmc_repair_load_profiles(profiles_path, repo_root = repo_root)
  row <- .qdesn_rhs_mcmc_repair_select_row(matrix_df, experiment_id = experiment_id, run_order = run_order)

  executable <- TRUE
  blockers <- character(0)

  if (isTRUE(.qdesn_rhs_mcmc_repair_parse_bool(row$multichain))) {
    executable <- FALSE
    blockers <- c(blockers, "multichain_experiment_not_yet_implemented")
  }
  if (.qdesn_rhs_mcmc_repair_field_is_placeholder(row$vb_warm_start_profile)) {
    executable <- FALSE
    blockers <- c(blockers, "vb_warm_start_profile_placeholder")
  }
  if (.qdesn_rhs_mcmc_repair_field_is_placeholder(row$mcmc_rhs_freeze_tau_burnin_iters)) {
    executable <- FALSE
    blockers <- c(blockers, "mcmc_rhs_freeze_tau_burnin_iters_placeholder")
  }
  if (any(is.na(c(
    .qdesn_rhs_mcmc_repair_parse_int(row$n_burn),
    .qdesn_rhs_mcmc_repair_parse_int(row$n_mcmc),
    .qdesn_rhs_mcmc_repair_parse_num(row$width_gamma),
    .qdesn_rhs_mcmc_repair_parse_num(row$width_rhs_lambda),
    .qdesn_rhs_mcmc_repair_parse_num(row$width_rhs_tau),
    .qdesn_rhs_mcmc_repair_parse_num(row$width_rhs_c2),
    .qdesn_rhs_mcmc_repair_parse_int(row$max_steps_out),
    .qdesn_rhs_mcmc_repair_parse_int(row$max_shrink)
  )))) {
    executable <- FALSE
    blockers <- c(blockers, "numeric_control_placeholder")
  }

  root_grid_path <- .qdesn_rhs_mcmc_repair_root_set_path(row$root_set, profiles, repo_root = repo_root)
  vb_profile <- if (!.qdesn_rhs_mcmc_repair_field_is_placeholder(row$vb_warm_start_profile)) {
    .qdesn_rhs_mcmc_repair_vb_profile(row$vb_warm_start_profile, profiles)
  } else {
    NULL
  }

  defaults_path <- .qdesn_validation_resolve_path(as.character(row$defaults_base)[1L], repo_root = repo_root, must_work = TRUE)
  defaults <- qdesn_validation_load_defaults(defaults_path, repo_root = repo_root)
  defaults$campaign$name <- as.character(row$experiment_id)[1L]
  defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", "rhs_mcmc_repair", as.character(row$experiment_id)[1L])
  defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", "rhs_mcmc_repair", as.character(row$experiment_id)[1L])

  rhs_override <- defaults$pipeline$inference$mcmc$prior_overrides$rhs %||% list()
  rhs_override$n_burn <- .qdesn_rhs_mcmc_repair_parse_int(row$n_burn)
  rhs_override$n_mcmc <- .qdesn_rhs_mcmc_repair_parse_int(row$n_mcmc)
  rhs_override$slice <- modifyList(rhs_override$slice %||% list(), list(
    width_gamma = .qdesn_rhs_mcmc_repair_parse_num(row$width_gamma),
    width_rhs_lambda = .qdesn_rhs_mcmc_repair_parse_num(row$width_rhs_lambda),
    width_rhs_tau = .qdesn_rhs_mcmc_repair_parse_num(row$width_rhs_tau),
    width_rhs_c2 = .qdesn_rhs_mcmc_repair_parse_num(row$width_rhs_c2),
    max_steps_out = .qdesn_rhs_mcmc_repair_parse_int(row$max_steps_out),
    max_shrink = .qdesn_rhs_mcmc_repair_parse_int(row$max_shrink)
  ))
  rhs_override$rhs <- modifyList(rhs_override$rhs %||% list(), list(
    freeze_tau_burnin_iters = .qdesn_rhs_mcmc_repair_parse_int(row$mcmc_rhs_freeze_tau_burnin_iters),
    freeze_tau_only_during_burn = isTRUE(.qdesn_rhs_mcmc_repair_parse_bool(row$mcmc_rhs_freeze_tau_only_during_burn))
  ))
  if (!is.null(vb_profile)) {
    rhs_override$vb_warm_start_control <- modifyList(rhs_override$vb_warm_start_control %||% list(), vb_profile)
  }
  defaults$pipeline$inference$mcmc$prior_overrides$rhs <- rhs_override

  list(
    executable = executable,
    blockers = unique(blockers),
    row = row,
    defaults = defaults,
    defaults_path = defaults_path,
    matrix_path = .qdesn_validation_resolve_path(matrix_path, repo_root = repo_root, must_work = TRUE),
    profiles_path = .qdesn_validation_resolve_path(profiles_path, repo_root = repo_root, must_work = TRUE),
    grid_path = root_grid_path,
    repo_root = repo_root
  )
}

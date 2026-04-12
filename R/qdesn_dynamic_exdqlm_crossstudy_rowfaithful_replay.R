`%||%` <- function(a, b) if (is.null(a)) b else a

qdesn_dynamic_crossstudy_rowfaithful_load_manifest <- function(path = file.path(
                                                                "config",
                                                                "validation",
                                                                "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_replay_manifest.yaml"
                                                              ),
                                                              repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- yaml::read_yaml(yaml_path)
  if (!is.list(out)) {
    stop("Row-faithful replay manifest YAML must parse to a list.", call. = FALSE)
  }
  out
}

.qdesn_dynamic_crossstudy_rowfaithful_read_csv <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  info <- file.info(path)
  if (!is.data.frame(info) || is.na(info$size[1L]) || info$size[1L] <= 0) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  utils::read.csv(path, stringsAsFactors = FALSE)
}

.qdesn_dynamic_crossstudy_rowfaithful_named_chr <- function(keys) {
  stats::setNames(as.list(rep("", length(keys))), keys)
}

.qdesn_dynamic_crossstudy_rowfaithful_named_chrvec <- function(keys) {
  stats::setNames(lapply(keys, function(...) character(0)), keys)
}

.qdesn_dynamic_crossstudy_rowfaithful_stage_root_ids <- function(report_root,
                                                                 run_tag,
                                                                 stage_id) {
  stage_outer_root <- file.path(
    .qdesn_validation_resolve_path(report_root, must_work = FALSE),
    as.character(run_tag)[1L],
    "stages",
    as.character(stage_id)[1L]
  )
  stage_root <- .qdesn_dynamic_crossstudy_fitfail_pick_campaign_root(
    stage_outer_root,
    required_child = "tables"
  )
  path <- file.path(stage_root, "tables", "stage_root_ids.csv")
  df <- .qdesn_dynamic_crossstudy_rowfaithful_read_csv(path)
  if (!nrow(df) || !("root_id" %in% names(df))) {
    stop(sprintf("Stage root inventory is missing or malformed: %s", path), call. = FALSE)
  }
  sort(unique(as.character(df$root_id)))
}

.qdesn_dynamic_crossstudy_rowfaithful_profile_override <- function(wave_manifest,
                                                                  profile_id,
                                                                  wave_label) {
  profile_id <- as.character(profile_id)[1L]
  profiles <- wave_manifest$profiles %||% list()
  if (!length(profiles)) {
    stop(sprintf("Wave '%s' has no profile inventory.", wave_label), call. = FALSE)
  }
  profile_ids <- vapply(profiles, function(profile) as.character(profile$profile_id %||% NA_character_)[1L], character(1))
  idx <- match(profile_id, profile_ids)
  if (is.na(idx)) {
    stop(sprintf("Profile '%s' not found in wave '%s'.", profile_id, wave_label), call. = FALSE)
  }
  as.list((profiles[[idx]] %||% list())$overrides %||% list())
}

.qdesn_dynamic_crossstudy_rowfaithful_apply_patch <- function(current_patch, new_patch) {
  current_patch <- current_patch %||% list()
  new_patch <- new_patch %||% list()
  if (!length(new_patch)) return(current_patch)
  utils::modifyList(current_patch, new_patch)
}

.qdesn_dynamic_crossstudy_rowfaithful_validate_root_ids <- function(root_ids,
                                                                    known_root_ids,
                                                                    label) {
  unknown <- setdiff(unique(as.character(root_ids)), unique(as.character(known_root_ids)))
  if (length(unknown)) {
    stop(
      sprintf(
        "%s references unknown roots: %s",
        label,
        paste(unknown, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(root_ids)
}

qdesn_dynamic_crossstudy_rowfaithful_resolve <- function(manifest,
                                                         repo_root = NULL) {
  manifest <- manifest %||% qdesn_dynamic_crossstudy_rowfaithful_load_manifest(repo_root = repo_root)
  base_cfg <- manifest$base %||% list()
  base_defaults_path <- base_cfg$defaults_path %||% file.path(
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_defaults.yaml"
  )
  base_grid_path <- base_cfg$grid_path %||% file.path(
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_grid.csv"
  )

  defaults <- qdesn_dynamic_crossstudy_load_defaults(base_defaults_path, repo_root = repo_root)
  grid_df <- qdesn_dynamic_crossstudy_load_grid(base_grid_path, repo_root = repo_root)
  known_root_ids <- unique(as.character(grid_df$root_id))

  row_patches <- stats::setNames(vector("list", length(known_root_ids)), known_root_ids)
  stage_decision_chain <- .qdesn_dynamic_crossstudy_rowfaithful_named_chrvec(known_root_ids)
  applied_profile_chain <- .qdesn_dynamic_crossstudy_rowfaithful_named_chrvec(known_root_ids)
  exact_root_chain <- .qdesn_dynamic_crossstudy_rowfaithful_named_chrvec(known_root_ids)
  final_profile_id <- .qdesn_dynamic_crossstudy_rowfaithful_named_chr(known_root_ids)
  final_profile_origin <- .qdesn_dynamic_crossstudy_rowfaithful_named_chr(known_root_ids)

  accepted_chain <- manifest$accepted_chain %||% list()
  if (!length(accepted_chain)) {
    stop("Replay manifest is missing accepted_chain entries.", call. = FALSE)
  }

  for (wave in accepted_chain) {
    wave_id <- as.character(wave$wave_id %||% wave$id %||% "UNKNOWN_WAVE")[1L]
    wave_label <- as.character(wave$label %||% wave_id)[1L]
    wave_manifest_path <- wave$manifest_path %||% NA_character_
    wave_report_root <- as.character(wave$report_root %||% "")[1L]
    wave_run_tag <- as.character(wave$run_tag %||% "")[1L]
    if (!nzchar(wave_report_root) || !nzchar(wave_run_tag)) {
      stop(sprintf("Wave '%s' must define report_root and run_tag.", wave_id), call. = FALSE)
    }
    wave_manifest <- qdesn_dynamic_crossstudy_fitfail_load_manifest(wave_manifest_path, repo_root = repo_root)

    stage_profile_map <- wave$selected_stage_profiles %||% list()
    if (!is.null(stage_profile_map) && length(stage_profile_map)) {
      stage_ids <- names(stage_profile_map)
      if (is.null(stage_ids) || any(!nzchar(stage_ids))) {
        stop(sprintf("Wave '%s' selected_stage_profiles must be a named map.", wave_id), call. = FALSE)
      }
      for (stage_id in stage_ids) {
        selected_profile_id <- as.character(stage_profile_map[[stage_id]] %||% "SOURCE_BASELINE")[1L]
        stage_root_ids <- .qdesn_dynamic_crossstudy_rowfaithful_stage_root_ids(
          report_root = wave_report_root,
          run_tag = wave_run_tag,
          stage_id = stage_id
        )
        .qdesn_dynamic_crossstudy_rowfaithful_validate_root_ids(
          stage_root_ids,
          known_root_ids,
          sprintf("Wave '%s' stage '%s'", wave_id, stage_id)
        )
        stage_marker <- sprintf("%s:%s=%s", wave_id, stage_id, selected_profile_id)
        for (root_id in stage_root_ids) {
          stage_decision_chain[[root_id]] <- c(stage_decision_chain[[root_id]], stage_marker)
        }
        if (identical(selected_profile_id, "SOURCE_BASELINE")) next

        override_patch <- .qdesn_dynamic_crossstudy_rowfaithful_profile_override(
          wave_manifest = wave_manifest,
          profile_id = selected_profile_id,
          wave_label = wave_label
        )
        profile_marker <- sprintf("%s:%s:%s", wave_id, stage_id, selected_profile_id)
        for (root_id in stage_root_ids) {
          row_patches[[root_id]] <- .qdesn_dynamic_crossstudy_rowfaithful_apply_patch(
            row_patches[[root_id]],
            override_patch
          )
          applied_profile_chain[[root_id]] <- c(applied_profile_chain[[root_id]], profile_marker)
          final_profile_id[[root_id]] <- selected_profile_id
          final_profile_origin[[root_id]] <- sprintf("%s stage %s", wave_id, stage_id)
        }
      }
    }

    root_overrides <- wave$selected_root_profile_overrides %||% list()
    if (length(root_overrides)) {
      for (override in root_overrides) {
        root_id <- as.character(override$root_id %||% "")[1L]
        profile_id <- as.character(override$profile_id %||% "")[1L]
        if (!nzchar(root_id) || !nzchar(profile_id)) {
          stop(sprintf("Wave '%s' exact-root overrides must define root_id and profile_id.", wave_id), call. = FALSE)
        }
        .qdesn_dynamic_crossstudy_rowfaithful_validate_root_ids(
          root_id,
          known_root_ids,
          sprintf("Wave '%s' exact-root override", wave_id)
        )
        override_patch <- .qdesn_dynamic_crossstudy_rowfaithful_profile_override(
          wave_manifest = wave_manifest,
          profile_id = profile_id,
          wave_label = wave_label
        )
        row_patches[[root_id]] <- .qdesn_dynamic_crossstudy_rowfaithful_apply_patch(
          row_patches[[root_id]],
          override_patch
        )
        exact_root_chain[[root_id]] <- c(
          exact_root_chain[[root_id]],
          sprintf("%s:%s", wave_id, profile_id)
        )
        final_profile_id[[root_id]] <- profile_id
        final_profile_origin[[root_id]] <- sprintf("%s exact-root override", wave_id)
      }
    }
  }

  nonempty_row_overrides <- row_patches[vapply(row_patches, length, integer(1)) > 0L]

  inventory_df <- grid_df[, c(
    "root_id",
    "dataset_cell_id",
    "source_root_kind",
    "source_scenario",
    "source_family",
    "tau",
    "fit_size",
    "effective_fit_size",
    "source_total_size",
    "source_window_label",
    "beta_prior_type"
  ), drop = FALSE]
  inventory_df$stage_decision_chain <- vapply(
    as.character(inventory_df$root_id),
    function(root_id) paste(stage_decision_chain[[root_id]], collapse = " | "),
    character(1)
  )
  inventory_df$applied_profile_chain <- vapply(
    as.character(inventory_df$root_id),
    function(root_id) paste(applied_profile_chain[[root_id]], collapse = " | "),
    character(1)
  )
  inventory_df$exact_root_override_chain <- vapply(
    as.character(inventory_df$root_id),
    function(root_id) paste(exact_root_chain[[root_id]], collapse = " | "),
    character(1)
  )
  inventory_df$has_row_override <- vapply(
    as.character(inventory_df$root_id),
    function(root_id) isTRUE(length(row_patches[[root_id]]) > 0L),
    logical(1)
  )
  inventory_df$final_selected_profile <- vapply(
    as.character(inventory_df$root_id),
    function(root_id) {
      out <- as.character(final_profile_id[[root_id]] %||% "")[1L]
      if (!nzchar(out)) "SOURCE_BASELINE" else out
    },
    character(1)
  )
  inventory_df$final_profile_origin <- vapply(
    as.character(inventory_df$root_id),
    function(root_id) {
      out <- as.character(final_profile_origin[[root_id]] %||% "")[1L]
      if (!nzchar(out)) "BASE_DEFAULTS" else out
    },
    character(1)
  )

  contract <- manifest$global_replay_contract %||% manifest$replay$contract %||% list()
  replay_cfg <- list(
    mode = as.character(manifest$replay$mode %||% "rowfaithful_current_best_multiseed")[1L],
    description = as.character((manifest$meta %||% list())$purpose %||% "Row-faithful replay of the current accepted source with standardized burn/draws/seeds.")[1L],
    contract = contract,
    row_overrides = nonempty_row_overrides,
    accepted_chain = accepted_chain,
    source_summary = manifest$source_summary %||% list(),
    inventory_summary = list(
      total_roots = nrow(grid_df),
      overridden_roots = length(nonempty_row_overrides),
      source_baseline_roots = nrow(grid_df) - length(nonempty_row_overrides)
    )
  )

  resolved_defaults <- defaults
  if (length(manifest$campaign %||% list())) {
    resolved_defaults$campaign <- utils::modifyList(resolved_defaults$campaign %||% list(), manifest$campaign)
  }
  if (length(manifest$metrics %||% list())) {
    resolved_defaults$metrics <- utils::modifyList(resolved_defaults$metrics %||% list(), manifest$metrics)
  }
  if (length(manifest$runtime %||% list())) {
    resolved_defaults$runtime <- utils::modifyList(resolved_defaults$runtime %||% list(), manifest$runtime)
  }
  if (length(manifest$multiseed %||% list())) {
    resolved_defaults$multiseed <- utils::modifyList(resolved_defaults$multiseed %||% list(), manifest$multiseed)
  }
  resolved_defaults$replay <- replay_cfg

  list(
    manifest = manifest,
    defaults = resolved_defaults,
    grid = grid_df,
    inventory = inventory_df,
    row_overrides = nonempty_row_overrides
  )
}

qdesn_dynamic_crossstudy_rowfaithful_write_materialized <- function(resolved,
                                                                    defaults_out_path,
                                                                    inventory_out_path,
                                                                    summary_out_path = NULL,
                                                                    canary_grid_out_path = NULL) {
  .qdesn_validation_require_namespace("yaml")
  defaults_out_path <- .qdesn_validation_resolve_path(defaults_out_path, must_work = FALSE)
  inventory_out_path <- .qdesn_validation_resolve_path(inventory_out_path, must_work = FALSE)
  if (!is.null(summary_out_path)) {
    summary_out_path <- .qdesn_validation_resolve_path(summary_out_path, must_work = FALSE)
  }
  if (!is.null(canary_grid_out_path)) {
    canary_grid_out_path <- .qdesn_validation_resolve_path(canary_grid_out_path, must_work = FALSE)
  }

  inventory_df <- as.data.frame(resolved$inventory %||% data.frame(stringsAsFactors = FALSE), stringsAsFactors = FALSE)
  manifest <- resolved$manifest %||% list()
  replay_cfg <- resolved$defaults$replay %||% list()

  if (nrow(inventory_df)) {
    .qdesn_validation_dir_create(dirname(inventory_out_path))
    utils::write.csv(inventory_df, inventory_out_path, row.names = FALSE)
  }

  if (!is.null(canary_grid_out_path)) {
    canary_cfg <- manifest$canary %||% list()
    canary_root_ids <- unique(as.character(unlist(canary_cfg$root_ids %||% character(0), use.names = FALSE)))
    if (!length(canary_root_ids)) {
      stop("Replay manifest canary section must define root_ids before writing a canary grid.", call. = FALSE)
    }
    canary_grid <- resolved$grid[as.character(resolved$grid$root_id) %in% canary_root_ids, , drop = FALSE]
    if (!nrow(canary_grid)) {
      stop("Resolved canary grid is empty.", call. = FALSE)
    }
    .qdesn_validation_dir_create(dirname(canary_grid_out_path))
    utils::write.csv(canary_grid, canary_grid_out_path, row.names = FALSE)
  }

  resolved$defaults$replay$inventory_csv <- inventory_out_path
  if (!is.null(canary_grid_out_path)) {
    resolved$defaults$replay$canary_grid_csv <- canary_grid_out_path
  }
  resolved$defaults$replay$manifest_path <- manifest$meta$manifest_path %||% NA_character_
  .qdesn_validation_dir_create(dirname(defaults_out_path))
  yaml::write_yaml(resolved$defaults, defaults_out_path)

  if (!is.null(summary_out_path)) {
    lines <- c(
      "# QDESN Dynamic Row-Faithful Replay Materialization",
      "",
      sprintf("- generated_at: `%s`", as.character(Sys.time())),
      sprintf("- defaults_out_path: `%s`", defaults_out_path),
      sprintf("- inventory_out_path: `%s`", inventory_out_path),
      if (!is.null(canary_grid_out_path)) sprintf("- canary_grid_out_path: `%s`", canary_grid_out_path) else NULL,
      sprintf("- total_roots: `%d`", as.integer(nrow(resolved$grid %||% data.frame(stringsAsFactors = FALSE)))),
      sprintf("- overridden_roots: `%d`", as.integer(length(replay_cfg$row_overrides %||% list()))),
      sprintf("- source_baseline_roots: `%d`", as.integer(nrow(resolved$grid %||% data.frame(stringsAsFactors = FALSE)) - length(replay_cfg$row_overrides %||% list()))),
      "",
      "## Replay Contract",
      sprintf("- posterior_metric_draws: `%s`", as.character(replay_cfg$contract$posterior_metric_draws %||% NA_character_)),
      sprintf("- vb_sampling_nd_draws: `%s`", as.character(replay_cfg$contract$vb_sampling_nd_draws %||% NA_character_)),
      sprintf("- vb_synthesis_n_samp: `%s`", as.character(replay_cfg$contract$vb_synthesis_n_samp %||% NA_character_)),
      sprintf("- mcmc_n_burn: `%s`", as.character(replay_cfg$contract$mcmc_n_burn %||% NA_character_)),
      sprintf("- mcmc_n_mcmc: `%s`", as.character(replay_cfg$contract$mcmc_n_mcmc %||% NA_character_)),
      sprintf("- mcmc_thin: `%s`", as.character(replay_cfg$contract$mcmc_thin %||% NA_character_))
    )
    .qdesn_validation_dir_create(dirname(summary_out_path))
    writeLines(lines, summary_out_path)
  }

  invisible(list(
    defaults_out_path = defaults_out_path,
    inventory_out_path = inventory_out_path,
    summary_out_path = summary_out_path,
    canary_grid_out_path = canary_grid_out_path
  ))
}

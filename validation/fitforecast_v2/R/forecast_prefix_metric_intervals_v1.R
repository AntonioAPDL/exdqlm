# Study-only forecast scoring. Missing posterior evidence never invokes fitting.
fpf_sha <- function(path) unname(tools::sha256sum(path)[[1L]])
fpf_stop <- function(message) stop(message, call. = FALSE)
fpf_assert <- function(ok, message) if (!isTRUE(ok)) fpf_stop(message)
fpf_read <- function(path) read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
fpf_function_sha <- function(fun) digest::digest(list(formals(fun), body(fun)), algo = "sha256")
fpf_write <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile("prefix_", tmpdir = dirname(path))
  con <- if (grepl("[.]gz$", path)) gzfile(tmp, "wt") else file(tmp, "wt")
  tryCatch(write.csv(x, con, row.names = FALSE, na = ""), finally = close(con))
  fpf_assert(file.rename(tmp, path), "Atomic output rename failed.")
  invisible(path)
}
fpf_grid <- function(start = 9000L, n = 1000L, stride = 30L, horizon = 30L) {
  fpf_assert(n > 0 && stride == horizon && stride > 0, "Expected a nonoverlapping forecast grid.")
  i <- seq_len(n)
  data.frame(origin = start + ((i - 1L) %/% stride) * stride,
    lead = (i - 1L) %% stride + 1L, target = start + i)
}
fpf_check_grid <- function(grid) {
  fpf_assert(all(c("origin", "lead", "target") %in% names(grid)), "Missing grid columns.")
  fpf_assert(nrow(grid) > 0 && all(is.finite(as.matrix(grid[c("origin", "lead", "target")]))), "Invalid grid.")
  fpf_assert(!anyDuplicated(grid$target) && all(diff(grid$target) == 1) &&
    all(grid$lead > 0) && all(grid$target == grid$origin + grid$lead), "Grid alignment failed.")
  invisible(TRUE)
}
fpf_loss <- function(y, q, p) (y - q) * (p - as.numeric(y < q))
fpf_score_paths <- function(q, grid, y, oracle, p, cutoffs = c(300L, 500L, 1000L),
                            chain = 1L, source_draw_index = seq_len(ncol(q)),
                            origin_snapshots = TRUE) {
  fpf_check_grid(grid)
  q <- as.matrix(q)
  fpf_assert(nrow(q) == nrow(grid) && ncol(q) > 1 &&
    length(y) == nrow(q) && length(oracle) == nrow(q) &&
    all(is.finite(c(q, y, oracle))) && is.finite(p) && p > 0 && p < 1, "Invalid scoring input.")
  fpf_assert(length(source_draw_index) == ncol(q) && !anyDuplicated(source_draw_index), "Invalid draw alignment.")
  fpf_assert(all(cutoffs == as.integer(cutoffs)) && all(cutoffs > 0 & cutoffs <= nrow(q)), "Invalid cutoff.")
  boundaries <- which(c(diff(grid$origin) != 0, TRUE))
  checkpoints <- sort(unique(c(cutoffs, if (origin_snapshots) boundaries)))
  absolute_sum <- check_sum <- numeric(ncol(q))
  result <- list()
  for (i in seq_len(nrow(q))) {
    absolute_sum <- absolute_sum + abs(q[i, ] - oracle[i])
    check_sum <- check_sum + fpf_loss(y[i], q[i, ], p)
    if (i %in% checkpoints) result[[length(result) + 1L]] <- data.frame(
      chain_id = chain, draw_id = seq_len(ncol(q)), source_draw_index = source_draw_index,
      cutoff = i, requested_cutoff = i %in% cutoffs, n_pairs = i,
      n_origins = length(unique(grid$origin[seq_len(i)])),
      end_origin = grid$origin[i], end_lead = grid$lead[i], last_target = grid$target[i],
      absolute_error_sum = absolute_sum, check_loss_sum = check_sum,
      forecast_mae = absolute_sum / i, forecast_check_loss = check_sum / i)
  }
  do.call(rbind, result)
}
fpf_verify_full <- function(scores, reference, n = 1000L, tolerance = 1e-6) {
  z <- scores[scores$cutoff == n, , drop = FALSE]
  fpf_assert(nrow(z) == nrow(reference) && !anyDuplicated(z$draw_id) &&
    setequal(z$draw_id, reference$draw_id), "Full-window draw IDs do not match.")
  z <- z[match(reference$draw_id, z$draw_id), ]
  fpf_assert(all(is.finite(as.matrix(z[c("forecast_mae", "forecast_check_loss")]))), "Non-finite scores.")
  error <- max(abs(as.matrix(z[c("forecast_mae", "forecast_check_loss")]) -
    as.matrix(reference[c("forecast_mae", "forecast_check_loss")])) )
  fpf_assert(error <= tolerance, sprintf("Full-window replay mismatch: %.9g > %.9g", error, tolerance))
  error
}
fpf_score_origin_groups <- function(groups, reference, grid = fpf_grid(),
                                    cutoffs = c(300L, 500L, 1000L), tolerance = 1e-6) {
  fpf_check_grid(grid)
  fpf_assert(all(c("scope", "group_type", "group_value", "draw_id", "n_targets",
    "forecast_mae", "forecast_check_loss") %in% names(groups)), "Incomplete group-draw evidence.")
  z <- groups[groups$scope == "all_targets" & groups$group_type == "origin", ]
  z$origin <- as.integer(z$group_value)
  fpf_assert(!anyNA(z$origin) && !anyDuplicated(paste(z$origin, z$draw_id)), "Duplicate/invalid origin groups.")
  counts <- table(grid$origin)
  fpf_assert(setequal(z$origin, as.integer(names(counts))), "Origin groups do not cover the original grid.")
  fpf_assert(all(z$n_targets == as.integer(counts[as.character(z$origin)])), "Origin group sizes changed.")
  ids <- reference$draw_id
  fpf_assert(!anyDuplicated(ids), "Duplicate reference draw IDs.")
  boundary <- which(c(diff(grid$origin) != 0, TRUE))
  possible <- sort(unique(cutoffs[cutoffs %in% boundary]))
  # Whole-origin draw means recover sums only at complete origin boundaries.
  all_boundaries <- sort(unique(c(possible, nrow(grid))))
  sums_a <- sums_c <- numeric(length(ids))
  answer <- list()
  origins <- unique(grid$origin)
  position <- 0L
  for (origin in origins) {
    b <- z[z$origin == origin, ]
    fpf_assert(nrow(b) == length(ids) && setequal(b$draw_id, ids), "Group draw alignment failed.")
    b <- b[match(ids, b$draw_id), ]
    fpf_assert(all(is.finite(as.matrix(b[c("forecast_mae", "forecast_check_loss")]))), "Non-finite group scores.")
    count <- as.integer(counts[as.character(origin)])
    sums_a <- sums_a + b$forecast_mae * count
    sums_c <- sums_c + b$forecast_check_loss * count
    position <- position + count
    if (position %in% all_boundaries) answer[[length(answer) + 1L]] <- data.frame(
      chain_id = reference$chain_id, draw_id = ids,
      source_draw_index = reference$source_draw_index,
      parent_coefficient_draw_index = if ("source_draw_index" %in% names(b)) b$source_draw_index else NA_integer_,
      cutoff = position, requested_cutoff = position %in% cutoffs,
      n_pairs = position, n_origins = match(origin, origins),
      end_origin = origin, end_lead = count, last_target = grid$target[position],
      absolute_error_sum = sums_a, check_loss_sum = sums_c,
      forecast_mae = sums_a / position, forecast_check_loss = sums_c / position)
  }
  answer <- do.call(rbind, answer)
  fpf_verify_full(answer, reference, nrow(grid), tolerance)
  answer
}
fpf_pool <- function(scores, quantile_type = 8L) {
  fpf_assert(quantile_type %in% c(7L, 8L), "Unrecognized historical quantile estimator.")
  for (field in intersect(c("replay_id", "family", "p", "model_variant"), names(scores)))
    fpf_assert(length(unique(scores[[field]])) == 1L, "Pooling mixed source/case identities is prohibited.")
  fpf_assert(!anyDuplicated(paste(scores$chain_id, scores$draw_id, scores$cutoff)), "Duplicate pooled draws.")
  rows <- list()
  for (n in sort(unique(scores$cutoff))) {
    z <- scores[scores$cutoff == n, ]
    fpf_assert(length(unique(z$n_pairs)) == 1 &&
      length(unique(z$n_origins)) == 1 && length(unique(z$last_target)) == 1,
      "Pooling mixed forecast grids.")
    fpf_assert(length(unique(as.integer(table(z$chain_id)))) == 1L, "Unequal chain budgets.")
    for (metric in c("forecast_mae", "forecast_check_loss")) {
      values <- z[[metric]]
      fpf_assert(all(is.finite(values)), "Cannot pool non-finite scores.")
      qs <- unname(quantile(values, c(.025, .5, .975), type = quantile_type))
      rows[[length(rows) + 1L]] <- data.frame(cutoff = n, metric = metric,
        posterior_mean = mean(values), cri_lower = qs[1], posterior_median = qs[2], cri_upper = qs[3],
        n_draws = length(values), n_chains = length(unique(z$chain_id)),
        n_pairs = z$n_pairs[1], n_origins = z$n_origins[1], last_target = z$last_target[1],
        quantile_type = quantile_type)
    }
  }
  do.call(rbind, rows)
}
fpf_registry <- function(source_map, article_data) {
  s <- source_map[!duplicated(source_map$metric_draws_path), ]
  k <- strsplit(s$key, "|", fixed = TRUE)
  s$family <- vapply(k, `[`, character(1), 1L)
  s$p <- as.numeric(vapply(k, `[`, character(1), 2L))
  s$model_variant <- vapply(k, `[`, character(1), 3L)
  s$n_draws <- article_data$n_draws[match(s$replay_id, article_data$replay_id)] / 3L
  s$quantile_type <- ifelse(s$replay_id == "idolp_v2_winner_three_chain_pool", 7L, 8L)
  s$task_id <- paste(s$replay_id, sprintf("c%02d", s$chain_id), sep = "__")
  fpf_assert(!anyDuplicated(s$task_id) && !anyNA(s$n_draws), "Invalid task registry.")
  s
}
fpf_json <- function(p) jsonlite::read_json(p, simplifyVector = TRUE)
fpf_artifact_candidates <- function(root) {
  if (!dir.exists(root)) return(character())
  list.files(root, recursive = TRUE, full.names = TRUE, ignore.case = TRUE,
    pattern = "(forecast_objects|posterior|beta_draw|coefficient_draw|fit_object|rhs_trace|forecast_location_draw|quantile_draw|origin_horizon_group_draws|prefix_metric).*(rds|rda|rdata|ffv2handoff|csv|csv[.]gz)$")
}
fpf_audit_recovery <- function(registry, bundle_root, output) {
  inventory <- probes <- candidates <- list()
  for (i in seq_len(nrow(registry))) {
    r <- registry[i, ]
    root <- dirname(dirname(r$metric_draws_path))
    config <- NULL
    cfg_path <- if (r$model_variant %in% c("dqlm", "exdqlm")) {
      stem <- sub("_metric_draws.csv.gz", "", basename(r$metric_draws_path), fixed = TRUE)
      file.path(root, "configs", paste0(stem, "_config.json"))
    } else file.path(bundle_root, "jobs", paste0("qdesn__", r$replay_id,
      sprintf("__c%02d", r$chain_id)), "config.json")
    if (file.exists(cfg_path)) config <- fpf_json(cfg_path)
    else if (file.exists(file.path(root, "fit_request.json"))) cfg_path <- file.path(root, "fit_request.json")
    fit_paths <- if (!is.null(config$fit_handoff_path)) as.character(config$fit_handoff_path) else
      c(file.path(root, "models/forecast_objects.rds"), file.path(root, "models/rhs_trace.rds"))
    for (p in fit_paths) probes[[length(probes) + 1L]] <- data.frame(task_id = r$task_id,
      path = p, exists = file.exists(p), role = "configured_posterior_candidate")
    roots <- root
    if (!is.null(config$source_request_path) && file.exists(config$source_request_path)) {
      old <- fpf_json(config$source_request_path)
      for (field in c("job_root", "method_dir", "run_root", "output_root")) {
        if (is.character(old[[field]]) && length(old[[field]]) == 1 && dir.exists(old[[field]]))
          roots <- c(roots, old[[field]])
      }
    }
    found <- unique(unlist(lapply(unique(roots), fpf_artifact_candidates), use.names = FALSE))
    if (length(found)) for (p in found) candidates[[length(candidates) + 1L]] <- data.frame(
      task_id = r$task_id, path = normalizePath(p), sha256 = fpf_sha(p), bytes = file.info(p)$size,
      verified_for_this_source = FALSE)
    group <- file.path(root, "tables/origin_horizon_group_draws.csv.gz")
    handoff <- fit_paths[file.exists(fit_paths)]
    inventory[[i]] <- data.frame(task_id = r$task_id, replay_id = r$replay_id,
      family = r$family, p = r$p, model_variant = r$model_variant, chain_id = r$chain_id,
      config_path = cfg_path, config_exists = file.exists(cfg_path),
      configured_posterior_candidates_present = length(handoff),
      group_draws_path = if (file.exists(group)) group else "",
      candidate_count = length(found),
      recovery_status = if (file.exists(group)) "GROUP_DRAWS_REQUIRE_ALIGNMENT_CHECK" else
        if (length(handoff)) "CAPSULE_REQUIRES_SUFFICIENCY_CHECK" else "RECOVERY_INCOMPLETE")
  }
  inventory <- do.call(rbind, inventory)
  probes <- do.call(rbind, probes)
  candidates <- if (length(candidates)) do.call(rbind, candidates) else
    data.frame(task_id = character(), path = character(), sha256 = character(), bytes = numeric(),
      verified_for_this_source = logical())
  fpf_write(inventory, file.path(output, "recovery_inventory.csv"))
  fpf_write(probes, file.path(output, "posterior_locator_probe.csv"))
  fpf_write(candidates, file.path(output, "source_linked_candidate_inventory.csv"))
  inventory
}
fpf_capsule_checks <- function(cap, task) {
  fpf_assert(identical(cap$schema, "independent_forecast_prefix_capsule_v1"), "Unknown capsule schema.")
  fpf_assert(identical(cap$task_id, task$task_id) && identical(cap$replay_id, task$replay_id), "Wrong capsule source.")
  fpf_assert(!is.null(cap$fit), "Required fitted posterior missing; refitting is disabled.")
  fpf_assert(cap$adapter %in% c("qdesn_lattice_v14", "dqlm_rolling_v14"), "Unknown forecast adapter.")
  fpf_assert(identical(as.character(utils::packageVersion("exdqlm")), cap$package_version), "Wrong installed package.")
  fpf_assert(length(cap$code_paths) > 0 && length(cap$code_paths) == length(cap$code_sha256) &&
    all(file.exists(cap$code_paths)) &&
    all(vapply(cap$code_paths, fpf_sha, character(1)) == cap$code_sha256), "Pinned forecast code hashes failed.")
  fpf_assert(cap$n_metric_draws == task$n_draws && cap$chain_id == task$chain_id, "Capsule draw/chain budget changed.")
  fpf_assert(is.finite(cap$p) && cap$p == task$p && length(cap$y) == 1000 && length(cap$oracle) == 1000,
    "Capsule scoring targets changed.")
  fpf_assert(identical(cap$grid, fpf_grid()), "Capsule is not the frozen article grid.")
  fpf_assert(length(cap$rng_kind) == 3 && is.finite(cap$seed), "Missing original RNG contract.")
  invisible(TRUE)
}
fpf_replay_capsule <- function(cap, task, q_forecaster = NULL, d_forecaster = NULL) {
  fpf_capsule_checks(cap, task)
  old_kind <- RNGkind()
  old_seed <- if (exists(".Random.seed", .GlobalEnv)) get(".Random.seed", .GlobalEnv) else NULL
  on.exit({
    do.call(RNGkind, as.list(old_kind))
    if (is.null(old_seed)) {
      if (exists(".Random.seed", .GlobalEnv)) rm(".Random.seed", envir = .GlobalEnv)
    } else assign(".Random.seed", old_seed, .GlobalEnv)
  }, add = TRUE)
  do.call(RNGkind, as.list(cap$rng_kind))
  set.seed(cap$seed)
  if (cap$adapter == "qdesn_lattice_v14") {
    args <- cap$forecast_args
    fpf_assert(is.list(args) && isTRUE(args$keep_origin_draws) && args$H == 30L &&
      length(cap$local_origins) == 34 && length(cap$draw_columns) == cap$n_metric_draws &&
      !anyDuplicated(cap$draw_columns) && is.finite(cap$location_center) &&
      is.finite(cap$location_scale) && cap$location_scale > 0, "Incomplete Q-DESN forecast contract.")
    args$object <- cap$fit
    if (is.null(q_forecaster)) q_forecaster <- getExportedValue("exdqlm", "forecast_lattice.qdesn_fit")
    fpf_assert(identical(fpf_function_sha(q_forecaster), cap$forecast_function_sha256), "Loaded forecast function differs from the frozen function.")
    forecast <- do.call(q_forecaster, args)
    q <- do.call(rbind, lapply(seq_along(cap$local_origins), function(i) {
      pos <- match(cap$local_origins[i], forecast$origins)
      fpf_assert(!is.na(pos), "Original local origin missing from forecast.")
      block <- as.matrix(forecast$mu_by_origin[[pos]])
      k <- sum(cap$grid$origin == unique(cap$grid$origin)[i])
      fpf_assert(nrow(block) >= k && ncol(block) >= max(cap$draw_columns), "Incomplete quantile draws.")
      block[seq_len(k), cap$draw_columns, drop = FALSE] * cap$location_scale + cap$location_center
    }))
  } else {
    e <- new.env(parent = globalenv())
    for (p in cap$helper_sources) {
      fpf_assert(p %in% cap$code_paths, "Unpinned helper source.")
      sys.source(p, envir = e)
    }
    ff <- if (is.null(d_forecaster)) getExportedValue("exdqlm", "exdqlmForecast") else d_forecaster
    fpf_assert(identical(fpf_function_sha(ff), cap$forecast_function_sha256), "Loaded dynamic forecast function differs from the frozen function.")
    fit_origin <- cap$fit
    previous <- 9000L
    q <- do.call(rbind, lapply(seq_along(unique(cap$grid$origin)), function(i) {
      origin <- unique(cap$grid$origin)[i]
      cfg <- cap$config
      fit_origin <<- if (identical(cfg$state_update_strategy, "incremental_teacher_forced"))
        e$ffv2_advance_fit_between_source_origins(fit_origin, cfg, cap$data, previous, origin) else
        e$ffv2_extend_fit_to_source_origin(cap$fit, cfg, cap$data, origin)
      previous <<- origin
      k <- sum(cap$grid$origin == origin)
      future <- e$ffv2_make_future_model_arrays(fit_origin$model, k)
      pred <- ff(start.t = length(fit_origin$y), k = k, m1 = fit_origin,
        fFF = future$fFF, fGG = future$fGG, plot = FALSE, return.draws = TRUE,
        n.samp = cap$n_response_draws, seed = cap$seed + i)
      e$ffv2_latent_forecast_draws(pred, cap$n_metric_draws, cap$seed + 100000L + i)
    }))
  }
  fpf_score_paths(q, cap$grid, cap$y, cap$oracle, cap$p,
    chain = cap$chain_id, source_draw_index = cap$source_draw_index)
}
fpf_run_task <- function(task, capsule_path, capsule_sha256, output) {
  fpf_assert(file.exists(capsule_path), "Posterior capsule absent; no fit will be run.")
  fpf_assert(identical(fpf_sha(capsule_path), capsule_sha256), "Capsule hash mismatch.")
  reference <- fpf_read(task$metric_draws_path)
  fpf_assert(identical(fpf_sha(task$metric_draws_path), task$full_metric_draws_sha256), "Reference hash changed.")
  cap <- readRDS(capsule_path)
  fpf_assert(identical(fpf_sha(task$path), task$point_path_sha256), "Original target evidence changed.")
  original <- fpf_read(task$path)
  fpf_assert(length(cap$y) == nrow(original) && length(cap$oracle) == nrow(original) &&
    max(abs(cap$y - original$y)) <= 1e-6 && max(abs(cap$oracle - original$q_true)) <= 1e-6,
    "Capsule observations/oracle do not match the article source.")
  scores <- fpf_replay_capsule(cap, task)
  error <- fpf_verify_full(scores, reference)
  fpf_assert(identical(fpf_sha(capsule_path), capsule_sha256), "Recovered capsule was modified.")
  fpf_write(scores, file.path(output, "prefix_draws.csv.gz"))
  jsonlite::write_json(list(status = "VERIFIED", fit_calls = 0, max_full_draw_error = error,
    task_id = task$task_id, capsule_sha256 = capsule_sha256,
    reference_sha256 = task$full_metric_draws_sha256,
    prefix_draws_sha256 = fpf_sha(file.path(output, "prefix_draws.csv.gz"))),
    file.path(output, "task_status.json"), pretty = TRUE, auto_unbox = TRUE)
  invisible(scores)
}
fpf_run_pool <- function(tasks, capsules, output, workers = 1L, worker = fpf_run_task) {
  fpf_assert(workers == as.integer(workers) && workers >= 1L && workers <= 15L,
    "Explicit worker count must be between 1 and 15.")
  fpf_assert(all(c("task_id", "capsule_path", "capsule_sha256") %in% names(capsules)) &&
    !anyDuplicated(capsules$task_id) && nrow(capsules) > 0 &&
    all(capsules$task_id %in% tasks$task_id), "Invalid or empty recovered-capsule registry.")
  result <- parallel::mclapply(seq_len(nrow(capsules)), function(i) {
    c <- capsules[i, ]
    task <- tasks[tasks$task_id == c$task_id, ]
    root <- file.path(output, c$task_id)
    status_path <- file.path(root, "task_status.json")
    tryCatch({
      if (file.exists(status_path)) {
        old <- fpf_json(status_path)
        draws <- file.path(root, "prefix_draws.csv.gz")
        fpf_assert(identical(old$status, "VERIFIED") && identical(old$task_id, c$task_id) &&
          identical(old$reference_sha256, task$full_metric_draws_sha256) &&
          file.exists(draws) && identical(fpf_sha(draws), old$prefix_draws_sha256), "Invalid cached task output.")
        if ("metric_draws_path" %in% names(task))
          fpf_assert(file.exists(task$metric_draws_path) &&
            identical(fpf_sha(task$metric_draws_path), task$full_metric_draws_sha256), "Cached task reference has changed.")
        return(data.frame(task_id = c$task_id, status = "VERIFIED_REUSED", message = ""))
      }
      dir.create(root, recursive = TRUE, showWarnings = FALSE)
      lock <- file.path(root, "task.lock")
      fpf_assert(dir.create(lock, showWarnings = FALSE), "Task already locked.")
      on.exit(unlink(lock, recursive = TRUE), add = TRUE)
      worker(task, c$capsule_path, c$capsule_sha256, root)
      data.frame(task_id = c$task_id, status = "VERIFIED", message = "")
    }, error = function(e) data.frame(task_id = c$task_id, status = "FAILED_NO_REFIT", message = conditionMessage(e)))
  }, mc.cores = min(as.integer(workers), nrow(capsules)), mc.preschedule = FALSE, mc.set.seed = FALSE)
  answer <- do.call(rbind, result)
  fpf_write(answer, file.path(output, "pool_status.csv"))
  answer
}

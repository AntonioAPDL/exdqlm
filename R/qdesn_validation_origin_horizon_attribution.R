.qdesn_validation_oha_group_matrix <- function(values, groups) {
  values <- as.matrix(values)
  groups <- as.character(groups)
  levels <- unique(groups)
  index <- lapply(levels, function(value) which(groups == value))
  matrix_out <- do.call(rbind, lapply(index, function(idx) {
    colMeans(values[idx, , drop = FALSE])
  }))
  rownames(matrix_out) <- levels
  list(
    values = matrix_out,
    levels = levels,
    counts = vapply(index, length, integer(1L))
  )
}

.qdesn_validation_oha_metric_matrices <- function(q, q_true, y, tau, groups) {
  q <- as.matrix(q)
  q_true <- as.numeric(q_true)
  y <- as.numeric(y)
  error <- sweep(q, 1L, q_true, "-")
  check <- .qdesn_validation_metric_check_loss(
    matrix(y, nrow = length(y), ncol = ncol(q)), q, tau
  )
  list(
    forecast_mae = .qdesn_validation_oha_group_matrix(abs(error), groups),
    forecast_check_loss = .qdesn_validation_oha_group_matrix(check, groups),
    oracle_bias = .qdesn_validation_oha_group_matrix(error, groups),
    oracle_rmse = .qdesn_validation_oha_group_matrix(error^2, groups)
  )
}

.qdesn_validation_oha_draw_table <- function(metric_matrices, group_type,
                                               scope, chain_id, draw_id,
                                               source_draw_index) {
  template <- metric_matrices$forecast_mae
  n_group <- length(template$levels)
  n_draw <- ncol(template$values)
  out <- data.frame(
    scope = rep(scope, n_group * n_draw),
    group_type = rep(group_type, n_group * n_draw),
    group_value = rep(template$levels, each = n_draw),
    n_targets = rep(template$counts, each = n_draw),
    chain_id = rep(as.integer(chain_id), n_group * n_draw),
    draw_id = rep(as.integer(draw_id), times = n_group),
    source_draw_index = rep(as.integer(source_draw_index), times = n_group),
    forecast_mae = as.vector(t(metric_matrices$forecast_mae$values)),
    forecast_check_loss = as.vector(t(metric_matrices$forecast_check_loss$values)),
    oracle_bias = as.vector(t(metric_matrices$oracle_bias$values)),
    oracle_rmse = sqrt(as.vector(t(metric_matrices$oracle_rmse$values))),
    stringsAsFactors = FALSE
  )
  out
}

.qdesn_validation_oha_summary <- function(group_draws) {
  keys <- unique(group_draws[c("scope", "group_type", "group_value", "n_targets")])
  metrics <- c("forecast_mae", "forecast_check_loss", "oracle_bias", "oracle_rmse")
  rows <- vector("list", nrow(keys) * length(metrics))
  k <- 0L
  for (i in seq_len(nrow(keys))) {
    keep <- group_draws$scope == keys$scope[[i]] &
      group_draws$group_type == keys$group_type[[i]] &
      group_draws$group_value == keys$group_value[[i]]
    for (metric in metrics) {
      x <- as.numeric(group_draws[[metric]][keep])
      qs <- stats::quantile(x, c(0.025, 0.5, 0.975), names = FALSE,
                            type = 8, na.rm = TRUE)
      k <- k + 1L
      rows[[k]] <- data.frame(
        keys[i, , drop = FALSE], metric = metric,
        posterior_mean = mean(x), posterior_sd = stats::sd(x),
        cri_lower = qs[[1L]], posterior_median = qs[[2L]],
        cri_upper = qs[[3L]], cri_width = qs[[3L]] - qs[[1L]],
        n_draws = sum(is.finite(x)), stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows[seq_len(k)])
}

.qdesn_validation_oha_covariance <- function(metric_matrices, group_type, scope) {
  rows <- list()
  k <- 0L
  for (metric in c("forecast_mae", "forecast_check_loss")) {
    block <- metric_matrices[[metric]]
    covariance <- stats::cov(t(block$values))
    correlation <- suppressWarnings(stats::cor(t(block$values)))
    pair <- which(upper.tri(covariance, diag = TRUE), arr.ind = TRUE)
    k <- k + 1L
    rows[[k]] <- data.frame(
      scope = scope, group_type = group_type, metric = metric,
      group_i = block$levels[pair[, 1L]],
      group_j = block$levels[pair[, 2L]],
      group_i_index = pair[, 1L], group_j_index = pair[, 2L],
      separation = abs(pair[, 2L] - pair[, 1L]),
      covariance = covariance[pair], correlation = correlation[pair],
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

.qdesn_validation_oha_variance <- function(metric_matrices, group_type, scope) {
  rows <- lapply(c("forecast_mae", "forecast_check_loss"), function(metric) {
    block <- metric_matrices[[metric]]
    weights <- block$counts / sum(block$counts)
    aggregate <- as.numeric(crossprod(weights, block$values))
    total <- stats::var(aggregate)
    diagonal <- sum(weights^2 * apply(block$values, 1L, stats::var))
    covariance <- total - diagonal
    data.frame(
      scope = scope, group_type = group_type, metric = metric,
      n_groups = length(weights), n_targets = sum(block$counts),
      total_variance = total, diagonal_variance = diagonal,
      covariance_variance = covariance,
      covariance_fraction = if (is.finite(total) && total > 0) covariance / total else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

.qdesn_validation_oha_lag_summary <- function(covariance) {
  keys <- unique(covariance[c("scope", "group_type", "metric", "separation")])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    keep <- covariance$scope == keys$scope[[i]] &
      covariance$group_type == keys$group_type[[i]] &
      covariance$metric == keys$metric[[i]] &
      covariance$separation == keys$separation[[i]]
    data.frame(
      keys[i, , drop = FALSE], n_pairs = sum(keep),
      mean_covariance = mean(covariance$covariance[keep]),
      median_covariance = stats::median(covariance$covariance[keep]),
      mean_correlation = mean(covariance$correlation[keep]),
      median_correlation = stats::median(covariance$correlation[keep]),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

.qdesn_validation_oha_target_summary <- function(q, q_true, y, tau, grid) {
  q <- as.matrix(q)
  qs <- .qdesn_validation_dispersion_row_quantiles(q)
  q_mean <- rowMeans(q)
  q_sd <- if (requireNamespace("matrixStats", quietly = TRUE)) {
    matrixStats::rowSds(q)
  } else apply(q, 1L, stats::sd)
  draw_mae <- rowMeans(abs(sweep(q, 1L, q_true, "-")))
  draw_check <- rowMeans(.qdesn_validation_metric_check_loss(
    matrix(y, nrow = length(y), ncol = ncol(q)), q, tau
  ))
  data.frame(
    grid[c("origin_sequence_id", "forecast_origin_source_index", "forecast_lead",
           "target_source_index")], q_true = q_true, y = y,
    posterior_mean_q = q_mean, posterior_sd_q = q_sd,
    q_cri_lower = qs[, "q025"], q_cri_median = qs[, "q500"],
    q_cri_upper = qs[, "q975"], q_cri_width = qs[, "q975"] - qs[, "q025"],
    oracle_covered = q_true >= qs[, "q025"] & q_true <= qs[, "q975"],
    point_path_abs_error = abs(q_mean - q_true),
    posterior_mean_abs_error = draw_mae,
    mae_jensen_gap = draw_mae - abs(q_mean - q_true),
    point_path_check_loss = .qdesn_validation_metric_check_loss(y, q_mean, tau),
    posterior_mean_check_loss = draw_check,
    check_jensen_gap = draw_check -
      .qdesn_validation_metric_check_loss(y, q_mean, tau),
    stringsAsFactors = FALSE
  )
}

.qdesn_validation_oha_path_structure <- function(q, grid) {
  complete_origins <- names(which(table(grid$forecast_origin_source_index) ==
                                    max(table(grid$forecast_origin_source_index))))
  keep <- as.character(grid$forecast_origin_source_index) %in% complete_origins
  qb <- as.matrix(q[keep, , drop = FALSE])
  gb <- grid[keep, , drop = FALSE]
  centered <- sweep(qb, 1L, rowMeans(qb), "-")
  global <- colMeans(centered)
  origin <- .qdesn_validation_oha_group_matrix(
    centered, gb$forecast_origin_source_index
  )$values
  lead <- .qdesn_validation_oha_group_matrix(centered, gb$forecast_lead)$values
  origin_effect <- sweep(origin, 2L, global, "-")
  lead_effect <- sweep(lead, 2L, global, "-")
  origin_index <- match(as.character(gb$forecast_origin_source_index), rownames(origin))
  lead_index <- match(as.character(gb$forecast_lead), rownames(lead))
  residual <- centered - matrix(global, nrow(centered), ncol(centered), byrow = TRUE) -
    origin_effect[origin_index, , drop = FALSE] - lead_effect[lead_index, , drop = FALSE]
  total <- sum(centered^2)
  energies <- c(
    global_shift = nrow(centered) * sum(global^2),
    origin_main = length(unique(gb$forecast_lead)) * sum(origin_effect^2),
    lead_main = length(unique(gb$forecast_origin_source_index)) * sum(lead_effect^2),
    interaction = sum(residual^2)
  )
  data.frame(
    scope = "balanced_complete_origins", component = names(energies),
    sum_squares = as.numeric(energies), fraction = as.numeric(energies) / total,
    n_targets = nrow(centered), n_draws = ncol(centered),
    stringsAsFactors = FALSE
  )
}

.qdesn_validation_oha_parameter_associations <- function(group_draws, context) {
  parameters <- .qdesn_validation_dispersion_add_rhs_parameters(
    context$draw_parameters, context$fit, context$posterior_source_draw_index
  )
  fields <- intersect(c("beta_intercept", "beta_norm", "sigma", "gamma", "tau",
                        "c2", "lambda_mean", "lambda_min", "lambda_max"),
                      names(parameters))
  if (!length(fields)) return(data.frame(stringsAsFactors = FALSE))
  keys <- unique(group_draws[c("scope", "group_type", "group_value")])
  rows <- list()
  k <- 0L
  for (i in seq_len(nrow(keys))) {
    keep <- group_draws$scope == keys$scope[[i]] &
      group_draws$group_type == keys$group_type[[i]] &
      group_draws$group_value == keys$group_value[[i]]
    block <- group_draws[keep, , drop = FALSE]
    order <- match(block$source_draw_index, context$posterior_source_draw_index)
    for (field in fields) {
      x <- as.numeric(parameters[[field]][order])
      for (metric in c("forecast_mae", "forecast_check_loss")) {
        z <- as.numeric(block[[metric]])
        ok <- is.finite(x) & is.finite(z)
        k <- k + 1L
        rows[[k]] <- data.frame(
          keys[i, , drop = FALSE], parameter = field, metric = metric,
          pearson = if (sum(ok) > 2L && stats::sd(x[ok]) > 0 && stats::sd(z[ok]) > 0) {
            stats::cor(x[ok], z[ok])
          } else NA_real_,
          spearman = if (sum(ok) > 2L && stats::sd(x[ok]) > 0 && stats::sd(z[ok]) > 0) {
            suppressWarnings(stats::cor(x[ok], z[ok], method = "spearman"))
          } else NA_real_,
          n = sum(ok), stringsAsFactors = FALSE
        )
      }
    }
  }
  do.call(rbind, rows)
}

.qdesn_validation_origin_horizon_artifacts <- function(draws, defaults = NULL) {
  context <- attr(draws, "metric_dispersion_context")
  if (is.null(context)) {
    stop("Origin-horizon attribution requires metric-dispersion context.",
         call. = FALSE)
  }
  q <- as.matrix(context$native_q)
  grid <- as.data.frame(context$grid, stringsAsFactors = FALSE)
  q_true <- as.numeric(context$q_true)
  y <- as.numeric(context$y)
  tau <- as.numeric(context$tau)[1L]
  if (!identical(nrow(q), 1000L) || ncol(q) != nrow(draws) || nrow(grid) != 1000L) {
    stop("Origin-horizon attribution requires 1,000 aligned targets and metric draws.",
         call. = FALSE)
  }
  grid$lead_band <- cut(
    as.integer(grid$forecast_lead), breaks = c(0, 5, 10, 15, 20, 25, 30),
    labels = c("01-05", "06-10", "11-15", "16-20", "21-25", "26-30")
  )
  cfg <- .qdesn_validation_origin_horizon_cfg(defaults)
  scopes <- list(all_targets = seq_len(nrow(grid)))
  if (isTRUE(cfg$balanced_complete_origins)) {
    counts <- table(grid$forecast_origin_source_index)
    complete <- names(counts[counts == max(counts)])
    scopes$balanced_complete_origins <- which(
      as.character(grid$forecast_origin_source_index) %in% complete
    )
  }
  draw_tables <- list()
  covariance <- list()
  variance <- list()
  k <- 0L
  for (scope in names(scopes)) {
    idx <- scopes[[scope]]
    for (group_type in c("all", "origin", "lead", "lead_band")) {
      groups <- switch(group_type,
        all = rep("all", length(idx)),
        origin = grid$forecast_origin_source_index[idx],
        lead = grid$forecast_lead[idx],
        lead_band = grid$lead_band[idx]
      )
      matrices <- .qdesn_validation_oha_metric_matrices(
        q[idx, , drop = FALSE], q_true[idx], y[idx], tau, groups
      )
      k <- k + 1L
      draw_tables[[k]] <- .qdesn_validation_oha_draw_table(
        matrices, group_type, scope, draws$chain_id[[1L]], draws$draw_id,
        context$posterior_source_draw_index
      )
      covariance[[k]] <- if (group_type != "all") {
        .qdesn_validation_oha_covariance(matrices, group_type, scope)
      } else NULL
      variance[[k]] <- .qdesn_validation_oha_variance(
        matrices, group_type, scope
      )
    }
  }
  group_draws <- do.call(rbind, draw_tables)
  covariance <- do.call(rbind, Filter(Negate(is.null), covariance))
  variance <- do.call(rbind, variance)
  reconstruction <- do.call(rbind, lapply(c("origin", "lead"), function(axis) {
    block <- group_draws[group_draws$scope == "all_targets" &
                           group_draws$group_type == axis, , drop = FALSE]
    split <- split(block, block$group_value)
    counts <- vapply(split, function(x) x$n_targets[[1L]], numeric(1L))
    weights <- counts / sum(counts)
    mae <- Reduce(`+`, Map(function(x, w) x$forecast_mae * w, split, weights))
    check <- Reduce(`+`, Map(function(x, w) x$forecast_check_loss * w, split, weights))
    data.frame(
      group_type = axis,
      forecast_mae_max_abs_error = max(abs(mae - draws$forecast_mae)),
      forecast_check_max_abs_error = max(abs(check - draws$forecast_check_loss)),
      tolerance = 1e-6,
      pass = max(abs(mae - draws$forecast_mae),
                 abs(check - draws$forecast_check_loss)) <= 1e-6,
      stringsAsFactors = FALSE
    )
  }))
  list(
    group_draws = group_draws,
    group_summary = .qdesn_validation_oha_summary(group_draws),
    covariance = covariance,
    covariance_lag_summary = .qdesn_validation_oha_lag_summary(covariance),
    variance_decomposition = variance,
    target_summary = .qdesn_validation_oha_target_summary(q, q_true, y, tau, grid),
    path_structure = .qdesn_validation_oha_path_structure(q, grid),
    parameter_associations = .qdesn_validation_oha_parameter_associations(
      group_draws[group_draws$scope == "all_targets", , drop = FALSE], context
    ),
    reconstruction_audit = reconstruction
  )
}

.qdesn_validation_write_origin_horizon_attribution <- function(draws, method_dir,
                                                                defaults = NULL) {
  cfg <- .qdesn_validation_origin_horizon_cfg(defaults)
  if (!isTRUE(cfg$enabled)) return(list(status = "DISABLED"))
  artifacts <- .qdesn_validation_origin_horizon_artifacts(draws, defaults)
  table_dir <- file.path(method_dir, "tables")
  manifest_dir <- file.path(method_dir, "manifest")
  dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(manifest_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- c(
    group_draws = file.path(table_dir, "origin_horizon_group_draws.csv.gz"),
    group_summary = file.path(table_dir, "origin_horizon_group_summary.csv"),
    covariance = file.path(table_dir, "origin_horizon_covariance.csv.gz"),
    covariance_lag_summary = file.path(table_dir, "origin_horizon_covariance_lag_summary.csv"),
    variance_decomposition = file.path(table_dir, "origin_horizon_variance_decomposition.csv"),
    target_summary = file.path(table_dir, "origin_horizon_target_summary.csv.gz"),
    path_structure = file.path(table_dir, "origin_horizon_path_structure.csv"),
    parameter_associations = file.path(table_dir, "origin_horizon_parameter_associations.csv.gz"),
    reconstruction_audit = file.path(table_dir, "origin_horizon_reconstruction_audit.csv")
  )
  for (name in names(paths)) {
    path <- paths[[name]]
    if (grepl("[.]gz$", path)) {
      con <- gzfile(path, open = "wt")
      tryCatch(utils::write.csv(artifacts[[name]], con, row.names = FALSE, na = ""),
               finally = close(con))
    } else {
      .qdesn_validation_write_df(artifacts[[name]], path)
    }
  }
  sha <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)
  status <- if (all(artifacts$reconstruction_audit$pass)) "PASS" else "FAIL"
  manifest_path <- file.path(manifest_dir, "origin_horizon_attribution_manifest.json")
  manifest <- list(
    schema_version = cfg$schema_version,
    generated_at = as.character(Sys.time()),
    status = status,
    estimand = "posterior_distribution_of_draw_specific_group_risk",
    article_metric_unchanged = TRUE,
    full_forecast_draw_matrix_retained = FALSE,
    balanced_complete_origin_sensitivity = cfg$balanced_complete_origins,
    reconstruction_tolerance = 1e-6,
    artifact_paths = lapply(paths, normalizePath, winslash = "/", mustWork = TRUE),
    artifact_sha256 = lapply(paths, sha),
    artifact_rows = lapply(artifacts, nrow)
  )
  .qdesn_validation_write_json(manifest_path, manifest)
  list(
    status = status,
    manifest_path = normalizePath(manifest_path, winslash = "/", mustWork = TRUE),
    manifest_sha256 = sha(manifest_path),
    paths = as.list(paths)
  )
}

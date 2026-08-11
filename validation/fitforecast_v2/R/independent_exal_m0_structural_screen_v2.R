qdesn_ssv2_stage <- "qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_structural_screen_v2"
qdesn_ssv2_method_id <- "m0_v_collapsed_support_logit"
qdesn_ssv2_registry_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
qdesn_ssv2_virtual_seed <- 260809L
qdesn_ssv2_virtual_size <- 50000L
qdesn_ssv2_exogenous_readout_columns <- 6L
qdesn_ssv2_max_effective_readout_dimension <- 900L
qdesn_ssv2_profile_fields <- c(
  "D", "n", "n_tilde", "m", "alpha", "rho", "pi_w", "pi_in", "rhs_tau0",
  "readout_y_lags", "reservoir_lags", "washout", "layer_shape", "alpha_pattern",
  "rho_pattern", "expected_degree", "total_states", "max_alpha", "min_alpha",
  "mean_alpha", "max_rho", "min_rho", "mean_rho", "design_role", "selection_arm",
  "profile_signature", "target_cell_id", "family", "tau", "priority",
  "objective_metric", "current_value", "comparator_value", "parent_anchor_id",
  "candidate_id", "screening_profile_id", "effective_readout_dimension"
)

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

qdesn_ssv2_repo_root <- function() {
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                winslash = "/", mustWork = TRUE)
}

qdesn_ssv2_path <- function(repo_root, ..., must_work = FALSE) {
  normalizePath(file.path(repo_root, ...), winslash = "/",
                mustWork = isTRUE(must_work))
}

qdesn_ssv2_rel <- function(path, repo_root) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  prefix <- paste0("^", gsub("([].[^$*+?{}|()\\\\])", "\\\\\\1", repo_root), "/?")
  sub(prefix, "", path)
}

qdesn_ssv2_sha256 <- function(path) {
  if (!file.exists(path)) return(NA_character_)
  unname(tools::sha256sum(path))
}

qdesn_ssv2_read_csv <- function(path) {
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}

qdesn_ssv2_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

qdesn_ssv2_read_json <- function(path) {
  jsonlite::read_json(path, simplifyVector = TRUE)
}

qdesn_ssv2_write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE,
                       null = "null", digits = NA)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

qdesn_ssv2_safe <- function(x) {
  x <- tolower(as.character(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  gsub("^_|_$", "", x)
}

qdesn_ssv2_vec <- function(x, mode = c("numeric", "integer")) {
  mode <- match.arg(mode)
  if (is.null(x) || !length(x) || all(is.na(x))) return(if (mode == "integer") integer() else numeric())
  if (length(x) == 1L && is.character(x) && !nzchar(trimws(x))) {
    return(if (mode == "integer") integer() else numeric())
  }
  if (length(x) == 1L && is.character(x)) x <- strsplit(x, ";", fixed = TRUE)[[1L]]
  if (mode == "integer") as.integer(x) else as.numeric(x)
}

qdesn_ssv2_pack <- function(x) paste(format(x, scientific = FALSE, trim = TRUE, digits = 12), collapse = ";")

qdesn_ssv2_profile_field <- function(value) {
  if (is.null(value) || !length(value) || all(is.na(value))) return("")
  if (is.list(value)) value <- unlist(value, recursive = TRUE, use.names = FALSE)
  if (!length(value)) return("")
  if (length(value) > 1L) return(qdesn_ssv2_pack(value))
  value[[1L]]
}

qdesn_ssv2_profile_from_job <- function(job) {
  if (is.null(job$profile) || !is.list(job$profile) || !length(job$profile)) {
    stop("Job JSON has no usable profile object.", call. = FALSE)
  }
  values <- lapply(job$profile, qdesn_ssv2_profile_field)
  x <- as.data.frame(values, stringsAsFactors = FALSE, check.names = FALSE)
  x$candidate_id <- as.character(job$candidate_id %||% "")
  x$target_cell_id <- as.character(job$target_cell_id %||% "")
  x <- qdesn_ssv2_ensure_effective_dimension(x)
  missing <- setdiff(qdesn_ssv2_profile_fields, names(x))
  for (field in missing) x[[field]] <- NA
  x[, qdesn_ssv2_profile_fields, drop = FALSE]
}

qdesn_ssv2_resolve_stage_repeats <- function(x, stage_order) {
  required <- c("stage", "job_id", "target_cell_id", "candidate_id", "source_id",
                "objective_metric")
  missing <- setdiff(required, names(x))
  if (length(missing)) {
    stop(sprintf("Stage results are missing: %s", paste(missing, collapse = ", ")),
         call. = FALSE)
  }
  stage_order <- unique(as.character(stage_order))
  stage_rank <- match(x$stage, stage_order)
  if (anyNA(stage_rank)) {
    stop("Stage results contain a stage outside stage_order.", call. = FALSE)
  }
  chain_id <- if ("chain_id" %in% names(x)) x$chain_id else rep(1L, nrow(x))
  key_fields <- data.frame(
    target_cell_id = x$target_cell_id,
    candidate_id = x$candidate_id,
    source_id = x$source_id,
    objective_metric = x$objective_metric,
    chain_id = chain_id,
    stringsAsFactors = FALSE
  )
  key <- do.call(paste, c(key_fields, sep = "\r"))
  stage_key <- paste(x$stage, key, sep = "\r")
  if (anyDuplicated(stage_key)) {
    stop("A stage contains duplicate candidate/source/metric/chain observations.",
         call. = FALSE)
  }

  order_index <- order(stage_rank, seq_len(nrow(x)))
  ordered <- x[order_index, , drop = FALSE]
  ordered_key <- key[order_index]
  keep <- !duplicated(ordered_key, fromLast = TRUE)
  kept <- ordered[keep, , drop = FALSE]
  superseded <- ordered[!keep, , drop = FALSE]

  if (nrow(superseded)) {
    retained_index <- match(ordered_key[!keep], ordered_key[keep])
    retained <- kept[retained_index, , drop = FALSE]
    ledger <- data.frame(
      target_cell_id = superseded$target_cell_id,
      candidate_id = superseded$candidate_id,
      source_id = superseded$source_id,
      objective_metric = superseded$objective_metric,
      chain_id = if ("chain_id" %in% names(superseded)) superseded$chain_id else 1L,
      superseded_stage = superseded$stage,
      superseded_job_id = superseded$job_id,
      superseded_objective_value = superseded$objective_value,
      retained_stage = retained$stage,
      retained_job_id = retained$job_id,
      retained_objective_value = retained$objective_value,
      resolution = "latest_stage_supersedes_earlier_repeat",
      stringsAsFactors = FALSE
    )
  } else {
    ledger <- data.frame(
      target_cell_id = character(), candidate_id = character(), source_id = character(),
      objective_metric = character(), chain_id = integer(), superseded_stage = character(),
      superseded_job_id = character(), superseded_objective_value = numeric(),
      retained_stage = character(), retained_job_id = character(),
      retained_objective_value = numeric(), resolution = character(),
      stringsAsFactors = FALSE
    )
  }
  rownames(kept) <- rownames(ledger) <- NULL
  list(results = kept, ledger = ledger)
}

qdesn_ssv2_effective_readout_dimension <- function(n, n_tilde, reservoir_lags,
                                                    readout_y_lags) {
  n <- qdesn_ssv2_vec(n, "integer")
  n_tilde <- qdesn_ssv2_vec(n_tilde, "integer")
  if (!length(n)) stop("At least one DESN layer size is required.", call. = FALSE)
  state_width <- sum(n_tilde) + utils::tail(n, 1L)
  as.integer(
    state_width * (as.integer(reservoir_lags) + 1L) +
      as.integer(readout_y_lags) + qdesn_ssv2_exogenous_readout_columns
  )
}

qdesn_ssv2_ensure_effective_dimension <- function(x) {
  if (!nrow(x)) {
    x$effective_readout_dimension <- integer()
    return(x)
  }
  x$effective_readout_dimension <- vapply(seq_len(nrow(x)), function(i) {
    qdesn_ssv2_effective_readout_dimension(
      x$n[[i]], x$n_tilde[[i]], x$reservoir_lags[[i]], x$readout_y_lags[[i]]
    )
  }, integer(1L))
  x
}

qdesn_ssv2_profile_signature <- function(x) {
  fields <- c("D", "n", "n_tilde", "m", "alpha", "rho", "pi_w", "pi_in",
              "rhs_tau0", "readout_y_lags", "reservoir_lags", "washout")
  paste(vapply(fields, function(nm) qdesn_ssv2_pack(x[[nm]] %||% NA), character(1L)),
        collapse = "|")
}

qdesn_ssv2_gap_path <- function(repo_root) {
  qdesn_ssv2_path(
    repo_root, "validation", "fitforecast_v2", "promotions",
    "qdesn_dqlm_500obs_trainonly_article_v4_exal_m0_20260809",
    "remaining_gap_ledger.csv", must_work = TRUE
  )
}

qdesn_ssv2_parent_request_path <- function(repo_root, anchor_id) {
  qdesn_ssv2_path(
    repo_root, "config", "validation",
    "qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_relaunch_v1_frozen_requests",
    paste0(anchor_id, ".json"), must_work = TRUE
  )
}

qdesn_ssv2_targets <- function(repo_root) {
  gap <- qdesn_ssv2_read_csv(qdesn_ssv2_gap_path(repo_root))
  gap <- gap[is.finite(gap$gap_percent_after) & gap$gap_percent_after > 0, , drop = FALSE]
  key <- paste(gap$family, sprintf("%.2f", gap$tau), sep = "|")
  split_gap <- split(gap, key)
  rows <- lapply(split_gap, function(cell) {
    primary <- cell[which.max(cell$gap_percent_after), , drop = FALSE]
    priority <- if (any(cell$priority == "PRIMARY_LOWER_QUANTILE")) {
      "primary_lower_quantile"
    } else {
      "secondary_median"
    }
    data.frame(
      target_cell_id = sprintf("%s_t%s", cell$family[[1L]],
                               sub("[.]", "p", sprintf("%.2f", cell$tau[[1L]]))),
      family = cell$family[[1L]],
      tau = as.numeric(cell$tau[[1L]]),
      priority = priority,
      objective_metric = as.character(primary$metric_role[[1L]]),
      current_value = as.numeric(primary$selected_value[[1L]]),
      comparator_model = as.character(primary$best_model_after[[1L]]),
      comparator_value = as.numeric(primary$best_value_after[[1L]]),
      current_gap_percent = as.numeric(primary$gap_percent_after[[1L]]),
      parent_anchor_id = as.character(primary$anchor_id[[1L]]),
      companion_metrics = paste(sort(unique(cell$metric_role)), collapse = ";"),
      designs_wave1 = if (priority == "primary_lower_quantile") 16L else 8L,
      survivors_wave2 = if (priority == "primary_lower_quantile") 8L else 4L,
      adaptive_wave3 = if (priority == "primary_lower_quantile") 4L else 2L,
      finalists_sealed = if (priority == "primary_lower_quantile") 2L else 1L,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out <- out[order(out$priority != "primary_lower_quantile", -out$current_gap_percent,
                   out$target_cell_id), , drop = FALSE]
  rownames(out) <- NULL
  if (nrow(out) != 7L || sum(out$designs_wave1) != 96L ||
      sum(out$survivors_wave2) != 48L || sum(out$adaptive_wave3) != 24L ||
      sum(out$finalists_sealed) != 12L) {
    stop("The structural-screen target/count contract has drifted.", call. = FALSE)
  }
  out$parent_request_path <- vapply(
    out$parent_anchor_id, qdesn_ssv2_parent_request_path, character(1L),
    repo_root = repo_root
  )
  out$parent_request_sha256 <- vapply(out$parent_request_path, qdesn_ssv2_sha256,
                                      character(1L))
  out
}

.qdesn_ssv2_layer_sizes <- function(total, D, shape) {
  weights <- switch(
    shape,
    constant = rep(1, D),
    tapered = seq(1.35, 0.65, length.out = D),
    expanding = seq(0.65, 1.35, length.out = D),
    bottleneck = if (D == 1L) 1 else c(1.25, rep(0.55, max(0, D - 2L)), 1.25),
    rep(1, D)
  )
  n <- pmax(4L, as.integer(round(total * weights / sum(weights))))
  delta <- as.integer(total - sum(n))
  if (delta != 0L) n[[which.max(n)]] <- max(4L, n[[which.max(n)]] + delta)
  n
}

.qdesn_ssv2_layer_pattern <- function(base, D, pattern, lower, upper, spread) {
  if (D == 1L || pattern == "constant") return(rep(min(upper, max(lower, base)), D))
  offsets <- seq(-spread, spread, length.out = D)
  if (pattern == "fast_to_slow") offsets <- rev(offsets)
  if (pattern == "multiscale") offsets <- rep(c(-spread, spread), length.out = D)
  pmin(upper, pmax(lower, base + offsets))
}

.qdesn_ssv2_profile_row <- function(D, n, m, alpha, rho, degree, tau0,
                                    readout_y_lags, reservoir_lags, washout,
                                    layer_shape, alpha_pattern, rho_pattern,
                                    design_role, selection_arm) {
  n <- as.integer(n)
  n_tilde <- if (D > 1L) n[2:D] else integer()
  input_dims <- c(m + 6L, if (D > 1L) n_tilde else integer())
  pi_w <- pmin(1, degree / n)
  input_degree <- pmin(degree, pmax(2, round(sqrt(input_dims))))
  pi_in <- pmin(1, input_degree / input_dims)
  row <- data.frame(
    D = as.integer(D), n = qdesn_ssv2_pack(n), n_tilde = qdesn_ssv2_pack(n_tilde),
    m = as.integer(m), alpha = qdesn_ssv2_pack(alpha), rho = qdesn_ssv2_pack(rho),
    pi_w = qdesn_ssv2_pack(pi_w), pi_in = qdesn_ssv2_pack(pi_in),
    rhs_tau0 = as.numeric(tau0), readout_y_lags = as.integer(readout_y_lags),
    reservoir_lags = as.integer(reservoir_lags), washout = as.integer(washout),
    layer_shape = layer_shape, alpha_pattern = alpha_pattern, rho_pattern = rho_pattern,
    expected_degree = as.integer(degree), total_states = sum(n),
    effective_readout_dimension = qdesn_ssv2_effective_readout_dimension(
      n, n_tilde, reservoir_lags, readout_y_lags
    ),
    max_alpha = max(alpha), min_alpha = min(alpha), mean_alpha = mean(alpha),
    max_rho = max(rho), min_rho = min(rho), mean_rho = mean(rho),
    design_role = design_role, selection_arm = selection_arm,
    stringsAsFactors = FALSE
  )
  row$profile_signature <- qdesn_ssv2_profile_signature(row[1L, , drop = FALSE])
  row
}

qdesn_ssv2_virtual_universe <- function(n = qdesn_ssv2_virtual_size,
                                        seed = qdesn_ssv2_virtual_seed) {
  set.seed(seed)
  alpha_explicit <- c(.001, .01, .05, .10, .20, .40, .60, .80, .90,
                      .95, .98, .99, .995, .999)
  rho_explicit <- c(.10, .25, .40, .60, .75, .85, .90, .95, .98, .995)
  m_levels <- c(1L, 5L, 15L, 30L, 45L, 60L, 90L, 120L, 150L)
  m_probs <- c(.03, .04, .08, .16, .18, .12, .22, .09, .08)
  out <- vector("list", n)
  for (i in seq_len(n)) {
    D <- sample(1:4, 1L, prob = c(.10, .38, .37, .15))
    boundary <- stats::runif(1) < .10
    total <- if (boundary) sample(c(20L, 500L, 600L), 1L) else {
      as.integer(round(exp(stats::runif(1, log(30), log(420)))))
    }
    shape <- sample(c("constant", "tapered", "expanding", "bottleneck"), 1L)
    n_vec <- .qdesn_ssv2_layer_sizes(total, D, shape)
    stratum <- sample(1:5, 1L, prob = c(.15, .15, .25, .25, .20))
    bounds <- list(c(.001, .10), c(.10, .40), c(.40, .80), c(.80, .95), c(.95, .999))[[stratum]]
    alpha_base <- if (stats::runif(1) < .55) {
      sample(alpha_explicit[alpha_explicit >= bounds[[1L]] & alpha_explicit <= bounds[[2L]]], 1L)
    } else stats::runif(1, bounds[[1L]], bounds[[2L]])
    alpha_pattern <- sample(c("constant", "fast_to_slow", "slow_to_fast", "multiscale"), 1L,
                            prob = c(.30, .25, .25, .20))
    alpha <- .qdesn_ssv2_layer_pattern(alpha_base, D, alpha_pattern, .0005, .999,
                                       min(.30, max(.02, alpha_base * .45)))
    rho_base <- if (stats::runif(1) < .55) sample(rho_explicit, 1L) else stats::runif(1, .10, .995)
    rho_pattern <- sample(c("constant", "fast_to_slow", "slow_to_fast", "multiscale"), 1L,
                          prob = c(.35, .25, .25, .15))
    rho <- .qdesn_ssv2_layer_pattern(rho_base, D, rho_pattern, .05, .995, .18)
    degree <- sample(c(2L, 4L, 8L, 16L), 1L)
    capacity_penalty <- .45 * log10(max(1, sum(n_vec) / 20))
    tau0 <- 10^stats::runif(1, -8, -3.52 - capacity_penalty / 3)
    out[[i]] <- .qdesn_ssv2_profile_row(
      D, n_vec, sample(m_levels, 1L, prob = m_probs), alpha, rho, degree, tau0,
      sample(c(1L, 2L, 3L, 6L, 12L), 1L, prob = c(.25, .2, .2, .2, .15)),
      sample(0:3, 1L, prob = c(.45, .25, .18, .12)),
      sample(c(90L, 180L, 300L, 450L), 1L, prob = c(.10, .20, .45, .25)),
      shape, alpha_pattern, rho_pattern, "virtual_universe", "broad"
    )
  }
  ans <- do.call(rbind, out)
  ans$virtual_id <- sprintf("v%05d", seq_len(nrow(ans)))
  ans <- ans[!duplicated(ans$profile_signature), , drop = FALSE]
  rownames(ans) <- NULL
  ans
}

qdesn_ssv2_history_ledger <- function(repo_root) {
  files <- list.files(qdesn_ssv2_path(repo_root, "config", "validation"),
                      pattern = "profiles[.]csv$", recursive = TRUE, full.names = TRUE)
  files <- files[!grepl(qdesn_ssv2_stage, files, fixed = TRUE)]
  rows <- list()
  k <- 0L
  for (path in files) {
    x <- tryCatch(qdesn_ssv2_read_csv(path), error = function(e) NULL)
    if (is.null(x) || !nrow(x) || !all(c("D", "m") %in% names(x))) next
    n_field <- if ("n" %in% names(x)) "n" else if ("n_each" %in% names(x)) "n_each" else NA_character_
    if (is.na(n_field) || !all(c("alpha", "rho", "pi_w", "pi_in") %in% names(x))) next
    for (i in seq_len(nrow(x))) {
      D <- suppressWarnings(as.integer(x$D[[i]]))
      if (!is.finite(D) || D < 1L) next
      n_vec <- qdesn_ssv2_vec(x[[n_field]][[i]], "integer")
      if (!length(n_vec)) next
      if (length(n_vec) == 1L) n_vec <- rep(n_vec, D)
      if (length(n_vec) != D) next
      expand <- function(value) {
        z <- qdesn_ssv2_vec(value)
        if (length(z) == 1L) z <- rep(z, D)
        z
      }
      alpha <- expand(x$alpha[[i]]); rho <- expand(x$rho[[i]])
      pi_w <- expand(x$pi_w[[i]]); pi_in <- expand(x$pi_in[[i]])
      if (any(vapply(list(alpha, rho, pi_w, pi_in), length, integer(1L)) != D)) next
      tau0 <- if ("rhs_tau0" %in% names(x)) x$rhs_tau0[[i]] else 3e-4
      ylags <- if ("readout_y_lags" %in% names(x)) x$readout_y_lags[[i]] else x$m[[i]]
      rlags <- if ("reservoir_lags" %in% names(x)) x$reservoir_lags[[i]] else 0L
      washout <- if ("washout" %in% names(x)) x$washout[[i]] else 300L
      row <- .qdesn_ssv2_profile_row(
        D, n_vec, x$m[[i]], alpha, rho, max(1L, round(mean(pi_w * n_vec))),
        tau0, ylags, rlags, washout, "historical", "historical", "historical",
        "historical", "history"
      )
      row$pi_w <- qdesn_ssv2_pack(pi_w)
      row$pi_in <- qdesn_ssv2_pack(pi_in)
      row$profile_signature <- qdesn_ssv2_profile_signature(row)
      k <- k + 1L
      rows[[k]] <- data.frame(
        profile_signature = row$profile_signature,
        source_file = qdesn_ssv2_rel(path, repo_root),
        source_row = i,
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) return(data.frame(profile_signature = character(), source_file = character(), source_row = integer()))
  unique(do.call(rbind, rows))
}

.qdesn_ssv2_features <- function(x) {
  x <- qdesn_ssv2_ensure_effective_dimension(x)
  data.frame(
    D = as.numeric(x$D) / 4,
    states = log1p(as.numeric(x$total_states)) / log1p(600),
    m = log1p(as.numeric(x$m)) / log1p(150),
    alpha_mean = as.numeric(x$mean_alpha),
    alpha_range = as.numeric(x$max_alpha) - as.numeric(x$min_alpha),
    rho_mean = as.numeric(x$mean_rho),
    rho_range = as.numeric(x$max_rho) - as.numeric(x$min_rho),
    degree = log2(as.numeric(x$expected_degree)) / 4,
    tau0 = (pmax(-8, pmin(-3.5, log10(as.numeric(x$rhs_tau0)))) + 8) / 4.5,
    ylags = as.numeric(x$readout_y_lags) / 12,
    rlags = as.numeric(x$reservoir_lags) / 3,
    readout_dimension = as.numeric(x$effective_readout_dimension) /
      qdesn_ssv2_max_effective_readout_dimension,
    washout = as.numeric(x$washout) / 450
  )
}

.qdesn_ssv2_maximin <- function(pool, anchors, n_select, offset = 0L) {
  if (n_select <= 0L) return(pool[FALSE, , drop = FALSE])
  pool <- pool[!duplicated(pool$profile_signature), , drop = FALSE]
  if (nrow(pool) < n_select) stop("Insufficient unique maximin candidates.", call. = FALSE)
  pool <- pool[c(seq_len(nrow(pool)) + offset - 1L) %% nrow(pool) + 1L, , drop = FALSE]
  px <- as.matrix(.qdesn_ssv2_features(pool))
  ax <- if (nrow(anchors)) as.matrix(.qdesn_ssv2_features(anchors)) else matrix(.5, 1L, ncol(px))
  dmin <- rep(Inf, nrow(px))
  for (j in seq_len(nrow(ax))) {
    dmin <- pmin(dmin, rowSums((px - ax[j, ])^2))
  }
  keep <- integer(n_select)
  for (i in seq_len(n_select)) {
    pick <- which.max(dmin)
    keep[[i]] <- pick
    dmin <- pmin(dmin, rowSums((px - px[pick, ])^2))
    dmin[keep[seq_len(i)]] <- -Inf
  }
  pool[keep, , drop = FALSE]
}

.qdesn_ssv2_parent_profile <- function(request, role = "parent_control") {
  d <- request$config$desn
  D <- as.integer(d$D)
  n <- as.integer(d$n)
  if (length(n) == 1L) n <- rep(n, D)
  alpha <- as.numeric(d$alpha); if (length(alpha) == 1L) alpha <- rep(alpha, D)
  rho <- as.numeric(d$rho); if (length(rho) == 1L) rho <- rep(rho, D)
  pi_w <- as.numeric(d$pi_w); if (length(pi_w) == 1L) pi_w <- rep(pi_w, D)
  degree <- max(1L, round(mean(pi_w * n)))
  out <- .qdesn_ssv2_profile_row(
    D, n, d$m, alpha, rho, degree,
    request$config$inference$mcmc$priors$beta$rhs_ns$tau0,
    request$root_spec$readout_y_lags %||% request$config$lags$m_y,
    request$root_spec$reservoir_lags %||% request$config$readout$reservoir_lags,
    d$washout, "parent", "parent", "parent", role, "parent"
  )
  out$pi_w <- qdesn_ssv2_pack(pi_w)
  pi_in <- as.numeric(d$pi_in); if (length(pi_in) == 1L) pi_in <- rep(pi_in, D)
  out$pi_in <- qdesn_ssv2_pack(pi_in)
  out$profile_signature <- qdesn_ssv2_profile_signature(out)
  out
}

.qdesn_ssv2_local_profiles <- function(parent, n) {
  base_n <- qdesn_ssv2_vec(parent$n, "integer")
  base_alpha <- qdesn_ssv2_vec(parent$alpha)
  base_rho <- qdesn_ssv2_vec(parent$rho)
  designs <- list(
    list(D = 1L, n = max(12L, base_n[[1L]]), m = max(5L, parent$m), a = base_alpha[[1L]], r = base_rho[[1L]], deg = 2L),
    list(D = 2L, n = c(max(12L, base_n[[1L]] * 2L), max(10L, base_n[[1L]] * 2L)), m = max(15L, parent$m), a = c(base_alpha[[1L]], .40), r = c(base_rho[[1L]], .80), deg = 4L),
    list(D = 2L, n = c(30L, 20L), m = max(30L, parent$m), a = c(.20, .80), r = c(.65, .90), deg = 4L),
    list(D = 3L, n = c(40L, 30L, 20L), m = max(45L, parent$m), a = c(.10, .60, .95), r = c(.55, .80, .95), deg = 8L)
  )
  do.call(rbind, lapply(designs[seq_len(n)], function(z) .qdesn_ssv2_profile_row(
    z$D, z$n, z$m, z$a, z$r, z$deg, parent$rhs_tau0,
    parent$readout_y_lags, parent$reservoir_lags, max(parent$washout, 300L),
    "local", "multiscale", "multiscale", "local_structural_bridge", "local"
  )))
}

.qdesn_ssv2_transfer_profiles <- function(n) {
  designs <- list(
    list(D = 2L, n = c(20L, 20L), m = 90L, a = c(.30, .30), r = c(.85, .85), deg = 2L, tau = 1e-4),
    list(D = 2L, n = c(40L, 40L), m = 90L, a = c(.10, .10), r = c(.70, .70), deg = 2L, tau = 1e-4)
  )
  do.call(rbind, lapply(designs[seq_len(n)], function(z) .qdesn_ssv2_profile_row(
    z$D, z$n, z$m, z$a, z$r, z$deg, z$tau, 90L, 0L, 300L,
    "constant", "constant", "constant", "historical_transfer_control", "transfer"
  )))
}

qdesn_ssv2_select_wave1 <- function(repo_root, universe, history, targets) {
  universe <- qdesn_ssv2_ensure_effective_dimension(universe)
  universe$historical_exact <- universe$profile_signature %in% history$profile_signature
  eligible <- universe[
    !universe$historical_exact &
      universe$effective_readout_dimension <= qdesn_ssv2_max_effective_readout_dimension,
    , drop = FALSE
  ]
  selected <- list(); parents <- list(); k <- 0L
  for (i in seq_len(nrow(targets))) {
    target <- targets[i, , drop = FALSE]
    request <- qdesn_ssv2_read_json(target$parent_request_path[[1L]])
    parent <- .qdesn_ssv2_parent_profile(request)
    cell_eligible <- eligible[, names(parent), drop = FALSE]
    n_local <- if (target$priority == "primary_lower_quantile") 4L else 2L
    n_broad <- if (target$priority == "primary_lower_quantile") 8L else 4L
    n_boundary <- if (target$priority == "primary_lower_quantile") 2L else 1L
    n_transfer <- if (target$priority == "primary_lower_quantile") 2L else 1L
    local <- .qdesn_ssv2_local_profiles(parent, n_local)
    transfer <- .qdesn_ssv2_transfer_profiles(n_transfer)
    anchors <- rbind(parent, local, transfer)
    boundary_pool <- cell_eligible[
      cell_eligible$max_alpha >= .95 | cell_eligible$total_states >= 500L |
        cell_eligible$m >= 120L,
      , drop = FALSE
    ]
    boundary <- .qdesn_ssv2_maximin(boundary_pool, anchors, n_boundary, offset = i * 101L)
    boundary$selection_arm <- "boundary"
    boundary$design_role <- "high_alpha_or_capacity_boundary"
    used <- c(anchors$profile_signature, boundary$profile_signature)
    broad <- .qdesn_ssv2_maximin(
      cell_eligible[!cell_eligible$profile_signature %in% used, , drop = FALSE],
                                 rbind(anchors, boundary), n_broad, offset = i * 997L)
    broad$selection_arm <- "broad"
    broad$design_role <- "deterministic_maximin_random_subset"
    cell <- rbind(local, broad, boundary, transfer)
    if (nrow(cell) != target$designs_wave1[[1L]]) stop("Wave-1 quota drift.", call. = FALSE)
    cell$target_cell_id <- target$target_cell_id[[1L]]
    cell$family <- target$family[[1L]]
    cell$tau <- target$tau[[1L]]
    cell$priority <- target$priority[[1L]]
    cell$objective_metric <- target$objective_metric[[1L]]
    cell$current_value <- target$current_value[[1L]]
    cell$comparator_value <- target$comparator_value[[1L]]
    cell$parent_anchor_id <- target$parent_anchor_id[[1L]]
    cell$candidate_id <- sprintf(
      "ssv2_%s_%s_%02d_%s", qdesn_ssv2_safe(target$target_cell_id[[1L]]),
      cell$selection_arm, seq_len(nrow(cell)),
      substr(vapply(cell$profile_signature, digest::digest, character(1L), algo = "sha256", serialize = FALSE), 1L, 10L)
    )
    cell$screening_profile_id <- cell$candidate_id
    k <- k + 1L; selected[[k]] <- cell
    parent$target_cell_id <- target$target_cell_id[[1L]]
    parent$family <- target$family[[1L]]; parent$tau <- target$tau[[1L]]
    parent$priority <- target$priority[[1L]]; parent$objective_metric <- target$objective_metric[[1L]]
    parent$current_value <- target$current_value[[1L]]; parent$comparator_value <- target$comparator_value[[1L]]
    parent$parent_anchor_id <- target$parent_anchor_id[[1L]]
    parent$candidate_id <- paste0("ssv2_", qdesn_ssv2_safe(target$target_cell_id[[1L]]), "_parent")
    parent$screening_profile_id <- parent$candidate_id
    parents[[i]] <- parent
  }
  selected <- do.call(rbind, selected); parents <- do.call(rbind, parents)
  rownames(selected) <- rownames(parents) <- NULL
  if (nrow(selected) != 96L || nrow(parents) != 7L || anyDuplicated(selected$candidate_id)) {
    stop("Wave-1 selection is not the predeclared 96+7 contract.", call. = FALSE)
  }
  list(selected = selected, parents = parents)
}

qdesn_ssv2_repair_capacity <- function(profiles, universe, history, parents,
                                       max_dimension = qdesn_ssv2_max_effective_readout_dimension) {
  profiles <- qdesn_ssv2_ensure_effective_dimension(profiles)
  universe <- qdesn_ssv2_ensure_effective_dimension(universe)
  parents <- qdesn_ssv2_ensure_effective_dimension(parents)
  invalid <- which(profiles$effective_readout_dimension > max_dimension)
  repaired <- profiles
  chosen_signatures <- character()
  manifest <- vector("list", nrow(profiles))
  base_pool <- universe[
    universe$effective_readout_dimension <= max_dimension &
      !universe$profile_signature %in% history$profile_signature &
      !universe$profile_signature %in% profiles$profile_signature,
    , drop = FALSE
  ]
  base_features <- as.matrix(.qdesn_ssv2_features(base_pool))

  for (i in seq_len(nrow(profiles))) {
    old <- profiles[i, , drop = FALSE]
    if (!i %in% invalid) {
      manifest[[i]] <- data.frame(
        target_cell_id = old$target_cell_id, selection_arm = old$selection_arm,
        action = "retained_exact", predecessor_candidate_id = old$candidate_id,
        predecessor_profile_signature = old$profile_signature,
        predecessor_effective_readout_dimension = old$effective_readout_dimension,
        repaired_candidate_id = old$candidate_id,
        repaired_profile_signature = old$profile_signature,
        repaired_effective_readout_dimension = old$effective_readout_dimension,
        maximum_effective_readout_dimension = as.integer(max_dimension),
        stringsAsFactors = FALSE
      )
      next
    }

    pool_index <- which(!base_pool$profile_signature %in% chosen_signatures)
    if (identical(as.character(old$selection_arm), "boundary")) {
      pool_index <- pool_index[
        base_pool$max_alpha[pool_index] >= .95 |
          base_pool$total_states[pool_index] >= 500L |
          base_pool$m[pool_index] >= 120L
      ]
    }
    same_cell <- repaired$target_cell_id == old$target_cell_id &
      repaired$effective_readout_dimension <= max_dimension
    anchors <- rbind(
      parents[parents$target_cell_id == old$target_cell_id, , drop = FALSE],
      repaired[same_cell, , drop = FALSE]
    )
    offset <- qdesn_ssv2_seed(old$target_cell_id, old$selection_arm,
                              old$candidate_id, "capacity_repair_v1") %% length(pool_index)
    rotated <- pool_index[
      (seq_along(pool_index) + offset - 1L) %% length(pool_index) + 1L
    ]
    px <- base_features[rotated, , drop = FALSE]
    ax <- as.matrix(.qdesn_ssv2_features(anchors))
    dmin <- rep(Inf, nrow(px))
    for (j in seq_len(nrow(ax))) {
      dmin <- pmin(dmin, rowSums((px - ax[j, ])^2))
    }
    candidate <- base_pool[rotated[[which.max(dmin)]], , drop = FALSE]
    replacement <- old
    design_fields <- intersect(
      c("D", "n", "n_tilde", "m", "alpha", "rho", "pi_w", "pi_in",
        "rhs_tau0", "readout_y_lags", "reservoir_lags", "washout",
        "layer_shape", "alpha_pattern", "rho_pattern", "expected_degree",
        "total_states", "effective_readout_dimension", "max_alpha", "min_alpha",
        "mean_alpha", "max_rho", "min_rho", "mean_rho", "profile_signature"),
      names(candidate)
    )
    for (nm in design_fields) replacement[[nm]] <- candidate[[nm]][[1L]]
    replacement$design_role <- paste0("capacity_feasible_", old$selection_arm,
                                      "_maximin_replacement")
    replacement$selection_arm <- old$selection_arm
    hash <- substr(digest::digest(replacement$profile_signature[[1L]], algo = "sha256",
                                  serialize = FALSE), 1L, 10L)
    replacement$candidate_id <- sprintf(
      "ssv2_%s_capacityrepair_%s_%02d_%s",
      qdesn_ssv2_safe(old$target_cell_id), qdesn_ssv2_safe(old$selection_arm),
      match(i, invalid), hash
    )
    replacement$screening_profile_id <- replacement$candidate_id
    repaired[i, names(replacement)] <- replacement
    chosen_signatures <- c(chosen_signatures, replacement$profile_signature)
    manifest[[i]] <- data.frame(
      target_cell_id = old$target_cell_id, selection_arm = old$selection_arm,
      action = "replaced_above_capacity_contract",
      predecessor_candidate_id = old$candidate_id,
      predecessor_profile_signature = old$profile_signature,
      predecessor_effective_readout_dimension = old$effective_readout_dimension,
      repaired_candidate_id = replacement$candidate_id,
      repaired_profile_signature = replacement$profile_signature,
      repaired_effective_readout_dimension = replacement$effective_readout_dimension,
      maximum_effective_readout_dimension = as.integer(max_dimension),
      stringsAsFactors = FALSE
    )
  }

  manifest <- do.call(rbind, manifest)
  if (nrow(repaired) != nrow(profiles) || anyDuplicated(repaired$candidate_id) ||
      any(repaired$effective_readout_dimension > max_dimension)) {
    stop("Capacity repair violated the frozen design contract.", call. = FALSE)
  }
  list(profiles = repaired, ledger = manifest)
}

qdesn_ssv2_stage_source_window <- function(root_row, source_id, m, washout,
                                           output_root) {
  m <- as.integer(m); washout <- as.integer(washout)
  raw_start <- 8501L - m - washout
  raw_end <- 10000L
  if (raw_start < 1L) stop("Source window exceeds TT_main.", call. = FALSE)
  source <- qdesn_ssv2_read_csv(root_row$series_wide_path[[1L]])
  idx <- raw_start:raw_end
  source <- source[idx, , drop = FALSE]
  source$t <- seq_len(nrow(source))
  dir <- file.path(output_root, source_id, root_row$family[[1L]],
                   sprintf("tau_%s", sub("[.]", "p", sprintf("%.2f", root_row$tau[[1L]]))),
                   sprintf("m%d_w%d", m, washout))
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  series_path <- qdesn_ssv2_write_csv(source, file.path(dir, "series_wide.csv"))
  selection <- data.frame(t = seq_len(nrow(source)), source_index = idx)
  selection_path <- qdesn_ssv2_write_csv(selection, file.path(dir, "selection_indices.csv"))
  phase1 <- 2 * pi * idx / 90
  phase2 <- 4 * pi * idx / 90
  trend <- (idx - mean(idx)) / stats::sd(idx)
  observed <- data.frame(
    y = source$y, period90_sin_h1 = sin(phase1), period90_cos_h1 = cos(phase1),
    period90_sin_h2 = sin(phase2), period90_cos_h2 = cos(phase2),
    period90_trend_z = trend, stringsAsFactors = FALSE
  )
  observed_path <- qdesn_ssv2_write_csv(observed, file.path(dir, "observed.csv"))
  qtrue_path <- qdesn_ssv2_write_csv(data.frame(
    t = seq_len(nrow(source)), source_index = idx, q_true = source$q_target,
    y = source$y, mu = source$mu
  ), file.path(dir, "q_true.csv"))
  data.frame(
    source_id = source_id, source_role = root_row$source_role[[1L]],
    scenario = root_row$scenario[[1L]], family = root_row$family[[1L]],
    tau = root_row$tau[[1L]], m = m, washout = washout,
    raw_start_source_index = raw_start, raw_end_source_index = raw_end,
    train_start_source_index = 8501L, train_end_source_index = 9000L,
    forecast_start_source_index = 9001L, forecast_end_source_index = 10000L,
    source_total_size = nrow(source), source_series_wide_path = series_path,
    source_series_wide_sha256 = qdesn_ssv2_sha256(series_path),
    source_selection_indices_path = selection_path,
    source_selection_indices_sha256 = qdesn_ssv2_sha256(selection_path),
    source_sim_path = root_row$sim_output_path[[1L]],
    source_sim_sha256 = root_row$sim_output_sha256[[1L]],
    observed_path = observed_path, observed_sha256 = qdesn_ssv2_sha256(observed_path),
    qtrue_path = qtrue_path, qtrue_sha256 = qdesn_ssv2_sha256(qtrue_path),
    stringsAsFactors = FALSE
  )
}

qdesn_ssv2_budget <- function(stage) {
  switch(stage,
    smoke = list(n_burn = 4L, n_mcmc = 4L, draws = 4L),
    calibration = list(n_burn = 200L, n_mcmc = 500L, draws = 32L),
    wave1 = list(n_burn = 1000L, n_mcmc = 3000L, draws = 100L),
    wave2 = list(n_burn = 1000L, n_mcmc = 3000L, draws = 100L),
    wave3 = list(n_burn = 1000L, n_mcmc = 3000L, draws = 100L),
    sealed = list(n_burn = 1000L, n_mcmc = 3000L, draws = 100L),
    confirmation = list(n_burn = 5000L, n_mcmc = 20000L, draws = 200L),
    stop(sprintf("Unknown stage: %s", stage), call. = FALSE)
  )
}

qdesn_ssv2_timeout_seconds <- function(stage) {
  switch(stage,
    smoke = 1800L,
    calibration = 21600L,
    wave1 = 86400L,
    wave2 = 86400L,
    wave3 = 86400L,
    sealed = 86400L,
    confirmation = 604800L,
    stop(sprintf("Unknown stage: %s", stage), call. = FALSE)
  )
}

qdesn_ssv2_parse_progress_lines <- function(lines, n_burn = NA_integer_,
                                             n_mcmc = NA_integer_) {
  pattern <- "(burn-in|MCMC)[[:space:]]+iteration[[:space:]]+([0-9]+)"
  hits <- grep(pattern, lines, value = TRUE, ignore.case = TRUE)
  total <- as.integer(n_burn) + as.integer(n_mcmc)
  if (!length(hits)) {
    return(list(iteration = NA_integer_, total = total, phase = NA_character_))
  }
  iteration <- as.integer(sub(paste0(".*", pattern, ".*"), "\\2", hits,
                              ignore.case = TRUE))
  last <- length(hits)
  list(
    iteration = iteration[[last]], total = total,
    phase = if (grepl("burn-in", hits[[last]], ignore.case = TRUE)) "burnin" else "sampling"
  )
}

qdesn_ssv2_seed <- function(...) {
  key <- paste(..., collapse = "|")
  as.integer(strtoi(substr(digest::digest(key, algo = "sha256", serialize = FALSE), 1L, 7L), 16L))
}

qdesn_ssv2_make_job <- function(repo_root, profile, target, source, stage,
                                source_registry_path, chain_id = 1L) {
  profile <- qdesn_ssv2_ensure_effective_dimension(profile)
  if (profile$effective_readout_dimension[[1L]] >
      qdesn_ssv2_max_effective_readout_dimension) {
    stop(sprintf(
      "Candidate %s has effective readout dimension %d above the %d-column contract.",
      profile$candidate_id[[1L]], profile$effective_readout_dimension[[1L]],
      qdesn_ssv2_max_effective_readout_dimension
    ), call. = FALSE)
  }
  request <- qdesn_ssv2_read_json(target$parent_request_path[[1L]])
  cfg <- request$config
  D <- as.integer(profile$D[[1L]])
  cfg$desn$D <- D
  cfg$desn$n <- qdesn_ssv2_vec(profile$n[[1L]], "integer")
  cfg$desn$n_tilde <- qdesn_ssv2_vec(profile$n_tilde[[1L]], "integer")
  cfg$desn$m <- as.integer(profile$m[[1L]])
  cfg$desn$alpha <- qdesn_ssv2_vec(profile$alpha[[1L]])
  cfg$desn$rho <- qdesn_ssv2_vec(profile$rho[[1L]])
  cfg$desn$pi_w <- qdesn_ssv2_vec(profile$pi_w[[1L]])
  cfg$desn$pi_in <- qdesn_ssv2_vec(profile$pi_in[[1L]])
  cfg$desn$washout <- as.integer(profile$washout[[1L]])
  cfg$desn$seed <- qdesn_ssv2_seed(profile$candidate_id[[1L]], source$source_id[[1L]], "desn")
  cfg$lags$m_y <- as.integer(profile$readout_y_lags[[1L]])
  cfg$readout$reservoir_lags <- as.integer(profile$reservoir_lags[[1L]])
  cfg$split$T_use <- as.integer(source$source_total_size[[1L]])
  cfg$split$train_n <- as.integer(source$source_total_size[[1L]] - 1000L)
  cfg$inference$method <- "mcmc"
  cfg$inference$likelihood_family <- "exal"
  budget <- qdesn_ssv2_budget(stage)
  cfg$inference$mcmc$n_burn <- budget$n_burn
  cfg$inference$mcmc$n_mcmc <- budget$n_mcmc
  cfg$inference$mcmc$thin <- 1L
  cfg$inference$mcmc$progress_every <- if (stage == "smoke") 1L else 50L
  cfg$inference$mcmc$init_from_vb <- TRUE
  cfg$inference$mcmc$slice$core_update_mode <- qdesn_ssv2_method_id
  cfg$inference$mcmc$slice$width_gamma <- 4
  cfg$inference$mcmc$slice$core_extra_passes <- 0L
  cfg$inference$mcmc$priors$beta$rhs_ns$tau0 <- as.numeric(profile$rhs_tau0[[1L]])
  cfg$inference$mcmc$control$seed <- qdesn_ssv2_seed(profile$candidate_id[[1L]], source$source_id[[1L]], chain_id, "mcmc")
  cfg$inference$mcmc$control$rng_seed <- qdesn_ssv2_seed(profile$candidate_id[[1L]], source$source_id[[1L]], chain_id, "rng")
  cfg$inference$mcmc$vb_warm_start_seed <- qdesn_ssv2_seed(profile$candidate_id[[1L]], source$source_id[[1L]], chain_id, "vb")
  cfg$sampling$nd_draws <- budget$draws
  cfg$synthesis$n_samp <- budget$draws
  cfg$metrics$posterior_metric_draws <- budget$draws
  cfg$outputs$save <- TRUE
  cfg$outputs$keep_draws <- FALSE
  cfg$outputs$keep_mcmc_vb_init <- FALSE
  cfg$outputs$save_forecast_objects <- FALSE
  cfg$outputs$save_compact_fit_paths <- TRUE
  cfg$outputs$save_metric_summaries <- TRUE
  cfg$outputs$retain_full_rds_on_failure <- FALSE
  cfg$outputs$retention_profile <- "storage_light_independent_exal_m0_structural_v2"
  cfg$cpp$postpred_threads <- 1L
  cfg$validation$stream_child_stdout <- TRUE
  cfg$validation$timeout_seconds <- qdesn_ssv2_timeout_seconds(stage)
  root <- request$root_spec
  root$source_scenario <- source$scenario[[1L]]
  root$scenario <- source$scenario[[1L]]
  root$source_family <- source$family[[1L]]
  root$tau <- as.numeric(source$tau[[1L]])
  root$source_total_size <- as.integer(source$source_total_size[[1L]])
  root$source_window_label <- sprintf("effTT500_m%d_w%d_trainEnd9000_H1000",
                                      profile$m[[1L]], profile$washout[[1L]])
  for (nm in c("raw_start_source_index", "raw_end_source_index",
               "train_start_source_index", "train_end_source_index",
               "forecast_start_source_index", "forecast_end_source_index")) {
    root[[nm]] <- as.integer(source[[nm]][[1L]])
  }
  root$source_series_wide_path <- source$source_series_wide_path[[1L]]
  root$source_series_wide_sha256 <- source$source_series_wide_sha256[[1L]]
  root$source_selection_indices_path <- source$source_selection_indices_path[[1L]]
  root$source_selection_indices_sha256 <- source$source_selection_indices_sha256[[1L]]
  root$source_sim_path <- source$source_sim_path[[1L]]
  root$source_sim_sha256 <- source$source_sim_sha256[[1L]]
  root$screening_profile_id <- profile$candidate_id[[1L]]
  root$reservoir_profile <- profile$candidate_id[[1L]]
  root$screening_stage <- qdesn_ssv2_stage
  root$screening_wave <- stage
  root$profile_role <- profile$design_role[[1L]]
  root$rhs_tau0 <- as.numeric(profile$rhs_tau0[[1L]])
  root$readout_y_lags <- as.integer(profile$readout_y_lags[[1L]])
  root$reservoir_lags <- as.integer(profile$reservoir_lags[[1L]])
  root$desn_seed <- cfg$desn$seed
  root$mcmc_seed <- cfg$inference$mcmc$control$seed
  root$mcmc_rng_seed <- cfg$inference$mcmc$control$rng_seed
  root$vb_warm_start_seed <- cfg$inference$mcmc$vb_warm_start_seed
  root$dimension_p_estimate <- as.integer(profile$effective_readout_dimension[[1L]])
  root$effective_readout_dimension <- root$dimension_p_estimate
  root$maximum_effective_readout_dimension <- qdesn_ssv2_max_effective_readout_dimension
  root$p_over_n_tt500 <- root$dimension_p_estimate / 500
  job_id <- sprintf("%s__%s__%s__c%02d", stage, profile$candidate_id[[1L]],
                    source$source_id[[1L]], as.integer(chain_id))
  root$root_id <- job_id
  spec_id <- paste0("independent_exal_m0_structural_v2__", job_id)
  cfg$validation_spec_id <- spec_id
  list(
    schema_version = "independent_exal_m0_structural_screen_v2_job_v1",
    job_id = job_id, stage = stage, target_cell_id = target$target_cell_id[[1L]],
    candidate_id = profile$candidate_id[[1L]], chain_id = as.integer(chain_id),
    source_id = source$source_id[[1L]], source_role = source$source_role[[1L]],
    objective_metric = target$objective_metric[[1L]], current_value = target$current_value[[1L]],
    comparator_value = target$comparator_value[[1L]], spec_id = spec_id,
    observed_path = source$observed_path[[1L]], observed_sha256 = source$observed_sha256[[1L]],
    source_registry_path = source_registry_path,
    source_registry_sha256 = qdesn_ssv2_sha256(source_registry_path),
    source_registry_hash_value = qdesn_ssv2_registry_hash,
    inference_method_id = "M0_v_collapsed_support_logit",
    profile = as.list(profile[1L, , drop = FALSE]), config = cfg, root_spec = root,
    study_contract = list(
      package_version = "1.0.0", canonical_source_registry_hash_value = qdesn_ssv2_registry_hash,
      development_source_registry_sha256 = qdesn_ssv2_sha256(source_registry_path),
      preprocessing_scope = "train_only", train_window = c(8501L, 9000L),
      forecast_window = c(9001L, 10000L), max_lead = 30L, origin_stride = 30L,
      effective_readout_dimension = root$effective_readout_dimension,
      maximum_effective_readout_dimension = qdesn_ssv2_max_effective_readout_dimension,
      article_promotion_automatic = FALSE, full_confirmation_requires_explicit_approval = TRUE
    )
  )
}

qdesn_ssv2_job_root <- function(repo_root, run_tag, job_id) {
  qdesn_ssv2_path(repo_root, "results", "qdesn_mcmc_validation", qdesn_ssv2_stage,
                  run_tag, "jobs", job_id)
}

qdesn_ssv2_metric_value <- function(job_root, metric) {
  if (metric == "fit_qtrue_rmse") {
    path <- file.path(job_root, "fit_summary_row.csv")
    if (!file.exists(path)) return(NA_real_)
    x <- qdesn_ssv2_read_csv(path)
    return(as.numeric(x$train_qtrue_rmse[[1L]]))
  }
  path <- file.path(job_root, "tables", "forecast_horizon_summary.csv")
  if (!file.exists(path)) return(NA_real_)
  x <- qdesn_ssv2_read_csv(path)
  idx <- which(suppressWarnings(as.integer(x$horizon)) == 1000L |
                 as.character(x$window) == "forecast_H1000")
  if (!length(idx)) return(NA_real_)
  if (metric == "forecast_qtrue_mae_H1000") as.numeric(x$qtrue_mae[[idx[[1L]]]]) else
    as.numeric(x$pinball_tau[[idx[[1L]]]])
}

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

iqfr_v2_protocol_relpath <- file.path(
  "config", "validation", "independent_qdesn_full_redesign_v2",
  "protocol_defaults.yaml"
)
iqfr_v2_schema <- "independent_qdesn_full_redesign_v2_v1"
iqfr_v2_expected_branch <-
  "validation/independent-qdesn-full-redesign-v2-20260925"
iqfr_v2_quantiles <- c(0.05, 0.25, 0.50)
iqfr_v2_families <- c("normal", "laplace", "gausmix")

iqfr_v2_repo_root <- function() {
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                winslash = "/", mustWork = TRUE)
}

iqfr_v2_read_protocol <- function(repo_root = iqfr_v2_repo_root()) {
  path <- file.path(repo_root, iqfr_v2_protocol_relpath)
  if (!file.exists(path)) stop("Missing v2 protocol: ", path, call. = FALSE)
  yaml::read_yaml(path)
}

iqfr_v2_sha256 <- function(path) {
  if (!file.exists(path)) return(NA_character_)
  unname(tools::sha256sum(path))
}

iqfr_v2_seed <- function(...) {
  token <- paste(..., collapse = "|")
  as.integer(strtoi(substr(digest::digest(token, algo = "sha256",
                                         serialize = FALSE), 1L, 7L), 16L))
}

iqfr_v2_safe <- function(x) {
  x <- tolower(as.character(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  gsub("^_|_$", "", x)
}

iqfr_v2_pack <- function(x) {
  paste(format(x, scientific = FALSE, trim = TRUE, digits = 15), collapse = ";")
}

iqfr_v2_unpack_numeric <- function(x) {
  if (is.null(x) || !length(x) || is.na(x[[1L]]) || !nzchar(x[[1L]])) {
    return(numeric())
  }
  as.numeric(strsplit(as.character(x[[1L]]), ";", fixed = TRUE)[[1L]])
}

iqfr_v2_unpack_integer <- function(x) as.integer(iqfr_v2_unpack_numeric(x))

iqfr_v2_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(pattern = paste0(".", basename(path), "."),
                  tmpdir = dirname(path))
  on.exit(unlink(tmp, force = TRUE), add = TRUE)
  utils::write.csv(x, tmp, row.names = FALSE, na = "")
  if (!file.rename(tmp, path)) stop("Could not atomically write ", path,
                                    call. = FALSE)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

iqfr_v2_write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(pattern = paste0(".", basename(path), "."),
                  tmpdir = dirname(path))
  on.exit(unlink(tmp, force = TRUE), add = TRUE)
  jsonlite::write_json(x, tmp, pretty = TRUE, auto_unbox = TRUE,
                       null = "null", digits = NA)
  if (!file.rename(tmp, path)) stop("Could not atomically write ", path,
                                    call. = FALSE)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

iqfr_v2_protocol_checks <- function(protocol = iqfr_v2_read_protocol()) {
  s <- protocol$scope
  a <- protocol$architecture
  x <- protocol$search
  z <- protocol$selection
  e <- protocol$execution
  checks <- c(
    protocol_id = identical(protocol$protocol$id,
                            "independent_qdesn_full_redesign_v2"),
    launch_enabled = isTRUE(protocol$protocol$launch_enabled),
    families = identical(as.character(s$families), iqfr_v2_families),
    quantiles = isTRUE(all.equal(as.numeric(s$quantiles), iqfr_v2_quantiles)),
    four_models = identical(as.character(s$models), c(
      "dqlm_al", "qdesn_al_rhs", "exdqlm_exal", "qdesn_exal_rhs"
    )),
    only_qdesn_tuned = identical(as.character(s$structurally_tuned_models),
                                 c("qdesn_al_rhs", "qdesn_exal_rhs")),
    fixed_comparator_guard = identical(
      as.character(s$fixed_comparator_policy),
      "frozen_authority_reference"
    ) && isTRUE(s$common_lattice_comparator_replay_required_before_article_replacement),
    windows = identical(as.integer(unlist(s$fit_window)), c(8501L, 9000L)) &&
      identical(as.integer(unlist(s$heldout_window)), c(9001L, 10000L)),
    rolling = identical(as.integer(s$horizon), 30L) &&
      identical(as.integer(s$final_origins$stride), 1L) &&
      isTRUE(s$teacher_forced_between_origins) &&
      isTRUE(s$recursive_within_horizon) && !isTRUE(s$refit_per_origin),
    architecture = identical(a$reservoir_activation, "tanh") &&
      identical(a$lower_state_readout_activation, "identity") &&
      identical(as.character(a$readout_columns),
                c("intercept", "all_reservoir_layers")) &&
      !isTRUE(a$direct_response_lags_in_readout) &&
      !isTRUE(a$reservoir_lags_in_readout),
    search_size = identical(as.integer(x$initial_candidates_per_family), 384L) &&
      identical(as.integer(x$adaptive_candidates_per_family), 128L) &&
      identical(as.integer(x$full_budget_top_k_per_family), 50L),
    search_support = identical(as.integer(x$depth_values), 1:4) &&
      max(as.integer(x$width_values)) == 300L &&
      max(as.integer(x$response_lag_values)) == 150L &&
      max(as.numeric(x$alpha_range)) == 0.99 &&
      min(as.numeric(x$log10_tau0_range)) == -8,
    sealed = isTRUE(z$final_window_access_forbidden),
    case_specific = isTRUE(z$global_specification_forbidden),
    workers = identical(as.integer(e$workers), 15L) &&
      identical(as.integer(e$threads_per_worker), 1L)
  )
  data.frame(check = names(checks), pass = unname(checks),
             stringsAsFactors = FALSE)
}

iqfr_v2_assert_protocol <- function(protocol = iqfr_v2_read_protocol()) {
  checks <- iqfr_v2_protocol_checks(protocol)
  if (any(!checks$pass)) {
    stop("v2 protocol checks failed: ",
         paste(checks$check[!checks$pass], collapse = ", "), call. = FALSE)
  }
  invisible(checks)
}

iqfr_v2_vdc <- function(index, base) {
  index <- as.integer(index)
  out <- numeric(length(index))
  denom <- 1
  while (any(index > 0L)) {
    denom <- denom * base
    out <- out + (index %% base) / denom
    index <- index %/% base
  }
  out
}

iqfr_v2_halton <- function(n, d, start = 1L, shift_seed = 1L) {
  primes <- c(2L, 3L, 5L, 7L, 11L, 13L, 17L, 19L, 23L, 29L,
              31L, 37L, 41L, 43L, 47L, 53L, 59L, 61L, 67L, 71L)
  if (d > length(primes)) stop("Halton dimension exceeds prime table.",
                               call. = FALSE)
  idx <- seq.int(as.integer(start), length.out = n)
  z <- vapply(primes[seq_len(d)], function(b) iqfr_v2_vdc(idx, b),
              numeric(n))
  set.seed(as.integer(shift_seed))
  shifts <- stats::runif(d)
  sweep(z, 2L, shifts, "+") %% 1
}

iqfr_v2_architecture_catalog <- function(protocol) {
  widths <- as.integer(protocol$search$width_values)
  shapes <- as.character(protocol$search$layer_shapes)
  rows <- list()
  k <- 0L
  for (D in as.integer(protocol$search$depth_values)) {
    for (shape in shapes) {
      for (w in widths) {
        raw <- switch(shape,
          flat = rep(w, D),
          taper = round(seq(w, max(20, w / 2), length.out = D)),
          expand = round(seq(max(20, w / 2), w, length.out = D)),
          bottleneck = if (D == 1L) w else {
            z <- rep(w, D)
            z[seq.int(2L, D, by = 2L)] <- max(20, round(w / 2))
            z
          }
        )
        n <- vapply(raw, function(v) widths[which.min(abs(widths - v))],
                    integer(1L))
        if (sum(n) > as.integer(protocol$search$maximum_total_states)) next
        k <- k + 1L
        rows[[k]] <- data.frame(
          D = D, layer_shape = shape, n = iqfr_v2_pack(n),
          n_tilde = iqfr_v2_pack(if (D > 1L) n[seq_len(D - 1L)] else integer()),
          total_states = sum(n), readout_dimension = 1L + sum(n),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  out <- unique(do.call(rbind, rows))
  out$dimension_stratum <- cut(
    out$readout_dimension, breaks = c(-Inf, 500, 800, 1201),
    labels = c("small", "medium", "large"), right = TRUE
  )
  out <- out[!is.na(out$dimension_stratum), , drop = FALSE]
  rownames(out) <- NULL
  out
}

iqfr_v2_pick_architecture <- function(catalog, u_stratum, u_row) {
  stratum <- if (u_stratum < 0.70) "small" else if (u_stratum < 0.90) {
    "medium"
  } else "large"
  pool <- catalog[as.character(catalog$dimension_stratum) == stratum, , drop = FALSE]
  if (!nrow(pool)) stop("No architecture in stratum ", stratum, call. = FALSE)
  pool[1L + floor(u_row * nrow(pool)) %% nrow(pool), , drop = FALSE]
}

iqfr_v2_candidate_signature <- function(row) {
  fields <- c(
    "family", "D", "n", "n_tilde", "m", "alpha", "rho",
    "tau0_mode", "tau0_base", "rhs_tau0", "center_scale", "input_bound",
    "input_gain", "recurrent_indegree", "input_fanin_fraction",
    "input_fanin", "interlayer_fanin"
  )
  paste(iqfr_v2_schema,
        paste(vapply(fields, function(nm) as.character(row[[nm]][[1L]]),
                     character(1L)), collapse = "|"), sep = "|")
}

iqfr_v2_matrix_signature <- function(row) {
  paste(row$D, row$n, row$n_tilde, row$m, row$recurrent_indegree,
        row$input_fanin, row$interlayer_fanin, sep = "|")
}

iqfr_v2_generate_initial_candidates <- function(protocol, family,
                                                 n = NULL,
                                                 start = 19L,
                                                 generation = "initial") {
  family <- match.arg(family, iqfr_v2_families)
  n <- as.integer(n %||% protocol$search$initial_candidates_per_family)
  shift_seed <- iqfr_v2_seed(protocol$protocol$id, family, generation,
                             "halton")
  h <- iqfr_v2_halton(n, 16L, start = start, shift_seed = shift_seed)
  catalog <- iqfr_v2_architecture_catalog(protocol)
  m_values <- as.integer(protocol$search$response_lag_values)
  center_values <- as.character(protocol$preprocessing$center_scale)
  bound_values <- as.character(protocol$preprocessing$input_bound)
  gain_values <- as.numeric(protocol$preprocessing$input_gain)
  degree_values <- as.integer(protocol$topology$recurrent_indegree)
  input_fraction_values <- as.numeric(protocol$topology$input_fanin_fraction)
  inter_values <- as.character(protocol$topology$interlayer_fanin)
  rows <- vector("list", n)
  for (i in seq_len(n)) {
    arch <- iqfr_v2_pick_architecture(catalog, h[i, 1L], h[i, 2L])
    m <- m_values[1L + floor(h[i, 3L] * length(m_values)) %% length(m_values)]
    alpha <- 0.01 + 0.98 * h[i, 4L]
    rho <- 0.20 + 0.79 * h[i, 5L]
    log_tau <- -8 + 7 * h[i, 6L]
    tau0_base <- 10^log_tau
    tau0_mode <- if (h[i, 7L] < 0.5) "absolute" else "dimension_aware"
    p <- as.integer(arch$readout_dimension[[1L]])
    tau0 <- if (tau0_mode == "dimension_aware") {
      tau0_base * sqrt(500 / p)
    } else tau0_base
    tau0 <- min(1e-1, max(1e-8, tau0))
    center <- center_values[1L + floor(h[i, 8L] * length(center_values)) %%
                              length(center_values)]
    bound <- bound_values[1L + floor(h[i, 9L] * length(bound_values)) %%
                            length(bound_values)]
    gain <- gain_values[1L + floor(h[i, 10L] * length(gain_values)) %%
                          length(gain_values)]
    degree <- degree_values[1L + floor(h[i, 11L] * length(degree_values)) %%
                              length(degree_values)]
    input_fraction <- input_fraction_values[
      1L + floor(h[i, 12L] * length(input_fraction_values)) %%
        length(input_fraction_values)
    ]
    input_fanin <- max(1L, min(m + 1L, as.integer(ceiling(input_fraction * (m + 1L)))))
    inter_token <- inter_values[
      1L + floor(h[i, 13L] * length(inter_values)) %% length(inter_values)
    ]
    n_vec <- iqfr_v2_unpack_integer(arch$n)
    inter_fanin <- if (inter_token == "dense") max(n_vec) else
      as.integer(inter_token)
    row <- data.frame(
      family = family, generation = generation, generation_index = i,
      D = as.integer(arch$D), n = arch$n, n_tilde = arch$n_tilde,
      layer_shape = arch$layer_shape, total_states = arch$total_states,
      readout_dimension = p, m = m, alpha = alpha, rho = rho,
      tau0_mode = tau0_mode, tau0_base = tau0_base, rhs_tau0 = tau0,
      center_scale = center, input_bound = bound, input_gain = gain,
      recurrent_indegree = min(degree, min(n_vec)),
      input_fanin_fraction = input_fraction, input_fanin = input_fanin,
      interlayer_fanin = inter_fanin,
      screen_reservoir_seed = as.integer(protocol$search$screening_reservoir_seed),
      stringsAsFactors = FALSE
    )
    matrix_signature <- iqfr_v2_matrix_signature(row)
    row$matrix_seed <- iqfr_v2_seed(
      protocol$search$screening_reservoir_seed, family, matrix_signature
    )
    row$candidate_signature <- iqfr_v2_candidate_signature(row)
    hash <- digest::digest(row$candidate_signature, algo = "sha256",
                           serialize = FALSE)
    generation_token <- substr(iqfr_v2_safe(generation), 1L, 3L)
    row$candidate_id <- sprintf("iqfr2_%s_%s%03d_%s", family,
                                generation_token, i,
                                substr(hash, 1L, 10L))
    rows[[i]] <- row
  }
  out <- do.call(rbind, rows)
  if (anyDuplicated(out$candidate_signature) || anyDuplicated(out$candidate_id)) {
    stop("Initial candidate generation produced duplicate signatures.",
         call. = FALSE)
  }
  if (mean(out$alpha >= 0.4) <
      as.numeric(protocol$search$minimum_fraction_alpha_at_least_0p4)) {
    stop("Initial design undercovers alpha >= 0.4.", call. = FALSE)
  }
  rownames(out) <- NULL
  out
}

iqfr_v2_rekey_candidate <- function(row, generation, generation_index,
                                    protocol) {
  row$generation <- generation
  row$generation_index <- as.integer(generation_index)
  row$matrix_seed <- iqfr_v2_seed(
    protocol$search$screening_reservoir_seed, row$family[[1L]],
    iqfr_v2_matrix_signature(row)
  )
  row$candidate_signature <- iqfr_v2_candidate_signature(row)
  hash <- digest::digest(row$candidate_signature, algo = "sha256",
                         serialize = FALSE)
  row$candidate_id <- sprintf(
    "iqfr2_%s_%s%03d_%s", row$family[[1L]],
    substr(iqfr_v2_safe(generation), 1L, 3L),
    as.integer(generation_index), substr(hash, 1L, 10L)
  )
  row
}

iqfr_v2_generate_adaptive_candidates <- function(protocol, family,
                                                  ranked_initial,
                                                  initial_candidates) {
  family <- match.arg(family, iqfr_v2_families)
  target_n <- as.integer(protocol$search$adaptive_candidates_per_family)
  ranked <- ranked_initial[ranked_initial$family == family, , drop = FALSE]
  candidates <- initial_candidates[initial_candidates$family == family,
                                   , drop = FALSE]
  parents <- merge(
    ranked[order(ranked$family_rank), c("candidate_id", "family_rank")],
    candidates, by = "candidate_id", all.x = TRUE, sort = FALSE
  )
  parents <- parents[order(parents$family_rank), , drop = FALSE]
  parents <- parents[seq_len(min(32L, nrow(parents))), , drop = FALSE]
  if (!nrow(parents) || anyNA(parents$candidate_signature)) {
    stop("Adaptive generation is missing ranked parent candidates.",
         call. = FALSE)
  }

  h <- iqfr_v2_halton(
    96L, 10L, start = 5003L,
    shift_seed = iqfr_v2_seed(protocol$protocol$id, family, "adaptive_local")
  )
  m_values <- as.integer(protocol$search$response_lag_values)
  gains <- as.numeric(protocol$preprocessing$input_gain)
  degrees <- as.integer(protocol$topology$recurrent_indegree)
  fractions <- as.numeric(protocol$topology$input_fanin_fraction)
  inter_values <- as.character(protocol$topology$interlayer_fanin)
  rows <- vector("list", 96L)
  for (i in seq_len(96L)) {
    parent <- parents[1L + (i - 1L) %% nrow(parents), , drop = FALSE]
    row <- parent[, intersect(names(candidates), names(parent)), drop = FALSE]
    row$alpha <- min(0.99, max(0.01, as.numeric(row$alpha) +
                                (h[i, 1L] - 0.5) * 0.36))
    row$rho <- min(0.99, max(0.20, as.numeric(row$rho) +
                              (h[i, 2L] - 0.5) * 0.30))
    row$tau0_base <- min(1e-1, max(1e-8,
      10^(log10(as.numeric(row$tau0_base)) + (h[i, 3L] - 0.5) * 4)
    ))
    p <- as.integer(row$readout_dimension)
    row$rhs_tau0 <- if (identical(as.character(row$tau0_mode),
                                  "dimension_aware")) {
      row$tau0_base * sqrt(500 / p)
    } else row$tau0_base
    row$rhs_tau0 <- min(1e-1, max(1e-8, row$rhs_tau0))

    parent_m <- match(as.integer(row$m), m_values)
    m_shift <- floor(h[i, 4L] * 5L) - 2L
    row$m <- m_values[min(length(m_values), max(1L, parent_m + m_shift))]
    gain_idx <- which.min(abs(gains - as.numeric(row$input_gain)))
    gain_shift <- floor(h[i, 5L] * 3L) - 1L
    row$input_gain <- gains[min(length(gains), max(1L, gain_idx + gain_shift))]
    row$recurrent_indegree <- degrees[
      1L + floor(h[i, 6L] * length(degrees)) %% length(degrees)
    ]
    row$input_fanin_fraction <- fractions[
      1L + floor(h[i, 7L] * length(fractions)) %% length(fractions)
    ]
    row$input_fanin <- max(1L, min(row$m + 1L,
      as.integer(ceiling(row$input_fanin_fraction * (row$m + 1L)))))
    inter <- inter_values[
      1L + floor(h[i, 8L] * length(inter_values)) %% length(inter_values)
    ]
    n_vec <- iqfr_v2_unpack_integer(row$n)
    row$interlayer_fanin <- if (inter == "dense") max(n_vec) else
      as.integer(inter)
    if (h[i, 9L] > 0.67) {
      row$center_scale <- if (row$center_scale == "mean_sd") {
        "median_mad"
      } else "mean_sd"
    }
    if (h[i, 10L] > 0.67) {
      row$input_bound <- if (row$input_bound == "none") {
        "tanh_z_over_3"
      } else "none"
    }
    row <- iqfr_v2_rekey_candidate(row, "adaptive_local", i, protocol)
    rows[[i]] <- row
  }

  explorer <- iqfr_v2_generate_initial_candidates(
    protocol, family, n = 256L, start = 12011L,
    generation = "adaptive_explore"
  )
  pool <- rbind(do.call(rbind, rows), explorer)
  historical <- initial_candidates$candidate_signature
  pool <- pool[!pool$candidate_signature %in% historical, , drop = FALSE]
  pool <- pool[!duplicated(pool$candidate_signature), , drop = FALSE]
  if (nrow(pool) < target_n) {
    stop("Adaptive candidate generator could not produce enough unique rows.",
         call. = FALSE)
  }
  out <- pool[seq_len(target_n), , drop = FALSE]
  out$generation_index <- seq_len(nrow(out))
  out <- do.call(rbind, lapply(seq_len(nrow(out)), function(i) {
    iqfr_v2_rekey_candidate(out[i, , drop = FALSE], out$generation[[i]], i,
                            protocol)
  }))
  rownames(out) <- NULL
  if (anyDuplicated(out$candidate_signature) ||
      any(out$candidate_signature %in% historical)) {
    stop("Adaptive candidate uniqueness contract failed.", call. = FALSE)
  }
  out
}

iqfr_v2_source_path <- function(protocol, family, tau) {
  token <- switch(sprintf("%.2f", as.numeric(tau)),
                  "0.05" = "0p05", "0.25" = "0p25", "0.50" = "0p50")
  rel <- protocol$source$source_template
  rel <- gsub("{family}", family, rel, fixed = TRUE)
  rel <- gsub("{tau_token}", token, rel, fixed = TRUE)
  normalizePath(file.path(protocol$source$authority_root, rel), winslash = "/",
                mustWork = TRUE)
}

iqfr_v2_materialize_sources <- function(protocol, output_root) {
  rows <- list()
  k <- 0L
  for (family in iqfr_v2_families) {
    family_mu_hash <- NULL
    for (tau in iqfr_v2_quantiles) {
      source <- iqfr_v2_source_path(protocol, family, tau)
      x <- utils::read.csv(source, check.names = FALSE)
      required <- as.character(protocol$source$required_columns)
      if (!all(required %in% names(x)) || nrow(x) != 1890L ||
          !identical(as.integer(x$t), 8111:10000)) {
        stop("Source contract failed: ", source, call. = FALSE)
      }
      y_hash <- digest::digest(as.numeric(x$y), algo = "sha256", serialize = TRUE)
      mu_hash <- digest::digest(as.numeric(x$mu), algo = "sha256", serialize = TRUE)
      if (is.null(family_mu_hash)) {
        family_mu_hash <- mu_hash
      } else if (!identical(mu_hash, family_mu_hash)) {
        stop("Family oracle-location path changed across quantiles: ", family,
             call. = FALSE)
      }
      target <- file.path(output_root, "sources", sprintf(
        "%s_tau_%s.csv", family, gsub("[.]", "p", sprintf("%.2f", tau))
      ))
      dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
      if (!file.copy(source, target, overwrite = FALSE, copy.mode = TRUE)) {
        stop("Could not copy frozen source to ", target, call. = FALSE)
      }
      k <- k + 1L
      rows[[k]] <- data.frame(
        family = family, tau = tau, source_path = source,
        source_sha256 = iqfr_v2_sha256(source), frozen_path = target,
        frozen_sha256 = iqfr_v2_sha256(target), rows = nrow(x),
        first_source_index = min(x$t), last_source_index = max(x$t),
        y_hash = y_hash, mu_hash = mu_hash, stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, rows)
  if (any(out$source_sha256 != out$frozen_sha256)) {
    stop("Frozen source copy hash mismatch.", call. = FALSE)
  }
  iqfr_v2_write_csv(out, file.path(output_root, "source_manifest.csv"))
  out
}

iqfr_v2_materialize_initial_jobs <- function(repo_root, run_root, protocol,
                                             candidates, sources) {
  configs <- file.path(run_root, "configs", "normal_initial")
  dir.create(configs, recursive = TRUE, showWarnings = FALSE)
  rows <- vector("list", nrow(candidates))
  for (i in seq_len(nrow(candidates))) {
    candidate <- candidates[i, , drop = FALSE]
    source <- sources[sources$family == candidate$family[[1L]] &
                        abs(sources$tau - 0.50) < 1e-10, , drop = FALSE]
    if (nrow(source) != 1L) stop("Missing median source for ", candidate$family,
                                 call. = FALSE)
    job_id <- paste0("normal_initial__", candidate$candidate_id[[1L]])
    config_path <- file.path(configs, paste0(job_id, ".json"))
    result_path <- file.path(run_root, "results", "normal_initial",
                             paste0(job_id, ".csv"))
    status_path <- file.path(run_root, "status", "normal_initial",
                             paste0(job_id, ".json"))
    config <- list(
      schema_version = iqfr_v2_schema,
      protocol_id = protocol$protocol$id,
      stage = "normal_initial", job_id = job_id,
      repo_root = repo_root, run_root = run_root,
      protocol_path = file.path(repo_root, iqfr_v2_protocol_relpath),
      protocol_sha256 = iqfr_v2_sha256(file.path(repo_root,
                                                 iqfr_v2_protocol_relpath)),
      source = as.list(source[1L, , drop = FALSE]),
      candidate = as.list(candidate[1L, , drop = FALSE]),
      result_path = result_path, status_path = status_path,
      seed = iqfr_v2_seed(job_id, "normal_screen"),
      budget = protocol$inference$normal_rhs$screen,
      selection = protocol$selection
    )
    iqfr_v2_write_json(config, config_path)
    rows[[i]] <- data.frame(
      stage = "normal_initial", job_id = job_id,
      family = candidate$family[[1L]],
      candidate_id = candidate$candidate_id[[1L]],
      config_path = config_path, config_sha256 = iqfr_v2_sha256(config_path),
      result_path = result_path, status_path = status_path,
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  iqfr_v2_write_csv(out, file.path(run_root, "plans", "normal_initial.csv"))
  out
}

iqfr_v2_materialize_normal_jobs <- function(repo_root, run_root, protocol,
                                            candidates, sources, stage,
                                            budget) {
  stage <- match.arg(stage, c("normal_initial", "normal_adaptive",
                              "normal_full"))
  configs <- file.path(run_root, "configs", stage)
  dir.create(configs, recursive = TRUE, showWarnings = FALSE)
  rows <- vector("list", nrow(candidates))
  for (i in seq_len(nrow(candidates))) {
    candidate <- candidates[i, , drop = FALSE]
    source <- sources[sources$family == candidate$family[[1L]] &
                        abs(sources$tau - 0.50) < 1e-10, , drop = FALSE]
    if (nrow(source) != 1L) stop("Missing median source for ", candidate$family,
                                 call. = FALSE)
    job_id <- paste0(stage, "__", candidate$candidate_id[[1L]])
    config_path <- file.path(configs, paste0(job_id, ".json"))
    result_path <- file.path(run_root, "results", stage,
                             paste0(job_id, ".csv"))
    status_path <- file.path(run_root, "status", stage,
                             paste0(job_id, ".json"))
    config <- list(
      schema_version = iqfr_v2_schema,
      protocol_id = protocol$protocol$id, stage = stage, job_id = job_id,
      repo_root = repo_root, run_root = run_root,
      protocol_path = file.path(repo_root, iqfr_v2_protocol_relpath),
      protocol_sha256 = iqfr_v2_sha256(file.path(repo_root,
                                                 iqfr_v2_protocol_relpath)),
      source = as.list(source[1L, , drop = FALSE]),
      candidate = as.list(candidate[1L, , drop = FALSE]),
      result_path = result_path, status_path = status_path,
      seed = iqfr_v2_seed(job_id, "normal_screen"), budget = budget,
      selection = protocol$selection
    )
    iqfr_v2_write_json(config, config_path)
    rows[[i]] <- data.frame(
      stage = stage, job_id = job_id, family = candidate$family[[1L]],
      candidate_id = candidate$candidate_id[[1L]],
      config_path = config_path, config_sha256 = iqfr_v2_sha256(config_path),
      result_path = result_path, status_path = status_path,
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  iqfr_v2_write_csv(out, file.path(run_root, "plans", paste0(stage, ".csv")))
  out
}

iqfr_v2_materialize_initial <- function(repo_root = iqfr_v2_repo_root(),
                                        run_root) {
  protocol <- iqfr_v2_read_protocol(repo_root)
  checks <- iqfr_v2_assert_protocol(protocol)
  if (dir.exists(run_root) && length(list.files(run_root, all.files = TRUE,
                                                no.. = TRUE))) {
    stop("Refusing to overwrite nonempty run root: ", run_root, call. = FALSE)
  }
  dir.create(run_root, recursive = TRUE, showWarnings = FALSE)
  for (subdir in c("configs", "plans", "results", "status", "logs",
                   "workers", "manifests", "summaries", "sources")) {
    dir.create(file.path(run_root, subdir), recursive = TRUE,
               showWarnings = FALSE)
  }
  sources <- iqfr_v2_materialize_sources(protocol, run_root)
  candidates <- do.call(rbind, lapply(iqfr_v2_families, function(family) {
    iqfr_v2_generate_initial_candidates(protocol, family)
  }))
  rownames(candidates) <- NULL
  candidate_path <- iqfr_v2_write_csv(
    candidates, file.path(run_root, "manifests", "initial_candidates.csv")
  )
  plan <- iqfr_v2_materialize_initial_jobs(repo_root, run_root, protocol,
                                           candidates, sources)
  git <- list(
    branch = system2("git", c("-C", repo_root, "branch", "--show-current"),
                     stdout = TRUE),
    head = system2("git", c("-C", repo_root, "rev-parse", "HEAD"),
                   stdout = TRUE),
    status = system2("git", c("-C", repo_root, "status", "--porcelain"),
                     stdout = TRUE)
  )
  session_path <- file.path(run_root, "manifests", "session_info.txt")
  writeLines(c(
    capture.output(utils::sessionInfo()), "",
    "External software:", capture.output(base::extSoftVersion()), "",
    "Thread environment:",
    paste0(c(
      "OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
      "VECLIB_MAXIMUM_THREADS", "NUMEXPR_NUM_THREADS",
      "RCPP_PARALLEL_NUM_THREADS"
    ), "=", Sys.getenv(c(
      "OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
      "VECLIB_MAXIMUM_THREADS", "NUMEXPR_NUM_THREADS",
      "RCPP_PARALLEL_NUM_THREADS"
    ), unset = "<unset>"))
  ), session_path)
  environment <- list(
    host = unname(Sys.info()[["nodename"]]),
    r_version = R.version.string,
    package_version = as.character(utils::packageDescription(
      "exdqlm", lib.loc = NULL, fields = "Version"
    ) %||% read.dcf(file.path(repo_root, "DESCRIPTION"),
                    fields = "Version")[[1L]]),
    description_version = read.dcf(file.path(repo_root, "DESCRIPTION"),
                                   fields = "Version")[[1L]],
    rng_kind = RNGkind(),
    session_info_path = normalizePath(session_path, winslash = "/",
                                      mustWork = TRUE),
    session_info_sha256 = iqfr_v2_sha256(session_path),
    thread_environment = as.list(Sys.getenv(c(
      "OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
      "VECLIB_MAXIMUM_THREADS", "NUMEXPR_NUM_THREADS",
      "RCPP_PARALLEL_NUM_THREADS"
    ), unset = "<unset>")),
    exal_vb_sigmagam_default = list(
      factorization = "structured", structured_grid_size = 151L
    ),
    exal_mcmc_method = protocol$inference$mcmc$exal_method_id
  )
  environment_path <- iqfr_v2_write_json(
    environment, file.path(run_root, "manifests", "environment.json")
  )
  manifest <- list(
    schema_version = iqfr_v2_schema,
    created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    protocol_path = file.path(repo_root, iqfr_v2_protocol_relpath),
    protocol_sha256 = iqfr_v2_sha256(file.path(repo_root,
                                               iqfr_v2_protocol_relpath)),
    protocol_checks = checks, git = git,
    candidate_path = candidate_path,
    candidate_sha256 = iqfr_v2_sha256(candidate_path),
    initial_candidates = nrow(candidates), initial_jobs = nrow(plan),
    source_manifest_sha256 = iqfr_v2_sha256(file.path(run_root,
                                                       "source_manifest.csv")),
    environment_path = environment_path,
    environment_sha256 = iqfr_v2_sha256(environment_path),
    workers = as.integer(protocol$execution$workers), threads_per_worker = 1L,
    final_window_sealed = TRUE
  )
  iqfr_v2_write_json(manifest,
                     file.path(run_root, "manifests", "materialization.json"))
  list(protocol = protocol, sources = sources, candidates = candidates,
       plan = plan, manifest = manifest)
}

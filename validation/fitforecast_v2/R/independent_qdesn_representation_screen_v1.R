`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

iqrs_v1_protocol_relpath <- file.path(
  "config", "validation", "independent_qdesn_representation_screen_v1",
  "protocol_defaults.yaml"
)
iqrs_v1_schema <- "independent_qdesn_representation_screen_v1_v1"
iqrs_v1_expected_branch <-
  "validation/independent-qdesn-representation-screen-v1-20260929"
iqrs_v1_families <- c("normal", "laplace", "gausmix")
iqrs_v1_quantiles <- c(0.05, 0.25, 0.50)

iqrs_v1_read_protocol <- function(repo_root = iqfr_v2_repo_root()) {
  path <- file.path(repo_root, iqrs_v1_protocol_relpath)
  if (!file.exists(path)) stop("Missing representation-screen protocol: ", path,
                               call. = FALSE)
  yaml::read_yaml(path)
}

iqrs_v1_protocol_checks <- function(protocol = iqrs_v1_read_protocol()) {
  s <- protocol$scope
  a <- protocol$architecture
  x <- protocol$search
  z <- protocol$selection
  e <- protocol$execution
  checks <- c(
    protocol_id = identical(protocol$protocol$id,
                            "independent_qdesn_representation_screen_v1"),
    launch_enabled = isTRUE(protocol$protocol$launch_enabled),
    families = identical(as.character(s$families), iqrs_v1_families),
    quantiles = isTRUE(all.equal(as.numeric(s$quantiles), iqrs_v1_quantiles)),
    tuned_models = identical(as.character(s$tuned_models),
                              c("qdesn_al_rhs", "qdesn_exal_rhs")),
    fixed_comparators = identical(as.character(s$frozen_comparators),
                                   c("dqlm_al", "exdqlm_exal")),
    windows = identical(as.integer(unlist(s$fit_window)), c(8501L, 9000L)) &&
      identical(as.integer(unlist(s$heldout_window)), c(9001L, 10000L)),
    forecast_contract = identical(as.integer(s$horizon), 30L) &&
      isTRUE(s$teacher_forced_between_origins) &&
      isTRUE(s$recursive_within_horizon) && !isTRUE(s$refit_per_origin),
    readout_contract = identical(a$reservoir_activation, "tanh") &&
      identical(a$lower_state_readout_activation, "identity") &&
      identical(as.character(a$readout_columns),
                c("intercept", "all_reservoir_layers")) &&
      !isTRUE(a$direct_response_lags_in_readout) &&
      !isTRUE(a$direct_exogenous_lags_in_readout),
    identity_projection = identical(a$projection$mode, "identity") &&
      isTRUE(a$projection$require_exact_identity) &&
      isTRUE(a$projection$dimensionality_reduction_forbidden),
    broad_capacity = identical(as.integer(x$depth_values), 1:4) &&
      max(as.integer(x$width_values)) == 600L &&
      as.integer(x$maximum_total_states) == 1800L &&
      max(as.integer(x$response_lag_values)) == 300L,
    broad_memory = identical(as.numeric(unlist(x$alpha_range)),
                              c(0.01, 0.99)) &&
      identical(as.numeric(unlist(x$rho_range)), c(0.20, 0.999)) &&
      as.numeric(x$minimum_high_memory_fraction) >= 0.30,
    fixed_seed = isTRUE(x$fixed_matrix_seed_across_all_stages) &&
      identical(as.integer(x$fixed_screen_matrix_seed), 920001L),
    blocked_folds = length(z$blocked_folds) == 2L &&
      all(vapply(z$blocked_folds, function(f) as.integer(f$origin_stride) == 1L,
                 logical(1L))) &&
      isTRUE(z$final_window_access_forbidden_before_confirmation),
    case_specific = isTRUE(z$family_specific) &&
      isTRUE(z$quantile_specific) && isTRUE(z$likelihood_specific) &&
      isTRUE(z$global_specification_forbidden),
    workers = identical(as.integer(e$workers), 15L) &&
      identical(as.character(e$cpu_set), "32-46") &&
      identical(as.integer(e$threads_per_worker), 1L),
    stage_graph = identical(
      as.integer(unlist(e$expected_jobs[c(
        "ridge_screen", "rhs_screen", "quantile_vb", "mcmc_pilot",
        "replication", "confirmation", "total"
      )])), c(960L, 360L, 150L, 144L, 108L, 54L, 1776L)
    )
  )
  data.frame(check = names(checks), pass = unname(checks),
             stringsAsFactors = FALSE)
}

iqrs_v1_assert_protocol <- function(protocol = iqrs_v1_read_protocol()) {
  checks <- iqrs_v1_protocol_checks(protocol)
  if (any(!checks$pass)) {
    stop("Representation-screen protocol checks failed: ",
         paste(checks$check[!checks$pass], collapse = ", "), call. = FALSE)
  }
  invisible(checks)
}

iqrs_v1_architecture_catalog <- function(protocol) {
  widths <- as.integer(protocol$search$width_values)
  maximum <- as.integer(protocol$search$maximum_total_states)
  rows <- list()
  k <- 0L
  snap <- function(x) widths[which.min(abs(widths - x))]
  for (D in as.integer(protocol$search$depth_values)) {
    for (shape in as.character(protocol$search$layer_shapes)) {
      for (width in widths) {
        raw <- switch(shape,
          flat = rep(width, D),
          taper = if (D == 1L) width else seq(width, max(20, width / 2),
                                               length.out = D),
          expand = if (D == 1L) width else seq(max(20, width / 2), width,
                                               length.out = D),
          bottleneck = if (D == 1L) width else {
            out <- rep(width, D)
            out[seq.int(2L, D, by = 2L)] <- max(20, width / 2)
            out
          },
          stop("Unknown layer shape: ", shape, call. = FALSE)
        )
        n <- as.integer(vapply(raw, snap, integer(1L)))
        if (sum(n) > maximum) next
        k <- k + 1L
        rows[[k]] <- data.frame(
          D = D, layer_shape = shape, n = iqfr_v2_pack(n),
          n_tilde = iqfr_v2_pack(if (D > 1L) n[seq_len(D - 1L)] else integer()),
          total_states = sum(n), readout_dimension = 1L + sum(n),
          capacity_stratum = cut(
            sum(n), breaks = c(-Inf, 250, 600, 1200, 1800),
            labels = c("small", "medium", "large", "very_large")
          ), stringsAsFactors = FALSE
        )
      }
    }
  }
  out <- unique(do.call(rbind, rows))
  out <- out[order(out$total_states, out$D, out$n), , drop = FALSE]
  rownames(out) <- NULL
  out
}

iqrs_v1_pick_architecture <- function(catalog, u_stratum, u_row) {
  label <- if (u_stratum < 0.25) "small" else if (u_stratum < 0.55) {
    "medium"
  } else if (u_stratum < 0.80) "large" else "very_large"
  pool <- catalog[as.character(catalog$capacity_stratum) == label, , drop = FALSE]
  if (!nrow(pool)) stop("No architecture in capacity stratum ", label,
                         call. = FALSE)
  pool[1L + floor(u_row * nrow(pool)) %% nrow(pool), , drop = FALSE]
}

iqrs_v1_structure_fingerprint <- function(row) {
  fields <- c(
    "family", "D", "n", "n_tilde", "m", "alpha", "rho", "center_scale",
    "input_bound", "input_gain", "recurrent_indegree",
    "input_fanin_fraction", "input_fanin", "interlayer_fanin"
  )
  values <- vapply(fields, function(field) {
    value <- row[[field]]
    if ((is.null(value) || !length(value)) &&
        identical(field, "input_fanin_fraction")) {
      value <- as.numeric(row$input_fanin[[1L]]) / as.numeric(row$m[[1L]])
    }
    if (is.null(value) || !length(value)) {
      stop("Structure fingerprint is missing field: ", field, call. = FALSE)
    }
    value <- value[[1L]]
    if (is.numeric(value)) format(value, digits = 14, scientific = FALSE,
                                  trim = TRUE) else as.character(value)
  }, character(1L))
  paste(values, collapse = "|")
}

iqrs_v1_rekey_structure <- function(row, generation, index, protocol) {
  row$generation <- generation
  row$generation_index <- as.integer(index)
  row$screen_reservoir_seed <- as.integer(
    protocol$search$fixed_screen_matrix_seed
  )
  row$matrix_seed <- row$screen_reservoir_seed
  row$rhs_tau0 <- NA_real_
  row$tau0_mode <- "pending"
  row$tau0_base <- NA_real_
  row$tau_arm <- "pending"
  row$tau_arm_index <- NA_integer_
  row$structure_signature <- paste(
    iqrs_v1_schema, iqrs_v1_structure_fingerprint(row), sep = "|"
  )
  hash <- digest::digest(row$structure_signature, algo = "sha256",
                         serialize = FALSE)
  row$structure_id <- sprintf("iqrs1_%s_s%03d_%s", row$family[[1L]],
                              as.integer(index), substr(hash, 1L, 10L))
  row$candidate_signature <- NA_character_
  row$candidate_id <- NA_character_
  row
}

iqrs_v1_bind_rows <- function(rows) {
  columns <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows <- lapply(rows, function(x) {
    for (column in setdiff(columns, names(x))) x[[column]] <- NA
    x[columns]
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

iqrs_v1_anchor_structures <- function(protocol, family) {
  ledger <- utils::read.csv(protocol$authorities$historical_candidate_ledger,
                            check.names = FALSE, stringsAsFactors = FALSE)
  ledger <- ledger[ledger$family == family, , drop = FALSE]
  ledger <- ledger[order(ledger$normal_selection_rank, ledger$candidate_id),
                   , drop = FALSE]
  ledger <- ledger[!duplicated(ledger$structure_signature), , drop = FALSE]
  n <- as.integer(protocol$search$anchor_structures_per_family)
  if (nrow(ledger) < n) stop("Insufficient historical anchors for ", family,
                             call. = FALSE)
  rows <- vector("list", n)
  for (i in seq_len(n)) {
    row <- ledger[i, , drop = FALSE]
    row$input_fanin_fraction <- as.numeric(row$input_fanin_fraction)
    row$generation <- "historical_anchor"
    rows[[i]] <- iqrs_v1_rekey_structure(row, "historical_anchor", i,
                                         protocol)
  }
  iqrs_v1_bind_rows(rows)
}

iqrs_v1_generate_new_structures <- function(protocol, family) {
  target <- as.integer(protocol$search$new_structures_per_family)
  historical <- utils::read.csv(protocol$authorities$historical_normal_ranking,
                                check.names = FALSE, stringsAsFactors = FALSE)
  historical <- historical[historical$family == family, , drop = FALSE]
  seen <- unique(vapply(seq_len(nrow(historical)), function(i) {
    iqrs_v1_structure_fingerprint(historical[i, , drop = FALSE])
  }, character(1L)))
  catalog <- iqrs_v1_architecture_catalog(protocol)
  m_values <- as.integer(protocol$search$response_lag_values)
  gains <- as.numeric(protocol$preprocessing$input_gain)
  indegrees <- as.integer(protocol$topology$recurrent_indegree)
  fractions <- as.numeric(protocol$topology$input_fanin_fraction)
  inter_values <- as.character(protocol$topology$interlayer_fanin)
  alpha_range <- as.numeric(unlist(protocol$search$alpha_range))
  rho_range <- as.numeric(unlist(protocol$search$rho_range))
  rows <- list()
  cursor <- 1L
  while (length(rows) < target) {
    batch <- iqfr_v2_halton(512L, 12L, start = cursor,
                            shift_seed = iqfr_v2_seed(iqrs_v1_schema, family))
    cursor <- cursor + nrow(batch)
    for (i in seq_len(nrow(batch))) {
      u <- batch[i, ]
      arch <- iqrs_v1_pick_architecture(catalog, u[[1L]], u[[2L]])
      m <- m_values[1L + floor(u[[3L]] * length(m_values)) %% length(m_values)]
      high_memory <- ((length(rows) + 1L) %% 3L) == 0L
      alpha <- if (high_memory) 0.40 + 0.59 * u[[4L]] else {
        alpha_range[[1L]] + diff(alpha_range) * u[[4L]]
      }
      rho <- if (high_memory) 0.90 + 0.099 * u[[5L]] else {
        rho_range[[1L]] + diff(rho_range) * u[[5L]]
      }
      center_scale <- protocol$preprocessing$center_scale[[
        1L + floor(u[[6L]] * length(protocol$preprocessing$center_scale)) %%
          length(protocol$preprocessing$center_scale)
      ]]
      input_bound <- protocol$preprocessing$input_bound[[
        1L + floor(u[[7L]] * length(protocol$preprocessing$input_bound)) %%
          length(protocol$preprocessing$input_bound)
      ]]
      input_gain <- gains[1L + floor(u[[8L]] * length(gains)) %% length(gains)]
      requested_recurrent_indegree <- indegrees[
        1L + floor(u[[9L]] * length(indegrees)) %% length(indegrees)
      ]
      input_fraction <- fractions[
        1L + floor(u[[10L]] * length(fractions)) %% length(fractions)
      ]
      input_fanin <- max(
        1L, min(m + 1L, as.integer(ceiling((m + 1L) * input_fraction)))
      )
      inter_token <- inter_values[
        1L + floor(u[[11L]] * length(inter_values)) %% length(inter_values)
      ]
      n <- iqfr_v2_unpack_integer(arch$n)
      recurrent_indegree <- min(requested_recurrent_indegree, min(n))
      interlayer_fanin <- if (identical(inter_token, "dense")) {
        max(n)
      } else if (length(n) > 1L) {
        min(as.integer(inter_token), min(n[seq_len(length(n) - 1L)]))
      } else as.integer(inter_token)
      row <- cbind(data.frame(family = family, stringsAsFactors = FALSE),
                   arch[c("D", "n", "n_tilde", "layer_shape",
                          "total_states", "readout_dimension")])
      row$m <- m
      row$alpha <- alpha
      row$rho <- rho
      row$center_scale <- center_scale
      row$input_bound <- input_bound
      row$input_gain <- input_gain
      row$recurrent_indegree <- recurrent_indegree
      row$input_fanin_fraction <- input_fraction
      row$input_fanin <- input_fanin
      row$interlayer_fanin <- interlayer_fanin
      fingerprint <- iqrs_v1_structure_fingerprint(row)
      if (fingerprint %in% seen) next
      seen <- c(seen, fingerprint)
      index <- length(rows) + 1L
      rows[[index]] <- iqrs_v1_rekey_structure(
        row, "representation_v1_new", index, protocol
      )
      if (length(rows) == target) break
    }
    if (cursor > 100000L && length(rows) < target) {
      stop("Could not generate enough unseen structures for ", family,
           call. = FALSE)
    }
  }
  iqrs_v1_bind_rows(rows)
}

iqrs_v1_generate_structures <- function(protocol = iqrs_v1_read_protocol()) {
  iqrs_v1_assert_protocol(protocol)
  rows <- lapply(iqrs_v1_families, function(family) {
    anchors <- iqrs_v1_anchor_structures(protocol, family)
    novel <- iqrs_v1_generate_new_structures(protocol, family)
    out <- iqrs_v1_bind_rows(list(anchors, novel))
    out$generation_index <- seq_len(nrow(out))
    for (i in seq_len(nrow(out))) {
      out[i, ] <- iqrs_v1_rekey_structure(
        out[i, , drop = FALSE], out$generation[[i]], i, protocol
      )
    }
    out
  })
  out <- iqrs_v1_bind_rows(rows)
  expected <- as.integer(protocol$search$new_structures_per_family) +
    as.integer(protocol$search$anchor_structures_per_family)
  counts <- table(out$family)
  if (!all(counts[iqrs_v1_families] == expected) ||
      anyDuplicated(out$structure_signature) ||
      anyDuplicated(out$structure_id)) {
    stop("Structure count or identity contract failed.", call. = FALSE)
  }
  identity <- vapply(seq_len(nrow(out)), function(i) {
    D <- as.integer(out$D[[i]])
    n <- iqfr_v2_unpack_integer(out$n[[i]])
    n_tilde <- iqfr_v2_unpack_integer(out$n_tilde[[i]])
    length(n) == D && if (D == 1L) !length(n_tilde) else
      identical(n_tilde, n[seq_len(D - 1L)])
  }, logical(1L))
  if (!all(identity) || max(out$total_states) > 1800L ||
      !any(out$total_states >= 1200L)) {
    stop("Identity projection or large-capacity coverage failed.", call. = FALSE)
  }
  out
}

iqrs_v1_tau_token <- function(tau) {
  gsub("[.]", "p", sprintf("%.2f", as.numeric(tau)))
}

iqrs_v1_copy_sources <- function(protocol, run_root) {
  rows <- list()
  k <- 0L
  for (family in iqrs_v1_families) {
    for (tau in iqrs_v1_quantiles) {
      relative <- protocol$authorities$source_template
      relative <- sub("{family}", family, relative, fixed = TRUE)
      relative <- sub("{tau_token}", iqrs_v1_tau_token(tau), relative,
                      fixed = TRUE)
      source <- file.path(protocol$authorities$source_root, relative)
      if (!file.exists(source)) stop("Missing source: ", source, call. = FALSE)
      destination <- file.path(run_root, "sources", paste0(
        family, "_tau_", iqrs_v1_tau_token(tau), ".csv"
      ))
      if (!file.exists(destination) && !file.copy(source, destination)) {
        stop("Could not copy source: ", source, call. = FALSE)
      }
      source_hash <- iqfr_v2_sha256(source)
      if (!identical(iqfr_v2_sha256(destination), source_hash)) {
        stop("Source-copy hash mismatch: ", destination, call. = FALSE)
      }
      k <- k + 1L
      rows[[k]] <- data.frame(
        family = family, tau = tau, authority_path = source,
        authority_sha256 = source_hash,
        frozen_path = normalizePath(destination, winslash = "/",
                                    mustWork = TRUE),
        frozen_sha256 = source_hash, stringsAsFactors = FALSE
      )
    }
  }
  manifest <- do.call(rbind, rows)
  iqfr_v2_write_csv(manifest, file.path(run_root, "source_manifest.csv"))
  manifest
}

iqrs_v1_make_job_config <- function(repo_root, run_root, protocol, stage,
                                     job_id, payload, plan_fields = list()) {
  config_path <- file.path(run_root, "configs", stage, paste0(job_id, ".json"))
  result_path <- file.path(run_root, "results", stage, paste0(job_id, ".csv"))
  status_path <- file.path(run_root, "status", stage, paste0(job_id, ".json"))
  config <- c(list(
    schema_version = iqrs_v1_schema, protocol_id = protocol$protocol$id,
    protocol_path = file.path(repo_root, iqrs_v1_protocol_relpath),
    protocol_sha256 = iqfr_v2_sha256(file.path(repo_root,
                                                iqrs_v1_protocol_relpath)),
    stage = stage, job_id = job_id, repo_root = repo_root,
    run_root = run_root, result_path = result_path, status_path = status_path
  ), payload)
  iqfr_v2_write_json(config, config_path)
  c(list(stage = stage, job_id = job_id, config_path = config_path,
         config_sha256 = iqfr_v2_sha256(config_path),
         result_path = result_path, status_path = status_path), plan_fields)
}

iqrs_v1_materialize_normal_plan <- function(repo_root, run_root, protocol,
                                             candidates, sources, stage) {
  stage <- match.arg(stage, c("ridge_screen", "rhs_screen"))
  rows <- vector("list", nrow(candidates))
  for (i in seq_len(nrow(candidates))) {
    candidate <- candidates[i, , drop = FALSE]
    source <- sources[sources$family == candidate$family[[1L]] &
                        abs(sources$tau - 0.50) < 1e-12, , drop = FALSE]
    if (nrow(source) != 1L) stop("Median source lookup failed.", call. = FALSE)
    job_id <- paste(stage, candidate$structure_id[[1L]], sep = "__")
    scale_grid <- if (stage == "ridge_screen") {
      as.numeric(protocol$inference$normal_ridge$beta_ridge_tau2)
    } else as.numeric(protocol$inference$normal_rhs$tau0)
    row <- iqrs_v1_make_job_config(
      repo_root, run_root, protocol, stage, job_id,
      payload = list(
        candidate = as.list(candidate), source = as.list(source),
        folds = protocol$selection$blocked_folds, scale_grid = scale_grid,
        seed = iqfr_v2_seed(protocol$protocol$id, stage, job_id),
        budget = if (stage == "rhs_screen") protocol$inference$normal_rhs else
          protocol$inference$normal_ridge
      ),
      plan_fields = list(family = candidate$family[[1L]],
                         structure_id = candidate$structure_id[[1L]])
    )
    rows[[i]] <- as.data.frame(row, stringsAsFactors = FALSE)
  }
  plan <- iqrs_v1_bind_rows(rows)
  iqfr_v2_write_csv(plan, file.path(run_root, "plans", paste0(stage, ".csv")))
  plan
}

iqrs_v1_materialize <- function(repo_root, run_root) {
  protocol <- iqrs_v1_read_protocol(repo_root)
  checks <- iqrs_v1_assert_protocol(protocol)
  branch <- system2("git", c("-C", repo_root, "branch", "--show-current"),
                    stdout = TRUE)
  dirty <- system2("git", c("-C", repo_root, "status", "--porcelain"),
                   stdout = TRUE)
  if (!identical(branch, iqrs_v1_expected_branch) || length(dirty)) {
    stop("Materialization requires the clean dedicated representation branch.",
         call. = FALSE)
  }
  if (dir.exists(run_root)) {
    existing <- list.files(run_root, all.files = TRUE, no.. = TRUE)
    unexpected <- setdiff(existing, c(".pipeline_lock", "pipeline.stdout.log"))
    if (length(unexpected)) {
      stop("Refusing to overwrite nonempty run root: ", run_root,
           " (unexpected: ", paste(unexpected, collapse = ", "), ")",
           call. = FALSE)
    }
  }
  for (part in c("configs", "plans", "results", "status", "logs",
                 "manifests", "summaries", "sources", "storage")) {
    dir.create(file.path(run_root, part), recursive = TRUE,
               showWarnings = FALSE)
  }
  sources <- iqrs_v1_copy_sources(protocol, run_root)
  structures <- iqrs_v1_generate_structures(protocol)
  structure_path <- iqfr_v2_write_csv(
    structures, file.path(run_root, "manifests", "structure_catalog.csv")
  )
  plan <- iqrs_v1_materialize_normal_plan(
    repo_root, run_root, protocol, structures, sources, "ridge_screen"
  )
  expected <- as.integer(protocol$execution$expected_jobs$ridge_screen)
  if (nrow(plan) != expected) stop("Ridge plan count mismatch: ", nrow(plan),
                                   " versus ", expected, call. = FALSE)
  authority_paths <- unlist(protocol$authorities, use.names = TRUE)
  authority_paths <- authority_paths[file.exists(authority_paths)]
  authority <- data.frame(
    key = names(authority_paths), path = unname(authority_paths),
    sha256 = vapply(authority_paths, iqfr_v2_sha256, character(1L)),
    stringsAsFactors = FALSE
  )
  authority_path <- iqfr_v2_write_csv(
    authority, file.path(run_root, "manifests", "authority_manifest.csv")
  )
  head <- system2("git", c("-C", repo_root, "rev-parse", "HEAD"),
                  stdout = TRUE)
  materialization <- list(
    schema_version = iqrs_v1_schema,
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    git = list(branch = branch, head = head),
    protocol_sha256 = iqfr_v2_sha256(file.path(repo_root,
                                                iqrs_v1_protocol_relpath)),
    structure_path = structure_path,
    structure_sha256 = iqfr_v2_sha256(structure_path),
    source_manifest_sha256 = iqfr_v2_sha256(file.path(run_root,
                                                       "source_manifest.csv")),
    authority_manifest_sha256 = iqfr_v2_sha256(authority_path),
    ridge_jobs = nrow(plan), exact_identity_projection = TRUE,
    maximum_total_states = max(structures$total_states)
  )
  iqfr_v2_write_json(materialization,
                     file.path(run_root, "manifests", "materialization.json"))
  session_path <- file.path(run_root, "manifests", "session_info.txt")
  writeLines(c(capture.output(utils::sessionInfo()), "",
               capture.output(base::extSoftVersion())), session_path)
  environment <- list(
    schema_version = iqrs_v1_schema, git_head = head,
    package_version = as.character(utils::packageVersion("exdqlm")),
    source_package_version = as.character(read.dcf(
      file.path(repo_root, "DESCRIPTION"), fields = "Version"
    )[[1L]]),
    r_version = R.version.string, platform = R.version$platform,
    cpu_set = protocol$execution$cpu_set,
    thread_environment = as.list(Sys.getenv(c(
      "OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
      "VECLIB_MAXIMUM_THREADS", "NUMEXPR_NUM_THREADS",
      "RCPP_PARALLEL_NUM_THREADS"
    ), unset = "1"))
  )
  iqfr_v2_write_json(environment,
                     file.path(run_root, "manifests", "environment.json"))
  list(checks = checks, structures = structures, sources = sources, plan = plan)
}

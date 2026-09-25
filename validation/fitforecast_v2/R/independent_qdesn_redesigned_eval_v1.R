iqre_v1_protocol_relpath <- file.path(
  "config", "validation", "independent_qdesn_redesigned_eval_v1",
  "protocol_defaults.yaml"
)

iqre_v1_read_protocol <- function(repo_root = ffv2_repo_root()) {
  path <- file.path(repo_root, iqre_v1_protocol_relpath)
  if (!file.exists(path)) stop("Missing redesigned evaluation protocol: ", path,
                               call. = FALSE)
  yaml::read_yaml(path)
}
iqre_v1_expected_pi_w <- function(n, expected_indegree = 10) {
  n <- as.numeric(n)
  expected_indegree <- as.numeric(expected_indegree)[[1L]]
  if (any(!is.finite(n)) || any(n <= 0) ||
      !is.finite(expected_indegree) || expected_indegree <= 0) {
    stop("n and expected_indegree must be positive and finite.", call. = FALSE)
  }
  pmin(1, expected_indegree / n)
}

iqre_v1_readout_dimension <- function(n, intercept = TRUE) {
  n <- as.integer(n)
  if (!length(n) || any(!is.finite(n)) || any(n <= 0L)) {
    stop("n must contain positive layer widths.", call. = FALSE)
  }
  sum(n) + as.integer(isTRUE(intercept))
}

iqre_v1_identity_projection_args <- function(n) {
  n <- as.integer(n)
  if (!length(n) || any(!is.finite(n)) || any(n <= 0L)) {
    stop("n must contain positive layer widths.", call. = FALSE)
  }
  list(
    D = length(n),
    n = n,
    n_tilde = if (length(n) == 1L) integer(0) else n[-length(n)]
  )
}

iqre_v1_protocol_checks <- function(protocol = iqre_v1_read_protocol()) {
  p <- protocol$protocol
  s <- protocol$scope
  a <- protocol$architecture
  r <- protocol$reservoir_randomization
  x <- protocol$search
  z <- protocol$selection
  rep <- protocol$reporting

  checks <- list(
    protocol_id = identical(p$id, "independent_qdesn_redesigned_eval_v1"),
    launch_disabled = identical(p$launch_enabled, FALSE),
    supersession = identical(
      p$supersession_decision,
      "SUPERSEDED_BY_REDESIGNED_INDEPENDENT_PROTOCOL"
    ),
    families = identical(as.character(s$families),
                         c("normal", "laplace", "gausmix")),
    quantiles = isTRUE(all.equal(as.numeric(s$quantiles), c(.05, .25, .50))),
    primary_models = identical(as.character(s$primary_models),
                               c("dqlm_al", "qdesn_al_rhs")),
    windows = identical(as.integer(unlist(s$fit_window)), c(8501L, 9000L)) &&
      identical(as.integer(unlist(s$heldout_window)), c(9001L, 10000L)),
    rolling_contract = identical(as.integer(s$horizon), 30L) &&
      identical(as.integer(s$final_origin_stride), 1L) &&
      isTRUE(s$teacher_forced_between_origins) &&
      isTRUE(s$recursive_within_horizon),
    heldout_sealed = isTRUE(s$heldout_sealed_during_selection) &&
      isTRUE(z$final_window_access_forbidden),
    activations = identical(a$reservoir_activation, "tanh") &&
      identical(a$lower_state_readout_activation, "identity") &&
      identical(a$readout_link, "identity"),
    readout = identical(as.character(a$readout_columns),
                        c("intercept", "all_reservoir_layers")) &&
      !isTRUE(a$direct_response_lags_in_readout) &&
      !isTRUE(a$direct_exogenous_lags_in_readout) &&
      !isTRUE(a$reservoir_lags_in_readout),
    identity_projection = identical(a$projection$mode, "identity") &&
      isTRUE(a$projection$require_exact_identity),
    fixed_seed = identical(as.integer(r$screening_seed), 910001L) &&
      identical(as.integer(r$finalist_sensitivity_seeds), c(910002L, 910003L)),
    connectivity_rule = identical(as.integer(r$recurrent_expected_indegree), 10L) &&
      identical(r$recurrent_topology, "fixed_indegree") &&
      identical(as.numeric(r$input_connectivity), 1),
    bounded_weights = identical(r$recurrent_weight_distribution,
                                "uniform_minus1_plus1") &&
      identical(r$input_weight_distribution, "uniform_minus1_plus1"),
    search_support = identical(as.integer(x$depth_values), 1:4) &&
      max(as.integer(x$width_values)) >= 300L &&
      max(as.integer(x$response_lag_values)) >= 150L &&
      max(as.numeric(x$shared_alpha_range)) >= .99 &&
      max(as.numeric(x$shared_rho_range)) >= .99,
    broad_tau0 = min(as.numeric(x$tau0_anchor_values)) <= 1e-8 &&
      max(as.numeric(x$tau0_anchor_values)) >= 1e-1,
    no_global_spec = isTRUE(z$global_specification_forbidden),
    complete_surface_only = isTRUE(rep$article_promotion_requires_complete_surface) &&
      !isTRUE(rep$old_and_new_protocol_rows_may_be_mixed)
  )
  data.frame(
    check = names(checks),
    pass = unlist(checks, use.names = FALSE),
    stringsAsFactors = FALSE
  )
}

iqre_v1_assert_protocol <- function(protocol = iqre_v1_read_protocol()) {
  checks <- iqre_v1_protocol_checks(protocol)
  if (any(!checks$pass)) {
    stop("Redesigned evaluation protocol failed: ",
         paste(checks$check[!checks$pass], collapse = ", "), call. = FALSE)
  }
  invisible(checks)
}

iqre_v1_assert_identity_projection <- function(fit, tolerance = 0) {
  res <- fit$reservoir
  if (is.null(res)) stop("Fit has no reservoir contract.", call. = FALSE)
  expected <- iqre_v1_identity_projection_args(res$n)
  if (!identical(as.integer(res$D), as.integer(expected$D)) ||
      !identical(as.integer(res$n_tilde), expected$n_tilde)) {
    stop("n_tilde does not preserve every lower-layer state.", call. = FALSE)
  }
  if (expected$D > 1L) {
    if (!identical(as.logical(res$Q_is_identity), rep(TRUE, expected$D - 1L))) {
      stop("Q_is_identity is not true for every lower layer.", call. = FALSE)
    }
    for (d in seq_len(expected$D - 1L)) {
      target <- diag(1, expected$n[[d]])
      if (!isTRUE(all.equal(res$Q[[d]], target, tolerance = tolerance,
                            check.attributes = TRUE))) {
        stop("Projection Q_", d, " is not the exact identity matrix.",
             call. = FALSE)
      }
    }
  }
  expected_columns <- iqre_v1_readout_dimension(expected$n, intercept = TRUE)
  if (!isTRUE(fit$meta$add_bias) || ncol(fit$X) != expected_columns) {
    stop("Readout is not intercept plus all reservoir states.", call. = FALSE)
  }
  invisible(list(
    D = expected$D,
    n = expected$n,
    n_tilde = expected$n_tilde,
    readout_columns = expected_columns
  ))
}

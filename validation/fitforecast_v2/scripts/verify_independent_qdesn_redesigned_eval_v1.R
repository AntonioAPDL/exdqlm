#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/verify_independent_qdesn_redesigned_eval_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
source(file.path(harness_root, "R", "independent_qdesn_redesigned_eval_v1.R"))

args <- ffv2_parse_args()
repo_root <- ffv2_repo_root()
output_root <- ffv2_resolve_path(
  args$`output-root` %||% file.path(
    "validation", "fitforecast_v2", "local_trackers",
    "independent_qdesn_redesigned_eval_v1_preflight"
  ),
  repo_root = repo_root
)
ffv2_ensure_dir(output_root)

protocol <- iqre_v1_read_protocol(repo_root)
checks <- iqre_v1_protocol_checks(protocol)
iqre_v1_assert_protocol(protocol)

suppressPackageStartupMessages(pkgload::load_all(repo_root, quiet = TRUE))
withr::local_seed(as.integer(protocol$reservoir_randomization$screening_seed))
y <- 200 + 0.03 * seq_len(180L) + 4 * sin(seq_len(180L) / 12) +
  stats::rnorm(180L, sd = 0.4)
shape <- iqre_v1_identity_projection_args(c(8L, 6L, 5L))
fit <- qdesn_fit_vb(
  y = y,
  p0 = 0.25,
  D = shape$D,
  n = shape$n,
  n_tilde = shape$n_tilde,
  m = 5L,
  standardize_inputs = TRUE,
  input_bound = "none",
  alpha = 0.4,
  rho = rep(0.85, shape$D),
  act_f = "tanh",
  act_k = "identity",
  pi_w = iqre_v1_expected_pi_w(shape$n),
  pi_in = 1,
  w_dist = function(n) stats::runif(n, -1, 1),
  in_dist = function(n) stats::runif(n, -1, 1),
  washout = 10L,
  add_bias = TRUE,
  seed = as.integer(protocol$reservoir_randomization$screening_seed),
  fit_readout = FALSE
)
identity <- iqre_v1_assert_identity_projection(fit)

ffv2_write_csv(checks, file.path(output_root, "protocol_checks.csv"))
ffv2_write_json(list(
  schema_version = "independent_qdesn_redesigned_eval_v1_preflight",
  protocol_path = file.path(repo_root, iqre_v1_protocol_relpath),
  protocol_sha256 = ffv2_file_sha256(file.path(repo_root, iqre_v1_protocol_relpath)),
  git = ffv2_git_info(repo_root),
  checks_passed = sum(checks$pass),
  checks_total = nrow(checks),
  identity_projection = identity,
  reservoir_seed = fit$reservoir$seed,
  reservoir_activation = fit$reservoir$act_f,
  lower_state_readout_activation = fit$reservoir$act_k,
  q_identity_flags = as.logical(fit$reservoir$Q_is_identity),
  launch_enabled = isTRUE(protocol$protocol$launch_enabled)
), file.path(output_root, "preflight_summary.json"))

cat(sprintf("protocol checks: %d/%d PASS\n", sum(checks$pass), nrow(checks)))
cat(sprintf("identity projections: %d/%d PASS\n",
            sum(fit$reservoir$Q_is_identity), length(fit$reservoir$Q_is_identity)))
cat("launch enabled: FALSE\n")
cat(sprintf("evidence: %s\n", output_root))

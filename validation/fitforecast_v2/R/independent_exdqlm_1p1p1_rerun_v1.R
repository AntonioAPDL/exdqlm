i111_schema <- "independent_qdesn_exdqlm_1p1p1_rerun_v1"
i111_stage <- "qdesn_dqlm_500obs_independent_exdqlm_1p1p1_rerun_v1"
i111_branch <- "validation/independent-qdesn-exdqlm-1.1.1-rerun-20260827"
i111_authority_id <- "qdesn_dqlm_500obs_trainonly_article_v11_location_orthogonalized_20260827"
i111_package_version <- "1.1.1"
i111_package_source_commit <- "6dba6f2863705e0e90f0ce19e0c75d106d022a52"
i111_package_source_branch <- "feature/jss-resubmission-from-cran-1.0.0"
i111_workers <- 16L
i111_expected_jobs <- 198L
i111_expected_metric_roles <- 216L
i111_expected_source_identities <- 90L
i111_seed_ledger_relpath <- file.path(
  "config", "validation", "independent_qdesn_exdqlm_1p1p1_rerun_v1_seed_ledger.csv"
)
i111_v11_source_fixture_relpath <- file.path(
  "config", "validation", "frozen_sources", "independent_qdesn_v11",
  "normal_tau_0p05_m12_w300_series_wide.csv"
)
i111_v11_source_fixture_sha256 <-
  "fdc14c967268e8cd48cc2118c134e1a70cf446b3684a801a472a757601680122"

i111_static_audit <- function(repo_root = ffv2_repo_root()) {
  imi_v1_static_audit(repo_root, authority_id = i111_authority_id)
}

i111_seed_ledger_path <- function(repo_root = ffv2_repo_root()) {
  file.path(repo_root, i111_seed_ledger_relpath)
}

i111_read_seed_ledger <- function(repo_root = ffv2_repo_root()) {
  path <- i111_seed_ledger_path(repo_root)
  ledger <- ffv2_read_csv(path)
  required <- c(
    "source_identity", "model_variant", "inference", "chain_id", "seed",
    "mcmc_seed", "mcmc_rng_seed", "vb_warm_start_seed", "synthesis_seed",
    "desn_seed", "seed_source", "request_override_path", "request_override_sha256",
    "source_override_path", "source_override_sha256"
  )
  missing <- setdiff(required, names(ledger))
  if (length(missing)) {
    stop(sprintf("1.1.1 seed ledger is missing: %s", paste(missing, collapse = ", ")),
         call. = FALSE)
  }
  key <- paste(ledger$source_identity, ledger$chain_id, sep = "|")
  if (nrow(ledger) != i111_expected_jobs || anyDuplicated(key)) {
    stop("1.1.1 seed ledger does not contain exactly one row per planned replay chain.",
         call. = FALSE)
  }
  ledger
}

i111_seed_row <- function(ledger, source_identity, chain_id) {
  keep <- ledger$source_identity == as.character(source_identity) &
    as.integer(ledger$chain_id) == as.integer(chain_id)
  if (sum(keep) != 1L) {
    stop(sprintf("Seed ledger join failed for chain %d: %s", chain_id, source_identity),
         call. = FALSE)
  }
  ledger[keep, , drop = FALSE]
}

i111_state_root <- function(repo_root, run_id) {
  file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration", run_id)
}

i111_contract <- function(repo_root = ffv2_repo_root()) {
  list(
    schema_version = i111_schema,
    authority_id = i111_authority_id,
    package_version = i111_package_version,
    package_source_branch = i111_package_source_branch,
    package_source_commit = i111_package_source_commit,
    package_source_is_ancestor = identical(
      system2("git", c("-C", repo_root, "merge-base", "--is-ancestor",
                       i111_package_source_commit, "HEAD"),
              stdout = FALSE, stderr = FALSE),
      0L
    ),
    models = c("dqlm", "exdqlm", "qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
    families = c("normal", "laplace", "gausmix"),
    quantiles = c(0.05, 0.25, 0.50),
    train_window = c(8501L, 9000L),
    forecast_window = c(9001L, 10000L),
    max_lead = 30L,
    origin_stride = 30L,
    mcmc = list(chains = 3L, n_burn = 5000L, n_mcmc = 20000L, thin = 1L),
    vb = list(max_iter_min = 300L, posterior_draws = 10000L),
    qdesn_exal_mcmc_update = "m0_v_collapsed_support_logit",
    exdqlm_exal_mcmc_update = "collapsed_slice",
    exal_vb_factorization = "structured_qgamma_qsigma_given_gamma",
    exal_vb_grid_size = 151L,
    success_binary_payloads_allowed = FALSE
  )
}

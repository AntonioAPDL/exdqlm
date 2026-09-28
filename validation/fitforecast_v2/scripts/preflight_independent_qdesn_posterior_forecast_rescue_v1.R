#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
i <- match("--run-root", args)
if (is.na(i) || i == length(args)) stop("Usage: --run-root PATH", call. = FALSE)
run_root <- normalizePath(args[[i + 1L]], winslash = "/", mustWork = TRUE)
repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
suppressPackageStartupMessages(pkgload::load_all(repo_root, quiet = TRUE))
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_qdesn_full_redesign_v2.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_qdesn_full_redesign_v2_runtime.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_qdesn_posterior_forecast_rescue_v1.R"))

protocol <- iqpfr_v1_read_protocol(repo_root)
checks <- iqpfr_v1_protocol_checks(protocol)
authority <- iqpfr_v1_verify_authorities(protocol)
candidates <- utils::read.csv(
  file.path(run_root, "manifests", "candidate_pool.csv"),
  check.names = FALSE, stringsAsFactors = FALSE
)
sources <- utils::read.csv(file.path(run_root, "source_manifest.csv"),
                           check.names = FALSE, stringsAsFactors = FALSE)
plan <- utils::read.csv(
  file.path(run_root, "plans", "posterior_screen.csv"),
  check.names = FALSE, stringsAsFactors = FALSE
)
candidate_counts <- table(candidates$family)
novel <- candidates[grepl("^novel_", candidates$candidate_origin), , drop = FALSE]
novel_tau0_coverage <- vapply(split(novel, novel$family), function(x) {
  min(x$rhs_tau0) <=
    as.numeric(protocol$candidate_pool$exploration_tau0_low_max) &&
    max(x$rhs_tau0) >=
      as.numeric(protocol$candidate_pool$exploration_tau0_high_min)
}, logical(1L))
cell_counts <- table(plan$family, plan$tau, plan$likelihood_family)
config_hash_pass <- vapply(plan$config_path, iqfr_v2_sha256, character(1L)) ==
  plan$config_sha256
source_hash_pass <- vapply(sources$frozen_path, iqfr_v2_sha256,
                           character(1L)) == sources$frozen_sha256
branch <- system2("git", c("-C", repo_root, "branch", "--show-current"),
                  stdout = TRUE)
head <- system2("git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE)
materialization <- iqfr_v2_read_json(file.path(
  run_root, "manifests", "materialization.json"
))

preflight <- list(
  schema_version = iqpfr_v1_schema,
  generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  checks = list(
    protocol = all(checks$pass), authority = all(authority$pass),
    branch = identical(branch, iqpfr_v1_expected_branch),
    head = identical(head, as.character(materialization$git$head)),
    package = identical(as.character(utils::packageVersion("exdqlm")),
                        as.character(protocol$scope$package_version)),
    candidates = nrow(candidates) == 180L && all(candidate_counts == 60L),
    novel = nrow(novel) == 30L &&
      all(table(novel$family) == 10L) &&
      min(novel$alpha) <= 0.30 && max(novel$alpha) >= 0.80 &&
      min(novel$rho) <= 0.40 && max(novel$rho) >= 0.80 &&
      all(novel_tau0_coverage),
    sources = nrow(sources) == 9L && all(source_hash_pass),
    plan = nrow(plan) == 1020L && length(which(cell_counts == 60L)) == 17L &&
      sum(cell_counts) == 1020L,
    config_hashes = all(config_hash_pass),
    no_fitted_binaries = !any(grepl(
      "[.](rds|rda|rdata)$", list.files(run_root, recursive = TRUE,
                                        ignore.case = TRUE)
    ))
  ),
  branch = branch, head = head, candidates = nrow(candidates),
  novel_candidates = nrow(novel), pilot_jobs = nrow(plan),
  hard_cells = 17L, workers = 15L, threads_per_worker = 1L,
  canary_policy = "one AL and one exAL production job before bulk release"
)
preflight$pass <- all(unlist(preflight$checks, use.names = FALSE))
iqfr_v2_write_json(preflight,
                   file.path(run_root, "manifests", "preflight_report.json"))
print(preflight)
if (!isTRUE(preflight$pass)) quit(status = 1L)

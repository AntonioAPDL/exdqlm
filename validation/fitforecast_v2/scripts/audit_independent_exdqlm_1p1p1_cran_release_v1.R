#!/usr/bin/env Rscript

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

parse_args <- function(x) {
  out <- list()
  i <- 1L
  while (i <= length(x)) {
    key <- sub("^--", "", x[[i]])
    if (identical(key, x[[i]]) || i == length(x)) {
      stop("Arguments must be supplied as --name value pairs", call. = FALSE)
    }
    out[[gsub("-", "_", key, fixed = TRUE)]] <- x[[i + 1L]]
    i <- i + 2L
  }
  out
}

sha256_file <- function(path) {
  output <- system2("sha256sum", shQuote(normalizePath(path)), stdout = TRUE)
  if (!length(output)) stop("sha256sum produced no output for ", path, call. = FALSE)
  strsplit(output[[1L]], "[[:space:]]+")[[1L]][[1L]]
}

extract_package <- function(tarball, root) {
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  utils::untar(tarball, exdir = root)
  candidates <- list.dirs(root, recursive = FALSE, full.names = TRUE)
  candidates <- candidates[file.exists(file.path(candidates, "DESCRIPTION"))]
  if (length(candidates) != 1L) {
    stop("Expected exactly one package root in ", tarball, call. = FALSE)
  }
  normalizePath(candidates[[1L]])
}

run_package_probe <- function(library_path, output_path, child_script) {
  status <- system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", shQuote(child_script), shQuote(library_path), shQuote(output_path)),
    stdout = TRUE,
    stderr = TRUE
  )
  code <- attr(status, "status") %||% 0L
  if (!identical(as.integer(code), 0L) || !file.exists(output_path)) {
    stop(
      "Package probe failed for ", library_path, ":\n",
      paste(status, collapse = "\n"),
      call. = FALSE
    )
  }
  readRDS(output_path)
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
required <- c(
  "cran_tarball", "historical_tarball", "cran_library",
  "historical_library", "output_dir"
)
missing <- required[!nzchar(vapply(required, function(x) args[[x]] %||% "", character(1L)))]
if (length(missing)) {
  stop("Missing required arguments: ", paste(missing, collapse = ", "), call. = FALSE)
}

cran_tarball <- normalizePath(args$cran_tarball, mustWork = TRUE)
historical_tarball <- normalizePath(args$historical_tarball, mustWork = TRUE)
cran_library <- normalizePath(args$cran_library, mustWork = TRUE)
historical_library <- normalizePath(args$historical_library, mustWork = TRUE)
output_dir <- normalizePath(args$output_dir, mustWork = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

scratch <- tempfile("ind-exdqlm-cran-audit-")
dir.create(scratch, recursive = TRUE)
on.exit(unlink(scratch, recursive = TRUE, force = TRUE), add = TRUE)

cran_source <- extract_package(cran_tarball, file.path(scratch, "cran"))
historical_source <- extract_package(historical_tarball, file.path(scratch, "historical"))

source_files <- data.frame(
  path = c(
    "DESCRIPTION",
    "R/exdqlmMCMC.R",
    "R/exalStaticMCMC.R",
    "R/exalStaticLDVB.R",
    "R/exal_sigmagam_structured.R",
    "R/exal_inference_config.R",
    "R/exdqlmLDVB.R",
    "src/sampling_truncnorm.cpp",
    "src/sampling_utils.cpp"
  ),
  role = c(
    "package_metadata",
    "dynamic_exal_mcmc_core",
    "static_exal_mcmc_core",
    "static_exal_vb_core",
    "structured_sigmagam_core",
    "shared_inference_configuration",
    "dynamic_exal_vb_entrypoint",
    "serial_rng_helper",
    "serial_rng_helper"
  ),
  exact_match_required = c(FALSE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, TRUE),
  stringsAsFactors = FALSE
)

for (side in c("cran", "historical")) {
  source_root <- if (identical(side, "cran")) cran_source else historical_source
  paths <- file.path(source_root, source_files$path)
  if (any(!file.exists(paths))) {
    stop("Missing audited source files in ", side, ": ",
         paste(source_files$path[!file.exists(paths)], collapse = ", "), call. = FALSE)
  }
  source_files[[paste0(side, "_sha256")]] <- vapply(paths, sha256_file, character(1L))
}
source_files$exact_match <- source_files$cran_sha256 == source_files$historical_sha256
source_files$interpretation <- ifelse(
  source_files$exact_match,
  "byte_identical",
  ifelse(
    source_files$path == "R/exdqlmLDVB.R",
    "source_diff_is_duplicate_max_iter_assignment; behavioral_parity_test_required",
    ifelse(
      source_files$path == "R/exal_inference_config.R",
      "historical_tree_contains_additional_qdesn_configuration; public_exdqlm_defaults_tested_separately",
      "expected_release_or_metadata_difference"
    )
  )
)
utils::write.csv(
  source_files,
  file.path(output_dir, "relevant_source_hash_comparison.csv"),
  row.names = FALSE,
  na = ""
)

child_script <- file.path(scratch, "probe_package.R")
writeLines(
  c(
    "args <- commandArgs(trailingOnly = TRUE)",
    ".libPaths(c(normalizePath(args[[1L]]), .Library))",
    "suppressPackageStartupMessages(library(exdqlm))",
    "desc <- packageDescription('exdqlm')",
    "vb_control <- exal_make_vb_sigmagam_control()",
    "mcmc_formal <- eval(formals(exdqlmMCMC)$mh.proposal)",
    "static_formal <- eval(formals(exalStaticMCMC)$mh.proposal)",
    "options(",
    "  exdqlm.use_cpp_mcmc = FALSE,",
    "  exdqlm.use_cpp_kf = FALSE,",
    "  exdqlm.compute_elbo = TRUE,",
    "  exdqlm.max_iter = 25L,",
    "  exdqlm.vb.min_iter = 5L,",
    "  exdqlm.vb.patience = 2L",
    ")",
    "set.seed(2026082801)",
    "TT <- 18L",
    "y <- cumsum(stats::rnorm(TT, sd = 0.15))",
    "model <- as.exdqlm(list(",
    "  m0 = 0, C0 = matrix(1, 1, 1),",
    "  FF = matrix(1, 1, TT), GG = array(1, dim = c(1, 1, TT))",
    "))",
    "set.seed(2026082802)",
    "vb <- exdqlmLDVB(",
    "  y = y, p0 = 0.25, model = model, df = 1, dim.df = 1,",
    "  fix.sigma = FALSE, n.samp = 20, verbose = FALSE",
    ")",
    "set.seed(2026082803)",
    "mc <- exdqlmMCMC(",
    "  y = y, p0 = 0.25, model = model, df = 1, dim.df = 1,",
    "  fix.sigma = FALSE, n.burn = 30L, n.mcmc = 20L,",
    "  init.from.isvb = FALSE, verbose = FALSE",
    ")",
    "saveRDS(list(",
    "  metadata = list(",
    "    version = as.character(packageVersion('exdqlm')),",
    "    repository = desc$Repository %||% NA_character_,",
    "    publication = desc[['Date/Publication']] %||% NA_character_,",
    "    mcmc_proposals = mcmc_formal,",
    "    static_mcmc_proposals = static_formal,",
    "    vb_factorization = vb_control$factorization,",
    "    vb_grid_size = vb_control$structured_grid_size",
    "  ),",
    "  vb = list(sm = vb$sm, sC = vb$sC, gammasig = vb$gammasig.out, misc = vb$misc$sigmagam),",
    "  mcmc = list(",
    "    theta = mc$samp.theta, gamma = mc$samp.gamma, sigma = mc$samp.sigma,",
    "    sts = mc$samp.sts, post = mc$samp.post.pred,",
    "    proposal = mc$mh.diagnostics$proposal,",
    "    sigma_collapsed = mc$mh.diagnostics$sigma_collapsed",
    "  )",
    "), args[[2L]], version = 3)",
    "`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x"
  ),
  child_script
)

# Move the helper definition before its first use without introducing package dependencies.
child_lines <- readLines(child_script, warn = FALSE)
helper <- child_lines[length(child_lines)]
child_lines <- c(helper, child_lines[-length(child_lines)])
writeLines(child_lines, child_script)

cran_probe_path <- file.path(scratch, "cran_probe.rds")
historical_probe_path <- file.path(scratch, "historical_probe.rds")
cran_probe <- run_package_probe(cran_library, cran_probe_path, child_script)
historical_probe <- run_package_probe(historical_library, historical_probe_path, child_script)

test_script <- file.path(scratch, "run_focused_upstream_tests.R")
writeLines(
  c(
    "args <- commandArgs(trailingOnly = TRUE)",
    ".libPaths(c(normalizePath(args[[1L]]), .Library))",
    "Sys.setenv(NOT_CRAN = 'true')",
    "suppressPackageStartupMessages(library(testthat))",
    "suppressPackageStartupMessages(library(exdqlm))",
    "res <- testthat::test_dir(",
    "  file.path(normalizePath(args[[2L]]), 'tests', 'testthat'),",
    "  filter = '^(exal-inference-config|exal-sigmagam-structured|rng-repeatability)$',",
    "  reporter = 'silent', stop_on_failure = FALSE",
    ")",
    "tab <- as.data.frame(res)",
    "value_sum <- function(name) {",
    "  if (!name %in% names(tab)) return(0L)",
    "  as.integer(sum(tab[[name]], na.rm = TRUE))",
    "}",
    "summary <- data.frame(",
    "  test_scope = 'official_cran_1p1p1_focused_inference_rng',",
    "  files = paste(sort(unique(tab$file)), collapse = ';'),",
    "  test_blocks = nrow(tab),",
    "  passed_expectations = value_sum('passed'),",
    "  failed_expectations = value_sum('failed'),",
    "  errors = value_sum('error'),",
    "  warnings = value_sum('warning'),",
    "  skips = value_sum('skipped'),",
    "  pass = value_sum('failed') == 0L && value_sum('error') == 0L && value_sum('warning') == 0L && value_sum('skipped') == 0L,",
    "  stringsAsFactors = FALSE",
    ")",
    "saveRDS(summary, args[[3L]], version = 3)",
    "if (!isTRUE(summary$pass[[1L]])) quit(status = 1L)"
  ),
  test_script
)
test_summary_path <- file.path(scratch, "focused_upstream_test_summary.rds")
test_status <- system2(
  file.path(R.home("bin"), "Rscript"),
  c(
    "--vanilla", shQuote(test_script), shQuote(cran_library),
    shQuote(cran_source), shQuote(test_summary_path)
  ),
  stdout = TRUE,
  stderr = TRUE
)
test_code <- attr(test_status, "status") %||% 0L
if (!file.exists(test_summary_path)) {
  stop(
    "Focused CRAN package tests did not produce a summary:\n",
    paste(test_status, collapse = "\n"),
    call. = FALSE
  )
}
test_summary <- readRDS(test_summary_path)
utils::write.csv(
  test_summary,
  file.path(output_dir, "focused_upstream_test_summary.csv"),
  row.names = FALSE,
  na = ""
)

checks <- data.frame(
  check_id = c(
    "cran_version_1p1p1",
    "cran_repository_field",
    "dynamic_mcmc_default_collapsed_slice",
    "static_mcmc_default_collapsed_slice",
    "vb_default_structured",
    "vb_default_grid_151",
    "historical_version_1p1p1",
    "interface_signatures_identical",
    "tiny_vb_result_identical",
    "tiny_mcmc_result_identical",
    "tiny_full_probe_identical",
    "required_core_files_identical",
    "focused_upstream_tests_pass"
  ),
  pass = c(
    identical(cran_probe$metadata$version, "1.1.1"),
    identical(cran_probe$metadata$repository, "CRAN"),
    identical(cran_probe$metadata$mcmc_proposals[[1L]], "collapsed_slice"),
    identical(cran_probe$metadata$static_mcmc_proposals[[1L]], "collapsed_slice"),
    identical(cran_probe$metadata$vb_factorization, "structured"),
    identical(as.integer(cran_probe$metadata$vb_grid_size), 151L),
    identical(historical_probe$metadata$version, "1.1.1"),
    identical(cran_probe$metadata[c("mcmc_proposals", "static_mcmc_proposals", "vb_factorization", "vb_grid_size")],
              historical_probe$metadata[c("mcmc_proposals", "static_mcmc_proposals", "vb_factorization", "vb_grid_size")]),
    identical(cran_probe$vb, historical_probe$vb),
    identical(cran_probe$mcmc, historical_probe$mcmc),
    identical(cran_probe[c("vb", "mcmc")], historical_probe[c("vb", "mcmc")]),
    all(source_files$exact_match[source_files$exact_match_required]),
    identical(as.integer(test_code), 0L) && isTRUE(test_summary$pass[[1L]])
  ),
  stringsAsFactors = FALSE
)
checks$detail <- c(
  cran_probe$metadata$version,
  cran_probe$metadata$repository,
  paste(cran_probe$metadata$mcmc_proposals, collapse = ","),
  paste(cran_probe$metadata$static_mcmc_proposals, collapse = ","),
  cran_probe$metadata$vb_factorization,
  as.character(cran_probe$metadata$vb_grid_size),
  historical_probe$metadata$version,
  "dynamic/static MCMC proposal order and structured VB defaults",
  "fixed-seed exdqlmLDVB result object",
  "fixed-seed exdqlmMCMC result object",
  "fixed-seed VB and MCMC result objects",
  paste(source_files$path[source_files$exact_match_required], collapse = ";"),
  paste0(
    test_summary$test_blocks[[1L]], " test blocks; ",
    test_summary$passed_expectations[[1L]], " passed expectations"
  )
)
utils::write.csv(
  checks,
  file.path(output_dir, "behavioral_compatibility_checks.csv"),
  row.names = FALSE,
  na = ""
)

decision <- if (all(checks$pass)) {
  "CRAN_1P1P1_PUBLIC_AUTHORITY_HISTORICAL_EXECUTION_PROVENANCE_RETAINED"
} else {
  "BLOCKED_CRAN_1P1P1_COMPATIBILITY_CHECK_FAILED"
}

manifest <- list(
  schema_version = "independent_exdqlm_cran_release_addendum_v1",
  created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  decision = decision,
  public_software_authority = list(
    package = "exdqlm",
    version = "1.1.1",
    repository = "CRAN",
    canonical_url = "https://CRAN.R-project.org/package=exdqlm",
    doi = "10.32614/CRAN.package.exdqlm",
    publication_utc = cran_probe$metadata$publication,
    source_tarball_sha256 = sha256_file(cran_tarball)
  ),
  frozen_validation_execution = list(
    package = "exdqlm",
    version = historical_probe$metadata$version,
    source_tarball_sha256 = sha256_file(historical_tarball),
    source_commit = "6dba6f2863705e0e90f0ce19e0c75d106d022a52",
    promotion_packet = "validation/fitforecast_v2/promotions/independent_exdqlm_1p1p1_scoped_compatibility_v2_20260828",
    provenance_policy = "retain_exact_historical_artifact; do_not_relabel_tarball"
  ),
  compatibility = list(
    all_checks_pass = all(checks$pass),
    required_core_files_identical = all(source_files$exact_match[source_files$exact_match_required]),
    fixed_seed_vb_identical = identical(cran_probe$vb, historical_probe$vb),
    fixed_seed_mcmc_identical = identical(cran_probe$mcmc, historical_probe$mcmc),
    scientific_rerun_required = FALSE
  )
)
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' is required to write the release manifest", call. = FALSE)
}
jsonlite::write_json(
  manifest,
  file.path(output_dir, "cran_release_manifest.json"),
  auto_unbox = TRUE,
  pretty = TRUE,
  null = "null"
)

artifact_paths <- c(
  "relevant_source_hash_comparison.csv",
  "behavioral_compatibility_checks.csv",
  "focused_upstream_test_summary.csv",
  "cran_release_manifest.json"
)
artifact_manifest <- data.frame(
  path = artifact_paths,
  sha256 = vapply(file.path(output_dir, artifact_paths), sha256_file, character(1L)),
  bytes = as.numeric(file.info(file.path(output_dir, artifact_paths))$size),
  stringsAsFactors = FALSE
)
utils::write.csv(
  artifact_manifest,
  file.path(output_dir, "artifact_manifest.csv"),
  row.names = FALSE,
  na = ""
)

if (!all(checks$pass)) {
  failed <- checks$check_id[!checks$pass]
  stop("CRAN compatibility checks failed: ", paste(failed, collapse = ", "), call. = FALSE)
}

cat(decision, "\n")

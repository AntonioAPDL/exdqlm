#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
as_bool <- function(x) {
  if (is.logical(x)) return(x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
}

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
setwd(repo_root)
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "qdesn_mcmc_dynamic_alpha_confirm_v1.R"
))

stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_dynamic_alpha_confirm_v1"
stub <- file.path("config", "validation", stage)
paths <- list(
  manifest = paste0(stub, "_materialization_manifest.json"),
  shortlist = paste0(stub, "_shortlist.csv"),
  profiles = paste0(stub, "_profiles.csv"),
  assignments = paste0(stub, "_cell_assignments.csv"),
  pairs = paste0(stub, "_pair_map.csv"),
  base_designs = paste0(stub, "_base_designs.csv"),
  topology = paste0(stub, "_topology_audit.csv"),
  source_registry = paste0(stub, "_source_registry.csv"),
  source_files = paste0(stub, "_source_file_hash_audit.csv"),
  defaults = paste0(stub, "_defaults.yaml"),
  grid = paste0(stub, "_grid.csv"),
  seed_audit = paste0(stub, "_seed_contract_audit.csv"),
  specs = paste0(stub, "_target_spec_ids.csv"),
  smoke_defaults = paste0(stub, "_smoke_defaults.yaml"),
  smoke_grid = paste0(stub, "_smoke_grid.csv"),
  smoke_specs = paste0(stub, "_smoke_target_spec_ids.csv"),
  article_context = paste0(stub, "_current_article_metric_context.csv"),
  promotion = paste0(stub, "_promotion_contract.csv"),
  generated = paste0(stub, "_generated_file_manifest.csv")
)
missing_paths <- unlist(paths)[!file.exists(unlist(paths))]
if (length(missing_paths)) {
  stop(sprintf("Missing materialized contract: %s", paste(missing_paths, collapse = ", ")), call. = FALSE)
}
read_csv <- function(path) {
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}
manifest <- jsonlite::read_json(paths$manifest, simplifyVector = TRUE)
shortlist <- read_csv(paths$shortlist)
profiles <- read_csv(paths$profiles)
assignments <- read_csv(paths$assignments)
pairs <- read_csv(paths$pairs)
base_designs <- read_csv(paths$base_designs)
topology <- read_csv(paths$topology)
registry <- read_csv(paths$source_registry)
source_files <- read_csv(paths$source_files)
defaults <- yaml::read_yaml(paths$defaults)
grid <- read_csv(paths$grid)
seed_audit <- read_csv(paths$seed_audit)
specs <- read_csv(paths$specs)
smoke_defaults <- yaml::read_yaml(paths$smoke_defaults)
smoke_grid <- read_csv(paths$smoke_grid)
smoke_specs <- read_csv(paths$smoke_specs)
article_context <- read_csv(paths$article_context)
promotion <- read_csv(paths$promotion)
generated <- read_csv(paths$generated)

expected_registry_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
expected_interface_hash <- "dff814fab1e920c10760645ac9e8d37dfa7f33ae2afba34ee8ed2a5509f4952a"
expected_discovery_hash <- "fb561c286fbb120dc4f1f4ca6ac49fd03805673f10dbcc6a3e3e6274179dcaee"
qdesn_dacf1_validate_shortlist(shortlist)
role_counts <- table(profiles$comparison_role)
generated_hashes <- vapply(generated$path, function(path) {
  if (file.exists(path)) unname(tools::sha256sum(path)) else NA_character_
}, character(1L))

checks <- list(
  package_version = identical(as.character(read.dcf("DESCRIPTION")[1L, "Version"]), "1.0.0"),
  branch = identical(
    trimws(system("git branch --show-current", intern = TRUE)),
    "validation/qdesn-mcmc-dynamic-alpha-confirm-v1-1.0.0"
  ),
  authority_hash = identical(
    unname(tools::sha256sum(manifest$authority_interface_path)), expected_interface_hash
  ),
  discovery_evidence_hash = identical(
    unname(tools::sha256sum(manifest$discovery_evidence_path)), expected_discovery_hash
  ),
  registry_identity = identical(manifest$source_registry_hash_value, expected_registry_hash) &&
    identical(unique(as.character(grid$source_registry_hash_value)), expected_registry_hash),
  source_files_verified = nrow(source_files) == 4L && all(as_bool(source_files$hash_match)),
  generated_hashes_match = nrow(generated) == 17L &&
    all(!is.na(generated_hashes)) && all(generated_hashes == generated$sha256),
  shortlist_count = nrow(shortlist) == 6L,
  base_design_count = nrow(base_designs) == 10L &&
    sum(base_designs$comparison_role == "candidate") == 6L &&
    sum(base_designs$comparison_role == "parent_exact_same_reservoir") == 4L,
  profile_count = nrow(profiles) == 30L && !anyDuplicated(profiles$screening_profile_id),
  profile_roles = identical(
    as.integer(role_counts[c("candidate", "parent_exact_same_reservoir")]),
    c(18L, 12L)
  ),
  sampler_replicates = identical(sort(unique(as.integer(profiles$sampler_replicate))), 1:3),
  unique_controls = length(unique(profiles$control_key)) == 4L,
  assignment_count = nrow(assignments) == 30L && !anyDuplicated(assignments$assignment_id),
  pair_count = nrow(pairs) == 18L && !anyDuplicated(pairs$confirmation_pair_id),
  pair_profiles_exist = all(pairs$candidate_profile_id %in% profiles$screening_profile_id) &&
    all(pairs$parent_profile_id %in% profiles$screening_profile_id),
  dynamic_topology = nrow(topology) == 10L && all(as.integer(topology$dynamic_input_nnz) > 0L) &&
    all(as_bool(topology$candidate_topology_valid)),
  recurrence_disclosed = nrow(topology) == 10L && all(as.integer(topology$recurrent_nnz) == 0L),
  grid_count = nrow(grid) == 30L && !anyDuplicated(grid$root_id),
  spec_count = nrow(specs) == 30L && !anyDuplicated(specs$spec_id),
  likelihood_filter = all(specs$likelihood_family == specs$likelihood_target),
  seed_contract = nrow(seed_audit) == 30L && all(seed_audit$status == "PASS"),
  source_windows = all(as.integer(grid$train_start_source_index) == 8501L) &&
    all(as.integer(grid$train_end_source_index) == 9000L) &&
    all(as.integer(grid$forecast_start_source_index) == 9001L) &&
    all(as.integer(grid$forecast_end_source_index) == 10000L),
  source_design = nrow(registry) == 1L && as.integer(registry$TT_warmup) == 2000L &&
    as.integer(registry$TT_main) == 10000L && as.integer(registry$TT_total) == 12000L &&
    as.integer(registry$forecast_origin_source_index) == 9000L,
  rolling_contract = as.integer(defaults$study_contract$rolling_origin$max_lead_configured) == 30L &&
    as.integer(defaults$study_contract$rolling_origin$origin_stride) == 30L &&
    isTRUE(defaults$study_contract$rolling_origin$no_refit),
  full_budget = as.integer(defaults$pipeline$inference$mcmc$n_burn) == 5000L &&
    as.integer(defaults$pipeline$inference$mcmc$n_mcmc) == 20000L &&
    as.integer(defaults$metrics$posterior_metric_draws) == 200L,
  worker_contract = as.integer(defaults$runtime$workers) == 20L &&
    as.integer(defaults$runtime$campaign_workers) == 20L &&
    as.integer(defaults$runtime$threads) == 1L,
  telemetry_contract = as.integer(defaults$pipeline$inference$mcmc$progress_every) == 50L,
  storage_light = !isTRUE(defaults$pipeline$outputs$keep_draws) &&
    !isTRUE(defaults$pipeline$outputs$keep_mcmc_vb_init) &&
    !isTRUE(defaults$pipeline$outputs$save_forecast_objects) &&
    !isTRUE(defaults$pipeline$outputs$retain_full_rds_on_failure),
  smoke_count = nrow(smoke_grid) == 2L && nrow(smoke_specs) == 2L &&
    length(unique(smoke_grid$sampler_pair_id)) == 1L,
  smoke_budget = as.integer(smoke_defaults$pipeline$inference$mcmc$n_burn) == 4L &&
    as.integer(smoke_defaults$pipeline$inference$mcmc$n_mcmc) == 4L,
  article_context = nrow(article_context) == 2L &&
    identical(sort(article_context$model_variant), sort(c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"))),
  status_agnostic_promotion = nrow(promotion) == 2L && !any(as_bool(promotion$status_filter)) &&
    identical(manifest$metric_promotion_policy, "strictly_lower_finite_value_status_agnostic"),
  article_not_automatic = identical(manifest$article_update_automatic, FALSE),
  no_home_src_paths = !any(grepl(
    "/home/jaguir26/local/src",
    c(unlist(manifest), unlist(defaults), unlist(smoke_defaults), unlist(grid)),
    fixed = TRUE
  ))
)

rows <- data.frame(
  check = names(checks), passed = unlist(checks, use.names = FALSE),
  stringsAsFactors = FALSE
)
passed <- all(rows$passed)
output <- get_arg(
  "--output",
  file.path("reports", "qdesn_mcmc_validation", stage, "contract_verification.json")
)
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(list(
  generated_at = as.character(Sys.time()),
  passed = passed,
  checks = rows,
  candidate_designs = 6L,
  full_specs = nrow(specs),
  candidate_specs = sum(profiles$comparison_role == "candidate"),
  parent_specs = sum(profiles$comparison_role == "parent_exact_same_reservoir"),
  workers = 20L,
  threads_per_fit = 1L,
  article_update_automatic = FALSE
), output, pretty = TRUE, auto_unbox = TRUE, digits = NA)
if (!passed) {
  print(rows[!rows$passed, , drop = FALSE])
  stop("Dynamic-alpha confirmation contract verification failed.", call. = FALSE)
}
cat(sprintf("PASS: %d checks; %d full specs; %d exact pairs.\n", nrow(rows), nrow(specs), nrow(pairs)))

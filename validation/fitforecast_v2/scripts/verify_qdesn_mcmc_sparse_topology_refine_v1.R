#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
as_bool <- function(x) {
  if (is.logical(x)) return(!is.na(x) & x)
  tolower(as.character(x)) %in% c("true", "t", "1", "yes")
}
repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                           winslash = "/", mustWork = TRUE)
setwd(repo_root)
stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_sparse_topology_refine_v1"
stub <- file.path("config", "validation", stage)
read_csv <- function(suffix) utils::read.csv(paste0(stub, suffix), check.names = FALSE,
                                              stringsAsFactors = FALSE)
manifest <- jsonlite::read_json(paste0(stub, "_materialization_manifest.json"),
                                simplifyVector = TRUE)
defaults <- yaml::read_yaml(paste0(stub, "_defaults.yaml"))
smoke_defaults <- yaml::read_yaml(paste0(stub, "_smoke_defaults.yaml"))
generated <- read_csv("_generated_file_manifest.csv")
profiles <- read_csv("_profiles.csv")
assignments <- read_csv("_cell_assignments.csv")
pairs <- read_csv("_pair_map.csv")
topology <- read_csv("_topology_audit.csv")
topology_seeds <- read_csv("_topology_seed_contract.csv")
topology_search <- read_csv("_topology_seed_search_audit.csv")
design <- read_csv("_interaction_design.csv")
registry <- read_csv("_source_registry.csv")
source_files <- read_csv("_source_file_hash_audit.csv")
grid <- read_csv("_grid.csv")
specs <- read_csv("_target_spec_ids.csv")
seed_audit <- read_csv("_seed_contract_audit.csv")
smoke_grid <- read_csv("_smoke_grid.csv")
smoke_specs <- read_csv("_smoke_target_spec_ids.csv")
article <- read_csv("_current_article_metric_context.csv")
promotion <- read_csv("_promotion_contract.csv")
registry_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
authority_hash <- "d412434bb3546cb3e3c4f03d633b30d0e64125948bbe3ac55ef230c0f1c56a53"
generated_hashes <- unname(tools::sha256sum(generated$path))

checks <- c(
  package_version = identical(as.character(read.dcf("DESCRIPTION")[1L, "Version"]), "1.0.0"),
  branch = identical(trimws(system("git branch --show-current", intern = TRUE)),
                     "validation/qdesn-mcmc-sparse-topology-refine-v1-1.0.0"),
  authority_hash = identical(unname(tools::sha256sum(manifest$authority_interface_path)),
                             authority_hash),
  registry_identity = identical(manifest$source_registry_hash_value, registry_hash) &&
    identical(unique(grid$source_registry_hash_value), registry_hash),
  generated_hashes = nrow(generated) == 19L && all(file.exists(generated$path)) &&
    identical(generated_hashes, unname(generated$sha256)),
  profile_count = nrow(profiles) == 168L && !anyDuplicated(profiles$screening_profile_id),
  profile_roles = sum(profiles$comparison_role == "candidate") == 144L &&
    sum(profiles$comparison_role == "matched_sparse_parent") == 24L,
  target_cells = identical(sort(unique(profiles$target_cell_id)),
                           sort(c("al_normal_t0p25", "exal_normal_t0p25"))),
  sampler_replicates = identical(sort(unique(as.integer(profiles$sampler_replicate))), 1:2),
  assignment_count = nrow(assignments) == 168L && !anyDuplicated(assignments$assignment_id),
  pair_count = nrow(pairs) == 144L && !anyDuplicated(pairs$pair_id),
  pair_profiles = all(pairs$candidate_profile_id %in% profiles$screening_profile_id) &&
    all(pairs$parent_profile_id %in% profiles$screening_profile_id),
  topology_seed_count = nrow(topology_seeds) == 6L &&
    all(table(topology_seeds$topology_class) == 2L),
  topology_seed_classes = identical(sort(unique(topology_seeds$recurrent_edges_target)), 1:3),
  topology_search_outcome_blind = nrow(topology_search) == 39L &&
    sum(as_bool(topology_search$selection_valid)) == 6L,
  topology_audit = nrow(topology) == 168L && all(as_bool(topology$topology_valid)) &&
    all(topology$recurrent_nnz == topology$recurrent_edges_target) &&
    all(topology$dynamic_input_nnz >= 1L),
  interaction_design = nrow(design) == 12L &&
    all(table(design$likelihood_target) == 6L) &&
    any(design$rho > 0.35),
  grid_count = nrow(grid) == 168L && !anyDuplicated(grid$root_id),
  spec_count = nrow(specs) == 168L && !anyDuplicated(specs$spec_id),
  likelihood_filter = all(specs$likelihood_family == specs$likelihood_target),
  seed_contract = nrow(seed_audit) == 168L && all(seed_audit$status == "PASS"),
  source_files = nrow(source_files) == 4L && all(as_bool(source_files$hash_match)),
  source_design = nrow(registry) == 1L && registry$TT_warmup == 2000L &&
    registry$TT_main == 10000L && registry$TT_total == 12000L &&
    registry$train_start_source_index == 8501L && registry$train_end_source_index == 9000L &&
    registry$forecast_origin_source_index == 9000L &&
    registry$forecast_start_source_index == 9001L &&
    registry$forecast_end_source_index == 10000L,
  source_windows = all(grid$train_start_source_index == 8501L) &&
    all(grid$train_end_source_index == 9000L) &&
    all(grid$forecast_start_source_index == 9001L) &&
    all(grid$forecast_end_source_index == 10000L),
  rolling_origin = defaults$study_contract$rolling_origin$max_lead_configured == 30L &&
    defaults$study_contract$rolling_origin$origin_stride == 30L &&
    isTRUE(defaults$study_contract$rolling_origin$no_refit),
  full_budget = defaults$pipeline$inference$mcmc$n_burn == 5000L &&
    defaults$pipeline$inference$mcmc$n_mcmc == 20000L &&
    defaults$metrics$posterior_metric_draws == 200L,
  workers = defaults$runtime$workers == 20L && defaults$runtime$campaign_workers == 20L &&
    defaults$runtime$threads == 1L,
  telemetry = defaults$pipeline$inference$mcmc$progress_every == 50L,
  storage_light = !isTRUE(defaults$pipeline$outputs$keep_draws) &&
    !isTRUE(defaults$pipeline$outputs$keep_mcmc_vb_init) &&
    !isTRUE(defaults$pipeline$outputs$save_forecast_objects) &&
    !isTRUE(defaults$pipeline$outputs$retain_full_rds_on_failure),
  smoke = nrow(smoke_grid) == 3L && nrow(smoke_specs) == 3L &&
    identical(sort(unique(smoke_specs$likelihood_family)), c("al", "exal")) &&
    smoke_defaults$pipeline$inference$mcmc$n_burn == 4L &&
    smoke_defaults$pipeline$inference$mcmc$n_mcmc == 4L,
  article_context = nrow(article) == 2L && all(article$family == "normal") &&
    all(abs(article$tau - 0.25) <= 1e-12),
  status_agnostic = nrow(promotion) == 2L && !any(as_bool(promotion$status_filter)) &&
    identical(manifest$metric_promotion_policy,
              "strictly_lower_finite_value_status_agnostic"),
  article_manual = identical(manifest$article_update_automatic, FALSE),
  no_stale_home_paths = !any(grepl("/home/jaguir26/local/src",
                                   c(unlist(manifest), unlist(defaults),
                                     unlist(smoke_defaults), unlist(grid)), fixed = TRUE))
)
rows <- data.frame(check = names(checks), passed = unname(checks),
                   stringsAsFactors = FALSE)
output <- get_arg("--output", file.path("reports", "qdesn_mcmc_validation", stage,
                                        "contract_verification.json"))
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(list(
  generated_at = as.character(Sys.time()), passed = all(rows$passed), checks = rows,
  full_specs = nrow(specs), candidate_specs = sum(profiles$comparison_role == "candidate"),
  parent_specs = sum(profiles$comparison_role == "matched_sparse_parent"),
  exact_pairs = nrow(pairs), workers = 20L, threads_per_fit = 1L,
  article_update_automatic = FALSE
), output, pretty = TRUE, auto_unbox = TRUE, digits = NA)
if (!all(rows$passed)) {
  print(rows[!rows$passed, , drop = FALSE])
  stop("Sparse-topology refinement contract verification failed.", call. = FALSE)
}
cat(sprintf("PASS: %d checks; %d full specs; %d exact pairs.\n",
            nrow(rows), nrow(specs), nrow(pairs)))

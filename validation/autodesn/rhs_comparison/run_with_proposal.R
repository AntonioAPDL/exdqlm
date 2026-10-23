# Optional computational tuning from an already completed TRAINING attempt.
# The target prior, data, bank and benchmark gates remain unchanged. The fixed
# independence proposal is passed to the production exact-Hastings MH kernel.
source("validation/autodesn/rhs_comparison/helpers.R")
source("validation/autodesn/rhs_comparison/runner.R")
args <- commandArgs(trailingOnly = TRUE)
at <- which(args == "--proposal-from")
if (length(at) != 1L || at == length(args))
  stop("Supply --proposal-from /path/to/attempt_N/model_probabilities.csv")
proposal_file <- normalizePath(args[at + 1L], mustWork = TRUE)
args <- args[-c(at, at + 1L)]
if (!"--out" %in% args) stop("An explicit new --out directory is required for a changed proposal")
options <- rhs_options(args)
if (options$method != "rhs") stop("This optional proposal adapter is only for RHS")
if (options$mode == "smoke") stop("Use the normal smoke runner; this adapter requires the full training bank")
if (!"--bank-dir" %in% args)
  options$bank_dir <- file.path(rhs_compare_root, "artifacts/full/bank")
cfg <- rhs_configuration(options)
source_directory <- dirname(dirname(proposal_file))
source_contract <- readRDS(file.path(source_directory, "contract.rds"))
source_cfg <- source_contract$contract$configuration
if (source_contract$contract$method != "rhs" || source_cfg$fit_start != 501L ||
    source_cfg$fit_end != 2500L || !identical(source_cfg$input_sha256, cfg$input_sha256))
  stop("Proposal source must be a matching RHS training-only posterior on the frozen C1 data")
source_attempt_status <- jsonlite::fromJSON(file.path(dirname(proposal_file), "status.json"))
if (!isTRUE(source_attempt_status$complete))
  stop("Proposal source attempt is not complete")
bank_result <- rhs_build_bank(cfg, options$bank_dir)
if (!identical(bank_result$id, source_contract$contract$bank_id))
  stop("Proposal source belongs to a different feature bank")
p <- read.csv(proposal_file)
bank <- bank_result$bank; M <- length(bank$models)
if (nrow(p) != M || !identical(as.integer(p$model), seq_len(M)) ||
    !identical(as.character(p$candidate), as.character(bank$model_info$candidate)))
  stop("Proposal probabilities are not aligned with the frozen bank")
if (!isTRUE(all.equal(p$prior_probability, bank$prior, tolerance = 1e-12)) ||
    any(!is.finite(p$occupancy)) || any(p$occupancy < 0) || abs(sum(p$occupancy) - 1) > 1e-8)
  stop("Invalid training occupancy or prior probabilities")
proposal <- .1 * bank$prior + .9 * p$occupancy
proposal <- proposal / sum(proposal)
stopifnot(all(is.finite(proposal)), all(proposal > 0), length(proposal) == M)
cfg$model_control$proposal <- proposal
cfg$training_proposal <- list(rule = "0.1 * original_model_prior + 0.9 * training_attempt_mean_occupancy",
  source_file = proposal_file, source_file_sha256 = digest::digest(file = proposal_file, algo = "sha256"),
  source_contract_id = source_contract$id,
  source_inference_seconds_all_attempts = source_attempt_status$inference_seconds_all_attempts,
  timing_note = "Source training cost is additional to the new run's inference timer. It includes completed source attempts through this proposal's attempt, not unrelated or unrecorded pilots.",
  adapter_sha256 = digest::digest(file = file.path(rhs_compare_root, "run_with_proposal.R"), algo = "sha256"),
  frozen_before_chain = TRUE, prior_or_likelihood_changed = FALSE,
  test_outcomes_used = FALSE, scope = "Fixed computational proposal; exact Hastings correction remains in force")
dir.create(options$out, recursive = TRUE, showWarnings = FALSE)
rhs_json(cfg, file.path(options$out, "configuration.json"))
write.csv(data.frame(model = seq_len(M), candidate = p$candidate,
  original_prior = bank$prior, training_occupancy = p$occupancy, proposal_probability = proposal),
  file.path(options$out, "frozen_training_proposal.csv"), row.names = FALSE)
if (options$stage != "build") rhs_run_model(bank_result, cfg, options)

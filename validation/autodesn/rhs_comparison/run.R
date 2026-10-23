source("validation/autodesn/rhs_comparison/helpers.R")
options <- rhs_options()
cfg <- rhs_configuration(options)
dir.create(options$out, recursive = TRUE, showWarnings = FALSE)
rhs_json(cfg, file.path(options$out, "configuration.json"))
bank_result <- rhs_build_bank(cfg, options$bank_dir)
cat("Bank ready:", length(bank_result$bank$models), "admitted candidates;", bank_result$bank$n, "training rows\n")
flush.console()
if (options$stage != "build") {
  source("validation/autodesn/rhs_comparison/runner.R")
  rhs_run_model(bank_result, cfg, options)
}

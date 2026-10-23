# Compare the shared builder with the untouched base implementation. Requires
# the base commit to be available in the local Git checkout.
source("validation/autodesn/load_checkout.R")
out <- Sys.getenv("AUTODESN_OUT", "validation/autodesn/artifacts")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
base_file <- tempfile(fileext = ".R")
base_code <- system2("git", c("show", "94bd95784f413f3edde88a35cb991f2a56b6afef:R/qdesn_vb.R"),
                      stdout = TRUE)
stopifnot(is.null(attr(base_code, "status")))
writeLines(base_code, base_file)
base_env <- new.env(parent = .GlobalEnv)
sys.source(base_file, envir = base_env)
y <- sin(seq_len(80) / 5) + 0.02 * seq_len(80)
checks <- list()
for (D in 1:3) for (standardize in c(FALSE, TRUE)) {
  n <- c(9L, 7L, 5L)[seq_len(D)]
  args <- list(y = y, p0 = 0.5, D = D, n = n,
    n_tilde = c(4L, 3L)[seq_len(D - 1L)], m = 3L, alpha = 0.5,
    rho = rep(0.7, D), pi_w = 0.6, pi_in = 0.8, washout = 8L,
    add_bias = TRUE, standardize_inputs = standardize,
    input_bound = "tanh", seed = 100L + D, fit_readout = FALSE)
  old <- do.call(base_env$qdesn_fit_vb, args)
  current <- do.call(qdesn_fit_vb, args)
  checks[[length(checks) + 1L]] <- data.frame(D = D, standardize_inputs = standardize,
    design_identical = identical(old$X, current$X),
    reservoir_identical = identical(old$reservoir, current$reservoir),
    states_identical = identical(old$states, current$states))
}
result <- do.call(rbind, checks)
write.csv(result, file.path(out, "shared_builder_parity.csv"), row.names = FALSE)
print(result, row.names = FALSE)
stopifnot(all(result$design_identical), all(result$reservoir_identical), all(result$states_identical))

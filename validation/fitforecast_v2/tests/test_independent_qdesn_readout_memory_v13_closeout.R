repo <- normalizePath(Sys.getenv("IRM13_REPO", "."), mustWork = TRUE)
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_runtime_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_readout_memory_v13.R"))
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_readout_memory_v13_closeout.R"))
root <- Sys.getenv("IRM13_COMPLETION_AUDIT")
stopifnot(nzchar(root))
audit <- iqt12_read(file.path(root, "analysis/audit.json"))
tests <- iqt12_read(file.path(root, "focused_tests.json"))
health <- do.call(rbind, lapply(audit$health, as.data.frame))
summary <- read.csv(file.path(root, "analysis/summary.csv"))
paired <- read.csv(file.path(root, "analysis/paired.csv"))
count <- 0L
assert <- function(condition, name) {
  stopifnot(isTRUE(condition)); count <<- count+1L; cat("PASS:", name, "\n")
}
reject <- function(h = health, a = audit, t = tests, s = summary, p = paired)
  inherits(try(irm13_closeout_validate(h, a, t, s, p), silent = TRUE), "try-error")
assert(isTRUE(irm13_closeout_validate(health, audit, tests, summary, paired)),
  "completed audited screen accepted")
bad <- health; bad$running[3L] <- 1L
assert(reject(h = bad), "active worker status blocks closeout")
bad <- health; bad$failed[3L] <- 1L
assert(reject(h = bad), "implementation failure cannot be called successful")
bad <- health; bad$pending[3L] <- 1L
assert(reject(h = bad), "unfinished launched work blocks closeout")
bad <- health; bad$complete[3L] <- 19L
assert(reject(h = bad), "missing completed job blocks closeout")
bad <- health; bad$gated[7L] <- 35L
assert(reject(h = bad), "conditional budget must remain exactly 72")
bad <- audit; bad$independent_mean_error <- 1e-6
assert(reject(a = bad), "1e-6 reproduction bound enforced")
bad$independent_mean_error <- 1e-7
assert(!reject(a = bad), "sub-tolerance errors accepted without bitwise equality")
bad <- audit; bad$independent_endpoint_error <- NA_real_
assert(reject(a = bad), "nonfinite endpoint audit rejected")
bad <- audit; bad$first_step_guards_pass <- 191L
assert(reject(a = bad), "failed causal guard blocks closeout")
bad <- audit; bad$selection$article_changed <- TRUE
assert(reject(a = bad), "article replacement prohibited")
bad <- audit; bad$selection$strict_check_gain_over_static <- TRUE
assert(reject(a = bad), "positive campaign cannot be mislabeled negative")
bad <- tests; bad$status <- "FAIL"
assert(reject(t = bad), "failed focused tests rejected")
bad <- summary; bad$mean[1L] <- Inf
assert(reject(s = bad), "nonfinite score rejected")
bad <- summary; bad$lower[1L] <- bad$upper[1L]+1
assert(reject(s = bad), "invalid interval endpoints rejected")
bad <- paired; j <- which(bad$arm_control == "static")[1L]
bad$strict_gain[j] <- !bad$strict_gain[j]
assert(reject(p = bad), "strict local improvements verified independently of labels")
original <- unname(tools::sha256sum(file.path(root, "analysis/paired.csv")))
irm13_closeout_validate(health, audit, tests, summary, paired)
assert(identical(original, unname(tools::sha256sum(file.path(root, "analysis/paired.csv")))),
  "validation leaves evidence byte-identical")
tmp <- tempfile("irm13_portable_manifest_"); dir.create(tmp)
writeLines("original", file.path(tmp, "example.txt"))
iqt12_csv(data.frame(path = "example.txt", bytes = file.info(file.path(tmp, "example.txt"))$size,
  sha256 = unname(tools::sha256sum(file.path(tmp, "example.txt")))), file.path(tmp, "artifact_manifest.csv"))
assert(isTRUE(irm13_closeout_artifacts(tmp)), "relative artifact manifest works in another directory")
writeLines("tampered", file.path(tmp, "example.txt"))
assert(inherits(try(irm13_closeout_artifacts(tmp), silent = TRUE), "try-error"),
  "tampered compact artifact rejected")
if (nzchar(Sys.getenv("IRM13_CLOSEOUT_TEST_EVIDENCE")))
  iqt12_json(list(status = "PASS", checks = count,
    source_hashes = data.frame(path = file.path(repo, "validation/fitforecast_v2", c(
      "R/independent_qdesn_readout_memory_v13_closeout.R",
      "scripts/close_independent_qdesn_readout_memory_v13.R",
      "scripts/audit_independent_qdesn_readout_memory_v13_completed.R",
      "tests/test_independent_qdesn_readout_memory_v13_closeout.R")),
      sha256 = unname(tools::sha256sum(file.path(repo, "validation/fitforecast_v2", c(
        "R/independent_qdesn_readout_memory_v13_closeout.R",
        "scripts/close_independent_qdesn_readout_memory_v13.R",
        "scripts/audit_independent_qdesn_readout_memory_v13_completed.R",
        "tests/test_independent_qdesn_readout_memory_v13_closeout.R")))))),
    Sys.getenv("IRM13_CLOSEOUT_TEST_EVIDENCE"))
cat("TOTAL:", count, "closeout checks passed\n")

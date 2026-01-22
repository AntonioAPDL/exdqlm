#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) {
  cat("Usage: plot_rhs_logtau_profile.R <run_dir_or_models_dir> [--p=0.50] [--out=path]\n")
  quit(status = 1)
}

run_dir <- args[1]
opt_p <- NULL
out_path <- NULL
for (arg in args[-1]) {
  if (grepl("^--p=", arg)) {
    opt_p <- sub("^--p=", "", arg)
  } else if (grepl("^--out=", arg)) {
    out_path <- sub("^--out=", "", arg)
  }
}

models_dir <- run_dir
if (dir.exists(file.path(run_dir, "models"))) {
  models_dir <- file.path(run_dir, "models")
}

if (!dir.exists(models_dir)) {
  stop(sprintf("Models directory not found: %s", models_dir))
}

pattern <- "^rhs_logtau_profile_p.*_iter[0-9]+\\.csv$"
files <- list.files(models_dir, pattern = pattern, full.names = TRUE)
if (length(files) == 0L) {
  stop(sprintf("No rhs_logtau_profile CSVs found in %s", models_dir))
}

if (!is.null(opt_p) && nzchar(opt_p)) {
  tag <- paste0("p", opt_p)
  files <- files[grepl(tag, basename(files), fixed = TRUE)]
}

if (length(files) == 0L) {
  stop("No profile files matched the requested p.")
}

if (is.null(out_path) || !nzchar(out_path)) {
  out_path <- file.path(models_dir, "rhs_logtau_profiles.pdf")
}

files <- sort(files)

pdf(out_path, width = 7.5, height = 5.5)
for (f in files) {
  dat <- try(read.csv(f, stringsAsFactors = FALSE), silent = TRUE)
  if (inherits(dat, "try-error") || is.null(dat$eta_tau)) next

  main <- basename(f)
  plot(dat$eta_tau, dat$obj_total, type = "l", lwd = 2, col = "black",
       xlab = "eta_tau (log tau)", ylab = "objective", main = main)
  if ("term_logV" %in% names(dat)) lines(dat$eta_tau, dat$term_logV, col = "steelblue", lwd = 1)
  if ("term_quad" %in% names(dat)) lines(dat$eta_tau, dat$term_quad, col = "firebrick", lwd = 1)
  if ("term_tau" %in% names(dat)) lines(dat$eta_tau, dat$term_tau, col = "darkgreen", lwd = 1)
  if ("term_lambda" %in% names(dat)) lines(dat$eta_tau, dat$term_lambda, col = "gray40", lwd = 1)
  if ("term_c2" %in% names(dat)) lines(dat$eta_tau, dat$term_c2, col = "purple4", lwd = 1)

  abline(v = dat$eta_tau_center[1], lty = 2, col = "gray50")
  legend("topright", bty = "n", cex = 0.8,
         legend = c("obj_total", "term_logV", "term_quad", "term_tau", "term_lambda", "term_c2", "eta_tau_center"),
         lty = c(1,1,1,1,1,1,2),
         col = c("black","steelblue","firebrick","darkgreen","gray40","purple4","gray50"))
}
dev.off()

cat(sprintf("Wrote: %s\n", out_path))

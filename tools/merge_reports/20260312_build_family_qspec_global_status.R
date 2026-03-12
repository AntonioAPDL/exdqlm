#!/usr/bin/env Rscript

root <- "."
if (!file.exists(file.path(root, "DESCRIPTION"))) {
  stop("Run from the exdqlm repository root.")
}

tau_to_tag <- function(x) gsub("\\.", "p", sprintf("%.2f", as.numeric(x)))
fmt_tau <- function(x) sprintf("%.2f", as.numeric(x))

families <- c("normal", "laplace", "gausmix")
taus <- c("0.05", "0.25", "0.50")
static_tts <- c(100L, 1000L)
dynamic_tts <- c(500L, 5000L)
priors <- c("ridge", "rhs")

make_key <- function(kind, family, tau, tt, prior = "") {
  sprintf("%s|%s|%s|%s|%s", kind, family, fmt_tau(tau), as.integer(tt), prior)
}

rows <- list()

for (fam in families) {
  for (tau in taus) {
    for (tt in static_tts) {
      tau_tag <- tau_to_tag(tau)
      prep <- file.path(
        "results/function_testing_20260309_static_paper_family_qspec",
        fam,
        paste0("tau_", tau_tag),
        sprintf("fit_input_subsample_tt%d_x01_sorted", tt)
      )
      run <- file.path(prep, sprintf("validation_paper_tt%d", tt))
      rows[[length(rows) + 1L]] <- data.frame(
        key = make_key("static_paper", fam, tau, tt, ""),
        kind = "static_paper",
        family = fam,
        tau = fmt_tau(tau),
        tt = tt,
        prior = "none",
        prepared_root = prep,
        run_root = run,
        batch_label = sprintf("static_paper_tt%d", tt),
        stringsAsFactors = FALSE
      )
    }
  }
}

for (fam in families) {
  for (tau in taus) {
    for (tt in static_tts) {
      for (prior in priors) {
        tau_tag <- tau_to_tag(tau)
        prep <- file.path(
          "results/function_testing_20260309_static_shrinkage_family_qspec",
          fam,
          paste0("tau_", tau_tag),
          sprintf("fit_input_subsample_tt%d_x01_sorted", tt)
        )
        run <- file.path(prep, sprintf("validation_shrink_%s_tt%d", prior, tt))
        rows[[length(rows) + 1L]] <- data.frame(
          key = make_key("static_shrink", fam, tau, tt, prior),
          kind = "static_shrink",
          family = fam,
          tau = fmt_tau(tau),
          tt = tt,
          prior = prior,
          prepared_root = prep,
          run_root = run,
          batch_label = sprintf("static_shrink_%s_tt%d", prior, tt),
          stringsAsFactors = FALSE
        )
      }
    }
  }
}

for (fam in families) {
  for (tau in taus) {
    for (tt in dynamic_tts) {
      tau_tag <- tau_to_tag(tau)
      prep <- file.path(
        "results/function_testing_20260309_dynamic_dlm_family_qspec",
        "dlm_constV_smallW",
        fam,
        paste0("tau_", tau_tag),
        sprintf("fit_input_lastTT%d", tt)
      )
      run <- file.path(prep, sprintf("validation_dynamic_tt%d", tt))
      rows[[length(rows) + 1L]] <- data.frame(
        key = make_key("dynamic", fam, tau, tt, ""),
        kind = "dynamic",
        family = fam,
        tau = fmt_tau(tau),
        tt = tt,
        prior = "none",
        prepared_root = prep,
        run_root = run,
        batch_label = sprintf("dynamic_tt%d", tt),
        stringsAsFactors = FALSE
      )
    }
  }
}

status <- do.call(rbind, rows)
if (nrow(status) != 72L) {
  stop("Expected 72 roots, got ", nrow(status))
}

# Jerez states from latest audited status as of 2026-03-11 + 2026-03-11 completion update.
jerez_complete <- c(
  make_key("static_paper", "gausmix", "0.05", 100, ""),
  make_key("static_paper", "gausmix", "0.05", 1000, ""),
  make_key("static_shrink", "gausmix", "0.05", 100, "ridge"),
  make_key("static_shrink", "gausmix", "0.05", 1000, "ridge"),
  make_key("static_shrink", "gausmix", "0.05", 100, "rhs"),
  make_key("static_shrink", "gausmix", "0.05", 1000, "rhs"),
  make_key("dynamic", "gausmix", "0.05", 500, ""),
  make_key("dynamic", "gausmix", "0.25", 500, ""),
  make_key("dynamic", "gausmix", "0.50", 500, "")
)

jerez_running <- c(
  make_key("static_paper", "gausmix", "0.25", 100, ""),
  make_key("static_paper", "gausmix", "0.25", 1000, ""),
  make_key("static_shrink", "gausmix", "0.25", 100, "ridge"),
  make_key("static_shrink", "gausmix", "0.25", 1000, "ridge"),
  make_key("static_shrink", "gausmix", "0.25", 100, "rhs"),
  make_key("static_shrink", "gausmix", "0.25", 1000, "rhs"),
  make_key("dynamic", "gausmix", "0.05", 5000, "")
)

jerez_session <- rep("", nrow(status))
session_map <- c(
  "static_paper|gausmix|0.25|100|" = "qsp_rsp100_20260310_204439",
  "static_paper|gausmix|0.25|1000|" = "qsp_rsp1k_20260310_204439",
  "static_shrink|gausmix|0.25|100|ridge" = "qsp_rss100r_20260310_204439",
  "static_shrink|gausmix|0.25|1000|ridge" = "qsp_rss1kr_20260310_204439",
  "static_shrink|gausmix|0.25|100|rhs" = "qsp_rss100h_20260310_204439",
  "static_shrink|gausmix|0.25|1000|rhs" = "qsp_rss1kh_20260310_204439",
  "dynamic|gausmix|0.05|5000|" = "qsp_rdy5k_fix_20260311_173314"
)
jidx <- match(status$key, names(session_map), nomatch = 0L)
jerez_session[jidx > 0] <- unname(session_map[jidx])

status$jerez_state <- "not_launched"
status$jerez_state[status$key %in% jerez_complete] <- "complete_on_jerez"
status$jerez_state[status$key %in% jerez_running] <- "running_on_jerez"
status$jerez_session <- jerez_session

if (sum(status$jerez_state == "complete_on_jerez") != 9L) {
  stop("Expected 9 complete jerez roots.")
}
if (sum(status$jerez_state == "running_on_jerez") != 7L) {
  stop("Expected 7 running jerez roots.")
}

is_complete_muscat <- function(kind, run_root, tau, prior = "") {
  tau_tag <- tau_to_tag(tau)
  if (kind == "static_paper" || kind == "static_shrink") {
    vb_al <- file.path(run_root, "fits", "vb", sprintf("vb_al_tau_%s_fit.rds", tau_tag))
    vb_ex <- file.path(run_root, "fits", "vb", sprintf("vb_exal_tau_%s_fit.rds", tau_tag))
    mc_al <- file.path(run_root, "fits", "mcmc", sprintf("mcmc_al_tau_%s_fit.rds", tau_tag))
    mc_ex <- file.path(run_root, "fits", "mcmc", sprintf("mcmc_exal_tau_%s_fit.rds", tau_tag))
    metrics <- file.path(run_root, "tables", "metrics_summary.csv")
    return(all(file.exists(c(vb_al, vb_ex, mc_al, mc_ex, metrics))))
  }
  vb_d <- file.path(run_root, "fits", "vb", sprintf("vb_dqlm_tau_%s_fit.rds", tau_tag))
  vb_x <- file.path(run_root, "fits", "vb", sprintf("vb_exdqlm_tau_%s_fit.rds", tau_tag))
  mc_d <- file.path(run_root, "fits", "mcmc", sprintf("mcmc_dqlm_tau_%s_fit.rds", tau_tag))
  mc_x <- file.path(run_root, "fits", "mcmc", sprintf("mcmc_exdqlm_tau_%s_fit.rds", tau_tag))
  metrics <- file.path(run_root, "tables", "metrics_summary.csv")
  all(file.exists(c(vb_d, vb_x, mc_d, mc_x, metrics)))
}

status$prepared_exists <- dir.exists(status$prepared_root)
status$run_root_exists <- dir.exists(status$run_root)
status$run_config_exists <- file.exists(file.path(status$run_root, "tables", "run_config.rds"))

status$muscat_state <- "absent_on_muscat"
for (i in seq_len(nrow(status))) {
  if (is_complete_muscat(status$kind[i], status$run_root[i], status$tau[i], status$prior[i])) {
    status$muscat_state[i] <- "complete_on_muscat"
  } else if (status$run_root_exists[i] || status$run_config_exists[i]) {
    status$muscat_state[i] <- "partial_on_muscat"
  }
}

status$global_state <- ifelse(
  status$jerez_state == "complete_on_jerez", "complete_on_jerez",
  ifelse(
    status$jerez_state == "running_on_jerez", "running_on_jerez",
    ifelse(
      status$muscat_state == "complete_on_muscat", "already_present_on_muscat_complete",
      ifelse(status$muscat_state == "partial_on_muscat", "already_present_on_muscat_partial", "not_launched_anywhere")
    )
  )
)

status$launch_on_muscat_now <- status$global_state %in% c(
  "already_present_on_muscat_partial",
  "not_launched_anywhere"
)

status$sync_pending_from_jerez <- status$jerez_state %in% c("complete_on_jerez", "running_on_jerez")

status <- status[order(status$kind, status$family, status$tau, status$tt, status$prior), ]

out_dir <- file.path("tools", "merge_reports")
global_tsv <- file.path(out_dir, "20260312_family_qspec_global_root_status.tsv")
launch_tsv <- file.path(out_dir, "20260312_family_qspec_muscat_launch_manifest.tsv")
jerez_excl_tsv <- file.path(out_dir, "20260312_family_qspec_jerez_excluded_roots.tsv")

write.table(status, file = global_tsv, sep = "\t", row.names = FALSE, quote = FALSE)
write.table(status[status$launch_on_muscat_now, ], file = launch_tsv, sep = "\t", row.names = FALSE, quote = FALSE)
write.table(status[status$jerez_state %in% c("complete_on_jerez", "running_on_jerez"), ],
            file = jerez_excl_tsv, sep = "\t", row.names = FALSE, quote = FALSE)

cat("Wrote:\n")
cat(" - ", global_tsv, "\n", sep = "")
cat(" - ", launch_tsv, "\n", sep = "")
cat(" - ", jerez_excl_tsv, "\n", sep = "")
cat("\nCounts:\n")
print(table(status$global_state))
cat("launch_on_muscat_now = ", sum(status$launch_on_muscat_now), "\n", sep = "")

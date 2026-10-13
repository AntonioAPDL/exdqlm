#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3L)
repo <- normalizePath(args[1L], mustWork = TRUE)
run <- normalizePath(args[2L], mustWork = TRUE)
out <- args[3L]; dir.create(out, recursive = TRUE, showWarnings = FALSE)
for (file in c("independent_qdesn_training1000_runtime_v1.R",
    "independent_qdesn_training1000_campaign_v1.R", "independent_qdesn_sentinel_mechanism_v1.R",
    "independent_qdesn_training_size_mechanism_v6.R", "independent_qdesn_gausmix_conditioning_v7.R",
    "independent_qdesn_forecast_uncertainty_v8.R", "independent_qdesn_rhs_uncertainty_v9.R",
    "independent_qdesn_layerwise_readout_v10.R", "independent_qdesn_fresh_dgp_v11.R",
    "independent_qdesn_dynamic_location_v12.R", "independent_qdesn_readout_memory_v13.R"))
  source(file.path(repo, "validation/fitforecast_v2/R", file))
irm13_verify(run)
health <- irm13_health(run)
stopifnot(sum(health$complete) == 42L, sum(health$failed+health$running+health$pending) == 0L)
plan <- ifd11_plan_status(run, "selection")
controls <- read.csv(file.path(run, "controls.csv"))
paths <- c(controls$config_path, plan$config_path)
recorded <- read.csv(file.path(run, "review/selection_summary.csv"))
summaries <- profiles <- attributions <- diagnostics <- decomposition <- guards <- list()
score_error <- endpoint_error <- path_error <- 0
for (i in seq_along(paths)) {
  cfg <- iqt12_read(paths[i]); source <- read.csv(cfg$source_path)
  fit_file <- read.csv(file.path(cfg$evidence, "fit_location_draws.csv.gz"))
  forecast_file <- read.csv(file.path(cfg$evidence, "forecast_location_draws.csv.gz"))
  fit <- as.matrix(fit_file[, -1L]); forecast <- as.matrix(forecast_file[, -(1:3)])
  grid <- iqt12_grid(cfg$window)
  stopifnot(identical(as.integer(fit_file[[1L]]), cfg$window$train),
    identical(as.matrix(forecast_file[, 1:3]), as.matrix(grid)),
    ncol(fit) == 300L, ncol(forecast) == 300L, all(is.finite(fit)), all(is.finite(forecast)))
  # Reconstruct scores independently from persisted path matrices.
  check <- function(q, y) {
    residual <- y-q; colMeans(residual * (cfg$p-(residual < 0)))
  }
  draws <- data.frame(fit_rmse = sqrt(colMeans((fit-source$q_target[cfg$window$train])^2)),
    fit_check_loss = check(fit, source$y[cfg$window$train]),
    forecast_mae = colMeans(abs(forecast-source$q_target[grid$target])),
    forecast_rmse = sqrt(colMeans((forecast-source$q_target[grid$target])^2)),
    forecast_check_loss = check(forecast, source$y[grid$target]))
  result <- ifd11_score_companions(fit, forecast, source, cfg$window, cfg$p)
  cell <- paste(cfg$replica, cfg$window$fold, sep = "_")
  old <- recorded[recorded$replica == cell & recorded$arm == cfg$arm, ]
  stopifnot(nrow(old) == 5L)
  for (k in names(draws)) {
    row <- old[old$metric == k, ]; ci <- quantile(draws[[k]], c(.025,.975), names = FALSE, type = 8)
    score_error <- max(score_error, abs(mean(draws[[k]])-row$mean))
    endpoint_error <- max(endpoint_error, abs(ci-c(row$lower,row$upper)))
  }
  matched <- result$summary[match(old$metric, result$summary$metric), ]
  path_error <- max(path_error, abs(old$mean_path_score-matched$mean_path_score))
  id <- data.frame(replica = cfg$replica, fold = cfg$window$fold, cell = cell, arm = cfg$arm)
  summaries[[i]] <- cbind(id, result$summary)
  profile <- result$profile
  origins <- sort(unique(profile$origin)); rank <- match(profile$origin, origins)
  profile$origin_block <- c("early", "middle", "late")[ifelse(rank <= 3, 1, ifelse(rank <= 6, 2, 3))]
  profile$lead_block <- as.character(cut(profile$lead, c(0,1,5,10,20,30),
    labels = c("h1", "h2_5", "h6_10", "h11_20", "h21_30")))
  profile$mean_path_abs_error <- abs(profile$q_mean-profile$true)
  profiles[[i]] <- cbind(id, profile)
  attributions[[i]] <- cbind(id, result$attribution)
  d <- iqt12_read(file.path(cfg$evidence, "diagnostics.json"))
  diagnostics[[i]] <- cbind(id, sigma_ESS = d$trace_diagnostics$sigma_ESS %||% NA_real_,
    intercept_ESS = d$trace_diagnostics$intercept_ESS %||% NA_real_,
    initialization_dependence = d$initialization_dependence %||% NA_real_,
    direct_precision_successes = d$diagnostics$precision_beta$direct_successes %||% NA_integer_,
    precision_rescues = d$diagnostics$precision_beta$rescue_count %||% NA_integer_,
    gamma_refreshes = d$diagnostics$core_gamma_refreshes_per_iter %||% NA_integer_,
    fit_seconds = d$fit_seconds, forecast_seconds = d$forecast_seconds,
    peak_RSS_MiB = d$peak_rss_kib/1024)
  guard_file <- file.path(cfg$evidence, "first_step_guard.csv")
  if (file.exists(guard_file)) guards[[length(guards)+1L]] <- cbind(id, read.csv(guard_file))
  if (cfg$model == "qdesn") {
    parameters <- read.csv(file.path(cfg$evidence, "selected_parameters.csv.gz"))
    stopifnot(nrow(parameters) == 300L, ncol(parameters) == d$readout_dimension+3L)
    intercept <- parameters[[4L]] * d$scale_only
    remainder <- sweep(forecast, 2L, intercept, "-")
    mean_forecast <- colMeans(forecast); mean_remainder <- colMeans(remainder)
    decomposition[[length(decomposition)+1L]] <- cbind(id,
      intercept_variance = var(intercept), average_other_variance = mean(apply(remainder,1,var)),
      average_twice_covariance = mean(vapply(seq_len(nrow(remainder)), function(j)
        2*cov(intercept,remainder[j,]), 0)), average_location_variance = mean(apply(forecast,1,var)),
      mean_location_variance = var(mean_forecast), mean_other_variance = var(mean_remainder),
      mean_twice_covariance = 2*cov(intercept,mean_remainder))
  }
  iqt12_csv(cbind(id, draws), file.path(out, paste0(cell, "__", cfg$arm, "__independent_metric_draws.csv.gz")))
}
stopifnot(max(score_error,endpoint_error,path_error) < 1e-6)
summary <- do.call(rbind,summaries); profile <- do.call(rbind,profiles)
attribution <- do.call(rbind,attributions); diagnostics <- do.call(rbind,diagnostics)
guard <- do.call(rbind,guards); parts <- do.call(rbind,decomposition)
stopifnot(all(guard$pass))
parts$point_variance_identity_error <- abs(parts$intercept_variance+parts$average_other_variance+
  parts$average_twice_covariance-parts$average_location_variance)
parts$mean_variance_identity_error <- abs(parts$intercept_variance+parts$mean_other_variance+
  parts$mean_twice_covariance-parts$mean_location_variance)
stopifnot(max(parts$point_variance_identity_error,parts$mean_variance_identity_error) < 1e-6)
means <- aggregate(summary[c("mean","mean_path_score","width")], summary[c("arm","metric")],mean)
paired <- merge(summary[summary$arm %in% irm13_arms, ], summary[summary$arm %in% c("static","dqlm"), ],
  by=c("replica","fold","cell","metric"),suffixes=c("_candidate","_control"))
paired$strict_gain <- paired$mean_candidate < paired$mean_control
paired$gain_percent <- 100*(1-paired$mean_candidate/paired$mean_control)
paired$width_change_percent <- 100*(paired$width_candidate/paired$width_control-1)
paired$mean_path_gain_percent <- 100*(1-paired$mean_path_score_candidate/paired$mean_path_score_control)
counts <- aggregate(strict_gain~arm_candidate+arm_control+metric,paired,sum)
static <- means[means$arm == "static", ]; dqlm <- means[means$arm == "dqlm", ]
relative <- merge(means, static, by="metric",suffixes=c("","_static"))
relative$mean_change_percent <- 100*(relative$mean/relative$mean_static-1)
relative$width_change_percent <- 100*(relative$width/relative$width_static-1)
relative$central_change_percent <- 100*(relative$mean_path_score/relative$mean_path_score_static-1)
columns <- c("mae","mean_path_abs_error","check_loss","band_width","interval_score")
lead <- aggregate(profile[columns],profile[c("arm","lead_block")],mean)
origin <- aggregate(profile[columns],profile[c("arm","origin_block")],mean)
cell_origin <- aggregate(profile[columns],profile[c("cell","arm","origin_block")],mean)
cell_lead <- aggregate(profile[columns],profile[c("cell","arm","lead_block")],mean)
phase <- read.csv(file.path(run,"review/selection_phase_summary.csv"))
phase_means <- aggregate(phase[c("mean","lower","upper")],phase[c("arm","metric","phase_offset")],mean)
timing <- aggregate(diagnostics[c("fit_seconds","forecast_seconds","peak_RSS_MiB")],
  list(arm=diagnostics$arm),mean)
for (name in c("summary","profile","attribution","diagnostics","guard","parts","means","paired",
    "counts","relative","lead","origin","cell_origin","cell_lead","phase_means","timing"))
  iqt12_csv(get(name),file.path(out,paste0(name,if(name == "profile") ".csv.gz" else ".csv")))
manifest_files <- c(file.path(run,paste0(c("source","package","input","frozen","control_import"),"_hashes.csv")),
  list.files(file.path(run,"plans"),pattern="_hashes[.]csv$",full.names=TRUE),
  list.files(file.path(run,"evidence"),pattern="manifest[.]csv$",recursive=TRUE,full.names=TRUE),
  file.path(run,"selection_review_hashes.csv"))
files <- list.files(run,full.names=TRUE,recursive=TRUE); files <- files[!file.info(files)$isdir]
state <- iqt12_read(file.path(run,"campaign.json"))
audit <- list(timestamp_UTC=format(Sys.time(),tz="UTC",format="%Y-%m-%dT%H:%M:%SZ"),
  timestamp_Pacific=format(Sys.time(),tz="America/Los_Angeles",format="%Y-%m-%d %H:%M:%S %Z"),
  source_head=state$head, health=health, verified_surfaces=length(paths),
  finite_outer_draws_per_surface=300L, independent_mean_error=score_error,
  independent_endpoint_error=endpoint_error, independent_mean_path_error=path_error,
  first_step_guards=nrow(guard), first_step_guards_pass=sum(guard$pass),
  manifest_count=length(manifest_files),manifest_rows=sum(vapply(manifest_files,function(path)nrow(read.csv(path)),0L)),
  run_size_MiB=sum(file.info(files)$size)/1024^2,
  fitted_binary_payloads=files[grepl("[.](rds|rda|rdata|ffv2handoff)$",files,ignore.case=TRUE)],
  selection=iqt12_read(file.path(run,"selection_review.json")),
  finite_cell_metric_gains_vs_static=sum(paired$strict_gain[paired$arm_control=="static"]),
  finite_forecast_metric_gains_vs_static=sum(paired$strict_gain[paired$arm_control=="static" & grepl("^forecast",paired$metric)]),
  average_accuracy_gain_over_static=any(relative$mean_change_percent[relative$arm %in% irm13_arms & relative$metric=="forecast_mae"] < 0),
  numerical_score_tolerance=1e-6,
  observations_not_promoted=TRUE)
iqt12_json(audit,file.path(out,"audit.json"))
iqt12_hash(c(list.files(out,full.names=TRUE)[basename(list.files(out,full.names=TRUE)) != "audit_hashes.csv"],
  normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L]), mustWork = TRUE)),
  file.path(out,"audit_hashes.csv"))
iqt12_verify(file.path(out,"audit_hashes.csv"))
print(audit); print(means); print(counts); print(lead); print(origin)

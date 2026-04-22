#!/usr/bin/env Rscript

daily_input_path <- Sys.getenv(
  "EXDQLM_DAILY_USGS_PATH",
  unset = "/home/jaguir26/data/exdqlm_experiments/ex3_daily/big_trees_daily_usgs_ppt_soil.csv"
)

repo_root <- normalizePath(file.path(getwd()), mustWork = TRUE)
if (!file.exists(daily_input_path)) {
  stop("Daily USGS input file not found: ", daily_input_path, call. = FALSE)
}

df <- read.csv(daily_input_path, stringsAsFactors = FALSE)
required_cols <- c("date", "usgs_cfs")
missing_cols <- setdiff(required_cols, names(df))
if (length(missing_cols)) {
  stop("Missing required columns in daily input: ", paste(missing_cols, collapse = ", "), call. = FALSE)
}

df$date <- as.Date(df$date)
df <- df[order(df$date), c("date", "usgs_cfs")]
if (any(!is.finite(df$usgs_cfs))) {
  stop("Daily usgs_cfs column must be finite.", call. = FALSE)
}

month_id <- format(df$date, "%Y-%m")
monthly <- aggregate(df$usgs_cfs, by = list(month = month_id), FUN = mean, na.rm = TRUE)
monthly$date <- as.Date(paste0(monthly$month, "-01"))
monthly <- monthly[order(monthly$date), ]

start_year <- as.integer(format(monthly$date[1], "%Y"))
start_month <- as.integer(format(monthly$date[1], "%m"))
BTflowUSGS <- ts(monthly$x, start = c(start_year, start_month), frequency = 12)

output_path <- file.path(repo_root, "data", "BTflowUSGS.rda")
save(BTflowUSGS, file = output_path, compress = "bzip2")

cat("Saved", output_path, "\n")
cat("Range:", format(monthly$date[1]), "to", format(monthly$date[nrow(monthly)]), "\n")
cat("Length:", length(BTflowUSGS), "\n")

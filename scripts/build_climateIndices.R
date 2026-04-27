#!/usr/bin/env Rscript

input_path <- Sys.getenv(
  "EXDQLM_CLIMATE_INDICES_PATH",
  unset = "/home/jaguir26/muscat_data_backup/jaguir26/project1_ucsc_phd/climate_indices/combined_indices.csv"
)

repo_root <- normalizePath(getwd(), mustWork = TRUE)
if (!file.exists(input_path)) {
  stop("Climate-index input file not found: ", input_path, call. = FALSE)
}

raw <- read.csv(input_path, stringsAsFactors = FALSE, check.names = FALSE)
source_names <- c(
  date = "Date",
  nino3 = "Ni\u00f1o 3",
  nao = "NAO",
  nino12 = "Ni\u00f1o 1+2",
  whwp = "WHWP",
  gmt = "GMT",
  oni = "ONI",
  pna = "PNA",
  noi = "NOI",
  wp = "WP",
  nino34 = "Ni\u00f1o 3.4",
  solar_flux = "Solar Flux",
  amo = "AMO",
  espi = "ESPI",
  tsa = "TSA",
  nino4 = "Ni\u00f1o 4",
  tna = "TNA",
  soi = "SOI"
)

missing_cols <- setdiff(unname(source_names), names(raw))
if (length(missing_cols)) {
  stop("Missing climate-index columns: ", paste(missing_cols, collapse = ", "), call. = FALSE)
}

climateIndices <- data.frame(
  date = as.Date(raw[[source_names[["date"]]]]),
  stringsAsFactors = FALSE
)

for (nm in setdiff(names(source_names), "date")) {
  climateIndices[[nm]] <- as.numeric(raw[[source_names[[nm]]]])
}

if (anyNA(climateIndices$date)) {
  stop("Climate-index dates could not be parsed.", call. = FALSE)
}

expected_dates <- seq(min(climateIndices$date), max(climateIndices$date), by = "month")
if (!identical(climateIndices$date, expected_dates)) {
  stop("Climate-index dates are not a complete monthly sequence.", call. = FALSE)
}

value_cols <- setdiff(names(climateIndices), "date")
if (anyNA(climateIndices[value_cols])) {
  stop("Climate-index values contain missing entries.", call. = FALSE)
}

output_path <- file.path(repo_root, "data", "climateIndices.rda")
save(climateIndices, file = output_path, compress = "bzip2")

cat("Saved", output_path, "\n")
cat("Range:", format(min(climateIndices$date)), "to", format(max(climateIndices$date)), "\n")
cat("Rows:", nrow(climateIndices), "\n")

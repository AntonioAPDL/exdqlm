# Run study scripts from the repository root. Source the checked-out code rather
# than silently picking an older installed exdqlm package.
stopifnot(file.exists("DESCRIPTION"), file.exists("R/autodesn.R"))
for (.autodesn_source_file in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(.autodesn_source_file, local = .GlobalEnv)
}
rm(.autodesn_source_file)
.autodesn_checkout_revision <- suppressWarnings(.qdesn_vb_package_sha())
.autodesn_source_paths <- list.files("R", pattern = "\\.R$", full.names = TRUE)
.autodesn_source_manifest <- data.frame(path = .autodesn_source_paths,
  md5 = unname(tools::md5sum(.autodesn_source_paths)))
options(warn = 1)

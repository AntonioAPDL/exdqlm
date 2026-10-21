# Run against the installed package built from this checkout, with real
# namespace dispatch and the existing test helpers. An optional regular-expression
# filter allows a focused development run before the complete suite.
stopifnot(file.exists("DESCRIPTION"))
library(testthat)
library(exdqlm)
out <- Sys.getenv("AUTODESN_OUT", "validation/autodesn/artifacts")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
filter <- Sys.getenv("AUTODESN_TEST_FILTER", "")
if (!nzchar(filter)) filter <- NULL
testthat::set_max_fails(Inf)
res <- testthat::test_dir("tests/testthat", package = "exdqlm", load_package = "installed",
                          filter = filter, reporter = "summary",
                          stop_on_failure = FALSE, stop_on_warning = FALSE)
tab <- as.data.frame(res)
flat <- tab[, !vapply(tab, is.list, logical(1)), drop = FALSE]
name <- if (is.null(filter)) "package_tests.csv" else "focused_tests.csv"
write.csv(flat, file.path(out, name), row.names = FALSE)
writeLines(c(paste("Package version:", as.character(utils::packageVersion("exdqlm"))),
              paste("Filter:", if (is.null(filter)) "all" else filter),
              capture.output(sessionInfo())), file.path(out, sub("csv$", "txt", name)))
if (any(tab$failed > 0L | tab$error)) quit(status = 1L)

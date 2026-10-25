# Checkpoints are computational state, never additional posterior draws.
.ext_checkpoint_control <- function(x) {
  if (is.null(x)) return(NULL)
  if (!identical(RNGkind(), c("Mersenne-Twister", "Inversion", "Rejection"))) stop("Checkpointing requires RNGkind Mersenne-Twister/Inversion/Rejection; other samplers retain their existing RNG support.", call. = FALSE)
  .ext_named(x, c("path", "every", "resume", "stop_after", "source_id"), "checkpoint")
  z <- utils::modifyList(list(every = 8000L, resume = FALSE, stop_after = Inf, source_id = NULL), x)
  if (!is.character(z$path) || length(z$path) != 1L || is.na(z$path) || !nzchar(z$path)) stop("checkpoint path must be one nonempty filename.", call. = FALSE)
  .autodesn_integer(z$every, "checkpoint every")
  .autodesn_flag(z$resume, "checkpoint resume")
  if (length(z$stop_after) != 1L || is.na(z$stop_after) || z$stop_after < 1 || (!is.infinite(z$stop_after) && z$stop_after != floor(z$stop_after))) stop("checkpoint stop_after must be a positive integer or Inf.", call. = FALSE)
  if (!is.null(z$source_id) && (!is.character(z$source_id) || length(z$source_id) != 1L || is.na(z$source_id) || !grepl("^[0-9a-f]{64}$", z$source_id))) stop("checkpoint source_id must be a SHA256 identity.", call. = FALSE)
  if (file.exists(z$path) && !z$resume) stop("Checkpoint exists; explicitly request resume or use a new path.", call. = FALSE)
  if (z$resume && !file.exists(z$path)) stop("Requested checkpoint does not exist.", call. = FALSE)
  if (!dir.exists(dirname(z$path))) stop("Checkpoint parent directory must already exist.", call. = FALSE)
  z
}

.ext_checkpoint_code_id <- function() {
  e <- environment(.ext_fit)
  names <- sort(ls(e, all.names = TRUE))
  names <- names[grepl("^(\\.ext_|\\.autodesn_|autodesn_)", names) & !grepl("_cpp$", names)]
  code <- lapply(names, function(n) {
    f <- get(n, e, inherits = FALSE)
    # Deparse excludes JIT bytecode/compiled-object serialization state. Native
    # wrappers contain process-specific pointers; their verified source_id is
    # supplied separately when using C++.
    if (is.function(f)) list(formals = deparse(formals(f)), body = deparse(body(f))) else NULL
  })
  digest::digest(stats::setNames(code, names), algo = "sha256")
}

.ext_checkpoint_read <- function(path, id) {
  x <- readRDS(path)
  if (!is.list(x) || !identical(x$version, 1L) || !identical(x$id, id) ||
      !identical(x$sha256, digest::digest(x$payload, algo = "sha256"))) stop("Checkpoint identity or payload checksum mismatch.", call. = FALSE)
  x$payload
}

.ext_checkpoint_write <- function(path, id, payload) {
  tmp <- tempfile(".autodesn-checkpoint-", tmpdir = dirname(path))
  on.exit(unlink(tmp), add = TRUE)
  x <- list(version = 1L, id = id, sha256 = digest::digest(payload, algo = "sha256"), payload = payload)
  saveRDS(x, tmp, compress = FALSE, version = 3)
  .ext_checkpoint_read(tmp, id)
  # Same-directory rename publishes a complete file atomically on POSIX.
  # Use one writer per path; a stale or truncated temporary file is never read.
  if (!file.rename(tmp, path)) stop("Could not atomically publish checkpoint.", call. = FALSE)
  invisible(NULL)
}

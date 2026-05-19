#!/usr/bin/env Rscript

# ====================================
# User Configuration
# ====================================
target_dir <- "out_videos"
logs_dir   <- "logs"
# ====================================

library(tools)

now      <- format(Sys.time(), "%Y%m%d_%H%M%S")
log_file <- file.path(logs_dir, paste0("/add_faststart_log_", now, ".log"))
dir.create(dirname(log_file), recursive = TRUE, showWarnings = FALSE)

log_message <- function(msg) {
  cat(msg, "\n")
  write(msg, file = log_file, append = TRUE)
}

check_ffmpeg <- function() {
  res <- suppressWarnings(system2("ffmpeg", "-version", stdout = TRUE, stderr = TRUE))
  if (length(res) == 0) stop("ERROR: ffmpeg not found. Install it or add it to PATH.")
}

has_faststart <- function(filepath) {
  output <- system2("ffprobe", args = c("-v", "trace", "-i", shQuote(filepath)),
                    stdout = TRUE, stderr = TRUE)
  moov_line <- grep("type:'moov'", output)[1]
  mdat_line <- grep("type:'mdat'", output)[1]
  if (is.na(moov_line) || is.na(mdat_line)) return(FALSE)
  moov_line < mdat_line
}

check_ffmpeg()

if (!dir.exists(target_dir)) stop(paste("ERROR: Directory not found:", target_dir))

all_files <- list.files(target_dir, recursive = TRUE, full.names = TRUE)
mp4_files <- Filter(function(f) tolower(paste0(".", file_ext(f))) == ".mp4", all_files)

total_mp4 <- length(mp4_files)
if (total_mp4 == 0) {
  cat("No mp4 files found in", target_dir, "\n")
  quit(save = "no")
}

cat("Checking", total_mp4, "mp4 files for faststart...\n")

to_fix <- Filter(function(f) {
  cat(sprintf("\r  Checking %s  ", basename(f)))
  flush.console()
  !has_faststart(f)
}, mp4_files)

cat("\n\n")

total <- length(to_fix)
if (total == 0) {
  cat("All mp4 files already have faststart.\n")
  log_message("All mp4 files already have faststart. Nothing to do.")
  quit(save = "no")
}

log_message(paste("Found", total, "mp4 files missing faststart"))
cat("Adding faststart to", total, "files...\n\n")

results    <- list()
start_time <- Sys.time()

for (i in seq_along(to_fix)) {
  input_path <- to_fix[i]
  tmp_path   <- paste0(input_path, ".faststart.tmp.mp4")

  err_file <- tempfile(fileext = ".log")
  status <- system2("ffmpeg", args = c(
    "-i", shQuote(input_path),
    "-c", "copy",
    "-map_metadata", "0",
    "-movflags", "use_metadata_tags+faststart",
    shQuote(tmp_path)
  ), stdout = FALSE, stderr = err_file)

  if (status != 0) {
    err_msg  <- readLines(err_file, warn = FALSE)
    err_tail <- paste(tail(err_msg, 10), collapse = "\n")
    unlink(err_file)
    unlink(tmp_path)
    msg <- paste("✘ Failed:", basename(input_path), "\n", err_tail)
    log_message(msg)
    results[[i]] <- list(success = FALSE, file = basename(input_path))
    next
  }

  unlink(err_file)
  file.remove(input_path)
  file.rename(tmp_path, input_path)

  results[[i]] <- list(success = TRUE, file = basename(input_path))

  pct     <- round(100 * i / total)
  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  if (elapsed > 0) {
    eta_secs <- elapsed / i * (total - i)
    eta <- if (is.finite(eta_secs)) {
      sprintf("%02d:%02d:%02d", floor(eta_secs / 3600), floor((eta_secs %% 3600) / 60), floor(eta_secs %% 60))
    } else "calculating..."
  } else {
    eta <- "calculating..."
  }

  bar_width <- 50
  filled    <- round(bar_width * i / total)
  bar       <- paste0(rep("=", filled), collapse = "")
  empty     <- paste0(rep(" ", bar_width - filled), collapse = "")
  status_ch <- if (isTRUE(results[[i]]$success)) "✓" else "✗"

  cat(sprintf("\r[%s%s] %d%% (%d/%d) ETA: %s %s %s  ", bar, empty, pct, i, total, eta, status_ch, basename(to_fix[i])))
  flush.console()
}

cat("\n\n")

successes <- sum(sapply(results, function(r) isTRUE(r$success)))
failures  <- sum(sapply(results, function(r) !isTRUE(r$success)))

log_message("=== Faststart complete ===")
log_message(paste("Fixed:  ", successes))
log_message(paste("Failed: ", failures))

failed_files <- Filter(Negate(is.null), lapply(results, function(r) if (!isTRUE(r$success)) r$file else NULL))
if (length(failed_files) > 0) {
  log_message("Failed files:")
  for (f in failed_files) log_message(paste(" -", f))
}

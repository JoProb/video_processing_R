#!/usr/bin/env Rscript

# ====================================
# User Configuration
# ====================================
target_dir <- "out_videos" # directory containing already-processed videos
logs_dir   <- "logs"
delete_originals <- TRUE  # Set to FALSE to keep the original non-mp4 files after remuxing
# ====================================

library(tools)

now          <- format(Sys.time(), "%Y%m%d_%H%M%S")
log_file     <- file.path(logs_dir, paste0("/remux_to_mp4_log_", now, ".log"))
dir.create(dirname(log_file), recursive = TRUE, showWarnings = FALSE)

log_message <- function(msg) {
  cat(msg, "\n")
  write(msg, file = log_file, append = TRUE)
}

check_ffmpeg <- function() {
  res <- suppressWarnings(system2("ffmpeg", "-version", stdout = TRUE, stderr = TRUE))
  if (length(res) == 0) stop("ERROR: ffmpeg not found. Install it or add it to PATH.")
}

check_ffmpeg()

if (!dir.exists(target_dir)) stop(paste("ERROR: Directory not found:", target_dir))

all_files  <- list.files(target_dir, recursive = TRUE, full.names = TRUE)
video_ext  <- c(".avi", ".mov", ".mkv")
to_remux   <- Filter(function(f) tolower(paste0(".", file_ext(f))) %in% video_ext, all_files)

total <- length(to_remux)
if (total == 0) {
  cat("No non-mp4 video files found in", target_dir, "\n")
  quit(save = "no")
}

log_message(paste("Found", total, "non-mp4 videos to remux"))
cat("\nRemuxing", total, "videos to .mp4...\n\n")

results  <- list()
start_time <- Sys.time()

for (i in seq_along(to_remux)) {
  input_path  <- to_remux[i]
  output_path <- paste0(file_path_sans_ext(input_path), ".mp4")

  # Skip if .mp4 already exists
  if (file.exists(output_path)) {
    log_message(paste("Skipped (mp4 exists):", basename(input_path)))
    results[[i]] <- list(success = TRUE, file = basename(input_path), skipped = TRUE)
    next
  }

  mtime <- file.info(input_path)$mtime
  creation_time <- format(mtime, "%Y-%m-%dT%H:%M:%S.000000Z", tz = "UTC")

  err_file <- tempfile(fileext = ".log")
  status <- system2("ffmpeg", args = c(
    "-i", shQuote(input_path),
    "-c", "copy",
    "-map_metadata", "0",
    "-metadata", paste0("creation_time=", creation_time),
    "-movflags", "use_metadata_tags+faststart",
    shQuote(output_path)
  ), stdout = FALSE, stderr = err_file)

  if (status != 0) {
    err_msg  <- readLines(err_file, warn = FALSE)
    err_tail <- paste(tail(err_msg, 10), collapse = "\n")
    unlink(err_file)
    msg <- paste("✘ Failed:", basename(input_path), "\n", err_tail)
    log_message(msg)
    results[[i]] <- list(success = FALSE, file = basename(input_path))
    next
  }

  unlink(err_file)

  if (isTRUE(delete_originals)) {
    file.remove(input_path)
  }

  results[[i]] <- list(success = TRUE, file = basename(input_path), skipped = FALSE)

  # Progress
  pct     <- round(100 * i / total)
  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  if (i > 0 && elapsed > 0) {
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
  status_ch <- if (!results[[i]]$success) "✗" else if (isTRUE(results[[i]]$skipped)) "—" else "✓"

  cat(sprintf("\r[%s%s] %d%% (%d/%d) ETA: %s %s %s  ", bar, empty, pct, i, total, eta, status_ch, basename(to_remux[i])))
  flush.console()
}

cat("\n\n")

successes <- sum(sapply(results, function(r) isTRUE(r$success) && !isTRUE(r$skipped)))
skipped   <- sum(sapply(results, function(r) isTRUE(r$skipped)))
failures  <- sum(sapply(results, function(r) !isTRUE(r$success)))

log_message(paste("=== Remux complete ==="))
log_message(paste("Converted: ", successes))
log_message(paste("Skipped:   ", skipped))
log_message(paste("Failed:    ", failures))

failed_files <- Filter(Negate(is.null), lapply(results, function(r) if (!isTRUE(r$success)) r$file else NULL))
if (length(failed_files) > 0) {
  log_message("Failed files:")
  for (f in failed_files) log_message(paste(" -", f))
}

all_after    <- list.files(target_dir, recursive = TRUE, full.names = TRUE)
video_ext_all <- c(".mp4", ".avi", ".mov", ".mkv")
videos_after  <- Filter(function(f) tolower(paste0(".", file_ext(f))) %in% video_ext_all, all_after)
mp4_after     <- Filter(function(f) tolower(paste0(".", file_ext(f))) == ".mp4", videos_after)

log_message(paste("=== Directory state after remux ==="))
log_message(paste("Total video files:", length(videos_after)))
log_message(paste("MP4:              ", length(mp4_after)))
log_message(paste("Non-MP4:          ", length(videos_after) - length(mp4_after)))

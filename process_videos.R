#!/usr/bin/env Rscript

# ====================================
# User Configuration
# ====================================
input_dir   <- "in_videos"
output_dir  <- "out_videos"
# Set resolution to a specific value like "720x404" to resize,
# or set to NULL or "" to keep the original resolution.
resolution  <- "720x404"
frame_rate  <- 24
overwrite   <- FALSE  # Set to TRUE to overwrite existing files, FALSE to skip
log_file    <- "video_processing.log"
use_watermark <- TRUE  # Set to TRUE to apply watermark, FALSE to skip
watermark_png <- "logo_WCF.png"
watermark_scale <- 0.1  # scale to 20% of original
## Watermark position options:
# # Center
# watermark_pos = "(W-w)/2:(H-h)/2"
#
# # Top center
# watermark_pos = "(W-w)/2:0"
#
# # Bottom center
# watermark_pos = "(W-w)/2:H-h"
#
# # Top left
# watermark_pos = "0:0"
#
# # Top right (current default)
watermark_pos = "W-w:0"
#
# # Bottom right
# watermark_pos = "W-w:H-h"
#
# # Bottom left
# watermark_pos = "0:H-h"
#
# # Center left
# watermark_pos = "0:(H-h)/2"
#
# # Center right
# watermark_pos = "W-w:(H-h)/2"
# ====================================

library(tools)

# -----------------------
# Logging setup
# -----------------------
log_message <- function(msg) {
  cat(msg, "\n")
  write(msg, file = log_file, append = TRUE)
}

# -----------------------
# ffmpeg check
# -----------------------
check_ffmpeg <- function() {
  res <- suppressWarnings(system2("ffmpeg", "-version", stdout = TRUE, stderr = TRUE))
  if (length(res) == 0) {
    stop("ERROR: ffmpeg not found. Install it or add it to PATH.")
  }
}

# -----------------------
# Process a single video using system2 (cross-platform)
# -----------------------
process_video <- function(input_path, output_path, resolution, frame_rate, overwrite, watermark_png = NULL, watermark_pos = "W-w-10:H-h-10", watermark_scale = 0.5, use_watermark = FALSE) {
  # Handle both boolean and y/n for overwrite flag
  overwrite_flag <- if (isTRUE(overwrite) || tolower(as.character(overwrite)) == "y") "-y" else "-n"

  # For system2 on non-Windows, args with special characters need shell quoting.
  quote_arg <- function(arg) {
    # No need to quote on Windows as system2 handles it.
    if (.Platform$OS.type != "windows") {
      return(shQuote(arg, type = "sh"))
    }
    return(arg)
  }

  # --- Argument building ---
  args <- c(
    overwrite_flag,
    "-i", quote_arg(input_path)
  )

  if (use_watermark) {
      args <- c(args, "-i", quote_arg(watermark_png))
  }

  filter_chains <- c()
  video_stream <- "[0:v]"

  if (!is.null(resolution) && nzchar(resolution)) {
      filter_chains <- c(filter_chains, paste0(video_stream, "scale=", resolution, "[scaled]"))
      video_stream <- "[scaled]"
  }

  if (use_watermark) {
      filter_chains <- c(filter_chains,
                        paste0("[1:v]scale=iw*", watermark_scale, ":ih*", watermark_scale, ":flags=lanczos[wm]"),
                        paste0(video_stream, "[wm]overlay=", watermark_pos))
  }

  # The filter_complex argument is a single string that often needs quoting
  if (length(filter_chains) > 0) {
      filter_complex <- paste(filter_chains, collapse = ";")
      args <- c(args, "-filter_complex", quote_arg(filter_complex))
  }
    
  args <- c(
    args,
    "-r", as.character(frame_rate),
    "-c:v", "libx264",
    "-crf", "20",
    "-c:a", "aac",
    quote_arg(output_path)
  )
  
  # --- Execution ---
  err_file <- tempfile(fileext = ".log")
  status <- system2("ffmpeg", args = args, stdout = FALSE, stderr = err_file)

  if (status != 0) {
    err_msg <- readLines(err_file, warn = FALSE)
    unlink(err_file)
    # Show more lines for better debugging context
    err_tail <- paste(tail(err_msg, 20), collapse = "\n")
    stop(paste("ffmpeg failed with exit code", status, "\nLast lines of output:\n", err_tail))
  }
  
  unlink(err_file) # Clean up temp file on success
}

# -----------------------
# Worker function
# -----------------------
process_worker <- function(input_path, input_dir, output_dir, resolution, frame_rate, overwrite, log_file) {
  # Remove leading slash if present
  input_dir_clean <- sub("/$", "", input_dir)
  relative_path <- sub(paste0("^", input_dir_clean, "/?"), "", input_path)
  
  base <- file_path_sans_ext(relative_path)
  ext  <- paste0(".", file_ext(relative_path))
  new_file_name <- paste0(base, ext)
  output_path <- file.path(output_dir, new_file_name)
  
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  
  tryCatch({
    if (!use_watermark) {
      watermark_png = NULL
    }
    process_video(input_path, output_path, resolution, frame_rate, overwrite, watermark_png = watermark_png, watermark_pos = watermark_pos, watermark_scale = watermark_scale, use_watermark = use_watermark)
    return(list(success = TRUE, file = basename(input_path)))
  }, error = function(e) {
    msg <- paste("✘ Error:", basename(input_path), ":", e$message)
    write(msg, file = log_file, append = TRUE)
    return(list(success = FALSE, file = basename(input_path), error = e$message))
  })
}

# -----------------------
# Directory scanning + runner
# -----------------------
process_directory <- function() {
  check_ffmpeg()
  
  all_files <- list.files(input_dir, recursive = TRUE, full.names = TRUE)
  video_ext <- c(".mp4", ".avi", ".mov", ".mkv")
  videos <- Filter(function(f) tolower(paste0(".", file_ext(f))) %in% video_ext,
                   all_files)
  
  total <- length(videos)
  if (total == 0) {
    stop("No video files found.")
  }
  
  log_message(paste("Found", total, "videos"))
  cat("\nProcessing", total, "videos...\n\n")
  
  # Progress tracking
  start_time <- Sys.time()
  results <- list()
  
  for (i in seq_along(videos)) {
    v <- videos[i]
    
    # Process video
    res <- process_worker(v, input_dir, output_dir, resolution, frame_rate, overwrite, log_file)
    results[[i]] <- res
    
    # Update progress bar
    pct <- round(100 * i / total)
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    
    if (i > 0 && elapsed > 0) {
      eta_secs <- elapsed / i * (total - i)
      if (is.finite(eta_secs)) {
        eta <- sprintf("%02d:%02d:%02d", 
                       floor(eta_secs / 3600), 
                       floor((eta_secs %% 3600) / 60), 
                       floor(eta_secs %% 60))
      } else {
        eta <- "calculating..."
      }
    } else {
      eta <- "calculating..."
    }
    
    bar_width <- 50
    filled <- round(bar_width * i / total)
    bar <- paste0(rep("=", filled), collapse = "")
    empty <- paste0(rep(" ", bar_width - filled), collapse = "")
    
    status <- if (res$success) "✓" else "✗"
    cat(sprintf("\r[%s%s] %d%% (%d/%d) ETA: %s %s %s  ", 
                bar, empty, pct, i, total, eta, status, basename(v)))
    flush.console()
  }
  
  cat("\n\n")
  
  # Summary
  successes <- sum(sapply(results, function(r) r$success))
  failures <- total - successes
  
  log_message(paste("\n=== Processing complete ==="))
  log_message(paste("Successful:", successes))
  log_message(paste("Failed:", failures))
  
  if (failures > 0) {
    log_message("\nFailed files:")
    for (r in results) {
      if (!r$success) {
        log_message(paste("  -", r$file, ":", r$error))
      }
    }
  }
  
  cat("\nCheck", log_file, "for detailed logs.\n")
}

# Run
process_directory()

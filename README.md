# Video Processing with R and FFmpeg

This R script provides a comprehensive solution for batch-processing video files using FFmpeg. It is designed to be flexible and easy to configure, allowing for resizing, frame rate conversion, and watermarking of videos.

## Features

- **Batch Processing:** Recursively finds and processes all video files in a specified directory.
- **Video Resizing:** Change the resolution of the videos to a specified dimension.
- **Frame Rate Conversion:** Convert the frame rate of the videos.
- **Watermarking:** Add a watermark image to the videos with configurable position and scale.
- **Overwrite Control:** Choose whether to overwrite existing output files.
- **Logging:** Detailed logging of all operations, including errors, to a log file.
- **Progress Bar:** A real-time progress bar in the console shows the status of the processing.
- **Cross-Platform:** Works on any system with R and FFmpeg installed.

## Prerequisites

Before running the script, you need to have the following software installed:

- **R:** A recent version of R is required. You can download it from the [R Project website](https://www.r-project.org/).
- **FFmpeg:** FFmpeg must be installed and accessible from your system's PATH.

---

### How to Install FFmpeg

#### On Windows

1. **Download:** Go to [gyan.dev/ffmpeg/builds/](https://www.gyan.dev/ffmpeg/builds/) and download the latest "release-full" build (e.g., `ffmpeg-release-full.7z`).
2. **Extract:** Extract the downloaded archive. You will get a folder like `ffmpeg-6.x-full_build`.
3. **Add to PATH:**
   - Open the `bin` directory inside the extracted folder.
   - Copy the full path to this `bin` directory.
   - Press `Win + R`, type `sysdm.cpl`, and press Enter.
   - Go to the `Advanced` tab and click `Environment Variables`.
   - Under "System variables," find and select the `Path` variable, then click `Edit`.
   - Click `New` and paste the path to the `bin` directory.
   - Click `OK` to save all changes.
4. **Verify:** Open a new Command Prompt and run `ffmpeg -version`. If it prints version information, FFmpeg is installed correctly.

#### On macOS (using Homebrew)

```bash
brew install ffmpeg
```

#### On Linux (using a package manager)

- **Debian/Ubuntu:**

  ```bash
  sudo apt-get update
  sudo apt-get install ffmpeg
  ```

- **Fedora/CentOS:**

  ```bash
  sudo dnf install ffmpeg
  ```

---

## Configuration

All configuration is done by editing the user-configurable variables at the top of the `process_videos.R` script:

- `input_dir`: The directory containing the video files you want to process.
- `output_dir`: The directory where the processed video files will be saved.
- `resolution`: The desired output resolution (e.g., `"1280x720"`). Set to `NULL` or `""` to keep the original resolution.
- `frame_rate`: The desired output frame rate (e.g., `24`).
- `overwrite`: Set to `TRUE` to overwrite existing files in the output directory, or `FALSE` to skip them. Recommended to set to `FALSE` to continue processing after interruptions.
- `log_file`: The name of the file where logs will be stored.
- `use_watermark`: Set to `TRUE` to add a watermark, or `FALSE` to disable it.
- `watermark_png`: The path to the watermark image file (e.g., `logo_WCF.png`).
- `watermark_scale`: The scale of the watermark relative to the video width (e.g., `0.1` for 10%).
- `watermark_pos`: The position of the watermark on the video. Several presets are available in the script, such as top-right (`"W-w:0"`), bottom-left (`"10:H-h-10"`), etc.

## Usage

1. **Configure the script:** Open `process_videos.R` in a text editor and set the configuration variables as described above.
2. **Run the script:** Open your terminal or command prompt, navigate to the project directory, and run the script using the following command:

   ```bash
   Rscript process_videos.R
   ```

The script will then start processing the videos, and you will see a progress bar in the console.

## Logging

The script creates a log file (e.g., `video_processing.log`) in the project directory. This file contains a detailed record of the processing, including:

- The total number of videos found.
- A summary of successful and failed operations.
- Detailed error messages for any videos that failed to process.

This log file is useful for troubleshooting any issues that may occur.

## Directory Structure

- **`in_vids/`**: A sample directory for input videos. You should place the videos you want to process here or change the `input_dir` variable to point to your videos' location.
- **`out/`**: The default output directory where the processed videos will be saved. The script will replicate the directory structure from the input directory.


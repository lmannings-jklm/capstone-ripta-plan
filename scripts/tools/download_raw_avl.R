# ==============================================================================
# Script:  scripts/tools/download_raw_avl.R
# Purpose: Downloads the raw 1-year RIPTA AVL dataset (~924 MB) from the
#          project's GitHub Releases page into the local data/ directory.
# Usage:   Run from the capstone-ripta-plan.Rproj root:
#          source("scripts/tools/download_raw_avl.R")
# ==============================================================================

download_raw_avl <- function(
  url = "https://github.com/lmannings-jklm/capstone-ripta-plan/releases/latest/download/ripta_avl_1yr_log.csv",
  dest_dir = "data",
  dest_file = "ripta_avl_1yr_log.csv",
  timeout_sec = 900,
  overwrite = FALSE
) {
  # Ensure script is run from the project root (or create data/ if missing)
  if (!dir.exists(dest_dir)) {
    message("Creating directory: ", dest_dir)
    dir.create(dest_dir, recursive = TRUE)
  }

  dest_path <- file.path(dest_dir, dest_file)

  # Avoid re-downloading a ~924 MB file unnecessarily
  if (file.exists(dest_path) && !overwrite) {
    size_mb <- round(file.info(dest_path)$size / (1024^2), 1)
    message(sprintf(
      "File already exists at '%s' (%.1f MB). Set overwrite = TRUE to re-download.",
      dest_path, size_mb
    ))
    return(invisible(dest_path))
  }

  # Temporarily increase download timeout and restore original value on exit
  old_timeout <- getOption("timeout")
  on.exit(options(timeout = old_timeout), add = TRUE)
  options(timeout = max(timeout_sec, old_timeout))

  message("Downloading raw RIPTA AVL dataset (~924 MB)...")
  message("Source: ", url)
  message("Destination: ", dest_path)

  status <- tryCatch(
    {
      download.file(
        url = url,
        destfile = dest_path,
        mode = "wb",
        quiet = FALSE
      )
    },
    error = function(e) {
      if (file.exists(dest_path)) unlink(dest_path)
      stop(
        "Download failed: ", conditionMessage(e), "\n",
        "You can download the file manually from:\n",
        "https://github.com/lmannings-jklm/capstone-ripta-plan/releases",
        call. = FALSE
      )
    }
  )

  if (status != 0 || !file.exists(dest_path)) {
    if (file.exists(dest_path)) unlink(dest_path)
    stop(
      "Download did not complete cleanly. Please download manually from:\n",
      "https://github.com/lmannings-jklm/capstone-ripta-plan/releases",
      call. = FALSE
    )
  }

  size_mb <- round(file.info(dest_path)$size / (1024^2), 1)
  message(sprintf("Download complete: '%s' (%.1f MB)", dest_path, size_mb))

  invisible(dest_path)
}

# Execute automatically when sourced
download_raw_avl()
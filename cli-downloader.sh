#!/bin/bash

# --- Configuration Loading ---
# Define potential config file locations: user's home directory and the script's directory.
HOME_CONFIG_FILE="$HOME/.cli-downloader.conf"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT_CONFIG_FILE="$SCRIPT_DIR/.cli-downloader.conf"

CONFIG_FILE=""

# Check for the config file first in the home directory, then in the script directory.
if [ -f "$HOME_CONFIG_FILE" ]; then
    CONFIG_FILE="$HOME_CONFIG_FILE"
elif [ -f "$SCRIPT_CONFIG_FILE" ]; then
    CONFIG_FILE="$SCRIPT_CONFIG_FILE"
fi

# If no config file was found in either location, show an error and instructions.
if [ -z "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found!"
    echo "Please create a file named '.cli-downloader.conf' in your home directory (~/) or in the script's directory."
    echo ""
    echo "Add the following content to the file, replacing the placeholder values:"
    echo "--------------------------------------------------------------------"
    cat << EOF
# --- Download Configuration ---
# Destination folder for your downloads. No trailing slash.
DEST_FOLDER="/path/to/your/downloads"

# Your username for the protected website.
USERNAME="your_username"

# Your password for the protected website.
PASSWORD="your_password"

# Number of parallel connections to use for each download.
CONNECTIONS=8
EOF
    echo "--------------------------------------------------------------------"
    exit 1
fi

# Load the configuration variables from the found file.
source "$CONFIG_FILE"
# ---------------------

# --- Dependency Check ---
# Check if aria2c is installed before proceeding.
if ! command -v aria2c &> /dev/null; then
    echo "Error: aria2c is not installed." >&2
    echo "Please install it to use this script." >&2
    echo "On Debian/Raspbian/Ubuntu: sudo apt-get install aria2" >&2
    echo "On macOS (with Homebrew): brew install aria2" >&2
    exit 1
fi
# ------------------------

# --- Main Download Function ---
# This function handles the download logic for a single URL using aria2c.
download_file() {
  # The URL is the first argument passed to the function.
  local URL="$1"

  # Check for empty URL.
  if [ -z "$URL" ]; then
    echo "Warning: Skipped an empty URL."
    return
  fi

  # --- Decode the URL to get a clean filename ---
  local DECODED_URL
  DECODED_URL=$(printf '%b' "${URL//%/\\x}")
  local FILENAME
  FILENAME=$(basename "$DECODED_URL")

  # Define the final path and the aria2 control file path.
  local FINAL_PATH="$DEST_FOLDER/$FILENAME"
  local ARIA2_CONTROL_FILE="$FINAL_PATH.aria2"

  # --- Check if file is already complete ---
  # A download is complete only if the final file exists AND the .aria2 control file does NOT.
  if [ -f "$FINAL_PATH" ] && [ ! -f "$ARIA2_CONTROL_FILE" ]; then
    echo "✅ $FILENAME"
    return
  fi
  # -------------------------------------

  # Start the download process using aria2c.
  echo "Starting or resuming download for: $FILENAME"
  echo "Using URL for aria2c: '$URL'"

  # Use aria2c to download the file.
  # It automatically handles resuming and uses a temporary file (.aria2)
  # -c, --continue=true: Resumes interrupted downloads.
  # -x: Specifies the number of connections.
  # -d: Sets the destination directory.
  # -o: Sets the output filename.
  # --http-user/--http-passwd: Sets credentials for authentication.
  # --log-level=warn: Suppresses non-error messages but keeps the progress meter.
  aria2c \
    --continue=true \
    --http-user="$USERNAME" \
    --http-passwd="$PASSWORD" \
    -x "$CONNECTIONS" \
    -d "$DEST_FOLDER" \
    -o "$FILENAME" \
    --log-level=warn \
    "$URL"

  # Check the exit code of the aria2c command.
  if [ $? -eq 0 ]; then
    echo "✅ Download complete! File saved to $FINAL_PATH"
  else
    # aria2c leaves a .aria2 control file which allows it to resume next time.
    echo "❌ Download failed or was interrupted for '$FILENAME'."
    echo "Run the script again to resume."
  fi
}

# --- Script Entry Point ---

# Check if an argument was provided.
if [ -z "$1" ]; then
  echo "Usage: $0 <URL | path/to/links.txt>"
  echo "Provide a single direct download URL or a .txt file with one URL per line."
  exit 1
fi

ARGUMENT="$1"

# Create the destination directory if it doesn't exist.
echo "Ensuring destination directory exists: $DEST_FOLDER"
mkdir -p "$DEST_FOLDER"
echo "" # Add a newline for better readability

# Check if the argument is a text file.
if [[ -f "$ARGUMENT" && "$ARGUMENT" == *.txt ]]; then
  echo "Processing download list from file: $ARGUMENT"
  echo "============================================="
  # Read the file line by line and call the download function.
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Sanitize the line to remove ALL non-printing control characters.
    line=$(printf "%s" "$line" | tr -d '[:cntrl:]')
    
    # Ignore empty lines or lines that start with a # (comments)
    if [[ -z "$line" || "$line" == \#* ]]; then
      continue
    fi
    download_file "$line"
    echo "---------------------------------------------" # Separator between files
  done < "$ARGUMENT"
  echo "All downloads from file processed."
else
  # Treat the argument as a single URL.
  # Sanitize the single URL as well.
  ARGUMENT=$(printf "%s" "$ARGUMENT" | tr -d '[:cntrl:]')
  echo "Processing a single URL."
  echo "========================"
  download_file "$ARGUMENT"
fi

exit 0

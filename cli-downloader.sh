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

# --- Interactive Setup ---
# If no config file was found, guide the user through creating one.
if [ -z "$CONFIG_FILE" ]; then
    echo "Configuration file not found. Let's create one!"
    
    # Set the default location to the script's directory.
    CONFIG_FILE="$SCRIPT_CONFIG_FILE"
    echo "The new config file will be saved at: $CONFIG_FILE"
    
    read -p "Enter the destination folder for your downloads: " DEST_FOLDER
    read -p "Enter your username for the protected website: " USERNAME
    echo "Enter your password (optional, press Enter to be prompted each time): "
    read -s PASSWORD_INPUT
    read -p "Enter the number of parallel connections (default: 8): " CONNECTIONS
    CONNECTIONS=${CONNECTIONS:-8}
    read -p "Enter the max download speed (e.g., 500K, 1M, or 0 for no limit) (default: 0): " MAX_DOWNLOAD_SPEED
    MAX_DOWNLOAD_SPEED=${MAX_DOWNLOAD_SPEED:-"0"}
    read -p "Enter the path for the log file (optional, press Enter to disable logging): " LOG_FILE
    
    # Create the configuration file.
    cat > "$CONFIG_FILE" << EOF
# --- Download Configuration ---
DEST_FOLDER="$DEST_FOLDER"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD_INPUT"
CONNECTIONS=$CONNECTIONS
MAX_DOWNLOAD_SPEED="$MAX_DOWNLOAD_SPEED"
LOG_FILE="$LOG_FILE"
EOF
    echo -e "\nConfiguration file created successfully!"
fi

# Load the configuration variables from the found file.
source "$CONFIG_FILE"
# ---------------------

# --- Logging Function ---
log_message() {
  # Check if LOG_FILE is set and not an empty string.
  if [[ -n "$LOG_FILE" ]]; then
    # Append timestamp and the message ($1) to the log file.
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
  fi
}
# --------------------

# --- Password Prompt Fallback ---
if [ -z "$PASSWORD" ]; then
    echo -n "Enter password for user '$USERNAME': "
    read -s PASSWORD
    echo ""
fi
# ------------------------------

# --- Dependency Check ---
if ! command -v aria2c &> /dev/null; then
    echo "Error: aria2c is not installed." >&2
    log_message "ERROR: aria2c is not installed."
    exit 1
fi
# ------------------------

# --- Main Download Function ---
download_file() {
  local URL="$1"

  if [ -z "$URL" ]; then
    echo "Warning: Skipped an empty URL."
    log_message "WARNING: Skipped an empty URL."
    return
  fi

  local DECODED_URL
  DECODED_URL=$(printf '%b' "${URL//%/\\x}")
  local FILENAME
  FILENAME=$(basename "$DECODED_URL")

  local FINAL_PATH="$DEST_FOLDER/$FILENAME"
  local ARIA2_CONTROL_FILE="$FINAL_PATH.aria2"

  if [ -f "$FINAL_PATH" ] && [ ! -f "$ARIA2_CONTROL_FILE" ]; then
    echo "✅ $FILENAME"
    log_message "SKIPPED: $FILENAME already exists."
    return
  fi

  local ARIA2_CMD=(aria2c \
    --continue=true \
    --http-user="$USERNAME" \
    --http-passwd="$PASSWORD" \
    -x "$CONNECTIONS" \
    -d "$DEST_FOLDER" \
    -o "$FILENAME" \
    --log-level=warn)

  if [[ -n "$MAX_DOWNLOAD_SPEED" && "$MAX_DOWNLOAD_SPEED" != "0" ]]; then
    echo "Limiting download speed to: $MAX_DOWNLOAD_SPEED"
    ARIA2_CMD+=(--max-download-limit="$MAX_DOWNLOAD_SPEED")
  fi

  ARIA2_CMD+=("$URL")

  echo "Starting or resuming download for: $FILENAME"
  log_message "STARTING: $FILENAME"

  "${ARIA2_CMD[@]}"

  if [ $? -eq 0 ]; then
    echo "✅ Download complete! File saved to $FINAL_PATH"
    log_message "SUCCESS: Download complete for $FILENAME."
  else
    echo "❌ Download failed or was interrupted for '$FILENAME'."
    echo "Run the script again to resume."
    log_message "FAILED: Download failed or interrupted for $FILENAME."
  fi
}

# --- Script Entry Point ---
if [ -z "$1" ]; then
  echo "Usage: $0 <URL | path/to/links.txt>"
  exit 1
fi

ARGUMENT="$1"

echo "Ensuring destination directory exists: $DEST_FOLDER"
mkdir -p "$DEST_FOLDER"
echo ""

if [[ -f "$ARGUMENT" && "$ARGUMENT" == *.txt ]]; then
  echo "Processing download list from file: $ARGUMENT"
  log_message "START_SESSION: Processing download list from file: $ARGUMENT"
  echo "============================================="
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=$(printf "%s" "$line" | tr -d '[:cntrl:]')
    if [[ -z "$line" || "$line" == \#* ]]; then
      continue
    fi
    download_file "$line"
    echo "---------------------------------------------"
  done < "$ARGUMENT"
  echo "All downloads from file processed."
  log_message "END_SESSION: Finished processing file: $ARGUMENT"
else
  ARGUMENT=$(printf "%s" "$ARGUMENT" | tr -d '[:cntrl:]')
  echo "Processing a single URL."
  log_message "START_SESSION: Processing single URL."
  echo "========================"
  download_file "$ARGUMENT"
  log_message "END_SESSION: Finished processing single URL."
fi

exit 0

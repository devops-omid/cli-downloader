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
    
    # Ask for the destination folder.
    read -p "Enter the destination folder for your downloads: " DEST_FOLDER
    
    # Ask for the username.
    read -p "Enter your username for the protected website: " USERNAME
    
    # Ask for the password (optional, can be left blank).
    echo "Enter your password (optional, press Enter to be prompted each time): "
    read -s PASSWORD_INPUT # -s flag hides the input
    
    # Ask for the number of connections.
    read -p "Enter the number of parallel connections (default: 8): " CONNECTIONS
    CONNECTIONS=${CONNECTIONS:-8} # Default to 8 if empty
    
    # Ask for the max download speed.
    read -p "Enter the max download speed (e.g., 500K, 1M, or 0 for no limit) (default: 0): " MAX_DOWNLOAD_SPEED
    MAX_DOWNLOAD_SPEED=${MAX_DOWNLOAD_SPEED:-"0"} # Default to "0" if empty
    
    # Create the configuration file.
    cat > "$CONFIG_FILE" << EOF
# --- Download Configuration ---
DEST_FOLDER="$DEST_FOLDER"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD_INPUT"
CONNECTIONS=$CONNECTIONS
MAX_DOWNLOAD_SPEED="$MAX_DOWNLOAD_SPEED"
EOF
    echo -e "\nConfiguration file created successfully!"
fi

# Load the configuration variables from the found file.
source "$CONFIG_FILE"
# ---------------------

# --- Password Prompt Fallback ---
# If the PASSWORD variable is empty after sourcing the config, prompt for it securely.
if [ -z "$PASSWORD" ]; then
    echo -n "Enter password for user '$USERNAME': "
    read -s PASSWORD # -s flag hides the input
    echo "" # Add a newline after the hidden input
fi
# ------------------------------

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

  # --- Build aria2c command ---
  # Start with the base command and options in an array for robustness.
  local ARIA2_CMD=(aria2c \
    --continue=true \
    --http-user="$USERNAME" \
    --http-passwd="$PASSWORD" \
    -x "$CONNECTIONS" \
    -d "$DEST_FOLDER" \
    -o "$FILENAME" \
    --log-level=warn)

  # Conditionally add the download speed limit if it's set and not "0".
  if [[ -n "$MAX_DOWNLOAD_SPEED" && "$MAX_DOWNLOAD_SPEED" != "0" ]]; then
    echo "Limiting download speed to: $MAX_DOWNLOAD_SPEED"
    ARIA2_CMD+=(--max-download-limit="$MAX_DOWNLOAD_SPEED")
  fi

  # Add the URL as the final argument to the command array.
  ARIA2_CMD+=("$URL")
  # --------------------------

  # Start the download process.
  echo "Starting or resuming download for: $FILENAME"

  # Execute the command. Using an array handles spaces and special characters safely.
  "${ARIA2_CMD[@]}"

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

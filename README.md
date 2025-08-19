# CLI-Downloader

This is a powerful Bash script for downloading files from password-protected websites. It uses `aria2c` to accelerate downloads by using multiple connections per file.

## Features

* **Accelerated Downloads**: Uses `aria2c` to open multiple connections for a single file, significantly increasing download speed.
* **Automatic Resume**: If a download is interrupted, it will automatically resume from where it left off the next time you run the script.
* **Batch Downloading**: Accepts either a single URL or a `.txt` file with multiple URLs (one per line) as input.
* **Smart File Checking**: Skips files that have already been completely downloaded.
* **Secure Configuration**: Keeps your username, password, and other settings in a separate `.cli-downloader.conf` file to avoid exposing sensitive information directly in the script.
* **Cross-Platform**: Compatible with macOS and Linux distributions like Raspbian OS.

## Requirements

* **`aria2c`**: The script depends on the `aria2c` command-line download utility.

## Setup

1.  **Install `aria2c`**:
    * **On macOS (with Homebrew):** `brew install aria2`
    * **On Raspbian/Debian/Ubuntu:** `sudo apt update && sudo apt install aria2`

2.  **Create the Configuration File**: Create a file named `.cli-downloader.conf` in either your home directory (`~/`) or in the same directory as the `download.sh` script. Add your configuration details to this file. A sample is provided in the project.

3.  **Make the Script Executable**: Open your terminal and run the following command to give the script permission to execute:
    ```bash
    chmod +x download.sh
    ```

## Usage

You can run the script in one of two ways:

### 1. Download a Single File

Provide the direct download link as an argument:

```bash
./download.sh '[https://protected.example.com/path/to/yourfile.zip](https://protected.example.com/path/to/yourfile.zip)'
```

### 2. Download Multiple Files from a List

Provide the path to a text file containing one download link per line:

```bash
./download.sh /path/to/your/links.txt

#!/bin/bash
# Snapshot restore script
# Downloads and extracts chain snapshot data

set -eu

CHAIN_HOME="/home/operator/$homeDir"

# Check if database already exists
if test -n "$(find "$DATA_DIR" -maxdepth 1 -name '*.db' -print -quit)" || [ -d "$DATA_DIR/db" ]; then
    echo "Databases in $DATA_DIR already exists; skipping initialization."
    exit 0
fi

# Source download utilities if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/download-utils.sh" ]; then
    source "$SCRIPT_DIR/download-utils.sh"
else
    echo "Warning: download-utils.sh not found, download functions may not work"
fi

# SNAPSHOT_URL should be provided as environment variable or argument
SNAPSHOT_URL="${1:-${SNAPSHOT_URL}}"

if [ -z "$SNAPSHOT_URL" ]; then
    echo "Error: SNAPSHOT_URL must be provided as argument or environment variable"
    exit 1
fi

# Construct full chain home path
CHAIN_HOME="$HOME/$CHAIN_HOME"

echo "Downloading snapshot archive $SNAPSHOT_URL to $CHAIN_HOME..."

case "$SNAPSHOT_URL" in
    *.tar.lz4)
        download_lz4 "$SNAPSHOT_URL" "$CHAIN_HOME"
        ;;
    *.tar.zst)
        download_zst "$SNAPSHOT_URL" "$CHAIN_HOME"
        ;;
    *.tar.gzip)
        download_targz "$SNAPSHOT_URL" "$CHAIN_HOME"
        ;;
    *.tar.gz)
        download_targz "$SNAPSHOT_URL" "$CHAIN_HOME"
        ;;
    *.tar)
        download_tar "$SNAPSHOT_URL" "$CHAIN_HOME"
        ;;
    *.lz4)
        download_lz4_raw "$SNAPSHOT_URL" "$CHAIN_HOME"
        ;;
    *)
        echo "Unable to handle file extension for $SNAPSHOT_URL"
        exit 1
        ;;
esac

echo "Download and extract snapshot complete."
echo "$DATA_DIR initialized."

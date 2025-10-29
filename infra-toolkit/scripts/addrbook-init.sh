#!/bin/bash
# Address book initialization script
# Downloads and processes the address book file

set -eu

CONFIG_DIR="/home/operator/$homeDir/.config"

# Check if address book already exists
ls "$CONFIG_DIR/addrbook.json" 1> /dev/null 2>&1
ADDRBOOK_EXISTS=$?
if [ $ADDRBOOK_EXISTS -eq 0 ]; then
    echo "Address book already exists"
    exit 0
fi

# Source download utilities if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/download-utils.sh" ]; then
    source "$SCRIPT_DIR/download-utils.sh"
else
    echo "Warning: download-utils.sh not found, download functions may not work"
fi

# ADDRBOOK_URL should be provided as environment variable or argument
ADDRBOOK_URL="${1:-${ADDRBOOK_URL}}"

if [ -z "$ADDRBOOK_URL" ]; then
    echo "Error: ADDRBOOK_URL must be provided as argument or environment variable"
    exit 1
fi

ls -l "$CONFIG_DIR/addrbook.json" 2>/dev/null || true

echo "Downloading address book file $ADDRBOOK_URL to $ADDRBOOK_FILE..."

rm -f "$ADDRBOOK_FILE"

case "$ADDRBOOK_URL" in
    *.json.gz)
        download_jsongz "$ADDRBOOK_URL" "$ADDRBOOK_FILE"
        ;;
    *.json)
        download_json "$ADDRBOOK_URL" "$ADDRBOOK_FILE"
        ;;
    *.tar.gz)
        download_targz "$ADDRBOOK_URL" "$CONFIG_DIR"
        ;;
    *.tar.gzip)
        download_targz "$ADDRBOOK_URL" "$CONFIG_DIR"
        ;;
    *.tar)
        download_tar "$ADDRBOOK_URL" "$CONFIG_DIR"
        ;;
    *.zip)
        download_zip "$ADDRBOOK_URL" "$ADDRBOOK_FILE"
        ;;
    *)
        echo "Unable to handle file extension for $ADDRBOOK_URL"
        exit 1
        ;;
esac

echo "Saved address book file to $ADDRBOOK_FILE."
echo "Download address book file complete."

ls -l "$CONFIG_DIR/addrbook.json" 2>/dev/null || true

echo "Address book $ADDRBOOK_FILE downloaded"

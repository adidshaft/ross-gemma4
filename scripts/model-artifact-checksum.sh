#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 path/to/model-file"
    exit 1
fi

FILE="$1"

if [ ! -f "$FILE" ]; then
    echo "Error: File not found: $FILE"
    exit 1
fi

echo "File: $FILE"

if [[ "$OSTYPE" == "darwin"* ]]; then
    SIZE=$(stat -f%z "$FILE")
    CHECKSUM=$(shasum -a 256 "$FILE" | awk '{print $1}')
else
    SIZE=$(stat -c%s "$FILE")
    CHECKSUM=$(sha256sum "$FILE" | awk '{print $1}')
fi

echo "Size (bytes): $SIZE"
echo "SHA-256 Checksum: $CHECKSUM"
echo ""
echo "Suggested Manifest Fields:"
echo "\"sizeBytes\": $SIZE,"
echo "\"checksumSha256\": \"$CHECKSUM\","

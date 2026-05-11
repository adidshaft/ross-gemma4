#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "❌ FAIL: No file path provided."
    echo "Usage: $0 /path/to/model.gguf"
    exit 1
fi

FILE_PATH="$1"

if [ ! -f "$FILE_PATH" ]; then
    echo "❌ FAIL: File does not exist at '$FILE_PATH'."
    exit 1
fi

echo "Calculating metrics for: $FILE_PATH"

if [[ "$OSTYPE" == "darwin"* ]]; then
    SIZE_BYTES=$(stat -f%z "$FILE_PATH")
    CHECKSUM=$(shasum -a 256 "$FILE_PATH" | awk '{print $1}')
else
    SIZE_BYTES=$(stat -c%s "$FILE_PATH")
    CHECKSUM=$(sha256sum "$FILE_PATH" | awk '{print $1}')
fi

echo ""
echo "=== METRICS ==="
echo "file path: $FILE_PATH"
echo "sizeBytes: $SIZE_BYTES"
echo "checksumSha256: $CHECKSUM"
echo ""

echo "=== SUGGESTED JSON MANIFEST ==="
echo "\"downloadUrl\": \"__REPLACE_WITH_VERIFIED_DIRECT_URL__\","
echo "\"finalSha256\": \"$CHECKSUM\","
echo "\"estimatedSizeBytes\": $SIZE_BYTES"
echo ""

echo "=== SUGGESTED SWIFT FIELDS ==="
echo "downloadURLString: \"__REPLACE_WITH_VERIFIED_DIRECT_URL__\","
echo "finalSHA256: \"$CHECKSUM\","
echo "estimatedSizeBytes: $SIZE_BYTES"
echo ""

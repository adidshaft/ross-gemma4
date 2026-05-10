#!/bin/bash

# Exit on failure
set -e

echo "Starting ROSS-Gemma4 Migration Audit..."

# Directories to check
SEARCH_DIRS="docs ios shared README.md"

# 1. Check for forbidden terms
echo "Checking for forbidden terms..."
FORBIDDEN_TERMS=("\bfork\b" "\bvariant\b" "\bmigrated\b" "\bcopied\b" "\brepurposed\b" "Gemma 4 E2B Q4" "Gemma 4 E4B Q4" "Gemma 4 E4B Q4" "Gemma 4 local runtime" "Gemma 4 local runtime" "Gemma 4 E2B Q4" "qwen3" "google" "Q4" "Q4")

FAIL=0
for TERM in "${FORBIDDEN_TERMS[@]}"; do
    if grep -riIE --exclude-dir=".git" --exclude-dir="build" --exclude-dir="DerivedData" --exclude-dir="ios/build-device" --exclude-dir=".migration" --exclude-dir=".build" --exclude-dir="Pods" --exclude-dir=".swiftpm" --exclude-dir="tmp" "$TERM" docs README.md; then
        echo "❌ FAILED: Found forbidden term '$TERM'."
        FAIL=1
    fi
done

# 2. Check exactly three active tiers in AlphaRossModel.swift
echo "Checking active model tiers..."
if ! grep -q "gemma-4-e2b-q4" ios/Ross/AlphaFoundation/AlphaRossModel.swift || \
   ! grep -q "gemma-4-e4b-q4" ios/Ross/AlphaFoundation/AlphaRossModel.swift || \
   ! grep -q "gemma-4-26b-a4b-q4" ios/Ross/AlphaFoundation/AlphaRossModel.swift; then
    echo "❌ FAILED: Missing one or more required Gemma 4 active tiers."
    FAIL=1
fi

# 3. Check for old download URLs or verified=true without real checksum
echo "Checking download configurations..."
if grep -riI "verified *: *true" shared ios | grep -iE "(__REPLACE_WITH_VERIFIED_SHA256__|REPLACE_ME)"; then
    echo "❌ FAILED: Found verified=true with a placeholder checksum."
    FAIL=1
fi

if grep -riI "huggingface.co/google" ios shared; then
    echo "❌ FAILED: Found old huggingface download URLs."
    FAIL=1
fi

if [ $FAIL -eq 1 ]; then
    echo "❌ AUDIT FAILED."
    exit 1
else
    echo "✅ AUDIT PASSED."
    exit 0
fi

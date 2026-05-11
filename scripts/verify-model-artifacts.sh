#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-"--release"}"

echo "Running Model Artifact Verification ($MODE mode)..."

fail() {
    echo "❌ FAIL: $1"
    exit 1
}

warn() {
    echo "⚠️  WARN: $1"
}

# 1. Verify exactly three active model ids
ACTIVE_MODELS=$(grep -oE 'packId: "gemma-4-[a-z0-9A-Z-]+"' ios/Ross/AlphaFoundation/AlphaRossModel.swift | sort | uniq)
COUNT=$(echo "$ACTIVE_MODELS" | wc -l | tr -d ' ')

if [ "$COUNT" -ne 3 ]; then
    fail "Found $COUNT active models. Expected exactly 3."
fi

if ! echo "$ACTIVE_MODELS" | grep -q "gemma-4-e2b-q4"; then fail "Missing gemma-4-e2b-q4"; fi
if ! echo "$ACTIVE_MODELS" | grep -q "gemma-4-e4b-q4"; then fail "Missing gemma-4-e4b-q4"; fi
if ! echo "$ACTIVE_MODELS" | grep -q "gemma-4-26b-a4b-q4"; then fail "Missing gemma-4-26b-a4b-q4"; fi

if echo "$ACTIVE_MODELS" | grep -q "31b"; then
    fail "Active 31B tier found. 31B must not be active."
fi

PLACEHOLDERS_FOUND=false

if grep -q "__REPLACE_WITH_VERIFIED" ios/Ross/AlphaFoundation/AlphaRossModel.swift; then
    warn "Found placeholder URLs/checksums in iOS manifest."
    PLACEHOLDERS_FOUND=true
fi

if grep -q "__REPLACE_WITH_VERIFIED" shared/constants/privateAssistantModelRegistry.json; then
    warn "Found placeholder URLs/checksums in Shared manifest."
    PLACEHOLDERS_FOUND=true
fi

# Verify no releaseReady=true or verified=true with placeholders
if grep -riI "releaseReady *: *true" shared ios | grep -q -iE "__REPLACE_WITH_VERIFIED"; then
    fail "Found releaseReady=true with a placeholder."
fi

if grep -riI "verified *: *true" shared ios | grep -q -iE "__REPLACE_WITH_VERIFIED"; then
    fail "Found verified=true with a placeholder."
fi

echo ""
if [ "$PLACEHOLDERS_FOUND" = true ]; then
    if [ "$MODE" = "--release" ]; then
        echo "Demo readiness: PASS"
        echo "Release readiness: FAIL (Placeholders remain)"
        exit 1
    else
        echo "Demo readiness: PASS"
        echo "Release readiness: FAIL (Placeholders remain, but allowed in --dev mode)"
        exit 0
    fi
else
    echo "Demo readiness: PASS"
    echo "Release readiness: PASS"
    exit 0
fi

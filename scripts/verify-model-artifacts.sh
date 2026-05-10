#!/bin/bash
set -e

MODE=${1:-"--release"}

echo "Running Model Artifact Verification ($MODE mode)..."

fail() {
    echo "❌ FAIL: $1"
    exit 1
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

# 2. No active 31B tier
if grep -q "gemma-4-31b" ios/Ross/AlphaFoundation/AlphaRossModel.swift; then
    fail "Found forbidden gemma-4-31b active tier."
fi

# 3. Check for placeholders
PLACEHOLDERS_FOUND=false
if grep -q "__REPLACE_WITH_VERIFIED" ios/Ross/AlphaFoundation/AlphaRossModel.swift; then
    PLACEHOLDERS_FOUND=true
    echo "⚠️  Found placeholder URLs/checksums in iOS manifest."
fi

if grep -q "__REPLACE_WITH_VERIFIED" shared/constants/privateAssistantModelRegistry.json; then
    PLACEHOLDERS_FOUND=true
    echo "⚠️  Found placeholder URLs/checksums in Shared manifest."
fi

# 4. Enforce rules based on MODE
if [ "$PLACEHOLDERS_FOUND" = true ]; then
    if [ "$MODE" = "--release" ]; then
        fail "Release readiness blocks on placeholder artifact URLs/checksums."
    else
        echo "⚠️  DEV MODE: Placeholders allowed. But this build is NOT release-ready."
    fi
else
    echo "✅ No placeholders found."
fi

# 5. Check old model references
if git grep -qE "Qwen|Mistral|Llama|Ollama|OpenRouter|Gemini Nano" -- . ':!.git' ':!.migration' ':!scripts/audit-ross-gemma4-migration.sh'; then
    fail "Old provider references found in source code."
fi

if [ "$PLACEHOLDERS_FOUND" = true ]; then
    echo "Release Readiness: FAIL (Placeholders remain)"
    if [ "$MODE" = "--release" ]; then
        exit 1
    else
        exit 0
    fi
else
    echo "Release Readiness: PASS"
    exit 0
fi

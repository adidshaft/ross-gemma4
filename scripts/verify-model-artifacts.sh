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

# 1. Verify active iOS model ids
ACTIVE_MODELS=$(grep -oE 'packId: "gemma-4-[a-z0-9A-Z-]+"' ios/Ross/AlphaFoundation/AlphaRossModel.swift | sort | uniq)
COUNT=$(echo "$ACTIVE_MODELS" | wc -l | tr -d ' ')

if [ "$COUNT" -ne 4 ]; then
    fail "Found $COUNT active iOS models. Expected exactly 4 including the Flash first-run tier."
fi

if ! echo "$ACTIVE_MODELS" | grep -q "gemma-4-e2b-q2"; then fail "Missing gemma-4-e2b-q2"; fi
if ! echo "$ACTIVE_MODELS" | grep -q "gemma-4-e2b-q4"; then fail "Missing gemma-4-e2b-q4"; fi
if ! echo "$ACTIVE_MODELS" | grep -q "gemma-4-e4b-q4"; then fail "Missing gemma-4-e4b-q4"; fi
if ! echo "$ACTIVE_MODELS" | grep -q "gemma-4-26b-a4b-q4"; then fail "Missing gemma-4-26b-a4b-q4"; fi

if echo "$ACTIVE_MODELS" | grep -q "31b"; then
    fail "Active 31B tier found. 31B must not be active."
fi

if ! command -v jq >/dev/null 2>&1; then
    fail "jq is required for registry consistency checks."
fi

# 2. Verify Matter Search retrieval metadata stays wired across registries.
TECHNICAL_MODEL_IDS=$(jq -r '.[].id' shared/constants/technicalModelRegistry.json | sort -u)
TIER_RETRIEVAL_IDS=$(jq -r '.[].retrievalModelIds[]?' shared/constants/modelCapabilityTiers.json | sort -u)
PRIVATE_RETRIEVAL_IDS=$(jq -r '.retrievalModels[] | .repo + "|" + .runtimeMode + "|" + .artifactKind' shared/constants/privateAssistantModelRegistry.json | sort -u)

while IFS= read -r retrieval_id; do
    [ -n "$retrieval_id" ] || continue
    if ! echo "$TECHNICAL_MODEL_IDS" | grep -qx "$retrieval_id"; then
        fail "Capability tier references missing retrieval model id: $retrieval_id"
    fi
done <<< "$TIER_RETRIEVAL_IDS"

if ! echo "$TIER_RETRIEVAL_IDS" | grep -qx "embeddinggemma-300m-litert"; then
    fail "Capability tiers do not reference EmbeddingGemma 300M."
fi

if ! echo "$TIER_RETRIEVAL_IDS" | grep -qx "Gemma 4-embedding-0_6b-gguf"; then
    fail "Capability tiers do not reference Gemma 4 embedding fallback."
fi

if ! echo "$PRIVATE_RETRIEVAL_IDS" | grep -qx "litert-community/embeddinggemma-300m|litert|local_embedding_model"; then
    fail "Private assistant registry is missing preferred Matter Search EmbeddingGemma metadata."
fi

if ! echo "$PRIVATE_RETRIEVAL_IDS" | grep -qx "google/gemma-4-embedding-0.6b|gemma_local_runtime|local_embedding_model"; then
    fail "Private assistant registry is missing Gemma 4 embedding fallback metadata."
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

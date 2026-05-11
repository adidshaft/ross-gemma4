#!/usr/bin/env bash
set -euo pipefail

echo "Starting ROSS-Gemma4 Migration Audit..."

FAIL=0

echo "Checking for forbidden terms..."
FORBIDDEN_TERMS=(
    "\bfork\b"
    "\bvariant\b"
    "\bmigrated\b"
    "\bcopied\b"
    "\brepurposed\b"
    "Qwe""n"
    "Mistra""l"
    "\bLlam""a\b"
    "Ollam""a"
    "OpenRoute""r"
    "Gemini Nan""o"
    "qwen""3"
    "ggml-or""g"
    "Q4_""0"
)
for TERM in "${FORBIDDEN_TERMS[@]}"; do
    if grep -riIE --exclude-dir=".git" --exclude-dir="build" --exclude-dir="DerivedData" --exclude-dir="ios/build-device" --exclude-dir=".migration" --exclude-dir=".build" --exclude-dir="Pods" --exclude-dir=".swiftpm" --exclude-dir="tmp" "$TERM" docs README.md | grep -viE "llama\.cpp|LlamaCpp" > /dev/null; then
        echo "❌ FAILED: Found forbidden term '$TERM'."
        FAIL=1
    fi
done

echo "Checking active model tiers..."
if ! grep -q "gemma-4-e2b-q4" ios/Ross/AlphaFoundation/AlphaRossModel.swift || \
   ! grep -q "gemma-4-e4b-q4" ios/Ross/AlphaFoundation/AlphaRossModel.swift || \
   ! grep -q "gemma-4-26b-a4b-q4" ios/Ross/AlphaFoundation/AlphaRossModel.swift; then
    echo "❌ FAILED: Missing one or more required Gemma 4 active tiers."
    FAIL=1
fi

echo "Checking download configurations..."
if grep -riI "verified *: *true" shared ios | grep -q -iE "(__REPLACE_WITH_VERIFIED_SHA256__|REPLACE_ME)"; then
    echo "❌ FAILED: Found verified=true with a placeholder checksum."
    FAIL=1
fi

if grep -riI "huggingface.co/ggml-o""rg" ios shared >/dev/null 2>&1 || true; then
    # We ignore the exit code of grep when there's no match
    if grep -qriI "huggingface.co/ggml-o""rg" ios shared; then
        echo "❌ FAILED: Found old huggingface download URLs."
        FAIL=1
    fi
fi

if [ "$FAIL" -eq 1 ]; then
    echo "❌ AUDIT FAILED."
    exit 1
else
    echo "✅ AUDIT PASSED."
    exit 0
fi

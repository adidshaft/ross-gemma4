#!/usr/bin/env bash
set -euo pipefail

FAIL=0

echo "Running iOS Runtime Audit..."

if grep -qE "pgorzelany|swift-gemma-runtime" ios/Package.swift 2>/dev/null; then
    echo "❌ FAIL: Dead dependency found in ios/Package.swift"
    FAIL=1
fi

if [ -f ios/Package.resolved ] && grep -qE "pgorzelany|swift-gemma-runtime" ios/Package.resolved 2>/dev/null; then
    echo "❌ FAIL: Dead dependency found in ios/Package.resolved"
    FAIL=1
fi

if git grep -qE "import SwiftGemmaRuntime|AlphaGemmaLocalModelProvider" ios/Ross/ 2>/dev/null; then
    echo "❌ FAIL: Code still imports or uses dead SwiftGemmaRuntime symbols."
    FAIL=1
fi

if ! grep -q "protocol Gemma4Runtime" ios/Ross/AlphaFoundation/Gemma4Runtime.swift 2>/dev/null; then
    echo "❌ FAIL: Gemma4Runtime abstraction missing."
    FAIL=1
fi

if ! grep -q "Gemma4RuntimeStatus" ios/Ross/AlphaFoundation/Gemma4Runtime.swift 2>/dev/null; then
    echo "❌ FAIL: Gemma4RuntimeStatus missing."
    FAIL=1
fi

if ! grep -q "Gemma4DemoRuntime" ios/Ross/AlphaFoundation/Gemma4Runtime.swift 2>/dev/null; then
    echo "❌ FAIL: Gemma4DemoRuntime missing."
    FAIL=1
fi

if ! grep -q "Gemma4UnavailableRuntime" ios/Ross/AlphaFoundation/Gemma4Runtime.swift 2>/dev/null; then
    echo "❌ FAIL: Gemma4UnavailableRuntime missing."
    FAIL=1
fi

if ! git grep -q "Demo Mode — model response simulated for walkthrough" ios/Ross/ 2>/dev/null; then
    echo "❌ FAIL: Demo mode UI label missing."
    FAIL=1
fi

if [ ! -f docs/IOS_RUNTIME.md ]; then
    echo "❌ FAIL: docs/IOS_RUNTIME.md missing."
    FAIL=1
fi

if [ ! -f docs/RUNTIME_AND_MODEL_RESEARCH.md ]; then
    echo "❌ FAIL: docs/RUNTIME_AND_MODEL_RESEARCH.md missing."
    FAIL=1
fi

if [ "$FAIL" -eq 1 ]; then
    echo "iOS runtime dependency audit: FAIL"
    exit 1
else
    echo "iOS runtime dependency audit: PASS"
    echo "real local inference: PENDING"
    echo "demo runtime: READY"
    exit 0
fi

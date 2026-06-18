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

if ! grep -q "protocol AlphaRealLocalModelProvider" ios/Ross/AlphaFoundation/AlphaLocalModelRuntime.swift 2>/dev/null; then
    echo "❌ FAIL: AlphaRealLocalModelProvider abstraction missing."
    FAIL=1
fi

if ! grep -q "AlphaLlamaCppProvider" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null; then
    echo "❌ FAIL: GGUF llama.cpp provider missing."
    FAIL=1
fi

if ! grep -q "AlphaMLXLocalProvider" ios/Ross/AlphaFoundation/AlphaMLXLocalProvider.swift 2>/dev/null; then
    echo "❌ FAIL: MLX provider missing."
    FAIL=1
fi

if ! grep -q "AlphaFoundationModelsLocalProvider" ios/Ross/AlphaFoundation/AlphaLocalModelRuntime.swift 2>/dev/null; then
    echo "❌ FAIL: CoreAI/Foundation provider missing."
    FAIL=1
fi

if ! grep -q "ROSS_RUNTIME_IDENTITY" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null; then
    echo "❌ FAIL: runtime identity smoke marker missing."
    FAIL=1
fi

if ! grep -q "draft_status" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null; then
    echo "❌ FAIL: draft status missing from runtime identity marker."
    FAIL=1
fi

if ! grep -q "ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null; then
    echo "❌ FAIL: smoke benchmark matrix marker missing."
    FAIL=1
fi

for smoke_script in scripts/ios-simulator-local-model-smoke.sh scripts/ios-device-installed-pack-smoke.sh scripts/ios-device-gguf-smoke.sh; do
    if ! grep -q "missing_benchmark_matrix" "$smoke_script" 2>/dev/null; then
        echo "❌ FAIL: $smoke_script does not require benchmark matrix before benchmark summary."
        FAIL=1
    fi
    if ! grep -q "benchmark_summary_line" "$smoke_script" 2>/dev/null; then
        echo "❌ FAIL: $smoke_script does not use the shared benchmark summary parser."
        FAIL=1
    fi
    if ! grep -q "failure_summary_line" "$smoke_script" 2>/dev/null; then
        echo "❌ FAIL: $smoke_script does not emit normalized failure summaries."
        FAIL=1
    fi
done

if ! grep -q "matrix_stages" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: shared benchmark summary parser omits matrix stages."
    FAIL=1
fi

if ! grep -q '"profile", "cases", "stages"' scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: shared benchmark summary parser does not require matrix cases for pass summaries."
    FAIL=1
fi

if ! grep -q "failure_summary_line" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: shared smoke parser omits failure summaries."
    FAIL=1
fi

if ! grep -q "runtime_identity_mismatch" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: simulator smoke runtime identity guard missing."
    FAIL=1
fi

if ! grep -q "runtime_identity_mismatch" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack device smoke runtime identity guard missing."
    FAIL=1
fi

if ! grep -q "identity_requested" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack device smoke does not validate requested runtime identity."
    FAIL=1
fi

if ! grep -q "identity_requested" scripts/ios-device-gguf-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: GGUF device smoke does not validate requested runtime identity."
    FAIL=1
fi

if ! grep -q "runtime_pass_mismatch" scripts/ios-device-assistant-download-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: assistant-download smoke runtime pass guard missing."
    FAIL=1
fi

if ! grep -q "missing_mlx_artifact" ios/Ross/AlphaFoundation/AlphaMLXLocalProvider.swift 2>/dev/null; then
    echo "❌ FAIL: MLX missing-artifact error category missing."
    FAIL=1
fi

if grep -q 'return (false, "invalid_mlx_draft_artifact"' ios/Ross/AlphaFoundation/AlphaMLXLocalProvider.swift 2>/dev/null; then
    echo "❌ FAIL: invalid MLX draft companion still poisons primary MLX availability."
    FAIL=1
fi

if ! grep -q "alphaMLXDirectoryArtifactLooksUsable" ios/Ross/AlphaFoundation/AlphaStore.swift 2>/dev/null; then
    echo "❌ FAIL: MLX install-time artifact content guard missing."
    FAIL=1
fi

if ! grep -q "mlx_directory_looks_usable" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: simulator MLX artifact content preflight missing."
    FAIL=1
fi

if [ ! -x scripts/test-ios-runtime-smoke-preflights.sh ]; then
    echo "❌ FAIL: executable iOS runtime smoke preflight test script missing."
    FAIL=1
fi

if [ ! -x scripts/test-ross-smoke-summary.py ]; then
    echo "❌ FAIL: executable smoke benchmark summary parser test missing."
    FAIL=1
fi

if ! grep -q "missing_coreai_artifact" ios/Ross/AlphaFoundation/AlphaLocalModelRuntime.swift 2>/dev/null; then
    echo "❌ FAIL: CoreAI missing-artifact error category missing."
    FAIL=1
fi

if ! grep -q "alphaPackUsesSystemFoundationModel" ios/Ross/AlphaFoundation/AlphaRossModel+Persistence.swift 2>/dev/null; then
    echo "❌ FAIL: CoreAI system shortcut and adapter artifact distinction missing."
    FAIL=1
fi

if ! grep -q "alphaDebugSmokePathUsesSystemFoundationModel" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null; then
    echo "❌ FAIL: debug smoke CoreAI system path helper missing."
    FAIL=1
fi

if ! grep -q 'artifactKind=system_model only with model path system-model/system://' scripts/ios-simulator-local-model-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: simulator CoreAI system-model path preflight missing."
    FAIL=1
fi

if ! grep -q 'artifactKind=system_model only with system-model/system:// paths' scripts/ios-device-installed-pack-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack CoreAI system-model path preflight missing."
    FAIL=1
fi

if ! grep -q "draft_acceleration_inactive" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: simulator MTP draft-acceleration guard missing."
    FAIL=1
fi

if ! grep -q 'draft_status != "active"' scripts/ios-simulator-local-model-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: simulator MTP guard does not require active draft status."
    FAIL=1
fi

if ! grep -q 'draft_status != "active"' scripts/ios-device-installed-pack-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack MTP guard does not require active draft status."
    FAIL=1
fi

if ! grep -Fq 'draft_status=\(providerHealth.draftAccelerationStatus' ios/Ross/App/ScreenshotExporter.swift 2>/dev/null; then
    echo "❌ FAIL: app-side MTP failure marker does not report draft status."
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
    scripts/test-ios-runtime-smoke-preflights.sh
    scripts/test-ross-smoke-summary.py
    echo "iOS runtime dependency audit: PASS"
    echo "real local inference: GGUF ready; MLX/CoreAI/MTP require guarded validation"
    echo "benchmark guardrails: READY"
    exit 0
fi

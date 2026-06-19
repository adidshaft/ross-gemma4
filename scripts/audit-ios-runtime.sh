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

if ! grep -q "preflightProvider = AlphaLocalModelRuntime.resolveProvider" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null; then
    echo "❌ FAIL: unavailable smoke preflight does not log the actual provider identity."
    FAIL=1
fi

if ! grep -q "draft_status" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null; then
    echo "❌ FAIL: draft status missing from runtime identity marker."
    FAIL=1
fi

if ! grep -q "draft_model_path_type" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null; then
    echo "❌ FAIL: draft model path type missing from runtime identity marker."
    FAIL=1
fi

if ! grep -q "ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null; then
    echo "❌ FAIL: smoke benchmark matrix marker missing."
    FAIL=1
fi

if ! grep -q 'key: "tokens_processed"' ios/Ross/AlphaFoundation/AlphaAskConversationScreen.swift 2>/dev/null; then
    echo "❌ FAIL: answer details sheet does not expose processed-token metrics."
    FAIL=1
fi

if ! grep -q 'key: "token_speed"' ios/Ross/AlphaFoundation/AlphaAskConversationScreen.swift 2>/dev/null; then
    echo "❌ FAIL: answer details sheet does not expose token-speed metrics."
    FAIL=1
fi

if ! grep -q 'key: "runtime_acceleration"' ios/Ross/AlphaFoundation/AlphaAskConversationScreen.swift 2>/dev/null; then
    echo "❌ FAIL: answer details sheet does not expose runtime acceleration metrics."
    FAIL=1
fi

if ! grep -q 'Label(rossLocalized("answer_details"), systemImage: "info.circle")' ios/Ross/AlphaFoundation/AlphaAskConversationScreen.swift 2>/dev/null; then
    echo "❌ FAIL: answer details metrics are not available from the hidden info/context-menu action."
    FAIL=1
fi

for smoke_script in scripts/ios-simulator-local-model-smoke.sh scripts/ios-device-installed-pack-smoke.sh scripts/ios-device-gguf-smoke.sh; do
    if ! grep -q "MissingBenchmarkMatrixError" "$smoke_script" 2>/dev/null; then
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

if ! grep -q "draft_model_path_type" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: shared smoke parser omits draft model path type."
    FAIL=1
fi

if ! grep -q "runtime_identity_artifact_error" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: shared smoke parser omits runtime artifact identity validation."
    FAIL=1
fi

if ! grep -q "runtime_identity_draft_artifact_error" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: shared smoke parser omits draft artifact identity validation."
    FAIL=1
fi

for smoke_script in scripts/ios-simulator-local-model-smoke.sh scripts/ios-device-installed-pack-smoke.sh scripts/ios-device-gguf-smoke.sh; do
    if ! grep -q "runtime_identity_artifact_mismatch" "$smoke_script" 2>/dev/null; then
        echo "❌ FAIL: $smoke_script does not reject mismatched runtime artifact identity."
        FAIL=1
    fi
done

if ! grep -q "runtime_identity_mismatch" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: simulator smoke runtime identity guard missing."
    FAIL=1
fi

if ! grep -q "runtime_identity_mismatch" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack device smoke runtime identity guard missing."
    FAIL=1
fi

if ! grep -q "preferredRuntimeMode != nil" ios/Ross/AlphaFoundation/AlphaRossModel+Ask.swift 2>/dev/null; then
    echo "❌ FAIL: Ask runtime resolver does not fail closed for explicit preferred runtime requests."
    FAIL=1
fi

if ! grep -q "testExplicitMLXRuntimeRequestDoesNotFallBackToGGUFProvider" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: Swift tests do not cover explicit MLX requests avoiding GGUF fallback."
    FAIL=1
fi

if ! grep -q "testExplicitCoreMLRuntimeRequestDoesNotFallBackToGGUFProvider" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: Swift tests do not cover explicit CoreAI/CoreML requests avoiding GGUF fallback."
    FAIL=1
fi

if ! grep -q "PassingLlamaContext" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: fallback tests do not stub GGUF context creation for placeholder fixtures."
    FAIL=1
fi

if ! grep -q "testCanRunRealLocalAskFallsBackFromUnavailableSystemAssistantToRecoveredDownload" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: Swift tests do not cover automatic Ask fallback from unavailable CoreAI to recovered GGUF."
    FAIL=1
fi

if ! grep -q "testRuntimeIdentityLineMarksDeterministicProviderAsFallback" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: Swift tests do not prove deterministic fallback identity is marked as fallback."
    FAIL=1
fi

if ! grep -q "identity_requested" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack device smoke does not validate requested runtime identity."
    FAIL=1
fi

for smoke_script in scripts/ios-simulator-local-model-smoke.sh scripts/ios-device-installed-pack-smoke.sh; do
    if ! grep -q "Unsupported smoke profile" "$smoke_script" 2>/dev/null; then
        echo "❌ FAIL: $smoke_script does not reject unsupported smoke profiles before launch."
        FAIL=1
    fi
done

if ! grep -q "draftArtifact.relativePath" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack device smoke does not preflight required draft companion paths."
    FAIL=1
fi

if ! grep -q "selected_draft_artifact_kind" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack device smoke does not preflight draft companion artifact kind."
    FAIL=1
fi

if ! grep -q "Draft acceleration proof is only supported" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack device smoke does not reject unsupported draft-acceleration proof lanes before launch."
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

if ! grep -q "unsupported_mlx_draft_artifact" ios/Ross/AlphaFoundation/AlphaMLXLocalProvider.swift 2>/dev/null; then
    echo "❌ FAIL: MLX draft companion diagnostics do not surface unsupported draft archive categories."
    FAIL=1
fi

if ! grep -q "draftModelPathType: draftModelPathType()" ios/Ross/AlphaFoundation/AlphaMLXLocalProvider.swift 2>/dev/null; then
    echo "❌ FAIL: MLX runtime health does not preserve configured draft artifact path type in unavailable branches."
    FAIL=1
fi

if ! grep -q "unavailableDraftAccelerationStatus" ios/Ross/AlphaFoundation/AlphaLocalModelRuntime.swift 2>/dev/null; then
    echo "❌ FAIL: unavailable MLX runtime health does not surface concrete draft status for blocked lanes."
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

if [ ! -x scripts/test-ios-device-installed-pack-preflights.sh ]; then
    echo "❌ FAIL: executable installed-pack manifest preflight test script missing."
    FAIL=1
fi

if ! grep -q "seeded device-proof pack excluded by default" scripts/test-ios-device-installed-pack-preflights.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack preflight tests do not cover seeded device-proof exclusion."
    FAIL=1
fi

if [ ! -x scripts/test-ross-smoke-summary.py ]; then
    echo "❌ FAIL: executable smoke benchmark summary parser test missing."
    FAIL=1
fi

if [ ! -x scripts/ios-morning-runtime-checkpoint-plan.sh ]; then
    echo "❌ FAIL: executable morning runtime checkpoint dry-run planner missing."
    FAIL=1
fi

if ! grep -q -- "--require-draft-acceleration" scripts/ios-morning-runtime-checkpoint-plan.sh 2>/dev/null; then
    echo "❌ FAIL: morning runtime checkpoint plan does not include guarded MTP proof."
    FAIL=1
fi

if ! grep -q "every benchmark matrix stage" scripts/ios-morning-runtime-checkpoint-plan.sh 2>/dev/null; then
    echo "❌ FAIL: morning runtime checkpoint plan does not explain stage-level MTP proof."
    FAIL=1
fi

if grep -q -- "--allow-device-proof-pack" scripts/ios-morning-runtime-checkpoint-plan.sh 2>/dev/null; then
    echo "❌ FAIL: morning runtime checkpoint plan should not allow seeded proof packs for MTP proof."
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

if ! grep -q "Selected CoreAI/CoreML adapter manifest reports an empty artifact" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack CoreAI adapter smoke does not reject empty adapter artifacts before launch."
    FAIL=1
fi

if ! grep -q "Selected GGUF manifest reports an implausibly small artifact" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack GGUF smoke does not reject implausibly small primary artifacts before launch."
    FAIL=1
fi

if ! grep -q "Selected GGUF/MTP manifest reports an implausibly small draft artifact" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack MTP proof does not reject implausibly small draft artifacts before launch."
    FAIL=1
fi

if ! grep -q "Selected MLX manifest reports an implausibly small artifact" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack MLX smoke does not reject implausibly small primary artifacts before launch."
    FAIL=1
fi

if ! grep -q "Selected MLX manifest reports an implausibly small draft artifact" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack MLX draft proof does not reject implausibly small draft artifacts before launch."
    FAIL=1
fi

if ! grep -q "draft_acceleration_inactive" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: simulator MTP draft-acceleration guard missing."
    FAIL=1
fi

if ! grep -q "GGUF/MTP simulator draft proof requires a GGUF draft file" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: simulator MTP proof does not preflight GGUF draft artifact shape."
    FAIL=1
fi

if ! grep -q "GGUF header and size larger than 1 MB" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: simulator MTP proof does not reject placeholder draft GGUF files before launch."
    FAIL=1
fi

if ! grep -q "MLX simulator draft proof requires an MLX draft directory" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: simulator MLX draft proof does not preflight MLX draft artifact shape."
    FAIL=1
fi

if ! grep -q "Draft acceleration proof is only supported for GGUF/MLX simulator smokes" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: simulator CoreAI smoke does not reject unsupported draft proof."
    FAIL=1
fi

if ! grep -q 'identity.get("draft_status") != "active"' scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: shared MTP guard does not require active draft status."
    FAIL=1
fi

if ! grep -q "benchmark_stage_draft_error" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: benchmark summary guard does not verify stage-level draft acceleration."
    FAIL=1
fi

if ! grep -q "benchmark_draft_stage_mismatch" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: benchmark summary guard does not reject active identity with standard generation stages."
    FAIL=1
fi

for smoke_helper in scripts/ios-simulator-local-model-smoke.sh scripts/ios-device-installed-pack-smoke.sh scripts/ios-device-gguf-smoke.sh; do
    if ! grep -q "MissingBenchmarkMatrixError as error" "$smoke_helper" 2>/dev/null; then
        echo "❌ FAIL: $smoke_helper does not preserve specific benchmark summary guard errors."
        FAIL=1
    fi
done

if ! grep -q "draft_model_format" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: shared MTP guard does not reject non-GGUF draft artifact labels."
    FAIL=1
fi

if ! grep -q "draft_validator_failed" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null; then
    echo "❌ FAIL: GGUF/MTP health does not surface draft validator failure categories."
    FAIL=1
fi

if ! grep -q "draft_validator_rejected" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null; then
    echo "❌ FAIL: GGUF/MTP health does not surface draft validator rejection categories."
    FAIL=1
fi

if ! grep -q "runtime_identity_draft_artifact_error" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: simulator MTP guard does not validate draft artifact path shape."
    FAIL=1
fi

if ! grep -q "runtime_identity_draft_artifact_error" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack MTP guard does not validate draft artifact path shape."
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
    scripts/test-ios-device-installed-pack-preflights.sh
    scripts/test-ross-smoke-summary.py
    echo "iOS runtime dependency audit: PASS"
    echo "real local inference: GGUF ready; MLX/CoreAI/MTP require guarded validation"
    echo "benchmark guardrails: READY"
    exit 0
fi

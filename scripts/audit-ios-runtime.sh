#!/usr/bin/env bash
set -euo pipefail

FAIL=0

echo "Running iOS Runtime Audit..."

if [[ ! -x scripts/test-ios-runtime-swiftpm.sh ]] ||
   ! grep -q "REQUIRED_TESTS" scripts/test-ios-runtime-swiftpm.sh 2>/dev/null ||
   ! grep -q "Missing required runtime guardrail test" scripts/test-ios-runtime-swiftpm.sh 2>/dev/null ||
   ! grep -q "testExplicitMLXRuntimeRequestDoesNotFallBackToGGUFProvider" scripts/test-ios-runtime-swiftpm.sh 2>/dev/null ||
   ! grep -q "testFoundationProviderReportsUnsupportedPlatformBeforeGeneration" scripts/test-ios-runtime-swiftpm.sh 2>/dev/null ||
   ! grep -q "testExperimentalGGUFProviderUsesStrictDraftContextWhenSmokeRequiresDraftAcceleration" scripts/test-ios-runtime-swiftpm.sh 2>/dev/null ||
   ! grep -q "testAnswerDetailOverviewMetricsPreferMeasuredTokenCountLabel" scripts/test-ios-runtime-swiftpm.sh 2>/dev/null; then
    echo "❌ FAIL: SwiftPM runtime guardrail test helper is missing MLX/CoreAI/MTP coverage."
    FAIL=1
fi

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

if ! grep -q "error=no_active_pack" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null; then
    echo "❌ FAIL: smoke no-active-pack failures are not structured with an error field."
    FAIL=1
fi

if ! grep -q "stage=resolve_provider error=provider_unavailable" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null; then
    echo "❌ FAIL: smoke provider-unavailable failures are not structured with stage/error fields."
    FAIL=1
fi

if ! grep -q "stage=provider_health error=.*requested_runtime" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null &&
   ! grep -q "requested_runtime=.*stage=provider_health" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null; then
    echo "❌ FAIL: smoke provider-health failures do not preserve requested runtime."
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

if ! grep -q "draft_error_detail" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null ||
   ! grep -q "draftAccelerationDetail" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null; then
    echo "❌ FAIL: MTP runtime identity does not preserve safe draft validator diagnostics."
    FAIL=1
fi

if ! grep -q "runtime_error_detail" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null ||
   ! grep -q "runtimeErrorDetail" ios/Ross/AlphaFoundation/AlphaLocalModelRuntime.swift 2>/dev/null ||
   ! grep -q '"runtime_error_detail": summary_value(identity, "runtime_error_detail")' scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: runtime identity does not preserve provider runtime error diagnostics."
    FAIL=1
fi

if ! grep -q "artifactCompatibilityError" ios/Ross/AlphaFoundation/AlphaLocalModelRuntime.swift 2>/dev/null ||
   ! grep -q "missing_mlx_artifact" ios/Ross/AlphaFoundation/AlphaLocalModelRuntime.swift 2>/dev/null ||
   ! grep -q "missing_coreai_artifact" ios/Ross/AlphaFoundation/AlphaLocalModelRuntime.swift 2>/dev/null; then
    echo "❌ FAIL: runtime resolver does not reject incompatible MLX/CoreAI artifact kinds before provider construction."
    FAIL=1
fi

if ! grep -q "testRuntimeHealthRejectsMLXRequestAgainstGGUFPackBeforeFallback" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null ||
   ! grep -q "testRuntimeHealthRejectsCoreAIRequestAgainstGGUFPackBeforeFallback" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: Swift tests do not cover MLX/CoreAI runtime requests rejecting GGUF packs before fallback."
    FAIL=1
fi

if ! grep -q "getOrContext(path: modelPath, includeDraft: false)" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null ||
   ! grep -q "testRuntimeHealthKeepsBaselineAvailableWhenDraftArtifactIsInvalid" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: GGUF runtime availability can still be poisoned by invalid MTP draft artifacts."
    FAIL=1
fi

if ! grep -q "iOS GGUF/.*current proven real local inference lane" docs/RUNTIME_DECISION_MEMO.md 2>/dev/null ||
   ! grep -q "Do not claim MLX/CoreAI/MTP numbers from a GGUF identity marker" docs/RUNTIME_DECISION_MEMO.md 2>/dev/null ||
   ! grep -q "App-side provider resolution and smoke preflights both fail closed on incompatible artifact shapes" docs/LOCAL_MODEL_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: runtime docs do not preserve the current iOS GGUF proof and no-GGUF-fallback contract."
    FAIL=1
fi

if ! grep -q "error=draft_acceleration_required.*draft_model_path_type" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null; then
    echo "❌ FAIL: MTP-required smoke failures do not preserve draft artifact path type."
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

if ! grep -q "alphaInstalledAssistantPackPassesRuntimeValidation" ios/Ross/AlphaFoundation/AlphaPrivateAIViews.swift 2>/dev/null; then
    echo "❌ FAIL: assistant runtime variant options do not filter invalid installed packs."
    FAIL=1
fi

if ! grep -q "testAssistantVariantOptionsHideInvalidInstalledRuntimePack" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: Swift tests do not cover invalid installed packs being hidden from runtime options."
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

if ! grep -q "benchmark_matrix_shape_mismatch" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: shared benchmark summary parser does not reject matrix case/stage shape mismatches."
    FAIL=1
fi

if ! grep -q "CASE_EXPECTATIONS" scripts/ross_smoke_summary.py 2>/dev/null ||
   ! grep -q "case_stage_mismatch" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: shared benchmark summary parser does not semantically validate varied document/query matrix cases."
    FAIL=1
fi

if ! grep -q 'summary\[f"{stage}_case"\]' scripts/ross_smoke_summary.py 2>/dev/null ||
   ! grep -q 'summary\[f"{stage}_max_tokens"\]' scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: benchmark summaries do not preserve per-stage case and max-token matrix metadata."
    FAIL=1
fi

if ! grep -q "unknown_stages" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: shared benchmark summary parser does not reject unknown matrix stages."
    FAIL=1
fi

if ! grep -q "benchmark_runtime_unavailable" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: shared benchmark summary parser does not reject unavailable/fallback runtime identities."
    FAIL=1
fi

if ! grep -q "test_benchmark_summary_rejects_unavailable_runtime_identity" scripts/test-ross-smoke-summary.py 2>/dev/null ||
   ! grep -q "test_benchmark_summary_rejects_fallback_runtime_identity" scripts/test-ross-smoke-summary.py 2>/dev/null; then
    echo "❌ FAIL: smoke summary tests do not cover unavailable/fallback identity benchmark rejection."
    FAIL=1
fi

if ! grep -q "benchmark_runtime_unsupported" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: shared benchmark summary parser does not reject unsupported runtime identities."
    FAIL=1
fi

if ! grep -q "benchmark_runtime_artifact_mismatch" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: shared benchmark summary parser does not reject runtime artifact mismatches."
    FAIL=1
fi

if ! grep -q "benchmark_runtime_identity_missing" scripts/ross_smoke_summary.py 2>/dev/null ||
   ! grep -q "runtime_identity_resource_error" scripts/ross_smoke_summary.py 2>/dev/null ||
   ! grep -q "test_benchmark_summary_rejects_missing_runtime_resource_identity" scripts/test-ross-smoke-summary.py 2>/dev/null ||
   ! grep -q "benchmark_runtime_identity_missing" docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: shared benchmark summary parser does not require provider/context/offload identity evidence."
    FAIL=1
fi

if ! grep -q "system_model_path" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: shared benchmark summary parser does not require CoreAI system_model sentinel paths."
    FAIL=1
fi

if ! grep -q "artifactPathLabel = alphaPackUsesSystemFoundationModel" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null ||
   ! grep -q "artifact_path=system://apple-foundation-models" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: CoreAI system-model runtime identity does not preserve system:// sentinel artifact paths."
    FAIL=1
fi

if ! grep -q "test_benchmark_summary_accepts_coreai_system_url_identity" scripts/test-ross-smoke-summary.py 2>/dev/null; then
    echo "❌ FAIL: smoke summary tests do not prove CoreAI system:// identities can become guarded benchmark summaries."
    FAIL=1
fi

if ! grep -q "mlx_directory_path" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: shared benchmark summary parser does not reject file-like MLX directory labels."
    FAIL=1
fi

if ! grep -q "failure_summary_line" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: shared smoke parser omits failure summaries."
    FAIL=1
fi

if ! grep -q "stageDoneLine(stage:" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null ||
   ! grep -q "benchmarkFields(stage: stage, output: output)" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null; then
    echo "❌ FAIL: app stage-done smoke marker does not preserve benchmark metrics."
    FAIL=1
fi

if ! grep -q "completed_stage_fields" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null ||
   ! grep -q 'outcome == "timeout"' scripts/ios-simulator-local-model-smoke.sh 2>/dev/null ||
   ! grep -q "failure_summary_line(identity, fail_fields, matrix_fields)" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: simulator helper timeout path does not preserve completed stage metrics in failure summaries."
    FAIL=1
fi

if ! grep -q '"fail_runtime"' scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: failure summaries do not preserve the raw failure-marker runtime."
    FAIL=1
fi

if ! grep -q 'fail_fields.get("requested_runtime")' scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: failure summaries do not preserve requested runtime from failure markers."
    FAIL=1
fi

if ! grep -q '"matrix_shape_error"' scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: failure summaries do not preserve benchmark matrix shape errors."
    FAIL=1
fi

if ! grep -q "tamil_acceleration=standard" scripts/test-ross-smoke-summary.py 2>/dev/null; then
    echo "❌ FAIL: smoke failure summary tests do not cover stage acceleration evidence."
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

for smoke_script in scripts/ios-simulator-local-model-smoke.sh scripts/ios-device-installed-pack-smoke.sh scripts/ios-device-gguf-smoke.sh; do
    if ! grep -q "pack_runtime_mismatch" "$smoke_script" 2>/dev/null; then
        echo "❌ FAIL: $smoke_script does not fail early on active pack/runtime identity mismatches."
        FAIL=1
    fi
done

for smoke_script in scripts/ios-simulator-local-model-smoke.sh scripts/ios-device-installed-pack-smoke.sh scripts/ios-device-gguf-smoke.sh; do
    if ! grep -q "pack_runtime_missing" "$smoke_script" 2>/dev/null; then
        echo "❌ FAIL: $smoke_script does not fail early on missing active pack runtime identity."
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

if ! grep -q "Stage timeout must be a positive integer" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null ||
   ! grep -q "nonnumeric installed-pack stage timeout" scripts/test-ios-device-installed-pack-preflights.sh 2>/dev/null ||
   ! grep -q "zero installed-pack stage timeout" scripts/test-ios-device-installed-pack-preflights.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack device smoke does not validate stage timeouts before launch."
    FAIL=1
fi

if ! grep -q "installed MLX request rejects GGUF identity" scripts/test-ios-device-installed-pack-preflights.sh 2>/dev/null ||
   ! grep -q "runtime_identity_mismatch" scripts/test-ios-device-installed-pack-preflights.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack smoke tests do not cover rejecting GGUF identity for a requested MLX lane."
    FAIL=1
fi

if ! grep -q "installed CoreAI request rejects GGUF identity" scripts/test-ios-device-installed-pack-preflights.sh 2>/dev/null ||
   ! grep -q "requested_runtime=apple_foundation_models actual_runtime=gemma_local_runtime" scripts/test-ios-device-installed-pack-preflights.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack smoke tests do not cover rejecting GGUF identity for a requested CoreAI/CoreML lane."
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

if ! grep -q "testRuntimeIdentityLineIncludesMissingCoreAIArtifactForExplicitCoreMLWithoutSentinel" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: Swift tests do not prove explicit CoreAI/CoreML requests without a sentinel fail as missing_coreai_artifact."
    FAIL=1
fi

if ! grep -q "testRuntimeIdentityLineIncludesMissingMLXArtifactForExplicitMLXWithoutBorrowingGGUF" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: Swift tests do not prove explicit MLX requests without an MLX artifact fail as missing_mlx_artifact without borrowing active GGUF identity."
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

if ! grep -q "testRuntimeIdentityPreflightProviderNamesStayRuntimeSpecific" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: Swift tests do not pin runtime-specific preflight provider names."
    FAIL=1
fi

if ! grep -q "testRuntimeIdentityLineMarksDeterministicProviderAsFallback" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: Swift tests do not prove deterministic fallback identity is marked as fallback."
    FAIL=1
fi

if ! grep -q "testRuntimeIdentityLineIncludesUnavailableMLXDraftCandidate" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: Swift tests do not prove unavailable MLX identity preserves draft candidate diagnostics."
    FAIL=1
fi

if ! grep -q "alphaDebugSmokeArtifactKind" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null ||
   ! grep -q "testDebugLocalModelSmokePackRejectsMissingRuntimeArtifactKind" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: debug smoke packs do not fail closed on missing or mismatched artifact kinds."
    FAIL=1
fi

if ! grep -q "testExplicitCoreAIAdapterPathOverridesActiveSystemSentinel" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: Swift tests do not prove explicit CoreAI/CoreML adapter smoke paths override an active system sentinel."
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

if ! grep -q "runtime_pass_mismatch" scripts/ios-device-assistant-download-smoke.sh 2>/dev/null ||
   ! grep -q "missing_runtime_identity" scripts/ios-device-assistant-download-smoke.sh 2>/dev/null ||
   ! grep -q "runtime_identity_artifact_mismatch" scripts/ios-device-assistant-download-smoke.sh 2>/dev/null ||
   ! grep -q "runtime_identity_mismatch_on_failure" scripts/ios-device-assistant-download-smoke.sh 2>/dev/null ||
   ! grep -q "fail_gguf_identity" scripts/test-ios-device-assistant-download-smoke-guards.sh 2>/dev/null ||
   ! grep -q "test-ios-device-assistant-download-smoke-guards.sh" scripts/audit-ios-runtime.sh 2>/dev/null; then
    echo "❌ FAIL: assistant-download smoke runtime pass/failure guard missing."
    FAIL=1
fi

if ! grep -q "missing_mlx_artifact" ios/Ross/AlphaFoundation/AlphaMLXLocalProvider.swift 2>/dev/null; then
    echo "❌ FAIL: MLX missing-artifact error category missing."
    FAIL=1
fi

if ! grep -q "fileLooksNonEmpty" ios/Ross/AlphaFoundation/AlphaMLXLocalProvider.swift 2>/dev/null ||
   ! grep -q "testRuntimeHealthMarksEmptyMLXWeightsUnavailable" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: Swift MLX runtime health can still treat empty weights as a usable artifact."
    FAIL=1
fi

if ! grep -q "testMLXRunReturnsUnsupportedArchiveCategoryBeforeGeneration" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: Swift MLX run path can still reach generation for known-unsupported primary archives."
    FAIL=1
fi

if ! grep -q "testMLXRunReturnsInvalidArtifactForEmptyWeightsBeforeGeneration" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: Swift MLX run path can still reach generation for empty primary weights."
    FAIL=1
fi

if ! grep -q "mlx_generation_failed" ios/Ross/AlphaFoundation/AlphaMLXLocalProvider.swift 2>/dev/null ||
   ! grep -q "mlx_generation_failed" ios/Ross/AlphaFoundation/AlphaRossModel+Ask.swift 2>/dev/null ||
   ! grep -q "mlx_generation_failed" ios/Ross/AlphaFoundation/AlphaRossModel+Documents.swift 2>/dev/null ||
   ! grep -q "testExperimentalMLXProviderReportsStandardGenerationFailureAsMLXFailure" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null ||
   ! grep -q "mlx_generation_failed" docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: MLX standard generation failures are not wired through provider, fallback handling, tests, and docs."
    FAIL=1
fi

if grep -q 'return (false, "invalid_mlx_draft_artifact"' ios/Ross/AlphaFoundation/AlphaMLXLocalProvider.swift 2>/dev/null; then
    echo "❌ FAIL: invalid MLX draft companion still poisons primary MLX availability."
    FAIL=1
fi

if ! grep -q 'draftStatus.status == "active"' ios/Ross/AlphaFoundation/AlphaMLXLocalProvider.swift 2>/dev/null ||
   ! grep -q "testExperimentalMLXProviderRunsStandardGenerationWhenDraftArtifactIsInvalid" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: invalid MLX draft companion can still be passed into generation or output metadata."
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

if [ ! -x scripts/test-ios-morning-runtime-checkpoint-plan.sh ]; then
    echo "❌ FAIL: executable morning runtime checkpoint planner test missing."
    FAIL=1
fi

if [ ! -x scripts/ios-runtime-artifact-inventory.sh ]; then
    echo "❌ FAIL: executable local runtime artifact inventory missing."
    FAIL=1
fi

if [ ! -x scripts/test-ios-runtime-artifact-inventory.sh ]; then
    echo "❌ FAIL: executable local runtime artifact inventory test missing."
    FAIL=1
fi

if ! grep -q '"mtp_draft"' scripts/ios-runtime-artifact-inventory.sh 2>/dev/null; then
    echo "❌ FAIL: local runtime artifact inventory does not report MTP draft readiness."
    FAIL=1
fi

if ! grep -q -- "--installed-root" scripts/ios-runtime-artifact-inventory.sh 2>/dev/null; then
    echo "❌ FAIL: local runtime artifact inventory cannot inspect installed-pack manifests."
    FAIL=1
fi

if ! grep -q "manifest_primary_unusable_artifact" scripts/ios-runtime-artifact-inventory.sh 2>/dev/null ||
   ! grep -q "manifest_draft_unusable_artifact" scripts/ios-runtime-artifact-inventory.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack runtime inventory does not reject malformed reachable artifacts."
    FAIL=1
fi

if ! grep -q "manifest_primary_checksum_mismatch" scripts/ios-runtime-artifact-inventory.sh 2>/dev/null ||
   ! grep -q "manifest_draft_checksum_mismatch" scripts/ios-runtime-artifact-inventory.sh 2>/dev/null ||
   ! grep -q "checksum_status=mismatch" scripts/test-ios-runtime-artifact-inventory.sh 2>/dev/null ||
   ! grep -q "manifest_primary_checksum_mismatch" docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: installed artifact inventory does not reject checksum-mismatched file artifacts."
    FAIL=1
fi

if ! grep -q "device_mlx_directory_looks_usable" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null ||
   ! grep -q "malformed installed MLX directory" scripts/test-ios-device-installed-pack-preflights.sh 2>/dev/null ||
   ! grep -q "malformed installed MLX draft directory" scripts/test-ios-device-installed-pack-preflights.sh 2>/dev/null; then
    echo "❌ FAIL: device installed-pack smoke can still treat malformed MLX directories as launch-ready."
    FAIL=1
fi

if ! grep -q -- "-size +0c" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null ||
   ! grep -q -- "-size +0c" scripts/ios-runtime-artifact-inventory.sh 2>/dev/null ||
   ! grep -q "empty MLX weights" scripts/test-ios-runtime-smoke-preflights.sh 2>/dev/null ||
   ! grep -q "lane=mlx status=missing" scripts/test-ios-runtime-artifact-inventory.sh 2>/dev/null; then
    echo "❌ FAIL: MLX preflight/inventory can still treat empty safetensors files as usable."
    FAIL=1
fi

if ! grep -q "coreai_adapter_looks_usable" scripts/ios-runtime-artifact-inventory.sh 2>/dev/null ||
   ! grep -q "bad-coreai" scripts/test-ios-runtime-artifact-inventory.sh 2>/dev/null ||
   ! grep -q "lane=coreai_adapter status=missing" scripts/test-ios-runtime-artifact-inventory.sh 2>/dev/null ||
   ! grep -q "Local and installed file-backed CoreAI/CoreML adapter rows must have non-empty reachable adapter contents" docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: installed CoreAI adapter inventory can treat empty adapter paths as ready."
    FAIL=1
fi

if ! grep -q "installed_mtp_draft" scripts/test-ios-runtime-artifact-inventory.sh 2>/dev/null; then
    echo "❌ FAIL: local runtime artifact inventory tests do not cover installed MTP draft manifests."
    FAIL=1
fi

if ! grep -q "catalog_mtp_draft" scripts/test-ios-runtime-artifact-inventory.sh 2>/dev/null; then
    echo "❌ FAIL: local runtime artifact inventory tests do not cover catalog MTP draft expectations."
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

if ! grep -q "positive context_tokens" scripts/ios-morning-runtime-checkpoint-plan.sh 2>/dev/null ||
   ! grep -q "gpu_offload evidence" scripts/ios-morning-runtime-checkpoint-plan.sh 2>/dev/null ||
   ! grep -q "positive context_tokens" scripts/test-ios-morning-runtime-checkpoint-plan.sh 2>/dev/null ||
   ! grep -q "gpu_offload evidence" scripts/test-ios-morning-runtime-checkpoint-plan.sh 2>/dev/null; then
    echo "❌ FAIL: morning runtime checkpoint plan does not require resource identity evidence for benchmark rows."
    FAIL=1
fi

if ! grep -q "Full matrix cases: English source-bound document QA, Bengali source-bound document QA, Hindi source-bound document QA, Tamil source-bound document QA, Telugu source-bound document QA, and English open no-document query." scripts/ios-morning-runtime-checkpoint-plan.sh 2>/dev/null; then
    echo "❌ FAIL: morning runtime checkpoint plan does not document the varied document/query benchmark matrix."
    FAIL=1
fi

if ! grep -q "Inventory gate: not provided" scripts/ios-morning-runtime-checkpoint-plan.sh 2>/dev/null ||
   ! grep -q "runtime commands are templates until installed-pack inventory proves matching artifacts" scripts/test-ios-morning-runtime-checkpoint-plan.sh 2>/dev/null; then
    echo "❌ FAIL: morning runtime checkpoint plan does not warn when installed inventory gating is unavailable."
    FAIL=1
fi

if ! grep -q "Stage timeout must be a positive integer" scripts/ios-morning-runtime-checkpoint-plan.sh 2>/dev/null ||
   ! grep -q "nonnumeric morning stage timeout" scripts/test-ios-morning-runtime-checkpoint-plan.sh 2>/dev/null ||
   ! grep -q "zero morning stage timeout" scripts/test-ios-morning-runtime-checkpoint-plan.sh 2>/dev/null; then
    echo "❌ FAIL: morning runtime checkpoint plan does not validate stage timeouts before printing device commands."
    FAIL=1
fi

if ! grep -q -- "--preflight-only" scripts/ios-morning-runtime-checkpoint-plan.sh 2>/dev/null ||
   ! grep -q "without launching Simulator or touching the cabled iPhone" scripts/ios-morning-runtime-checkpoint-plan.sh 2>/dev/null ||
   ! grep -q "ROSS_SIMULATOR_SMOKE_PREFLIGHT_OK" scripts/test-ios-morning-runtime-checkpoint-plan.sh 2>/dev/null ||
   ! grep -q "Run no-launch artifact preflights" docs/MODEL_ARTIFACT_STATUS.md 2>/dev/null; then
    echo "❌ FAIL: morning runtime checkpoint plan does not remind operators to use no-launch artifact preflights before device work."
    FAIL=1
fi

if ! grep -q "inventory_tier_pattern" scripts/ios-morning-runtime-checkpoint-plan.sh 2>/dev/null ||
   ! grep -q "missing_installed_mlx_for_tier" scripts/ios-morning-runtime-checkpoint-plan.sh 2>/dev/null ||
   ! grep -q "wrong-tier inventory" scripts/test-ios-morning-runtime-checkpoint-plan.sh 2>/dev/null; then
    echo "❌ FAIL: morning runtime checkpoint plan does not gate installed lanes by requested tier."
    FAIL=1
fi

if ! grep -q 'inventory_has_present_lane "installed_gguf"' scripts/ios-morning-runtime-checkpoint-plan.sh 2>/dev/null ||
   ! grep -q "broken installed GGUF primary" scripts/test-ios-morning-runtime-checkpoint-plan.sh 2>/dev/null; then
    echo "❌ FAIL: morning MTP checkpoint plan can run draft proof without a usable installed GGUF primary."
    FAIL=1
fi

if ! grep -q "installed_gguf status=present.*installed_mtp_draft status=present" docs/IOS_RUNTIME.md 2>/dev/null ||
   ! grep -q "installed_gguf status=present.*installed_mtp_draft status=present" docs/REAL_MODEL_QA_REPORT_TEMPLATE.md 2>/dev/null; then
    echo "❌ FAIL: docs do not state that MTP proof needs both installed GGUF primary and installed MTP draft inventory."
    FAIL=1
fi

if ! grep -q "installed_gguf status=present.*installed_mtp_draft status=present" docs/MODEL_ARTIFACT_STATUS.md 2>/dev/null ||
   ! grep -q "every benchmark summary stage must keep draft acceleration active" docs/MODEL_ARTIFACT_STATUS.md 2>/dev/null ||
   ! grep -q "context_tokens=1024" docs/MODEL_ARTIFACT_STATUS.md 2>/dev/null; then
    echo "❌ FAIL: model artifact status does not reflect paired MTP inventory and per-stage draft proof requirements."
    FAIL=1
fi

if ! grep -q "current repo proof lane is now tighter at .*context_tokens=1024.*prompt batch .*128.*physical batch .*64" docs/REAL_MODEL_QA_RESULTS.md 2>/dev/null; then
    echo "❌ FAIL: real-model QA results do not distinguish historical 2k MTP logs from the current 1024-token proof lane."
    FAIL=1
fi

if grep -q -- "--allow-device-proof-pack" scripts/ios-morning-runtime-checkpoint-plan.sh 2>/dev/null; then
    echo "❌ FAIL: morning runtime checkpoint plan should not allow seeded proof packs for MTP proof."
    FAIL=1
fi

if ! grep -q "Morning MTP proof plan must not allow seeded device-proof packs" scripts/test-ios-morning-runtime-checkpoint-plan.sh 2>/dev/null; then
    echo "❌ FAIL: morning runtime checkpoint plan tests do not prove printed commands omit seeded device-proof pack allowance."
    FAIL=1
fi

if ! grep -q "missing_coreai_artifact" ios/Ross/AlphaFoundation/AlphaLocalModelRuntime.swift 2>/dev/null; then
    echo "❌ FAIL: CoreAI missing-artifact error category missing."
    FAIL=1
fi

if ! grep -q "coreai_empty_response" ios/Ross/AlphaFoundation/AlphaLocalModelRuntime.swift 2>/dev/null ||
   ! grep -q "coreai_empty_response" ios/Ross/AlphaFoundation/AlphaRossModel+Ask.swift 2>/dev/null ||
   ! grep -q "coreai_empty_response" ios/Ross/AlphaFoundation/AlphaRossModel+Documents.swift 2>/dev/null ||
   ! grep -q "coreai_empty_response" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null ||
   ! grep -q "coreai_empty_response" docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: CoreAI empty-response category is not wired through provider, fallback handling, tests, and docs."
    FAIL=1
fi

if ! grep -q "coreai_invalid_response" ios/Ross/AlphaFoundation/AlphaLocalModelRuntime.swift 2>/dev/null ||
   ! grep -q "coreai_invalid_response" ios/Ross/AlphaFoundation/AlphaRossModel+Ask.swift 2>/dev/null ||
   ! grep -q "coreai_invalid_response" ios/Ross/AlphaFoundation/AlphaRossModel+Documents.swift 2>/dev/null ||
   ! grep -q "coreai_invalid_response" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null ||
   ! grep -q "coreai_invalid_response" docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: CoreAI invalid structured-response category is not wired through provider, fallback handling, tests, and docs."
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

if ! grep -q "adapterPathLooksUsable" ios/Ross/AlphaFoundation/AlphaLocalModelRuntime.swift 2>/dev/null ||
   ! grep -q "testRuntimeHealthMarksEmptyConfiguredAdapterFileUnavailable" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null ||
   ! grep -q "testRuntimeHealthMarksEmptyConfiguredAdapterDirectoryUnavailable" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: Swift CoreAI adapter runtime health can still treat empty adapter artifacts as usable."
    FAIL=1
fi

if ! grep -q "adapterPathLooksLikeForeignModel" ios/Ross/AlphaFoundation/AlphaLocalModelRuntime.swift 2>/dev/null ||
   ! grep -q "testRuntimeHealthMarksGGUFConfiguredAsCoreAIAdapterUnavailable" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null ||
   ! grep -q "testRuntimeHealthMarksMLXDirectoryConfiguredAsCoreAIAdapterUnavailable" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null ||
   ! grep -q "foreign model artifact" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: CoreAI adapter health/preflights can still accept foreign GGUF/MLX artifacts."
    FAIL=1
fi

if ! grep -q "testFoundationProviderReportsForeignAdapterArtifactsBeforeGeneration" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: CoreAI adapter run path can still reach generation for foreign GGUF/MLX artifacts."
    FAIL=1
fi

if ! grep -q "testFoundationProviderReportsEmptyAdapterArtifactsBeforeGeneration" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: CoreAI adapter run path can still reach generation for empty adapter artifacts."
    FAIL=1
fi

if ! grep -q "testFoundationProviderReportsUnsupportedPlatformBeforeGeneration" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: CoreAI unsupported-platform run path can still reach generation."
    FAIL=1
fi

if ! grep -q "coreai_adapter_looks_usable" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null ||
   ! grep -q "empty CoreAI adapter directory" scripts/test-ios-runtime-smoke-preflights.sh 2>/dev/null ||
   ! grep -q "empty CoreAI adapter file" scripts/test-ios-runtime-smoke-preflights.sh 2>/dev/null; then
    echo "❌ FAIL: simulator CoreAI adapter smoke does not reject empty adapter artifacts before launch."
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

if ! grep -q "device_relative_path_exists" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null ||
   grep -q '! -e "\$device_model_path"' scripts/ios-device-installed-pack-smoke.sh 2>/dev/null ||
   grep -q '! -e "\$device_draft_path"' scripts/ios-device-installed-pack-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack smoke must verify artifact existence through devicectl file listings, not host-side checks of device paths."
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

if ! grep -q "absolute_local_path" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null ||
   ! grep -q 'model_path="$(absolute_local_path "$model_path")"' scripts/ios-simulator-local-model-smoke.sh 2>/dev/null ||
   ! grep -q 'draft_model_path="$(absolute_local_path "$draft_model_path")"' scripts/ios-simulator-local-model-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: simulator smoke does not pass app-readable absolute artifact paths after local preflight."
    FAIL=1
fi

if ! grep -q "Draft acceleration proof is only supported for GGUF/MLX simulator smokes" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: simulator CoreAI smoke does not reject unsupported draft proof."
    FAIL=1
fi

if ! grep -q "ROSS_SIMULATOR_SMOKE_PREFLIGHT_OK" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null ||
   ! grep -q "GGUF model file" scripts/test-ios-runtime-smoke-preflights.sh 2>/dev/null ||
   ! grep -q "MLX usable directory" scripts/test-ios-runtime-smoke-preflights.sh 2>/dev/null ||
   ! grep -q "CoreAI system URL sentinel" scripts/test-ios-runtime-smoke-preflights.sh 2>/dev/null ||
   ! grep -q -- "--preflight-only.*ROSS_SIMULATOR_SMOKE_PREFLIGHT_OK" docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: simulator smoke helper cannot prove valid GGUF/MLX/CoreAI preflights without launching Simulator."
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

if ! grep -q "benchmark_profile_draft_error" scripts/ross_smoke_summary.py 2>/dev/null ||
   ! grep -q "test_benchmark_summary_rejects_mtp_profile_without_active_draft_identity" scripts/test-ross-smoke-summary.py 2>/dev/null ||
   ! grep -q "test_benchmark_profile_draft_error_recognizes_hyphenated_mtp_alias" scripts/test-ross-smoke-summary.py 2>/dev/null ||
   ! grep -q "test_benchmark_profile_draft_error_recognizes_short_mtp_alias" scripts/test-ross-smoke-summary.py 2>/dev/null; then
    echo "❌ FAIL: benchmark summary guard does not reject MTP profiles without active draft identity."
    FAIL=1
fi

if ! grep -q "mtp_quick.*/.*mtp-quick" docs/IOS_RUNTIME.md 2>/dev/null ||
   ! grep -q "mtp.*/.*mtp_quick.*/.*mtp-quick" docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: iOS runtime docs do not document both MTP smoke profile aliases as guarded proof profiles."
    FAIL=1
fi

if ! grep -q "return 1_024" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null ||
   ! grep -q "return min(baseline, 128)" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null ||
   ! grep -q "return min(baseline, 64)" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null ||
   ! grep -q "1024-token context cap" docs/IOS_RUNTIME.md 2>/dev/null ||
   ! grep -q "smaller prompt/physical batches" docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: MTP smoke proof profile is not pinned to the low-context activation lane."
    FAIL=1
fi

if ! grep -q "full | quick | mtp | mtp-quick | mtp_quick" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null ||
   ! grep -q "quick | full | mtp | mtp-quick | mtp_quick" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null; then
    echo "❌ FAIL: smoke helper usage text does not advertise all accepted MTP proof profile aliases."
    FAIL=1
fi

if ! grep -q "Draft acceleration proof requires --smoke-profile mtp_quick" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null ||
   ! grep -q "Draft acceleration proof requires --smoke-profile mtp_quick" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null ||
   ! grep -q "Draft acceleration proof cannot be combined with --disable-draft" scripts/ios-device-installed-pack-smoke.sh 2>/dev/null ||
   ! grep -q "Draft acceleration proof cannot be combined with --disable-draft" scripts/ios-simulator-local-model-smoke.sh 2>/dev/null ||
   ! grep -q "installed-pack draft proof without MTP profile" scripts/test-ios-device-installed-pack-preflights.sh 2>/dev/null ||
   ! grep -q "simulator draft proof without MTP profile" scripts/test-ios-runtime-smoke-preflights.sh 2>/dev/null ||
   ! grep -q "installed-pack draft proof with draft disabled" scripts/test-ios-device-installed-pack-preflights.sh 2>/dev/null ||
   ! grep -q "simulator draft proof with draft disabled" scripts/test-ios-runtime-smoke-preflights.sh 2>/dev/null ||
   ! grep -q "fail before launch if .*--require-draft-acceleration.*full.*quick.*source-only.*--disable-draft" docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: required MTP proof can still run outside the low-token MTP smoke profile."
    FAIL=1
fi

if ! grep -q "benchmark_stage_metric_error" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: benchmark summary guard does not require per-stage token and speed metrics."
    FAIL=1
fi

if ! grep -q "benchmark_stage_quality_error" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: benchmark summary guard does not require per-stage source/native quality evidence."
    FAIL=1
fi

if ! grep -q "gguf_file_path" scripts/ross_smoke_summary.py 2>/dev/null ||
   ! grep -q "gguf_file_path=model.bin" scripts/test-ross-smoke-summary.py 2>/dev/null ||
   ! grep -q 'GGUF summaries require a `\.gguf` artifact label/path' docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: benchmark summary guard does not reject GGUF identities with non-.gguf artifact paths."
    FAIL=1
fi

if ! grep -q "test_benchmark_summary_rejects_missing_source_refs_for_source_bound_stage" scripts/test-ross-smoke-summary.py 2>/dev/null; then
    echo "❌ FAIL: smoke summary tests do not reject source-bound benchmark summaries without retained source refs."
    FAIL=1
fi

if ! grep -q "test_benchmark_summary_rejects_non_native_stage_output" scripts/test-ross-smoke-summary.py 2>/dev/null; then
    echo "❌ FAIL: smoke summary tests do not reject benchmark summaries backed by non-native/fallback stage output."
    FAIL=1
fi

if ! grep -q "test_benchmark_summary_rejects_stage_error_in_pass_marker" scripts/test-ross-smoke-summary.py 2>/dev/null; then
    echo "❌ FAIL: smoke summary tests do not reject pass markers that still carry stage errors."
    FAIL=1
fi

if ! grep -q "source_token_speed=nil" scripts/test-ross-smoke-summary.py 2>/dev/null; then
    echo "❌ FAIL: benchmark summary tests do not reject nil token speed metrics."
    FAIL=1
fi

if ! grep -q "benchmark_runtime_mismatch" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: benchmark summary guard does not reject pass runtime and identity runtime mismatches."
    FAIL=1
fi

if ! grep -q "benchmark_pack_runtime_mismatch" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: benchmark summary guard does not reject active pack/runtime identity mismatches."
    FAIL=1
fi

if ! grep -q "benchmark_pack_runtime_missing" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: benchmark summary guard does not require active pack runtime identity."
    FAIL=1
fi

if ! grep -q "test_benchmark_summary_rejects_missing_pack_runtime" scripts/test-ross-smoke-summary.py 2>/dev/null; then
    echo "❌ FAIL: smoke summary tests do not cover missing active pack runtime identity."
    FAIL=1
fi

if ! grep -q '"pack_runtime": summary_value(identity, "pack_runtime")' scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: benchmark summaries do not preserve active pack runtime identity."
    FAIL=1
fi

if ! grep -q "installedPackPassesRuntimeValidation(currentPack)" ios/Ross/AlphaFoundation/AlphaRossModel+Ask.swift 2>/dev/null; then
    echo "❌ FAIL: preferred-runtime Ask routing can reuse current packs without runtime artifact validation."
    FAIL=1
fi

if ! grep -q "benchmark_requested_runtime_missing" scripts/ross_smoke_summary.py 2>/dev/null ||
   ! grep -q "benchmark_requested_runtime_mismatch" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: benchmark summary guard does not reject missing or mismatched requested/runtime identity."
    FAIL=1
fi

if ! grep -q "ROSS_LOCAL_MODEL_SMOKE_PASS runtime=.*requested_runtime" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null; then
    echo "❌ FAIL: smoke pass markers do not preserve requested runtime context."
    FAIL=1
fi

if ! grep -q "benchmark_pass_requested_runtime_missing" scripts/ross_smoke_summary.py 2>/dev/null ||
   ! grep -q "benchmark_pass_requested_runtime_mismatch" scripts/ross_smoke_summary.py 2>/dev/null ||
   ! grep -q "test_benchmark_summary_rejects_missing_pass_requested_runtime" scripts/test-ross-smoke-summary.py 2>/dev/null; then
    echo "❌ FAIL: benchmark summary guard does not reject missing or mismatched pass requested/runtime identity."
    FAIL=1
fi

if ! grep -q "first_non_nil_value" scripts/ross_smoke_summary.py 2>/dev/null ||
   ! grep -q "test_failure_summary_uses_fail_requested_runtime_when_identity_is_nil" scripts/test-ross-smoke-summary.py 2>/dev/null; then
    echo "❌ FAIL: failure summaries can drop requested-runtime context when identity reports nil."
    FAIL=1
fi

if ! grep -q "benchmark_stage_metrics_missing" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: benchmark summary guard does not reject missing per-stage token and speed metrics."
    FAIL=1
fi

if ! grep -q "benchmark_draft_stage_mismatch" scripts/ross_smoke_summary.py 2>/dev/null; then
    echo "❌ FAIL: benchmark summary guard does not reject active identity with standard generation stages."
    FAIL=1
fi

if ! grep -q "installed MTP stage fallback guard" scripts/test-ios-device-installed-pack-preflights.sh 2>/dev/null ||
   ! grep -q "benchmark_draft_stage_mismatch" scripts/test-ios-device-installed-pack-preflights.sh 2>/dev/null; then
    echo "❌ FAIL: installed-pack MTP smoke tests do not reject active identity when a benchmark stage falls back to standard."
    FAIL=1
fi

if ! grep -q "benchmark_runtime_mismatch" docs/REAL_MODEL_QA_REPORT_TEMPLATE.md 2>/dev/null; then
    echo "❌ FAIL: QA report template does not document runtime mismatch benchmark rejection."
    FAIL=1
fi

if ! grep -q "benchmark_pack_runtime_mismatch" docs/REAL_MODEL_QA_REPORT_TEMPLATE.md 2>/dev/null; then
    echo "❌ FAIL: QA report template does not document active pack/runtime mismatch benchmark rejection."
    FAIL=1
fi

if ! grep -q "benchmark_pack_runtime_missing" docs/REAL_MODEL_QA_REPORT_TEMPLATE.md 2>/dev/null; then
    echo "❌ FAIL: QA report template does not document missing active pack runtime benchmark rejection."
    FAIL=1
fi

if ! grep -q "benchmark_stage_metrics_missing" docs/REAL_MODEL_QA_REPORT_TEMPLATE.md 2>/dev/null; then
    echo "❌ FAIL: QA report template does not document per-stage metric benchmark rejection."
    FAIL=1
fi

if ! grep -q "benchmark_stage_quality_missing" docs/REAL_MODEL_QA_REPORT_TEMPLATE.md 2>/dev/null; then
    echo "❌ FAIL: QA report template does not document per-stage source/native quality benchmark rejection."
    FAIL=1
fi

if ! grep -q "benchmark_draft_profile_mismatch" docs/REAL_MODEL_QA_REPORT_TEMPLATE.md 2>/dev/null; then
    echo "❌ FAIL: QA report template does not document MTP profile/draft identity benchmark rejection."
    FAIL=1
fi

if ! grep -q "benchmark_runtime_identity_missing" docs/REAL_MODEL_QA_REPORT_TEMPLATE.md 2>/dev/null; then
    echo "❌ FAIL: QA report template does not document missing runtime identity resource benchmark rejection."
    FAIL=1
fi

if ! grep -q "positive .*context_tokens.*gpu_offload.*evidence" docs/REAL_MODEL_QA_REPORT_TEMPLATE.md 2>/dev/null ||
   ! grep -q "context_tokens.*positive.*gpu_offload.*evidence" docs/LOCAL_MODEL_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: runtime benchmark docs do not require provider/context/offload evidence for accepted summaries."
    FAIL=1
fi

for qa_guard_label in \
    "missing_benchmark_*" \
    "benchmark_pass_requested_runtime_missing" \
    "benchmark_pass_requested_runtime_mismatch" \
    "benchmark_profile_mismatch" \
    "benchmark_matrix_shape_mismatch" \
    "benchmark_runtime_unavailable" \
    "benchmark_runtime_identity_missing" \
    "benchmark_runtime_artifact_mismatch" \
    "benchmark_draft_artifact_mismatch"; do
    if ! grep -Fq "$qa_guard_label" docs/REAL_MODEL_QA_REPORT_TEMPLATE.md 2>/dev/null; then
        echo "❌ FAIL: QA report template does not document benchmark rejection guard: $qa_guard_label"
        FAIL=1
    fi
done

if ! grep -q "test_qa_report_template_documents_benchmark_rejection_labels" scripts/test-ross-smoke-summary.py 2>/dev/null; then
    echo "❌ FAIL: smoke summary tests do not lock QA template benchmark rejection vocabulary."
    FAIL=1
fi

if ! grep -q "runtime_error_detail" docs/REAL_MODEL_QA_REPORT_TEMPLATE.md 2>/dev/null ||
   ! grep -q "draft_error_detail" docs/LOCAL_MODEL_RUNTIME.md 2>/dev/null ||
   ! grep -q "manifest_primary_unusable_artifact" docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: runtime docs do not document diagnostic identity fields and unusable installed artifacts."
    FAIL=1
fi

if ! grep -q "Product surfaces use the same distinction" docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: iOS runtime docs do not document CoreML adapter vs built-in CoreAI distinction."
    FAIL=1
fi

if ! grep -q "installed MLX/CoreAI lanes with the full varied document/query matrix" docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: iOS runtime docs do not match the morning varied MLX/CoreAI benchmark plan."
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

if ! grep -q "strictDraftSetup: true" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null ||
   ! grep -q "couldNotInitializeDraftContext" ios/Ross/AlphaFoundation/AlphaLlamaCppEngine.swift 2>/dev/null ||
   ! grep -q "MTP validation uses strict draft setup" docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: GGUF/MTP validator can silently downgrade failed draft setup to standard generation."
    FAIL=1
fi

if ! grep -q "draft_validator_rejected" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null; then
    echo "❌ FAIL: GGUF/MTP health does not surface draft validator rejection categories."
    FAIL=1
fi

if ! grep -q "requested_draft_tokens" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null ||
   ! grep -q "max_supported_draft_tokens" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null ||
   ! grep -q "requested_draft_tokens=4,max_supported_draft_tokens=2" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null ||
   ! grep -q "requested_draft_tokens=4,max_supported_draft_tokens=2" docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: GGUF/MTP draft token-policy blocks do not preserve safe requested/max token diagnostics."
    FAIL=1
fi

if ! grep -q "draft_memory_policy_blocked" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null ||
   ! grep -q "testExperimentalGGUFProviderBlocksConstrainedE4BDraftBeforeMemoryRiskyValidation" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null ||
   ! grep -q "draft_memory_policy_blocked" docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: constrained GGUF/MTP draft memory-policy blocks are not documented and tested."
    FAIL=1
fi

if ! grep -q "draft_output_degenerate" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null; then
    echo "❌ FAIL: GGUF/MTP health does not quarantine degenerate draft output."
    FAIL=1
fi

if ! grep -q "draft_output_degenerate" docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: iOS runtime docs do not document degenerate MTP quarantine."
    FAIL=1
fi

if ! grep -q 'activeDraftMetadata = draftValidation.status == "active"' ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null ||
   ! grep -q "accelerationDraftTokens: activeDraftMetadata?.tokens" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null ||
   ! grep -q "draftModelPathLabel: activeDraftMetadata?.label" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null; then
    echo "❌ FAIL: GGUF/MTP health can expose draft token/model metadata without active draft validation."
    FAIL=1
fi

if ! grep -q "draftModelPathLabel: draftModelPathLabel()" ios/Ross/AlphaFoundation/AlphaLocalModelRuntime.swift 2>/dev/null; then
    echo "❌ FAIL: unavailable runtime health drops configured draft model diagnostics."
    FAIL=1
fi

if ! grep -q "testRuntimeIdentityLineIncludesRejectedGGUFDraftCandidateWithoutClaimingAcceleration" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null ||
   ! grep -q "draft_status=validator_rejected" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null ||
   ! grep -q "draft_tokens=nil" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null ||
   ! grep -q "draft_model=nil" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: runtime identity tests do not lock inactive GGUF draft metadata suppression."
    FAIL=1
fi

if ! grep -q 'active draft tokens/model only when `draft_status=active`' docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: iOS runtime docs do not document active-only draft token/model disclosure."
    FAIL=1
fi

if ! grep -q "draft_status=draft_output_degenerate" scripts/test-ross-smoke-summary.py 2>/dev/null; then
    echo "❌ FAIL: shared smoke summary tests do not cover degenerate MTP draft status."
    FAIL=1
fi

if ! grep -q "draft_format_unsupported" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null; then
    echo "❌ FAIL: GGUF/MTP health does not reject non-GGUF draft candidates before validation."
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

if ! grep -q "strictDraftContextFactory" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null ||
   ! grep -q "smokeRequiresDraftAcceleration" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null ||
   ! grep -q "testExperimentalGGUFProviderUsesStrictDraftContextWhenSmokeRequiresDraftAcceleration" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: GGUF/MTP required-draft smoke can still build a non-strict generation context."
    FAIL=1
fi

if ! grep -q "draft_context_failed" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null ||
   ! grep -q "testExperimentalGGUFProviderReportsStrictDraftContextFailureWithoutFallback" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null; then
    echo "❌ FAIL: GGUF/MTP required-draft smoke does not preserve strict draft context failure evidence."
    FAIL=1
fi

if ! grep -q "draft_acceleration_inactive" ios/Ross/AlphaFoundation/AlphaLlamaCppProvider.swift 2>/dev/null ||
   ! grep -q "testExperimentalGGUFProviderFailsStrictDraftProofWhenContextRunsStandard" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null ||
   ! grep -q "draft_acceleration_inactive" docs/IOS_RUNTIME.md 2>/dev/null; then
    echo "❌ FAIL: GGUF/MTP required-draft smoke can still publish a standard-generation context as proof."
    FAIL=1
fi

if ! grep -Fq 'draft_status=\(providerHealth.draftAccelerationStatus' ios/Ross/App/ScreenshotExporter.swift 2>/dev/null; then
    echo "❌ FAIL: app-side MTP failure marker does not report draft status."
    FAIL=1
fi

if ! grep -q "alphaInstalledModelSmokePack" ios/Ross/App/ScreenshotExporter.swift 2>/dev/null ||
   ! grep -q "testInstalledModelSmokePackPrefersRequestedRuntimeOverActiveFallback" ios/Tests/RossTests/AlphaExtractionTests.swift 2>/dev/null ||
   ! grep -q "testInstalledModelSmokePackPrefersRequestedRuntimeOverActiveFallback" scripts/test-ios-runtime-swiftpm.sh 2>/dev/null; then
    echo "❌ FAIL: app smoke can still ignore installed packs matching an explicit runtime override."
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
    scripts/test-ios-device-assistant-download-smoke-guards.sh
    scripts/test-ios-morning-runtime-checkpoint-plan.sh
    scripts/test-ios-runtime-artifact-inventory.sh
    scripts/test-ross-smoke-summary.py
    echo "iOS runtime dependency audit: PASS"
    echo "real local inference: GGUF ready; MLX/CoreAI/MTP require guarded validation"
    echo "benchmark guardrails: READY"
    exit 0
fi

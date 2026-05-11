# Model Downloads & Validation

To operate in full production mode, ROSS-Gemma4 requires secure, offline inference artifacts for three active Gemma 4 capability packs.

## Active Capability Tiers
1. **Quick Associate**: `gemma-4-e2b-q4` (upstream: `google/gemma-4-E2B-it`)
2. **Case Associate**: `gemma-4-e4b-q4` (upstream: `google/gemma-4-E4B-it`)
3. **Senior Drafting Support**: `gemma-4-26b-a4b-q4` (upstream: `google/gemma-4-26B-A4B-it`)

## Desired Format
The desired artifact format for mobile/local inference is `GGUF` at `Q4_K_M` (4-bit quantization).

## Download & Verification Process
Currently, the model registry uses placeholder URLs (`__REPLACE_WITH_VERIFIED_DIRECT_URL__`) and placeholder checksums (`__REPLACE_WITH_VERIFIED_SHA256__`).

To enable real model downloads:
1. Locate or produce the verified GGUF files for the active tiers.
2. Calculate the exact file size (bytes) and SHA-256 hash using `./scripts/model-artifact-checksum.sh <path-to.gguf>`.
3. Update the Swift registry (`ios/Ross/AlphaFoundation/AlphaRossModel.swift`) and the JSON registry (`shared/constants/privateAssistantModelRegistry.json`).
4. Set `verified: true` and `releaseReady: true`.

**Important**: 
- Never fabricate real URLs or checksums.
- `releaseReady` must remain `false` while placeholders are present.
- A real, iOS-compatible local runtime must be integrated alongside these artifacts (see `IOS_RUNTIME.md`).

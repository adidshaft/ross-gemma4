# Release Blockers

The following items must be resolved before this repository can be marked as fully production/release ready. Until then, `verify-model-artifacts.sh --release` will continue to fail to protect the production channel.

1. **Gemma 4 GGUF Model Artifacts:**
   The `downloadUrl` and `finalSha256` for the following capability packs in `shared/constants/privateAssistantModelRegistry.json` and `ios/Ross/AlphaFoundation/AlphaRossModel.swift` are currently using `__REPLACE_WITH_VERIFIED_*__` placeholders:
   - `gemma-4-e2b-q4`
   - `gemma-4-e4b-q4`
   - `gemma-4-26b-a4b-q4`
   
   **Action Required:** Obtain the official Q4 Gemma 4 GGUF files, calculate their true SHA256 checksums using `scripts/model-artifact-checksum.sh`, and update the manifests. Then set `verified: true` and `releaseReady: true`.

2. **Disable Demo Mode:**
   Ensure that the `REAL_LOCAL_GEMMA4` environment variable is set to `true` and `DEMO_MODE` is `false` during the production build so that simulated responses are turned off and true model inference is performed.

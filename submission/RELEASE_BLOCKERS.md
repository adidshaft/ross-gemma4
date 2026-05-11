# Release Blockers

The following items must be resolved before this repository can be marked as fully production/release ready. Until then, `verify-model-artifacts.sh --release` will continue to fail to protect the production channel.

Release readiness is blocked by:
1. Verified Gemma 4 GGUF artifact URLs/checksums.
2. Production validation of a real iOS local inference runtime.

Demo readiness is acceptable if:
1. Demo Mode is visibly disclosed.
2. Deterministic simulated outputs are clearly labeled.
3. The model registry and runtime abstraction are present.
4. The app does not pretend placeholder artifacts are real downloads.

## Actions Required

1. **Obtain Official GGUF Artifacts:** 
   Obtain the official Q4 Gemma 4 GGUF files, calculate their true SHA256 checksums using `scripts/model-artifact-checksum.sh`, and update the manifests. Then set `verified: true` and `releaseReady: true`.

2. **Integrate Real Local Runtime:**
   Replace `Gemma4DemoRuntime` with an actively maintained, verified GGUF local inference package (such as a `llama.cpp` wrapper) that conforms to the `Gemma4Runtime` abstraction.

3. **Disable Demo Mode:**
   Ensure that the `REAL_LOCAL_GEMMA4` environment variable is set to `true` and `DEMO_MODE` is `false` during the production build so that simulated responses are turned off and true model inference is performed.

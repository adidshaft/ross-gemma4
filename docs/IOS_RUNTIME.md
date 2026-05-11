# iOS Gemma 4 Runtime

## 1. Current runtime status
The app currently builds and runs using the `Gemma4DemoRuntime` abstraction. Real local inference is marked as `PENDING` until a verified runtime and GGUF artifacts are integrated.

## 2. Why the dead Swift package was removed
The previous dependency (`swift-gemma-runtime` by `pgorzelany`) was returning a 404 (Not Found) during Xcode package resolution, which completely blocked the iOS build. We have removed it and replaced it with a clean local abstraction.

## 3. Runtime abstraction
The app interacts with local models via the `Gemma4Runtime` protocol. It provides standard methods for loading the model, sending `Gemma4InferenceRequest`, and receiving `Gemma4InferenceResponse`.

## 4. Demo mode behavior
If `DEMO_MODE=true` (or when the real runtime is unavailable), the app falls back to `Gemma4DemoRuntime`. This provides deterministic, simulated outputs for walkthroughs and ensures the app does not pretend that placeholder artifacts are real. It is visually labeled with "Demo Mode — model response simulated for walkthrough" in the UI.

## 5. Real local inference path
To enable real local inference, `REAL_LOCAL_GEMMA4=true` must be set, and a true local inference package must be integrated that conforms to `Gemma4Runtime`. `Gemma4UnavailableRuntime` will safely block execution with an error message until it is set up.

## 6. GGUF/Q4 artifact requirement
The real local inference path requires 4-bit quantized `Q4_K_M` (or similar) GGUF artifacts for the Gemma 4 variants. Placeholders must be replaced with verified URLs and SHA256 checksums before production.

## 7. Candidate runtime options
- **llama.cpp Swift package**: The standard path for running GGUFs on iOS.
- **MLX Swift**: An alternative from Apple, though it may require a non-GGUF format.

## 8. Build instructions
The iOS project currently resolves and builds successfully with the local abstraction.
```bash
swift package resolve --package-path ios
swift build --package-path ios
```

## 9. Known limitations
The real local inference is currently unavailable due to the missing GGUF files and Swift runtime.

## 10. Next verification checklist
- [ ] Research and download valid `Q4_K_M` GGUFs for all 3 tiers.
- [ ] Generate size and SHA256 hashes using `scripts/model-artifact-checksum.sh`.
- [ ] Integrate a verified `llama.cpp` Swift package.
- [ ] Write the `Gemma4LlamaCppRuntime` conforming to the abstraction.
- [ ] Set `releaseReady=true` in the model registries.

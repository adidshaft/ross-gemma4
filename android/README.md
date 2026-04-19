# Ross Android Project

## Build from CLI

```sh
cd /Users/amanpandey/projects/ross/android
./gradlew :app:assembleDebug
```

To run the current JVM tests:

```sh
cd /Users/amanpandey/projects/ross/android
./gradlew :app:testDebugUnitTest
```

## Current alpha foundation

- onboarding flows into Private AI Pack setup and then the case list
- cases, documents, extracted fields, findings, review state, and pack-install metadata persist to encrypted app-private storage
- Android runs a local extraction orchestrator with:
  - PDF page rendering
  - on-device ML Kit OCR
  - language and script heuristics
  - deterministic fallback extraction
  - prompt packing
  - schema validation
  - verification and review queue generation
- source chips deep-link into the document viewer
- public-law search keeps the sanitized-preview flow
- pack delivery uses `/model-catalog`, `/model-download/session`, and `/dev-artifacts/:artifactId`

## Real local inference alpha status

- Android now has a real-provider abstraction behind the installed-pack provider contract.
- Android now has a concrete MediaPipe local inference adapter path for developer-supplied `.task` artifacts.
- Runtime metadata supports `deterministic_dev`, `mediapipe_llm`, `gemma_local_runtime`, `apple_foundation_models`, and `unavailable`.
- Gemma 4 Q4 remains blocked in this alpha.
- If a configured real runtime is unavailable, Android falls back safely to the deterministic development provider.
- Invocation metadata stores hashes and runtime mode, not raw prompts or raw source text.
- Local-only runtime metrics now record counts and timings without storing content.
- All model output still flows through prompt packing, JSON extraction, schema validation, source-ref validation, verifier gating, and advocate review.
- Unsupported fields are not silently accepted.

## Debug configuration

These debug-only values are supported through Gradle properties or environment variables:

- `ROSS_ENABLE_REAL_LOCAL_INFERENCE`
- `ROSS_LOCAL_RUNTIME`
- `ROSS_LOCAL_MODEL_PATH`
- `ROSS_LOCAL_MODEL_CHECKSUM`
- `ROSS_LOCAL_MODEL_KIND`
- `ROSS_BACKEND_BASE_URL`

No model file is committed to the repo, and CI does not require a real model artifact.

Android physical-device proof tooling now exists at:

- `/Users/amanpandey/projects/ross/scripts/dev/android-real-inference-smoke.sh`

The app also includes:

- `Settings > Private AI > Technical details > Run local inference smoke`

## Known caveats

- Android real local inference still requires a physical-device run plus a developer-provided model artifact before it can be claimed as exercised.
- Exact snippet highlights remain best-effort.
- Technical runtime details remain inside Private AI settings and should not move into onboarding.

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
- Runtime metadata supports `deterministic_dev`, `mediapipe_llm`, `gemma_local_runtime`, `apple_foundation_models`, and `unavailable`.
- MediaPipe and Gemma 4 Q4 paths are compile-safe adapter skeletons in this alpha.
- If a configured real runtime is unavailable, Android falls back safely to the deterministic development provider.
- Invocation metadata stores hashes and runtime mode, not raw prompts or raw source text.

## Debug configuration

These debug-only values are supported through Gradle properties or environment variables:

- `ROSS_ENABLE_REAL_LOCAL_INFERENCE`
- `ROSS_LOCAL_RUNTIME`
- `ROSS_LOCAL_MODEL_PATH`
- `ROSS_BACKEND_URL`

No model file is committed to the repo, and CI does not require a real model artifact.

## Known caveats

- Android does not yet execute a real local model in this branch.
- Exact snippet highlights remain best-effort.
- The real-runtime scaffolding is present so MediaPipe or Gemma 4 Q4 integration can be added without changing the extraction contract.

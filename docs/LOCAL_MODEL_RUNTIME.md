# Local Model Runtime

Ross uses a local model runtime contract so extraction quality can improve without weakening the privacy boundary.

OCR is only acquisition. The runtime sits between source-packed local text and advocate review.

## Alpha proof update

- `deterministic_dev` remains the default fallback and is not a real model.
- iPhone setup now first checks for the iOS on-device private assistant and installs a `system_model` pack when available.
- Android model download now preserves backend artifact filenames, including `.task`, so downloaded MediaPipe artifacts can be loaded by the runtime.
- Android Ask Ross now attempts `matter_question_answer` with the installed local runtime when available, then safely falls back to deterministic local review.
- Android real inference proof is expected to come from a physical device plus a compatible `.task` artifact.
- iOS real inference proof requires Aman's device to support the on-device private assistant.
- Model files are not committed and are not bundled.
- No cloud inference is used.
- Raw prompts and raw source text are not persisted in invocation metadata.
- Accepted output remains schema-validated, source-validated, and verifier-gated.
- Unsupported fields are not silently accepted.
- Local-only runtime metrics now record counts and timings without storing content.

Latest observed proof state on 2026-04-23:

- iOS `system_model` pack creation is covered by Swift tests; physical iPhone setup availability still needs a manual tap on Aman's device.
- Android `.task` artifact installation is covered by unit tests; real `mediapipe_llm` execution still needs a compatible physical Android device and artifact.
- Android Ask Ross model-backed answer routing is implemented behind installed-pack provider selection, with local fallback preserved.

## Design goals

- keep case files on-device
- keep deterministic development behavior for CI
- allow a real local inference adapter when a compatible runtime and developer artifact are available
- keep prompt packing and output validation strict
- require source refs for accepted fields
- avoid storing raw prompts or raw source text in invocation metadata
- keep the runtime network-free

## Runtime modes

Ross runtime metadata distinguishes between:

- `deterministic_dev`
- `mediapipe_llm`
- `gemma_local_runtime`
- `apple_foundation_models`
- `unavailable`

Artifact metadata distinguishes between:

- `tiny_dev_artifact`
- `local_model_artifact`
- `system_model`
- `external_debug_model`

The backend still serves only checksum-verified tiny development artifacts for normal CI and development installs. No large model file is committed to the repo.

## Canonical debug configuration

Use these names in docs and manual QA:

- `ROSS_BACKEND_BASE_URL`
- `ROSS_ENABLE_REAL_LOCAL_INFERENCE`
- `ROSS_LOCAL_RUNTIME`
- `ROSS_LOCAL_MODEL_PATH`
- `ROSS_LOCAL_MODEL_CHECKSUM`
- `ROSS_LOCAL_MODEL_KIND`

If these values are absent, Ross keeps deterministic fallback behavior.

## Providers

### Deterministic development provider

This provider remains real and remains the default for CI, tests, and safe fallback behavior.

It:

- never uses the network
- does not pretend to be a real LLM
- returns schema-shaped outputs for deterministic validation
- keeps the end-to-end extraction pipeline testable

### Android MediaPipe path

Android now has a concrete `mediapipe_llm` adapter path behind the installed-pack provider contract.

Current behavior:

- compiles against `com.google.mediapipe:tasks-genai:0.10.27`
- loads only developer-provided `.task` artifacts from debug or app-private storage
- never loads models from bundled app assets
- never imports network clients into the local runtime provider
- reports runtime availability, model-path presence, checksum status, fallback state, and last error category in technical details
- falls back safely to `deterministic_dev` when runtime availability is false

Real Android inference still requires:

- a physical device
- a developer-provided compatible model artifact
- a manual QA run that proves `Last invocation runtime` was `mediapipe_llm`

### iOS on-device assistant path

iOS uses the on-device private assistant supplied by iOS when available.

Current behavior:

- setup creates a `system_model` installed pack with `apple_foundation_models` runtime when the device reports availability
- no Gemma 4 local runtime or Hugging Face model is downloaded inside the iPhone app
- case files remain on device
- if the runtime is unavailable, setup records a plain-language failure and Ross keeps using basic local review
- technical runtime details remain under Advanced diagnostics

## Prompt packing

`PromptPackBuilder`:

- selects page-aware source blocks
- enforces an input character budget
- keeps source refs attached to every included block
- includes document language profile
- includes document classification
- includes the expected JSON schema
- includes refusal rules
- treats uploaded documents as quoted data rather than instructions

For large documents, Ross chunks real extraction and verification passes by page budget and falls back safely when the runtime cannot process a safe prompt pack.

## Output handling

Ross treats model output as untrusted until it passes several gates:

1. raw model output capture
2. JSON candidate extraction
3. schema validation
4. safe repair attempt for small malformed JSON
5. source-ref validation
6. verifier categorization into `verified`, `needs_review`, or `rejected`

Free-form model text is not accepted as extracted legal fields.

Unsupported values must never be accepted silently.

## Invocation metadata

Invocation metadata includes:

- task
- case/document/run ids
- capability tier
- runtime mode
- timestamps
- status
- prompt/input/output hashes
- redacted source refs
- local-only status

Ross does not persist raw prompts by default.

Ross does not persist raw source text in invocation metadata by default.

## Current alpha status

What is real now:

- shared runtime contracts
- deterministic development provider
- Android MediaPipe adapter path
- iOS on-device assistant pack path
- Ask Ross matter-answer routing through the installed local runtime on iOS and Android when available
- prompt packing
- schema-specific output validation
- runtime health and resource estimates
- pack-aware provider selection on Android and iOS

What still requires manual proof:

- Android real device execution with a developer model artifact
- iOS real device setup on Aman's specific iPhone

What remains stubbed:

- Android Gemma 4 Q4 runtime
- iOS MediaPipe and Gemma 4 Q4 runtimes
- shipping production local model artifacts through normal pack delivery

Ross should be described precisely: this alpha contains a real Android adapter path and a real iOS opt-in path, but deterministic fallback remains the default unless a compatible real runtime actually runs.

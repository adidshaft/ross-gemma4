# Local Model Runtime

Ross uses a local model runtime contract so extraction quality can improve without weakening the privacy boundary.

The runtime is not the same thing as OCR. OCR only acquires text. The runtime sits between source-packed text acquisition and advocate review.

## Design goals

- keep case files on-device
- keep deterministic development behavior for CI
- allow a real local inference adapter when a compatible local model artifact is available
- keep prompt packing and output validation strict
- require source refs for accepted fields
- avoid storing raw prompts or raw source text in invocation metadata
- keep the runtime network-free

## Runtime modes

Ross runtime metadata now distinguishes between:

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

The current backend still serves only checksum-verified tiny development artifacts for CI and development installs. No large model files are committed to the repo.

## Core contract

The shared runtime contract now centers on:

- `LocalModelTask`
- `LocalModelInput`
- `LocalModelOutput`
- `LocalModelInvocation`
- `LocalModelProvider`
- `LocalRuntimeHealth`
- `LocalModelResourceEstimate`
- `ModelPromptPolicy`
- `PromptPackBuilder`

`LocalModelProvider` exposes:

- availability checks
- runtime mode
- supported tasks
- context-window and input-budget estimates
- full-run execution
- optional streaming
- cancellation

`LocalRuntimeHealth` reports:

- runtime mode
- whether the runtime is actually available
- whether a model path is present
- whether checksum verification succeeded
- supported tasks
- max input budget
- estimated context window
- last error category
- user-facing status text

## Providers

### Deterministic development provider

This provider is real and remains the default for CI, tests, and safe fallback behavior.

It:

- never uses the network
- does not pretend to be a real LLM
- returns schema-shaped outputs for deterministic validation
- keeps the end-to-end extraction pipeline testable

### Real local provider layer

Ross now has an adapter-first real-provider layer behind the existing provider contract.

Current alpha status:

- Android has compile-safe MediaPipe and Gemma 4 Q4 adapter skeletons plus runtime-health reporting and deterministic fallback.
- iOS has a real Apple Foundation Models adapter path behind availability checks and explicit developer opt-in.
- Real-runtime probing is disabled by default so CI and simulator runs remain deterministic.

To exercise a real runtime in this alpha, a developer must explicitly opt in with local debug configuration such as:

- `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`
- `ROSS_LOCAL_RUNTIME=apple_foundation_models`
- `ROSS_LOCAL_MODEL_PATH=/absolute/path/to/local/model` where the runtime needs an external file

If no compatible local runtime is available, Ross falls back safely to the deterministic provider and surfaces runtime unavailability only in technical or debug details.

## Prompt packing

Real local inference is only useful if the prompt pack is tightly controlled.

`PromptPackBuilder` now:

- selects page-aware source blocks
- enforces an input character budget
- keeps source refs attached to every included block
- includes document language profile
- includes document classification
- includes the expected JSON schema
- includes refusal rules
- treats uploaded documents as quoted data rather than instructions

Prompt injection inside a document is therefore contained inside source data instead of being treated as executable instruction text.

## Output handling

Ross now treats model output as untrusted until it passes several gates:

1. raw model output capture
2. JSON candidate extraction
3. schema validation
4. safe repair attempt for small malformed JSON
5. source-ref validation
6. verifier categorization into `verified`, `needs_review`, or `rejected`

Unsupported values must never be accepted silently.

## Invocation metadata

Ross records local invocation metadata so extraction runs can be audited without leaking case content.

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

## Alpha status

What is real now:

- shared runtime contracts
- deterministic development provider
- runtime health and resource estimates
- prompt packing
- schema-specific output validation
- pack-aware provider selection on Android and iOS
- iOS Apple Foundation Models adapter path behind explicit developer opt-in

What remains stubbed:

- Android real inference execution
- MediaPipe integration on either platform
- Gemma 4 Q4 runtime integration on either platform
- shipping production local model artifacts

Ross should be described precisely: this alpha contains a real adapter layer and a real iOS system-model path, but deterministic fallback remains the default unless a developer explicitly enables local real inference.

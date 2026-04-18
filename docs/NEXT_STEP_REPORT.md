# Ross Local Model Extraction Runtime Alpha Report

## Branch

- Working branch: `alpha-local-model-extraction`
- Base branch preserved: `alpha-law-grade-extraction`

## Scope completed

This phase connects the existing law-grade extraction architecture to a real local runtime abstraction, pack-aware multi-pass planning, deterministic development execution, mobile orchestration, and source-grounding validation.

The product line remains the same:

- OCR is acquisition only.
- Extraction quality depends on the installed `Private AI Pack`.
- Unsupported fields are not silently accepted.
- Low-confidence or weakly supported values are pushed into advocate review.
- No cloud model calls or cloud OCR were added.

## What is implemented now

### Shared and Rust core

- Added platform-neutral local runtime contracts for:
  - `LocalModelTask`
  - `LocalModelInput`
  - `LocalModelOutput`
  - `LocalModelInvocation`
  - `ExtractionPipelinePlan`
- Added Rust runtime/orchestration modules for:
  - `local_model`
  - `model_invocation`
  - `extraction_plan`
  - `output_validation`
- Added a deterministic local provider for tests and CI.
- Added a platform runtime stub that fails safely when a true on-device runtime is unavailable.
- Added prompt and validation rules that treat documents as data, reject instruction-following from document text, and require source support.
- Added invocation hashing so prompt and input bodies are not persisted in invocation metadata.

### Extraction pipeline behavior

- Basic mode remains deterministic and review-heavy.
- Quick Start can run the local runtime chain for shorter documents and otherwise fails safely into deterministic review-oriented behavior.
- Case Associate now plans and runs a deeper extraction path:
  - cleanup
  - language correction
  - document classification
  - legal field extraction
  - verifier/refiner pass
  - case memory synthesis
- Senior Drafting Support adds deeper-pass placeholders and stronger plan steps without pretending a real bundled local LLM is already present.
- Every accepted extracted field must keep at least one source reference.
- Unsupported or weakly grounded values are marked `needs review`.
- User-corrected fields are preserved on reruns.

### Android

- Added Android runtime and validation files:
  - `AlphaLocalModelRuntime.kt`
  - `AlphaExtractionPipelinePlan.kt`
  - `AlphaModelInvocationStore.kt`
  - `AlphaModelOutputValidator.kt`
- Updated `AlphaExtraction.kt` to execute pack-aware multi-pass extraction.
- Persisted pipeline plans and model invocation metadata locally.
- Redacted prompt/source bodies from invocation records.
- Updated review/export flows so verified values and review-needed values stay distinct.
- Added UI refinements for:
  - extraction quality
  - needs-review counts
  - verified vs needs-review field labels
  - `Run better extraction`

### iOS

- Added iOS runtime and validation files:
  - `AlphaLocalModelRuntime.swift`
  - `AlphaExtractionPipelinePlan.swift`
  - `AlphaModelInvocationStore.swift`
  - `AlphaModelOutputValidator.swift`
- Updated `AlphaStore` orchestration to execute the same conceptual pack-aware multi-pass flow as Android.
- Persisted local invocation metadata without raw prompt/source bodies.
- Preserved user corrections when rerunning extraction.
- Updated the iOS review shell to show quality, review counts, verified status, and upgrade messaging.

### Backend and model-pack linkage

- Extended catalog/download metadata with:
  - `artifactKind`
  - `runtimeMode`
  - `developmentOnly`
- Dev artifacts are explicitly marked:
  - `artifactKind: tiny_dev_artifact`
  - `runtimeMode: deterministic_dev`
  - `developmentOnly: true`
- Android and iOS now use installed-pack metadata to choose extraction mode and pipeline shape.
- No real model binaries were added to the repo or app bundles.

### Evaluation harness

- Added synthetic extraction fixtures in Rust for:
  - English civil order
  - Hindi/English mixed order
  - noisy OCR affidavit text
  - pleading with prayers
  - evidence and exhibit list
  - prompt-injection text
  - conflicting dates
  - hallucination trap
- Added runtime and source-grounding tests that assert:
  - every accepted field has source refs
  - unsupported accepted count stays zero
  - prompt injection does not change extraction behavior
  - mixed-language signals are preserved
  - invocation metadata excludes raw prompt/source text

## What is real versus stubbed

### Real in this branch

- The local runtime contract is real.
- The deterministic development provider is real.
- Pack-aware pipeline planning is real.
- Mobile extraction orchestration now follows the runtime contract.
- Source validation is real.
- Review gating for unsupported fields is real.
- Model-pack download/install metadata now changes extraction mode and quality messaging.

### Still stubbed

- A true bundled on-device inference engine is not yet integrated.
- `InstalledPackLocalModelProvider` remains a safe platform stub for future native inference runtimes.
- Senior Drafting Support deeper passes are planned and scaffolded, but they still rely on deterministic/runtime-stub behavior until a real local engine is integrated.
- The evaluation harness is an alpha safety harness, not a claim of production-model accuracy.

## Validation run in this phase

### Baseline before edits

- Rust: `cargo test`
- Backend:
  - `npm test`
  - `npm run typecheck`
  - `npm run build`
- Privacy guards:
  - `./scripts/dev/verify-boundaries.sh`
  - `./scripts/ci/check-no-cloud-llm.sh`
  - `./scripts/ci/check-no-analytics.sh`
  - `./scripts/ci/check-no-large-model-assets.sh`
  - `./scripts/ci/check-onboarding-copy-boundary.sh`
- Android:
  - `./gradlew :app:testDebugUnitTest :app:assembleDebug`
- iOS:
  - `swift build --scratch-path tmp/swiftpm`
  - `xcodebuild -project Ross.xcodeproj -scheme Ross -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/DerivedData build`
  - `swift test --scratch-path tmp/swiftpm`
  - `swift run --scratch-path tmp/swiftpm Ross --generate-screenshots`

### Final after changes

- Rust: `cargo test`
- Backend:
  - `npm test`
  - `npm run typecheck`
  - `npm run build`
- Privacy guards:
  - `./scripts/dev/verify-boundaries.sh`
  - `./scripts/ci/check-no-cloud-llm.sh`
  - `./scripts/ci/check-no-analytics.sh`
  - `./scripts/ci/check-no-large-model-assets.sh`
  - `./scripts/ci/check-onboarding-copy-boundary.sh`
- Android:
  - `./gradlew :app:testDebugUnitTest :app:assembleDebug`
- iOS:
  - `swift build --scratch-path tmp/swiftpm`
  - `xcodebuild -project Ross.xcodeproj -scheme Ross -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/DerivedData build`
  - `swift test --scratch-path tmp/swiftpm`
  - `swift run --scratch-path tmp/swiftpm Ross --generate-screenshots`
- Backend smoke:
  - `GET /model-catalog`
  - `POST /model-download/session`
  - `GET /dev-artifacts/:artifactId` with `Range`
  - `POST /public-law/search`

## Privacy notes

- No raw prompts are persisted by default.
- No raw model input text is stored in invocation metadata.
- Source refs inside invocation metadata are redacted to avoid leaking snippets.
- No cloud model calls were added.
- No cloud OCR was added.
- No analytics or telemetry SDKs were added.
- Case/document repositories remain separate from model delivery and public-law search boundaries.

## Repository hygiene

- `SCRIPT.md` was inspected but left untouched.
- `artifacts/` was inspected but left untouched.
- Neither was modified or committed in this phase.

## Exact next recommended step

Integrate a real local on-device inference adapter behind the existing `InstalledPackLocalModelProvider` contract for Case Associate first, then reuse that same adapter contract on Android and iOS so the existing cleanup, extraction, verifier, and case-memory passes run on true local inference instead of deterministic development behavior.

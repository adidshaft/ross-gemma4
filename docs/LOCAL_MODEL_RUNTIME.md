# Local Model Runtime

Ross uses a local model runtime contract so extraction quality can improve without changing the privacy boundary.

The point of this runtime is not to make OCR look smarter. OCR only acquires text. The runtime sits above acquisition and below advocate review.

## Design goals

- keep case files on-device
- keep runtime decisions local
- support pack-aware extraction quality
- allow deterministic development behavior in tests and CI
- make unsupported fields fail safely into review
- avoid storing raw prompts or raw source text in invocation metadata

## Core contract

The shared/runtime contract centers on these concepts:

- `LocalModelTask`
- `LocalModelInput`
- `LocalModelOutput`
- `LocalModelInvocation`
- `LocalModelProvider`

Supported task families include:

- `ocr_cleanup`
- `language_correction`
- `document_classification`
- `legal_field_extraction`
- `legal_field_verification`
- `case_memory_synthesis`
- `chronology_generation`
- `order_summary`
- `issue_extraction`

## Providers

### Deterministic development provider

This provider is real and active in alpha tests.

It:

- never uses the network
- does not pretend to be a real LLM
- returns schema-shaped outputs from source-backed text blocks
- lets CI and mobile shells validate runtime wiring end to end

### Installed pack provider

This provider is currently a safe platform stub.

It exists so Ross can cleanly support:

- verified installed pack paths
- future native runtime linkage
- checksum-verified local model assets
- strict local-only invocation behavior

If no true local runtime is installed, the provider fails safely instead of fabricating confidence.

## Invocation records

Ross records local invocation metadata so extraction runs can be reasoned about without storing case content in logs.

Invocation metadata includes:

- task
- case/document/run ids
- capability tier
- started/completed timestamps
- status
- prompt/input/output hashes
- redacted source references
- `localOnly: true`

Ross does not persist raw prompts by default. Ross does not persist raw source text in invocation metadata.

## Pipeline planning

The installed `Private AI Pack` determines the extraction plan:

- Basic: deterministic acquisition and review-first extraction
- Quick Start: lighter model-assisted cleanup/extraction for short documents
- Case Associate: deeper extraction plus verifier/refiner behavior
- Senior Drafting Support: deeper pass scaffolding and long-document synthesis planning

The runtime contract allows those modes to share the same structure across Rust, Android, and iOS.

## Verification rules

The runtime is only useful if it refuses false certainty.

Ross therefore applies these rules:

- every accepted field must keep at least one source ref
- unsupported values become `needs review`
- invalid schema output fails safely
- prompt injection inside documents is ignored
- user-corrected fields are not overwritten silently

## Alpha status

What is real now:

- shared runtime contract
- deterministic dev provider
- pack-aware multi-pass planning
- mobile orchestration through the runtime contract
- source-grounding validation

What is not yet real:

- bundled production local model weights
- a shipping native on-device inference engine
- production-quality bilingual legal extraction claims

Ross should be described accurately: this branch proves the local-runtime architecture and privacy-preserving pipeline shape, not a finished production local LLM integration.

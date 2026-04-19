# Model Registry

Ross shows advocate-friendly capability packs in product UI. Technical model names stay out of onboarding because the user-facing promise is extraction quality, not model branding.

## User-facing packs

### Basic

- available with no Private AI Pack installed
- uses local acquisition, OCR where available, heuristics, and deterministic extraction

### Quick Start

- extraction quality: `Standard`
- best for short documents and lighter cleanup

### Case Associate

- extraction quality: `Advanced`
- best for stronger field extraction, mixed-language handling, chronology support, and review queues

### Senior Drafting Support

- extraction quality: `Advanced`
- best for deeper synthesis and longer bundle workflows

## Runtime registry notes

Ross now tracks runtime metadata separately from user-facing pack labels.

Supported runtime-mode values:

- `deterministic_dev`
- `mediapipe_llm`
- `gemma_local_runtime`
- `apple_foundation_models`
- `unavailable`

Supported artifact-kind values:

- `tiny_dev_artifact`
- `local_model_artifact`
- `system_model`
- `external_debug_model`

The current alpha catalog still serves only `tiny_dev_artifact` packs with `deterministic_dev` runtime metadata for normal development installs.

## Registry principles

- do not show technical model names in onboarding
- present packs as advocate workflows
- keep installation separate from the base app
- keep the app usable without a pack
- prefer real local inference when a compatible local runtime is available
- fall back deterministically when it is not
- never imply that every pack already includes a running local model

## Alpha delivery status

- backend `/model-catalog` returns signed dev-artifact metadata
- backend `/model-download/session` returns signed segmented dev-artifact metadata
- Android and iOS both use this delivery path without sending case data
- real local model artifacts remain developer-provided and outside the repo in this alpha
- the Android app can now load a developer-provided MediaPipe `.task` artifact from debug or app-private storage without bundling the model into the app

# Model Artifact Strategy

Ross needs a model artifact strategy that proves real local inference without weakening privacy or committing binaries.

## Current proof status

Latest observed state on 2026-04-24:

- Ross's production-intended assistant metadata is Gemma 4 E2B Q4 Gemma 4 Q4 through `gemma_local_runtime`.
- Backend default mode still serves tiny deterministic artifacts for CI and local tests.
- Backend `production_metadata` mode advertises Gemma 4 E2B Q4 tier metadata without serving large model files.
- Matter Search is a separate embedding model requirement, not part of the generative model file.
- Real Gemma 4 Q4 inference still needs a linked mobile runtime and physical-device proof.

## Non-negotiable rules

- no large model files in git
- no large model files in app bundles
- no case data in model delivery requests
- no raw local file paths in backend responses or logs
- no cloud inference fallback

## A. Debug-path model

Recommended first proof path.

- the developer places a compatible local model artifact on the device
- the app reads `ROSS_LOCAL_MODEL_PATH`
- the source artifact stays outside the repo and outside `android/app/src/main/assets` or `res/raw`
- `ROSS_LOCAL_MODEL_CHECKSUM` is optional but recommended
- `ROSS_LOCAL_MODEL_PUSH_SOURCE` can point to an absolute source path outside the repo when using the Android smoke helper
- no backend delivery is required
- fastest way to prove the Android real provider on a physical device

When to use:

- first physical-device QA
- adapter bring-up
- runtime health verification
- smoke runs from Technical details

## B. Backend-advertised external debug model

- backend can optionally advertise `external_debug_model` metadata in `/model-catalog`
- mobile can install the artifact through `/model-download/session` when backend serving is explicitly enabled
- no download URL is exposed from the catalog
- useful for testing metadata selection and runtime labeling without serving a binary

Required env:

- `ROSS_ENABLE_EXTERNAL_MODEL_METADATA=1`
- `ROSS_EXTERNAL_MODEL_RUNTIME=mediapipe_llm`
- `ROSS_EXTERNAL_MODEL_KIND=external_debug_model`
- `ROSS_EXTERNAL_MODEL_SHA256`
- `ROSS_EXTERNAL_MODEL_SIZE_BYTES`
- optional `ROSS_EXTERNAL_MODEL_DISPLAY_NAME`
- optional `ROSS_EXTERNAL_MODEL_MIN_APP_VERSION`

## C. Backend-served development model artifact

Allowed only in explicit dev mode.

- disabled by default
- requires `ROSS_ENABLE_EXTERNAL_MODEL_SERVING=1`
- requires `ROSS_EXTERNAL_MODEL_FILE_PATH`
- file path must be absolute and outside the repo
- backend streams bytes with Range support
- backend never logs the full path
- backend never stores case data

When to use:

- developer QA where a local backend is part of the setup
- artifact integrity checks
- download/session plumbing tests

## D. Production model delivery

Future work only.

- signed manifests
- signed URLs
- checksums
- app-private storage after download
- explicit artifact lifecycle management
- separate embedding model lifecycle for Matter Search

Not for this alpha:

- app-bundled models
- committed models
- hidden remote-provider fallback

## Alpha recommendation

1. Keep `ROSS_MODEL_CATALOG_MODE=dev` for CI and normal local tests.
2. Use `ROSS_MODEL_CATALOG_MODE=production_metadata` only to verify Gemma 4 E2B Q4 metadata and UI mapping.
3. Implement the separate Matter Search embedding lifecycle before claiming source-backed RAG is production-ready.
4. Prove Android and iOS Gemma 4 Q4 inference on hardware before claiming real Gemma 4 E2B Q4 execution.
5. Use backend dev serving with one compatible external file outside the repo only for manual runtime bring-up.

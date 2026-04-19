# Model Artifact Strategy

Ross needs a model artifact strategy that proves real local inference without weakening privacy or committing binaries.

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
- `ROSS_LOCAL_MODEL_CHECKSUM` is optional but recommended
- no backend delivery is required
- fastest way to prove the Android real provider on a physical device

When to use:

- first physical-device QA
- adapter bring-up
- runtime health verification
- smoke runs from Technical details

## B. Backend-advertised external debug model

- backend can optionally advertise `external_debug_model` metadata in `/model-catalog`
- mobile still uses a developer-provided local model path
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

Not for this alpha:

- app-bundled models
- committed models
- hidden remote-provider fallback

## Alpha recommendation

1. Prefer the debug-path model first.
2. Use backend external metadata only when you need to validate metadata plumbing.
3. Use backend dev serving only as a clearly disabled-by-default developer feature.
4. Do not add broader delivery architecture until a real physical-device proof run exists.

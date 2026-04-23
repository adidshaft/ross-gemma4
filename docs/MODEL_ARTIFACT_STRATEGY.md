# Model Artifact Strategy

Ross needs a model artifact strategy that proves real local inference without weakening privacy or committing binaries.

## Current proof status

Latest observed state on 2026-04-23:

- iPhone setup uses the iOS on-device private assistant when available; it does not download a model from Gemma 4 local runtime or Hugging Face inside the app.
- Android real model downloads are wired through the existing Ross backend model session flow.
- Android now preserves the backend artifact filename, so a served `.task` file remains `.task` in app-private storage for MediaPipe loading.
- Android real local inference still needs one compatible `.task` artifact outside the repo and a physical Android proof run.

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

Not for this alpha:

- app-bundled models
- committed models
- hidden remote-provider fallback

## Alpha recommendation

1. On iPhone, use the system on-device assistant path first and record whether Aman's device reports it available.
2. On Android, use backend dev serving with one compatible `.task` file outside the repo to prove download plus MediaPipe loading.
3. Keep backend external serving disabled by default.
4. Do not add broader delivery architecture until a real physical-device proof run exists.
5. Record `Not run` immediately if either the physical Android device or the external `.task` artifact is missing.

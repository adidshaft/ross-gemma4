# Manual Local Inference QA

This runbook is for manual alpha QA of pack install, runtime availability, document import, extraction, review, export, and privacy boundaries.

The deterministic development provider remains the default. Real local inference should only be claimed if a compatible developer-provided runtime actually runs.

## Backend

Start the backend from the repo root:

```sh
cd /Users/amanpandey/projects/ross/backend
npm install
npm run dev
```

Confirm the development endpoints:

```sh
curl http://127.0.0.1:8080/model-catalog?platform=ios
curl -X POST http://127.0.0.1:8080/model-download/session -H 'content-type: application/json' -d '{"accountToken":"dev-account","packId":"case-associate-pack","platform":"ios","deviceIdHash":"dev-device","appVersion":"0.0.0-dev"}'
curl -H 'Range: bytes=0-1023' http://127.0.0.1:8080/dev-artifacts/<artifactId>
```

Expected result:

- model catalog returns signed pack metadata
- download session returns signed segment metadata
- ranged artifact delivery succeeds
- no case data appears in requests

## Android QA

1. Build and install the Android app.
2. Point the app at the local backend if needed.
3. Install `Quick Start` or `Case Associate`.
4. Verify that extraction quality changes in Private AI settings.
5. Import a sample document.
6. Wait for extraction to finish.
7. Open `Review extracted details`.
8. Confirm fields are shown as `Verified from source` or `Needs advocate review`.
9. Export a report.
10. Confirm the Privacy Ledger shows only local activity and sanitized public-law activity.

Optional Android real-runtime debug path:

- Set `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`
- Set `ROSS_LOCAL_RUNTIME=mediapipe_llm` or `ROSS_LOCAL_RUNTIME=gemma_local_runtime`
- Set `ROSS_LOCAL_MODEL_PATH=/absolute/path/to/local/model`

Expected current alpha result:

- Android reports runtime metadata correctly
- Android falls back safely to deterministic execution because the real adapter remains scaffolded only

## iOS QA

1. Open the shared `Ross` scheme in Xcode.
2. Set `ROSS_BACKEND_URL=http://127.0.0.1:8080` if needed.
3. Run the app on a simulator.
4. Install `Quick Start` or `Case Associate`.
5. Import a sample document.
6. Wait for extraction to finish.
7. Open `Review extracted details`.
8. Confirm fields are shown as `Verified from source` or `Needs advocate review`.
9. Export a report.
10. Confirm the Privacy Ledger shows only local activity and sanitized public-law activity.

Optional iOS real-runtime debug path:

- `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`
- `ROSS_LOCAL_RUNTIME=apple_foundation_models`
- `ROSS_LOCAL_MODEL_PATH=/absolute/path/to/local/model` when an external adapter file is required

Expected current alpha result:

- on compatible Apple platforms, the Apple Foundation Models path may become available
- if unavailable, the app reports local runtime unavailability only in technical details and falls back deterministically

## What to verify in extraction

Use a short sample document first.

Confirm that Ross can extract or review:

- document type
- court
- case number
- parties
- dates
- next date
- sections
- order directions

Every accepted field should keep a visible source reference.

Unsupported values should not appear as silently accepted fields.

## Public-law suggestion QA

1. Use verified or user-corrected extracted fields.
2. Open the public-law suggestion preview.
3. Confirm the preview keeps legal concepts but strips private values such as:
   - party names
   - case numbers
   - phone numbers
   - email addresses
   - addresses
4. Confirm the user must approve the preview before the backend request is sent.

## Privacy checks

During QA, confirm that the following do not appear in backend logs, model metadata, or public-law payloads:

- raw prompts
- raw OCR text
- filenames
- party names
- client facts
- fake privacy regression strings

During local QA, these values may appear only in:

- encrypted local storage
- local document viewer
- extraction review UI
- source-backed local outputs

## How to record a real-runtime result

Only record a real local inference success if all of the following are true:

- a developer-provided local runtime was explicitly enabled
- the reported runtime mode matched the intended adapter
- inference actually executed locally
- output passed schema validation
- no network model call occurred

Record:

- platform
- runtime mode
- whether a local model path was used
- whether schema validation passed
- whether deterministic fallback was used instead

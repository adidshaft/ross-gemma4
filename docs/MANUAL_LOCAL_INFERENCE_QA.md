# Manual Local Inference QA

This runbook tracks what can and cannot be claimed for local inference in the current alpha.

Deterministic development runtime remains the default. It is not a real LLM. Do not claim a real local inference success unless a compatible runtime actually ran and the app recorded the real runtime mode in technical details.

## Canonical debug configuration

Use these names across Android and iOS:

- `ROSS_BACKEND_BASE_URL`
- `ROSS_ENABLE_REAL_LOCAL_INFERENCE`
- `ROSS_LOCAL_RUNTIME`
- `ROSS_LOCAL_MODEL_PATH`
- `ROSS_LOCAL_MODEL_CHECKSUM`
- `ROSS_LOCAL_MODEL_KIND`

Legacy `ROSS_BACKEND_URL` is tolerated only as a compatibility alias. New docs and new manual QA should use `ROSS_BACKEND_BASE_URL`.

## Backend

Start the backend if you want to exercise catalog, download-session, or public-law flows:

```sh
cd /Users/amanpandey/projects/ross/backend
npm install
npm run dev
```

Optional smoke checks:

```sh
curl http://127.0.0.1:8080/model-catalog?platform=ios
curl -X POST http://127.0.0.1:8080/model-download/session -H 'content-type: application/json' -d '{"accountToken":"dev-account","packId":"case-associate-pack","platform":"ios","deviceIdHash":"dev-device","appVersion":"0.0.0-dev"}'
curl -X POST http://127.0.0.1:8080/public-law/search -H 'content-type: application/json' -d '{"query":"Section 138 cheque dishonour notice limitation India","jurisdiction":"IN-ALL","language":"en","confirmedPublicPreview":true}'
```

Expected:

- only metadata or sanitized public-law previews cross the boundary
- no case data appears in backend requests

## Android

For the concrete Android MediaPipe path, use:

- [ANDROID_REAL_INFERENCE_QA.md](/Users/amanpandey/projects/ross/docs/ANDROID_REAL_INFERENCE_QA.md)

Current honest status:

- Android now has a concrete `mediapipe_llm` adapter path
- Android still needs a physical-device run plus developer model artifact before any real-runtime claim can be made
- if the runtime is unavailable, Ross must stay on deterministic fallback

## iOS

Use a compatible Apple Intelligence device and explicit opt-in:

- `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`
- `ROSS_LOCAL_RUNTIME=apple_foundation_models`
- `ROSS_LOCAL_MODEL_PATH=/absolute/path/to/local/model` only if an external adapter file is required
- `ROSS_BACKEND_BASE_URL=http://127.0.0.1:8080`

Manual steps:

1. Open `/Users/amanpandey/projects/ross/ios/Ross.xcodeproj` in Xcode.
2. Add the canonical environment variables to the scheme.
3. Run on a compatible device.
4. Open `Settings > Private AI > Technical details`.
5. Confirm:
   - `Runtime mode` is `apple_foundation_models`
   - `Local runtime` is `available`
   - `Fallback active` is `no`
6. Import a short legal fixture.
7. Run `Case Associate` extraction.
8. Confirm `Last invocation runtime` is `apple_foundation_models`.
9. Confirm outputs still pass schema validation, source refs remain visible, and uncertain values stay in review.
10. Confirm no model-network event appeared.

If the device or OS is incompatible:

- technical details must say the runtime is unavailable
- deterministic fallback must remain active
- no real-runtime claim should be recorded

## Shared extraction checks

Use a short sample document first and confirm:

- every accepted field keeps a visible source reference
- unsupported values are not silently accepted
- raw prompts are not shown in logs or metadata
- raw OCR text is not shown in logs or metadata
- deterministic fallback is obvious when active

## Public-law suggestion checks

Use only verified or user-corrected legal concepts and confirm:

- party names are removed
- case numbers are removed
- phone numbers are removed
- email addresses are removed
- private narrative phrases are removed
- the preview remains mandatory before any backend request

## Fake privacy regression strings

These values may appear only in encrypted local storage, local document viewing, local review UI, and local source-backed outputs:

- `Raghav Fakepriv`
- `9876501234`
- `fakepriv@example.com`
- `FAKE/123/2026`
- `blue suitcase near temple`

They must not appear in:

- backend logs
- model invocation metadata as raw text
- public-law payloads
- runtime health details
- diagnostics

## How to record the result honestly

Record:

- platform
- runtime mode
- whether a developer model artifact was used
- whether schema validation passed
- whether deterministic fallback stayed active

Do not record a real local inference success unless:

- the real runtime was explicitly enabled
- the runtime reported itself as available
- `Last invocation runtime` matched the real runtime
- no network model request occurred

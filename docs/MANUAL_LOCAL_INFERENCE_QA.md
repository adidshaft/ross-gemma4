# Manual Local Inference QA

This runbook exists to keep the repo honest about what was actually proven.

- `deterministic_dev` is not a real model.
- Real local inference requires a compatible runtime and a developer-provided model artifact.
- Do not claim a real local inference run unless Technical details recorded the real runtime mode.

## Canonical environment names

- `ROSS_BACKEND_BASE_URL`
- `ROSS_ENABLE_REAL_LOCAL_INFERENCE`
- `ROSS_LOCAL_RUNTIME`
- `ROSS_LOCAL_MODEL_PATH`
- `ROSS_LOCAL_MODEL_CHECKSUM`
- `ROSS_LOCAL_MODEL_KIND`

## Shared truth checks

For any platform:

- model files are not committed to git
- model files are not bundled in app assets or app bundles
- no cloud inference is used
- raw prompts are not persisted by default
- raw source text is not persisted in invocation metadata
- accepted output must be schema-valid, source-backed, and verifier-gated
- unsupported fields must not be silently accepted

## Backend QA

Baseline:

```sh
cd /Users/amanpandey/projects/ross/backend
npm test
npm run typecheck
npm run build
```

Optional alpha metadata QA:

- enable `ROSS_ENABLE_EXTERNAL_MODEL_METADATA=1`
- verify `/model-catalog` includes the `external_debug_model` entry
- confirm no local path is exposed

Optional alpha serving QA:

- enable `ROSS_ENABLE_EXTERNAL_MODEL_SERVING=1`
- set `ROSS_EXTERNAL_MODEL_FILE_PATH` to an absolute path outside the repo
- verify `/model-download/session` works only in this explicit dev mode
- verify ranged artifact delivery works

## Android QA

Use the Android-specific runbook:

- [ANDROID_REAL_INFERENCE_QA.md](/Users/amanpandey/projects/ross/docs/ANDROID_REAL_INFERENCE_QA.md)

Current status:

- Android is the preferred first proof path.
- A physical device is likely required for meaningful MediaPipe QA.
- The app now includes `Settings > Private AI > Technical details > Run local inference smoke`.

## iOS QA

Requirements:

- `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`
- `ROSS_LOCAL_RUNTIME=apple_foundation_models`
- compatible Apple device/runtime

Manual steps:

1. Open `/Users/amanpandey/projects/ross/ios/Ross.xcodeproj`.
2. Add the environment variables to the scheme.
3. Run on a compatible device.
4. Open `Settings > Private AI > Technical details`.
5. Confirm:
   - `Runtime mode` is `apple_foundation_models`
   - `Real runtime enabled` is `yes`
   - `Local runtime` is `available`
   - `Fallback active` is `no`
6. Run `Run local inference smoke`.
7. Confirm the smoke report shows:
   - runtime used
   - schema valid
   - fields found
   - fields verified
   - unsupported accepted `0`

If the runtime is unavailable:

- record the sanitized reason
- keep deterministic fallback active
- mark the QA result as not run

## Public-law sanitation checks

Confirm the preview still removes:

- party names
- case numbers
- phone numbers
- email addresses
- addresses and private locations
- exact private dates
- fake secrets
- long factual narrative

Confirm the preview keeps only legal concepts such as:

- statutory sections
- generic procedural issues
- court-neutral legal concepts

## Fake-secret regression strings

These values must not appear in backend requests, logs, runtime metrics, runtime health details, or crash messages:

- `Raghav Fakepriv`
- `9876501234`
- `fakepriv@example.com`
- `FAKE/123/2026`
- `blue suitcase near temple`

## Honest outcome recording

Record either:

- `Real inference ran`
- or `Not run`

If `Not run`, list the exact blocker, such as:

- no compatible physical device
- no compatible runtime
- no developer-provided model artifact
- checksum mismatch

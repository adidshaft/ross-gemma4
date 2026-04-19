# Android Real Inference QA

This runbook is for proving the Android `mediapipe_llm` path on a physical device.

Do not claim a real local inference success unless the app actually records `mediapipe_llm` as the last invocation runtime.

## Prerequisites

- A physical Android device, preferably high-end
- A developer-provided MediaPipe `.task` model artifact
- A debug build of Ross
- Optional local backend if you also want to exercise pack metadata or public-law search
- No model file committed to the repo

## Canonical debug configuration

Use these names when building the debug app:

- `ROSS_BACKEND_BASE_URL`
- `ROSS_ENABLE_REAL_LOCAL_INFERENCE`
- `ROSS_LOCAL_RUNTIME`
- `ROSS_LOCAL_MODEL_PATH`
- `ROSS_LOCAL_MODEL_CHECKSUM`
- `ROSS_LOCAL_MODEL_KIND`

Recommended Android real-runtime values:

- `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`
- `ROSS_LOCAL_RUNTIME=mediapipe_llm`
- `ROSS_LOCAL_MODEL_PATH=debug-models/case-associate.task`
- `ROSS_LOCAL_MODEL_KIND=mediapipe_task`
- `ROSS_LOCAL_MODEL_CHECKSUM=<optional sha256>`

## 1. Build the debug APK

```sh
cd /Users/amanpandey/projects/ross/android
export ROSS_BACKEND_BASE_URL=http://10.0.2.2:8080
export ROSS_ENABLE_REAL_LOCAL_INFERENCE=1
export ROSS_LOCAL_RUNTIME=mediapipe_llm
export ROSS_LOCAL_MODEL_PATH=debug-models/case-associate.task
export ROSS_LOCAL_MODEL_KIND=mediapipe_task
./gradlew :app:assembleDebug
```

If you want checksum enforcement, compute it first and export it:

```sh
shasum -a 256 /absolute/path/to/case-associate.task
export ROSS_LOCAL_MODEL_CHECKSUM=<paste_sha256_here>
```

## 2. Install the app

```sh
adb install -r /Users/amanpandey/projects/ross/android/app/build/outputs/apk/debug/app-debug.apk
```

## 3. Copy the model into app-private storage

Push the model to a temporary device-visible location:

```sh
adb push /absolute/path/to/case-associate.task /data/local/tmp/ross-case-associate.task
```

Copy it into Ross app-private storage:

```sh
adb shell run-as com.ross.android mkdir -p files/ross-alpha/debug-models
adb shell "run-as com.ross.android sh -c 'cat /data/local/tmp/ross-case-associate.task > files/ross-alpha/debug-models/case-associate.task'"
```

The relative path `debug-models/case-associate.task` matches the recommended `ROSS_LOCAL_MODEL_PATH` value above because Ross resolves relative debug paths under its app-private root.

## 4. Launch Ross

Open the installed debug app on the device.

## 5. Open Settings > Private AI > Technical details

Confirm all of the following:

- `Runtime mode` shows `mediapipe_llm`
- `Local runtime` shows `available`
- `Fallback active` shows `no`
- `Model path present` shows `yes`
- `Checksum verified` shows `yes` if you supplied `ROSS_LOCAL_MODEL_CHECKSUM`

If `Local runtime` is `unavailable`, do not proceed with a real-runtime claim. Record the exact `Last runtime error` value instead.

## 6. Import a fixture document

Use a short source-backed legal fixture first. Avoid large bundles for the first proof run.

Recommended initial fixture shape:

- one short order or pleading
- 1 to 5 pages
- clear case number, date, section, and order-direction text

## 7. Run Case Associate extraction

- Open the document
- Start extraction under `Case Associate`
- Wait for extraction and verification to finish

## 8. Confirm the run actually used the real runtime

Return to `Settings > Private AI > Technical details`.

You may record a real local inference success only if:

- `Last invocation runtime` is `mediapipe_llm`
- `Fallback active` is still `no`
- the app did not crash or silently switch back to `deterministic_dev`

## 9. Review extracted details

Confirm:

- extracted fields still show source chips
- unsupported or weak fields are marked `Needs advocate review`
- free-form model text did not slip through as accepted fields
- schema-invalid output was not silently accepted

## 10. Export a case note or summary

Confirm the export completes locally and remains source-backed.

## 11. Inspect Privacy Ledger

Confirm:

- no model-network event exists
- any public-law search event still says only a sanitized query crossed the boundary

## 12. Check logs for privacy regressions

Do not record success if raw prompts, OCR text, or raw page text appear in logs or diagnostics.

The following values must not appear outside local storage and local review UI:

- `Raghav Fakepriv`
- `9876501234`
- `fakepriv@example.com`
- `FAKE/123/2026`
- `blue suitcase near temple`

## Expected pass result

- `mediapipe_llm` is available in technical details
- `Last invocation runtime` is `mediapipe_llm`
- extraction remains source-backed
- `Needs advocate review` appears where support is weak
- Privacy Ledger shows no model-network activity

## Fail conditions

- runtime remains unavailable
- last invocation runtime is `deterministic_dev`
- checksum mismatch blocks the run
- schema-invalid free-form output is accepted as extracted fields
- raw prompts or source text leak into logs or invocation metadata

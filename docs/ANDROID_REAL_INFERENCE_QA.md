# Android Real Inference QA

This runbook proves the Android `mediapipe_llm` path on a physical device.

- Do not claim success from `deterministic_dev`.
- Do not claim success from emulator-only runs.
- Do not claim success unless `Last invocation runtime` or the smoke report shows `mediapipe_llm`.

## Prerequisites

- physical Android device
- developer-provided `.task` model artifact
- debug build of Ross
- optional local backend for catalog/download/public-law checks

Model files:

- are not committed
- are not bundled
- stay outside the repo unless copied into app-private storage during manual QA

## Recommended path

Use the smoke helper first:

```sh
cd /Users/amanpandey/projects/ross
export ROSS_ENABLE_REAL_LOCAL_INFERENCE=1
export ROSS_LOCAL_RUNTIME=mediapipe_llm
export ROSS_LOCAL_MODEL_PATH=debug-models/case-associate.task
export ROSS_LOCAL_MODEL_KIND=mediapipe_task
export ROSS_LOCAL_MODEL_CHECKSUM=<optional sha256>
export ROSS_LOCAL_MODEL_PUSH_SOURCE=/absolute/path/to/case-associate.task
./scripts/dev/android-real-inference-smoke.sh
```

What the script does:

- checks `adb`
- lists connected devices
- looks for a physical device
- checks required env vars
- builds the debug APK
- optionally pushes the model file
- prints install/run instructions
- never prints case text or prompt text

## Manual app flow

1. Install the debug APK.
2. Launch Ross on the physical device.
3. Open `Settings > Private AI > Technical details`.
4. Confirm:
   - `Runtime mode` is `mediapipe_llm`
   - `Real runtime enabled` is `yes`
   - `Model path` is `Configured`
   - `Checksum verified` is `yes` if configured
   - `Local runtime` is `available`
   - `Fallback active` is `no`
5. Run `Run local inference smoke`.
6. Confirm the smoke report shows:
   - runtime used `mediapipe_llm`
   - schema valid `yes`
   - unsupported accepted `0`
7. Import a short synthetic or non-sensitive legal fixture.
8. Run `Case Associate` extraction.
9. Return to Technical details and confirm the last invocation runtime still shows `mediapipe_llm`.

## What to verify in extraction

- extracted fields remain source-backed
- weak or unsupported fields remain in `Needs advocate review`
- invalid/free-form model output is not silently accepted
- no crash occurs for larger files; Ross batches or falls back safely
- exports still generate locally

## Privacy checks

- Privacy Ledger shows no model-network event
- raw prompts do not appear in logs
- raw source text does not appear in logs
- runtime health does not expose the full model path
- runtime metrics contain counts and timings only

## Blocked status

Mark the run as blocked if any of the following is true:

- no physical device
- no compatible `.task` artifact
- checksum mismatch
- runtime dependency unavailable
- local runtime unavailable on the device

## Result language

Use precise wording:

- `Real Android local inference ran on a physical device`
- or `Android real local inference was not run`

If not run, include the exact blocker.

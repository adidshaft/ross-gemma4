# Manual Local Inference QA

This runbook exists to keep the repo honest about what was actually proven.

- `deterministic_dev` is not a real model.
- Real local inference requires a compatible runtime and a developer-provided model artifact.
- Do not claim a real local inference run unless Technical details recorded the real runtime mode.

## Latest observed status

Observed through 2026-06-18:

- iOS Swift tests and simulator build passed for the Gemma GGUF download/install/readiness plumbing.
- iOS simulator real Gemma GGUF smoke passed with `/Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf` (`e0aee85060f168f0f2d8473d7ea41ce2f3230c1bc1374847505ea599288a7787`) using `ROSS_LOCAL_RUNTIME=gemma_local_runtime`.
- The smoke passed English source grounding, Bengali Bangla-script source grounding, Hindi Devanagari source grounding, and a general cautious answer.
- A stricter rerun later on 2026-06-02 emitted `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime tier=quick_start elapsed=89.36s ... source_native_model=true bengali_native_model=true hindi_native_model=true general_native_model=true`.
- Native Bengali and Hindi behavior are proven in that simulator smoke; no language-preserving fallback was used in the latest pass.
- A June 18, 2026 cabled-device helper run on Aman's physical iPhone passed with the 2B GGUF artifact, proving the real physical-device GGUF path itself.
- A later June 18, 2026 cabled-device helper run with the intended `gemma-4-12b-it-UD-Q4_K_XL.gguf` artifact reached the phone and entered real GGUF load on the A17 Pro GPU, but failed with `mmap failed: Cannot allocate memory` before any smoke stage could generate output.
- The observed physical iPhone in that 12B attempt reported `System physical memory: 7 GB`, so this run should be treated as below-target evidence for the current Case Associate 12B footprint rather than as a successful pack proof.
- A physical/device QA pass over user-imported files is still required before claiming App Store/device performance on a target that can actually run the intended 12B pack.

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
- model artifacts used for manual proof must stay outside the repo until transferred into app-private storage during QA
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
- If `adb devices -l` is empty or no `.task` artifact is configured, stop and record `Not run`.

## iOS QA

Requirements for Apple Foundation Models:

- `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`
- `ROSS_LOCAL_RUNTIME=apple_foundation_models`
- compatible Apple device/runtime

Requirements for Gemma GGUF:

- `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`
- `ROSS_LOCAL_RUNTIME=gemma_local_runtime`
- `ROSS_LOCAL_MODEL_PATH=<app-readable absolute GGUF path>`
- optional `ROSS_LOCAL_MODEL_CHECKSUM=<sha256>`
- optional `ROSS_LOCAL_MODEL_KIND=gguf`

Manual setup smoke:

1. Open `/Users/amanpandey/projects/ross-gemma4/ios/Ross.xcodeproj`.
2. Add the environment variables to the scheme.
3. For direct GGUF smoke, add `--local-model-smoke` to the scheme arguments.
4. Run on a compatible simulator or device that can read the configured model path.
5. Confirm the console prints `ROSS_LOCAL_MODEL_SMOKE_HEALTH`.
6. Claim real local model execution only if the console prints `ROSS_LOCAL_MODEL_SMOKE_PASS`.
7. Treat any `ROSS_LOCAL_MODEL_SMOKE_FAIL` as a failed proof, especially when it reports `source_grounded=false`, `bengali_grounded=false`, or `hindi_grounded=false`.
8. Read `bengali_native_model` and `hindi_native_model` on the pass/fail line:
   - `true` means the real provider produced that language/script answer itself.
   - `false` means Ross kept the product answer safe by using the source-preserving extractive fallback.
9. If the console only shows llama.cpp model/context setup and never prints a Ross pass/fail marker, record the run as stalled and terminate the app; do not claim native model proof from that run.

Cabled physical iPhone helper:

- For a cabled iPhone plus a local GGUF file, you can use `/Users/amanpandey/projects/ross-gemma4/scripts/ios-device-gguf-smoke.sh` instead of reconstructing the container path by hand.
- Example:

```sh
cd /Users/amanpandey/projects/ross-gemma4
scripts/ios-device-gguf-smoke.sh \
  --device 00008130-000C74820130001C \
  --model /Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf \
  --tier quickStart \
  --stage-timeout 45
```

- The helper seeds the GGUF plus a manifest into `Library/Application Support/RossAlpha/model-packs/<tier>/`, resolves the absolute device-side model path with a probe copy, then launches Ross with `--local-model-smoke` and the required `DEVICECTL_CHILD_ROSS_*` environment variables. Device-side seed filenames are run-scoped with the pack id and checksum prefix, and the manifest is copied only after the model transfer succeeds, so an interrupted cabled copy leaves an orphaned artifact instead of poisoning the next smoke path.
- A June 18, 2026 run on Aman's physical iPhone (`iPhone16,1`, iOS `27.0`) passed this flow with the 2B GGUF artifact and emitted `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime tier=quick_start`.
- A later June 18, 2026 run with `/Users/amanpandey/model-artifacts/gemma-4-12b-it-UD-Q4_K_XL.gguf` under `--tier caseAssociate` proved that the intended 12B artifact can be staged and opened on the phone, but it failed with `llama_model_load: error loading model: mmap failed: Cannot allocate memory`.
- That same 12B run also exposed a Hugging Face checksum nuance that is now reconciled in Ross metadata: the downloaded GGUF bytes hash to `ee33ab5be8e07aca1c269fc645eaed5f3298e089d52db29415839d8f29957020`, while the CDN `etag` still reported `2f76adb77c0cbce35bf0f14c8a9d57f5a8c08528acf2edf3684b1eb38b075637`.
- This helper proves the physical GGUF runtime path itself. It does not replace the still-needed successful `Case Associate` 12B proof on a device class that can actually fit that pack.

The current `--local-model-smoke` pass requires all of these from the real provider:

- English source-grounded answer about Article 417 citation verification.
- Bengali source-grounded answer in Bangla script.
- Hindi source-grounded answer in Devanagari script.
- General cautious answer without a tagged source.
- No deterministic fallback provider.

Native multilingual model proof is stricter than product safety proof. To claim the model itself handled Bengali/Hindi, require `bengali_native_model=true` and `hindi_native_model=true` in addition to `ROSS_LOCAL_MODEL_SMOKE_PASS`.

Manual in-app flow:

1. Open `/Users/amanpandey/projects/ross-gemma4/ios/Ross.xcodeproj`.
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
   - source-grounded file answer
   - Hindi/Bengali script-appropriate answer when prompted
   - fields found
   - fields verified
   - unsupported accepted `0`
8. In `Support details`, use the hidden runtime switcher whenever more than one lane is immediately available for the current tier.
9. Keep the hidden recent sample-check history visible while switching runtimes so first-response and token-speed comparisons stay on-device.
10. Use the hidden `Latest sample check by runtime` summary to confirm which lanes already have basic sample-file proof and which still need a sample-file pass before you move on.
11. Also run `Check private assistant with a longer matter bundle` in `Support details` for each runtime you compare, then record:
   - answer headline/preview quality on the synthetic longer bundle
   - source refs returned
   - first response
   - token speed
   - runtime choice / execution path / acceleration detail shown for that run
12. Use the hidden `Latest by runtime` summary to confirm whether GGUF, MLX, and CoreAI each have a recent longer-bundle result before making the final ladder decision.
13. Read the hidden `Comparison readout` after the three runtime lanes have recent results so you can note the current leaders on first response, token speed, and visible source coverage before deciding whether the ladder should change.
14. Use the hidden `Device-proof coverage` summary to confirm whether each lane already has both sample-file evidence and longer-bundle evidence, and note any lane that still lacks one side of the proof.
15. Read the hidden `Next device steps` list under that coverage summary to see the exact remaining runs still needed for each lane before you save the note.
16. Confirm the hidden `Device proof profile` shows the expected iPhone model identifier, OS version, memory class, storage state, and current device condition before you save the note.
17. Confirm the hidden `Runtime lane readiness` summary matches reality for this device before you start or save the pass, especially if one lane still needs setup or repair on this iPhone.
18. Tap `Save runtime comparison note` in hidden `Support details` once you have the comparison set you want to keep. This writes a local PDF into `Notes & Drafts` so the device run has a shareable artifact without adding front-stage UI, and now includes the per-runtime readiness snapshot, the combined device-proof coverage summary, the current iPhone proof profile, and the lane-readiness state at capture time.

If the runtime is unavailable:

- record the sanitized reason
- keep deterministic fallback active
- mark the QA result as not run

Current decision:

- persisted iOS metric parity is deferred until after the Android physical-device proof exists

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

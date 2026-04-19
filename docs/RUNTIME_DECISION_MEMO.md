# Runtime Decision Memo

## Phase

Ross Real Local Model Proof & QA Alpha

## Current decision

- Keep `deterministic_dev` as the default runtime for CI, simulator, and safe fallback.
- Treat the deterministic dev provider as a test/runtime scaffold, not as a real model.
- Use Android `mediapipe_llm` as the first real local inference proof path.
- Keep iOS `apple_foundation_models` behind explicit opt-in and compatible-device checks.
- Do not bundle model files.
- Do not commit model files.
- Do not add any cloud inference path.

## Why Android is the first proof target

- The Android branch already has a concrete MediaPipe-backed provider path.
- A developer can supply a `.task` artifact outside the repo.
- Physical-device proof is more important than adding more runtime scaffolding.
- The app now exposes runtime mode, fallback state, checksum status, model-path status, and the last invocation runtime in Technical details.

## Why iOS stays opt-in

- The iOS alpha path is useful for QA readiness, but it still depends on compatible OS and hardware.
- Real-runtime probing remains off unless `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`.
- The canonical real-runtime value remains `ROSS_LOCAL_RUNTIME=apple_foundation_models`.
- If unavailable, Ross must say so clearly and keep deterministic fallback active.

## Backend decision

- Default backend behavior remains the tiny deterministic development artifacts already used by CI.
- Disabled-by-default alpha support now exists for:
  - external debug model metadata in `/model-catalog`
  - external debug model serving for `/model-download/session` plus ranged artifact delivery
- External model serving is dev-only.
- External model serving requires an absolute path outside the repo.
- External model serving rejects in-repo, source-tree, build-output, or unsafe paths.
- Backend logs never print the configured local model path.

## Model artifact strategy for alpha

1. Preferred proof path: developer-provided local debug model on Android.
   - Set `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`
   - Set `ROSS_LOCAL_RUNTIME=mediapipe_llm`
   - Set `ROSS_LOCAL_MODEL_PATH`
   - Optionally set `ROSS_LOCAL_MODEL_CHECKSUM`
2. Optional backend metadata path:
   - enable `ROSS_ENABLE_EXTERNAL_MODEL_METADATA=1`
   - advertise `external_debug_model` metadata without exposing a download path
3. Optional backend dev serving path:
   - enable `ROSS_ENABLE_EXTERNAL_MODEL_SERVING=1`
   - provide `ROSS_EXTERNAL_MODEL_FILE_PATH`
   - keep the file outside the repo
4. Production delivery remains future work.
   - signed manifests
   - signed URLs
   - app-private storage
   - checksum enforcement

## Runtime truth rules

- Do not claim real local inference unless the app actually recorded the real runtime mode.
- Android proof should normally come from a physical device.
- iOS proof requires a compatible device/runtime and explicit opt-in.
- If the runtime is unavailable, Ross must say fallback is active.
- Unsupported or low-confidence model output must not be silently accepted.
- All accepted output must remain schema-validated, source-validated, and verifier-gated.

## Privacy rules kept in force

- Case files stay on this device.
- Public-law search sends only a sanitized query.
- Raw prompts are not persisted by default.
- Raw source text is not persisted in model invocation metadata.
- Local runtime metrics contain counts and timings only, not content.
- No remote model provider was added.

## Blockers that still require manual proof

- A compatible physical Android device.
- A developer-provided `.task` model artifact.
- A compatible Apple device/runtime for Foundation Models QA.

## Recommendation

- Use the new Android smoke tooling and Technical details screen first.
- Record one honest physical-device `Case Associate` run before expanding runtime architecture any further.

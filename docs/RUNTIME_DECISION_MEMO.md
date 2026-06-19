# Runtime Decision Memo

## Phase

Ross Real Local Model Proof & QA Alpha

## Current decision

- Keep `deterministic_dev` as the default runtime for CI, simulator, and safe fallback.
- Treat the deterministic dev provider as a test/runtime scaffold, not as a real model.
- Treat iOS GGUF/`llama.cpp` as the current proven real local inference lane.
- Keep MLX and Apple Foundation/CoreAI/CoreML behind explicit runtime identity and artifact-shape checks.
- Do not bundle model files.
- Do not commit model files.
- Do not add any cloud inference path.

## Latest observed outcome

- iOS GGUF Quick Start has physical-device benchmark evidence on Aman's iPhone from June 19, 2026.
- The 12B GGUF lane is correctly blocked as `insufficient_device_memory` on the 7 GB iPhone class.
- MTP draft artifacts are discoverable and can reach `draftModelSpeculative` on some stages, but the June 19 physical full-matrix attempt failed quality gates with `draft_output_degenerate`. A benchmark is invalid unless runtime identity reports `acceleration=draftModelSpeculative`, `draft_status=active`, non-`nil` draft tokens, a non-`nil` draft model, and every requested benchmark stage reports matching draft metadata without degenerate output.
- MLX and CoreAI/CoreML requests are not valid benchmarks unless `ROSS_RUNTIME_IDENTITY actual_runtime` proves `mlx_swift_lm` or `apple_foundation_models` respectively.
- Runtime resolution now rejects incompatible active/debug artifact shapes before provider construction, so a requested MLX/CoreAI lane cannot borrow a GGUF artifact and become benchmark evidence.

## Why iOS GGUF is the current proof target

- The iOS app has a concrete `llama.cpp` provider path with source-grounded physical-device smoke evidence.
- The cabled-device and simulator smoke helpers now require runtime identity before benchmark summaries.
- The app exposes runtime mode, artifact shape, fallback state, checksum status, acceleration state, draft metadata, token counts, and speed in diagnostic surfaces.
- Further MLX/CoreAI/MTP work should improve real provider activation and guardrails, not widen fallback behavior.

## Why MLX/CoreAI/MTP stay guarded

- Real-runtime probing remains off unless `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`.
- `ROSS_LOCAL_RUNTIME=mlx` must resolve to `mlx_swift_lm` with `artifactKind=mlx_directory` and a usable directory.
- `ROSS_LOCAL_RUNTIME=coreai` or `coreml` must resolve to `apple_foundation_models` with a system sentinel or a valid Foundation/CoreAI/CoreML adapter artifact.
- `ROSS_LOCAL_RUNTIME=gguf` with `--require-draft-acceleration` must fail unless MTP draft acceleration is active and generation stages report draft acceleration.
- If unavailable, Ross must say so clearly with categories such as `missing_mlx_artifact`, `missing_coreai_artifact`, `unsupported_runtime_on_platform`, or draft-specific MTP errors.

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

1. Preferred proven path: installed or explicit GGUF artifact on iOS.
   - Set `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`
   - Set `ROSS_LOCAL_RUNTIME=gguf`
   - Set `ROSS_LOCAL_MODEL_PATH`
   - Optionally set `ROSS_LOCAL_MODEL_CHECKSUM`
2. MTP proof path:
   - Use the GGUF lane with a valid `.gguf` draft companion.
   - Set `ROSS_LOCAL_DRAFT_MODEL_PATH` or use an installed manifest with `draftArtifact.relativePath`.
   - Use the `mtp_quick` profile and require draft acceleration for proof.
3. MLX proof path:
   - Set `ROSS_LOCAL_RUNTIME=mlx`.
   - Provide an MLX directory artifact, not a GGUF file.
4. CoreAI/CoreML proof path:
   - Set `ROSS_LOCAL_RUNTIME=coreai` or `coreml`.
   - Use `system-model`/`system://...` only for the built-in Foundation Models sentinel, or provide a real adapter artifact.
5. Optional backend metadata path:
   - enable `ROSS_ENABLE_EXTERNAL_MODEL_METADATA=1`
   - advertise `external_debug_model` metadata without exposing a download path
6. Optional backend dev serving path:
   - enable `ROSS_ENABLE_EXTERNAL_MODEL_SERVING=1`
   - provide `ROSS_EXTERNAL_MODEL_FILE_PATH`
   - keep the file outside the repo
7. Production delivery remains future work.
   - signed manifests
   - signed URLs
   - app-private storage
   - checksum enforcement

## Runtime truth rules

- Do not claim real local inference unless the app records a matching `ROSS_RUNTIME_IDENTITY` runtime mode.
- Do not claim MLX/CoreAI/MTP numbers from a GGUF identity marker or a failed smoke summary.
- Physical iPhone proof is required for release-quality device performance claims.
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

- Physical-device MTP proof with active draft acceleration and non-degenerate output.
- Physical-device MLX proof with a real MLX directory artifact.
- Physical-device Apple Foundation/CoreAI/CoreML proof on a supported OS/device or with a valid adapter.
- End-to-end model delivery, resume, repair, and deletion for production-sized artifacts.

## Recommendation

- Keep using iOS smoke helpers and runtime identity as the source of truth.
- Run the morning checkpoint only after the iPhone is cabled/unlocked, using short guarded smokes and stopping on fallback, memory pressure, thermal issues, or instability.
- Do not publish new MLX/CoreAI/MTP benchmark numbers until the matching runtime identity and generation pass are recorded.

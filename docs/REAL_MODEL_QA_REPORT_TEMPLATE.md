# Real Model QA Report Template

- Date:
- Branch:
- Commit observed during validation:
- Platform:
- Device model:
- Android version / OS version:
- Runtime mode:
- Requested runtime:
- Actual runtime from `ROSS_RUNTIME_IDENTITY`:
- Runtime provider:
- Artifact path type / label:
- Acceleration:
- Draft status / draft model / draft tokens:
- Draft error detail:
- Runtime error detail:
- Fallback status:
- Model artifact kind:
- Model artifact source:
- Model checksum status:
- Whether model file was committed: No
- Whether inference actually ran: Yes/No
- Whether deterministic fallback was used:
- Runtime health result:
- Fixture(s) used:
- Document/query variety covered:
- Benchmark profile:
- `ROSS_RUNTIME_IDENTITY` marker:
- `ROSS_SMOKE_BENCHMARK_SUMMARY` marker:
- Benchmark summary guard reason, if rejected:
- Extraction mode:
- Duration:
- First-token latency:
- Tokens processed:
- Token speed:
- Token metrics source: hidden response details / smoke marker / manual stopwatch
- Fields found:
- Fields verified:
- Fields needing review:
- Unsupported accepted count:
- Schema valid:
- Source refs present:
- Export generated:
- Privacy ledger checked:
- Logs checked for raw prompt/source:
- Network checked for model calls:
- Evidence classification: benchmark / routing-only / failed-load / skipped
- Exact blocker:
- What was validated instead:
- Failures/blockers:
- Next exact manual step:

## Runtime Evidence Rules

- Do not record a benchmark unless the requested runtime and actual runtime match the lane under test.
- Prefer `ROSS_SMOKE_BENCHMARK_SUMMARY` over raw pass logs. The summary is valid only when the pass runtime, pass `requested_runtime`, identity `actual_runtime`, identity `requested_runtime`, required identity `pack_runtime`, provider, `checksum_verified=true`, positive `context_tokens`, `gpu_offload` evidence, benchmark matrix profile, known smoke-stage names, per-stage token/speed metrics, per-stage native-output markers, and source refs for source-bound stages agree.
- `draft_error_detail` and `runtime_error_detail` are diagnostic fields. Record them for failed-load/routing-only rows, but never use them to upgrade a failed or fallback row into benchmark evidence.
- MLX requires `actual_runtime=mlx_swift_lm`.
- CoreAI/CoreML/Foundation Models requires `actual_runtime=apple_foundation_models`.
- MTP requires `acceleration=draftModelSpeculative`, `draft_status=active`, non-empty draft tokens, and a `.gguf` draft model label in `ROSS_RUNTIME_IDENTITY`. Smoke benchmark summaries also require every matrix stage to report matching `*_acceleration=draftModelSpeculative`, `*_draft_tokens`, and `*_draft_model`.
- Any `missing_benchmark_*` guard failure, `benchmark_runtime_mismatch`, `benchmark_requested_runtime_missing`, `benchmark_requested_runtime_mismatch`, `benchmark_pass_requested_runtime_missing`, `benchmark_pass_requested_runtime_mismatch`, `benchmark_pack_runtime_missing`, `benchmark_pack_runtime_mismatch`, `benchmark_profile_mismatch`, `benchmark_matrix_shape_mismatch`, `benchmark_runtime_unsupported`, `benchmark_runtime_unavailable`, `benchmark_runtime_identity_missing`, `benchmark_runtime_diagnostic_error`, `benchmark_runtime_artifact_mismatch`, `benchmark_stage_metrics_missing`, `benchmark_stage_quality_missing`, `benchmark_draft_artifact_mismatch`, `benchmark_draft_profile_mismatch`, or `benchmark_draft_stage_mismatch` means the entry is not benchmark evidence for the requested lane.
- Any fallback to GGUF, deterministic development output, or unavailable runtime makes the entry routing-only or failed-load, not a benchmark for the requested lane.
- Before cabled-device validation, record whether `scripts/ios-runtime-artifact-inventory.sh --installed-root ...` reported the requested installed lane as present. MTP requires both `installed_gguf status=present` and `installed_mtp_draft status=present` for the same tier before launch. `manifest_primary_unusable_artifact` or `manifest_draft_unusable_artifact` means the lane should be skipped or repaired before launching the app.

## Recommended Variety Matrix

- Source-grounded document QA with source references retained.
- General legal query without tagged document sources.
- At least two non-English source-grounded prompts when using a multilingual smoke profile.
- One longer-bundle or multi-document matter prompt before making product-quality claims.
- Manual UI runs should capture hidden answer details for `Tokens processed` and `Token speed` without surfacing those metrics in the main response UI.

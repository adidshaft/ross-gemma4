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
- Prefer `ROSS_SMOKE_BENCHMARK_SUMMARY` over raw pass logs. The summary is valid only when the pass runtime, identity `actual_runtime`, identity `requested_runtime`, identity `pack_runtime`, benchmark matrix profile, known smoke-stage names, and per-stage token/speed metrics agree.
- MLX requires `actual_runtime=mlx_swift_lm`.
- CoreAI/CoreML/Foundation Models requires `actual_runtime=apple_foundation_models`.
- MTP requires `acceleration=draftModelSpeculative`, `draft_status=active`, non-empty draft tokens, and a `.gguf` draft model label in `ROSS_RUNTIME_IDENTITY`. Smoke benchmark summaries also require every matrix stage to report matching `*_acceleration=draftModelSpeculative`, `*_draft_tokens`, and `*_draft_model`.
- `benchmark_runtime_mismatch`, `benchmark_requested_runtime_mismatch`, `benchmark_pack_runtime_mismatch`, `benchmark_runtime_unsupported`, `benchmark_stage_metrics_missing`, or `benchmark_draft_stage_mismatch` means the entry is not benchmark evidence for the requested lane.
- Any fallback to GGUF, deterministic development output, or unavailable runtime makes the entry routing-only or failed-load, not a benchmark for the requested lane.

## Recommended Variety Matrix

- Source-grounded document QA with source references retained.
- General legal query without tagged document sources.
- At least two non-English source-grounded prompts when using a multilingual smoke profile.
- One longer-bundle or multi-document matter prompt before making product-quality claims.
- Manual UI runs should capture hidden answer details for `Tokens processed` and `Token speed` without surfacing those metrics in the main response UI.

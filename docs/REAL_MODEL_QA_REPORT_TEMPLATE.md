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
- MLX requires `actual_runtime=mlx_swift_lm`.
- CoreAI/CoreML/Foundation Models requires `actual_runtime=apple_foundation_models`.
- MTP requires `acceleration=draftModelSpeculative`, `draft_status=active`, non-empty draft tokens, and a `.gguf` draft model label.
- Any fallback to GGUF, deterministic development output, or unavailable runtime makes the entry routing-only or failed-load, not a benchmark for the requested lane.

## Recommended Variety Matrix

- Source-grounded document QA with source references retained.
- General legal query without tagged document sources.
- At least two non-English source-grounded prompts when using a multilingual smoke profile.
- One longer-bundle or multi-document matter prompt before making product-quality claims.
- Manual UI runs should capture hidden answer details for `Tokens processed` and `Token speed` without surfacing those metrics in the main response UI.

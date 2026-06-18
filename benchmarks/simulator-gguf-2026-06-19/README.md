# Simulator GGUF Runtime Benchmark - 2026-06-19

This checkpoint records simulator-only benchmark evidence for the local GGUF path. No physical iPhone was used for these runs.

## Environment

| Field | Value |
| --- | --- |
| Simulator | iPhone 17, `E36AB177-2287-4112-8225-339048142D11` |
| App bundle | `com.ross.ios` |
| Runtime | `gemma_local_runtime` |
| Provider | `AlphaLlamaCppProvider` |
| Model | `artifacts/gemma-2-2b-it-Q4_K_M.gguf` |
| Model size | 1.6 GB |
| Acceleration | `standard` |
| Draft status | `no_draft_configured` |
| Fallback | `none` |

Both successful and failed rows below had `requested_runtime=gemma_local_runtime` and `actual_runtime=gemma_local_runtime` in `ROSS_RUNTIME_IDENTITY`.

## Commands

```bash
scripts/ios-simulator-local-model-smoke.sh \
  --runtime gguf \
  --model /Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf \
  --simulator E36AB177-2287-4112-8225-339048142D11 \
  --smoke-profile quick \
  --stage-timeout 120 \
  --launch-timeout 360

scripts/ios-simulator-local-model-smoke.sh \
  --runtime gguf \
  --model /Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf \
  --simulator E36AB177-2287-4112-8225-339048142D11 \
  --smoke-profile full \
  --stage-timeout 150 \
  --launch-timeout 720
```

## Results

| Profile | Result | Coverage | Notes |
| --- | --- | --- | --- |
| `quick` | PASS | English source-bound document QA and general query. | Valid benchmark summary emitted. |
| `full` | FAIL | English source-bound QA, general query, Bengali, Hindi, Tamil, Telugu. | Tamil and Telugu were schema-valid/native-model responses but failed grounding checks. |

## Speed And Token Metrics

| Profile | Stage | Tokens processed | Token speed | First token |
| --- | --- | ---: | ---: | ---: |
| quick | Source document QA | 325 | 10.29 tok/s | 13.13s |
| quick | General query | 382 | 10.54 tok/s | 12.58s |
| full | Source document QA | 325 | 7.78 tok/s | 15.02s |
| full | General query | 382 | 8.76 tok/s | 14.48s |
| full | Bengali source QA | 449 | 8.05 tok/s | 29.66s |
| full | Hindi source QA | 412 | 7.88 tok/s | 22.82s |
| full | Tamil source QA | 369 | 7.53 tok/s | 29.64s |
| full | Telugu source QA | 396 | 6.31 tok/s | 29.76s |

`Tokens processed` is `input_tokens + output_tokens` from the smoke fields. Token counts are estimator-backed in this simulator run (`*_measured_tokens=false`).

## Memory Notes

| Run point | Observed memory |
| --- | ---: |
| Launch | ~31 MB physical footprint |
| Provider ready | ~3.15 GB physical footprint |
| Quick peak observed | ~3.21 GB physical footprint |
| Full peak observed | ~3.25 GB physical footprint |

The simulator forced CPU execution (`n_gpu_layers=0` in loader output), so these numbers are useful for local stability and guardrail validation, not for final physical-device performance claims.

# Physical iPhone Runtime Benchmarks - 2026-06-19

This report records the physical-device benchmark evidence captured on Aman's attached iPhone. It is intentionally conservative: only runs that actually produced generation through a runtime are marked as benchmarks.

## Device And App

| Field | Value |
| --- | --- |
| Device | Aman's iPhone |
| Model | iPhone 15 Pro |
| Hardware identifier | iPhone16,1 |
| iOS | 27.0 |
| RAM reported by tooling | 7 GB |
| App bundle | `com.ross.ios` |
| Install path | Current checkout built for device and installed over cable |

## Runtime Coverage

| Runtime path | Status | Evidence |
| --- | --- | --- |
| GGUF / `llama.cpp` / `llama.swift` | Benchmarked and passing | E4B Quick Start and 2B baseline generated local source-grounded and general answers. |
| MTP draft acceleration | Artifact detected, not release-safe | E4B pack included `mtp-gemma-4-E4B-it.gguf`. Strict validation failed in one run, and a later full-matrix draft run produced `draft_output_degenerate` on Bengali. Do not publish MTP numbers from these runs. |
| MLX / `mlx_swift_lm` | Requested, not benchmarked | The smoke request entered `runtime=mlx_swift_lm`, but the installed state resolved through GGUF files and loader logs. No MLX artifact-backed generation result was produced. |
| CoreAI / Foundation Models | Requested, not benchmarked | The smoke request entered `runtime=apple_foundation_models`, but the installed state resolved through GGUF files and loader logs. No CoreAI artifact-backed generation result was produced. |
| Gemma 4 12B GGUF | Blocked safely | The app refused generation with `insufficient_device_memory` on this 7 GB device class. |

## Fresh Checkpoint - 2026-06-19 13:10 IST

A fresh Debug build was installed on Aman's physical iPhone 15 Pro (`iPhone16,1`) with `xcrun devicectl device install app`. The installed app container preserved the E4B Quick Start pack, the 2B seeded proof pack, and the 12B seeded proof pack.

The 2B proof pack passed the full physical-device benchmark matrix after the fresh install. This covered English source-bound document Q&A, Bengali source-bound document Q&A, Hindi source-bound document Q&A, Tamil source-bound document Q&A, Telugu source-bound document Q&A, and an English open no-document query. The guarded `ROSS_SMOKE_BENCHMARK_SUMMARY` matched `requested_runtime=gemma_local_runtime`, `actual_runtime=gemma_local_runtime`, `fallback=none`, `available=true`, `artifact_path_type=file`, and `profile=full`.

The E4B Quick Start GGUF pack still loads on the physical device, but the fresh full-matrix run with a 90s stage timeout did not produce a benchmark summary: the first source-bound stage timed out after real generation started. Treat this checkpoint as load/routing evidence, not a fresh E4B benchmark.

The E4B MTP proof attempt failed safely. Strict draft validation required active speculative acceleration, but the run reported `draft_status=validator_failed`, `error=draft_validator_failed`, `acceleration=standard`, and `draft_tokens=nil` after `llama_model_load` failed with `mmap failed: Cannot allocate memory`. This is not MTP benchmark evidence.

## Fresh Standard E4B Full-Matrix Checkpoint - 2026-06-19 13:55 IST

A later installed-pack smoke used the same E4B Quick Start pack with draft explicitly disabled:

```bash
scripts/ios-device-installed-pack-smoke.sh \
  --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B \
  --pack-id gemma-4-e4b-q4 \
  --runtime gguf \
  --smoke-profile full \
  --stage-timeout 180 \
  --disable-draft
```

This run passed the full benchmark matrix with `ROSS_RUNTIME_IDENTITY actual_runtime=gemma_local_runtime`, `acceleration=standard`, `draft_status=no_draft_configured`, `fallback=none`, `available=true`, `context_tokens=4096`, and `gpu_offload=n_gpu_layers:0,offload_kqv:false,op_offload:false`.

The companion draft-enabled full-matrix run is intentionally not a benchmark pass. It produced useful failure evidence: source/general/Bengali stages initially reported `draftModelSpeculative`, but Bengali failed with `bengali_error=draft_output_degenerate`. The same draft pair must remain blocked until a future MTP proof passes the low-token `mtp_quick` profile and any requested full matrix without degenerate output.

## Current Physical Checkpoint - 2026-06-19 14:18 IST

The current checkout was rebuilt and installed on Aman's cabled iPhone 15 Pro (`iPhone16,1`, UDID `3803F5B6-1666-56D3-A71A-62F131F6CE3B`) with the same automatic signing settings. The app container still held the E4B Quick Start pack, the 2B seeded proof pack, and the 12B seeded proof pack.

Two full benchmark matrices passed on the physical device:

| Pack | Result | Coverage | Runtime identity |
| --- | --- | --- | --- |
| `gemma-4-e4b-q4` | PASS | English source-bound document Q&A, Bengali/Hindi/Tamil/Telugu source-bound document Q&A, English open query | `gemma_local_runtime`, `acceleration=standard`, `fallback=none`, `context_tokens=4096`, CPU-only llama.cpp |
| `gemma-2-2b-it-Q4_K_M-device-proof` | PASS | Same full multilingual/source/general matrix | `gemma_local_runtime`, `acceleration=standard`, `fallback=none`, `context_tokens=10240`, Metal offload enabled |

Guardrail probes behaved correctly:

| Probe | Result | Meaning |
| --- | --- | --- |
| E4B strict MTP `mtp_quick` with `--require-draft-acceleration` | FAIL SAFE | `draft_status=validator_failed`, `error=draft_acceleration_required`; do not count MTP speed. |
| 12B quick smoke | FAIL SAFE | `insufficient_device_memory` before generation; 12B remains gated on this 7 GB device class. |
| MLX assistant-download smoke | NOT BENCHMARKED | Ended as `ROSS_ASSISTANT_DOWNLOAD_SMOKE_FAIL missing_job`; it did not produce MLX artifact-backed generation. |
| CoreAI assistant-download smoke | NOT BENCHMARKED | Ended as `ROSS_ASSISTANT_DOWNLOAD_SMOKE_FAIL missing_job`; it did not produce CoreAI artifact-backed generation. |

Fresh speed highlights:

| Run | Stage | Tokens processed | Token speed |
| --- | --- | ---: | ---: |
| E4B standard full | Source document query | 207 input / 56 output | 6.18 output tok/s |
| E4B standard full | Bengali document query | 240 input / 59 output | 6.28 output tok/s |
| E4B standard full | Hindi document query | 246 input / 59 output | 5.92 output tok/s |
| E4B standard full | Tamil document query | 305 input / 95 output | 5.46 output tok/s |
| E4B standard full | Telugu document query | 339 input / 96 output | 5.79 output tok/s |
| E4B standard full | General query | 190 input / 30 output | 6.11 output tok/s |
| 2B full | Source document query | 207 input / 105 output | 14.28 output tok/s |
| 2B full | Bengali document query | 328 input / 192 output | 13.97 output tok/s |
| 2B full | Hindi document query | 278 input / 192 output | 14.29 output tok/s |
| 2B full | Tamil document query | 382 input / 54 output | 10.19 output tok/s |
| 2B full | Telugu document query | 433 input / 60 output | 10.00 output tok/s |
| 2B full | General query | 190 input / 190 output | 14.85 output tok/s |

## Final Physical Pause Checkpoint - 2026-06-19 14:30 IST

The current checkout was rebuilt, installed, and revalidated on the same cabled iPhone 15 Pro. Installed storage still resolved to three manifest-backed packs: E4B Quick Start (`5.13 GB` plus the MTP draft companion), Gemma 2 2B proof (`1.71 GB`), and Gemma 4 12B proof (`7.37 GB`). The full benchmark matrix again covered English source-grounded document Q&A, Bengali/Hindi/Tamil/Telugu source-grounded document Q&A, and an English open no-document query.

| Pack / probe | Result | Runtime identity |
| --- | --- | --- |
| `gemma-4-e4b-q4`, draft disabled | PASS | `gemma_local_runtime`, `acceleration=standard`, `fallback=none`, `context_tokens=4096`, CPU-only llama.cpp |
| `gemma-2-2b-it-Q4_K_M-device-proof` | PASS | `gemma_local_runtime`, `acceleration=standard`, `fallback=none`, `context_tokens=10240`, Metal offload enabled |
| `gemma-4-12b-it-UD-Q4_K_XL-device-proof` | FAIL SAFE | Blocked before generation with `insufficient_device_memory` |
| E4B strict `mtp_quick` | FAIL SAFE | `draft_status=validator_failed`, `error=draft_acceleration_required`; not benchmark evidence |

Fresh speed highlights from this checkpoint:

| Run | Stage | Tokens processed | Token speed |
| --- | --- | ---: | ---: |
| E4B standard full | Source document query | 207 input / 56 output | 9.56 output tok/s |
| E4B standard full | Bengali document query | 240 input / 59 output | 8.87 output tok/s |
| E4B standard full | Hindi document query | 246 input / 59 output | 7.92 output tok/s |
| E4B standard full | Tamil document query | 305 input / 95 output | 7.75 output tok/s |
| E4B standard full | Telugu document query | 339 input / 96 output | 7.56 output tok/s |
| E4B standard full | General query | 190 input / 30 output | 9.23 output tok/s |
| 2B full | Source document query | 207 input / 105 output | 17.02 output tok/s |
| 2B full | Bengali document query | 328 input / 192 output | 16.45 output tok/s |
| 2B full | Hindi document query | 278 input / 192 output | 14.91 output tok/s |
| 2B full | Tamil document query | 382 input / 54 output | 10.68 output tok/s |
| 2B full | Telugu document query | 433 input / 60 output | 10.44 output tok/s |
| 2B full | General query | 190 input / 190 output | 17.66 output tok/s |

The pause-state conclusion is unchanged but better evidenced: GGUF standard generation is working on the physical device, storage selection is manifest-backed and runtime-guarded, 12B remains correctly gated on this 7 GB device class, and MTP must stay non-release until a strict draft-acceleration proof passes without validator failure or degenerate output.

## Installed Packs Observed

| Tier | Pack | Runtime | Artifact | Size | Notes |
| --- | --- | --- | --- | ---: | --- |
| Quick Start | `gemma-4-e4b-q4` | `gemma_local_runtime` | `gemma-4-E4B-it-UD-Q4_K_XL.gguf` | 5.13 GB | Includes draft artifact `mtp-gemma-4-E4B-it.gguf`. |
| Quick Start baseline | `gemma-2-2b-it-Q4_K_M-device-proof` | `gemma_local_runtime` | `gemma-2-2b-it-Q4_K_M.gguf` | 1.71 GB | Seeded proof pack. |
| Case Associate | `gemma-4-12b-it-UD-Q4_K_XL-device-proof` | `gemma_local_runtime` | `gemma-4-12b-it-UD-Q4_K_XL.gguf` | 7.37 GB | Seeded proof pack, blocked by memory guard. |

## Commands Used

The app was built and installed with automatic signing for the attached device:

```bash
xcodebuild \
  -project ios/Ross.xcodeproj \
  -scheme Ross \
  -configuration Debug \
  -destination 'platform=iOS,id=3803F5B6-1666-56D3-A71A-62F131F6CE3B' \
  -derivedDataPath ios/build-device \
  DEVELOPMENT_TEAM=JP4HU7X6G7 \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY='Apple Development' \
  build

xcrun devicectl device install app \
  --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B \
  ios/build-device/Build/Products/Debug-iphoneos/Ross.app
```

The benchmark and runtime smoke commands were:

```bash
scripts/ios-device-installed-pack-smoke.sh \
  --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B \
  --tier quick_start \
  --runtime gguf \
  --smoke-profile quick \
  --stage-timeout 120

scripts/ios-device-installed-pack-smoke.sh \
  --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B \
  --tier quick_start \
  --runtime gguf \
  --smoke-profile full \
  --stage-timeout 180

scripts/ios-device-installed-pack-smoke.sh \
  --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B \
  --pack-id gemma-4-e4b-q4 \
  --runtime gguf \
  --smoke-profile full \
  --stage-timeout 180 \
  --disable-draft

scripts/ios-device-installed-pack-smoke.sh \
  --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B \
  --pack-id gemma-2-2b-it-Q4_K_M-device-proof \
  --allow-device-proof-pack \
  --smoke-profile quick \
  --stage-timeout 120

scripts/ios-device-installed-pack-smoke.sh \
  --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B \
  --pack-id gemma-4-12b-it-UD-Q4_K_XL-device-proof \
  --allow-device-proof-pack \
  --smoke-profile quick \
  --stage-timeout 60

scripts/ios-device-assistant-download-smoke.sh \
  --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B \
  --tier quickStart \
  --runtime coreai \
  --mobile-allowed \
  --wait-seconds 180

scripts/ios-device-assistant-download-smoke.sh \
  --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B \
  --tier quickStart \
  --runtime mlx \
  --mobile-allowed \
  --wait-seconds 90
```

The MLX and CoreAI requests were stopped after they resolved into the existing GGUF-installed state instead of producing MLX/CoreAI artifact-backed generation results.

## Generation Results

| Pack | Profile | Result | Document/query coverage | Runtime |
| --- | --- | --- | --- | --- |
| Gemma 4 E4B Quick Start, 5.13 GB | quick | PASS | Source-grounded document query plus general query. | `gemma_local_runtime` |
| Gemma 4 E4B Quick Start, 5.13 GB | full, standard only | PASS | Source, general, Bengali, Hindi, Tamil, and Telugu queries. | `gemma_local_runtime`, `acceleration=standard` |
| Gemma 4 E4B Quick Start + MTP draft, 5.13 GB + 79 MB | full, draft enabled | FAIL | Source, general, Bengali, Hindi, Tamil, and Telugu queries; Bengali failed as `draft_output_degenerate`. | Not valid MTP evidence |
| Gemma 2 2B baseline, 1.71 GB | quick | PASS | Source-grounded document query plus general query. | Seeded proof pack |
| Gemma 4 12B Case Associate, 7.37 GB | quick | BLOCKED | Generation did not run because the device failed the memory guard. | `insufficient_device_memory` |

## Visible Speed Numbers

| Run | Stage | Tokens processed | Duration | Token speed |
| --- | --- | ---: | ---: | ---: |
| E4B current app | Source document query | 399 scheduled tokens | 11.91s | 16.12 output tok/s, 33.49 total tok/s |
| E4B current app | General query | 382 scheduled tokens | 8.76s | 21.92 output tok/s, 43.62 total tok/s |
| E4B full | Source document query | 399 scheduled tokens | 13.04s | 14.72 output tok/s, 30.59 total tok/s |
| E4B full | General query | 382 scheduled tokens | 8.08s | 23.78 output tok/s, 47.31 total tok/s |
| E4B full standard-only | Source document query | 207 input / 56 output tokens | 14.75s | 6.75 output tok/s |
| E4B full standard-only | General query | 190 input / 30 output tokens | 10.40s | 6.56 output tok/s |
| E4B full standard-only | Bengali document query | 240 input / 59 output tokens | 126.32s | 0.49 output tok/s |
| E4B full standard-only | Hindi document query | 246 input / 59 output tokens | 16.43s | 6.30 output tok/s |
| E4B full standard-only | Tamil document query | 305 input / 95 output tokens | 25.43s | 5.96 output tok/s |
| E4B full standard-only | Telugu document query | 339 input / 96 output tokens | 25.25s | 6.28 output tok/s |
| E4B full | Bengali | 432 scheduled tokens | 12.51s | 15.34 output tok/s, 34.52 total tok/s |
| E4B full | Hindi | 438 scheduled tokens | 14.77s | 13.00 output tok/s, 29.66 total tok/s |
| E4B full | Tamil | 445 scheduled tokens | 15.39s | 12.47 output tok/s, 28.91 total tok/s |
| E4B full | Telugu | 473 scheduled tokens | 20.37s | 9.43 output tok/s, 23.22 total tok/s |
| 2B baseline | Source document query | 399 scheduled tokens | 6.28s | 30.56 output tok/s, 63.51 total tok/s |
| 2B baseline | General query | 382 scheduled tokens | 10.58s | 18.15 output tok/s, 36.11 total tok/s |
| 2B full checkpoint | Source document query | 312 measured tokens | 6.92s | 15.36 output tok/s |
| 2B full checkpoint | Bengali | 520 measured tokens | 13.03s | 14.78 output tok/s |
| 2B full checkpoint | Hindi | 470 measured tokens | 12.88s | 14.95 output tok/s |
| 2B full checkpoint | Tamil | 436 measured tokens | 5.11s | 10.64 output tok/s |
| 2B full checkpoint | Telugu | 493 measured tokens | 5.87s | 10.29 output tok/s |
| 2B full checkpoint | General query | 380 measured tokens | 11.90s | 16.01 output tok/s |

The smoke path did not emit exact final decoded token counts. `output tok/s` is calculated as `max_new_tokens / stage duration`; `tokens processed` is `prompt_tokens + max_new_tokens`.

## Memory And Runtime Notes

| Metric | E4B Quick Start |
| --- | ---: |
| Context window used | 4,096 tokens |
| Max input chars | 22,000 |
| GPU layers | 0 |
| CPU mapped model buffer | 4,873.73 MiB |
| App resident memory after provider ready | ~3.15 GB |
| Peak observed resident memory | ~3.95 GB |
| Device recommended working set | 5,726.63 MB |
| Draft acceleration | Not active: `acceleration=standard`, `draft_tokens=nil` |

The E4B lane works on this iPhone 15 Pro-class device, but it is already a large memory footprint. The 12B lane should remain gated off for this 7 GB RAM class unless a future runtime path proves a safer memory profile.

## Evidence Logs

Compact logs are stored in this folder:

| Log | Purpose |
| --- | --- |
| [`logs/e4b-current-quick.log`](logs/e4b-current-quick.log) | E4B Quick Start source and general query pass. |
| [`logs/e4b-full.log`](logs/e4b-full.log) | E4B multilingual full smoke pass. |
| [`logs/2b-baseline-quick.log`](logs/2b-baseline-quick.log) | Gemma 2 2B baseline quick pass. |
| [`logs/12b-quick.log`](logs/12b-quick.log) | 12B memory-guard block. |
| [`logs/coreai-request.log`](logs/coreai-request.log) | CoreAI request evidence showing fallback into GGUF-installed state. |
| [`logs/mlx-request.log`](logs/mlx-request.log) | MLX request evidence showing fallback into GGUF-installed state. |
| [`logs/current-final-checkpoint/installed-packs.log`](logs/current-final-checkpoint/installed-packs.log) | Final checkpoint installed-pack inventory. |
| [`logs/current-final-checkpoint/e4b-standard-full.log`](logs/current-final-checkpoint/e4b-standard-full.log) | Final E4B standard full multilingual/source/general pass. |
| [`logs/current-final-checkpoint/2b-full.log`](logs/current-final-checkpoint/2b-full.log) | Final 2B full multilingual/source/general pass. |
| [`logs/current-final-checkpoint/12b-quick.log`](logs/current-final-checkpoint/12b-quick.log) | Final 12B memory-guard block. |
| [`logs/current-final-checkpoint/e4b-mtp-quick-strict.log`](logs/current-final-checkpoint/e4b-mtp-quick-strict.log) | Final strict MTP failure-safe evidence. |

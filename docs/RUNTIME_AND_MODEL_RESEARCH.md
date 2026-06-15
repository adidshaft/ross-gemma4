# Runtime and Model Research Tracker

## Part 1 — Models needed

### Gemma 4 E4B Instruct
| Property | Value |
| --- | --- |
| product tier | Basic |
| active model id | gemma-4-e4b-q4 |
| upstream identity | google/gemma-4-E4B-it |
| desired artifact format | GGUF Q4_K_M |
| candidate Hugging Face repo URL | `https://huggingface.co/bartowski/google_gemma-4-E4B-it-GGUF` |
| direct file URL | `https://huggingface.co/bartowski/google_gemma-4-E4B-it-GGUF/resolve/main/google_gemma-4-E4B-it-Q4_K_M.gguf?download=1` |
| file name | `google_gemma-4-E4B-it-Q4_K_M.gguf` |
| sizeBytes | `5405168384` |
| checksumSha256 | `51865750adafd22de56994a343d5a887cc1a589b9bae41d62b748c8bd0ca9c76` |
| verified | true |
| releaseReady | true |
| notes | Current lighter visible pack for iPhone-first setups. |

### Gemma 4 12B Instruct
| Property | Value |
| --- | --- |
| product tier | Standard |
| active model id | gemma-4-12b-q4 |
| upstream identity | google/gemma-4-12B-it |
| desired artifact format | GGUF Q4_K_M |
| candidate Hugging Face repo URL | `https://huggingface.co/ggml-org/gemma-4-12B-it-GGUF` |
| direct file URL | `https://huggingface.co/ggml-org/gemma-4-12B-it-GGUF/resolve/main/gemma-4-12B-it-Q4_K_M.gguf?download=1` |
| file name | `gemma-4-12B-it-Q4_K_M.gguf` |
| sizeBytes | `7381382048` |
| checksumSha256 | `1278394b693672ac2799eadc9a83fd98259a6a88a40acfb1dcaa6c6fc895a606` |
| verified | true |
| releaseReady | true |
| notes | New default quality target for most matters. Alternate repo: `bartowski/gemma-4-12B-it-GGUF`. |

### Gemma 4 26B-A4B Instruct
| Property | Value |
| --- | --- |
| product tier | Advanced |
| active model id | gemma-4-26b-a4b-q4 |
| upstream identity | google/gemma-4-26B-A4B-it |
| desired artifact format | GGUF Q4_K_M |
| candidate Hugging Face repo URL | `https://huggingface.co/bartowski/google_gemma-4-26B-A4B-it-GGUF` |
| direct file URL | `https://huggingface.co/bartowski/google_gemma-4-26B-A4B-it-GGUF/resolve/main/google_gemma-4-26B-A4B-it-Q4_K_M.gguf?download=1` |
| file name | `google_gemma-4-26B-A4B-it-Q4_K_M.gguf` |
| sizeBytes | `17035038112` |
| checksumSha256 | `e718536fe9b4bd505b07d44ded8f1595053a5d5407315bccf555ce592f33c140` |
| verified | true |
| releaseReady | true |
| notes | Highest quality visible pack. Best reserved for larger-memory devices. |

---

## Part 2 — Runtime needed

### llama.cpp Swift/iOS GGUF runtime candidate
- package URL: `https://github.com/mattt/llama.swift`
- package status: Active / Maintained
- supports iOS: Yes
- supports GGUF: Yes
- supports Gemma-family models: Yes
- integration complexity: Medium
- license notes: MIT
- chosen/not chosen: chosen
- reason: Current Ross iPhone path. Verified package release `2.9637.0`, resolved to `llama.cpp` XCFramework `b9637`.

### MLX Swift candidate
- package URL: `https://github.com/ml-explore/mlx-swift.git`
- package status: Active / Maintained by Apple
- supports iOS: Partial pathfinding only
- supports GGUF: No (requires MLX conversion)
- supports Gemma-family models: Yes
- integration complexity: High (requires model format conversion)
- license notes: MIT
- chosen/not chosen: not chosen for default runtime
- reason: Worth exploring for iPhone speed, but it breaks the direct GGUF artifact workflow and current public research still shows moving pieces around Gemma 4 MTP and drafter support.

### Local abstraction fallback
- chosen runtime for submission demo: `Gemma4DemoRuntime`
- production runtime: `llama_cpp_gguf`

## Part 3 — Current iPhone tuning

- `AlphaLlamaRuntimeProfile` now scales context windows by pack and RAM instead of fixed global caps.
- `Basic` targets 8k to 12k context tokens.
- `Standard` targets 12k to 16k context tokens.
- `Advanced` targets 8k to 12k context tokens.
- Input budgets now scale by tier so longer matter files and larger source sets stay on-device.
- `llama_batch_init` was raised from `512` to `1024`, and prompt chunking now uses the same larger threshold.

## Part 4 — Next validation focus

- Run physical iPhone QA on the Standard 12B pack.
- Record latency, memory pressure, and long-file behavior after the new context tuning.
- Reassess whether an MLX branch is justified only after the current GGUF path is measured on device.

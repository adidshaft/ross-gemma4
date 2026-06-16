# Runtime and Model Research Tracker

## Part 1 — Shipped visible model ladder

### Quick Start
| Property | Value |
| --- | --- |
| product tier | Quick Start |
| active model id | `gemma-4-e4b-q4` |
| upstream identity | `google/gemma-4-E4B-it` |
| shipping repo | `unsloth/gemma-4-E4B-it-qat-GGUF` |
| artifact format | GGUF UD-Q4_K_XL |
| file name | `gemma-4-E4B-it-UD-Q4_K_XL.gguf` |
| sizeBytes | `4215693760` |
| checksumSha256 | `b3052f962d6449b4eb2075733c068bdec1c51eadb7b237e6c3157bfbb7b1dae0` |
| draft companion | `mtp-gemma-4-E4B-it.gguf` |
| draftSizeBytes | `59676544` |
| draftChecksumSha256 | `b0005dc39d47ede950c3ec413cb20e832f15b216126eae368d9f572676153cb6` |
| verified | true |
| releaseReady | true |
| notes | Lighter visible pack for everyday work and faster short-turn review. |

### Case Associate
| Property | Value |
| --- | --- |
| product tier | Case Associate |
| active model id | `gemma-4-12b-q4` |
| upstream identity | `google/gemma-4-12B-it` |
| shipping repo | `unsloth/gemma-4-12B-it-qat-GGUF` |
| artifact format | GGUF UD-Q4_K_XL |
| file name | `gemma-4-12b-it-UD-Q4_K_XL.gguf` |
| sizeBytes | `6716355328` |
| checksumSha256 | `cc9ff072e0a8203429ed854e6662c17a6c2bc1e5dca5b475dd4736caaacbc165` |
| draft companion | `mtp-gemma-4-12b-it.gguf` |
| draftSizeBytes | `253707328` |
| draftChecksumSha256 | `c50c91c35f04903815b2e8930cbb8c8c5bee0e1aa00748c30a7b8ff05d2310b4` |
| verified | true |
| releaseReady | true |
| notes | Current recommended quality target for most matters and larger files. |

### Senior Drafting Support
| Property | Value |
| --- | --- |
| product tier | Senior Drafting Support |
| active model id | `gemma-4-26b-a4b-q4` |
| upstream identity | `google/gemma-4-26B-A4B-it` |
| shipping repo | `unsloth/gemma-4-26B-A4B-it-qat-GGUF` |
| artifact format | GGUF UD-Q4_K_XL |
| file name | `gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf` |
| sizeBytes | `14249045120` |
| checksumSha256 | `dcf179a91153e3a7ece792e48ef872180d9d6ef9b7677f0a0bd3e83cfe624d5e` |
| draft companion | `mtp-gemma-4-26B-A4B-it.gguf` |
| draftSizeBytes | `251937728` |
| draftChecksumSha256 | `62bd3af7f66c9308de9a5454233852f8c7324c93767e8dfb824ed45b9179864a` |
| verified | true |
| releaseReady | true |
| notes | Highest-quality visible pack. Best reserved for larger-memory devices and drafting-heavy workflows. |

Legacy compatibility note:

- `flash` still decodes older state and test fixtures.
- It is not part of the normal setup ladder.

## Part 2 — Runtime status

### GGUF iOS runner
- package URL: `https://github.com/mattt/llama.swift`
- status: active and currently pinned in Ross
- chosen: yes
- current Ross package floor: `2.9670.0`
- current resolved revision: `9018836a615e1076bbde40c287099d06a95c397d`
- current upstream binary lane: `llama.cpp` Apple XCFramework `b9670`
- role in Ross: default GGUF path, including speculative draft companions for the visible 3-pack ladder

### MLX Swift lane
- package URLs:
  - `https://github.com/ml-explore/mlx-swift`
  - `https://github.com/ml-explore/mlx-swift-lm`
- status: active secondary runtime lane
- chosen: yes, but not as the only delivery path
- role in Ross: iPhone/macOS runtime option for MLX model directories, with packaged MLX companions for Quick Start and Case Associate and iPhone-specific speed heuristics
- limitation: it requires MLX-native model directories instead of direct GGUF execution

### Built-in CoreAI lane
- runtime raw value: `apple_foundation_models`
- status: active fallback/instant-setup lane on supported devices
- role in Ross: lets supported iPhones prefer the built-in model when no download or faster recent runs make that the better UX choice

## Part 3 — Current iPhone tuning

- `AlphaLlamaRuntimeProfile` now scales context windows and input budgets by model class and RAM instead of fixed caps.
- Verified GGUF examples from tests:
  - 12B at 8 GB RAM -> `20,480` context tokens
  - 12B at 12 GB RAM -> `28,672` context tokens
  - 12B at 16 GB RAM -> `40,960` context tokens
  - 12B max input chars at 12 GB RAM -> `56,000`
  - 12B max input chars at 16 GB RAM -> `72,000`
- `llama_batch_init` and prompt batching were widened so capable iPhones can prefill larger prompts more efficiently.
- `AlphaMLXRuntimeProfile` now carries iPhone-aware context, input-budget, prefill, draft-token, and speed heuristics.
- Verified MLX examples from tests:
  - Case Associate at 12 GB RAM -> `24,576` context tokens and `56,000` input chars
  - Case Associate at 16 GB RAM -> `40,960` context tokens and `72,000` input chars
  - Quick Start at 8 GB RAM -> `40,000` input chars
- `AlphaFoundationRuntimeProfile` also raises CoreAI budgets on larger-memory devices so the built-in lane is less cramped for longer asks.

## Part 4 — Current Ross implementation result

- The visible setup ladder is already the intended 3-pack lineup: Quick Start, Case Associate, and Senior Drafting Support.
- `gemma-4-12b-q4` is the middle visible tier and current recommended quality target.
- GGUF remains the most stable cross-platform delivery path.
- MLX is now a real runtime lane for supported iPhones instead of a future-only idea.
- CoreAI is now a real runtime lane for supported devices instead of only a brainstorm.
- The answer-details UX for `Tokens processed` and `Token speed` already exists behind hidden response actions instead of adding noise to the main answer body.

## Part 5 — Next validation focus

- Run physical iPhone QA on the 12B GGUF and MLX lanes.
- Compare smoother long-file behavior and measured token speed across GGUF, MLX, and CoreAI on representative iPhones.
- Confirm whether the 26B tier should stay GGUF/CoreAI-only on iPhone until the MLX main archive story is fully reliable.

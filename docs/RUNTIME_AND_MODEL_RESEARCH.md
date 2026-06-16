# Runtime and Model Research Tracker

## Part 1 — Shipped visible model ladder

### Quick Start
| Property | Value |
| --- | --- |
| product tier | Quick Start |
| active model id | `gemma-4-e4b-q4` |
| upstream identity | `google/gemma-4-E4B-it` |
| shipping repo | `unsloth/gemma-4-E4B-it-GGUF` |
| artifact format | GGUF UD-Q4_K_XL |
| file name | `gemma-4-E4B-it-UD-Q4_K_XL.gguf` |
| sizeBytes | `5126304928` |
| checksumSha256 | `724f9a1e6966e36586c70f4c5fa08a8bdafbc39676469481ce98683a0366e8bf` |
| draft companion | `mtp-gemma-4-E4B-it.gguf` |
| draftSizeBytes | `98653248` |
| draftChecksumSha256 | `c41954b43f5e2de1ff5128d5c2abb4195aea72ee7ed5e36405be9b02fa687e77` |
| verified | true |
| releaseReady | true |
| notes | Lighter visible pack for everyday work and faster short-turn review. |

### Case Associate
| Property | Value |
| --- | --- |
| product tier | Case Associate |
| active model id | `gemma-4-12b-q4` |
| upstream identity | `google/gemma-4-12B-it` |
| shipping repo | `unsloth/gemma-4-12b-it-GGUF` |
| artifact format | GGUF UD-Q4_K_XL |
| file name | `gemma-4-12b-it-UD-Q4_K_XL.gguf` |
| sizeBytes | `7366421920` |
| checksumSha256 | `2f76adb77c0cbce35bf0f14c8a9d57f5a8c08528acf2edf3684b1eb38b075637` |
| draft companion | `mtp-gemma-4-12b-it.gguf` |
| draftSizeBytes | `465109248` |
| draftChecksumSha256 | `aed49e55a3d0123a8a13b47667eb8d8198f4237f5e8c7c57829b531c26b34200` |
| verified | true |
| releaseReady | true |
| notes | Current recommended quality target for most matters and larger files. |

### Senior Drafting Support
| Property | Value |
| --- | --- |
| product tier | Senior Drafting Support |
| active model id | `gemma-4-26b-a4b-q4` |
| upstream identity | `google/gemma-4-26B-A4B-it` |
| shipping repo | `unsloth/gemma-4-26B-A4B-it-GGUF` |
| artifact format | GGUF UD-Q4_K_XL |
| file name | `gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf` |
| sizeBytes | `17010978592` |
| checksumSha256 | `7e9c7880585fbf09ab31f3c042bd4c2c20d1c8036441163cdd839fd16670736d` |
| draft companion | `mtp-gemma-4-26B-A4B-it.gguf` |
| draftSizeBytes | `461766816` |
| draftChecksumSha256 | `fb7a81da9da6f2287b5c8b357e9e854d0dfaca4d24eac7d69ab564ad5514e525` |
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
- current Ross package floor: `2.9672.0`
- current resolved revision: `c3e6e06277638dc253c1e2f0ea52aab225343548`
- current upstream binary lane: `llama.cpp` Apple XCFramework `b9672`
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

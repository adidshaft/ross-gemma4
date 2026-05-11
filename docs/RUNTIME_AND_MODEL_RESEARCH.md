# Runtime and Model Research Tracker

## Part 1 — Models needed

### Gemma 4 E2B Instruct
| Property | Value |
| --- | --- |
| product tier | Quick Associate |
| active model id | gemma-4-e2b-q4 |
| upstream identity | google/gemma-4-E2B-it |
| desired artifact format | GGUF Q4_K_M |
| candidate Hugging Face repo URL | __REPLACE_WITH_VERIFIED_HF_REPO_URL__ |
| direct file URL | __REPLACE_WITH_VERIFIED_DIRECT_GGUF_URL__ |
| file name | gemma-4-e2b-q4.gguf |
| sizeBytes | __REPLACE_WITH_VERIFIED_SIZE_BYTES__ |
| checksumSha256 | __REPLACE_WITH_VERIFIED_SHA256__ |
| verified | false |
| releaseReady | false |
| notes | Needs to fit in ~1.6GB |

### Gemma 4 E4B Instruct
| Property | Value |
| --- | --- |
| product tier | Case Associate |
| active model id | gemma-4-e4b-q4 |
| upstream identity | google/gemma-4-E4B-it |
| desired artifact format | GGUF Q4_K_M |
| candidate Hugging Face repo URL | __REPLACE_WITH_VERIFIED_HF_REPO_URL__ |
| direct file URL | __REPLACE_WITH_VERIFIED_DIRECT_GGUF_URL__ |
| file name | gemma-4-e4b-q4.gguf |
| sizeBytes | __REPLACE_WITH_VERIFIED_SIZE_BYTES__ |
| checksumSha256 | __REPLACE_WITH_VERIFIED_SHA256__ |
| verified | false |
| releaseReady | false |
| notes | Needs to fit in ~2.8GB |

### Gemma 4 26B-A4B Instruct
| Property | Value |
| --- | --- |
| product tier | Senior Drafting Support |
| active model id | gemma-4-26b-a4b-q4 |
| upstream identity | google/gemma-4-26B-A4B-it |
| desired artifact format | GGUF Q4_K_M |
| candidate Hugging Face repo URL | __REPLACE_WITH_VERIFIED_HF_REPO_URL__ |
| direct file URL | __REPLACE_WITH_VERIFIED_DIRECT_GGUF_URL__ |
| file name | gemma-4-26b-a4b-q4.gguf |
| sizeBytes | __REPLACE_WITH_VERIFIED_SIZE_BYTES__ |
| checksumSha256 | __REPLACE_WITH_VERIFIED_SHA256__ |
| verified | false |
| releaseReady | false |
| notes | High-end workstation pack, ~16GB |

---

## Part 2 — Runtime needed

### llama.cpp Swift/iOS GGUF runtime candidate
- package URL: `https://github.com/ggerganov/llama.cpp.git`
- package status: Active / Maintained
- supports iOS: Yes
- supports GGUF: Yes
- supports Gemma-family models: Yes
- integration complexity: Medium
- license notes: MIT
- chosen/not chosen: pending verification
- reason: Industry standard for local inference on iOS.

### MLX Swift candidate
- package URL: `https://github.com/ml-explore/mlx-swift.git`
- package status: Active / Maintained by Apple
- supports iOS: Yes
- supports GGUF: No (requires MLX conversion)
- supports Gemma-family models: Yes
- integration complexity: High (requires model format conversion)
- license notes: MIT
- chosen/not chosen: not chosen
- reason: Does not support GGUF natively out of the box, breaking current artifact workflows.

### Local abstraction fallback
- chosen runtime for submission demo: `Gemma4DemoRuntime`
- production runtime: pending verification

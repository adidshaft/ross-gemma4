# Ross Gemma 4 Quality Pass

## Branch Used

- `gemma-4-gguf-model-strategy`

## What Changed

- reduced the exposed lineup to three higher-quality packs
- promoted Gemma 4 12B Q4_K_M into the default Standard tier
- kept Gemma 4 E4B Q4_K_M as the lighter Basic tier
- kept Gemma 4 26B-A4B Q4_K_M as the Advanced tier
- updated backend and shared registry metadata with verified URLs, sizes, and SHA-256 values
- widened iPhone context and input budgets for larger files and smoother on-device use
- updated the iOS llama runtime package floor to `llama.swift` `2.9647.0`
- resolved the newer `llama.cpp` XCFramework (`b9647`)

## Model Mapping

- Basic -> Gemma 4 E4B UD Q4_K_XL, about 5.2 GB
- Standard -> Gemma 4 12B UD Q4_K_XL, about 7.8 GB
- Advanced -> Gemma 4 26B-A4B UD Q4_K_XL, about 17.5 GB
- Flash remains a legacy compatibility tier and is no longer shown in the normal setup catalog

## Current Truth

- The registry and catalog metadata now match the intended 3-pack product lineup.
- The iOS runtime now derives context windows from the active model and device RAM instead of a fixed 4k or 8k cap.
- Prompt chunking and batch sizing are tuned upward for longer local reads.
- The backend still serves tiny deterministic artifacts by default in `dev` mode.
- No model files are committed or bundled in the repository.

## Still Unimplemented

- production delivery of real Q4 files from a trusted distribution path
- Android native Q4 inference and memory tuning
- physical iPhone QA for the 12B pack on representative 8 GB and 12 GB devices
- speculative decoding or MTP-specific runtime proof on iPhone
- MLX-based iPhone pathfinding for cases where converted weights outperform GGUF on-device

## Exact Next Recommended Step

Finish a physical-device validation pass for the new Standard tier: prove download/resume/verify/activate, measure prompt latency on a long matter file, and capture whether the updated llama runtime is sufficient before investing in an MLX-specific iPhone path.

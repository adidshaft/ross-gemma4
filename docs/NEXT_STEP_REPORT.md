# Ross Pause Point

This is the current safe handoff point for the Ross Gemma 4 runtime and product-quality pass as of June 17, 2026.

## Current Stable State

- the exposed assistant lineup is still the intended 3-pack Gemma 4 ladder
- one of those three packs is `gemma-4-12b-it-GGUF`, which remains the Case Associate default
- the iOS GGUF runner is now pinned to `llama.swift` `2.9672.0`, which resolves upstream `llama.cpp` Apple XCFramework `b9672`
- `mlx-swift` remains at `0.31.4`
- `mlx-swift-lm` remains at `3.31.3`
- CoreAI, MLX, and GGUF runtime selection logic is already present on iOS and has been improved further for modern iPhones
- long-file ask handling on iOS now scales source chunk sizing with runtime budget instead of using only the old fixed chunk size
- answer diagnostics stay hidden behind secondary actions instead of adding more up-front UI clutter
- hidden iOS Technical details now retain a short on-device history of sample-file checks so GGUF, MLX, and CoreAI runs can be compared without extra logging setup
- hidden iOS Technical details now also include a longer matter-bundle check for the current runtime, with persisted history for answer preview, source refs, first response, and token speed
- hidden iOS Support details now include a direct runtime switcher for immediately-available lanes on the current tier, so the longer-bundle comparison loop no longer has to go back through setup
- hidden iOS longer-bundle comparison history now also retains runtime-choice, execution-path, and acceleration detail for each run

## Visible Pack Mapping

- Quick Start -> `gemma-4-e4b-q4` -> `unsloth/gemma-4-E4B-it-GGUF`
- Case Associate -> `gemma-4-12b-q4` -> `unsloth/gemma-4-12b-it-GGUF`
- Senior Drafting Support -> `gemma-4-26b-a4b-q4` -> `unsloth/gemma-4-26B-A4B-it-GGUF`
- Flash remains a legacy compatibility tier and is not part of the shipped visible ladder

## Recent Progress

Most recent commits that define this pause point:

- `7030227` `chore: bump ios llama runtime to 2.9672`
- `2f4eff7` `feat: scale ios ask chunking with runtime budget`
- `d925a35` `feat: declutter hidden answer details actions`
- `eff4d55` `fix: reuse installed packaged ios mlx offline`
- `542f69a` `fix: preserve assistant catalog state across resets`
- `d7e7f02` `feat: prefer packaged ios mlx downloads`
- `301b950` `feat: expand android ask runtime budgets`
- `e7ed434` `feat: improve android ask source coverage`

## What Is Verified

- backend production catalog still advertises only the intended 3 GGUF primary packs
- iOS Swift package graph builds against `llama.swift` `2.9672.0`
- focused iOS tests still pass for:
  - higher-budget ask source-pack policy
  - long-page source chunking
  - override-driven chunk sizing
  - llama runtime context and draft-token budget expectations
- MLX and CoreAI decision paths are implemented in code and covered by unit tests
- hidden answer details already include `Tokens processed` and `Token speed`
- hidden iOS Technical details now keep recent sample-file smoke results with runtime, first-response, and token-speed evidence
- hidden iOS Technical details now keep recent longer-bundle comparison runs for the current runtime without adding more front-stage UI
- hidden iOS Support details now expose a direct GGUF / MLX / CoreAI switcher whenever more than one runtime is immediately available for the current tier
- hidden iOS longer-bundle comparison runs now capture why that runtime was selected and whether draft acceleration was active

Most recent verification commands:

- `swift test --package-path ios --filter 'AlphaExtractionTests/(testAskRuntimeSourcePackChunksLongTaggedPageIntoMultipleBlocks|testAskRuntimeSourcePackHonorsChunkSizingFromOverridePolicy)'`
- `swift test --package-path ios --filter 'AlphaExtractionTests/(testLlamaRuntimeProfileExpandsContextFor12BOnCapablePhones|testLlamaRuntimeProfileRaisesDraftTokensOnCapablePhones)'`
- `'/Users/amanpandey/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node' node_modules/tsx/dist/cli.mjs --test tests/model-registry.test.ts`
  Run from `/Users/amanpandey/projects/ross-gemma4/backend`
- `'/Users/amanpandey/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node' backend/node_modules/tsx/dist/cli.mjs --test backend/tests/routes-smoke.test.ts`

## What Is Still Not Proven

- physical iPhone proof for the full GGUF and MLX setup lifecycle on representative 8 GB and 12 GB devices
- final real-device comparison of CoreAI vs MLX vs GGUF on modern iPhones
- production delivery proof for real multi-GB artifacts end to end
- Android compile cleanliness in the current dirty worktree
- Android native runtime validation beyond the recent retrieval and budget improvements

## Why This Is A Good Pause Point

- model selection is no longer in a churn state
- the latest verified iOS llama runner bump is already in
- large-file and context handling moved forward without opening a larger migration
- the next remaining work is mostly validation and final product judgment, not urgent architecture repair

## Exact Resume Step

Resume with a focused real-device validation pass instead of more code changes:

1. verify Case Associate on a physical iPhone using the current GGUF lane
2. compare CoreAI, MLX, and GGUF latency and answer quality on a longer matter bundle, using `Settings > Private AI > Support details` to switch the current runtime directly and rerun `Check private assistant with a longer matter bundle` between passes
3. decide whether the current 3-pack ladder should stay exactly as-is or swap any one pack after evidence
4. only then return to Android cleanup and deeper runtime work there

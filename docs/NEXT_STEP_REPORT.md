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
- hidden iOS Support details now also summarize the latest sample-file check per runtime, so basic readiness proof is easier to confirm before running the longer-bundle comparison
- hidden iOS Technical details now also include a longer matter-bundle check for the current runtime, with persisted history for answer preview, source refs, first response, and token speed
- hidden iOS Support details now include a direct runtime switcher for immediately-available lanes on the current tier, so the longer-bundle comparison loop no longer has to go back through setup
- hidden iOS longer-bundle comparison history now also retains runtime-choice, execution-path, and acceleration detail for each run
- hidden iOS Support details now summarize the latest longer-bundle result per runtime and call out which of GGUF / MLX / CoreAI still need a run
- hidden iOS Support details now surface a small comparison readout from the latest per-runtime runs, including current leaders on first response, token speed, and visible coverage
- hidden iOS Support details now also show a single per-runtime device-proof coverage summary, combining whether each lane already has sample-file evidence, longer-bundle evidence, or both
- hidden iOS Support details now also spell out the exact next device runs still needed from that coverage summary, so the resume path no longer has to be reconstructed by hand
- hidden iOS Support details now also stamp a small device-proof profile with capture source, model identifier, OS version, representative memory class, storage, and device condition so saved evidence is tied more clearly to the actual proof target that produced it
- hidden iOS Support details now also summarize whether CoreAI, MLX, and GGUF are active now, ready now, need setup, need repair, or are unavailable on the current iPhone before the next proof run starts
- hidden iOS Support details can now save the current multi-runtime comparison set into `Notes & Drafts` as a local PDF note, so device QA evidence is easier to keep and share without exposing it in the main flow

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
- hidden iOS Support details now summarize the latest sample-file readiness result per runtime and call out which lanes still need a sample-file pass
- hidden iOS Technical details now keep recent longer-bundle comparison runs for the current runtime without adding more front-stage UI
- hidden iOS Support details now expose a direct GGUF / MLX / CoreAI switcher whenever more than one runtime is immediately available for the current tier
- hidden iOS longer-bundle comparison runs now capture why that runtime was selected and whether draft acceleration was active
- hidden iOS Support details now make it obvious whether the current comparison set already covers all three runtime lanes
- hidden iOS Support details now reduce manual comparison work by surfacing current leaders from the latest three-lane evidence set
- hidden iOS Support details now make it obvious which runtime lanes still lack sample-file proof, longer-bundle proof, or both before the device note is considered complete
- hidden iOS Support details now turn those remaining gaps into ordered next-step guidance in both the hidden view and the exported device note
- hidden iOS Support details can now export the current comparison evidence set straight into `Notes & Drafts` for later device-proof handoff, including the latest per-runtime sample-file readiness snapshot and the current iPhone proof profile
- hidden iOS device-proof note now also includes current lane readiness, so the saved artifact shows which runtime lanes were actually runnable on that iPhone at capture time
- hidden iOS device-proof profile now explicitly says whether the evidence came from a simulator or a physical device and whether it counts as below-target, 8 GB class, or 12 GB+ class evidence

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
3. once all needed lanes have recent evidence, tap `Save runtime comparison note` in hidden `Support details` so the current readout lands in `Notes & Drafts` as the device-QA artifact
4. decide whether the current 3-pack ladder should stay exactly as-is or swap any one pack after evidence
5. only then return to Android cleanup and deeper runtime work there

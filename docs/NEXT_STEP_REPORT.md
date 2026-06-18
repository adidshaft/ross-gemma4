# Ross Pause Point

This is the current safe handoff point for the Ross Gemma 4 runtime and product-quality pass as of June 18, 2026.

## New Safe Stop

- Ross now carries smoke-only MLX memory telemetry around provider setup and generation, which narrowed the prior device kill to the first MLX container load on Aman’s iPhone
- Quick Start MLX is now treated as unsupported on iPhone below `12 GB` in the product-facing support gates, runtime selection flow, installed-runtime activation checks, and MLX runtime resolution
- focused iOS tests covering the new guard now pass, including:
  - Quick Start MLX hidden from below-12 GB iPhone setup options
  - installed Quick Start MLX no longer stays preferred on below-12 GB iPhones
  - Quick Start MLX runtime health now returns `insufficient_device_memory` before model load on below-12 GB iPhones
- after rebuilding and reinstalling on Aman’s cabled iPhone (`3803F5B6-1666-56D3-A71A-62F131F6CE3B`), the same no-draft installed-pack smoke no longer ends with `signal 9`
- current device result from:
  - `scripts/ios-device-installed-pack-smoke.sh --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B --tier quickStart --smoke-profile quick --stage-timeout 30 --disable-draft`
  - now ends with `source_error=insufficient_device_memory` and `general_error=insufficient_device_memory`
  - the app stays alive long enough to report the failure instead of being jetsammed during MLX container load
- the smoke reporting path is now also aligned with the new guard:
  - the same installed-pack smoke now logs `ROSS_LOCAL_MODEL_SMOKE_HEALTH runtime=mlx_swift_lm available=false ... error=insufficient_device_memory`
  - it now stops at `ROSS_LOCAL_MODEL_SMOKE_FAIL ... stage=active_pack error=insufficient_device_memory`
  - it no longer emits misleading `available=true` or `provider_ready` lines for that unsupported lane
- Quick Start policy for below-12 GB iPhones is now explicit in shipped product flow:
  - setup/download/catalog selection now keeps Quick Start on GGUF when MLX is unsupported on the current iPhone
  - explicit Quick Start MLX requests in product setup flow now fall back to GGUF on below-12 GB iPhones instead of preserving the unsupported runtime choice
  - cached/backend catalog helpers now filter unsupported Quick Start MLX entries for that device class instead of letting them remain selectable earlier in setup flow
  - MLX on that device class is now effectively a deliberate debug/runtime-experiment path rather than a shipped setup/download default
- Quick Start GGUF metadata is now reconciled with the current provider checksum contract:
  - the shipped Quick Start GGUF main artifact and draft companion now pin the live `x-linked-etag` values Ross actually validates during preflight, instead of the older Xet reconstruction hashes
  - the iOS bundled metadata, backend production metadata, and focused metadata/session tests now all agree on those updated Quick Start checksum pins
- on June 18, 2026, a fresh bounded assistant-download smoke on Aman’s cabled iPhone (`3803F5B6-1666-56D3-A71A-62F131F6CE3B`) also proved the intended below-target Quick Start lane moved forward again:
  - `scripts/ios-device-assistant-download-smoke.sh --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B --tier quickStart --mobile-allowed --force-refresh --wait-seconds 90`
  - before the checksum-pin fix, the same `auto` smoke selected `pack=gemma-4-e4b-q4 runtime=gemma_local_runtime` and failed immediately with `The assistant download listing changed before setup could start.`
  - after the checksum-pin fix, the same smoke still auto-selects `pack=gemma-4-e4b-q4 runtime=gemma_local_runtime` but now gets through preflight and into a real GGUF transfer, reaching `bytes=3098452346 total=5224958176` before timing out on the artificial `90 s` harness budget
- Quick Start GGUF now also carries a constrained E4B runtime profile for 7 GB-class phones, so the real production pack no longer falls into the old aggressive decimal-byte lane on Aman's current iPhone:
  - `n_gpu_layers` now drops from the previous `99` all-GPU path to `20`
  - the same constrained lane now uses `n_ctx = 8192`, `n_batch = 768`, `n_ubatch = 512`, `draftTokens = 2`, and the smaller `22_000` quick-start input budget
  - focused iOS tests now pass for that bounded profile shift, including the new 7 GB-class E4B expectations
- after rebuilding and reinstalling that constrained profile on Aman’s cabled iPhone, the real manifest-backed production Quick Start GGUF pack now gets materially farther into runtime setup:
  - `scripts/ios-device-installed-pack-smoke.sh --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B --tier quickStart --runtime gguf --smoke-profile quick --stage-timeout 30`
  - the smoke selects the real app-private pack `gemma-4-e4b-q4`, reports `Using n_gpu_layers = 20`, and reaches real context/KV setup instead of the earlier immediate `n_gpu_layers = 99` Metal-allocation failure
  - with draft still enabled, the phone still gets terminated by `signal 9`, but only after the runtime has already allocated about `5314 MiB` of the device's `5461 MiB` recommended GPU working set
- the same constrained Quick Start GGUF lane now also exposes a clearer no-draft blocker instead of only another jetsam:
  - `scripts/ios-device-installed-pack-smoke.sh --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B --tier quickStart --runtime gguf --smoke-profile quick --stage-timeout 30 --disable-draft`
  - the real pack still selects `n_gpu_layers = 20` and completes model/KV setup with `n_ctx = 8192`
  - the terminal failure has now moved to a concrete llama.cpp scheduler assertion, `GGML_ASSERT(n_inputs < GGML_SCHED_MAX_SPLIT_INPUTS)`, followed by `signal 6`
- this is the current preferred pause point for the below-target Quick Start GGUF lane:
  - download/session/checksum/catalog work is now behaving as intended on the physical phone
  - the next meaningful pass is a llama.cpp offload/scheduler compatibility fix for this constrained E4B lane, not another catalog or installer change

## Latest MLX Runtime Checkpoint

- Ross now carries a runtime-only shared-KV shim in `AlphaMLXLocalProvider`, so Gemma 4 QAT packs that omit shared-layer `k_proj` / `v_proj` / `k_norm` tensors can still load without mutating the installed pack directory
- the iOS package graph is now temporarily pinned to `mlx-swift-lm` revision `774607e8cdbc5ebdfeab1f9016ef9424a7ca23fc`, which matches the upstream Gemma 4 E-series `per_layer_model_projection` quantization fix discussed in official PR `#320`
- focused iOS tests still pass after that pin, and the iOS device build/install still succeeds on Aman's cabled iPhone (`3803F5B6-1666-56D3-A71A-62F131F6CE3B`)
- the earlier Gemma 4 installed-pack runtime failures have now moved twice:
  - first blocker removed: missing shared-KV tensor key `language_model.model.layers.24.self_attn.v_proj.weight`
  - second blocker removed: mismatched `language_model.model.per_layer_model_projection.weight` shape (`actual [10752, 320]`, `expected [10752, 2560]`)
- the current real-device blocker is now later in execution: the real manifest-backed production Quick Start MLX pack (`gemma-4-e4b-mlx`) reaches `provider_ready` and begins the source-grounded smoke stage, then the app is terminated by `signal 9`
- that crash path has now been converted into a safe refusal on the same phone:
  - the same installed-pack smoke now finishes with `insufficient_device_memory` instead of `signal 9`
  - this is the current preferred pause point because the product no longer walks into the jetsam path on the physical device
- that new blocker reproduced twice on the same phone with the same installed production pack:
  - `scripts/ios-device-installed-pack-smoke.sh --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B --tier quickStart --smoke-profile quick --stage-timeout 15`
  - `scripts/ios-device-installed-pack-smoke.sh --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B --tier quickStart --smoke-profile quick --stage-timeout 30`
- both runs produced the same latest signal:
  - `ROSS_LOCAL_MODEL_SMOKE_STAGE provider_ready runtime=mlx_swift_lm`
  - `ROSS_LOCAL_MODEL_SMOKE_STAGE source timeout=...`
  - `App terminated due to signal 9.`
- a true no-draft comparison is now also in place:
  - `scripts/ios-device-installed-pack-smoke.sh --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B --tier quickStart --smoke-profile quick --stage-timeout 30 --disable-draft`
  - the smoke reports `draft_disabled=true`, `acceleration=standard`, and still ends in `App terminated due to signal 9.`
- the first copied crash and jetsam artifacts clarified that there were really two failure modes on device:
  - `Ross-2026-06-18-184817.ips` showed a `FRONTBOARD` `0x8BADF00D` scene-create watchdog on launch with the main thread blocked in onboarding/runtime-health UI work
  - `JetsamEvent-2026-06-18-185549.ips` showed `largestProcess : "Ross"` with `reason : "per-process-limit"` at `rpages : 216081`
- Ross now avoids the specific launch-time FoundationModels context-size probe that appeared in that watchdog stack:
  - `AlphaFoundationModelsLocalProvider.runtimeHealth()` now uses the existing Foundation heuristic budgets for `estimatedContextTokens` and `maxInputChars` instead of synchronously asking `SystemLanguageModel.contextSize`
  - focused iOS tests still pass after that change, and the rebuilt app still installs successfully on Aman's cabled iPhone
- after that heuristic-only runtime-health patch, the same no-draft installed-pack smoke now gets cleanly through launch, `provider_ready`, and into the source stage before the kill, which strongly suggests the earlier scene-create watchdog path has been mitigated even though the later MLX `signal 9` remains

## Immediate Resume Target

Resume from the new physical-device checkpoint above, not from the older Gemma 4 loader mismatches.

1. treat the shared-KV missing-key bug and the `per_layer_model_projection` shape bug as cleared checkpoints for the current repo state
2. treat the old launch-time watchdog and the later MLX `signal 9` path on Aman’s phone as mitigated for the current product flow, because the app now refuses the unsupported lane instead of crashing
3. treat the smoke/runtime-health reporting mismatch as cleared for the current repo state:
   - the smoke path now agrees with the device-support guard and refuses the unsupported lane before `provider_ready`
4. treat the product-policy decision as made for the current repo state:
   - below-12 GB iPhones keep Quick Start on GGUF in shipped setup/download/catalog flow
   - any later Quick Start MLX work on that device class should stay behind deliberate debug/runtime experimentation until a new physical-device proof changes the policy
5. only after that policy decision should the next pass revisit any deeper MLX memory experiments on physical hardware

## Current Stable State

- the exposed assistant lineup is still the intended 3-pack Gemma 4 ladder
- one of those three packs is `gemma-4-12b-it-GGUF`, which remains the Case Associate default
- the iOS GGUF runner is now pinned to `llama.swift` `2.9672.0`, which resolves upstream `llama.cpp` Apple XCFramework `b9672`
- `mlx-swift` remains at `0.31.4`
- the active iOS package graph now temporarily pins `mlx-swift-lm` to revision `774607e8cdbc5ebdfeab1f9016ef9424a7ca23fc` on top of the prior `3.31.3` baseline while the upstream Gemma 4 E-series fix is still pending a normal release
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
- hidden iOS Support details now also summarize saved device-comparison note coverage across the physical 8 GB and 12 GB+ proof targets, so repeated exports make it obvious which real-device comparison class is still missing
- hidden iOS Support details now also surface any saved below-target physical iPhone proof as its own coverage line, so smaller-phone guardrail evidence is visible without changing the final 8 GB / 12 GB+ ladder gate
- hidden iOS Support details and the exported runtime comparison note now also state directly that saved below-target proof is guardrail evidence only and does not replace the required 8 GB / 12 GB+ comparison notes
- hidden iOS Support details now also turn that saved-note history into a final device-comparison readiness summary with concrete next physical-note steps, so the ladder decision is gated on saved 8 GB and 12 GB+ proof instead of memory
- hidden iOS Support details and the saved note now also state the ladder-decision gate directly, so the product itself says whether pack-selection review is unlocked or still waiting on specific physical-device notes
- Android debug compile and assemble now succeed in the current dirty worktree, so the remaining Android gap is narrowed to real runtime validation rather than baseline build breakage
- backend production download sessions now prove that the default 12B and 26B iOS GGUF packs preserve their real multi-GB size, byte-range resume metadata, and direct delivery URLs end to end through signed session payloads
- backend production download sessions now also prove the default Quick Start iOS GGUF pack and draft companion preserve their current provider-aligned checksum pins end to end, closing the metadata gap that was aborting below-target Quick Start setup before download
- iOS assistant download descriptors now preserve multi-GB segment and byte-range resume metadata from signed backend sessions, and bundled GGUF defaults now expose the same single-segment range assumptions on the client side
- iOS installer acceptance now rejects assistant downloads whose delivery metadata falls outside the current client contract, so unsupported range units or resume strategies fail before real download begins
- iOS installer acceptance now also enforces the current single-segment artifact contract directly, so multi-segment or mismatched segment-size payloads are rejected until the client has real segmented-download support
- hidden iOS Support details and the saved runtime comparison note now also summarize the current assistant download delivery contract and latest on-device verification status, so physical-device proof exports can carry delivery-check evidence alongside runtime comparisons
- hidden iOS Support details and the saved runtime comparison note now also distinguish verified assistant download delivery from saved runtime-consumption proof for that downloaded lane, so the remaining end-to-end device gap is explicit instead of being inferred by hand
- saved physical iPhone comparison-note records now also persist whether the note included a verified assistant download delivery check, and device-target readiness now treats missing delivery verification as incomplete physical proof even when runtime coverage is otherwise present
- hidden iOS saved device-proof coverage now also shows the persisted delivery-check status and delivery contract per saved target, so later reviews can tell which physical note actually carried verified download evidence without reopening the PDF
- hidden iOS saved device-proof coverage and the exported runtime comparison note now also show when the latest saved physical note was captured for each target, so evidence recency is easier to audit before the next ladder decision review
- hidden iOS saved device-proof coverage and the exported runtime comparison note now also show the saved PDF filename for each target, so QA review can jump straight to the exact `Notes & Drafts` artifact that currently counts as proof
- hidden iOS saved device-proof coverage and the exported runtime comparison note now also show the saved system version for each target, so later review can tell which iOS build produced the current proof artifact without reopening the PDF
- hidden iOS saved device-proof coverage and the exported runtime comparison note now also show the saved device state for each target, including free storage, low-power mode, and thermal state, so later comparison review can spot constrained-device evidence without reopening the PDF
- hidden iOS saved device-proof coverage and the exported runtime comparison note now also persist the saved runtime blocker when one is known, so below-target or failed-lane evidence keeps the concrete reason instead of only a generic target label
- the current iOS Debug build now also compiles, installs, and foreground-launches on Aman's physical iPhone (`iPhone16,1` on iOS `27.0`), so the next iPhone step is runtime proof rather than device bring-up
- the repo now also includes a cabled-device GGUF smoke helper at `scripts/ios-device-gguf-smoke.sh`, so physical iPhone GGUF reruns no longer depend on reconstructing the app-container path by hand
- the repo now also includes an installed-pack cabled-device smoke helper at `scripts/ios-device-installed-pack-smoke.sh`, so Ross can now target manifest-backed packs directly from app-private storage on a physical iPhone without copying multi-GB artifacts back out first
- the installed-pack helper now also supports a `quick` smoke profile for shorter cabled-device consumption checks, so physical-device validation can request a source-grounded pass/fail signal without paying for the full multilingual smoke every time
- the intended `Case Associate` 12B GGUF artifact has now also been staged and opened on Aman's physical iPhone through that helper, and the observed blocker on this exact device is now a concrete `mmap failed: Cannot allocate memory` load failure rather than a bring-up unknown
- Android Technical details smoke reporting now also stamps device model, Android version, free storage, low-power mode, and thermal state, so the eventual physical-device MediaPipe proof carries the same basic device context without hand-written notes

## Visible Pack Mapping

- Quick Start -> `gemma-4-e4b-q4` -> `unsloth/gemma-4-E4B-it-GGUF`
- Case Associate -> `gemma-4-12b-q4` -> `unsloth/gemma-4-12b-it-GGUF`
- Senior Drafting Support -> `gemma-4-26b-a4b-q4` -> `unsloth/gemma-4-26B-A4B-it-GGUF`
- Flash remains a legacy compatibility tier and is not part of the shipped visible ladder

## Recent Progress

Most recent commits that define this pause point:

- `36b9e99` `feat: show ios proof device state`
- `6864171` `feat: show ios proof note system versions`
- `1d8b67a` `feat: show ios proof note filenames`
- `ef81cd1` `feat: stamp ios proof note capture times`
- `6a6ae7c` `feat: clarify ios proof rerun guidance`
- `bb1c586` `feat: show saved ios delivery proof details`
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
- hidden iOS sample-file and longer-bundle evidence now also persist which assistant and model source each saved run used, so later review can tell built-in CoreAI, MLX, and GGUF proofs apart without reopening runtime internals
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
- hidden iOS saved comparison-note history now tracks whether a physical 8 GB or physical 12 GB+ device note has already been captured, and whether that saved note covered the full three-runtime comparison
- hidden iOS saved comparison-note coverage now explicitly says whether the final device-comparison proof is ready for ladder review or which physical note still needs to be saved or rerun
- hidden iOS saved comparison-note coverage now also shows saved below-target physical iPhone proof separately when it exists, while keeping ladder-decision readiness tied to the required 8 GB and 12 GB+ targets
- hidden iOS saved comparison-note coverage now also spells out that below-target proof only confirms the smaller-phone guardrail and does not count as a substitute for the required decision-gate targets
- hidden iOS ladder-decision readiness is now exported alongside the device note, so final pack judgment is explicitly held until the missing physical-note targets are complete
- the current iOS app bundle now builds for `iphoneos`, installs onto Aman's physical iPhone, and stays up after a foreground launch from `devicectl`
- the current iPhone now also proves a real on-device GGUF smoke pass through the cabled-device helper and `--local-model-smoke`, using the local `gemma-2-2b-it-Q4_K_M.gguf` artifact as a Quick Start debug pack on the physical phone
- the current iPhone now also proves that the intended `gemma-4-12b-it-UD-Q4_K_XL.gguf` artifact reaches the phone, opens in the real GGUF load path, and then fails specifically on memory mapping with `Cannot allocate memory`, with the device reporting `System physical memory: 7 GB`
- the current iPhone now also proves that Ross app-private installed packs can be enumerated over `devicectl`, and the helper currently finds only seeded `-device-proof` manifests for `quickStart` and `caseAssociate` on that phone rather than a true client-downloaded production pack
- the installed-pack cabled-device smoke helper now also refuses those seeded manifests by default, so a missing real client-download proof on the phone is surfaced immediately instead of being mistaken for production download evidence
- with explicit `--allow-device-proof-pack`, the installed-pack helper now also reaches the live GGUF load path for the already-installed Quick Start artifact on Aman's phone, including provider resolution, model load, KV/cache allocation, and a real local completion attempt against the app-container model path
- the updated installed-pack helper and `quick` smoke profile now also produce a structured on-device failure for that seeded Quick Start artifact instead of an ambiguous hang: on Aman's phone the source-grounded stage completed successfully in `6357 ms`, then the general no-source stage timed out after `15 s`, yielding `ROSS_LOCAL_MODEL_SMOKE_FAIL ... profile=quick ... general_error=smoke_stage_timeout_general`
- the current iPhone now also proves that a real client-downloaded manifest-backed production Quick Start GGUF pack exists in app-private storage and is selectable through the installed-pack helper: `tier=quick_start pack=gemma-4-e4b-q4 runtime=gemma_local_runtime file=gemma-4-E4B-it-UD-Q4_K_XL.gguf size=5.13 GB draft=mtp-gemma-4-E4B-it.gguf`
- the constrained Quick Start GGUF E4B runtime profile is now in code and covered by focused iOS tests, keeping 7 GB-class phones on the smaller `n_gpu_layers = 20`, `n_ctx = 8192`, `n_batch = 768`, `n_ubatch = 512`, and `draftTokens = 2` lane instead of the old aggressive decimal-byte branch
- with that constrained lane installed on Aman's phone, the real production Quick Start GGUF pack now gets beyond the earlier `n_gpu_layers = 99` Metal-allocation cliff:
  - with draft enabled, it still ends in `signal 9`, but only after loading the real production pack and allocating roughly `5314 MiB` of the `5461 MiB` recommended GPU working set
  - with `--disable-draft`, it now reaches full model/context/KV setup and exposes a concrete llama.cpp scheduler assertion, `GGML_ASSERT(n_inputs < GGML_SCHED_MAX_SPLIT_INPUTS)`, followed by `signal 6`
- the current below-target Quick Start GGUF blocker has therefore moved from checksum/download failure to llama.cpp runtime compatibility on the constrained E4B lane
- Ross production metadata now also pins the downloaded 12B GGUF bytes hash `ee33ab5be8e07aca1c269fc645eaed5f3298e089d52db29415839d8f29957020`, reconciling the earlier mismatch with the CDN/Xet `etag` value observed during the physical-device proof pass
- below-target iPhones now also treat the `Case Associate` 12B GGUF lane as unavailable up front instead of merely broken: the shipped minimum memory floor is now 12 GB for that pack, the hidden runtime-lane readiness copy reports it as unavailable on this iPhone, and the phone-side runtime chooser now prefers MLX for `Case Associate` when GGUF would not fit
- below-target iPhones now also stop offering the unsupported `Case Associate` GGUF lane in setup/runtime variant chips, so smaller phones are steered toward viable MLX or built-in lanes instead of advertising a path that cannot activate there
- below-target iPhones now also keep Quick Start on GGUF through shipped setup/download/catalog selection instead of letting explicit or cached MLX choices survive earlier in product flow
- below-target iPhones now also get past the stale Quick Start GGUF checksum guard: the shipped `auto` setup lane still chooses `gemma-4-e4b-q4` on Aman's phone, and a fresh bounded device smoke now proves that lane reaches real download progress instead of failing immediately with the old listing-changed error
- Android debug build now completes cleanly in the current worktree after clearing the lingering Kotlin annotation-target warning in `AlphaRossApp.kt`
- backend model-registry tests now explicitly cover signed multi-GB delivery descriptors for the default iOS `Case Associate` and `Senior Drafting Support` GGUF packs
- backend model-registry tests now explicitly cover the default iOS `Quick Start` GGUF pack and draft checksum pins in the same signed-session contract that already covered the larger GGUF lanes
- focused iOS extraction tests now prove the client preserves multi-GB GGUF session metadata for segment size, segment count, range unit, and resume strategy, and that bundled GGUF defaults expose the same single-segment byte-range assumptions before device download begins
- focused iOS extraction tests now also prove the installer rejects backend artifacts or cached download descriptors that advertise unsupported delivery metadata, instead of carrying them into a broken client download path
- focused iOS extraction tests now also prove the installer rejects multi-segment or mismatched single-segment delivery metadata, so the current client contract stays aligned with the single full-artifact GGUF path it actually knows how to verify and download
- focused iOS tests now also prove the device-proof export path includes download delivery verification details, and that the summary helper reports signed-session GGUF delivery as verified when the on-device ledger already recorded a verified assistant download check
- focused iOS tests now also prove the download-proof summary distinguishes whether the downloaded lane has actually been consumed in saved sample-file and longer-bundle runtime evidence, so later device review can see when delivery verification still lacks runtime consumption proof
- focused iOS usability tests now also prove that saved device-proof targets remain incomplete until the exported note includes a verified download delivery check, and that the rerun guidance and ladder-decision readiness text follow that stricter proof rule
- focused iOS usability tests now also prove the saved proof export includes persisted delivery-check details for each saved physical target, so proof history stays auditable after multiple exports
- focused iOS usability tests now also prove the saved proof export includes the saved-note capture timestamp for each physical target, so later reviewers can tell when the current 8 GB or 12 GB+ evidence was actually recorded
- focused iOS usability tests now also prove the saved proof export includes the saved PDF filename for each physical target, so later reviewers can open the exact proof artifact instead of inferring which `Notes & Drafts` entry was current
- focused iOS usability tests now also prove the exported sample-file and longer-bundle summaries retain per-run assistant and model-source provenance, so saved device notes make the actual CoreAI / MLX / GGUF lane used by each result explicit
- focused iOS usability tests now also prove the saved proof export includes the saved system version for each physical target, so later reviewers can tell which iOS build produced the latest counted proof artifact
- focused iOS usability tests now also prove the saved proof export includes the saved device state for each physical target, so later reviewers can spot low-storage or throttled-device evidence without reopening the saved note
- focused iOS usability tests now also prove that saved below-target proof records retain an observed runtime blocker summary, and that exports surface that blocker alongside the rest of the saved device-proof metadata
- focused iOS usability tests now also prove that saved below-target proof carries an explicit guardrail-only note, so later reviewers do not mistake it for the required 8 GB / 12 GB+ ladder-decision evidence
- focused Android unit tests now also prove the local smoke report still captures a device proof profile even when the real runtime is unavailable, so later physical-device smoke evidence can include model, Android version, and device-state context
- a physical iPhone GGUF smoke now also passes through the cabled-device helper with `source_native_model=true`, `bengali_native_model=true`, `hindi_native_model=true`, `tamil_native_model=true`, `telugu_native_model=true`, and `general_native_model=true`
- the repo now also includes an iPhone assistant-download smoke helper at `scripts/ios-device-assistant-download-smoke.sh`, plus a dedicated `--assistant-download-smoke` launch mode that can trigger, observe, and report real production assistant downloads from the phone over `devicectl`
- on June 18, 2026, Aman's cabled `iPhone 15 Pro` (`iPhone16,1`, iOS `27.0`) also proved that the production `quickStart` MLX pack `gemma-4-e4b-mlx` starts a real client download on device and can complete the full `6927877785`-byte transfer on phone
- the first terminal physical-device failure after that full transfer was a real checksum-verification stop in Ross, and the smoke-only technical line exposed the underlying app error directly as `domain=RossAlphaPack code=2 detail=Checksum verification failed.`
- the bundled direct-MLX checksum pins for `gemma-4-E4B-it-qat-4bit`, `gemma-4-E4B-it-qat-assistant-6bit`, `gemma-4-12B-it-qat-4bit`, and `gemma-4-12B-it-qat-assistant-4bit` have now been updated to match Ross's on-device sorted manifest-row digest contract rather than the earlier stale values
- that checksum fix surfaced the next real bug in the client flow: Ross was still sweeping `tmp/ross-pending-*` artifacts during multi-part assistant setup, which deleted the already-downloaded main MLX directory when the draft companion download started
- the temp-sweep preservation fix is now in place and covered by focused tests, and the current smoke-only tracing plus SHA-256 `autoreleasepool` fix moved the latest physical-device run all the way through both multi-GB MLX shard hashes instead of dying mid-verify
- the direct-MLX checksum contract is now reconciled with what Ross actually verifies on device: the bundled `mlx_directory` pins were updated from the earlier Hugging Face repository-tree digests to Ross's own sorted manifest-row digest contract
- with those corrected digest pins in place, Aman's cabled `iPhone 15 Pro` now completes the full real `quickStart` MLX production install on device: the latest smoke reached `verify_artifact_done`, `install_artifact_move_success`, `manifest_write_done`, `runtime_validation_done`, and ended in `ROSS_ASSISTANT_DOWNLOAD_SMOKE_PASS elapsed=216.35s`
- `scripts/ios-device-installed-pack-smoke.sh --list-only` now also shows a real non-seeded manifest-backed production pack on the phone: `tier=quick_start pack=gemma-4-e4b-mlx runtime=mlx_swift_lm file=gemma-4-E4B-it-qat-4bit size=6.83 GB draft=gemma-4-E4B-it-qat-assistant-6bit`
- the current blocking state on Aman's phone has moved again: runtime consumption from that real installed MLX pack now reaches `provider_ready` and then fails during inference with a concrete MLX loader/update error rather than a download or install issue
- the latest installed-pack quick smoke without `--allow-device-proof-pack` exposed that technical failure directly as `domain=MLXNN.UpdateError code=3 detail=Key language_model.model.layers.24.self_attn.v_proj.weight not found in Gemma4Model.Gemma4TextModel.Gemma4TextModelInner.Gemma4DecoderLayer.Gemma4Attention.Linear`
- a resilience retry that falls back from speculative draft generation to standard MLX generation is now in the code and covered by a focused unit test, but this specific device failure still reproduces, which strongly suggests the incompatibility is in the main installed quick-start MLX weights or architecture contract rather than only in the draft companion

Most recent verification commands:

- `swift test --package-path ios --filter 'AlphaExtractionTests/(testAskRuntimeSourcePackChunksLongTaggedPageIntoMultipleBlocks|testAskRuntimeSourcePackHonorsChunkSizingFromOverridePolicy)'`
- `swift test --package-path ios --filter 'AlphaExtractionTests/(testLlamaRuntimeProfileExpandsContextFor12BOnCapablePhones|testLlamaRuntimeProfileRaisesDraftTokensOnCapablePhones)'`
- `swift test --package-path ios --filter 'AlphaExtractionTests/(testAssistantDownloadDescriptorPreservesMultiGBSessionDeliveryMetadata|testDefaultAssistantDownloadDescriptorUsesSingleSegmentByteRangeDefaultsForGGUF)'`
- `swift test --package-path ios --filter 'AlphaExtractionTests/(testAssistantDownloadDescriptorPreservesMultiGBSessionDeliveryMetadata|testDefaultAssistantDownloadDescriptorUsesSingleSegmentByteRangeDefaultsForGGUF|testAssistantDownloadDescriptorSupportsCurrentInstallerAllowsDirectMLXRepository|testAssistantDownloadDescriptorSupportsCurrentInstallerAllowsMLXDraftCompanion|testAssistantDownloadDescriptorSupportsCurrentInstallerRejectsUnsupportedRangeUnit|testAssistantDownloadDescriptorSupportsCurrentInstallerRejectsUnsupportedResumeStrategy|testAssistantDownloadDescriptorSupportsCurrentInstallerRejectsOptiQRepository|testAssistantDownloadDescriptorSupportsCurrentInstallerRejectsOptiQDraftCompanion|testBackendArtifactSupportsCurrentInstallerAllowsDirectMLXRepository|testBackendArtifactSupportsCurrentInstallerRejectsUnsupportedRangeUnit|testBackendArtifactSupportsCurrentInstallerRejectsUnsupportedResumeStrategy|testBackendArtifactSupportsCurrentInstallerRejectsOptiQRepository|testBackendArtifactSupportsCurrentInstallerAllowsMLXDraftCompanion)'`
- `swift test --package-path ios --filter 'AlphaExtractionTests/(testAssistantDownloadDescriptorPreservesMultiGBSessionDeliveryMetadata|testDefaultAssistantDownloadDescriptorUsesSingleSegmentByteRangeDefaultsForGGUF|testAssistantDownloadDescriptorSupportsCurrentInstallerAllowsDirectMLXRepository|testAssistantDownloadDescriptorSupportsCurrentInstallerAllowsMLXDraftCompanion|testAssistantDownloadDescriptorSupportsCurrentInstallerRejectsUnsupportedRangeUnit|testAssistantDownloadDescriptorSupportsCurrentInstallerRejectsUnsupportedResumeStrategy|testAssistantDownloadDescriptorSupportsCurrentInstallerRejectsMultiSegmentMetadata|testAssistantDownloadDescriptorSupportsCurrentInstallerRejectsMismatchedSingleSegmentSize|testAssistantDownloadDescriptorSupportsCurrentInstallerRejectsOptiQRepository|testAssistantDownloadDescriptorSupportsCurrentInstallerRejectsOptiQDraftCompanion|testBackendArtifactSupportsCurrentInstallerAllowsDirectMLXRepository|testBackendArtifactSupportsCurrentInstallerAllowsMLXDraftCompanion|testBackendArtifactSupportsCurrentInstallerRejectsUnsupportedRangeUnit|testBackendArtifactSupportsCurrentInstallerRejectsUnsupportedResumeStrategy|testBackendArtifactSupportsCurrentInstallerRejectsMultiSegmentMetadata|testBackendArtifactSupportsCurrentInstallerRejectsMismatchedSingleSegmentSize|testBackendArtifactSupportsCurrentInstallerRejectsOptiQRepository)'`
- `swift test --package-path ios --filter '(AlphaExtractionTests/testAssistantDownloadDeliveryVerificationSummaryUsesSignedSessionAndVerifiedLedgerEntry|AlphaLawyerUsabilityTests/testMatterBundleComparisonExportBodyLinesIncludeReadoutAndLatestRuntimeDetails|AlphaLawyerUsabilityTests/testSaveMatterBundleComparisonExportCreatesNotesDraft)'`
- `swift test --package-path ios --filter '(AlphaLawyerUsabilityTests/testPrivateAIDeviceComparisonProofStatusesTrackSavedCoverageByTarget|AlphaLawyerUsabilityTests/testPrivateAIDeviceComparisonProofStatusesTreatMissingDeliveryVerificationAsIncomplete|AlphaLawyerUsabilityTests/testMatterBundleComparisonExportBodyLinesIncludeReadoutAndLatestRuntimeDetails|AlphaLawyerUsabilityTests/testSaveMatterBundleComparisonExportCreatesNotesDraft|AlphaExtractionTests/testAssistantDownloadDeliveryVerificationSummaryUsesSignedSessionAndVerifiedLedgerEntry)'`
- `./gradlew :app:compileDebugKotlin`
- `./gradlew :app:assembleDebug`
- `./gradlew :app:testDebugUnitTest --tests 'com.ross.android.alpha.AlphaLawyerUsabilityTest.local inference smoke unavailable still captures android device proof profile'`
- `xcodebuild -project ios/Ross.xcodeproj -scheme Ross -destination 'id=00008130-000C74820130001C' -derivedDataPath ios/build-device build`
- `xcrun devicectl device install app --device '00008130-000C74820130001C' ios/build-device/Build/Products/Debug-iphoneos/Ross.app`
- `xcrun devicectl device process launch --device '00008130-000C74820130001C' --terminate-existing com.ross.ios`
- `scripts/ios-device-gguf-smoke.sh --device 00008130-000C74820130001C --model /Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf --tier quickStart --stage-timeout 45`
- `swift test --package-path ios --filter 'AlphaExtractionTests/(testCanonicalRuntimeConfigParsesEnvironment|testCanonicalRuntimeConfigParsesMLXEnvironment|testDebugLocalModelSmokePackUsesTierAndPackIDOverrides|testLocalModelSmokeProfileParsesQuickAliases)'`
- `xcodebuild -project ios/Ross.xcodeproj -scheme Ross -destination 'id=3803F5B6-1666-56D3-A71A-62F131F6CE3B' -derivedDataPath ios/build-device build`
- `xcrun devicectl device install app --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B ios/build-device/Build/Products/Debug-iphoneos/Ross.app`
- `scripts/ios-device-installed-pack-smoke.sh --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B --tier quickStart --allow-device-proof-pack --smoke-profile quick --stage-timeout 15`
- `swift test --package-path ios --filter 'AlphaExtractionTests/(testLocalModelSmokeProfileParsesQuickAliases|testAssistantDownloadSmokeConfigParsesTierRuntimeAndFlags|testAssistantDownloadSmokeConfigRequiresTier|testAssistantDownloadSmokeJobPrefersMostRecentMatchingJob|testDebugLocalModelSmokePackUsesTierAndPackIDOverrides)'`
- `xcodebuild -project ios/Ross.xcodeproj -scheme Ross -destination 'id=3803F5B6-1666-56D3-A71A-62F131F6CE3B' -derivedDataPath ios/build-device build`
- `xcrun devicectl device install app --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B ios/build-device/Build/Products/Debug-iphoneos/Ross.app`
- `scripts/ios-device-assistant-download-smoke.sh --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B --tier quickStart --runtime mlx --mobile-allowed --force-refresh --wait-seconds 900`
- `scripts/ios-device-assistant-download-smoke.sh --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B --tier quickStart --runtime mlx --mobile-allowed --wait-seconds 180`
- `swift test --package-path ios --filter 'AlphaExtractionTests/(testLlamaRuntimeProfileRaisesHighQualityInputBudgets|testLlamaRuntimeProfileUsesModelAwareGPUOffload|testLlamaRuntimeProfileEnablesBroaderBatching|testLlamaRuntimeProfileUsesConstrainedQuickStartE4BProfileFor7GBClassDevice|testLlamaRuntimeProfileRaisesDraftTokensOnCapablePhones)'`
- `xcodebuild -project ios/Ross.xcodeproj -scheme Ross -destination 'id=3803F5B6-1666-56D3-A71A-62F131F6CE3B' -derivedDataPath ios/build-device build`
- `xcrun devicectl device install app --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B ios/build-device/Build/Products/Debug-iphoneos/Ross.app`
- `scripts/ios-device-installed-pack-smoke.sh --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B --tier quickStart --runtime gguf --smoke-profile quick --stage-timeout 30`
- `scripts/ios-device-installed-pack-smoke.sh --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B --tier quickStart --runtime gguf --smoke-profile quick --stage-timeout 30 --disable-draft`
- `'/Users/amanpandey/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node' backend/node_modules/tsx/dist/cli.mjs --test --test-name-pattern 'ios production sessions preserve multi-gb GGUF delivery descriptors end to end' backend/tests/model-registry.test.ts`
- `swift test --package-path ios --filter 'AlphaExtractionTests/testReleaseReadyAssistantArtifactsPinDownloadMetadata'`
- `swift test --package-path ios --filter 'AlphaExtractionTests/(testRecommendedOnDeviceTierMatchesCurrentThreeTierProductLineup|testPreferredAssistantRuntimeModeUsesMLXForCaseAssociateBelow12GBPhoneFloor|testLlamaRuntimeHealthMarks12BPackUnavailableOnBelowTargetPhoneMemory)'`
- `swift test --package-path ios --filter 'AlphaExtractionTests/(testAssistantVariantOptionsIncludeDownloadableRuntimesForFreshSetup|testAssistantVariantOptionsKeepInstalledSelectionAndOfferDownloadableAlternate|testAssistantVariantOptionsHideUnsupportedCaseAssociateGGUFOnBelow12GBPhone|testAssistantVariantOptionsHideInstalledUnsupportedCaseAssociateGGUFOnBelow12GBPhone|testRecommendedOnDeviceTierMatchesCurrentThreeTierProductLineup|testPreferredAssistantRuntimeModeUsesMLXForCaseAssociateBelow12GBPhoneFloor|testLlamaRuntimeHealthMarks12BPackUnavailableOnBelowTargetPhoneMemory)'`
- `swift test --package-path ios --filter 'AlphaLawyerUsabilityTests/(testPrivateAIDeviceComparisonProofStatusesShowBelowTargetProofWithoutBlockingDecisionGate|testPrivateAIDeviceComparisonProofRecordBuildsBelowTargetRuntimeBlockerSummary|testPrivateAIDeviceComparisonProofRecordPrefersLatestFailedJobReasonAsRuntimeBlocker|testMatterBundleComparisonExportBodyLinesIncludeReadoutAndLatestRuntimeDetails|testSaveMatterBundleComparisonExportCreatesNotesDraft)'`
- `swift test --package-path ios --filter 'AlphaLawyerUsabilityTests/(testPrivateAIDeviceComparisonProofStatusesShowBelowTargetProofWithoutBlockingDecisionGate|testMatterBundleComparisonExportBodyLinesIncludeReadoutAndLatestRuntimeDetails|testSaveMatterBundleComparisonExportCreatesNotesDraft)'`
- `swift test --package-path ios --filter 'AlphaLawyerUsabilityTests/testMatterBundleComparisonExportBodyLinesIncludeReadoutAndLatestRuntimeDetails'`
- `'/Users/amanpandey/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node' node_modules/tsx/dist/cli.mjs --test tests/model-registry.test.ts`
  Run from `/Users/amanpandey/projects/ross-gemma4/backend`
- `'/Users/amanpandey/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node' backend/node_modules/tsx/dist/cli.mjs --test backend/tests/routes-smoke.test.ts`
- `swift test --package-path ios --filter 'AlphaExtractionTests/(testAssistantDownloadTechnicalFailureSummaryIncludesNSErrorDetails|testAssistantSmokeVerificationSummaryIncludesDirectoryDigestDetails|testSweepTemporaryAssistantDownloadsPreservesExcludedArtifacts)'`
- `xcodebuild -project ios/Ross.xcodeproj -scheme Ross -destination 'id=3803F5B6-1666-56D3-A71A-62F131F6CE3B' -derivedDataPath ios/build-device build`
- `xcrun devicectl device install app --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B ios/build-device/Build/Products/Debug-iphoneos/Ross.app`
- `scripts/ios-device-assistant-download-smoke.sh --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B --tier quickStart --runtime mlx --mobile-allowed --wait-seconds 600`
- `scripts/ios-device-installed-pack-smoke.sh --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B --list-only`
- `swift test --package-path ios --filter 'AlphaExtractionTests/(testAssistantCatalogCacheDescriptorsPreserveMLXDraftCompanionFromBackendManifest|testPreferredAssistantDownloadFallbackUsesRossDirectoryDigestChecksumsForBundledDirectMLX|testAssistantDownloadDescriptorPreservesMLXDraftCompanionFromSessionArtifact|testExperimentalMLXProviderPassesDraftModelConfigToGenerator|testExperimentalMLXProviderRetriesWithoutDraftWhenSpeculativeGenerationFails|testAssistantDownloadTechnicalFailureSummaryIncludesNSErrorDetails|testAssistantSmokeVerificationSummaryIncludesDirectoryDigestDetails|testSweepTemporaryAssistantDownloadsPreservesExcludedArtifacts)'`
- `scripts/ios-device-installed-pack-smoke.sh --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B --tier quickStart --smoke-profile quick --stage-timeout 15`

## What Is Still Not Proven

- successful physical iPhone proof for the intended `Case Associate` 12B GGUF artifact on a 12 GB+ target, now that the current 7 GB-class A17 Pro phone has a recorded memory-mapping failure for that exact pack
- final real-device comparison of CoreAI vs MLX vs GGUF on modern iPhones
- real end-to-end client download and consumption proof for production multi-GB artifacts on device, even though the current iPhone now proves full production MLX transfer, verification, install, manifest write, and installed-pack selection from app-private storage, and now also proves that the intended below-target Quick Start GGUF lane gets through preflight and into a real multi-GB transfer
- a successful real local-inference pass from the newly installed `quickStart` MLX production pack on Aman's current phone, which is now specifically blocked by an `MLXNN.UpdateError` weight-key mismatch during generation
- Android native runtime validation beyond the recent retrieval and budget improvements

## Why This Is A Good Pause Point

- model selection is no longer in a churn state
- the latest verified iOS llama runner bump is already in
- large-file and context handling moved forward without opening a larger migration
- the whole real device pipeline now reaches much farther than before: download, verify, install, manifest write, and runtime validation are all proven on Aman's phone for the production quick-start MLX lane
- the next remaining work is mostly validation and final product judgment, not urgent architecture repair

## Exact Resume Step

Resume with a focused real-device validation pass instead of more code changes:

1. resume from the new physical-device checkpoint rather than from checksum or install debugging: the current phone now proves full `quickStart` MLX transfer, full verify, install move, manifest write, runtime validation, and a real manifest-backed production pack at `model-packs/quick_start/gemma-4-E4B-it-qat-4bit`
2. focus the next investigation on the MLX runtime/load compatibility of that installed production pack itself: the current blocker is no longer transport or install, but `MLXNN.UpdateError code=3` complaining that `language_model.model.layers.24.self_attn.v_proj.weight` is missing during generation
3. use the latest installed-pack smoke as the canonical evidence for that runtime investigation, because it now reaches `provider_ready` on the real production pack and surfaces the concrete failing weight key
4. compare that failing quick-start repository against the MLX runtime/model class Ross is actually loading, including whether the `gemma-4-E4B-it-qat-4bit` repo format still matches the current `mlx-swift-lm` Gemma 4 loader expectations
5. keep the new retry-without-draft path in mind as a signal: because the failure still reproduces even after adding a speculative-draft fallback path, the likely mismatch is in the main installed quick-start weights or architecture contract rather than only in the draft companion
6. once the MLX runtime mismatch is resolved, rerun `scripts/ios-device-installed-pack-smoke.sh --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B --tier quickStart --smoke-profile quick --stage-timeout 15` without `--allow-device-proof-pack` so the physical-device proof includes real local consumption from app-private storage
7. if that quick installed-pack smoke passes, follow with the longer matter-bundle comparison on the same real production lane before treating the quick-start MLX path as fully proven
8. treat Aman's current iPhone as a completed below-target proof for the intended 12B `Case Associate` artifact: the real pack now stages and opens there, but it fails with `mmap failed: Cannot allocate memory` on a device that reports `System physical memory: 7 GB`
9. use the new below-target behavior as the current shipping guardrail: on smaller iPhones, `Case Associate` should now steer toward MLX and no longer advertise the 12B GGUF lane as ready
10. resume the physical-device proof on a 12 GB+ iPhone target, or lower the intended Case Associate pack if that class of phone must be supported by the shipped ladder without the MLX fallback path
11. once one viable physical target can actually run the intended lane, compare CoreAI, MLX, and GGUF latency and answer quality on a longer matter bundle, using `Settings > Private AI > Support details` to switch the current runtime directly and rerun `Check private assistant with a longer matter bundle` between passes
12. once all needed lanes have recent evidence, tap `Save runtime comparison note` in hidden `Support details` so the current readout lands in `Notes & Drafts` as the device-QA artifact
13. decide whether the current 3-pack ladder should stay exactly as-is or swap any one pack after evidence
14. only then return to Android real-device runtime validation and deeper runtime work there

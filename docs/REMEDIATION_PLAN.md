# Ross — On-Device Remediation Plan

Scope: Android app (Kotlin/Compose, `android/app/src/main/kotlin/com/ross/android/alpha/`). This document maps the five issues reported on a physical device to the exact code paths responsible and prescribes concrete fixes. Each issue lists: **Symptom → Root cause → File:line → Fix → Verification**.

Implementation status: applied in this branch. The shipped changes add runtime diagnostics and softer device support, split file/OCR/extraction status, remove the stale heuristic ask generator with a persisted-state migration, gate chat source context through BM25-style retrieval, switch import entry points to batch pickers, key matter/chat lists, and move ask/import helpers into bounded modules (`AlphaAskPipeline.kt`, `AlphaImportPipeline.kt`).

---

## 1. No bulk file import

### Symptom
File picker only allows one file at a time. User wants to multi-select 10–20 files in one shot.

### Root cause
Every import entrypoint uses `ActivityResultContracts.OpenDocument()` (single-URI) or `ActivityResultContracts.GetContent()` (single-URI). The controller method that ingests files takes one `Uri` and writes one document per call.

### File:line
- [AlphaRossApp.kt:853](android/app/src/main/kotlin/com/ross/android/alpha/AlphaRossApp.kt:853) — `OpenDocument()` for file picker
- [AlphaRossApp.kt:856](android/app/src/main/kotlin/com/ross/android/alpha/AlphaRossApp.kt:856) — `GetContent()` for images (single)
- [AlphaRossApp.kt:1190](android/app/src/main/kotlin/com/ross/android/alpha/AlphaRossApp.kt:1190) — sheet "Add file" → `fileLauncher.launch(arrayOf("application/pdf", "text/plain"))`
- [AlphaRossApp.kt:1204](android/app/src/main/kotlin/com/ross/android/alpha/AlphaRossApp.kt:1204) — sheet "Add image" → `imageLauncher.launch("image/*")`
- [AlphaRossApp.kt:1824](android/app/src/main/kotlin/com/ross/android/alpha/AlphaRossApp.kt:1824) — Case workspace importer
- [AlphaRossApp.kt:1896](android/app/src/main/kotlin/com/ross/android/alpha/AlphaRossApp.kt:1896) — "Import document" button
- [AlphaRossApp.kt:2037](android/app/src/main/kotlin/com/ross/android/alpha/AlphaRossApp.kt:2037) — Document list importer
- [AlphaFoundation.kt:1504](android/app/src/main/kotlin/com/ross/android/alpha/AlphaFoundation.kt:1504) — `importDocument(caseId, uri: Uri): Boolean` is single-URI

### Fix
1. Replace **all four** `OpenDocument()` launchers with `ActivityResultContracts.OpenMultipleDocuments()`. Their callbacks receive `List<Uri>` instead of `Uri?`.
2. Replace the image `GetContent()` with `ActivityResultContracts.PickMultipleVisualMedia` (Photo Picker, no permission, supports up to ~100) or `GetMultipleContents`.
3. Add `controller.importDocuments(caseId: String?, uris: List<Uri>)` in `AlphaFoundation.kt` that:
   - Persists a single `AlphaImportBatch` row with `totalCount`, `successCount`, `failedCount` so the UI shows aggregate progress instead of N independent spinners.
   - Iterates URIs in a `Dispatchers.IO` coroutine, copying each into app-private storage and creating the `AlphaCaseDocument` rows in one `persisted = persisted.copy(...)` call (don't call `save()` per file — that re-serializes the whole encrypted state on every iteration and is the second-order cause of slowness).
   - Kicks off `runExtractionForDocument` per document **after** all files are persisted so the list pops in immediately and extraction runs in the background.
4. Show a snackbar / sticky strip: "Importing 14 files… 9 done, 1 failed (unsupported)."
5. Cap batch at 25 to bound memory and reflect that limit in the picker call: there is no Android-side cap, but you can validate count in the callback and surface a friendly toast above 25.

### Verification
- Pick 15 PDFs at once; all rows appear under the matter within ~2s; extraction badges flip to "reading" individually.
- Toggle airplane mode mid-import — successful copies stay; extraction badges stall at "reading" and do not flip to Failed (see issue 2).

---

## 2. Imports flip to "Failed" within ~5 seconds

### Symptom
After picking a file, the row shows "reading…" then flips to **Failed** in roughly five seconds.

### Root cause
Two-part bug:

**(a)** `importDocument` immediately launches extraction at [AlphaFoundation.kt:1603-1605](android/app/src/main/kotlin/com/ross/android/alpha/AlphaFoundation.kt:1603). If the local model runtime is not "available" (see issue 3), `executeModelPass` short-circuits and the orchestrator returns `failedExtractionResult` with `errorMessage = "Private assistant setup required."` at [AlphaExtraction.kt:579](android/app/src/main/kotlin/com/ross/android/alpha/AlphaExtraction.kt:579). This sets `AlphaExtractionRunStatus.Failed` which the UI surfaces as the red Failed pill.

**(b)** Even when the model **is** available, `verification.fields.isEmpty()` flips the run to `Failed` at [AlphaExtraction.kt:471](android/app/src/main/kotlin/com/ross/android/alpha/AlphaExtraction.kt:471). For documents that have valid OCR text but no extractable *legal fields* (random PDFs, photos, scratch notes), users still see "Failed" — which is misleading. The document is fine; only structured extraction yielded nothing.

### Fix
1. **Decouple ingest status from LLM status.** Introduce three independent statuses on `AlphaCaseDocument`:
   - `fileStatus` — `Copied | CopyFailed`
   - `ocrStatus` — already exists (`NativeText | OcrComplete | Failed | Placeholder`)
   - `extractionStatus` — `NotStarted | Running | Complete | NeedsReview | Skipped | Failed`
   Render the document tile as "Ready" if `ocrStatus != Failed`, regardless of `extractionStatus`. Only show a red badge when *copy* or *OCR* actually failed.
2. **Stop flipping to Failed when the model is missing.** In `failedExtractionResult` ([AlphaExtraction.kt:524](android/app/src/main/kotlin/com/ross/android/alpha/AlphaExtraction.kt:524)) return `AlphaExtractionRunStatus.Skipped` when `lastErrorCategory in {"model_file_not_found", "unsupported_runtime", "unsupported_device"}`, with a friendly message: "Document saved. Set up the private assistant to extract legal fields." Add an inline CTA that deep-links into the My Assistant setup screen.
3. **Stop flipping to Failed when zero fields found.** Change [AlphaExtraction.kt:470-474](android/app/src/main/kotlin/com/ross/android/alpha/AlphaExtraction.kt:470) to:
   ```
   verification.fields.isEmpty() && findings.isEmpty() -> Complete (with note "No structured fields found")
   verification.fields.isEmpty() && findings.isNotEmpty() -> NeedsReview
   else -> existing logic
   ```
4. **Tighten the ~5 second timing**: add a 2-second minimum dwell on the "reading…" state before any status change so the user doesn't see a flash failure. Cosmetic, but it stops the "felt-broken" impression.

### Verification
- Import a PDF on a device with no model installed → row shows "Saved · extraction skipped" with a "Set up assistant" link; no red error.
- Import a hand-written photo with poor OCR → "Needs review" amber badge, not Failed.
- Import a clean legal order → green Complete with extracted fields.

---

## 3. Setup assistant says "not installed" after the model has been downloaded

### Symptom
User completed the setup flow, downloaded the model, then asked a chat question and got: *"Private assistant setup required"*.

### Root cause
The runtime probe in [AlphaLocalModelRuntime.kt:628-707](android/app/src/main/kotlin/com/ross/android/alpha/AlphaLocalModelRuntime.kt:628) rejects the installed file unless **every** gate passes:

1. `deviceSupported` — likely a Soc/ABI/RAM check; often returns false on real devices that should be supported.
2. `modelFile.exists() && modelFile.isFile` — assumes the resolved path matches what the downloader wrote.
3. `modelFile.canRead()`
4. `!isBundledAssetPath(modelFile)` — blocks bundled `assets/` paths.
5. **`modelFile.name.endsWith(".task")`** ([AlphaLocalModelRuntime.kt:672](android/app/src/main/kotlin/com/ross/android/alpha/AlphaLocalModelRuntime.kt:672)) — this is the most common failure: a downloaded Gemma artifact is typically `.gguf`, `.bin`, or `.tflite`. Anything that isn't literally named `*.task` falls through with `userFacingStatus = "Private assistant file is not configured on this device."`
6. `isSupportedModelKind(modelKind)` — accepts only `mediapipe_llm | mediapipe_task | local_model_artifact | huggingface_gated_model_artifact | external_debug_model`. The downloader's manifest must set one of these exact strings; a mismatch fails silently.
7. Checksum verification ([AlphaLocalModelRuntime.kt:690-697](android/app/src/main/kotlin/com/ross/android/alpha/AlphaLocalModelRuntime.kt:690)) — if `expectedChecksum` is set but the SHA-256 doesn't match (e.g. partial download or resume corruption), the runtime is blocked with no retry path.

Additionally `canRunRealLocalAsk` at [AlphaFoundation.kt:3232-3243](android/app/src/main/kotlin/com/ross/android/alpha/AlphaFoundation.kt:3232) requires `MatterQuestionAnswer in health.supportedTasks` — easy to miss in the runtime's `supportedTasks()` declaration.

### Fix
1. **Single source of truth for the model file.** `AlphaInstalledPack.installRelativePath` written by the downloader must round-trip exactly into `probeAvailability().modelFile`. Add a unit test that asserts: after `markInstalled`, calling `activeRuntimeHealth().available` returns true on the same file the downloader produced.
2. **Replace strict extension check** with a content-detection table. Map artifact kind → expected extensions:
   ```
   mediapipe_task → .task, .tflite
   gemma_gguf     → .gguf
   onnx           → .onnx
   ```
   Use the manifest's declared kind, not filename matching, as the gate.
3. **Show the *actual* failure reason** in the setup screen. Today the UI only knows "setup required." Add a "Diagnostics" expander on the My Assistant screen that prints, verbatim:
   - resolved model path
   - file exists / readable
   - file size vs expected size
   - sha256 first 8 chars vs expected
   - `deviceSupported` result and which subcheck failed
   This single screen will turn ten hours of remote debugging into ten seconds.
4. **Repair, not block.** When checksum mismatches, surface a one-tap "Re-verify / Redownload" action instead of a dead end. The download job in [AlphaFoundation.kt:3715](android/app/src/main/kotlin/com/ross/android/alpha/AlphaFoundation.kt:3715) already has the state machine — wire a retry button.
5. **Loosen `deviceSupported`** to a soft warning. On unknown SoCs, attempt initialization; if the runtime throws `UnsatisfiedLinkError`, then mark unsupported. Today the app pre-rejects valid devices it doesn't recognize.
6. **Move the assistant-ready check into a `StateFlow`** so the chat composer recomputes when the model finishes installing. Today `activeRuntimeHealth()` is recomputed on each `canRunRealLocalAsk()` call, but the chat screen may have cached its previous result — see issue 4.

### Verification
- Fresh install → My Assistant → download Standard model → diagnostics panel shows all green → return to chat → ask "summarize this matter" → answer card switches from "Setup required" to "Ross is using the private assistant" within one second.
- Force a checksum mismatch (rename a byte in the file) → diagnostics shows the mismatch, "Re-verify" button works.

---

## 4. Newly-created matter doesn't appear until the tab is reopened

### Symptom
Create a matter → it doesn't show in the matter list until the user navigates away and back.

### Root cause
`createCase` at [AlphaFoundation.kt:1402-1436](android/app/src/main/kotlin/com/ross/android/alpha/AlphaFoundation.kt:1402) does set `persisted = persisted.copy(cases = listOf(case) + persisted.cases, …)`, and `persisted` is `mutableStateOf` ([AlphaFoundation.kt:590](android/app/src/main/kotlin/com/ross/android/alpha/AlphaFoundation.kt:590)), so Compose *should* observe the change. The bug is one of three (need to confirm with a Layout Inspector trace; all are plausible and all are worth fixing):

1. **List rendered from a snapshot copy.** Several screens compute derived lists like `controller.cases.sortedByDescending { … }` outside of a `remember(controller.cases)` — Compose tracks state reads, but only inside composable scope. If the sort happens in a non-snapshot lambda passed to `LazyColumn`, the snapshot read is hidden and the row doesn't recompose. See [AlphaRossApp.kt:5995-5997](android/app/src/main/kotlin/com/ross/android/alpha/AlphaRossApp.kt:5995). Wrap derived lists in `remember(controller.cases) { ... }`.
2. **List `key=` collisions.** The matter list likely does not pass `key = { it.id }` to `LazyColumn.items(...)`, so Compose may skip the diff when the head of the list changes. Add `key = { it.id }` everywhere matters are rendered.
3. **`createCase` immediately navigates to the workspace** via `pendingRoute = AndroidAlphaRoute.CaseWorkspace(case.id)` ([AlphaFoundation.kt:1433](android/app/src/main/kotlin/com/ross/android/alpha/AlphaFoundation.kt:1433)) — so the *first* time the user creates from the matters tab, the list is rendered behind the workspace, and only when they pop back does the recomposition trigger (because the activity resumes and `persisted` is re-read from storage). Behavior: change the flow to **not navigate** when create is invoked from the matters list — stay on the list and surface a snackbar "Matter created"; navigate only from the create-screen "Open workspace" button.

### Fix
1. Audit every place a list of matters/documents/tasks is rendered. Ensure:
   - the source `List<...>` is read from `controller.persisted.cases` (snapshot-tracked) **inside** a composable, not captured in a remembered lambda;
   - `LazyColumn.items` always passes `key = { it.id }`;
   - derived sorts use `remember(controller.cases, sortMode) { ... }`.
2. Decouple `createCase` from navigation. Return the new id; let the caller decide whether to push the workspace route.
3. Replace the `mutableStateOf` controller pattern with a `StateFlow<AlphaPersistedState>` collected via `collectAsStateWithLifecycle()` in the root composable. This eliminates the entire class of "compose lost the read" bugs and lets the chat / matters tabs share a single observed state regardless of where they are in the back stack.

### Verification
- From the matters tab, tap "+ New matter", enter "Test 1", confirm — new row appears at the top of the list within one frame without any navigation.
- Create five matters in a row — each appears immediately, none require a tab toggle.

---

## 5. Chat hallucinates: "What is FMLA?" → "Ross drafted this from your files"

### Symptom
User asked a generic legal question ("What is the FMLA?") with no relevant files imported. The answer card said *"Ross drafted this from your files"* and listed unrelated files as follow-ups.

### Root cause
Two interacting paths produce this output:

**(a) Stale heuristic generator still on disk.** `buildLocalAskResult` ([AlphaFoundation.kt:3081-3230](android/app/src/main/kotlin/com/ross/android/alpha/AlphaFoundation.kt:3081)) contains a template-based answer generator that, when it can't find anything (`sections.isEmpty() && selectedDocuments.isNotEmpty()`), falls through to:
```
selectedDocuments.take(3).forEach { document ->
    sections += "${document.title}: included for this answer."
}
…
answerTitle = "Ross drafted this from your files"
```
This is exactly the output the user saw. Greping for `buildLocalAskResult` shows no current caller, **but** older `AlphaAskResult` rows from previous app versions are still in `persisted.askHistory` and get re-rendered on relaunch — so the user is seeing a *replayed* old turn that pretends to be fresh. Also, any unit test or alternate ask flow that still routes through this function will exhibit the bug live.

**(b) When no document is selected and no model is available, the live path is `buildLocalModelRequiredAskResult`** ([AlphaFoundation.kt:3265-3287](android/app/src/main/kotlin/com/ross/android/alpha/AlphaFoundation.kt:3265)) — that path correctly says "Private assistant setup required." But if a document **is** selected (auto-selected via `fixedDocumentIds` from the file viewer, or sticky from a previous session), the document is appended to the ask payload regardless of relevance — and `scheduleAskRuntimeUpgrade` will then send those file contents as context to the local LLM, which dutifully writes a "drafted from your files" framing.

### Fix
1. **Delete `buildLocalAskResult` entirely.** If nothing calls it, it can't produce live output, and removing it guarantees old persisted turns can't be revived by accident. After deletion, migrate older `askHistory` entries on load: any historical `AlphaAskResult` whose `answerTitle == "Ross drafted this from your files"` should be rewritten to a neutral placeholder ("This conversation is from a previous version of Ross."). Do this in `loadState`.
2. **Gate the chat on retrieval.** Before submitting to the local model, run a relevance check:
   - tokenize the question
   - score each `AlphaSourceRef.textSnippet` by BM25 / overlap
   - if the top score is below a threshold, **do not** include any file context. Instead respond: *"This question isn't supported by the files on this device. Turn on Legal Search or import a relevant document."*
   The current implementation in `scheduleAskRuntimeUpgrade` ([AlphaFoundation.kt:2181](android/app/src/main/kotlin/com/ross/android/alpha/AlphaFoundation.kt:2181)) already builds a `sourcePack` from the question — replace that with a real retriever instead of substring matching. The substring path is at [AlphaFoundation.kt:3122-3132](android/app/src/main/kotlin/com/ross/android/alpha/AlphaFoundation.kt:3122) (`lowered.contains(it.documentTitle.lowercase())`) and is what creates the false "this file is relevant" signal.
3. **Tighten the prompt.** In `askRuntimeInstruction` ([AlphaFoundation.kt:2282](android/app/src/main/kotlin/com/ross/android/alpha/AlphaFoundation.kt:2282)) prepend a system rule: *"If no excerpt directly supports the answer, reply 'I don't have a source on this device for this question.' Do not paraphrase. Do not invent citations."* Today the only guard is "say what extra jurisdiction or context is needed" which doesn't stop confabulation.
4. **Strip auto-selected documents** when the question is a generic legal definition ("what is X", "define X", "is X legal"). Detect via a small regex set and force `selectedDocuments = emptyList()` on that path so the file context doesn't leak in.
5. **Show grounding visibly.** The answer card should render each claim with the source ref it came from. If a claim has no source ref, render it greyed-out with "(no local source)". This is both an honesty signal and a debugging tool for the team.

### Verification
- Ask "What is FMLA?" with no relevant files → response: "I don't have a source on this device for this question. Enable Legal Search or import a relevant document."
- Ask "What is FMLA?" with an FMLA policy PDF imported → grounded answer with page citations.
- Replay a historical ask turn from before the migration → renders as a neutral placeholder, not the misleading "drafted from your files" text.

---

## Cross-cutting changes

### A. Move long file (`AlphaFoundation.kt`) into bounded modules
`AlphaFoundation.kt` is **4,648+ lines** and `AlphaRossApp.kt` is **6,259 lines** — both are doing controller, persistence, ask pipeline, downloader, public-law search, payload shaping, and UI shell. Split into:
- `AlphaRossController.kt`
- `AlphaPersistence.kt`
- `AlphaAskPipeline.kt`
- `AlphaImportPipeline.kt`
- `AlphaPublicLawController.kt`
- `feature/home/*`, `feature/matter/*`, `feature/chat/*`, `feature/setup/*` for UI

This is prerequisite work — every fix above is harder than it needs to be because changes ripple through unrelated screens.

### B. Replace ad-hoc `mutableStateOf` controller with proper state holders
Adopt one `StateFlow<AlphaPersistedState>` plus per-screen ViewModels. The `var persisted by mutableStateOf(...)` pattern works inside a single composable tree but breaks when navigating across destinations, which is the seed of issue 4. While migrating, keep the encrypted state store as-is — only the in-memory observation layer changes.

### C. Persisted-state migrations
Add a `schemaVersion: Int` to `AlphaPersistedState` and run forward migrations in `loadState`. This is needed (a) to clean up legacy `AlphaAskResult` rows that contain the hallucinated "drafted from your files" headline (issue 5), and (b) for the new `extractionStatus` field (issue 2) without losing existing documents.

### D. On-device QA harness
Add a developer-only `Diagnostics` screen that runs:
- "Import five sample PDFs and report row count vs expected" (issue 1)
- "Force-fail extraction and confirm the document tile stays green-Ready" (issue 2)
- "Run `probeAvailability()` and dump every gate's pass/fail" (issue 3)
- "Create-then-list-without-navigation roundtrip" (issue 4)
- "Ask 'What is FMLA?' with no files and assert response is the 'no source' template" (issue 5)
These five tests block release.

### E. Realistic-device CI
Today the QA artifacts (`docs/*_QA.md`) mostly describe simulator/emulator runs. The bugs in this report all surface on **real** devices. Add a Firebase Test Lab / BrowserStack pass that runs the diagnostics harness above on at least one mid-tier Pixel and one mid-tier Samsung. The runtime guard at [AlphaLocalModelRuntime.kt:636](android/app/src/main/kotlin/com/ross/android/alpha/AlphaLocalModelRuntime.kt:636) (`!deviceSupported`) cannot be trusted until it has been exercised against the actual hardware mix.

---

## Priority and sequencing

| # | Issue | Severity | Effort | Order |
|---|-------|----------|--------|-------|
| 3 | Setup status wrong after download | Blocker | M | 1 |
| 2 | Imports flip to Failed | Blocker | S | 2 |
| 5 | Chat hallucinates | Blocker | M | 3 |
| 1 | No bulk import | High | S | 4 |
| 4 | Matter list stale | Medium | S | 5 |

Ship 3 → 2 → 5 first. Without those three, the app is unusable regardless of how good the polish on 1 and 4 is.

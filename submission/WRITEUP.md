# ROSS-Gemma4

**Private AI junior associate for access-to-justice legal workflows**

---

## One-line summary

ROSS-Gemma4 is a mobile-first, local-first legal workbench that uses Gemma 4 capability tiers to help advocates and legal-aid teams turn sensitive case bundles into source-backed summaries, chronologies, issue notes, missing-fact checklists, tasks, and first drafts — without sending private case files to a cloud LLM.

---

## The problem

Legal-aid lawyers and small chambers work with overloaded dockets, fragmented documents, scanned orders, mixed-language records, and urgent hearing dates. The day-to-day work is not glamorous: read the latest order, identify the next date, check directions, update the matter note, prepare follow-up tasks, draft a short hearing brief.

For these users, cloud AI has a serious adoption barrier. Case files contain privileged facts, client identities, phone numbers, financial details, addresses, medical history, and litigation strategy. Uploading those files to a remote AI service is often unacceptable ethically and professionally. The lawyers who most need automation may also work in low-connectivity settings or on personal devices without corporate IT infrastructure.

Ross asks a narrower question: **what if a privacy-preserving local model could act like a careful junior associate for the routine first pass, while the human advocate remains responsible for review and final judgment?**

---

## The solution

Ross is designed as a calm daily matter desk — not a chatbot toy. A lawyer opens Ross in the morning and sees what needs attention today: upcoming dates, pending review items, newly imported documents, suggested tasks, and drafts ready for advocate review.

Inside a matter, Ross can:

- **Read** imported case documents entirely on-device
- **Classify** legal documents and identify their type
- **Extract** dates, court details, parties, directions, issues, reliefs, and statutory references
- **Surface** source chips for every important fact so the advocate can verify provenance
- **Queue** uncertain or conflicting details for human review
- **Suggest** follow-up tasks generated from orders and pleadings
- **Generate** local drafts — chronologies, case notes, order summaries, and Ross transcripts
- **Answer** matter-scoped questions from local case files via Ask Ross
- **Prepare** sanitized public-law searches only after explicit user review and approval

The product principle is simple: **Ross prepares work locally; the advocate reviews, edits, accepts, dismisses, or asks for more.**

---

## Why Gemma 4

Gemma 4 is central to the product direction because Ross needs private, edge-capable intelligence rather than a remote general-purpose assistant. The app is structured around Gemma 4 capability packs selected by device capacity and workflow complexity:

| Tier | Model | Primary use |
|---|---|---|
| **Quick Start** | Gemma 4 E2B Q4 | Fast intake, short summaries, checklist-style review |
| **Case Associate** | Gemma 4 E4B Q4 | Source-packed document review, chronology building, issue extraction, missing-fact analysis |
| **Senior Drafting Support** | Gemma 4 26B-A4B Q4 | Longer bundles and heavier first-pass drafting in workstation-style use |

Ross also separates retrieval from generation. The production-intended architecture uses a dedicated local embedding model for Matter Search and source retrieval, with Gemma 4 used for grounded synthesis, extraction, verification, and drafting. This separation keeps answers tied to evidence rather than turning the app into an unsupported free-form legal assistant.

---

## Architecture

Ross has four major layers:

1. **Mobile app shell** — iOS-first SwiftUI product with Home, Matter workspace, Ask Ross, document review, exports, settings, and Privacy Ledger surfaces.
2. **Shared Rust core** — extraction logic, redaction, public-query sanitization, RAG contracts, feature gating, model invocation contracts, source validation, and evaluation fixtures.
3. **Backend control plane** — model catalog metadata, download session routes, entitlement routes, auth wiring, and a public-law search proxy.
4. **Local model runtime abstraction** — deterministic development provider today, with Gemma 4 Q4 runtime metadata and adapter contracts for local inference providers.

### Legal extraction pipeline

The extraction pipeline is intentionally layered and treat every stage as a potential failure point:

```
document import
  → page rendering and text acquisition
  → language/script detection
  → OCR cleanup and normalization
  → prompt packing with source refs
  → local document classification
  → legal field extraction
  → verifier/refiner pass
  → confidence findings and review queue
  → source-backed case memory synthesis
  → chronology and order-summary outputs
  → advocate review and correction
```

Ross treats model output as untrusted until it passes schema validation, source-reference validation, and review gating. Extracted values are categorized as `verified`, `needs_review`, or `rejected`. Unsupported free-form output is not silently accepted as legal fact.

---

## Privacy and safety

Ross is built around a hard privacy boundary:

- Case files stay on the device
- OCR text, prompts, embeddings, extracted fields, case memory, review corrections, and local drafts are **never** uploaded to cloud AI services
- Public-law search is **off by default**
- Before any public-law search, Ross builds a sanitized query locally and shows the user a preview
- Only the approved sanitized public-law query can cross the network boundary
- Private matter facts, filenames, phone numbers, emails, case-specific identifiers, party names, and factual narratives are stripped or blocked
- The **Privacy Ledger** records what ran, whether it stayed local, and whether any approved network action occurred

The app is deliberately framed as a workbench for advocates. Outputs are labeled as drafts for advocate review. Ross is not presented as an autonomous lawyer and does not replace professional judgment.

---

## Current prototype status

This repository demonstrates the product shell, privacy boundary, model-delivery contracts, legal extraction pipeline contracts, public-law search boundary, and deterministic local development runtime.

### What's implemented and validated

- iOS app shell: Home, Matter workspace, Ask Ross, document review, exports, settings, and Privacy Ledger
- Local matter tasks and date commands through Ask Ross
- Document review surfaces with plain-language accept/edit/ignore controls
- Source-backed extracted-field and review-queue data model
- Local export generation paths for chronology, case note, order summary, and transcript
- Public-law search preview and confirmation model
- Privacy sanitizer that preserves legal citations (CPC, CrPC, NI Act, constitutional article references) while blocking private matter details
- Rust tests for extraction, redaction, language detection, RAG, feature gating, prompt building, and public query behavior
- Backend tests, typecheck, and build
- Privacy guard scripts for no cloud LLM use on private case files, no analytics, no large committed model assets, and onboarding copy boundaries
- Android build/test/install path (emulator launch still needs follow-up proof)

### iOS performance and reliability engineering

The iOS app went through a significant reliability and performance hardening pass during development:

- **Startup hang fix** — eliminated an unnecessary SHA-256 hash of multi-GB model files on every launch (~30–90 second startup stall). Startup now uses stored manifest checksums with a 350ms dismissal timeout as a safety floor.
- **Physical-device crash fix** — resolved a Swift exclusive-access violation in the inference hot path: precomputed all `persisted` reads before entering `updateStoredAskTurn` mutation closures to prevent a crash that occurred on the first query after fresh install.
- **Streaming performance fix** — cached 5 regex patterns as static `NSRegularExpression` objects at file level instead of recompiling on every SwiftUI body render during token streaming.
- **State invalidation fix** — debounced snapshot rebuilds to a 300ms rolling window instead of firing on every persisted mutation; eliminated an O(N·M·K) `flatMap.contains` pattern on Ask submit.
- **Storage leak fix** — cleaned up orphaned `CFNetworkDownload_*.tmp` files (2 GB+ found in test containers) by switching to deterministic temp paths and wiring cleanup into failure, cancellation, and foreground-resume paths.

### Important limitation

The current alpha should not be represented as completed production Gemma 4 Q4 hardware inference. The Gemma 4-first model registry, download metadata, runtime contracts, and deterministic proof paths are all implemented, but real Gemma 4 Q4 inference on device is still pending verified artifacts and hardware/runtime proof.

The prototype is best described as **a working local-first product proof with a clear Gemma 4 deployment path**, not a finished production release.

---

## Demo flow (3 minutes)

1. Open Ross and land on the daily matter desk.
2. Create or open a matter.
3. Import a sample legal order or bundle.
4. Ross reviews the document locally and surfaces extracted dates, directions, source chips, and review items.
5. Ask Ross to create tasks from the latest order.
6. Ask Ross to generate a chronology or case note draft.
7. Turn on public-law search for a general legal issue.
8. Ross shows the sanitized query first — no web search runs until the user confirms.
9. Show the Privacy Ledger proving local work stayed local and the public-law boundary was explicit.

---

## Impact

Ross targets the access-to-justice gap where AI could help most but privacy and connectivity constraints are strictest. A legal-aid team handling many small matters does not need a flashy general chatbot. It needs reliable first-pass help with reading, organizing, verifying, and drafting from sensitive documents.

If completed, Ross could:

- Reduce routine matter-preparation time for advocates
- Improve deadline and direction visibility across a busy docket
- Make case files easier to review and organize
- Give smaller legal teams a private assistant that works even when cloud AI is not appropriate

The broader lesson is that "AI for good" is not only about bigger models. It is about putting capable open models into workflows where **trust, locality, source grounding, and human review are designed into the product from the start**.

---

## What comes next

1. Wire the real Gemma 4 Q4 local runtime provider on iOS and Android
2. Complete the Matter Search embedding model install/retrieval lifecycle
3. Run hardware proof for Quick Start and Case Associate tiers
4. Measure latency, memory pressure, battery impact, and failure modes
5. Complete a fresh end-to-end iOS walkthrough covering import, review, Ask Ross, public-law approval, export, and Privacy Ledger
6. Resolve the Android emulator launch blocker and complete an Android in-app walkthrough
7. Expand Ross Routines so the app can prepare morning briefs, after-import reviews, hearing-prep packs, and weekly matter sweeps locally

# Offline Behavior

Ross is designed so that legal work can continue even when no network is available. OCR is only one acquisition step inside a larger local extraction pipeline; the useful behavior is the combination of local text acquisition, local language handling, local field extraction, local review, and local exports.

## Works with no Private AI Pack installed

- Complete onboarding and create a case.
- Import PDF, image, or text files into encrypted app-private storage.
- Preview imported PDFs and images locally.
- Acquire embedded PDF text where available.
- Run on-device OCR where available.
  - iOS uses local PDFKit text extraction and Vision OCR for images.
  - Android uses local PDF page rendering plus on-device ML Kit OCR.
- Detect English, Hindi, and mixed-script documents locally.
- Run Basic extraction mode:
  - heuristic language/script profiling
  - deterministic case-number, court, date, section, exhibit, and amount extraction
  - source-backed findings with confidence labels
- Review extracted details inside the document workflow.
- Accept, edit, or ignore uncertain fields locally.
- Generate chronology, case note, and order-summary exports locally.
- Review the Privacy Ledger locally.

## Works with Quick Start

- Everything in Basic mode.
- Short-document cleanup and stronger local multi-pass extraction through the local extraction interface.
- Simple document classification.
- Better short-document field extraction.
- Better language correction on shorter pages.
- Small local summaries and light case-memory updates.

## Works with Case Associate

- Everything in Quick Start.
- Stronger local extraction and verification for everyday advocate workflows.
- Better mixed English/Hindi handling.
- Source-backed document classification, field extraction, chronology candidates, issue candidates, and order-direction extraction.
- Second-pass local verifier/refiner behavior through the orchestrated pipeline.
- Better review queues so the advocate only corrects uncertain fields.
- This is the tier where the app should feel most assistant-like, but it still must not overclaim if the runtime path is deterministic or stubbed on a given platform.

## Works with Senior Drafting Support

- Everything in Case Associate.
- Deeper multi-pass extraction and verification.
- Better support for longer bundles and stronger bilingual review.
- Better evidence, issue, and contradiction-oriented synthesis.
- Stronger senior-brief and hearing-preparation candidates, still local-first.

## Requires network

- Model catalog checks.
- Model-download session setup.
- Dev-artifact byte delivery for pack-install development flows.
- Entitlement refresh.
- Public-law search after the user approves the sanitized preview.

## Degraded or waiting behavior

- If no pack is installed, Ross still remains useful for import, preview, OCR/text acquisition, heuristic extraction, review, and local exports.
- If a pack download is pending, already-imported case files remain available locally and are unaffected.
- Public-law search stays blocked until the user approves the sanitized preview.
- Larger pack installs can pause for Wi-Fi or explicit mobile-data approval.
- If the backend is unavailable during development, pack install can fall back to a local dev artifact without touching case data.
- Exact PDF highlight placement is still best-effort. Ross always falls back to visible source chips instead of pretending to anchor a missing quote.

## Evaluation limits

- The current test harness is useful for boundary, source-ref, and review-queue checks.
- It does not prove that a production-grade on-device LLM is running.
- Fixture-driven tests can confirm orchestration behavior, but they do not measure real local inference quality, latency, or memory use on shipped model assets.

## User-facing messaging

- Say what still works right now.
- Say when better extraction is available with a stronger Private AI Pack.
- Tell the user when a field needs review.
- Keep the privacy boundary explicit: case files stay on this device.

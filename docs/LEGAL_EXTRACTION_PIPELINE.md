# Legal Extraction Pipeline

Ross does not treat OCR as the core intelligence.

OCR is only a text-acquisition step. The useful system is the layered legal-document extraction pipeline that sits above acquisition and below advocate review.

## Layered flow

Ross now follows this local-first flow:

1. `Document import`
2. `Page rendering and text acquisition`
3. `Language and script detection`
4. `OCR cleanup and normalization`
5. `Prompt packing with source refs`
6. `Local document classification`
7. `Local legal field extraction`
8. `Local verifier/refiner pass`
9. `Confidence findings and review queue`
10. `Source-backed case memory synthesis`
11. `Chronology and order-summary outputs`
12. `Advocate review and correction`

## Extraction quality depends on the installed Private AI Pack

### Basic

- No pack required.
- Uses local OCR, heuristics, and deterministic extraction only.
- Best for conservative import, preview, and review.

### Quick Start

- Uses the same runtime contract but stays lighter and budget-gated.
- Refuses oversized prompt packs and falls back safely.

### Case Associate

- This is the first tier intended to use the deeper extraction chain.
- Runs source-packed extraction, verification, and case-memory synthesis.
- Uses a real local runtime only when a compatible local runtime is available.
- Falls back to deterministic behavior when the runtime is unavailable.

### Senior Drafting Support

- Extends the same pipeline with deeper synthesis and longer-document planning.
- Still may fall back deterministically if a real runtime is unavailable.

## Prompt packing and output validation

Real local inference is only useful if the surrounding pipeline stays strict.

Ross therefore:

- builds prompt packs from bounded source blocks
- keeps page and source refs in the pack
- includes expected JSON schema
- treats document text as quoted data
- validates output against schema-specific rules
- repairs only small safe JSON errors
- rejects unsupported free-form output

Free-form text is not accepted as extracted legal fields.

## Verifier categories

Every extracted candidate now lands in one of three categories:

- `verified`
- `needs_review`
- `rejected`

`verified` means the value is directly supported by cited source text.

`needs_review` means support is weak, mixed-language uncertainty is present, OCR is weak, or the value is normalized but still uncertain.

`rejected` means the field failed schema checks, lacks source support, looks hallucinatory, or appears contaminated by prompt-injection content.

Rejected values do not appear as accepted extracted fields in normal UI.

## Runtime status in this alpha

- The deterministic development runtime remains real and active.
- Android has a concrete MediaPipe adapter path for developer-supplied `.task` artifacts.
- iOS has an Apple Foundation Models adapter path behind explicit developer opt-in.
- Real local inference should not be claimed unless it actually ran with a compatible runtime on-device.

## Advocate review

Ross should ask for focused review only where uncertainty remains:

- document type
- court
- case number
- parties
- important dates
- next date
- order directions
- sections

Each card should show:

- value
- source chip
- confidence label
- verified or needs-review state
- accept, edit, and ignore actions

## Privacy guarantee

All of the following remain local in the active product:

- case files
- OCR text
- extracted fields
- prompts
- embeddings
- case memory
- chronology candidates
- review corrections

Public-law search remains a separate sanitized boundary.

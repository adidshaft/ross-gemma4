# Extraction Evaluation

Ross uses an alpha extraction evaluation harness to measure whether the local extraction pipeline stays conservative, source-backed, and privacy-safe.

This harness is a regression safety net. It does not prove production legal accuracy.

## Alpha proof update

- Real-device proof is still separate from this harness.
- `deterministic_dev` is not a real model result.
- Evaluation remains conservative only if `unsupportedAccepted` stays `0`.
- Local inference metrics now capture runtime mode, duration, schema validity, and review counts without storing prompt text, source text, or raw model output.
- Real local inference claims require a compatible runtime and developer-provided artifact in addition to passing these evaluation checks.

## Why the harness exists

Legal extraction can fail in dangerous ways:

- inventing a case number
- normalizing the wrong date
- turning noisy OCR into false certainty
- misreading mixed Hindi and English text
- following malicious instructions embedded inside a document
- emitting invalid JSON that slips through as accepted data

The harness exists to catch those failures early and keep unsupported accepted fields at zero.

## Fixture coverage

Synthetic or anonymized fixtures cover:

- English civil orders
- Hindi and English mixed orders
- noisy OCR affidavit text
- pleadings with prayers
- evidence and exhibit lists
- prompt-injection text
- conflicting dates
- hallucination traps

## Evaluation run shape

Ross now models fixture runs with an `EvaluationRun` shape that records:

- `id`
- `runtimeMode`
- `extractionMode`
- `fixtureId`
- `startedAt`
- `completedAt`
- `fieldsExpected`
- `fieldsFound`
- `fieldsVerified`
- `fieldsNeedingReview`
- `unsupportedAccepted`
- `schemaValid`
- `sourceCoverage`
- `notes`

The required invariant is unchanged:

- `unsupportedAccepted` must stay `0`

## What the harness now checks

- prompt packs stay inside the configured budget
- accepted fields keep source refs
- invalid JSON fails safely
- repair paths stay conservative
- unsupported values become `needs_review` or `rejected`
- verifier categorization stays stable
- prompt injection does not change extraction behavior
- mixed-language detection remains intact
- invocation metadata excludes raw prompt and raw source text

## Relation to runtime modes

The harness is designed to work in two modes:

- deterministic development evaluation
- optional real local evaluation when a developer explicitly provides a compatible local runtime

If `ROSS_LOCAL_MODEL_PATH` or another explicit debug runtime configuration is absent, Ross should run deterministic evaluation and skip real-runtime claims.

Current alpha note:

- Android CI now validates a concrete MediaPipe adapter path at compile time and through fallback tests.
- iOS CI still validates the explicit opt-in and safe fallback path only.
- No real device execution is implied by the automated harness.

## Pack-quality coverage

The evaluation harness helps validate that pack-aware planning changes the extraction path:

- Basic stays deterministic and review-heavy
- Quick Start stays lighter and budget-gated
- Case Associate runs the deeper extraction and verification chain
- Senior Drafting Support keeps stronger synthesis scaffolding without accepting unsupported fields

## Privacy boundary

Fixture data is local test data only.

The harness does not require:

- cloud OCR
- cloud model calls
- case upload
- remote evaluation services

It is intentionally compatible with the existing privacy guard scripts.

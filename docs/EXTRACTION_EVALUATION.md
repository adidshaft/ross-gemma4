# Extraction Evaluation

Ross uses an alpha extraction evaluation harness to measure whether the local extraction pipeline stays conservative, source-backed, and privacy-safe.

This harness does not prove production-model accuracy. It is a local regression safety net.

## Why this harness exists

Legal extraction can fail in dangerous ways:

- inventing a case number
- normalizing the wrong date
- turning noisy OCR into false certainty
- misreading mixed Hindi/English text
- following malicious instructions embedded in documents
- exporting unsupported facts as if they were verified

The harness exists to catch those failures early.

## Fixture set

Synthetic or anonymized fixtures cover:

- English civil order
- Hindi/English mixed order
- noisy OCR affidavit text
- pleading with parties and prayers
- evidence and exhibit list
- prompt-injection text
- conflicting dates
- hallucination trap

Each fixture defines:

- source text
- expected document type
- expected language profile
- expected extracted fields
- required source refs
- values that must remain in review

## What the report measures

Ross can summarize fixture runs with an `ExtractionQualityReport` shape:

- `fixtureId`
- `mode`
- `fieldsExpected`
- `fieldsFound`
- `fieldsVerified`
- `fieldsNeedingReview`
- `unsupportedAccepted`
- `sourceCoverage`
- `notes`

The most important alpha metric is simple:

- `unsupportedAccepted` must stay `0`

## Assertions

The current harness asserts:

- every accepted field has source refs
- unsupported values are pushed into review
- invalid model JSON fails safely
- prompt injection does not change extraction behavior
- mixed-language detection remains intact
- verifier logic catches hallucinated court, case number, and date values
- deterministic development runtime output stays stable
- invocation metadata excludes raw prompt and raw source text

## Relation to pack quality

The harness helps validate that pack-aware planning changes the extraction path:

- Basic stays deterministic and review-heavy
- Quick Start stays lighter and gated for shorter documents
- Case Associate enables deeper verifier behavior
- Senior Drafting Support adds deeper-pass scaffolding

That means Ross can test the pipeline shape before shipping real device-side model assets.

## Privacy boundaries

Fixture data is local test data only.

The harness is designed so it does not require:

- cloud OCR
- cloud models
- case upload
- remote evaluation services

It is intentionally compatible with the existing privacy guard scripts.

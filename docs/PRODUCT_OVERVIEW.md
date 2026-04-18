# Product Overview

Ross is a privacy-first legal workbench for Indian advocates. It is designed to make legal documents useful on-device through layered extraction, source-backed review, chronology building, issue spotting, order analysis, and local drafting support.

## Product direction

Ross is not a cloud case processor and it is not an OCR-only tool.

The product direction is:

- acquire text locally
- understand language and document type locally
- extract legally important fields locally
- verify important fields locally
- preserve source anchors
- show uncertainty honestly
- ask the advocate to correct only what needs review
- turn reviewed extraction into local case memory
- keep case files on this device

## Product pillars

1. Privacy-first local execution
2. Law-grade source-backed extraction
3. Clear separation between case data and network traffic
4. Extraction quality that scales with the installed Private AI Pack
5. Practical advocate review UX instead of hidden automation
6. Honest runtime messaging when deterministic fallback is active

## Key workflows

1. Install the app and complete minimal setup.
2. Choose a Private AI Pack or continue in Basic mode.
3. Create a case and import documents.
4. Run local acquisition and local language detection.
5. Review extracted details with source chips.
6. Correct only the uncertain fields.
7. Generate chronology, issue, order-summary, and case-note drafts locally.
8. Optionally run public-law search with a sanitized query preview.

## Current alpha status

- deterministic local runtime remains the default for CI and fallback
- Case Associate is the first tier wired for the deeper extraction and verification chain
- Android has real-runtime scaffolding but not a shipping inference engine yet
- iOS has an Apple Foundation Models adapter path behind explicit developer opt-in
- no large model files are committed
- no cloud inference is used

## Non-goals

- public legal advice
- silent cloud case processing
- analytics-driven case monitoring
- remote case sync in this phase
- pretending deterministic output is the same as real local inference

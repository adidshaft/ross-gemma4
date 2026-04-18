# Model Registry

Ross shows advocate-friendly capability packs in product UI. Technical model names are hidden from onboarding and routine settings because the user-facing promise is extraction quality, not model branding.

## User-facing packs

### Basic

- Available with no Private AI Pack installed.
- Uses local text acquisition, local OCR where available, heuristics, and deterministic extraction.
- Best for import, preview, basic extraction, and local review.

### Quick Start

- Extraction quality: `Standard`
- Best for short documents, lighter cleanup, and simple summaries.
- Some fields may still need manual review.

### Case Associate

- Extraction quality: `Advanced`
- Best for better document understanding, stronger field extraction, mixed English/Hindi handling, chronologies, and order summaries.

### Senior Drafting Support

- Extraction quality: `Advanced Plus`
- Best for deeper review, verifier/refiner passes, longer bundles, and stronger bilingual workflows.

## Registry principles

- Do not show technical model names in onboarding.
- Present capability tiers as advocate workflows, not inference internals.
- Keep installation separate from the base app.
- Allow the product to remain usable without a pack.
- Prefer local model-assisted extraction, verification, and synthesis when a pack is installed.

## Engineering registry notes

The current architecture supports:

- lightweight local model-assisted extraction interfaces
- stronger local extraction passes for Case Associate
- deeper verifier/refiner passes for Senior Drafting Support
- future local VLM-capable or multimodal passes for scan-heavy documents

The repo does not ship large production binaries in source control.

## Delivery principles

- Delivery is signed, resumable, and checksum verified.
- Model delivery endpoints must never receive case data.
- Dev-artifact delivery exists so download/install logic can be validated without bundling real model assets.
- Technical details may be exposed only under advanced settings or engineering documentation.

## Alpha delivery status

- Backend `/model-catalog` returns signed dev-artifact metadata for the visible packs.
- Backend `/model-download/session` returns signed segmented artifact metadata.
- Backend `/dev-artifacts/:artifactId` supports byte-range delivery.
- Android and iOS alpha shells both integrate privacy-safe model-catalog and model-download clients.

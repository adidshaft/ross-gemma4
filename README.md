# Ross

Ross is a privacy-first mobile workbench for Indian advocates. It is designed to keep case files on the device while supporting local OCR, indexing, retrieval, chronology generation, issue extraction, evidence review, draft work product, and optional public-law search through a visible privacy boundary.

This repository is a production-grade scaffold for a Kotlin/Compose Android app, a SwiftUI iOS app, a Rust privacy and AI core, and a TypeScript Fastify backend for entitlement and model delivery only.

## Product promise

- Case files are designed to stay on-device.
- OCR, indexing, retrieval, and draft generation are designed to run locally.
- Account, billing, model delivery, and optional public-law search are separated from case data.
- Public-law search requires a sanitized, user-approved public query preview.
- Outputs are drafts for advocate review and must remain source-backed.

## Monorepo layout

```text
ross/
  android/                  Android app scaffold and Compose UX
  ios/                      iOS app scaffold and SwiftUI UX
  backend/                  Fastify entitlement, model delivery, billing stubs
  core/rust/                Shared privacy, redaction, RAG, entitlement logic
  shared/                   Shared schemas, constants, and type references
  docs/                     Product, privacy, legal, billing, and test docs
  scripts/                  CI and local development helpers
  .github/workflows/        CI pipelines
```

## Architecture principles

1. `Case Vault` never imports network modules.
2. No cloud LLM API exists in this repository.
3. No analytics SDK is included by default.
4. Network requests are explicit, constrained, and visible in the Privacy Ledger.
5. Public-law search accepts only a sanitized public query type.
6. Model delivery is post-install and user-approved.

## Capability tiers

During onboarding the apps show only:

- `Quick Start`
- `Case Associate`
- `Senior Drafting Support`

Technical model details are reserved for `Settings > Private AI > Technical Details` and [`docs/MODEL_REGISTRY.md`](./docs/MODEL_REGISTRY.md).

## Repository status

This scaffold includes:

- User-facing onboarding and Private AI Pack flow scaffolding on Android and iOS
- Shared Rust privacy core with redaction, query sanitization, feature gating, and RAG interfaces
- Backend stubs for auth, entitlements, model catalog, model download, and public-law search
- Tests focused on privacy boundaries, model delivery behavior, and source-backed AI behavior
- Documentation for privacy boundaries, threat model, offline behavior, billing notes, and legal positioning

This scaffold does not include actual model binaries, production signing keys, payment credentials, or store-complete billing integrations. Those are represented through production interfaces, development stubs, TODO markers, and tests.

## Getting started

### Prerequisites

- Rust stable toolchain
- Node.js 20+
- Java 17+
- Android Studio / SDK
- Xcode 16+ for iOS work

### Backend

```bash
cd backend
npm install
npm run dev
```

### Rust core

```bash
cd core/rust
cargo test
```

### Android

Open [`android/settings.gradle.kts`](./android/settings.gradle.kts) in Android Studio.

### iOS

Open the Swift package at [`ios/Package.swift`](./ios/Package.swift).

## Compliance posture

The product is a productivity tool for advocates. It is not framed as an AI lawyer, does not present outputs as legal advice, and does not claim blanket compliance guarantees. See:

- [`docs/LEGAL_POSITIONING_NOTES.md`](./docs/LEGAL_POSITIONING_NOTES.md)
- [`docs/PRIVACY_ARCHITECTURE.md`](./docs/PRIVACY_ARCHITECTURE.md)
- [`docs/APP_STORE_BILLING_NOTES.md`](./docs/APP_STORE_BILLING_NOTES.md)


# Ross Gemma4

**A private, local-first AI workbench for access-to-justice legal workflows.**

<p align="center">
  <img src="ios/Ross/Resources/Assets.xcassets/RossLogo.imageset/RossLogo.png" width="180" alt="Ross app logo" />
</p>

<p align="center">
  <a href="./LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-111827.svg" /></a>
  <img alt="Local-first" src="https://img.shields.io/badge/Local--first-private%20case%20files-0f766e.svg" />
  <img alt="Gemma 4" src="https://img.shields.io/badge/Gemma%204-on--device-2563eb.svg" />
  <img alt="iOS and Android" src="https://img.shields.io/badge/iOS%20%2B%20Android-mobile-7c2d12.svg" />
  <img alt="Human review required" src="https://img.shields.io/badge/Human%20review-required-b91c1c.svg" />
</p>

Ross Gemma4 helps advocates and legal-aid teams turn sensitive case bundles into source-grounded chronologies, issue notes, missing-fact checklists, and first drafts without sending private case documents to a cloud LLM.

<p align="center">
  <img src="docs/images/onboarding_welcome.png" width="215" alt="Ross private onboarding screen" />
  <img src="docs/images/dashboard_needs_attention.png" width="215" alt="Ross matter dashboard" />
  <img src="docs/images/ross_mock_case_source_backed_answer.png" width="215" alt="Ross source-backed legal answer" />
</p>

<p align="center">
  <img src="docs/images/gemma_hindi_answer.png" width="260" alt="Gemma 4 answering a Hindi legal query in Ross" />
  <img src="docs/images/gemma_bengali_answer.png" width="260" alt="Gemma 4 answering a Bengali legal query in Ross" />
</p>

## What It Does

- **Private case workbench:** import local case files, ask questions, and keep sensitive client material inside the device sandbox.
- **Source-grounded legal assistance:** produce answers, chronologies, and draft notes from retrieved matter snippets instead of unsupported model memory.
- **On-device Gemma 4 runtime:** run quantized GGUF packs through the iOS `llama.cpp` lane, with capability hooks for MLX/CoreAI where the device can support them.
- **Multilingual workflows:** tested app flows include English, Hindi, and Bengali prompts against the synthetic matter bundle.
- **Human-in-the-loop safety:** Ross is a drafting and analysis aid for legal professionals, not an automated decision-maker or replacement for advocate review.

## Current Status

Ross is an active engineering project, not a packaged App Store release. The repo currently includes:

| Area | Status |
| --- | --- |
| iOS app | Local-first Swift app with matter UI, document import paths, Gemma pack selection, GGUF runtime wiring, and physical-device Quick Start smoke proof. |
| Android app | Native Android prototype with matching product direction and debug build plumbing. Runtime validation still needs broader device QA. |
| Backend | Node service for public-law/catalog style support. Private case files are not intended for backend LLM processing. |
| Model packs | Product-visible Quick Start, Case Associate, and Senior Drafting Support tiers mapped to Gemma 4 GGUF artifacts. Large-model release confidence still requires representative-device QA. |
| Documentation | `docs/NEXT_STEP_REPORT.md` tracks the latest checkpoint and proof notes. |

The latest verified local inference checkpoint is the iOS Quick Start GGUF lane on a physical iPhone using the patched `llama.swift` / `llama.cpp` runtime. The 12B and 26B tiers are intentionally treated as higher-risk until full download, storage-pressure, thermal, and representative-device validation is complete.

## Architecture

```mermaid
flowchart TD
    Advocate["Legal advocate"] --> App["Ross mobile app"]
    App --> Store["On-device matter storage"]
    Store --> Docs["Case documents"]
    Store --> Index["Local retrieval index"]
    App --> Runtime["Local Gemma 4 runtime"]
    Index --> Runtime
    Runtime --> Draft["Source-grounded response"]
    Draft --> Review["Human advocate review"]
    App -. "public-law/catalog only" .-> Backend["Backend services"]
```

Private matter documents are designed to stay local. Backend services should be used for public-law metadata, app support, and non-private catalog workflows only.

## Gemma 4 Capability Packs

| Tier | Pack | Base model | Quantization | Approx. size | Intended use |
| --- | --- | --- | --- | --- | --- |
| Quick Start | `gemma-4-e4b-q4` | Gemma 4 E4B | `UD-Q4_K_XL` | ~5.2 GB | Short legal Q&A, intake review, and smaller matters on constrained phones. |
| Case Associate | `gemma-4-12b-q4` | Gemma 4 12B | `UD-Q4_K_XL` | ~7.8 GB | Balanced chronology building, issue extraction, and everyday drafting support. |
| Senior Drafting Support | `gemma-4-26b-a4b-q4` | Gemma 4 26B-A4B | `UD-Q4_K_XL` | ~17.5 GB | Advanced drafting and workstation-class local analysis. |

Downloaded model files are intentionally not committed to this repository. Model artifacts and their usage remain subject to the applicable upstream model license and terms.

## Repository Map

```text
.
├── android/                 # Android prototype
├── backend/                 # Node backend services and tests
├── docs/                    # QA notes, architecture docs, screenshots
├── ios/                     # Swift iOS app, tests, runtime integration
├── scripts/                 # Audit, model, and runtime helper scripts
└── third_party/patches/     # Local patches used to stabilize dependencies
```

## Quick Start

Clone the repo:

```bash
git clone https://github.com/adidshaft/ross-gemma4.git
cd ross-gemma4
```

Run backend checks:

```bash
cd backend
npm install
npm test
```

Run iOS tests:

```bash
swift test --package-path ios
```

Prepare the patched iOS GGUF runtime when validating local inference:

```bash
./scripts/prepare-patched-llama-runtime.sh
```

Build Android debug:

```bash
cd android
./gradlew assembleDebug
```

Some iOS runtime checks require Xcode, a configured signing team, and enough local disk space for multi-GB model artifacts.

## Verification Commands

```bash
./scripts/audit-ross-gemma4-migration.sh
./scripts/verify-model-artifacts.sh --dev
./scripts/audit-ios-runtime.sh
```

For the current project checkpoint, read [`docs/NEXT_STEP_REPORT.md`](docs/NEXT_STEP_REPORT.md).

## Contributing

Contributions are welcome. Start with [`CONTRIBUTING.md`](CONTRIBUTING.md), open focused pull requests, and avoid committing private matter files, generated model artifacts, secrets, or local build outputs.

Good first contribution areas include documentation polish, test coverage, Android validation, accessibility passes, smaller UI fixes, and reproducible device QA notes.

## Responsible Use

Ross is a legal-workflow assistant for professionals and supervised legal-aid teams. It should not be used for fully automated legal decisions, unsupervised legal advice, or direct-to-consumer representation without qualified human review.

All generated outputs require human advocate review. Source citations and retrieval snippets are aids to review, not proof that an output is complete or legally correct.

## License

This repository is licensed under the [MIT License](LICENSE).

Gemma models, datasets, public-law sources, and other third-party artifacts may have separate licenses or terms. Review those terms before downloading, redistributing, or using them in production.

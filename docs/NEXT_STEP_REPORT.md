# Ross Lawyer Usability Alpha Report

## Branches

- Base branch inspected: `alpha-android-real-proof`
- Working branch created: `alpha-lawyer-usable-app`

## Phase outcome

This phase moved Ross toward a cleaner lawyer-facing product without changing the privacy boundary.

Ross now centers the normal app flow around:

- Home
- Cases
- Capture / Import
- Ask Ross
- Settings

The normal experience is now oriented around:

- private case dashboards
- tasks and reminders
- upcoming dates
- document review
- bottom Ask Ross input
- simple public-law Web toggle with preview and confirmation

This phase did not claim a real local model proof.

That proof remains a separate track. The current usability alpha keeps the real-runtime work behind advanced diagnostics and does not present Ross as a model-runtime demo.

## Product correction delivered

Normal user flows now use lawyer-facing language such as:

- `Draft for advocate review`
- `Source-backed`
- `Case files stay on this device`
- `Needs review`
- `Verified from source`
- `Ready`
- `Still reading`
- `Could not read this clearly`

Technical runtime details are kept behind:

- `Settings > Advanced > Technical diagnostics` on iOS
- `Settings > Private AI > Advanced` on Android

## Functional usability alpha scope

Implemented in the active alpha shell:

- lawyer-focused Home dashboard
- first-class local task model
- task quick-add and mark-done flows
- case summaries with next date, review count, and document count
- case workspace sections for overview, documents, tasks, review, and notes / exports
- recent-document status mapping in plain language
- bottom Ask Ross bar on Home and case flows
- case scope selector in Ask Ross
- Web toggle that is off by default
- sanitized public-law preview before any network request
- clear separation between case-file sources and public-law results
- privacy ledger entries in plain language

## Validation summary

Baseline validation passed before edits for:

- Rust `cargo test`
- backend test, typecheck, and build
- privacy guard scripts
- Android unit tests and debug assemble
- iOS SwiftPM build, Xcode build, Swift tests, and screenshot export

Final validation should be read from the latest command run in the working session and the final response for exact results. This document records the product direction and next step, not a substitute for the final command log.

## Unrelated items

Inspected and intentionally left untouched:

- `SCRIPT.md`
- `artifacts/`

Also noted before work:

- unrelated tracked iOS project changes were already present in `ios/Ross.xcodeproj/project.pbxproj`
- the user-called-out iOS UI files were inspected and not blindly overwritten

## Real-model status

Real local model proof is still separate from this usability alpha.

What this phase does honestly support:

- a stronger lawyer-facing shell
- safer local-only workflows
- cleaner copy
- guarded public-law Web search
- better persistence and task organization

What this phase does not claim:

- a verified production-grade local-model run on Android or iOS
- proven legal accuracy beyond source-backed review
- cloud AI, cloud OCR, analytics, or remote case sync

## Exact next recommended step

Run a short manual product pass on both platforms and record the outcomes in a dedicated QA note:

1. Create a case from Home.
2. Add a task from Home and mark it done.
3. Import a document into a case.
4. Review and correct one extracted field.
5. Ask Ross with Web off and confirm the answer stays local.
6. Ask Ross with Web on and confirm the sanitized preview before search.
7. Generate one export and open the Privacy Ledger.

If those manual flows pass cleanly, the next engineering phase should be:

- physical-device real local model proof, separately documented and separately claimed

# Ross Private Assistant E2E QA - 2026-04-24

Simulator: iPhone 17, iOS 26.4.1

Build: `com.ross.ios` Debug, launched with `ROSS_ALLOW_DEVELOPMENT_MODEL_ARTIFACTS=1` and `ROSS_RUNNING_TESTS=1` for the setup-ready path.

No real model files were downloaded for this QA pass. The ready-state path used the tiny deterministic test artifact behind the development artifact gate.

## Coverage

- Sign-in landing, email chooser, demo account, and fresh account flows.
- Home dashboard, workspace drawer, settings top, and private assistant settings entry.
- Private Assistant not-set-up state, compacted setup cards, recommended Case Associate tier, and all three visible tier labels/sizes.
- Case Associate setup using the development-only tiny artifact.
- Installed/ready state and Advanced > Technical diagnostics boundary.
- Ask Ross setup guidance before/around setup, including the no-source-chip edge case.
- Ask Ross daily-priority/source-backed answer with the private assistant active.

## Screenshots

- `01-ios-sign-in.jpg` - sign-in landing.
- `02-ios-email-access.jpg` - email/demo chooser.
- `03-ios-home-dashboard.jpg` - home dashboard.
- `04-ios-workspace-drawer.jpg` - workspace drawer.
- `05-ios-settings-top.jpg` - settings top.
- `06-ios-settings-private-assistant-entry.jpg` - settings entry for private assistant.
- `07-ios-private-assistant-baseline-noisy.jpg` - pre-fix noisy private assistant setup screen.
- `08-ios-fresh-empty-matter-form.jpg` - fresh-account empty matter flow.
- `09-ios-ask-ross-empty-before-setup.jpg` - pre-fix Ask Ross setup edge case.
- `10-ios-private-assistant-setup-fixed-current.jpg` - post-fix setup screen.
- `11-ios-private-assistant-case-associate-ready.jpg` - Case Associate active/ready.
- `12-ios-private-assistant-installed-ready.jpg` - installed pack ready state.
- `13-ios-advanced-technical-diagnostics.jpg` - technical diagnostics, where model/runtime names are allowed.
- `14-ios-ask-ross-private-assistant-guidance.jpg` - improved setup guidance answer without matter source chips.
- `15-ios-ask-ross-next-actions.jpg` - active-assistant daily-priority answer.

## UX Issues Fixed During QA

- Removed technical wording from the normal setup screen.
- Compacted large private assistant tier cards.
- Kept Case Associate as the normal recommended tier instead of recommending Senior Drafting Support by simulator memory alone.
- Changed visible sizes to user-friendly estimates.
- Fixed contradictory installed-state copy for test-only development artifacts.
- Added Ask Ross guidance for private assistant setup questions.
- Prevented setup guidance from being relabeled as a web-search state or decorated with document source chips.

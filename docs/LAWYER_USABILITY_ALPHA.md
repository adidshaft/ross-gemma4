# Lawyer Usability Alpha

Ross Lawyer Usability Alpha is the phase that turns Ross from a technically deep scaffold into a simpler lawyer-facing mobile product.

## Product goals

Ross should feel like:

- a private case dashboard
- a task and dates organizer
- a document verification workbench
- a source-backed local assistant at the bottom

Ross should not feel like:

- a runtime console
- a pack installer demo
- a developer diagnostics panel
- a generic chat toy

## Delivered shell

The alpha shell now centers the app around:

- Home triage: Today, Needs review, Upcoming dates, Recent files, Ask Ross
- Matter workbench: status strip, next action, review queue, files
- Capture / Import
- Document verification: status, what Ross found, preview, collapsed sources/raw text, advocate note
- Ask Ross with explicit scope and separate public-law review
- Settings with technical diagnostics kept under advanced views

## Delivered behaviors

This phase adds or simplifies:

- Home dashboard with Today, Needs review, upcoming dates, recent files, and one Ask entrypoint
- local task model and quick-add flows
- matter workspace sections that answer what this matter is, what is next, and what needs review first
- simplified document statuses
- document verification flow where accept, edit, and ignore actions stay primary
- bottom Ask Ross composer
- case scope selector
- Web toggle that is off by default
- preview-and-confirm public-law search flow
- privacy-ledger copy in plain language
- advanced-only technical diagnostics

## Copy direction

Normal screens should show:

- `Case files stay on this device`
- `Draft for advocate review`
- `Verified from source`
- `Needs review`
- `Ready`
- `Still reading`

Normal screens should avoid:

- runtime names
- artifact labels
- checksum text
- prompt or schema wording
- provider or fallback internals

## What remains separate

This phase does not prove:

- a real Android local model run
- a real iOS local model run
- law-grade accuracy beyond advocate review

Those remain separate QA and proof tracks.

## Current IA checkpoint

Home asks: what needs attention today?

Matter asks: what is this matter, what is next, and what needs review?

Document asks: what did Ross find, what should the advocate accept, edit, or ignore, and where is the source?

Ask Ross asks: what local scope is being used, whether public law is separate, and which sources support the answer?

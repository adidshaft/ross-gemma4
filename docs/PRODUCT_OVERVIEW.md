# Product Overview

Ross is a privacy-first legal workbench for Indian advocates.

The current alpha should feel like a calm daily matter desk, not a developer console.

## Product shape

The normal app experience is organized around:

- Home
- Matters
- Ask Ross
- Settings

Document import, review, notes, exports, and the Privacy Ledger live inside the matter workflow.

## Morning-use goal

Ross should help a lawyer do this:

1. open Ross in the morning
2. see what needs attention today
3. open the right matter
4. add or review a new file
5. confirm dates, directions, and follow-ups
6. ask Ross a plain question
7. optionally run a public-law search with explicit preview
8. generate a draft note

## Launch and sign-in

The intended launch path is:

1. Language selection
2. Sign in
3. Optional quick unlock
4. Home

Supported sign-in modes in this phase:

- demo mode for local QA
- Google sign-in wiring, ready for manual testing with configured credentials
- Apple sign-in on iOS as a local-only session for now

## Home

Home is the main daily dashboard.

It should answer:

- what needs my attention today
- which dates are coming up
- what still needs review
- which matter to open next

Home sections:

- Today
- Upcoming dates
- Open tasks
- Needs review
- Active matters
- Recent files or activity
- Ask Ross bar

## Matter workflow

Each matter should make it easy to:

- review the summary
- check the next date
- manage tasks and reminders
- open the file room
- review document details
- ask Ross in scope
- generate a note or chronology

## Demo workspace

Demo mode now opens a realistic synthetic workspace instead of a blank app.

Current seeded content includes:

- `Demo Matter: Sharma v. Rana`
- court and case number
- hearing and deadline dates
- open tasks
- demo documents
- review items

This is sample data only and is resettable from Settings.

## Ask Ross

Default behavior:

- `Web search` is off
- Ross answers from local case files only
- case-file sources stay separate and source-backed

Optional public-law behavior:

- the user turns `Web search` on
- Ross builds a generic public-law query locally
- Ross shows the preview
- Ross requires confirmation before sending anything
- public-law results are labeled separately from case-file sources

## Exports

Ross can surface local draft work product such as:

- chronology
- case note
- order summary
- Ross transcript

Outputs should remain framed as `Draft for advocate review`.

## Privacy promises

Ross keeps these user-facing promises:

- `Case files stay on this device`
- `Draft for advocate review`
- `Source-backed`
- `Verified from source`
- `Needs review`
- `Public-law search sends only a sanitized query`

## What this alpha proves and does not prove

This alpha is meant to prove:

- the app can launch and feel usable
- the matter workflow is practical
- public-law preview and confirmation are explicit
- privacy boundaries are preserved

This alpha does not by itself prove:

- real Google OAuth with production credentials
- backend-backed Apple sign-in
- physical-device install completion
- real local model performance on hardware

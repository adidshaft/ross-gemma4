# Product Overview

Ross is a privacy-first legal workbench for Indian advocates.

The current alpha is designed to feel like a simple private mobile app for day-to-day legal work, not a technical AI runtime showcase.

## Core product shape

The normal app experience is organized around:

- Home
- Cases
- Capture / Import
- Ask Ross
- Settings

The main product loop is:

1. Create a case.
2. Add or import documents.
3. Review uncertain extracted details.
4. Track tasks, dates, and reminders.
5. Ask Ross from local case files.
6. Optionally run a sanitized public-law search.
7. Export a chronology, case note, or order summary.

## Home-first experience

Home is the primary dashboard.

It is expected to show:

- greeting and day summary
- items due today
- upcoming dates
- active cases
- open tasks
- review-required items
- recent documents
- a bottom Ask Ross bar

## Ask Ross

Ask Ross is designed as a simple bottom input pattern, available globally and within a case.

Default behavior:

- Web is off
- Ross answers from local case files only
- if Ross cannot find the answer locally, it says `I could not find this in your case files.`

Optional Web behavior:

- the user turns on `Web`
- Ross builds a generic public-law query locally
- Ross shows the query preview
- Ross requires explicit confirmation before sending anything
- Ross labels public-law results separately from case-file sources

## Privacy promises

Ross keeps these user-facing promises:

- `Case files stay on this device`
- `Draft for advocate review`
- `Source-backed`
- `Verified from source`
- `Needs review`
- `Public-law search sends only a sanitized query`

## Private AI positioning

Private AI Pack options remain:

- Quick Start
- Case Associate
- Senior Drafting Support

Normal users see:

- what each pack helps with
- how much space it needs
- whether Wi-Fi is recommended
- whether it is ready, downloading, waiting, or needs attention

Normal users should not need to see runtime identifiers or artifact details.

## Technical diagnostics

Technical diagnostics still exist, but they are not part of the normal product narrative.

They remain hidden under advanced settings and are used for QA, debugging, and real-runtime proof work.

## What this alpha is not

Ross is not:

- a cloud AI case processor
- an AI lawyer
- a developer console
- a remote case-sync product
- a claim of proven real local model performance

Real local model proof remains a separate effort from this usability alpha.

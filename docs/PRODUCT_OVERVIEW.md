# Product Overview

Ross is a privacy-first legal workbench for Indian advocates.

The current internal alpha is designed to feel like a calm private work app, not a developer console.

## Core product shape

The normal app experience is organized around:

- Home
- Cases
- Ask Ross
- Settings

Document import, review, exports, and the Privacy Ledger live inside the Home and matter workflow rather than as separate technical surfaces.

## Launch and auth

The intended launch path is:

1. Language selection
2. Sign in
3. Optional quick unlock
4. Home

Supported sign-in modes in this phase:

- demo mode for local QA
- Google sign-in wiring, ready for manual testing with configured credentials
- Apple sign-in on iOS as a local-only session for now

## Home-first experience

Home is the main daily dashboard.

It should show:

- today summary
- current or active matter
- open tasks
- review items
- next action
- recent files or activity
- Ask Ross bar

## Matter workflow

The core matter loop is:

1. create or open a matter
2. import documents
3. review extracted details
4. ask Ross from local files
5. optionally run a public-law search
6. export a draft
7. inspect the Privacy Ledger

## Ask Ross

Ask Ross is available from Home and within matters.

Default behavior:

- Web is off
- Ross answers from local case files only
- answers remain source-backed

Optional Web behavior:

- the user turns Web on
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

Private AI remains part of the product narrative, but with plain-language status:

- `Ready`
- `Not installed`
- `Downloading`
- `Waiting for Wi-Fi`
- `Needs attention`
- `Using basic local mode`

Technical details remain hidden under advanced settings.

## What this alpha is and is not

This internal alpha is meant to prove:

- the app can launch cleanly
- the core legal workflow is usable
- privacy boundaries are still enforced
- public-law preview and confirmation are explicit

This alpha does not by itself prove:

- real Google OAuth with production credentials
- backend-backed Apple sign-in
- physical-device installation completion
- real local model performance on device

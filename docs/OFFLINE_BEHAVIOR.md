# Offline Behavior

Ross is designed to remain useful when the network is unavailable.

The current dogfood phase assumes the app should still feel usable even when the private assistant is unavailable or the backend cannot be reached.

The current alpha keeps the core matter workflow local-first.

## Works offline

These flows are designed to keep working without network access:

- open the app after a local session already exists
- use demo mode after it has been selected locally
- open Home and Matters
- create and edit matters
- manage tasks and dates
- import PDF, image, and text files into app-private storage
- open the file room
- open the document viewer
- review extracted details
- ask Ross from local case files with `Web search` off
- generate local notes and exports
- inspect the Privacy Ledger

## Works offline in basic local mode

Ross should still remain useful in `Using basic local review`.

That includes:

- basic document reading
- plain-language review status
- matter and task management
- local Ask Ross answers when enough case data exists
- local export generation

## Requires network

These flows still depend on the network:

- Google sign-in
- session refresh for backend-backed sessions
- model catalog checks
- Private AI Pack downloads
- public-law search after the user confirms the preview

## Demo mode note

Demo mode is still local-first:

- it seeds a synthetic workspace locally
- it does not create a cloud Ross account
- it can be reset locally from Settings

## Public-law behavior

Public-law search is never automatic.

If `Web search` is off:

- no public-law request is made
- Ross answers from local case files only

If `Web search` is on:

- Ross builds the query locally
- Ross shows the sanitized preview
- Ross requires explicit confirmation
- no case text, filenames, or party details are sent
- if the live connector is unavailable, Ross may fall back to a privacy-safe backend index

## Degraded behavior

Expected plain-language degraded states include:

- `Using basic local mode`
- `Using basic local review`
- `Still reading`
- `Needs review`
- `Could not read this clearly`
- `Public-law search is unavailable right now. Your case files were not sent.`

Normal screens should not expose backend or runtime jargon in these states.

## Real-runtime note

This document describes the product behavior Ross is designed to preserve.

It is not a claim that a real local model has already been proven on hardware.

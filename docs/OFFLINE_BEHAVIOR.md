# Offline Behavior

Ross is designed to remain useful when the network is unavailable.

The current internal alpha keeps the core matter workflow usable on device.

## Works offline

These flows are designed to work without network access:

- open the app after a local session already exists
- use demo mode after it has been selected locally
- open Home and Cases
- create and update matters
- import PDF, image, and text files into app-private storage
- open the document viewer
- review extracted details
- ask Ross from local case files with Web off
- generate local exports
- inspect the Privacy Ledger

## Works offline with no Private AI Pack installed

Ross should still remain useful in `Using basic local mode`.

That includes:

- basic local document reading
- plain-language review status
- matter and task management
- local Ask Ross responses where enough case data exists
- local export generation

## Requires network

These flows still depend on the network:

- Google sign-in
- session refresh for backend-backed sessions
- model catalog checks
- Private AI Pack download setup
- public-law search after the user approves a sanitized preview

## Public-law behavior

Public-law search is never automatic.

If Web is off:

- no public-law request is made
- Ross answers from local case files only

If Web is on:

- Ross builds the public-law query locally
- Ross shows the sanitized preview
- Ross requires explicit confirmation
- no case text, filenames, or party details are sent

## Degraded behavior

Expected plain-language degraded states include:

- `Using basic local mode`
- `Still reading`
- `Needs review`
- `Could not read this clearly`
- `Could not search public law right now. Your files stayed on this device.`

Normal user screens should not expose backend or runtime jargon in these states.

## Real-runtime note

This document describes product behavior that should remain true even without a network connection.

It is not a claim that a real local model has already been proven on hardware.

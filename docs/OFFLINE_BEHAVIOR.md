# Offline Behavior

Ross is useful even when the network is unavailable.

The current usability alpha is built so the main case workflow still works locally.

## Works offline

The following flows are designed to work without network access:

- create a case
- open Home and Cases
- add and complete tasks
- import PDF, image, and text documents into app-private storage
- run local document reading and review
- open document viewer and source-backed review UI
- accept, edit, or ignore extracted details
- ask Ross from local case files with Web off
- generate local exports
- inspect the Privacy Ledger

## Works offline with no Private AI Pack installed

Ross still supports:

- basic local document reading
- plain-language review status
- local task management
- local-only case answers where enough case data exists
- local exports

In that state, Ross should present itself as using `basic local mode`, not as a failed technical runtime.

## Requires network

These flows remain network-dependent:

- model catalog checks
- Private AI Pack download setup
- development artifact delivery
- entitlement refresh
- public-law search after the user approves a sanitized preview

## Public-law search behavior

Public-law Web search is not automatic.

If Web is off:

- no public-law network request is made
- Ross answers from local case files only

If Web is on:

- Ross builds the public-law query locally
- Ross shows the sanitized preview
- Ross requires explicit user confirmation before sending it
- no case files or document text are sent

## Degraded behavior

If Ross cannot complete a richer private review path, the app should still remain useful and calm.

Expected degraded states include:

- `Using basic local mode`
- `Still reading`
- `Needs review`
- `Could not read this clearly`

The app should avoid exposing runtime jargon in these normal user flows.

## Real-runtime note

Real local model proof remains separate from offline product usability.

This document describes the offline product behavior the lawyer can rely on today, not a claim that a real runtime has been proven on hardware in this phase.

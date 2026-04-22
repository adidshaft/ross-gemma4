# Public-Law Sanitization Rules

This document records the public-law sanitization behavior Ross is expected to preserve in the current dogfood phase.

## Goal

Ross must preserve legal research meaning while stripping private matter details.

The sanitizer should:

- keep legally meaningful citation patterns intact
- strip private or case-specific matter details
- require explicit preview and confirmation before search
- ensure the approved preview query matches the query that is sent

## Preserve

These are representative examples that must survive sanitization:

- `Order 39 Rules 1 and 2 CPC temporary injunction`
- `Order 7 Rule 11 CPC`
- `Order 41 Rule 27 CPC`
- `Section 138 NI Act notice limitation`
- `Section 482 CrPC quashing FIR`
- `Section 438 CrPC`
- `Section 439 CrPC`
- `Section 34 IPC`
- `Section 420 IPC`
- `Article 226 Constitution of India writ mandamus`
- `Article 227 Constitution of India`
- `Section 9 Arbitration Act`
- `Section 11 Arbitration Act`
- `Section 13 Commercial Courts Act`
- `Section 125 CrPC`
- `Section 498A IPC`
- `Section 25 Hindu Marriage Act`
- `Section 24 Hindu Marriage Act`
- `Section 17 Domestic Violence Act`
- `delay filing written statement 120 days Commercial Courts Act`
- `limitation condonation Section 5 Limitation Act`

Rule:

- do not strip numbers merely because they are numbers
- preserve numbers when they are attached to legal concepts such as `Order`, `Rule`, `Rules`, `Section`, `Article`, `CPC`, `CrPC`, `IPC`, `NI Act`, `Constitution`, `Arbitration Act`, `Limitation Act`, `Commercial Courts Act`, `Domestic Violence Act`, and `Hindu Marriage Act`

## Strip or block

These are representative patterns that must not cross the public-law boundary:

- party names
- client names
- matter names
- filenames
- exact case numbers
- phone numbers
- email addresses
- addresses
- private factual narratives
- `my client`
- `this matter`
- `our case`
- `the attached order`
- `file demo-order.pdf`

Fake-secret regression values that must be stripped or blocked:

- `Raghav Fakepriv`
- `9876501234`
- `fakepriv@example.com`
- `FAKE/123/2026`
- `blue suitcase near temple`

## Query matching rule

The approved preview query must equal the query that is sent to the backend.

That means:

- preview text cannot silently differ from the transmitted query
- backend forwarding tests must use the exact approved query
- clients must not mutate the confirmed query after approval

## Current test coverage

Current tests in this repo cover:

- citation preservation in Rust
- citation preservation in iOS
- citation preservation in Android
- backend forwarding of the exact approved query
- fake-secret stripping and blocking

Representative covered cases include:

- `Order 39 Rules 1 and 2 CPC temporary injunction`
- `Section 138 NI Act notice limitation`
- `Section 482 CrPC quashing FIR`
- `Article 226 Constitution of India writ mandamus`

## Boundary rule

Gemini may only be used server-side for public-law search.

Mobile apps must:

- never call Gemini directly
- never send private matter text
- never send filenames, party names, client names, or factual narratives
- only send the approved sanitized public-law query

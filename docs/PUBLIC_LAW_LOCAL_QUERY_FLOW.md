# Public-Law Local Query Flow

This document records the current public-law flow Ross is expected to preserve.

## Rules

- `Web Search` is off by default
- the mobile app must shape the query locally first
- the user must see a preview before search
- only the approved sanitized query may be sent
- Gemini is server-side only
- private matter text, filenames, party names, client names, and OCR passages must not be sent

## Expected flow

1. user asks a question
2. Ross first handles it locally
3. if `Web Search` is off, Ross stays local-only
4. if `Web Search` is on, Ross prepares a generic public-law query locally
5. Ross shows the preview
6. the user confirms search
7. the app sends only the sanitized query to the Ross backend
8. the backend performs public-law retrieval
9. the app renders public-law results separately from case-file sources

## Backend URL patterns

iOS simulator:

- `http://127.0.0.1:8787` was the manual proof URL in this session

Android emulator:

- default documented path is `http://10.0.2.2:8080`
- if your backend runs on a different port, use the matching `10.0.2.2:<port>` override

Physical device:

- `http://<your-mac-lan-ip>:<port>`

## Fresh proof

### iOS

Freshly proven in this session:

- `Web Search` off stayed local for a matter-specific question
- turning `Web Search` on produced a preview before the backend request
- confirming a generic public-law question returned results
- the result view separated case-file material from public-law results

Freshly observed issue:

- citation sanitization is too aggressive for some legal references such as `Order 39 Rules 1 and 2 CPC`

### Android

Freshly proven in this session:

- the tools sheet can toggle `Web Search` on
- the privacy copy says Ross only sends a sanitized public-law query

Not yet proven in this Android pass:

- preview -> confirm -> results

## Failure copy

The user-facing failure message should remain:

- `Public-law search is unavailable right now. Your case files were not sent.`

Normal UI must not expose:

- `Gemini`
- raw provider errors
- HTTP internals
- endpoint paths
- stack traces

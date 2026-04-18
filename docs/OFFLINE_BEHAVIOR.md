# Offline Behavior

## Works without a Private AI Pack

- Complete onboarding and reach the case list
- Create a case matter
- Import PDF, image, or text files into encrypted app-private storage metadata and app-private file storage
- Open the document list and document viewer
- Review source refs and jump from source chips into document context
- Generate local PDF exports that remain on-device
- Review prior Privacy Ledger entries

## Works with Quick Start

- Everything above
- Instant Mode style short local review flows
- Smaller local case questions
- Basic chronology and short-note style exports

## Works with Case Associate

- Everything in Quick Start
- Broader source-backed case review
- Heavier chronology and issue workflows
- Better sustained document navigation and local drafting support

## Works with Senior Drafting Support

- Everything in Case Associate
- Longer-file drafting support
- Deeper issue extraction and hearing-prep style outputs
- Larger local review sessions once the pack is installed

## Requires network

- Model catalog checks
- Model-download session setup
- Dev-artifact byte delivery for backend-connected download flows
- Entitlement refresh
- Public-law search after the user approves the sanitized preview

## Degraded or waiting behavior

- If no pack is installed, Ross still supports capture, organization, imports, source navigation, and local exports.
- If Quick Start is installed, Ross can keep short local review flows available while larger packs are still pending.
- Public-law search remains blocked until the user confirms the sanitized preview.
- Larger model-pack installs can pause for Wi-Fi or explicit mobile-data approval.
- Android currently keeps public-law execution and pack delivery on local alpha/dev paths even though the backend contracts and tests are in place.
- iOS can call the hardened backend for sanitized public-law search and model-download metadata, then falls back to a local dev artifact if the backend is unavailable.
- iOS extracts native PDF text locally where available and runs Vision OCR for images; Android still needs ML Kit wiring for real image OCR.

## User messaging

- Explain what still works immediately.
- Explain which larger workflows are waiting for the Private AI Pack.
- State clearly that case files stay on this device and are unaffected by delayed network tasks.

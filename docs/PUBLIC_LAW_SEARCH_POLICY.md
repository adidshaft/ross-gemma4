# Public-Law Search Policy

Public-law search is optional and distinct from private case work.

## Allowed flow

1. User requests public-law support
2. App builds a sanitized public query locally
3. App shows the query preview
4. User explicitly confirms
5. Backend proxy searches approved public or licensed sources
6. Results return as titles, citations, snippets, and links
7. Results are cached locally as public-law material

## Never send

- Case ID
- Document ID
- Filename
- OCR text
- Chunk text
- Embeddings
- Prompt text
- Chat history
- Client or party names
- Phone numbers
- Email addresses
- Case numbers
- Long pasted factual passages

## Backend policy

- Reject payloads containing case-related fields
- Log only minimal abuse metadata
- Do not log full search query in production
- Use official, public, or licensed sources only


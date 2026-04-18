# Test Strategy

## Priorities

1. Privacy boundary enforcement
2. Model delivery reliability
3. Source-backed AI behavior
4. Offline-first case workflows
5. Cross-platform parity of product logic

## Test layers

- Rust unit tests for redaction, query sanitization, RAG, entitlement verification, and feature gating
- Backend unit and integration tests for payload rejection and signed responses
- Android unit tests for pack selection, download policies, and privacy ledger wiring
- iOS unit tests for capability gating, download state recovery, and onboarding visibility
- Fixture-based alpha extraction tests for source refs, mixed-language heuristics, and review-queue behavior

## Must-pass privacy tests

- Fake-secret exfiltration regression
- Public query sanitization
- Boundary import rules
- No case fields on backend endpoints
- Privacy Ledger classification correctness

## Harness limits

- The current alpha harness is good at checking contract shape and safety.
- It is not a substitute for measuring a real on-device model's accuracy, latency, memory pressure, or device-specific failure modes.
- When docs mention the local runtime, they mean the implemented runtime contract plus deterministic fallback behavior unless a real bundled inference adapter is explicitly called out.

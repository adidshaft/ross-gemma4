# Threat Model

## Assets to protect

- Case files
- OCR text
- Derived summaries and chronologies
- Embeddings
- Draft work product
- Entitlement tokens
- Model pack integrity metadata

## Primary threats

1. Accidental network exfiltration of private case facts
2. Over-permissive public-law query generation
3. Device compromise or shared-device exposure
4. Corrupt or tampered model downloads
5. Logs or diagnostics containing sensitive content
6. Confused-deputy boundary failures between case modules and network modules

## Controls

- Encrypted local storage abstractions
- Key material in Android Keystore and iOS Keychain
- Explicit network allowlist
- Typed sanitized query boundary
- Signed manifests and checksum verification
- Privacy Ledger for all outbound traffic
- Fake-secret exfiltration tests
- Feature gating that fails closed
- Optional app lock and biometric unlock

## Residual risks

- Rooted or jailbroken devices reduce local guarantees
- Compromised OS backups can expose app-private files
- Production-grade secure enclave or keystore behavior varies by device
- OCR quality may affect downstream summaries if advocates do not review uncertain fields


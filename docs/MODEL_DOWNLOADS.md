# Model Downloads & Validation

To operate in full production mode, ROSS-Gemma4 requires secure, offline inference artifacts for the active Gemma 4 capability packs.

## Active Capability Tiers
1. **Quick Start**: `gemma-4-e4b-q4` (`bartowski/google_gemma-4-E4B-it-GGUF`, Q4_K_M)
2. **Case Associate**: `gemma-4-12b-q4` (`ggml-org/gemma-4-12B-it-GGUF`, Q4_K_M)
3. **Senior Drafting Support**: `gemma-4-26b-a4b-q4` (`bartowski/google_gemma-4-26B-A4B-it-GGUF`, Q4_K_M)

## Desired Format
The desired artifact format for mobile/local inference is `GGUF`. The product-visible tiers use `Q4_K_M`. The older Flash pack remains only as a compatibility and recovery path.

## Download & Verification Process
The iOS registry now uses direct Hugging Face GGUF URLs. Catalog SHA-256 values may be empty when the upstream provider exposes the digest during preflight; Ross stores that provider checksum after HEAD/range validation and validates the GGUF can open before activating it.

Current proof:

1. `--local-model-smoke` ran real simulator GGUF inference on 2026-06-02.
2. The smoke passed English source grounding, Bengali Bangla-script grounding, Hindi Devanagari grounding, and a general cautious answer.
3. Live Hugging Face probes on 2026-06-02 confirmed the configured assistant URLs resolve, expose linked ETags matching the pinned SHA-256 values, advertise range support, and return `206 Partial Content` for one-byte range GETs.
4. Swift tests cover preflight parsing, range probes, checksum/provider digest handling, startup recovery, repair, and artifact removal.

Still required before claiming physical-device production readiness:

1. Download a full configured GGUF on a physical iPhone.
2. Exercise pause/resume, checksum/provider digest handling, runtime validation, repair, and re-download.
3. Ask from imported PDF/image/text files in English, Hindi, and Bengali.
4. Record performance, storage, privacy, and fallback status.

**Important**: 
- Never fabricate real URLs or checksums.
- Keep model files out of the repository.
- Treat simulator proof separately from physical-device performance proof.

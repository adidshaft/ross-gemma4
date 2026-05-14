# iOS Real-Device Regression CI

Ross must pass on an actual attached iPhone before a build is considered reliable. Simulator checks catch compilation and layout regressions; device checks catch model download, storage pressure, and llama.cpp runtime failures.

## GitHub Actions

The main CI workflow now has two iOS lanes:

- `ios-simulator-build`: runs on hosted macOS and builds the app for a generic iOS Simulator destination.
- `ios-real-device-smoke`: manual `workflow_dispatch` lane for a self-hosted macOS runner labeled `macOS` and `iOS-device`.

## Self-Hosted Runner Requirements

- Xcode installed and selected with `xcode-select`.
- One trusted, unlocked iPhone connected over USB.
- A valid Apple development team configured locally for device signing.
- The runner must not store production passwords or open the Passwords app.
- Labels: `self-hosted`, `macOS`, `iOS-device`.

## Required Manual Smoke

After the real-device build, run this product smoke before release:

1. Install Ross on the attached iPhone.
2. Set up the private assistant and verify the selected Gemma 4 GGUF model is present.
3. Create a new matter.
4. Bulk-import 5-10 local PDFs or text files.
5. Confirm file status reaches readable/ready without flipping to failed because the model is missing.
6. Ask 4-5 Ross chat questions against tagged files.
7. Ask at least one Hindi and one Bengali question, and confirm the answer stays in the requested script.
8. Run Today and Routines once, then confirm no duplicate loading cards and no stale matter list.
9. Open Ross assistant settings and check storage diagnostics for model, resume, interrupted downloads, and device cache bytes.

## Failure Policy

Any failure in setup, import, local answer generation, multilingual output, or storage reclamation blocks release. Capture the device log and the Settings storage breakdown before retrying so the failure remains diagnosable.

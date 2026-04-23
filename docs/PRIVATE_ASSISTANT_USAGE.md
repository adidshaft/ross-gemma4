# Private Assistant Usage

Ross treats the Private AI Pack as the private assistant on this device.

This phase now separates the iPhone system assistant path from Android model-artifact downloads.

## User-facing status copy

Normal UI should use only plain-language statuses:

- `Private assistant is not set up`
- `Setting up private assistant`
- `Waiting for Wi-Fi`
- `Private assistant needs attention`
- `Using basic local review`
- `Private assistant is ready`

## What the user should understand

When the private assistant is not ready:

- matters still work
- tasks and dates still work
- document import still works
- basic local review still works
- Ask Ross can still answer simple local questions

When the private assistant is ready:

- Ask Ross is the main control surface
- Ross can interpret everyday requests more naturally
- Ross can shape public-law queries locally before preview
- private matter work remains on-device

## Model source in this alpha

On iPhone, Ross uses the private assistant supplied by iOS when the device supports it. The app does not download a model from Gemma 4 local runtime or Hugging Face inside the iPhone app.

On Android, Ross can install a compatible MediaPipe `.task` artifact from the Ross backend when the backend is explicitly configured with an external model file outside the repo. The app stores the downloaded artifact in app-private storage and loads it locally; case files are not sent with model catalog or download requests.

## Privacy boundary

The private assistant may work with local matter data on-device.

It may not:

- send private matter content off-device
- call Gemini directly
- search public law without preview and user confirmation
- expose technical runtime detail in normal UI

Normal UI should keep these promises visible:

- `Case files stay on this device`
- `Public-law search sends only a sanitized query`
- `Using basic local review`
- `Private assistant is ready`

## Advanced-only details

These belong only under `Settings -> Advanced -> Technical diagnostics`:

- runtime details
- checksums
- model paths
- provider details
- failure traces

## Current proof status

Validated by automated tests on 2026-04-23:

- iOS setup can create a `system_model` private assistant pack without a downloaded file when the on-device assistant is available.
- iOS Ask Ross still supports local file answers, task/date commands, exports, and public-law preview flow.
- Android downloaded real-model artifacts keep their `.task` filename so MediaPipe can load them from app-private storage.
- Android Ask Ross now attempts a model-backed matter answer when an installed real local pack is available, and keeps deterministic local fallback when not.
- Android task/date/export dock commands still pass automated tests.

Still not proven in this run:

- a live iPhone manual setup tap proving Apple on-device assistant availability on Aman's specific device
- a real Android `.task` model executing on a physical Android device
- a production model-delivery source

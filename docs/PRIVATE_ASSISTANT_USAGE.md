# Private Assistant Usage

Ross treats the Private AI Pack as the private assistant on this device.

This phase is about product usability, not a claim of real local-model proof on hardware.

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

Freshly observed in the latest iOS manual pass:

- plain-language private assistant copy exists
- the app remains usable in local mode

Freshly observed in the latest Android manual pass:

- the Ask Ross tools sheet uses plain-language `Web Search` privacy copy

Still not proven in this phase:

- a real downloaded local model running on-device
- full manual walkthrough of every private assistant state on both platforms

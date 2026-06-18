# Contributing to Ross Gemma4

Thanks for helping improve Ross Gemma4. This project handles legal-workflow concepts, so contributions should be careful, reproducible, and explicit about privacy and safety tradeoffs.

## Ground Rules

- Do not commit private case files, secrets, tokens, `.env` files, downloaded model weights, device logs with personal data, or local build outputs.
- Keep pull requests focused. One behavior change, bug fix, or documentation improvement per PR is easiest to review.
- Treat generated legal text as draft assistance only. Do not remove human-review safeguards or source-grounding boundaries without a clear design discussion.
- Prefer tests or reproducible QA notes for runtime, storage, and performance changes.

## Local Setup

```bash
git clone https://github.com/adidshaft/ross-gemma4.git
cd ross-gemma4
```

Backend:

```bash
cd backend
npm install
npm test
```

iOS:

```bash
swift test --package-path ios
./scripts/prepare-patched-llama-runtime.sh
```

Android:

```bash
cd android
./gradlew assembleDebug
```

## Pull Request Checklist

- Explain the user-facing change and why it is needed.
- List the exact checks you ran.
- Add screenshots or short screen recordings for UI changes.
- Note any device, simulator, model-pack, or storage assumptions.
- Confirm no private data, model weights, or generated build artifacts are included.

## Good First Issues

- Improve docs and setup reproducibility.
- Add focused tests around parsing, retrieval, and model-pack validation.
- Improve accessibility labels and dynamic type behavior.
- Validate Android flows on real devices and document results.
- Tighten storage cleanup and interruption recovery for model downloads.

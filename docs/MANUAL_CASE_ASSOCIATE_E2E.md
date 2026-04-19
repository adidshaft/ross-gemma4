# Manual Case Associate E2E

This script validates the `Case Associate` workflow from setup through privacy review.

Use it whether you are running the deterministic development runtime or an optional real local runtime. Only call the run "real local inference" if the runtime details explicitly show the real runtime mode.

## Alpha proof update

- Use the Technical details screen to confirm runtime mode before making any claim.
- For Android, prefer the built-in `Run local inference smoke` action before a full document run.
- For iOS, keep the smoke action behind explicit opt-in and compatible runtime availability.
- Accepted fields must remain source-backed and verifier-gated.

## 1. Fresh install

- Install a fresh debug build on Android or iOS.
- Launch Ross.

Expected:

- onboarding loads cleanly
- the app still says `Case files stay on this device`
- no technical model names appear in onboarding

Fail if:

- the app crashes
- onboarding promises cloud processing
- onboarding shows technical runtime names

## 2. Complete or skip Private AI Pack setup

- Continue through `Quick Start`, `Case Associate`, or `Senior Drafting Support`
- Or skip the pack flow and confirm Basic mode still works

Expected:

- the workbench loads either way
- extraction quality labels stay user-facing

## 3. Configure the runtime path

Choose one:

- Deterministic baseline:
  - install the normal dev artifact
  - do not enable real local inference
- Optional real Android runtime:
  - follow [ANDROID_REAL_INFERENCE_QA.md](/Users/amanpandey/projects/ross/docs/ANDROID_REAL_INFERENCE_QA.md)
- Optional real iOS runtime:
  - follow [MANUAL_LOCAL_INFERENCE_QA.md](/Users/amanpandey/projects/ross/docs/MANUAL_LOCAL_INFERENCE_QA.md)

Expected:

- deterministic runs show `deterministic_dev`
- real runs show the configured real runtime mode

## 4. Confirm extraction quality changes

- Open `Settings > Private AI`
- Review the active pack and technical details

Expected:

- `Case Associate` shows deeper extraction quality than Basic
- fallback state is explicit
- runtime availability is explicit

Fail if:

- the app hides fallback state during manual QA
- runtime mode is ambiguous

## 5. Import a PDF or image sample

- Import a short legal fixture
- Confirm the file lands in the local case workspace

Expected:

- import succeeds without uploading the file
- the document viewer shows source chips or source panel metadata

## 6. Run extraction

- Start extraction under `Case Associate`
- Wait for acquisition, extraction, and verification to finish

Expected:

- the app does not freeze or crash
- extraction completes or falls back safely
- long files do not cause a fatal failure

## 7. Review extracted details

Check:

- court
- case number
- dates and next date
- sections
- order directions
- issues or relief candidates if present

Expected:

- accepted fields are source-backed
- weak fields show `Needs advocate review`
- unsupported values are not silently accepted

## 8. Accept, edit, or ignore fields

- Accept a correct field
- Edit one uncertain field
- Ignore one field if needed

Expected:

- the review queue updates
- corrected values stay local
- later public-law suggestions use verified or user-corrected legal concepts only

## 9. Tap source chips

- Open at least one source chip from a reviewed field

Expected:

- the app lands on the cited page or source panel
- source references remain visible even when exact highlight placement is best-effort

## 10. Generate a case note or order summary

- Create a local note or summary from the reviewed document

Expected:

- the result is framed as `Draft for advocate review`
- the output remains `Source-backed`

## 11. Export PDF or report output

- Export a report or summary artifact

Expected:

- export completes locally
- output remains in app-private storage or the local export surface

## 12. Open Privacy Ledger

- Review the most recent ledger entries

Expected:

- no model-network event exists
- public-law search entries, if any, say only a sanitized query crossed the boundary

## 13. Validate sanitized public-law preview

- Open Public Law
- Generate a preview from reviewed extraction or a manual query

Expected:

- preview is mandatory before the backend request
- preview keeps legal concepts but strips party names, case numbers, phone numbers, email addresses, and private narrative facts

Fail if:

- the request sends without a preview
- the preview includes private identifiers

## 14. Record the runtime honestly

Record one of these outcomes:

- `deterministic_dev`
- `mediapipe_llm`
- `apple_foundation_models`
- `fallback_active`

Only record a real local inference success if:

- the technical details show the real runtime as available
- `Last invocation runtime` matches the real runtime
- schema validation and verifier checks still passed
- no network model request occurred

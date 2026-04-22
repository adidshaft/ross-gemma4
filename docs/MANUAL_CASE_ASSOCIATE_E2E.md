# Manual Case Associate E2E

This script validates the lawyer-facing matter and document loop in Ross.

Use it for manual product QA. Do not use it to claim a real local-model proof.

For the latest truth in status, pair this script with [`docs/PRODUCT_PROOF_QA.md`](/Users/amanpandey/projects/ross/docs/PRODUCT_PROOF_QA.md).

Current known environment blockers on April 23, 2026:

- iOS simulator inline review taps are flaky in this environment and can throw Ross to SpringBoard instead of reliably pressing visible review buttons
- Android emulator boots and accepts the APK, but the app does not launch through `adb`

## 1. Launch and sign in

Steps:

- open the app
- choose a language if prompted
- use `Open demo mode`

Expected:

- no technical model names appear in normal auth screens
- demo mode clearly reads as local testing only
- the app lands on Home after sign-in

## 2. Confirm Home

Expected:

- Home feels like a private daily dashboard
- it shows today summary, dates, tasks, review items, active matters, and Ask Ross

## 3. Create or open a matter

Steps:

- either use the seeded demo matter or tap `Create matter`
- save title, court, case number, and next date

Expected:

- the matter appears on Home and in the matter list
- the matter opens as a private workspace

## 4. Add tasks and dates

Steps:

- add one task
- add one hearing or deadline date

Expected:

- both appear in the matter and Home
- counts stay coherent

## 5. Import a document

Steps:

- open the matter
- import a PDF, image, or text file

Expected:

- the file appears in the file room
- the viewer opens
- status stays plain-language

Expected statuses:

- `Ready`
- `Still reading`
- `Needs review`
- `Could not read this clearly`

## 6. Review extracted details

Steps:

- open the document viewer
- accept one field
- edit one field
- ignore one field if needed

Expected:

- review counts update
- corrected values remain local
- source references remain visible

## 7. Create follow-up work from review

Steps:

- create a task or date from a review item where supported

Expected:

- the follow-up appears in the matter
- Home reflects the change

## 8. Ask Ross with Web off

Steps:

- keep `Web search` off
- ask about the matter or document

Expected:

- Ross answers from local case files only
- case-file sources are shown separately
- if Ross cannot answer, it stays local and says so plainly

## 9. Ask Ross with Web on

Steps:

- turn `Web search` on
- ask a public-law question such as `Order 39 Rules 1 and 2 CPC temporary injunction`

Expected:

- Ross explains that only a sanitized public-law query will be sent
- Ross shows the query preview
- Ross requires explicit confirmation before sending anything
- the approved preview query matches the query that is sent
- legal citations survive sanitization
- public-law results are shown separately from case-file sources

Fail if:

- the search runs without preview
- private case wording is sent

## 10. Export

Steps:

- open `Notes / Exports`
- generate a chronology, case note, or order summary

Expected:

- output is framed as `Draft for advocate review`
- export remains local

## 11. Privacy Ledger

Steps:

- open Privacy Ledger

Expected:

- entries are understandable to a lawyer
- no raw payloads appear
- a public-law entry says only that a generic public-law query crossed the boundary

## 12. Settings and Advanced

Steps:

- open Settings
- open Advanced only if needed

Expected:

- diagnostics are hidden from normal screens
- normal settings remain plain-language

## 13. What not to claim from this pass

Do not claim from this manual pass alone:

- a real local model proof
- legal advice
- proven legal accuracy without advocate review
- proven real Google OAuth unless you actually ran it
- proven backend-backed Apple sign-in
- proven quick unlock on real hardware

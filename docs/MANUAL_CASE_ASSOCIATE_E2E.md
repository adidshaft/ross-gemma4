# Manual Case Associate E2E

This script validates the lawyer-facing `Case Associate` workflow in the current usability alpha.

Use it for a manual app pass, not for claiming a real local-model proof.

## 1. Launch the app

Expected:

- onboarding is short
- Ross says `Case files stay on this device`
- no technical model names appear in onboarding

## 2. Complete or skip Private AI Pack setup

Expected:

- Quick Start, Case Associate, and Senior Drafting Support are shown with user-facing descriptions
- the app can continue even if pack setup is skipped
- technical diagnostics are not shown here

## 3. Land on Home

Expected:

- Home feels like a clean private case dashboard
- Home shows cases, tasks, dates, recent documents, and review-required items
- the Ask Ross bar is visible at the bottom

## 4. Create a case

Steps:

- tap `Create Case`
- save a case title and forum

Expected:

- the case appears on Home
- the case appears in Cases
- the case opens as a private workspace

## 5. Add a task

Steps:

- add a task from Home or a case workspace
- mark it done

Expected:

- the task appears under Today or Tasks
- the task can be marked done and reopened
- the task remains local

## 6. Import a document

Steps:

- open a case
- import a PDF, image, or text file

Expected:

- the document appears in Documents
- the status is shown in plain language
- the viewer opens

Expected plain-language statuses:

- `Ready`
- `Still reading`
- `Needs review`
- `Low confidence scan`
- `Could not read this clearly`

## 7. Review extracted details

Steps:

- open Review or the document viewer
- accept one field
- edit one field
- ignore one field if needed

Expected:

- review counts update
- corrected values remain local
- source references remain visible

## 8. Ask Ross with Web off

Steps:

- keep `Web` off
- ask about a case or document

Expected:

- Ross answers from local case files only
- case-file sources are shown separately
- if Ross does not find the answer, it says `I could not find this in your case files.`

## 9. Ask Ross with Web on

Steps:

- turn `Web` on
- ask a public-law question

Expected:

- Ross explains that only a generic public-law query will be sent
- Ross shows `Public-law query to be sent`
- Ross requires explicit confirmation before sending anything
- public-law results are shown separately from case-file sources

Fail if:

- the search runs without preview
- case text or document text is sent

## 10. Export

Steps:

- generate a chronology, case note, or order summary

Expected:

- output is framed as `Draft for advocate review`
- export stays local

## 11. Privacy Ledger

Steps:

- open Privacy Ledger

Expected:

- entries are understandable to a lawyer
- no raw payloads appear
- a public-law search entry says only that a sanitized query crossed the boundary

## 12. What not to claim from this pass

Do not claim from this manual pass alone:

- a real local model proof
- legal advice
- proven legal accuracy without advocate review

That proof work remains separate from this usability-alpha checklist.

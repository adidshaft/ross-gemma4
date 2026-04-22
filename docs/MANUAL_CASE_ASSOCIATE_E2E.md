# Manual Case Associate E2E

This script validates the lawyer-facing `Case Associate` workflow in the current internal alpha.

Use it for manual product QA. Do not use it to claim a real local-model proof.

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

- Home feels like a private legal dashboard
- it shows today summary, matters, tasks, review items, recent files, and Ask Ross

## 3. Create a matter

Steps:

- tap `Create matter`
- save a matter title and basic forum details

Expected:

- the matter appears on Home
- the matter appears in Cases
- the matter opens as a private workspace

## 4. Import a document

Steps:

- open the matter
- import a PDF, image, or text file

Expected:

- the file appears in the matter file room
- the viewer opens
- status stays plain-language

Expected plain-language statuses:

- `Ready`
- `Still reading`
- `Needs review`
- `Could not read this clearly`

## 5. Review extracted details

Steps:

- open Review or the document viewer
- accept one field
- edit one field
- ignore one field if needed

Expected:

- review counts update
- corrected values remain local
- source references remain visible

## 6. Ask Ross with Web off

Steps:

- keep `Web` off
- ask about the matter or document

Expected:

- Ross answers from local case files only
- case-file sources are shown separately
- if Ross cannot answer, it stays local and says so plainly

## 7. Ask Ross with Web on

Steps:

- turn `Web` on
- ask a public-law question

Expected:

- Ross explains that only a sanitized public-law query will be sent
- Ross shows the query preview
- Ross requires explicit confirmation before sending anything
- public-law results are shown separately from case-file sources

Fail if:

- the search runs without preview
- case text or document text is sent

## 8. Export

Steps:

- generate a chronology, case note, or order summary

Expected:

- output is framed as `Draft for advocate review`
- export stays local

## 9. Privacy Ledger

Steps:

- open Privacy Ledger

Expected:

- entries are understandable to a lawyer
- no raw payloads appear
- a public-law search entry says only that a sanitized query crossed the boundary

## 10. Advanced diagnostics

Steps:

- open Settings
- open Advanced
- open Technical diagnostics only if needed

Expected:

- diagnostics are hidden from normal screens
- normal settings remain plain-language

## 11. What not to claim from this pass

Do not claim from this manual pass alone:

- a real local model proof
- legal advice
- proven legal accuracy without advocate review
- proven real Google OAuth unless you actually ran it
- proven backend-backed Apple sign-in

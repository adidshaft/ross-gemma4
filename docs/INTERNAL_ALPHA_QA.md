# Internal Alpha QA

This checklist is the general manual QA script for Ross on April 22, 2026.

Record pass or fail, platform, screenshot path, and any blocker at each step.

## 1. Fresh state

Expected result:

- app opens without crash
- if you removed the app first, prior local demo data is gone

Fail condition:

- crash on launch
- stuck loading state

Privacy expectation:

- no case data leaves the device just to open the app

## 2. Choose language

Expected result:

- language selection is visible when required
- one choice lets the user continue

Fail condition:

- cannot continue after choosing a language

Privacy expectation:

- no private matter data is transmitted

## 3. Sign in with demo mode

Expected result:

- `Open demo mode` is visible
- sign-in works without real credentials
- app lands on Home
- demo workspace is clearly synthetic

Fail condition:

- sign-in loops, crashes, or lands on an empty shell

Privacy expectation:

- demo mode creates a local session only

## 4. Optional Google sign-in

Expected result:

- Google sign-in starts cleanly when backend credentials are configured
- missing or invalid setup stays plain-language

Fail condition:

- raw OAuth errors appear in normal UI

Privacy expectation:

- no case data is sent during auth

## 5. Optional Apple sign-in on iOS

Expected result:

- Apple sign-in can be invoked on iOS
- the current UI does not imply backend-backed cross-device sync

Fail condition:

- UI implies server account sync that does not exist

Privacy expectation:

- auth remains separate from matter content

## 6. Optional quick unlock

Expected result:

- supported hardware offers quick unlock
- unsupported devices show a plain fallback

Fail condition:

- crash loop or broken auth state

Privacy expectation:

- unlock remains local only

## 7. Confirm Home

Expected result:

- Home shows Today, upcoming dates, open tasks, review items, active matters, recent activity, and Ask Ross
- every section has a next action

Fail condition:

- Home feels empty or technical

Privacy expectation:

- Home data stays local

## 8. Confirm demo workspace

Expected result:

- `Demo Matter: Sharma v. Rana` appears
- demo tasks, dates, and documents are visible
- demo copy states that sample data is being used

Fail condition:

- demo sign-in lands on a blank workspace

Privacy expectation:

- demo data is synthetic and local only

## 9. Create a matter

Expected result:

- matter saves and reopens
- matter name, court, case number, and next date persist

Fail condition:

- matter disappears or cannot be reopened

Privacy expectation:

- matter details remain local

## 10. Add a task

Expected result:

- task is created and appears in Home and the matter workspace

Fail condition:

- task is lost or duplicated unexpectedly

Privacy expectation:

- task stays local

## 11. Add a date or reminder

Expected result:

- hearing, deadline, compliance, or follow-up date can be added
- the date appears in Home and in the matter

Fail condition:

- date is not saved or creates broken counts

Privacy expectation:

- date metadata stays local

## 12. Import a file

Expected result:

- PDF, image, or text import appears in the matter file room
- import status stays plain-language

Fail condition:

- import silently fails or the file does not appear

Privacy expectation:

- file stays in app-private local storage

## 13. Open the document viewer

Expected result:

- selected file opens
- review snapshot and source-backed details are visible

Fail condition:

- blank viewer, crash, or no review surface

Privacy expectation:

- source stays local

## 14. Review one field

Expected result:

- one field can be accepted, edited, or ignored
- review counts update

Fail condition:

- action is lost immediately

Privacy expectation:

- edits remain local

## 15. Create a task or date from review

Expected result:

- follow-up work can be created from review where supported

Fail condition:

- review action does nothing or creates broken counts

Privacy expectation:

- follow-up stays local

## 16. Ask Ross with Web off

Expected result:

- Ross answers from local files only
- no public-law call is made

Fail condition:

- any web search starts while Web is off

Privacy expectation:

- no search request leaves the device

## 17. Ask Ross with Web on

Expected result:

- Web state is clearly visible
- Ross explains the privacy boundary
- a sanitized preview appears
- confirmation is required before search

Fail condition:

- search runs without preview or confirmation

Privacy expectation:

- only the sanitized public-law query may be sent

## 18. View public-law results

Expected result:

- public-law results are labeled separately from case-file sources
- backend failures remain plain-language

Fail condition:

- private case content appears as if it was sent to web search

Privacy expectation:

- no private matter data appears in public-law transport or result metadata

## 19. Open notes and exports

Expected result:

- chronology, case note, order summary, and transcript surfaces are reachable where supported
- exports are framed as `Draft for advocate review`

Fail condition:

- export surface is missing or misleading

Privacy expectation:

- exports stay local

## 20. Open the Privacy Ledger

Expected result:

- entries are plain-language
- public-law entries explain that only a generic public-law query crossed the boundary

Fail condition:

- raw payloads, routes, or technical metadata appear in normal ledger copy

Privacy expectation:

- no raw prompts or raw case text are shown

## 21. Open Settings and Advanced

Expected result:

- top-level settings remain lawyer-facing
- technical diagnostics remain inside Advanced only

Fail condition:

- runtime or provider jargon appears on normal settings screens

Privacy expectation:

- backend override and diagnostics remain deliberate, not automatic

## 22. Reset demo data

Expected result:

- demo session can reset its synthetic workspace cleanly

Fail condition:

- reset is missing or leaves a broken state

Privacy expectation:

- reset affects local demo data only

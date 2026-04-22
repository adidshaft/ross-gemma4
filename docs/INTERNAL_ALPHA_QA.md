# Internal Alpha QA

This checklist is for the Ross internal alpha on April 22, 2026.

For each step, record pass or fail, the platform used, and any screenshot or note path.

## 1. Fresh install or clean state

Expected result:

- app opens without crash
- prior local demo data is cleared if you intentionally removed the app first

Fail condition:

- crash on launch
- stuck loading screen

Privacy expectation:

- no sign-in is forced through a cloud-only path

## 2. Choose language

Expected result:

- language screen is visible
- one selection is required before continuing

Fail condition:

- cannot continue after choosing a language

Privacy expectation:

- no case data leaves the device

## 3. Sign in with demo mode

Expected result:

- `Open demo mode` is visible
- demo mode works without real credentials
- app lands on Home

Fail condition:

- demo sign-in loops or crashes

Privacy expectation:

- demo mode creates a local session only

## 4. Optional Google sign-in attempt

Expected result:

- Google sign-in starts cleanly when credentials are configured
- failure remains plain-language when credentials are missing or invalid

Fail condition:

- raw OAuth errors appear in normal UI

Privacy expectation:

- no case data is sent during auth

## 5. Optional Apple sign-in on iOS

Expected result:

- Apple sign-in can be invoked on iOS
- if it succeeds, it is clearly local-only for now

Fail condition:

- UI implies backend-backed sync that does not exist

Privacy expectation:

- no case data crosses the auth boundary

## 6. Enable quick unlock if available

Expected result:

- a supported device offers quick unlock
- unsupported devices show plain-language fallback

Fail condition:

- crash loop or broken auth state after enabling

Privacy expectation:

- local lock or unlock only

## 7. Confirm Home

Expected result:

- Home shows today summary, active matter, open tasks, review items, recent files, and Ask Ross

Fail condition:

- Home feels empty without a next action

Privacy expectation:

- Home data stays on device

## 8. Create matter

Expected result:

- matter can be created and reopened

Fail condition:

- matter is not saved or cannot be reopened

Privacy expectation:

- matter details remain local

## 9. Add basic matter details

Expected result:

- title, forum, and related details save correctly

Fail condition:

- edited values disappear or corrupt the matter

Privacy expectation:

- details remain local

## 10. Import PDF

Expected result:

- PDF appears in the matter file room

Fail condition:

- import silently fails or imported file does not appear

Privacy expectation:

- PDF remains on device

## 11. Import image or text if supported

Expected result:

- non-PDF import is handled cleanly

Fail condition:

- app crashes or mislabels the file

Privacy expectation:

- imported file remains on device

## 12. Open file room

Expected result:

- file room lists imported files and statuses plainly

Fail condition:

- files are missing or unreadable

Privacy expectation:

- no upload occurs

## 13. Open document viewer

Expected result:

- viewer opens and displays the selected file

Fail condition:

- blank viewer or crash

Privacy expectation:

- source remains local

## 14. Review extracted details

Expected result:

- review items and source references are visible

Fail condition:

- no review path exists for uncertain details

Privacy expectation:

- extracted details remain local

## 15. Accept, edit, or ignore one field

Expected result:

- one field can be accepted, edited, or ignored

Fail condition:

- change is lost immediately

Privacy expectation:

- edited data stays local

## 16. Create task or reminder from review if supported

Expected result:

- follow-up action can be created where supported

Fail condition:

- task creation path is broken

Privacy expectation:

- task data stays local

## 17. Ask Ross locally with Web off

Expected result:

- Ross answers from local files only

Fail condition:

- any public-law request fires while Web is off

Privacy expectation:

- no network search occurs

## 18. Toggle Web on

Expected result:

- Web state changes clearly

Fail condition:

- toggle state is confusing or ignored

Privacy expectation:

- enabling Web alone does not send anything

## 19. Preview sanitized public-law query

Expected result:

- Ross shows the public-law query preview before search

Fail condition:

- no preview appears

Privacy expectation:

- preview removes case-specific private details

## 20. Confirm search

Expected result:

- confirmed search sends only the sanitized query

Fail condition:

- search sends private details or runs without confirmation

Privacy expectation:

- no case text, prompt text, or filenames are sent

## 21. View public-law results

Expected result:

- public-law results appear separately from case-file sources

Fail condition:

- result surface mixes public-law results with local-source citations

Privacy expectation:

- results are labeled as public-law results

## 22. Generate chronology or case note

Expected result:

- export or note is created and framed as `Draft for advocate review`

Fail condition:

- export path is broken or wording implies legal advice

Privacy expectation:

- export remains local

## 23. Open export area

Expected result:

- generated export is visible and reopenable

Fail condition:

- export disappears or is mislabeled

Privacy expectation:

- no cloud sync

## 24. Open Privacy Ledger

Expected result:

- ledger entries are understandable to a lawyer

Fail condition:

- raw payloads or raw text are shown

Privacy expectation:

- only boundary events are recorded

## 25. Check Settings

Expected result:

- settings remain plain-language

Fail condition:

- normal settings read like a developer console

Privacy expectation:

- no secret or raw auth details shown

## 26. Check Advanced diagnostics

Expected result:

- diagnostics are hidden behind Advanced

Fail condition:

- technical diagnostics appear in normal UI

Privacy expectation:

- diagnostics do not expose raw prompts or source text

## 27. Delete local test data if supported

Expected result:

- local test data can be removed cleanly

Fail condition:

- stale test data remains stuck

Privacy expectation:

- deletion affects only local data

# Real-World Usage QA

This is the primary manual script for `Ross Dogfood Proof & Public-Law Polish`.

The goal is not just feature coverage. The goal is to prove that a non-technical advocate can use Ross through a realistic morning loop.

## Morning loop

1. Open Ross
2. See what needs attention today
3. Open a matter
4. Add or import a file
5. Review the useful details Ross found
6. Turn those details into tasks or dates
7. Ask Ross a plain question
8. Keep `Web search` off unless public-law research is needed
9. If `Web search` is turned on, review the sanitized preview before search
10. Generate a hearing note or case note
11. Export or share it
12. Open the Privacy Ledger if needed

## Step-by-step script

### 1. Launch

Expected:

- app opens cleanly
- normal UI is lawyer-facing

### 2. Demo sign-in

Expected:

- `Open demo mode` works
- Home appears with a synthetic workspace that feels alive

### 3. Home dashboard

Expected:

- Today, dates, tasks, review items, matters, and recent activity are visible
- a next action is obvious

### 4. Matter workspace

Expected:

- matter summary, dates, tasks, documents, review work, and notes/exports are reachable

### 5. File room

Expected:

- imported and seeded files appear clearly
- statuses remain plain-language

### 6. Document review

Expected:

- review snapshot is visible
- source references are visible
- accept, edit, and ignore actions exist

### 7. Follow-up work

Expected:

- review work can create tasks or dates where supported
- counts stay coherent

### 8. Ask Ross with Web off

Expected:

- local-only answer
- no public-law call

### 9. Ask Ross with Web on

Expected:

- explicit privacy explanation
- sanitized preview
- confirm before search
- citations like `Order 39 Rules 1 and 2 CPC` survive sanitization
- results separated from case-file sources

### 10. Notes and exports

Expected:

- chronology, case note, and order summary surfaces are reachable
- copy says `Draft for advocate review`

### 11. Privacy Ledger

Expected:

- entries are understandable to a lawyer
- no raw technical payloads appear

### 12. Settings

Expected:

- top-level sections are lawyer-facing
- Advanced and Support details remain separate

## Current proof status on April 23, 2026

Fresh iOS simulator proof in this pass:

- demo sign-in
- live Home dashboard
- create matter
- Ask Ross add task
- Ask Ross save next hearing
- new matter workspace
- reach the import picker
- seeded document viewer/review surface reopen
- review controls are visibly present

Current iOS blocker:

- inline review taps are flaky in this simulator environment and cannot yet be treated as reliable proof of review state changes

Fresh Android proof in this pass:

- emulator boot
- debug APK install

Current Android blocker:

- the installed app does not launch through `adb`, so the fresh Android in-app walkthrough did not start

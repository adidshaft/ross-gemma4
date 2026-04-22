# Real-World Usage QA

This is the primary manual script for `Ross Real-World Usage Alpha`.

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
- Advanced and Technical diagnostics remain separate

### 13. Demo reset

Expected:

- synthetic demo workspace can be reset cleanly

## Current proof status on April 22, 2026

Fresh iOS simulator proof:

- demo sign-in
- live Home dashboard
- matter list and matter workspace
- file room
- document viewer and review surface
- Ask Ross with Web off
- public-law preview before search
- Privacy Ledger
- notes and exports surface
- Settings surface

Still needing a fresh clean pass after relaunch:

- create matter on the freshly built app
- add task and date on the freshly built app
- generate and then open one export draft
- final in-app public-law results confirmation on the refreshed build

Android status:

- no fresh emulator walkthrough in this session because no emulator was attached

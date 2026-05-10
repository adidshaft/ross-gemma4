# Computer Use Simulator Sweep

Date: 2026-05-03  
Device: iPhone 15 Pro simulator, iOS 26.2  
Method: manual walkthrough with the Computer Use plugin

## Coverage

Visited in this pass:

- splash / signed-out landing
- sign-in sheet
- email-access mode switcher
- onboarding `Set up Ross`
- local assistant chooser
- assistant info modal
- empty workspace `Today`
- empty-state Ask dock
- public-law review sheet
- matters list
- create-matter screen
- sample workspace `Today`
- sample workspace drawer
- sample matter workspace
  - overview
  - files
  - tasks
  - review
  - notes
- matter conversation screen
- document viewer / review screen
- settings
- privacy log
- technical diagnostics expansion
- language picker disclosure
- Ross assistant settings screen
- document inspect panel
  - sources expansion
  - raw text expansion
  - more document actions menu

Not fully covered in this pass:

- Google / Apple auth completion
- quick unlock / privacy shield re-entry
- actual assistant download progress screen in this exact signed-out cycle
- file importer picker flow end-to-end
- full draft export/share flow

## Highest-Priority Findings

### 1. `<think>` tags and raw JSON are still visible in the current simulator build

Observed in:
- matter conversation screen after `What is the next hearing date?`

What happens:
- the answer card still renders literal `<think>` / `</think>` lines
- raw JSON is shown in the visible answer body

Why it matters:
- this is the biggest trust break in the product right now
- the assistant feels like a leaking runtime instead of a quiet legal clerk

### 2. Response cards and Ask dock still crowd the screen too aggressively

Observed in:
- sample `Today`
- tasks tab
- document viewer
- empty-state Ask results

What happens:
- inline answer / status cards sit on top of the work instead of staying secondary
- the bottom Ask dock eats into short screens and hides lower content
- on tasks and document review, the dock competes with the actual work surface

Why it matters:
- skimming gets harder exactly where lawyers need speed

### 3. Onboarding and assistant setup layouts still clip horizontally

Observed in:
- `Set up Ross`
- `Choose local assistant`

What happens:
- content is visibly pushed off the right edge
- the screen feels misaligned rather than intentionally centered

Why it matters:
- first-run trust suffers immediately

### 4. Technical diagnostics expansion creates a header / safe-area collision

Observed in:
- Settings -> `Technical diagnostics`

What happens:
- after expanding diagnostics, top content collides with the status bar area
- the header and top chrome feel broken

Why it matters:
- even advanced surfaces should still feel stable and intentional

### 5. Document review still has interaction traps, not just visual density

Observed in:
- document viewer / review
- inspect -> sources
- inspect -> raw text
- more document actions

What happens:
- opening inspect sections can jump the screen into an awkward half-empty state with a large blank preview block
- source / raw-text toggles do not feel anchored to the part of the document they belong to
- the more-actions menu appears as a detached floating pill near the bottom controls
- the back button on this screen was unreliable under repeated Computer Use taps and required leaving the screen through simulator controls to continue QA

Why it matters:
- this is supposed to be Ross's clearest verification surface
- when navigation and inspect behavior feel slippery, trust drops even if the data is technically correct

## Screen-by-Screen Notes

### Signed-out landing

Good:
- simpler than before
- headline is readable
- `Get Started` feels clear

Needs work:
- the glass card still does not feel perfectly centered in the composition
- the surface is clean, but the spacing balance between brand, headline card, and bottom card can still be tighter

### Sign-in sheet

Good:
- much easier to understand than a busier auth surface
- email access entry is clear

Needs work:
- visual hierarchy is still slightly soft; the primary CTA area could feel more anchored
- the sheet is readable, but not yet especially polished

### Email access screen

Good:
- sample vs empty workspace split is understandable

Needs work:
- the copy stack still feels a bit tall for the amount of decision-making required
- could be even simpler and more obviously “demo” vs “fresh”

### Onboarding `Set up Ross`

Good:
- copy is short
- benefits are understandable

Needs work:
- severe right-edge clipping
- the screen currently looks broken on simulator

### Assistant chooser

Good:
- tier framing is understandable
- info modal is much cleaner than technical setup jargon

Needs work:
- severe right-edge clipping again
- card widths and central alignment feel off
- the overall composition looks pushed to the right instead of centered

### Empty `Today`

Good:
- the first matter form is easy to understand
- the empty-state direction is much clearer than before

Needs work:
- Ask dock still takes too much visual attention on a screen that should focus on first matter creation
- once Ask expands, it competes with the empty-state form too early

### Empty-state Ask dock

Good:
- global scope reads correctly as `All work`
- public-law toggle is visually separate from scope
- public-law review gate still appears before send

Needs work:
- canceling public-law review left behind a `Private assistant running locally` card with `Answered from your files`, which feels misleading for a public-law-only question in an empty workspace
- bottom dock still sits a bit too heavy against the main content

### Public-law review sheet

Good:
- clear statement that only the query will be sent
- cleaned query preview is understandable
- cancel action is visible

Needs work:
- the sheet is functionally good, but can still be quieter visually
- the “removed private details” area is a little bulky for simple cases
- after cancel, the following screen state can imply a local answer happened even when the user backed out of network review

### Sample `Today`

Good:
- much cleaner than earlier builds
- sections are more focused

Needs work:
- `Needs review` and `Recent files` remain similar in weight to each other; attention hierarchy can still sharpen
- expanded sections feel a little cramped vertically

### Matters list

Good:
- much calmer than older builds
- search / sort / create affordances are understandable

Needs work:
- a stale inline answer card can still remain on the screen and compete with the list
- the bottom Ask dock still steals some quiet from a simple list view

### Matter workspace overview

Good:
- tabbed structure is better than the old everything-at-once layout
- `Next action` bar is more useful than a huge review block

Needs work:
- still too much empty vertical air between some sections
- stale draft/result cards can linger and distract from the main workbench
- the segmented tab row can feel cramped at smaller widths

### Matter workspace files tab

Good:
- simple empty state
- import is obvious

Needs work:
- still too much blank vertical space
- lingering result card plus dock can make a sparse screen feel oddly crowded

### Matter workspace tasks tab

Good:
- dates and tasks are separated clearly
- date actions are understandable

Needs work:
- inline cards and dock overlap the lower task list too easily
- the user has to mentally filter too many stacked surfaces at once

### Matter workspace review tab

Good:
- much cleaner than putting review into overview
- empty review state is understandable

Needs work:
- the page is almost too bare in the empty state; a slightly stronger cue toward review sources or documents could help

### Matter workspace notes tab

Good:
- better separation from overview
- draft actions are easy to find

Needs work:
- duplicate copy still appears: `Make a local draft without leaving this matter.` was repeated
- matter chat card and draft card still feel a little card-inside-card heavy

### Matter conversation screen

Good:
- scoped matter context is visible

Needs work:
- this is where the `<think>` / raw JSON leak is currently most obvious
- answer cards still feel too dense when content is malformed
- Ask dock at the bottom keeps competing with the conversation itself

### Document viewer / review

Good:
- review actions are clearer than older versions
- sections are more purposeful

Needs work:
- duplicate stats still show up: the same `Fields found / Verified / Please confirm` summary appears in more than one place
- the large top review banner is still too tall for the information it carries
- the bottom Ask strip still covers useful content on this short viewport
- the overall review screen still feels busy to skim quickly
- opening `Sources` or `Raw text` can abruptly reposition the screen and reveal a large blank preview area
- source detail is readable, but does not yet feel like a precise “take me to the cited place” interaction
- the `More document actions` menu feels visually detached from the buttons that summon it
- the top back affordance on this screen needs a manual tap-target check on device; in the simulator pass it repeatedly failed to navigate out under Computer Use

### Settings

Good:
- mostly layman-readable now
- advanced details are largely pushed down
- assistant status language is much better
- language picker disclosure is simple and understandable

Needs work:
- diagnostics expansion breaks top layout
- storage/help blocks still feel a bit card-heavy
- expanding diagnostics and then drilling into assistant setup can visually stack content in a broken way, with headers and rows colliding near the top

### Privacy log

Good:
- plain, understandable, and clearly separate from the main work surfaces
- summary language stays privacy-first

Needs work:
- the screen is so minimal that it feels more like a stub than a usable audit trail
- entries would benefit from stronger time / action grouping cues without turning into a console
- after generating more actions in the app, this screen should be checked again for richer coverage and clearer chronology

### Ross assistant settings

Good:
- setup tiers are easy to understand in plain language
- `Active` state is visible without exposing too much machinery

Needs work:
- the screen still repeats itself a bit (`Ross assistant` and `ready` language appear more than once in the visual stack)
- once reached from a broken diagnostics state, the composition looks unstable and partially stacked
- Wi-Fi / network and advanced sections are present, but the scroll and layout rhythm do not yet feel polished

### Workspace drawer

Good:
- matter switching is easy
- settings is easy to reach

Needs work:
- after some state changes, blurred / stale visual residue can remain in the drawer background
- drawer still feels a little oversized for the amount of content in empty-workspace mode

## Product-Level Themes

### Simplicity is better, but stale state still makes the app feel noisy

The main remaining noise is no longer “too many sections on one screen.” It is now:

- stale answer cards
- stale status cards
- Ask dock overlap
- occasional duplicated helper copy

### The app still needs stronger skim cues

Without adding decoration, it would help to improve:

- section priority
- typographic contrast between label / headline / support copy
- when to collapse or dismiss old answer states
- when an inspect/detail branch should replace the main surface versus briefly expand inside it

### Centering and alignment still need another pass

This is especially obvious in:

- signed-out hero composition
- onboarding setup
- assistant chooser

## Recommended Next Fixes

1. Eliminate visible `<think>` / raw JSON in the simulator build and retest matter chat.
2. Reduce stale inline answer/result persistence across screens.
3. Make the bottom Ask dock take less vertical control on short screens.
4. Fix right-edge clipping on onboarding and assistant chooser.
5. Remove duplicate support copy in notes/drafts and duplicated metrics in document review.
6. Fix safe-area/header collision in technical diagnostics.
7. Tighten document-review navigation, inspect toggles, and source-opening behavior.

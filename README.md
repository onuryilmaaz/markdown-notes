# Plain

Markdown notes for iOS — the "Soft mono" direction: grey ground, floating white
cards at large radii, pill controls, circular icon buttons, and one heavy
geometric sans (Figtree) doing everything from the 44pt counter down to the 11pt
meta line.

There is no sign-in and no account: the library is local, and a fresh install
opens empty. Nothing is seeded, so every number on screen — the day counter, the
fortnight of dots, the folder and tag counts — is something you wrote.

## Running

```bash
xcodegen generate            # regenerate Plain.xcodeproj from project.yml
open Plain.xcodeproj         # or: xcodebuild -scheme Plain -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Requires Xcode 26 / iOS 18+. `Plain.xcodeproj` is generated and git-ignored;
`project.yml` is the source of truth for targets and settings.

### Signing and the app name

Signing is automatic against team `T9F78GA3Y9`; both App IDs
(`com.onur6541.plain`, `com.onur6541.plain.widgets`) and the shared app group
are created by Xcode on first build.

The name is not settled, so it lives in exactly one place — `APP_NAME` in
`project.yml`. Change it and regenerate:

```yaml
settings:
  base:
    APP_NAME: plain        # -> com.onur6541.<APP_NAME>, .widgets, group.com.onur6541.<APP_NAME>
```

The bundle ids, the entitlements and the app group identifier all derive from
it; the code reads the group id back out of Info.plist, so nothing is
hard-coded. What does *not* follow automatically is the user-facing name —
`CFBundleDisplayName` in `App/Plain/Support/Info.plist`, the `Plain` product
name, and the "Plain 1.0 · build 214" line in Settings.

## What it does

**Photos** — attach photos from the system photo picker, open a swipeable gallery,
zoom, or remove an attachment in the editor. Photos are optimized to JPEG with a
maximum 2048px edge; the original stays in Photos. Small thumbnails keep lists
and widgets light. Markdown exports with photos become ZIP bundles containing
relative image links and JPEG files; PDF export includes photo pages.

**Writing** — markdown editor with live highlighting, a shortcut bar, and three
views of the same note (write, split, read). Focus mode dims every paragraph but
the one under the caret; typewriter mode keeps that line in the middle of the
screen. `⌘B`, `⌘I`, `⌘K`, `⌘⇧H`, `⌘⇧L` work from an attached keyboard, `⌘N`
starts a note and `⌘↩` finishes one. Templates for a daily note, a meeting and a
checklist sit behind a long press on the compose button.

**Structure** — folders, tags, pinning, four sort orders, and `[[wiki links]]`
between notes with a backlink list on every note. A link to a note that does not
exist yet writes it. Checkboxes are tappable in the reading view, tables and
fenced code blocks render, and a note can be searched from inside itself.

**Keeping things** — deleting moves a note to a thirty-day trash it can be
restored from; the editor keeps up to 25 earlier versions of each note, which
can be previewed and put back. A note can be locked behind Face ID, which also
keeps its body out of list previews and search snippets. Optional iCloud sync
through CloudKit, off until you turn it on.

**Getting notes in and out** — import markdown files or paste the clipboard,
export one note as markdown or a paginated PDF, or the whole library as a zip of
markdown files foldered the way the app is. Nothing written here is trapped
here.

**The rest of iOS** — Shortcuts and Siri (create, append, open, search) through
App Intents, notes in Spotlight, a share extension that saves from any app, Lock
Screen and Control Centre buttons, five home-screen widgets (today, pinned, recent, photo and quick note), Live Activities, and a
`plain://` URL scheme (`new`, `note`, `search`, `trash`).

**Not in v1** — sending a note to another person. Collaboration needs a service
behind it, and until there is one the app does not pretend: what it offers is
export and the system share sheet.

**On-device help** — with Apple Intelligence available, the system model can
suggest a title, propose tags or summarise a note. It runs on the phone, the
note never leaves it, and nothing is applied without being shown first.

## Languages

English and Turkish, as String Catalogs: `App/Plain/Resources/Localizable.xcstrings`
for the app, one beside each extension, and one inside `PlainDomain` for the
words that wrap a date. English is the source language, so its catalogue entries
are the keys themselves.

Nothing in the design system renders a bare `String`: titles that are written in
the app take `LocalizedStringKey`, and the ones that carry the user's own words —
a folder, a tag, a note — take an explicit `verbatim:` initialiser, so a note
called "Settings" can never be translated into something else. Counts avoid
English grammar rules in other languages: the source uses
`^[\(count) note](inflect: true)` and Turkish simply reads `%lld not`.

To add a language, add its entries to the four catalogues:

```bash
xcodebuild -scheme Plain -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  SWIFT_EMIT_LOC_STRINGS=YES build            # re-extracts strings from source
xcstringstool sync App/Plain/Resources/Localizable.xcstrings --stringsdata <files…>
```

A handful of strings live outside the extractor's reach (enum labels that the
view wraps in `LocalizedStringKey`, and the model-availability messages); they
are marked `manual` in the catalogue and are not removed by a sync.

## Architecture

```
Packages/PlainKit          local Swift package, four libraries
  PlainDomain              entities, markdown parser, search, statistics, repository protocol
  PlainDesignSystem        palette, type ramp, metrics, and the shared components
  PlainPersistence         SwiftData entities + repository implementation
  PlainActivity            ActivityAttributes shared by the app and the widget
App/Plain                  the app: store, router, intents, and one folder per screen
App/PlainWidgets           widget extension: Live Activity, Dynamic Island, widgets, controls
App/PlainShare             share extension: save text or a link from any app
Tests/PlainTests           domain and repository tests (Swift Testing)
Tests/PlainUITests         smoke tests that drive the real app through the launch seam
```

The dependency arrow only ever points inwards: features talk to `NotesStore`,
`NotesStore` talks to a `NoteRepository`, and only `PlainPersistence` knows that
SwiftData exists. Swapping in a remote backend later means writing one more
conformance, not touching a view.

* **State** — `@Observable` stores (`NotesStore`, `AppSettings`, `Router`,
  `LiveActivityController`) injected through the environment. Views hold no
  business logic and never reach for storage.
* **Navigation** — a single `NavigationStack` driven by `Router.path`; every
  screen is a value (`Route`), so deep links and the debug seam are free.
* **Editor** — a `UITextView` behind a `UIViewRepresentable` for real selection
  control, with a lightweight regex highlighter for headings, list markers,
  inline code and tags. The shortcut bar drives it through `EditorController`.
* **Live notes** — a note can broadcast itself for a fixed window. The ring
  screen, the Lock Screen banner and the Dynamic Island all read the same
  `LiveSession` value; ActivityKit is wrapped so features never import it.
* **Widgets** — the app writes a small `WidgetSnapshot` to the shared app group
  after every mutation and reloads timelines; the extension only ever reads.
* **Schema versions** — version 2 adds externally stored photo records through a
  tested lightweight migration from version 1. Existing note shapes stay frozen.
   the models live inside `PlainSchemaV1` and are reached
  through type aliases, so the shape of version 1 stays in the code once version
  2 exists. A `SchemaMigrationPlan` is registered with the container while there
  is still nothing to migrate: a plan added after a store has already been
  guessed at cannot rescue it. With iCloud sync on, this matters twice over —
  CloudKit field names cannot be withdrawn once they reach production.
* **One library, several processes** — the SwiftData store lives in the app
  group so the share extension writes into the same file the app is holding, and
  a build from before the move carries its old store over once. The container is
  built as a ladder: iCloud, then shared-local, then app-local, then in-memory,
  so a missing entitlement costs the sync and never the notes.
* **Outside in** — `DeepLink` is the single parser for everything that points at
  the app: the URL scheme, Spotlight results, widget taps, Shortcuts. App
  Intents reach the library through `IntentLibrary`, which uses the running
  app's store when there is one.

## Screens

Home (folders + day statistics), note list (roomy and index densities, multi
select), rendered note, markdown editor with live preview, search with tag and
folder filters, tags, settings, empty folder, live-note ring, plus
the Lock Screen / Dynamic Island / home-screen widget moments. Light and dark
are both first class — every colour is a semantic token, so dark is a palette
swap rather than a second design.

## Tests

```bash
xcodebuild -project Plain.xcodeproj -scheme Plain \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

`PlainTests` covers the domain and the repository against a real in-memory
SwiftData store — markdown and task parsing, sorting, the markdown exchange
format, the trash rules and the revision policy. `PlainUITests` drives the built
app for the handful of things only a tap can prove: ticking a checkbox, deleting
into the trash and restoring, following a wiki link, and that a fresh install
opens empty.

## Test seam

DEBUG builds read their launch environment, which is how both the UI tests and
the screenshots are driven:

| Variable | Does |
| --- | --- |
| `PLAIN_ROUTE` | `folder`, `note`, `editor`, `live`, `search`, `tags`, `settings`, `empty`, `compose`, `trash` |
| `PLAIN_NOTE_TITLE` | which note the `note` and `editor` routes open |
| `PLAIN_EDITOR_MODE` | `write`, `split`, `read` |
| `PLAIN_APPEARANCE` | `light`, `dark` |
| `PLAIN_SEED` | fills an empty library with fixtures |
| `PLAIN_RESET` | empties the library first, so a run starts from a known state |

The UI tests pin the language on every launch (`-AppleLanguages`), so they assert
the same words whatever the simulator is set to; one of them runs the app in
Turkish on purpose.

A shipped build has none of this: it starts empty and stays that way until
somebody writes something.

## Plain Pro

The notebook remains free: unlimited notes, iCloud, locking and Markdown
backups. Pro adds focus/typewriter modes, version history, PDF export and
on-device assistance on compatible devices. StoreKit 2 verifies access and
handles restored, refunded and expired purchases. No account or backend is
required for these local features.

See [the monetization and release guide](Docs/Monetization.md) for product IDs,
initial pricing, local StoreKit tests and App Store Connect setup. Use the
`Plain-StoreKit` scheme for local purchases; archive with `Plain`.

## Motion and widget gallery

Home cards enter with a short spring sequence, note cards zoom into the reading
view, and photo thumbnails and checkboxes respond to changes. Reduce Motion
turns off these animated transitions. The Widgets button on Home opens a gallery
that renders the same shared components used by the extension. Each widget opens
its own note or a fresh page; locked-note bodies and photos are excluded from
widget snapshots.

DEBUG screenshot fixtures can opt into `PLAIN_SEED_PHOTO=1` with `PLAIN_SEED=1`.
Production builds never seed photos. The current tests cover a real on-disk V1
migration, photo retention in trash, permanent photo deletion, image downsizing,
PDF photo pages, and gallery/picker navigation.

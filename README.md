# ClipDrop

A local clipboard-history app for macOS (13 Ventura or later) that also reads text from images, on-device, using Apple's Vision framework (the engine behind Live Text). Nothing leaves your Mac.

## Build and run

1. Unzip `ClipDrop.zip` somewhere, e.g. `~/Developer/ClipDrop`.
2. If you've never compiled anything on this Mac: `xcode-select --install` (full Xcode not needed).
3. In Terminal:

```bash
cd ~/Developer/ClipDrop
chmod +x build.sh
./build.sh install
```

That compiles the app, copies it to `~/Applications` and opens it. Run the same command again after changing any code.

**First-run permissions**
- *Capture Text from Screen* (⌘⇧2) needs **Screen Recording** permission: System Settings › Privacy & Security › Screen & System Audio Recording › enable ClipDrop, then relaunch.
- On newer macOS versions you may be asked whether ClipDrop can read what other apps copy — choose **Allow**.
- On a managed work Mac, MDM/PPPC policy may block self-built apps or screen recording, and a clipboard history stores whatever you copy. Check your security policy before using it on a corporate machine.

## Features

| What | How |
|---|---|
| Clipboard history | Everything you copy appears at the top. Copying the same text again moves it to the top. |
| Read text from images | Drag images or PDFs onto the window, ⌘O to open files, ⌘⇧2 to drag over part of the screen, or just copy an image. |
| Multi-select | Click, ⇧-click for a range, ⌘-click to add/remove. Then ⌘C, ⌫, right-click, or the toolbar. |
| Copy | Double-click a row, ⌘C, or the Copy button. Several items are joined with your chosen separator. |
| Lowercase | ⌘⇧L, the toolbar or right-click › Copy as Lowercase copies the text in lowercase and leaves the saved item alone. Right-click › Change to Lowercase changes the saved item itself. |
| Pin | Keeps items at the top and stops them being removed automatically. |
| Rename | Right-click › Rename… gives an item a title (titles count for category matching). |
| Search | Search field in the toolbar filters titles and text. |
| Menu bar | The clipboard icon shows up to 99 items (pinned first, numbered; ⌘1–⌘9 copy the first nine). Set the number in Settings › Appearance. |

## Settings (⌘,)

- **General** — record clipboard on/off, read text from copied images, auto-copy recognised text, **how many items to keep** (25–1000), **how long items can stay** (forever, 1 hour … 90 days), separator for multi-item copies, clear history.
- **Categories** — group the list by **name/title keywords**. Each category has a name and comma-separated keywords; an item goes into the first category whose keywords appear in its title or text. Drag to reorder priority. Ships with examples (Links, Tickets, Commands, Emails).
- **Appearance** — **list font** and size with live preview; show/hide the menu bar icon and how many items its menu shows (5–99).

## Where data lives

`~/Library/Application Support/ClipDrop/` — `items.json`, `categories.json` and an `Images` folder. Settings are in `~/Library/Preferences/local.clipdrop.app.plist`. Delete the folder to wipe history.

Copies marked as concealed by password managers (the `org.nspasteboard.ConcealedType` convention) are never recorded.

## How the code is organised

| File | What it does |
|---|---|
| `Sources/ClipDropApp.swift` | Starting point: main window, Settings window, menu bar menu, keyboard shortcuts. |
| `Sources/Models.swift` | The data: a clip item, a category (with keyword matching), setting names and defaults. |
| `Sources/ClipStore.swift` | The "brain": list of items, saving to disk, grouping into categories, copy/delete/pin, history limits, images. |
| `Sources/ClipboardMonitor.swift` | Checks the clipboard twice a second for new copies. |
| `Sources/OCR.swift` | Reads text from an image with Vision. ~20 lines — a good one to read first. |
| `Sources/ContentView.swift` | The main window: list, detail pane, drop zone, right-click menu. |
| `Sources/SettingsView.swift` | The three Settings tabs. |
| `build.sh` | Compiles everything into `ClipDrop.app` with `swiftc` — no Xcode project needed. |

To work on it in Xcode instead: File › New › Project › macOS App (SwiftUI), delete the generated Swift files, and drag the files from `Sources/` in.

Easy first changes to try: add a category in `ClipCategory.examples` (Models.swift), change the 0.5-second check interval (ClipboardMonitor.swift), or change the 99 cap in the menu bar (`min(99, …)` in ClipDropApp.swift).

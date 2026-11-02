# CopyCatch

<img width="1280" height="640" alt="CopyCatch-social-preview" src="https://github.com/user-attachments/assets/a4eeb404-7b56-4318-86d5-92418795897b" />

<img width="1546" height="996" alt="Screenshot 2026-11-02 at 00 40 45" src="https://github.com/user-attachments/assets/a120953a-016a-416b-8fb9-37ce8be60c70" />

<img width="1336" height="827" alt="Screenshot 2026-11-02 at 00 42 07" src="https://github.com/user-attachments/assets/f85f5d68-cb72-4e37-a621-42983d48cbdc" />

<img width="868" height="831" alt="Screenshot 2026-11-02 at 00 33 48" src="https://github.com/user-attachments/assets/403aeec3-414c-480b-bd6b-80d8b1d7dbc1" />

<img width="1336" height="827" alt="Screenshot 2026-11-02 at 00 44 20" src="https://github.com/user-attachments/assets/d6eea7ae-e873-4533-92d9-b8b4bcdbfa8b" />

A local clipboard-history app for macOS (13 Ventura or later) that also reads text from images, pdf + more, on-device, using Apple's Vision framework (the engine behind Live Text). Nothing leaves your Mac.

## Download

Get the latest `.dmg` (drag to Applications) or `.pkg` (installer) from the [Releases page](https://github.com/boyratty/CopyCatch/releases). Both run on Intel and Apple Silicon Macs.

CopyCatch isn't signed with an Apple Developer ID yet, so the first time you open it macOS will say it can't check the app for malicious software. To open it anyway:

1. Click **Done** (or **OK**) on the warning.
2. Go to **System Settings › Privacy & Security**, scroll down, and click **Open Anyway** next to the CopyCatch message.
3. Open CopyCatch again and confirm.

You only need to do this once. If you'd rather avoid it, build the app yourself as described below: apps you build on your own Mac open without a warning.

## Build and run

1. If you've never compiled anything on this Mac: `xcode-select --install` (full Xcode not needed).
2. Download the code into `~/Developer/CopyCatch`:

```bash
git clone https://github.com/boyratty/CopyCatch.git ~/Developer/CopyCatch
```

3. Build and install:

```bash
cd ~/Developer/CopyCatch
chmod +x build.sh
./build.sh install
```

That compiles the app, copies it to `~/Applications` and opens it. Run the same command again after changing any code, or after `git pull` to get the latest version.

**First-run permissions**
- *Capture Text from Screen* (⌘⇧2) needs **Screen Recording** permission: System Settings › Privacy & Security › Screen & System Audio Recording › enable CopyCatch, then relaunch.
- On newer macOS versions you may be asked whether CopyCatch can read what other apps copy — choose **Allow**.
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
| Menu bar | The net icon shows up to 99 items (pinned first, numbered; ⌘1–⌘9 copy the first nine). Set the number in Settings › Appearance. |

## Settings (⌘,)

- **General** — record clipboard on/off, read text from copied images, auto-copy recognised text, **how many items to keep** (25–1000), **how long items can stay** (forever, 1 hour … 90 days), separator for multi-item copies, clear history.
- **Categories** — group the list by **name/title keywords**. Each category has a name and comma-separated keywords; an item goes into the first category whose keywords appear in its title or text. Drag to reorder priority. Ships with examples (Links, Tickets, Commands, Emails).
- **Appearance** — **list font** and size with live preview; show/hide the menu bar icon and how many items its menu shows (5–99).

## Where data lives

`~/Library/Application Support/CopyCatch/` — `items.json`, `categories.json` and an `Images` folder. Settings are in `~/Library/Preferences/local.copycatch.app.plist`. Delete the folder to wipe history.

CopyCatch used to be called ClipDrop. The first time CopyCatch opens, it moves your old ClipDrop history and settings across, and `./build.sh install` removes the old ClipDrop app.

Copies marked as concealed by password managers (the `org.nspasteboard.ConcealedType` convention) are never recorded.

## Making the installers

```bash
./build.sh universal   # one app that runs on Intel and Apple Silicon
./build.sh dmg         # → build/CopyCatch-<version>.dmg
./build.sh pkg         # → build/CopyCatch-<version>.pkg (installs to /Applications; works with Jamf/Intune)
./build.sh release     # both
```

The version number comes from `CFBundleShortVersionString` in `Info.plist`.

**Publishing a release:** GitHub builds it for you. Tag a version and push the tag:

```bash
git tag v1.1.0
git push origin v1.1.0
```

The *Build* workflow (`.github/workflows/build.yml`) runs on one of GitHub's Macs, makes the `.dmg` and `.pkg` with that version number, and attaches them to a new release on the Releases page. It also checks that every pull request still compiles.

## How the code is organised

| File | What it does |
|---|---|
| `Sources/CopyCatchApp.swift` | Starting point: main window, Settings window, menu bar menu, keyboard shortcuts. |
| `Sources/Models.swift` | The data: a clip item, a category (with keyword matching), setting names and defaults. |
| `Sources/ClipStore.swift` | The "brain": list of items, saving to disk, grouping into categories, copy/delete/pin, history limits, images. |
| `Sources/ClipboardMonitor.swift` | Checks the clipboard twice a second for new copies. |
| `Sources/OCR.swift` | Reads text from an image with Vision. ~20 lines — a good one to read first. |
| `Sources/ContentView.swift` | The main window: list, detail pane, drop zone, right-click menu. |
| `Sources/SettingsView.swift` | The three Settings tabs. |
| `Sources/NetIcon.swift` | Draws the butterfly-net menu bar icon. |
| `build.sh` | Compiles everything into `CopyCatch.app` with `swiftc` (no Xcode project needed), and makes the `.dmg` / `.pkg`. |

To work on it in Xcode instead: File › New › Project › macOS App (SwiftUI), delete the generated Swift files, and drag the files from `Sources/` in.

Easy first changes to try: add a category in `ClipCategory.examples` (Models.swift), change the 0.5-second check interval (ClipboardMonitor.swift), or change the 99 cap in the menu bar (`min(99, …)` in CopyCatchApp.swift).

## License

MIT, see [LICENSE](LICENSE). Free to use, change and share; no warranty.

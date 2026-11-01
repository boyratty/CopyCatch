// CopyCatchApp.swift
// Entry point: the main window, the Settings window and the menu bar icon.

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Keep running (and recording the clipboard) after the window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct CopyCatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ClipStore()
    @AppStorage(Prefs.showMenuBarIcon) private var showMenuBarIcon = true

    var body: some Scene {
        Window("CopyCatch", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 620, minHeight: 380)
        }
        .defaultSize(width: 900, height: 580)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Image…") { store.openImages() }
                    .keyboardShortcut("o")
                Button("Capture Text from Screen") { store.captureScreenRegion() }
                    .keyboardShortcut("2", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }

        MenuBarExtra("CopyCatch", systemImage: "doc.on.clipboard", isInserted: $showMenuBarIcon) {
            MenuBarView()
                .environmentObject(store)
        }
    }
}

/// The drop-down menu from the menu bar icon: the 10 most recent items plus shortcuts.
struct MenuBarView: View {
    @EnvironmentObject private var store: ClipStore
    @Environment(\.openWindow) private var openWindow
    @AppStorage(Prefs.menuBarItemCount) private var menuBarItemCount = 99

    var body: some View {
        let limit = min(99, max(1, menuBarItemCount))
        let ordered = store.items.filter(\.pinned) + store.items.filter { !$0.pinned }
        let recent = Array(ordered.prefix(limit).enumerated())
        if recent.isEmpty {
            Text("Nothing copied yet")
        }
        ForEach(recent, id: \.element.id) { index, item in
            let label = "\(index + 1). \(item.pinned ? "📌 " : "")\(item.title.prefix(50))"
            if index < 9 {
                Button(label) { store.copy([item.id], in: [item]) }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            } else {
                Button(label) { store.copy([item.id], in: [item]) }
            }
        }
        if ordered.count > limit {
            Text("\(ordered.count - limit) more in the CopyCatch window")
        }
        Divider()
        Button("Open CopyCatch") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Capture Text from Screen") { store.captureScreenRegion() }
        Button("Read Text from Image…") { store.openImages() }
        Divider()
        if #available(macOS 14.0, *) {
            SettingsLink { Text("Settings…") }
        } else {
            Button("Settings…") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
        }
        Button("Quit CopyCatch") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

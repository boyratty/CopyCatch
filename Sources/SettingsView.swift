// SettingsView.swift
// ClipDrop > Settings… (⌘,)

import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            CategorySettings()
                .tabItem { Label("Categories", systemImage: "folder") }
            AppearanceSettings()
                .tabItem { Label("Appearance", systemImage: "textformat") }
        }
        .frame(width: 560, height: 440)
    }
}

// MARK: - General

struct GeneralSettings: View {
    @EnvironmentObject private var store: ClipStore
    @AppStorage(Prefs.monitorClipboard) private var monitorClipboard = true
    @AppStorage(Prefs.ocrCopiedImages) private var ocrCopiedImages = true
    @AppStorage(Prefs.autoCopyOCR) private var autoCopyOCR = true
    @AppStorage(Prefs.fastOCR) private var fastOCR = false
    @AppStorage(Prefs.maxItems) private var maxItems = 200
    @AppStorage(Prefs.retentionHours) private var retentionHours = 0
    @AppStorage(Prefs.joinSeparator) private var joinSeparator = JoinSeparator.newline.rawValue
    @StateObject private var confirmClear = Flag()

    var body: some View {
        Form {
            Section("Clipboard") {
                Toggle("Record everything I copy", isOn: $monitorClipboard)
                Toggle("Read text from images I copy", isOn: $ocrCopiedImages)
                Toggle("Put text read from images straight onto the clipboard", isOn: $autoCopyOCR)
                Toggle("Faster text recognition (less accurate on small or messy text)", isOn: $fastOCR)
                Text("Passwords copied from password managers that mark them as concealed are never recorded.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("History") {
                Picker("Keep up to", selection: $maxItems) {
                    ForEach([25, 50, 100, 200, 500, 1000], id: \.self) { Text("\($0) items").tag($0) }
                }
                Picker("Items can stay for", selection: $retentionHours) {
                    ForEach(Retention.allCases) { Text($0.label).tag($0.rawValue) }
                }
                Text("Pinned items are never removed automatically.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Clear All Unpinned Items…") { confirmClear.on = true }
            }
            Section("Multiple selection") {
                Picker("When copying several items, separate them with", selection: $joinSeparator) {
                    ForEach(JoinSeparator.allCases) { Text($0.label).tag($0.rawValue) }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: maxItems) { _ in store.prune() }
        .onChange(of: retentionHours) { _ in store.prune() }
        .confirmationDialog("Clear all unpinned items?", isPresented: $confirmClear.on) {
            Button("Clear", role: .destructive) { store.clearUnpinned() }
        } message: {
            Text("This can't be undone.")
        }
    }
}

// MARK: - Categories

struct CategorySettings: View {
    @EnvironmentObject private var store: ClipStore
    @AppStorage(Prefs.groupByCategory) private var grouped = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Group the list into categories", isOn: $grouped)
            Text("An item goes into the first category whose keywords appear in its title or text (not case-sensitive). Separate keywords with commas. Drag rows to change which category wins.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            List {
                ForEach($store.categories) { $category in
                    HStack {
                        TextField("Name", text: $category.name)
                            .frame(width: 120)
                        TextField("keywords, separated, by commas", text: $category.keywords)
                        Button {
                            let id = category.id
                            store.categories.removeAll { $0.id == id }
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                        .help("Remove category")
                    }
                }
                .onMove { from, to in store.categories.move(fromOffsets: from, toOffset: to) }
            }
            .disabled(!grouped)

            HStack {
                Button {
                    store.categories.append(ClipCategory(name: "New category", keywords: ""))
                } label: {
                    Label("Add Category", systemImage: "plus")
                }
                Spacer()
                Button("Restore Examples") { store.categories = ClipCategory.examples }
            }
        }
        .padding()
    }
}

// MARK: - Appearance

struct AppearanceSettings: View {
    @AppStorage(Prefs.fontName) private var fontName = "System"
    @AppStorage(Prefs.fontSize) private var fontSize = 13.0
    @AppStorage(Prefs.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(Prefs.menuBarItemCount) private var menuBarItemCount = 99
    private let families = NSFontManager.shared.availableFontFamilies.sorted()

    var body: some View {
        Form {
            Section("List font") {
                Picker("Font", selection: $fontName) {
                    Text("System").tag("System")
                    Divider()
                    ForEach(families, id: \.self) { Text($0).tag($0) }
                }
                HStack {
                    Slider(value: $fontSize, in: 10...24, step: 1)
                    Text("\(Int(fontSize)) pt").monospacedDigit().frame(width: 44)
                }
                Text("The quick brown fox copies the lazy dog — 0123456789")
                    .font(.clip(fontName, fontSize))
                    .padding(.vertical, 4)
            }
            Section("Menu bar") {
                Toggle("Show ClipDrop in the menu bar", isOn: $showMenuBarIcon)
                Stepper(value: $menuBarItemCount, in: 5...99, step: 1) {
                    Text("Menu shows up to \(menuBarItemCount) items")
                }
                .disabled(!showMenuBarIcon)
                Text("Pinned items are listed first. ⌘1–⌘9 copy the first nine while the menu is open.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

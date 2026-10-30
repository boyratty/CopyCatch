// ContentView.swift
// The main window: grouped list on the left (click, ⇧-click, ⌘-click to select),
// detail of the selection on the right, and a drop zone for images.

import SwiftUI
import UniformTypeIdentifiers

extension Font {
    static func clip(_ name: String, _ size: Double) -> Font {
        name == "System" ? .system(size: size) : .custom(name, size: size)
    }
}

struct ContentView: View {
    @EnvironmentObject var store: ClipStore
    @StateObject var ui = ContentUI()
    @AppStorage(Prefs.groupByCategory) var groupByCategory = true
    @AppStorage(Prefs.fontName) var fontName = "System"
    @AppStorage(Prefs.fontSize) var fontSize = 13.0

    var body: some View {
        let sections = store.sections(search: ui.search, grouped: groupByCategory)
        let ordered = sections.flatMap(\.items)
        let selectedItems = ordered.filter { ui.selection.contains($0.id) }

        VStack(spacing: 0) {
            HSplitView {
                clipList(sections: sections, ordered: ordered)
                    .frame(minWidth: 320, idealWidth: 420)
                DetailPane(selected: selectedItems, fontName: fontName, fontSize: fontSize) {
                    store.delete(ui.selection)
                    ui.selection.removeAll()
                }
                .frame(minWidth: 260, idealWidth: 340)
            }
            statusBar(total: ordered.count)
        }
        .searchable(text: $ui.search, placement: .toolbar, prompt: "Search clips")
        .toolbar {
            ToolbarItemGroup {
                Button { store.openImages() } label: {
                    Label("Open Image", systemImage: "photo.badge.plus")
                }
                .help("Open images or PDFs and read their text (⌘O)")

                Button { store.captureScreenRegion() } label: {
                    Label("Capture Text", systemImage: "text.viewfinder")
                }
                .help("Drag over part of the screen and read its text (⌘⇧2)")

                Button { store.copy(ui.selection, in: ordered) } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .help("Copy the selected items (⌘C)")
                .disabled(ui.selection.isEmpty)

                Button { store.copy(ui.selection, in: ordered, lowercased: true) } label: {
                    Label("Copy as Lowercase", systemImage: "textformat.abc")
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .help("Copy the selected items in lowercase (⌘⇧L)")
                .disabled(ui.selection.isEmpty)

                Button { store.togglePin(ui.selection) } label: {
                    Label("Pin", systemImage: store.isAllPinned(ui.selection) ? "pin.slash" : "pin")
                }
                .help("Pin keeps items at the top and stops them being removed")
                .disabled(ui.selection.isEmpty)

                Button(role: .destructive) {
                    store.delete(ui.selection)
                    ui.selection.removeAll()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .help("Delete the selected items (⌫)")
                .disabled(ui.selection.isEmpty)
            }
        }
        .onDrop(of: [.fileURL, .image], isTargeted: $ui.dropTargeted) { providers in
            handleDrop(providers)
        }
        .overlay {
            if ui.dropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .background(Color.accentColor.opacity(0.08))
                    .overlay(Label("Drop to read text", systemImage: "text.viewfinder").font(.title2))
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .sheet(item: $ui.renaming) { item in
            RenameSheet(item: item) { newTitle in store.rename(item.id, to: newTitle) }
        }
    }

    // MARK: - List

    private func clipList(sections: [ClipSection], ordered: [ClipItem]) -> some View {
        List(selection: $ui.selection) {
            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { item in
                        ClipRow(item: item, fontName: fontName, fontSize: fontSize)
                            .tag(item.id)
                    }
                } header: {
                    Text("\(section.name)  ·  \(section.items.count)")
                }
            }
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            Button(ids.count > 1 ? "Copy \(ids.count) Items" : "Copy") { store.copy(ids, in: ordered) }
            Button("Copy as Lowercase") { store.copy(ids, in: ordered, lowercased: true) }
            if ids.count == 1, let id = ids.first, let item = ordered.first(where: { $0.id == id }) {
                if let image = store.image(for: item) {
                    Button("Copy Image") { store.writeToPasteboard(image: image) }
                }
                Button("Rename…") { ui.renaming = item }
            }
            Button(store.isAllPinned(ids) ? "Unpin" : "Pin") { store.togglePin(ids) }
            Button("Change to Lowercase") { store.makeLowercase(ids) }
            Divider()
            Button("Delete", role: .destructive) {
                store.delete(ids)
                ui.selection.subtract(ids)
            }
        } primaryAction: { ids in
            store.copy(ids, in: ordered)          // double-click copies
        }
        .onDeleteCommand {
            store.delete(ui.selection)
            ui.selection.removeAll()
        }
        .onCopyCommand {
            let text = store.joinedText(ordered.filter { ui.selection.contains($0.id) })
            guard !text.isEmpty else { return [] }
            store.suppressNextChange = true      // don't record our own ⌘C as a new item
            return [NSItemProvider(object: text as NSString)]
        }
    }

    private func statusBar(total: Int) -> some View {
        HStack(spacing: 8) {
            if store.ocrInProgress > 0 {
                ProgressView().controlSize(.small)
                Text("Reading text…")
            }
            Spacer()
            Text(ui.selection.isEmpty
                 ? "\(total) items"
                 : "\(ui.selection.count) of \(total) selected  ·  ⇧-click or ⌘-click to select more")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Drag and drop

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in store.ingestFile(at: url) }
                }
            } else if provider.canLoadObject(ofClass: NSImage.self) {
                handled = true
                _ = provider.loadObject(ofClass: NSImage.self) { object, _ in
                    guard let image = object as? NSImage else { return }
                    Task { @MainActor in store.ingestImage(image, source: .imageOCR) }
                }
            }
        }
        return handled
    }
}

// MARK: - Row

struct ClipRow: View {
    @EnvironmentObject var store: ClipStore
    let item: ClipItem
    let fontName: String
    let fontSize: Double

    private var icon: String {
        switch item.source {
        case .clipboard:     return "doc.on.clipboard"
        case .imageOCR:      return "photo"
        case .screenCapture: return "text.viewfinder"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let image = store.image(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if item.pinned {
                        Image(systemName: "pin.fill").foregroundStyle(.orange).font(.caption)
                    }
                    Text(item.title).font(.clip(fontName, fontSize)).lineLimit(1)
                }
                if !item.preview.isEmpty {
                    Text(item.preview)
                        .font(.clip(fontName, max(9, fontSize - 2)))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(item.date, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detail pane

struct DetailPane: View {
    @EnvironmentObject var store: ClipStore
    let selected: [ClipItem]
    let fontName: String
    let fontSize: Double
    let onDelete: () -> Void

    var body: some View {
        Group {
            if selected.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.viewfinder").font(.system(size: 44)).foregroundStyle(.secondary)
                    Text("Drop an image or PDF anywhere in this window to read its text.")
                    Text("Or press ⌘O to open a file, or ⌘⇧2 to capture part of the screen.")
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding()
            } else if selected.count == 1 {
                single(selected[0])
            } else {
                multiple
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func single(_ item: ClipItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let image = store.image(for: item) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    Text(item.text.isEmpty ? "No text found." : item.text)
                        .font(.clip(fontName, fontSize))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            Divider()
            HStack {
                Text("\(item.text.count) characters · \(item.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !item.text.isEmpty {
                    Button("Copy as Lowercase") { store.copy([item.id], in: [item], lowercased: true) }
                }
                Button("Copy") { store.copy([item.id], in: [item]) }
            }
            .padding(10)
        }
    }

    private var multiple: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(selected.count) items selected").font(.headline).padding()
            ScrollView {
                Text(store.joinedText(selected))
                    .font(.clip(fontName, fontSize))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            Divider()
            HStack {
                Button("Delete", role: .destructive, action: onDelete)
                Spacer()
                Button("Copy as Lowercase") { store.copy(Set(selected.map(\.id)), in: selected, lowercased: true) }
                Button("Copy All") { store.copy(Set(selected.map(\.id)), in: selected) }
            }
            .padding(10)
        }
    }
}

// MARK: - Rename

struct RenameSheet: View {
    @Environment(\.dismiss) var dismiss
    let item: ClipItem
    let onSave: (String) -> Void
    @StateObject var form = TextForm()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rename Item").font(.headline)
            Text("Titles are matched by category keywords too. Leave empty to use the first line.")
                .font(.caption).foregroundStyle(.secondary)
            TextField("Title", text: $form.text).frame(width: 340)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { onSave(form.text); dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .onAppear { form.text = item.customTitle ?? item.title }
    }
}

// MARK: - View state holders
// These replace SwiftUI's @State, which on newer macOS needs full Xcode to compile.
// @StateObject + ObservableObject works with just the Command Line Tools.

final class ContentUI: ObservableObject {
    @Published var selection = Set<UUID>()
    @Published var search = ""
    @Published var dropTargeted = false
    @Published var renaming: ClipItem? = nil
}

final class TextForm: ObservableObject {
    @Published var text = ""
}

final class Flag: ObservableObject {
    @Published var on = false
}

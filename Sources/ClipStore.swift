// ClipStore.swift
// Holds the list of items and categories, saves them to disk, and does the actions
// (copy, delete, pin, rename, read text from images, capture the screen).

import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ClipStore: ObservableObject {
    @Published var items: [ClipItem] = [] {
        didSet { if !isLoading { saveItems() } }
    }
    @Published var categories: [ClipCategory] = [] {
        didSet { if !isLoading { saveCategories() } }
    }
    /// Number of images currently being read. Shows a spinner in the window.
    @Published var ocrInProgress = 0

    /// ~/Library/Application Support/ClipDrop
    let supportFolder: URL
    let imagesFolder: URL

    /// Used so the app doesn't record its own copies as new history items.
    var ownChangeCount = -1
    var suppressNextChange = false

    private var isLoading = false
    private var monitor: ClipboardMonitor?
    private var pruneTimer: Timer?
    private var imageCache: [String: NSImage] = [:]

    private var itemsURL: URL { supportFolder.appendingPathComponent("items.json") }
    private var categoriesURL: URL { supportFolder.appendingPathComponent("categories.json") }

    init() {
        Prefs.register()
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipDrop", isDirectory: true)
        supportFolder = base
        imagesFolder = base.appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesFolder, withIntermediateDirectories: true)

        load()
        prune()

        let monitor = ClipboardMonitor(store: self)
        self.monitor = monitor
        monitor.start()

        // Re-check the "keep items for" rule once a minute.
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.prune() }
        }
    }

    // MARK: - Loading and saving

    private func load() {
        isLoading = true
        defer { isLoading = false }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = try? Data(contentsOf: itemsURL),
           let saved = try? decoder.decode([ClipItem].self, from: data) {
            items = saved
        }
        if let data = try? Data(contentsOf: categoriesURL),
           let saved = try? decoder.decode([ClipCategory].self, from: data) {
            categories = saved
        } else {
            categories = ClipCategory.examples
            saveCategories()
        }
    }

    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        return encoder
    }

    private func saveItems() {
        if let data = try? encoder().encode(items) { try? data.write(to: itemsURL, options: .atomic) }
    }

    private func saveCategories() {
        if let data = try? encoder().encode(categories) { try? data.write(to: categoriesURL, options: .atomic) }
    }

    // MARK: - Adding and trimming

    func add(_ item: ClipItem) {
        var list = items
        // Same text copied again: move the existing entry to the top instead of duplicating it.
        if item.imageFile == nil,
           let index = list.firstIndex(where: { $0.imageFile == nil && $0.text == item.text }) {
            var existing = list.remove(at: index)
            existing.date = item.date
            list.insert(existing, at: 0)
        } else {
            list.insert(item, at: 0)
        }
        items = list
        prune()
    }

    /// Applies the "Keep up to N items" and "Keep items for" settings. Pinned items are never removed.
    func prune() {
        let defaults = UserDefaults.standard
        let maxItems = max(1, defaults.integer(forKey: Prefs.maxItems))
        let hours = defaults.integer(forKey: Prefs.retentionHours)
        let cutoff: Date? = hours > 0 ? Date().addingTimeInterval(-Double(hours) * 3600) : nil

        var kept: [ClipItem] = []
        var removed: [ClipItem] = []
        var unpinnedCount = 0
        for item in items {
            if item.pinned { kept.append(item); continue }
            if let cutoff, item.date < cutoff { removed.append(item); continue }
            unpinnedCount += 1
            if unpinnedCount > maxItems { removed.append(item) } else { kept.append(item) }
        }
        guard !removed.isEmpty else { return }
        removed.forEach { deleteImageFile(for: $0) }
        items = kept
    }

    // MARK: - Grouping for the list

    func sections(search: String, grouped: Bool) -> [ClipSection] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = query.isEmpty
            ? items
            : items.filter { ($0.title + "\n" + $0.text).lowercased().contains(query) }

        var result: [ClipSection] = []
        let pinned = filtered.filter { $0.pinned }
        let rest = filtered.filter { !$0.pinned }
        if !pinned.isEmpty { result.append(ClipSection(id: "pinned", name: "Pinned", items: pinned)) }

        guard grouped, !categories.isEmpty else {
            if !rest.isEmpty { result.append(ClipSection(id: "recent", name: "Recent", items: rest)) }
            return result
        }

        var buckets: [UUID: [ClipItem]] = [:]
        var other: [ClipItem] = []
        for item in rest {
            if let category = categories.first(where: { $0.matches(item) }) {
                buckets[category.id, default: []].append(item)
            } else {
                other.append(item)
            }
        }
        for category in categories {
            if let bucket = buckets[category.id], !bucket.isEmpty {
                result.append(ClipSection(id: category.id.uuidString, name: category.name, items: bucket))
            }
        }
        if !other.isEmpty { result.append(ClipSection(id: "other", name: "Uncategorised", items: other)) }
        return result
    }

    // MARK: - Actions on selected items

    /// Copies the chosen items, in the order they appear in `order`, joined by the separator setting.
    /// With `lowercased`, the text is copied in lowercase and the saved item is left as it was.
    func copy(_ ids: Set<UUID>, in order: [ClipItem], lowercased: Bool = false) {
        let chosen = order.filter { ids.contains($0.id) }
        guard !chosen.isEmpty else { return }
        if !lowercased, chosen.count == 1, chosen[0].text.isEmpty, let image = image(for: chosen[0]) {
            writeToPasteboard(image: image)
            return
        }
        let text = joinedText(chosen)
        guard !text.isEmpty else { return }
        writeToPasteboard(text: lowercased ? text.lowercased() : text)
    }

    /// Changes the saved text of the chosen items to lowercase for good.
    func makeLowercase(_ ids: Set<UUID>) {
        for index in items.indices where ids.contains(items[index].id) {
            items[index].text = items[index].text.lowercased()
        }
    }

    func joinedText(_ list: [ClipItem]) -> String {
        let raw = UserDefaults.standard.string(forKey: Prefs.joinSeparator) ?? ""
        let separator = JoinSeparator(rawValue: raw) ?? .newline
        return list.map(\.text).filter { !$0.isEmpty }.joined(separator: separator.string)
    }

    func delete(_ ids: Set<UUID>) {
        let removed = items.filter { ids.contains($0.id) }
        removed.forEach { deleteImageFile(for: $0) }
        items.removeAll { ids.contains($0.id) }
    }

    /// Pins all of them, unless they're all pinned already, in which case unpins them.
    func togglePin(_ ids: Set<UUID>) {
        let allPinned = items.filter { ids.contains($0.id) }.allSatisfy(\.pinned)
        for index in items.indices where ids.contains(items[index].id) {
            items[index].pinned = !allPinned
        }
    }

    func isAllPinned(_ ids: Set<UUID>) -> Bool {
        let chosen = items.filter { ids.contains($0.id) }
        return !chosen.isEmpty && chosen.allSatisfy(\.pinned)
    }

    func rename(_ id: UUID, to title: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        items[index].customTitle = trimmed.isEmpty ? nil : trimmed
    }

    func clearUnpinned() {
        items.filter { !$0.pinned }.forEach { deleteImageFile(for: $0) }
        items.removeAll { !$0.pinned }
    }

    // MARK: - Pasteboard

    func writeToPasteboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        ownChangeCount = pasteboard.changeCount
    }

    func writeToPasteboard(image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        ownChangeCount = pasteboard.changeCount
    }

    // MARK: - Images and text recognition

    /// Saves the image, reads its text on-device, and adds it to the list.
    func ingestImage(_ image: NSImage, source: ClipItem.Source) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let folder = imagesFolder
        let fast = UserDefaults.standard.bool(forKey: Prefs.fastOCR)
        ocrInProgress += 1
        Task {
            // Save the image and read its text at the same time, both off the main thread.
            async let savedFile = Self.saveImage(cgImage, in: folder)
            async let recognized = OCR.recognizeText(in: cgImage, fast: fast)
            let (fileName, text) = await (savedFile, recognized)
            ocrInProgress -= 1
            add(ClipItem(text: text, imageFile: fileName, source: source, date: Date()))
            if UserDefaults.standard.bool(forKey: Prefs.autoCopyOCR), !text.isEmpty {
                writeToPasteboard(text: text)
            }
        }
    }

    func ingestFile(at url: URL) {
        if let image = NSImage(contentsOf: url) { ingestImage(image, source: .imageOCR) }
    }

    /// Shows an Open dialog for one or more images or PDFs.
    func openImages() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = "Choose images to read text from"
        panel.allowedContentTypes = [.image, .pdf]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            panel.urls.forEach { ingestFile(at: $0) }
        }
    }

    /// Lets the user drag over part of the screen (like ⌘⇧4) and reads the text in it.
    func captureScreenRegion() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipdrop-\(UUID().uuidString).png")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", url.path]   // -i interactive selection, -x no sound
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                if let image = NSImage(contentsOf: url) {
                    self?.ingestImage(image, source: .screenCapture)
                }
                try? FileManager.default.removeItem(at: url)
            }
        }
        try? process.run()
    }

    func image(for item: ClipItem) -> NSImage? {
        guard let file = item.imageFile else { return nil }
        if let cached = imageCache[file] { return cached }
        guard let image = NSImage(contentsOf: imagesFolder.appendingPathComponent(file)) else { return nil }
        imageCache[file] = image
        return image
    }

    /// Writes the image as a PNG on a background thread and returns its file name.
    nonisolated private static func saveImage(_ cgImage: CGImage, in folder: URL) async -> String? {
        await Task.detached(priority: .utility) {
            let name = UUID().uuidString + ".png"
            let rep = NSBitmapImageRep(cgImage: cgImage)
            guard let data = rep.representation(using: .png, properties: [:]) else { return nil }
            do {
                try data.write(to: folder.appendingPathComponent(name))
                return name
            } catch {
                return nil
            }
        }.value
    }

    private func deleteImageFile(for item: ClipItem) {
        guard let file = item.imageFile else { return }
        imageCache[file] = nil
        try? FileManager.default.removeItem(at: imagesFolder.appendingPathComponent(file))
    }
}

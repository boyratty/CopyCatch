// Models.swift
// The data types the app works with: a clip item, a category, and the settings keys.

import Foundation

// MARK: - Settings keys (stored in UserDefaults, edited in the Settings window)

enum Prefs {
    static let monitorClipboard = "monitorClipboard"
    static let ocrCopiedImages  = "ocrCopiedImages"
    static let autoCopyOCR      = "autoCopyOCR"
    static let maxItems         = "maxItems"
    static let retentionHours   = "retentionHours"
    static let groupByCategory  = "groupByCategory"
    static let fontName         = "fontName"
    static let fontSize         = "fontSize"
    static let showMenuBarIcon  = "showMenuBarIcon"
    static let joinSeparator    = "joinSeparator"
    static let menuBarItemCount = "menuBarItemCount"
    static let fastOCR          = "fastOCR"

    /// Default values used until the user changes something in Settings.
    static func register() {
        UserDefaults.standard.register(defaults: [
            monitorClipboard: true,
            ocrCopiedImages: true,
            autoCopyOCR: true,
            maxItems: 200,
            retentionHours: 0,          // 0 = keep forever
            groupByCategory: true,
            fontName: "System",
            fontSize: 13.0,
            showMenuBarIcon: true,
            menuBarItemCount: 99,
            fastOCR: false,
            joinSeparator: JoinSeparator.newline.rawValue
        ])
    }
}

/// How long unpinned items can stay in the list.
enum Retention: Int, CaseIterable, Identifiable {
    case forever = 0, oneHour = 1, oneDay = 24, oneWeek = 168, oneMonth = 720, threeMonths = 2160

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .forever:     return "Forever"
        case .oneHour:     return "1 hour"
        case .oneDay:      return "1 day"
        case .oneWeek:     return "1 week"
        case .oneMonth:    return "30 days"
        case .threeMonths: return "90 days"
        }
    }
}

/// What goes between items when several are copied at once.
enum JoinSeparator: String, CaseIterable, Identifiable {
    case newline, blankLine, comma, tab, space

    var id: String { rawValue }
    var label: String {
        switch self {
        case .newline:   return "New line"
        case .blankLine: return "Blank line"
        case .comma:     return "Comma"
        case .tab:       return "Tab"
        case .space:     return "Space"
        }
    }
    var string: String {
        switch self {
        case .newline:   return "\n"
        case .blankLine: return "\n\n"
        case .comma:     return ", "
        case .tab:       return "\t"
        case .space:     return " "
        }
    }
}

// MARK: - Clip item

struct ClipItem: Identifiable, Codable, Equatable {
    enum Source: String, Codable {
        case clipboard      // copied from any app
        case imageOCR       // dropped or opened image
        case screenCapture  // screen area captured from inside the app
    }

    var id = UUID()
    var text: String
    var customTitle: String?
    var imageFile: String?          // PNG file name in the Images folder, if any
    var source: Source
    var date: Date
    var pinned: Bool = false

    /// The custom title if set, otherwise the first line of the text.
    var title: String {
        if let customTitle, !customTitle.isEmpty { return customTitle }
        let firstLine = text
            .split(whereSeparator: \.isNewline)
            .first
            .map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        if firstLine.isEmpty { return imageFile != nil ? "Image (no text found)" : "(empty)" }
        return String(firstLine.prefix(100))
    }

    /// Text after the first line, used as a grey preview under the title.
    var preview: String {
        let lines = text.split(whereSeparator: \.isNewline)
        guard customTitle == nil || customTitle!.isEmpty else {
            return lines.prefix(2).joined(separator: " ")
        }
        return lines.dropFirst().prefix(2).joined(separator: " ")
    }
}

// MARK: - Category

struct ClipCategory: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var name: String
    var keywords: String            // comma-separated, e.g. "http, www."

    var keywordList: [String] {
        keywords
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }

    /// True if any keyword appears in the item's title or text (not case-sensitive).
    func matches(_ item: ClipItem) -> Bool {
        let haystack = (item.title + "\n" + item.text).lowercased()
        return keywordList.contains { haystack.contains($0) }
    }

    static let examples: [ClipCategory] = [
        ClipCategory(name: "Links",    keywords: "http://, https://, www."),
        ClipCategory(name: "Tickets",  keywords: "INC0, REQ0, RITM, CHG0, ticket"),
        ClipCategory(name: "Commands", keywords: "sudo , defaults write, brew , Get-, Set-, powershell, ssh "),
        ClipCategory(name: "Emails",   keywords: "@")
    ]
}

struct ClipSection: Identifiable {
    let id: String
    let name: String
    let items: [ClipItem]
}

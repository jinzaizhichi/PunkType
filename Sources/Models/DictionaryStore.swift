import SwiftUI
import Foundation

// MARK: - Dictionary Entry

struct DictionaryEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var term: String
    var note: String = "" // 译法 / 备注

    var createdAt: Date = Date()
}

// MARK: - Dictionary Store
// Personal glossary: terms are auto-extracted after each output and can be
// edited manually. Injected into prompts so the LLM fixes recognition errors
// and uses the preferred translations.

@MainActor
final class DictionaryStore: ObservableObject {
    static let shared = DictionaryStore()

    @Published var entries: [DictionaryEntry] = []

    static let maxEntries = 300
    private let storageURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("PunkType")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        storageURL = folder.appendingPathComponent("dictionary.json")
        load()
    }

    // MARK: - Mutations

    func add(term: String, note: String = "") {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !contains(trimmed), entries.count < Self.maxEntries else { return }
        entries.insert(DictionaryEntry(term: trimmed, note: note), at: 0)
        save()
    }

    /// Merge auto-extracted terms, skipping duplicates and respecting the cap.
    func merge(terms: [String]) {
        var added = false
        for term in terms {
            let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !contains(trimmed), entries.count < Self.maxEntries else { continue }
            entries.insert(DictionaryEntry(term: trimmed), at: 0)
            added = true
        }
        if added { save() }
    }

    func update(_ entry: DictionaryEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx] = entry
        save()
    }

    func remove(_ entry: DictionaryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clearAll() {
        entries.removeAll()
        save()
    }

    private func contains(_ term: String) -> Bool {
        entries.contains { $0.term.caseInsensitiveCompare(term) == .orderedSame }
    }

    // MARK: - Prompt injection

    /// Glossary block appended to cleanup/format prompts (term-only correction list).
    var correctionGlossary: String? {
        guard !entries.isEmpty else { return nil }
        let terms = entries.prefix(200).map(\.term).joined(separator: "、")
        return """

        专有名词参考表（语音识别可能把它们听错，如出现读音相近的词请修正为表内写法）：
        \(terms)
        """
    }

    /// Full glossary with notes/translations, for command mode.
    var commandGlossary: String? {
        guard !entries.isEmpty else { return nil }
        let lines = entries.prefix(200).map { entry in
            entry.note.isEmpty ? "- \(entry.term)" : "- \(entry.term)：\(entry.note)"
        }
        return """

        个人词典（处理时保持这些写法，翻译时按标注的译法）：
        \(lines.joined(separator: "\n"))
        """
    }

    // MARK: - Persistence

    func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: storageURL)
        } catch {
            print("[PunkType] Failed to save dictionary: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            entries = try JSONDecoder().decode([DictionaryEntry].self, from: data)
        } catch {
            print("[PunkType] Failed to load dictionary: \(error)")
        }
    }
}

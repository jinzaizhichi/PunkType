import SwiftUI
import Foundation

// MARK: - History Entry

struct HistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let cleanedText: String
    let rawText: String
    let timestamp: Date
    let model: String
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh-CN")
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    var preview: String {
        let short = String(cleanedText.prefix(12)).replacingOccurrences(of: "\n", with: " ")
        return short.count < cleanedText.count ? short + "..." : short
    }
}

// MARK: - History Manager

@MainActor
final class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    @Published var entries: [HistoryEntry] = []
    
    private let maxEntries = 100
    private let storageURL: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("PunkType")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        storageURL = folder.appendingPathComponent("history.json")
        load()
    }
    
    func add(cleanedText: String, rawText: String, model: String) {
        let entry = HistoryEntry(
            id: UUID(),
            cleanedText: cleanedText,
            rawText: rawText,
            timestamp: Date(),
            model: model
        )
        entries.insert(entry, at: 0)
        
        // Trim to max
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        
        save()
    }
    
    func remove(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }
    
    func clearAll() {
        entries.removeAll()
        save()
    }
    
    // MARK: - Persistence
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: storageURL)
        } catch {
            print("[PunkType] Failed to save history: \(error)")
        }
    }
    
    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            entries = try JSONDecoder().decode([HistoryEntry].self, from: data)
        } catch {
            print("[PunkType] Failed to load history: \(error)")
        }
    }
}

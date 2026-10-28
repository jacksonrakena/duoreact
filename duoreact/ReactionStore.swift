import Foundation
import Observation

/// Manages built-in and user-created reactions, persisting custom ones to disk.
@Observable
class ReactionStore {
    static let shared = ReactionStore()
    
    private(set) var customReactions: [ReactionItem] = []
    
    /// All reactions: built-in first, then custom
    var allItems: [ReactionItem] {
        allReactions + customReactions
    }
    
    private var saveURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("custom_reactions.json")
    }
    
    private var customDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CustomReactions")
    }
    
    private init() {
        ensureCustomDirExists()
        load()
    }
    
    // MARK: - CRUD
    
    func add(_ reaction: ReactionItem) {
        customReactions.append(reaction)
        save()
    }
    
    func delete(_ reaction: ReactionItem) {
        guard reaction.isCustom else { return }
        customReactions.removeAll { $0.id == reaction.id }
        
        // Clean up files
        let imageFile = customDir.appendingPathComponent(reaction.fullFileName)
        try? FileManager.default.removeItem(at: imageFile)
        
        if case .custom(let fn, let fe) = reaction.sound {
            let soundFile = customDir.appendingPathComponent("\(fn).\(fe)")
            try? FileManager.default.removeItem(at: soundFile)
        }
        
        save()
    }
    
    // MARK: - File Management
    
    /// Copy a file into the CustomReactions directory
    func copyFile(from sourceURL: URL, name: String, ext: String) -> Bool {
        ensureCustomDirExists()
        let dest = customDir.appendingPathComponent("\(name).\(ext)")
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: sourceURL, to: dest)
            return true
        } catch {
            print("Failed to copy file: \(error)")
            return false
        }
    }
    
    /// Save raw data as a file in the CustomReactions directory
    func saveData(_ data: Data, name: String, ext: String) -> Bool {
        ensureCustomDirExists()
        let dest = customDir.appendingPathComponent("\(name).\(ext)")
        do {
            try data.write(to: dest)
            return true
        } catch {
            print("Failed to save data: \(error)")
            return false
        }
    }
    
    // MARK: - Persistence
    
    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(customReactions) {
            try? data.write(to: saveURL)
        }
    }
    
    private func load() {
        guard let data = try? Data(contentsOf: saveURL),
              let reactions = try? JSONDecoder().decode([ReactionItem].self, from: data) else {
            return
        }
        customReactions = reactions
    }
    
    private func ensureCustomDirExists() {
        try? FileManager.default.createDirectory(at: customDir, withIntermediateDirectories: true)
    }
}

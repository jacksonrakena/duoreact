import Foundation

enum SoundType: Hashable, Codable {
    case system(UInt32)
    case custom(fileName: String, fileExtension: String)
    case none
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case type, systemId, fileName, fileExtension
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .system(let id):
            try container.encode("system", forKey: .type)
            try container.encode(id, forKey: .systemId)
        case .custom(let name, let ext):
            try container.encode("custom", forKey: .type)
            try container.encode(name, forKey: .fileName)
            try container.encode(ext, forKey: .fileExtension)
        case .none:
            try container.encode("none", forKey: .type)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "system":
            let id = try container.decode(UInt32.self, forKey: .systemId)
            self = .system(id)
        case "custom":
            let name = try container.decode(String.self, forKey: .fileName)
            let ext = try container.decode(String.self, forKey: .fileExtension)
            self = .custom(fileName: name, fileExtension: ext)
        default:
            self = .none
        }
    }
}

struct ReactionItem: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let fileName: String
    let fileExtension: String
    let sound: SoundType
    let emoji: String
    let color: String
    let isCustom: Bool
    
    init(name: String, fileName: String, fileExtension: String,
         sound: SoundType, emoji: String, color: String, isCustom: Bool = false) {
        self.id = UUID()
        self.name = name
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.sound = sound
        self.emoji = emoji
        self.color = color
        self.isCustom = isCustom
    }
    
    var isVideo: Bool {
        fileExtension == "mp4" || fileExtension == "mov"
    }
    
    var isAnimated: Bool {
        fileExtension == "gif"
    }
    
    var fullFileName: String {
        "\(fileName).\(fileExtension)"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ReactionItem, rhs: ReactionItem) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - File URL Resolution
    
    /// Resolve a file URL, checking documents/CustomReactions first, then the app bundle.
    static func resolveFileURL(fileName: String, fileExtension: String) -> URL? {
        // Check custom reactions directory first
        if let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let customURL = documentsDir
                .appendingPathComponent("CustomReactions")
                .appendingPathComponent("\(fileName).\(fileExtension)")
            if FileManager.default.fileExists(atPath: customURL.path) {
                return customURL
            }
        }
        // Fall back to bundle
        return Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: "Reactions")
            ?? Bundle.main.url(forResource: fileName, withExtension: fileExtension)
    }
    
    /// Convenience: resolve this reaction's image/video file
    var resolvedImageURL: URL? {
        Self.resolveFileURL(fileName: fileName, fileExtension: fileExtension)
    }
}

// MARK: - Built-in Reactions

let allReactions: [ReactionItem] = [
    ReactionItem(
        name: "Laugh",
        fileName: "laugh",
        fileExtension: "png",
        sound: .custom(fileName: "cat-laugh-meme-1", fileExtension: "mp3"),
        emoji: "😂",
        color: "FFD93D"
    ),
    ReactionItem(
        name: "Side Eye",
        fileName: "sideeye",
        fileExtension: "gif",
        sound: .custom(fileName: "among-us-role-reveal-sound", fileExtension: "mp3"),
        emoji: "👀",
        color: "6BCB77"
    ),
    ReactionItem(
        name: "Cat Stare",
        fileName: "catstare",
        fileExtension: "jpg",
        sound: .system(1016),
        emoji: "🐱",
        color: "4D96FF"
    ),
    ReactionItem(name: "Angry", fileName: "angry_cat", fileExtension: "mp4", sound: .none, emoji: "😡", color: "FF6B6B"),
    ReactionItem(
        name: "Cat Hire",
        fileName: "cathire",
        fileExtension: "gif",
        sound: .system(1001),
        emoji: "🐈",
        color: "FF6B6B"
    ),
    ReactionItem(
        name: "Absolute Cinema",
        fileName: "absolute-cinema",
        fileExtension: "jpg",
        sound: .system(1001),
        emoji: "🎦",
        color: "FF6B6B"
    ),
    ReactionItem(
        name: "Luna Blink",
        fileName: "lunablink",
        fileExtension: "gif",
        sound: .system(1306),
        emoji: "😸",
        color: "C780FA"
    ),
    ReactionItem(
        name: "Side Eye 2",
        fileName: "sideeye2",
        fileExtension: "webp",
        sound: .system(1053),
        emoji: "🫣",
        color: "FF922B"
    ),
    ReactionItem(
        name: "Boom",
        fileName: "boom",
        fileExtension: "gif",
        sound: .custom(fileName: "vine-boom", fileExtension: "mp3"),
        emoji: "💥",
        color: "E03131"
    ),
]

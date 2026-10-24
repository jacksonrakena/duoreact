import Foundation

enum SoundType: Hashable {
    case system(UInt32)
    case custom(fileName: String, fileExtension: String)
    case none
}

struct ReactionItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let fileName: String
    let fileExtension: String
    let sound: SoundType
    let emoji: String
    let color: String // hex color for the button background
    
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
}

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

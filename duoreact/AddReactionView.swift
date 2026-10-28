import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct AddReactionView: View {
    @Environment(\.dismiss) private var dismiss
    let store: ReactionStore
    var onAdded: (() -> Void)?
    
    @State private var name = ""
    @State private var emoji = ""
    @State private var selectedColor = "FFD93D"
    
    // Image
    @State private var showImagePicker = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pickedImageName: String?      // UUID-based filename (no ext)
    @State private var pickedImageExt: String?        // e.g. "jpg", "gif", "mp4"
    @State private var pickedImageDisplayName: String? // original file name for display
    
    // Sound
    @State private var showSoundPicker = false
    @State private var pickedSoundName: String?
    @State private var pickedSoundExt: String?
    @State private var pickedSoundDisplayName: String?
    
    private static let colorPresets = [
        "FFD93D", "6BCB77", "4D96FF", "FF6B6B",
        "C780FA", "FF922B", "E03131", "20C997",
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: Details
                Section("Details") {
                    TextField("Name", text: $name)
                    HStack {
                        Text("Emoji")
                        Spacer()
                        TextField("e.g. 😂", text: $emoji)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .onChange(of: emoji) { _, newValue in
                                if newValue.count > 1 {
                                    emoji = String(newValue.suffix(1))
                                }
                            }
                    }
                }
                
                // MARK: Color
                Section("Button Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(Self.colorPresets, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .gray)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Circle()
                                        .stroke(.blue, lineWidth: selectedColor == hex ? 3 : 0)
                                        .padding(-3)
                                )
                                .onTapGesture { selectedColor = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: Image / Video
                Section {
                    if let display = pickedImageDisplayName {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(display)
                                .lineLimit(1)
                            Spacer()
                            Button("Change") {
                                pickedImageName = nil
                                pickedImageExt = nil
                                pickedImageDisplayName = nil
                            }
                            .font(.caption)
                        }
                    }
                    
                    PhotosPicker(selection: $selectedPhotoItem,
                                 matching: .any(of: [.images, .videos])) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .foregroundStyle(.blue)
                            Text("Choose from Photo Library")
                        }
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        handlePhotoPick(newItem)
                    }
                    
                    Button {
                        showImagePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                                .foregroundStyle(.blue)
                            Text("Choose from Files")
                        }
                    }
                } header: {
                    Text("Image / Video")
                } footer: {
                    Text("Supports PNG, JPG, GIF, WebP, and MP4.")
                }
                
                // MARK: Sound
                Section {
                    Button {
                        showSoundPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "speaker.wave.2")
                                .foregroundStyle(.blue)
                            if let display = pickedSoundDisplayName {
                                Text(display)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            } else {
                                Text("Choose Sound (optional)...")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if pickedSoundName != nil {
                        Button("Remove Sound", role: .destructive) {
                            // Delete the already-copied file
                            if let sn = pickedSoundName, let se = pickedSoundExt {
                                let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                                    .appendingPathComponent("CustomReactions")
                                try? FileManager.default.removeItem(
                                    at: dir.appendingPathComponent("\(sn).\(se)")
                                )
                            }
                            pickedSoundName = nil
                            pickedSoundExt = nil
                            pickedSoundDisplayName = nil
                        }
                    }
                } header: {
                    Text("Sound")
                } footer: {
                    Text("MP3, WAV, or M4A. Leave empty for no sound.")
                }
            }
            .navigationTitle("New Reaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cleanupOnCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveReaction()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty || pickedImageName == nil)
                }
            }
            .fileImporter(
                isPresented: $showImagePicker,
                allowedContentTypes: [.image, .movie],
                allowsMultipleSelection: false
            ) { result in
                handleImagePick(result)
            }
            .fileImporter(
                isPresented: $showSoundPicker,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                handleSoundPick(result)
            }
        }
    }
    
    // MARK: - Handlers
    
    private func handlePhotoPick(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        let uniqueName = UUID().uuidString
        
        // Try loading as video first, then as image data
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
            item.loadTransferable(type: VideoTransferable.self) { result in
                if case .success(let video) = result, let video = video {
                    let ext = video.url.pathExtension.lowercased()
                    if store.copyFile(from: video.url, name: uniqueName, ext: ext.isEmpty ? "mp4" : ext) {
                        DispatchQueue.main.async {
                            pickedImageName = uniqueName
                            pickedImageExt = ext.isEmpty ? "mp4" : ext
                            pickedImageDisplayName = "Photo Library video"
                        }
                    }
                }
            }
        } else {
            // For images, load raw data to preserve GIF animation
            item.loadTransferable(type: Data.self) { result in
                if case .success(let data) = result, let data = data {
                    // Determine extension from content type
                    var ext = "jpg"
                    for ct in item.supportedContentTypes {
                        if ct.conforms(to: .gif) { ext = "gif"; break }
                        if ct.conforms(to: .png) { ext = "png"; break }
                        if ct.conforms(to: .webP) { ext = "webp"; break }
                        if ct.conforms(to: .heic) { ext = "heic"; break }
                    }
                    
                    if store.saveData(data, name: uniqueName, ext: ext) {
                        DispatchQueue.main.async {
                            pickedImageName = uniqueName
                            pickedImageExt = ext
                            pickedImageDisplayName = "Photo Library image"
                        }
                    }
                }
            }
        }
    }
    
    private func handleImagePick(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let ext = url.pathExtension.lowercased()
        let uniqueName = UUID().uuidString
        
        if store.copyFile(from: url, name: uniqueName, ext: ext) {
            pickedImageName = uniqueName
            pickedImageExt = ext
            pickedImageDisplayName = url.lastPathComponent
        }
    }
    
    private func handleSoundPick(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let ext = url.pathExtension.lowercased()
        let uniqueName = "snd_\(UUID().uuidString)"
        
        if store.copyFile(from: url, name: uniqueName, ext: ext) {
            pickedSoundName = uniqueName
            pickedSoundExt = ext
            pickedSoundDisplayName = url.lastPathComponent
        }
    }
    
    private func saveReaction() {
        guard let imgName = pickedImageName, let imgExt = pickedImageExt else { return }
        
        let sound: SoundType
        if let sndName = pickedSoundName, let sndExt = pickedSoundExt {
            sound = .custom(fileName: sndName, fileExtension: sndExt)
        } else {
            sound = .none
        }
        
        let reaction = ReactionItem(
            name: name,
            fileName: imgName,
            fileExtension: imgExt,
            sound: sound,
            emoji: emoji.isEmpty ? "⭐" : emoji,
            color: selectedColor,
            isCustom: true
        )
        
        store.add(reaction)
        
        // Preload into caches so it's instantly available
        ImageCache.shared.preloadOne(reaction)
        SoundManager.shared.preloadOne(reaction)
        
        onAdded?()
        dismiss()
    }
    
    /// Clean up copied files if the user cancels without saving
    private func cleanupOnCancel() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CustomReactions")
        if let n = pickedImageName, let e = pickedImageExt {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(n).\(e)"))
        }
        if let n = pickedSoundName, let e = pickedSoundExt {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(n).\(e)"))
        }
    }
}


// MARK: - Video Transferable

struct VideoTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            // Copy to a temp location we control
            let tempDir = FileManager.default.temporaryDirectory
            let dest = tempDir.appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return Self(url: dest)
        }
    }
}

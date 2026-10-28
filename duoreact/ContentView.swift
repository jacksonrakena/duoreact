import SwiftUI
import AVFoundation
import AVKit
import Playgrounds

// MARK: - What's being shown on the outer display

enum OuterContent: Equatable {
    case none
    case reaction(ReactionItem)
    case text(String, TextStyle)
    
    static func == (lhs: OuterContent, rhs: OuterContent) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none): return true
        case (.reaction(let a), .reaction(let b)): return a.id == b.id
        case (.text(let a, let sa), .text(let b, let sb)): return a == b && sa == sb
        default: return false
        }
    }
}

struct TextStyle: Equatable, Hashable {
    var fontSize: CGFloat = 64
    var fontDesign: Font.Design = .default
    var textColor: Color = .white
    var backgroundColor: Color = .black
    
    // Preset color options
    static let textColors: [(String, Color)] = [
        ("White", .white),
        ("Yellow", .yellow),
        ("Cyan", .cyan),
        ("Green", .green),
        ("Orange", .orange),
        ("Pink", .pink),
        ("Red", .red),
    ]
    
    static let bgColors: [(String, Color)] = [
        ("Black", .black),
        ("Dark Blue", Color(red: 0.05, green: 0.05, blue: 0.2)),
        ("Dark Green", Color(red: 0.05, green: 0.15, blue: 0.05)),
        ("Dark Red", Color(red: 0.2, green: 0.02, blue: 0.02)),
        ("Purple", Color(red: 0.15, green: 0.0, blue: 0.2)),
        ("White", .white),
    ]
    
    static let fontDesigns: [(String, Font.Design)] = [
        ("Default", .default),
        ("Rounded", .rounded),
        ("Serif", .serif),
        ("Mono", .monospaced),
    ]
}

// MARK: - Main Content View

@available(iOS 27.1, *)
struct ContentView: View {
    @State private var captureManager = DualScreenCaptureManager()
    @State private var outerContent: OuterContent = .none
    @State private var selectedTab = 0
    @State private var reactionStore = ReactionStore.shared
    @State private var showAddReaction = false
    
    // Text mode state
    @State private var customText = ""
    @State private var textStyle = TextStyle()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preview strip at the top
                outerScreenPreview
                
                // Tab picker
                Picker("Mode", selection: $selectedTab) {
                    Text("Reactions").tag(0)
                    Text("Text").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                
                // Content based on selected tab
                if selectedTab == 0 {
                    reactionsTab
                } else {
                    textTab
                }
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("DuoReact 🎭")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CameraPreviewView(session: captureManager.captureSession)
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 1))
                }
            }
        }
        .sceneAccessory {
            CameraCaptureAccessory(isEnabled: $captureManager.isSessionRunning) {
                OuterDisplayView(content: outerContent)
            }
            .onAvailabilityChange { isAvailable in
                print("Outer display available: \(isAvailable)")
            }
        }
        .onAppear {
            captureManager.requestPermissionAndStart()
        }
        .onDisappear {
            captureManager.stopSession()
        }
    }
    
    // MARK: - Outer Screen Preview Strip
    
    private var outerScreenPreview: some View {
        HStack(spacing: 12) {
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(outerContent != .none ? .green : .secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                    Text("Outer Screen")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                
                switch outerContent {
                case .none:
                    Text("Nothing showing")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                case .reaction(let r):
                    Text("\(r.emoji) \(r.name)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                case .text(let t, _):
                    Text("\"\(t.prefix(30))\(t.count > 30 ? "…" : "")\"")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Mini preview of what's on the outer screen
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black)
                
                OuterDisplayView(content: outerContent)
                    .allowsHitTesting(false)
            }
            .frame(width: 80, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.secondary.opacity(0.3), lineWidth: 1)
            )
            
            // Clear button
            if outerContent != .none {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        outerContent = .none
                    }
                    SoundManager.shared.hapticTap()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Reactions Tab
    
    private var reactionsTab: some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
        ]
        
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(reactionStore.allItems) { reaction in
                    let isSelected: Bool = {
                        if case .reaction(let r) = outerContent { return r.id == reaction.id }
                        return false
                    }()
                    
                    ReactionButton(
                        reaction: reaction,
                        isSelected: isSelected
                    ) {
                        triggerReaction(reaction)
                    }
                    .contextMenu {
                        if reaction.isCustom {
                            Button(role: .destructive) {
                                deleteReaction(reaction)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                
                // Add button
                Button {
                    showAddReaction = true
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.tertiarySystemBackground))
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                                .foregroundStyle(.secondary.opacity(0.4))
                            
                            Image(systemName: "plus")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                        .frame(height: 130)
                        
                        Text("Add New")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                }
                .buttonStyle(BounceButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showAddReaction) {
            AddReactionView(store: reactionStore)
        }
    }
    
    // MARK: - Text Tab
    
    private var textTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Text input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    TextField("Type something...", text: $customText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.tertiarySystemBackground))
                        )
                        .lineLimit(1...5)
                }
                
                // Font size slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Size")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        Text("\(Int(textStyle.fontSize))pt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $textStyle.fontSize, in: 24...120, step: 4)
                        .tint(.blue)
                }
                
                // Font design picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Font")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    HStack(spacing: 8) {
                        ForEach(TextStyle.fontDesigns, id: \.0) { label, design in
                            Button {
                                textStyle.fontDesign = design
                            } label: {
                                Text(label)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(textStyle.fontDesign == design
                                                  ? Color.blue
                                                  : Color(.tertiarySystemBackground))
                                    )
                                    .foregroundStyle(textStyle.fontDesign == design ? .white : .primary)
                            }
                        }
                    }
                }
                
                // Text color
                VStack(alignment: .leading, spacing: 8) {
                    Text("Text Color")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    colorRow(colors: TextStyle.textColors, selected: textStyle.textColor) { color in
                        textStyle.textColor = color
                    }
                }
                
                // Background color
                VStack(alignment: .leading, spacing: 8) {
                    Text("Background")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    colorRow(colors: TextStyle.bgColors, selected: textStyle.backgroundColor) { color in
                        textStyle.backgroundColor = color
                    }
                }
                
                // Send button
                Button {
                    sendText()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "display")
                        Text("Show on Outer Screen")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(customText.isEmpty ? Color.gray : Color.blue)
                    )
                    .foregroundStyle(.white)
                }
                .disabled(customText.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }
    
    private func colorRow(colors: [(String, Color)], selected: Color, onSelect: @escaping (Color) -> Void) -> some View {
        HStack(spacing: 10) {
            ForEach(colors, id: \.0) { label, color in
                Button {
                    onSelect(color)
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(color == .black ? .gray : .clear, lineWidth: 1)
                        )
                        .overlay(
                            Circle()
                                .stroke(.blue, lineWidth: selected == color ? 3 : 0)
                                .padding(-3)
                        )
                }
            }
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func triggerReaction(_ reaction: ReactionItem) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            outerContent = .reaction(reaction)
        }
        SoundManager.shared.play(reaction.sound)
    }
    
    private func deleteReaction(_ reaction: ReactionItem) {
        // Clear outer display if showing this reaction
        if case .reaction(let r) = outerContent, r.id == reaction.id {
            outerContent = .none
        }
        ImageCache.shared.evict(reaction)
        SoundManager.shared.evict(reaction)
        reactionStore.delete(reaction)
    }
    
    private func sendText() {
        guard !customText.isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            outerContent = .text(customText, textStyle)
        }
        SoundManager.shared.hapticTap(style: .medium)
    }
}

// MARK: - Reaction Button

struct ReactionButton: View {
    let reaction: ReactionItem
    let isSelected: Bool
    let action: () -> Void
    
    private var buttonColor: Color {
        Color(hex: reaction.color) ?? .blue
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Thumbnail — taller to show more of the image
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(buttonColor.opacity(0.12))
                    
                    ReactionImageView(reaction: reaction, contentMode: .scaleAspectFill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
                .frame(height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                
                // Label
                HStack(spacing: 5) {
                    Text(reaction.emoji)
                        .font(.callout)
                    Text(reaction.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? buttonColor.opacity(0.2) : Color(.tertiarySystemBackground))
                    .shadow(color: isSelected ? buttonColor.opacity(0.3) : .black.opacity(0.05), radius: isSelected ? 8 : 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? buttonColor : .clear, lineWidth: 2.5)
            )
        }
        .contentShape(Rectangle())
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Bounce Button Style

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Outer Display View

struct OuterDisplayView: View {
    let content: OuterContent
    
    var body: some View {
        ZStack {
            switch content {
            case .none:
                Color.black.ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("DuoReact")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.2))
                }
                
            case .reaction(let reaction):
                Color.black.ignoresSafeArea()
                if reaction.isVideo {
                    VideoPlayerView(
                        fileName: reaction.fileName,
                        fileExtension: reaction.fileExtension,
                        contentMode: .scaleAspectFit
                    )
                    .ignoresSafeArea()
                    .transition(.scale.combined(with: .opacity))
                } else {
                    ReactionImageView(reaction: reaction, contentMode: .scaleAspectFit)
                        .ignoresSafeArea()
                        .transition(.scale.combined(with: .opacity))
                }
                
            case .text(let text, let style):
                style.backgroundColor.ignoresSafeArea()
                Text(text)
                    .font(.system(size: style.fontSize, design: style.fontDesign))
                    .fontWeight(.bold)
                    .foregroundStyle(style.textColor)
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .minimumScaleFactor(0.3)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: content)
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator { var previewLayer: AVCaptureVideoPreviewLayer? }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

#Preview {
    if #available(iOS 27.1, *) {
        ContentView()
    }
}

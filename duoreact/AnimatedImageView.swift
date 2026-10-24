import SwiftUI
import UIKit
import ImageIO
import AVFoundation

/// Displays an animated GIF (or static image) from the ImageCache.
/// Falls back to on-demand decoding if the cache isn't warm yet.
struct AnimatedImageView: UIViewRepresentable {
    let fileName: String
    let fileExtension: String
    let contentMode: UIView.ContentMode
    
    init(fileName: String, fileExtension: String, contentMode: UIView.ContentMode = .scaleAspectFit) {
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.contentMode = contentMode
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = contentMode
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = false
        imageView.backgroundColor = .clear
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        applyImage(to: imageView, context: context)
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.contentMode = contentMode
        
        let currentFile = "\(fileName).\(fileExtension)"
        if context.coordinator.loadedFile != currentFile {
            uiView.stopAnimating()
            uiView.animationImages = nil
            uiView.image = nil
            applyImage(to: uiView, context: context)
        }
    }
    
    private func applyImage(to imageView: UIImageView, context: Context) {
        let currentFile = "\(fileName).\(fileExtension)"
        context.coordinator.loadedFile = currentFile
        
        // Try cache first (instant)
        let key = currentFile
        if let cached = ImageCache.shared.get(
            ReactionItem(name: "", fileName: fileName, fileExtension: fileExtension,
                         sound: .system(0), emoji: "", color: "000000")
        ) {
            applyCached(cached, to: imageView)
            return
        }
        
        // Not cached yet — check directly by key
        // Fall back to on-demand decode on background thread
        let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: "Reactions")
            ?? Bundle.main.url(forResource: fileName, withExtension: fileExtension)
        
        guard let url = url else { return }
        
        let coordinator = context.coordinator
        DispatchQueue.global(qos: .userInitiated).async {
            let cached: CachedImage
            if self.fileExtension == "gif" {
                guard let data = try? Data(contentsOf: url),
                      let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }
                
                let frameCount = CGImageSourceGetCount(source)
                var frames: [UIImage] = []
                frames.reserveCapacity(frameCount)
                var totalDuration: Double = 0
                
                for i in 0..<frameCount {
                    guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
                    frames.append(UIImage(cgImage: cgImage))
                    if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                       let gifProps = props[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                        let delay = gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                            ?? gifProps[kCGImagePropertyGIFDelayTime as String] as? Double ?? 0.1
                        totalDuration += max(delay, 0.02)
                    } else {
                        totalDuration += 0.1
                    }
                }
                cached = CachedImage(frames: frames, duration: totalDuration)
            } else {
                guard let data = try? Data(contentsOf: url),
                      let image = UIImage(data: data) else { return }
                cached = CachedImage(frames: [image], duration: 0)
            }
            
            DispatchQueue.main.async {
                guard coordinator.loadedFile == currentFile else { return }
                self.applyCached(cached, to: imageView)
            }
        }
    }
    
    private func applyCached(_ cached: CachedImage, to imageView: UIImageView) {
        imageView.image = cached.staticImage
        if cached.isAnimated {
            imageView.animationImages = cached.frames
            imageView.animationDuration = cached.duration
            imageView.animationRepeatCount = 0
            imageView.startAnimating()
        }
    }
    
    class Coordinator {
        var loadedFile: String?
    }
}

/// A unified view that shows a cached reaction image with a loading spinner fallback.
/// For mp4 videos used as thumbnails (e.g. in the grid), shows the cached thumbnail frame.
/// For full playback (outer display), use VideoPlayerView directly.
struct ReactionImageView: View {
    let reaction: ReactionItem
    var contentMode: UIView.ContentMode = .scaleAspectFit
    @State private var imageCache = ImageCache.shared
    
    var body: some View {
        ZStack {
            if imageCache.isLoaded(reaction) {
                // For videos, show the cached thumbnail as a static image
                AnimatedImageView(
                    fileName: reaction.fileName,
                    fileExtension: reaction.fileExtension,
                    contentMode: contentMode
                )
            } else {
                // Loading spinner while decoding
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .id(reaction.id)
    }
}

import UIKit
import AVFoundation
import ImageIO
import Observation

/// Cached result for a decoded image (static or animated)
struct CachedImage {
    let frames: [UIImage]
    let duration: Double
    
    var isAnimated: Bool { frames.count > 1 }
    var staticImage: UIImage? { frames.first }
}

/// Preloads and caches all reaction images in the background.
/// GIF frames are decoded once and kept in memory so tapping a
/// reaction is instant.
@Observable
class ImageCache {
    static let shared = ImageCache()
    
    private var cache: [String: CachedImage] = [:]
    private let queue = DispatchQueue(label: "com.duoreact.imagecache", qos: .userInitiated, attributes: .concurrent)
    private(set) var loadedCount = 0
    private(set) var totalCount = 0
    
    private init() {}
    
    /// Whether a specific reaction's image is ready
    func isLoaded(_ reaction: ReactionItem) -> Bool {
        cache[reaction.fullFileName] != nil
    }
    
    /// Get the cached image for a reaction (nil if not yet decoded)
    func get(_ reaction: ReactionItem) -> CachedImage? {
        cache[reaction.fullFileName]
    }
    
    /// Preload all reactions. Call once at app launch.
    func preloadAll() {
        let reactions = allReactions
        totalCount = reactions.count
        loadedCount = 0
        
        for reaction in reactions {
            queue.async { [weak self] in
                let key = reaction.fullFileName
                
                // Skip if already cached
                if self?.cache[key] != nil { return }
                
                let url = Bundle.main.url(forResource: reaction.fileName, withExtension: reaction.fileExtension, subdirectory: "Reactions")
                    ?? Bundle.main.url(forResource: reaction.fileName, withExtension: reaction.fileExtension)
                
                guard let url = url else { return }
                
                let cached: CachedImage
                if reaction.isVideo {
                    cached = Self.generateVideoThumbnail(from: url)
                } else if reaction.fileExtension == "gif" {
                    cached = Self.decodeGIF(from: url)
                } else {
                    cached = Self.decodeStatic(from: url)
                }
                
                DispatchQueue.main.async {
                    self?.cache[key] = cached
                    self?.loadedCount += 1
                }
            }
        }
    }
    
    // MARK: - Decoders
    
    private static func decodeGIF(from url: URL) -> CachedImage {
        guard let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return CachedImage(frames: [], duration: 0)
        }
        
        let frameCount = CGImageSourceGetCount(source)
        var frames: [UIImage] = []
        frames.reserveCapacity(frameCount)
        var totalDuration: Double = 0
        
        for i in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            frames.append(UIImage(cgImage: cgImage))
            
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let gifProps = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                let delay = gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                    ?? gifProps[kCGImagePropertyGIFDelayTime as String] as? Double
                    ?? 0.1
                totalDuration += max(delay, 0.02)
            } else {
                totalDuration += 0.1
            }
        }
        
        return CachedImage(frames: frames, duration: totalDuration)
    }
    
    private static func decodeStatic(from url: URL) -> CachedImage {
        if let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            return CachedImage(frames: [image], duration: 0)
        }
        return CachedImage(frames: [], duration: 0)
    }
    
    private static func generateVideoThumbnail(from url: URL) -> CachedImage {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 512, height: 512)
        
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
            return CachedImage(frames: [UIImage(cgImage: cgImage)], duration: 0)
        }
        return CachedImage(frames: [], duration: 0)
    }
}

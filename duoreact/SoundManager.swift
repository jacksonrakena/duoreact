import AudioToolbox
import AVFoundation
import UIKit

class SoundManager {
    static let shared = SoundManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var preloadedPlayers: [String: AVAudioPlayer] = [:]
    
    private init() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Audio session setup failed: \(error)")
            }
        }
    }
    
    /// Preload all custom audio files so playback is instant
    func preloadAll(items: [ReactionItem]? = nil) {
        let reactions = items ?? allReactions
        for reaction in reactions {
            if case .custom(let fileName, let fileExtension) = reaction.sound {
                preloadSound(fileName: fileName, fileExtension: fileExtension)
            }
        }
    }
    
    /// Preload a single newly-added reaction's sound
    func preloadOne(_ reaction: ReactionItem) {
        if case .custom(let fileName, let fileExtension) = reaction.sound {
            preloadSound(fileName: fileName, fileExtension: fileExtension)
        }
    }
    
    /// Remove a preloaded sound (when a custom reaction is deleted)
    func evict(_ reaction: ReactionItem) {
        if case .custom(let fileName, let fileExtension) = reaction.sound {
            let key = "\(fileName).\(fileExtension)"
            preloadedPlayers.removeValue(forKey: key)
        }
    }
    
    private func preloadSound(fileName: String, fileExtension: String) {
        let key = "\(fileName).\(fileExtension)"
        guard preloadedPlayers[key] == nil else { return }
        
        if let url = ReactionItem.resolveFileURL(fileName: fileName, fileExtension: fileExtension),
           let player = try? AVAudioPlayer(contentsOf: url) {
            player.prepareToPlay()
            preloadedPlayers[key] = player
        }
    }
    
    /// Stop any currently playing sounds
    func stopAll() {
        audioPlayer?.stop()
        for player in preloadedPlayers.values {
            if player.isPlaying {
                player.stop()
                player.currentTime = 0
            }
        }
    }
    
    /// Play a sound, cancelling any currently playing sound first
    func play(_ sound: SoundType) {
        stopAll()
        
        switch sound {
        case .system(let id):
            AudioServicesPlaySystemSoundWithCompletion(SystemSoundID(id), nil)
        case .custom(let fileName, let fileExtension):
            playBundledAudio(fileName: fileName, fileExtension: fileExtension)
        case .none:
            break
        }
        hapticTap(style: .medium)
    }
    
    private func playBundledAudio(fileName: String, fileExtension: String) {
        let key = "\(fileName).\(fileExtension)"
        
        if let player = preloadedPlayers[key] {
            player.currentTime = 0
            player.play()
            return
        }
        
        guard let url = ReactionItem.resolveFileURL(fileName: fileName, fileExtension: fileExtension) else {
            print("Could not find \(key)")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    func hapticTap(style: UIImpactFeedbackGenerator.FeedbackStyle = .heavy) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

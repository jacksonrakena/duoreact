import AudioToolbox
import AVFoundation
import UIKit

class SoundManager {
    static let shared = SoundManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var preloadedPlayers: [String: AVAudioPlayer] = [:]
    
    private init() {
        // Move AVAudioSession setup off the main thread to avoid UI unresponsiveness warning
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Audio session setup failed: \(error)")
            }
        }
    }
    
    /// Preload all custom audio files from reactions so playback is instant
    func preloadAll() {
        for reaction in allReactions {
            if case .custom(let fileName, let fileExtension) = reaction.sound {
                let key = "\(fileName).\(fileExtension)"
                let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: "Reactions")
                    ?? Bundle.main.url(forResource: fileName, withExtension: fileExtension)
                
                if let url = url, let player = try? AVAudioPlayer(contentsOf: url) {
                    player.prepareToPlay()
                    preloadedPlayers[key] = player
                }
            }
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
    
    /// Play a sound based on the SoundType, cancelling any currently playing sound first
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
        
        // Use preloaded player if available
        if let player = preloadedPlayers[key] {
            player.currentTime = 0 // Rewind so it plays from the start
            player.play()
            return
        }
        
        // Fallback: load on demand
        let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: "Reactions")
            ?? Bundle.main.url(forResource: fileName, withExtension: fileExtension)
        
        guard let url = url else {
            print("Could not find \(key) in bundle")
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

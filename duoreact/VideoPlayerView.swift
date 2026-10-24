import SwiftUI
import AVFoundation
import AVKit

/// Custom UIView that hosts an AVPlayerLayer and keeps its frame in sync.
class LoopingPlayerUIView: UIView {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var loopObserver: NSObjectProtocol?
    
    var loadedFile: String?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
    
    func loadVideo(fileName: String, fileExtension: String, videoGravity: AVLayerVideoGravity) {
        cleanup()
        
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: "Reactions")
                ?? Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            return
        }
        
        let player = AVPlayer(url: url)
        player.isMuted = false
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = videoGravity
        playerLayer.frame = bounds
        layer.addSublayer(playerLayer)
        
        self.player = player
        self.playerLayer = playerLayer
        self.loadedFile = "\(fileName).\(fileExtension)"
        
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
        
        player.play()
    }
    
    func cleanup() {
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        player = nil
        playerLayer = nil
    }
    
    deinit {
        cleanup()
    }
}

/// A UIViewRepresentable that plays an mp4 video in a loop using AVPlayerLayer.
struct VideoPlayerView: UIViewRepresentable {
    let fileName: String
    let fileExtension: String
    let contentMode: UIView.ContentMode
    
    init(fileName: String, fileExtension: String, contentMode: UIView.ContentMode = .scaleAspectFit) {
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.contentMode = contentMode
    }
    
    private var videoGravity: AVLayerVideoGravity {
        contentMode == .scaleAspectFill ? .resizeAspectFill : .resizeAspect
    }
    
    func makeUIView(context: Context) -> LoopingPlayerUIView {
        let view = LoopingPlayerUIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.loadVideo(fileName: fileName, fileExtension: fileExtension, videoGravity: videoGravity)
        return view
    }
    
    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        let currentFile = "\(fileName).\(fileExtension)"
        if uiView.loadedFile != currentFile {
            uiView.loadVideo(fileName: fileName, fileExtension: fileExtension, videoGravity: videoGravity)
        }
    }
    
    static func dismantleUIView(_ uiView: LoopingPlayerUIView, coordinator: ()) {
        uiView.cleanup()
    }
}

import SwiftUI

@main struct MyApp: App {
    init() {
        // Preload all reaction images in the background at launch
        ImageCache.shared.preloadAll()
        // Preload custom audio files
        SoundManager.shared.preloadAll()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

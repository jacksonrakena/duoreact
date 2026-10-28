import SwiftUI

@main struct MyApp: App {
    init() {
        // Use ReactionStore to include both built-in and custom reactions
        let items = ReactionStore.shared.allItems
        ImageCache.shared.preloadAll(items: items)
        SoundManager.shared.preloadAll(items: items)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

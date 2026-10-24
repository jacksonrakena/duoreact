import SwiftUI
import Playgrounds

struct ContentView: View {
    @State private var isOuterDisplayActive = false
    @State private var scriptText = "Hello, welcome to the dual screen demonstration."
    var body: some View {
        VStack(spacing: 20) {
                    Text("Inner Display (Controls)")
                        .font(.title)
                        .bold()
                    
                    TextEditor(text: $scriptText)
                        .padding()
                        .border(Color.secondary)
                    
                    Toggle("Project to Outer Screen", isOn: $isOuterDisplayActive)
                        .padding()
                }
                .padding()
                // Attach the dual-screen accessory to your main view
                .sceneAccessory {
                    CameraCaptureAccessory(isEnabled: $isOuterDisplayActive) {
                        // This content renders exclusively on the outer display facing the subject
                        OuterView(text: scriptText)
                    }
                    .onAvailabilityChange { isAvailable in
                        // Detects if the device status or posture allows the outer screen to be used
                        print("Outer display accessory available: \(isAvailable)")
                    }
                }
    }
}

struct OuterView: View {
    let text: String
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Text(text)
                .font(.largeTitle)
                .foregroundColor(.yellow)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

#Preview {
    ContentView()
}

#Playground {
    _ = 1 + 2
}

import AVFoundation
import Observation

@Observable
class DualScreenCaptureManager {
    var isSessionRunning = false
    var permissionStatus: AVAuthorizationStatus = .notDetermined
    
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.app.dualscreen.captureQueue")
    
    init() {
        self.permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    /// Requests physical camera permissions from the user
    func requestPermissionAndStart() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionStatus = granted ? .authorized : .denied
                if granted {
                    self?.setupAndStartSession()
                }
            }
        }
    }
    
    /// Configures a minimal, lightweight camera stack
    private func setupAndStartSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Prevent double configuration
            if self.captureSession.isRunning { return }
            
            self.captureSession.beginConfiguration()
            
            // Use a low resolution since we don't care about the stream pixels
            self.captureSession.sessionPreset = .low
            
            // Target any standard wide-angle back camera
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
                print("Failed to find or link physical camera device.")
                self.captureSession.commitConfiguration()
                return
            }
            
            if self.captureSession.canAddInput(videoDeviceInput) {
                self.captureSession.addInput(videoDeviceInput)
            }
            
            self.captureSession.commitConfiguration()
            
            // Wake up the physical hardware layer
            self.captureSession.startRunning()
            
            DispatchQueue.main.async {
                self.isSessionRunning = self.captureSession.isRunning
                print("AVCaptureSession successfully running on physical hardware.")
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            if self?.captureSession.isRunning == true {
                self?.captureSession.stopRunning()
                DispatchQueue.main.async {
                    self?.isSessionRunning = false
                }
            }
        }
    }
}

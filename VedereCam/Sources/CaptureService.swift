import AVFoundation
import CoreImage
import UIKit

/// Owns the capture session. Preview frames go through LookEngine; photos are captured as RAW when supported
/// (bypassing the system's tone mapping/sharpening/NR) and rendered with the same look.
final class CaptureService: NSObject, ObservableObject {
    @Published var previewImage: CGImage?
    @Published var rawSupported = false
    @Published var lastError: String?

    var look: Look = .neutral
    var options = OutputOptions()

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "capture.session")
    private let videoQueue = DispatchQueue(label: "capture.video")
    private var lastPreview = CFAbsoluteTimeGetCurrent()
    private var pendingLook = Look.neutral
    private var pendingOptions = OutputOptions()
    private var onSaved: (() -> Void)?

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted else { DispatchQueue.main.async { self?.lastError = "Camera access denied" }; return }
            self?.queue.async { self?.configure(); self?.session.startRunning() }
        }
    }

    func stop() { queue.async { self.session.stopRunning() } }

    private func configure() {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            session.commitConfiguration(); return
        }
        session.addInput(input)
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        session.commitConfiguration()
        DispatchQueue.main.async { self.rawSupported = !self.photoOutput.availableRawPhotoPixelFormatTypes.isEmpty }
    }

    func capture(onSaved: @escaping () -> Void) {
        pendingLook = look
        pendingOptions = options
        self.onSaved = onSaved
        queue.async {
            let settings: AVCapturePhotoSettings
            if let raw = self.photoOutput.availableRawPhotoPixelFormatTypes.first(where: {
                !AVCapturePhotoOutput.isAppleProRAWPixelFormat($0)
            }) ?? self.photoOutput.availableRawPhotoPixelFormatTypes.first {
                settings = AVCapturePhotoSettings(rawPixelFormatType: raw)
            } else {
                settings = AVCapturePhotoSettings()
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastPreview > 1.0 / 30, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastPreview = now
        var image = CIImage(cvPixelBuffer: buffer).oriented(.right)
        image = LookEngine.shared.render(image, look: look)
        if let cg = LookEngine.shared.context.createCGImage(image, from: image.extent) {
            DispatchQueue.main.async { self.previewImage = cg }
        }
    }
}

extension CaptureService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error { DispatchQueue.main.async { self.lastError = error.localizedDescription }; return }
        guard let data = photo.fileDataRepresentation() else { return }
        let id = Storage.newID()
        let look = pendingLook, options = pendingOptions

        // Render from RAW data when this is a RAW capture, otherwise from the processed photo.
        var base: CIImage?
        if photo.isRawPhoto {
            base = CIRAWFilter(imageData: data, identifierHint: "dng")?.outputImage
        } else {
            base = CIImage(data: data)
        }
        let rendered = base.map { LookEngine.shared.render($0, look: look) }
        do {
            try Storage.save(id: id, rawData: photo.isRawPhoto ? data : nil, rendered: rendered, look: look, options: options)
            DispatchQueue.main.async { self.onSaved?() }
        } catch {
            DispatchQueue.main.async { self.lastError = error.localizedDescription }
        }
    }
}

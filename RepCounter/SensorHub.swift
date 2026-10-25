import AVFoundation
import CoreMotion
import Vision

/// Toutes les mesures d'une image vidéo. Horloge : temps hôte (secondes), comme l'audio.
struct SensorFrame {
    let time: Double
    var values: [SignalSource: [Float]]
}

/// Caméra avant (TrueDepth si disponible), Vision et CoreMotion.
final class SensorHub: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDepthDataOutputDelegate {
    let session = AVCaptureSession()
    /// File série des mesures, sur laquelle `onFrame` est appelé.
    let queue = DispatchQueue(label: "repcounter.sensors", qos: .userInteractive)

    var onFrame: ((SensorFrame) -> Void)?

    private let sessionQueue = DispatchQueue(label: "repcounter.session")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let depthOutput = AVCaptureDepthDataOutput()
    private let motion = CMMotionManager()
    private let poseRequest = VNDetectHumanBodyPoseRequest()
    private let faceRequest = VNDetectFaceRectanglesRequest()
    private let poseExtractor = PoseFeatureExtractor()
    private var latestDepth: [Float]?
    private var lastDepthMean: Float = 0

    func start() {
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1.0 / 30
            motion.startDeviceMotionUpdates()
        }
        sessionQueue.async {
            if self.session.inputs.isEmpty { self.configure() }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func configure() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.automaticallyConfiguresApplicationAudioSession = false

        guard let device = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        // 640×480 : suffisant pour Vision et compatible avec la profondeur
        if session.canSetSessionPreset(.vga640x480) { session.sessionPreset = .vga640x480 }

        if session.canAddOutput(videoOutput) {
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
            videoOutput.setSampleBufferDelegate(self, queue: queue)
            session.addOutput(videoOutput)
        }

        if device.deviceType == .builtInTrueDepthCamera, session.canAddOutput(depthOutput) {
            session.addOutput(depthOutput)
            depthOutput.isFilteringEnabled = true
            depthOutput.alwaysDiscardsLateDepthData = true
            depthOutput.setDelegate(self, callbackQueue: queue)
            depthOutput.connection(with: .depthData)?.isEnabled = true
        }

        // Images droites (portrait) et en miroir comme l'aperçu : Vision travaille en .up
        if let connection = videoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }
    }

    // MARK: - Profondeur

    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData,
                         timestamp: CMTime, connection: AVCaptureConnection) {
        let converted = depthData.depthDataType == kCVPixelFormatType_DepthFloat32
            ? depthData : depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let map = converted.depthDataMap
        CVPixelBufferLockBaseAddress(map, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(map) else { return }
        let width = CVPixelBufferGetWidth(map)
        let height = CVPixelBufferGetHeight(map)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(map)

        // Moitié centrale de l'image ; trop près, la profondeur n'est plus mesurable
        var sum: Float = 0
        var valid = 0
        var total = 0
        for y in stride(from: height / 4, to: 3 * height / 4, by: 4) {
            let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: Float32.self)
            for x in stride(from: width / 4, to: 3 * width / 4, by: 4) {
                total += 1
                let depth = row[x]
                if depth.isFinite, depth > 0 {
                    sum += depth
                    valid += 1
                }
            }
        }
        if valid > 0 { lastDepthMean = sum / Float(valid) }
        latestDepth = [lastDepthMean, Float(valid) / Float(max(total, 1))]
    }

    // MARK: - Vidéo

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        var values: [SignalSource: [Float]] = [:]

        if let depth = latestDepth { values[.depth] = depth }
        if let thumbnail = thumbnail(pixelBuffer) { values[.pixels] = thumbnail }
        if let gravity = motion.deviceMotion?.gravity {
            values[.motion] = [Float(gravity.x), Float(gravity.y), Float(gravity.z)]
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([poseRequest, faceRequest])
        if let face = faceRequest.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }) {
            let box = face.boundingBox
            values[.face] = [Float(box.midX), Float(box.midY), Float(box.width)]
        }
        if let observation = poseRequest.results?.max(by: { $0.confidence < $1.confidence }),
           let recognized = try? observation.recognizedPoints(.all) {
            var points = [Joint: CGPoint]()
            for (joint, point) in recognized where point.confidence > 0.3 { points[joint] = point.location }
            let aspect = CGFloat(CVPixelBufferGetWidth(pixelBuffer)) / CGFloat(max(CVPixelBufferGetHeight(pixelBuffer), 1))
            if points.count >= 8, let features = poseExtractor.features(from: points, aspect: aspect) {
                values[.pose] = features
            }
        }

        onFrame?(SensorFrame(time: time, values: values))
    }

    /// Image réduite à 12×16 en niveaux de gris (plan Y), valeurs 0…1.
    private func thumbnail(_ pixelBuffer: CVPixelBuffer) -> [Float]? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard CVPixelBufferGetPlaneCount(pixelBuffer) > 0,
              let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return nil }
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let bytes = base.assumingMemoryBound(to: UInt8.self)

        let columns = 12, rows = 16
        let blockWidth = width / columns, blockHeight = height / rows
        guard blockWidth >= 4, blockHeight >= 4 else { return nil }
        var result = [Float](repeating: 0, count: columns * rows)
        for r in 0..<rows {
            for c in 0..<columns {
                // 16 échantillons par bloc suffisent
                var sum = 0
                for sy in 0..<4 {
                    let y = r * blockHeight + sy * blockHeight / 4 + blockHeight / 8
                    for sx in 0..<4 {
                        let x = c * blockWidth + sx * blockWidth / 4 + blockWidth / 8
                        sum += Int(bytes[y * bytesPerRow + x])
                    }
                }
                result[r * columns + c] = Float(sum) / (16 * 255)
            }
        }
        return result
    }
}

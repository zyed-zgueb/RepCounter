import AVFoundation
import CoreMotion
import Vision

/// Toutes les mesures d'une image vidéo. Horloge : temps hôte (secondes), comme l'audio.
struct SensorFrame {
    let time: Double
    var values: [SignalSource: [Float]]
    /// Mesures supplémentaires, seulement enregistrées pour l'analyse (pas utilisées pour compter).
    var extras: [String: [Float]] = [:]
}

/// Caméra avant (TrueDepth si disponible), Vision et CoreMotion. Avec la caméra, chaque image
/// vidéo produit une mesure ; sans caméra, c'est le capteur de mouvement qui cadence (30/s).
final class SensorHub: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDepthDataOutputDelegate {
    let session = AVCaptureSession()
    /// File série des mesures, sur laquelle `onFrame` est appelé.
    let queue = DispatchQueue(label: "repcounter.sensors", qos: .userInteractive)

    var onFrame: ((SensorFrame) -> Void)?
    /// Sources calculées à chaque mesure : celles de l'exercice.
    let activeSources: Set<SignalSource>
    private let usesCamera: Bool

    private let sessionQueue = DispatchQueue(label: "repcounter.session")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let depthOutput = AVCaptureDepthDataOutput()
    private let motion = CMMotionManager()
    private let poseRequest = VNDetectHumanBodyPoseRequest()
    private let faceRequest = VNDetectFaceRectanglesRequest()
    private let poseExtractor: PoseFeatureExtractor
    private var latestDepth: [Float]?
    private var lastDepthMean: Float = 0
    /// Distances mesurées au centre (10e, 50e, 90e centiles), part mesurable, moyenne.
    private var latestDepthStats: [Float]?
    private lazy var motionQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = self.queue
        return operationQueue
    }()

    init(sources: Set<SignalSource>, upperBody: Bool = false) {
        activeSources = sources
        poseExtractor = PoseFeatureExtractor(upperBody: upperBody)
        usesCamera = !sources.isDisjoint(with: [.depth, .pixels, .face, .pose])
        super.init()
    }

    func start() {
        guard motion.isDeviceMotionAvailable || usesCamera else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30
        if usesCamera {
            // Lu à chaque image vidéo
            motion.startDeviceMotionUpdates()
            sessionQueue.async {
                if self.session.inputs.isEmpty { self.configure() }
                if !self.session.isRunning { self.session.startRunning() }
            }
        } else {
            motion.startDeviceMotionUpdates(to: motionQueue) { [weak self] deviceMotion, _ in
                guard let self, let deviceMotion else { return }
                self.onFrame?(SensorFrame(time: deviceMotion.timestamp, values: self.motionValues(deviceMotion)))
            }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func motionValues(_ deviceMotion: CMDeviceMotion) -> [SignalSource: [Float]] {
        let gravity = deviceMotion.gravity
        let acceleration = deviceMotion.userAcceleration
        let rotation = deviceMotion.rotationRate
        // Accélération le long de la verticale, quelle que soit l'orientation du téléphone
        let vertical = acceleration.x * gravity.x + acceleration.y * gravity.y + acceleration.z * gravity.z
        return [
            .motion: [Float(gravity.x), Float(gravity.y), Float(gravity.z)],
            .vertical: [Float(vertical)],
            .rotation: [Float(rotation.x), Float(rotation.y), Float(rotation.z)],
        ]
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
            // Mesures brutes : le lissage invente des distances là où la caméra ne mesure rien
            // (visage à moins de 20 cm) ; sans lui, la part non mesurable est une vraie mesure
            depthOutput.isFilteringEnabled = false
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
        var measured: [Float] = []
        var total = 0
        for y in stride(from: height / 4, to: 3 * height / 4, by: 4) {
            let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: Float32.self)
            for x in stride(from: width / 4, to: 3 * width / 4, by: 4) {
                total += 1
                let depth = row[x]
                if depth.isFinite, depth > 0 { measured.append(depth) }
            }
        }
        let validFraction = Float(measured.count) / Float(max(total, 1))
        if !measured.isEmpty { lastDepthMean = measured.reduce(0, +) / Float(measured.count) }
        latestDepth = [lastDepthMean, validFraction]
        let sorted = measured.sorted()
        func centile(_ p: Float) -> Float {
            sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Float(sorted.count - 1) * p))]
        }
        latestDepthStats = [centile(0.1), centile(0.5), centile(0.9), validFraction, lastDepthMean]
    }

    // MARK: - Vidéo

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let sources = activeSources
        var values: [SignalSource: [Float]] = [:]

        if sources.contains(.depth), let depth = latestDepth { values[.depth] = depth }
        if sources.contains(.pixels), let thumbnail = thumbnail(pixelBuffer) { values[.pixels] = thumbnail }
        if let deviceMotion = motion.deviceMotion {
            values.merge(motionValues(deviceMotion)) { current, _ in current }
        }

        // Vision est le calcul le plus coûteux : seulement si l'exercice en a besoin
        var requests: [VNRequest] = []
        if sources.contains(.pose) { requests.append(poseRequest) }
        if sources.contains(.face) { requests.append(faceRequest) }
        if !requests.isEmpty {
            try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up).perform(requests)
        }
        if sources.contains(.face),
           let face = faceRequest.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }) {
            let box = face.boundingBox
            values[.face] = [Float(box.midX), Float(box.midY), Float(box.width)]
        }
        var joints: [Float]?
        if sources.contains(.pose) {
            var points = [Joint: CGPoint]()
            if let observation = poseRequest.results?.max(by: { $0.confidence < $1.confidence }),
               let recognized = try? observation.recognizedPoints(.all) {
                for (joint, point) in recognized where point.confidence > 0.3 { points[joint] = point.location }
            }
            let aspect = CGFloat(CVPixelBufferGetWidth(pixelBuffer)) / CGFloat(max(CVPixelBufferGetHeight(pixelBuffer), 1))
            // Haut du corps : tête, épaules, bras suffisent (5 articulations) ; sinon le corps entier
            if points.count >= (poseExtractor.upperBody ? 5 : 8), let features = poseExtractor.features(from: points, aspect: aspect) {
                values[.pose] = features
            }
            // Articulations vues, pour la mise en place (cadrage) : x, y en coordonnées d'image,
            // origine en haut à gauche comme à l'écran ; −1 si non vue
            joints = Skeleton.joints.flatMap { joint -> [Float] in
                guard let p = points[joint] else { return [-1, -1] }
                return [Float(p.x), Float(1 - p.y)]
            }
        }

        var frame = SensorFrame(time: time, values: values)
        if let joints { frame.extras["joints"] = joints }
        if sources.contains(.depth), let stats = latestDepthStats { frame.extras["depthStats"] = stats }
        onFrame?(frame)
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

import SwiftUI
import AVFoundation

/// Retour sonore : on ne voit pas l'écran pendant des pompes ou avec le téléphone sur la poitrine.
/// Voix pour les nombres annoncés, bip court pour les autres répétitions.
final class Announcer {
    private let synthesizer = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(language: "fr-FR")
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let tick: AVAudioPCMBuffer?

    init() {
        // Lecture même en mode silencieux, mélangée à la musique en cours
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        tick = format.flatMap(Self.makeTick)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    func say(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = 0.55
        synthesizer.speak(utterance)
    }

    func playTick() {
        guard let tick else { return }
        // Le moteur s'arrête lors d'une interruption audio (appel, changement d'écouteurs)
        if !engine.isRunning { try? engine.start() }
        player.scheduleBuffer(tick, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    /// Bip de 80 ms à 1 320 Hz, attaque nette et extinction rapide.
    private static func makeTick(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(format.sampleRate * 0.08)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / format.sampleRate
            samples[i] = Float(sin(2 * Double.pi * 1320 * t) * exp(-t * 40) * 0.6)
        }
        return buffer
    }
}

final class WorkoutModel: ObservableObject {
    @Published private(set) var count = 0
    @Published private(set) var phase: Float = 0
    @Published private(set) var state: AutoCounter.State = .searching
    @Published private(set) var source: SignalSource?
    @Published private(set) var repPulse = 0
    @Published private(set) var cameraDenied = false
    /// Écran de diagnostic : images par seconde et état de chaque capteur.
    @Published var showsDiagnostics = false
    @Published private(set) var framesPerSecond: Double = 0
    @Published private(set) var diagnostics: [SourceDiagnostic] = []
    /// Annonce vocale toutes les N répétitions (1, 5 ou 10) ; bip pour les autres.
    @Published var announceEvery = 1 {
        didSet { UserDefaults.standard.set(announceEvery, forKey: "announceEvery") }
    }
    static let announceChoices = [1, 5, 10]
    /// Exercice choisi : capteurs écoutés et placement du téléphone.
    @Published var exercise = Exercise.auto {
        didSet {
            UserDefaults.standard.set(exercise.rawValue, forKey: "exercise")
            apply(exercise)
        }
    }

    let sensors = SensorHub()
    private var counter = AutoCounter(exercise: .auto)   // utilisé uniquement sur sensors.queue
    private let announcer = Announcer()
    private let haptic = UIImpactFeedbackGenerator(style: .heavy)
    // Mesure du débit d'images (sensors.queue)
    private var frameTimes: [Double] = []
    private var frameIndex = 0

    init() {
        let saved = UserDefaults.standard.integer(forKey: "announceEvery")
        announceEvery = Self.announceChoices.contains(saved) ? saved : 1
        exercise = UserDefaults.standard.string(forKey: "exercise").flatMap(Exercise.init(rawValue:)) ?? .auto
        sensors.onFrame = { [weak self] frame in self?.handle(frame) }
        apply(exercise)   // didSet n'est pas appelé pendant l'init
    }

    func start() {
        UIApplication.shared.isIdleTimerDisabled = true
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sensors.start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.sensors.start() } else { self.cameraDenied = true }
                }
            }
        default:
            cameraDenied = true
        }
    }

    func stop() {
        UIApplication.shared.isIdleTimerDisabled = false
        sensors.stop()
    }

    func cycleAnnounceEvery() {
        let index = Self.announceChoices.firstIndex(of: announceEvery) ?? 0
        announceEvery = Self.announceChoices[(index + 1) % Self.announceChoices.count]
    }

    /// Nouveau compteur pour l'exercice ; seuls ses capteurs restent calculés.
    private func apply(_ exercise: Exercise) {
        sensors.queue.async {
            self.counter = AutoCounter(exercise: exercise)
            self.sensors.activeSources = Set(exercise.sources)
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { count = 0 }
        phase = 0
        state = .searching
        source = nil
        diagnostics = []
    }

    func reset() {
        sensors.queue.async { self.counter.reset() }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { count = 0 }
        phase = 0
    }

    // Appelé sur sensors.queue
    private func handle(_ frame: SensorFrame) {
        let output = counter.process(frame)
        frameTimes.append(frame.time)
        if frameTimes.count > 30 { frameTimes.removeFirst(frameTimes.count - 30) }
        frameIndex += 1
        // Diagnostic rafraîchi 3 fois par seconde environ
        if frameIndex % 10 == 0, let first = frameTimes.first, let last = frameTimes.last, last > first {
            let fps = Double(frameTimes.count - 1) / (last - first)
            let diagnostics = output.diagnostics
            DispatchQueue.main.async {
                self.framesPerSecond = fps
                self.diagnostics = diagnostics
            }
        }
        DispatchQueue.main.async {
            self.phase = output.phase
            if output.count != self.count {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { self.count = output.count }
            }
            if output.didCount {
                self.repPulse += 1
                self.haptic.impactOccurred()
                // Le premier nombre est toujours dit : il signale que le comptage a démarré
                let started = self.state != .counting
                if started || output.count % self.announceEvery == 0 {
                    self.announcer.say("\(output.count)")
                } else {
                    self.announcer.playTick()
                }
            }
            if self.state == .counting, output.state == .resting {
                self.announcer.say("Pause. Total : \(output.count)")
            }
            if self.state != output.state { self.state = output.state }
            if output.source != nil, self.source != output.source { self.source = output.source }
        }
    }
}

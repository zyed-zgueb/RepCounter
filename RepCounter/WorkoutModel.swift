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

/// Ce qui change à chaque mesure (30 fois par seconde). Seuls l'anneau et la courbe
/// l'observent : le reste de l'écran, et ses boutons, ne sont pas redessinés en continu.
final class LiveSignal: ObservableObject {
    static let sampleCount = 90   // 3 s de courbe

    /// Avancement dans la répétition en cours (anneau).
    @Published private(set) var phase: Float = 0
    /// Position récente du signal suivi, 0…1 (courbe).
    @Published private(set) var samples = [Float](repeating: 0.5, count: LiveSignal.sampleCount)
    /// Netteté du mouvement : ≥ 1 quand il est assez net pour compter.
    @Published private(set) var strength: Float = 0

    func push(phase: Float, value: Float, strength: Float) {
        self.phase = phase
        self.strength = strength
        samples.removeFirst()
        samples.append(value)
    }

    func clearPhase() {
        phase = 0
    }
}

/// Enregistrement arrêté, en attente du nombre de répétitions réellement faites.
struct FinishedRecording: Identifiable {
    let id = UUID()
    let recorder: SessionRecorder
    let countedReps: Int
}

final class WorkoutModel: ObservableObject {
    /// Ce que l'app perçoit de toi, pour l'indicateur sous le compteur.
    enum Presence { case absent, weak, clear }

    let exercise: Exercise
    let live = LiveSignal()

    @Published private(set) var count = 0
    @Published private(set) var state: AutoCounter.State = .searching
    @Published private(set) var source: SignalSource?
    @Published private(set) var presence = Presence.absent
    @Published private(set) var repPulse = 0
    @Published private(set) var cameraDenied = false
    /// Écran de diagnostic : mesures par seconde et état de chaque capteur.
    @Published var showsDiagnostics = false
    @Published private(set) var framesPerSecond: Double = 0
    @Published private(set) var diagnostics: [SourceDiagnostic] = []
    /// Annonce vocale toutes les N répétitions (1, 5 ou 10) ; bip pour les autres.
    @Published var announceEvery: Int {
        didSet { UserDefaults.standard.set(announceEvery, forKey: Self.announceEveryKey) }
    }
    static let announceEveryKey = "announceEvery"
    static let announceChoices = [1, 5, 10]
    /// Enregistrement des mesures, pour analyser une séance qui compte mal.
    @Published private(set) var isRecording = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published var finishedRecording: FinishedRecording?

    let sensors: SensorHub
    private let counter: AutoCounter   // utilisé uniquement sur sensors.queue
    private let announcer = Announcer()
    private let haptic = UIImpactFeedbackGenerator(style: .heavy)
    // Sur sensors.queue : débit des mesures et netteté lissée (évite que l'indicateur clignote)
    private var frameTimes: [Double] = []
    private var frameIndex = 0
    private var smoothedStrength: Float = 0
    private var recorder: SessionRecorder?

    init(exercise: Exercise) {
        self.exercise = exercise
        sensors = SensorHub(sources: Set(exercise.sources))
        counter = AutoCounter(exercise: exercise)
        let saved = UserDefaults.standard.integer(forKey: Self.announceEveryKey)
        announceEvery = Self.announceChoices.contains(saved) ? saved : 1
        sensors.onFrame = { [weak self] frame in self?.handle(frame) }
    }

    func start() {
        UIApplication.shared.isIdleTimerDisabled = true
        guard exercise.usesCamera else {
            sensors.start()
            return
        }
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
        // Écran quitté pendant un enregistrement : on le termine sans le résultat
        if isRecording {
            let counted = count
            sensors.queue.async {
                self.recorder?.finish(countedReps: counted, actualReps: nil)
                self.recorder = nil
            }
            isRecording = false
        }
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else if let recorder = SessionRecorder(exercise: exercise) {
            sensors.queue.async { self.recorder = recorder }
            recordingDuration = 0
            isRecording = true
        }
    }

    private func stopRecording() {
        isRecording = false
        let counted = count
        // Retiré de la file des capteurs avant d'être terminé : plus aucune écriture ensuite
        sensors.queue.async {
            guard let recorder = self.recorder else { return }
            self.recorder = nil
            DispatchQueue.main.async {
                self.finishedRecording = FinishedRecording(recorder: recorder, countedReps: counted)
            }
        }
    }

    func cycleAnnounceEvery() {
        let index = Self.announceChoices.firstIndex(of: announceEvery) ?? 0
        announceEvery = Self.announceChoices[(index + 1) % Self.announceChoices.count]
    }

    func reset() {
        sensors.queue.async { self.counter.reset() }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { count = 0 }
        live.clearPhase()
    }

    // Appelé sur sensors.queue
    private func handle(_ frame: SensorFrame) {
        let output = counter.process(frame)
        frameTimes.append(frame.time)
        if frameTimes.count > 30 { frameTimes.removeFirst(frameTimes.count - 30) }
        frameIndex += 1
        smoothedStrength += 0.1 * (output.liveStrength - smoothedStrength)
        let presence: Presence = smoothedStrength >= 1 ? .clear : (smoothedStrength >= 0.3 ? .weak : .absent)
        if let recorder {
            recorder.append(frame, output: output)
            if frameIndex % 15 == 0 {
                let duration = recorder.duration
                DispatchQueue.main.async {
                    self.recordingDuration = duration
                    if duration >= SessionRecorder.maxDuration, self.isRecording { self.stopRecording() }
                }
            }
        }

        // Diagnostic rafraîchi 3 fois par seconde environ
        if frameIndex % 10 == 0, let first = frameTimes.first, let last = frameTimes.last, last > first {
            let fps = Double(frameTimes.count - 1) / (last - first)
            let diagnostics = output.diagnostics
            DispatchQueue.main.async {
                self.framesPerSecond = fps
                if self.showsDiagnostics { self.diagnostics = diagnostics }
            }
        }
        DispatchQueue.main.async {
            self.live.push(phase: output.phase, value: output.liveValue, strength: output.liveStrength)
            // Les propriétés suivantes ne sont publiées que quand elles changent
            if self.presence != presence { self.presence = presence }
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

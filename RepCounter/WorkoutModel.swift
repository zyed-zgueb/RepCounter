import SwiftUI
import AVFoundation
import QuartzCore

/// Ce qui change à chaque mesure (30 fois par seconde). Seuls l'anneau et la courbe
/// l'observent : le reste de l'écran, et ses boutons, ne sont pas redessinés en continu.
///
/// La courbe est apaisée, pour l'affichage seulement (le compteur n'en dépend pas) : lissée,
/// aplatie quand le mouvement est trop faible pour compter (le bruit des capteurs ne s'agite
/// pas à l'écran), et lente (8 s à l'écran, 20 points par seconde).
final class LiveSignal: ObservableObject {
    static let sampleCount = 160
    private static let sampleInterval = 1.0 / 20

    /// Avancement dans la répétition en cours (anneau).
    @Published private(set) var phase: Float = 0
    /// Position récente du signal suivi, 0…1 (courbe).
    @Published private(set) var samples = [Float](repeating: 0.5, count: LiveSignal.sampleCount)
    /// Netteté du mouvement, lissée : ≥ 1 quand il est assez net pour compter.
    @Published private(set) var strength: Float = 0

    private var smoothedValue: Float = 0.5
    private var lastSample: CFTimeInterval = 0

    func push(phase: Float, value: Float, strength: Float) {
        self.phase = phase
        self.strength += 0.05 * (strength - self.strength)
        // Sous le seuil de comptage, l'oscillation s'efface progressivement jusqu'à la ligne plate
        let presence = min(max((self.strength - 0.3) / 0.7, 0), 1)
        smoothedValue += 0.15 * (0.5 + (value - 0.5) * presence - smoothedValue)
        let now = CACurrentMediaTime()
        guard now - lastSample >= Self.sampleInterval else { return }
        lastSample = now
        samples.removeFirst()
        samples.append(smoothedValue)
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

/// Une série terminée.
struct WorkoutSet: Identifiable {
    let id = UUID()
    let number: Int
    let reps: Int
    /// De la première à la dernière répétition.
    let duration: TimeInterval
    /// Durée d'une répétition (s).
    let cadence: Double?
    /// Première répétition.
    let start: Date
    /// Instant de chaque répétition, en secondes depuis la première (rythme rep par rep).
    let repTimes: [TimeInterval]
}

/// Séance : prêt → compte à rebours → séries et récupérations automatiques → résumé.
final class WorkoutModel: ObservableObject {
    enum Phase: Equatable {
        case ready
        case countdown(Int)
        case active
        case finished
    }

    /// Ampleur du mouvement capté (au repos, léger, assez net pour compter), pour le voyant.
    enum Presence { case absent, weak, clear }

    static let countdownSeconds = 5
    /// Récupération signalée toutes les 30 s.
    private static let restAnnouncementInterval = 30

    let exercise: Exercise
    let live = LiveSignal()

    @Published private(set) var phase = Phase.ready
    /// Répétitions de la série en cours.
    @Published private(set) var setReps = 0
    @Published private(set) var sets: [WorkoutSet] = []
    @Published private(set) var state: AutoCounter.State = .searching
    @Published private(set) var source: SignalSource?
    @Published private(set) var presence = Presence.absent
    @Published private(set) var cadence: Double?
    @Published private(set) var regularity: Float = 0
    @Published private(set) var repPulse = 0
    /// Répétitions détectées mais pas encore validées (avant le démarrage du comptage d'une série).
    @Published private(set) var tentative = 0
    @Published private(set) var tentativePulse = 0
    @Published private(set) var cameraDenied = false
    /// Horloge de l'écran (1 Hz) : durée de séance et chronomètre de récupération.
    @Published private(set) var now = Date()
    @Published private(set) var sessionStart: Date?
    @Published private(set) var sessionEnd: Date?
    @Published private(set) var lastRepDate: Date?
    /// Écran de diagnostic : mesures par seconde et état de chaque capteur.
    @Published var showsDiagnostics = false
    @Published private(set) var framesPerSecond: Double = 0
    @Published private(set) var diagnostics: [SourceDiagnostic] = []
    /// Enregistrement des mesures, pour analyser une séance qui compte mal.
    @Published private(set) var isRecording = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published var finishedRecording: FinishedRecording?

    var totalReps: Int { sets.reduce(0) { $0 + $1.reps } + setReps }
    /// Numéro de la série en cours (ou de la prochaine, pendant la récupération).
    var setNumber: Int { sets.count + 1 }
    var isResting: Bool { phase == .active && state != .counting && !sets.isEmpty }
    var restDuration: TimeInterval { isResting ? now.timeIntervalSince(lastRepDate ?? now) : 0 }
    var sessionDuration: TimeInterval {
        guard let sessionStart else { return 0 }
        return (sessionEnd ?? now).timeIntervalSince(sessionStart)
    }

    let sensors: SensorHub
    private let counter: AutoCounter   // utilisé uniquement sur sensors.queue
    /// Retour sonore, selon le réglage lu à l'ouverture de l'écran.
    private let announcer = Announcer()
    private let haptic = UIImpactFeedbackGenerator(style: .heavy)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private var clock: Timer?
    private var countdownTimer: Timer?
    // Fil principal : compte du compteur depuis le démarrage, base de la série en cours
    private var counterTotal = 0
    private var setBase = 0
    private var setStart: Date?
    /// Instants des répétitions de la série en cours.
    private var setRepDates: [Date] = []
    private var restAnnouncements = 0
    /// Remise à zéro demandée au compteur (démarrage, série annulée) : les mesures sont
    /// ignorées jusqu'à ce qu'il la confirme, pour ne pas compter avec l'ancien état.
    private var awaitingReset = false
    // Sur sensors.queue : débit des mesures et netteté lissée (évite que l'indicateur clignote)
    private var frameTimes: [Double] = []
    private var frameIndex = 0
    private var smoothedStrength: Float = 0
    private var recorder: SessionRecorder?
    /// Dernières mesures (autant que l'historique du compteur), écrites au début d'un enregistrement.
    private var recentFrames: [(frame: SensorFrame, output: AutoCounter.Output)] = []
    private static let preRollDuration = 16.0

    init(exercise: Exercise) {
        self.exercise = exercise
        sensors = SensorHub(sources: Set(exercise.sources))
        counter = AutoCounter(exercise: exercise)
        sensors.onFrame = { [weak self] frame in self?.handle(frame) }
    }

    // MARK: - Capteurs

    /// Écran affiché : les capteurs tournent (l'indicateur de signal aide à se placer),
    /// mais rien n'est compté avant « Démarrer ».
    func start() {
        UIApplication.shared.isIdleTimerDisabled = true
        clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
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
        clock?.invalidate()
        countdownTimer?.invalidate()
        sensors.stop()
        // Écran quitté pendant un enregistrement : on le termine sans le résultat
        if isRecording {
            let counted = totalReps
            sensors.queue.async {
                self.recorder?.finish(countedReps: counted, actualReps: nil)
                self.recorder = nil
            }
            isRecording = false
        }
    }

    // MARK: - Séance

    /// « Démarrer » : compte à rebours, le temps de se mettre en place. Silencieux, puis
    /// une note à 3, 2 et 1, et l'accord du départ.
    func beginSession() {
        guard phase == .ready else { return }
        var remaining = Self.countdownSeconds
        phase = .countdown(remaining)
        lightHaptic.impactOccurred()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { return timer.invalidate() }
            remaining -= 1
            if remaining > 0 {
                self.phase = .countdown(remaining)
                if remaining <= 3 {
                    self.announcer.play(.count)
                    self.lightHaptic.impactOccurred()
                }
            } else {
                timer.invalidate()
                self.startCounting()
            }
        }
    }

    func cancelCountdown() {
        guard phase.isCountdown else { return }
        countdownTimer?.invalidate()
        phase = .ready
    }

    /// Fin du compte à rebours : tout ce qui précède (mise en place) est ignoré.
    private func startCounting() {
        sensors.queue.async { self.counter.reset() }
        awaitingReset = true
        counterTotal = 0
        setBase = 0
        setReps = 0
        sets = []
        state = .searching
        lastRepDate = nil
        sessionStart = Date()
        sessionEnd = nil
        now = Date()
        phase = .active
        announcer.play(.go)
        haptic.impactOccurred()
    }

    /// Annule la série en cours, ou la dernière terminée pendant la récupération.
    func cancelSet() {
        guard phase == .active else { return }
        if state == .counting || setReps > 0 {
            sensors.queue.async { self.counter.reset() }
            awaitingReset = true
            counterTotal = 0
            setBase = 0
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { setReps = 0 }
            setRepDates = []
            state = .searching
            live.clearPhase()
            announcer.say("Série annulée")
        } else if !sets.isEmpty {
            sets.removeLast()
            announcer.say("Série annulée")
        }
    }

    /// « Terminer » : la série en cours est close, puis le résumé s'affiche.
    func finishSession() {
        guard phase == .active || phase.isCountdown else { return }
        countdownTimer?.invalidate()
        if setReps > 0 { closeSet(announce: false) }
        sessionEnd = Date()
        phase = .finished
        // Séance enregistrée : l'enregistrement s'arrête avec elle, et la feuille de fin
        // (répétitions réelles, partage) s'ouvre sur le résumé
        if isRecording { stopRecording() }
        sensors.stop()
        announcer.play(.finish)
        announcer.say(totalReps > 0 ? "Séance terminée. \(totalReps) répétitions." : "Séance terminée.")
    }

    /// Depuis le résumé : nouvelle séance, même exercice.
    func newSession() {
        guard phase == .finished else { return }
        sets = []
        setReps = 0
        sessionStart = nil
        sessionEnd = nil
        lastRepDate = nil
        phase = .ready
        sensors.start()
    }

    private func closeSet(announce: Bool) {
        let reps = setReps
        guard reps > 0 else { return }
        let start = setStart ?? setRepDates.first ?? Date()
        let duration = max(0, (lastRepDate ?? Date()).timeIntervalSince(start))
        let repTimes = setRepDates.prefix(reps).map { max(0, $0.timeIntervalSince(start)) }
        // Cadence de la série : intervalle médian entre ses répétitions (le rythme du compteur,
        // mesuré sur les derniers cycles, est faussé par la fin de série)
        let pace = medianInterval(Array(repTimes)) ?? cadence
        sets.append(WorkoutSet(number: sets.count + 1, reps: reps, duration: duration, cadence: pace,
                               start: start, repTimes: repTimes))
        setBase = counterTotal
        setReps = 0
        setRepDates = []
        restAnnouncements = 0
        if announce {
            announcer.play(.setEnd)
            announcer.say("Série \(sets.count) : \(reps).")
        }
    }

    private func tick() {
        now = Date()
        // Récupération annoncée toutes les 30 s
        guard isResting else { return }
        let marks = Int(restDuration) / Self.restAnnouncementInterval
        if marks > restAnnouncements {
            restAnnouncements = marks
            announcer.play(.rest)
            announcer.say(Self.spokenDuration(marks * Self.restAnnouncementInterval))
        }
    }

    private static func spokenDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60, rest = seconds % 60
        switch (minutes, rest) {
        case (0, _): return "\(rest) secondes"
        case (_, 0): return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        default: return "\(minutes) minute\(minutes > 1 ? "s" : "") \(rest)"
        }
    }

    // MARK: - Enregistrement

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else if let recorder = SessionRecorder(exercise: exercise) {
            sensors.queue.async {
                for entry in self.recentFrames { recorder.append(entry.frame, output: entry.output, preRoll: true) }
                self.recorder = recorder
            }
            recordingDuration = 0
            isRecording = true
        }
    }

    private func stopRecording() {
        isRecording = false
        let counted = totalReps
        // Retiré de la file des capteurs avant d'être terminé : plus aucune écriture ensuite
        sensors.queue.async {
            guard let recorder = self.recorder else { return }
            self.recorder = nil
            DispatchQueue.main.async {
                self.finishedRecording = FinishedRecording(recorder: recorder, countedReps: counted)
            }
        }
    }

    // MARK: - Mesures

    // Appelé sur sensors.queue
    private func handle(_ frame: SensorFrame) {
        let output = counter.process(frame)
        recentFrames.append((frame: frame, output: output))
        let expired = recentFrames.prefix { $0.frame.time < frame.time - Self.preRollDuration }.count
        if expired > 0 { recentFrames.removeFirst(expired) }
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
            if output.source != nil, self.source != output.source { self.source = output.source }
            // Avant « Démarrer » et pendant le compte à rebours, rien ne compte
            guard self.phase == .active else { return }
            self.apply(output)
        }
    }

    // Fil principal, séance en cours
    private func apply(_ output: AutoCounter.Output) {
        if awaitingReset {
            guard output.didReset else { return }
            awaitingReset = false
        }
        counterTotal = output.count
        if let cadence = output.cadence, self.cadence != cadence { self.cadence = cadence }
        if output.regularity > 0, regularity != output.regularity { regularity = output.regularity }

        // Répétitions provisoires : une vibration légère à chacune, pour dire « je te suis »
        let tentative = output.state == .counting ? 0 : output.tentative
        if tentative != self.tentative {
            if tentative > self.tentative {
                tentativePulse += 1
                lightHaptic.impactOccurred()
            }
            self.tentative = tentative
        }

        if output.didCount {
            let reps = max(0, output.count - setBase)
            let started = state != .counting
            if started {
                // Nouvelle série : ses premières répétitions viennent d'être rattrapées ; leurs
                // instants sont reconstitués à la cadence mesurée
                let cadence = output.cadence ?? 2
                let last = repDate(output)
                let start = last.addingTimeInterval(-Double(max(reps - 1, 0)) * cadence)
                setStart = start
                setRepDates = (0..<reps).map { start.addingTimeInterval(Double($0) * cadence) }
                restAnnouncements = 0
            } else {
                while setRepDates.count < reps { setRepDates.append(repDate(output)) }
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { setReps = reps }
            lastRepDate = Date()
            repPulse += 1
            haptic.impactOccurred()
            // Une note par répétition, un motif aux paliers de 5 et 10. La voix (si choisie) dit
            // les paliers et le premier nombre d'une série, qui signale que le comptage a démarré.
            announcer.play(Cue.forRep(reps))
            if started || reps % 5 == 0 { announcer.say("\(reps)") }
        }
        if state == .counting, output.state != .counting {
            closeSet(announce: true)
        }
        if state != output.state { state = output.state }
    }
}

extension WorkoutModel {
    /// Instant réel du mouvement de la répétition comptée (et non celui où elle est comptée,
    /// parfois plus tard : abdos dont le retour n'est pas vu).
    fileprivate func repDate(_ output: AutoCounter.Output) -> Date {
        Date().addingTimeInterval(-(output.repAge ?? 0))
    }
}

extension WorkoutModel.Phase {
    var isCountdown: Bool {
        if case .countdown = self { return true }
        return false
    }
}

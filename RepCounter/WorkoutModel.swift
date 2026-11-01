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
    /// La cible du plan pour cette série (nil sans plan).
    var target: Int? = nil
    /// Échauffement ou test (nil : série normale).
    var role: SetRole? = nil
}

/// Séance : prêt → mise en place (si elle se vérifie) → compte à rebours → séries et
/// récupérations automatiques → résumé.
final class WorkoutModel: ObservableObject {
    enum Phase: Equatable {
        case ready
        /// Le départ attend que l'iPhone et le sportif soient bien placés.
        case positioning
        case countdown(Int)
        case active
        case finished
    }

    /// Ampleur du mouvement capté (au repos, léger, assez net pour compter), pour le voyant.
    enum Presence { case absent, weak, clear }

    static let countdownSeconds = 5
    /// Après la mise en place, on est déjà en position : un compte à rebours court suffit.
    static let placedCountdownSeconds = 3
    /// Récupération marquée toutes les 15 s (un, deux, trois battements, puis un accord à la
    /// minute) ; la voix, si elle est choisie, dit la durée toutes les 30 s.
    private static let restAnnouncementInterval = 15

    let exercise: Exercise
    let live = LiveSignal()

    @Published private(set) var phase = Phase.ready
    /// Durée du compte à rebours en cours (s).
    @Published private(set) var countdownTotal = WorkoutModel.countdownSeconds
    /// Mise en place : consigne, vérifications, squelette vu par la caméra.
    @Published private(set) var placement = PlacementStatus()
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
    /// Accès à la caméra pas encore demandé : il l'est au premier « Démarrer », après la fiche
    /// qui explique pourquoi, pas à l'ouverture de l'app.
    private var cameraUndetermined = false
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

    /// La séance du jour, s'il y a un plan : les cibles, la baisse habituelle, et les séries déjà
    /// faites aujourd'hui dans des séances précédentes (séries espacées).
    struct PlanDay {
        let session: Prescription.Session
        let ratios: [Double]?
        let earlierToday: [Int]
        /// La cible affichée pour chaque série déjà faite aujourd'hui (réajustée en séance).
        var earlierTargets: [Int?] = []
    }

    /// Le plan du jour, fixé au départ de la séance (nil : pas de plan, ou jour de test).
    @Published var planDay: PlanDay?
    /// Repos prévu entre deux séries (s), fixé au départ de la séance : le compte à rebours sonore
    /// (3, 2, 1, puis l'accord du départ) s'y cale. Nil : pas de compte à rebours sonore (test).
    var plannedRest: Int?
    /// Dernier bip du compte à rebours joué pendant ce repos (3, 2, 1, 0).
    private var restCountdown = Int.max

    /// La cible de la série en cours (ou de la prochaine, pendant la récupération) : réajustée
    /// d'après la série précédente (`Prescription.nextTarget`). Nil sans plan, ou toutes les séries
    /// prévues faites.
    var currentTarget: Int? {
        // En mode test, aucune cible : on va au bout
        guard testStage == nil, let planDay else { return nil }
        let done = sets.map(\.reps)
        return Prescription.nextTarget(planDay.session, ratios: planDay.ratios,
                                       dayDone: planDay.earlierToday + done, sessionDone: done)
    }

    // MARK: Test annoncé (Science/METHODE-TEST.md)

    /// Les étapes d'une séance de test.
    enum TestStage: Equatable {
        /// Avant le départ : l'échauffement est proposé, on peut le passer.
        case warmupOffer
        /// La série d'échauffement (~⅓ du dernier max) : enregistrée, jamais comptée.
        case warmup
        /// Le repos de 2:00 après l'échauffement ; le test démarre au signal (ou dès la reprise).
        case warmupRest
        /// La série max, sans cible.
        case test
        /// Le résultat ; une 2e tentative est possible après 3:00 de repos.
        case result
    }

    /// Séance de test (lancée par la personne) : son étape ; nil pour une séance normale.
    @Published private(set) var testStage: TestStage?
    /// Le dernier max connu : il dose l'échauffement.
    private(set) var lastMax: Int?
    /// Fin de la dernière série d'échauffement ou de test : le repos se compte depuis elle.
    @Published private(set) var testRestStart: Date?
    /// Le résultat est affiché : le compteur ne compte plus jusqu'à une 2e tentative.
    private var countingPaused = false
    private var warmupSignaled = false

    /// Choix de l'app : 2:00 de repos après l'échauffement, 3:00 avant une 2e tentative (de Salles
    /// 2009 : 3 à 5 min permettent de refaire plus de répétitions), 2 tentatives au plus.
    static let warmupRest: TimeInterval = 120
    static let secondAttemptRest: TimeInterval = 180
    static let maxTestAttempts = 2

    var testAttempts: Int { sets.filter { $0.role == .test }.count }
    /// Le résultat : la meilleure série de test.
    var testBest: Int? { sets.filter { $0.role == .test && $0.reps > 0 }.map(\.reps).max() }
    /// L'échauffement conseillé : environ un tiers du dernier max (choix de l'app).
    var warmupReps: Int? { lastMax.map { Swift.max(1, Int((Double($0) / 3).rounded())) } }
    var testRestElapsed: TimeInterval { testRestStart.map { now.timeIntervalSince($0) } ?? 0 }
    var secondAttemptReady: Bool {
        testStage == .result && testAttempts < Self.maxTestAttempts && testRestElapsed >= Self.secondAttemptRest
    }

    /// « ◆ Lancer le test » : l'échauffement est proposé.
    func prepareTest(lastMax: Int?) {
        guard phase == .ready, exercise != .auto else { return }
        self.lastMax = lastMax
        planDay = nil
        testStage = .warmupOffer
    }

    /// Retour à la veille sans rien lancer.
    func cancelTest() {
        guard phase == .ready, testStage != nil else { return }
        testStage = nil
    }

    func startWarmup() {
        guard testStage == .warmupOffer else { return }
        testStage = .warmup
        beginSession()
    }

    /// « Passer · test direct ».
    func skipWarmup() {
        guard testStage == .warmupOffer else { return }
        testStage = .test
        beginSession()
    }

    /// « Lancer la 2e tentative », après 3:00 de repos.
    func startSecondAttempt() {
        guard secondAttemptReady else { return }
        resumeCounting()
        testStage = .test
        announcer.play(.go)
        AccessibilityNotification.Announcement("Deuxième tentative").post()
    }

    /// « Quitter le test ». La série en cours est abandonnée (la vue demande confirmation si elle a
    /// des répétitions). Une tentative déjà close n'est jamais perdue : la séance est enregistrée.
    /// Sans tentative, rien n'est enregistré et le test reste à faire.
    func quitTest() {
        guard testStage != nil else { return }
        setReps = 0
        setRepDates = []
        if testBest != nil {
            finishSession()
            return
        }
        countdownTimer?.invalidate()
        if isRecording { stopRecording() }
        sets = []
        setReps = 0
        setRepDates = []
        sessionStart = nil
        sessionEnd = nil
        lastRepDate = nil
        testRestStart = nil
        countingPaused = false
        testStage = nil
        state = .searching
        phase = .ready
        sensors.queue.async { self.counter.reset() }
        awaitingReset = true
    }

    private func resumeCounting() {
        sensors.queue.async { self.counter.reset() }
        awaitingReset = true
        counterTotal = 0
        setBase = 0
        countingPaused = false
        state = .searching
    }

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
    /// La séance se compte à la caméra (sinon aux capteurs de mouvement). Fixé à la création.
    let countsWithCamera: Bool
    /// Mise en place vérifiée avant le départ (nil : départ direct). Fixé à la création.
    let placementKind: PlacementKind?
    private let placementMonitor: PlacementMonitor?   // utilisé uniquement sur sensors.queue
    private let successHaptic = UINotificationFeedbackGenerator()
    /// Pendant le compte à rebours : depuis quand l'iPhone est manipulé.
    private var handledSince: Date?
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
        // Abdos : le gabarit de ton geste, appris au fil des séances précédentes
        counter = AutoCounter(exercise: exercise,
                              template: exercise.learnsGesture ? LearnedGesture.load(exercise).template : nil)
        countsWithCamera = !Set(counter.sources).isDisjoint(with: [.depth, .pixels, .face, .pose])
        placementKind = exercise.placementKind
        placementMonitor = placementKind.map { PlacementMonitor(kind: $0) }
        sensors = SensorHub(sources: Set(counter.sources))
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
            cameraUndetermined = true
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

    /// « Démarrer ». Si la mise en place se vérifie (pompes, abdos, exercices à la caméra), le
    /// départ attend qu'elle soit bonne, puis un compte à rebours court ; sinon, un compte à
    /// rebours de 5 s, le temps de se mettre en place.
    func beginSession() {
        guard phase == .ready else { return }
        if cameraUndetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.cameraUndetermined = false
                    guard granted else { return self.cameraDenied = true }
                    self.sensors.start()
                    self.beginSession()
                }
            }
            return
        }
        lightHaptic.impactOccurred()
        if placementKind != nil {
            placement = PlacementStatus()
            sensors.queue.async { self.placementMonitor?.reset() }
            phase = .positioning
        } else {
            startCountdown(Self.countdownSeconds)
        }
    }

    /// Compte à rebours : silencieux, puis une note à 3, 2 et 1, et l'accord du départ.
    private func startCountdown(_ seconds: Int) {
        var remaining = seconds
        countdownTotal = seconds
        phase = .countdown(remaining)
        if remaining <= 3 { announcer.play(.count) }
        countdownTimer?.invalidate()
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

    /// Annule le départ (mise en place ou compte à rebours).
    func cancelCountdown() {
        guard phase.isCountdown || phase == .positioning else { return }
        countdownTimer?.invalidate()
        // Un test annulé avant le départ : rien n'est lancé, la veille revient
        testStage = nil
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
        if testStage == .test { AccessibilityNotification.Announcement("Test commencé").post() }
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
        // Les répétitions de la séance enrichissent le gabarit (mémorisé pour les suivantes)
        let exercise = self.exercise
        sensors.queue.async {
            let learned = self.counter.takeLearned()
            DispatchQueue.main.async { LearnedGesture.remember(learned, for: exercise) }
        }
        sensors.stop()
        announcer.play(.finish)
        announcer.say(totalReps > 0 ? "Séance terminée. \(totalReps) répétitions." : "Séance terminée.")
    }

    /// Depuis le résumé : nouvelle séance, même exercice.
    func newSession() {
        guard phase == .finished else { return }
        testStage = nil
        testRestStart = nil
        countingPaused = false
        warmupSignaled = false
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
        let target = currentTarget
        // En mode test : l'échauffement à part, toute autre série est une tentative de test
        let role: SetRole? = testStage.map { $0 == .warmup ? .warmup : .test }
        sets.append(WorkoutSet(number: sets.count + 1, reps: reps, duration: duration, cadence: pace,
                               start: start, repTimes: repTimes, target: target, role: role))
        setBase = counterTotal
        setReps = 0
        setRepDates = []
        restAnnouncements = 0
        if announce {
            announcer.play(.setEnd)
            announcer.say(role == .test ? "Test : \(reps)." : "Série \(sets.count) : \(reps).")
        }
        switch testStage {
        case .warmup:
            // Le repos de 2:00 se remplit, puis le signal du test
            testRestStart = Date()
            warmupSignaled = false
            testStage = .warmupRest
        case .test, .warmupRest:
            // Le résultat : le compteur s'arrête jusqu'à une éventuelle 2e tentative
            testRestStart = Date()
            countingPaused = true
            testStage = .result
        default:
            break
        }
    }

    private func tick() {
        now = Date()
        if testStage == .warmupRest, !warmupSignaled, testRestElapsed >= Self.warmupRest {
            // Fin du repos d'échauffement : le signal du test
            warmupSignaled = true
            testStage = .test
            announcer.play(.go)
            haptic.impactOccurred()
            AccessibilityNotification.Announcement("Test commencé").post()
        }
        // Récupération marquée toutes les 15 s : on sait où on en est dans la minute sans
        // regarder l'écran
        guard isResting else { return }
        // Fin du repos prévu : 3, 2, 1 (une note courte), puis l'accord du départ, comme au
        // départ de la séance (avis de Vincent sur le cycle 3)
        let elapsed = Int(restDuration)
        if let planned = plannedRest, testStage == nil {
            let left = planned - elapsed
            if left >= 0, left <= 3, left < restCountdown {
                restCountdown = left
                announcer.play(left == 0 ? .go : .count)
                if left == 0 { lightHaptic.impactOccurred() }
            }
            // Les battements des 15 s se taisent pendant le compte à rebours
            if left >= 0, left <= 3 {
                restAnnouncements = elapsed / Self.restAnnouncementInterval
                return
            }
        }
        let marks = elapsed / Self.restAnnouncementInterval
        if marks > restAnnouncements {
            restAnnouncements = marks
            let cues: [Cue] = [.restMinute, .rest, .rest2, .rest3]
            announcer.play(cues[marks % 4])
            if marks % 2 == 0 { announcer.say(Self.spokenDuration(marks * Self.restAnnouncementInterval)) }
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
        let placement = placementMonitor?.process(frame)
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
        let index = frameIndex
        DispatchQueue.main.async {
            self.live.push(phase: output.phase, value: output.liveValue, strength: output.liveStrength)
            if let placement {
                if self.phase == .positioning {
                    self.applyPlacement(placement, frameIndex: index)
                } else if self.phase.isCountdown {
                    self.watchCountdown(placement)
                }
            }
            // Les propriétés suivantes ne sont publiées que quand elles changent
            if self.presence != presence { self.presence = presence }
            if output.source != nil, self.source != output.source { self.source = output.source }
            // Avant « Démarrer » et pendant le compte à rebours, rien ne compte
            guard self.phase == .active else { return }
            self.apply(output)
        }
    }

    // Fil principal, mise en place : publiée quand la consigne change, et 10 fois par seconde
    // pour le squelette ; tout est bon depuis un moment : le compte à rebours part
    private func applyPlacement(_ status: PlacementStatus, frameIndex: Int) {
        if status.ready {
            placement = status
            successHaptic.notificationOccurred(.success)
            startCountdown(Self.placedCountdownSeconds)
            return
        }
        let changed = status.instruction != placement.instruction || status.checks != placement.checks
        if changed || frameIndex % 3 == 0 { placement = status }
    }

    // Fil principal, compte à rebours après la mise en place : l'iPhone manipulé (pris en
    // main, en train de s'allonger) une demi-seconde, et la mise en place est à refaire. Sinon,
    // ces mouvements fausseraient le début du comptage.
    private func watchCountdown(_ status: PlacementStatus) {
        guard status.handled else { return handledSince = nil }
        let since = handledSince ?? Date()
        handledSince = since
        guard Date().timeIntervalSince(since) >= 0.5 else { return }
        handledSince = nil
        countdownTimer?.invalidate()
        placement = status
        sensors.queue.async { self.placementMonitor?.reset() }
        phase = .positioning
        lightHaptic.impactOccurred()
    }

    // Fil principal, séance en cours
    private func apply(_ output: AutoCounter.Output) {
        if awaitingReset {
            guard output.didReset else { return }
            awaitingReset = false
        }
        if countingPaused {
            // Résultat du test affiché : les mouvements ne comptent pas
            counterTotal = output.count
            setBase = output.count
            if tentative != 0 { tentative = 0 }
            return
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
                // Chaque répétition sonne dès la première, même avant la validation de la
                // série (à la 3e) : le rythme s'entend tout de suite. Pendant la récupération,
                // un mouvement isolé (respiration, se replacer) n'est pas une reprise : il ne
                // sonne qu'à partir de la 2e répétition de suite (il se superposait aux bips
                // de récupération)
                if !isResting || tentative >= 2 { announcer.play(.rep) }
            }
            self.tentative = tentative
        }

        if output.didCount {
            let reps = max(0, output.count - setBase)
            let started = state != .counting
            // Reprise pendant le repos d'échauffement : c'est le test qui commence
            if started, testStage == .warmupRest {
                testStage = .test
                warmupSignaled = true
                AccessibilityNotification.Announcement("Test commencé").post()
            }
            if started {
                // Nouvelle série : ses premières répétitions viennent d'être rattrapées ; leurs
                // instants sont reconstitués à la cadence mesurée
                let cadence = output.cadence ?? 2
                let last = repDate(output)
                let start = last.addingTimeInterval(-Double(max(reps - 1, 0)) * cadence)
                setStart = start
                setRepDates = (0..<reps).map { start.addingTimeInterval(Double($0) * cadence) }
                restAnnouncements = 0
                restCountdown = Int.max
            } else {
                while setRepDates.count < reps { setRepDates.append(repDate(output)) }
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { setReps = reps }
            lastRepDate = Date()
            repPulse += 1
            haptic.impactOccurred()
            // Une note par répétition, un motif aux paliers de 5 et 10, un accord aigu quand la
            // cible de la série est atteinte (on le sait sans regarder). La voix (si choisie) dit
            // les paliers et le premier nombre d'une série, qui signale que le comptage a démarré.
            let reachedTarget = currentTarget.map { reps == $0 } ?? false
            announcer.play(reachedTarget ? .target : Cue.forRep(reps))
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

// MARK: - Mode capture (CI)

extension WorkoutModel {
    /// Met l'écran dans un état à photographier, sans capteur : `serie` (17 répétitions de la
    /// série 2, cible 24), `repos` (45 s après la série 1), `fin` (séance de 3 séries terminée).
    /// Ne sert qu'au mode capture (`-captureDemo YES`, RepCounterApp.swift).
    func showCaptureState(_ name: String) {
        sensors.stop()
        clock?.invalidate()
        let start = Date().addingTimeInterval(-300)
        func set(_ number: Int, _ reps: Int, target: Int, at offset: TimeInterval) -> WorkoutSet {
            WorkoutSet(number: number, reps: reps, duration: Double(reps) * 1.6, cadence: 1.6,
                       start: start.addingTimeInterval(offset),
                       repTimes: (0..<reps).map { Double($0) * 1.6 }, target: target)
        }
        sessionStart = start
        now = Date()
        switch name {
        case "serie":
            phase = .active
            sets = [set(1, 28, target: 28, at: 0)]
            state = .counting
            setReps = 17
            lastRepDate = Date()
        case "repos":
            phase = .active
            sets = [set(1, 28, target: 28, at: 0)]
            state = .searching
            setReps = 0
            lastRepDate = Date().addingTimeInterval(-45)
        case "fin":
            phase = .active
            sets = [set(1, 28, target: 28, at: 0), set(2, 23, target: 24, at: 100), set(3, 18, target: 21, at: 160)]
            state = .searching
            setReps = 0
            lastRepDate = Date()
            sessionEnd = Date()
            phase = .finished
        default:
            break
        }
    }
}

import Foundation

/// Les signaux mesurés en continu. Le compteur suit celui qui bat le rythme le plus net.
enum SignalSource: String, CaseIterable {
    case depth    // TrueDepth : distance moyenne au centre de l'image + part de pixels mesurables
    case pixels   // image 12×16 en niveaux de gris
    case face     // rectangle du visage
    case pose     // squelette Vision
    case motion   // gravité dans le repère du téléphone (téléphone porté sur soi)
    case vertical // accélération verticale (téléphone tenu qui monte et descend : squats)
    case rotation // gyroscope : vitesse de rotation (petits gestes rapides : abdos)

    /// Nom court pour le tableau de bord.
    var code: String {
        switch self {
        case .depth: return "CAM 3D"
        case .pixels: return "IMAGE"
        case .face: return "VISAGE"
        case .pose: return "SQUELETTE"
        case .motion: return "INCLINAISON"
        case .vertical: return "ACCÉL. VERT."
        case .rotation: return "GYROSCOPE"
        }
    }

    var label: String {
        switch self {
        case .depth: return "Caméra 3D"
        case .pixels: return "Image"
        case .face: return "Visage"
        case .pose: return "Squelette"
        case .motion: return "Inclinaison du téléphone"
        case .vertical: return "Montée-descente du téléphone"
        case .rotation: return "Rotation du téléphone"
        }
    }

    /// Amplitude en dessous de laquelle on ignore le signal (mètres, luminance, g…).
    var minAmplitude: Float {
        switch self {
        case .depth: return 0.04
        case .pixels: return 0.05
        case .face: return 0.03
        case .pose: return 0.2
        case .motion: return 0.1
        case .vertical: return 0.08
        case .rotation: return 0.25   // rad/s ; une respiration ample reste sous 0,2
        }
    }
}

private enum Tuning {
    static let history = 16.0         // s d'historique (3 cycles lents de 4 s + marge)
    static let statsWindow = 6.0      // s pour les seuils adaptatifs (court : oublie vite une manipulation)
    static let pcaFrames = 120        // ~4 s pour l'ACP
    static let axisRefreshInterval = 10
    static let minPeriod = 0.4
    static let highThreshold: Float = 0.75
    static let lowThreshold: Float = 0.25
    /// Compter à l'autre extrême : on compte quand le signal en repart (5 % de son ampleur).
    static let turn: Float = 0.05
    static let minRegularity: Float = 0.6
    static let maxRoughness: Float = 0.12   // au-delà, signal trop saccadé : du bruit, pas un geste
    static let keptCycles = 30
    /// En série, un cycle plus faible que 40 % des précédents ne compte pas.
    static let weakCycleRatio: Float = 0.4
    /// En série, un cycle 40 % plus ample que les précédents, après une pause d'au moins 1,5 fois
    /// le rythme de la série : le téléphone qu'on reprend en fin de série. Il ne compte pas.
    static let strongCycleRatio: Float = 1.4
    static let pauseRatio = 1.5
    /// Une répétition après une pause attend ce délai (s) avant de compter : si le geste
    /// continue, bien plus ample, c'est le téléphone qu'on reprend.
    static let confirmDelay = 0.3
    /// Rotation (rad/s) au-delà de laquelle un téléphone censé être posé est manipulé.
    static let handlingRotation: Float = 0.5
}

/// État d'une source, pour l'écran de diagnostic.
struct SourceDiagnostic {
    var source: SignalSource
    var amplitude: Float
    var cycles: Int
    var regularity: Float
}

/// Suit une source : ACP glissante → signal 1D → cycles par hystérésis adaptative.
final class SignalTracker {
    let source: SignalSource
    private let maxPeriod: Double
    private(set) var cycles: [Double] = []
    /// Écart max − min du signal pendant chaque cycle.
    private(set) var cycleSwings: [Float] = []
    private(set) var phase: Float = 0
    /// Position du signal pour l'affichage (0…1), même sous le seuil : un petit mouvement
    /// donne une petite oscillation, un mouvement net une oscillation complète.
    private(set) var displayValue: Float = 0.5
    /// Amplitude rapportée au seuil : ≥ 1 quand le mouvement est assez net pour compter.
    var strength: Float { amplitude / source.minAmplitude }
    private(set) var amplitude: Float = 0
    /// Dernière note de régularité calculée (diagnostic).
    private(set) var lastRegularity: Float = 0

    private var times: [Double] = []
    private var rows: [[Float]] = []
    private var signal: [Float] = []
    private var axis: [Float]?
    private var frameIndex = 0
    // Un cycle se termine au retour à la position de repos, après être passé à l'autre
    // extrême. Par défaut le repos est le bas du signal ; au démarrage du comptage, on
    // regarde où était le signal juste avant la série (adoptRestPosition).
    private var restHigh = false
    /// Capteur de vitesse (gyroscope, accélération) : au repos, le signal est au milieu.
    private var restInMiddle = false
    private var armed = false
    private var armedSince = -Double.infinity
    /// Moment du comptage : au retour à la position de départ, ou à l'autre extrême
    /// (`Exercise.countsAtFarEnd`). À l'autre extrême, on compte quand le signal en repart :
    /// au sommet du geste (tractions : les jambes restent levées jusqu'en haut).
    private let countAtFar: Bool
    private var inCountZone = false
    private var zoneExtreme: Float = 0
    /// Instant où le geste de la dernière répétition comptée a atteint son extrême : l'instant
    /// réel du mouvement, même quand la répétition est comptée plus tard (retour non vu).
    private(set) var lastRepPeak = -Double.infinity
    private var skipNext = false
    private var ignoreBefore = -Double.infinity

    init(source: SignalSource, maxPeriod: Double, countAtFar: Bool = false) {
        self.source = source
        self.maxPeriod = maxPeriod
        self.countAtFar = countAtFar
    }

    /// Oublie les cycles passés (remise à zéro du compteur).
    /// Remise à zéro du compteur : oublie les cycles passés, et le sens de comptage adopté pour
    /// la série précédente (sinon une nouvelle séance hérite d'un sens qui ne lui correspond
    /// peut-être pas, et compte au mauvais moment du geste : tractions, 8 au lieu de 5).
    func forgetCycles(before t: Double) {
        cycles = []
        cycleSwings = []
        ignoreBefore = t
        restHigh = false
        restInMiddle = false
        armed = false
        inCountZone = false
        skipNext = false
    }

    /// Repart de zéro (téléphone manipulé : ce qui précède ne décrit pas l'exercice).
    func forgetHistory() {
        times = []
        rows = []
        signal = []
        cycles = []
        cycleSwings = []
        axis = nil
        armed = false
        skipNext = false
        amplitude = 0
    }

    /// Ajoute une mesure ; renvoie true quand un cycle complet vient de se terminer.
    func process(_ value: [Float], at t: Double) -> Bool {
        if let first = rows.first, first.count != value.count {
            rows = []
            times = []
            axis = nil
        }
        times.append(t)
        rows.append(value)
        let expired = times.prefix { $0 < t - Tuning.history }.count
        if expired > 0 {
            times.removeFirst(expired)
            rows.removeFirst(expired)
        }

        frameIndex += 1
        if value.count == 1 {
            axis = [1]
        } else if axis == nil || frameIndex % Tuning.axisRefreshInterval == 0,
                  let newAxis = principalAxis(rows.suffix(Tuning.pcaFrames), seed: axis) {
            axis = newAxis
        }
        guard let axis, rows.count >= 10 else { return false }

        signal = movingAverage(rows.map { innerProduct($0, axis) }, width: 5)
        let recentStart = times.firstIndex { $0 >= t - Tuning.statsWindow } ?? 0
        let recent = signal[recentStart...]
        let low = percentile(recent, 0.05)
        amplitude = percentile(recent, 0.95) - low
        let current = signal[signal.count - 1]
        let scale = max(amplitude, source.minAmplitude)
        displayValue = min(max(0.5 + (current - (low + amplitude / 2)) / scale, 0), 1)
        guard amplitude >= source.minAmplitude else {
            phase = 0
            return false
        }

        let n = (current - low) / amplitude
        phase = min(max(n, 0), 1)
        let atExtreme = restHigh ? n < Tuning.lowThreshold : n > Tuning.highThreshold
        let atRest = restHigh ? n > Tuning.highThreshold : n < Tuning.lowThreshold
        if !armed, atExtreme {
            armed = true
            armedSince = t
        } else if armed, !skipNext, restInMiddle, let period, !cycles.isEmpty, t - armedSince > 1.5 * period {
            // Capteur de vitesse : un retour lent au repos (ou pas de retour, en fin de série)
            // ne se voit pas. Le geste a eu lieu : on le compte ; son retour, s'il se voit
            // plus tard, ne comptera pas une seconde fois.
            skipNext = true
            lastRepPeak = armedSince
            recordCycle(at: t)
            return true
        } else if armed, atRest, countAtFar, !restInMiddle, !inCountZone {
            // Arrivé à l'autre extrême : on comptera en le quittant
            inCountZone = true
            zoneExtreme = n
        } else if armed, inCountZone, restHigh ? n > zoneExtreme : n < zoneExtreme {
            zoneExtreme = n   // l'extrême se creuse encore
        } else if armed, inCountZone ? abs(n - zoneExtreme) >= Tuning.turn : atRest {
            armed = false
            inCountZone = false
            if skipNext, !cycles.isEmpty {
                // Fin de la répétition déjà comptée : elle se termine maintenant, au retour au repos
                skipNext = false
                cycles[cycles.count - 1] = t
                return false
            }
            if let last = cycles.last, t - last < Tuning.minPeriod { return false }
            lastRepPeak = armedSince
            recordCycle(at: t)
            return true
        }
        return false
    }

    private func recordCycle(at t: Double) {
        let cycleStart = cycles.last ?? t - maxPeriod
        let startIndex = times.firstIndex { $0 > cycleStart } ?? 0
        let cycleSignal = signal[startIndex...]
        cycles.append(t)
        cycleSwings.append((cycleSignal.max() ?? 0) - (cycleSignal.min() ?? 0))
        if cycles.count > Tuning.keptCycles {
            cycles.removeFirst(cycles.count - Tuning.keptCycles)
            cycleSwings.removeFirst(cycleSwings.count - Tuning.keptCycles)
        }
    }

    /// Durée moyenne des deux derniers cycles.
    var period: Double? {
        guard cycles.count >= 3 else { return nil }
        let last = cycles.suffix(3)
        return (last[last.endIndex - 1] - last[last.startIndex]) / 2
    }

    /// Note de 0 à 1 : est-ce un rythme net ? 0 si ce n'est pas un vrai mouvement répétitif.
    func regularity(at t: Double) -> Float {
        lastRegularity = computeRegularity(at: t)
        return lastRegularity
    }

    private func computeRegularity(at t: Double) -> Float {
        guard cycles.count >= 3, amplitude > 0 else { return 0 }
        let last = Array(cycles.suffix(3))
        let p1 = last[1] - last[0], p2 = last[2] - last[1]
        guard min(p1, p2) >= Tuning.minPeriod, max(p1, p2) <= maxPeriod,
              max(p1, p2) / min(p1, p2) <= 1.5 else { return 0 }
        let period = (p1 + p2) / 2
        guard let first = times.first, let lastTime = times.last, times.count > 1,
              lastTime - first >= 1.8 * period else { return 0 }

        let frameDuration = (lastTime - first) / Double(times.count - 1)
        let lag = Int((period / frameDuration).rounded())
        let start = times.firstIndex { $0 >= t - 2.5 * period } ?? 0
        let segment = signal[start...]
        guard lag >= 2, segment.count > lag + 5 else { return 0 }

        // Le signal doit se ressembler à une période d'écart, s'opposer à une demi-période,
        // et être fluide : trois propriétés d'un geste répété que le bruit n'a pas
        let fullPeriod = lagCorrelation(segment, lag: lag)
        let halfPeriod = lagCorrelation(segment, lag: max(1, lag / 2))
        guard fullPeriod >= Tuning.minRegularity, halfPeriod <= -0.2,
              roughness(segment, amplitude: amplitude) <= Tuning.maxRoughness else { return 0 }
        return fullPeriod
    }

    /// Au démarrage du comptage : la position tenue juste avant la série est le repos.
    ///
    /// Les cycles détectés jusque-là se terminaient peut-être à l'autre extrême (le signe de
    /// l'ACP est arbitraire) : une pompe était alors comptée en bas, à mi-chemin. On bascule
    /// pour compter au retour au repos. Sans position tenue nette, ou si le repos est au
    /// milieu (capteur de vitesse : gyroscope, accélération), on garde le sens actuel.
    /// - Parameter seriesStart: premier cycle de la série ; elle commence au plus une période avant.
    /// Gyroscope : renvoie les répétitions de la série, recomptées (voir `lobeReps`) ; sinon nil.
    @discardableResult
    func adoptRestPosition(seriesStart: Double) -> Int? {
        if source == .rotation { return lobeReps(seriesStart: seriesStart) }
        guard let period, cycles.count >= 3 else { return nil }
        let before = seriesStart - period
        let held = signal.indices.filter { times[$0] >= before - 1.0 && times[$0] <= before - 0.1 }.map { signal[$0] }
        guard let regularStart = times.firstIndex(where: { $0 >= cycles[cycles.count - 3] - period }) else { return nil }
        let regular = signal[regularStart...]
        let low = percentile(regular, 0.05)
        let regularAmplitude = percentile(regular, 0.95) - low
        guard held.count >= 5, regularAmplitude > 0,
              standardDeviation(held) <= 0.25 * regularAmplitude else { return nil }
        let level = (median(held[...]) - low) / regularAmplitude
        guard level < 0.3 || level > 0.7 else {
            // Repos au milieu (capteur de vitesse : accélération) : pas d'extrême
            restInMiddle = true
            return nil
        }
        // Compter à l'autre extrême : c'est lui qui joue le rôle du « repos » du comptage
        let newRestHigh = (level > 0.7) != countAtFar
        if newRestHigh != restHigh {
            restHigh = newRestHigh
            // On est à l'extrême où l'on vient de compter, qui devient celui où l'on arme.
            // Compter au retour au départ : la répétition en cours a été comptée à mi-chemin,
            // son retour ne doit pas compter une seconde fois. Compter à l'autre extrême : la
            // répétition est finie, le prochain passage à l'autre extrême est la suivante.
            armed = true
            inCountZone = false
            skipNext = !countAtFar
        }
        return nil
    }

    /// Gyroscope (vitesse de rotation) : chaque répétition fait deux bosses, l'aller puis le
    /// retour, séparées des répétitions voisines par un court repos. La bosse qui suit ce repos
    /// ouvre la répétition ; on arme à elle et on compte à la seconde : la répétition est
    /// comptée finie, toujours au même moment de la série (sinon, selon le démarrage, on
    /// comptait à l'aller, et la dernière comptait deux fois). Renvoie les répétitions de la
    /// série, recomptées ainsi depuis son début.
    func lobeReps(seriesStart: Double) -> Int? {
        guard let period, cycles.count >= 3,
              let regularStart = times.firstIndex(where: { $0 >= cycles[cycles.count - 3] - period }) else { return nil }
        let regular = signal[regularStart...]
        let low = percentile(regular, 0.05)
        let amplitude = percentile(regular, 0.95) - low
        guard amplitude > 0 else { return nil }
        // Les bosses : intervalles au-delà des seuils, avec leur sens, leur début et leur fin
        struct Lobe { let low: Bool; let start: Double; var end: Double? }
        var lobes: [Lobe] = []
        for i in times.indices where times[i] >= seriesStart - period {
            let v = (signal[i] - low) / amplitude
            let kind: Bool? = v < Tuning.lowThreshold ? true : (v > Tuning.highThreshold ? false : nil)
            if let kind {
                if let last = lobes.last, last.low == kind, last.end == nil { continue }
                lobes.append(Lobe(low: kind, start: times[i], end: nil))
            } else if let last = lobes.last, last.end == nil {
                lobes[lobes.count - 1].end = times[i]
            }
        }
        guard lobes.count >= 4 else { return nil }
        // La bosse qui ouvre une répétition : celle précédée du plus long repos
        var gapsLow: [Float] = [], gapsHigh: [Float] = []
        for (previous, lobe) in zip(lobes, lobes.dropFirst()) {
            guard let end = previous.end else { continue }
            if lobe.low { gapsLow.append(Float(lobe.start - end)) } else { gapsHigh.append(Float(lobe.start - end)) }
        }
        guard !gapsLow.isEmpty, !gapsHigh.isEmpty else { return nil }
        let firstLow = median(gapsLow[...]) > median(gapsHigh[...])
        var reps = 0, inRep = false
        var lastEnd: Double?
        for lobe in lobes {
            if lobe.low == firstLow {
                inRep = true
            } else if inRep {
                reps += 1
                inRep = false
                lastEnd = lobe.start
            }
        }
        restInMiddle = true
        restHigh = firstLow   // armer à la bosse d'ouverture, compter à la seconde
        armed = inRep
        if inRep, let last = lobes.last { armedSince = last.start }
        skipNext = false
        // Le dernier cycle se termine à la dernière seconde bosse (pas à celle où le comptage
        // vient de démarrer) : la suivante n'est pas prise pour un rebond
        if let lastEnd, !cycles.isEmpty { cycles[cycles.count - 1] = lastEnd }
        return reps
    }

    /// Ampleur du signal (max − min) depuis l'instant `start`.
    func swing(since start: Double) -> Float {
        let values = signal.indices.filter { times[$0] > start }.map { signal[$0] }
        guard let high = values.max(), let low = values.min() else { return 0 }
        return high - low
    }

    /// Répétitions faites avant que la série soit jugée régulière.
    ///
    /// Pendant la mise en place, l'axe de l'ACP et les seuils n'étaient pas encore justes :
    /// les premières répétitions ont pu être mal découpées ou manquées. On relit tout
    /// l'historique avec l'axe et les seuils de la série régulière, et on remonte les cycles
    /// qui lui ressemblent : même rythme, ampleur comparable (ni moitié moins, ni presque le
    /// double), tracé fluide. On s'arrête au premier qui ne ressemble pas (pause, secousses).
    /// Renvoie le nombre de cycles repris et l'instant du premier cycle de la série.
    func cyclesBeforeRegularRun() -> (count: Int, seriesStart: Double) {
        guard let period, cycles.count >= 3 else { return (0, cycles.last ?? 0) }
        let runStart = cycles[cycles.count - 3]
        guard let regularStart = times.firstIndex(where: { $0 >= runStart - period }) else { return (0, runStart) }
        let regular = signal[regularStart...]
        let low = percentile(regular, 0.05)
        let regularAmplitude = percentile(regular, 0.95) - low
        guard regularAmplitude > 0 else { return (0, runStart) }

        var events: [(time: Double, swing: Float, roughness: Float)] = []
        var high = false
        var previous = ignoreBefore
        for i in signal.indices {
            let time = times[i]
            guard time < runStart - 0.5 * period else { break }
            guard time >= ignoreBefore else { continue }
            let n = (signal[i] - low) / regularAmplitude
            if !high, n > Tuning.highThreshold {
                high = true
            } else if high, n < Tuning.lowThreshold {
                high = false
                // Le cycle : depuis le précédent, au plus 1,5 période (pas toute l'installation)
                let cycleStart = max(previous, time - 1.5 * period)
                let startIndex = times.firstIndex { $0 >= cycleStart } ?? i
                let cycle = signal[startIndex...i]
                events.append((time, (cycle.max() ?? 0) - (cycle.min() ?? 0),
                               roughness(cycle, amplitude: regularAmplitude)))
                previous = time
            }
        }

        var count = 0
        var next = runStart
        for event in events.reversed() {
            let gap = next - event.time
            guard gap >= 0.6 * period, gap <= 1.6 * period,
                  event.swing >= 0.5 * regularAmplitude, event.swing <= 1.8 * regularAmplitude,
                  event.roughness <= Tuning.maxRoughness else { break }
            count += 1
            next = event.time
        }
        return (count, next)
    }

    /// Cycles récents qui s'enchaînent (écart ≤ période max), postérieurs à `after` :
    /// des répétitions probablement en cours, pas encore validées.
    func recentChain(at t: Double, after: Double) -> Int {
        guard let last = cycles.last, last > after, t - last <= maxPeriod else { return 0 }
        var chain = 1
        var i = cycles.count - 1
        while i > 0, cycles[i] - cycles[i - 1] <= maxPeriod, cycles[i - 1] > after {
            chain += 1
            i -= 1
        }
        return chain
    }

    var diagnostic: SourceDiagnostic {
        SourceDiagnostic(source: source, amplitude: amplitude, cycles: cycles.count, regularity: lastRegularity)
    }
}

/// Compteur automatique : les sources de l'exercice sont suivies en parallèle ; dès que l'une
/// montre 3 cycles réguliers, elle devient la référence et le compteur s'affiche
/// (avec les répétitions faites avant, retrouvées dans son historique).
/// Utilisé uniquement sur la file des capteurs.
final class AutoCounter {
    enum State { case searching, counting, resting }

    struct Output {
        var count: Int
        var phase: Float
        var didCount: Bool
        var state: State
        var source: SignalSource?
        var diagnostics: [SourceDiagnostic]
        /// Pour l'affichage en direct : position du signal suivi (0…1) et netteté du
        /// mouvement (amplitude / seuil, ≥ 1 : assez net pour compter).
        var liveValue: Float
        var liveStrength: Float
        /// Première mesure après une remise à zéro (marquée dans les enregistrements).
        var didReset: Bool
        /// Durée d'une répétition (s) et régularité du signal suivi, pendant le comptage.
        var cadence: Double?
        var regularity: Float
        /// Avant le démarrage du comptage : répétitions déjà détectées mais pas encore
        /// validées (0 à cyclesToLock − 1), pour montrer que l'app suit le mouvement.
        var tentative: Int
        /// Répétition comptée : il y a combien de secondes son mouvement a eu lieu.
        var repAge: Double?
    }

    /// Cycles réguliers exigés pour démarrer le comptage d'une série.
    static let cyclesToLock = 3

    let exercise: Exercise
    /// Capteurs écoutés, figés pour la séance (ils dépendent d'un réglage).
    let sources: [SignalSource]
    private var trackers: [SignalSource: SignalTracker] = [:]
    private var leader: SignalSource?
    private var count = 0
    private var lastCountTime = -Double.infinity
    private var lastFrameTime = 0.0
    private var resetPending = false
    /// Ampleur des répétitions de la série en cours.
    private var setSwings: [Float] = []
    /// Instants où elles ont été comptées.
    private var setTimes: [Double] = []
    private var weakCycles = 0
    /// Répétition après une pause, en attente de confirmation (instant où elle s'est terminée).
    private var pending: Double?
    /// Gabarit personnel (abdos) : reconnaît une répétition seule, hors série régulière.
    private let template: GestureTemplate?
    /// Gyroscope brut des 4 dernières secondes (pour le gabarit).
    private var rawTimes: [Double] = []
    private var rawRows: [[Float]] = []
    /// Répétitions comptées par le gabarit.
    private var templateTimes: [Double] = []
    private var lastTemplateCheck = -Double.infinity
    /// Répétitions comptées en série régulière : leur forme enrichira le gabarit.
    private var learned: [GestureSample] = []

    init(exercise: Exercise, template: GestureTemplate? = nil) {
        self.exercise = exercise
        sources = exercise.sources
        self.template = exercise.learnsGesture ? template : nil
    }

    /// Les répétitions apprises depuis le dernier appel (à mémoriser en fin de séance).
    func takeLearned() -> [GestureSample] {
        defer { learned = [] }
        return learned
    }

    /// Rythme de la série : intervalle médian entre ses dernières répétitions comptées.
    private var setRhythm: Double? {
        let recent = Array(setTimes.suffix(6))
        guard recent.count >= 2 else { return nil }
        let intervals = zip(recent.dropFirst(), recent).map { Float($0 - $1) }
        return Double(median(intervals[...]))
    }

    /// Remise à zéro : démarrage d'une séance (fin du compte à rebours) ou série annulée.
    /// Ce qui précède est ignoré : le compteur ne retient que les cycles postérieurs.
    func reset() {
        count = 0
        leader = nil
        lastCountTime = -.infinity
        pending = nil
        templateTimes = []
        resetPending = true
        for tracker in trackers.values { tracker.forgetCycles(before: lastFrameTime) }
    }

    func process(_ frame: SensorFrame) -> Output {
        let t = frame.time
        lastFrameTime = t
        let didReset = resetPending
        resetPending = false
        // Téléphone censé être posé (pompes) : s'il est manipulé, ce qui précède ne décrit
        // pas l'exercice, on repart de zéro une fois qu'il est reposé
        if exercise.phoneAtRest, let rotation = frame.values[.rotation],
           innerProduct(rotation, rotation).squareRoot() > Tuning.handlingRotation {
            for tracker in trackers.values { tracker.forgetHistory() }
        }
        if exercise.learnsGesture, let rotation = frame.values[.rotation], rotation.count == 3 {
            rawTimes.append(t)
            rawRows.append(rotation)
            let expired = rawTimes.prefix { $0 < t - 4 }.count
            if expired > 0 {
                rawTimes.removeFirst(expired)
                rawRows.removeFirst(expired)
            }
        }
        var completed = Set<SignalSource>()
        for (source, value) in frame.values where sources.contains(source) {
            // L'accélération verticale compte toujours à son creux : au sommet du geste
            let tracker = trackers[source] ?? SignalTracker(source: source, maxPeriod: exercise.maxPeriod,
                                                            countAtFar: exercise.countsAtFarEnd && source != .vertical)
            trackers[source] = tracker
            if tracker.process(value, at: t) { completed.insert(source) }
        }

        var didCount = false
        var countedByTemplate = false
        if let leader, let tracker = trackers[leader] {
            var stillLeading = true
            if let pending, t - pending >= Tuning.confirmDelay {
                // Répétition après une pause, en attente : le geste a-t-il continué, bien plus
                // ample que les répétitions de la série ? C'est le téléphone qu'on reprend.
                self.pending = nil
                let cycles = tracker.cycles
                let swing = tracker.swing(since: cycles.count >= 2 ? cycles[cycles.count - 2] : pending - 2)
                let usual = median(setSwings.suffix(5))
                if swing > Tuning.strongCycleRatio * usual {
                    self.leader = nil
                    stillLeading = false
                } else {
                    count += 1
                    lastCountTime = pending
                    didCount = true
                    setSwings.append(min(swing, usual))
                    setTimes.append(pending)
                    weakCycles = 0
                }
            }
            if stillLeading, completed.contains(leader), let swing = tracker.cycleSwings.last {
                // Un cycle bien plus ample, après une pause : le téléphone qu'on reprend en fin
                // de série. Il ne compte pas, la série est finie.
                // Un cycle bien plus faible que les répétitions de la série (essoufflement,
                // téléphone qu'on repose…) ne compte pas ; deux de suite : fin de série
                let usual = median(setSwings.suffix(5))
                let rhythm = setRhythm ?? tracker.period
                let afterPause = rhythm.map { t - lastCountTime > Tuning.pauseRatio * $0 } ?? false
                if swing > Tuning.strongCycleRatio * usual, afterPause {
                    self.leader = nil
                } else if swing >= Tuning.weakCycleRatio * usual, afterPause {
                    // Après une pause : on attend un instant avant de compter
                    pending = t
                } else if swing >= Tuning.weakCycleRatio * usual {
                    count += 1
                    learnRep(at: t)
                    lastCountTime = t
                    didCount = true
                    setSwings.append(swing)
                    setTimes.append(t)
                    weakCycles = 0
                } else {
                    weakCycles += 1
                }
            }
            // Plus de cycle franc depuis un moment : fin de série, on cherchera à nouveau
            if stillLeading, pending == nil,
               weakCycles >= 2 || t - lastCountTime > max(4, 3 * (tracker.period ?? 2)) { self.leader = nil }
        } else {
            if recognize(frame, at: t) {
                didCount = true
                countedByTemplate = true
            }
            if let best = bestRegularSource(among: completed, at: t), let tracker = trackers[best] {
                // Les 3 cycles réguliers comptent, plus ceux faits avant
                leader = best
                pending = nil
                countedByTemplate = false
                let earlier = tracker.cyclesBeforeRegularRun()
                // Répétitions de cette série déjà comptées par le gabarit : remplacées par le recompte
                let seriesFrom = earlier.seriesStart - (tracker.period ?? 0)
                let byTemplate = templateTimes.filter { $0 >= seriesFrom }.count
                let base = count - byTemplate
                count = base + Self.cyclesToLock + earlier.count
                // Gyroscope : les répétitions de la série recomptées à la seconde bosse
                if let reps = tracker.adoptRestPosition(seriesStart: earlier.seriesStart) {
                    count = base + reps
                }
                count = max(count, base + byTemplate)
                lastCountTime = t
                didCount = true
                setSwings = Array(tracker.cycleSwings.suffix(Self.cyclesToLock))
                setTimes = [t]
                weakCycles = 0
            }
        }

        // Une série comptée par le gabarit dure tant que ses répétitions se suivent
        let templateSet = template.map { tpl in templateTimes.last.map { t - $0 < max(4, 3 * tpl.duration) } ?? false } ?? false
        let state: State = leader != nil || templateSet ? .counting : (count == 0 ? .searching : .resting)
        let phase = leader.flatMap { trackers[$0]?.phase } ?? 0
        let diagnostics = sources.compactMap { trackers[$0]?.diagnostic }
        // Signal affiché : la source qui compte, sinon celle qui bouge le plus
        let shown = leader.flatMap { trackers[$0] }
            ?? sources.compactMap { trackers[$0] }.max { $0.strength < $1.strength }
        return Output(count: count, phase: phase, didCount: didCount, state: state, source: leader,
                      diagnostics: diagnostics,
                      liveValue: shown?.displayValue ?? 0.5, liveStrength: shown?.strength ?? 0,
                      didReset: didReset,
                      cadence: leader.flatMap { trackers[$0]?.period },
                      regularity: leader.flatMap { trackers[$0]?.lastRegularity } ?? 0,
                      tentative: tentative(at: t),
                      repAge: didCount ? (countedByTemplate ? 0 : leader.flatMap { trackers[$0] }.map { max(0, t - $0.lastRepPeak) }) : nil)
    }

    /// Hors série régulière : une répétition reconnue par le gabarit compte tout de suite.
    private func recognize(_ frame: SensorFrame, at t: Double) -> Bool {
        guard let template, !rawTimes.isEmpty, t - lastTemplateCheck >= 1.0 / 15 else { return false }
        lastTemplateCheck = t
        // Abdos : l'iPhone reste à plat sur la poitrine
        if let gravity = frame.values[.motion], gravity.count == 3, abs(gravity[2]) < 0.6 { return false }
        let last = max(lastCountTime, templateTimes.last ?? -.infinity)
        guard t - last >= 0.6 * template.duration,
              template.score(times: rawTimes, rows: rawRows, now: t) >= GestureTemplate.match else { return false }
        count += 1
        templateTimes.append(t)
        return true
    }

    /// Répétition comptée en série régulière : sa forme enrichit le gabarit.
    private func learnRep(at t: Double) {
        guard exercise.learnsGesture, setTimes.count >= 2, rawTimes.count >= 10 else { return }
        let recent = Array(setTimes.suffix(6)) + [t]
        let intervals = zip(recent.dropFirst(), recent).map { Float($0 - $1) }
        let duration = Double(median(intervals[...]))
        guard let first = rawTimes.first, t - duration >= first else { return }
        let sample = GestureTemplate.resample(times: rawTimes, rows: rawRows, from: t - duration, to: t)
        learned.append(GestureSample(shape: sample.shape, norm: sample.norm, duration: duration))
    }

    private func tentative(at t: Double) -> Int {
        guard leader == nil else { return 0 }
        let chains = sources.compactMap { trackers[$0] }
            .filter { $0.strength >= 1 }
            .map { $0.recentChain(at: t, after: lastCountTime) }
        return min(chains.max() ?? 0, Self.cyclesToLock - 1)
    }

    private func bestRegularSource(among sources: Set<SignalSource>, at t: Double) -> SignalSource? {
        var best: (source: SignalSource, score: Float)?
        for source in self.sources where sources.contains(source) {
            guard let score = trackers[source]?.regularity(at: t), score >= Tuning.minRegularity else { continue }
            // Scores arrondis : à 0,1 près, l'ordre de préférence départage
            if best == nil || (score * 10).rounded() > (best!.score * 10).rounded() {
                best = (source, score)
            }
        }
        return best?.source
    }
}

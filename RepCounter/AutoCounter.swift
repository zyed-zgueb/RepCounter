import Foundation

/// Les signaux mesurés en continu. Le compteur suit celui qui bat le rythme le plus net.
enum SignalSource: String, CaseIterable {
    case depth    // TrueDepth : distance moyenne au centre de l'image + part de pixels mesurables
    case pixels   // image 12×16 en niveaux de gris
    case face     // rectangle du visage
    case pose     // squelette Vision
    case motion   // gravité dans le repère du téléphone (téléphone porté sur soi)
    case vertical // accélération verticale (téléphone tenu qui monte et descend : squats)

    var label: String {
        switch self {
        case .depth: return "Caméra 3D"
        case .pixels: return "Image"
        case .face: return "Visage"
        case .pose: return "Squelette"
        case .motion: return "Inclinaison du téléphone"
        case .vertical: return "Montée-descente du téléphone"
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
        }
    }

    /// À régularité égale, on préfère les mesures les plus directes du mouvement.
    static let preference: [SignalSource] = [.depth, .motion, .vertical, .pose, .face, .pixels]
}

private enum Tuning {
    static let history = 16.0         // s d'historique (3 cycles lents de 4 s + marge)
    static let statsWindow = 10.0     // s pour les seuils adaptatifs
    static let pcaFrames = 120        // ~4 s pour l'ACP
    static let axisRefreshInterval = 10
    static let minPeriod = 0.4
    static let maxPeriod = 6.0
    static let highThreshold: Float = 0.75
    static let lowThreshold: Float = 0.25
    static let minRegularity: Float = 0.6
    static let maxRoughness: Float = 0.12   // au-delà, signal trop saccadé : du bruit, pas un geste
    static let keptCycles = 30
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
    private(set) var cycles: [Double] = []
    private(set) var phase: Float = 0
    private(set) var amplitude: Float = 0
    /// Dernière note de régularité calculée (diagnostic).
    private(set) var lastRegularity: Float = 0

    /// Amplitude du signal au moment de chaque cycle.
    private var cycleAmplitudes: [Float] = []
    private var times: [Double] = []
    private var rows: [[Float]] = []
    private var signal: [Float] = []
    private var axis: [Float]?
    private var frameIndex = 0
    private var isHigh = false
    private var ignoreBefore = -Double.infinity

    init(source: SignalSource) {
        self.source = source
    }

    /// Oublie les cycles passés (remise à zéro du compteur).
    func forgetCycles(before t: Double) {
        cycles = []
        cycleAmplitudes = []
        ignoreBefore = t
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
        guard amplitude >= source.minAmplitude else {
            phase = 0
            return false
        }

        let n = (signal[signal.count - 1] - low) / amplitude
        phase = min(max(n, 0), 1)
        if !isHigh, n > Tuning.highThreshold {
            isHigh = true
        } else if isHigh, n < Tuning.lowThreshold {
            isHigh = false
            if let last = cycles.last, t - last < Tuning.minPeriod { return false }
            cycles.append(t)
            cycleAmplitudes.append(amplitude)
            if cycles.count > Tuning.keptCycles {
                cycles.removeFirst(cycles.count - Tuning.keptCycles)
                cycleAmplitudes.removeFirst(cycleAmplitudes.count - Tuning.keptCycles)
            }
            return true
        }
        return false
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
        guard min(p1, p2) >= Tuning.minPeriod, max(p1, p2) <= Tuning.maxPeriod,
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

    /// Cycles faits avant que la série soit jugée régulière : ceux déjà détectés qui
    /// s'enchaînent au même rythme avec une amplitude comparable (le rythme d'un humain
    /// varie, la note de régularité peut tarder), puis ceux manqués pendant la mise en
    /// place, quand le téléphone manipulé faussait encore les seuils.
    func missedCyclesBeforeRegularRun() -> Int {
        guard let period, cycles.count >= 3 else { return 0 }
        var chainStart = cycles.count - 3
        while chainStart > 0 {
            let gap = cycles[chainStart] - cycles[chainStart - 1]
            guard gap >= 0.7 * period, gap <= 1.4 * period,
                  cycleAmplitudes[chainStart - 1] >= 0.5 * amplitude else { break }
            chainStart -= 1
        }
        let detected = cycles.count - 3 - chainStart

        let runStart = cycles[chainStart]
        let start = max(runStart - 1.3 * period, ignoreBefore)
        guard let startIndex = times.firstIndex(where: { $0 >= start }) else { return detected }
        let segment = signal[startIndex...]
        let low = percentile(segment, 0.05)
        let range = percentile(segment, 0.95) - low
        guard range > 0 else { return detected }

        var high = false
        var missed = 0
        for i in segment.indices {
            let n = (signal[i] - low) / range
            if !high, n > Tuning.highThreshold {
                high = true
            } else if high, n < Tuning.lowThreshold {
                high = false
                if times[i] < runStart - 0.5 * period { missed += 1 }
            }
        }
        return detected + missed
    }

    var diagnostic: SourceDiagnostic {
        SourceDiagnostic(source: source, amplitude: amplitude, cycles: cycles.count, regularity: lastRegularity)
    }
}

/// Compteur automatique : toutes les sources sont suivies en parallèle ; dès que l'une
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
    }

    private var trackers: [SignalSource: SignalTracker] = [:]
    private var leader: SignalSource?
    private var count = 0
    private var lastCountTime = -Double.infinity
    private var lastFrameTime = 0.0

    func reset() {
        count = 0
        leader = nil
        lastCountTime = -.infinity
        for tracker in trackers.values { tracker.forgetCycles(before: lastFrameTime) }
    }

    func process(_ frame: SensorFrame) -> Output {
        let t = frame.time
        lastFrameTime = t
        var completed = Set<SignalSource>()
        for (source, value) in frame.values {
            let tracker = trackers[source] ?? SignalTracker(source: source)
            trackers[source] = tracker
            if tracker.process(value, at: t) { completed.insert(source) }
        }

        var didCount = false
        if let leader, let tracker = trackers[leader] {
            if completed.contains(leader) {
                count += 1
                lastCountTime = t
                didCount = true
            }
            // Plus de cycle depuis un moment : fin de série, on cherchera à nouveau
            if t - lastCountTime > max(4, 3 * (tracker.period ?? 2)) { self.leader = nil }
        } else if let best = bestRegularSource(among: completed, at: t), let tracker = trackers[best] {
            // Les 3 cycles réguliers comptent, plus ceux faits avant
            leader = best
            count += 3 + tracker.missedCyclesBeforeRegularRun()
            lastCountTime = t
            didCount = true
        }

        let state: State = leader != nil ? .counting : (count == 0 ? .searching : .resting)
        let phase = leader.flatMap { trackers[$0]?.phase } ?? 0
        let diagnostics = SignalSource.preference.compactMap { trackers[$0]?.diagnostic }
        return Output(count: count, phase: phase, didCount: didCount, state: state, source: leader,
                      diagnostics: diagnostics)
    }

    private func bestRegularSource(among sources: Set<SignalSource>, at t: Double) -> SignalSource? {
        var best: (source: SignalSource, score: Float)?
        for source in SignalSource.preference where sources.contains(source) {
            guard let score = trackers[source]?.regularity(at: t), score >= Tuning.minRegularity else { continue }
            // Scores arrondis : à 0,1 près, l'ordre de préférence départage
            if best == nil || (score * 10).rounded() > (best!.score * 10).rounded() {
                best = (source, score)
            }
        }
        return best?.source
    }
}

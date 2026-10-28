import Foundation

/// Gabarit personnel d'un geste : la forme moyenne d'une répétition sur les 3 axes du
/// gyroscope (rééchantillonnée, centrée, de norme 1), son ampleur et sa durée. Appris en
/// silence sur les répétitions comptées en série régulière ; sert à reconnaître une répétition
/// seule, quel que soit le rythme (séries irrégulières, premières répétitions).
/// Même calcul que `GestureTemplate` dans Simulation/simulate_counter.py.
struct GestureTemplate {
    /// Points d'un geste rééchantillonné.
    static let samples = 32
    /// Ressemblance (cosinus) au-delà de laquelle le geste est reconnu.
    static let match: Float = 0.8
    static let scales = [0.75, 1.0, 1.3]
    /// Répétitions apprises avant de servir.
    static let minReps = 10
    /// Ampleur et durée : médianes des 100 dernières répétitions apprises.
    static let recent = 100

    /// Forme : `samples` × 3 axes, centrée, de norme 1.
    let shape: [Float]
    let norm: Float
    let duration: Double

    /// Le geste entre `start` et `end`, rééchantillonné (interpolation linéaire), centré et
    /// ramené à une norme de 1 ; et son ampleur (la norme avant).
    static func resample(times: [Double], rows: [[Float]], from start: Double, to end: Double) -> (shape: [Float], norm: Float) {
        var shape = [Float](repeating: 0, count: samples * 3)
        guard let first = times.first, let last = times.last else { return (shape, 0) }
        var j = 0
        for i in 0..<samples {
            let x = start + (end - start) * Double(i) / Double(samples - 1)
            let row: [Float]
            if x <= first {
                row = rows[0]
            } else if x >= last {
                row = rows[rows.count - 1]
            } else {
                while j + 1 < times.count, times[j + 1] < x { j += 1 }
                let k = Float((x - times[j]) / max(times[j + 1] - times[j], 1e-9))
                row = (0..<3).map { rows[j][$0] + (rows[j + 1][$0] - rows[j][$0]) * k }
            }
            for axis in 0..<3 { shape[i * 3 + axis] = row[axis] }
        }
        for axis in 0..<3 {
            let mean = stride(from: axis, to: shape.count, by: 3).map { shape[$0] }.reduce(0, +) / Float(samples)
            for i in stride(from: axis, to: shape.count, by: 3) { shape[i] -= mean }
        }
        let norm = innerProduct(shape, shape).squareRoot()
        if norm > 0 { shape = shape.map { $0 / norm } }
        return (shape, norm)
    }

    /// Ressemblance du geste qui vient de finir (0 si son ampleur ne correspond pas).
    func score(times: [Double], rows: [[Float]], now: Double) -> Float {
        var best: Float = 0
        for scale in Self.scales {
            let start = now - duration * scale
            guard let first = times.first, start >= first else { continue }
            let candidate = Self.resample(times: times, rows: rows, from: start, to: now)
            guard candidate.norm >= 0.5 * norm, candidate.norm <= 2 * norm else { continue }
            best = max(best, innerProduct(candidate.shape, shape))
        }
        return best
    }
}

/// Une répétition apprise : sa forme, son ampleur, sa durée.
struct GestureSample {
    let shape: [Float]
    let norm: Float
    let duration: Double
}

/// Ce que l'app a appris du geste d'un exercice, au fil des séances, sur cet iPhone : la somme
/// des formes (leur moyenne fait le gabarit) et les ampleurs et durées récentes.
struct LearnedGesture: Codable {
    var shapeSum: [Float] = []
    var count = 0
    var norms: [Float] = []
    var durations: [Double] = []

    /// Le gabarit, une fois assez de répétitions apprises.
    var template: GestureTemplate? {
        guard count >= GestureTemplate.minReps, !shapeSum.isEmpty else { return nil }
        let length = innerProduct(shapeSum, shapeSum).squareRoot()
        guard length > 0 else { return nil }
        return GestureTemplate(shape: shapeSum.map { $0 / length },
                               norm: median(norms[...]),
                               duration: Double(median(durations.map { Float($0) }[...])))
    }

    mutating func add(_ samples: [GestureSample]) {
        for sample in samples {
            if shapeSum.isEmpty { shapeSum = [Float](repeating: 0, count: sample.shape.count) }
            guard sample.shape.count == shapeSum.count else { continue }
            for i in shapeSum.indices { shapeSum[i] += sample.shape[i] }
            count += 1
            norms.append(sample.norm)
            durations.append(sample.duration)
        }
        norms = Array(norms.suffix(GestureTemplate.recent))
        durations = Array(durations.suffix(GestureTemplate.recent))
    }

    // MARK: Mémoire (UserDefaults)

    private static func key(_ exercise: Exercise) -> String { "gesture.\(exercise.rawValue)" }

    static func load(_ exercise: Exercise) -> LearnedGesture {
        guard let data = UserDefaults.standard.data(forKey: key(exercise)),
              let learned = try? JSONDecoder().decode(LearnedGesture.self, from: data) else { return LearnedGesture() }
        return learned
    }

    /// Ajoute les répétitions apprises pendant une séance.
    static func remember(_ samples: [GestureSample], for exercise: Exercise) {
        guard !samples.isEmpty else { return }
        var learned = load(exercise)
        learned.add(samples)
        if let data = try? JSONEncoder().encode(learned) {
            UserDefaults.standard.set(data, forKey: key(exercise))
        }
    }
}

extension Exercise {
    /// Le gabarit personnel ne sert qu'aux abdos (validé sur des séances réelles).
    var learnsGesture: Bool { self == .crunches }
}

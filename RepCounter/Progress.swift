import Foundation

/// Verdict de progression d'un exercice : « En progrès » seulement quand c'est statistiquement
/// établi, sur le score d'endurance des 8 dernières semaines.
///
/// - Pente de Theil-Sen (Sen 1968, J Am Stat Assoc 63:1379–1389) : la médiane des pentes entre
///   toutes les paires de séances, robuste aux séances aberrantes ; intervalle de confiance
///   sans hypothèse de loi (équation 2.6 de Sen, comme scipy.stats.theilslopes), à 99 % :
///   Var(S) = n(n−1)(2n+5)/18 moins la correction des ex-æquo, C = 2,576·√Var(S), bornes =
///   pentes de rangs (N−C)/2 et (N+C)/2 + 1 parmi les N pentes triées.
/// - Plus petit changement significatif : 0,3 fois la variation habituelle d'une séance à
///   l'autre (Hopkins 2004, Sportscience 8:1–7), estimée par l'erreur typique (Hopkins 2000,
///   Sports Med 30(1):1–15) : écart-type des différences entre séances consécutives ÷ √2.
/// - En progrès : pente sûrement positive (intervalle au-dessus de zéro) et gain sur la période
///   au moins égal au plus petit changement significatif. En recul : l'inverse. Sinon Stable.
/// Au moins 8 séances notées ; les séances dont une série a été corrigée de plus de 2
/// répétitions sont écartées (comptage douteux), comme celles d'une décharge (pas de « recul »
/// pendant une décharge voulue).
/// Même calcul que Simulation/progress.py (validé : 0,2 % de « En progrès » à tort sur des
/// historiques plats bruités).
struct ProgressVerdict: Equatable {
    enum Kind { case pending, unreliable, up, stable, down }

    let kind: Kind
    /// En cours : séances notées.
    var progress = 0
    /// Pente (score par semaine).
    var weeklySlope: Double = 0

    static let minPoints = 8
    static let windowDays = 56
    /// Quantile de la loi normale pour un intervalle à 99 %.
    static let z = 2.5758293035489

    var title: String {
        switch kind {
        case .pending: return "Tendance \(progress) / \(Self.minPoints)"
        case .unreliable: return "Comptage à fiabiliser"
        case .up: return "En progrès"
        case .stable: return "Stable"
        case .down: return "En recul"
        }
    }

    /// Pente de Theil-Sen et son intervalle de confiance, ou nil.
    static func theilSen(_ x: [Double], _ y: [Double]) -> (slope: Double, low: Double, high: Double)? {
        let n = x.count
        var slopes: [Double] = []
        for i in 0..<n {
            for j in (i + 1)..<n where x[j] != x[i] {
                slopes.append((y[j] - y[i]) / (x[j] - x[i]))
            }
        }
        slopes.sort()
        let count = slopes.count
        guard count > 0 else { return nil }
        let middle = count / 2
        let slope = count % 2 == 1 ? slopes[middle] : (slopes[middle - 1] + slopes[middle]) / 2
        let ties = { (values: [Double]) -> Double in
            Dictionary(grouping: values) { $0 }.values.map(\.count).filter { $0 > 1 }
                .reduce(0) { $0 + Double($1 * ($1 - 1) * (2 * $1 + 5)) }
        }
        let variance = (Double(n * (n - 1) * (2 * n + 5)) - ties(x) - ties(y)) / 18
        let c = z * max(variance, 0).squareRoot()
        let lowRank = Int(((Double(count) - c) / 2).rounded())       // rang 1 = première pente
        let highRank = Int(((Double(count) + c) / 2).rounded()) + 1
        let clamp = { (rank: Int) in min(max(rank, 1), count) - 1 }
        return (slope, slopes[clamp(lowRank)], slopes[clamp(highRank)])
    }

    /// Erreur typique : écart-type des différences entre valeurs consécutives ÷ √2.
    static func typicalError(_ y: [Double]) -> Double? {
        let differences = zip(y.dropFirst(), y).map { $0 - $1 }
        guard differences.count >= 2 else { return nil }
        let mean = differences.reduce(0, +) / Double(differences.count)
        let variance = differences.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(differences.count - 1)
        return variance.squareRoot() / 2.0.squareRoot()
    }

    /// Le verdict sur des points (jour, score), les plus anciens d'abord.
    static func make(_ points: [(day: Double, value: Double)]) -> ProgressVerdict {
        guard points.count >= minPoints else { return ProgressVerdict(kind: .pending, progress: points.count) }
        let x = points.map(\.day), y = points.map(\.value)
        guard let fit = theilSen(x, y), let error = typicalError(y),
              let first = x.first, let last = x.last else {
            return ProgressVerdict(kind: .pending, progress: points.count)
        }
        let gain = fit.slope * (last - first)
        let smallest = 0.3 * error
        let kind: Kind = fit.low > 0 && gain >= smallest ? .up : (fit.high < 0 && -gain >= smallest ? .down : .stable)
        return ProgressVerdict(kind: kind, progress: points.count, weeklySlope: fit.slope * 7)
    }
}

extension HistoryStats {
    /// Verdict de progression du score d'endurance sur les 8 dernières semaines.
    /// Les séances d'une décharge déclarée sont écartées (volume réduit exprès).
    var progressVerdict: ProgressVerdict {
        guard countingIsReliable else { return ProgressVerdict(kind: .unreliable) }
        let deloads = Deloads.starts.map { DateInterval(start: calendar.startOfDay(for: $0), duration: Double(TrainingPhase.deloadDays) * 86_400) }
        let origin = calendar.startOfDay(for: now.addingTimeInterval(-Double(ProgressVerdict.windowDays) * 86_400))
        let points = sessions.reversed()
            .filter { $0.start > origin && $0.start <= now }
            .filter { session in !session.orderedSets.contains { abs($0.reps - $0.countedReps) > 2 } }
            .filter { session in !deloads.contains { $0.contains(session.start) } }
            .compactMap { session -> (day: Double, value: Double)? in
                guard let index = session.performanceIndex else { return nil }
                let day = calendar.dateComponents([.day], from: origin, to: calendar.startOfDay(for: session.start)).day ?? 0
                return (day: Double(day), value: index)
            }
        return ProgressVerdict.make(points)
    }
}

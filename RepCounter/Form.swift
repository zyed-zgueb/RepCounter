import Foundation
import SwiftData

/// Indice de forme d'une séance, tiré de la vitesse des répétitions : on est en forme quand on
/// va aussi vite que d'habitude et qu'on garde cette vitesse au fil de la série (principe de
/// l'entraînement basé sur la vitesse : la vitesse et sa perte reflètent la fatigue).
struct FormMeasure {
    /// Vitesse : durée médiane d'une répétition de la première série mesurable (s). Plus court = plus rapide.
    let pace: Double
    /// Maintien : durée des 3 dernières répétitions ÷ durée des 3 premières, en moyenne sur les
    /// séries mesurables (1 = vitesse tenue ; 1,3 = 30 % plus lent en fin de série).
    let slowdown: Double

    /// Séries mesurables : au moins 6 répétitions (3 premières et 3 dernières distinctes).
    static let minimumReps = 6
}

extension SessionRecord {
    /// Les séries corrigées à la main de plus de 2 répétitions sont écartées : leur découpage en
    /// répétitions est douteux.
    var formMeasure: FormMeasure? {
        let sets = orderedSets.filter { $0.repDurations.count >= FormMeasure.minimumReps - 1 && abs($0.reps - $0.countedReps) <= 2 }
        guard let first = sets.first, let pace = medianInterval(first.repTimes) else { return nil }
        let slowdowns = sets.compactMap { set -> Double? in
            let durations = set.repDurations
            let start = durations.prefix(3).reduce(0, +) / 3
            let end = durations.suffix(3).reduce(0, +) / 3
            return start > 0 ? end / start : nil
        }
        guard let slowdown = average(slowdowns), pace > 0, slowdown > 0 else { return nil }
        return FormMeasure(pace: pace, slowdown: slowdown)
    }
}

/// Zone de forme.
enum FormZone {
    case tired, normal, fresh

    var title: String {
        switch self {
        case .tired: return "Fatigué"
        case .normal: return "Forme normale"
        case .fresh: return "En forme"
        }
    }
}

/// Forme d'une séance, situées par rapport aux séances qui la précèdent.
struct FormResult {
    /// Forme en % de la référence : 100 = comme d'habitude ; plus = plus rapide et mieux tenu.
    let percent: Double
    let zone: FormZone
    /// Bande de variation normale (± %) : en dessous, fatigué ; au-dessus, en forme.
    let band: Double

    /// Séances précédentes nécessaires pour établir la référence.
    static let baselineSessions = 3
    /// Séances récentes qui forment la référence.
    static let referenceWindow = 10

    /// Forme = 100 × √((vitesse habituelle ÷ vitesse du jour) × (ralentissement habituel ÷ ralentissement du jour)).
    /// Référence : médianes des 10 dernières séances mesurables qui n'étaient pas fatiguées (une
    /// baisse qui dure reste visible au lieu de devenir la nouvelle norme). Variation normale :
    /// écart-type des formes des 10 dernières séances (fatiguées comprises) par rapport à la
    /// référence ; un écart ne compte qu'au-delà de 1,5 fois cette variation, et jamais sous 3 %.
    /// Nil tant qu'il y a moins de 3 séances de référence.
    /// `previous` : les séances d'avant, avec leur zone (nil tant que la référence n'était pas établie).
    /// Même calcul que `form_result` dans Simulation/phases.py.
    static func make(_ measure: FormMeasure, previous: [(measure: FormMeasure, zone: FormZone?)]) -> FormResult? {
        let reference = Array(previous.filter { $0.zone != .tired }.map(\.measure).suffix(referenceWindow))
        guard reference.count >= baselineSessions,
              let pace = median(reference.map(\.pace)), let slowdown = median(reference.map(\.slowdown)) else { return nil }
        let form = { (m: FormMeasure) in 100 * ((pace / m.pace) * (slowdown / m.slowdown)).squareRoot() }
        let past = previous.suffix(referenceWindow).map { form($0.measure) }
        let mean = past.reduce(0, +) / Double(past.count)
        let deviation = (past.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(past.count)).squareRoot()
        let band = max(3, 1.5 * deviation)
        let percent = form(measure)
        let zone: FormZone = percent < 100 - band ? .tired : (percent > 100 + band ? .fresh : .normal)
        return FormResult(percent: percent, zone: zone, band: band)
    }

    private static func median(_ values: [Double]) -> Double? {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return nil }
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }
}

extension HistoryStats {
    /// Forme de chaque séance mesurable (référence établie), de la plus ancienne à la plus récente.
    var formResults: [(session: SessionRecord, result: FormResult)] {
        var previous: [(measure: FormMeasure, zone: FormZone?)] = []
        var results: [(session: SessionRecord, result: FormResult)] = []
        for session in sessions.reversed() {
            guard let measure = session.formMeasure else { continue }
            let result = FormResult.make(measure, previous: previous)
            previous.append((measure: measure, zone: result?.zone))
            if let result { results.append((session: session, result: result)) }
        }
        return results
    }

    /// Séances mesurables de l'exercice (pour savoir où en est la référence).
    var measuredSessionCount: Int {
        sessions.filter { $0.formMeasure != nil }.count
    }

    /// Forme d'une séance précise (situées par rapport aux séances d'avant).
    func form(of session: SessionRecord) -> FormResult? {
        guard session.formMeasure != nil else { return nil }
        let same = HistoryStats(sessions: sessions.filter { $0.start <= session.start }, exercise: session.exercise,
                                calendar: calendar, now: now)
        return same.formResults.last { $0.session.persistentModelID == session.persistentModelID }?.result
    }
}

import Foundation
import SwiftData

/// Un test de forme : quelques répétitions aussi vite que possible, amplitude complète.
/// La durée d'une répétition, comparée à sa référence personnelle, dit si l'on est frais ou fatigué
/// (principe de l'entraînement basé sur la vitesse). Modèle compatible CloudKit, comme l'historique.
@Model
final class FormTest {
    var exerciseID: String = Exercise.auto.rawValue
    var date: Date = Date()
    /// Durée de chaque répétition mesurée (s), d'un extrême du mouvement au suivant.
    var intervals: [Double] = []

    init(exercise: Exercise, date: Date, intervals: [Double]) {
        exerciseID = exercise.rawValue
        self.date = date
        self.intervals = intervals
    }

    var exercise: Exercise { Exercise(rawValue: exerciseID) ?? .auto }
    /// Durée moyenne d'une répétition (s).
    var meanInterval: Double { intervals.isEmpty ? 0 : intervals.reduce(0, +) / Double(intervals.count) }

    /// Répétitions faites pendant le test (la première sert de départ : on mesure les suivantes).
    static let reps = 4
    /// Tests nécessaires pour connaître sa variation normale.
    static let baselineTests = 3
    /// Tests récents qui forment la référence.
    static let referenceWindow = 10
}

/// Zone d'un résultat de test.
enum FormZone {
    case tired, normal, fresh

    var title: String {
        switch self {
        case .tired: return "Fatigué"
        case .normal: return "Forme normale"
        case .fresh: return "Frais"
        }
    }

    var advice: String {
        switch self {
        case .tired: return "Tes répétitions sont nettement plus lentes que d'habitude. Séance légère ou repos conseillé."
        case .normal: return "Dans ta variation habituelle. Séance prévue."
        case .fresh: return "Plus rapide que d'habitude : bon jour pour viser un record."
        }
    }
}

/// Résultat d'un test, situé par rapport aux tests qui le précèdent.
struct FormResult {
    /// Forme en % de la référence : 100 = comme d'habitude, plus = plus rapide.
    let percent: Double
    let zone: FormZone
    /// Bande de variation normale (± %) : en dessous, fatigué ; au-dessus, frais.
    let band: Double

    /// Situe `test` par rapport aux `previous` tests du même exercice (du plus ancien au plus
    /// récent). Nil tant que la référence n'est pas établie (moins de 3 tests précédents).
    ///
    /// Référence : médiane des 10 derniers tests. Variation normale : leur écart-type relatif ;
    /// un écart ne compte qu'au-delà de 1,5 fois cette variation, et jamais sous 3 % (finesse de
    /// la mesure, une image tous les 1/30 s).
    static func make(_ test: FormTest, previous: [FormTest]) -> FormResult? {
        let recent = previous.suffix(FormTest.referenceWindow).map(\.meanInterval).filter { $0 > 0 }
        guard recent.count >= FormTest.baselineTests, test.meanInterval > 0 else { return nil }
        let sorted = recent.sorted()
        let reference = sorted.count % 2 == 1
            ? sorted[sorted.count / 2]
            : (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
        let mean = recent.reduce(0, +) / Double(recent.count)
        let deviation = (recent.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(recent.count)).squareRoot()
        let band = max(3, 1.5 * deviation / mean * 100)
        let percent = reference / test.meanInterval * 100
        let zone: FormZone = percent < 100 - band ? .tired : (percent > 100 + band ? .fresh : .normal)
        return FormResult(percent: percent, zone: zone, band: band)
    }
}

extension Array where Element == FormTest {
    /// Résultat de chaque test (ceux dont la référence était établie), du plus ancien au plus récent.
    func results() -> [(test: FormTest, result: FormResult)] {
        let ordered = sorted { $0.date < $1.date }
        return ordered.enumerated().compactMap { index, test in
            FormResult.make(test, previous: Array(ordered[..<index])).map { (test: test, result: $0) }
        }
    }
}

extension Exercise {
    /// Le test de forme a un sens pour les exercices identifiés (pas pour « Autre »).
    var supportsFormTest: Bool { self != .auto }

    /// « 4 pompes », « 4 abdos »…
    var testNoun: String {
        switch self {
        case .pushups: return "pompes"
        case .crunches: return "abdos"
        case .squats: return "squats"
        case .curls: return "flexions"
        case .press: return "développés"
        case .auto: return "répétitions"
        }
    }
}

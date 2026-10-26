import Foundation

// MARK: - Profil

/// Profil facultatif, pour situer son niveau par rapport aux barèmes publiés (âge, sexe).
enum Sex: String, CaseIterable, Identifiable {
    case female, male

    var id: String { rawValue }
    var title: String { self == .female ? "Femme" : "Homme" }
}

enum Profile {
    static let sexKey = "profile.sex"
    static let birthYearKey = "profile.birthYear"

    static var sex: Sex? { UserDefaults.standard.string(forKey: sexKey).flatMap(Sex.init) }

    static var age: Int? {
        let year = UserDefaults.standard.integer(forKey: birthYearKey)
        guard year > 0 else { return nil }
        return Calendar.current.component(.year, from: Date()) - year
    }
}

// MARK: - Niveaux

/// Niveau d'endurance musculaire, selon un barème publié.
enum EnduranceLevel: Int, CaseIterable, Comparable {
    case needsImprovement, fair, good, veryGood, excellent

    var title: String {
        switch self {
        case .needsImprovement: return "À améliorer"
        case .fair: return "Moyen"
        case .good: return "Bon"
        case .veryGood: return "Très bon"
        case .excellent: return "Excellent"
        }
    }

    static func < (a: EnduranceLevel, b: EnduranceLevel) -> Bool { a.rawValue < b.rawValue }
}

/// Barème du test de pompes de la Société canadienne de physiologie de l'exercice (SCPE/CSEP),
/// repris par l'ACSM : nombre maximal de pompes d'affilée, sans limite de temps, par âge et sexe.
/// Chaque ligne donne le minimum pour Moyen, Bon, Très bon et Excellent.
/// Pour les femmes, le test se fait genoux au sol : avec des pompes classiques, le niveau est sous-estimé.
enum PushupNorms {
    static let source = "SCPE/CSEP, Guide du conditionnement physique (ACSM, Guidelines for Exercise Testing and Prescription)"

    private static let men: [(maxAge: Int, thresholds: [Int])] = [
        (19, [18, 23, 29, 39]),
        (29, [17, 22, 29, 36]),
        (39, [12, 17, 22, 30]),
        (49, [10, 13, 17, 25]),
        (59, [7, 10, 13, 21]),
        (.max, [5, 8, 11, 18]),
    ]

    private static let women: [(maxAge: Int, thresholds: [Int])] = [
        (19, [12, 18, 25, 33]),
        (29, [10, 15, 21, 30]),
        (39, [8, 13, 20, 27]),
        (49, [5, 11, 15, 24]),
        (59, [2, 7, 11, 21]),
        (.max, [2, 5, 12, 17]),
    ]

    /// Seuils (Moyen, Bon, Très bon, Excellent) pour cet âge et ce sexe.
    static func thresholds(age: Int, sex: Sex) -> [Int] {
        let table = sex == .male ? men : women
        return (table.first { age <= $0.maxAge } ?? table[table.count - 1]).thresholds
    }

    static func level(reps: Int, age: Int, sex: Sex) -> EnduranceLevel {
        let passed = thresholds(age: age, sex: sex).filter { reps >= $0 }.count
        return EnduranceLevel(rawValue: passed) ?? .needsImprovement
    }

    /// Position sur la jauge (0…1) : cinq zones égales, interpolées entre leurs seuils.
    static func position(reps: Int, age: Int, sex: Sex) -> Double {
        let t = thresholds(age: age, sex: sex)
        let bounds = [0] + t + [t[t.count - 1] + (t[t.count - 1] - t[t.count - 2])]
        for zone in 0..<5 where reps < bounds[zone + 1] || zone == 4 {
            let low = Double(bounds[zone]), high = Double(bounds[zone + 1])
            let inZone = min(max((Double(reps) - low) / max(high - low, 1), 0), 1)
            return (Double(zone) + inZone) / 5
        }
        return 1
    }
}

/// Ce qu'on peut dire du niveau d'un exercice : un niveau publié (pompes, avec un profil), ou rien.
struct EnduranceAssessment {
    let level: EnduranceLevel
    /// Position sur la jauge (0…1).
    let position: Double
    /// Meilleure série prise en compte.
    let reps: Int
    let age: Int
    let sex: Sex

    static func make(exercise: Exercise, bestSet: Int?) -> EnduranceAssessment? {
        guard exercise == .pushups, let bestSet, bestSet > 0, let age = Profile.age, let sex = Profile.sex,
              age >= 10 else { return nil }
        return EnduranceAssessment(level: PushupNorms.level(reps: bestSet, age: age, sex: sex),
                                   position: PushupNorms.position(reps: bestSet, age: age, sex: sex),
                                   reps: bestSet, age: age, sex: sex)
    }

    /// « 30-39 ans »
    var ageBand: String {
        switch age {
        case ..<20: return "15-19 ans"
        case ..<30: return "20-29 ans"
        case ..<40: return "30-39 ans"
        case ..<50: return "40-49 ans"
        case ..<60: return "50-59 ans"
        default: return "60 ans et plus"
        }
    }
}

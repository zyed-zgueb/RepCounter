import Foundation

/// Tous les paramètres de prescription du plan, en un seul endroit, chacun avec sa référence.
///
/// Prise de position de l'ACSM : Currier et al., Med Sci Sports Exerc 2026;58(4):851–872 (accès
/// ouvert, lu en texte intégral) :
/// - fréquence : « at least twice weekly » (p. 863) → au moins 2 séances par semaine ;
/// - séries : « at least two sets per exercise » (p. 864), « 2–3 sets/session » pour la force
///   (tableau 6), gains décroissants au-delà de « ~2–3 sets/exercise » → 3 séries ;
/// - effort : pas besoin d'aller à l'échec ; « “near-failure” or a target of 2–3 repetitions in
///   reserve (RIR) » (p. 864), mais « insufficient evidence to quantify exact RIR » → au poids du
///   corps, la cible d'une série est le max mesuré moins 3 (la formule « max − 3 » est un choix
///   de l'app, fondé sur cette cible) ;
/// - repos : pas d'effet d'un repos court (< 1 min) ou long (> 1 min) sur la force (p. 856) →
///   le repos habituel de la personne ;
/// - progression : par des tests réguliers (« regular strength testing », p. 863) → le test de
///   fin de bloc recale la cible ; aucune hausse hebdomadaire chiffrée dans l'article, donc aucune ;
/// - endurance musculaire : améliorée par l'entraînement, mais « insufficient data » pour dire
///   quel dosage (p. 859, tableau 6 : « ND ») : le plan applique les recommandations générales
///   et vérifie le résultat par les tests.
/// Semaine allégée : volume réduit, 7 jours (Bell et al. 2023 ; Rogerson et al. 2024 : 6,4 ±
/// 1,7 jours) ; l'ACSM ne traite pas des décharges et ne trouve pas la périodisation supérieure.
/// Choix de l'app : le rythme 3 + 1 et le test, la moitié des séries en semaine allégée et en
/// séance légère, la semaine refaite, la règle « séance faite ».
enum Prescription {
    /// Une séance prévue : la cible de chaque série, enchaînées avec le repos prévu (s).
    struct Session: Equatable {
        var targets: [Int]
        var rest: Int

        var sets: Int { targets.count }
        var total: Int { targets.reduce(0, +) }
        /// « 29 · 25 · 22 »
        var label: String { targets.map(String.init).joined(separator: " · ") }
    }

    /// Au moins 2 séances par semaine (ACSM 2026).
    static let minSessionsPerWeek = 2
    /// 3 séries par séance (ACSM 2026 : au moins 2, « 2–3 sets/session »).
    static let sets = 3
    /// Répétitions en réserve : cible de la série 1 = max − 3 (ACSM 2026 : 2–3 en réserve ; la
    /// formule est un choix de l'app).
    static let repsInReserve = 3
    /// La règle de l'ACSM porte sur l'effort de chaque série (2–3 en réserve), pas sur un nombre
    /// de répétitions identique : avec la fatigue, le nombre baisse d'une série à l'autre. Les
    /// cibles des séries 2 et 3 suivent la baisse habituelle de la personne (rapports médians série
    /// k / série 1, sur ses séances des 4 dernières semaines faites avec un repos à ± 30 s du repos
    /// prévu, au moins 3 séances) ; sans cet historique, chaque série vise 80 % de la précédente.
    /// Ces deux règles et ce rapport par défaut (prudent) sont des choix de l'app.
    static let defaultStep = 0.8
    static let ratioSessions = 3
    static let ratioRestTolerance: TimeInterval = 30
    /// Semaines de progression puis semaine allégée, avant le test (choix de l'app).
    static let progressionWeeks = 3
    static let deloadWeeks = 1
    /// Une semaine de progression refaite au plus deux fois par bloc (choix de l'app).
    static let maxRepeats = 2
    /// Fenêtre de la séance habituelle (repos, séances par semaine, meilleure série, baisse).
    static let habitDays = 28

    /// La cible de la série 1 d'après le max (au moins 1).
    static func target(max: Int) -> Int { Swift.max(1, max - repsInReserve) }

    /// Les cibles d'une séance : la série 1, puis la baisse habituelle (`ratios` : série k ÷
    /// série 1) ou, sans elle, 80 % de la série précédente.
    static func targets(first: Int, ratios: [Double]?) -> [Int] {
        (0..<sets).map { k in
            let ratio = ratios.map { k < $0.count ? $0[k] : $0.last ?? 1 } ?? pow(defaultStep, Double(k))
            return Swift.max(1, Int((Double(first) * ratio).rounded()))
        }
    }

    /// Le rapport d'une série à la précédente (série k ÷ série k − 1).
    static func step(_ k: Int, ratios: [Double]?) -> Double {
        guard let ratios, k > 0, k < ratios.count, ratios[k - 1] > 0 else { return defaultStep }
        return ratios[k] / ratios[k - 1]
    }

    /// La baisse habituelle d'une série à l'autre : médianes de série k ÷ série 1, sur les séances
    /// d'au moins `sets` séries faites avec un repos à ± 30 s de `rest`. Nil sous 3 séances.
    static func ratios(_ sessions: [SessionRecord], rest: Int) -> [Double]? {
        // Ni séance de test (une série max), ni échauffement
        let eligible = sessions.filter { session in
            guard !session.isTest else { return false }
            let reps = session.workSets.map(\.reps)
            guard reps.count >= sets, reps[0] > 0 else { return false }
            return (1..<sets).allSatisfy { k in
                session.rest(before: k).map { abs($0 - Double(rest)) <= ratioRestTolerance } ?? false
            }
        }
        guard eligible.count >= ratioSessions else { return nil }
        return (0..<sets).map { k in
            k == 0 ? 1 : median(eligible.map { Double($0.workSets[k].reps) / Double($0.workSets[0].reps) })
        }
    }

    /// La cible de la prochaine série du jour. `dayDone` : séries déjà faites aujourd'hui (séances
    /// précédentes du jour comprises) ; `sessionDone` : celles de la séance en cours. Une série sous
    /// sa cible réajuste aussitôt la suivante, à partir de ce qui vient d'être fait, sans rattrapage ;
    /// une nouvelle séance du même jour (séries espacées) repart de la série 1, la personne étant
    /// fraîche. Nil quand toutes les séries prévues sont faites.
    static func nextTarget(_ session: Session, ratios: [Double]?, dayDone: [Int], sessionDone: [Int]) -> Int? {
        let k = dayDone.count
        guard k < session.sets else { return nil }
        guard let previous = sessionDone.last else { return session.targets[0] }
        let adjusted = Swift.max(1, Int((Double(previous) * step(k, ratios: ratios)).rounded()))
        return Swift.min(session.targets[k], adjusted)
    }

    /// Semaine allégée et séance légère : la moitié des séries, arrondie au-dessus (choix de l'app).
    static func lighter(_ session: Session) -> Session {
        Session(targets: Array(session.targets.prefix(Swift.max(1, (session.sets + 1) / 2))), rest: session.rest)
    }

    /// La séance d'une semaine de progression : la même tout le bloc (pas de hausse hebdomadaire).
    static func progression(_ base: Session, week: Int) -> Session { base }

    /// La séance prévue et la baisse habituelle, d'après les séances de l'exercice des `habitDays`
    /// jours avant `date` : max = le dernier test (`testMax`), sinon la meilleure série de ces
    /// 4 semaines ; repos habituel (médiane, arrondi à 15 s, entre 30 s et 5 min). Nil sans séance.
    static func habitual(_ sessions: [SessionRecord], before date: Date, testMax: Int? = nil, calendar: Calendar)
        -> (session: Session, ratios: [Double]?)? {
        let since = date.addingTimeInterval(-Double(habitDays) * 86_400)
        let recent = sessions.filter { $0.start >= since && $0.start < date && !$0.orderedSets.isEmpty }
        guard !recent.isEmpty else { return nil }
        let best = recent.map(\.bestSet).max() ?? 1
        let rests = recent.flatMap { session in
            (1..<Swift.max(session.orderedSets.count, 1)).compactMap { session.rest(before: $0) }
        }
        let rest = rests.count >= 3 ? median(rests) : 60
        let plannedRest = Swift.min(Swift.max(Int((rest / 15).rounded()) * 15, 30), 300)
        let ratios = ratios(recent, rest: plannedRest)
        return (Session(targets: targets(first: target(max: testMax ?? best), ratios: ratios), rest: plannedRest), ratios)
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }
}

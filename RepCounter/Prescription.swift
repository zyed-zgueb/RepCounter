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
    /// Une séance prévue : séries × répétitions, repos entre les séries (s).
    struct Session: Equatable {
        var sets: Int
        var reps: Int
        var rest: Int

        var total: Int { sets * reps }
    }

    /// Au moins 2 séances par semaine (ACSM 2026).
    static let minSessionsPerWeek = 2
    /// 3 séries par séance (ACSM 2026 : au moins 2, « 2–3 sets/session »).
    static let sets = 3
    /// Répétitions en réserve : cible d'une série = max − 3 (ACSM 2026 : 2–3 en réserve ; la
    /// formule est un choix de l'app).
    static let repsInReserve = 3
    /// Semaines de progression puis semaine allégée, avant le test (choix de l'app).
    static let progressionWeeks = 3
    static let deloadWeeks = 1
    /// Une semaine de progression refaite au plus deux fois par bloc (choix de l'app).
    static let maxRepeats = 2
    /// Fenêtre de la séance habituelle (repos, séances par semaine, meilleure série).
    static let habitDays = 28

    /// La cible d'une série d'après le max (au moins 1).
    static func target(max: Int) -> Int { Swift.max(1, max - repsInReserve) }

    /// Semaine allégée et séance légère : la moitié des séries, arrondie au-dessus (choix de l'app).
    static func lighter(_ session: Session) -> Session {
        Session(sets: Swift.max(1, (session.sets + 1) / 2), reps: session.reps, rest: session.rest)
    }

    /// La séance d'une semaine de progression : la même tout le bloc (pas de hausse hebdomadaire).
    static func progression(_ base: Session, week: Int) -> Session { base }

    /// La séance prévue et le nombre de séances par semaine, d'après les séances de l'exercice
    /// des `habitDays` jours avant `date` : max = le dernier test (`testMax`), sinon la meilleure
    /// série de ces 4 semaines ; repos habituel (médiane) ; séances par semaine habituelles, au
    /// moins 2. Nil sans aucune séance.
    static func habitual(_ sessions: [SessionRecord], before date: Date, testMax: Int? = nil, calendar: Calendar)
        -> (session: Session, perWeek: Int)? {
        let since = date.addingTimeInterval(-Double(habitDays) * 86_400)
        let recent = sessions.filter { $0.start >= since && $0.start < date && !$0.orderedSets.isEmpty }
        guard !recent.isEmpty else { return nil }
        let best = recent.map(\.bestSet).max() ?? 1
        let rests = recent.flatMap { session in
            (1..<Swift.max(session.orderedSets.count, 1)).compactMap { session.rest(before: $0) }
        }
        let rest = rests.count >= 3 ? median(rests) : 60
        var weeks: [Date: Int] = [:]
        for session in recent {
            let week = calendar.dateInterval(of: .weekOfYear, for: session.start)?.start ?? session.start
            weeks[week, default: 0] += 1
        }
        let perWeek = Int(median(weeks.values.map(Double.init)).rounded())
        let roundedRest = Int((rest / 15).rounded()) * 15
        return (Session(sets: sets, reps: target(max: testMax ?? best), rest: Swift.min(Swift.max(roundedRest, 30), 300)),
                Swift.max(minSessionsPerWeek, perWeek))
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }
}

import Foundation

/// Tous les paramètres de prescription du plan, en un seul endroit : le jour où la prise de
/// position ACSM 2026 (Currier et al., Med Sci Sports Exerc 2026;58(4):851–872) aura été lue en
/// texte intégral, c'est ici seulement qu'on les remplacera.
///
/// En attendant, rien n'est inventé :
/// - la séance prévue est la séance habituelle de la personne pour l'exercice (séries,
///   répétitions par série, repos et séances par semaine : médianes des 4 semaines qui
///   précèdent le bloc) ;
/// - pas d'augmentation d'une semaine à l'autre, faute de référence qui la fixe ;
/// - la semaine allégée réduit le volume, et dure 7 jours (Bell et al. 2023, consensus Delphi :
///   « reduce volume by lowering sets », 100 % ; Rogerson et al. 2024 : 6,4 ± 1,7 jours). La part
///   de séries retirée n'est fixée par aucune des deux : la moitié, choix provisoire de l'app ;
/// - le rythme 3 semaines + 1 allégée + un test, la séance légère quand la Forme est basse, et la
///   règle « séance faite » (total prévu atteint) sont des choix de l'app.
enum Prescription {
    /// Les valeurs ci-dessous sont provisoires (affiché dans le (i)).
    static let isProvisional = true

    /// Une séance prévue : séries × répétitions, repos entre les séries (s).
    struct Session: Equatable {
        var sets: Int
        var reps: Int
        var rest: Int

        var total: Int { sets * reps }
    }

    /// Semaines de progression puis semaine allégée, avant le test (choix de l'app).
    static let progressionWeeks = 3
    static let deloadWeeks = 1
    /// Augmentation de la séance d'une semaine de progression à la suivante : aucune tant
    /// qu'aucune référence ne la fixe.
    static let weeklyIncrease = 0
    /// Une semaine de progression refaite au plus deux fois par bloc (choix de l'app).
    static let maxRepeats = 2
    /// Fenêtre de la séance habituelle.
    static let habitDays = 28

    /// Semaine allégée et séance légère : moitié des séries, au moins une (choix provisoire).
    static func lighter(_ session: Session) -> Session {
        Session(sets: max(1, session.sets / 2), reps: session.reps, rest: session.rest)
    }

    /// La séance de la semaine `week` (0, 1, 2) d'un bloc, à partir de la séance habituelle.
    static func progression(_ base: Session, week: Int) -> Session {
        Session(sets: base.sets, reps: base.reps + weeklyIncrease * week, rest: base.rest)
    }

    /// La séance habituelle et le nombre de séances par semaine, en médianes des séances de
    /// l'exercice des `habitDays` jours avant `date` ; nil sans aucune séance.
    static func habitual(_ sessions: [SessionRecord], before date: Date, calendar: Calendar)
        -> (session: Session, perWeek: Int)? {
        let since = date.addingTimeInterval(-Double(habitDays) * 86_400)
        let recent = sessions.filter { $0.start >= since && $0.start < date && !$0.orderedSets.isEmpty }
        guard !recent.isEmpty else { return nil }
        let sets = median(recent.map { Double($0.orderedSets.count) })
        let reps = median(recent.flatMap { $0.orderedSets.map { Double($0.reps) } })
        let rests = recent.flatMap { session in
            (1..<max(session.orderedSets.count, 1)).compactMap { session.rest(before: $0) }
        }
        let rest = rests.count >= 3 ? median(rests) : 60
        var weeks: [Date: Int] = [:]
        for session in recent {
            let week = calendar.dateInterval(of: .weekOfYear, for: session.start)?.start ?? session.start
            weeks[week, default: 0] += 1
        }
        let perWeek = median(weeks.values.map(Double.init))
        let roundedRest = Int((rest / 15).rounded()) * 15
        return (Session(sets: max(1, Int(sets.rounded())), reps: max(1, Int(reps.rounded())),
                        rest: min(max(roundedRest, 30), 300)),
                max(1, Int(perWeek.rounded())))
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }
}

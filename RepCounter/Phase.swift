import Foundation

/// Où en est l'utilisateur dans son cycle d'entraînement, pour un exercice : construction,
/// surcharge, décharge, rebond… La charge d'entraînement (toutes les séances) est confrontée à la
/// performance mesurée (la Forme de l'exercice).
///
/// Bases publiées :
/// - Meeusen et al. 2013, consensus ECSS / ACSM, Med Sci Sports Exerc 45(1):186–205 : une baisse
///   de performance après un entraînement intensifié est une surcharge fonctionnelle quand elle se
///   résorbe en jours ou semaines, suivie d'un rebond (surcompensation) ; non fonctionnelle quand
///   elle dure des semaines à des mois. Le surentraînement est un diagnostic médical : l'app ne
///   l'emploie pas.
/// - Bell et al. 2023, consensus Delphi, Sports Med Open 9:87 : la décharge est une période de
///   stress d'entraînement réduit (volume en baisse) pour résorber la fatigue. Rogerson et al.
///   2024, Sports Med Open : décharges de 6,4 ± 1,7 jours chez 246 athlètes de force.
/// - Foster et al. 2001, J Strength Cond Res 15(1):109–115 : charge de séance = effort (CR-10)
///   × durée (min).
/// - Hopkins 2000, Sports Med 30(1):1–15 : une mesure isolée hors de la variation habituelle peut
///   être du bruit ; une baisse se constate sur deux séances de suite.
/// - Saw, Main et Gastin 2016, Br J Sports Med 50(5):281–291 : le ressenti suit la charge mieux
///   que les mesures objectives courantes, et les deux concordent mal ; on les croise.
///
/// Seuils provisoires (choix de l'app, à remplacer par la valeur d'une référence) : `forDays`,
/// `reboundDays`, `minSessions`, `minDays`.
/// Même calcul que `phase` dans Simulation/phases.py, validé sur des historiques synthétiques.
struct TrainingPhase: Equatable {
    enum Kind: Equatable {
        /// Pas encore assez de séances mesurables (`progress` sur `minSessions`).
        case pending
        /// Comptage juste à moins de 90 % : pas d'analyse (`progress` : précision en %).
        case unreliable
        case building, overreaching, lowForm, comeback, deloadAdvised, deload, rest, rebound, persistentFatigue
    }

    let kind: Kind
    /// Début de la baisse, de la décharge ou de la pause.
    var since: Date?
    /// En cours : séances mesurables.
    var progress = 0
    /// Construction : fatigue ressentie avant la dernière séance, pas encore mesurée.
    var felt = false

    /// Durée d'une baisse au-delà de laquelle elle n'est plus une surcharge fonctionnelle
    /// (Meeusen 2013 : « jours à semaines » ; provisoire).
    static let forDays = 14
    /// Une décharge dure une semaine (Rogerson 2024 : 6,4 ± 1,7 jours).
    static let deloadDays = 7
    /// Le rebond se cherche dans les 14 jours qui suivent la fin d'une surcharge ou d'une décharge (provisoire).
    static let reboundDays = 14
    /// Confiance : 8 séances mesurables sur 4 semaines au moins (provisoire).
    static let minSessions = 8
    static let minDays = 28
    /// Plus de 7 jours sans aucune séance : une pause, stress d'entraînement réduit (Bell 2023).
    static let breakDays = 7
}

// MARK: - Décharges déclarées

/// Les décharges que l'utilisateur a commencées (bouton de la phase « Décharge conseillée »).
/// Elles valent pour tous les exercices : la fatigue n'est pas propre à un exercice.
enum Deloads {
    static let key = "phase.deloads"

    static var starts: [Date] {
        (UserDefaults.standard.array(forKey: key) as? [Double] ?? []).map(Date.init(timeIntervalSince1970:))
    }

    static func start(_ date: Date = Date()) {
        let values = (UserDefaults.standard.array(forKey: key) as? [Double] ?? []) + [date.timeIntervalSince1970]
        UserDefaults.standard.set(values, forKey: key)
    }

    /// Annule une décharge commencée (touchée par erreur).
    static func cancel(_ date: Date) {
        let values = (UserDefaults.standard.array(forKey: key) as? [Double] ?? []).filter { $0 != date.timeIntervalSince1970 }
        UserDefaults.standard.set(values, forKey: key)
    }
}

// MARK: - Calcul

extension HistoryStats {
    /// La phase de l'exercice de ces statistiques. `all` : toutes les séances, tous exercices (la
    /// charge d'entraînement). `deloads` : débuts des décharges déclarées.
    func phase(all: [SessionRecord], deloads: [Date] = Deloads.starts) -> TrainingPhase {
        guard countingIsReliable else {
            return TrainingPhase(kind: .unreliable, progress: Int(((countingAccuracy ?? 0) * 100).rounded()))
        }
        let origin = calendar.startOfDay(for: all.map(\.start).min() ?? now)
        let dayOf = { (date: Date) -> Int in
            calendar.dateComponents([.day], from: origin, to: calendar.startOfDay(for: date)).day ?? 0
        }
        let dateOf = { (day: Int) -> Date in calendar.date(byAdding: .day, value: day, to: origin) ?? origin }
        let today = dayOf(now)
        let everything = all.filter { $0.start <= now }

        // Charge de séance (Foster 2001) ; sans réponse, l'effort habituel de la personne
        let efforts = everything.compactMap(\.effort).map { Double($0) }
        let usualEffort = Self.median(efforts) ?? 1
        let loads: [(day: Int, load: Double)] = everything.map {
            (day: dayOf($0.start), load: ($0.effort.map { Double($0) } ?? usualEffort) * $0.duration / 60)
        }
        func weeklyLoad(endingBefore end: Int) -> Double {
            loads.filter { $0.day >= end - 7 && $0.day < end }.reduce(0) { $0 + $1.load }
        }
        // Entraînement intensifié avant `day` (Meeusen 2013) : les 7 jours d'avant (ou les 7
        // d'avant encore) plus chargés que chacune des 4 semaines qui les précèdent
        func intensified(before day: Int) -> Bool {
            [day, day - 7].contains { end in
                let week = weeklyLoad(endingBefore: end)
                let previous = (1...4).map { weeklyLoad(endingBefore: end - 7 * $0) }
                return (previous.max() ?? 0) > 0 && week > (previous.max() ?? 0)
            }
        }

        // Séances mesurées de l'exercice, de la plus ancienne à la plus récente
        let results = formResults
        let measurable = sessions.reversed().filter { $0.formMeasure != nil }
        guard let first = measurable.first, measurable.count >= TrainingPhase.minSessions,
              today - dayOf(first.start) >= TrainingPhase.minDays, !results.isEmpty else {
            return TrainingPhase(kind: .pending, progress: min(measurable.count, TrainingPhase.minSessions))
        }
        let records = recordSessions
        let measured = results.map { (day: dayOf($0.session.start), zone: $0.result.zone, percent: $0.result.percent,
                                      record: records.contains($0.session.persistentModelID), session: $0.session) }

        // Périodes de stress réduit : décharges déclarées, et pauses (plus de 7 jours sans séance)
        var periods: [(start: Int, end: Int, pause: Bool)] = deloads.map(dayOf).filter { $0 <= today }
            .map { (start: $0, end: $0 + TrainingPhase.deloadDays, pause: false) }
        let days = Array(Set(everything.map { dayOf($0.start) })).sorted()
        for (a, b) in zip(days, days.dropFirst()) where b - a > TrainingPhase.breakDays {
            periods.append((start: a + 1, end: b, pause: true))
        }
        if let last = days.last, today - last > TrainingPhase.breakDays {
            periods.append((start: last + 1, end: today + 1, pause: true))
        }
        let current = periods.first { $0.start <= today && today < $0.end }
        func reduced(_ period: (start: Int, end: Int, pause: Bool)) -> TrainingPhase {
            TrainingPhase(kind: period.pause ? .rest : .deload, since: dateOf(period.start))
        }

        // Baisse en cours : les séances fatiguées de suite, jusqu'à la dernière
        let streak = measured.reversed().prefix { $0.zone == .tired }
        if streak.count >= 2, let start = streak.last?.day, let lastTired = streak.first?.day {
            let since = dateOf(start)
            let ended = periods.filter { $0.start >= start && $0.end <= today }.map(\.end)
            if let end = ended.max(), lastTired >= end {
                return TrainingPhase(kind: .persistentFatigue, since: since)
            }
            if let current { return reduced(current) }
            // Reprise : la baisse commence peu après une pause (désentraînement, pas surcharge)
            if periods.contains(where: { $0.pause && start - $0.end >= 0 && start - $0.end <= TrainingPhase.forDays }) {
                return TrainingPhase(kind: .comeback, since: since)
            }
            if today - start >= TrainingPhase.forDays { return TrainingPhase(kind: .deloadAdvised, since: since) }
            if intensified(before: start) { return TrainingPhase(kind: .overreaching, since: since) }
            return TrainingPhase(kind: .lowForm, since: since)
        }
        if let current { return reduced(current) }

        // Rebond (Meeusen 2013) : après une surcharge (baisse qui suit un entraînement intensifié)
        // ou une décharge déclarée, la première séance revenue au moins à la référence, ou un
        // record, dans les 14 jours : la surcompensation. Une fois par épisode.
        guard let last = measured.last else { return TrainingPhase(kind: .building) }
        var ends = periods.filter { !$0.pause && $0.end <= today }.map(\.end)
        for i in measured.indices.dropFirst(2)
        where measured[i].zone != .tired && measured[i - 1].zone == .tired && measured[i - 2].zone == .tired {
            var k = i - 1
            while k > 0, measured[k - 1].zone == .tired { k -= 1 }
            if intensified(before: measured[k].day) { ends.append(measured[i - 1].day + 1) }
        }
        for end in ends {
            let first = measured.first { $0.day >= end && $0.day <= end + TrainingPhase.reboundDays && ($0.percent >= 100 || $0.record) }
            if let first, first.session.persistentModelID == last.session.persistentModelID {
                return TrainingPhase(kind: .rebound, since: dateOf(last.day))
            }
        }

        // Ressenti × mesure (Saw et al. 2016) : fatigué avant la séance, Forme pourtant normale
        let felt = (last.session.feltFatigue ?? 0) >= Feeling.tiredFrom && last.zone != .tired
        return TrainingPhase(kind: .building, felt: felt)
    }

    private static func median(_ values: [Double]) -> Double? {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return nil }
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }

    /// Charge d'entraînement (Foster 2001) de chacune des `weeks` dernières semaines, la plus
    /// ancienne d'abord, toutes séances confondues (`all`).
    func weeklyLoads(all: [SessionRecord], weeks: Int = 12) -> [(week: Date, load: Double, answered: Bool)] {
        let efforts = all.compactMap(\.effort).map { Double($0) }
        let usual = Self.median(efforts) ?? 1
        return lastWeeks(weeks).map { week in
            let inWeek = all.filter { weekStart($0.start) == week }
            let load = inWeek.reduce(0) { $0 + ($1.effort.map { Double($0) } ?? usual) * $1.duration / 60 }
            return (week: week, load: load, answered: inWeek.contains { $0.effort != nil })
        }
    }
}

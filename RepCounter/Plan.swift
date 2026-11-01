import Foundation
import SwiftData

/// Le plan d'un exercice, déduit de l'objectif et des séances faites (rien n'est stocké d'autre
/// que l'objectif) : des blocs de 3 semaines de progression, 1 semaine allégée, puis un test (une
/// série max). Le bloc suivant repart du test. Une semaine de progression où l'on décroche (moins
/// de 2 séances, ou Forme basse deux fois) est refaite : le test est décalé d'autant.
/// Pas de jours prévus (Science/METHODE-JOURS.md, décision de Vincent) : chaque jour, l'app propose
/// une séance, sauf repos conseillé (`RestReason`). Les paramètres de séance viennent tous de
/// `Prescription`.
struct TrainingPlan {
    enum WeekKind: Equatable {
        /// Semaine de progression (0, 1, 2) ; `redo` : refaite après un décrochage.
        case progression(Int, redo: Bool)
        case deload
        /// Semaine de reprise avant le test, après plus de 7 jours sans séance (« ! reprise »,
        /// intensité calme). Choix de l'app ; Bell et al. 2023 : une pause réduit le stress
        /// d'entraînement, le test ne la suit donc pas directement.
        case reprise
    }

    struct Week {
        let start: Date
        let kind: WeekKind
        let planned: Prescription.Session
        /// Séances faites (jours d'entraînement : des séries espacées le même jour font une
        /// séance), et répétitions faites cette semaine.
        let done: Int
        let doneReps: Int
        /// Semaine finie, ou en cours.
        let isPast: Bool
        let isCurrent: Bool
        /// Semaine finie et refaite : pourquoi (« 1 séance », « aucune séance », « Forme basse × 2 »).
        let redoReason: String?

        /// Le prévu des séances faites : sans jours prévus, la semaine n'a pas de nombre de séances
        /// attendu ; on compare le fait aux cibles des séances faites.
        var plannedReps: Int { planned.total * done }
    }

    /// Un bloc : son début, le début de sa semaine allégée, son test (à partir de ce jour), et le
    /// début de sa semaine de reprise s'il y en a une (entre la fin de l'allégée et la reprise :
    /// une pause, pas de séance prévue).
    struct Block {
        let start: Date
        let deload: Date
        let test: Date
        var reprise: Date? = nil
    }

    struct Test {
        let date: Date
        let value: Int
        let block: Int
    }

    enum Today: Equatable {
        case session(Prescription.Session)
        case light(Prescription.Session)
        case deload(Prescription.Session)
        /// Semaine de reprise avant le test (séance allégée).
        case reprise(Prescription.Session)
        /// Plus de 28 jours sans séance : une séance libre, qui ouvre un nouveau bloc 1.
        case comeback
        case test
    }

    /// Aujourd'hui : une séance à faire, déjà faite, ou un repos conseillé (`restReason`).
    enum DayStatus: Equatable { case due, done, rest }

    /// Pourquoi l'app conseille un repos aujourd'hui (METHODE-JOURS.md, règle 3). Un repos est une
    /// proposition : une séance faite ce jour-là compte normalement.
    enum RestReason: Equatable {
        /// (a) La veille du test (choix de l'app ; Bosquet 2007, affûtage, par analogie).
        case beforeTest
        /// (b) Phase « Fatigue persistante » (Meeusen 2013).
        case persistentFatigue
        /// (c) La séance d'hier notée « Très difficile » (choix de l'app).
        case hardYesterday
        /// (d) 20 séries sur les 7 derniers jours (ACSM 2026, p. 864 : rendements décroissants
        /// au-delà de « ~18–20 weekly sets », établi pour l'hypertrophie).
        case weeklyVolume

        /// « test demain », « fatigue persistante », « séance d'hier très difficile », « 20 séries en 7 jours ».
        var short: String {
            switch self {
            case .beforeTest: return "test demain"
            case .persistentFatigue: return "fatigue persistante"
            case .hardYesterday: return "séance d'hier très difficile"
            case .weeklyVolume: return "\(TrainingPlan.weeklySetCap) séries en 7 jours"
            }
        }
    }

    /// « Effort ? » à partir duquel la séance compte comme « Très difficile » (échelle de Foster).
    static let hardEffort = 7
    /// Séries sur 7 jours au-delà desquelles un repos est conseillé.
    static let weeklySetCap = 20

    /// L'objectif (nil : retiré ; le plan continue en progression simple, ancré sur le max).
    let goal: Goal?
    /// Le début du plan (lundi de la semaine où il a commencé).
    let anchor: Date
    /// Le premier jour du plan : la semaine où il commence en cours de semaine n'exige qu'une séance.
    let firstDay: Date
    /// Les blocs, du premier au bloc en cours (bornes réelles), pour le graphique du chemin.
    let blocks: [Block]
    let block: Int
    let weeks: [Week]
    /// Le test du bloc en cours : à partir de ce jour.
    let testDate: Date
    /// Les tests faits, du plus ancien au plus récent.
    let tests: [Test]
    /// Semaines refaites depuis le début de l'objectif : la date de l'objectif recule d'autant.
    let shiftWeeks: Int
    /// La séance du jour (celle que « Démarrer quand même » lance un jour de repos conseillé).
    let today: Today
    let status: DayStatus
    /// La prochaine séance (après aujourd'hui) : le premier jour sans repos conseillé.
    let next: Date?
    /// La baisse habituelle d'une série à l'autre (nil : rapport par défaut).
    let ratios: [Double]?
    /// Le repos conseillé aujourd'hui (nil : pas un jour de repos).
    var restReason: RestReason? = nil
    /// Le repos conseillé demain, d'après les séances jusqu'à aujourd'hui (dit pourquoi la
    /// prochaine séance n'est pas demain).
    var tomorrowRest: RestReason? = nil
    /// Moins de 2 séances sur les 7 derniers jours, le plan ayant au moins une semaine (règle 6).
    var belowMinimum = false
    /// La séance du jour est faite, mais sous le total prévu : « fait · cible non atteinte »
    /// (décision de Vincent : une séance terminée est faite, la cible manquée est seulement notée).
    var targetMissed = false
    /// La part de la cible faite quand elle est manquée (0 à 99 %) : rater de peu n'est pas rater
    /// de beaucoup (avis de Vincent sur le cycle 3). Chaque série compte jusqu'à sa cible.
    var targetPercent: Int? = nil
    /// Le test est en retard : pas lancé le jour prévu, il reste « à faire » (le bloc suivant attend).
    var testOverdue = false
    /// Bloc 1 : « test 1 / 2 », les 2 tests de calibrage de la première semaine.
    var testStep: TestStep? = nil
    /// Bloc 1, première semaine : les 2 tests de départ (nil ailleurs, ou une fois faits).
    var startTests: StartTests? = nil
    /// Les jours de test passés sans test (le bloc suivant est reparti du dernier max).
    var missedTests: [Date] = []
    /// Un jour de test : la séance proposée si l'on ne lance pas le test (allégée en attendant).
    var fallback: Prescription.Session? = nil
    /// Le max qui dose les cibles aujourd'hui (le dernier test, relevé en cours de bloc).
    var currentMax: Int? = nil
    /// Le max relevé en cours de bloc (nil : pas relevé).
    var maxRaise: Int? = nil
    /// Pourquoi la séance du jour est légère, quand ce n'est pas la forme du jour (une décharge
    /// commencée depuis la carte État).
    var lightBecause: String? = nil

    struct TestStep: Equatable {
        let number: Int
        let of: Int
    }

    /// Les 2 tests de départ du bloc 1, pendant sa première semaine : combien sont faits, et le jour
    /// où le suivant est proposé (nil : plus de place cette semaine, les séances calent les cibles).
    struct StartTests: Equatable {
        let done: Int
        let next: Date?
    }

    /// Le test annoncé est entré dans l'app au premier lancement de cette version : les séances
    /// plus anciennes, sans rôle de série, gardent l'ancienne règle du test (première série > 0
    /// faite à partir du jour de test), pour que l'historique ne perde pas ses tests.
    static var announcedTestSince: Date {
        let key = "test.announcedSince"
        if let date = UserDefaults.standard.object(forKey: key) as? Date { return date }
        let now = Date()
        UserDefaults.standard.set(now, forKey: key)
        return now
    }
    /// Lecture d'un écart entre deux tests : sous ~10 %, « dans la variation » (provisoire,
    /// METHODE-TEST.md, règle 10 ; Hopkins pour le principe).
    static let testVariation = 0.10

    var currentWeek: Week? { weeks.first { $0.isCurrent } }
    /// Un test est prévu (pas pendant une reprise après une longue absence).
    var hasTest: Bool { today != .comeback }
    /// La date de l'objectif, décalée des semaines refaites.
    var shiftedGoalDate: Date? { goal?.date.map { $0.addingTimeInterval(Double(shiftWeeks) * 7 * 86_400) } }

    /// La séance prévue aujourd'hui (nil : jour de test, ou reprise libre après une longue absence).
    var todaySession: Prescription.Session? {
        switch today {
        case .session(let s), .light(let s), .deload(let s), .reprise(let s): return s
        case .test, .comeback: return nil
        }
    }

    /// Choix de l'app : sans séance depuis plus de 28 jours, le plan repart de zéro (nouveau bloc 1,
    /// ancré sur la séance de reprise) ; plus de 7 jours avant le test, une semaine de reprise.
    static let comebackDays = 28.0
    static let repriseDays = 7.0

    /// Le plan au jour `now`. Nil sans aucune séance de l'exercice pour caler la séance.
    /// - Parameters:
    ///   - sessions: séances de l'exercice (tout ordre).
    ///   - tired: les séances dont la Forme était dans la zone fatiguée.
    ///   - lowForm: Forme basse aujourd'hui (phase : surcharge, forme basse…) : séance légère.
    ///   - persistentFatigue: phase « Fatigue persistante » aujourd'hui : repos conseillé.
    static func make(goal: Goal?, anchor: Date, sessions: [SessionRecord], tired: Set<PersistentIdentifier>, lowForm: Bool,
                     persistentFatigue: Bool = false, legacyBefore: Date? = nil, now: Date = Date(),
                     calendar: Calendar = .current) -> TrainingPlan? {
        let sorted = sessions.filter { $0.start <= now }.sorted { $0.start < $1.start }
        let week = 7 * 86_400.0
        let day = 86_400.0
        func weekStart(_ date: Date) -> Date { Schedule.weekStart(date, calendar: calendar) }
        func inWeek(_ start: Date) -> [SessionRecord] { sorted.filter { $0.start >= start && $0.start < start.addingTimeInterval(week) } }
        func trainingDays(_ list: [SessionRecord]) -> Int { Set(list.map { calendar.startOfDay(for: $0.start) }).count }
        guard let last = sorted.last else { return nil }

        // Plus de 28 jours sans séance : la carte Aujourd'hui propose une séance de reprise
        // (le chemin et l'objectif restent visibles)
        if now.timeIntervalSince(last.start) > comebackDays * day {
            return TrainingPlan(goal: goal, anchor: weekStart(anchor), firstDay: calendar.startOfDay(for: now),
                                blocks: [], block: 1, weeks: [], testDate: now, tests: [],
                                shiftWeeks: 0, today: .comeback, status: .due, next: nil, ratios: nil)
        }
        // Une séance après plus de 28 jours sans séance ouvre un nouveau bloc 1, ancré sur elle
        var start0 = anchor
        var comeback: Date?
        for (before, after) in zip(sorted, sorted.dropFirst()) where after.start.timeIntervalSince(before.start) > comebackDays * day {
            start0 = max(start0, after.start)
            comeback = after.start
        }
        // Après une longue absence, rien d'avant le retour : le bloc 1 calibre sur les nouvelles séances
        let usable = comeback.map { cutoff in sorted.filter { $0.start >= cutoff } } ?? sorted
        let firstDay = calendar.startOfDay(for: start0)
        /// Le test : la meilleure série faite en mode test (test annoncé) ; nil sans test.
        func testValue(_ session: SessionRecord) -> Int? { session.testBest }
        /// Une séance d'avant le test annoncé (aucune série n'a de rôle) faite à partir de l'ancien
        /// jour de test : l'ancienne règle, sa première série > 0.
        func legacyValue(_ session: SessionRecord, from date: Date) -> Int? {
            guard let legacyBefore, session.start < legacyBefore, session.start >= date,
                  !session.orderedSets.contains(where: { $0.role != nil }) else { return nil }
            return session.orderedSets.first { $0.reps > 0 }?.reps
        }
        /// Les séances à faire au moins dans la semaine qui commence `start` : 2 (ACSM 2026) ; une
        /// seule la semaine où le plan commence en cours de semaine (choix de l'app).
        func required(inWeek start: Date) -> Int { start >= firstDay ? Prescription.minSessionsPerWeek : 1 }
        let today0 = calendar.startOfDay(for: now)
        func dayOffset(_ days: Int, from date: Date) -> Date { calendar.date(byAdding: .day, value: days, to: date) ?? date }
        /// Le repos conseillé le jour `day` (début du jour), d'après les séances d'avant ce jour
        /// (METHODE-JOURS.md, règle 3) ; nil : séance. La fatigue persistante est à part : elle
        /// n'est connue que pour aujourd'hui.
        func restReason(on day: Date, testDate: Date?) -> RestReason? {
            if let testDate, calendar.isDate(dayOffset(1, from: day), inSameDayAs: testDate) { return .beforeTest }
            let yesterday = dayOffset(-1, from: day)
            if sorted.contains(where: { calendar.isDate($0.start, inSameDayAs: yesterday) && ($0.effort ?? 0) >= hardEffort }) {
                return .hardYesterday
            }
            let from = dayOffset(-7, from: day)
            let sets = sorted.filter { $0.start >= from && $0.start < day }
                .reduce(0) { total, session in total + session.workSets.filter { $0.reps > 0 }.count }
            return sets >= weeklySetCap ? .weeklyVolume : nil
        }
        /// La prochaine séance après aujourd'hui : le premier jour sans repos conseillé.
        func nextDay(testDate: Date?) -> Date {
            (1...7).map { dayOffset($0, from: today0) }.first { restReason(on: $0, testDate: testDate) == nil }
                ?? dayOffset(1, from: today0)
        }
        /// Le statut du jour, le repos conseillé, la prochaine séance et le rappel du minimum.
        func dayPlan(_ today: Today, testDate: Date?)
            -> (status: DayStatus, rest: RestReason?, next: Date, belowMinimum: Bool, targetMissed: Int?,
                tomorrowRest: RestReason?) {
            let todaySessions = sorted.filter { calendar.isDate($0.start, inSameDayAs: now) }
            let todayReps = todaySessions.reduce(0) { $0 + $1.totalReps }
            let plannedToday: Int = {
                switch today {
                case .session(let s), .light(let s), .deload(let s), .reprise(let s): return s.total
                case .test, .comeback: return 1
                }
            }()
            // Un jour de test (du jour, à faire, ou de calibrage), seule la fatigue persistante
            // conseille un repos : l'effort d'une série max ne doit pas repousser le test suivant
            let reason: RestReason? = persistentFatigue ? .persistentFatigue
                : (today == .test ? nil : restReason(on: today0, testDate: testDate))
            let status: DayStatus
            if today == .test, todaySessions.contains(where: { testValue($0) != nil }) {
                status = .done
            } else if today != .test, !todaySessions.isEmpty {
                // Une séance terminée est faite, cible atteinte ou non (décision de Vincent)
                status = .done
            } else if !todaySessions.isEmpty || reason == nil {
                status = .due
            } else {
                status = .rest
            }
            let recent = sorted.filter { $0.start >= dayOffset(-6, from: today0) && $0.start <= now }
            // Le rappel du minimum, jamais un jour de repos conseillé ni une fois la séance faite
            let below = status == .due && today0 >= dayOffset(7, from: firstDay)
                && trainingDays(recent) < Prescription.minSessionsPerWeek
            // Cible manquée : d'après les cibles affichées par le compteur (réajustées en séance)
            // quand elles sont enregistrées, sinon d'après le total prévu ; une série prévue non
            // faite manque aussi
            let work = todaySessions.flatMap(\.workSets)
            let recorded = work.filter { $0.target != nil }
            let plannedSets: Int = {
                switch today {
                case .session(let s), .light(let s), .deload(let s), .reprise(let s): return s.sets
                case .test, .comeback: return 1
                }
            }()
            let short = recorded.isEmpty ? todayReps < plannedToday
                : recorded.contains { $0.reps < ($0.target ?? 0) } || work.count < plannedSets
            // La part faite : chaque série compte jusqu'à sa cible (une série au-dessus ne
            // rattrape pas une série manquée) ; 99 % au plus quand la cible est manquée
            let credited = recorded.isEmpty ? min(todayReps, plannedToday)
                : work.reduce(0) { $0 + min($1.reps, $1.target ?? $1.reps) }
            // Rapportée aux cibles affichées par le compteur, plus celles des séries prévues non faites
            let plannedTargets: [Int] = {
                switch today {
                case .session(let s), .light(let s), .deload(let s), .reprise(let s): return s.targets
                case .test, .comeback: return []
                }
            }()
            let base = recorded.isEmpty ? plannedToday
                : work.enumerated().reduce(0) { $0 + ($1.element.target ?? (($1.offset < plannedTargets.count) ? plannedTargets[$1.offset] : $1.element.reps)) }
                    + plannedTargets.dropFirst(work.count).reduce(0, +)
            let percent = min(99, Int((Double(credited) / Double(max(base, 1)) * 100).rounded(.down)))
            let missed: Int? = status == .done && today != .test && short ? percent : nil
            let tomorrow = restReason(on: dayOffset(1, from: today0), testDate: testDate)
            return (status, status == .rest ? reason : nil, nextDay(testDate: testDate), below, missed, tomorrow)
        }
        /// Les semaines d'attente du test (jours de retard, arrondis à la semaine supérieure) : la
        /// date de l'objectif recule d'autant.
        func waitingWeeks(from testDate: Date, to date: Date) -> Int {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: testDate), to: calendar.startOfDay(for: date)).day ?? 0
            return days > 0 ? Int((Double(days) / 7).rounded(.up)) : 0
        }
        /// La séance d'un max : série 1 = max − 3, puis la baisse habituelle.
        func session(for max: Int, _ habit: (session: Prescription.Session, ratios: [Double]?)) -> Prescription.Session {
            Prescription.Session(targets: Prescription.targets(first: Prescription.target(max: max), ratios: habit.ratios),
                                 rest: habit.session.rest)
        }

        var blockStart = weekStart(start0)
        var blocks: [Block] = []
        var block = 1
        var tests: [Test] = []
        var missedTests: [Date] = []
        var shift = 0
        /// Le max de référence : le dernier test (ou le meilleur des 2 tests de calibrage).
        var baseMax: Int?
        // Séances de semaines allégées, de reprise, de tests et d'attente du test : hors de la
        // séance habituelle
        var excluded = Set<PersistentIdentifier>()

        while true {
            // Bloc 1 (et nouveau bloc 1 après une longue absence) : 2 tests sur 2 jours de la
            // première semaine, le meilleur sert de départ (choix de l'app, METHODE-TEST.md, règle 7)
            var calibrationDays = 0
            var calibrationDates: [Date] = []
            if block == 1 {
                let calibration = inWeek(blockStart).filter { testValue($0) != nil }
                let days = Array(Set(calibration.map { calendar.startOfDay(for: $0.start) })).sorted().prefix(2)
                let kept = calibration.filter { days.contains(calendar.startOfDay(for: $0.start)) }
                calibrationDays = days.count
                calibrationDates = Array(days)
                kept.forEach { excluded.insert($0.persistentModelID) }
                if let best = kept.compactMap(testValue).max(), let first = kept.first {
                    tests.append(Test(date: first.start, value: best, block: 0))
                    baseMax = best
                }
            }
            let reference = usable.filter { !excluded.contains($0.persistentModelID) }
            // Sans séance avant le bloc (nouvel utilisateur, bloc de reprise) : la semaine 1 calibre,
            // les cibles suivent chaque séance ; à partir de la semaine 2, elles sont figées jusqu'au
            // test (choix de l'app)
            let calibrationEnd = blockStart.addingTimeInterval(week)
            guard let habit = Prescription.habitual(reference, before: blockStart, testMax: baseMax, calendar: calendar)
                    ?? Prescription.habitual(reference, before: min(now.addingTimeInterval(1), calibrationEnd), testMax: baseMax, calendar: calendar)
                    ?? Prescription.habitual(reference, before: now.addingTimeInterval(1), testMax: baseMax, calendar: calendar)
            else { return nil }
            // Le max du bloc ; il est relevé en cours de bloc par une série (ou un test fait en semaine
            // de progression) qui le dépasse : nouveau max = les répétitions faites, seules mesurées
            // (supposer des répétitions en réserve ne l'est pas : on se trompe d'environ 1 en les
            // estimant, Halperin et al. 2022 ; le test de fin de bloc mesure le reste). Choix de
            // l'app (METHODE-TEST.md). Les cibles suivent dès la séance suivante
            var currentMax = baseMax ?? (habit.session.targets.first ?? 1) + Prescription.repsInReserve
            var lastRaise: Int?
            func raise(from done: [SessionRecord]) {
                for session in done.sorted(by: { $0.start < $1.start }) {
                    if let tested = testValue(session) {
                        excluded.insert(session.persistentModelID)
                        if tested > currentMax { currentMax = tested; lastRaise = tested }
                        continue
                    }
                    // Un seul relèvement par séance : sa meilleure série (échauffement exclu)
                    let best = session.orderedSets.filter { !$0.isWarmup }.map(\.reps).max() ?? 0
                    if best > currentMax { currentMax = best; lastRaise = best }
                }
            }
            var weeks: [Week] = []
            var start = blockStart
            var progression = 0
            var repeats = 0
            var redo = false
            // Semaines de progression : une semaine finie où l'on a décroché est refaite
            while progression < Prescription.progressionWeeks {
                let planned = Prescription.progression(session(for: currentMax, habit), week: progression)
                let done = inWeek(start)
                let end = start.addingTimeInterval(week)
                let isPast = end <= now
                var reason: String?
                if isPast, repeats < Prescription.maxRepeats {
                    let count = trainingDays(done)
                    let tiredCount = done.filter { tired.contains($0.persistentModelID) }.count
                    let needed = required(inWeek: start)
                    if count < needed {
                        reason = count == 0 ? "aucune séance" : "\(count) séance sur \(needed) minimum"
                    } else if tiredCount >= 2 { reason = "forme basse à \(tiredCount) séances" }
                }
                weeks.append(Week(start: start, kind: .progression(progression, redo: redo), planned: planned,
                                  done: trainingDays(done),
                                  doneReps: done.reduce(0) { $0 + $1.totalReps }, isPast: isPast,
                                  isCurrent: start <= now && now < end, redoReason: reason))
                raise(from: done)
                start = end
                if reason != nil {
                    repeats += 1
                    shift += 1
                    redo = true
                } else {
                    progression += 1
                    redo = false
                }
            }
            let sessionNow = session(for: currentMax, habit)
            // Semaine allégée, puis le test
            let deload = Prescription.lighter(sessionNow)
            let deloadStart = start
            let deloadDone = inWeek(deloadStart)
            let deloadEnd = deloadStart.addingTimeInterval(week)
            weeks.append(Week(start: deloadStart, kind: .deload, planned: deload,
                              done: trainingDays(deloadDone), doneReps: deloadDone.reduce(0) { $0 + $1.totalReps },
                              isPast: deloadEnd <= now, isCurrent: deloadStart <= now && now < deloadEnd, redoReason: nil))
            // Jour de test : le lundi qui suit la semaine allégée (METHODE-JOURS.md, règle 7)
            var testDate = deloadEnd
            // Un test lancé dès la semaine allégée compte et clôt le bloc (règle 8)
            func closingValue(_ session: SessionRecord) -> Int? { testValue(session) ?? legacyValue(session, from: deloadEnd) }
            let firstTest = sorted.first { $0.start >= deloadStart && !excluded.contains($0.persistentModelID) && closingValue($0) != nil }
            deloadDone.filter { testValue($0) == nil }.forEach { excluded.insert($0.persistentModelID) }
            // Plus de 7 jours sans séance avant le test : une semaine de reprise d'abord, puis le
            // test (choix de l'app ; Bell 2023)
            var repriseToday = false
            var repriseStart: Date?
            let candidate = sorted.first { $0.start >= testDate }
            if let candidate, candidate.persistentModelID != firstTest?.persistentModelID,
               firstTest.map({ $0.start > candidate.start }) ?? true,
               let previous = sorted.last(where: { $0.start < candidate.start }),
               candidate.start.timeIntervalSince(previous.start) > repriseDays * day {
                let reprise = weekStart(candidate.start)
                let repriseEnd = reprise.addingTimeInterval(week)
                let repriseDone = inWeek(reprise).filter { testValue($0) == nil }
                repriseDone.forEach { excluded.insert($0.persistentModelID) }
                weeks.append(Week(start: reprise, kind: .reprise, planned: deload,
                                  done: trainingDays(repriseDone), doneReps: repriseDone.reduce(0) { $0 + $1.totalReps },
                                  isPast: repriseEnd <= now, isCurrent: reprise <= now && now < repriseEnd, redoReason: nil))
                repriseStart = reprise
                testDate = repriseEnd
            } else if firstTest == nil, now >= testDate, now.timeIntervalSince(last.start) > repriseDays * day {
                // Plus de 7 jours sans séance, même pendant l'attente du test : la reprise prime
                // Pas encore revenu : la reprise d'abord (cette semaine), le test ensuite ; jamais de
                // test à une date passée
                repriseToday = true
                let reprise = weekStart(now)
                weeks.append(Week(start: reprise, kind: .reprise, planned: deload,
                                  done: 0, doneReps: 0, isPast: false, isCurrent: true, redoReason: nil))
                repriseStart = reprise
                testDate = reprise.addingTimeInterval(week)
            }
            blocks.append(Block(start: weeks.first?.start ?? blockStart, deload: deloadStart, test: testDate, reprise: repriseStart))
            // En attendant le test, les séances comptent comme séances, mais ni comme test ni comme
            // séance habituelle (règle 10)
            // L'attente s'arrête au test, ou 7 jours après le jour prévu (le bloc suivant repart)
            let waitingEnd = firstTest?.start ?? min(now.addingTimeInterval(1), testDate.addingTimeInterval(repriseDays * day))
            sorted.filter { $0.start >= testDate && $0.start < waitingEnd && testValue($0) == nil }
                .forEach { excluded.insert($0.persistentModelID) }

            if let firstTest {
                // Test fait : le meilleur entre le premier test et le début du bloc suivant (la
                // semaine d'après) ; il recale le niveau (ACSM 2026, p. 863)
                let next = weekStart(firstTest.start).addingTimeInterval(week)
                let window = sorted.filter { $0.start >= firstTest.start && $0.start < next && closingValue($0) != nil }
                window.forEach { excluded.insert($0.persistentModelID) }
                let value = window.compactMap(closingValue).max() ?? closingValue(firstTest) ?? currentMax
                tests.append(Test(date: firstTest.start, value: value, block: block))
                shift += waitingWeeks(from: testDate, to: firstTest.start)
                baseMax = value
                blockStart = next
                block += 1
                if blockStart <= now { continue }
                // Le bloc suivant commence la semaine prochaine : jusque-là, la séance de son nouveau
                // max, au jour le jour
                let reference = usable.filter { !excluded.contains($0.persistentModelID) }
                let fresh = Prescription.habitual(reference, before: now.addingTimeInterval(1), testMax: value, calendar: calendar) ?? habit
                let today = Today.session(fresh.session)
                let d = dayPlan(today, testDate: nil)
                return TrainingPlan(goal: goal, anchor: weekStart(start0), firstDay: firstDay, blocks: blocks, block: block - 1, weeks: weeks,
                                    testDate: testDate, tests: tests, shiftWeeks: shift, today: today, status: d.status,
                                    next: d.next, ratios: fresh.ratios, restReason: d.rest, tomorrowRest: d.tomorrowRest, belowMinimum: d.belowMinimum, targetMissed: d.targetMissed != nil, targetPercent: d.targetMissed,
                                    missedTests: missedTests, currentMax: value)
            }
            // Test pas lancé 7 jours après le jour prévu, alors qu'on s'entraîne : le bloc suivant
            // repart du dernier max, sans recalage (règle 10, choix de l'app)
            let giveUp = testDate.addingTimeInterval(repriseDays * day)
            if !repriseToday, now >= giveUp {
                missedTests.append(testDate)
                shift += 1
                let monday = weekStart(giveUp)
                blockStart = monday == giveUp ? giveUp : monday.addingTimeInterval(week)
                baseMax = currentMax
                block += 1
                if blockStart <= now { continue }
                let today = Today.session(sessionNow)
                let d = dayPlan(today, testDate: nil)
                return TrainingPlan(goal: goal, anchor: weekStart(start0), firstDay: firstDay, blocks: blocks, block: block - 1, weeks: weeks,
                                    testDate: testDate, tests: tests, shiftWeeks: shift, today: today, status: d.status,
                                    next: d.next, ratios: habit.ratios, restReason: d.rest, tomorrowRest: d.tomorrowRest, belowMinimum: d.belowMinimum, targetMissed: d.targetMissed != nil, targetPercent: d.targetMissed,
                                    missedTests: missedTests, currentMax: currentMax)
            }
            let current = weeks.last { $0.isCurrent }
            let today: Today
            var testStep: TestStep?
            let todaySessions = sorted.filter { calendar.isDate($0.start, inSameDayAs: now) }
            let testedToday = todaySessions.contains { testValue($0) != nil }
            // Les 2 tests de départ (bloc 1, 1re semaine) : le 1er au plus tard le vendredi, le 2e
            // 2 jours après le 1er, dans la même semaine ; sinon la semaine calibre sur les séances
            // (choix de l'app : jamais de test de départ en fin de semaine, sans annonce)
            var startTests: StartTests?
            if block == 1, current?.kind == .progression(0, redo: false) {
                let weekEnd = dayOffset(7, from: blockStart)
                // Le premier jour encore libre : aujourd'hui sans séance, sinon demain
                let free = todaySessions.isEmpty ? max(today0, firstDay) : dayOffset(1, from: today0)
                var next: Date?
                if calibrationDays == 0 {
                    next = free <= dayOffset(-3, from: weekEnd) ? free : nil
                } else if calibrationDays == 1, let first = calibrationDates.first {
                    let second = max(dayOffset(2, from: first), free)
                    next = second < weekEnd ? second : nil
                }
                startTests = StartTests(done: calibrationDays, next: next)
            }
            let calibrationToday = testedToday || (todaySessions.isEmpty && (startTests?.next.map { $0 <= today0 } ?? false))
            if repriseToday || current?.kind == .reprise {
                today = .reprise(deload)
            } else if now >= testDate {
                today = .test
            } else if current?.kind == .deload {
                today = .deload(deload)
            } else if let start = startTests, start.done < 2 || testedToday, calibrationToday {
                // Bloc 1, première semaine : les 2 tests de départ
                today = .test
                testStep = TestStep(number: calibrationDays + (testedToday ? 0 : 1), of: 2)
            } else if lowForm || persistentFatigue, current != nil {
                // Forme basse, ou fatigue persistante si l'on s'entraîne quand même : séance légère
                today = .light(Prescription.lighter(sessionNow))
            } else {
                today = .session(sessionNow)
            }
            let overdue = today == .test && testStep == nil && calendar.startOfDay(for: now) > calendar.startOfDay(for: testDate)
            if overdue { shift += waitingWeeks(from: testDate, to: now) }
            let d = dayPlan(today, testDate: testDate)
            return TrainingPlan(goal: goal, anchor: weekStart(start0), firstDay: firstDay, blocks: blocks, block: block, weeks: weeks,
                                testDate: testDate, tests: tests, shiftWeeks: shift, today: today, status: d.status, next: d.next,
                                ratios: habit.ratios, restReason: d.rest, tomorrowRest: d.tomorrowRest, belowMinimum: d.belowMinimum, targetMissed: d.targetMissed != nil, targetPercent: d.targetMissed,
                                testOverdue: overdue, testStep: testStep, startTests: startTests, missedTests: missedTests,
                                fallback: today == .test ? (testStep == nil ? deload : sessionNow) : nil,
                                currentMax: currentMax, maxRaise: lastRaise)
        }
    }
}

// MARK: - La semaine

/// Le calendrier des semaines (du lundi au dimanche). Pas de jours prévus : chaque jour, l'app
/// propose une séance ou un repos (METHODE-JOURS.md).
enum Schedule {
    /// Le lundi de la semaine.
    static func weekStart(_ date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -(isoWeekday(day, calendar: calendar) - 1), to: day) ?? day
    }

    /// 1 = lundi … 7 = dimanche.
    static func isoWeekday(_ date: Date, calendar: Calendar) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }

    /// Les jours choisis des anciennes versions (« ✎ jours ») ne servent plus : effacés.
    static func forgetSavedDays() {
        for exercise in Exercise.allCases { UserDefaults.standard.removeObject(forKey: "coaching.days.\(exercise.rawValue)") }
    }
}

// MARK: - Mesuré face à attendu

extension TrainingPlan {
    /// L'attendu à une date : le rythme nécessaire pour aller du départ à l'objectif à la date
    /// choisie (décalée des semaines refaites). Ce n'est pas une prédiction. Nil sans date.
    func expected(at date: Date) -> Double? {
        guard let goal, let end = shiftedGoalDate, end > goal.created else { return nil }
        let share = date.timeIntervalSince(goal.created) / end.timeIntervalSince(goal.created)
        return Double(goal.start) + Double(goal.target - goal.start) * share
    }

    enum Verdict: Equatable { case pending(Int), ahead, onTrack, behind }

    /// En avance ou en retard, seulement quand c'est établi : pente de Theil-Sen des tests et
    /// son intervalle à 99 % (Sen 1968, comme `ProgressVerdict`), comparés au rythme nécessaire.
    /// Il faut 3 tests ; sans date d'objectif, pas de rythme nécessaire.
    var verdict: Verdict? {
        guard let goal, let end = shiftedGoalDate else { return nil }
        guard tests.count >= Self.minTests else { return .pending(tests.count) }
        let x = tests.map { $0.date.timeIntervalSince(goal.created) / 86_400 }
        let y = tests.map { Double($0.value) }
        guard let fit = ProgressVerdict.theilSen(x, y) else { return .pending(tests.count) }
        let required = Double(goal.target - goal.start) / max(end.timeIntervalSince(goal.created) / 86_400, 1)
        if fit.low > required { return .ahead }
        if fit.high < required { return .behind }
        return .onTrack
    }

    /// Projection : la date où la tendance des tests (pente de Theil-Sen) atteint l'objectif.
    var projection: Date? {
        guard let goal, tests.count >= Self.minTests, let last = tests.last else { return nil }
        let x = tests.map { $0.date.timeIntervalSince(goal.created) / 86_400 }
        let y = tests.map { Double($0.value) }
        guard let fit = ProgressVerdict.theilSen(x, y), fit.slope > 0 else { return nil }
        let days = Double(goal.target - last.value) / fit.slope
        return days <= 0 ? last.date : last.date.addingTimeInterval(days * 86_400)
    }

    static let minTests = 3

    /// La prochaine séance (après aujourd'hui) : celle de sa semaine (progression ou allégée),
    /// le test, ou, au-delà du bloc, la séance du jour.
    var upcoming: Today {
        guard let next else { return today }
        // Bloc 1 : le test 1 / 2 fait, le 2e est proposé les jours suivants de la première semaine
        if let step = testStep, step.number < step.of, let week = currentWeek,
           next < week.start.addingTimeInterval(7 * 86_400) { return .test }
        // Le test du bloc déjà fait : la prochaine séance ouvre le bloc suivant
        let tested = tests.last.map { $0.date >= testDate } ?? false
        if tested { return today }
        if next >= testDate { return .test }
        if let week = weeks.first(where: { $0.start <= next && next < $0.start.addingTimeInterval(7 * 86_400) }) {
            switch week.kind {
            case .deload: return .deload(week.planned)
            case .reprise: return .reprise(week.planned)
            case .progression: return .session(week.planned)
            }
        }
        return today
    }
}

extension HistoryStats {
    /// Le plan de l'exercice de ces statistiques, avec ou sans objectif : sans objectif, il
    /// démarre de lui-même sur la séance habituelle, dès qu'elle se calcule (l'ancre est posée
    /// ce jour-là). Jamais nil pour un exercice qui a un historique, sauf « Autre exercice ».
    /// `all` : toutes les séances (pour la phase, qui dit si la Forme est basse aujourd'hui).
    func plan(all: [SessionRecord]) -> TrainingPlan? {
        // « Autre exercice » mêle des mouvements : pas de plan, et un objectif déjà enregistré est ignoré
        guard let exercise = sessions.first?.exercise, exercise != .auto else { return nil }
        let goal = Goal.load(exercise)
        if goal == nil, PlanAnchor.load(exercise) == nil,
           Prescription.habitual(sessions, before: now.addingTimeInterval(1), calendar: calendar) != nil {
            PlanAnchor.setIfNeeded(now, for: exercise)
        }
        guard let anchor = goal?.created ?? PlanAnchor.load(exercise) else { return nil }
        // Forme basse : seulement sur un comptage fiable (sinon la carte État dit « comptage à fiabiliser »)
        let tired = countingIsReliable
            ? Set(formResults.filter { $0.result.zone == .tired }.map { $0.session.persistentModelID }) : []
        let kind = phase(all: all).kind
        // Une décharge commencée (carte État) allège aussi les séances du plan : les deux écrans
        // disent la même chose
        let lowForm = [.lowForm, .overreaching, .deloadAdvised, .deload].contains(kind)
        var plan = TrainingPlan.make(goal: goal, anchor: anchor, sessions: sessions, tired: tired, lowForm: lowForm,
                                     persistentFatigue: kind == .persistentFatigue,
                                     legacyBefore: TrainingPlan.announcedTestSince, now: now, calendar: calendar)
        if kind == .deload {
            plan?.lightBecause = "Décharge en cours : séance légère."
        } else if kind == .deloadAdvised {
            plan?.lightBecause = "Décharge conseillée : séance légère."
        }
        return plan
    }
}

/// Le début du plan d'un exercice : fixé avec le premier objectif, gardé quand on le retire (le
/// plan continue alors en progression simple, ancré sur le max).
enum PlanAnchor {
    private static func key(_ exercise: Exercise) -> String { "coaching.planStart.\(exercise.rawValue)" }

    static func load(_ exercise: Exercise) -> Date? {
        UserDefaults.standard.object(forKey: key(exercise)) as? Date
    }

    static func setIfNeeded(_ date: Date, for exercise: Exercise) {
        if load(exercise) == nil { UserDefaults.standard.set(date, forKey: key(exercise)) }
    }
}

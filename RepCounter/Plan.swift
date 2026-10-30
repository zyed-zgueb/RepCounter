import Foundation
import SwiftData

/// Le plan d'un exercice, déduit de l'objectif et des séances faites (rien n'est stocké d'autre
/// que l'objectif et, si on les déplace, les jours de séance) : des blocs de 3 semaines de
/// progression, 1 semaine allégée, puis un test (une série max). Le bloc suivant repart du test.
/// Une semaine de progression où l'on décroche (séances manquées, ou Forme basse deux fois) est
/// refaite : le test est décalé d'autant. Les séances sont placées dans la semaine (`Schedule`).
/// Les paramètres de séance viennent tous de `Prescription`.
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
        let plannedSessions: Int
        /// Séances faites (jours d'entraînement : des séries espacées le même jour font une
        /// séance), et répétitions faites cette semaine.
        let done: Int
        let doneReps: Int
        /// Semaine finie, ou en cours.
        let isPast: Bool
        let isCurrent: Bool
        /// Semaine finie et refaite : pourquoi (« 2 séances manquées », « Forme basse × 2 »).
        let redoReason: String?

        var plannedReps: Int { planned.total * plannedSessions }
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

    /// Aujourd'hui dans la semaine : une séance à faire (prévue, ou en retard), déjà faite, ou
    /// un jour de repos.
    enum DayStatus: Equatable { case due, done, rest }

    /// Un jour de la semaine en cours (Coaching).
    struct Day {
        let date: Date
        let planned: Bool
        /// Séances faites ce jour-là (2 ou plus : séries espacées).
        let sessions: Int
        let missed: Bool
        let isToday: Bool
    }

    /// L'objectif (nil : retiré ; le plan continue en progression simple, ancré sur le max).
    let goal: Goal?
    /// Le début du plan (lundi de la semaine où il a commencé).
    let anchor: Date
    /// Le premier jour du plan : les jours prévus avant lui (même semaine) ne comptent pas.
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
    /// La séance du jour (ou de la prochaine séance, un jour de repos).
    let today: Today
    let status: DayStatus
    /// La prochaine séance prévue (après aujourd'hui).
    let next: Date?
    /// La semaine en cours, jour par jour.
    let days: [Day]
    /// La baisse habituelle d'une série à l'autre (nil : rapport par défaut).
    let ratios: [Double]?
    let perWeek: Int
    /// Le test est en retard : pas lancé le jour prévu, il reste « à faire » (le bloc suivant attend).
    var testOverdue = false
    /// Bloc 1 : « test 1 / 2 », les 2 tests de calibrage de la première semaine.
    var testStep: TestStep? = nil
    /// Les jours de test passés sans test (le bloc suivant est reparti du dernier max).
    var missedTests: [Date] = []
    /// Un jour de test : la séance proposée si l'on ne lance pas le test (allégée en attendant).
    var fallback: Prescription.Session? = nil
    /// Le max qui dose les cibles aujourd'hui (le dernier test, relevé en cours de bloc).
    var currentMax: Int? = nil
    /// Le max relevé en cours de bloc (nil : pas relevé).
    var maxRaise: Int? = nil
    /// Les jours enregistrés ne correspondaient pas au nombre de séances par semaine : ignorés.
    var daysReset = false

    struct TestStep: Equatable {
        let number: Int
        let of: Int
    }

    /// Une série au moins 3 au-dessus de sa cible relève le max (choix de l'app, audit point 3).
    static let raiseMargin = 3
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
    ///   - weekdays: jours de séance choisis (1 = lundi … 7 = dimanche) ; nil : placés par l'app.
    static func make(goal: Goal?, anchor: Date, sessions: [SessionRecord], tired: Set<PersistentIdentifier>, lowForm: Bool,
                     weekdays: [Int]? = nil, now: Date = Date(), calendar: Calendar = .current) -> TrainingPlan? {
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
                                shiftWeeks: 0, today: .comeback, status: .due, next: nil, days: [], ratios: nil,
                                perWeek: Prescription.minSessionsPerWeek)
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
        /// Séances prévues dans la semaine qui commence `start` : les jours avant le début du plan
        /// ne comptent pas.
        func plannedDays(_ days: [Int], inWeek start: Date) -> [Int] {
            days.filter { (calendar.date(byAdding: .day, value: $0 - 1, to: start) ?? start) >= firstDay }
        }
        /// Le test : la meilleure série faite en mode test (test annoncé) ; nil sans test.
        func testValue(_ session: SessionRecord) -> Int? { session.testBest }
        /// Le premier jour de séance prévu à partir de `date` (même semaine, sinon la suivante).
        func plannedDay(onOrAfter date: Date, _ days: [Int]) -> Date {
            let day0 = calendar.startOfDay(for: date)
            let monday = weekStart(day0)
            if let inWeek = days.compactMap({ calendar.date(byAdding: .day, value: $0 - 1, to: monday) }).first(where: { $0 >= day0 }) {
                return inWeek
            }
            return Schedule.firstDay(days, inWeekOf: monday.addingTimeInterval(week), calendar: calendar) ?? day0
        }
        /// Les semaines d'attente du test (jours de retard, arrondis à la semaine supérieure) : la
        /// date de l'objectif recule d'autant.
        func waitingWeeks(from testDate: Date, to date: Date) -> Int {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: testDate), to: calendar.startOfDay(for: date)).day ?? 0
            return days > 0 ? Int((Double(days) / 7).rounded(.up)) : 0
        }
        /// La séance d'un max : série 1 = max − 3, puis la baisse habituelle.
        func session(for max: Int, _ habit: (session: Prescription.Session, ratios: [Double]?, perWeek: Int)) -> Prescription.Session {
            Prescription.Session(targets: Prescription.targets(first: Prescription.target(max: max), ratios: habit.ratios),
                                 rest: habit.session.rest)
        }

        var blockStart = weekStart(start0)
        var daysReset = false
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
            if block == 1 {
                let calibration = inWeek(blockStart).filter { testValue($0) != nil }
                let days = Array(Set(calibration.map { calendar.startOfDay(for: $0.start) })).sorted().prefix(2)
                let kept = calibration.filter { days.contains(calendar.startOfDay(for: $0.start)) }
                calibrationDays = days.count
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
            // Les jours choisis doivent correspondre au nombre de séances par semaine du plan ; sinon
            // ils sont ignorés (jours proposés), et la vue le signale une fois
            let chosen = weekdays.map(Schedule.days)
            if let chosen, chosen.count != habit.perWeek { daysReset = true }
            let days = chosen.flatMap { $0.count == habit.perWeek ? $0 : nil } ?? Schedule.defaultWeekdays(habit.perWeek)
            let perWeek = days.count
            // Le max du bloc ; il est relevé en cours de bloc par une série ≥ 3 au-dessus de sa cible,
            // ou un test fait en semaine de progression qui le dépasse (règle 13, choix de l'app) :
            // les cibles suivent dès la séance suivante
            var currentMax = baseMax ?? (habit.session.targets.first ?? 1) + Prescription.repsInReserve
            var lastRaise: Int?
            func raise(from done: [SessionRecord]) {
                for session in done.sorted(by: { $0.start < $1.start }) {
                    if let tested = testValue(session) {
                        excluded.insert(session.persistentModelID)
                        if tested > currentMax { currentMax = tested; lastRaise = tested }
                        continue
                    }
                    for set in session.orderedSets {
                        guard let target = set.target, !set.isWarmup, set.reps - target >= raiseMargin else { continue }
                        let raised = currentMax + (set.reps - target)
                        if raised > currentMax { currentMax = raised; lastRaise = raised }
                    }
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
                    let missed = plannedDays(days, inWeek: start).count - trainingDays(done)
                    let tiredCount = done.filter { tired.contains($0.persistentModelID) }.count
                    if missed > 0 { reason = missed == 1 ? "1 séance manquée" : "\(missed) séances manquées" }
                    else if tiredCount >= 2 { reason = "Forme basse × \(tiredCount)" }
                }
                weeks.append(Week(start: start, kind: .progression(progression, redo: redo), planned: planned,
                                  plannedSessions: perWeek, done: trainingDays(done),
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
            weeks.append(Week(start: deloadStart, kind: .deload, planned: deload, plannedSessions: perWeek,
                              done: trainingDays(deloadDone), doneReps: deloadDone.reduce(0) { $0 + $1.totalReps },
                              isPast: deloadEnd <= now, isCurrent: deloadStart <= now && now < deloadEnd, redoReason: nil))
            // Jour de test : le premier jour de séance prévu après la semaine allégée (règle 2)
            var testDate = plannedDay(onOrAfter: deloadEnd, days)
            // Un test lancé dès la semaine allégée compte et clôt le bloc (règle 8)
            let firstTest = sorted.first { $0.start >= deloadStart && !excluded.contains($0.persistentModelID) && testValue($0) != nil }
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
                weeks.append(Week(start: reprise, kind: .reprise, planned: deload, plannedSessions: perWeek,
                                  done: trainingDays(repriseDone), doneReps: repriseDone.reduce(0) { $0 + $1.totalReps },
                                  isPast: repriseEnd <= now, isCurrent: reprise <= now && now < repriseEnd, redoReason: nil))
                repriseStart = reprise
                testDate = plannedDay(onOrAfter: repriseEnd, days)
            } else if firstTest == nil, candidate == nil, now >= testDate, now.timeIntervalSince(last.start) > repriseDays * day {
                // Pas encore revenu : la reprise d'abord (cette semaine), le test ensuite ; jamais de
                // test à une date passée
                repriseToday = true
                let reprise = weekStart(now)
                weeks.append(Week(start: reprise, kind: .reprise, planned: deload, plannedSessions: perWeek,
                                  done: 0, doneReps: 0, isPast: false, isCurrent: true, redoReason: nil))
                repriseStart = reprise
                testDate = plannedDay(onOrAfter: reprise.addingTimeInterval(week), days)
            }
            blocks.append(Block(start: weeks.first?.start ?? blockStart, deload: deloadStart, test: testDate, reprise: repriseStart))
            // En attendant le test, les séances comptent comme séances, mais ni comme test ni comme
            // séance habituelle (règle 10)
            let waitingEnd = firstTest?.start ?? now.addingTimeInterval(1)
            sorted.filter { $0.start >= testDate && $0.start < waitingEnd && testValue($0) == nil }
                .forEach { excluded.insert($0.persistentModelID) }

            if let firstTest {
                // Test fait : le meilleur entre le premier test et le début du bloc suivant (la
                // semaine d'après) ; il recale le niveau (ACSM 2026, p. 863)
                let next = weekStart(firstTest.start).addingTimeInterval(week)
                let window = sorted.filter { $0.start >= firstTest.start && $0.start < next && testValue($0) != nil }
                window.forEach { excluded.insert($0.persistentModelID) }
                let value = window.compactMap(testValue).max() ?? testValue(firstTest) ?? currentMax
                tests.append(Test(date: firstTest.start, value: value, block: block))
                shift += waitingWeeks(from: testDate, to: firstTest.start)
                baseMax = value
                blockStart = next
                block += 1
                if blockStart <= now { continue }
                // Le bloc suivant commence la semaine prochaine : jusque-là, repos. Ses cibles partent
                // déjà du nouveau max
                let reference = usable.filter { !excluded.contains($0.persistentModelID) }
                let fresh = Prescription.habitual(reference, before: now.addingTimeInterval(1), testMax: value, calendar: calendar) ?? habit
                return TrainingPlan(goal: goal, anchor: weekStart(start0), firstDay: firstDay, blocks: blocks, block: block - 1, weeks: weeks,
                                    testDate: testDate, tests: tests, shiftWeeks: shift, today: .session(fresh.session), status: .rest,
                                    next: Schedule.firstDay(days, inWeekOf: blockStart, calendar: calendar), days: [],
                                    ratios: fresh.ratios, perWeek: perWeek, missedTests: missedTests, currentMax: value, daysReset: daysReset)
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
                return TrainingPlan(goal: goal, anchor: weekStart(start0), firstDay: firstDay, blocks: blocks, block: block - 1, weeks: weeks,
                                    testDate: testDate, tests: tests, shiftWeeks: shift, today: .session(sessionNow), status: .rest,
                                    next: Schedule.firstDay(days, inWeekOf: blockStart, calendar: calendar), days: [],
                                    ratios: habit.ratios, perWeek: perWeek, missedTests: missedTests, currentMax: currentMax, daysReset: daysReset)
            }
            let current = weeks.last { $0.isCurrent }
            let today: Today
            var testStep: TestStep?
            let thisWeek = weekStart(now)
            let schedule = Schedule.week(plannedDays(days, inWeek: thisWeek), start: thisWeek, sessions: inWeek(thisWeek), now: now, calendar: calendar)
            let todaySessions = sorted.filter { calendar.isDate($0.start, inSameDayAs: now) }
            if repriseToday || current?.kind == .reprise {
                today = .reprise(deload)
            } else if now >= testDate {
                today = .test
            } else if current?.kind == .deload {
                today = .deload(deload)
            } else if block == 1, current?.kind == .progression(0, redo: false), calibrationDays < 2,
                      todaySessions.isEmpty ? schedule.due : todaySessions.contains(where: { testValue($0) != nil }) {
                // Bloc 1, première semaine : les 2 tests de calibrage
                today = .test
                testStep = TestStep(number: calibrationDays + (todaySessions.contains { testValue($0) != nil } ? 0 : 1), of: 2)
            } else if lowForm, current != nil {
                today = .light(Prescription.lighter(sessionNow))
            } else {
                today = .session(sessionNow)
            }
            // Aujourd'hui dans la semaine
            let todayReps = todaySessions.reduce(0) { $0 + $1.totalReps }
            let plannedToday: Int = {
                switch today {
                case .session(let s), .light(let s), .deload(let s), .reprise(let s): return s.total
                case .test, .comeback: return 1
                }
            }()
            let testDoneToday = todaySessions.contains { testValue($0) != nil }
            let overdue = today == .test && testStep == nil && calendar.startOfDay(for: now) > calendar.startOfDay(for: testDate)
            if overdue { shift += waitingWeeks(from: testDate, to: now) }
            let status: DayStatus
            if today == .test {
                // Le test : fait aujourd'hui, à faire un jour de séance (prévu, ou en retard), sinon repos
                status = testDoneToday ? .done
                    : (calendar.isDate(now, inSameDayAs: testDate) || schedule.due || !todaySessions.isEmpty ? .due : .rest)
            } else if !todaySessions.isEmpty, todayReps >= plannedToday {
                status = .done
            } else if repriseToday || !todaySessions.isEmpty || schedule.due {
                status = .due
            } else {
                status = .rest
            }
            var next = schedule.next
            if next == nil {
                // Rien de plus cette semaine : la première séance de la semaine prochaine
                let nextWeek = thisWeek.addingTimeInterval(week)
                next = nextWeek >= testDate ? max(testDate, nextWeek) : Schedule.firstDay(days, inWeekOf: nextWeek, calendar: calendar)
            }
            return TrainingPlan(goal: goal, anchor: weekStart(start0), firstDay: firstDay, blocks: blocks, block: block, weeks: weeks,
                                testDate: testDate, tests: tests, shiftWeeks: shift, today: today, status: status, next: next,
                                days: schedule.days, ratios: habit.ratios, perWeek: perWeek,
                                testOverdue: overdue, testStep: testStep, missedTests: missedTests,
                                fallback: today == .test ? (testStep == nil ? deload : sessionNow) : nil,
                                currentMax: currentMax, maxRaise: lastRaise, daysReset: daysReset)
        }
    }
}

// MARK: - Les séances dans la semaine

/// Le placement des séances dans la semaine : espacées régulièrement (2 → lundi et jeudi ;
/// 3 → lundi, mercredi, vendredi), déplaçables dans le Coaching. L'ACSM 2026 demande au moins
/// 2 séances par semaine sans fixer l'espacement : ce placement est un choix de l'app.
/// Une séance faite un jour non prévu compte, et remplace la prochaine prévue.
enum Schedule {
    /// Jours (1 = lundi … 7 = dimanche) pour `count` séances par semaine.
    static func defaultWeekdays(_ count: Int) -> [Int] {
        switch count {
        case ...1: return [1]
        case 2: return [1, 4]
        case 3: return [1, 3, 5]
        case 4: return [1, 2, 4, 5]
        case 5: return [1, 2, 3, 4, 5]
        case 6: return [1, 2, 3, 4, 5, 6]
        default: return [1, 2, 3, 4, 5, 6, 7]
        }
    }

    private static func key(_ exercise: Exercise) -> String { "coaching.days.\(exercise.rawValue)" }

    /// Les jours choisis pour un exercice (nil : placés par l'app).
    static func saved(_ exercise: Exercise) -> [Int]? {
        let days = UserDefaults.standard.array(forKey: key(exercise)) as? [Int]
        return days.flatMap { $0.count >= Prescription.minSessionsPerWeek ? $0 : nil }
    }

    static func save(_ days: [Int]?, for exercise: Exercise) {
        if let days { UserDefaults.standard.set(days.sorted(), forKey: key(exercise)) }
        else { UserDefaults.standard.removeObject(forKey: key(exercise)) }
    }

    static func days(_ weekdays: [Int]) -> [Int] { Array(Set(weekdays.filter { (1...7).contains($0) })).sorted() }

    private static func resetKey(_ exercise: Exercise) -> String { "coaching.daysReset.\(exercise.rawValue)" }

    /// Les jours enregistrés ont été réinitialisés : à signaler une fois.
    static func noteReset(_ exercise: Exercise) {
        UserDefaults.standard.set(true, forKey: resetKey(exercise))
    }

    /// Lit et efface l'avis de réinitialisation (affiché une seule fois).
    static func takeResetNotice(_ exercise: Exercise) -> Bool {
        let pending = UserDefaults.standard.bool(forKey: resetKey(exercise))
        if pending { UserDefaults.standard.removeObject(forKey: resetKey(exercise)) }
        return pending
    }

    /// Le lundi de la semaine.
    static func weekStart(_ date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -(isoWeekday(day, calendar: calendar) - 1), to: day) ?? day
    }

    /// 1 = lundi … 7 = dimanche.
    static func isoWeekday(_ date: Date, calendar: Calendar) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }

    static func firstDay(_ days: [Int], inWeekOf start: Date, calendar: Calendar) -> Date? {
        days.first.flatMap { calendar.date(byAdding: .day, value: $0 - 1, to: weekStart(start, calendar: calendar)) }
    }

    /// La semaine qui commence `start` : les jours, une séance à faire aujourd'hui (`due`), la
    /// prochaine séance après aujourd'hui. Les jours d'entraînement consomment les jours prévus
    /// dans l'ordre : une séance faite un jour non prévu remplace la prochaine prévue.
    static func week(_ days: [Int], start: Date, sessions: [SessionRecord], now: Date, calendar: Calendar)
        -> (days: [TrainingPlan.Day], due: Bool, next: Date?) {
        let today = calendar.startOfDay(for: now)
        let trained = Set(sessions.map { calendar.startOfDay(for: $0.start) })
        let planned = days.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: start) }
        let done = trained.count
        let remaining = Array(planned.dropFirst(done))
        let trainedToday = trained.contains(today)
        // Une séance prévue aujourd'hui, ou en retard cette semaine (pas encore rattrapée)
        let due = !trainedToday && remaining.contains { $0 <= today }
        // La prochaine : le premier jour prévu restant après aujourd'hui (la séance du jour, faite
        // ou à faire, consomme le jour prévu le plus ancien)
        let next = remaining.filter { $0 > today }.first
        // Jours manqués : les jours prévus passés au-delà de ceux consommés
        let missed = Set(remaining.filter { $0 < today })
        let list = (0..<7).compactMap { offset -> TrainingPlan.Day? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return TrainingPlan.Day(date: date, planned: days.contains(offset + 1),
                                    sessions: sessions.filter { calendar.isDate($0.start, inSameDayAs: date) }.count,
                                    missed: missed.contains(date), isToday: date == today)
        }
        return (list, due, next)
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
        let lowForm = [.lowForm, .overreaching, .deloadAdvised, .persistentFatigue].contains(phase(all: all).kind)
        let plan = TrainingPlan.make(goal: goal, anchor: anchor, sessions: sessions, tired: tired, lowForm: lowForm,
                                     weekdays: Schedule.saved(exercise), now: now, calendar: calendar)
        if plan?.daysReset == true {
            // Jours incohérents (3 jours pour 4 séances…) : retour aux jours proposés, signalé une fois
            Schedule.save(nil, for: exercise)
            Schedule.noteReset(exercise)
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

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

    /// Un bloc : son début, le début de sa semaine allégée, son test (à partir de ce jour).
    struct Block {
        let start: Date
        let deload: Date
        let test: Date
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

    var currentWeek: Week? { weeks.first { $0.isCurrent } }
    /// La date de l'objectif, décalée des semaines refaites.
    var shiftedGoalDate: Date? { goal?.date.map { $0.addingTimeInterval(Double(shiftWeeks) * 7 * 86_400) } }

    /// La séance prévue aujourd'hui (nil : jour de test).
    var todaySession: Prescription.Session? {
        switch today {
        case .session(let s), .light(let s), .deload(let s): return s
        case .test: return nil
        }
    }

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
        func weekStart(_ date: Date) -> Date { Schedule.weekStart(date, calendar: calendar) }
        func inWeek(_ start: Date) -> [SessionRecord] { sorted.filter { $0.start >= start && $0.start < start.addingTimeInterval(week) } }
        func trainingDays(_ list: [SessionRecord]) -> Int { Set(list.map { calendar.startOfDay(for: $0.start) }).count }

        var blockStart = weekStart(anchor)
        var blocks: [Block] = []
        var block = 1
        var tests: [Test] = []
        var shift = 0
        // Séances de semaines allégées et de tests : hors de la séance habituelle
        var excluded = Set<PersistentIdentifier>()

        while true {
            let reference = sorted.filter { !excluded.contains($0.persistentModelID) }
            // Le max : le dernier test ; au premier bloc, la meilleure série récente
            let testMax = tests.last?.value
            guard let habit = Prescription.habitual(reference, before: blockStart, testMax: testMax, calendar: calendar)
                    ?? Prescription.habitual(reference, before: now.addingTimeInterval(1), testMax: testMax, calendar: calendar)
            else { return nil }
            let days = Schedule.days(weekdays ?? Schedule.defaultWeekdays(habit.perWeek))
            let perWeek = days.count
            var weeks: [Week] = []
            var start = blockStart
            var progression = 0
            var repeats = 0
            var redo = false
            // Semaines de progression : une semaine finie où l'on a décroché est refaite
            while progression < Prescription.progressionWeeks {
                let planned = Prescription.progression(habit.session, week: progression)
                let done = inWeek(start)
                let end = start.addingTimeInterval(week)
                let isPast = end <= now
                var reason: String?
                if isPast, repeats < Prescription.maxRepeats {
                    let missed = perWeek - trainingDays(done)
                    let tiredCount = done.filter { tired.contains($0.persistentModelID) }.count
                    if missed > 0 { reason = missed == 1 ? "1 séance manquée" : "\(missed) séances manquées" }
                    else if tiredCount >= 2 { reason = "Forme basse × \(tiredCount)" }
                }
                weeks.append(Week(start: start, kind: .progression(progression, redo: redo), planned: planned,
                                  plannedSessions: perWeek, done: trainingDays(done),
                                  doneReps: done.reduce(0) { $0 + $1.totalReps }, isPast: isPast,
                                  isCurrent: start <= now && now < end, redoReason: reason))
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
            // Semaine allégée, puis le test
            let deload = Prescription.lighter(habit.session)
            let deloadDone = inWeek(start)
            deloadDone.forEach { excluded.insert($0.persistentModelID) }
            let deloadEnd = start.addingTimeInterval(week)
            weeks.append(Week(start: start, kind: .deload, planned: deload, plannedSessions: perWeek,
                              done: trainingDays(deloadDone), doneReps: deloadDone.reduce(0) { $0 + $1.totalReps },
                              isPast: deloadEnd <= now, isCurrent: start <= now && now < deloadEnd, redoReason: nil))
            let testDate = deloadEnd
            blocks.append(Block(start: weeks.first?.start ?? start, deload: start, test: testDate))
            if let test = sorted.first(where: { $0.start >= testDate }) {
                // Test fait : le bloc suivant repart la semaine d'après
                tests.append(Test(date: test.start, value: test.bestSet, block: block))
                excluded.insert(test.persistentModelID)
                blockStart = weekStart(test.start).addingTimeInterval(week)
                block += 1
                if blockStart <= now { continue }
                // Le bloc suivant commence la semaine prochaine : jusque-là, repos
                let next = Schedule.firstDay(days, inWeekOf: blockStart, calendar: calendar)
                return TrainingPlan(goal: goal, anchor: weekStart(anchor), blocks: blocks, block: block - 1, weeks: weeks, testDate: testDate, tests: tests,
                                    shiftWeeks: shift, today: .session(habit.session), status: .rest, next: next,
                                    days: [], ratios: habit.ratios, perWeek: perWeek)
            }
            let current = weeks.first { $0.isCurrent }
            let today: Today
            if now >= testDate {
                today = .test
            } else if current?.kind == .deload {
                today = .deload(deload)
            } else if lowForm, let current {
                today = .light(Prescription.lighter(current.planned))
            } else {
                today = .session(current?.planned ?? habit.session)
            }
            // La semaine en cours, jour par jour
            let thisWeek = weekStart(now)
            let schedule = Schedule.week(days, start: thisWeek, sessions: inWeek(thisWeek), now: now, calendar: calendar)
            let todaySessions = sorted.filter { calendar.isDate($0.start, inSameDayAs: now) }
            let todayReps = todaySessions.reduce(0) { $0 + $1.totalReps }
            let plannedToday: Int = {
                switch today {
                case .session(let s), .light(let s), .deload(let s): return s.total
                case .test: return 1
                }
            }()
            let status: DayStatus
            if !todaySessions.isEmpty, todayReps >= plannedToday {
                status = .done
            } else if today == .test || !todaySessions.isEmpty || schedule.due {
                status = .due
            } else {
                status = .rest
            }
            var next = schedule.next
            if next == nil {
                // Rien de plus cette semaine : la première séance de la semaine prochaine
                let nextWeek = thisWeek.addingTimeInterval(week)
                next = nextWeek >= testDate ? testDate : Schedule.firstDay(days, inWeekOf: nextWeek, calendar: calendar)
            }
            return TrainingPlan(goal: goal, anchor: weekStart(anchor), blocks: blocks, block: block, weeks: weeks, testDate: testDate, tests: tests,
                                shiftWeeks: shift, today: today, status: status, next: next, days: schedule.days,
                                ratios: habit.ratios, perWeek: perWeek)
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
}

extension HistoryStats {
    /// Le plan de l'exercice de ces statistiques, s'il a un objectif. `all` : toutes les séances
    /// (pour la phase, qui dit si la Forme est basse aujourd'hui).
    func plan(all: [SessionRecord]) -> TrainingPlan? {
        guard let exercise = sessions.first?.exercise else { return nil }
        let goal = Goal.load(exercise)
        guard let anchor = goal?.created ?? PlanAnchor.load(exercise) else { return nil }
        let tired = Set(formResults.filter { $0.result.zone == .tired }.map { $0.session.persistentModelID })
        let lowForm = [.lowForm, .overreaching, .deloadAdvised, .persistentFatigue].contains(phase(all: all).kind)
        return TrainingPlan.make(goal: goal, anchor: anchor, sessions: sessions, tired: tired, lowForm: lowForm,
                                 weekdays: Schedule.saved(exercise), now: now, calendar: calendar)
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

import Foundation
import SwiftData

/// Le plan d'un exercice, déduit de l'objectif et des séances faites (rien n'est stocké d'autre
/// que l'objectif) : des blocs de 3 semaines de progression, 1 semaine allégée, puis un test (une
/// série max). Le bloc suivant repart du test. Une semaine de progression où l'on décroche
/// (séances manquées, ou Forme basse deux fois) est refaite : le test est décalé d'autant.
/// Les paramètres de séance viennent tous de `Prescription` (provisoires).
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
        /// Séances faites, et répétitions faites cette semaine.
        let done: Int
        let doneReps: Int
        /// Semaine finie, ou en cours.
        let isPast: Bool
        let isCurrent: Bool
        /// Semaine finie et refaite : pourquoi (« 2 séances manquées », « Forme basse × 2 »).
        let redoReason: String?

        var plannedReps: Int { planned.total * plannedSessions }
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

    let goal: Goal
    let block: Int
    let weeks: [Week]
    /// Le test du bloc en cours : à partir de ce jour.
    let testDate: Date
    /// Les tests faits, du plus ancien au plus récent.
    let tests: [Test]
    /// Semaines refaites depuis le début de l'objectif : la date de l'objectif recule d'autant.
    let shiftWeeks: Int
    let today: Today
    let perWeek: Int

    var currentWeek: Week? { weeks.first { $0.isCurrent } }
    /// La date de l'objectif, décalée des semaines refaites.
    var shiftedGoalDate: Date? { goal.date.map { $0.addingTimeInterval(Double(shiftWeeks) * 7 * 86_400) } }

    /// La séance prévue aujourd'hui (nil : jour de test).
    var todaySession: Prescription.Session? {
        switch today {
        case .session(let s), .light(let s), .deload(let s): return s
        case .test: return nil
        }
    }

    /// Le plan au jour `now`. Nil sans aucune séance de l'exercice pour caler la séance habituelle.
    /// - Parameters:
    ///   - sessions: séances de l'exercice (tout ordre).
    ///   - tired: les séances dont la Forme était dans la zone fatiguée.
    ///   - lowForm: Forme basse aujourd'hui (phase : surcharge, forme basse…) : séance légère.
    static func make(goal: Goal, sessions: [SessionRecord], tired: Set<PersistentIdentifier>, lowForm: Bool,
                     now: Date = Date(), calendar: Calendar = .current) -> TrainingPlan? {
        let sorted = sessions.filter { $0.start <= now }.sorted { $0.start < $1.start }
        let week = 7 * 86_400.0
        func weekStart(_ date: Date) -> Date { calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date }
        func inWeek(_ start: Date) -> [SessionRecord] { sorted.filter { $0.start >= start && $0.start < start.addingTimeInterval(week) } }

        var blockStart = weekStart(goal.created)
        var block = 1
        var tests: [Test] = []
        var shift = 0
        // Séances de semaines allégées et de tests : hors de la séance habituelle
        var excluded = Set<PersistentIdentifier>()

        while true {
            let reference = sorted.filter { !excluded.contains($0.persistentModelID) }
            // La séance habituelle avant le bloc ; au tout début, celle des séances déjà faites
            guard let habit = Prescription.habitual(reference, before: blockStart, calendar: calendar)
                    ?? Prescription.habitual(reference, before: now.addingTimeInterval(1), calendar: calendar) else { return nil }
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
                    let missed = habit.perWeek - done.count
                    let tiredCount = done.filter { tired.contains($0.persistentModelID) }.count
                    if missed > 0 { reason = missed == 1 ? "1 séance manquée" : "\(missed) séances manquées" }
                    else if tiredCount >= 2 { reason = "Forme basse × \(tiredCount)" }
                }
                weeks.append(Week(start: start, kind: .progression(progression, redo: redo), planned: planned,
                                  plannedSessions: habit.perWeek, done: done.count,
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
            weeks.append(Week(start: start, kind: .deload, planned: deload, plannedSessions: habit.perWeek,
                              done: deloadDone.count, doneReps: deloadDone.reduce(0) { $0 + $1.totalReps },
                              isPast: deloadEnd <= now, isCurrent: start <= now && now < deloadEnd, redoReason: nil))
            let testDate = deloadEnd
            if let test = sorted.first(where: { $0.start >= testDate }) {
                // Test fait : le bloc suivant repart la semaine d'après
                tests.append(Test(date: test.start, value: test.bestSet, block: block))
                excluded.insert(test.persistentModelID)
                blockStart = weekStart(test.start).addingTimeInterval(week)
                block += 1
                if blockStart <= now { continue }
                // Le bloc suivant commence la semaine prochaine : on reste sur le test fait
                return TrainingPlan(goal: goal, block: block - 1, weeks: weeks, testDate: testDate, tests: tests,
                                    shiftWeeks: shift, today: .session(habit.session), perWeek: habit.perWeek)
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
            return TrainingPlan(goal: goal, block: block, weeks: weeks, testDate: testDate, tests: tests,
                                shiftWeeks: shift, today: today, perWeek: habit.perWeek)
        }
    }
}

// MARK: - Mesuré face à attendu

extension TrainingPlan {
    /// L'attendu à une date : le rythme nécessaire pour aller du départ à l'objectif à la date
    /// choisie (décalée des semaines refaites). Ce n'est pas une prédiction. Nil sans date.
    func expected(at date: Date) -> Double? {
        guard let end = shiftedGoalDate, end > goal.created else { return nil }
        let share = date.timeIntervalSince(goal.created) / end.timeIntervalSince(goal.created)
        return Double(goal.start) + Double(goal.target - goal.start) * share
    }

    enum Verdict { case pending(Int), ahead, onTrack, behind }

    /// En avance ou en retard, seulement quand c'est établi : pente de Theil-Sen des tests et
    /// son intervalle à 99 % (Sen 1968, comme `ProgressVerdict`), comparés au rythme nécessaire.
    /// Il faut 3 tests ; sans date d'objectif, pas de rythme nécessaire.
    var verdict: Verdict? {
        guard let end = shiftedGoalDate else { return nil }
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
        guard tests.count >= Self.minTests, let last = tests.last else { return nil }
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
        guard let exercise = sessions.first?.exercise, let goal = Goal.load(exercise) else { return nil }
        let tired = Set(formResults.filter { $0.result.zone == .tired }.map { $0.session.persistentModelID })
        let lowForm = [.lowForm, .overreaching, .deloadAdvised, .persistentFatigue].contains(phase(all: all).kind)
        return TrainingPlan.make(goal: goal, sessions: sessions, tired: tired, lowForm: lowForm, now: now, calendar: calendar)
    }
}

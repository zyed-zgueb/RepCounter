import Foundation
import SwiftData

// MARK: - Données

/// Une séance terminée, enregistrée sur l'iPhone.
///
/// Modèle conforme aux règles de CloudKit (valeur par défaut pour chaque propriété, relations
/// optionnelles, aucune contrainte d'unicité) : la synchronisation iCloud pourra être activée
/// plus tard sans migration.
@Model
final class SessionRecord {
    var exerciseID: String = Exercise.auto.rawValue
    var start: Date = Date()
    var end: Date = Date()
    /// Charge (kg, par haltère) pour les exercices qui en ont une.
    var load: Double?
    @Relationship(deleteRule: .cascade, inverse: \SetRecord.session)
    var sets: [SetRecord]? = []

    init(exercise: Exercise, start: Date, end: Date) {
        exerciseID = exercise.rawValue
        self.start = start
        self.end = end
    }

    var exercise: Exercise { Exercise(rawValue: exerciseID) ?? .auto }
    var orderedSets: [SetRecord] { (sets ?? []).sorted { $0.index < $1.index } }
    var totalReps: Int { orderedSets.reduce(0) { $0 + $1.reps } }
    var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
    var bestSet: Int { orderedSets.map(\.reps).max() ?? 0 }
    var averagePerSet: Double? {
        let sets = orderedSets
        return sets.isEmpty ? nil : Double(totalReps) / Double(sets.count)
    }
    /// Cadence moyenne (s par répétition).
    var cadence: Double? { average(orderedSets.compactMap(\.pace)) }
    /// Récupération avant une série : de la fin de la précédente au début de celle-ci.
    func rest(before index: Int) -> TimeInterval? {
        let sets = orderedSets
        guard index > 0, index < sets.count else { return nil }
        let previous = sets[index - 1]
        return max(0, sets[index].start.timeIntervalSince(previous.start.addingTimeInterval(previous.duration)))
    }

    /// Indice de performance : les répétitions des 3 premières séries, chacune pondérée par le
    /// repos qui la précède, k = (60 s / repos)^0,2 (1 avec 60 s, 1,15 avec 30 s, 0,80 avec 3 min ;
    /// repos borné entre 15 s et 5 min), multipliées par la charge pour les exercices avec haltère.
    /// Il récompense la capacité, le maintien d'une série à l'autre et la récupération rapide ;
    /// le format commun (3 séries) le rend comparable d'une séance et d'une personne à l'autre.
    /// Nil avec moins de 3 séries, ou sans charge pour un exercice avec haltère.
    var performanceIndex: Double? {
        let sets = orderedSets
        guard sets.count >= Self.indexSets else { return nil }
        var index = Double(sets[0].reps)
        for i in 1..<Self.indexSets {
            let rest = min(max(self.rest(before: i) ?? 60, 15), 300)
            index += Double(sets[i].reps) * pow(60 / rest, 0.2)
        }
        guard exercise.isWeighted else { return index }
        guard let load, load > 0 else { return nil }
        return index * load
    }

    static let indexSets = 3

    /// Écart entre la dernière et la première série, en % de la première (négatif quand on faiblit).
    var fatigue: Double? {
        let sets = orderedSets
        guard sets.count >= 2, let first = sets.first, let last = sets.last, first.reps > 0 else { return nil }
        return Double(last.reps - first.reps) / Double(first.reps) * 100
    }
}

/// Une série d'une séance enregistrée.
@Model
final class SetRecord {
    var index: Int = 0
    /// Répétitions retenues (éventuellement corrigées à la main).
    var reps: Int = 0
    /// Répétitions comptées par l'app.
    var countedReps: Int = 0
    var start: Date = Date()
    var duration: TimeInterval = 0
    /// Rythme du compteur à la fin de la série (voir `pace`, plus juste).
    var cadence: Double?
    /// Instant de chaque répétition, en secondes depuis la première.
    var repTimes: [Double] = []
    var session: SessionRecord?

    init(index: Int, reps: Int, start: Date, duration: TimeInterval, cadence: Double?, repTimes: [Double]) {
        self.index = index
        self.reps = reps
        countedReps = reps
        self.start = start
        self.duration = duration
        self.cadence = cadence
        self.repTimes = repTimes
    }

    /// Durée de chaque répétition (s) : elle s'allonge quand la fatigue arrive.
    var repDurations: [Double] { zip(repTimes.dropFirst(), repTimes).map { $0 - $1 } }

    /// Cadence de la série (s par répétition) : intervalle médian entre ses répétitions. La
    /// fin de série (dernière répétition comptée en retard, téléphone repris) ne la fausse pas.
    var pace: Double? { medianInterval(repTimes) ?? cadence }
}

extension SessionRecord {
    /// Enregistre la séance terminée d'un modèle de séance (rien si aucune répétition).
    @discardableResult
    static func save(_ model: WorkoutModel, load: Double?, in context: ModelContext) -> SessionRecord? {
        guard !model.sets.isEmpty, let start = model.sessionStart else { return nil }
        let record = SessionRecord(exercise: model.exercise, start: start, end: model.sessionEnd ?? Date())
        record.load = model.exercise.isWeighted ? load : nil
        context.insert(record)
        record.sets = model.sets.enumerated().map { index, set in
            SetRecord(index: index, reps: set.reps, start: set.start, duration: set.duration,
                      cadence: set.cadence, repTimes: set.repTimes)
        }
        try? context.save()
        return record
    }
}

// MARK: - Statistiques

/// Statistiques d'un ensemble de séances (un exercice, ou tous), calculées à la demande.
struct HistoryStats {
    let sessions: [SessionRecord]   // les plus récentes d'abord
    let calendar: Calendar
    let now: Date

    init(sessions: [SessionRecord], exercise: Exercise?, calendar: Calendar = .current, now: Date = Date()) {
        self.sessions = sessions
            .filter { exercise == nil || $0.exercise == exercise }
            .sorted { $0.start > $1.start }
        self.calendar = calendar
        self.now = now
    }

    var isEmpty: Bool { sessions.isEmpty }

    // Semaines

    func weekStart(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    var thisWeek: Date { weekStart(now) }

    /// Début des `count` dernières semaines, la plus ancienne d'abord (la dernière est la semaine en cours).
    func lastWeeks(_ count: Int) -> [Date] {
        (0..<count).reversed().compactMap { calendar.date(byAdding: .weekOfYear, value: -$0, to: thisWeek) }
    }

    func sessions(inWeek week: Date) -> [SessionRecord] {
        sessions.filter { weekStart($0.start) == week }
    }

    func volume(inWeek week: Date) -> Int {
        sessions(inWeek: week).reduce(0) { $0 + $1.totalReps }
    }

    var weekVolume: Int { volume(inWeek: thisWeek) }
    var previousWeekVolume: Int {
        calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek).map { volume(inWeek: $0) } ?? 0
    }
    var weekSessions: Int { sessions(inWeek: thisWeek).count }
    var weekDuration: TimeInterval { sessions(inWeek: thisWeek).reduce(0) { $0 + $1.duration } }

    /// Semaines consécutives avec au moins une séance, jusqu'à la semaine en cours (ou la
    /// précédente, si la semaine en cours n'a pas encore commencé).
    var weekStreak: Int {
        let active = Set(sessions.map { weekStart($0.start) })
        var week = active.contains(thisWeek) ? thisWeek : calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek)
        var streak = 0
        while let current = week, active.contains(current) {
            streak += 1
            week = calendar.date(byAdding: .weekOfYear, value: -1, to: current)
        }
        return streak
    }

    // Records (un exercice)

    struct Record {
        let value: Int
        let date: Date
    }

    var bestSet: Record? {
        sessions.max { $0.bestSet < $1.bestSet || ($0.bestSet == $1.bestSet && $0.start > $1.start) }
            .map { Record(value: $0.bestSet, date: $0.start) }
    }

    var bestSession: Record? {
        sessions.max { $0.totalReps < $1.totalReps || ($0.totalReps == $1.totalReps && $0.start > $1.start) }
            .map { Record(value: $0.totalReps, date: $0.start) }
    }

    var bestWeek: Record? {
        let weeks = Set(sessions.map { weekStart($0.start) })
        return weeks.map { Record(value: volume(inWeek: $0), date: $0) }
            .max { $0.value < $1.value || ($0.value == $1.value && $0.date > $1.date) }
    }

    /// Séances qui ont battu un record (série ou séance) de leur exercice au moment où elles ont eu lieu.
    var recordSessions: Set<PersistentIdentifier> {
        var result = Set<PersistentIdentifier>()
        var bestSet: [Exercise: Int] = [:], bestTotal: [Exercise: Int] = [:]
        for session in sessions.reversed() {
            let exercise = session.exercise
            if let set = bestSet[exercise], let total = bestTotal[exercise],
               session.bestSet > set || session.totalReps > total {
                result.insert(session.persistentModelID)
            }
            bestSet[exercise] = max(bestSet[exercise] ?? 0, session.bestSet)
            bestTotal[exercise] = max(bestTotal[exercise] ?? 0, session.totalReps)
        }
        return result
    }

    /// Séance précédente du même exercice.
    func previous(of session: SessionRecord) -> SessionRecord? {
        sessions.first { $0.exercise == session.exercise && $0.start < session.start }
    }

    // Progression (un exercice) : une valeur par semaine qui a des séances

    func weekly(weeks: Int = 12, _ value: (SessionRecord) -> Double?) -> [(week: Int, value: Double)] {
        lastWeeks(weeks).enumerated().compactMap { index, week in
            average(sessions(inWeek: week).compactMap(value)).map { (index, $0) }
        }
    }

    // Indice de performance (un exercice)

    /// Indice de l'exercice : la meilleure séance des 4 semaines qui précèdent `date`.
    func performanceIndex(at date: Date? = nil) -> Double? {
        let end = date ?? now
        let start = end.addingTimeInterval(-28 * 86_400)
        return sessions.filter { $0.start > start && $0.start <= end }.compactMap(\.performanceIndex).max()
    }

    /// Meilleure série des `lastDays` derniers jours.
    func bestSet(lastDays: Int) -> Int? {
        let start = now.addingTimeInterval(-Double(lastDays) * 86_400)
        return sessions.filter { $0.start > start }.map(\.bestSet).max()
    }

    /// Indice de l'exercice 4 semaines plus tôt, pour mesurer la progression.
    var previousPerformanceIndex: Double? {
        performanceIndex(at: now.addingTimeInterval(-28 * 86_400))
    }

    /// Un point par séance notée sur les `weeks` dernières semaines, de la plus ancienne à la
    /// plus récente : x en semaines depuis le début de la période (de 0 à `span`).
    func sessionIndices(weeks: Int = 12) -> (points: [(x: Double, value: Double)], span: Double) {
        let start = lastWeeks(weeks).first ?? thisWeek
        let week = 7.0 * 86_400
        let points = sessions.reversed()
            .filter { $0.start >= start }
            .compactMap { session in session.performanceIndex.map { (x: session.start.timeIntervalSince(start) / week, value: $0) } }
        return (points, max(now.timeIntervalSince(start) / week, 1))
    }

    /// Première séance notée : point de comparaison tant qu'il n'y a pas 4 semaines d'historique.
    var firstScored: (date: Date, value: Double)? {
        sessions.last { $0.performanceIndex != nil }.flatMap { session in session.performanceIndex.map { (date: session.start, value: $0) } }
    }

    // Régularité

    /// Répétitions par jour.
    func dailyVolume() -> [Date: Int] {
        sessions.reduce(into: [:]) { $0[calendar.startOfDay(for: $1.start), default: 0] += $1.totalReps }
    }
}

/// Intervalle médian entre des instants croissants (au moins trois), sinon nil.
func medianInterval(_ times: [Double]) -> Double? {
    guard times.count >= 3 else { return nil }
    let intervals = zip(times.dropFirst(), times).map { $0 - $1 }.sorted()
    let middle = intervals.count / 2
    return intervals.count % 2 == 1 ? intervals[middle] : (intervals[middle - 1] + intervals[middle]) / 2
}

func average(_ values: [Double]) -> Double? {
    values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
}

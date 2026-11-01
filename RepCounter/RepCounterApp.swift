import SwiftData
import SwiftUI
import TipKit

@main
struct RepCounterApp: App {
    @StateObject private var themeStore = ThemeStore()
    @StateObject private var tipJar = TipJar()
    private let container: ModelContainer

    init() {
        // CI : les tests du plan sur le vrai code Swift (miroir des scénarios de plan.py), puis sortie
        if UserDefaults.standard.bool(forKey: "planSelfTest") { PlanSelfTest.runAndExit() }
        if Capture.isActive {
            Capture.prepareDefaults()
            Tips.hideAllTipsForTesting()
        }
        RepsTips.configure()
        Schedule.forgetSavedDays()
        container = Capture.isActive ? Capture.container() : Self.storeContainer()
    }

    /// L'historique des séances, sur l'iPhone (le conteneur par défaut de SwiftData).
    private static func storeContainer() -> ModelContainer {
        do { return try ModelContainer(for: SessionRecord.self) }
        catch { fatalError("Historique illisible : \(error)") }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(themeStore)
                .environmentObject(tipJar)
                .environment(\.theme, themeStore.current)
                .preferredColorScheme(themeStore.current.colorScheme)
        }
        // Historique des séances, sur l'iPhone (iCloud activable plus tard : modèle compatible CloudKit)
        .modelContainer(container)
    }
}

/// L'app s'ouvre sur le cadran, réglé sur le dernier exercice (s'il fait toujours partie de « Mes
/// exercices »). Changer d'exercice (en glissant dans le cadran) recrée l'écran avec les capteurs
/// du nouvel exercice.
struct RootView: View {
    static let exerciseKey = "exercise"

    @AppStorage(RootView.exerciseKey) private var exerciseID = Exercise.pushups.rawValue
    @AppStorage(Exercise.mineKey) private var mineValue = Exercise.defaultMineValue
    @EnvironmentObject private var themeStore: ThemeStore
    @EnvironmentObject private var tipJar: TipJar
    /// L'écran du nouvel exercice démarre sa séance dès son affichage.
    @State private var startsSession = false
    @State private var showsSettings = false
    /// Premier lancement : la page de bienvenue, une seule fois.
    @AppStorage(WelcomeView.key) private var welcomed = false
    /// Exercice affiché à l'ouverture des Réglages : il le reste tant qu'ils sont ouverts, même
    /// si on le retire de Mes exercices (l'écran ne change qu'à leur fermeture).
    @State private var exerciseUnderSettings: Exercise?
    /// Incrémenté pour recréer l'écran avec d'autres capteurs (brassard).
    @State private var generation = 0

    private var mine: [Exercise] { Exercise.decode(mineValue) }

    private var exercise: Exercise {
        if let exerciseUnderSettings { return exerciseUnderSettings }
        let stored = Exercise(rawValue: exerciseID)
        return stored.flatMap { mine.contains($0) ? $0 : nil } ?? mine[0]
    }

    var body: some View {
        // Un écran par exercice : changer d'exercice arrête ses capteurs et démarre ceux du suivant.
        // Le nouvel écran s'affiche à l'identique (même exercice dans le cadran) : pas de transition.
        WorkoutView(exercise: exercise, exercises: mine, startsSession: startsSession,
                    settingsShown: showsSettings,
                    onOpenSettings: {
                        exerciseUnderSettings = exercise
                        showsSettings = true
                    },
                    onRebuild: { startsSession = false; generation += 1 }) { selected, start in
            startsSession = start
            exerciseID = selected.rawValue
        }
            .id("\(exercise.rawValue).\(generation)")
            .transition(.identity)
            // Présentés ici, au-dessus de l'écran d'entraînement. Leurs changements (brassard,
            // exercice retiré de Mes exercices) s'appliquent à leur fermeture
            .fullScreenCover(isPresented: Binding(get: { !welcomed }, set: { welcomed = !$0 })) {
                WelcomeView { welcomed = true }
                    .environment(\.theme, themeStore.current)
                    .preferredColorScheme(themeStore.current.colorScheme)
            }
            .sheet(isPresented: $showsSettings, onDismiss: { exerciseUnderSettings = nil }) {
                SettingsView()
                    .environmentObject(themeStore)
                    .environmentObject(tipJar)
                    .systemSheet()
            }
    }
}

// MARK: - Mode capture (captures d'écran de la CI)

/// Mode capture, pour les captures d'écran faites par la CI sur le simulateur : actif seulement
/// avec l'argument de lancement `-captureDemo YES` (jamais sur l'iPhone de l'utilisateur).
/// L'historique est alors remplacé par des séances de pompes d'exemple, en mémoire, et
/// `-captureScreen coaching|history|counter` ouvre cet écran.
enum Capture {
    static var isActive: Bool { UserDefaults.standard.bool(forKey: "captureDemo") }
    static var screen: String? { isActive ? UserDefaults.standard.string(forKey: "captureScreen") : nil }
    /// La situation à montrer : `progression` (par défaut, semaine 2 du bloc 1), `restDay` (repos
    /// conseillé après une séance très difficile hier), `done` (séance du jour faite),
    /// `testDay` (test de fin de bloc à faire).
    static var scenario: String { UserDefaults.standard.string(forKey: "captureScenario") ?? "progression" }

    private static var calendar: Calendar { .current }
    private static var today: Date { calendar.startOfDay(for: Date()) }
    private static func day(_ offset: Int, hour: Int = 18) -> Date {
        calendar.date(byAdding: .hour, value: hour, to: calendar.date(byAdding: .day, value: offset, to: today) ?? today) ?? today
    }
    /// Le début du plan : il y a 9 jours (deuxième semaine du bloc 1), ou 4 semaines avant ce lundi
    /// pour le jour de test (le test de fin de bloc tombe ce lundi, il est donc à faire).
    private static var planStart: Int {
        guard scenario == "testDay" else { return -9 }
        let monday = Schedule.weekStart(Date(), calendar: calendar)
        let days = calendar.dateComponents([.day], from: monday, to: today).day ?? 0
        return -(days + 28)
    }

    static func prepareDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: WelcomeView.key)
        defaults.set(Coach.steps + 1, forKey: Coach.key)
        Goal.save(Goal(target: 40, date: day(70, hour: 0), start: 30, created: day(planStart, hour: 8)), for: .pushups)
    }

    @MainActor
    static func container() -> ModelContainer {
        do {
            let container = try ModelContainer(for: SessionRecord.self,
                                               configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            seed(container.mainContext)
            return container
        } catch {
            fatalError("Mode capture : \(error)")
        }
    }

    /// 4 semaines d'habitude avant le plan (3 séances par semaine), les 2 tests de départ, puis
    /// une séance tous les 2 jours, aux cibles du plan.
    private static func seed(_ context: ModelContext) {
        func session(_ offset: Int, _ reps: [Int], targets: [Int?]? = nil, roles: [SetRole?]? = nil, effort: Int? = nil) {
            let start = day(offset)
            let record = SessionRecord(exercise: .pushups, start: start, end: start.addingTimeInterval(Double(reps.count) * 120))
            record.effort = effort
            record.sensing = "motion"
            context.insert(record)
            for (index, count) in reps.enumerated() {
                let set = SetRecord(index: index, reps: count, start: start.addingTimeInterval(Double(index) * 120),
                                    duration: Double(count) * 1.6, cadence: 1.6,
                                    repTimes: (0..<count).map { Double($0) * 1.6 })
                set.target = targets.flatMap { index < $0.count ? $0[index] : nil }
                set.role = roles.flatMap { index < $0.count ? $0[index]?.rawValue : nil }
                set.session = record
                context.insert(set)
            }
        }
        for offset in stride(from: planStart - 28, to: planStart, by: 2) where offset % 7 != 0 {
            session(offset, [24, 20, 17], effort: 6)
        }
        session(planStart, [8, 29], roles: [.warmup, .test], effort: 9)
        session(planStart + 2, [9, 31], roles: [.warmup, .test], effort: 9)
        for offset in stride(from: planStart + 4, through: -1, by: 2) {
            // Repos conseillé : la séance d'hier a été très difficile
            let hard = scenario == "restDay" && offset == -1
            session(offset, [28, 24, 21], targets: [28, 24, 21], effort: hard ? 8 : 6)
        }
        if scenario == "restDay", !stride(from: planStart + 4, through: -1, by: 2).contains(-1) {
            session(-1, [28, 24, 21], targets: [28, 24, 21], effort: 8)
        }
        if scenario == "done" {
            session(0, [28, 22, 21], targets: [28, 24, 21], effort: 6)
        }
        try? context.save()
    }
}

// MARK: - Tests du plan (CI)

/// Les scénarios clés de `Simulation/plan.py`, rejoués sur le vrai `TrainingPlan.make` : la CI
/// lance l'app avec `-planSelfTest YES` dans le simulateur, lit la sortie et échoue si un
/// scénario échoue. Un écart entre le Swift et son miroir Python se voit ainsi.
@MainActor
enum PlanSelfTest {
    private static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    /// Jour 0 : un lundi, comme dans plan.py.
    private static let base = Date(timeIntervalSince1970: 1_767_571_200) // lundi 5 janvier 2026, 00:00 UTC

    private static func date(_ day: Double) -> Date { base.addingTimeInterval(day * 86_400) }
    private static func day(_ date: Date) -> Int { Int((date.timeIntervalSince(base) / 86_400).rounded(.down)) }

    private static var context: ModelContext!
    private static var failures: [String] = []
    private static var count = 0

    private static func session(_ day: Double, _ reps: [Int], roles: [SetRole?]? = nil, targets: [Int?]? = nil,
                                effort: Int? = nil) -> SessionRecord {
        let start = date(day)
        let record = SessionRecord(exercise: .pushups, start: start, end: start.addingTimeInterval(600))
        record.effort = effort
        context.insert(record)
        var t = start
        for (index, count) in reps.enumerated() {
            let set = SetRecord(index: index, reps: count, start: t, duration: 30, cadence: 1.5, repTimes: [])
            set.role = roles.flatMap { index < $0.count ? $0[index]?.rawValue : nil }
            set.target = targets.flatMap { index < $0.count ? $0[index] : nil }
            set.session = record
            context.insert(set)
            t = t.addingTimeInterval(30 + 60)
        }
        return record
    }

    /// Lundi, mercredi, vendredi de [first, last), 4 × 15 (plan.py : schedule)
    private static func schedule(_ first: Int, _ last: Int, days: [Int] = [0, 2, 4], sets: [Int] = [15, 15, 15, 15]) -> [SessionRecord] {
        (first..<last).filter { days.contains((($0 % 7) + 7) % 7) }.map { session(Double($0) + 0.75, sets) }
    }

    private static func plan(_ sessions: [SessionRecord], _ now: Double, fatigue: Bool = false) -> TrainingPlan? {
        TrainingPlan.make(goal: nil, anchor: date(0), sessions: sessions, tired: [], lowForm: fatigue,
                          persistentFatigue: fatigue, now: date(now), calendar: calendar)
    }

    private static func check(_ name: String, _ ok: Bool) {
        count += 1
        if !ok { failures.append(name) }
    }

    static func runAndExit() {
        let container = try! ModelContainer(for: SessionRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = container.mainContext
        let history = schedule(-28, 0)

        // Bloc régulier : une séance proposée chaque jour ; semaine allégée ; jour de test
        let s10 = history + schedule(0, 10)
        let p10 = plan(s10, 10.5)
        check("régulier : séance, cibles 12 · 12 · 12", p10?.status == .due && p10?.todaySession?.targets == [12, 12, 12])
        check("régulier : prochaine demain", p10.flatMap { $0.next.map(day) } == 11)
        check("régulier : test au jour 28", p10.map { day($0.testDate) } == 28)
        let p22 = plan(history + schedule(0, 22), 22.5)
        check("semaine allégée : 2 séries", p22?.todaySession?.targets == [12, 12])
        check("jour de test", plan(history + schedule(0, 28), 28.2)?.today == .test)

        // Test fait : bloc 2, série 1 = 32 − 3
        let s2 = history + schedule(0, 28) + [session(28.75, [32], roles: [.test])]
        let p2 = plan(s2, 36.5)
        check("bloc 2 après le test", p2?.block == 2 && p2?.todaySession?.targets.first == 29)

        // Semaine refaite (1 séance en semaine 2) : test au jour 35
        let s3 = history + schedule(0, 21).filter { ![9, 11].contains(day($0.start)) }
        check("semaine refaite : test au jour 35", plan(s3, 21.5).map { day($0.testDate) } == 35)

        // Repos conseillé : séance d'hier très difficile (semaine 2)
        let w2 = schedule(-28, 8, days: [0, 3])
        let hard = w2 + [session(8.5, [15, 15, 15], effort: 8)]
        let pHard = plan(hard, 9.4)
        check("repos : séance d'hier très difficile", pHard?.status == .rest && pHard?.restReason == .hardYesterday)
        check("repos : prochaine le jour 10", pHard.flatMap { $0.next.map(day) } == 10)
        check("repos : séance faite quand même compte",
              plan(hard + [session(9.5, [15, 15, 15])], 9.7)?.status == .done)
        // 20 séries en 7 jours
        let daily = schedule(-28, 0, days: [0, 3]) + (0..<7).map { session(Double($0) + 0.5, [12, 12, 12]) }
        check("repos : 20 séries en 7 jours", plan(daily, 7.4)?.restReason == .weeklyVolume)
        // Veille du test
        check("repos : veille du test", plan(history + schedule(0, 27), 27.5)?.restReason == .beforeTest)
        // Fatigue persistante : repos, séance légère si on s'entraîne
        let pf = plan(history + schedule(0, 10), 10.5, fatigue: true)
        check("fatigue persistante : repos et séance légère", pf?.restReason == .persistentFatigue && pf?.todaySession?.targets == [12, 12])

        // Tests de départ : 2e à J+2, pas le lendemain, pas de 1er après le vendredi
        let cal = history + [session(0.75, [30], roles: [.test])]
        check("départ : pas de 2e test le lendemain", plan(cal, 1.5)?.today != .test)
        check("départ : 2e test 2 jours après", plan(cal, 2.5)?.testStep == TrainingPlan.TestStep(number: 2, of: 2))
        check("départ : pas de 1er test le samedi", plan(history, 5.5)?.today != .test)
        check("départ : 1er test le vendredi", plan(history, 4.5)?.today == .test)

        // Cible : jugée sur la cible affichée (réajustée), une série manquante compte
        let s8 = schedule(-28, 0, days: [0, 3])
        check("cible réajustée atteinte : fait", plan(s8 + [session(8.5, [97, 78, 62], targets: [97, 78, 62])], 8.7)?.targetMissed == false)
        check("une série sous sa cible : cible manquée", plan(s8 + [session(8.5, [97, 70, 62], targets: [97, 78, 64])], 8.7)?.targetMissed == true)
        check("une série prévue non faite : cible manquée", plan(s8 + [session(8.5, [97, 78], targets: [97, 78])], 8.7)?.targetMissed == true)

        // Longue absence : reprise
        check("longue absence : reprise", plan(history + schedule(0, 10), 45)?.today == .comeback)

        let result = failures.isEmpty ? "PLAN SELFTEST OK \(count)" : "PLAN SELFTEST ÉCHEC \(failures.count)/\(count) : " + failures.joined(separator: " | ")
        print(result)
        fflush(stdout)
        exit(failures.isEmpty ? 0 : 1)
    }
}


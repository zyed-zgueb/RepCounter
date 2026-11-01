import SwiftData
import SwiftUI
import TipKit

@main
struct RepCounterApp: App {
    @StateObject private var themeStore = ThemeStore()
    @StateObject private var tipJar = TipJar()
    private let container: ModelContainer

    init() {
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

    private static var calendar: Calendar { .current }
    private static var today: Date { calendar.startOfDay(for: Date()) }
    private static func day(_ offset: Int, hour: Int = 18) -> Date {
        calendar.date(byAdding: .hour, value: hour, to: calendar.date(byAdding: .day, value: offset, to: today) ?? today) ?? today
    }
    /// Le plan a commencé il y a 9 jours : la deuxième semaine du bloc 1.
    private static let planStart = -9

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
            session(offset, [28, 24, 21], targets: [28, 24, 21], effort: 6)
        }
        try? context.save()
    }
}


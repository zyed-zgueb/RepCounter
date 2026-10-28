import SwiftData
import SwiftUI

@main
struct RepCounterApp: App {
    @StateObject private var themeStore = ThemeStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(themeStore)
                .environment(\.theme, themeStore.current)
                .preferredColorScheme(themeStore.current.colorScheme)
        }
        // Historique des séances, sur l'iPhone (iCloud activable plus tard : modèle compatible CloudKit)
        .modelContainer(for: SessionRecord.self)
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
            .statusBarHidden()
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
                    .environment(\.theme, themeStore.current)
                    .preferredColorScheme(themeStore.current.colorScheme)
            }
    }
}

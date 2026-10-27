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
    @AppStorage(Exercise.armbandKey) private var hasArmband = false
    /// L'écran du nouvel exercice démarre sa séance dès son affichage.
    @State private var startsSession = false

    private var mine: [Exercise] { Exercise.decode(mineValue) }

    private var exercise: Exercise {
        let stored = Exercise(rawValue: exerciseID)
        return stored.flatMap { mine.contains($0) ? $0 : nil } ?? mine[0]
    }

    var body: some View {
        // Un écran par exercice : changer d'exercice arrête ses capteurs et démarre ceux du suivant.
        // Le nouvel écran s'affiche à l'identique (même exercice dans le cadran) : pas de transition.
        WorkoutView(exercise: exercise, exercises: mine, startsSession: startsSession) { selected, start in
            startsSession = start
            exerciseID = selected.rawValue
        }
            // Brassard déclaré ou retiré : l'écran d'un exercice de bras change de capteurs
            .id(exercise.isArmExercise ? "\(exercise.rawValue).\(hasArmband)" : exercise.rawValue)
            .transition(.identity)
            .statusBarHidden()
    }
}

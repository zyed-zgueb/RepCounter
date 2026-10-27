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
        .modelContainer(for: [SessionRecord.self, FormTest.self])
    }
}

/// L'app s'ouvre sur le cadran, réglé sur le dernier exercice. Changer d'exercice (en glissant
/// dans le cadran) recrée l'écran avec les capteurs du nouvel exercice.
struct RootView: View {
    static let exerciseKey = "exercise"

    @AppStorage(RootView.exerciseKey) private var exerciseID = Exercise.pushups.rawValue
    /// Ce que l'écran du nouvel exercice lance dès son affichage.
    @State private var startAction = StartAction.none

    private var exercise: Exercise { Exercise(rawValue: exerciseID) ?? .pushups }

    var body: some View {
        // Un écran par exercice : changer d'exercice arrête ses capteurs et démarre ceux du suivant.
        // Le nouvel écran s'affiche à l'identique (même exercice dans le cadran) : pas de transition.
        WorkoutView(exercise: exercise, startAction: startAction) { selected, action in
            startAction = action
            exerciseID = selected.rawValue
        }
            .id(exercise)
            .transition(.identity)
            .statusBarHidden()
    }
}

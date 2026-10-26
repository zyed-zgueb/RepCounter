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
    }
}

/// L'app s'ouvre sur le cadran, réglé sur le dernier exercice. Le choix de l'exercice
/// se pose par-dessus, puis le cadran se règle sur le nouvel exercice.
struct RootView: View {
    static let exerciseKey = "exercise"

    @AppStorage(RootView.exerciseKey) private var exerciseID = Exercise.pushups.rawValue
    @State private var showsPicker = false

    private var exercise: Exercise { Exercise(rawValue: exerciseID) ?? .pushups }

    var body: some View {
        ZStack {
            // Un écran par exercice : changer d'exercice arrête ses capteurs et démarre ceux du suivant
            WorkoutView(exercise: exercise) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showsPicker = true }
            }
            .id(exercise)
            .transition(.opacity)

            if showsPicker {
                ExercisePicker(selected: exercise) { choice in
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        exerciseID = choice.rawValue
                        showsPicker = false
                    }
                } onClose: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showsPicker = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.04)))
                .zIndex(1)
            }
        }
        .statusBarHidden()
    }
}

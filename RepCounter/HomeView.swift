import SwiftUI

/// Accueil : uniquement la liste des exercices. Les réglages sont rangés derrière la roue dentée.
struct HomeView: View {
    @Environment(\.theme) private var theme
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                header
                // Liste : défile seulement si l'écran est trop petit pour tout afficher
                ScrollView {
                    MonitorPanel("Exercice") {
                        VStack(spacing: 0) {
                            ForEach(Array(Exercise.allCases.enumerated()), id: \.element) { index, exercise in
                                NavigationLink(value: exercise) {
                                    ExerciseRow(index: index + 1, exercise: exercise)
                                }
                                .buttonStyle(.plain)
                                if index < Exercise.allCases.count - 1 {
                                    Rectangle().fill(theme.line).frame(height: 1)
                                }
                            }
                        }
                    }
                }
                .bounceOnlyIfNeeded()
            }
            .padding(.horizontal, 16)
            .background(theme.background.ignoresSafeArea())
            .navigationDestination(for: Exercise.self) { exercise in
                WorkoutView(exercise: exercise)
            }
            .sheet(isPresented: $showsSettings) {
                SettingsView()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(theme.primary)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("REPS")
                    .font(theme.font(28, .bold))
                    .tracking(6)
                    .foregroundStyle(
                        LinearGradient(colors: [theme.secondary, theme.primary], startPoint: .leading, endPoint: .trailing)
                    )
                MonitorLabel("Moniteur de répétitions")
            }
            Spacer()
            IconButton(systemImage: "gearshape") { showsSettings = true }
        }
        .padding(.top, 8)
    }
}

private struct ExerciseRow: View {
    @Environment(\.theme) private var theme
    let index: Int
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index))
                .font(theme.font(12, .semibold))
                .foregroundStyle(theme.dim)
            ExerciseIcon(exercise: exercise)
                .foregroundStyle(theme.primary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.title.uppercased())
                    .font(theme.font(15, .bold))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(exercise.placement)
                    .font(theme.font(10))
                    .foregroundStyle(theme.dim)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Text(exercise.sensorTag)
                .font(theme.font(9, .bold))
                .tracking(1)
                .foregroundStyle(theme.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.primary.opacity(0.5), lineWidth: 1))
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.dim)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

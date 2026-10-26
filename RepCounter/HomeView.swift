import SwiftUI

/// Accueil : sélection de l'exercice, sans caméra. Toucher une ligne ouvre la séance.
struct HomeView: View {
    @AppStorage(WorkoutModel.announceEveryKey) private var announceEvery = 1

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    MonitorPanel("Sélection de l'exercice") {
                        VStack(spacing: 0) {
                            ForEach(Array(Exercise.allCases.enumerated()), id: \.element) { index, exercise in
                                NavigationLink(value: exercise) {
                                    ExerciseRow(index: index + 1, exercise: exercise)
                                }
                                .buttonStyle(.plain)
                                if index < Exercise.allCases.count - 1 {
                                    Rectangle().fill(Theme.line).frame(height: 1)
                                }
                            }
                        }
                    }
                    MonitorPanel("Annonce vocale") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                ForEach(WorkoutModel.announceChoices, id: \.self) { every in
                                    Button(every == 1 ? "Chaque rep" : "Toutes les \(every)") {
                                        announceEvery = every
                                    }
                                    .buttonStyle(MonitorButtonStyle(color: Theme.trace, filled: announceEvery == every, height: 38))
                                }
                            }
                            Text("Les répétitions non annoncées font un bip court.")
                                .font(Theme.mono(11))
                                .foregroundStyle(Theme.dim)
                        }
                    }
                    footer
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationDestination(for: Exercise.self) { exercise in
                WorkoutView(exercise: exercise)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Theme.trace)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("REPS")
                    .font(Theme.mono(28, .bold))
                    .tracking(6)
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.violet, Theme.trace], startPoint: .leading, endPoint: .trailing)
                    )
                MonitorLabel("Moniteur de répétitions")
            }
            Spacer()
            HStack(spacing: 6) {
                StatusLED(color: Theme.ok)
                MonitorLabel("Prêt", color: Theme.ok)
            }
        }
        .padding(.top, 8)
    }

    private var footer: some View {
        Text("Comptage par caméra 3D et capteurs de mouvement · aucune image enregistrée")
            .font(Theme.mono(10))
            .foregroundStyle(Theme.dim)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }
}

private struct ExerciseRow: View {
    let index: Int
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index))
                .font(Theme.mono(12, .semibold))
                .foregroundStyle(Theme.dim)
            Image(systemName: exercise.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.trace)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.title.uppercased())
                    .font(Theme.mono(15, .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(exercise.placement)
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.dim)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Text(exercise.sensorTag)
                .font(Theme.mono(9, .bold))
                .tracking(1)
                .foregroundStyle(Theme.trace)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.trace.opacity(0.5), lineWidth: 1))
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.dim)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

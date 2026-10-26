import SwiftUI

/// Accueil : sélection de l'exercice, sans caméra. Toucher une ligne ouvre la séance.
struct HomeView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var themeStore: ThemeStore
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
                                    Rectangle().fill(theme.line).frame(height: 1)
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
                                    .buttonStyle(MonitorButtonStyle(color: theme.primary, filled: announceEvery == every, height: 38, fontSize: 11))
                                }
                            }
                            Text("Les répétitions non annoncées font un bip court.")
                                .font(theme.font(11))
                                .foregroundStyle(theme.dim)
                        }
                    }
                    MonitorPanel("Thème d'affichage") {
                        VStack(spacing: 8) {
                            ForEach(themeStore.themes) { option in
                                ThemeRow(option: option,
                                         selected: option.id == themeStore.current.id,
                                         unlocked: themeStore.isUnlocked(option)) {
                                    themeStore.selectedID = option.id
                                }
                            }
                        }
                    }
                    footer
                }
                .padding(16)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationDestination(for: Exercise.self) { exercise in
                WorkoutView(exercise: exercise)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(theme.primary)
        .preferredColorScheme(theme.colorScheme)
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
            HStack(spacing: 6) {
                StatusLED(color: theme.ok)
                MonitorLabel("Prêt", color: theme.ok)
            }
        }
        .padding(.top, 8)
    }

    private var footer: some View {
        Text("Comptage par caméra 3D et capteurs de mouvement · aucune image enregistrée")
            .font(theme.font(10))
            .foregroundStyle(theme.dim)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
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
            Image(systemName: exercise.symbol)
                .font(.system(size: 20, weight: .semibold))
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

/// Aperçu d'un thème : ses couleurs, son nom dans sa police, et son statut (inclus ou premium).
private struct ThemeRow: View {
    @Environment(\.theme) private var theme
    let option: AppTheme
    let selected: Bool
    let unlocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                HStack(spacing: 0) {
                    let swatches = [option.background, option.panel, option.primary, option.secondary, option.ok]
                    ForEach(swatches.indices, id: \.self) { index in
                        Rectangle().fill(swatches[index])
                    }
                }
                .frame(width: 70, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.line, lineWidth: 1))
                Text(option.name.uppercased())
                    .font(option.font(14, .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                if option.premium {
                    Label(unlocked ? "Premium" : "Verrouillé", systemImage: unlocked ? "star.fill" : "lock.fill")
                        .font(theme.font(9, .bold))
                        .foregroundStyle(theme.warn)
                }
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? theme.primary : theme.dim)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
}

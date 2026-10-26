import SwiftUI

/// Choix de l'exercice, posé sur le cadran : six tuiles, sans défilement.
struct ExercisePicker: View {
    @Environment(\.theme) private var theme
    let selected: Exercise
    let onSelect: (Exercise) -> Void
    let onClose: () -> Void

    private static let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                MonitorLabel("Exercice", color: theme.text)
                Spacer()
                IconButton(systemImage: "xmark", action: onClose)
            }
            .frame(height: 44)

            LazyVGrid(columns: Self.columns, spacing: 12) {
                ForEach(Exercise.allCases) { exercise in
                    tile(exercise)
                }
            }

            Text("Le cadran se règle sur l'exercice choisi.\nL'app s'en souvient à la prochaine ouverture.")
                .font(theme.font(12))
                .foregroundStyle(theme.dim)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                theme.background.opacity(0.82)
            }
            .ignoresSafeArea()
        }
    }

    private func tile(_ exercise: Exercise) -> some View {
        let on = exercise == selected
        let corner = max(theme.radius, 4) * 2
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            onSelect(exercise)
        } label: {
            VStack(spacing: 10) {
                ExerciseIcon(exercise: exercise, size: 46)
                    .foregroundStyle(on ? theme.primary : theme.text)
                Text(exercise.shortTitle.uppercased())
                    .font(theme.font(14, .bold))
                    .tracking(1.5)
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(exercise.sensorTag)
                    .font(theme.font(9, .bold))
                    .tracking(1)
                    .foregroundStyle(on ? theme.primary : theme.dim)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 148)
            .background(on ? theme.primary.opacity(0.1) : theme.panel,
                        in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(on ? theme.primary : theme.line, lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if on {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(theme.primary)
                        .padding(10)
                }
            }
            .shadow(color: theme.primary.opacity(on ? 0.25 * min(theme.glow, 1) : 0), radius: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(exercise.title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
